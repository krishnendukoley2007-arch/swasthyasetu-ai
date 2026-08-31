#pragma once
#ifndef STATE_H
#define STATE_H

#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <BLEServer.h>
#include <Preferences.h>
#include "Config.h"

// ---------------- STATE ----------------

extern Adafruit_SSD1306 display;
extern Preferences prefs;

extern BLEServer* pServer;
extern BLECharacteristic* pLiveVitals;
extern BLECharacteristic* pEcgStream;

extern volatile bool deviceConnected;
extern volatile bool connectEventPending;
extern volatile bool disconnectEventPending;
extern bool oldDeviceConnected;
extern volatile bool ecgStreaming;

extern bool advertisingConfigured;
extern uint32_t lastAdvertiseAt;

// ---------------- ECG pipeline ----------------

extern volatile int16_t ringBuf[RING_SIZE];
extern volatile uint16_t ringHead;
extern volatile uint16_t ringTail;

extern int16_t  frameBuf[ECG_FRAME_SAMPLES];
extern uint8_t  frameFill;
extern volatile uint16_t ecgSeq;

extern hw_timer_t* ecgTimer;

// ---------------- R-peak detector ----------------

extern float dcEma;
extern float hpPrev;
extern float runningPeak;
extern uint32_t lastPeakMs;
extern int      refractory;

#define RR_LEN 4
extern uint32_t rrHist[RR_LEN];
extern uint8_t  rrCount;
extern uint8_t  rrIdx;

extern uint8_t  currentBpm;
extern uint16_t lastRrMs;
extern uint8_t  ecgQuality;
extern bool     rPeakPulse;
extern uint32_t lastBeatSeenMs;

// ---------------- signal health / fault ----------------

extern uint16_t sigPp;
extern uint16_t sigMean;
extern bool     sigSaturated;
extern bool     ecgFault;
extern uint32_t badSince;
extern uint32_t goodSince;
extern uint32_t lastSigCalc;

// ---------------- touch ----------------

extern bool touchRaw;
extern bool touchStable;
extern bool pressActive;
extern bool pressConsumed;
extern uint32_t touchEdgeAt;
extern uint32_t pressStartAt;

extern uint8_t  pendingTaps;
extern uint32_t lastTapAt;

// ---------------- pages / screen ----------------

extern uint8_t  currentPage;
extern uint32_t transitionUntil;
extern uint32_t recalUntil;
extern uint32_t wakeFlashUntil;
extern bool     screenSleep;
extern bool     oledInitialized;

// ---------------- battery / misc sensors ----------------

extern bool     battPresent;
extern uint8_t  batteryPercent;
extern float    batteryVolts;
extern uint16_t batteryRaw;
extern float    battCalGain;

extern int  latestEcgRaw;
extern bool leadOff;

// ---------------- stats ----------------

extern uint32_t bootCount;
extern uint32_t connectCount;
extern uint32_t framesSent;
extern uint32_t telemetrySent;
extern uint32_t beatCount;
extern uint32_t faultCount;
extern uint8_t  bpmMin;
extern uint8_t  bpmMax;

extern uint32_t loopCounter;
extern uint32_t loopHz;

#define BPM_HIST_LEN 32
extern uint8_t  bpmHist[BPM_HIST_LEN];
extern uint8_t  bpmHistIdx;
extern uint32_t lastBpmHistAt;

// ---------------- timing ----------------

extern uint32_t lastTelemetry;
extern uint32_t lastOledUpdate;
extern uint32_t lastSerialUpdate;
extern uint32_t lastBattRead;

// ---------------- animation ----------------

extern uint32_t sparkleAt;
extern uint32_t beatLedUntil;

struct LEDPattern { bool active; bool state; int flashesRemaining; uint32_t lastChange; };
extern LEDPattern ledPattern;

// ---------------- boot log ----------------

#define BOOTLOG_ROWS 7
extern char bootLog[BOOTLOG_ROWS][22];
extern uint8_t bootLogCount;

#endif
