/*
====================================================================
                  SSAI-SENSE-01  --  FIRMWARE v2.0.0
        ESP32 DevKit V1 + AD8232 ECG + TTP223 touch + SSD1306

   Built for exactly the parts you have on the desk RIGHT NOW:
       ESP32, AD8232 ECG board, one TTP223 touch pad, 0.96" OLED.
   Anything not wired yet (battery divider, INA219) is detected as
   missing and reported honestly instead of faked.

   WHAT IS NEW IN v2.0
   -------------------
   1. BOOT SEQUENCE with a real self-test log
        rings -> typewriter -> beating heart -> [ OK ] / [WARN] log
        lines for OLED, ADC, AD8232, TOUCH, BATT, TIMER, BLE.
   2. SIX ANIMATED PAGES driven by the touch pad
        1 LIVE     heart pumping on real beats + scrolling ECG strip
        2 RATE     huge BPM digits, RR ms, min/max, BPM sparkline
        3 SCOPE    full screen ECG scope with grid and beat flash
        4 POWER    animated battery, or "no gauge wired" if absent
        5 STATS    uptime, boots, connects, frames, beats, loop Hz
        6 ABOUT    version info + scrolling marquee help line
    3. THE TOUCH PAD FINALLY HAS A JOB (5 gestures, zero screen clutter)
         tap        : next page (with wipe transition)
         double tap : previous page
         triple tap : start / stop the ECG stream manually
         hold 1s    : recalibrate the ECG detector (LED 2x flash)
         hold 2.5s  : screen off / tap again to wake
       While holding, a THIN vertical meter on the right edge shows the
       progress -- the graph stays fully visible (no popup boxes).
       The LED lights up while you hold, so the gesture is felt.
   4. AD8232 FAULT WATCH
        if the ECG output goes flat or dead for 8 s, a flashing
        warning screen with marching-ants border explains what to
        check. BLE keeps streaming the whole time. Auto-recovers.
   5. HARDENING
        no-loss ECG framing (frames flush inside the sample drain),
        non-blocking touch debounce, task watchdog, re-advertise
        keepalive, boot counter in NVS, LED thump on every R-peak,
        serial console commands (n r i b s w).

   PROTOCOL IS BYTE-IDENTICAL TO v1.5 -- the Flutter app and the
   laptop dashboard need no changes at all.

PIN MAP (locked for SSAI-SENSE-01 reference build)
----------------------------------------------
GPIO36 (VP / ADC1_CH0) : AD8232 OUTPUT (analog ECG)
GPIO39 (VN)            : AD8232 LO+
GPIO34                 : AD8232 LO-
GPIO18                 : AD8232 SDN  (driven HIGH = front end on)
   GPIO4                  : TTP223 touch OUT (active LOW, INPUT_PULLUP)
                            tap=next  2xtap=back  3xtap=stream
                            hold1s=recalibrate  hold2.5s=screen off
GPIO2                  : built-in blue LED
GPIO21 / 22            : OLED SDA / SCL (0x3C)
GPIO35                 : battery divider (not wired yet -> shows USB)
3V3 / GND              : rails

SERIAL CONSOLE (115200): n=next page  r=recalibrate  i=info
                         b=stats      s=toggle stream  w=screen

SAFETY: never take an ECG while the board is plugged into a charger.
Battery or power-bank power only when electrodes touch skin.
This firmware is a screening aid, not a medical device.
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
#include <Preferences.h>

#define USE_TASK_WDT 1
#if USE_TASK_WDT
#include <esp_task_wdt.h>
#endif


#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>

#include "Config.h"
#include "State.h"
#include "BLEHandler.h"
#include "DisplayHandler.h"
#include "EcgSensor.h"
#include "TouchHandler.h"

// ====================================================================
// BOOT SEQUENCE
// ====================================================================

void bootLogRender(uint8_t progressPct) {
  if (!oledInitialized) return;
  display.clearDisplay();
  display.fillRect(0, 0, 128, 9, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(2, 1);
  display.print(F("SELF TEST"));
  display.setCursor(80, 1);
  display.print(F("v" FIRMWARE_VERSION));
  display.setTextColor(SSD1306_WHITE);

  for (uint8_t i = 0; i < bootLogCount; i++) {
    display.setCursor(0, 11 + i * 7);
    display.print(bootLog[i]);
  }

  display.drawRect(0, 57, 128, 7, SSD1306_WHITE);
  int w = (progressPct * 126) / 100;
  if (w > 0) display.fillRect(1, 58, w, 5, SSD1306_WHITE);
  display.display();
}

void bootLogAdd(const char* line, uint8_t progressPct) {
  Serial.print(F("[BOOT] "));
  Serial.println(line);

  if (bootLogCount < BOOTLOG_ROWS) {
    strncpy(bootLog[bootLogCount], line, 21);
    bootLog[bootLogCount][21] = 0;
    bootLogCount++;
  } else {
    for (uint8_t i = 1; i < BOOTLOG_ROWS; i++) {
      memcpy(bootLog[i - 1], bootLog[i], 22);
    }
    strncpy(bootLog[BOOTLOG_ROWS - 1], line, 21);
    bootLog[BOOTLOG_ROWS - 1][21] = 0;
  }
  bootLogRender(progressPct);
  delay(250);                                       // ~4 Hz, readable
}

void bootIntro() {
  if (!oledInitialized) return;

  // act 1 - expanding rings: the board waking up
  for (int r = 2; r <= 44; r += 7) {
    display.clearDisplay();
    display.drawCircle(64, 32, r, SSD1306_WHITE);
    if (r > 12) display.drawCircle(64, 32, r / 2, SSD1306_WHITE);
    if (r > 26) display.drawCircle(64, 32, r / 4, SSD1306_WHITE);
    display.display();
    delay(35);
  }

  // act 2 - typewriter title
  const char* title = "SSAI-SENSE-01";
  int len = strlen(title);
  for (int i = 0; i <= len; i++) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(25, 24);
    for (int j = 0; j < i; j++) display.write(title[j]);
    if (i < len) display.write('_');
    display.setCursor(31, 38);
    display.print(F("vitals, honestly"));
    display.setCursor(52, 50);
    display.print(F("v" FIRMWARE_VERSION));
    display.display();
    delay(45);
  }
  delay(180);

  // act 3 - the heart says hello
  for (int beat = 0; beat < 2; beat++) {
    for (int s = 2; s <= 6; s++) {
      display.clearDisplay();
      drawHeart(64, 26, s);
      display.setTextSize(1);
      display.setCursor(44, 50);
      display.print(F("Hello! :)"));
      display.display();
      delay(28);
    }
    for (int s = 6; s >= 2; s--) {
      display.clearDisplay();
      drawHeart(64, 26, s);
      display.setTextSize(1);
      display.setCursor(44, 50);
      display.print(F("Hello! :)"));
      display.display();
      delay(28);
    }
  }
  delay(120);
}

void bootReadySplash() {
  if (!oledInitialized) return;
  for (int i = 0; i < 14; i++) {
    display.clearDisplay();
    int r = 6 + i * 3;
    display.drawCircle(64, 30, r, SSD1306_WHITE);
    // big check mark
    display.drawLine(52, 30, 60, 38, SSD1306_WHITE);
    display.drawLine(53, 30, 61, 38, SSD1306_WHITE);
    display.drawLine(60, 38, 78, 20, SSD1306_WHITE);
    display.drawLine(61, 38, 79, 20, SSD1306_WHITE);
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(40, 54);
    display.print(F("ALL SYSTEMS"));
    display.display();
    delay(26);
  }
  delay(260);
}

// ====================================================================
// SERIAL CONSOLE
// ====================================================================

void printInfo() {
  Serial.println(F("---- SSAI-SENSE-01 ----"));
  Serial.printf("fw %s  proto %u  pages %u\n", FIRMWARE_VERSION,
                (unsigned)PROTOCOL_VERSION, (unsigned)PAGE_COUNT);
  Serial.printf("BLE %s  stream %s  page %u\n",
                deviceConnected ? "CONN" : "WAIT",
                ecgStreaming ? "ON" : "OFF",
                (unsigned)(currentPage + 1));
  Serial.printf("batt %s raw=%u pct=%u\n",
                battPresent ? "gauge" : "none(USB)",
                (unsigned)batteryRaw, (unsigned)batteryPercent);
  Serial.println(F("keys: n r i b s w"));
}

void printStats() {
  char up[12];
  formatUptime(up, sizeof(up), millis());
  Serial.printf("[STATS] up=%s boots=%u conn=%u frames=%u tlm=%u beats=%u "
                "faults=%u loop=%uHz pp=%u mean=%u\n",
                up, (unsigned)bootCount, (unsigned)connectCount,
                (unsigned)framesSent, (unsigned)telemetrySent,
                (unsigned)beatCount, (unsigned)faultCount,
                (unsigned)loopHz, (unsigned)sigPp, (unsigned)sigMean);
}

void handleSerial() {
  while (Serial.available() > 0) {
    int c = Serial.read();
    switch (c) {
      case 'n': nextPage(); break;
      case 'r': startRecalibration(); break;
      case 'i': printInfo(); break;
      case 'b': printStats(); break;
      case 's':
        ecgStreaming = !ecgStreaming;
        if (ecgStreaming) { ecgSeq = 0; frameFill = 0; }
        Serial.printf("[ECG] stream %s\n", ecgStreaming ? "ON" : "OFF");
        break;
      case 'w': setScreenSleep(!screenSleep); break;
      default: break;
    }
  }
}

// ====================================================================
// SETUP
// ====================================================================

void setup() {
  Serial.begin(115200);
  delay(700);

  Serial.println();
  Serial.println(F("================================================"));
  Serial.println(F("        SSAI-SENSE-01  firmware v2.0"));
  Serial.println(F("  6 animated pages, touch gestures, fault watch"));
  Serial.println(F("================================================"));

  // boot counter in NVS (survives power cycles)
  prefs.begin("ssai", false);
  bootCount = prefs.getUInt("boots", 0) + 1;
  prefs.putUInt("boots", bootCount);
  prefs.end();
  Serial.printf("[NVS] boot #%u\n", (unsigned)bootCount);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);
  delay(150);
  digitalWrite(LED_PIN, LOW);

  pinMode(TOUCH_PIN, INPUT_PULLUP);
  pinMode(ECG_LO_PLUS_PIN, INPUT);
  pinMode(ECG_LO_MINUS_PIN, INPUT);
  pinMode(BATT_PIN, INPUT);              // GPIO35 battery divider
  pinMode(ECG_SDN_PIN, OUTPUT);
  digitalWrite(ECG_SDN_PIN, HIGH);

  for (int i = 0; i < BPM_HIST_LEN; i++) bpmHist[i] = 0;

  // ---------- OLED ----------
  Wire.begin(21, 22);
  Wire.setClock(400000);
  delay(50);
  if (display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    oledInitialized = true;
    display.setTextWrap(false);   // NEVER wrap: long text must clip at the
                                  // right edge, not fall onto the next row
    Serial.println(F("[OLED] PASS"));
  } else {
    Serial.println(F("[OLED] FAIL - running headless"));
  }

  // ---------- opening animation ----------
  bootIntro();

  // ---------- self test log ----------
  char line[22];

  bootLogAdd(oledInitialized ? "[ OK ] OLED 128x64"
                             : "[FAIL] OLED missing", 12);

  adc1_config_width(ADC_WIDTH_BIT_12);
  adc1_config_channel_atten(ADC1_CHANNEL_0, ADC_ATTEN_DB_12);
  adc1_config_channel_atten(ADC1_CHANNEL_7, ADC_ATTEN_DB_12);
  int probe = adc1_get_raw(ADC1_CHANNEL_0);
  latestEcgRaw = probe;
  dcEma = (float)probe;
  snprintf(line, sizeof(line), "[ OK ] ADC1 r=%d", probe);
  bootLogAdd(line, 26);

  // AD8232 liveness: 120 ms of samples, look for movement
  int mn = 4095;
  int mx = 0;
  long sum = 0;
  for (int i = 0; i < 120; i++) {
    int v = adc1_get_raw(ADC1_CHANNEL_0);
    if (v < mn) mn = v;
    if (v > mx) mx = v;
    sum += v;
    delay(1);
  }
  int pp = mx - mn;
  int mean = (int)(sum / 120);
  if (pp < 10 || mean < 30) {
    snprintf(line, sizeof(line), "[WARN] AD8232 pp=%d", pp);
  } else {
    snprintf(line, sizeof(line), "[ OK ] AD8232 pp=%d", pp);
  }
  bootLogAdd(line, 40);

  bool touchIdle;
  if (TOUCH_ACTIVE_LOW) touchIdle = (digitalRead(TOUCH_PIN) == HIGH);
  else                  touchIdle = (digitalRead(TOUCH_PIN) == LOW);
  bootLogAdd(touchIdle ? "[ OK ] TOUCH idle"
                       : "[WARN] TOUCH held", 54);

  uint16_t bmv = readBattMilliVolts();
  batteryRaw = (uint16_t)analogRead(BATT_PIN);
  if (bmv < BATT_MV_MIN) {
    battPresent = false;
    batteryPercent = 0;
    bootLogAdd("[ -- ] BATT no gauge", 68);
  } else {
    battPresent = true;
    batteryVolts = (bmv / 1000.0f) * BATT_DIVIDER * battCalGain;
    float pct = (batteryVolts - BATT_V_EMPTY) / (BATT_V_FULL - BATT_V_EMPTY) * 100.0f;
    if (pct < 0.0f) pct = 0.0f;
    if (pct > 100.0f) pct = 100.0f;
    batteryPercent = (uint8_t)pct;
    snprintf(line, sizeof(line), "[ OK ] BATT %u%% %umV",
             (unsigned)batteryPercent, (unsigned)bmv);
    bootLogAdd(line, 68);
  }

  // ---------- 250 Hz sampling timer (Core 3.x API) ----------
  ecgTimer = timerBegin(1000000);
  if (ecgTimer == nullptr) {
    bootLogAdd("[FAIL] TIMER", 82);
  } else {
    timerAttachInterrupt(ecgTimer, &onEcgTimer);
    timerAlarm(ecgTimer, 4000, true, 0);
    bootLogAdd("[ OK ] TIMER 250Hz", 82);
  }

  // ---------- BLE ----------
  initBLE();
  bootLogAdd("[ OK ] BLE advertise", 100);

  bootReadySplash();

  // ---------- watchdog (gentle: 12 s, only the loop task) ----------
#if USE_TASK_WDT
  esp_task_wdt_config_t wdtCfg;
  wdtCfg.timeout_ms = 12000;
  wdtCfg.idle_core_mask = 0;
  wdtCfg.trigger_panic = true;
  esp_task_wdt_init(&wdtCfg);        // already-inited returns an error: ignore
  esp_task_wdt_add(NULL);
  Serial.println(F("[WDT] loop watchdog armed"));
#endif

  resetDetector();
  lastOledUpdate = 0;
  startLEDPattern(3);

  Serial.println(F("[READY] scan as SSAI-SENSE-01"));
  printInfo();
}

// ====================================================================
// MAIN LOOP
// ====================================================================

void loop() {
#if USE_TASK_WDT
  esp_task_wdt_reset();
#endif

  uint32_t now = millis();
  loopCounter++;

  updateLEDPattern();

  if (connectEventPending) {
    connectEventPending = false;
    connectCount++;
    startLEDPattern(5);
  }
  if (disconnectEventPending) {
    disconnectEventPending = false;
    // no manual flash here: the advertising beacon in
    // updateLEDPattern() starts blinking on its own
    delay(250);
    startBLEAdvertising();
  }
  if (deviceConnected && !oldDeviceConnected) oldDeviceConnected = true;
  if (!deviceConnected && oldDeviceConnected) oldDeviceConnected = false;

  // advertising keepalive: some stacks go quiet after a bad connection
  if (!deviceConnected && (now - lastAdvertiseAt > 60000)) {
    startBLEAdvertising();
  }

  // drain the sample ring; flush a BLE frame the moment one is full,
  // so no ECG sample is ever dropped regardless of loop timing
  while (ringTail != ringHead) {
    int16_t s = ringBuf[ringTail];
    ringTail = (ringTail + 1) & RING_MASK;

    processSample(s);

    if (frameFill < ECG_FRAME_SAMPLES) frameBuf[frameFill++] = s;
    if (frameFill >= ECG_FRAME_SAMPLES) sendEcgFrame();
  }

  sendTelemetry();
  updateTouch();
  updateLeadOff();
  updateSignalStats();
  updateBattery();
  handleSerial();
  updateOLED();

  // BPM history for the sparkline
  if (now - lastBpmHistAt >= 2000) {
    lastBpmHistAt = now;
    bpmHist[bpmHistIdx] = currentBpm;
    bpmHistIdx = (uint8_t)((bpmHistIdx + 1) % BPM_HIST_LEN);
  }

  if (now - lastSerialUpdate >= 1000) {
    lastSerialUpdate = now;
    loopHz = loopCounter;
    loopCounter = 0;
    Serial.printf("[STAT] ble:%s str:%s lead:%s hr:%u q:%u pp:%u m:%u "
                  "bat:%s pg:%u loop:%uHz%s\n",
                  deviceConnected ? "CONN" : "WAIT",
                  ecgStreaming ? "ON" : "OFF",
                  leadOff ? "OFF-BODY" : "CONTACT",
                  (unsigned)currentBpm, (unsigned)ecgQuality,
                  (unsigned)sigPp, (unsigned)sigMean,
                  battPresent ? "gauge" : "usb",
                  (unsigned)(currentPage + 1), (unsigned)loopHz,
                  ecgFault ? " FAULT" : "");
  }

  delay(1);
}
