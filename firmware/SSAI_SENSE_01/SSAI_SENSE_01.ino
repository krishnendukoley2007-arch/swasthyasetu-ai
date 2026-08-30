/*
====================================================================
                    SSAI-SENSE-01  —  FIRMWARE v1.5

   ESP32 + AD8232 ECG + TTP223 touch + SSD1306 OLED + battery gauge

   Everything from v1.4 (real R-peak HR, real battery, honest
   sentinels, active-LOW touch, LED patterns) PLUS showtime:

   * BOOT SHOW: 3 LED blinks -> expanding rings on the OLED ->
     a typewriter typing "SSAI-SENSE-01" -> a big heart that beats
     twice while saying "Hello! :)" -> sensor checklist wipes in.
   * LIVE SCREEN never sits still:
       - heart icon PUMPS in sync with your real heartbeat
         (a little thump every R-peak, gentle breathing when idle),
       - a live ECG trace scrolls along the bottom of the screen,
       - signal-quality bar fills with an animated shimmer,
       - tiny sparkle pops over the heart on every detected beat.
   * No blocking delays in the live loop; the boot show only runs
     once in setup() before BLE starts.

   This firmware is a screening aid, not a medical device.
====================================================================

PIN MAP (your actual wiring)
----------------------------
GPIO36 (VP / ADC1_CH0) : AD8232 OUTPUT (analog ECG)
GPIO39 (VN)            : AD8232 LO+
GPIO34                 : AD8232 LO-
GPIO18                 : AD8232 SDN  (driven HIGH = front end enabled)
GPIO4                  : TTP223 touch OUT (active LOW)
GPIO2                  : built-in blue LED
GPIO21 / 22            : OLED SDA / SCL (0x3C)
GPIO35                 : battery divider (BAT+ -100k- GPIO35 -100k- GND)
3V3 / GND              : rails

SAFETY: never take an ECG while the board is plugged into a charger.
Battery or power-bank power only when electrodes touch skin.
====================================================================
*/

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include <driver/adc.h>

// ====================================================================
// CONFIG
// ====================================================================

#define TOUCH_ACTIVE_LOW   true         // TTP223: idle HIGH, touch LOW
#define FIRMWARE_VERSION   "2.0.0"

#define SCREEN_WIDTH       128
#define SCREEN_HEIGHT      64
#define OLED_RESET         -1
#define OLED_ADDRESS       0x3C

#define ECG_OUT_PIN        36
#define ECG_LO_PLUS_PIN    39
#define ECG_LO_MINUS_PIN   34
#define ECG_SDN_PIN        18
#define TOUCH_PIN          4
#define LED_PIN            2
#define BATT_PIN           35           // 100k / 100k divider from BAT+

#define BATT_DIVIDER       2.0f
#define BATT_V_FULL        4.2f
#define BATT_V_EMPTY       3.0f
#define BATT_SAMPLE_MS     1000

#define ECG_SAMPLE_HZ      250
#define ECG_FRAME_SAMPLES  8
#define TELEMETRY_MS       250

// ====================================================================
// BLE UUIDS (must match the app)
// ====================================================================

static const char* SERVICE_UUID     = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
static const char* DEVICE_INFO_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
static const char* LIVE_VITALS_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
static const char* ECG_STREAM_UUID  = "6e400004-b5a3-f393-e0a9-e50e24dcca9e";
static const char* CONTROL_UUID     = "6e400005-b5a3-f393-e0a9-e50e24dcca9e";

// ====================================================================
// STATE
// ====================================================================

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

BLEServer* pServer = nullptr;
BLECharacteristic* pLiveVitals = nullptr;
BLECharacteristic* pEcgStream   = nullptr;

volatile bool deviceConnected = false;
volatile bool connectEventPending = false;
volatile bool disconnectEventPending = false;
bool oldDeviceConnected = false;
volatile bool ecgStreaming = false;

// ---------------- ECG pipeline ----------------

#define RING_BITS  9
#define RING_SIZE  (1 << RING_BITS)
#define RING_MASK  (RING_SIZE - 1)

volatile int16_t ringBuf[RING_SIZE];
volatile uint16_t ringHead = 0;
volatile uint16_t ringTail = 0;

int16_t  frameBuf[ECG_FRAME_SAMPLES];
uint8_t  frameFill = 0;
volatile uint16_t ecgSeq = 0;

hw_timer_t* ecgTimer = nullptr;

// ---------------- R-peak detector state ----------------

float dcEma       = 2048.0f;
float hpPrev      = 0.0f;
float runningPeak = 0.0f;
uint32_t lastPeakMs = 0;
int      refractory = 0;

#define RR_LEN 4
uint32_t rrHist[RR_LEN] = {0, 0, 0, 0};
uint8_t  rrCount = 0;
uint8_t  rrIdx   = 0;

uint8_t  currentBpm    = 0;
uint16_t lastRrMs      = 0;
uint8_t  ecgQuality    = 0;
bool     rPeakPulse    = false;
uint32_t lastBeatSeenMs = 0;

// ---------------- touch / led / battery / status ----------------

bool touchState = false;
bool previousTouchState = false;

bool oledInitialized = false;
int  latestEcgRaw = 0;
bool leadOff = true;

uint8_t  batteryPercent = 0;
float    batteryVolts   = 0.0f;

unsigned long lastTelemetry = 0;
unsigned long lastOledUpdate = 0;
unsigned long lastSerialUpdate = 0;
unsigned long lastBattRead = 0;

// live-screen animation state
uint8_t  heartScale = 0;          // 0..3, driven by real beats
uint32_t sparkleAt = 0;           // sparkle timer after a beat

struct LEDPattern { bool active; bool state; int flashesRemaining; unsigned long lastChange; };
LEDPattern ledPattern = { false, false, 0, 0 };

// ====================================================================
// LED helper
// ====================================================================

void startLEDPattern(int count) {
  if (count <= 0) return;
  ledPattern.active = true;
  ledPattern.state = true;
  ledPattern.flashesRemaining = count;
  ledPattern.lastChange = millis();
  digitalWrite(LED_PIN, HIGH);
}

void updateLEDPattern() {
  if (!ledPattern.active) return;
  unsigned long now = millis();
  if (ledPattern.state) {
    if (now - ledPattern.lastChange >= 150) {
      digitalWrite(LED_PIN, LOW);
      ledPattern.state = false;
      ledPattern.lastChange = now;
    }
  } else {
    if (now - ledPattern.lastChange >= 150) {
      ledPattern.flashesRemaining--;
      if (ledPattern.flashesRemaining <= 0) {
        ledPattern.active = false;
        digitalWrite(LED_PIN, LOW);
        return;
      }
      digitalWrite(LED_PIN, HIGH);
      ledPattern.state = true;
      ledPattern.lastChange = now;
    }
  }
}

// ====================================================================
// HEART ICON (drawn from primitives, scales with s)
// ====================================================================

void drawHeart(int cx, int cy, int s) {
  // two circles + triangle; cx,cy is the vertical center of the lobes
  display.fillCircle(cx - s, cy, s, SSD1306_WHITE);
  display.fillCircle(cx + s, cy, s, SSD1306_WHITE);
  display.fillTriangle(cx - 2 * s, cy, cx + 2 * s, cy, cx, cy + 2 * s, SSD1306_WHITE);
}

// ====================================================================
// BOOT SHOW (runs once, blocking, before BLE starts)
// ====================================================================

void bootShow() {
  if (!oledInitialized) { startLEDPattern(3); return; }

  // --- act 1: expanding rings saying "waking up" -----------------
  for (int r = 2; r <= 40; r += 6) {
    display.clearDisplay();
    display.drawCircle(64, 32, r, SSD1306_WHITE);
    if (r > 10) display.drawCircle(64, 32, r / 2, SSD1306_WHITE);
    display.display();
    delay(45);
  }
  delay(120);

  // --- act 2: typewriter ------------------------------------------
  const char* title = "SSAI-SENSE-01";
  int len = strlen(title);
  for (int i = 0; i <= len; i++) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(28, 26);
    for (int j = 0; j < i; j++) display.write(title[j]);
    if (i < len) display.write('_');            // blinking cursor
    display.setCursor(34, 42);
    display.setTextSize(1);
    display.println(F("vitals, honestly"));
    display.display();
    delay(70);
  }
  delay(250);

  // --- act 3: heart beats hello -----------------------------------
  for (int beat = 0; beat < 2; beat++) {
    for (int s = 2; s <= 6; s++) {              // grow = thump in
      display.clearDisplay();
      drawHeart(64, 26, s);
      display.setTextSize(1);
      display.setCursor(44, 48);
      display.print(F("Hello! :)"));
      display.display();
      delay(40);
    }
    for (int s = 6; s >= 2; s--) {              // shrink = relax
      display.clearDisplay();
      drawHeart(64, 26, s);
      display.setTextSize(1);
      display.setCursor(44, 48);
      display.print(F("Hello! :)"));
      display.display();
      delay(40);
    }
  }
  delay(150);

  // --- act 4: checklist wipes in ----------------------------------
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println(F("SSAI-SENSE-01 v1.5"));
  display.drawLine(0, 9, 127, 9, SSD1306_WHITE);
  const char* items[] = { "ECG front end", "touch sensor", "battery gauge", "BLE radio" };
  for (int i = 0; i < 4; i++) {
    display.setCursor(0, 14 + i * 12);
    display.print(F("[+] "));
    display.print(items[i]);
    display.display();
    delay(160);
  }
  delay(350);

  startLEDPattern(3);                            // 3 boot blinks
}

// ====================================================================
// 250 Hz sample timer -- ONLY samples; DSP runs in the main loop.
// ====================================================================

void IRAM_ATTR onEcgTimer() {
  int raw = adc1_get_raw(ADC1_CHANNEL_0);
  ringBuf[ringHead] = (int16_t)raw;
  ringHead = (ringHead + 1) & RING_MASK;
}

// ====================================================================
// R-PEAK DETECTOR
// ====================================================================

void processSample(int16_t raw) {
  const uint32_t nowMs = millis();

  dcEma += ((float)raw - dcEma) * 0.004f;
  const float hp = (float)raw - dcEma;

  const float notch = (hp + hpPrev) * 0.5f;
  hpPrev = hp;

  const float sig = fabsf(notch);

  if (sig > runningPeak) runningPeak = sig;
  else runningPeak *= 0.9995f;
  if (runningPeak < 1.0f) runningPeak = 1.0f;

  const float threshold = runningPeak * 0.6f;

  if (refractory > 0) refractory--;

  if (sig > threshold && refractory == 0) {
    const uint32_t rr = nowMs - lastPeakMs;
    lastPeakMs  = nowMs;
    refractory  = (int)(0.180f * ECG_SAMPLE_HZ);

    if (rr >= 300 && rr <= 2000) {
      rrHist[rrIdx] = rr;
      rrIdx   = (rrIdx + 1) % RR_LEN;
      if (rrCount < RR_LEN) rrCount++;
      lastRrMs      = (uint16_t)rr;
      lastBeatSeenMs = nowMs;
      rPeakPulse    = true;
      sparkleAt     = nowMs;                     // trigger sparkle

      uint32_t sum = 0;
      for (int i = 0; i < rrCount; i++) sum += rrHist[i];
      const uint32_t avgRr = sum / rrCount;
      const uint32_t bpm   = 60000UL / avgRr;
      if (bpm >= 40 && bpm <= 200) currentBpm = (uint8_t)bpm;
    }
  }

  if (leadOff) {
    ecgQuality = 0;
  } else if (nowMs - lastBeatSeenMs > 4000) {
    ecgQuality = 20;
  } else {
    float q = 40.0f + (runningPeak / 25.0f);
    if (q > 92.0f) q = 92.0f;
    if (q < 15.0f) q = 15.0f;
    ecgQuality = (uint8_t)q;
  }

  if (leadOff || nowMs - lastBeatSeenMs > 8000) {
    currentBpm = 0;
    lastRrMs   = 0;
  }
}

// ====================================================================
// BATTERY (GPIO35, 100k/100k divider)
// ====================================================================

void updateBattery() {
  unsigned long now = millis();
  if (now - lastBattRead < BATT_SAMPLE_MS) return;
  lastBattRead = now;

  int raw = adc1_get_raw(ADC1_CHANNEL_7);
  batteryVolts = ((float)raw / 4095.0f) * 3.3f * BATT_DIVIDER;

  float pct = (batteryVolts - BATT_V_EMPTY) / (BATT_V_FULL - BATT_V_EMPTY) * 100.0f;
  if (pct < 0.0f)   pct = 0.0f;
  if (pct > 100.0f) pct = 100.0f;
  batteryPercent = (uint8_t)pct;
}

// ====================================================================
// BLE CALLBACKS
// ====================================================================

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) override {
    deviceConnected = true;
    connectEventPending = true;
    Serial.println(F("[BLE] CONNECTED"));
  }
  void onDisconnect(BLEServer* server) override {
    deviceConnected = false;
    ecgStreaming = false;
    disconnectEventPending = true;
    Serial.println(F("[BLE] DISCONNECTED"));
  }
};

class ControlCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    String rx = pChar->getValue();
    if (rx.length() == 0) return;
    uint8_t command = (uint8_t)rx[0];
    Serial.printf("[CONTROL] 0x%02X\n", command);
    if (command == 0xA1) {
      ecgStreaming = true;
      ecgSeq = 0;
      Serial.println(F("[ECG] STREAM START"));
    } else if (command == 0xA0) {
      ecgStreaming = false;
      Serial.println(F("[ECG] STREAM STOP"));
    }
  }
};

// ====================================================================
// TOUCH (active LOW) / LEAD-OFF
// ====================================================================

void updateTouch() {
  bool newTouchState = (digitalRead(TOUCH_PIN) == LOW);
  if (newTouchState != touchState) {
    delay(5);
    if ((digitalRead(TOUCH_PIN) == LOW) == newTouchState) {
      touchState = newTouchState;
      if (touchState && !previousTouchState) Serial.println(F("[TOUCH] PRESS"));
      previousTouchState = touchState;
    }
  }
}

void updateLeadOff() {
  bool loP = digitalRead(ECG_LO_PLUS_PIN);
  bool loN = digitalRead(ECG_LO_MINUS_PIN);
  leadOff = loP || loN;
  latestEcgRaw = ringBuf[(ringHead - 1) & RING_MASK];
}

// ====================================================================
// LIVE OLED (animated, ~10 Hz)
// ====================================================================

void updateOLED() {
  if (!oledInitialized) return;
  unsigned long now = millis();
  if (now - lastOledUpdate < 100) return;        // ~10 Hz, smooth motion
  lastOledUpdate = now;

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // ---- heart scale from real physiology -------------------------
  // thump: big right after a beat, relaxes over ~350 ms;
  // idle: gentle breathing so the screen never looks frozen.
  int s;
  uint32_t sinceBeat = now - sparkleAt;
  if (currentBpm > 0 && sinceBeat < 350) {
    s = 4 - (int)(sinceBeat / 120);              // 4 -> relaxed
  } else {
    s = 1 + ((now / 900) % 2);                   // breathing 1..2
  }
  heartScale = (uint8_t)s;

  drawHeart(14, 8, s);

  // sparkle right after a detected beat
  if (now - sparkleAt < 120) {
    display.drawLine(14, 0, 14, 2, SSD1306_WHITE);
    display.drawLine(6, 8, 8, 8, SSD1306_WHITE);
    display.drawLine(20, 8, 22, 8, SSD1306_WHITE);
  }

  // ---- BPM headline ----------------------------------------------
  display.setTextSize(2);
  display.setCursor(34, 4);
  if (currentBpm > 0) {
    display.print(currentBpm);
    display.setTextSize(1);
    display.print(F(" BPM"));
  } else {
    display.print(F("--"));
    display.setTextSize(1);
    display.print(leadOff ? F(" leads off") : F(" listening"));
  }

  // ---- status row -------------------------------------------------
  display.setCursor(0, 22);
  display.setTextSize(1);
  display.print(deviceConnected ? F("BLE:CONN") : F("BLE:WAIT"));
  display.setCursor(64, 22);
  display.print(F("S:"));
  display.print(ecgStreaming ? F("ON") : F("OFF"));
  display.setCursor(100, 22);
  display.print(batteryPercent);
  display.print(F("%"));

  // ---- quality bar with shimmer ----------------------------------
  display.setCursor(0, 32);
  display.print(F("Q"));
  display.drawRect(12, 32, 84, 7, SSD1306_WHITE);
  int fillW = (int)((ecgQuality / 100.0f) * 82);
  if (fillW > 0) display.fillRect(13, 33, fillW, 5, SSD1306_WHITE);
  // shimmer: 2 px highlight sweeping across the filled part
  int shim = (int)((now / 60) % 84);
  if (shim < fillW) {
    display.drawLine(13 + shim, 33, 13 + shim, 37, SSD1306_BLACK);
  }
  display.setCursor(100, 32);
  display.print(ecgQuality);

  // ---- live ECG strip across the bottom ---------------------------
  // 128 px wide, 20 px tall, scrolling real samples from the ring.
  const int baseY = 62;
  const int midY  = 52;
  int prevY = midY;
  uint16_t idx = (ringHead - 256) & RING_MASK;   // last ~1 s of data
  float lo = 4095.0f, hi = 0.0f;
  // quick auto-scale pass
  for (int x = 0; x < 128; x++) {
    float v = (float)ringBuf[(idx + x * 2) & RING_MASK];
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  if (hi - lo < 50.0f) { float m = (hi + lo) / 2; hi = m + 25; lo = m - 25; }
  for (int x = 0; x < 128; x++) {
    float v = (float)ringBuf[(idx + x * 2) & RING_MASK];
    int y = midY - (int)(((v - (hi + lo) / 2) / (hi - lo)) * (baseY - 42));
    if (y < 42) y = 42;
    if (y > baseY) y = baseY;
    if (x > 0) display.drawLine(x - 1, prevY, x, y, SSD1306_WHITE);
    prevY = y;
  }

  display.display();
}

// ====================================================================
// BLE SENDERS
// ====================================================================

void startBLEAdvertising() {
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMaxPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println(F("[BLE] Advertising started."));
}

void sendEcgFrames() {
  if (!deviceConnected || !ecgStreaming || pEcgStream == nullptr) {
    frameFill = 0;
    return;
  }
  if (frameFill < ECG_FRAME_SAMPLES) return;

  uint8_t packet[20];
  packet[0] = 0x02;
  packet[1] = 0x01;
  packet[2] = ecgSeq & 0xFF;
  packet[3] = (ecgSeq >> 8) & 0xFF;
  memcpy(&packet[4], frameBuf, 16);
  ecgSeq++;

  pEcgStream->setValue(packet, 20);
  pEcgStream->notify();

  frameFill = 0;
}

void sendTelemetry() {
  if (!deviceConnected || pLiveVitals == nullptr) return;
  unsigned long now = millis();
  if (now - lastTelemetry < TELEMETRY_MS) return;
  lastTelemetry = now;

  uint8_t t[20];
  memset(t, 0, sizeof(t));
  t[0] = 0x01;
  t[1] = 0x01;
  t[2] = currentBpm;
  t[3] = 0;                                        // SpO2: not measured
  t[6] = lastRrMs & 0xFF;
  t[7] = (lastRrMs >> 8) & 0xFF;
  t[8] = ecgQuality;
  uint8_t flags = 0;
  if (rPeakPulse) flags |= 0x01;
  if (leadOff)    flags |= 0x04;
  t[9] = flags;
  t[14] = batteryPercent;
  t[15] = 0x00;
  uint32_t up = (uint32_t)now;
  memcpy(&t[16], &up, 4);

  rPeakPulse = false;

  pLiveVitals->setValue(t, 20);
  pLiveVitals->notify();
}

// ====================================================================
// SETUP
// ====================================================================

void setup() {
  Serial.begin(115200);
  delay(800);

  Serial.println();
  Serial.println(F("================================================"));
  Serial.println(F("           SSAI-SENSE-01  firmware v1.5"));
  Serial.println(F("  real R-peaks, real battery, boot show, live UI"));
  Serial.println(F("================================================"));

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // LED greeting: one long hello blink while the OLED wakes up
  digitalWrite(LED_PIN, HIGH);
  delay(200);
  digitalWrite(LED_PIN, LOW);

  pinMode(TOUCH_PIN, INPUT_PULLUP);

  pinMode(ECG_LO_PLUS_PIN, INPUT);
  pinMode(ECG_LO_MINUS_PIN, INPUT);
  pinMode(ECG_SDN_PIN, OUTPUT);
  digitalWrite(ECG_SDN_PIN, HIGH);
  Serial.println(F("[ECG] SDN = HIGH (front end on)"));

  adc1_config_width(ADC_WIDTH_BIT_12);
  adc1_config_channel_atten(ADC1_CHANNEL_0, ADC_ATTEN_DB_11);
  adc1_config_channel_atten(ADC1_CHANNEL_7, ADC_ATTEN_DB_11);
  Serial.println(F("[ADC] GPIO36 ECG + GPIO35 battery, 12-bit"));

  // ---------- OLED ----------
  Wire.begin(21, 22);
  Wire.setClock(400000);
  delay(50);
  if (display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    oledInitialized = true;
    Serial.println(F("[OLED] PASS"));
  } else {
    Serial.println(F("[OLED] FAIL"));
  }

  // ---------- the boot show ----------
  bootShow();

  // ---------- 250 Hz timer (Core 3.x API) ----------
  ecgTimer = timerBegin(1000000);
  if (ecgTimer == nullptr) {
    Serial.println(F("[TIMER] FAIL"));
  } else {
    timerAttachInterrupt(ecgTimer, &onEcgTimer);
    timerAlarm(ecgTimer, 4000, true, 0);
    Serial.println(F("[TIMER] 250 Hz sampling ON"));
  }

  // ---------- BLE ----------
  BLEDevice::init("SSAI-SENSE-01");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  BLECharacteristic* pInfo = pService->createCharacteristic(
      DEVICE_INFO_UUID, BLECharacteristic::PROPERTY_READ);
  pInfo->setValue("1.5.0");

  pLiveVitals = pService->createCharacteristic(
      LIVE_VITALS_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pLiveVitals->addDescriptor(new BLE2902());

  pEcgStream = pService->createCharacteristic(
      ECG_STREAM_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pEcgStream->addDescriptor(new BLE2902());

  BLECharacteristic* pControl = pService->createCharacteristic(
      CONTROL_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  pControl->setCallbacks(new ControlCallbacks());

  pService->start();
  startBLEAdvertising();

  Serial.println(F("[READY] scan as SSAI-SENSE-01"));
}

// ====================================================================
// MAIN LOOP
// ====================================================================

void loop() {
  updateLEDPattern();

  if (connectEventPending) {
    connectEventPending = false;
    startLEDPattern(5);                            // 5 fast blinks
  }
  if (disconnectEventPending) {
    disconnectEventPending = false;
    startLEDPattern(1);                            // 1 blink
    delay(300);
    startBLEAdvertising();
  }
  if (deviceConnected && !oldDeviceConnected) oldDeviceConnected = true;
  if (!deviceConnected && oldDeviceConnected) oldDeviceConnected = false;

  while (ringTail != ringHead) {
    int16_t s = ringBuf[ringTail];
    ringTail = (ringTail + 1) & RING_MASK;

    if (frameFill < ECG_FRAME_SAMPLES) frameBuf[frameFill++] = s;
    processSample(s);
  }

  sendEcgFrames();
  sendTelemetry();
  updateTouch();
  updateLeadOff();
  updateBattery();
  updateOLED();

  if (millis() - lastSerialUpdate >= 1000) {
    lastSerialUpdate = millis();
    Serial.printf("[STAT] BLE:%s stream:%s lead:%s hr:%u q:%u adc:%d bat:%u%%\n",
                  deviceConnected ? "CONN" : "WAIT",
                  ecgStreaming ? "ON" : "OFF",
                  leadOff ? "OFF-BODY" : "CONTACT",
                  currentBpm, ecgQuality, latestEcgRaw, batteryPercent);
  }

  delay(1);
}
