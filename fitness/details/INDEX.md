# FitPulse AI — Details Directory Index

This directory contains copies of all key files describing the **FitPulse AI** advanced athletic wearable and biomechanical coaching system (AICTE MIC-Student Innovation, Problem Statement ID: 26213).

---

## 📋 File Catalog & Architecture

| File | Category | Original Source | Description |
| :--- | :--- | :--- | :--- |
| [`README.md`](file:///c:/nvdia/fitness/details/README.md) | Documentation | `c:\nvdia\fitness\README.md` | Executive summary, contest problem statement (ID: 26213), module overview, and quickstart guide. |
| [`HARDWARE_FITNESS.md`](file:///c:/nvdia/fitness/details/HARDWARE_FITNESS.md) | Hardware | `c:\nvdia\fitness\hardware\HARDWARE_FITNESS.md` | ESP32 DevKit V1 schematics, I2C bus pinout (MPU-6050, MAX30102, SSD1306, AD8232), and sensor placement. |
| [`pubspec.yaml`](file:///c:/nvdia/fitness/details/pubspec.yaml) | Configuration | `c:\nvdia\fitness\pubspec.yaml` | Flutter package dependencies, Bluetooth LE, audio/TTS, and UI asset configurations. |
| [`SSAI_FITNESS_FIRMWARE.ino`](file:///c:/nvdia/fitness/details/SSAI_FITNESS_FIRMWARE.ino) | Embedded Firmware | `c:\nvdia\fitness\firmware\SSAI_FITNESS_FIRMWARE\SSAI_FITNESS_FIRMWARE.ino` | ESP32 C++ firmware acquiring 6-axis MPU-6050 and analog ECG, OLED display, and 20-byte BLE telemetry streaming. |
| [`platformio.ini`](file:///c:/nvdia/fitness/details/platformio.ini) | Embedded Firmware | `c:\nvdia\fitness\firmware\SSAI_FITNESS_FIRMWARE\platformio.ini` | PlatformIO build settings, target microcontroller environment, and C++ library dependencies. |
| [`rep_counter_engine.dart`](file:///c:/nvdia/fitness/details/rep_counter_engine.dart) | Motion Engine | `c:\nvdia\fitness\lib\core\motion\rep_counter_engine.dart` | Biomechanical repetition counter state machine tracking joint angle inflection points and cadence. |
| [`fatigue_tremor_engine.dart`](file:///c:/nvdia/fitness/details/fatigue_tremor_engine.dart) | Motion Engine | `c:\nvdia\fitness\lib\core\motion\fatigue_tremor_engine.dart` | Fatigue Tremor Index (FTI) calculating 8–14 Hz gyro spectral jitter to predict form failure. |
| [`audio_coach_engine.dart`](file:///c:/nvdia/fitness/details/audio_coach_engine.dart) | Motion Engine | `c:\nvdia\fitness\lib\core\motion\audio_coach_engine.dart` | Real-time spoken voice feedback engine announcing rep counts, cadence, and form cues. |
| [`placement_mode.dart`](file:///c:/nvdia/fitness/details/placement_mode.dart) | Motion Engine | `c:\nvdia\fitness\lib\core\motion\placement_mode.dart` | Coordinate rotation matrix for wearable placement (Forearm, Chest, Thigh). |
| [`ble_protocol.dart`](file:///c:/nvdia/fitness/details/ble_protocol.dart) | BLE Protocol | `c:\nvdia\fitness\lib\core\bluetooth\ble_protocol.dart` | Binary decoders for 20-byte motion frames and 20-byte vitals frames from the ESP32. |
| [`ble_service.dart`](file:///c:/nvdia/fitness/details/ble_service.dart) | BLE Protocol | `c:\nvdia\fitness\lib\core\bluetooth\ble_service.dart` | BLE device scanner, connection lifecycle manager, and simulated offline mock generator. |
| [`athletic_strain.dart`](file:///c:/nvdia/fitness/details/athletic_strain.dart) | Domain Model | `c:\nvdia\fitness\lib\domain\models\athletic_strain.dart` | Logarithmic 0.0–21.0 cardiovascular daily strain score calculator. |
| [`heart_rate_zone.dart`](file:///c:/nvdia/fitness/details/heart_rate_zone.dart) | Domain Model | `c:\nvdia\fitness\lib\domain\models\heart_rate_zone.dart` | 5 physiological HR zones (Warm-up, Fat Burn, Aerobic, Anaerobic, Peak). |
| [`motion_telemetry.dart`](file:///c:/nvdia/fitness/details/motion_telemetry.dart) | Domain Model | `c:\nvdia\fitness\lib\domain\models\motion_telemetry.dart` | Data container for 3-axis acceleration, gyroscope, and computed pitch/roll attitude. |
| [`workout_session.dart`](file:///c:/nvdia/fitness/details/workout_session.dart) | Domain Model | `c:\nvdia\fitness\lib\domain\models\workout_session.dart` | Workout session history, consistency grade calculation, and 60-second HRR analytics. |
| [`main.dart`](file:///c:/nvdia/fitness/details/main.dart) | UI Application | `c:\nvdia\fitness\lib\main.dart` | Application entry point, athletic dark theme, and bottom tab bar navigation. |
| [`dashboard_screen.dart`](file:///c:/nvdia/fitness/details/dashboard_screen.dart) | UI Application | `c:\nvdia\fitness\lib\features\dashboard\dashboard_screen.dart` | Athletic dashboard with Strain vs. Recovery dial, fuel rings, and live BPM display. |
| [`live_workout_screen.dart`](file:///c:/nvdia/fitness/details/live_workout_screen.dart) | UI Application | `c:\nvdia\fitness\lib\features\workout\live_workout_screen.dart` | Live workout HUD with 3D avatar, fatigue tremor bar, rep counter, and voice coach. |
| [`biomechanical_avatar_painter.dart`](file:///c:/nvdia/fitness/details/biomechanical_avatar_painter.dart) | UI Application | `c:\nvdia\fitness\lib\core\widgets\biomechanical_avatar_painter.dart` | Custom canvas painter drawing the 3D wireframe humanoid avatar responding to live motion. |
| [`motion_lab_screen.dart`](file:///c:/nvdia/fitness/details/motion_lab_screen.dart) | UI Application | `c:\nvdia\fitness\lib\features\motion_lab\motion_lab_screen.dart` | 6-Axis diagnostic visualizer with artificial attitude horizon and live sensor waveforms. |
| [`readiness_screen.dart`](file:///c:/nvdia/fitness/details/readiness_screen.dart) | UI Application | `c:\nvdia\fitness\lib\features\readiness\readiness_screen.dart` | 60-Second morning ECG HRV scanner calculating RMSSD and autonomic readiness score. |
| [`workout_summary_screen.dart`](file:///c:/nvdia/fitness/details/workout_summary_screen.dart) | UI Application | `c:\nvdia\fitness\lib\features\workout\workout_summary_screen.dart` | Post-workout victory card, HR recovery grade, and unlocked achievement badges. |
| [`ble_pairing_screen.dart`](file:///c:/nvdia/fitness/details/ble_pairing_screen.dart) | UI Application | `c:\nvdia\fitness\lib\features\pairing\ble_pairing_screen.dart` | Wearable BLE scanner, RSSI indicator, and presentation mock mode toggle. |
| [`fitness_engine_test.dart`](file:///c:/nvdia/fitness/details/fitness_engine_test.dart) | Testing | `c:\nvdia\fitness\test\fitness_engine_test.dart` | Unit tests for 20-byte BLE parser, rep counter state machine, tremor index, and strain calculation. |
