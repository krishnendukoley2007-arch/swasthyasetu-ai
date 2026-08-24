# SwasthyaSetu AI

An offline-first health screening app for community health workers. It records a
patient's vitals and symptoms, sorts them into a triage band (routine / soon /
urgent), explains that decision in plain language, and can raise an SMS SOS —
all with no internet connection and no server.

**It is a screening aid, not a diagnosis.** Nothing in the app decides whether
someone is ill. It sorts people into "see a clinician sooner" or "later" using
published threshold rules, and shows the numbers it used so a worker can
disagree with it.

- **Version:** 1.1.0 (build 2)
- **Platform:** Android 7.0 (API 24) and newer
- **Languages:** English, हिन्दी (Hindi), বাংলা (Bengali)
- **Works offline:** yes — every screening, rule, explanation tier and map tile
  is on the device

---

## Install it on your phone

**You do not need a computer, an account, or a developer setup.**

1. Open the [Releases page](../../releases) on your Android phone.
2. Under the newest release, download **`app-arm64-v8a-release.apk`**.
   That's the right file for essentially every phone sold since ~2018. If it
   refuses to install, try `app-armeabi-v7a-release.apk` (older 32-bit phones),
   or `app-release.apk`, which contains every chip type and works everywhere but
   is ~68 MB instead of ~26 MB.
3. Tap the downloaded file. Android will say something like *"For your security,
   your phone is not allowed to install unknown apps from this source."* Tap
   **Settings → Allow from this source**, then go back and tap the file again.
4. Install, open, and grant permissions when asked. See
   [What it asks for, and why](#what-it-asks-for-and-why) below — you can say no
   to all of them and the app still works.

### Two honest warnings about installing this

- **The APK is signed with a debug key.** Android will warn you that the
  developer is unverified, and you will not be able to install it *over* a
  Play Store copy of the same app. That's a consequence of this being a
  field/demo build rather than a store release, not a sign the file is broken.
- **Without a compatible sensor board, all vitals are simulated.** The app is
  explicit about this — every simulated reading carries a `DEMO` badge and is
  stored flagged as demo — but if you install it expecting your phone alone to
  measure your heart rate, it cannot. Phones have no pulse oximeter.

---

## What it actually does

| | |
|---|---|
| **Screening** | Heart rate, SpO₂, temperature and a single-lead ECG trace read over Bluetooth LE from a sensor board; symptoms and duration entered by the worker. |
| **Triage** | A deterministic rule engine (no model, no network) maps vitals + symptoms to green / yellow / red, plus an escalation level. The thresholds it used are shown on screen. |
| **Explanation** | Two tiers, and the app always says which one you got: *"Explained offline"* from the guideline corpus on the phone, or *"Explained online"* from Google Gemini when a network and an API key are both present. Offline is never silently dressed up as online. |
| **Patients** | Multiple patient profiles with screening history, stored locally in SQLite. |
| **Emergency** | An SOS screen that composes an SMS to saved contacts with the triage result and, if you consented to location, a coordinate. It opens your messaging app — it cannot and does not send silently. |
| **Fall detection** | Uses the phone's accelerometer, and the sensor board's IMU when connected. |
| **Offline map** | Real OpenStreetMap raster tiles from a bundled MBTiles pack, so the "where have I screened" map works with no data. Zoom 0–6 only (country-level) — when a pack has no tiles for your area, the app says so instead of drawing invented terrain. |
| **Sync** | Optional and consent-gated. Screenings queue locally and upload only when you have a network and have turned sync on. |

### A note on what this codebase is trying not to do

Much of the recent work on this app has been removing UI that displayed numbers
the app had not measured — hardcoded dashboard counts, a pull-to-refresh that
incremented a counter, a "scan for devices" button that waited two seconds and
then selected a simulated device, a battery percentage that always read the demo
device's. If you find a screen showing you a value it could not have obtained,
that is a bug worth reporting, not a feature.

---

## What it asks for, and why

Every permission is optional. Denying any of them degrades a feature; none of
them breaks the app.

| Permission | Used for | If you deny it |
|---|---|---|
| Bluetooth / nearby devices | Connecting to the sensor board | Vitals stay in simulated demo mode |
| Location | Tagging screenings so the community map works | Map is off; screenings save without coordinates |
| Internet | Optional AI explanations and optional sync | Everything else works; explanations come from the phone |
| Camera | Scanning a patient/device QR code | Enter details by hand |
| Foreground service | Keeping a BLE session alive while screening | Screening may drop if you switch apps |

Location consent is **off by default**, and the community map says plainly when
it is off rather than showing an empty map.

---

## Build it yourself

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) —
this was built with **Flutter 3.47.1 / Dart 3.13.1** — and, for Android, the
Android SDK with a build-tools install (Android Studio provides both).

```bash
git clone https://github.com/<your-username>/swasthyasetu-ai.git
cd swasthyasetu-ai
flutter pub get
flutter test          # 345 tests, all of which should pass
flutter build apk --release --split-per-abi
```

The APKs land in `build/app/outputs/flutter-apk/`. To run on a plugged-in phone
instead: `flutter run --release`.

### Optional: enable the online explanation tier

The app works without this. To turn on Gemini-backed explanations and chat,
either paste a [Google AI Studio](https://aistudio.google.com/apikey) key into
**Settings → AI** at runtime, or compile one in:

```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key_here
```

No key is committed to this repository, and none is required to build or run.

### Optional: a better offline map

The bundled pack (`assets/map/india_lowzoom.mbtiles`, ~690 KB) is real OSM
tiles at zoom 0–6 — enough for country-level context, not for streets. To add
detail, copy any standard raster `.mbtiles` file into the app's `map_tiles`
directory on the device; imported packs take priority over the bundled one, and
the map caption tells you which pack it is drawing from. `tool/build_map_pack.py`
is the script that produced the bundled pack.

---

## Project layout

```
lib/
  core/          services (BLE, SMS/SOS, storage, sync, MBTiles reader),
                 theme, shared widgets, routing, Riverpod providers
  data/          drift/SQLite database, repositories, row mappers
  domain/        models and the deterministic triage rule engine
  features/      one folder per screen area: dashboard, patients,
                 screening, history, emergency, community, settings
  l10n/          app_en.arb / app_hi.arb / app_bn.arb (source of all UI text)
test/            345 tests, including layout-overflow tests at 2.0x font
                 scale and a suite pinning offline-map honesty
assets/
  guidelines/    the offline explanation corpus
  map/           bundled low-zoom OpenStreetMap tile pack
  fonts/         Inter, bundled so vitals never render in an OEM font
```

Architecture notes worth knowing before changing things:

- **Provenance is one-directional.** A reading can go from measured to
  demo-flagged, never the other way. `isDemo` on samples, screenings and drafts
  exists so a simulated number can never be presented as a measured one.
- **Storage strings stay English.** Only labels are translated, so the database,
  the exports and the rule engine share one vocabulary regardless of UI language.
- **Nothing is fabricated to fill a gap.** A value the app does not have renders
  as `—`, not as `0` and not as a plausible guess.

---

## Hardware

Real vitals need a BLE peripheral exposing heart rate, SpO₂, temperature and raw
ECG samples — the reference build is an ESP32 with MAX30102 (pulse/SpO₂),
AD8232 (ECG), MLX90614 or DS18B20 (temperature) and MPU6050 (fall detection).
The app connects by service UUID, reports honest link state (scanning /
connecting / connected / lost), and has a diagnostics screen that measures real
sample rates rather than asserting them.

Without that board the app runs in demo mode, clearly labelled throughout.

---

## Licence and attribution

- Application code: [MIT](LICENSE).
- Bundled map tiles: © OpenStreetMap contributors, available under the
  [Open Database Licence](https://www.openstreetmap.org/copyright).
- Inter typeface: [SIL Open Font Licence 1.1](https://github.com/rsms/inter).

## Medical disclaimer

This software is a screening and triage-support tool for trained community
health workers. It does not diagnose, treat, or prescribe. Its risk bands are
produced by fixed threshold rules and are not a clinical judgement. Do not use
it as the sole basis for a care decision, and do not use it in place of
emergency services.
