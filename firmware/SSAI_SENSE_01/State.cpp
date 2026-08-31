#include "State.h"

// ---------------- STATE ----------------

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
Preferences prefs;

BLEServer* pServer = nullptr;
BLECharacteristic* pLiveVitals = nullptr;
BLECharacteristic* pEcgStream = nullptr;

volatile bool deviceConnected = false;
volatile bool connectEventPending = false;
volatile bool disconnectEventPending = false;
bool oldDeviceConnected = false;
volatile bool ecgStreaming = false;

bool advertisingConfigured = false;
uint32_t lastAdvertiseAt = 0;

// ---------------- ECG pipeline ----------------

volatile int16_t ringBuf[RING_SIZE];
volatile uint16_t ringHead = 0;
volatile uint16_t ringTail = 0;

int16_t  frameBuf[ECG_FRAME_SAMPLES];
uint8_t  frameFill = 0;
volatile uint16_t ecgSeq = 0;

hw_timer_t* ecgTimer = nullptr;

// ---------------- R-peak detector ----------------

float dcEma = 2048.0f;
float hpPrev = 0.0f;
float runningPeak = 0.0f;
uint32_t lastPeakMs = 0;
int      refractory = 0;

uint32_t rrHist[RR_LEN] = {0, 0, 0, 0};
uint8_t  rrCount = 0;
uint8_t  rrIdx = 0;

uint8_t  currentBpm = 0;
uint16_t lastRrMs = 0;
uint8_t  ecgQuality = 0;
bool     rPeakPulse = false;
uint32_t lastBeatSeenMs = 0;

// ---------------- signal health / fault ----------------

uint16_t sigPp = 0;
uint16_t sigMean = 0;
bool     sigSaturated = false;
bool     ecgFault = false;
uint32_t badSince = 0;
uint32_t goodSince = 0;
uint32_t lastSigCalc = 0;

// ---------------- touch ----------------

bool touchRaw = false;
bool touchStable = false;
bool pressActive = false;
bool pressConsumed = false;
uint32_t touchEdgeAt = 0;
uint32_t pressStartAt = 0;

uint8_t  pendingTaps = 0;
uint32_t lastTapAt = 0;

// ---------------- pages / screen ----------------

uint8_t  currentPage = PAGE_LIVE;
uint32_t transitionUntil = 0;
uint32_t recalUntil = 0;
uint32_t wakeFlashUntil = 0;
bool     screenSleep = false;
bool     oledInitialized = false;

// ---------------- battery / misc sensors ----------------

bool     battPresent = false;
uint8_t  batteryPercent = 0;
float    batteryVolts = 0.0f;
uint16_t batteryRaw = 0;
float    battCalGain = 1.0f;

int  latestEcgRaw = 0;
bool leadOff = true;

// ---------------- stats ----------------

uint32_t bootCount = 0;
uint32_t connectCount = 0;
uint32_t framesSent = 0;
uint32_t telemetrySent = 0;
uint32_t beatCount = 0;
uint32_t faultCount = 0;
uint8_t  bpmMin = 0;
uint8_t  bpmMax = 0;

uint32_t loopCounter = 0;
uint32_t loopHz = 0;

uint8_t  bpmHist[BPM_HIST_LEN];
uint8_t  bpmHistIdx = 0;
uint32_t lastBpmHistAt = 0;

// ---------------- timing ----------------

uint32_t lastTelemetry = 0;
uint32_t lastOledUpdate = 0;
uint32_t lastSerialUpdate = 0;
uint32_t lastBattRead = 0;

// ---------------- animation ----------------

uint32_t sparkleAt = 0;
uint32_t beatLedUntil = 0;

LEDPattern ledPattern = { false, false, 0, 0 };

// ---------------- boot log ----------------

char bootLog[BOOTLOG_ROWS][22];
uint8_t bootLogCount = 0;

// ---------------- BLE UUID Definitions ----------------

const char* SERVICE_UUID     = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const char* DEVICE_INFO_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
const char* LIVE_VITALS_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
const char* ECG_STREAM_UUID  = "6e400004-b5a3-f393-e0a9-e50e24dcca9e";
const char* CONTROL_UUID     = "6e400005-b5a3-f393-e0a9-e50e24dcca9e";
