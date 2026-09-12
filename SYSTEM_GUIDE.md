# SwasthyaSetu AI — Complete System Manual & User Guide

**The Definitive Architecture, Hardware Engineering, Core Internals, and Operator Guide**  
*Board Revision: SSAI-SENSE-01 (Rev 2.0) | Mobile Client: SwasthyaSetu AI v1.4.1 (Flutter / Drift / Riverpod)*  
*Target Problem Statement: SIH 26181 (Qualcomm Inc. — MedTech / HealthTech / BioTech)*

---

## Table of Contents

1. [System Overview & High-Level Architecture](#1-system-overview--high-level-architecture)
2. [Hardware Engineering & Circuit Details](#2-hardware-engineering--circuit-details)
   - [2.1 The SSAI-SENSE-01 Board](#21-the-ssai-sense-01-board)
   - [2.2 ESP32-WROOM-32 Microcontroller Architecture](#22-esp32-wroom-32-microcontroller-architecture)
   - [2.3 Sensor Array Specifications & Operating Principles](#23-sensor-array-specifications--operating-principles)
   - [2.4 Master Pinout & Netlist](#24-master-pinout--netlist)
   - [2.5 Power Delivery & Critical LDO Erratum Fix](#25-power-delivery--critical-ldo-erratum-fix)
   - [2.6 Embedded DSP & Firmware Algorithms (`dsp_pure.h`)](#26-embedded-dsp--firmware-algorithms-dsp_pureh)
   - [2.7 Mutually Exclusive Sensor Isolation](#27-mutually-exclusive-sensor-isolation)
   - [2.8 On-Board 5-Page Animated OLED Dashboard](#28-on-board-5-page-animated-oled-dashboard)
3. [The Bluetooth Low Energy (BLE) Wire Protocol](#3-the-bluetooth-low-energy-ble-wire-protocol)
   - [3.1 Nordic UART Service (NUS) GATT Architecture](#31-nordic-uart-service-nus-gatt-architecture)
   - [3.2 Telemetry Frame (0x01) — 20-Byte Byte-by-Byte Layout](#32-telemetry-frame-0x01--20-byte-byte-by-byte-layout)
   - [3.3 ECG Waveform Frame (0x02) — 20-Byte Waveform Layout](#33-ecg-waveform-frame-0x02--20-byte-waveform-layout)
   - [3.4 Control Characteristic (0x05) Command Protocol](#34-control-characteristic-0x05-command-protocol)
   - [3.5 Packet Loss Detection & Exponential Backoff Reconnection](#35-packet-loss-detection--exponential-backoff-reconnection)
4. [Mobile App: Complete Feature Catalog](#4-mobile-app-complete-feature-catalog)
   - [4.1 Dual-Role Authentication & Access Control](#41-dual-role-authentication--access-control)
   - [4.2 Patient Registry & Demographics (ABHA ID)](#42-patient-registry--demographics-abha-id)
   - [4.3 3-Step Guided Screening Wizard](#43-3-step-guided-screening-wizard)
   - [4.4 Real-Time Live Vitals Dashboard](#44-real-time-live-vitals-dashboard)
   - [4.5 Live Diagnostic ECG Oscilloscope](#45-live-diagnostic-ecg-oscilloscope)
   - [4.6 Mutually Exclusive Screening Screen](#46-mutually-exclusive-screening-screen)
   - [4.7 Deterministic Clinical Triage Engine](#47-deterministic-clinical-triage-engine)
   - [4.8 2-Tier AI Clinical Companion & Explainability](#48-2-tier-ai-clinical-companion--explainability)
   - [4.9 Advisory Edge AI Rhythm Anomaly Detection](#49-advisory-edge-ai-rhythm-anomaly-detection)
   - [4.10 Clarke Error Grid Analysis (EGA) for Blood Glucose](#410-clarke-error-grid-analysis-ega-for-blood-glucose)
   - [4.11 Environmental & Heat Stress Guardians](#411-environmental--heat-stress-guardians)
   - [4.12 Overnight Sleep & Bradycardia Guardian](#412-overnight-sleep--bradycardia-guardian)
   - [4.13 Emergency SOS & Hardware Fall Detection](#413-emergency-sos--hardware-fall-detection)
   - [4.14 Longitudinal Trends & Trajectory Charts](#414-longitudinal-trends--trajectory-charts)
   - [4.15 Community Hotspots & Epidemiological Outbreak Heatmap](#415-community-hotspots--epidemiological-outbreak-heatmap)
   - [4.16 Offline-First SQLite (Drift) & Auto-Sync Queue](#416-offline-first-sqlite-drift--auto-sync-queue)
   - [4.17 Hardware Diagnostics & Protocol Hex Inspector](#417-hardware-diagnostics--protocol-hex-inspector)
   - [4.18 Accessibility, Localization & Audio Advisories](#418-accessibility-localization--audio-advisories)
   - [4.19 Longitudinal Early Warning Trajectory Engine (SIH #26181 Step 1)](#419-longitudinal-early-warning-trajectory-engine-sih-26181-step-1)
   - [4.20 Tailored Vulnerability Companion Personas & Adaptive HUD (SIH #26181 Step 2)](#420-tailored-vulnerability-companion-personas--adaptive-hud-sih-26181-step-2)
5. [Operator Guide: Step-by-Step Instructions](#5-operator-guide-step-by-step-instructions)
   - [5.1 Initial Setup & Role Selection](#51-initial-setup--role-selection)
   - [5.2 Pairing the SSAI-SENSE-01 Board (or Using Demo Mode)](#52-pairing-the-ssai-sense-01-board-or-using-demo-mode)
   - [5.3 Registering Patients & Setting Vulnerability Tags](#53-registering-patients--setting-vulnerability-tags)
   - [5.4 Conducting a Complete Clinical Screening](#54-conducting-a-complete-clinical-screening)
   - [5.5 Interpreting Triage Scores & Clinical Rule Triggers](#55-interpreting-triage-scores--clinical-rule-triggers)
   - [5.6 Using the 2-Tier AI Companion (Worker vs. Patient Views)](#56-using-the-2-tier-ai-companion-worker-vs-patient-views)
   - [5.7 Reading the Clarke Error Grid for Blood Glucose](#57-reading-the-clarke-error-grid-for-blood-glucose)
   - [5.8 Triggering or Cancelling an Emergency SOS](#58-triggering-or-cancelling-an-emergency-sos)
   - [5.9 Viewing Trends, Historical Screenings & PDF/CSV Export](#59-viewing-trends-historical-screenings--pdfcsv-export)
   - [5.10 Monitoring Community Disease Outbreaks](#510-monitoring-community-disease-outbreaks)
   - [5.11 Using the Protocol Hex Inspector to Debug Hardware](#511-using-the-protocol-hex-inspector-to-debug-hardware)
6. [Core Engine Internals: How It Actually Works Under the Hood](#6-core-engine-internals-how-it-actually-works-under-the-hood)
   - [6.1 The 4 Architectural Layers](#61-the-4-architectural-layers)
   - [6.2 The Five Non-Negotiable Architectural Mandates](#62-the-five-non-negotiable-architectural-mandates)
   - [6.3 Riverpod State Management & Reactive Dataflow](#63-riverpod-state-management--reactive-dataflow)
   - [6.4 Drift Local Database Schema & Migrations](#64-drift-local-database-schema--migrations)
   - [6.5 60 FPS Real-Time ECG Waveform Rendering Engine](#65-60-fps-real-time-ecg-waveform-rendering-engine)
   - [6.6 Deterministic Clinical Scoring Algorithm (`RiskEngine`)](#66-deterministic-clinical-scoring-algorithm-riskengine)
   - [6.7 Offline Semantic Guideline Retrieval Engine](#67-offline-semantic-guideline-retrieval-engine)
   - [6.8 Mathematical Formulation of Clarke Error Grid](#68-mathematical-formulation-of-clarke-error-grid)
7. [Clinical Safety, Electrical Isolation & Field Troubleshooting](#7-clinical-safety-electrical-isolation--field-troubleshooting)

---

## 1. System Overview & High-Level Architecture

**SwasthyaSetu AI** ("Bridge to Health") is an offline-first, clinical-grade vital signs screening, decision-support, and emergency telemetry workstation designed for frontline community health workers (ASHAs, ANMs) and families across rural and resource-constrained environments.

Frontline health workers face massive challenges: lack of continuous vital monitoring, erratic cellular connectivity, absence of plain-language diagnostic explanations, and unwitnessed patient falls. SwasthyaSetu AI solves this with a **tightly coupled, two-component ecosystem**:
1. **The SSAI-SENSE-01 Hardware Board:** A custom, ultra-low-power, pocket-sized medical telemetry unit built on the ESP32-WROOM-32. It acquires Lead-I ECG, optical photoplethysmography (PPG), dual-channel non-contact infrared temperature, ambient environmental telemetry, and 6-axis motion tracking.
2. **The SwasthyaSetu AI Mobile Application:** A cross-platform Flutter application built on Clean Architecture principles, running local SQLite (Drift) storage, a deterministic clinical triage rule engine (MEWS-aligned), a 2-tier explainable AI clinical companion, a 60 FPS ECG waveform oscilloscope, and offline SMS/telephony emergency dispatch.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   SWASTHYASETU AI ECOSYSTEM                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
          HUMAN BODY                               SSAI-SENSE-01 BOARD
     ┌──────────────────┐               ┌─────────────────────────────────────────┐
     │ • 3-Lead ECG     │───~1 mV AC───▶│ AD8232 Analog Front End (0.5–40 Hz)     │
     │ • Fingertip/Skin │───Photons────▶│ MAX30102 PPG (Red 660nm / IR 880nm)     │
     │ • Forehead Temp  │───Infrared───▶│ MLX90614 Non-Contact Thermopile        │
     │ • Body Motion    │───Inertia────▶│ MPU6050 6-DOF IMU (Fall Interrupt INT)  │
     │ • Ambient Env    │───Air/Press──▶│ BME280 Ambient Sensor (Temp/RH/Press)   │
     └──────────────────┘               └────────────────────┬────────────────────┘
                                                             │
                                                  FreeRTOS Dual-Core DSP
                                               Core 0: ADC, 250Hz IIR, R-Peak
                                               Core 1: 128x64 OLED, BLE GATT
                                                             │
                                                             ▼
                                                BLE 4.2 GATT Telemetry
                                         20-byte Telemetry (4 Hz) / ECG (31.25 Hz)
                                                             │
                                                             ▼
                                           ANDROID SMARTPHONE (SwasthyaSetu AI)
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (Flutter + Riverpod)                                                    │
│  • 60 FPS ECG Canvas Oscilloscope      • 3-Step Clinical Wizard (Screening Flow)           │
│  • Clarke Error Grid Glucose Analysis   • 2-Tier AI Health Companion (Worker / Patient)     │
│  • Community Hotspot Outbreak Heatmap  • 10-Second Cancellable Emergency SOS               │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│  DOMAIN LAYER (Pure Dart — Zero UI / Framework Dependencies)                                │
│  • RiskEngine (Deterministic MEWS Scoring 0–100, Green / Yellow / Red Bands)               │
│  • EcgClassifier (Lead-off, R-R intervals, QRS duration, Arrhythmia detection)             │
│  • HeatStressCalculator (Heat Index, Wet-Bulb Globe Temp WBGT)                             │
│  • ClarkeErrorGridEvaluator (Zones A, B, C, D, E classification)                           │
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│  DATA & STORAGE LAYER (Offline-First Engine)                                                │
│  • Drift (SQLite) Local Database (Encrypted, English Storage, Audit Trails)                │
│  • WaveformStore (Gzipped 16-bit Raw Waveform Storage on Local Filesystem)                 │
│  • Offline Guideline Corpus (WHO IMCI, ICMR, NDMA protocols indexed locally)               │
│  • Resilient Sync Queue (Exponential retry, conflict resolution, ABHA linking)            │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Hardware Engineering & Circuit Details

### 2.1 The SSAI-SENSE-01 Board
The **SSAI-SENSE-01** (Revision 2.0) is a custom clinical telemetry unit manufactured for under ₹6,000 using commercially accessible, high-precision medical-grade ICs.

```
       ┌────────────────────────────────────────────────────────────────┐
       │                   SSAI-SENSE-01 REV 2.0                        │
       │                                                                │
       │  [ 3.5mm ECG Jack ]     [ MLX90614 ]       [ MAX30102 PPG ]   │
       │         │                     │                   │            │
       │      AD8232               Primary I2C        Secondary I2C     │
       │    (Analog FE)           (GPIO 21/22)         (GPIO 26/27)     │
       │         │                     │                   │            │
       │         ▼                     ▼                   ▼            │
       │   GPIO 36 (ADC1)         ┌─────────┐         ┌─────────┐       │
       │   GPIO 39/34 (LO±)       │ ESP32   │         │ ESP32   │       │
       │                          │ Core 0  │         │ Core 1  │       │
       │  [ MPU6050 IMU ]         │ (DSP)   │         │ (BLE/UI)│       │
       │   INT: GPIO 33 ─────────▶└─────────┘         └─────────┘       │
       │                               │                   │            │
       │  [ Touch Pad 1 ] GPIO 4 ──────┘                   │            │
       │  [ Touch Pad 2 ] GPIO 14 ─────────────────────────┘            │
       │                                                                │
       │  [ SSD1306 OLED (128x64) ] ◀── Primary I2C (0x3C)              │
       │  [ TPS63020 Buck-Boost ] ───▶ Clean 3.3V Rail (DevKit VIN)     │
       │  [ Li-ion 3.7V / TP4056 ] ──▶ Battery Sense: GPIO 35 (ADC1)    │
       └────────────────────────────────────────────────────────────────┘
```

### 2.2 ESP32-WROOM-32 Microcontroller Architecture
The board is driven by the **Espressif ESP32-WROOM-32**, featuring a dual-core 32-bit Xtensa LX6 processor clocked at 240 MHz with 520 KB SRAM and integrated Bluetooth 4.2 BR/EDR & BLE.
- **Core 0 (Real-Time Sensor DSP Engine):** Operates a dedicated FreeRTOS task pinned to Core 0 (`sensorTask`). It handles analog-to-digital conversions on ADC1, reads the MAX30102 32-sample FIFO buffer over I2C, executes Pan-Tompkins filtering, and updates volatile vital state.
- **Core 1 (Application, UI & BLE Communications):** Runs the main Arduino `loop()`, servicing the SSD1306 OLED display at 20 Hz, processing capacitive touch inputs, maintaining the BLE GATT state machine, and transmitting unacknowledged notifications.
- **Lock-Free Thread Safety:** Cross-core state sharing (`current_hr`, `current_spo2`, `last_rr_ms`, `leadOff`, `ecgHistory`) uses atomic 32-bit scalar variables marked `volatile`. No mutexes or spinlocks are needed for these scalar variables, preventing priority inversion and timing jitter on Core 0.

### 2.3 Sensor Array Specifications & Operating Principles

| Sensor | Target Metric | Interface / Pin | Sampling Rate | Clinical Significance |
|---|---|---|---|---|
| **AD8232** | Single-Lead ECG (Lead I) | Analog: GPIO36 (ADC1)<br>LO+: GPIO39, LO-: GPIO34<br>SDN: GPIO18 | 250 Hz (4 ms interrupt) | Differential heart biopotential amplification (Gain ~100x), 0.5–40 Hz bandwidth, leads-off hardware detection. |
| **MAX30102** | Photoplethysmography (SpO₂, HR, PTT) | Secondary I²C: GPIO26 (SDA), GPIO27 (SCL)<br>INT: GPIO19 | 100 Hz (Red & IR LEDs) | Measures oxyhemoglobin vs deoxyhemoglobin light absorption; provides pulse wave systolic peak for Blood Pressure estimation. |
| **MLX90614** | Infrared Forehead & Skin Temperature | Primary I²C: GPIO21 (SDA), GPIO22 (SCL)<br>Address: 0x5A | 10 Hz (Smoothed via 5-tap median filter) | Factory-calibrated non-contact thermopile. Measures object temperature and ambient temperature simultaneously. |
| **MPU6050** | 6-DOF IMU (Fall Detection & Motion) | Primary I²C: GPIO21/22<br>Address: 0x68<br>INT: GPIO33 (RTC Wake) | 50 Hz internal DMP | Hardware motion interrupt triggers instant wake-up from ESP32 deep sleep on impact (>2.5g freefall followed by >3.0g collision). |
| **BME280** | Environmental Telemetry (Heat/Weather) | Primary I²C: GPIO21/22<br>Address: 0x76 | 1 Hz | Temperature, Relative Humidity, Barometric Pressure. Feeds mobile Heat Index and WBGT calculation. |
| **SSD1306** | On-Board Visual Display | Primary I²C: GPIO21/22<br>Address: 0x3C | 20 FPS refresh | 128×64 Monochrome OLED. Provides standalone local feedback when operating without a phone. |

### 2.4 Master Pinout & Netlist

The pin allocation strictly respects ESP32 silicon errata. **Only ADC1 pins are used for analog input** (ADC2 is completely disabled by Espressif silicon when the BLE/WiFi radio is powered).

```
ESP32 DevKit Pin     Connected Peripheral             Signal Type         Notes / Silicon Mandate
─────────────────────────────────────────────────────────────────────────────────────────────────────────────
GPIO 36 (SENSOR_VP)  AD8232 OUTPUT                    Analog In (ADC1)    ECG analog signal (0.0 V - 3.3 V)
GPIO 39 (SENSOR_VN)  AD8232 LO+                       Digital In (ADC1)   Lead-Off Positive detection
GPIO 34              AD8232 LO-                       Digital In (ADC1)   Lead-Off Negative detection
GPIO 35              Battery Voltage Divider          Analog In (ADC1)    1:1 divider (100kΩ / 100kΩ)
GPIO 18              AD8232 SDN                       Digital Out         Active-low shutdown for power saving
GPIO 21              Primary I²C SDA (Wire)           Open-Drain (4.7kΩ)  MLX90614, MPU6050, BME280, SSD1306
GPIO 22              Primary I²C SCL (Wire)           Open-Drain (4.7kΩ)  Primary bus clock (100 kHz)
GPIO 26              Secondary I²C SDA (Wire1)        Open-Drain (4.7kΩ)  MAX30102 DEDICATED BUS (1.8V isolation)
GPIO 27              Secondary I²C SCL (Wire1)        Open-Drain (4.7kΩ)  Secondary bus clock (400 kHz)
GPIO 19              MAX30102 INT                     Digital In          Data-ready interrupt
GPIO 33              MPU6050 INT                      Digital In (RTC)    Fall detection wake-up (`ext1` wake)
GPIO 4 (TOUCH 0)     Touch Pad 1 (Right)              Capacitive Touch    HOLD: Start / Stop Measurement
GPIO 14 (TOUCH 6)    Touch Pad 2 (Left)               Capacitive Touch    TAP: Cycle Display Page (Home/SpO2/ECG/Temp/Sys)
GPIO 2               On-Board Status LED              Digital Out         Flashes on BLE packet transmit
VIN                  TPS63020 Buck-Boost Output       Power In (5.0V)     Regulated rail into DevKit onboard LDO
GND                  Common Ground Bus                Ground              Star ground topology under AD8232
```

### 2.5 Power Delivery & Critical LDO Erratum Fix
- **The Fatal Flaw of AMS1117:** Earlier prototype designs attempted to feed a 3.7 V Li-ion battery (which discharges from 4.2 V down to 3.0 V) through an AMS1117-3.3 Low-Dropout (LDO) regulator. Because the AMS1117 has a dropout voltage of 1.1 V at 800 mA, it requires a minimum input of 4.4 V ($3.3 + 1.1\text{ V}$) to remain in regulation. With a Li-ion cell, the regulator is **never in regulation**, causing the ESP32 to brown out on the first BLE radio burst and rendering 60% of battery capacity unusable.
- **The SSAI-SENSE-01 Fix:** Revision 2.0 uses a high-efficiency **TPS63020 Buck-Boost Converter** (or boost stage into DevKit VIN). It cleanly steps down from 4.2 V when the battery is full and steps up from 3.0 V when nearly discharged, providing an unwavering 3.3 V rail across 100% of the lithium discharge curve.
- **Battery Measurement Circuit:** A matched 100 kΩ / 100 kΩ resistor divider divides battery voltage by 2. It connects to **GPIO35 (ADC1_CH7)**. Firmware maps this through an 11-point piecewise linear discharge lookup table (`batteryPercentFromVoltage()`) calibrated for 3.7V LiPo chemistry:

$$\text{Voltage} = \frac{\text{ADC Reading}}{4095} \times 3.3\text{ V} \times 2.0 \times \text{Calibration Factor}$$

```
LiPo Discharge Curve Mapping:
≥ 4.15 V ──▶ 100%       3.85 V ──▶ 60%       3.60 V ──▶ 15% (Pulsing Low-Bat Warning)
  4.05 V ──▶  90%       3.78 V ──▶ 40%       3.50 V ──▶  5%
  3.95 V ──▶  75%       3.70 V ──▶ 25%     < 3.40 V ──▶  0% (Shutdown Threshold)
```

### 2.6 Embedded DSP & Firmware Algorithms (`dsp_pure.h`)
All signal processing code in `dsp_pure.h` is written in pure C99 (`stdint.h`, `math.h`), completely free of Arduino or FreeRTOS headers. This allows identical code to be executed on the physical ESP32 and compiled on a laptop under native unit tests (`pio test -e native` / `flutter test`).

```
                              EMBEDDED DSP PIPELINE (Core 0 @ 250 Hz)
   ADC Raw (GPIO 36)
          │
          ▼
   ┌────────────────────────────────────────────────────────┐
   │ 50 Hz Mains Notch Filter (2nd-Order Biquad IIR)        │ ── Removes 50 Hz electrical hum
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │ 40 Hz Low-Pass Filter (2nd-Order Butterworth Biquad)   │ ── Attenuates EMG muscle tremor
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │ Adaptive Baseline-Wander High-Pass (EMA Subtraction)   │ ── Centers isoelectric line (0 mV)
   └──────────────────────────┬─────────────────────────────┘
                              ▼
          ┌───────────────────┴───────────────────┐
          │                                       │
          ▼                                       ▼
┌───────────────────────────────┐     ┌───────────────────────────────────┐
│ 8-Sample Ring Buffer          │     │ Pan-Tompkins Peak Detector        │
│ Transmitted at 31.25 Hz       │     │ • 5-Point Derivative: f'(x)       │
│ via BLE Characteristic 0x04   │     │ • Squaring Function: [f'(x)]²     │
└───────────────────────────────┘     │ • Moving-Window Integrator (150ms)│
                                      │ • Adaptive Thresholds & Refractory│
                                      └─────────────────┬─────────────────┘
                                                        ▼
                                       Heart Rate (BPM) & R-R Interval (ms)
```

1. **ECG Mains Notch Filter:** A 2nd-order Transposed Direct Form II IIR notch filter centered at 50.0 Hz (configurable to 60.0 Hz) with a quality factor $Q = 8.0$, eliminating powerline noise.
2. **40 Hz Low-Pass Filter:** A 2nd-order Butterworth low-pass filter ($f_c = 40.0\text{ Hz}$, $f_s = 250.0\text{ Hz}$) that removes electromyographic (muscle contraction) noise and RF interference.
3. **Adaptive Baseline Wander Removal:** An Exponential Moving Average (EMA, $\alpha = 0.01$) tracks low-frequency respiration baseline shifts and subtracts them dynamically, maintaining the ECG trace flat around zero.
4. **Pan-Tompkins Real-Time R-Peak Detection:**
   - **Differentiation:** High-pass filter emphasizing the steep slope of the QRS complex.
   - **Squaring:** Non-linear operator amplifying large QRS complexes and suppressing P and T waves.
   - **Moving Window Integrator (MWI):** 150 ms smoothing window accumulating QRS energy.
   - **Dual Adaptive Thresholding:** Two dynamically updating thresholds (Signal Threshold and Noise Threshold). When the MWI signal exceeds the threshold and the 240 ms physiological refractory period has elapsed, an R-peak is registered.
   - **Heart Rate & R-R Calculation:** The interval between consecutive R-peaks determines the R-R interval ($ms$) and the instant heart rate:

$$\text{Heart Rate (BPM)} = \frac{60000}{\text{R-R Interval (ms)}}$$

5. **Maxim Reference SpO₂ Ratio-of-Ratios Algorithm:**
   The MAX30102 samples alternating Red (660 nm) and Infrared (880 nm) light reflection through capillary beds. The algorithm separates the alternating pulsatile component ($AC$) from the constant tissue absorption baseline ($DC$):

$$R = \frac{AC_{\text{red}} / DC_{\text{red}}}{AC_{\text{ir}} / DC_{\text{ir}}}$$

$$\text{SpO}_2 = 110 - 25 \times R \quad (\text{Calibrated empirical curve, clamped } 50\% - 100\%)$$

6. **Pulse Transit Time (PTT) Cuffless Blood Pressure Estimation:**
   The ESP32 measures the exact time delta between the ventricular contraction (R-peak on ECG) and the peripheral arterial pressure pulse arrival at the fingertip (systolic peak on the MAX30102 PPG waveform). Faster transit times indicate higher arterial vascular stiffness and elevated systolic pressure:

$$\text{Estimated Systolic (mmHg)} = a \times \ln(\text{PTT}) + b$$

$$\text{Estimated Diastolic (mmHg)} = c \times \ln(\text{PTT}) + d$$

*(Where $a, b, c, d$ are calibrated coefficients per individual).*

### 2.7 Mutually Exclusive Sensor Isolation
A major innovation in the v3.0.0 firmware is **Strictly Mutually Exclusive Sensor Isolation**.
- **The Problem:** Running the MAX30102 high-current LED drivers (30–50 mA pulses) simultaneously with the AD8232 biopotential amplifier introduces severe power rail droop, photodiode switching spikes, and 100 Hz ripple onto the sensitive ~1 mV ECG trace.
- **The Solution:** The firmware enforces mutual exclusion:
  - During ECG streaming, the MAX30102 LEDs are placed into complete software power-down mode (`max30102.shutDown()`).
  - During SpO₂ acquisition, the AD8232 is put into low-power sleep via its active-low shutdown pin (`digitalWrite(ECG_SDN_PIN, LOW)`).
  - The mobile app's [mutually_exclusive_screening_screen.dart](file:///c:/nvdia/lib/features/screening/screens/mutually_exclusive_screening_screen.dart) enforces this sequentially: SpO₂ settles first (15 seconds), then ECG captures cleanly (30 seconds), ensuring zero optical or electrical crosstalk.

### 2.8 On-Board 5-Page Animated OLED Dashboard
The 128×64 SSD1306 OLED display features a five-page animated user interface navigated by capacitive touch:
- **Page 0 (Home):** Animated breathing radar graphic, battery percentage icon, BLE link status ("BLE LINKED" / "BLE LOST"), live uptime.
- **Page 1 (SpO₂ & Pulse):** Live oxygen percentage, heart rate in BPM, animated pulsing heart bitmap synchronized with detected beats.
- **Page 2 (ECG Scope):** Real-time miniature scrolling ECG waveform oscilloscope (128 columns) updated at 20 Hz, accompanied by lead-off alert ("REATTACH ELECTRODE").
- **Page 3 (Temperature & Environment):** Dual temperature readout: Skin/Forehead (°C) from MLX90614 and Ambient (°C / %RH) from BME280.
- **Page 4 (System & Diagnostics):** BLE RSSI, packet sequence counter, firmware version (`v3.0.0`), battery voltage ($mV$).
- **Touch Navigation:**
  - **TAP Touch Pad 2 (GPIO 14):** Cycles forward to the next screen (`Home → SpO2 → ECG → Temp → Sys → Home`).
  - **HOLD Touch Pad 1 (GPIO 4):** Triggers measurement start/stop sting animation (~400 ms expanding circle) and sends command over BLE.

---

## 3. The Bluetooth Low Energy (BLE) Wire Protocol

### 3.1 Nordic UART Service (NUS) GATT Architecture
Communication between the SSAI-SENSE-01 board and the mobile application uses a custom GATT service inspired by Nordic Semiconductor's UART Service:

| Characteristic | UUID | Properties | Purpose |
|---|---|---|---|
| **Service UUID** | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` | Primary | SwasthyaSetu AI Primary GATT Service |
| **Device Info** | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` | Read | Human-readable firmware string (e.g. `"SwasthyaSetu ESP32 v3.0.0"`) |
| **Telemetry** | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` | Notify (4 Hz) | 20-byte packed binary struct of live processed vitals |
| **ECG Stream** | `6e400004-b5a3-f393-e0a9-e50e24dcca9e` | Notify (31.25 Hz) | 20-byte packed binary struct (4-byte header + 8 raw int16 samples) |
| **Control** | `6e400005-b5a3-f393-e0a9-e50e24dcca9e` | Write | Command byte: `0xA1` (Start), `0xA0` (Stop), `0xA2` (Tare/Calibrate) |

### 3.2 Telemetry Frame (0x01) — 20-Byte Byte-by-Byte Layout
The live vitals notification is exactly **20 bytes**, sent 4 times per second. Both the ESP32 and ARM/Android are little-endian architectures, allowing direct struct serialization without endian conversion overhead.

```
Byte Offset   Data Type   Field Name            Encoding / Description
─────────────────────────────────────────────────────────────────────────────────────────────────────────────
0             uint8       Frame Type            Always 0x01 (FRAME_TELEMETRY)
1             uint8       Protocol Version      Always 0x01 (PROTOCOL_VERSION)
2             uint8       Heart Rate            BPM (25 to 250)
3             uint8       SpO₂                  Percentage (50 to 100)
4..5          int16       Temperature           Hundredths of °C, Little-Endian (e.g., 3685 = 36.85 °C)
6..7          uint16      Last R-R Interval     Milliseconds (ms), Little-Endian
8             uint8       ECG Signal Quality    0 to 100 % (derived from noise floor vs QRS amplitude)
9             uint8       Hardware Flags        Bitfield:
                                                  • Bit 0: R-Peak Detected (1 = instant beat)
                                                  • Bit 1: Fall Detected (1 = MPU6050 fall alarm)
                                                  • Bit 2: Lead Off (1 = electrode detached)
                                                  • Bit 3: Finger Off (1 = MAX30102 unseated)
                                                  • Bit 4: SpO₂ Stabilized (1 = reliable reading)
                                                  • Bit 5: Motion Artifact / Low Signal
10..11        uint16      Pulse Transit Time    Milliseconds (PTT), Little-Endian
12            uint8       Estimated Systolic    mmHg (e.g., 120)
13            uint8       Estimated Diastolic   mmHg (e.g., 80)
14            uint8       Battery Level         Percentage (0 to 100 %)
15            uint8       BP Confidence Level   0 = Low, 1 = Medium, 2 = High (or system state enum)
16..19        uint32      Device Uptime         Milliseconds since ESP32 boot, Little-Endian
```

### 3.3 ECG Waveform Frame (0x02) — 20-Byte Waveform Layout
Real-time diagnostic ECG data is streamed at **31.25 packets per second**. Each packet carries 8 signed 16-bit samples ($31.25 \times 8 = 250\text{ samples/second}$), perfectly matching the analog sampling rate:

```
Byte Offset   Data Type   Field Name            Encoding / Description
─────────────────────────────────────────────────────────────────────────────────────────────────────────────
0             uint8       Frame Type            Always 0x02 (FRAME_ECG)
1             uint8       Protocol Version      Always 0x01
2..3          uint16      Sequence Number       Monotonically increasing counter (0 to 65535, wraps)
4..5          int16       ECG Sample 0          Signed 16-bit ADC reading (-32768 to 32767), Little-Endian
6..7          int16       ECG Sample 1          Signed 16-bit ADC reading
8..9          int16       ECG Sample 2          Signed 16-bit ADC reading
10..11        int16       ECG Sample 3          Signed 16-bit ADC reading
12..13        int16       ECG Sample 4          Signed 16-bit ADC reading
14..15        int16       ECG Sample 5          Signed 16-bit ADC reading
16..17        int16       ECG Sample 6          Signed 16-bit ADC reading
18..19        int16       ECG Sample 7          Signed 16-bit ADC reading
```

### 3.4 Control Characteristic (0x05) Command Protocol
The mobile client controls sensor hardware by writing a single command byte to characteristic `...0005`:
- `0xA1`: **START_CAPTURE** — Wakes up sensors from sleep, initiates 250 Hz timer, starts BLE notifications.
- `0xA0`: **STOP_CAPTURE** — Puts AD8232 and MAX30102 into low-power sleep, ceases BLE streams.
- `0xA2`: **TARE_SENSORS** — Triggers dynamic DC baseline recalibration on the ESP32.

### 3.5 Packet Loss Detection & Exponential Backoff Reconnection
- **Sequence Continuity Verification:** In [ble_protocol.dart](file:///c:/nvdia/lib/core/services/ble_protocol.dart), the mobile client inspects `sequence` on every ECG packet:

$$\text{isContiguous} = (\text{Sequence}_{\text{current}} == (\text{Sequence}_{\text{previous}} + 1) \ \& \ \text{0xFFFF})$$

If a sequence gap is detected, the app logs a dropped packet counter and alerts the clinician rather than interpolating fake heartbeats.
- **Exponential Reconnection Backoff:** If the Bluetooth link drops mid-screening, `BleService` enters an automatic reconnection loop with exponential backoff: **1s, 2s, 4s, 8s, 16s, 30s max**. The UI displays an orange "Reconnecting to SSAI-SENSE-01..." banner. Critically, the accumulated ECG buffer is preserved in the background service and never wiped out by a brief connection glitch.

---

## 4. Mobile App: Complete Feature Catalog

### 4.1 Dual-Role Authentication & Access Control
The application features two dedicated operational modes:
1. **Clinician / Health Worker Mode (Default):** Designed for ASHAs and ANMs. Grants access to the full patient roster, diagnostic screening wizard, 60 FPS ECG waveform, clinical rule triggers, epidemiology maps, and CSV/JSON/PDF exports.
2. **Patient / Citizen Home Mode (`/my-health`):** Designed for individuals and families self-monitoring at home. The interface simplifies technical metrics into plain-language summaries ("My Health", "Advisories", "Device", "Emergency Help"), displaying large color-coded status cards and lifestyle recommendations.

### 4.2 Patient Registry & Demographics (ABHA ID)
- **Local Roster:** Manages community members with offline demographic records (Name, Age, Sex, Phone, Village / GPS Location, Clinical Notes).
- **Ayushman Bharat Health Account (ABHA ID):** Facilitates linkage with India's national digital health infrastructure.
- **Vulnerability Profiling:** Frontline workers can flag patients with specific physiological risk profiles:
  - `elderly` (Age ≥ 65)
  - `chronic` (Hypertension, Diabetes, COPD)
  - `pregnant` (Alters blood pressure and heart rate triage thresholds)
  - `infant` (Pediatric heart rate scaling)
  - `immunocompromised` (Lowers fever threshold to 37.5 °C)
  These flags directly tune the sensitivity of the deterministic triage engine.

### 4.3 3-Step Guided Screening Wizard
Navigated via `/screening/new`, this wizard enforces standardized screening protocol:
- **Step 1: Patient Selection:** Search and pick an existing patient from local SQLite or tap "Add New Patient".
- **Step 2: Device Linkage:** Scans for `SSAI-SENSE-01`. Connects over BLE GATT, inspects battery level and firmware version, or enables **Demo Mode** if hardware is not physically present.
- **Step 3: Sensor Placement Guide:** Displays visual diagrams showing 3-lead ECG electrode placement (Right Arm, Left Arm, Right Leg), fingertip placement on the PPG pulse oximeter, and infrared forehead thermometer aiming.

### 4.4 Real-Time Live Vitals Dashboard
Displays live biometric cards updated dynamically at 4 Hz:
- **Heart Rate (BPM):** Real-time pulse with physiological limit validation (25–250 bpm).
- **Blood Oxygen (SpO₂ %):** Color-coded display with a stabilization lock indicator to prevent recording incomplete readings.
- **Infrared Body Temperature (°C / °F):** High-precision forehead temperature.
- **Cuffless Blood Pressure (mmHg):** Non-invasive systolic/diastolic estimate derived from Pulse Transit Time (PTT) with confidence indicator (Low, Medium, High).
- **Blood Glucose Estimate (mg/dL):** Non-invasive optical metabolic estimate linked to Clarke Error Grid Analysis.

### 4.5 Live Diagnostic ECG Oscilloscope
Located at `/screening/ecg`, this screen delivers a hospital-grade single-lead electrocardiogram:
- **60 FPS Real-Time Canvas:** Renders smooth scrolling biopotential traces without UI jitter.
- **Lead-Off Detection Alert:** When an electrode falls off the patient's skin, an immediate warning banner appears ("ECG LEAD OFF — CHECK CHEST ELECTRODES") and waveform drawing pauses.
- **R-Peak Beat Markers:** Visual markers highlight every detected QRS complex.
- **R-R Interval & Signal Quality Index:** Displays instantaneous R-R interval in milliseconds and biopotential signal quality percentage (0–100%).

### 4.6 Mutually Exclusive Screening Screen
Located at `/screening/live`, this screen executes the firmware's mutual isolation protocol:
- **Phase 1 (15 Seconds):** Powers MAX30102 LEDs, measures SpO₂ and Pulse Transit Time, verifies finger stabilization.
- **Phase 2 (30 Seconds):** Shuts down MAX30102, powers AD8232 front-end, records 250 Hz Lead-I ECG without LED optical/electrical switching noise.

### 4.7 Deterministic Clinical Triage Engine
Located at `/screening/triage`, the app evaluates vitals against the Modified Early Warning Score (MEWS) and clinical protocols:
- **Green Band (Score 0–30):** Normal physiological parameters; routine community follow-up.
- **Yellow Band (Score 31–60):** Moderate risk; requires local primary health center (PHC) review and dietary/lifestyle guidance.
- **Red Band (Score 61–100):** Urgent / Critical risk; triggers immediate hospital escalation and ambulance notification.
- **Critical Floor Guarantee:** Any single life-threatening condition (e.g., $\text{SpO}_2 < 85\%$, $\text{HR} > 150\text{ bpm}$, severe fever with tachycardia) **automatically floors the risk score at 61 (RED)**, ensuring abnormal vitals cannot be averaged away.

### 4.8 2-Tier AI Clinical Companion & Explainability
Accessible via `/screening/ai-explanation`, this module demystifies clinical numbers:
- **Tier 1 (Clinician / ASHA View):** Provides evidence-based diagnostic explanations, differential diagnosis flags, relevant clinical guideline citations (WHO IMCI, ICMR, NDMA), and recommended medical next steps.
- **Tier 2 (Patient / Family View):** Translates complex medical findings into simple, culturally respectful, compassionate explanations in **Hindi, Bengali, or English**.
- **Offline Fallback:** If internet is unavailable, a local semantic rule matcher synthesizes explanations from pre-cached ICMR/WHO medical guideline chunks.

### 4.9 Advisory Edge AI Rhythm Anomaly Detection
In strict compliance with **Mandate 2.5**, an on-device machine learning model inspects the recorded ECG rhythm for morphological anomalies (e.g., premature ventricular contractions, atrial fibrillation indicators).
- The result is displayed as an **Advisory AI Flag** alongside confidence score (0.0 to 1.0).
- **Non-Negotiable Invariant:** The AI flag is purely advisory and is **strictly prohibited from altering the deterministic triage score or band**.

### 4.10 Clarke Error Grid Analysis (EGA) for Blood Glucose
Integrated into the metabolic screening interface (`ClarkeErrorGridWidget`), this feature provides clinical validation for non-invasive glucose estimation:
- Plots estimated blood glucose ($y$-axis) against reference fingerstick glucometer readings ($x$-axis).
- Categorizes estimations into **Zones A, B, C, D, and E** based on the Clarke et al. (1987) clinical standard.
- Zone A and B represent clinically acceptable accuracy; Zones C, D, and E trigger clear advisory warnings.

### 4.11 Environmental & Heat Stress Guardians
Accessible at `/screening/heat-guardian` and `/advisories`:
- **Heat Index & WBGT:** Computes Wet Bulb Globe Temperature and Heat Index from BME280 telemetry.
- **Vulnerability Cross-Referencing:** Alerts workers if elderly or pregnant patients are exposed to dangerous heat conditions.
- **Air Quality Warnings:** Warns of respiratory exacerbation risks based on PM2.5 and humidity levels.

### 4.12 Overnight Sleep & Bradycardia Guardian
Accessible via `/screening/overnight-guardian`:
- Enables low-power overnight continuous monitoring while the phone screen is off.
- Configurable alarms trigger if heart rate drops below 40 bpm (nocturnal bradycardia) or SpO₂ drops below 88% for more than 15 seconds (sleep apnea / respiratory depression).

### 4.13 Emergency SOS & Hardware Fall Detection
Accessible at `/emergency/sos`:
- **Dual Trigger Mechanisms:** Can be triggered manually by tapping the red SOS button or automatically by the ESP32 MPU6050 fall detection interrupt.
- **10-Second Cancellable Safety Countdown:** Prevents false alarms by giving the user 10 seconds (with loud audio beeps and haptic vibration) to cancel before dispatch.
- **GPS Location Latching:** Latches exact device coordinates (latitude, longitude) and creates an instant Google Maps link.
- **Multi-Channel Dispatch:**
  - Sends emergency SMS messages to designated local contacts and health supervisors.
  - Automatically launches the system phone dialer targeting **108 (Ambulance)** or **112 (National Emergency)**.
  - Sounds a loud local siren to alert nearby villagers.

### 4.14 Longitudinal Trends & Trajectory Charts
Accessible at `/trends?patientId=...`:
- Graphically displays vital sign trajectories over days, weeks, and months.
- Tracks systolic/diastolic BP shifts, resting heart rate variability, and SpO₂ stability across consecutive community visits.

### 4.15 Community Hotspots & Epidemiological Outbreak Heatmap
Accessible at `/community`:
- Visualizes geographic clusters of elevated fever, hypoxia, or respiratory symptoms.
- Enables early detection of infectious disease outbreaks (e.g., Dengue, Malaria, viral pneumonia) across villages.
- **DPDPA Privacy Compliance:** When location permission is withheld, the app displays an explicit **"Location is OFF"** message instead of rendering empty terrain.

### 4.16 Offline-First SQLite (Drift) & Auto-Sync Queue
- **Zero-Connectivity Architecture:** All patient profiles, vital signs, ECG waveform metadata, and triage assessments are persisted locally in an encrypted SQLite database.
- **Automatic Sync Queue:** Records are staged in a `SyncQueue` table. When cellular or Wi-Fi connectivity returns, records automatically sync to the regional health server with exponential retry and deduplication.
- **Clinical Data Export:** Health workers can generate and share comprehensive clinical reports formatted as **PDF, CSV, or JSON**.

### 4.17 Hardware Diagnostics & Protocol Hex Inspector
Accessible at `/devices/diagnostics`:
- Displays live incoming raw hex packets from characteristics `...0003` and `...0004`.
- Shows Bluetooth RSSI signal strength in dBm, live packet loss rate, dropped frame counter, and device uptime counter.

### 4.18 Accessibility, Localization & Audio Advisories
- **Full Multi-Language Support:** Localized in English, Hindi (हिन्दी), and Bengali (বাংলা) via Flutter ARB localization.
- **High-Scale Accessibility:** Layouts are engineered to scale seamlessly up to **`textScaleFactor: 2.0`** without text clipping or layout overflow.
- **Voice / Audio Advisories:** Synthesizes spoken voice alerts in local dialects for illiterate patients.

### 4.19 Longitudinal Early Warning Trajectory Engine (SIH #26181 Step 1)
Located in `lib/domain/rules/early_warning_trajectory_engine.dart` and `lib/domain/models/early_warning_trajectory.dart`:
- **Rolling Multi-Day Physiological Baseline:** Instead of relying only on instantaneous point-in-time measurements, the engine fuses 3-day and 7-day rolling biometric logs to recognize insidious, creeping deterioration days before overt clinical emergencies occur.
- **Cumulative Thermal Debt Trajectory:**
  - Evaluates consecutive hot nights (ambient temp $\ge 28^\circ\text{C}$ or nocturnal Heat Index) and nocturnal resting heart rate.
  - Detects incomplete autonomic recovery ($\Delta \text{HR} \ge 8\text{ bpm}$ above baseline over 3 consecutive nights).
  - Triggers proactive warnings for impending heat exhaustion, cardiovascular strain, and autonomic burnout.
- **Trailing Respiratory Degradation Curve:**
  - Evaluates cumulative 48-hour $\text{PM}_{2.5}$ exposure alongside resting $\text{SpO}_2$ trajectories.
  - Flags pre-bronchospasm risk when baseline $\text{SpO}_2$ slips by $\ge 2\%$ across consecutive readings during severe smog events.
  - Automatically recommends proactive inhaler staging, guided pursed-lip breathing, and indoor air containment.
- **Post-Flood 14-Day Epidemic Incubation Timeline:**
  - **Days 1–3 (Acute Waterborne Phase):** High-vigilance screening for acute cholera, *E. coli*, profuse rice-water diarrhea, and hypovolemic dehydration.
  - **Days 4–8 (Zoonotic/Wound Phase):** Sentinel tracking for leptospirosis (*Weil's disease*), high fever with intense calf pain, conjunctival suffusion, and open wound cellulitis/sepsis from wading in floodwaters.
  - **Days 9–14 (Vector-Borne Phase):** Surveillance for stagnant pool mosquito vectors (Dengue, Malaria, Chikungunya), retro-orbital headache, saddleback fever, and petechial rashes.
- **Mandate Adherence:** Pure Dart implementation (zero Flutter UI dependencies), strictly deterministic bands, and full Mandate 2.5 compliance (AI flags are advisory and never alter trajectory bands).

### 4.20 Tailored Vulnerability Companion Personas & Adaptive HUD (SIH #26181 Step 2)
Located in `lib/domain/models/vulnerability_persona.dart`, `lib/features/patient_home/widgets/vulnerability_persona_selector.dart`, and `lib/features/patient_home/widgets/persona_adaptive_hud.dart`:
- **Dynamic Demographic Inference & Cohort Tagging:** Automatically suggests or allows manual selection of tailored vulnerability personas based on age, occupation, and chronic disease flags:
  - **Outdoor Worker:** Construction laborers, farmers, delivery personnel, and street vendors exposed to radiant heat and physical exertion.
  - **Elderly Citizen:** Individuals aged 65+ with elevated fall risk, blunted thirst reflexes, and nocturnal cardiovascular vulnerability.
  - **Chronic Cardiorespiratory:** Individuals managing COPD, asthma, heart failure, or hypertension vulnerable to sudden air quality or thermal shifts.
  - **General Resident:** Standard community members needing baseline wellness, epidemic alerts, and disaster readiness.
- **Cohort-Tailored Adaptive HUD:**
  - **Outdoor Worker HUD:** Displays real-time Moran Physiological Strain Index (PSI 0–10), active hydration countdown timer, quick `+250 ml` water intake logging, and wet-bulb rest-cycle advisories.
  - **Elderly Citizen HUD:** 24/7 fall sentinel status indicator, nocturnal blood pressure/heart rate dipping tracker, blunted thirst reminder, and one-tap emergency SOS latch.
  - **Chronic Cardiorespiratory HUD:** Ambient NAQI/$\text{PM}_{2.5}$ cardiorespiratory distress gauge, quick-launch shortcut to the interactive 4s/6s Pursed-Lip Breathing Metronome, and medication staging checklists.
  - **General Resident HUD:** 7-day longitudinal stability radar, regional epidemic incubation status, and community disaster safety advisories.
- **Interactive Persona Switcher:** Floating horizontal selector allows instant switching between personas while persisting user selection in local encrypted storage.

---

## 5. Operator Guide: Step-by-Step Instructions

### 5.1 Initial Setup & Role Selection
1. Launch the **SwasthyaSetu AI** app.
2. The splash screen initializes the local database and loads clinical guidelines.
3. On the role selection screen, choose:
   - **Health Worker (ASHA / ANM):** Enter your 4-digit PIN or tap "Offline Login". You will arrive at the Clinician Home Dashboard.
   - **Patient / Family:** Tap "Patient Mode". You will arrive at the simplified My Health screen.

```
[ Splash Screen ] ──▶ [ Role Selection ]
                            ├─▶ Health Worker ──▶ [ Clinician Dashboard ] (/home)
                            └─▶ Patient / Home ──▶ [ My Health Screen ] (/my-health)
```

### 5.2 Pairing the SSAI-SENSE-01 Board (or Using Demo Mode)
1. Turn on the SSAI-SENSE-01 hardware board using the side slide switch. The OLED display will show the animated mascot and boot logo, followed by the breathing radar screen.
2. On the mobile app dashboard, tap the **"Connect Device"** card (or navigate to bottom tab **Device** → `/devices/scan`).
3. Tap **"Start Scan"**. The app scans for Bluetooth Low Energy advertisements.
4. When `SSAI-SENSE-01` appears in the list with signal strength (RSSI), tap **"Connect"**.
5. The app performs GATT discovery, reads the firmware version (`v3.0.0`), and subscribes to telemetry streams. A teal dot appears on the navigation bar indicating a live link.
6. *Hardware Not Available?* Tap **"Launch Demo Mode"** at the bottom of the scan screen. The app activates an internal physiological signal generator that synthesizes realistic live vitals and ECG waveforms.

### 5.3 Registering Patients & Setting Vulnerability Tags
1. From the bottom navigation bar, tap **"Patients"** (`/patients`).
2. Tap the floating **"+" (Add Patient)** button.
3. Fill in the patient details:
   - **Full Name**, **Age**, **Sex (Male / Female / Other)**.
   - **ABHA ID** (14-digit National Health ID, if available).
   - **Phone Number** and **Village / Ward**.
4. Check applicable **Vulnerability Tags**:
   - ☑ *Elderly (≥65 years)*
   - ☑ *Chronic Illness (Hypertension/Diabetes)*
   - ☑ *Pregnant*
   - ☑ *Infant*
   - ☑ *Immunocompromised*
5. Tap **"Save Patient Record"**. The patient is stored in local SQLite and appears in the community roster.

### 5.4 Conducting a Complete Clinical Screening
1. On the patient profile or home dashboard, tap **"Start New Screening"**.
2. **Step 1 (Select Patient):** Confirm the patient name. Tap **"Next"**.
3. **Step 2 (Device Connection):** Confirm `SSAI-SENSE-01` is connected. Tap **"Next"**.
4. **Step 3 (Placement & Measurement):**
   - **ECG Placement:** Attach the 3 electrode pads:
     - **Red (RA):** Right clavicle / wrist.
     - **Yellow (LA):** Left clavicle / wrist.
     - **Green (RL):** Right lower abdomen / leg (reference ground).
   - **PPG Placement:** Insert the patient's index finger gently into the MAX30102 sensor clip. Instruct them to remain still and avoid squeezing.
   - **Temperature:** Aim the MLX90614 sensor 2–4 cm from the center of the patient's forehead.
5. Tap **"Start Live Capture"**.
6. Watch the live vitals settle:
   - Allow SpO₂ 10–15 seconds to establish stabilization lock (indicated by a green checkmark).
   - Verify the ECG waveform shows clean QRS complexes with no "LEAD OFF" alert.
7. Tap **"Record & Continue to Symptoms"**.
8. Select any symptoms reported by the patient (e.g., *Chest Pain, Shortness of Breath, Dizziness, High Fever, Cough, Diarrhea*).
9. Tap **"Compute Clinical Triage"**.

```
[ Patient Roster ] ──▶ [ Connect SSAI-SENSE-01 ] ──▶ [ Attach Electrodes & Finger ]
                                                              │
[ Triage & AI Advice ] ◀── [ Select Symptoms ] ◀── [ Live Capture (30s) ]
```

### 5.5 Interpreting Triage Scores & Clinical Rule Triggers
The **Triage Result Screen** (`/screening/triage`) displays the deterministic clinical evaluation:
- **Triage Risk Card:**
  - **GREEN (Normal, Score 0–30):** All vitals within safe limits.
  - **YELLOW (Needs Attention, Score 31–60):** Mildly abnormal vitals; requires primary clinic evaluation.
  - **RED (Urgent, Score 61–100):** Severe risk; immediate referral or hospitalization required.
- **Triggered Clinical Rules:** Lists specific medical reasons behind the score (e.g., `spo2_critical: SpO2 84% is dangerously low (<88%)`, `hr_tachy_warning: Heart rate 118 bpm exceeds normal threshold`).
- **Recommended Actions:** Concrete operational guidance (e.g., *"Administer supplementary oxygen if available. Place patient in Fowler's position. Escalate immediately to Community Health Officer."*).

### 5.6 Using the 2-Tier AI Companion (Worker vs. Patient Views)
1. At the bottom of the Triage screen, tap **"Explain with AI Health Companion"**.
2. **Clinician View (ASHA Mode):**
   - Review diagnostic differentials, clinical severity rationales, and protocol citations (e.g., *ICMR Hypertension Guidelines 2023, WHO IMCI Pneumonia Protocol*).
3. **Patient & Family View:**
   - Tap the **"Patient View"** toggle at the top right.
   - The interface switches to plain-language, non-technical explanations.
   - Select language: **English**, **Hindi (हिन्दी)**, or **Bengali (বাংলা)**.
   - Tap the **"Speaker / Audio"** icon to play a voice readout for patients who cannot read.

### 5.7 Reading the Clarke Error Grid for Blood Glucose
1. On the screening result screen, navigate to the **Metabolic / Glucose** card and tap **"View Clarke Error Grid Analysis"**.
2. The coordinate system displays:
   - **X-axis:** Reference Laboratory / Fingerstick Glucose (mg/dL).
   - **Y-axis:** Optical PTT-estimated Glucose (mg/dL).
3. Interpret the plotted point:
   - **Zone A (Green):** Clinically accurate. Safe for clinical decision-making.
   - **Zone B (Light Green):** Benign error. Safe; no unwarranted clinical intervention.
   - **Zone C (Yellow):** Overcorrection error. Unwarranted treatment risk.
   - **Zone D (Orange):** Dangerous failure to detect hypoglycemia or hyperglycemia.
   - **Zone E (Red):** Erroneous treatment risk. Reverses clinical reality.

### 5.8 Triggering or Cancelling an Emergency SOS
1. In an emergency, tap the prominent red **"SOS Emergency"** button in the app header or on the Home screen.
2. The **Emergency SOS Screen** (`/emergency/sos`) opens with a prominent 10-second circular countdown timer, pulsing red screen, and loud audible alert beeps.
3. **To Cancel a False Alarm:** Tap **"I AM SAFE — CANCEL SOS"** before the 10 seconds elapse. The siren ceases and no messages are sent.
4. **When the Countdown Finishes:**
   - The app latches high-precision GPS coordinates.
   - Automatically dispatches an emergency SMS alert to all configured contacts containing the patient's name, age, triage risk, and Google Maps location link.
   - Launches the phone dialer targeting emergency services (**108** or **112**).

### 5.9 Viewing Trends, Historical Screenings & PDF/CSV Export
1. From the Clinician bottom bar, tap **"History"** (`/history`).
2. Filter screenings by date, patient name, or risk level (Green/Yellow/Red).
3. Tap any historical screening to view its full vital report, ECG rhythm strip, and rule audit log.
4. **Exporting Data:**
   - Tap the **"Share / Export"** icon in the app bar.
   - Choose **"Export PDF Clinical Report"** for a formal printable doctor's referral slip.
   - Choose **"Export CSV / JSON"** to export structured screening batches for import into district health portals (e.g., IHIP / HMIS).

### 5.10 Monitoring Community Disease Outbreaks
1. Tap the **"Community"** tab (`/community`).
2. The map displays geographic clusters of recent screenings.
3. Red and orange pins highlight localized surges in fever, respiratory distress, or severe hypoxia.
4. Tap any cluster to view aggregated village metrics and identify emerging infectious disease outbreaks before they overwhelm district hospitals.

### 5.11 Using the Protocol Hex Inspector to Debug Hardware
1. Navigate to **Device** (`/devices/scan`) → Tap the gear/diagnostics icon at the top right (`/devices/diagnostics`).
2. **Live Hex Stream:** Watch raw 20-byte hex payloads arriving in real time:
   - Telemetry: `01 01 48 62 0E 5A 03 ...`
   - Waveform: `02 01 04 12 FC FF 02 ...`
3. Check metrics:
   - **Packets Received:** Total valid packets.
   - **Dropped Frames:** Count of missing sequence IDs.
   - **RSSI:** Signal strength in dBm (-50 dBm is strong; below -85 dBm indicates range issues).

---

## 6. Core Engine Internals: How It Actually Works Under the Hood

### 6.1 The 4 Architectural Layers
The Flutter application strictly follows Clean Architecture principles with unidirectional dataflow:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. PRESENTATION LAYER (`lib/features/`, `lib/core/widgets/`)          │
│    • Flutter Widgets, CustomPainters, GoRouter routes                  │
│    • ConsumerStatefulWidgets listening to Riverpod providers           │
├────────────────────────────────────────────────────────────────────────┤
│ 2. DOMAIN LAYER (`lib/domain/`) ── PURE DART (ZERO FLUTTER IMPORTS)    │
│    • Models: `HealthSample`, `Patient`, `TriageResult`, `EcgFrame`     │
│    • Deterministic Rules: `RiskEngine`, `EcgClassifier`                │
│    • Algorithms: `HeatStressCalculator`, `ClarkeErrorGridEvaluator`    │
├────────────────────────────────────────────────────────────────────────┤
│ 3. DATA LAYER (`lib/data/`)                                            │
│    • Persistence: Drift SQLite schema (`app_database.dart`)            │
│    • Repositories: `PatientRepository`, `ScreeningRepository`          │
│    • Mappers: Translates pure domain models to/from Drift `*Row` types │
├────────────────────────────────────────────────────────────────────────┤
│ 4. CORE & HARDWARE ABSTRACTION LAYER (`lib/core/`)                     │
│    • Bluetooth LE: `BleService`, `BleProtocol` (flutter_blue_plus)    │
│    • Local Audio, Location Manager, SMS Intent Dispatcher             │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.2 The Five Non-Negotiable Architectural Mandates

These five core rules are enforced across the codebase and verified by automated unit tests:

#### Mandate 1: One-Way Provenance (`isDemo` Flag)
- Data can flow from live hardware to demo-flagged simulations, but **never the reverse**.
- Every vital record and screening has a non-nullable boolean `isDemo`.
- A screening started in live mode never silently switches to simulated values on disconnect. Demo records are permanently isolated from clinical triage records.

#### Mandate 2: Storage Stays English (Single Vocabulary)
- Translations (Hindi, Bengali) exist **only in user-facing UI labels**.
- All SQLite columns, exported JSON/CSV files, and triage rule IDs share **exactly one English vocabulary** (`GREEN`, `YELLOW`, `RED`, `spo2_critical`). A screening performed in Bengali generates identical database records to one performed in English.

#### Mandate 3: No Fabricated Gaps
- Missing, excluded, or failed sensor measurements must render as **`—` (em dash)**.
- Never replace missing values with `0`, `null`, or an interpolated plausible guess. A detached SpO₂ sensor renders as `— %`, never `0 %` or `98 %`.

#### Mandate 4: Screening Support, Not Diagnosis
- The application is a frontline screening and triage support tool, **never an automated medical diagnostician**.
- Triage scores are computed deterministically. All screens and PDF exports display mandatory statutory medical disclaimers.

#### Mandate 5: AI Flags Are Advisory, Never Authoritative
- Any machine learning model prediction (such as rhythm anomaly detection) is stored separately (`aiAnomalyFlag`, `aiAnomalyScore`) and displayed strictly as an advisory note.
- `RiskEngine` has **zero import dependency on AI modules**. Feeding the same vitals with different AI flags always produces an identical deterministic `RiskBand`.

### 6.3 Riverpod State Management & Reactive Dataflow

The application uses **Riverpod 2.x** with immutable state notifiers:
- `bleLinkProvider`: Exposes the current BLE state machine (`disconnected`, `scanning`, `connecting`, `connected`, `streaming`).
- `liveVitalsStreamProvider`: Subscribes to `BleService.telemetryStream`, mapping raw 20-byte packets into immutable `HealthSample` domain objects at 4 Hz.
- `ecgStreamProvider`: Streams raw 16-bit integer ECG sample batches at 31.25 Hz directly into the waveform painter.
- `currentScreeningController`: StateNotifier managing wizard progress, patient selection, symptoms, and final triage generation.

### 6.4 Drift Local Database Schema & Migrations
The local persistence engine in [app_database.dart](file:///c:/nvdia/lib/data/database/app_database.dart) compiles to high-performance C-based SQLite:
- **`Patients` Table:** Stores demographic profiles, ABHA ID, vulnerability flags (JSON array), and cloud sync status (`PENDING`, `SYNCED`, `FAILED`).
- **`Screenings` Table:** Stores complete vital sign snapshots, symptom arrays, deterministic risk band (`GREEN`/`YELLOW`/`RED`), score (0–100), triggered rule IDs, advisory AI anomaly flags, and optional DPDPA-consented GPS coordinates.
- **`WaveformBlobs` Table:** Stores metadata for compressed raw ECG and PPG sample streams. The actual raw 16-bit sample points are serialized as gzipped binary blobs on the device filesystem (`WaveformStore`) to prevent SQLite database bloat.
- **`SyncQueue` Table:** A persistent FIFO operational queue storing pending mutations (`INSERT`, `UPDATE`, `DELETE`) with retry counters and exponential backoff timers.
- **`GuidelineCache` Table:** Bundled clinical guideline database containing pre-tokenized medical protocols for offline semantic keyword retrieval.

### 6.5 60 FPS Real-Time ECG Waveform Rendering Engine
Electrocardiogram visualization requires ultra-smooth 60 FPS rendering without stutter or garbage collection (GC) pauses:
- **Circular Ring Buffer:** `EcgRingBuffer` allocates a fixed-size contiguous array in memory. When new 8-sample frames arrive, they overwrite the oldest samples using a wrap-around head index. Zero memory allocations occur during active streaming.
- **`CustomPainter` with Path Optimization:** The custom painter maps voltage values to screen coordinates using hardware-accelerated Skia/Impeller draw calls. The drawing path uses a fixed horizontal scale (typically 25 mm/s standard ECG paper speed) with a fading sweep-bar erase head.

### 6.6 Deterministic Clinical Scoring Algorithm (`RiskEngine`)
In [risk_engine.dart](file:///c:/nvdia/lib/domain/rules/risk_engine.dart), clinical risk is determined additively, capped at 100:

| Vital Parameter | Normal (0 pts) | Mild / Moderate Warning (+15–25 pts) | Severe / Critical (+40–60 pts) |
|---|---|---|---|
| **$\text{SpO}_2$** | $\ge 95\%$ | $90\% - 94\%$ (+25 pts) | $< 90\%$ (+60 pts, floors score at 61) |
| **Heart Rate** | $60 - 100\text{ bpm}$ | $101 - 120\text{ bpm}$ or $50 - 59\text{ bpm}$ (+15 pts) | $> 120\text{ bpm}$ or $< 50\text{ bpm}$ (+40 pts) |
| **Body Temp** | $36.1 - 37.5\text{ }^\circ\text{C}$ | $37.6 - 38.4\text{ }^\circ\text{C}$ or $35.5 - 36.0\text{ }^\circ\text{C}$ (+15 pts) | $\ge 38.5\text{ }^\circ\text{C}$ or $< 35.5\text{ }^\circ\text{C}$ (+40 pts) |
| **Systolic BP** | $90 - 120\text{ mmHg}$ | $121 - 139\text{ mmHg}$ (+15 pts) | $\ge 140\text{ mmHg}$ or $< 90\text{ mmHg}$ (+35 pts) |
| **Blood Glucose** | $70 - 140\text{ mg/dL}$ | $141 - 199\text{ mg/dL}$ (+15 pts) | $\ge 200\text{ mg/dL}$ or $< 70\text{ mg/dL}$ (+40 pts) |
| **ECG Rhythm** | Normal Sinus | Inconclusive / Poor Quality (+0 pts, advisory) | Ventricular Arrhythmia (+60 pts, floors at 61) |

```
Final Risk Score Calculation:
Score = Sum(Triggered Rule Points) + Vulnerability Shifts
Score = Min(Score, 100)
If Any Critical Rule Triggered ──▶ Score = Max(Score, 61)

Band Assignment:
Score 0–30   ──▶ GREEN (Normal)
Score 31–60  ──▶ YELLOW (Needs Attention)
Score 61–100 ──▶ RED (Urgent)
```

### 6.7 Offline Semantic Guideline Retrieval Engine
When an AI explanation is requested while the phone is offline:
1. The app extracts the set of `triggeredRules` from the triage result (e.g., `["spo2_critical", "temp_fever"]`).
2. It queries `GuidelineCache` in SQLite using precomputed normalized keyword tokens (`keywords MATCH ...`).
3. It retrieves exact guideline paragraphs from WHO IMCI and ICMR protocols.
4. A deterministic templating engine formats these guidelines into structured, conversational advice with safe next steps and escalation thresholds.

### 6.8 Mathematical Formulation of Clarke Error Grid
In [clarke_error_grid_widget.dart](file:///c:/nvdia/lib/features/screening/widgets/clarke_error_grid_widget.dart), blood glucose estimation pairs ($x = \text{Reference}, y = \text{Estimated}$) are classified into five geometric zones:
- **Zone A:** Points within $\pm 20\%$ of reference or both $\le 70\text{ mg/dL}$:

$$y \le 1.2 x \quad \text{and} \quad y \ge 0.8 x \quad (\text{or } x \le 70 \text{ and } y \le 70)$$

- **Zone E:** Erroneous treatment (reversing clinical reality):

$$(x \ge 180 \text{ and } y \le 70) \quad \text{or} \quad (x \le 70 \text{ and } y \ge 180)$$

- **Zone C:** Overcorrection errors:

$$(70 \le x \le 290 \text{ and } y \ge x + 110) \quad \text{or} \quad (130 \le x \le 180 \text{ and } y \le 1.4 x - 182)$$

- **Zone D:** Dangerous failure to detect hypo/hyperglycemia:

$$(x \ge 240 \text{ and } 70 \le y \le 180) \quad \text{or} \quad (x \le 70 \text{ and } 70 \le y \le 180)$$

- **Zone B:** All remaining points falling outside $\pm 20\%$ that do not lead to inappropriate clinical treatment.

---

## 7. Clinical Safety, Electrical Isolation & Field Troubleshooting

### 7.1 Electrical Patient Safety Mandate
> [!CAUTION]
> **NEVER CONDUCT AN ECG SCREENING WHILE THE ESP32 BOARD OR THE SMARTPHONE IS CONNECTED TO A WALL CHARGER (AC MAINS).**  
> Cheap USB wall adapters can leak high-voltage AC mains ripple or catastrophic transient surges through the DC ground plane directly onto the patient's skin through the AD8232 electrodes.  
> **Always unplug the device and operate exclusively from internal Li-ion battery power during clinical screenings.**

### 7.2 Field Troubleshooting Matrix

| Problem / Symptom | Probable Root Cause | Resolution Steps |
|---|---|---|
| **OLED displays `ECG: LEAD OFF`** | One or more ECG electrode pads detached or gel dried out. | Check the 3.5mm jack. Clean skin with an alcohol swab. Firmly reapply fresh adhesive electrode pads at RA, LA, and RL positions. |
| **SpO₂ values erratic or showing `— %`** | Finger cold, ambient light interference, or patient moving. | Warm patient's fingertip. Ensure finger fully covers both Red and IR LEDs. Keep hand resting flat on a table. |
| **App cannot find `SSAI-SENSE-01`** | Bluetooth disabled on phone, location permission off, or board unpowered. | Enable Bluetooth and Location services on Android. Verify the blue LED on the ESP32 is flashing and the OLED screen is illuminated. |
| **Dropped packets warning in Diagnostics** | RF interference (2.4 GHz Wi-Fi) or distance $>5\text{ meters}$. | Bring the phone within 1–2 meters of the board. Move away from high-power Wi-Fi routers. |
| **Temperature reading unexpectedly low** | Sensor held too far away from forehead ($>5\text{ cm}$) or reading hair/sweat. | Position the MLX90614 sensor 2 to 4 cm from clean forehead skin, perpendicular to the surface. |
| **ESP32 browns out / reboots during BLE broadcast** | Battery voltage sagging under load due to an unbuffered LDO. | Ensure the hardware uses the TPS63020 buck-boost module. Recharge the Li-ion battery via USB-C. |

---

*SwasthyaSetu AI — Bridging the diagnostic divide with honest engineering, clinical rigor, and compassionate technology.*
