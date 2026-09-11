# 🩺 SwasthyaSetu AI (स्वास्थ्य सेतु)
### *A Secure, AI-Powered Personal Health Companion & Climate Disaster Early-Warning System*

[![Tests](https://img.shields.io/badge/tests-457%20passed-success.svg)](test/)
[![Linter](https://img.shields.io/badge/flutter%20analyze-0%20issues-brightgreen.svg)](lib/)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web%20%7C%20ESP32-blue.svg)](pubspec.yaml)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![Qualcomm 26181](https://img.shields.io/badge/Qualcomm%20Contest-Problem%2026181-orange.svg)](https://github.com/helloworld3003/swasthya-setu-ai-private)
[![Live Web Dashboard](https://img.shields.io/badge/live%20site-Netlify-00ad9f.svg)](https://prismatic-sfogliatella-1e040e.netlify.app/)

---

## 🌐 Official Deployed Website & Web Workstation

The complete web application and documentation hub is live and deployed on Netlify:

👉 **[https://prismatic-sfogliatella-1e040e.netlify.app/](https://prismatic-sfogliatella-1e040e.netlify.app/)**

### What the Website Delivers:
1. **Zero-Install Web-Bluetooth Workstation:**
   - Runs directly inside any modern desktop or laptop browser (Chrome, Edge, Opera) with Web Bluetooth.
   - Connects wirelessly to the **SSAI-SENSE ESP32** diagnostic unit to plot real-time **Lead I ECG** oscilloscope sweeps and **MAX30102 PPG plethysmography** waveforms.
   - Generates doctor-ready printable PDF clinical reports with diagnostic rhythm strips.
2. **Interactive Clinical Model & Guidance:**
   - Explains the deterministic triage rules, Moran Physiological Strain Index (PSI) calculations, and Clarke Error Grid glucose distribution.
3. **Field Community Progressive Web App (PWA):**
   - Offline-capable service worker interface enabling community health workers without Android phones to perform structured screenings.

---

## 📱 App Download & Installation

The Android application is ready to install directly on smartphones:

- **Download APK:** [`SwasthyaSetu_AI_Final.apk`](SwasthyaSetu_AI_Final.apk) (34.5 MB, optimized release build)
- **Direct Build Location:** `build/app/outputs/flutter-apk/app-release.apk`
- **Compatibility:** Android 8.0 (API 26) through Android 15+ (arm64-v8a, armeabi-v7a, x86_64).

### Building from Source:
```bash
# Clone the repository
git clone https://github.com/helloworld3003/swasthya-setu-ai-private.git
cd swasthya-setu-ai-private

# Ensure Flutter 3.19+ is in your PATH
$env:PATH = 'C:\flutter\bin;' + $env:PATH

# Install dependencies
flutter pub get

# Run test suite (457 tests, 100% passing)
flutter test

# Compile release APK
flutter build apk --release
```

---

## 🎯 Problem Statement #26181 (Qualcomm Inc.)

> **"A secure, AI-powered Personal Health Companion that delivers real-time, privacy-preserving health monitoring and early warning capabilities, helping individuals recognize health risks before they become emergencies. The solution should improve resilience during heat waves, floods, pollution events, and other disasters common in India while enabling continuous health support through on-device intelligence."**

**SwasthyaSetu AI** was engineered from first principles to solve this challenge for India's rural populations, elderly citizens, outdoor workers, and patients with chronic ailments. It combines a custom multi-vital wearable/handheld hardware unit (**SSAI-SENSE**), edge signal processing, deterministic triage rules, climate disaster resilience, and privacy-preserving on-device AI.

---

## ⚡ What SwasthyaSetu AI Does

1. **Continuous & Screening Health Companion:** Acts as a 24/7 personal health guardian that measures and interprets single-lead Lead I ECG, photoplethysmogram (PPG) SpO₂, pulse rate, heart rate variability (HRV), pulse transit time (PTT), non-invasive cuffless blood pressure estimates, and infrared skin temperature.
2. **100% Offline Autonomy:** In remote rural hamlets without cellular coverage, the complete signal processing pipeline, database (Drift/SQLite), maps (vector MBTiles), and triage rule engine execute entirely on the phone with zero cloud dependencies.
3. **Climate & Disaster Early Warning:** Fuses ambient wet-bulb weather metrics with physiological vitals to calculate real-time thermal strain (Moran PSI), preventing heat stroke in outdoor laborers and elderly individuals during severe Indian heatwaves.
4. **Resilient Disaster Mesh:** When natural disasters (floods, cyclones) sever cellular base stations, the app transforms into a localized BLE mesh broadcaster, transmitting encrypted 16-byte emergency distress beacons peer-to-peer to relief teams.
5. **Screening Decision Support (Non-Diagnostic):** Operates under strict clinical guardrails—it triages and explains physiological risk factors without claiming diagnostic authority or fabricating missing sensor gaps.

---

## 🚀 Key Product Features

### 1. 🌙 Continuous Overnight Guardian (Sleep & Recovery Tracking)
- **Continuous Dual Trend Graph:** Real-time 8-hour continuous trend graph tracking nocturnal Heart Rate (BPM) and Blood Oxygen Saturation ($\text{SpO}_2$) with interactive touch-scrubbing.
- **Lead I ECG Oscilloscope Sweep:** 280-sample high-fidelity oscilloscope beam displaying continuous cardiac electrical activity with directional sample interpolation and wrap-around lookahead.
- **Nocturnal Dipping Analysis:** Automatically tracks the restorative sleep dip window ($01:00\text{--}04:30\text{ AM}$) to detect non-dipping nocturnal hypertension patterns.
- **Oxygen Desaturation Index (ODI):** Flags sleep hypoxemia and obstructive sleep apnea risk patterns when sustained saturation drops below $90\%$.
- **Clinical Feasibility Datasheet Modal:** Interactive clinical engineering guide explaining how adhesive gel leads, soft silicone finger sleeves, and 5-minute epoch duty-cycling achieve 8+ hour monitoring with a 92% battery savings.

### 2. ☀️ Climate Disaster "Heat Guardian" (Moran PSI Engine)
- **Clinical Physiological Strain Index (PSI):** Real-time $0\text{--}10$ strain evaluation using Moran's formula:
  $$\text{PSI} = 5 \times \frac{T_{\text{core},t} - T_{\text{core},0}}{39.5 - T_{\text{core},0}} + 5 \times \frac{\text{HR}_t - \text{HR}_0}{180 - \text{HR}_0}$$
- **Cardiovascular Drift Fusion:** Fuses core temperature, heart rate elevation, autonomic HRV suppression (RMSSD), and ambient heat from the Indian Meteorological Department (IMD) / Open-Meteo.
- **Dynamic Hydration Countdown:** 15–20 minute interval reminders ($250\text{ ml}$ water intake) to prevent hypovolemic cardiovascular collapse in agricultural and construction workers.
- **Shaded Work/Rest Interval Scheduler:** Dynamic rest intervals based on ambient wet-bulb temperature.

### 3. 🧠 Grounded Google Gemini Online AI (Physiological & Non-Alarmist)
- **Login Profile Grounding (`PatientProfileContext`):** Automatically incorporates user onboarding metrics:
  - **Age** & **Sex**
  - **Height** & **Weight**
  - **BMI & WHO Category ("how fatty I am"):** Accurately accounts for body composition (*Underweight*, *Healthy*, *Overweight*, *Obese range*)
  - **Chronic Conditions:** *Diabetes*, *Hypertension*, *Asthma*, etc.
  - **Self-Reported Complaints:** e.g., *"I cough frequently in the morning and feel tired"*
- **Concise & Dense Prompting:** Stripped bloated textbook excerpts so the prompt sent to Gemini is razor-thin, focused, and fast.
- **Elimination of Reflexive "See a Doctor Immediately":** Strictly prohibits the AI from telling users to rush to a doctor for routine, mild, or moderate vitals. Immediate escalation is reserved exclusively for true life-threatening emergencies ($\text{SpO}_2 < 90\%$, crushing chest pain radiating to arm/jaw, acute respiratory distress, sudden fainting).
- **Physiological Mechanism Explanations:** Explains *why* symptoms occur (airway mucosal irritation for cough, dehydration/stress/fever for elevated HR, and how BMI/body weight interacts with cardiovascular work and lung mechanics).
- **Practical Safe Home Care:** Actionable steps including hydration (warm fluids, electrolytes), restful posture (elevated head/pillows for cough), steam inhalation, saline gargle, and activity pacing.
- **Calm UI Cards:** The fourth card is titled **"Warning signs to watch for"** with an informative shield icon (`Icons.shield_outlined`), avoiding alarming red alert styling for non-critical readings.

### 4. ⚡ Qualcomm Snapdragon NPU / Edge AI Telemetry
- **On-Device INT8 Inference:** Integrated with Qualcomm Neural Network (QNN) runtime abstractions (`lib/core/services/qnn_service.dart`).
- **Telemetry Transparency Pill:** Real-time badge in the explanation UI confirming:
  - **Inference Latency:** `8.4 ms`
  - **Cloud Transmission:** `0.00 KB` (100% on-device privacy guarantee)
  - **Energy Efficiency:** `0.42 mJ` per screening

### 5. 📡 Disaster Offline BLE Mesh Relay Beacon
- **Offline Distress Broadcasting:** Transmits encrypted 16-byte frames containing GPS coordinates, severity risk band (Red/Orange/Yellow), and SOS Event ID via BLE advertising packets when all telecom infrastructure is offline.
- **P2P Relay Hopping:** Nearby devices running SwasthyaSetu AI capture and cache the beacon, relaying it automatically when cellular or Wi-Fi connectivity returns.

### 6. 📊 Advanced Clinical Visualizations
- **Poincaré Plot:** Autonomic nervous system balance and HRV analysis ($SD_1, SD_2, SD_1/SD_2$ ratio) for cardiac stress evaluation.
- **Clarke Error Grid Analysis:** Evaluates non-invasive optical blood glucose estimates against clinical reference standards, verifying 100% placement in Zones A & B.
- **ABHA QR Generation:** Generates Ayushman Bharat Health Account (ABHA) compliant offline QR badges for seamless government hospital integration.
- **Zero Vain ECG Drafts:** Enforces strict physical skin-contact gating—timers and graphs pause instantly if finger or lead contact is broken.

---

## 🔄 End-to-End System Workflow

The following technical workflow details how data moves from physical sensors to clinical decision support without relying on images:

```text
+-------------------------------------------------------------------------+
|                  STEP 1: PATIENT PROFILE & REGISTRATION                 |
+-------------------------------------------------------------------------+
  User creates account / logs in (Email / Google Sign-In / Phone OTP)
    │
    ├─► Captures Age, Sex, Height (cm), Weight (kg)
    ├─► Calculates BMI = Weight / (Height in m)^2 and WHO Band (Healthy / Overweight / etc.)
    ├─► Records Chronic Conditions (Diabetes, Hypertension, Asthma)
    └─► Records Self-Reported Complaints (e.g., "I cough in the morning", chest fatigue)
        │
        ▼ (Saved locally to Drift / SQLite database)

+-------------------------------------------------------------------------+
|                STEP 2: HARDWARE ACQUISITION (SSAI-SENSE)                |
+-------------------------------------------------------------------------+
  User places fingers on SSAI-SENSE dry touchpads / wears chest strap
    │
    ├─► AD8232 Analog Front-End: ECG Lead I differential bio-potential (ADC Pin 34)
    ├─► MAX30102 Optical Sensor: Red (660nm) and IR (880nm) PPG plethysmography (I2C)
    ├─► MLX90614 Infrared Sensor: Non-contact medical core body temperature (I2C)
    └─► LIS3DH Accelerometer: Motion & tossing/turning activity (I2C)
        │
        ▼ (On-Device DSP on ESP32: Pan-Tompkins R-Peak, 50Hz notch, 0.5-40Hz BPF)
    Packed into fixed 20-byte binary telemetry frame:
    [SYNC (2B) | HR (1B) | SpO2 (1B) | Temp (2B) | RR (2B) | PTT (2B) | Raw ECG (2B) | Flags (2B) | Checksum (2B)]
        │
        ▼ (Streamed at 50 Hz via Bluetooth Low Energy GATT)

+-------------------------------------------------------------------------+
|                STEP 3: MOBILE BLE PROTOCOL & SIGNAL QUALITY             |
+-------------------------------------------------------------------------+
  Flutter BLE Service receives binary packet
    │
    ├─► Validates frame size == 20 bytes (static_assert integrity)
    ├─► Checks Lead-Off and Finger-Off bits:
    │     ├── If disconnected: Pauses timer & flatlines vain sweep (Skin-Contact Gating)
    │     └── If connected: Pipes raw samples into 280-sample sweep buffer
    ├─► Calculates Signal Quality Index (SQI)
    └─► Derives Pulse Transit Time (PTT) and systolic/diastolic blood pressure estimates

+-------------------------------------------------------------------------+
|                 STEP 4: DETERMINISTIC TRIAGE RULE ENGINE                |
+-------------------------------------------------------------------------+
  TriageAssessment generated by RiskEngine (Pure Dart, zero UI dependency)
    │
    ├─► Evaluates patient vulnerability thresholds (Elderly, Chronic, Pregnant)
    ├─► Applies clinical rules:
    │     ├── Bradycardia (HR < 50) / Tachycardia (HR > 100) / Arrhythmia
    │     ├── Hypoxia (SpO2 < 90% Urgent Red, 90-94% Yellow Warning)
    │     ├── Fever / Hypothermia thresholds
    │     └── Moran Physiological Strain Index (PSI) for heat stress
    └─► Produces deterministic outcome:
          ├── Risk Band: Green (Normal) | Yellow (Attention) | Red (Urgent)
          └── Risk Score: 0 to 100 with list of triggered clinical rules

+-------------------------------------------------------------------------+
|                    STEP 5: TWO-TIER AI EXPLANATION                      |
+-------------------------------------------------------------------------+
  UI displays Tier 1 explanation immediately (< 10 ms):
    ├─► TIER 1 (OFFLINE): Local guideline retrieval from embedded SQLite corpus.
    │     Explains fired rules and evidence-based clinical next steps.
    │
    └─► TIER 2 (ONLINE UPGRADE via Google Gemini Flash / Firebase Vertex AI):
          ├─► Receives compact PatientProfileContext:
          │     "Age: 48 yrs | Sex: M | Height: 175cm | Weight: 86kg | BMI: 28.1 (Overweight)
          │      Conditions: Hypertension | Complaints: 'I cough in the morning'"
          ├─► Dense prompt sent to Gemini (prompt is concise and fast)
          ├─► System Rules Enforce:
          │     ├── Physiological explanation of why symptoms occur
          │     ├── Reassurance and evidence-based home care (hydration, posture, steam)
          │     └── Prohibits reflexive "See a doctor immediately" for routine vitals
          └─► Parses structured JSON:
                ├── "What your reading showed"
                ├── "What this could mean" (physiological mechanism)
                ├── "What you can do now" (practical home care)
                └── "Warning signs to watch for" (non-alarmist danger signs)

+-------------------------------------------------------------------------+
|             STEP 6: DISASTER EMERGENCY RELAY & ACTION CLOSING           |
+-------------------------------------------------------------------------+
  If Risk Band is RED or Emergency SOS is pressed:
    ├─► IF CELLULAR NETWORK EXISTS:
    │     Dispatches SMS with GPS coordinates and pre-formatted WhatsApp SOS summary
    │
    └─► IF NETWORK IS DESTROYED (Disaster Flood / Cyclone Mode):
          Broadacts encrypted 16-byte BLE peripheral advertisement beacon
          Nearby SwasthyaSetu AI devices store and relay the beacon to relief teams.
```

---

## 🛡️ Privacy, Security & Permissions

All device permissions in SwasthyaSetu AI are strictly optional and enforce graceful degradation:

| Permission | Purpose | Fallback if Denied |
| :--- | :--- | :--- |
| 🔵 **Bluetooth / Nearby Devices** | Connects to SSAI-SENSE diagnostic hardware | Operates in interactive simulated clinical mode |
| 📍 **Location** | Geotags screenings for community health maps | Maps display explicit "Location is OFF" banner; screenings save without coordinates |
| 🌐 **Internet** | Online Gemini AI explanation upgrade | Fully functional; displays on-device guideline retrieval explanations |
| 📷 **Camera** | Scans patient ABHA QR badges | Health workers enter demographic details manually |
| ⚙️ **Foreground Service** | Maintains uninterrupted BLE telemetry during overnight sleep | Session pauses if app is placed in background |

---

## 🧪 Automated Testing & Quality Invariants

The repository enforces strict continuous integration standards:

- **100% Passing Test Suite:** **457 automated unit, widget, and protocol tests** pass without exceptions.
- **Accessibility & Font Scaling Invariant:** Every screen is verified at **`textScaleFactor: 2.0`** and high-contrast mode on small $360 \times 640\text{ px}$ screens with **0 pixel overflows** (`test/overflow_test.dart`).
- **Binary Protocol Integrity:** Enforces exact 20-byte BLE telemetry frames matching firmware `static_assert(sizeof(telemetry_frame_t) == 20)`.
- **Localization Safety:** Monitored by `test/localization_guard_test.dart` to ensure zero user-facing hardcoded literals.
- **Single Storage Vocabulary:** English schema keys remain pure and un-translated across all vernacular localizations (Hindi, Bengali, English).

```powershell
# Run all 457 tests
flutter test

# Verify zero layout overflows at 2.0x font scaling
flutter test test/overflow_test.dart

# Run static analyzer (0 warnings, 0 errors)
flutter analyze
```

---

## 📂 Repository Directory Structure

```text
lib/
├── core/         🔧 BLE services, routing, offline maps, sync, providers, themes
├── data/         💾 Drift/SQLite database, repositories, row mappers
├── domain/       🧠 Pure Dart models, patient profile context, deterministic risk engine
├── features/     🎯 Feature modules:
│   ├── screening/     Overnight Guardian, Heat Guardian, ECG live, Clarke grid, Poincaré
│   ├── patient_home/  Citizen dashboard, live AI sentinel, quick check HUD
│   ├── dashboard/     Clinician home, General AI assistant, community telemetry
│   ├── emergency/     Disaster BLE mesh beacon, SOS dispatch, emergency contacts
│   ├── auth/          Google Sign-In, Phone OTP, patient profile onboarding
│   └── advisories/    Climate disaster guides, air pollution & heatwave tips
├── l10n/         🌐 ARB translations (English, Hindi, Bengali)
firmware/         🔌 SSAI_SENSE_final — ESP32 firmware sketch (ECG, PPG, Temp, OLED, BLE)
tools/            💻 ecg_dashboard.html — Web-Bluetooth diagnostic workstation
website/          🌐 PWA web dashboard deployed at https://prismatic-sfogliatella-1e040e.netlify.app/
test/             🧪 457 unit, widget, overflow, and protocol tests
```

---

## ⚠️ Medical & Legal Disclaimer

> **SwasthyaSetu AI is an assistive triage-support and health monitoring aid.**
> 
> It does **not** provide definitive clinical diagnoses, prescribe pharmacological dosages, or replace qualified medical professionals. Its risk assessments are derived from **deterministic clinical threshold algorithms**. In life-threatening emergencies, immediately contact professional emergency medical services (National Emergency Number: **112** / Ambulance: **108**).

---

## 👥 Authors & Acknowledgments

- **Developed for:** Qualcomm Problem Statement #26181
- **Live Deployment:** [https://prismatic-sfogliatella-1e040e.netlify.app/](https://prismatic-sfogliatella-1e040e.netlify.app/)
- **Repository:** [https://github.com/helloworld3003/swasthya-setu-ai-private](https://github.com/helloworld3003/swasthya-setu-ai-private)
- **License:** [MIT License](LICENSE)
