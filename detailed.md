# SwasthyaSetu AI — Complete Project Documentation

**Version:** 1.3.0 (build 4)  
**Date:** 2026-08-29  
**Target Problem Statement:** SIH 26181 (Qualcomm Inc, Category: Hardware, Theme: MedTech/BioTech/HealthTech)  
**Board Revision:** SSAI-SENSE-01 (Rev 2.0)

---

## 1. PROBLEM STATEMENT

### 1.1 What We Are Solving

Community health workers (ASHAs, ANMs, NGOs) in rural India perform door-to-door health screenings but face critical gaps:

| Gap | Impact |
|-----|--------|
| **No continuous vitals** | Phone sensors cannot measure SpO₂, ECG, or skin temperature while phone is asleep/in pocket |
| **No fall detection that survives screen-off** | Android kills foreground accelerometer streams; workers/patients fall unwitnessed |
| **No offline triage** | Cloud-dependent tools fail in areas with poor connectivity |
| **No plain-language explanation** | Workers get numbers (HR=108, SpO₂=94) but not "what this means" or "what to do" |
| **No audit trail** | Screenings vanish after the visit — no history, no community dashboard, no sync when online |

**SIH 26181 specifically demands:** A hardware + software solution for **community health screening** that works **offline-first**, provides **actionable triage**, and includes **environmental hazard awareness** (heat, air quality).

---

## 2. HOW WE SOLVE IT — ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SWASTHYASETU AI SYSTEM                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    BLE GATT (20-byte frames)    ┌─────────────┐   │
│  │  HARDWARE    │◀────────────────────────────────▶│  ANDROID    │   │
│  │  BOARD       │  31.25 Hz ECG  │  4 Hz vitals   │  APP        │   │
│  │  (ESP32)     │                                    │  (Flutter)  │   │
│  └──────────────┘                                    └──────┬──────┘   │
│        │                                                    │          │
│        │  Sensors:                                            │          │
│        │  • MAX30102 (PPG/SpO₂ @ 100 Hz)                     │          │
│        │  • AD8232 (ECG Lead I @ 250 Hz)                     │          │
│        │  • MLX90614 (IR skin temp)                          │          │
│        │  • MPU6050 (fall detection IMU)                     │          │
│        │  • BME280 (ambient T/RH/pressure)                   │          │
│        │                                                    ▼          │
│        │  ┌─────────────────────────────────────────────────────────┐ │
│        │  │              APP LAYER (Offline-First)                  │ │
│        │  │                                                         │ │
│        │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │ │
│        │  │  │ SCREENING│  │  TRIAGE  │  │ EXPLAIN  │              │ │
│        │  │  │  FLOW    │──│  ENGINE  │──│  (2-tier)│              │ │
│        │  │  └──────────┘  └──────────┘  └────┬─────┘              │ │
│        │  │                                     │                  │ │
│        │  │  ┌──────────┐  ┌──────────┐  ┌─────┴─────┐             │ │
│        │  │  │ PATIENTS │  │  SOS/    │  │  ENV/     │             │ │
│        │  │  │  + HIST  │  │  FALL    │  │  TRENDS   │             │ │
│        │  │  └──────────┘  └──────────┘  └───────────┘             │ │
│        │  │                                     │                  │ │
│        │  │  ┌──────────────────────────────────┴──────────────┐   │ │
│        │  │  │           LOCAL SQLITE (Drift)                   │   │ │
│        │  │  │  Patients • Screenings • Waveforms • Guidelines  │   │ │
│        │  │  │  Sync Queue • Explanations • SOS Log             │   │ │
│        │  │  └──────────────────────────────────────────────────┘   │ │
│        │  └─────────────────────────────────────────────────────────┘ │
│        │                                                             │
└────────┴─────────────────────────────────────────────────────────────┘
```

### 2.2 Core Design Principles (Enforced in Code)

| Principle | Implementation |
|-----------|----------------|
| **One-way provenance** | `isDemo` flag on every `HealthSample` — measured data can never become demo, demo data can never masquerade as measured |
| **Storage stays English** | Only UI labels translate; DB, exports, rules share one vocabulary |
| **No fabricated gaps** | Missing values render as `—`, never `0` or guesses |
| **Rules decide, AI explains** | `RiskEngine` is the **only** code permitted to write `TriageResult.level/score`; Gemini never sees a risk-level field in its output schema |
| **Deterministic, auditable** | Same inputs → same triage every time; 428 unit tests enforce this |

---

## 3. DETAILED SOLUTION — HOW IT WORKS

### 3.1 Screening Flow (3-Step Wizard)

```
NewScreeningScreen (3 pages)
    │
    ├─ Step 1: Patient Selection
    │   └─ Local SQLite roster → pick or "Add New Patient"
    │
    ├─ Step 2: Device Connection
    │   ├─ Scan for "SSAI-SENSE-01" (or name prefix swasthyasetu/ssai/ss-)
    │   ├─ GATT handshake: discover service UUID 6e400001-...
    │   ├─ Read firmware version from device-info characteristic
    │   ├─ Subscribe to:
    │   │   • Live vitals notify (UUID ...0003) → 4 Hz telemetry
    │   │   • ECG stream notify (UUID ...0004) → 31.25 Hz (8 samples/frame)
    │   │   • Control write (UUID ...0005) → 0xA1 start, 0xA0 stop
    │   └─ Auto-reconnect on drop (exponential backoff: 1,2,4,8,16,30s)
    │
    └─ Step 3: Instructions
        └─ Visual guide: finger on PPG, 3-lead ECG, forehead temp, stay still
```

**Key UX Decision:** The **DEMO/LIVE badge** is decided *once* at screening start (`_isDemo = !bleLink.isLive`) and **never changes mid-run**. A disconnection shows a "Reconnecting" banner but never silently swaps generated numbers behind a reading the worker already trusts.

### 3.2 Live Vitals Acquisition

**Live Mode (board connected):**
- `BleService.beginCapture()` starts accumulating ECG samples in service (not widget)
- Telemetry frames (20 bytes) arrive at 4 Hz → parsed by `BleProtocol.parseTelemetry()`
- ECG frames (8 samples × int16 = 20 bytes payload) arrive at 31.25 Hz
- Sequence numbers tracked → dropped-frame counter surfaced to UI
- On stop: `BleService.endCapture()` returns **full waveform** (service buffer survives reconnects)

**Demo Mode (no board):**
- Synthesised readings every 2 seconds with physiological variation
- ECG waveform regenerated per beat (5-deflection Gaussian model matching displayed HR)
- Every sample carries `isDemo: true` — **impossible to mistake for real data**

### 3.3 Deterministic Triage Engine (`risk_engine.dart`)

**Scoring Model:** Additive with hard cap at 100. Band from score alone:
```
0–30   → GREEN (Routine)
31–60  → YELLOW (Needs attention)  
61–100 → RED (Urgent)
```

**Critical Floor:** Any `RuleSeverity.critical` rule **floors score at 61** — a single life-threatening reading cannot be averaged away by otherwise normal vitals.

**Rule Categories:**

| Category | Rules | Severity | Points |
|----------|-------|----------|--------|
| Oxygen | SpO₂ < critical (90/91/92*), SpO₂ < warning (95/96*), Not measured | Critical/Warning/Advisory | 45/15/0 |
| Heart Rate | Tachycardia critical/warning, Bradycardia critical/warning | Critical/Warning | 35/10 |
| Temperature | High fever, Fever, Hypothermia | Warning/Critical | 25/10/30 |
| Sepsis Screen | Fever + Tachycardia + Hypoxaemia together | Critical | 30 |
| ECG | Irregular rhythm (quality ≥ 0.5), Poor quality (advisory) | Warning/Advisory | 20/0 |
| BP (Experimental) | Systolic ≥ 180 or Diastolic ≥ 110 | Warning | 20 |
| Symptoms | Red flags (chest pain, confusion...), Respiratory, Dehydration (≥2), Multiple (≥3) | Critical/Warning | 25/5–15/15/10 |
| Vulnerability | Elderly, Chronic, Pregnant, Infant, Immunocompromised | Warning | 5–10 |

*Thresholds shift per vulnerability — see §3.5

**Output:** `TriageAssessment` with:
- `band`, `score`, `firedRules[]` (each with id, severity, points, title, detail)
- `thresholds` used, `recommendedAction`, `escalationLevel` (NONE/CLINIC_VISIT/EMERGENCY)
- `sample`, `symptoms`, `flags`, `isDemo`

### 3.4 Two-Tier Explanation System

```
┌────────────────────────────────────────────────────────────────┐
│                    EXPLANATION ARCHITECTURE                     │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TriageAssessment ──▶ OfflineExplainer (always runs)           │
│       │                    │                                    │
│       │                    ▼                                    │
│       │            ┌─────────────┐                              │
│       │            │ 4 sections  │                              │
│       │            │ • Summary   │                              │
│       │            │ • Why level │                              │
│       │            │ • Next steps│                              │
│       │            │ • Escalate  │                              │
│       │            └─────────────┘                              │
│       │                    │                                    │
│       │                    ▼                                    │
│       │            Posted IMMEDIATELY to chat                   │
│       │                    │                                    │
│       │         ┌──────────┴──────────┐                         │
│       │         │                     │                         │
│       │    Settings.aiConsent?    No AI key?                    │
│       │         │                     │                         │
│       │        YES                    NO                        │
│       │         │                     │                         │
│       │         ▼                     ▼                         │
│       │  ExplanationRepository.explainOnline()                  │
│       │         │                     │                         │
│       │         ▼                     │                         │
│       │  GeminiService (Flash 3.6)    │                         │
│       │         │                     │                         │
│       │         ▼                     │                         │
│       │  JSON response ──▶ Replaces  │                         │
│       │  offline bubbles             │                         │
│       │         │                     │                         │
│       │         ▼                     ▼                         │
│       │  Footnote: "Explained online  Footnote: "Explained      │
│       │  by gemini-3.6-flash.        offline from guidelines    │
│       │  Risk band from rule engine" on this phone"              │
│       │                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Key Properties:**
- **Offline-first:** Local explanation renders in <100ms; online upgrades asynchronously
- **Provenance visible:** Every explanation carries footnote stating source
- **Model cannot change triage:** Prompt gives band/score/rules as **fixed facts**; response schema has no risk-level field
- **Audience-aware:** Nurse prompt (referral/monitoring only) vs Patient prompt (home care permitted)
- **Language support:** English, Hindi (Devanagari), Bengali (Bangla)

### 3.5 Vulnerability-Aware Thresholds (`vulnerability.dart`)

**Two kinds of adjustment — order matters:**

```dart
// 1. BASELINE SHIFTS (own their vital) — applied FIRST
Infant:      HR warning 160, critical 180, low warning 100, critical 90
Pregnant:    HR warning 110, critical 135, low warning 55, critical 45

// 2. CAUTION TIGHTENING (escalate earlier) — applied AFTER, only on unshifted vitals
Elderly:     SpO₂ warning 96, critical 91; Fever 37.7/38.6; HR warning 90, critical 115
Chronic:     SpO₂ warning 96, critical 91; HR warning 95, critical 120
Immunocomp:  Fever 37.5/38.5
Infant/Preg: Fever 37.5/38.5 (despite HR shift)
```

**Age implies flags:** Age ≥ 65 → `elderly`; Age < 1 → `infant` (even if unticked).

### 3.6 Environmental Risk Engine (`environmental_rules.dart`)

**Heat (apparent temperature = heat index):**
```
Standard:  Advice ≥32°C, Warning ≥38°C, Danger ≥43°C
Vulnerable: Shift −4°C (Warning at 34°C, Danger at 39°C)
```

**Air Quality (US AQI):**
```
Standard:  51–100 → info (sensitive only); 101–150 → advice; >150 → warning
Vulnerable: 101+ → warning immediately
```

**Cross-Domain Insight (the differentiator):**
- Heat + HR rising above personal baseline → "Your body may be feeling this heat"
- Poor air + SpO₂ dropping below personal baseline → "Your breathing may be feeling this air"
- Uses `TrendEngine` (30-day personal baselines) — not population norms

### 3.7 Fall Detection (Phone + Board)

**Phone-side (`fall_detection_service.dart`):**
- Accelerometer at game interval (~20 ms)
- State machine: `idle` → (|a|<4.0 for ≥80ms) → `freeFall` → (|a|>4.0) → `awaitingImpact` → (|a|≥26 within 1200ms) → **FALL**
- 20s refractory; bare impact without preceding free-fall ignored

**Board-side (firmware, `imu.cpp`):**
- MPU6050 INT → GPIO33 (RTC-capable, `ext1` wake)
- Same thresholds ported exactly so phone and board agree
- On detection: sets telemetry flags bit 1, sounds buzzer, holds 30s

**Both feed same SOS flow** — worker's pocket phone OR patient's cuff can trigger.

### 3.8 Emergency SOS (`sos_screen.dart`, `sos_service.dart`)

**Countdown Design (the safety feature):**
- Configurable countdown (default 10s, set in Settings)
- **Cancel is the big, full-width, first-reachable button**
- Haptic feedback each second; heavy impact at start
- Opens system SMS composer with pre-filled message — **never sends automatically**
- Message includes: trigger, worker name, patient name/age, risk band/score, vitals, location (if consented)
- Every attempt logged (DISPATCHED/CANCELLED/FAILED) with recipient list

### 3.9 Offline Map (`mbtiles_reader.dart`, `offline_tile_map.dart`)

- Bundled `india_lowzoom.mbtiles` (~690 KB, zoom 0–6, OSM ODbL)
- Additional `.mbtiles` files dropped in device `map_tiles` folder auto-imported
- No internet required; tile server runs locally
- Location consent OFF by default — map explicitly says when disabled

### 3.10 Data Persistence (Drift/SQLite)

**Tables:**
| Table | Purpose |
|-------|---------|
| `patients` | Roster with vulnerability flags, sync status |
| `screenings` | Full vitals, triage output, symptoms, location (consented), waveform refs |
| `waveform_blobs` | Metadata only; actual samples stored as gzipped int16 files |
| `devices` | Paired boards, firmware, BP calibration |
| `sync_queue` | PENDING/FAILED operations for upload when online |
| `guideline_cache` | Pre-tokenized corpus for offline retrieval |
| `explanations` | Cached AI/offline explanations per screening per source |
| `emergency_contacts` | SOS recipients |
| `sos_events` | Audit log of every SOS attempt |
| `app_settings` | Key-value preferences |
| `auth_accounts` | Local-first accounts (email PBKDF2 / Google) |

**Waveform Storage:** ECG/PPG samples written to gzipped files (not DB blobs) — 35s @ 250 Hz ≈ 17 KB int16.

### 3.11 Sync (Consent-Gated, Background)

- `SyncService` processes queue when connectivity returns
- Only uploads records where `syncStatus == PENDING`
- Location only included if `settings.locationConsent == true`
- Retry logic with exponential backoff; max 3 retries before marking FAILED

---

## 4. HARDWARE — WHAT WE BUILD

### 4.1 Board Specification (SSAI-SENSE-01)

**Target Problem:** SIH 26181 — Qualcomm Hardware Category

**What the board does that a phone CANNOT:**
1. **Continuous vitals while phone sleeps** — HR, SpO₂, skin temp, ECG streamed over BLE
2. **Fall detection surviving screen-off** — coin-cell MCU with motion interrupt never sleeps through a fall
3. **Body-worn measurements no camera can fake** — real ECG lead, real reflectance PPG, real IR skin temp

**The board is a SENSOR, not a diagnostician.** It never computes risk bands — that boundary is enforced in `risk_engine.dart`.

### 4.2 Sensor Suite

| Sensor | Purpose | Interface | Key Spec |
|--------|---------|-----------|----------|
| **MAX30102** | Pulse oximetry (HR + SpO₂) | I²C1 (GPIO26/27) + INT GPIO19 | 100 Hz, SpO₂ mode, auto LED current |
| **AD8232** | Single-lead ECG (Lead I) | ADC1_CH0 (GPIO36) + LO+/LO− (GPIO39/34) + SDN (GPIO18) | 250 Hz, 0.5–40 Hz analog BW, RLD |
| **MLX90614** | IR skin temperature | I²C0 (GPIO21/22) @ 0x5A | BAA: ±0.5°C, 90° FOV; DCI: ±0.2°C, 5° FOV |
| **MPU6050** | Fall detection (accel/gyro) | I²C0 @ 0x68 + INT GPIO33 | ±8g, 100 Hz, motion interrupt for deep-sleep wake |
| **BME280** | Ambient T/RH/pressure | I²C0 @ 0x76 | ±1°C, ±3% RH, ±1 hPa |
| **SSD1306** | 128×64 OLED status | I²C0 @ 0x3C | 4 Hz refresh (limited by MLX SMBus timing) |

**Optional (stretch):**
- **PMS5003** — Laser PM2.5 (UART2, 5V, duty-cycled) — turns pollution advisory from "API says" to "we measure"
- **DS3231** RTC — timestamps survive flat battery
- **Micro-SD** — local ring buffer when phone out of range

### 4.3 Power Architecture (Critical — Rev 1 Fatal Fix)

**Rev 1 Error (E1):** `Li-ion → AMS1117-3.3 → ESP32` — **FATAL.** AMS1117 needs Vin ≥ 4.4V (1.1V dropout at 800mA). Li-ion spans 4.2V→3.0V → regulator never in regulation. ESP32 browns out on first BLE burst.

**Rev 2 Fix — Option A (Recommended): Buck-Boost**
```
18650 (3.0–4.2V) → TP4056+DW01A → TPS63020 buck-boost (3.3V, 2A) → ESP32 3V3 pin
```
- Boosts when cell < 3.3V, bucks when > 3.3V → flat 3.3V from 4.2V down to ~2.5V
- Uses **whole cell**, not just top 15%
- **100 µF + 100 nF at ESP32 3V3 pins** — non-negotiable (absorbs 240mA BLE transient)

**Option B (Simpler): Boost to 5V → DevKit VIN**
```
18650 → TP4056 → MT3608 (set to 5.0V!) → DevKit VIN → onboard AMS1117 → 3V3
```
- ~72% efficiency → ~14.8h streaming (vs 19.8h)

### 4.4 Runtime on 3000 mAh 18650

| Mode | Current | Runtime |
|------|---------|---------|
| Continuous streaming (BLE 31Hz, ECG+PPG, OLED) | 130 mA | **≈ 19.8 h** |
| Monitoring (PPG duty-cycled 1:10, OLED off) | 63 mA | **≈ 40 h** |
| Idle (BLE advertising) | 26 mA | ≈ 99 h |
| **Deep sleep (fall-watch only)** | **25 µA** | **≈ 11 months** |

**The 11-month fall-watch is the demo.** A phone cannot watch for a fall for 11 months on one charge. Lead with it.

### 4.5 ESP32 Pin Constraints (Hardware Facts, Not Preferences)

| Pins | Constraint |
|------|------------|
| GPIO 6–11 | Wired to SPI flash — **never use** |
| GPIO 34,35,36,37,38,39 | **Input only** — no output driver, no internal pull-up/down |
| ADC2 (GPIO 0,2,4,12–15,25–27) | **Unusable while WiFi active** (hardware erratum) |
| GPIO 0,2,5,12,15 | Strapping pins — GPIO12 high can **brick module** |
| RTC GPIOs (0,2,4,12–15,25–27,32–39) | Only these wake from deep sleep |

**Critical Pin Assignments:**
- ECG → GPIO36 (ADC1_CH0) ✓
- Battery sense → GPIO35 (ADC1_CH7) ✓
- AD8232 LO+/LO− → GPIO39/34 (input-only, push-pull) ✓
- MAX30102 INT → GPIO19 (needs pull-up, can't use 34–39) ✓
- MPU6050 INT → GPIO33 (RTC, `ext1` wake, active-HIGH) ✓
- Wake button → GPIO32 (RTC, **switch to 3V3 + pull-down**, active-HIGH) ✓

### 4.6 BLE Protocol (Wire Format — Must Match Exactly)

**Service UUID:** `6e400001-b5a3-f393-e0a9-e50e24dcca9e` (Nordic UART style)

**Telemetry Frame (20 bytes, little-endian, 4 Hz):**
```
0:  uint8  frame_type = 0x01
1:  uint8  protocol_version = 1
2:  uint8  heart_rate (bpm, 25–250)
3:  uint8  SpO2 (%) 50–100, 0=not measured
4-5: int16  temperature ×100 (3650 = 36.50°C, range 2000–4500)
6-7: uint16 last R-R interval (ms)
8:  uint8  ECG quality 0–100 (<50 = NOISY)
9:  uint8  flags: bit0=R-peak, bit1=fall, bit2=lead-off, bit3=finger-off
10-11: uint16 PTT (ms)
12:  uint8  estimated systolic (mmHg)
13:  uint8  estimated diastolic (mmHg)
14:  uint8  battery %
15:  uint8  BP confidence (0=LOW,1=MEDIUM,2=HIGH,≥3=EXPERIMENTAL)
16-19: uint32 device uptime (ms)
```

**ECG Frame (20 bytes payload = 4 header + 8×int16 samples, 31.25 Hz):**
```
0:  uint8  frame_type = 0x02
1:  uint8  protocol_version = 1
2-3: uint16 sequence (wraps at 65535)
4-19: int16[8] samples (little-endian)
```
**Hard constraint:** 8 samples/frame max — default ATT MTU=23 → 20 bytes payload. 9 samples = silent drop.

**Advertising:** Name `SSAI-SENSE-01` **AND** service UUID in adv packet. No `DEMO_` prefix (that marks app's synthetic device).

### 4.7 ECG Front-End (Firmware DSP Chain)

1. **DC baseline removal** — single-pole HPF 0.5 Hz (AD8232 does analog; second stage kills residual drift)
2. **50 Hz notch** — biquad Q≈30 (**India is 50 Hz mains, not 60**) — single highest-value filter
3. **Low-pass** — 40 Hz 2-pole Butterworth (removes EMG)
4. **R-peak detection** — Pan-Tompkins-lite: differentiate → square → 150ms moving-window integrate → adaptive threshold 0.6×running peak, 200ms refractory
5. **Quality score 0–100** (telemetry byte 8):
   - Start at 100
   - LO+/LO− asserted → **0** (flags bit 2)
   - Subtract residual 50 Hz power after notch
   - Subtract if R-peak amplitude/noise-floor < 5
   - Subtract if successive R-R differ > 50%
   - **Phone treats <50 as unusable** — honesty essential

### 4.8 SpO₂ — The Honesty Boundary

**Reflectance PPG (MAX30102) is not a medical pulse oximeter.**
- Perfusion Index gate: PI < 0.2 → report SpO₂ = 0 (not measured)
- **Never emit a made-up 97%** — `0` is the "not measured" sentinel; `RiskEngine` scores it as advisory (0 points)
- Calibration: `SpO₂ ≈ 110 − 25×R` (literature default, ±4% on light skin at rest, degrades with motion/cold/darker skin)
- **Required:** Paired comparison against ₹1,200 fingertip oximeter, 30 readings across 5 people, fit own `a,b`, report MAE on screen

### 4.9 Temperature — Part Number Decision

| Variant | FOV | Accuracy | Spot at 3cm | Cost | Verdict |
|---------|-----|----------|-------------|------|---------|
| MLX90614ESF-BAA | 90° | ±0.5°C | **6 cm** | ₹460 | On every cheap breakout. Averages forehead+hair+air. **Trend only.** |
| MLX90614ESF-DCI | **5°** | **±0.2°C** medical | **0.26 cm** | ₹1,650 | **Only way to honestly claim fever detection. Buy this.** |

**Measurement procedure:** 2–3 cm, perpendicular, dry forehead (temporal), 8 readings @ 2Hz → median, emissivity 0.98, ambient sanity gate (<16°C ambient → report 0).

### 4.10 Cuffless BP — Kept Experimental

- PTT = t(PPG foot) − t(ECG R-peak) [ms, byte 10-11]
- SBP ≈ a − b·ln(PTT) — **requires per-subject cuff calibration, drifts in hours**
- **No regulator has cleared cuffless PTT for unsupervised use**
- **Implementation:** Transmit PTT (real, correctly measured). Set byte 15 = `0xFF` → label `EXPERIMENTAL` → `RiskEngine` skips it entirely. UI: "Experimental — not a blood pressure measurement."

### 4.11 Safety Interlock (Non-Negotiable)

**NEVER take ECG while board is plugged into USB charger.**

With USB connected, patient's chest electrodes share ground reference with mains earth through charger. Cheap unisolated charger can leak 100s of µA to earth → current path runs through patient.

**Firmware MUST enforce:**
```c
if (digitalRead(CHG_STAT) == LOW) {     // charger present
    digitalWrite(ECG_SDN, LOW);         // AD8232 hard off
    ecg_streaming_enabled = false;
    oled_banner("UNPLUG CHARGER TO MEASURE");
    quality = 0; flags |= 0x04;         // lead-off
}
```
- Printed label on enclosure saying the same
- Battery-only during any measurement on a person
- 1.5A polyfuse in series with B+ (₹15)

---

## 5. REMEDIES — WHAT WE FIXED FROM REV 1

| # | Rev-1 Defect | Fix in Rev 2 |
|---|--------------|--------------|
| **E1** | LDO (AMS1117) from bare Li-ion — board dead below 3.6V | Buck-boost (TPS63020) or boost→VIN. Uses whole cell. |
| **E2** | Claimed ±0.2°C temp accuracy with BAA part | Honest spec: BAA ±0.5°C. DCI variant required for fever claim. |
| **E3** | MPU6050 INT absent — no deep-sleep fall detection | INT → GPIO33 (RTC, `ext1` wake, active-HIGH) |
| **E4** | LO+/LO− on GPIO32/33 with pull-downs (burns RTC wake pins) | LO+→GPIO39, LO−→GPIO34 (input-only, no pulls) |
| **E5** | All 4 I²C devices on one bus — MAX30102 1.8V pull-ups back-driven | MAX30102 on **separate I²C1** (GPIO26/27), no external pull-ups |

**Additional Rev 2 Corrections:**
- ✅ Heat danger tier in `environmental_rules.dart:144` was dead code (both >=43 and >=38 returned warning) — **Fixed (returns `AdvisoryLevel.danger`)**
- MLX90614 SMBus timing caps I²C0 at 100 kHz — documented, OLED limited to 4 Hz
- Battery divider 100k/100k (21 µA drain) + 100nF + Li-ion discharge curve lookup table (not linear)
- AD8232 analog ground → star-point to regulator GND (not daisy-chained through OLED/buzzer)

---

## 6. FUTURE ASPECTS — WHAT COMES NEXT

### 6.1 Immediate (Pre-Hackathon)

1. **Fix heat-danger tier** in `environmental_rules.dart:144` — flagship hazard in PS 26181
2. **Order core BOM + spares** (₹6,200) — build and backup
3. **Create `firmware/platformio.ini`** — fixes red CI job
4. **Transcribe `ble_protocol.h`** from Dart + `static_assert(sizeof==20)`
5. **Run validation protocol (§18 of HARDWARE.md):**
   - Bland-Altman plots for HR/SpO₂ vs reference oximeter
   - Fall detection: ≥90% sensitivity on drops, **≤2 false positives per 50 ADLs**
   - Battery runtime within 20% of prediction
   - Deep-sleep current < 100 µA
   - BLE frame integrity < 0.1% dropped frames

### 6.2 Near-Term (Post-Hackathon)

| Feature | Effort | Value |
|---------|--------|-------|
| **DCI temperature sensor (MLX90614ESF-DCI)** | ₹1,190 | Honest fever detection (±0.2°C, 5° FOV) |
| **PMS5003 PM2.5 sensor** | ₹1,450 | Measured local pollution vs interpolated API |
| **WBGT measurement** | ₹250 (black globe) + ADS1115 (₹180) | **Real differentiator** — nobody at hackathon measures WBGT |
| **Micro-SD ring buffer** | ₹90 | Local retention when phone out of range |
| **DS3231 RTC** | ₹120 | Timestamps survive flat battery |

### 6.3 Medium-Term

- **Clinical validation study** — ethics approval, CDSCO registration path
- **Multi-language voice prompts** — for workers with low literacy
- **Federated learning** — on-device model personalization without data leaving phone
- **Telemedicine integration** — seamless handoff to eSanjeevani/PHC
- **Hardware v2** — custom PCB (not DevKit), integrated battery, IP54 enclosure

### 6.4 Long-Term Vision

**SwasthyaSetu as a platform:**
- Community health worker toolkit (screening + education + referral)
- District-level dashboard (aggregated, anonymized, DPDPA-compliant)
- AI-assisted outbreak detection from clustered screening patterns
- Integration with Ayushman Bharat Health Account (ABHA)

---

## 7. BUSINESS ASPECTS

### 7.1 Target Users & Market

| Segment | Size (India) | Pain Point | Willingness |
|---------|--------------|------------|-------------|
| **ASHAs/ANMs** | ~1.3M | Paper registers, no vitals, no decision support | Govt procurement / NGO funded |
| **NGO health programs** | 5,000+ orgs | Offline data collection, reporting burden | Grant-funded |
| **Corporate CSR / Occupational health** | Factory sites, construction | Worker safety compliance (heat, falls) | Direct B2B |
| **Telemedicine platforms** | eSanjeevani, 1mg, Practo | Pre-screening data quality | API partnership |

### 7.2 Business Model

| Revenue Stream | Description |
|----------------|-------------|
| **Hardware margin** | Board BOM ~₹5,000 → sell ₹8,000–10,000 (60–100% margin) |
| **SaaS/Platform** | District dashboard, analytics, sync backend — ₹50k–2L/yr |
| **Training/Certification** | Worker onboarding, clinical protocol training — per-head |
| **Data insights (anonymized)** | Heat-stress maps, outbreak early warning — govt/insurance |

### 7.3 Competitive Landscape

| Competitor | Gap vs SwasthyaSetu |
|------------|---------------------|
| **mHealth apps (CommCare, Dimagi)** | Cloud-dependent, no hardware vitals, no offline map |
| **Consumer wearables (GoQii, Noise)** | Not clinical grade, no ECG, no fall detection on patient, no triage |
| **Medical devices (Philips, GE)** | ₹50k–5L, hospital-grade, not for community workers |
| **Government apps (ANMOL, RCH)** | Data entry only, no vitals, no decision support, often online-only |

**Our Moat:** Hardware + software co-design, offline-first architecture, deterministic safety-critical triage, honest limitations stated upfront.

### 7.4 Regulatory & Compliance

| Requirement | Status |
|-------------|--------|
| **Medical Device (CDSCO)** | NOT registered — explicitly a **screening/triage aid**, not diagnostic. Every screen + docs state this. |
| **Data Protection (DPDPA 2023)** | Local-first; location consent OFF by default; no PII leaves device without consent |
| **IEC 60601** | NOT certified — battery-only operation during measurement is entire safety argument |
| **Clinical Validation** | NOT done — validation protocol defined (§18), to be executed post-hackathon |

### 7.5 Go-to-Market Strategy

1. **Hackathon Demo (SIH 26181)** → Visibility, potential govt/NGO partnerships
2. **Pilot with 1 NGO** (100 workers, 3 months) → Real-world validation, Bland-Altman data
3. **State NHM proposal** → Bulk procurement for ASHA kits
4. **CSR partnerships** → Factory/construction site occupational health
5. **Open-source community** → MIT license, firmware + app on GitHub → adoption, contributions

### 7.6 Cost Structure (Per Unit at Scale)

| Component | Qty 1 | Qty 1000 | Notes |
|-----------|-------|----------|-------|
| Core BOM | ₹5,011 | ~₹3,200 | Volume pricing on sensors, PCBA |
| Enclosure (PETG, outsourced) | ₹600 | ₹180 | Injection mold at scale |
| Assembly & test | ₹400 | ₹150 | Jig-based, automated |
| **Total COGS** | **~₹6,000** | **~₹3,500** | |
| **Target Price** | **₹8,000** | **₹6,000** | 40–60% gross margin |

---

## 8. TECHNICAL DEEP-DIVE — KEY CODE PATHS

### 8.1 Screening → Triage → Save Pipeline

```dart
// 1. LiveVitalsScreen captures sample (live or demo)
ref.read(screeningDraftProvider.notifier).setSample(sample, ecgSamples, ecgSampleRate);

// 2. SymptomsScreen captures symptoms
ref.read(screeningDraftProvider.notifier).setSymptoms(symptoms, duration, notes);

// 3. TriageResultScreen.didChangeDependencies():
_triageResult = RiskEngine.evaluateWithPatient(
  sample: draft.sample!,
  symptoms: draft.symptoms,
  patient: draft.patient!,
);

// 4. SAME SCREEN persists (not a separate "Save" button):
await screeningRepository.save(screening, ecgSamples, ecgSampleRate);
draft.markSaved(id);

// 5. Auto-opens explanation (push, not replace — preserves SOS button underneath)
context.push('/screening/ai-explanation', extra: {...});
```

### 8.2 BLE Service — Never Throws, Auto-Reconnects, Holds Capture

```dart
// State machine: unsupported → adapterOff → permissionDenied → idle
//                    scanning → connecting → discovering → handshaking
//                    streaming → reconnecting (backoff) → failed

// Capture survives reconnect:
service.beginCapture();           // clears service buffer
// ... frames arrive, accumulate in service._capturedEcg ...
captured = service.endCapture();  // returns full waveform, clears buffer
```

### 8.3 Risk Engine — Pure, Deterministic, Testable

```dart
// No network, no randomness, no clock reads beyond caller input
static TriageAssessment assess({
  required HealthSample sample,
  required List<String> symptoms,
  int age = 30,
  Set<Vulnerability> flags = const {},
}) {
  final thresholds = VitalThresholds.forPatient(age: age, flags: flags);
  final fired = <FiredRule>[];
  
  _evaluateOxygen(sample, thresholds, fired);
  _evaluateHeartRate(sample, thresholds, fired);
  _evaluateTemperature(sample, thresholds, fired);
  _evaluateSepsisScreen(sample, thresholds, fired);
  _evaluateEcg(sample, fired);
  _evaluateBloodPressure(sample, fired);
  _evaluateSymptoms(symptoms, fired);
  _evaluateVulnerability(flags, fired);
  
  var score = fired.fold(0, (sum, r) => sum + r.points);
  if (fired.any((r) => r.isCritical) && score < 61) score = 61;
  score = score.clamp(0, 100);
  
  return TriageAssessment(band: bandForScore(score), ...);
}
```

### 8.4 Offline Explainer — Template-Based, Guideline-Retrieved

```dart
static AIExplanation build({
  required TriageAssessment assessment,
  List<RetrievedChunk> retrieved = const [],
  String? patientName,
}) {
  // 1. Build query from fired rules + symptoms + flags
  // 2. Retrieve matching guideline chunks (offline TF-IDF)
  // 3. Fill 4-section template with retrieved text verbatim
  // 4. Add disclaimer + provenance footnote
}
```

### 8.5 Trend Engine — Personal Baselines, Not Population Norms

```dart
// 30-day window, prior readings only (latest excluded from baseline)
static VitalTrend _extract(List<Screening> screenings, double Function(Screening) pick) {
  final points = screenings
      .where((s) => !s.timestamp.isBefore(cutoff) && pick(s) > 0)
      .map((s) => TrendPoint(s.timestamp, pick(s)))
      .toList()..sort((a,b) => a.at.compareTo(b.at));
  
  final latest = points.last.value;
  final priors = points.length > 1 ? points.sublist(0, points.length-1) : [];
  final average = priors.isEmpty ? 0 : priors.map((p)=>p.value).reduce((a,b)=>a+b)/priors.length;
  
  return VitalTrend(points, average, latest, priors.isEmpty ? null : latest - average);
}

// Significance thresholds (physiological, not sensor noise):
// HR ±10 bpm, SpO₂ −2%, Temp +0.7°C
```

---

## 9. TESTING & QUALITY ASSURANCE

### 9.1 Test Coverage (428 Tests Passing)

| Test Suite | Focus |
|------------|-------|
| `risk_engine_test.dart` | Every rule, every vulnerability combo, critical floor, score clamping |
| `ecg_classifier_test.dart` | Quality gates, irregularity threshold, rate/interval agreement |
| `trend_engine_test.dart` | Baseline math, significance bands, empty/insufficient history |
| `environmental_rules_test.dart` | Heat/AQI bands, vulnerable shifts, cross-domain combos |
| `ble_protocol_test.dart` | Frame parsing, bounds, sequence continuity, malformed rejection |
| `ble_diagnostics_test.dart` | Sample rate measurement, gap counting |
| `fall_detector_test.dart` | State machine with synthetic sequences (idle→freefall→impact) |
| `overflow_test.dart` | **All screens render at 2.0× text scale without overflow** |
| `localization_test.dart` | EN/HI/BN all keys present, no missing translations |
| `scan_regressions_test.dart` | Device scan sorting, sensor-board recognition |

### 9.2 Critical Test Invariants

- **Overflow test:** Every screen tested at `textScaleFactor: 2.0` — layouts built to survive, not clamp
- **Offline-map honesty:** Map explicitly says "location off" instead of showing empty terrain
- **Demo/Live separation:** `isDemo` flag tested end-to-end — demo data never reaches triage as real
- **BLE frame integrity:** `static_assert(sizeof(telemetry_frame_t) == 20)` in firmware + Dart parser rejects ≠20 bytes

---

## 10. DEPLOYMENT & OPERATIONS

### 10.1 Build Commands

```bash
# Prerequisites: Flutter 3.47+ / Dart 3.13+
flutter pub get
flutter test                    # 428 tests
flutter build apk --release --split-per-abi

# With Gemini key (compile-time):
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key

# Or runtime: Settings → AI → paste Google AI Studio key
```

### 10.2 APK Variants

| APK | Size | Architecture | Use Case |
|-----|------|--------------|----------|
| `SwasthyaSetu-fixed.apk` | ~74 MB | Universal (arm64+arm32) | **Recommended — works everywhere** |
| `app-release-arm64.apk` | ~32 MB | arm64 only | Most phones since 2018 |
| `app-release.apk` | ~74 MB | Universal | Alternative |

### 10.3 Permissions — All Optional, All Transparent

| Permission | Purpose | If Denied |
|------------|---------|-----------|
| Bluetooth / Nearby Devices | Connect sensor board | Vitals stay in demo mode |
| Location | Tag screenings for community map | Map disabled; screenings save without coords |
| Internet | Online AI + optional sync | Everything else works; offline explanations used |
| Camera | Scan patient/device QR codes | Enter details manually |
| Foreground Service | Keep BLE alive during screening | Session may drop if app backgrounded |

---

## 11. KNOWN LIMITATIONS (Stated Honestly)

1. **Not a medical device** — No CDSCO registration, no IEC 60601, no clinical validation
2. **ECG is single-lead, 250 Hz** — Adequate for rate/rhythm regularity; cannot assess ST segments, ischaemia, or substitute 12-lead
3. **SpO₂ is uncalibrated** — ±4% MAE on light skin at rest; degrades with motion, cold, darker skin; **least reliable below 90%**
4. **Temperature is skin, not core** — ±0.5°C on BAA part; ambient <16°C makes it meaningless
5. **BP is experimental** — Contributes **zero** to triage score by design
6. **No galvanic isolation** — Battery-only during measurement; charging + measuring mutually exclusive
7. **Fall detection has false positives** — Measure the rate; detector nobody leaves on has 0% field sensitivity
8. **BLE range ~10m line-of-sight** — Companion to phone in same room/pocket, not telemetry base station
9. **No on-board retention** without SD module — samples lost if phone out of range
10. **Consumer breakouts** — No temp compensation, no traceable calibration, batch variation

---

## 12. PRESENTATION CHECKLIST (For Hackathon PPT)

### Must-Have Slides

- [ ] **Problem:** Community health worker gaps + SIH 26181 mapping
- [ ] **Solution:** Hardware + Software co-design, offline-first
- [ ] **Hardware:** Board photo, BOM table, power architecture (buck-boost fix), deep-sleep 11-month claim
- [ ] **BLE Protocol:** 20-byte frame diagram, 31.25 Hz ECG, 4 Hz vitals
- [ ] **Triage Engine:** Scoring table, critical floor, vulnerability shifts
- [ ] **Two-Tier AI:** Offline instant + online upgrade, provenance badges
- [ ] **Fall Detection:** Dual (phone + board), 20s refractory, SOS countdown
- [ ] **Environmental:** Heat index + AQI + **personal baseline cross-domain**
- [ ] **Validation Data:** Bland-Altman plots, fall false-positive count, battery runtime
- [ ] **Demo Flow:** Live screening → triage → explanation → SOS (on device + phone)
- [ ] **Business:** BOM cost, target price, pilot plan, regulatory honesty
- [ ] **Limitations Slide:** The 10 items above — stated before judges ask

### Physical Demo Artifacts

- [ ] **Two complete boards** (one backup) — spares of ESP32, MAX30102, MPU6050, OLED
- [ ] **Bland-Altman printed plots** (HR + SpO₂)
- [ ] **Fall detection log** showing ≤2 false positives / 50 ADLs
- [ ] **APK installed on demo phone** (universal build)
- [ ] **Enclosure** (laser-cut acrylic sandwich — shows sensors, looks deliberate)

---

## 13. FILE INDEX — KEY CODE LOCATIONS

| Area | File |
|------|------|
| **App Entry** | `lib/main.dart` |
| **Routing** | `lib/core/routing/app_router.dart` |
| **Theme** | `lib/core/theme/app_theme.dart` |
| **Database** | `lib/data/database/app_database.dart` |
| **Risk Engine** | `lib/domain/rules/risk_engine.dart` |
| **Vulnerability Thresholds** | `lib/domain/rules/vulnerability.dart` |
| **ECG Classifier** | `lib/domain/rules/ecg_classifier.dart` |
| **Offline Explainer** | `lib/domain/rules/offline_explainer.dart` |
| **Guideline Retriever** | `lib/domain/rules/guideline_retriever.dart` |
| **Environmental Rules** | `lib/domain/rules/environmental_rules.dart` |
| **Trend Engine** | `lib/domain/rules/trend_engine.dart` |
| **BLE Service** | `lib/core/services/ble_service.dart` |
| **BLE Protocol** | `lib/core/services/ble_protocol.dart` |
| **Gemini Service** | `lib/core/services/gemini_service.dart` |
| **Fall Detection** | `lib/core/services/fall_detection_service.dart` |
| **SOS Service** | `lib/core/services/sos_service.dart` |
| **Environment Service** | `lib/core/services/environment_service.dart` |
| **MBTiles Reader** | `lib/core/services/mbtiles_reader.dart` |
| **Screening Flow** | `lib/features/screening/screens/` (new, live, symptoms, triage, ai_explanation) |
| **Emergency** | `lib/features/emergency/screens/sos_screen.dart` |
| **Devices** | `lib/features/devices/screens/` (scan, connection, diagnostics) |
| **Patients** | `lib/features/patients/screens/` (list, add, profile) |
| **History** | `lib/features/history/screens/` |
| **Community** | `lib/features/community/screens/community_dashboard_screen.dart` |
| **Settings** | `lib/features/settings/screens/settings_screen.dart` |
| **Hardware Docs** | `hardware/HARDWARE.md`, `hardware/hardware-schematic.svg` |
| **Firmware** | `ai_context_bundle/firmware/` (drivers, BLE, PTT estimator) |

---

## 14. LICENSE & ATTRIBUTION

| Asset | License |
|-------|---------|
| Application code | MIT |
| Bundled map tiles | © OpenStreetMap contributors • ODbL |
| Inter typeface | SIL OFL 1.1 |
| Firmware libraries | Respective library licenses (NimBLE, Adafruit, SparkFun) |

---

## 15. MEDICAL DISCLAIMER (Repeated from README — Critical)

> **This software is a screening and triage-support tool for trained community health workers.**  
> It does **not** diagnose, treat, or prescribe. Its risk bands come from **fixed threshold rules**, not clinical judgment.  
> **Do not use as sole basis for care decisions. Do not use in place of emergency services.**

---

*This document is the single source of truth for the SwasthyaSetu AI hackathon submission. Every claim here is backed by code in the repository. Measured numbers beat claimed accuracy — run the validation protocol (§18 HARDWARE.md) and put the plots on the slides.*