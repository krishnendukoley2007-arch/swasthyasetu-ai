# FitPulse AI — Improvement Specification (for the coding agent)

**Project:** FitPulse AI — ESP32 wearable + Flutter app (`fitpulse_ai`), AICTE / SIH Problem Statement **SIH26213** (Fitness & Sports, category: **Hardware**)
**Owner:** Krishnendu Koley (student, learning embedded + robotics; explain non-obvious engineering choices in code comments)
**Date of review:** 2026-09-19
**Scope:** `firmware/SSAI_FITNESS_FIRMWARE/*`, `lib/**`, `test/**`, `pubspec.yaml`, `README.md`, `hardware/HARDWARE_FITNESS.md`

---

## 0. How to use this document

1. **Read every file completely before editing.** The reviewer did not see `lib/core/theme/fitness_theme.dart`, and only saw the truncated middle of `dashboard_screen.dart` (lines ~211–281) and `live_workout_screen.dart` (lines ~242–415). **Verify each finding below against the real code before changing anything.** If a finding is wrong, say so in the commit message and skip it.
2. Work in phase order: **P0 → P1 → P2 → P3 → P4 → P5** (P6 is optional stretch). One task ID = one commit. Commit message format: `[P0-3] Stop demo simulation when real BLE connects`.
3. After every task run: `flutter analyze` and `flutter test`. For firmware: `pio run`. Do not leave the build red between commits.
4. **Ground rules (apply everywhere):**
   - **R1 — No fabricated data presented as real.** Any simulated or hard-coded value must be visibly labelled `SIMULATED` / `SAMPLE` in the UI, or removed.
   - **R2 — One source of truth per metric.** (e.g. reps are counted in exactly one place.)
   - **R3 — No magic numbers.** Every threshold/constant goes in a named constant or config class with a comment stating the unit and why the value was chosen.
   - **R4 — Logic lives outside widgets** (engines/controllers/services) so it is unit-testable.
   - **R5 — Do not add a package without listing it and the reason in the commit message.** Remove packages that are unused.
   - **R6 — Keep demo mode.** It is valuable for presentations. It must never silently start and never mix with real data.
   - **R7 — Wellness, not medical.** No diagnosis language. Add a "not a medical device" disclaimer (P3-9).
5. Keep protocol v1 working until protocol v2 (P1-8) is implemented on **both** firmware and app side. The app must support both versions during the transition.

---

## 1. Current state at a glance

| Feature (as claimed in README) | Actual state in code | Target |
|---|---|---|
| ECG heart rate / R-peaks | `PIN_ECG_IN` is configured but never read. HR is a sine wave (`mockHr`). | Real ECG acquisition + R-peak detection (P1-2) |
| HRV / RMSSD readiness | `readiness_screen.dart` shows fixed 89 / 58 / 56 after a 60 s timer. | Real RR-based RMSSD + baseline-relative score (P2-9) |
| SpO2, skin temp, battery | Hard-coded 98 / 36.8 / 94. MAX30102 and MLX90614 are not initialised in the `.ino`. | Real drivers or remove (P1-3, P1-4, P1-5) |
| Blood pressure (systolic/diastolic/PTT) | Hard-coded 120/78/220. | Remove from protocol and UI (P1-6) |
| Rep counting | Fixed thresholds 1.25/0.95 for all exercises; also a second, different counter in firmware. | Adaptive, per-exercise, single source of truth (P2-2) |
| Form quality / grade / badges | Score is rep-rhythm only and converges to 100; badges always shown. | Honest, computed metrics (P2-3) |
| Fatigue Tremor Index "8–14 Hz" | Variance of gyro jerk sampled at 20 Hz (cannot see above 10 Hz). | ≥100 Hz sampling + band-pass 8–12 Hz (P1-7, P2-4) |
| Steps / cadence / intensity | `g_steps` never increments; cadence=24 and intensity=80 constants. | Real step detection (P1-7) |
| 60 s Heart Rate Recovery | `peakBpm - 28` | Real measurement after workout (P2-10) |
| Daily strain | Dashboard constant 13.8; `_finishWorkout` uses a wrong formula; `AthleticStrain` unused. | TRIMP-based strain (P2-11) |
| Share victory card | Shows a snackbar claiming export; does nothing. | Real PNG share (P3-6) |
| "AI" | No ML anywhere; coach is rule-based. | Earn it via exercise recognition (P6) or rename honestly |
| Workout history | `WorkoutSession` model exists, never saved. | Local persistence (P3-4) |

---

## 2. P0 — Bug fixes and honesty fixes (do these first, ~1 day)

### P0-1 — Fix SDK constraint
- **File:** `pubspec.yaml`
- **Problem:** `sdk: '>=3.2.0 <4.0.0'`, but the code uses `Color.withValues(alpha:)` (Flutter ≥ 3.27 / Dart ≥ 3.6) and `WidgetStateProperty` (Flutter ≥ 3.22).
- **Fix:** set `sdk: '>=3.6.0 <4.0.0'` (and `flutter: '>=3.27.0'`). Run `flutter pub get`.
- **Accept:** `flutter analyze` clean on a fresh clone with the stated SDK.

### P0-2 — BLE scan cannot find the device
- **Files:** `lib/core/bluetooth/ble_service.dart` (`startScan`), firmware advertises `"FITPULSE-AI"`.
- **Problem:** `withNames: ['SSAI-SENSE','FITPULSE','SwasthyaSetu']` is an **exact-name** filter. `"FITPULSE-AI"` matches none of them. Also, with a 128-bit service UUID in the advertisement the name is likely in the *scan response*, so name filters are unreliable anyway.
- **Fix:**
```dart
await FlutterBluePlus.startScan(
  timeout: timeout,
  withServices: [Guid('FFE0')], // matches SERVICE_UUID 0000ffe0-0000-1000-8000-00805f9b34fb
);
```
- Also listen to `FlutterBluePlus.isScanning`; when it becomes `false` and `_state == scanning`, set state back to `disconnected` (currently the state stays `scanning` forever after the timeout).
- **Accept:** a real ESP32 flashed with the current firmware appears in the pairing list on a physical Android phone.

### P0-3 — Demo simulation starts secretly and mixes with real data
- **Files:** `main.dart`, `motion_lab_screen.dart` (`initState`), `live_workout_screen.dart` (`initState`), `readiness_screen.dart`, `ble_service.dart` (`connectToDevice`).
- **Problem:** `MainNavigationShell` uses `IndexedStack`, which builds **all four tabs at app launch**. `MotionLabScreen.initState()` therefore calls `startDemoSimulation()` immediately at startup. When real hardware later connects, the demo timer keeps running and both streams feed the same controllers.
- **Fix:**
  1. Remove every auto-start of demo mode from screens' `initState`.
  2. In `connectToDevice()` call `stopDemoSimulation()` **first**.
  3. Screens that need data and have none show an explicit empty state: "No sensor connected" with two buttons: **Connect hardware** and **Use demo data**.
  4. Demo must be started only by a user tap.
  5. (Longer-term, P3-1) replace with `SensorSource` abstraction so mixing is structurally impossible.
- **Accept:** cold-start app → no data flows until the user picks a source. Connect hardware while demo is running → demo stops, only hardware data appears.

### P0-4 — BLE connection lifecycle and leaks
- **File:** `ble_service.dart`, `ble_pairing_screen.dart`, `dashboard_screen.dart`.
- **Problems:**
  - `connectToDevice` subscribes to **every** notify characteristic (including the generic GATT one) and never cancels `lastValueStream` subscriptions.
  - Nothing listens to `device.connectionState`, so if the band switches off the app still says CONNECTED.
  - `BlePairingScreen` and `DashboardScreen` listen to streams and never cancel them in `dispose()`.
- **Fix:**
```dart
final svc = services.firstWhere((s) => s.uuid == Guid('FFE0'));
for (final c in svc.characteristics.where((c) => c.properties.notify)) {
  await c.setNotifyValue(true);
  final sub = c.lastValueStream.listen(_handleIncomingPacket);
  device.cancelWhenDisconnected(sub);
}
final connSub = device.connectionState.listen((s) {
  if (s == BluetoothConnectionState.disconnected) {
    _connectedDevice = null;
    _setState(BleConnectionState.disconnected);
  }
});
device.cancelWhenDisconnected(connSub, delayed: true);
```
  (Verify signatures against the installed `flutter_blue_plus` version.)
- Add `reconnecting` to `BleConnectionState`. Persist the last device id (`shared_preferences`) and try to auto-reconnect on app start.
- Expose `FlutterBluePlus.adapterState` so the UI can show "Bluetooth is off" with a button to turn it on.
- Store all `StreamSubscription`s in screens and cancel them in `dispose()`.
- **Accept:** switch the ESP32 off mid-session → within ~5 s the UI shows DISCONNECTED; switch on → auto reconnects. No listener leaks (verify with a hot-restart loop).

### P0-5 — "DONE" button on the summary screen can blank the app
- **File:** `workout_summary_screen.dart`
- **Problem:** `LiveWorkoutScreen` uses `pushReplacement` to open the summary, so the stack is `[Shell, Summary]`. The two `Navigator.pop(context)` calls in DONE then pop the **root** route → black screen.
- **Fix:** `Navigator.of(context).popUntil((route) => route.isFirst);`
- **Accept:** finish workout → DONE → returns to the dashboard tab. Add a widget test.

### P0-6 — Wrong strain calculation, real calculator unused
- **File:** `live_workout_screen.dart` (`_finishWorkout`)
- **Problem:** `12.0 * (1.0 - (_calories / 500.0)) + reps * 0.4` gives *less* strain for *more* calories. Meanwhile `AthleticStrain.calculate()` exists and is not called.
- **Fix (interim; P2-11 replaces the model):**
```dart
final strain = AthleticStrain.calculate(
  secondsInZone: _zoneSeconds,
  totalReps: _reps,
  morningRecoveryScore: 88, // TODO: use persisted readiness (P2-9)
).currentStrain;
```
- **Accept:** more time in higher zones ⇒ strictly higher strain (add a monotonicity unit test).

### P0-7 — Rep timing uses whole seconds
- **File:** `live_workout_screen.dart`, `rep_counter_engine.dart`
- **Problem:** `_repEngine.processSample(motion, _secondsElapsed.toDouble())` — `_secondsElapsed` is an integer incremented once per second, so rep duration/cadence is quantised to 1 s.
- **Fix:** use a `Stopwatch` (pause/resume with the workout) or the sample's device timestamp (P1-8). Pass milliseconds-resolution seconds.
- **Accept:** unit test with samples at 20 Hz shows cadence resolution ≤ 50 ms.

### P0-8 — Joint angle from acceleration is linear instead of `asin`
- **File:** `placement_mode.dart`
- **Problem:** `(az.clamp(-1,1) * 90).abs()` is wrong: tilt from gravity is `asin(a/g)`. At a = 0.5 g the true tilt is 30°, the code returns 45°.
- **Fix:** `math.asin(v.clamp(-1.0, 1.0)) * 180 / math.pi`. Keep the sign; apply `.abs()` only where the UI needs magnitude. (Full replacement in P2-5.)
- **Accept:** test `az = 0.5 → 30° ± 0.1`, `az = 1 → 90°`, `az = 0 → 0°`.

### P0-9 — Audio coach spams and self-interrupts
- **Files:** `audio_coach_engine.dart`, `live_workout_screen.dart`
- **Problem:** in the motion listener, `if (tremor.shouldAlert && _tremorIndex > 82.0) speakPostureAlert(...)` runs on **every sample** (10–20 Hz). `speakPostureAlert` uses `highPriority: true`, which bypasses the cooldown, and `speak()` calls `_tts.stop()` first. Result: the phrase restarts 10–20 times per second and never finishes.
- **Fix:**
  1. Edge-trigger: keep `_lastSeverity`; speak only when severity **rises** into `highFatigue` or `imminentFailure`.
  2. Per-phrase cooldown even for high priority (`Map<String, DateTime> _lastByKey`, default 8 s), plus a global minimum gap of ~1.2 s.
  3. Do not interrupt an in-progress phrase with a lower- or equal-priority one; queue at most one pending phrase.
  4. Configure audio ducking so the user's music keeps playing (`flutter_tts` `setIosAudioCategory` with `mixWithOthers`/duck options; on Android request transient-may-duck audio focus).
  5. `speakZoneChange` exists but verify it is called; if not, call it with zone-change hysteresis (new zone must persist ≥ 5 s).
- **Accept:** unit-test the limiter with a fake clock: 100 alerts in 1 s produce ≤ 1 spoken phrase.

### P0-10 — Firmware: undefined behaviour and dead counters
- **File:** `SSAI_FITNESS_FIRMWARE.ino`
- **Problems:**
  - `mockHr = 110 + (uint8_t)(15 * sin(now / 10000.0));` — casting a **negative float to an unsigned type is undefined behaviour**. Use `(int)`.
  - `g_steps` is never incremented, so `step_count` is always 0.
  - `cadence_spm = 24` and `intensity = 80` are constants.
- **Fix (interim):** `mockHr = 110 + (int)(15 * sin(now / 10000.0));` and report `steps=0, cadence=0, intensity=0` until P1-7 provides real values. (P1 removes `mockHr` entirely.)

### P0-11 — Fake "Share" button
- **File:** `workout_summary_screen.dart`
- **Problem:** the SnackBar says "exported to clipboard & gallery!" but nothing is exported.
- **Fix (interim):** disable the button with tooltip "Coming soon" or hide it. Real implementation in P3-6.

### P0-12 — Dependencies, permissions
- **Files:** `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
- **Problem:** `flutter_riverpod`, `sensors_plus`, `uuid`, `intl`, `permission_handler` are declared but effectively unused. BLE permissions must be declared and requested at runtime.
- **Fix:**
  - Decide per package: use it (see P3-1 for Riverpod, P3-2 for `sensors_plus`) or remove it.
  - Android manifest: `BLUETOOTH_SCAN` (with `neverForLocation` flag if location is not derived), `BLUETOOTH_CONNECT`, legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` + `ACCESS_FINE_LOCATION` with `android:maxSdkVersion="30"`.
  - iOS: `NSBluetoothAlwaysUsageDescription` with a human-readable string.
  - Runtime permission request flow with a rationale screen and a "open settings" fallback if permanently denied.
- **Accept:** fresh install on Android 12+ and Android 10 can scan and connect.

### P0-13 — Relabel overclaims (until real features land)
Apply immediately, search the whole codebase and docs:

| Current text | Replace with |
|---|---|
| "clinical-grade ECG" | "single-lead ECG (hobby-grade AD8232)" |
| "3D wireframe avatar" | "2D skeleton avatar" (painter is 2D) |
| "KNEE: 90°" in avatar | "THIGH ANGLE" (a single thigh sensor cannot measure knee angle) |
| "ZERO CHEATING DETECTED" | remove (P2-3 replaces the badge system) |
| "Tier 1 Elite Conditioning / ELITE RECOVERY" | "Excellent recovery" |
| "CNS fully recovered", "primed for heavy training" | "HRV above your baseline" (wellness wording) |
| "Whoop-style" | "Daily strain vs. recovery" (avoid third-party brand names in UI/pitch) |
| "Gyroscope Biomechanical Consistency" | "Movement consistency" |
| Dashboard constants (380 kcal, 5420 steps, 13.8 strain, 96% form, 88 recovery) | show `--` with "No data yet", or a visible `SAMPLE DATA` chip |
| Readiness result 89 / 58 / 56 | show `--` until a real scan completes |

---

## 3. P1 — Firmware: make the hardware real

Goal: every field the app displays as "live" comes from a real sensor, or is explicitly marked unavailable. Do not start P2 algorithm work on live data before P1-1, P1-2, P1-7 and P1-8 exist, because the algorithms need correct sampling rates and timestamps.

### P1-1 — Firmware architecture (FreeRTOS tasks, no `loop()` timing)
Replace the `millis()`-polling `loop()` with tasks and ring buffers:

| Task | Core | Period | Responsibility |
|---|---|---|---|
| `ecgTask` | 1 | 2 ms (500 Hz) — minimum 4 ms (250 Hz) | ADC read, filtering, QRS detection, lead-off check |
| `imuTask` | 1 | 10 ms (100 Hz), or 5 ms (200 Hz) | Read MPU-6050, calibrate, batch samples, step detection |
| `ppgTask` | 1 | 10 ms (100 Hz) | MAX30102 FIFO read, HR/SpO2 |
| `bleTask` | 0 | event-driven | Pack + notify frames from queues |
| `uiTask` | 0 | 500 ms | OLED refresh, battery, temperature |

- Use `vTaskDelayUntil()` (fixed period, no drift). Arduino-ESP32 runs FreeRTOS at 1 kHz so 2 ms is achievable. Do **not** call `analogRead()` or I²C from an ISR.
- Share the I²C bus with a **mutex** (`SemaphoreHandle_t i2cMutex`). A full OLED frame (`display.display()`, 1 KB) takes ~25 ms at 400 kHz and would otherwise block IMU reads. Measure worst-case mutex wait; if it exceeds ~2 ms, use the MPU-6050 hardware FIFO (INT pin is already wired to GPIO 19) or update the OLED in page mode.
- Producers push to `xQueue`/ring buffers; the BLE task consumes. Never block a sensor task on BLE.
- Put all DSP in header-only, hardware-independent files (`dsp/biquad.h`, `dsp/qrs_detector.h`, `dsp/step_detector.h`) so they can be unit-tested on a PC with PlatformIO's `native` environment (see P4-3).
- Optional: migrate from the legacy Bluedroid `BLEDevice` library to **NimBLE-Arduino** (smaller RAM/flash, faster notifications).
- Add a task watchdog and a `sensor_status` bitmask (P1-8); a failed sensor must not crash the loop.

### P1-2 — Real ECG (AD8232) acquisition and R-peak detection
**Acquisition**
- Pin: GPIO 34 (ADC1_CH6). Use `analogSetPinAttenuation(PIN_ECG_IN, ADC_11db)` and `analogReadMilliVolts()` (better linearity than raw counts).
- Sample at **500 Hz** (minimum 250 Hz). RR timing resolution is 1/fs; RMSSD needs a few ms accuracy, so 500 Hz, or parabolic interpolation around each detected peak, is recommended.
- Lead-off: configure `LO+` (GPIO 32) and `LO-` (GPIO 35) as inputs. If either is HIGH → leads off → `ecg_quality = 0`, suppress beat detection, set flag. Wire the AD8232 `SDN` pin optionally to save power.
- Electrical noise: 100 nF + 10 µF decoupling near the AD8232 supply, short shielded/twisted electrode leads, common ground with the ESP32. Keep the ADC away from WiFi (WiFi unused; BLE is fine on ADC1).

**Filtering** (Direct Form II Transposed biquads; generate coefficients offline with `scipy.signal.butter(..., output='sos')` and paste as constants):
```cpp
struct Biquad {                     // a0 normalised to 1
  float b0,b1,b2,a1,a2, z1=0, z2=0;
  float process(float x) {
    float y = b0*x + z1;
    z1 = b1*x - a1*y + z2;
    z2 = b2*x - a2*y;
    return y;
  }
};
```
- Display/analysis band-pass: 0.5–40 Hz.
- **50 Hz mains notch** (India mains = 50 Hz).
- Detection copy: band-pass 5–15 Hz for QRS emphasis.

**R-peak detection (Pan–Tompkins style)**
1. Band-pass 5–15 Hz → 2. causal derivative `y[n] = (2x[n] + x[n-1] - x[n-3] - 2x[n-4]) / 8` → 3. square → 4. moving-window integration, ~150 ms window → 5. adaptive thresholds:
   - `SPKI = 0.125*peak + 0.875*SPKI` (signal peak), `NPKI = 0.125*peak + 0.875*NPKI` (noise peak)
   - `THRESH = NPKI + 0.25*(SPKI - NPKI)`
6. Refractory period 200 ms; T-wave check within 360 ms (compare slope; reject if < half the previous QRS slope); search-back with lower threshold if no beat within 166 % of the mean RR.
7. Locate the exact R-peak on the 0.5–40 Hz signal within ±50 ms of the integrator peak; timestamp = sample index / fs (device ms clock).

**Artifact rejection and outputs**
- Valid RR: 300–2000 ms; reject beats deviating > 20 % from the median of the last 5 RR intervals (mark as ectopic/artifact, do not use in HR/HRV).
- `heart_rate` = 60000 / median of last 5–8 valid RR (smooth, not per-beat).
- `ecg_quality` (0–100): from lead-off state, ADC saturation, ratio of R-peak amplitude to noise RMS, and fraction of valid beats in the last 10 s.
- Emit a **beat event** per R-peak (P1-8 frame `0x13`) — do not rely on a `flags` bit in a 2 Hz packet (beats between packets would be lost).

**Bring-up procedure (do in this order, in code comments/README):**
1. Print raw ADC to Serial Plotter; confirm a recognisable ECG with electrodes on the body.
2. Print filtered signal; confirm 50 Hz gone.
3. Print detected peaks over the signal; confirm 1 marker per QRS.
4. Compare HR with a reference (pulse oximeter or chest strap) for 5 min.
5. Only then add BLE.

**Safety:** when electrodes are on a person the ESP32 must run from a **LiPo battery only**, never while connected to a USB port/charger. Document this in `HARDWARE_FITNESS.md` (P5-2).

### P1-3 — Real PPG (MAX30102): heart rate and SpO₂
- `platformio.ini` already includes the SparkFun MAX3010x library; the `.ino` never includes/initialises it.
- Configure: LED mode red+IR, sample rate 100 Hz, pulse width 411 µs, ADC range 4096, sample averaging 4, LED current tuned (start ~0x1F, adjust so the DC level is mid-range).
- Finger detection: IR raw < ~50 000 ⇒ no finger ⇒ report invalid (0) and set flag.
- HR: `checkForBeat()` or peak detection on the AC component, median of the last N intervals.
- SpO₂: SparkFun's Maxim algorithm (`spo2_algorithm.h`) on 100-sample red/IR buffers, or ratio-of-ratios `R = (ACred/DCred)/(ACir/DCir)`. Reject when the library returns its invalid marker. Treat SpO₂ as an **estimate** ("wellness only") and mark motion-corrupted windows invalid.
- Define which sensor is authoritative per placement and send it in `hr_source` (P1-8): chest → ECG; finger/ear → PPG; forearm → PPG (poor during motion; show a quality indicator).
- Handle sensor absence: if `particleSensor.begin()` fails, clear the `sensor_status` bit; never fake values.

### P1-4 — Skin temperature (MLX90614) or remove
- Either initialise `Adafruit_MLX90614` (I²C 0x5A) and send the real object temperature labelled **skin temperature** (not core body temperature), or remove the field from the UI/docs. Invalid ⇒ sentinel `INT16_MIN`.

### P1-5 — Battery measurement
- Add a resistor divider (2 × 100 kΩ) from the LiPo to an ADC1 pin not already used (e.g. GPIO 33 or 36/39 — GPIO 32/34/35 are taken by the ECG). Average 16 samples; map 3.3–4.2 V to % using a small lookup curve (LiPo discharge is non-linear); smooth over ~10 s. If no divider is fitted send `0xFF` = unknown. Never send a constant.

### P1-6 — Remove blood pressure
- PTT-based blood pressure requires per-user calibration against a cuff and is not accurate in this build. Remove `systolic`, `diastolic`, `ptt_ms` from the vitals frame and from every doc/UI. Re-use those bytes (P1-8).

### P1-7 — IMU: correct sampling, calibration, steps, intensity
- **Sampling:** ≥ 100 Hz (200 Hz preferred) from a fixed-period task. Set accel ±4 g. Gyro ±500 dps. Set DLPF bandwidth to **44 Hz** (`MPU6050_BAND_44_HZ`); the current 21 Hz filter attenuates the 8–12 Hz tremor band you want to measure. Explain **Nyquist** in a comment: to observe frequency *f* you must sample faster than 2 f — the current 20 Hz stream cannot see anything above 10 Hz.
- **Gyro bias calibration:** on boot (and on a control command) keep the device still for 2 s, average gyro readings, store bias in NVS (`Preferences`), subtract in the task. Report calibration state in `sensor_status`.
- **Steps/cadence:** peak detection on the low-passed (≈5 Hz) acceleration magnitude minus 1 g, adaptive threshold (e.g. 0.5 × running peak amplitude), minimum interval 250 ms, maximum 2 s; `cadence_spm = 60 / median(last 5 step intervals)`; increment `g_steps` on each accepted step. If the wearing position makes steps unreliable, report 0 rather than a guess.
- **Intensity (0–100):** moving RMS of `‖a‖ − 1 g` over 2 s, mapped with a documented scale.
- **On-device rep counting:** remove the crude `az > 130 / az < 95` counter from the firmware (R2: the phone engine in P2-2 is the source of truth). Set `rep_count = 0` (reserved) and remove "HARDWARE REPS" from Motion Lab. (Optional later: port the *validated* P2-2 algorithm to firmware for phone-less counting on the OLED.)
- Units: send accel in **mG** (`int16`), gyro in **0.1 °/s** (`int16`).

### P1-8 — BLE protocol v2 (backward compatible)
**Why:** v1 is limited to 20-byte frames (default ATT MTU 23). v2 negotiates a larger MTU, batches IMU samples with timestamps, streams real ECG beats, and drops fake fields.

**MTU/connection settings**
- Firmware: `BLEDevice::setMTU(247)` (or NimBLE equivalent). App (Android): `await device.requestMtu(247)` after connecting; on Android also `requestConnectionPriority(ConnectionPriority.high)` during workouts. iOS negotiates automatically. The app must read the negotiated MTU and choose a batch size accordingly; if MTU stays 23 it falls back to v1 single-sample motion frames.

**Services/characteristics** (service `FFE0` unchanged):

| UUID | Name | Properties | Content |
|---|---|---|---|
| `FFE1` | Vitals | notify, read | Frame `0x01` @ 1 Hz |
| `FFE2` | IMU | notify | Frame `0x11` (v2) or `0x03` (v1 fallback) |
| `FFE3` | ECG/Beats | notify | Frame `0x12` (waveform) and `0x13` (beat events) |
| `FFE4` | Control | write | Commands (below) |
| `FFE5` | DeviceInfo | read | Firmware version, capabilities |

All frames: byte 0 = type, byte 1 = protocol version (`2`). All multi-byte fields little-endian. Use `#pragma pack(push,1)` + `static_assert(sizeof(...))` on the firmware side, mirrored tests on the Dart side.

**Frame `0x01` Vitals (exactly 20 bytes, 1 Hz)**

| Offset | Type | Field | Notes |
|---|---|---|---|
| 0 | u8 | type = 0x01 | |
| 1 | u8 | version = 2 | |
| 2 | u8 | heart_rate_bpm | 0 = invalid |
| 3 | u8 | spo2_pct | 0 = invalid |
| 4 | i16 | skin_temp_c ×100 | `INT16_MIN` = invalid |
| 6 | u16 | last_rr_ms | 0 = invalid |
| 8 | u8 | signal_quality 0–100 | ECG or PPG quality of the active source |
| 9 | u8 | flags | b0 leads_off, b1 finger_present, b2 motion_artifact, b3 charging |
| 10 | u8 | sensor_status | b0 MPU, b1 MAX30102, b2 AD8232, b3 MLX90614, b4 OLED, b5 gyro_calibrated |
| 11 | u8 | hr_source | 0 = ECG, 1 = PPG, 255 = none |
| 12 | u8 | battery_pct | 255 = unknown |
| 13 | u8 | reserved | |
| 14 | u16 | steps | |
| 16 | u32 | uptime_ms | device clock |

**Frame `0x11` IMU batch (variable length)**

| Offset | Type | Field |
|---|---|---|
| 0–1 | u8,u8 | type=0x11, version=2 |
| 2 | u8 | seq (wraps; detect drops) |
| 3 | u8 | n (samples in frame) |
| 4 | u32 | t0_ms (device time of first sample) |
| 8 | u8 | sample_period_ms (10 = 100 Hz) |
| 9 | u8 | reserved |
| 10… | n × 12 B | `ax, ay, az` (i16, mG), `gx, gy, gz` (i16, 0.1 °/s) |

Frame size = 10 + 12·n ≤ MTU − 3. With MTU 247 → n up to 19.

**Frame `0x12` ECG waveform chunk (optional, for the live ECG display)**
`type, ver, seq, n, t0_ms(u32), fs_code(u8: 0=125 Hz, 1=250 Hz), reserved, n × i16` where each sample = filtered mV × 100 at the ADC pin. Decimate to 125 Hz for BLE; analysis stays on-device.

**Frame `0x13` Beat event (12 bytes)**
`type(1), ver(1), seq(1), quality(1), t_ms(u32) = R-peak device time, rr_ms(u16) = since previous accepted beat (0 = first), amp(u16)`.

**Control characteristic (write)** — first byte = opcode:
`0x01` start/stop streams (bitmask: vitals, imu, ecg, beats) · `0x02` set IMU rate (Hz, u16) · `0x03` recalibrate gyro · `0x04` set placement id (for the OLED) · `0x05` ping (for clock-offset estimation).

**DeviceInfo (read):** firmware version (3 bytes), protocol version, sensor-presence bitmask, imu_rate_hz (u16), ecg_fs_hz (u16).

**Clock sync (app side):** maintain `offset = phoneReceiveTime − deviceTime` and keep the minimum over a sliding window (BLE latency only adds delay), then map device timestamps to phone time. Use **device timestamps** for all DSP (rep timing, RR, tremor), never `DateTime.now()` at receipt.

**App side changes**
- `ble_protocol.dart`: add parsers for `0x11`, `0x12`, `0x13`; keep v1 parsers; select by `bytes[1]`. Return typed objects: `ImuBatch`, `ImuSample`, `BeatEvent`, `VitalsV2`.
- Sentinel values must map to `null` (never show 0 as a real reading).
- Add tests that build byte arrays exactly like the firmware struct (see P4-1).

### P1-9 — Firmware quality items
- Keep `initOLED()` failure non-fatal but reflect it in `sensor_status`.
- OLED shows real values or `--`; never fake numbers. Show BLE state, HR (with source), reps only if the phone reports them (control opcode), battery, and sensor health icons.
- Re-advertise after disconnect (already present); add a connection-supervision timeout so a phone that walks away does not leave the device stuck.
- Handle `millis()` rollover (49 days) for `uptime_ms` differences — use unsigned subtraction consistently.
- `platformio.ini`: add a `[env:native]` for DSP unit tests (P4-3) and pin library versions exactly (no `^`) for reproducible builds.

---

## 4. P2 — Algorithms and signal processing (app side)

Develop each algorithm **in Python first** using recorded data (P4-2 data logger), evaluate, then port to Dart. Keep both implementations in the repo (`tools/analysis/`), and cross-check them with the same test vectors.

### P2-1 — Sensor abstraction and time base
- Introduce typed models: `ImuSample{tMs, ax, ay, az, gx, gy, gz}` (units: g and °/s), `BeatEvent{tMs, rrMs, quality}`, `VitalsSample`.
- All engines take `ImuSample` with device time; none call `DateTime.now()`.
- `MotionTelemetry` keeps `pitch`/`roll` only as "accel-only tilt (static)"; add the filtered attitude from P2-5 as the primary orientation.

### P2-2 — Rep counter redesign
**Problems in the current engine:** one fixed hysteresis pair (1.25 / 0.95) for all exercises even though the signals have different units/scales; orientation-dependent raw axis; `peakInflexion` is never used; integer-second timestamps; no range-of-motion (ROM) check, so fidgets count.

**Design:**
1. **Signal:** the segment angle from the attitude estimator (P2-5), e.g. thigh pitch for squats, forearm/upper-arm pitch for curls. Low-pass at ~4 Hz (Butterworth, zero-phase not needed).
2. **Exercise profiles** (`ExerciseProfile`, one config per `WorkoutType`):

| Exercise | Recommended placement | Primary signal | Min ROM | Rep duration bounds |
|---|---|---|---|---|
| Squats | Thigh | thigh pitch | ≥ 50° | 1.0–6 s |
| Bicep curls | Forearm | forearm pitch | ≥ 60° | 0.8–5 s |
| Push-ups | Upper arm or forearm | segment angle (fallback: vertical linear accel peaks with chest strap) | ≥ 25° | 0.8–5 s |
| Jumping jacks | Chest / wrist | landing impact peaks on `‖a‖` (> ~1.8 g), min interval 0.3 s | n/a | 0.3–2 s |
| Running | Chest / thigh | step peaks → cadence (SPM), steps | n/a | n/a |
| Open training | any | intensity only, no reps | n/a | n/a |

3. **Adaptive thresholds:** track running min/max (slow decay) to estimate ROM; require prominence ≥ `max(minRom, 0.5 × estimatedRom)` for a valid rep. A short optional "calibration rep" at set start sets baseline and ROM.
4. **Phase machine** with hysteresis on angular velocity sign: `idle → eccentric → bottom (peakInflexion, dwell) → concentric → top → count`. Count when the signal returns within 20 % of the start level after having reached the required prominence. Actually use `peakInflexion` (or delete the enum value).
5. **Reject and report** partial reps (ROM too small) and bounces (duration too short) — they are inputs to form metrics (P2-3), not silent drops.
6. **Per-rep record:** `RepRecord{start, end, eccentricS, concentricS, romDeg, peakAngVelDps, tremorRms}`. Emit a `Stream<RepEvent>`; keep `RepAnalysisResult` compatible for existing UI.
7. Reset per set. Support **sets and rest** (P3-5).

**Acceptance:** ≥ 95 % count accuracy on synthetic data (noise, tempo changes, fidgets) and ≥ 90 % on recorded real sessions (P4-2) with per-exercise confusion tables in `docs/validation.md`.

### P2-3 — Honest form/consistency score and badges
- Current formula `score*0.9 + 10` converges to 100 for any rhythmic reps, and starts at 96 before the first rep. Replace with a documented, weighted score computed **only after ≥ 3 reps**:
  - **Tempo consistency (40 %)** — 1 − coefficient of variation of rep durations (clamped).
  - **ROM consistency (30 %)** — median absolute deviation of ROM relative to median ROM.
  - **Stability (30 %)** — off-axis angular deviation during the rep (roll/yaw drift) relative to baseline from the first reps.
- Before 3 reps show "Need 3 reps" (no grade, no "A+").
- Grades: A+ ≥ 95, A ≥ 88, B ≥ 78, else C — but only for sessions with ≥ 3 reps.
- **Badges are rule-based and earned:** "Tempo Master" (≥ 10 reps and ≥ 80 % of reps within ±20 % of median duration), "Cardio Overload" (≥ N s in anaerobic/peak, N in config), "Steady Form" (form ≥ 90 and tremor < 40 for the set). If none earned: "No badges this time." Remove "ZERO CHEATING DETECTED".
- Note in UI/docs that with **one sensor** symmetry and joint alignment cannot be measured; the score measures movement *consistency*.

### P2-4 — Fatigue Tremor Index (FTI) redesign
- Physiological tremor near 8–12 Hz increasing with fatigue is real, but needs ≥ 100 Hz sampling (P1-7). Pipeline (Python → Dart, or firmware later):
  1. Gyro magnitude (or per-axis) from the IMU batch at ≥ 100 Hz.
  2. High-pass ~4 Hz to remove the rep movement (its fundamental < 2 Hz, harmonics < ~5 Hz).
  3. Band-pass 8–12 Hz (Butterworth SOS).
  4. RMS over 1 s windows, hop 0.5 s. (Alternative: FFT/Goertzel band power.)
  5. **Baseline:** band-RMS averaged over the first 3 valid reps of the set → `r = rms / baselineRms`.
  6. `FTI = clamp(100 × (r − 1) / (3 − 1), 0, 100)` (tunable constants in config).
- Combine with **velocity loss** (a validated fatigue marker in velocity-based training): `VL% = (1 − repVelocity / bestOfFirst3Velocity) × 100`. `fatigueScore = 0.6·FTI + 0.4·min(100, 2.5·VL)`; constants are tunable and must be tuned against the RPE/RIR labels collected by the data logger (P4-2).
- Alerts: hysteresis + edge-trigger (P0-9), never per-sample.
- **Fix the test:** the current test passes only because of the start-up transient (constant jerk after the first sample gives near-zero variance). Replace with: (a) synthetic 1 Hz movement + 10 Hz tremor of increasing amplitude sampled at 100 Hz → FTI rises monotonically; (b) same movement without tremor → FTI stays low; (c) a 20 Hz-sampled stream is rejected with a clear error ("sample rate too low for tremor band").
- Disclose in the UI that FTI is an indicator, not a measurement of muscle failure.

### P2-5 — Orientation estimation and placement calibration
- Implement an `AttitudeEstimator` (complementary filter first; Mahony/Madgwick later):
```dart
// degrees; dt from device timestamps (seconds)
roll  = atan2(ay, az);
pitch = atan2(-ax, sqrt(ay*ay + az*az));
roll  = alpha*(roll  + gx*dt) + (1-alpha)*rollAcc;   // alpha ≈ 0.98
pitch = alpha*(pitch + gy*dt) + (1-alpha)*pitchAcc;
// if | ‖a‖ − 1 g | > 0.3 g → alpha = 1.0 for this step (don't trust accel during impacts)
```
  Document the axis convention and verify gyro sign conventions on a jig with known 90° rotations. Yaw drifts without a magnetometer — do not present yaw as heading; show "yaw rate" only.
- Replace the hand-written per-placement axis swaps in `PlacementTransformer` with a **rotation-matrix calibration**: (1) "Stand still in neutral pose for 2 s" → mean accel vector = gravity direction in sensor frame → defines body-vertical; (2) optional "do one slow rep" → principal motion axis via PCA of gyro/accel. Store the 3×3 matrix per placement (persisted). All engines consume body-frame data.
- Motion Lab: calibration button stores offsets per placement; artificial horizon gets sky/ground fill, circle clipping, pitch ladder (polish).

### P2-6 — Heart-rate zones and user profile
- Add a `UserProfile` (age, sex, weight, height, resting HR, optional measured max HR). Persist locally. Remove hard-coded `userAge = 25` (the owner is 18).
- HRmax: prefer measured; else Tanaka `208 − 0.7 × age` (better than `220 − age`). If resting HR is known offer **Karvonen** zones: `target = rest + intensity × (max − rest)`.
- Smooth BPM (median of the last 5) and apply zone hysteresis to prevent flicker.
- Keep zone weights aligned with P2-11.

### P2-7 — Calories
- Replace the fixed 0.48/0.38 kcal per rep with:
  - HR-based when HR is valid and ≥ ~90 bpm (Keytel et al., 2005), kcal per minute:
    - Male: `(−55.0969 + 0.6309·HR + 0.1988·weightKg + 0.2017·age) / 4.184`
    - Female: `(−20.4022 + 0.4472·HR − 0.1263·weightKg + 0.074·age) / 4.184`
    - Clamp at ≥ 0; integrate per second.
  - MET-based fallback: `kcal = MET × weightKg × hours` (e.g. light resistance ≈ 3.5, vigorous ≈ 6; walking ≈ 3.5; running by speed), from an exercise table.
- Label as "estimated". Exclude resting periods.

### P2-8 — Steps and daily activity
- Use the firmware step counter (P1-7). Handle counter reset on device reboot (detect decreasing value / uptime reset) and accumulate a daily total in local storage; dashboard shows the stored total.

### P2-9 — Real readiness / HRV pipeline
- **Recording:** collect `BeatEvent`s for 60 s (allow up to 5 min optional). Pause the countdown when quality < threshold or leads-off, and tell the user ("Electrodes lost — re-attach").
- **Cleaning:** discard RR outside 300–2000 ms; discard an RR that differs > 20 % from the local median; require ≥ 80 % valid beats.
- **Metrics:**
```dart
double rmssd(List<int> rr) {           // ms
  double sum = 0;
  for (int i = 1; i < rr.length; i++) {
    final d = (rr[i] - rr[i - 1]).toDouble();
    sum += d * d;
  }
  return math.sqrt(sum / (rr.length - 1));
}
```
  Also `meanHr = 60000 / mean(rr)`, `lnRmssd = ln(rmssd)`, optional SDNN. Add unit tests with hand-computed vectors (e.g. RR `[800, 810, 790, 820]` → RMSSD = √((10² + 20² + 30²)/3) ≈ 20.5 ms).
- **Score (baseline-relative heuristic, document it as such):**
  - Baseline = mean/SD of `lnRmssd` and resting HR over the last 14 days (minimum 5 days; before that show raw HRV and "Building baseline (day n/5)" instead of a score).
  - `zHrv = (lnRmssd − mean) / max(sd, 0.05)`, `zRhr = (rhr − mean) / max(sd, 2.0)`.
  - `score = clamp(65 + 15·zHrv − 10·zRhr, 0, 100)`.
- Persist daily results; `morningRecoveryScore` feeds `AthleticStrain.target` and the dashboard ring.
- Wording: "HRV is above/below your baseline" — no claims about the CNS.
- Electrode placement guidance on screen (finger vs. chest must match `HARDWARE_FITNESS.md`).

### P2-10 — Real 60-second heart-rate recovery
- After **Finish**, go to a "Recovery" screen: instruct the user to stand or sit still, keep sampling HR, record peak (from smoothed HR, not a single sample) and HR at t = 60 s; `HRR = peak − hr60`. Show a 60 s countdown; allow skip (then HRR is "not measured").
- Wording: HRR depends on cool-down protocol; label thresholds as guidance ("≥ 25 bpm: excellent", 12–24: good, < 12: low), not "Elite".

### P2-11 — Strain model
- Replace ad-hoc weights with **Edwards TRIMP** for cardio: `TRIMP = Σ minutes_in_zone × w`, with `w = 1..5` for zones warm-up, fat-burn, aerobic, anaerobic, peak (matches the existing zone definitions).
- Add a resistance term: `TRIMP_res = totalReps × k` (k ≈ 0.3, configurable, per-exercise multiplier).
- Map to 0–21: `strain = 21 × (1 − exp(−TRIMP / K))` with `K ≈ 120` (100 TRIMP ≈ strain 12; a hard 60-min session ≈ 17). Put `K` in config.
- **Daily** strain = mapping of the **sum of the day's TRIMP**, not the sum of session strains. Persist per day. Target strain from readiness (existing 16.5/12/8 tiers are fine).
- Call it an in-house index; document the formula in `docs/strain.md`.

---

## 5. P3 — App architecture, UX and persistence

### P3-1 — Architecture: Riverpod + `SensorSource`
- Use Riverpod (already a dependency) properly. Suggested layers: `data/` (BLE, storage), `domain/` (models, engines), `application/` (controllers/notifiers), `presentation/` (widgets).
- Define:
```dart
enum SensorOrigin { hardware, simulated, phone }

abstract class SensorSource {
  SensorOrigin get origin;
  Stream<ImuSample> get imu;
  Stream<VitalsSample> get vitals;
  Stream<BeatEvent> get beats;
  Stream<SourceStatus> get status;
  Future<void> start();
  Future<void> stop();
}
```
  Implementations: `BleSensorSource`, `SimulatedSensorSource` (current demo generator), `PhoneSensorSource` (P3-2). Exactly one source is active (`activeSourceProvider`).
- Create `WorkoutController` (Notifier) that owns `RepCounterEngine`, `FatigueEngine`, `AudioCoach`, timers, zone counters, and exposes immutable `WorkoutState`. `LiveWorkoutScreen` becomes a thin view. This makes the workout logic unit-testable.
- **Performance:** the current screen `setState`s on every sample (10–20 Hz) and rebuilds the whole scroll view. Throttle UI updates to ~30 fps, use `ValueListenableBuilder`/`ref.watch(select)`, put painters on `RepaintBoundary`, pass a `repaint:` listenable to `CustomPainter`, and use a ring buffer for waveforms (`MotionWaveformPainter.shouldRepaint` currently always returns `true`).
- Persistent **source badge** on every data screen: `LIVE HARDWARE` / `SIMULATED` / `PHONE SENSORS`. Simulated data gets a visible watermark/border.

### P3-2 — Phone-sensor fallback
- Use `sensors_plus` (`userAccelerometerEventStream`, `gyroscopeEventStream`, `SensorInterval.gameInterval`) to implement `PhoneSensorSource` (m/s² → g). Lets users without hardware, and judges, try rep counting with the phone in an armband/pocket, and makes development possible without the device. Vitals from phone: none (show `--`).

### P3-3 — Permissions, onboarding, disclaimer
- First-run flow: welcome → **not a medical device** disclaimer → user profile (P2-6) → permissions with rationale (`permission_handler`) → connect device or skip.
- Handle Bluetooth off, permission permanently denied (deep-link to settings), device not found, connection lost.

### P3-4 — Local persistence and history
- Add local storage (`sqflite` or `drift`; keep it simple). Tables: `profile`, `workout_session`, `set`, `rep`, `daily_summary` (steps, TRIMP, strain, readiness), `readiness_scan`.
- Extend `WorkoutSession` with `zoneSeconds`, computed `avgHeartRate`, `maxHeartRate`, per-set data, peak FTI, HRR, source origin. `avgHeartRate` is currently never computed.
- Screens: **History** (list + detail), 7/30-day trend charts (strain, HRV baseline, resting HR). Dashboard reads from storage; empty states say "No workouts yet".
- Use `intl` for dates; remove if unused.

### P3-5 — Workout flow
- Pre-workout checklist: placement selector (persisted), neutral-pose calibration, sensor status.
- Set/rest structure: target reps, rest timer (audio cue at 10 s and 0 s), per-set summary; after each set ask RPE/RIR (1 tap) — this labels data for tuning P2-4.
- `PopScope` confirm dialog if the user leaves mid-workout; always save the partial session.
- Keep screen awake during workouts (`wakelock_plus`); if the sensor disconnects mid-workout: pause, announce, try to reconnect.
- Show zone-time bars on the summary (the `zoneTimes` parameter is currently unused).

### P3-6 — Real "Share victory card"
- Wrap the card in a `RepaintBoundary`, render `toImage(pixelRatio: 3)`, save to a temp file (`path_provider`), share via `share_plus`. Only show the success message after the share sheet returns.

### P3-7 — Audio coach improvements
- Cue set (all rate-limited): rep counts (every 5th and last-of-target), tempo too fast/slow, insufficient ROM vs baseline, zone changes, fatigue alert, rest countdown. Silence during rest unless critical.
- Language setting: check `isLanguageAvailable` for `bn-IN`, `hi-IN`, `en-IN`; fall back gracefully; localise cue strings (ARB via `intl`). Tell the user when the language voice pack isn't installed.

### P3-8 — Avatar and visuals
- Rename to a 2D skeleton avatar unless a real 3D rotation is implemented. Drive it from segment angles (P2-5). Smooth angles between frames (low-pass) to avoid jitter. Show a target ROM ghost outline.

### P3-9 — Accessibility, i18n, disclaimers
- Localisation scaffold (English + Bengali + Hindi ARB files), scalable text, contrast check on the neon-on-dark theme, semantic labels on icon buttons, colour is never the only indicator (add icons/text for zones and alerts).
- Persistent short disclaimer in Settings/About: wellness device, not for diagnosis; ECG only from battery-powered device.

---

## 6. P4 — Validation and QA (this is what wins a Hardware-category evaluation)

### P4-1 — Automated tests
- **Protocol:** byte-exact tests for v1 and v2 frames (build arrays mirroring the C++ structs; assert offsets; sentinel → `null`; bad length/type rejected).
- **Engines:** rep counter (synthetic + recorded CSV fixtures under `test/fixtures/`), FTI (P2-4), RMSSD vectors, TRIMP monotonicity, HR zones boundaries (including `getZoneForBpm` at exact edges), Keytel calories, attitude estimator (integrate known rotations), placement calibration.
- **Widget tests** with a mocked `SensorSource`: empty state, live state, disconnect mid-workout, summary navigation (P0-5).
- **Audio limiter** with a fake clock (P0-9).
- CI (GitHub Actions): `flutter pub get`, `flutter analyze`, `flutter test`; `pio run`; `pio test -e native`.

### P4-2 — Data logger and offline analysis
- In-app **Record** mode: log raw IMU/vitals/beats with device + phone timestamps, exercise, placement, per-rep taps (ground truth) and end-of-set RPE/RIR, into CSV; share via `share_plus`.
- `tools/analysis/` (Python: numpy, scipy, pandas, matplotlib): load CSVs, replay engines, plot signals and detected events, print accuracy tables. Keep all parameters in shared config so Python and Dart match.
- Collect a small dataset: ≥ 5 people, 3 exercises × 3 sets × (10, 15, 20) reps, two placements.

### P4-3 — Firmware tests
- PlatformIO `native` environment (Unity) for `dsp/*.h`: biquad frequency response vs SciPy reference, QRS detector on recorded ECG (and optionally public MIT-BIH records), step detector on recorded walks. Feed recorded Serial-captured CSV through the same code that runs on the ESP32.

### P4-4 — Bench and field validation protocol (report the numbers)

| Metric | Method | Target |
|---|---|---|
| IMU static accuracy | Device still on table: `‖a‖` ≈ 1 g; gyro bias after calibration | `‖a‖` within ±3 %; gyro drift < 1 °/s |
| Angle accuracy | Jig at 0/30/60/90° | ≤ 3° static, ≤ 5° dynamic |
| Rep-count accuracy | Ground-truth by video/manual count | ≥ 95 % (|error| ≤ 1 rep in ≥ 90 % of sets) |
| ECG HR accuracy | Simultaneous with reference chest strap/pulse oximeter | MAE ≤ 3 bpm rest, ≤ 5 bpm exercise |
| RR / RMSSD | Reference chest strap that exposes RR (e.g. Polar H10 via standard BLE HR service) | RR error ≤ 10 ms; RMSSD within ±15 % |
| BLE reliability | 30 min sessions | packet loss < 1 %, latency < 100 ms |
| App smoothness | Profile mode on a mid-range phone | ≥ 30 fps during workout |
| Battery life | LiPo capacity, real streaming | Report measured hours |

Report the results (with limitations and sample size) in `docs/validation.md`. Honest numbers beat impressive claims.

---

## 7. P5 — Documentation and pitch honesty

### P5-1 — README/INDEX
- Add a **status table**: `Implemented / Prototype / Simulated / Planned` per feature. Remove overclaims (see P0-13). Fix `INDEX.md`: it describes `workout_session.dart` as having "consistency grade calculation, and 60-second HRR analytics", which the file does not contain; the paths point to `c:\nvdia\fitness\...` — make them repo-relative.
- Add architecture diagram (sensor → firmware DSP → BLE → app engines → UI), protocol v2 spec (copy of P1-8), and a "Limitations" section (single sensor, no magnetometer, PPG at forearm is motion-sensitive, SpO₂ is an estimate, not a medical device).

### P5-2 — `HARDWARE_FITNESS.md`
- Fix inconsistencies: the readiness screen says "finger on AD8232 contacts" while the hardware doc recommends chest-strap ECG — specify electrode placement (RA/LA/RL) for each mode and what the app should tell the user.
- Battery-only safety note for ECG. Decoupling caps, I²C pull-up total resistance (three breakout boards each carry pull-ups — verify signal on a scope/logic analyser at 400 kHz), wire lengths, strapping-pin notes (GPIO 0/2/5/12/15), input-only pins (34–39).
- Add a real **BOM with actual INR prices** (from your bills) to support the "low-cost" pitch, and a wiring photo/diagram.

### P5-3 — Demo script (90 seconds) and fallback
- Script: connect real hardware → live ECG waveform + HR with source badge → 10 squats with real count and coach cues → set summary with honest form metrics → recovery HRR → history. Have `SIMULATED` fallback clearly labelled in case hardware fails.

---

## 8. P6 — Optional stretch (earns the "AI" in the name)

- **Exercise recognition:** windowed (2 s, 50 % overlap) IMU features (mean/std/energy per axis, dominant frequency, axis correlations, autocorrelation peak) → gradient boosting/random forest or a small 1D-CNN trained in Python on your logger data → export to Dart (`tflite_flutter` or a hand-ported decision tree). Auto-select the exercise profile and reject non-exercise motion. Report accuracy (confusion matrix) on held-out **subjects**, not just held-out windows.
- **Personalised fatigue model:** regress RPE/RIR from FTI, velocity loss, HR drift.
- **Custom PCB (learning goal):** KiCad board with ESP32 module/headers, LiPo charger (e.g. MCP73831/TP4056), 3.3 V regulator, AD8232 + MAX30102 connectors, battery divider, test points, proper I²C routing. Order a small run only after the breadboard version passes P4-4.
- **Bengali/Hindi voice coaching** as an inclusion feature.

---

## 9. Suggested execution order and definition of done

1. **P0-1 → P0-13** (bugs + honesty) — app compiles, no fake actions, demo mode explicit.
2. **P1-1, P1-2, P1-7, P1-8** (real ECG, real IMU, protocol v2) — real HR and real motion in the app.
3. **P2-1, P2-5, P2-2, P2-3** — trustworthy rep counting and form metrics; **P4-2** data logger built alongside.
4. **P2-9, P2-10, P2-11, P2-6, P2-7** — readiness, recovery, strain, zones, calories.
5. **P1-3/1-4/1-5** (PPG/temp/battery), **P2-4** (tremor).
6. **P3-*** architecture/UX/persistence, **P4-4** validation numbers, **P5-*** docs, then P6 if time allows.

**Minimum demo-ready cut (if time is short):** P0 (all), P1-1/1-2/1-7/1-8, P2-1/2-2/2-3/2-5, P3-1 source badge, P4-4 (ECG HR + rep-count accuracy), P5-1 status table.

**Definition of done for the whole effort:**
- No number on screen is a hard-coded constant presented as a measurement.
- Every claim in the README is backed by code that runs and by a validation number (or is marked Planned).
- `flutter analyze`, `flutter test`, `pio run`, `pio test -e native` all pass in CI.
- A first-time user can pair, calibrate, do a set, see honest metrics, recover, and find the session in History.

---

## 10. Decisions needed from the owner (ask before assuming)

1. Target platforms: Android only, or iOS as well?
2. Primary wearing position for the demo (thigh, forearm or chest)? This decides which exercise profiles get finished first.
3. ECG electrode arrangement for the demo (chest 3-electrode, or finger/hand contact)?
4. Is a LiPo battery + charger module available, or is the device powered from a power bank (still battery-only for ECG)?
5. Preferred storage library (`sqflite` vs `drift`) and whether cloud sync is out of scope (recommended: local-only for privacy).
6. Languages to support first (English + Bengali + Hindi?).
7. Competition deadline and demo format, to trim the plan to the minimum demo-ready cut.
