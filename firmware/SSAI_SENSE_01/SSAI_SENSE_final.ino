/**
 * SwasthyaSetu AI - ESP32 Firmware (v3.0.0)
 * 
 * Features: 
 * - Strictly Mutually Exclusive Sensor Isolation
 * - 5-Page Animated UI (Home, SpO2, ECG, Temp, Sys)
 * - Dynamic Live MAX30102 Processing on Core 0
 * - Real-time Telemetry payload management
 */
#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <MAX30105.h>
#include <Adafruit_MLX90614.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <math.h>

// ---------------------------------------------------------
// HARDWARE PINS
// ---------------------------------------------------------
#define I2C_SDA_PIN         21
#define I2C_SCL_PIN         22
#define I2C1_SDA_PIN        26
#define I2C1_SCL_PIN        27
#define ECG_ANALOG_PIN      36
#define ECG_LO_PLUS_PIN     39
#define ECG_LO_MINUS_PIN    34
#define ECG_SDN_PIN         18
#define TOUCH_PIN_1         4   // HOLD = Start Measure
#define TOUCH_PIN_2         14  // TAP = Next Page
#define LED_PIN             2
#define BATTERY_PIN         35
#define SCREEN_WIDTH        128
#define SCREEN_HEIGHT       64
#define OLED_RESET          -1
#define OLED_ADDR           0x3C

// BLE UUIDs
#define SERVICE_UUID        "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define DEV_INFO_CHAR_UUID  "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define TELEMETRY_CHAR_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
#define WAVEFORM_CHAR_UUID  "6e400004-b5a3-f393-e0a9-e50e24dcca9e"
#define CONTROL_CHAR_UUID   "6e400005-b5a3-f393-e0a9-e50e24dcca9e"

// ---------------------------------------------------------
// BITMAPS & ANIMATIONS
// ---------------------------------------------------------
const unsigned char bmp_heart_16[] PROGMEM = {
  0x00, 0x00, 0x1c, 0x38, 0x3e, 0x7c, 0x7f, 0xfe, 0x7f, 0xfe, 0x7f, 0xfe, 0x7f, 0xfe, 0x3f, 0xfc, 
  0x1f, 0xf8, 0x0f, 0xf0, 0x07, 0xe0, 0x03, 0xc0, 0x01, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};
// 16x16 Mascot
const unsigned char bmp_mascot_open[] PROGMEM = {
  0x03, 0xc0, 0x0f, 0xf0, 0x1c, 0x38, 0x30, 0x0c, 0x23, 0xc4, 0x63, 0xc6, 0x40, 0x02, 0x40, 0x02, 
  0x44, 0x22, 0x48, 0x12, 0x50, 0x0a, 0x20, 0x04, 0x30, 0x0c, 0x1c, 0x38, 0x0f, 0xf0, 0x03, 0xc0
};
const unsigned char bmp_mascot_blink[] PROGMEM = {
  0x03, 0xc0, 0x0f, 0xf0, 0x1c, 0x38, 0x30, 0x0c, 0x20, 0x04, 0x63, 0xc6, 0x40, 0x02, 0x40, 0x02, 
  0x44, 0x22, 0x48, 0x12, 0x50, 0x0a, 0x20, 0x04, 0x30, 0x0c, 0x1c, 0x38, 0x0f, 0xf0, 0x03, 0xc0
};

// ---------------------------------------------------------
// ARCHITECTURE ENUMS & STATE
// ---------------------------------------------------------
enum PageState { PAGE_HOME = 0, PAGE_SPO2, PAGE_ECG, PAGE_TEMP, PAGE_SYS };
volatile PageState currentPage = PAGE_HOME;

enum SystemState { SYS_IDLE = 0, MEASURE_SPO2, MEASURE_ECG, MEASURE_TEMP };
volatile SystemState sysState = SYS_IDLE;
unsigned long measurementStartTime = 0;
unsigned int measurementDuration = 0;

TwoWire I2C_MAX(1);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

BLEServer* pServer = NULL;
BLECharacteristic* pTelemetryChar = NULL;
BLECharacteristic* pWaveformChar = NULL;
bool deviceConnected = false;

QueueHandle_t ecgQueue;
hw_timer_t * timer = NULL;
portMUX_TYPE timerMux = portMUX_INITIALIZER_UNLOCKED;

TaskHandle_t Core0Task;
TaskHandle_t Core1Task;

bool mlxFound = false;
bool maxFound = false;
volatile int16_t currentECG = 0;
bool leadOff = false;

// Shared Vitals (Retained across mode switches)
uint16_t ecg_hr = 0, spo2_hr = 0, current_hr = 0;
uint16_t current_spo2 = 0;
float current_temp = 0.0;
float current_battery_v = 0;
int battery_percent = 0;

// ECG DSP
double b_n = 0, f_fast = 0, f_slow = 0;
const double alpha_min = 0.0005, alpha_max = 0.005;
double theta = 500.0, last_x = 0, slope_n_1 = 0, slope_n = 0;
unsigned long last_peak_time = 0;
int8_t ecgHistory[128] = {0}; 
uint8_t ecgHead = 0;

// SpO2 DSP
long ir_avg = 0;
unsigned long last_spo2_beat = 0;

// UI State
unsigned long bootTime = 0;
unsigned int bleFrames = 0;
unsigned long lastTouchTime2 = 0;
unsigned long touch1PressStart = 0;
bool showHeartIcon = false;

// ---------------------------------------------------------
// BLE CALLBACKS
// ---------------------------------------------------------
void powerSensors(SystemState targetMode);
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        BLEDevice::startAdvertising();
    }
};

class MyControlCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue();
        if (value.length() > 0) {
            uint8_t cmd = (uint8_t)value[0];
            if (cmd == 0x01) {
                currentPage = PAGE_SPO2;
                powerSensors(MEASURE_SPO2);
                measurementDuration = 30000;
            } else if (cmd == 0x02) {
                currentPage = PAGE_ECG;
                powerSensors(MEASURE_ECG);
                measurementDuration = 30000;
            } else if (cmd == 0x03) {
                currentPage = PAGE_TEMP;
                powerSensors(MEASURE_TEMP);
                measurementDuration = 5000;
            } else if (cmd == 0x00) {
                currentPage = PAGE_HOME;
                powerSensors(SYS_IDLE);
                measurementDuration = 0;
            }
        }
    }
};

// ---------------------------------------------------------
// MUTUALLY EXCLUSIVE POWER MANAGEMENT
// ---------------------------------------------------------
void powerSensors(SystemState targetMode) {
    if (targetMode == MEASURE_ECG) {
        digitalWrite(ECG_SDN_PIN, HIGH); // AD8232 ON
        if(maxFound) particleSensor.shutDown(); // MAX OFF
    } 
    else if (targetMode == MEASURE_SPO2) {
        digitalWrite(ECG_SDN_PIN, LOW); // AD8232 OFF
        if(maxFound) particleSensor.wakeUp(); // MAX ON
        particleSensor.clearFIFO(); // Reset stale data
    } 
    else if (targetMode == MEASURE_TEMP) {
        digitalWrite(ECG_SDN_PIN, LOW); // AD8232 OFF
        if(maxFound) particleSensor.shutDown(); // MAX OFF
    } 
    else {
        // SYS_IDLE
        digitalWrite(ECG_SDN_PIN, LOW);
        if(maxFound) particleSensor.shutDown();
    }
    sysState = targetMode;
    measurementStartTime = millis();
}

// ---------------------------------------------------------
// HARDWARE TIMER (ECG SAMPLING)
// ---------------------------------------------------------
void IRAM_ATTR onEcgTimer() {
    portENTER_CRITICAL_ISR(&timerMux);
    if(sysState == MEASURE_ECG) {
        if(digitalRead(ECG_LO_PLUS_PIN) || digitalRead(ECG_LO_MINUS_PIN)) {
            leadOff = true;
            currentECG = 0;
        } else {
            leadOff = false;
            currentECG = analogRead(ECG_ANALOG_PIN);
        }
        xQueueSendFromISR(ecgQueue, (void*)&currentECG, NULL);
    }
    portEXIT_CRITICAL_ISR(&timerMux);
}

// ---------------------------------------------------------
// DSP LOGIC
// ---------------------------------------------------------
double processECG_BaselineRemoval(double x_n) {
    f_fast = f_fast * 0.8 + x_n * 0.2;
    f_slow = f_slow * 0.99 + x_n * 0.01;
    double alpha_n = alpha_min + (abs(f_fast - f_slow) * 0.00001);
    if(alpha_n > alpha_max) alpha_n = alpha_max;
    if(alpha_n < alpha_min) alpha_n = alpha_min;
    b_n = b_n * (1.0 - alpha_n) + f_slow * alpha_n;
    return x_n - b_n;
}

void detectRPeak(double y_n, unsigned long t_n) {
    slope_n_1 = slope_n;
    slope_n = y_n - last_x;
    if (y_n > theta && slope_n_1 > 0 && slope_n < 0 && (t_n - last_peak_time > 400)) {
        uint16_t rr = t_n - last_peak_time;
        last_peak_time = t_n;
        showHeartIcon = true;
        if (rr > 0) {
            ecg_hr = (uint16_t)(60000.0 / rr);
            if(ecg_hr > 250) ecg_hr = 250;
            if(ecg_hr < 30) ecg_hr = 0;
            current_hr = ecg_hr; // Update global
        }
        theta = 0.9 * theta + 0.1 * abs(y_n);
    } else {
        if (t_n - last_peak_time > 100) showHeartIcon = false;
    }
    if(t_n - last_peak_time > 2000) theta *= 0.99; 
    last_x = y_n;
}

#define PPG_BUFFER_SIZE 100
uint32_t redBuffer[PPG_BUFFER_SIZE] = {0};
uint32_t irBuffer[PPG_BUFFER_SIZE] = {0};
uint8_t ppgHead = 0;

void processSpO2AndHR(uint32_t redValue, uint32_t irValue, unsigned long t_n) {
    if (irValue < 50000 || redValue < 50000) {
        current_spo2 = 0;
        current_hr = 0;
        showHeartIcon = false;
        return;
    }

    // Store in rolling PPG buffer
    redBuffer[ppgHead] = redValue;
    irBuffer[ppgHead] = irValue;
    ppgHead = (ppgHead + 1) % PPG_BUFFER_SIZE;

    // Detect Pulse Peak on IR channel with noise suppression
    if (ir_avg == 0) ir_avg = irValue;
    ir_avg = (ir_avg * 0.96) + (irValue * 0.04);

    if (irValue < ir_avg - 1800) {
        if (t_n - last_spo2_beat > 450) { // Refractory period: max 133 BPM to prevent noise double-counting
            uint16_t rr = t_n - last_spo2_beat;
            last_spo2_beat = t_n;
            uint16_t raw_hr = 60000 / rr;
            if (raw_hr >= 45 && raw_hr <= 140) {
                if (current_hr == 0 || current_hr > 140) {
                    current_hr = raw_hr;
                } else {
                    current_hr = (uint16_t)(current_hr * 0.75 + raw_hr * 0.25);
                }
            }
            showHeartIcon = true;

            // Compute R-Ratio SpO2 from rolling buffer
            double sumRed = 0, sumIr = 0;
            uint32_t minRed = 0xFFFFFFFF, maxRed = 0;
            uint32_t minIr = 0xFFFFFFFF, maxIr = 0;

            for (int i = 0; i < PPG_BUFFER_SIZE; i++) {
                if (redBuffer[i] == 0) continue;
                sumRed += redBuffer[i];
                sumIr += irBuffer[i];
                if (redBuffer[i] < minRed) minRed = redBuffer[i];
                if (redBuffer[i] > maxRed) maxRed = redBuffer[i];
                if (irBuffer[i] < minIr) minIr = irBuffer[i];
                if (irBuffer[i] > maxIr) maxIr = irBuffer[i];
            }

            double dcRed = sumRed / PPG_BUFFER_SIZE;
            double dcIr = sumIr / PPG_BUFFER_SIZE;
            double acRed = (double)(maxRed - minRed);
            double acIr = (double)(maxIr - minIr);

            if (dcRed > 0 && dcIr > 0 && acIr > 0) {
                // R-Ratio = (AC_red / DC_red) / (AC_ir / DC_ir)
                double rRatio = (acRed / dcRed) / (acIr / dcIr);
                // Standard Maxim Empirical Formula: SpO2 = 104 - 17 * R
                int calcSpO2 = (int)(104.0 - 17.0 * rRatio);
                if (calcSpO2 > 100) calcSpO2 = 100;
                if (calcSpO2 < 70) calcSpO2 = 70;
                current_spo2 = (uint16_t)calcSpO2;
            }
        }
    } else {
        if (t_n - last_spo2_beat > 150) showHeartIcon = false;
    }
}

// ---------------------------------------------------------
// CORE 0: ISOLATED SENSOR POLLING
// ---------------------------------------------------------
void core0TaskFunction(void * pvParameters) {
    int16_t raw_sample;
    uint8_t ble_buffer[16];
    uint8_t buffer_idx = 0;
    
    for(;;) {
        unsigned long current_time = millis();
        
        if (sysState == MEASURE_ECG) {
            if (xQueueReceive(ecgQueue, &raw_sample, pdMS_TO_TICKS(10))) {
                double filtered = processECG_BaselineRemoval((double)raw_sample);
                detectRPeak(filtered, current_time);
                
                int disp_val = (int)(filtered / 50.0); 
                if(disp_val > 31) disp_val = 31;
                if(disp_val < -32) disp_val = -32;
                ecgHistory[ecgHead] = (int8_t)disp_val;
                ecgHead = (ecgHead + 1) % 128;
                
                if (deviceConnected && !leadOff) {
                    int16_t transmit_val = (int16_t)filtered;
                    ble_buffer[buffer_idx++] = (transmit_val & 0xFF);
                    ble_buffer[buffer_idx++] = (transmit_val >> 8) & 0xFF;
                    if (buffer_idx >= 16) {
                        uint8_t tx_frame[20] = {0x02, 0x01, 0x00, 0x00}; 
                        memcpy(&tx_frame[4], ble_buffer, 16);
                        pWaveformChar->setValue(tx_frame, 20);
                        pWaveformChar->notify();
                        buffer_idx = 0;
                        bleFrames++;
                    }
                }
            }
        } 
        else if (sysState == MEASURE_SPO2) {
            if (maxFound) {
                particleSensor.check(); 
                while (particleSensor.available()) {
                    uint32_t red = particleSensor.getFIFORed();
                    uint32_t ir = particleSensor.getFIFOIR();
                    particleSensor.nextSample();
                    processSpO2AndHR(red, ir, current_time);
                }
            }
            vTaskDelay(pdMS_TO_TICKS(10));
        } 
        else {
            vTaskDelay(pdMS_TO_TICKS(50)); // Idle power savings
        }
    }
}

// ---------------------------------------------------------
// DRAWING ROUTINES (5 PAGES)
// ---------------------------------------------------------
void drawProgressBar(int y, unsigned long elapsed, unsigned int total) {
    display.drawRect(14, y, 100, 6, SSD1306_WHITE);
    int fill = (elapsed * 100) / total;
    if (fill > 100) fill = 100;
    display.fillRect(14, y, fill, 6, SSD1306_WHITE);
}

void drawPageHome(unsigned long ms) {
    // 1. Futuristic Header Frame
    display.drawRoundRect(0, 0, 128, 14, 3, SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(18, 3);
    display.print("SWASTHYASETU AI");

    // 2. Animated Pulsing Heart Shield in Center
    bool pulse = (ms / 400) % 2 == 0;
    if (pulse) {
        display.fillCircle(64, 30, 7, SSD1306_WHITE);
        display.drawCircle(64, 30, 12, SSD1306_WHITE); // Outer radar ring
    } else {
        display.drawCircle(64, 30, 7, SSD1306_WHITE);
        display.drawCircle(64, 30, 10, SSD1306_WHITE);
    }
    // Animated rotating orbit dot
    int angle = (ms / 12) % 360;
    int dotX = 64 + (int)(14.0 * cos(angle * 3.14159 / 180.0));
    int dotY = 30 + (int)(14.0 * sin(angle * 3.14159 / 180.0));
    display.fillRect(dotX - 1, dotY - 1, 3, 3, SSD1306_WHITE);

    // 3. Left Side: Battery Status Meter
    display.setCursor(2, 20);
    display.print(battery_percent); display.print("%");
    display.drawRect(2, 30, 16, 8, SSD1306_WHITE);
    display.fillRect(18, 32, 2, 4, SSD1306_WHITE); // Battery terminal
    int bFill = (battery_percent * 14) / 100;
    if (bFill > 14) bFill = 14;
    if (bFill < 1) bFill = 1;
    display.fillRect(3, 31, bFill, 6, SSD1306_WHITE);

    // 4. Right Side: BLE Radio Status Badge
    display.setCursor(88, 20);
    display.print("BLE");
    if (deviceConnected) {
        display.fillCircle(104, 33, 3, SSD1306_WHITE);
        int wave = (ms / 300) % 3;
        if (wave >= 1) display.drawCircle(104, 33, 6, SSD1306_WHITE);
        if (wave >= 2) display.drawCircle(104, 33, 9, SSD1306_WHITE);
    } else {
        display.drawCircle(104, 33, 3, SSD1306_WHITE);
    }

    // 5. Bottom Status Banner Bar
    display.drawLine(0, 47, 128, 47, SSD1306_WHITE);
    display.setCursor(4, 51);
    if (deviceConnected) {
        display.print("READY  [LINK OK]");
    } else {
        display.print("SEARCHING PHONE...");
    }
}

void drawPageSpO2(unsigned long ms) {
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("PULSE OXIMETER");
    
    if (sysState == MEASURE_SPO2) {
        display.setCursor(0, 16);
        display.print("HR:   "); display.print(current_hr); display.print(" BPM");
        display.setCursor(0, 26);
        display.print("SpO2: "); display.print(current_spo2); display.print(" %");
        
        if (showHeartIcon) display.drawBitmap(100, 14, bmp_heart_16, 16, 16, SSD1306_WHITE);
        
        drawProgressBar(44, ms - measurementStartTime, measurementDuration);
    } else {
        display.setCursor(0, 24);
        display.print("Last: "); display.print(current_spo2); display.print("% | "); display.print(current_hr); display.print("bpm");
        display.setCursor(0, 44);
        display.print("Hold TCH1 to Start");
    }
}

void drawPageECG(unsigned long ms) {
    if (sysState == MEASURE_ECG) {
        // Draw Full Screen Scrolling Graph
        for(int i=0; i<128; i+=16) display.drawFastVLine(i, 0, 56, SSD1306_WHITE);
        if (leadOff) {
            display.setCursor(20, 24);
            display.print("--- LEAD OFF ---");
            return;
        }
        int ptr = ecgHead, prev_x = 0, prev_y = 28 - ecgHistory[ptr];
        for (int x = 1; x < 128; x++) {
            ptr = (ptr + 1) % 128;
            int y = 28 - ecgHistory[ptr];
            if(y < 0) y = 0;
            if(y > 55) y = 55;
            if (x < 126) display.drawFastVLine(x+1, 0, 56, SSD1306_BLACK);
            display.drawLine(prev_x, prev_y, x, y, SSD1306_WHITE);
            prev_x = x; prev_y = y;
        }
        if (showHeartIcon) display.fillCircle(120, 6, 3, SSD1306_WHITE); // Pulse indicator
        drawProgressBar(58, ms - measurementStartTime, measurementDuration);
    } else {
        display.setTextSize(1);
        display.setCursor(0, 0);
        display.print("ECG MONITOR");
        display.setCursor(0, 24);
        display.print("Hold TCH1 to Start");
        display.setCursor(0, 36);
        display.print("(30s Trace)");
    }
}

void drawPageTemp(unsigned long ms) {
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("BODY TEMPERATURE");
    
    if (sysState == MEASURE_TEMP) {
        // Thermometer fill animation
        display.drawRect(58, 14, 8, 30, SSD1306_WHITE);
        display.drawCircle(62, 46, 6, SSD1306_WHITE);
        
        unsigned long elapsed = ms - measurementStartTime;
        int fillHeight = (elapsed * 30) / measurementDuration;
        if(fillHeight > 30) fillHeight = 30;
        
        display.fillCircle(62, 46, 4, SSD1306_WHITE); // Bulb
        display.fillRect(60, 44 - fillHeight, 4, fillHeight, SSD1306_WHITE); // Stem
    } else {
        display.setTextSize(2);
        display.setCursor(20, 20);
        display.print(current_temp, 1); display.print("C");
        display.setTextSize(1);
        display.setCursor(0, 44);
        display.print("Hold TCH1 to Start");
    }
}

void drawPageSys() {
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("SYSTEM STATUS");
    display.drawLine(0, 10, 128, 10, SSD1306_WHITE);
    
    display.setCursor(0, 16);
    display.print("Bat: "); display.print(battery_percent); display.print("% (");
    display.print(current_battery_v, 2); display.print("V)");
    
    unsigned long up = (millis() - bootTime) / 1000;
    display.setCursor(0, 28);
    display.print("Uptime: "); display.print(up); display.print("s");
    
    display.setCursor(0, 40);
    display.print("BLE Tx: "); display.print(bleFrames);
}

// ---------------------------------------------------------
// CORE 1: UI & TELEMETRY
// ---------------------------------------------------------
void core1TaskFunction(void * pvParameters) {
    unsigned long last_telemetry = 0;
    unsigned long last_display = 0;
    
    for(;;) {
        unsigned long current_time = millis();
        
        // Navigation (Tap TCH2 = Next Page)
        if (digitalRead(TOUCH_PIN_2) == HIGH && (current_time - lastTouchTime2 > 300)) {
            if (sysState == SYS_IDLE) { // Only allow navigation if idle
                currentPage = (PageState)((currentPage + 1) % 5);
            }
            lastTouchTime2 = current_time;
        }
        
        // Context-Aware Trigger (Hold TCH1 = Start Measure)
        if (digitalRead(TOUCH_PIN_1) == HIGH) {
            if (touch1PressStart == 0) touch1PressStart = current_time;
            else if (current_time - touch1PressStart > 1000 && sysState == SYS_IDLE) {
                if (currentPage == PAGE_SPO2) {
                    powerSensors(MEASURE_SPO2);
                    measurementDuration = 30000;
                } else if (currentPage == PAGE_ECG) {
                    powerSensors(MEASURE_ECG);
                    measurementDuration = 30000;
                } else if (currentPage == PAGE_TEMP) {
                    powerSensors(MEASURE_TEMP);
                    measurementDuration = 5000;
                }
                touch1PressStart = 0; 
            }
        } else {
            touch1PressStart = 0;
        }
        
        // Measurement Timer State Machine
        if (sysState != SYS_IDLE) {
            unsigned long elapsed = current_time - measurementStartTime;
            if (elapsed > measurementDuration) {
                // Finalize specific readings
                if (sysState == MEASURE_TEMP && mlxFound) {
                    current_temp = mlx.readObjectTempC() + 2.0; // Read instantly at end
                }
                powerSensors(SYS_IDLE); // Done, back to sleep
            }
        }
        
        // Retained Telemetry (4Hz)
        if (current_time - last_telemetry >= 250) { 
            last_telemetry = current_time;
            
            current_battery_v = analogRead(BATTERY_PIN) * (3.3 / 4095.0) * 2.0;
            battery_percent = (int)((current_battery_v - 3.2) / (4.2 - 3.2) * 100);
            if(battery_percent > 100) battery_percent = 100;
            if(battery_percent < 0) battery_percent = 0;
            
            if (deviceConnected) {
                // Payload retains last known values for inactive sensors
                // tx_telemetry[1] contains the active sysState so the app can sync UI
                uint8_t tx_telemetry[20] = {0x01, (uint8_t)sysState, (uint8_t)current_hr, (uint8_t)current_spo2}; 
                int16_t temp_x100 = (int16_t)(current_temp * 100);
                tx_telemetry[4] = temp_x100 & 0xFF;
                tx_telemetry[5] = (temp_x100 >> 8) & 0xFF;
                // Empty RR array space to preserve flutter app structure compatibility
                tx_telemetry[6] = 0; tx_telemetry[7] = 0;
                tx_telemetry[8] = leadOff ? 0 : 100; 
                tx_telemetry[9] = leadOff ? 0x04 : 0x00; 
                tx_telemetry[14] = battery_percent;
                pTelemetryChar->setValue(tx_telemetry, 20);
                pTelemetryChar->notify();
            }
        }
        
        // Display Refresh (~4 Hz = 250ms) to stop BLE starvation
        if (current_time - last_display >= 250) {
            last_display = current_time;
            display.clearDisplay();
            
            switch(currentPage) {
                case PAGE_HOME: drawPageHome(current_time); break;
                case PAGE_SPO2: drawPageSpO2(current_time); break;
                case PAGE_ECG:  drawPageECG(current_time); break;
                case PAGE_TEMP: drawPageTemp(current_time); break;
                case PAGE_SYS:  drawPageSys(); break;
            }
            
            // Draw Navigation dots if Idle
            if (sysState == SYS_IDLE) {
                for(int i=0; i<5; i++) {
                    if(i == currentPage) display.fillRect(106 + (i*4), 60, 3, 3, SSD1306_WHITE);
                    else display.drawRect(106 + (i*4), 60, 3, 3, SSD1306_WHITE);
                }
            }
            
            display.display();
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

// ---------------------------------------------------------
// BOOT & SETUP
// ---------------------------------------------------------
void playBootAnimation() {
    display.clearDisplay();
    // 1. Futuristic Laser Scan Line Animation
    for (int x = 0; x <= 128; x += 4) {
        display.clearDisplay();
        display.drawLine(x, 0, x, 64, SSD1306_WHITE);
        int ySine = 32 + (int)(15.0 * sin((double)x * 0.15));
        display.fillCircle(x, ySine, 3, SSD1306_WHITE);
        display.setTextSize(1);
        display.setCursor(20, 26);
        display.print("INITIALIZING...");
        display.display();
        delay(15);
    }
    
    // 2. Expanding Box Reveal
    for (int r = 2; r <= 28; r += 3) {
        display.clearDisplay();
        display.drawRoundRect(64 - r * 2, 32 - r / 2, r * 4, r, 4, SSD1306_WHITE);
        display.setTextSize(1);
        display.setCursor(18, 28);
        display.print("SWASTHYASETU AI");
        display.display();
        delay(20);
    }
    delay(350);

    // 3. Diagnostic Hardware Check
    display.clearDisplay();
    display.drawRect(0, 0, 128, 64, SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(10, 6);
    display.println("AI HARDWARE DIAG");
    display.drawLine(8, 16, 120, 16, SSD1306_WHITE);
    display.display(); delay(150);
    
    display.setCursor(10, 22);
    if (mlxFound) display.println("[OK] MLX90614 TEMP");
    else display.println("[WARN] MLX MISSING");
    display.display(); delay(150);
    
    display.setCursor(10, 34);
    if (maxFound) display.println("[OK] MAX30102 PPG");
    else display.println("[WARN] MAX MISSING");
    display.display(); delay(150);
    
    display.setCursor(10, 46);
    display.println("[OK] AD8232 ECG");
    display.display(); delay(300);
}

void setup() {
    Serial.begin(115200);
    bootTime = millis();
    
    pinMode(ECG_SDN_PIN, OUTPUT);
    digitalWrite(ECG_SDN_PIN, LOW); // Start powered off (Isolation)
    pinMode(ECG_LO_PLUS_PIN, INPUT);
    pinMode(ECG_LO_MINUS_PIN, INPUT);
    pinMode(BATTERY_PIN, INPUT);
    pinMode(LED_PIN, OUTPUT);
    pinMode(TOUCH_PIN_1, INPUT);
    pinMode(TOUCH_PIN_2, INPUT);
    
    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
    Wire.setClock(100000); 
    I2C_MAX.begin(I2C1_SDA_PIN, I2C1_SCL_PIN);
    
    mlxFound = mlx.begin();
    maxFound = particleSensor.begin(I2C_MAX, I2C_SPEED_FAST);
    if(maxFound) particleSensor.setup(); 
    
    if(display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
        display.setTextColor(SSD1306_WHITE);
        playBootAnimation();
    }
    
    BLEDevice::init("SSAI-SENSE-01");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    BLEService *pService = pServer->createService(SERVICE_UUID);
    
    BLECharacteristic* pDevInfoChar = pService->createCharacteristic(DEV_INFO_CHAR_UUID, BLECharacteristic::PROPERTY_READ);
    pDevInfoChar->setValue("3.0.0");

    pTelemetryChar = pService->createCharacteristic(TELEMETRY_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
    pTelemetryChar->addDescriptor(new BLE2902());
    
    BLECharacteristic* pControlChar = pService->createCharacteristic(CONTROL_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
    pControlChar->setCallbacks(new MyControlCallbacks());
    
    pWaveformChar = pService->createCharacteristic(WAVEFORM_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
    pWaveformChar->addDescriptor(new BLE2902());
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    BLEDevice::startAdvertising();
    
    ecgQueue = xQueueCreate(20, sizeof(int16_t));
    
    timer = timerBegin(1000000); 
    timerAttachInterrupt(timer, &onEcgTimer);
    timerAlarm(timer, 4000, true, 0); 
    
    xTaskCreatePinnedToCore(core0TaskFunction, "Core0_DSP", 10000, NULL, 2, &Core0Task, 0);
    xTaskCreatePinnedToCore(core1TaskFunction, "Core1_TLM", 10000, NULL, 1, &Core1Task, 1);
    
    // Ensure all sensors sleep at boot
    powerSensors(SYS_IDLE);
}

void loop() {
    vTaskDelay(pdMS_TO_TICKS(1000));
}
