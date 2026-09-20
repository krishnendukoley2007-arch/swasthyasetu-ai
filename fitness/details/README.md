# FitPulse AI — Advanced Athletic Wearable & Biomechanical Coaching System
**AICTE MIC-Student Innovation — Fitness & Sports (Problem Statement ID: 26213)**  
*Theme: "Ideas that can boost fitness activities and assist in keeping fit"*

---

## ⚡ Executive Summary

**FitPulse AI** transforms an ESP32-based biometric wearable into a high-tech personal athletic coach. By fusing a **6-Axis IMU (MPU-6050 Gyroscope & Accelerometer)** with clinical **ECG (AD8232)**, optical **PPG (MAX30102)**, and **OLED feedback**, FitPulse AI solves the biggest limitations of commercial fitness trackers:
1. **Commercial Smartwatches Suffer 10–15s Heart Rate Lag**: FitPulse AI uses instant electrical ECG R-peaks to deliver real-time heart rate and HR Recovery (HRR) during high-intensity intervals.
2. **Standard Apps Only Count Steps**: FitPulse AI provides true **biomechanical repetition counting, dynamic joint angle tracking, and fatigue tremor prediction** for Squats, Push-ups, Bicep Curls, and HIIT.
3. **No Voice or Form Coaching**: FitPulse AI integrates an offline **Spoken Audio AI Coach** and an **Interactive 3D Biomechanical Wireframe Avatar** that guides form in real time.

---

## 📱 Advanced Application Modules

### 1. High-Energy Athletic Dashboard
- **Whoop-Style Daily Strain vs. Recovery Dual Dial**: Logarithmic 0.0–21.0 strain scale balanced against morning autonomic recovery.
- **Daily Fuel Rings**: Active Calories, Workout Minutes, and Target Reps/Steps.
- **Live BPM & Zone Tracker**: Displays the current heart rate mapped into 5 physiological zones (Warm-up, Fat Burn, Aerobic Cardio, Anaerobic, and Peak).

### 2. Live Workout HUD & Biomechanical Coach
- **Interactive 3D Biomechanical Wireframe Avatar**: Custom-painted humanoid skeleton that flexes and tracks knee/hip/spine angles in real time (toggleable with 60 FPS raw motion waveform).
- **Spoken Audio AI Coach**: Real-time spoken vocal cues ("Rep 5 complete!", "Drive up through heels!", "Entering Peak Zone!").
- **Neuromuscular Fatigue Tremor Index (FTI)**: 8–14 Hz gyro spectral jitter analysis predicting muscle failure before form breaks down.
- **Wearable Placement Selector**: Forearm/Wrist vs. Chest Strap vs. Thigh/Ankle band mode with automatic DSP coordinate remapping.

### 3. Post-Workout Cinematic Summary & Victory Card
- **60-Second Heart Rate Recovery (HRR) Analysis**: Grades autonomic recovery slope (drops >25 BPM flag "Tier 1 Elite Conditioning").
- **Biomechanical Consistency Grade**: `Grade A+ • 96% Form Quality`.
- **Achievement Badges Unlocked**: `3-1-1 TEMPO MASTERY`, `CARDIO OVERLOAD`, `ZERO CHEATING DETECTED`.
- **Exportable / Shareable Victory Card**.

### 4. 6-Axis Motion Lab (MPU-6050)
- **Attitude & Artificial Horizon Indicator**: Real-time 3D pitch and roll tilt angles.
- **3-Axis Accelerometer (G-Force)**: Lateral (X), Longitudinal (Y), and Vertical Gravity (Z).
- **3-Axis Gyroscope (Angular Rate)**: Roll Rate, Pitch Rate, and Yaw Rate in °/s.
- **One-Tap Gyro Zero Calibration**.

### 5. Morning Athletic Readiness & ECG HRV
- **60-Second Morning ECG Scan**: Captures true R-R intervals to compute **RMSSD (Heart Rate Variability)**.
- **Autonomic Readiness Score (1–100)**: Recommends heavy overload volume vs. active recovery.

---

## 🛠️ Tech Stack & Directory Structure

```text
fitness/
├── android/                      # Native Android harness with BLE & motion permissions
├── firmware/
│   └── SSAI_FITNESS_FIRMWARE/    # ESP32 Arduino / PlatformIO code (MPU6050 + ECG + OLED)
│       ├── platformio.ini
│       └── SSAI_FITNESS_FIRMWARE.ino
├── hardware/
│   └── HARDWARE_FITNESS.md       # Complete circuit diagram & I2C pinout
├── lib/
│   ├── main.dart                 # FitPulse AI entry point & navigation shell
│   ├── core/
│   │   ├── bluetooth/            # 20-byte Vitals & 20-byte Motion BLE protocol
│   │   ├── motion/               # Rep counter, Audio coach, Fatigue tremor & Placement
│   │   ├── theme/                # Athletic dark theme (Volt Lime & Electric Cyan)
│   │   └── widgets/              # Biomechanical avatar painter & waveforms
│   ├── domain/models/            # HeartRateZone, MotionTelemetry, AthleticStrain, WorkoutSession
│   └── features/
│       ├── dashboard/            # Home metrics, Strain vs Recovery dial & workout launcher
│       ├── workout/              # Live athletic HUD, 3D avatar & victory summary card
│       ├── motion_lab/           # 6-Axis MPU6050 interactive visualizer
│       ├── readiness/            # 60-second ECG HRV recovery scanner
│       └── pairing/              # BLE wearable manager & presentation demo mode
├── test/
│   └── fitness_engine_test.dart  # Unit tests for protocol, rep counter, tremor & strain
└── pubspec.yaml                  # Flutter package dependencies
```

---

## 🚀 Quickstart Guide

### Running the App:
```powershell
# 1. Prepend Flutter to PATH
$env:PATH = 'C:\flutter\bin;' + $env:PATH

# 2. Enter fitness directory
cd fitness

# 3. Fetch dependencies & verify tests
flutter pub get
flutter test
flutter analyze

# 4. Launch on Android device or emulator
flutter run
```
