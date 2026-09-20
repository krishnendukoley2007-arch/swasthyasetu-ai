/**
 * SSAI_FITNESS_FIRMWARE.ino
 * FitPulse AI — Smart Athletic Wearable Firmware (AICTE PS-26213)
 *
 * Hardware Platform:
 *  - ESP32 DevKit V1
 *  - MPU-6050 (6-Axis Gyroscope & Accelerometer) on I2C (0x68)
 *  - MAX30102 (PPG Pulse Oximeter) on I2C (0x57)
 *  - AD8232 (Single-Lead ECG) on Analog Pin GPIO 34
 *  - SSD1306 0.96" OLED on I2C (0x3C)
 *  - MLX90614 (IR Temperature) on I2C (0x5A)
 */

#include <Arduino.h>
#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// OLED config
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// MPU6050 Motion Sensor
Adafruit_MPU6050 mpu;
bool mpuReady = false;

// AD8232 ECG Pin
#define PIN_ECG_IN 34

// BLE Service & Characteristic UUIDs
#define SERVICE_UUID           "0000ffe0-0000-1000-8000-00805f9b34fb"
#define CHAR_TELEMETRY_UUID    "0000ffe1-0000-1000-8000-00805f9b34fb"
#define CHAR_MOTION_UUID       "0000ffe2-0000-1000-8000-00805f9b34fb"

BLEServer* pServer = nullptr;
BLECharacteristic* pTelemetryChar = nullptr;
BLECharacteristic* pMotionChar = nullptr;
bool deviceConnected = false;

// Packed 20-Byte Vitals Telemetry Frame
#pragma pack(push, 1)
struct telemetry_frame_t {
  uint8_t  frame_type;     // 0x01
  uint8_t  proto_version;  // 0x01
  uint8_t  heart_rate;     // bpm
  uint8_t  spo2;           // percent
  int16_t  temperature;    // deg C * 100
  uint16_t rr_interval;    // ms
  uint8_t  ecg_quality;    // 0..100
  uint8_t  flags;          // bit0: R-peak, bit1: motion, etc.
  uint16_t ptt_ms;         // pulse transit time
  uint8_t  systolic;       // mmHg
  uint8_t  diastolic;      // mmHg
  uint8_t  battery;        // %
  uint8_t  confidence;     // 0..2
  uint32_t uptime_ms;      // ms
};

// Packed 20-Byte Motion Telemetry Frame (MPU6050)
struct motion_frame_t {
  uint8_t  frame_type;     // 0x03
  uint8_t  proto_version;  // 0x01
  int16_t  accel_x;        // G * 100
  int16_t  accel_y;        // G * 100
  int16_t  accel_z;        // G * 100
  int16_t  gyro_x;         // deg/s * 10
  int16_t  gyro_y;         // deg/s * 10
  int16_t  gyro_z;         // deg/s * 10
  uint16_t rep_count;      // on-device counted reps
  uint8_t  cadence_spm;    // steps per minute
  uint8_t  intensity;      // 0..100 %
  uint16_t step_count;     // steps
};
#pragma pack(pop)

static_assert(sizeof(telemetry_frame_t) == 20, "Telemetry frame must be 20 bytes");
static_assert(sizeof(motion_frame_t) == 20, "Motion frame must be 20 bytes");

// On-device Rep Counting State
uint16_t g_reps = 0;
uint16_t g_steps = 0;
bool g_isDescending = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    BLEDevice::startAdvertising();
  }
};

void initOLED() {
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("SSD1306 allocation failed");
  } else {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(15, 20);
    display.println("FITPULSE AI");
    display.setCursor(10, 35);
    display.println("Athletic Sensor Hub");
    display.display();
  }
}

void initMPU6050() {
  if (!mpu.begin(0x68, &Wire)) {
    Serial.println("MPU-6050 not detected at 0x68");
    mpuReady = false;
  } else {
    Serial.println("MPU-6050 6-Axis Motion Sensor Initialized");
    mpu.setAccelerometerRange(MPU6050_RANGE_4_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    mpuReady = true;
  }
}

void initBLE() {
  BLEDevice::init("FITPULSE-AI");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pTelemetryChar = pService->createCharacteristic(
    CHAR_TELEMETRY_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pTelemetryChar->addDescriptor(new BLE2902());

  pMotionChar = pService->createCharacteristic(
    CHAR_MOTION_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pMotionChar->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22, 400000); // Fast I2C 400kHz

  pinMode(PIN_ECG_IN, INPUT);

  initOLED();
  initMPU6050();
  initBLE();
}

unsigned long lastTelemetryTime = 0;
unsigned long lastMotionTime = 0;
uint8_t mockHr = 110;

void loop() {
  unsigned long now = millis();

  // 1. High-frequency Motion Reading & Telemetry (20 Hz = 50ms)
  if (now - lastMotionTime >= 50) {
    lastMotionTime = now;

    sensors_event_t a, g, temp;
    int16_t ax = 0, ay = 0, az = 100;
    int16_t gx = 0, gy = 0, gz = 0;

    if (mpuReady) {
      mpu.getEvent(&a, &g, &temp);
      // Convert m/s^2 to G (1 G ~= 9.80665 m/s^2) scaled by 100
      ax = (int16_t)((a.acceleration.x / 9.80665f) * 100);
      ay = (int16_t)((a.acceleration.y / 9.80665f) * 100);
      az = (int16_t)((a.acceleration.z / 9.80665f) * 100);

      // Convert rad/s to deg/s scaled by 10
      gx = (int16_t)((g.gyro.x * 57.2958f) * 10);
      gy = (int16_t)((g.gyro.y * 57.2958f) * 10);
      gz = (int16_t)((g.gyro.z * 57.2958f) * 10);

      // On-chip simple rep detection
      if (!g_isDescending && az > 130) {
        g_isDescending = true;
      } else if (g_isDescending && az < 95) {
        g_isDescending = false;
        g_reps++;
      }
    }

    motion_frame_t mFrame;
    mFrame.frame_type = 0x03;
    mFrame.proto_version = 0x01;
    mFrame.accel_x = ax;
    mFrame.accel_y = ay;
    mFrame.accel_z = az;
    mFrame.gyro_x = gx;
    mFrame.gyro_y = gy;
    mFrame.gyro_z = gz;
    mFrame.rep_count = g_reps;
    mFrame.cadence_spm = 24;
    mFrame.intensity = 80;
    mFrame.step_count = g_steps;

    if (deviceConnected && pMotionChar) {
      pMotionChar->setValue((uint8_t*)&mFrame, sizeof(mFrame));
      pMotionChar->notify();
    }
  }

  // 2. Vitals Telemetry Broadcast & OLED Refresh (2 Hz = 500ms)
  if (now - lastTelemetryTime >= 500) {
    lastTelemetryTime = now;

    // Simulate exertion modulation
    mockHr = 110 + (uint8_t)(15 * sin(now / 10000.0));

    telemetry_frame_t vFrame;
    vFrame.frame_type = 0x01;
    vFrame.proto_version = 0x01;
    vFrame.heart_rate = mockHr;
    vFrame.spo2 = 98;
    vFrame.temperature = 3680; // 36.80 C
    vFrame.rr_interval = 60000 / mockHr;
    vFrame.ecg_quality = 95;
    vFrame.flags = 0x01;
    vFrame.ptt_ms = 220;
    vFrame.systolic = 120;
    vFrame.diastolic = 78;
    vFrame.battery = 94;
    vFrame.confidence = 2;
    vFrame.uptime_ms = now;

    if (deviceConnected && pTelemetryChar) {
      pTelemetryChar->setValue((uint8_t*)&vFrame, sizeof(vFrame));
      pTelemetryChar->notify();
    }

    // Refresh OLED
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("FITPULSE AI  ");
    display.print(deviceConnected ? "[BLE ON]" : "[ADV...]");

    display.setTextSize(2);
    display.setCursor(0, 18);
    display.print(mockHr);
    display.setTextSize(1);
    display.print(" BPM   ");
    display.setTextSize(2);
    display.print(g_reps);
    display.setTextSize(1);
    display.print(" REPS");

    display.setCursor(0, 48);
    display.print("MPU6050: ");
    display.print(mpuReady ? "LIVE 6-AXIS" : "OFFLINE");
    display.display();
  }
}
