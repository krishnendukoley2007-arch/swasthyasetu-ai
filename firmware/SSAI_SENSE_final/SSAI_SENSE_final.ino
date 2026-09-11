/**
 * SwasthyaSetu AI - ESP32 Firmware (v3.0.0)
 *
 * Features:
 * - Strictly Mutually Exclusive Sensor Isolation
 * - 5-Page Animated UI (Home, SpO2, ECG, Temp, Sys)
 * - Dynamic Live MAX30102 Processing on Core 0
 * - Real-time Telemetry payload management
 *
 * UI/animation changelog (see "SHARED PER-PAGE ANIMATION STATE" below):
 * - Home page: outer radar ring now breathes continuously (sin-based),
 *   not just a two-frame toggle.
 * - Per-measurement "start" sting (~400ms expanding ring + label) on
 *   SpO2/ECG/Temp when a hold-to-start or BLE command begins a reading.
 * - "Reading saved" checkmark celebration (~600ms) when a measurement
 *   finalizes, before the page falls back to its idle summary view.
 * - Low-battery pulsing badge overlay (<15%), drawn on whichever page
 *   is active; purely visual, never touches sysState/powerSensors().
 * - BLE connect/disconnect flash ("BLE LINKED"/"BLE LOST"), shown on
 *   whichever page is active, not just Home.
 * - ECG lead-off view is now an animated "REATTACH ELECTRODE" prompt
 *   instead of static text.
 * - Optional: holding either touch pad during boot skips the intro
 *   (BOOT_SKIP_CHECK()) straight to the home screen.
 * No changes to DSP (dsp_pure.h/spo2_algorithm.h), BLE telemetry/
 * waveform byte layout, PROTOCOL_VERSION, battery voltage calibration,
 * BLE MTU/PHY, or OTA code — all untouched per spec.
 */
#include "dsp_pure.h"       // hardware-free DSP (shared with native unit tests)
#include "spo2_algorithm.h" // Maxim reference SpO2/HR algorithm (SparkFun lib)
#include <Adafruit_GFX.h>
#include <Adafruit_MLX90614.h>
#include <Adafruit_SSD1306.h>
#include <Arduino.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLESecurity.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <MAX30105.h>
#include <Wire.h>
#include <esp_adc_cal.h>
#include <esp_gap_ble_api.h>
#include <esp_task_wdt.h>
#include <math.h>
#include <string.h> // memset (native-safe; also in dsp via test)

// Uncomment + set credentials to enable WiFi OTA firmware updates
// (e.g. for clinic fleet maintenance). Off by default: BLE-only builds
// don't power the WiFi radio at all.
// #define ENABLE_CLINIC_OTA
#ifdef ENABLE_CLINIC_OTA
#include <ArduinoOTA.h>
#include <WiFi.h>
#define OTA_WIFI_SSID "clinic-iot"
#define OTA_WIFI_PASS "change-me"
#endif

// BLE telemetry protocol version the Flutter app parses at byte 1.
#define PROTOCOL_VERSION 1

// Boot animation is ON by default now — a ~2.5 s branded intro on every
// power-up (mascot blink + Band-Aid cross reveal + hardware self-test).
// Comment this out only if you need the absolute fastest boot-to-ready
// time in the field and are fine skipping the intro.
#define DEMO_BOOT

// ---------------------------------------------------------
// CROSS-CORE SHARED STATE — RACE TRANSPARENCY NOTE
// ---------------------------------------------------------
// current_hr, current_spo2, ecgHistory, ecgHead, leadOff, currentECG and
// last_rr_ms are written on Core 0 (sensor DSP) and read on Core 1
// (UI / BLE telemetry) with no lock. This is SAFE on ESP32 only because:
//   * every shared scalar is a naturally-aligned word-sized (<=32-bit)
//     type, so loads/stores are single-instruction and atomic;
//   * ecgHistory is a byte array written by one producer (Core 0) and
//     read by one consumer (Core 1) with a monotonic head index — the
//     worst case is one torn-vs-stale pixel column, never corruption.
// DO NOT widen any of these to 64-bit / multi-word structs or add a
// second writer without either protecting with timerMux or switching to
// a queue/critical section — the invariant above is load-bearing.
//
// IMPORTANT: the atomicity argument above only holds if the compiler is
// actually forced to re-read/re-write these on every access instead of
// caching a stale value in a register across loop iterations or inlined
// calls. That requires `volatile` on every variable in this set, on
// `deviceConnected` (written from the BLE stack's own task context —
// a THIRD execution context beyond Core 0 / Core 1), and on
// `showHeartIcon` / `bleFrames` (Core-0-written, Core-1-read). All are
// declared volatile below; do not remove volatile from any of them.
// ---------------------------------------------------------

// ---------------------------------------------------------
// HARDWARE PINS
// ---------------------------------------------------------
#define I2C_SDA_PIN 21
#define I2C_SCL_PIN 22
#define I2C1_SDA_PIN 26
#define I2C1_SCL_PIN 27
#define ECG_ANALOG_PIN 36
#define ECG_LO_PLUS_PIN 39
#define ECG_LO_MINUS_PIN 34
#define ECG_SDN_PIN 18
#define TOUCH_PIN_1 4  // HOLD = Start Measure
#define TOUCH_PIN_2 14 // TAP = Next Page
#define LED_PIN 2
#define BATTERY_PIN 35
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define OLED_ADDR 0x3C

// BLE UUIDs
#define SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define DEV_INFO_CHAR_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define TELEMETRY_CHAR_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
#define WAVEFORM_CHAR_UUID "6e400004-b5a3-f393-e0a9-e50e24dcca9e"
#define CONTROL_CHAR_UUID "6e400005-b5a3-f393-e0a9-e50e24dcca9e"

// ---------------------------------------------------------
// BITMAPS & ANIMATIONS
// ---------------------------------------------------------
const unsigned char bmp_heart_16[] PROGMEM = {
    0x00, 0x00, 0x1c, 0x38, 0x3e, 0x7c, 0x7f, 0xfe, 0x7f, 0xfe, 0x7f,
    0xfe, 0x7f, 0xfe, 0x3f, 0xfc, 0x1f, 0xf8, 0x0f, 0xf0, 0x07, 0xe0,
    0x03, 0xc0, 0x01, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
// 16x16 Mascot
const unsigned char bmp_mascot_open[] PROGMEM = {
    0x03, 0xc0, 0x0f, 0xf0, 0x1c, 0x38, 0x30, 0x0c, 0x23, 0xc4, 0x63,
    0xc6, 0x40, 0x02, 0x40, 0x02, 0x44, 0x22, 0x48, 0x12, 0x50, 0x0a,
    0x20, 0x04, 0x30, 0x0c, 0x1c, 0x38, 0x0f, 0xf0, 0x03, 0xc0};
const unsigned char bmp_mascot_blink[] PROGMEM = {
    0x03, 0xc0, 0x0f, 0xf0, 0x1c, 0x38, 0x30, 0x0c, 0x20, 0x04, 0x63,
    0xc6, 0x40, 0x02, 0x40, 0x02, 0x44, 0x22, 0x48, 0x12, 0x50, 0x0a,
    0x20, 0x04, 0x30, 0x0c, 0x1c, 0x38, 0x0f, 0xf0, 0x03, 0xc0};

// ---------------------------------------------------------
// ARCHITECTURE ENUMS & STATE
// ---------------------------------------------------------
enum PageState { PAGE_HOME = 0, PAGE_SPO2, PAGE_ECG, PAGE_TEMP, PAGE_SYS };
volatile PageState currentPage = PAGE_HOME;

enum SystemState { SYS_IDLE = 0, MEASURE_SPO2, MEASURE_ECG, MEASURE_TEMP };
volatile SystemState sysState = SYS_IDLE;
unsigned long measurementStartTime = 0;
unsigned long measurementDuration = 0; // 0 = Continuous/Infinite streaming

TwoWire I2C_MAX(1);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
MAX30105 particleSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();

BLEServer *pServer = NULL;
BLECharacteristic *pTelemetryChar = NULL;
BLECharacteristic *pWaveformChar = NULL;
volatile bool deviceConnected = false;

QueueHandle_t ecgQueue;
hw_timer_t *timer = NULL;
portMUX_TYPE timerMux = portMUX_INITIALIZER_UNLOCKED;

TaskHandle_t Core0Task;
TaskHandle_t Core1Task;

bool mlxFound = false;
bool maxFound = false;
volatile int16_t currentECG = 0;
volatile bool leadOff = false;
volatile uint8_t leadOffDebounceCount = 0;
volatile bool fingerPresent = false;
volatile bool ecgBaselineSeeded = false;

// Shared Vitals (Retained across mode switches)
volatile uint16_t ecg_hr = 0, spo2_hr = 0, current_hr = 0;
volatile uint16_t last_rr_ms =
    0; // last R-R interval in ms (sent in telemetry bytes 6-7)
volatile uint16_t current_spo2 = 0;
float current_temp = 0.0;
float current_battery_v = 0;
int battery_percent = 0;
// Running (EMA-smoothed) battery voltage. -1 means "not seeded yet" —
// the very first reading initializes it directly instead of blending
// with a bogus 0V starting point.
float battery_v_smoothed = -1.0f;

// Written on Core 0 (processSpO2AndHR / BLE waveform packer), read on
// Core 1 (drawPageSpO2 / drawPageECG / drawPageSys). Same single-writer,
// word-sized rule as the block above.
volatile bool showHeartIcon = false;
volatile unsigned int bleFrames = 0;

// Diagnostics: incremented from the ISR whenever the ECG sample queue is
// full and a sample has to be dropped. Declared up here (rather than down
// by the PPG buffers) so it's visible to onEcgTimer() below without a
// forward declaration. Surfaced on the SYS page so a stalled Core 0
// consumer or an oversubscribed link is visible instead of silently
// degrading the waveform with no cause shown anywhere.
volatile unsigned long ecgQueueDropCount = 0;

// ADC calibration: the bare (3.3/4095)*2 formula reads ~0.2 V low on typical
// boards because the ADC reference and divider are both nominal. esp_adc_cal
// removes the silicon part; BATTERY_CORRECTION_V removes the board part —
// measure once against a multimeter and set it here.
esp_adc_cal_characteristics_t adcChars;
#define BATTERY_CORRECTION_V 0.20f // adjust after first multimeter check
#define BATTERY_DIVIDER 2.0f       // R_top == R_bottom divider

/// eFuse-calibrated battery read: 8-sample average against the calibrated
/// ADC, divider reversed, then the board correction applied. Returns volts.
/// Samples are spaced ~1 ms apart (instead of back-to-back) since the
/// ESP32 ADC is noisiest when hammered with zero settling time between
/// reads on a high-impedance divider source.
float readBatteryVoltage() {
  uint32_t raw = 0;
  for (int i = 0; i < 8; i++) {
    raw += analogRead(BATTERY_PIN);
    delayMicroseconds(1000);
  }
  raw /= 8;
  float v = esp_adc_cal_raw_to_voltage(raw, &adcChars) / 1000.0f; // mV -> V
  return v * BATTERY_DIVIDER + BATTERY_CORRECTION_V;
}

// ECG DSP state moved to dsp_pure.h (shared with unit tests).
int8_t ecgHistory[128] = {0};
volatile uint8_t ecgHead = 0;

// SpO2 DSP
long ir_avg = 0;
unsigned long last_spo2_beat = 0;

// UI State
unsigned long bootTime = 0;
unsigned long lastTouchTime2 = 0;
unsigned long touch1PressStart = 0;

// Non-blocking median-of-5 temperature sampling state (Core 1 only —
// see the note in core1TaskFunction()'s measurement-timer block for why
// this deliberately isn't moved to Core 0).
float tempSamples[5];
uint8_t tempSampleCount = 0;
unsigned long tempLastSampleTime = 0;

// Forward decls: both are defined near playBootAnimation() further down,
// but the shared per-page animation helpers below reuse them rather than
// duplicating an easing curve / tick glyph.
float easeOutCubic(float t);
void drawBootCheck(int x, int y);

// ---------------------------------------------------------
// SHARED PER-PAGE ANIMATION STATE
// ---------------------------------------------------------
// These are UI-only timestamps/flags read and written exclusively on
// Core 1 (the display/telemetry task), except where noted. They follow
// the same "single word, single effective writer" rule as the sensor
// state above, so no locking is needed. Kept here as plain globals —
// intentionally NOT split into a State.h, per the single-.ino decision.
#define ANIM_STING_MS 400    // "measurement started" sting duration
#define ANIM_COMPLETE_MS 600 // "reading finalized" celebration duration
#define ANIM_BLE_MS 500      // BLE connect/disconnect flash duration
#define LOW_BATTERY_PCT 15 // battery_percent threshold for the warning overlay

// While a "burst" is active, core1TaskFunction() redraws at ~20 Hz instead
// of the normal 4 Hz so short animations (the sting, the completion pop)
// actually get enough frames to read as motion instead of a single jump
// cut. Outside a burst window the display stays at the original 4 Hz
// budget so BLE telemetry is never starved.
#define ANIM_BURST_FPS_MS 50
unsigned long animBurstUntil =
    0; // millis() timestamp; redraw fast until this time

unsigned long measurementStartAnimTime =
    0; // set by powerSensors() when a measurement begins
unsigned long measurementCompleteAnimTime =
    0; // set when a measurement finalizes
PageState measurementCompletePage =
    PAGE_HOME; // which page's reading just finalized (PAGE_HOME = none yet)

bool lastDeviceConnectedSeen =
    false; // Core-1-local copy, used only to detect edges
unsigned long bleStateChangeAnimTime = 0;
bool bleStateChangeWasConnect = false;

// ---------------------------------------------------------
// STATUS LED (single on-board LED, LED_PIN) — priority order:
//   1) During an active measurement (SpO2/ECG), the LED pulses in sync
//      with each detected heartbeat (mirrors showHeartIcon exactly) —
//      a literal, glanceable heartbeat indicator with no need to look
//      at the screen.
//   2) Otherwise, a short blink pattern plays once right after a BLE
//      connect/disconnect edge — 2 quick blinks for "connected", 4 for
//      "disconnected", so the two are distinguishable without the OLED.
//   3) Otherwise the LED stays off (idle -> saves power on a wearable).
// Driven from timestamps checked every core1TaskFunction() loop pass —
// no delay()s here, so it can never stall the display or BLE telemetry.
// ---------------------------------------------------------
#define LED_BLE_BLINK_ON_MS 120
#define LED_BLE_BLINK_OFF_MS 120
unsigned long ledBleBlinkStartTime = 0;
int ledBleBlinkPulsesLeft =
    0; // 0 = no pattern playing; set to 2 (connect) or 4 (disconnect)

// Called once per core1TaskFunction() loop iteration.
void updateStatusLed(unsigned long ms) {
  if (sysState == MEASURE_SPO2 || sysState == MEASURE_ECG) {
    digitalWrite(LED_PIN, showHeartIcon ? HIGH : LOW);
    return;
  }
  if (ledBleBlinkPulsesLeft > 0) {
    unsigned long elapsed = ms - ledBleBlinkStartTime;
    const unsigned long cycleMs = LED_BLE_BLINK_ON_MS + LED_BLE_BLINK_OFF_MS;
    unsigned long totalMs = (unsigned long)ledBleBlinkPulsesLeft * cycleMs;
    if (elapsed >= totalMs) {
      ledBleBlinkPulsesLeft = 0;
      digitalWrite(LED_PIN, LOW);
      return;
    }
    digitalWrite(LED_PIN,
                 (elapsed % cycleMs) < LED_BLE_BLINK_ON_MS ? HIGH : LOW);
    return;
  }
  digitalWrite(LED_PIN, LOW);
}

// Smooth 0..1 "breathing" value from a sine wave with the given period (ms).
// Shared by the home-page idle ring, the low-battery pulse and the
// lead-off prompt so they all read as the same animation language.
float breathe01(unsigned long ms, unsigned long periodMs) {
  return (sinf(2.0f * PI * (float)(ms % periodMs) / (float)periodMs) + 1.0f) *
         0.5f;
}

// True while a touch pad is held — used only to let the boot animation
// be skipped early; the debounced press-and-hold logic for normal
// operation still lives in core1TaskFunction() and is untouched.
inline bool bootSkipRequested() {
  return digitalRead(TOUCH_PIN_1) == HIGH || digitalRead(TOUCH_PIN_2) == HIGH;
}

// Small radial "powering on" sting shown for ANIM_STING_MS right after a
// measurement starts — an expanding ring + the mode label, distinct from
// a plain page navigation.
void drawStartSting(unsigned long ms, const char *label) {
  float t = (float)(ms - measurementStartAnimTime) / (float)ANIM_STING_MS;
  if (t > 1.0f)
    t = 1.0f;
  int r = 4 + (int)(easeOutCubic(t) * 32);
  display.drawCircle(64, 30, r, SSD1306_WHITE);
  if (r > 4)
    display.drawCircle(64, 30, r - 4, SSD1306_WHITE);
  display.setTextSize(1);
  int16_t bx, by;
  uint16_t bw, bh;
  display.getTextBounds(label, 0, 0, &bx, &by, &bw, &bh);
  display.setCursor(64 - bw / 2, 27);
  display.print(label);
}

// True while a "reading finalized" celebration should be shown instead
// of (or on top of) a page's normal idle/summary view.
bool justCompleted(PageState page, unsigned long ms) {
  return measurementCompletePage == page &&
         (ms - measurementCompleteAnimTime) < ANIM_COMPLETE_MS;
}

// Quick checkmark + pop-ring flash, reusing drawBootCheck() so the tick
// glyph matches the one used in the boot diagnostic checklist.
void drawCompleteCelebration(unsigned long ms) {
  float t = (float)(ms - measurementCompleteAnimTime) / (float)ANIM_COMPLETE_MS;
  if (t > 1.0f)
    t = 1.0f;
  float pop = 1.0f - fabsf(t - 0.3f) * 1.6f;
  if (pop < 0.35f)
    pop = 0.35f;
  int r = (int)(11 * pop);
  display.drawCircle(64, 26, r, SSD1306_WHITE);
  drawBootCheck(60, 21);
  display.setTextSize(1);
  display.setCursor(28, 44);
  display.print("READING SAVED");
}

// Pulsing "reattach electrode" prompt for the ECG page's leads-off
// state — replaces the old static text so it reads as alive, not frozen.
void drawLeadOffPrompt(unsigned long ms) {
  float p = breathe01(ms, 900);
  int r = 6 + (int)(p * 5);
  display.drawCircle(64, 22, r, SSD1306_WHITE);
  display.drawLine(61, 22 - r - 5, 61, 22 - r + 2, SSD1306_WHITE);
  display.drawLine(67, 22 - r - 5, 67, 22 - r + 2, SSD1306_WHITE);
  display.setTextSize(1);
  const char *msg = "REATTACH ELECTRODE";
  int16_t bx, by;
  uint16_t bw, bh;
  display.getTextBounds(msg, 0, 0, &bx, &by, &bw, &bh);
  display.setCursor(64 - bw / 2, 44);
  display.print(msg);
}

// Small pulsing warning badge, top-right corner, drawn on top of
// whichever page is active once battery_percent drops below
// LOW_BATTERY_PCT. Purely a display overlay — never touches sysState
// or powerSensors(), so it can never interrupt a running measurement.
void drawLowBatteryOverlay(unsigned long ms) {
  if (battery_percent >= LOW_BATTERY_PCT)
    return;
  if (breathe01(ms, 1000) < 0.5f)
    return; // blink: visible ~half the cycle
  display.drawRect(112, 1, 14, 7, SSD1306_WHITE);
  display.fillRect(126, 3, 2, 3, SSD1306_WHITE); // terminal nub
  display.fillRect(113, 2, 3, 5, SSD1306_WHITE); // low fill = warning look
}

// Brief "LINKED"/"LOST" flash the instant BLE connection state changes,
// shown on whichever page is currently on screen (Home already has its
// own persistent badge, so this is most useful away from Home).
void drawBleStateChangeOverlay(unsigned long ms) {
  if (ms - bleStateChangeAnimTime >= ANIM_BLE_MS)
    return;
  if ((((ms - bleStateChangeAnimTime) / 90) % 2) != 0)
    return; // quick flicker
  const char *msg = bleStateChangeWasConnect ? "BLE LINKED" : "BLE LOST";
  display.setTextSize(1);
  int16_t bx, by;
  uint16_t bw, bh;
  display.getTextBounds(msg, 0, 0, &bx, &by, &bw, &bh);
  int x = 64 - bw / 2, y = 55;
  display.fillRect(x - 3, y - 2, bw + 6, 10, SSD1306_BLACK);
  display.drawRect(x - 3, y - 2, bw + 6, 10, SSD1306_WHITE);
  display.setCursor(x, y);
  display.print(msg);
}

// ---------------------------------------------------------
// BLE CALLBACKS
// ---------------------------------------------------------
void powerSensors(SystemState targetMode);
void resetPpgDsp();
void resetEcgWaveformPacker(); // forward decl: defined near core0TaskFunction,
                               // used by powerSensors() below
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
    BLEDevice::startAdvertising();
  }
};

class MyControlCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    // Read into a fixed stack buffer instead of Arduino String: this
    // callback fires from the BLE stack's own task for the lifetime
    // of the device, and String's heap alloc/free on every write is
    // a slow, avoidable source of heap fragmentation on a long-running
    // field unit.
    // Protocol specification:
    //   data[0] = Command (0x01=SpO2, 0x02=ECG, 0x03=Temp, 0x00=Idle/Stop)
    //   data[1..2] (optional uint16 LE) = Duration in seconds:
    //              0 = Continuous / Infinite Streaming
    //              30 = 30 seconds (default)
    //              120 = 2 minutes
    //              300 = 5 minutes
    uint8_t *data = pCharacteristic->getData();
    size_t len = pCharacteristic->getLength();
    if (len == 0 || data == nullptr)
      return;
    uint8_t cmd = data[0];
    uint32_t targetDurationMs = 30000; // default for 1-byte legacy commands
    if (len >= 3) {
      uint16_t durSec = (uint16_t)data[1] | ((uint16_t)data[2] << 8);
      targetDurationMs = (uint32_t)durSec * 1000UL; // 0 = Infinite/Continuous!
    } else if (len == 2) {
      targetDurationMs = (uint32_t)data[1] * 1000UL;
    }

    if (cmd == 0x01) {
      currentPage = PAGE_SPO2;
      powerSensors(MEASURE_SPO2);
      measurementDuration = (len >= 2) ? targetDurationMs : 30000;
    } else if (cmd == 0x02) {
      currentPage = PAGE_ECG;
      powerSensors(MEASURE_ECG);
      measurementDuration = (len >= 2) ? targetDurationMs : 30000;
    } else if (cmd == 0x03) {
      currentPage = PAGE_TEMP;
      powerSensors(MEASURE_TEMP);
      measurementDuration = (len >= 2) ? targetDurationMs : 5000;
    } else if (cmd == 0x00) {
      currentPage = PAGE_HOME;
      powerSensors(SYS_IDLE);
      measurementDuration = 0;
    }
  }
};

// ---------------------------------------------------------
// MUTUALLY EXCLUSIVE POWER MANAGEMENT
// ---------------------------------------------------------
void powerSensors(SystemState targetMode) {
  if (targetMode == MEASURE_ECG) {
    digitalWrite(ECG_SDN_PIN, HIGH); // AD8232 ON
    if (maxFound)
      particleSensor.shutDown(); // MAX OFF
    resetEcgDsp();               // Fresh filters/threshold per session
    leadOffDebounceCount = 0;
    leadOff = false;
    ecgBaselineSeeded = false;
    // Drop any stale samples left in the queue from the tail end of a
    // previous ECG session (e.g. a session stopped mid-frame) so the
    // new session's trace never opens with old data.
    xQueueReset(ecgQueue);
    // Also reset the BLE waveform packer's partial-frame byte count —
    // it's a task-lifetime local in core0TaskFunction(), so without
    // this a session that ended mid-frame would splice its leftover
    // bytes onto the start of the next session's first BLE frame.
    resetEcgWaveformPacker();
  } else if (targetMode == MEASURE_SPO2) {
    digitalWrite(ECG_SDN_PIN, LOW); // AD8232 OFF
    if (maxFound)
      particleSensor.wakeUp();  // MAX ON
    particleSensor.clearFIFO(); // Reset stale data
    resetPpgDsp();              // Drop stale finger-off window
  } else if (targetMode == MEASURE_TEMP) {
    digitalWrite(ECG_SDN_PIN, LOW); // AD8232 OFF
    if (maxFound)
      particleSensor.shutDown(); // MAX OFF
    // Fresh median-of-5 window for this session.
    tempSampleCount = 0;
    tempLastSampleTime = millis();
  } else {
    // SYS_IDLE
    digitalWrite(ECG_SDN_PIN, LOW);
    if (maxFound)
      particleSensor.shutDown();
  }
  sysState = targetMode;
  measurementStartTime = millis();
  if (targetMode != SYS_IDLE) {
    measurementStartAnimTime =
        measurementStartTime; // triggers the brief "powering on" sting
    // Kick off a short fast-redraw burst so the sting/celebration
    // animations actually get enough frames at ANIM_BURST_FPS_MS to
    // read as motion, not a single jump cut, without permanently
    // raising the display refresh rate (which would starve BLE).
    animBurstUntil = measurementStartTime + ANIM_STING_MS + 50;
  }
}

// ---------------------------------------------------------
// HARDWARE TIMER (ECG SAMPLING)
// ---------------------------------------------------------
#define ECG_LEAD_OFF_THRESHOLD 25 // 25 samples @ 250Hz = 100ms sustained high

void IRAM_ATTR onEcgTimer() {
  BaseType_t xHigherPriorityTaskWoken = pdFALSE;
  portENTER_CRITICAL_ISR(&timerMux);
  if (sysState == MEASURE_ECG) {
    // Debounce LO+/LO- with hysteresis so single-sample noise spikes or
    // momentary skin contact impedance shifts don't cause rapid leads-off
    // flickering.
    bool rawLo = (digitalRead(ECG_LO_PLUS_PIN) != 0) ||
                 (digitalRead(ECG_LO_MINUS_PIN) != 0);
    if (rawLo) {
      if (leadOffDebounceCount < ECG_LEAD_OFF_THRESHOLD + 5) {
        leadOffDebounceCount++;
      }
      if (leadOffDebounceCount >= ECG_LEAD_OFF_THRESHOLD) {
        leadOff = true;
        currentECG = 0;
      }
    } else {
      if (leadOffDebounceCount > 0) {
        leadOffDebounceCount--;
      }
      if (leadOffDebounceCount == 0) {
        leadOff = false;
      }
    }

    if (!leadOff) {
      currentECG = analogRead(ECG_ANALOG_PIN);
    }
  }
  portEXIT_CRITICAL_ISR(&timerMux);
  // Queue send outside the critical section; yield immediately if a
  // higher-priority task (the Core 0 consumer) was woken so the 250 Hz
  // sample stream doesn't overrun the queue between ISRs.
  if (sysState == MEASURE_ECG) {
    int16_t sample = currentECG;
    if (xQueueSendFromISR(ecgQueue, (void *)&sample,
                          &xHigherPriorityTaskWoken) != pdTRUE) {
      // Queue is full (Core 0 is stalled/behind) — count the drop
      // instead of silently losing the sample with no visibility.
      ecgQueueDropCount++;
    }
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
  }
}

// ---------------------------------------------------------
// DSP LOGIC — lives in dsp_pure.h (ecgConditioningApply,
// processECG_BaselineRemoval, detectRPeak, resetEcgDsp,
// medianOf5, batteryPercentFromVoltage) so the native test
// env can exercise the exact same code as the firmware.
// ---------------------------------------------------------

#define PPG_BUFFER_SIZE 100 // 4 s at the 25 sps effective rate
uint32_t redBuffer[PPG_BUFFER_SIZE] = {0};
uint32_t irBuffer[PPG_BUFFER_SIZE] = {0};
uint8_t ppgHead = 0;
uint8_t ppgSamples = 0; // how many slots hold real data

#define FINGER_THRESHOLD 25000 // IR count threshold for finger presence
uint8_t fingerOffCounter = 0;
float smoothed_hr = 0.0f;
float smoothed_spo2 = 0.0f;

// ---- Accuracy upgrades ----------------------------------------------
// 1) Warm-up discard: the first PPG_WARMUP_READS Maxim outputs run on
//    data contaminated by finger-insertion transients (contact pressure
//    settling, blood re-perfusion). Previously the EMA seeded from that
//    first (garbage) estimate and the slew-rate limiter made it crawl
//    to the truth — the classic "140 -> 130 -> 90 -> settle" staircase.
//    Those early outputs are now still computed (icon/UX works) but
//    never enter the smoothed value or the result history.
// 2) Perfusion-Index (PI) gate: windows whose IR AC/DC ratio is below
//    PI_MIN_PERCENT carry almost no pulsatile information (hard finger
//    press, cold fingers, ambient light) — their Maxim output is
//    rejected so a bad window can't move the displayed value.
// 3) Stability lock: 3 consecutive accepted readings within +/-2 SpO2
//    points unlock a "stabilized" flag shown on the OLED and surfaced
//    to the dashboard over BLE (flags bit 0x10).
// 4) Median-of-last-5 final result: instead of reporting whatever the
//    EMA happens to be at t=30s, the final saved value is the median of
//    the last 5 accepted windows — outlier windows (motion spikes)
//    can't sway the stored result the way a mean would.
#define PPG_WARMUP_READS 3  // ~3 s of buffer-fresh windows after fill
#define PPG_HISTORY_LEN 5
#define PI_MIN_PERCENT 0.10f // AC/DC < 0.1% = useless pulsatile signal
uint8_t ppgAlgoCount = 0;    // Maxim calls since measurement start
bool ppgLowSignal = false;   // last window failed the PI gate
int32_t spo2Hist[PPG_HISTORY_LEN];
uint8_t nSpo2Hist = 0, spo2HistIdx = 0;
int32_t hrHist[PPG_HISTORY_LEN];
uint8_t nHrHist = 0, hrHistIdx = 0;
int32_t prevSpo2 = 0, prevHr = 0;
uint8_t stableRun = 0;
bool spo2Locked = false;

static int32_t medianOfI32(const int32_t *vals, uint8_t n) {
  int32_t tmp[PPG_HISTORY_LEN];
  memcpy(tmp, vals, n * sizeof(int32_t));
  for (uint8_t i = 1; i < n; i++) {
    int32_t key = tmp[i];
    int8_t j = (int8_t)i - 1;
    while (j >= 0 && tmp[j] > key) {
      tmp[j + 1] = tmp[j];
      j--;
    }
    tmp[j + 1] = key;
  }
  return tmp[n / 2];
}

// Reset the PPG pipeline — called on every SpO2 measurement start so a
// stale finger-off window can't contaminate the new reading.
void resetPpgDsp() {
  memset(redBuffer, 0, sizeof(redBuffer));
  memset(irBuffer, 0, sizeof(irBuffer));
  ppgHead = 0;
  ppgSamples = 0;
  ir_avg = 0;
  last_spo2_beat = 0;
  fingerPresent = false;
  fingerOffCounter = 0;
  smoothed_hr = 0.0f;
  smoothed_spo2 = 0.0f;
  ppgAlgoCount = 0;
  ppgLowSignal = false;
  nSpo2Hist = 0;
  spo2HistIdx = 0;
  nHrHist = 0;
  hrHistIdx = 0;
  prevSpo2 = 0;
  prevHr = 0;
  stableRun = 0;
  spo2Locked = false;
}

void processSpO2AndHR(uint32_t redValue, uint32_t irValue, unsigned long t_n) {
  if (irValue < FINGER_THRESHOLD) {
    // Debounce finger removal (~300ms = 8 samples @ 25sps)
    if (fingerOffCounter < 15)
      fingerOffCounter++;
    if (fingerOffCounter >= 8) {
      fingerPresent = false;
      current_spo2 = 0;
      current_hr = 0;
      showHeartIcon = false;
      ppgSamples = 0;
      ppgHead = 0;
      smoothed_hr = 0.0f;
      smoothed_spo2 = 0.0f;
      ppgAlgoCount = 0;
      ppgLowSignal = false;
      nSpo2Hist = 0;
      spo2HistIdx = 0;
      nHrHist = 0;
      hrHistIdx = 0;
      prevSpo2 = 0;
      prevHr = 0;
      stableRun = 0;
      spo2Locked = false;
    }
    return;
  }

  fingerOffCounter = 0;
  fingerPresent = true;

  // Store in rolling PPG buffer
  redBuffer[ppgHead] = redValue;
  irBuffer[ppgHead] = irValue;
  ppgHead = (ppgHead + 1) % PPG_BUFFER_SIZE;

  // Track fill level for the Maxim algorithm window
  if (ppgSamples < PPG_BUFFER_SIZE)
    ppgSamples++;

  // Detect Pulse Peak on IR channel with noise suppression (icon only;
  // HR/SpO2 values now come from the Maxim reference algorithm below)
  if (ir_avg == 0)
    ir_avg = irValue;
  ir_avg = (ir_avg * 0.96) + (irValue * 0.04);

  if (irValue < ir_avg - 1800) {
    if (t_n - last_spo2_beat > 450) { // Refractory period: max 133 BPM
      last_spo2_beat = t_n;
      showHeartIcon = true;
    }
  } else {
    if (t_n - last_spo2_beat > 150)
      showHeartIcon = false;
  }

  // Every ~1s of new data (25 samples @ 25 sps), run the Maxim
  // reference algorithm over the full 4-second buffer.
  // CRITICAL: Maxim's algorithm requires chronologically linearized
  // arrays (t=0..99). Passing the circular buffer directly introduces a
  // massive step discontinuity at ppgHead that ruins peak detection
  // and causes erroneous SpO2 ratios (72-87%) and erratic HR (40-200 BPM).
  if (ppgSamples >= PPG_BUFFER_SIZE && (ppgHead % 25) == 0) {
    uint32_t lin_ir[PPG_BUFFER_SIZE];
    uint32_t lin_red[PPG_BUFFER_SIZE];
    uint32_t irMin = 0xFFFFFFFF, irMax = 0;
    uint64_t irSum = 0;
    for (int i = 0; i < PPG_BUFFER_SIZE; i++) {
      int idx = (ppgHead + i) % PPG_BUFFER_SIZE;
      lin_ir[i] = irBuffer[idx];
      lin_red[i] = redBuffer[idx];
      if (lin_ir[i] < irMin)
        irMin = lin_ir[i];
      if (lin_ir[i] > irMax)
        irMax = lin_ir[i];
      irSum += lin_ir[i];
    }

    // Perfusion Index: AC peak-to-peak / DC mean on the IR channel.
    // Below PI_MIN_PERCENT the window carries almost no pulsatile
    // information — any Maxim output from it would be noise-shaped, so
    // the window is accepted for nothing (display keeps last value).
    float irDc = (float)irSum / PPG_BUFFER_SIZE;
    ppgLowSignal = (irDc <= 0.0f) ||
                   (((float)(irMax - irMin) / irDc) * 100.0f < PI_MIN_PERCENT);

    int32_t spo2Val = 0, hrVal = 0;
    int8_t spo2Valid = 0, hrValid = 0;
    maxim_heart_rate_and_oxygen_saturation(lin_ir, PPG_BUFFER_SIZE, lin_red,
                                           &spo2Val, &spo2Valid, &hrVal,
                                           &hrValid);
    ppgAlgoCount++;

    // WARM-UP DISCARD: the first PPG_WARMUP_READS windows after buffer
    // fill straddle the finger-insertion transient. Their outputs are
    // deliberately NOT fed to the smoother below — this is what used to
    // seed the EMA at a false high value and produce the slow
    // 140 -> 90 staircase as the slew limiter walked it down.
    bool warmup = ppgAlgoCount <= PPG_WARMUP_READS;

    if (warmup || ppgLowSignal) {
      // No update to smoothed values / history / lock this window.
      // (Lock state decays under sustained bad signal.)
      if (ppgLowSignal && stableRun > 0)
        stableRun--;
      if (stableRun == 0)
        spo2Locked = false;
      return;
    }

    // Physiological smoothing and slew-rate limiting for Heart Rate
    bool hrAccepted = false;
    if (hrValid && hrVal >= 45 && hrVal <= 180) {
      if (smoothed_hr < 30.0f) {
        smoothed_hr = (float)hrVal;
      } else {
        float delta = (float)hrVal - smoothed_hr;
        if (fabs(delta) > 20.0f) {
          delta = (delta > 0) ? 20.0f : -20.0f;
        }
        smoothed_hr += delta * 0.35f;
      }
      current_hr = (uint16_t)(smoothed_hr + 0.5f);
      hrHist[hrHistIdx] = hrVal;
      hrHistIdx = (hrHistIdx + 1) % PPG_HISTORY_LEN;
      if (nHrHist < PPG_HISTORY_LEN)
        nHrHist++;
      hrAccepted = true;
    }

    // Physiological smoothing and slew-rate limiting for SpO2
    bool spo2Accepted = false;
    if (spo2Valid && spo2Val >= 80 && spo2Val <= 100) {
      if (smoothed_spo2 < 70.0f) {
        smoothed_spo2 = (float)spo2Val;
      } else {
        float delta = (float)spo2Val - smoothed_spo2;
        if (fabs(delta) > 3.0f) {
          delta = (delta > 0) ? 3.0f : -3.0f;
        }
        smoothed_spo2 += delta * 0.30f;
      }
      current_spo2 = (uint16_t)(smoothed_spo2 + 0.5f);
      spo2Hist[spo2HistIdx] = spo2Val;
      spo2HistIdx = (spo2HistIdx + 1) % PPG_HISTORY_LEN;
      if (nSpo2Hist < PPG_HISTORY_LEN)
        nSpo2Hist++;
      spo2Accepted = true;
    }

    // Stability lock: 3 consecutive windows where BOTH channels move
    // little means the reading has converged and can be shown as such.
    if (hrAccepted && spo2Accepted) {
      if (prevSpo2 > 0 && prevHr > 0 && abs(spo2Val - prevSpo2) <= 2 &&
          abs(hrVal - prevHr) <= 5) {
        if (stableRun < 255)
          stableRun++;
      } else {
        stableRun = 0;
      }
      prevSpo2 = spo2Val;
      prevHr = hrVal;
      spo2Locked = (stableRun >= 3);
    }
  }
}

// ---------------------------------------------------------
// CORE 0: ISOLATED SENSOR POLLING
// ---------------------------------------------------------

// BLE waveform packer state — was a plain function-local before, which
// meant it silently persisted across ECG sessions instead of resetting.
// Pulled out here (file scope) so powerSensors() can reset it cleanly
// via resetEcgWaveformPacker() whenever a new ECG session starts.
uint8_t ecgBleBuffer[16];
uint8_t ecgBleBufferIdx = 0;
void resetEcgWaveformPacker() { ecgBleBufferIdx = 0; }

void core0TaskFunction(void *pvParameters) {
  int16_t raw_sample;

  // This task must also prove liveness to the watchdog: a locked I2C
  // bus (MAX30102/MLX90614) or a stuck queue receive here previously had
  // nothing to catch it, since only Core 1 registered with the TWDT.
  // On a device with no local screen-based error console, a silent
  // Core 0 hang meant vitals just stopped updating with no signal to
  // the user or a way to recover short of a manual power cycle.
  esp_task_wdt_add(NULL);

  for (;;) {
    esp_task_wdt_reset();
    unsigned long current_time = millis();

    if (sysState == MEASURE_ECG) {
      if (xQueueReceive(ecgQueue, &raw_sample, pdMS_TO_TICKS(10))) {
        // LEADS-OFF GATE: with electrodes detached the AD8232 input
        // floats and picks up mains (50/60 Hz) noise + phase-lead
        // network ringing. Never feed that phantom signal into the
        // DSP, the display history or the BLE stream — freeze the
        // trace and let the UI/app show "LEADS OFF" instead.
        if (leadOff) {
          ecgBaselineSeeded = false;
          continue;
        }

        // 50 Hz notch -> 40 Hz LP
        double clean = ecgConditioningApply((double)raw_sample);

        // Fast baseline acquisition and anti-saturation tracking:
        // Wait for the AD8232 op-amp to power up (> 500 counts) before seeding
        // baseline. If a baseline shift (motion/touch) moves clean by > 150
        // counts from b_n, adapt rapidly (tau ~ 80ms) so the trace never gets
        // stuck at the screen edge as a flat line!
        if (!ecgBaselineSeeded) {
          if (clean > 500.0) {
            b_n = clean;
            f_fast = clean;
            f_slow = clean;
            ecgBaselineSeeded = true;
          }
        } else {
          double offset = fabs(clean - b_n);
          if (offset > 150.0) {
            b_n = b_n * 0.95 + clean * 0.05;
          }
        }

        double filtered = processECG_BaselineRemoval(clean);
        detectRPeak(filtered, current_time);

        // Sweep speed decimation: record every 2nd sample (125 sps)
        // so the 128-pixel window displays 1.024 seconds of cardiac rhythm
        // (a full P-QRS-T complex) instead of spending 80% of its time in the
        // flat isoelectric diastole!
        static uint8_t ecgDecimator = 0;
        if ((++ecgDecimator % 2) == 0) {
          int disp_val = (int)(filtered / 8.0);
          if (disp_val > 26)
            disp_val = 26;
          if (disp_val < -26)
            disp_val = -26;
          ecgHistory[ecgHead] = (int8_t)disp_val;
          ecgHead = (ecgHead + 1) % 128;
        }

        if (deviceConnected) {
          int16_t transmit_val = (int16_t)filtered;
          ecgBleBuffer[ecgBleBufferIdx++] = (transmit_val & 0xFF);
          ecgBleBuffer[ecgBleBufferIdx++] = (transmit_val >> 8) & 0xFF;
          if (ecgBleBufferIdx >= 16) {
            uint8_t tx_frame[20] = {0x02, 0x01, 0x00, 0x00};
            memcpy(&tx_frame[4], ecgBleBuffer, 16);
            pWaveformChar->setValue(tx_frame, 20);
            pWaveformChar->notify();
            ecgBleBufferIdx = 0;
            bleFrames++;
          }
        }
      }
    } else if (sysState == MEASURE_SPO2) {
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
    } else {
      vTaskDelay(pdMS_TO_TICKS(50)); // Idle power savings
    }
  }
}

// ---------------------------------------------------------
// DRAWING ROUTINES (5 PAGES)
// ---------------------------------------------------------
void drawProgressBar(int y, unsigned long elapsed, unsigned long total) {
  display.drawRect(14, y, 100, 6, SSD1306_WHITE);
  if (total == 0) {
    // Continuous / Infinite mode: dynamic scanning radar marquee
    int scanPos = (int)((elapsed / 25) % 88);
    display.fillRect(16 + scanPos, y + 1, 10, 4, SSD1306_WHITE);
    return;
  }
  int fill = (int)((elapsed * 96) / total);
  if (fill > 96)
    fill = 96;
  if (fill < 0)
    fill = 0;
  display.fillRect(16, y + 1, fill, 4, SSD1306_WHITE);
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
  } else {
    display.drawCircle(64, 30, 7, SSD1306_WHITE);
  }
  // Continuous "breathing" outer ring (sin-based radius, ~3s cycle) so
  // the shield still reads as alive between beats, not just on/off.
  int radarR = 10 + (int)(breathe01(ms, 3000) * 4); // 10..14 px
  display.drawCircle(64, 30, radarR, SSD1306_WHITE);
  // Animated rotating orbit dot
  int angle = (ms / 12) % 360;
  int dotX = 64 + (int)(14.0 * cos(angle * 3.14159 / 180.0));
  int dotY = 30 + (int)(14.0 * sin(angle * 3.14159 / 180.0));
  display.fillRect(dotX - 1, dotY - 1, 3, 3, SSD1306_WHITE);

  // 3. Left Side: Battery Status Meter
  display.setCursor(2, 20);
  display.print(battery_percent);
  display.print("%");
  display.drawRect(2, 30, 16, 8, SSD1306_WHITE);
  display.fillRect(18, 32, 2, 4, SSD1306_WHITE); // Battery terminal
  int bFill = (battery_percent * 14) / 100;
  if (bFill > 14)
    bFill = 14;
  if (bFill < 1)
    bFill = 1;
  display.fillRect(3, 31, bFill, 6, SSD1306_WHITE);

  // 4. Right Side: BLE Radio Status Badge
  display.setCursor(88, 20);
  display.print("BLE");
  if (deviceConnected) {
    display.fillCircle(104, 33, 3, SSD1306_WHITE);
    int wave = (ms / 300) % 3;
    if (wave >= 1)
      display.drawCircle(104, 33, 6, SSD1306_WHITE);
    if (wave >= 2)
      display.drawCircle(104, 33, 9, SSD1306_WHITE);
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
    if (ms - measurementStartAnimTime < ANIM_STING_MS) {
      drawStartSting(ms, "SpO2");
      return;
    }
    if (!fingerPresent) {
      display.setCursor(0, 20);
      display.print("PLACE FINGER...");
      display.setCursor(0, 32);
      display.print("Rest gently on glass");
    } else if (ppgSamples < PPG_BUFFER_SIZE) {
      display.setCursor(0, 20);
      display.print("CALIBRATING...");
      display.setCursor(0, 32);
      display.print("Acquiring: ");
      display.print((ppgSamples * 100) / PPG_BUFFER_SIZE);
      display.print("%");
    } else if (ppgAlgoCount <= PPG_WARMUP_READS) {
      // Warm-up windows are deliberately discarded (insertion
      // transient) — tell the user instead of showing a fake number.
      display.setCursor(0, 20);
      display.print("SETTLING...");
      display.setCursor(0, 32);
      display.print("Hold finger still");
    } else {
      display.setCursor(0, 14);
      display.print("HR:   ");
      display.print(current_hr);
      display.print(" BPM");
      display.setCursor(0, 24);
      display.print("SpO2: ");
      display.print(current_spo2);
      display.print(" %");
      display.setCursor(0, 36);
      if (ppgLowSignal) {
        display.print("Low signal - relax");
      } else if (spo2Locked) {
        display.print("[ LOCKED ]");
      } else {
        display.print("Stabilizing");
        int dots = (ms / 500) % 4;
        for (int i = 0; i < dots; i++)
          display.print(".");
      }
      if (showHeartIcon)
        display.drawBitmap(100, 14, bmp_heart_16, 16, 16, SSD1306_WHITE);
    }

    unsigned long elapsed = ms - measurementStartTime;
    if (measurementDuration == 0) {
      display.setCursor(0, 48);
      display.setTextSize(1);
      unsigned int sec = (unsigned int)(elapsed / 1000);
      char tbuf[24];
      snprintf(tbuf, sizeof(tbuf), "LIVE %02u:%02u [CONT]", sec / 60, sec % 60);
      display.print(tbuf);
      drawProgressBar(58, elapsed, 0);
    } else {
      drawProgressBar(46, elapsed, measurementDuration);
    }
  } else if (justCompleted(PAGE_SPO2, ms)) {
    drawCompleteCelebration(ms);
  } else {
    display.setCursor(0, 24);
    display.print("Last: ");
    display.print(current_spo2);
    display.print("% | ");
    display.print(current_hr);
    display.print("bpm");
    display.setCursor(0, 44);
    display.print("Hold TCH1 to Start");
  }
}

void drawPageECG(unsigned long ms) {
  if (sysState == MEASURE_ECG) {
    if (ms - measurementStartAnimTime < ANIM_STING_MS) {
      drawStartSting(ms, "ECG");
      return;
    }
    // Draw Full Screen Scrolling Graph
    for (int i = 0; i < 128; i += 16)
      display.drawFastVLine(i, 0, 56, SSD1306_WHITE);
    if (leadOff) {
      drawLeadOffPrompt(
          ms); // pulsing prompt instead of static frozen-looking text
      return;
    }
    int ptr = ecgHead, prev_x = 0, prev_y = 28 - ecgHistory[ptr];
    for (int x = 1; x < 128; x++) {
      ptr = (ptr + 1) % 128;
      int y = 28 - ecgHistory[ptr];
      if (y < 0)
        y = 0;
      if (y > 55)
        y = 55;
      if (x < 126)
        display.drawFastVLine(x + 1, 0, 56, SSD1306_BLACK);
      display.drawLine(prev_x, prev_y, x, y, SSD1306_WHITE);
      prev_x = x;
      prev_y = y;
    }
    if (showHeartIcon)
      display.fillCircle(120, 6, 3, SSD1306_WHITE); // Pulse indicator
    display.setTextSize(1);
    display.setCursor(2, 2);
    if (current_hr > 0) {
      display.print(current_hr);
      display.print(" BPM");
    }
    unsigned long elapsed = ms - measurementStartTime;
    if (measurementDuration == 0) {
      display.setCursor(68, 2);
      unsigned int sec = (unsigned int)(elapsed / 1000);
      char tbuf[16];
      snprintf(tbuf, sizeof(tbuf), "%02u:%02u [C]", sec / 60, sec % 60);
      display.print(tbuf);
      drawProgressBar(58, elapsed, 0);
    } else {
      drawProgressBar(58, elapsed, measurementDuration);
    }
  } else if (justCompleted(PAGE_ECG, ms)) {
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print("ECG MONITOR");
    drawCompleteCelebration(ms);
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
    if (ms - measurementStartAnimTime < ANIM_STING_MS) {
      drawStartSting(ms, "TEMP");
      return;
    }
    // Thermometer fill animation
    display.drawRect(58, 14, 8, 30, SSD1306_WHITE);
    display.drawCircle(62, 46, 6, SSD1306_WHITE);

    unsigned long elapsed = ms - measurementStartTime;
    int fillHeight = (elapsed * 30) / measurementDuration;
    if (fillHeight > 30)
      fillHeight = 30;

    display.fillCircle(62, 46, 4, SSD1306_WHITE);                        // Bulb
    display.fillRect(60, 44 - fillHeight, 4, fillHeight, SSD1306_WHITE); // Stem
  } else if (justCompleted(PAGE_TEMP, ms)) {
    drawCompleteCelebration(
        ms); // median-of-5 landed — make the fresh reading obvious
  } else {
    display.setTextSize(2);
    display.setCursor(20, 20);
    display.print(current_temp, 1);
    display.print("C");
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
  display.print("Bat: ");
  display.print(battery_percent);
  display.print("% (");
  display.print(current_battery_v, 2);
  display.print("V)");

  unsigned long up = (millis() - bootTime) / 1000;
  display.setCursor(0, 28);
  display.print("Uptime: ");
  display.print(up);
  display.print("s");

  display.setCursor(0, 40);
  display.print("BLE Tx: ");
  display.print(bleFrames);
  // Surface dropped ECG samples (queue-full events) so a stalled Core 0
  // consumer or an oversubscribed BLE link shows up here instead of
  // just quietly degrading the waveform with no visible cause.
  if (ecgQueueDropCount > 0) {
    display.setCursor(0, 52);
    display.print("ECG drops: ");
    display.print(ecgQueueDropCount);
  }
}

// ---------------------------------------------------------
// CORE 1: UI & TELEMETRY
// ---------------------------------------------------------
void core1TaskFunction(void *pvParameters) {
  unsigned long last_telemetry = 0;
  unsigned long last_display = 0;

  // Task watchdog: Core 1 (UI + BLE) must prove liveness every 5 s.
  // A hung display loop or stalled BLE stack now triggers a clean
  // reboot instead of silently freezing a clinical device.
  esp_task_wdt_add(NULL);

  for (;;) {
    esp_task_wdt_reset();
    unsigned long current_time = millis();

    // Navigation (Tap TCH2 = Next Page)
    if (digitalRead(TOUCH_PIN_2) == HIGH &&
        (current_time - lastTouchTime2 > 300)) {
      if (sysState == SYS_IDLE) { // Only allow navigation if idle
        currentPage = (PageState)((currentPage + 1) % 5);
      }
      lastTouchTime2 = current_time;
    }

    // Context-Aware Trigger (Hold TCH1 = Start Measure)
    if (digitalRead(TOUCH_PIN_1) == HIGH) {
      if (touch1PressStart == 0)
        touch1PressStart = current_time;
      else if (current_time - touch1PressStart > 1000) {
        if (sysState == SYS_IDLE) {
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
        } else {
          // Manual stop: user holds touch button during active/continuous measurement
          if (sysState == MEASURE_SPO2) {
            if (nSpo2Hist >= 3)
              current_spo2 = (uint16_t)medianOfI32(spo2Hist, nSpo2Hist);
            if (nHrHist >= 3)
              current_hr = (uint16_t)medianOfI32(hrHist, nHrHist);
          }
          measurementCompleteAnimTime = current_time;
          measurementCompletePage = currentPage;
          powerSensors(SYS_IDLE);
          animBurstUntil = current_time + ANIM_COMPLETE_MS + 50;
        }
        touch1PressStart = 0;
      }
    } else {
      touch1PressStart = 0;
    }

    // Measurement Timer State Machine
    if (sysState != SYS_IDLE) {
      unsigned long elapsed = current_time - measurementStartTime;

      // Temperature median-of-5: sample once every ~100ms via a
      // non-blocking timestamp check instead of five sequential
      // delay(100) calls. The old blocking version froze touch
      // input, BLE telemetry and the display for ~400ms on every
      // single temp reading. This keeps the reads on Core 1
      // deliberately: the MLX90614 and the OLED share the same
      // Wire bus, so moving the reads to Core 0 to "free up" Core 1
      // would trade a 400ms UI stall for a genuine two-core I2C bus
      // race — strictly worse for a device with no bus-arbitration
      // mutex around Wire.
      if (sysState == MEASURE_TEMP && mlxFound &&
          (measurementDuration == 0 || elapsed <= measurementDuration)) {
        if (tempSampleCount < 5 && current_time - tempLastSampleTime >= 100) {
          tempSamples[tempSampleCount++] = mlx.readObjectTempC();
          tempLastSampleTime = current_time;
        }
      }

      // Only auto-finalize if measurementDuration is non-zero (0 = Continuous/Infinite)
      if (measurementDuration > 0 && elapsed > measurementDuration) {
        // Finalize specific readings
        if (sysState == MEASURE_TEMP && mlxFound) {
          // Grab any remaining samples immediately rather than
          // waiting out the normal 100ms spacing — the reading
          // window has already elapsed, so finish up now.
          while (tempSampleCount < 5) {
            tempSamples[tempSampleCount++] = mlx.readObjectTempC();
            esp_task_wdt_reset();
          }
          current_temp = medianOf5(tempSamples) +
                         2.0; // median + empirical skin->core offset
          tempSampleCount = 0;
        } else if (sysState == MEASURE_SPO2) {
          // Final result = MEDIAN of the last PPG_HISTORY_LEN accepted
          // windows (the steady tail of the 30s session), NOT whatever
          // the EMA happened to be at timeout. A median is robust to
          // one or two outlier windows; a mean of the whole session
          // would still leak the insertion transient. Requires >=3
          // accepted windows — otherwise the last smoothed value (or
          // 0 if there never was one) stands as "no reliable reading".
          if (nSpo2Hist >= 3)
            current_spo2 = (uint16_t)medianOfI32(spo2Hist, nSpo2Hist);
          if (nHrHist >= 3)
            current_hr = (uint16_t)medianOfI32(hrHist, nHrHist);
        }
        // Capture which page just finalized (and when) *before* powerSensors()
        // flips sysState back to idle, so the completion celebration knows
        // which page's summary view to decorate.
        measurementCompleteAnimTime = current_time;
        measurementCompletePage = currentPage;
        powerSensors(SYS_IDLE); // Done, back to sleep
        // Extend the fast-redraw burst so the "reading saved"
        // celebration also gets enough frames.
        animBurstUntil = current_time + ANIM_COMPLETE_MS + 50;
      }
    }

    // BLE connect/disconnect edge detection — deviceConnected is flipped
    // from the BLE stack's own callback context; polling it here (rather
    // than animating inside the callback) keeps the callback itself fast
    // and non-blocking.
    if (deviceConnected != lastDeviceConnectedSeen) {
      lastDeviceConnectedSeen = deviceConnected;
      bleStateChangeAnimTime = current_time;
      bleStateChangeWasConnect = deviceConnected;
      // A BLE state flip is exactly the kind of short-lived flash
      // event the burst mode exists for.
      animBurstUntil = current_time + ANIM_BLE_MS + 50;
      // Kick off the LED blink pattern for this edge: 2 quick
      // blinks for "connected", 4 for "disconnected".
      ledBleBlinkStartTime = current_time;
      ledBleBlinkPulsesLeft = deviceConnected ? 2 : 4;
    }

    // Drive the status LED every pass (cheap digitalWrite, no delay) so
    // the heartbeat pulse tracks each beat as tightly as possible,
    // independent of the display's own (slower) refresh rate.
    updateStatusLed(current_time);

    // Retained Telemetry (4Hz)
    if (current_time - last_telemetry >= 250) {
      last_telemetry = current_time;

      // Raw per-call reading already averages 8 ADC samples, but that
      // alone still lets normal divider/ADC noise move the value
      // enough to flip battery_percent back and forth between two
      // adjacent table steps every 250ms (e.g. 83/81/82/83...). An
      // exponential moving average across *readings* (not just within
      // one reading) fixes that: each new sample only nudges the
      // running value by 10%, so isolated noise gets absorbed and the
      // displayed number only moves when the battery is actually
      // trending up or down. alpha=0.1 settles in a few seconds —
      // fast enough to track real discharge, slow enough to kill jitter.
      float raw_battery_v = readBatteryVoltage();
      if (battery_v_smoothed < 0.0f) {
        battery_v_smoothed = raw_battery_v; // first-ever reading: seed directly
      } else {
        battery_v_smoothed = battery_v_smoothed * 0.9f + raw_battery_v * 0.1f;
      }
      current_battery_v = battery_v_smoothed;

      // Hysteresis on top of the smoothed voltage: even a well-averaged
      // voltage can sit right on a table breakpoint and tick the
      // percentage back and forth by 1-2%. Only adopt the new
      // percentage once it has drifted at least BATTERY_PCT_HYSTERESIS
      // points away from what's currently shown -- small noise gets
      // absorbed and battery_percent only moves on a real, sustained
      // trend, not a single noisy sample landing just past a boundary.
      int newBatteryPct = batteryPercentFromVoltage(current_battery_v);
      const int BATTERY_PCT_HYSTERESIS = 2;
      if (abs(newBatteryPct - battery_percent) >= BATTERY_PCT_HYSTERESIS) {
        battery_percent = newBatteryPct;
      }

      if (deviceConnected) {
        // Payload retains last known values for inactive sensors.
        // Byte layout (app contract):
        //   [0]=0x01 pkt id, [1]=PROTOCOL_VERSION, [2]=HR, [3]=SpO2,
        //   [4-5]=temp x100 LE, [6-7]=last RR ms LE, [8]=lead status,
        //   [9]=flags (bit0=beat, bit2=lead-off, bit3=finger-off,
        //   bit4=SpO2 locked/stabilized, bit5=low PPG signal),
        //   [14]=battery %,
        //   [15]=sysState so the app can sync UI.
        uint8_t tx_telemetry[20] = {0x01, PROTOCOL_VERSION, (uint8_t)current_hr,
                                    (uint8_t)current_spo2};
        int16_t temp_x100 = (int16_t)(current_temp * 100);
        tx_telemetry[4] = temp_x100 & 0xFF;
        tx_telemetry[5] = (temp_x100 >> 8) & 0xFF;
        tx_telemetry[6] = last_rr_ms & 0xFF;
        tx_telemetry[7] = (last_rr_ms >> 8) & 0xFF;
        tx_telemetry[8] = leadOff ? 0 : 100;
        uint8_t flags = 0;
        if (showHeartIcon)
          flags |= 0x01; // beat flash
        if (leadOff)
          flags |= 0x04; // lead-off
        if (!fingerPresent && sysState == MEASURE_SPO2)
          flags |= 0x08; // finger-off
        if (spo2Locked && sysState == MEASURE_SPO2)
          flags |= 0x10; // SpO2 reading stabilized (3 stable windows)
        if (ppgLowSignal && sysState == MEASURE_SPO2 && fingerPresent)
          flags |= 0x20; // low perfusion — poor optical signal
        tx_telemetry[9] = flags;
        tx_telemetry[14] = battery_percent;
        tx_telemetry[15] = (uint8_t)sysState;
        pTelemetryChar->setValue(tx_telemetry, 20);
        pTelemetryChar->notify();
      }
    }

    // Display Refresh: normally ~4 Hz (250ms) to stop BLE starvation,
    // but temporarily bumped to ~20 Hz (ANIM_BURST_FPS_MS) for a short
    // window after a measurement start/finish or a BLE state change,
    // so those sub-second animations (the sting, the completion pop,
    // the BLE flash) actually render enough frames to read as motion
    // instead of a single jump cut. Bursts are short (<=650ms) and
    // rare, so the BLE-starvation risk the original 4Hz choice guarded
    // against is not reintroduced in steady state.
    bool bursting = current_time < animBurstUntil;
    unsigned long displayIntervalMs = bursting ? ANIM_BURST_FPS_MS : 250;
    if (current_time - last_display >= displayIntervalMs) {
      last_display = current_time;
      display.clearDisplay();

      switch (currentPage) {
      case PAGE_HOME:
        drawPageHome(current_time);
        break;
      case PAGE_SPO2:
        drawPageSpO2(current_time);
        break;
      case PAGE_ECG:
        drawPageECG(current_time);
        break;
      case PAGE_TEMP:
        drawPageTemp(current_time);
        break;
      case PAGE_SYS:
        drawPageSys();
        break;
      }

      // Cross-page overlays — drawn after the page content so they sit
      // on top regardless of which page is active. Both are pure
      // display effects: neither touches sysState/powerSensors(), so
      // an in-progress measurement is never interrupted.
      drawLowBatteryOverlay(current_time);
      drawBleStateChangeOverlay(current_time);

      display.display();
    }
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

// ---------------------------------------------------------
// BOOT & SETUP
// ---------------------------------------------------------
//
// The intro is themed on the physical enclosure: a plus-shaped
// "Band-Aid" cross (see hardware/design render) with a heartbeat
// mascot that blinks awake. It is a fixed, non-blocking-friendly
// sequence of delay()-based frames — display + BLE + sensors haven't
// started their RTOS tasks yet at this point, so blocking here costs
// nothing at runtime. Total runtime: ~3.6 s.

// Small helper: draws a checkmark glyph (two short strokes) — used by
// the diagnostic checklist so passes feel like a "tick", not just text.
void drawBootCheck(int x, int y) {
  display.drawLine(x, y + 3, x + 2, y + 5, SSD1306_WHITE);
  display.drawLine(x + 2, y + 5, x + 6, y - 1, SSD1306_WHITE);
}

// Ease-out cubic — motion starts fast and settles gently instead of
// stopping dead. t is 0..1. Used by the sweep and slide-in so those
// moves read as "designed" rather than a raw linear for-loop.
float easeOutCubic(float t) {
  float f = t - 1.0f;
  return f * f * f + 1.0f;
}

// Checked at each animation frame inside playBootAnimation(). Holding
// either touch pad during boot clears the screen and returns immediately,
// so field restarts don't have to sit through the full ~2.5-3s intro
// every time. TOUCH_PIN_1/2 are already configured as INPUT before
// playBootAnimation() is called from setup().
#define BOOT_SKIP_CHECK()                                                      \
  do {                                                                         \
    if (bootSkipRequested()) {                                                 \
      display.clearDisplay();                                                  \
      display.display();                                                       \
      return;                                                                  \
    }                                                                          \
  } while (0)

// Quick left-to-right wipe-to-black used BETWEEN major boot stages instead
// of an abrupt clearDisplay() jump-cut — reads as an animated scene change
// rather than a hard cut. Returns true if the user asked to skip the intro
// mid-wipe; the caller must `return` immediately in that case, same as
// BOOT_SKIP_CHECK() does everywhere else (this can't use that macro itself
// since it needs to unwind out of playBootAnimation(), not just this helper).
bool wipeTransition() {
  for (int x = 0; x <= 128; x += 16) {
    display.fillRect(0, 0, x, 64, SSD1306_BLACK);
    display.display();
    delay(6);
    if (bootSkipRequested()) {
      display.clearDisplay();
      display.display();
      return true;
    }
  }
  display.clearDisplay();
  return false;
}

void playBootAnimation() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // --- 0. Big branded title, revealed with a left-to-right wipe ---
  // Two size-2 lines ("SWASTHYA" / "SETU AI") so the name reads large
  // and centered. The text is drawn once, then a black mask sweeps
  // away from the left edge to uncover it — a clean "type-on" reveal
  // rather than a hard cut to full text.
  display.setTextSize(2);
  int line1X = 16, line1Y = 14; // "SWASTHYA" — 8 chars * 12px = 96px
  int line2X = 22, line2Y = 36; // "SETU AI"  — 7 chars * 12px = 84px
  display.setCursor(line1X, line1Y);
  display.print("SWASTHYA");
  display.setCursor(line2X, line2Y);
  display.print("SETU AI");

  const int REVEAL_FRAMES = 16;
  for (int f = 0; f <= REVEAL_FRAMES; f++) {
    float t = f / (float)REVEAL_FRAMES;
    int revealX = (int)(easeOutCubic(t) * 128); // wipe edge moves left -> right
    // Mask must cover the FULL two-line text block (y=14..52, i.e. 38px
    // tall) with a little margin. The old 32px-tall mask (y=10..42)
    // stopped short of y=52, so the bottom few rows of "SETU AI" were
    // visible immediately, un-wiped, before the reveal reached them —
    // this is what showed up as jumbled/overlapping text in the field.
    display.fillRect(revealX, 10, 128 - revealX, 46,
                     SSD1306_BLACK); // mask what's not yet "typed"
    display.display();
    delay(13);
    BOOT_SKIP_CHECK();
  }
  delay(90);
  BOOT_SKIP_CHECK();

  // --- little flourish: a small heart blips awake under the title ---
  // Moved up to y=46 (was y=50): the bitmap is 16px tall, so at y=50 its
  // bottom 2 rows fell past the 64px screen edge and were silently
  // clipped — the visible symptom was a heart that looked "cut off".
  // The clear rect height is now 16 (was 14) to match the bitmap height
  // exactly, so no leftover pixel strip survives between blinks.
  for (int i = 0; i < 3; i++) {
    display.fillRect(56, 46, 16, 16, SSD1306_BLACK);
    display.drawBitmap(56, 46, bmp_heart_16, 16, 16, SSD1306_WHITE);
    display.display();
    delay(90);
    BOOT_SKIP_CHECK();
    display.fillRect(56, 46, 16, 16, SSD1306_BLACK);
    display.display();
    delay(60);
    BOOT_SKIP_CHECK();
  }
  display.drawBitmap(56, 46, bmp_heart_16, 16, 16, SSD1306_WHITE);
  display.display();
  delay(160);
  BOOT_SKIP_CHECK();
  display.invertDisplay(true);
  delay(35);
  BOOT_SKIP_CHECK();
  display.invertDisplay(false);
  delay(75);
  BOOT_SKIP_CHECK();

  // --- 2. Plus-shaped "Band-Aid" cross draws itself, arm by arm ---
  // Mirrors the physical 4-arm enclosure: ECG / Band-Aid (PPG+Temp) /
  // touch pads / battery-BLE arm, meeting at the OLED in the center.
  // Arms ease outward (fast start, gentle stop) instead of a constant
  // linear crawl, which is what actually reads as "smooth" on a panel
  // this small.
  // Wipe-to-black transition (instead of a bare clearDisplay()) so the
  // scene change reads as an animated cut, not an abrupt jump.
  if (wipeTransition())
    return;
  int cx = 64, cy = 30, arm = 4, armLen = 20;
  display.fillCircle(cx, cy, 2, SSD1306_WHITE);
  for (int f = 1; f <= 10; f++) {
    float t = f / 10.0f;
    int a = 1 + (int)(easeOutCubic(t) * (arm - 1));
    display.fillRect(cx - a, cy - a, a * 2, a * 2, SSD1306_WHITE);
    display.display();
    delay(10);
    BOOT_SKIP_CHECK();
  }
  const int FRAMES = 14;
  for (int f = 1; f <= FRAMES; f++) {
    float t = f / (float)FRAMES;
    int step = (int)(easeOutCubic(t) * armLen);
    display.drawRect(cx - arm, cy - arm - step, arm * 2, step,
                     SSD1306_WHITE);                                    // up
    display.drawRect(cx + arm, cy - arm, step, arm * 2, SSD1306_WHITE); // right
    display.drawRect(cx - arm, cy + arm, arm * 2, step, SSD1306_WHITE); // down
    display.drawRect(cx - arm - step, cy - arm, step, arm * 2,
                     SSD1306_WHITE); // left
    display.display();
    delay(13);
    BOOT_SKIP_CHECK();
  }
  display.setTextSize(1);
  display.setCursor(14, 54);
  display.print("SWASTHYASETU AI");
  display.display();
  delay(90);
  BOOT_SKIP_CHECK();
  // pop flash to punctuate the logo landing
  display.invertDisplay(true);
  delay(55);
  BOOT_SKIP_CHECK();
  display.invertDisplay(false);
  delay(200);
  BOOT_SKIP_CHECK();

  // --- 3. Tagline card eases in from the right, settling with a soft stop ---
  const int SLIDE_FRAMES = 16;
  for (int f = 0; f <= SLIDE_FRAMES; f++) {
    float t = f / (float)SLIDE_FRAMES;
    int offset = 80 - (int)(easeOutCubic(t) * 80);
    display.clearDisplay();
    display.drawRoundRect(4 + offset, 6, 120, 52, 6, SSD1306_WHITE);
    if (t > 0.45f) {
      int textFade = offset / 2;
      display.setCursor(16 + textFade, 14);
      display.print("Record vitals.");
      display.setCursor(16 + textFade, 26);
      display.print("Get triage.");
      display.setCursor(16 + textFade, 38);
      display.print("No internet needed.");
    }
    display.display();
    delay(14);
    BOOT_SKIP_CHECK();
  }
  delay(300);
  BOOT_SKIP_CHECK();

  // --- 4. Diagnostic hardware check with animated tick marks + bar ---
  // Wipe transition here too, for the same "scene change" polish.
  if (wipeTransition())
    return;
  display.drawRect(0, 0, 128, 64, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(10, 6);
  display.println("AI HARDWARE DIAG");
  display.drawLine(8, 16, 120, 16, SSD1306_WHITE);
  display.display();
  delay(70);
  BOOT_SKIP_CHECK();

  display.setCursor(10, 24);
  display.print(mlxFound ? "MLX90614 TEMP" : "[WARN] MLX MISSING");
  if (mlxFound)
    drawBootCheck(100, 24);
  display.display();
  delay(110);
  BOOT_SKIP_CHECK();

  display.setCursor(10, 36);
  display.print(maxFound ? "MAX30102 PPG" : "[WARN] MAX MISSING");
  if (maxFound)
    drawBootCheck(100, 36);
  display.display();
  delay(110);
  BOOT_SKIP_CHECK();

  display.setCursor(10, 48);
  display.print("AD8232 ECG");
  drawBootCheck(100, 48);
  display.display();
  delay(110);
  BOOT_SKIP_CHECK();

  // final loading bar sweep, finer steps for a smoother fill
  display.drawRect(10, 58, 108, 4, SSD1306_WHITE);
  for (int w = 0; w <= 106; w += 3) {
    display.fillRect(11, 59, w, 2, SSD1306_WHITE);
    display.display();
    delay(5);
    BOOT_SKIP_CHECK();
  }
  delay(140);
  BOOT_SKIP_CHECK();
}

void setup() {
  Serial.begin(115200);
  bootTime = millis();

  pinMode(ECG_SDN_PIN, OUTPUT);
  digitalWrite(ECG_SDN_PIN, LOW); // Start powered off (Isolation)
  pinMode(ECG_LO_PLUS_PIN, INPUT);
  pinMode(ECG_LO_MINUS_PIN, INPUT);
  pinMode(BATTERY_PIN, INPUT);
  // Calibrate the ADC from the factory eFuse values. GPIO35 is ADC1_CH7;
  // 11 dB attenuation spans ~0..3.1 V at the pin, i.e. 0..6.2 V after the
  // divider — comfortably covering a 4.2 V cell.
  analogSetPinAttenuation(BATTERY_PIN, ADC_11db);
  pinMode(ECG_ANALOG_PIN, INPUT);
  analogSetPinAttenuation(
      ECG_ANALOG_PIN, ADC_11db); // 0..3.3V full-scale for 1.65V AD8232 baseline
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_12, ADC_WIDTH_BIT_12, 1100,
                           &adcChars); // DB_11 deprecated in core 3.x
#else
  esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12, 1100,
                           &adcChars);
#endif
  pinMode(LED_PIN, OUTPUT);
  // "Powered on" confirmation: three quick blinks fire immediately, before
  // any sensor/display/BLE init runs, so there's a visible sign of life
  // the instant the device is switched on — even if the OLED or BLE
  // stack later fails to come up.
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(80);
    digitalWrite(LED_PIN, LOW);
    delay(80);
  }
  pinMode(TOUCH_PIN_1, INPUT);
  pinMode(TOUCH_PIN_2, INPUT);

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setClock(100000);
  // Give the Wire peripheral a bounded timeout instead of the default
  // (effectively unbounded on some cores) so a glitched/stuck I2C bus
  // -- a real risk with long sensor wires near the analog ECG front
  // end -- can't indefinitely hang whichever task calls into it.
  Wire.setTimeOut(50); // ms
  I2C_MAX.begin(I2C1_SDA_PIN, I2C1_SCL_PIN);
  I2C_MAX.setTimeOut(50);

  mlxFound = mlx.begin();
  maxFound = particleSensor.begin(I2C_MAX, I2C_SPEED_FAST);
  // 100 sps / averaging 4 -> 25 sps effective over interfaces bundled
  // to work with the Maxim reference algorithm (4 s windows x 25 sps).
  // 0x3C (60, ~12mA) provides optimal tissue penetration and high SNR without
  // saturation.
  if (maxFound)
    particleSensor.setup(0x3C, 4, 2, 100, 411, 4096);
  ecgConditioningInit();

  if (display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    display.setTextColor(SSD1306_WHITE);
#ifdef DEMO_BOOT
    playBootAnimation(); // ~2.4 s branded intro — mascot + cross + diag
#endif
  }

#ifdef CONFIG_BT_BLE_50_FEATURES_SUPPORTED
  // Prefer 2M PHY once connected — halves radio airtime for the 250 Hz
  // ECG waveform stream, which is a real battery win on a wearable.
  // (Requires Bluedroid 5.0 features; silently skipped on stock config.)
  BLEDevice::setCustomGapHandler(
      [](esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
        if (event == ESP_GAP_BLE_UPDATE_CONN_PARAMS_EVT) {
          esp_ble_gap_set_preferred_phy(
              param->update_conn_params.bda, ESP_BLE_GAP_PHY_2M_PREF_MASK,
              ESP_BLE_GAP_PHY_2M_PREF_MASK, ESP_BLE_GAP_PHY_OPTIONS_NO_PREF);
        }
      });
#endif
  BLEDevice::init("SSAI-SENSE-01");
  BLEDevice::setMTU(
      247); // large MTU: more samples per notify, fewer transactions

  // NOTE: bonding/encryption enforcement below is DISABLED for now.
  // This block never actually compiled in earlier versions of this file
  // (it referenced a GATT permission constant that doesn't exist), so it
  // never ran on real hardware. Once the typo was fixed so it would
  // compile, it started actually enforcing full BLE Secure-Connections
  // bonding before accepting ANY write to the control characteristic --
  // which is the exact characteristic a phone app writes to start
  // SpO2/ECG/Temp. A normal app that never initiates BLE pairing has
  // those writes silently rejected (and the link can even become
  // unstable), which looks exactly like "can't connect / can't measure".
  // Re-enable this only once the companion app is confirmed to handle
  // the OS-level BLE pairing/bonding prompt.
  // BLESecurity *pSecurity = new BLESecurity();
  // pSecurity->setAuthenticationMode(ESP_LE_AUTH_REQ_SC_BOND);
  // pSecurity->setCapability(ESP_IO_CAP_NONE);
  // pSecurity->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK |
  // ESP_BLE_ID_KEY_MASK);

#ifdef ENABLE_CLINIC_OTA
  WiFi.mode(WIFI_STA);
  WiFi.begin(OTA_WIFI_SSID, OTA_WIFI_PASS);
  ArduinoOTA.setHostname("SSAI-SENSE-01");
  ArduinoOTA.begin();
#endif
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);

  BLECharacteristic *pDevInfoChar = pService->createCharacteristic(
      DEV_INFO_CHAR_UUID, BLECharacteristic::PROPERTY_READ);
  pDevInfoChar->setValue("3.0.0");

  pTelemetryChar = pService->createCharacteristic(
      TELEMETRY_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pTelemetryChar->addDescriptor(new BLE2902());

  BLECharacteristic *pControlChar = pService->createCharacteristic(
      CONTROL_CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  pControlChar->setCallbacks(new MyControlCallbacks());
  // Access permission restriction removed -- see the disabled BLESecurity
  // block above for why. Plain write, same as DEV_INFO/TELEMETRY.

  pWaveformChar = pService->createCharacteristic(
      WAVEFORM_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pWaveformChar->addDescriptor(new BLE2902());
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  // 64-deep queue ~= 256 ms of 250 Hz samples — absorbs BLE notify
  // bursts on Core 0 that previously overflowed the 20-deep queue.
  ecgQueue = xQueueCreate(64, sizeof(int16_t));

#if ESP_ARDUINO_VERSION_MAJOR >= 3
  timer = timerBegin(1000000); // 1 MHz tick
  timerAttachInterrupt(timer, &onEcgTimer);
  timerAlarm(timer, 4000, true, 0); // 250 Hz
#else
  // Core 2.x legacy timer API: timer 0, 80 -> 1 MHz, count up
  timer = timerBegin(0, 80, true);
  timerAttachInterrupt(timer, &onEcgTimer, true);
  timerAlarmWrite(timer, 4000, true); // 250 Hz
  timerAlarmEnable(timer);
#endif

  // 5 s task watchdog, fed by both Core 0 and Core 1 tasks (previously
  // only Core 1 registered — see core0TaskFunction()).
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  esp_task_wdt_config_t wdt_cfg = {
      .timeout_ms = 5000, .idle_core_mask = 0, .trigger_panic = true};
  esp_task_wdt_init(&wdt_cfg);
#else
  esp_task_wdt_init(5, true);
#endif
  xTaskCreatePinnedToCore(core0TaskFunction, "Core0_DSP", 10000, NULL, 2,
                          &Core0Task, 0);
  xTaskCreatePinnedToCore(core1TaskFunction, "Core1_TLM", 10000, NULL, 1,
                          &Core1Task, 1);

  // Ensure all sensors sleep at boot
  powerSensors(SYS_IDLE);
}

void loop() {
#ifdef ENABLE_CLINIC_OTA
  ArduinoOTA.handle();
#endif
  vTaskDelay(pdMS_TO_TICKS(1000));
}
