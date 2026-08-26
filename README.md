# 🏥 SwasthyaSetu AI

<div align="center">

### Offline-first health screening for community health workers

**Record → Screen → Triage → Explain → Act**

A field-ready Android application that helps community health workers capture vital signs, identify risk levels, understand results in plain language, and respond quickly — even when there is **no internet connection**.

<br>

[![Version](https://img.shields.io/badge/version-1.3.0%20%28build%204%29-2563eb?style=for-the-badge)](../../releases)
[![Android](https://img.shields.io/badge/Android-7.0%2B-34a853?style=for-the-badge\&logo=android\&logoColor=white)](#-installation)
[![Tests](https://img.shields.io/badge/tests-428%20passing-16a34a?style=for-the-badge)](#-testing)
[![Offline](https://img.shields.io/badge/offline-first-yes-22c55e?style=for-the-badge)](#-offline-first-by-design)
[![License](https://img.shields.io/badge/license-MIT-7c3aed?style=for-the-badge)](LICENSE)

<br>

**⚠️ SwasthyaSetu AI is a screening and triage-support tool — not a diagnostic system.**

</div>

---

## ✨ Why SwasthyaSetu?

In many community-health settings, connectivity cannot be assumed.

SwasthyaSetu is designed around that reality.

It lets a health worker:

* capture patient information and vital signs
* receive a deterministic triage result
* understand *why* a result was produced
* keep screening history locally
* detect possible falls
* trigger an emergency SMS workflow
* work with a connected BLE sensor board
* continue using core functionality without internet access

The goal is simple:

> **Useful health screening should not stop just because the network does.**

---

## 👀 See It in Action

<div align="center">

<!-- Replace these placeholders with real screenshots -->

|          Dashboard          |          Screening          |          Triage          |
| :-------------------------: | :-------------------------: | :----------------------: |
| `screenshots/dashboard.png` | `screenshots/screening.png` | `screenshots/triage.png` |

|      Patient History      |     Community Map     |          Emergency          |
| :-----------------------: | :-------------------: | :-------------------------: |
| `screenshots/history.png` | `screenshots/map.png` | `screenshots/emergency.png` |

</div>

> **Tip:** Real screenshots will make this README dramatically more effective than text alone.
> A 6-image gallery directly under the hero section is one of the best upgrades you can make.

---

# 🧭 Quick Navigation

**Getting Started**

* [Why SwasthyaSetu](#-why-swasthyasetu)
* [Features](#-what-it-does)
* [Installation](#-installation)
* [Demo Mode](#-demo-mode)
* [Build From Source](#-build-from-source)

**How It Works**

* [Offline-First Design](#-offline-first-by-design)
* [Triage Engine](#-triage-engine)
* [AI Explanations](#-ai-explanations)
* [Hardware](#-hardware)
* [Data & Privacy](#-data--privacy)

**For Developers**

* [Architecture](#-architecture)
* [Project Structure](#-project-structure)
* [Testing](#-testing)
* [Maps](#-offline-maps)
* [Contributing](#-contributing)

**Important**

* [Medical Disclaimer](#-medical-disclaimer)
* [License](#-license--attribution)

---

# 🚀 What It Does

| Capability                 | What it provides                                                          | Offline |
| -------------------------- | ------------------------------------------------------------------------- | :-----: |
| 🩺 **Health Screening**    | Heart rate, SpO₂, temperature and single-lead ECG from a BLE sensor board |    ✅    |
| 🎯 **Triage**              | Deterministic risk classification: **Routine / Soon / Urgent**            |    ✅    |
| 💬 **Explanations**        | Local offline guidance or Gemini-powered online explanation               |  ✅ / 🌐 |
| 👥 **Patient Profiles**    | Multiple patients with local screening history                            |    ✅    |
| 🆘 **Emergency SOS**       | SMS containing triage information and location when consented             |    ✅    |
| 📉 **Fall Detection**      | Phone accelerometer and sensor-board IMU                                  |    ✅    |
| 🗺️ **Offline Map**        | Bundled OpenStreetMap tiles through MBTiles                               |    ✅    |
| ☁️ **Optional Sync**       | Consent-gated upload when connectivity is available                       |    🌐   |
| 🌡️ **Environment Alerts** | Heat and air-quality guidance from Open-Meteo                             |  🌐 / ✅ |
| 📈 **30-Day Trends**       | Personal HR, SpO₂ and temperature baselines                               |    ✅    |

---

# 🧠 How the Screening Flow Works

```text
                    ┌─────────────────┐
                    │ Patient Profile │
                    └────────┬────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Capture Measurements │
                  │  HR • SpO₂ • Temp    │
                  │       • ECG          │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │ Deterministic Rules  │
                  │      Engine           │
                  └──────────┬───────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
         🟢 ROUTINE      🟡 SOON        🔴 URGENT
              │              │              │
              └──────────────┼──────────────┘
                             ▼
                  ┌──────────────────────┐
                  │ Plain-Language      │
                  │ Explanation         │
                  └──────────┬───────────┘
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
        Offline guidance           Online Gemini
                                  explanation
                │                         │
                └────────────┬────────────┘
                             ▼
                    Recommended Action
```

### Important design principle

The AI **does not decide the triage band**.

The risk band comes from a deterministic rule engine. AI is used only for the explanation layer.

That separation makes the system easier to understand, test and audit.

---

# 🛡️ Offline-First by Design

SwasthyaSetu is not an online app with an offline fallback.

**Offline operation is the default architecture.**

### What works without internet?

✅ Patient profiles
✅ Screening history
✅ Vitals capture
✅ Deterministic triage
✅ Offline explanations
✅ Fall detection
✅ Emergency SMS composition
✅ Offline map
✅ 30-day trends
✅ BLE sensor communication

### What requires connectivity?

🌐 Gemini-powered explanations
🌐 Optional cloud synchronization
🌐 Live environmental data

When online features are unavailable, the app does not silently pretend they worked.

---

# 🎯 Triage Engine

The triage system uses fixed thresholds and deterministic rules.

Every screening is classified into one of three risk bands:

### 🟢 Routine

No configured threshold indicates immediate escalation.

### 🟡 Soon

The measurements suggest that follow-up should happen relatively soon.

### 🔴 Urgent

The measurements meet configured escalation criteria and require urgent attention.

The application clearly communicates that these bands are **screening outputs**, not diagnoses.

---

# 💬 AI Explanations

SwasthyaSetu uses a two-tier explanation system.

### 1. 📴 Explained Offline

A bundled local explanation corpus provides guidance without requiring network connectivity.

### 2. 🌐 Explained Online

When enabled, Gemini can generate a more flexible plain-language explanation.

The UI explicitly labels which explanation source was used:

> **Explained offline**

or

> **Explained online**

This prevents an offline explanation from being mistaken for live AI output.

---

# 📱 Installation

## Recommended APK

| APK                         | Approx. Size | Architecture | Recommendation              |
| --------------------------- | -----------: | ------------ | --------------------------- |
| 🎯 `SwasthyaSetu-fixed.apk` |       ~74 MB | Universal    | ⭐ Recommended               |
| ⚡ `app-release-arm64.apk`   |       ~32 MB | ARM64        | Most modern Android phones  |
| 📦 `app-release.apk`        |       ~74 MB | Universal    | Alternative universal build |

### Install

1. Open the [Releases](../../releases) page on your Android phone.
2. Download `SwasthyaSetu-fixed.apk`.
3. Open the downloaded APK.
4. Android may ask you to allow installation from that source.
5. Enable the permission and install.
6. Launch SwasthyaSetu.

### ⚠️ Two things to know

**Debug / field build**

Android may display an "unverified developer" or similar warning because this is not a Play Store release.

**No sensor board**

Without the hardware board, the app runs in clearly labelled **Demo Mode**. Simulated measurements are marked:

> 🧪 **DEMO**

The app does **not** pretend that the phone measured HR or SpO₂ by itself.

---

# 🧪 Demo Mode

Demo mode makes it possible to explore the application without the hardware board.

You can inspect:

* patient management
* screening flows
* triage
* explanations
* history
* trends
* emergency workflow
* map interface
* fall-detection logic

Simulated measurements remain explicitly marked as demo data.

---

# 🔐 Permissions

SwasthyaSetu follows a **permission-minimal** approach.

| Permission                    | Purpose                      | If denied                                 |
| ----------------------------- | ---------------------------- | ----------------------------------------- |
| 🔵 Bluetooth / Nearby Devices | Connect to sensor board      | Demo mode                                 |
| 📍 Location                   | Attach screening coordinates | Screening still saves without coordinates |
| 🌐 Internet                   | Online AI + optional sync    | Offline system remains available          |
| 📷 Camera                     | Scan QR codes                | Enter information manually                |
| ⚙️ Foreground Service         | Keep BLE screening alive     | BLE session may drop when backgrounded    |

### Location is off by default

The application does not silently collect location.

When location access is disabled, the UI explicitly communicates that the location-aware map functionality is unavailable.

---

# 🗺️ Offline Maps

The app includes a bundled MBTiles map pack.

```text
assets/
└── map/
    └── india_lowzoom.mbtiles
```

Current bundled pack:

* ~690 KB
* Zoom levels 0–6
* OpenStreetMap data

Additional `.mbtiles` packs can be imported into the device's `map_tiles` directory.

Imported packs take priority over the bundled pack, and the UI identifies the active map source.

### Generate a map pack

```bash
python tool/build_map_pack.py
```

---

# 🔌 Hardware

SwasthyaSetu can connect to a dedicated BLE sensor board.

| Component                  | Purpose                 |
| -------------------------- | ----------------------- |
| 💓 **MAX30102**            | Heart rate + SpO₂       |
| 📊 **AD8232**              | Single-lead ECG         |
| 🌡️ **MLX90614 / DS18B20** | Temperature             |
| 🤸 **MPU6050**             | Motion / fall detection |
| 📡 **ESP32**               | BLE + Wi-Fi + MQTT      |

### Connection model

```text
Sensor Board
     │
     │ Bluetooth LE
     ▼
┌───────────────┐
│ SwasthyaSetu  │
│   Android App │
└───────┬───────┘
        │
        ├── Screening
        ├── Triage
        ├── History
        ├── Trends
        └── Emergency
```

The application tracks the BLE connection honestly:

`Scanning → Connecting → Connected → Lost`

The diagnostics screen can also expose sensor/sample-rate information.

📖 [Hardware documentation](hardware/HARDWARE.md)
📐 [Hardware schematic](hardware/hardware-schematic.svg)

---

# 🧱 Architecture

SwasthyaSetu separates UI, data, business logic and device services.

```text
┌──────────────────────────────────────────────┐
│                  Flutter UI                  │
│ Dashboard • Patients • Screening • History  │
│ Emergency • Community • Settings            │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                 Domain Layer                 │
│ Models • Triage Rules • Screening Logic     │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                  Data Layer                  │
│ Drift / SQLite • Repositories • Mappers    │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│                   Core                      │
│ BLE • SOS • Storage • Sync • Maps • Routing│
└──────────────────────────────────────────────┘
```

---

# 📂 Project Structure

```text
lib/
├── core/
│   ├── BLE
│   ├── SMS / SOS
│   ├── storage
│   ├── sync
│   ├── MBTiles
│   ├── routing
│   ├── providers
│   └── theme
│
├── data/
│   ├── database
│   ├── repositories
│   └── row mappers
│
├── domain/
│   ├── models
│   └── deterministic triage engine
│
├── features/
│   ├── dashboard
│   ├── patients
│   ├── screening
│   ├── history
│   ├── emergency
│   ├── community
│   └── settings
│
└── l10n/
    ├── app_en.arb
    ├── app_hi.arb
    └── app_bn.arb

test/
└── 428 tests

assets/
├── guidelines/
├── map/
└── fonts/

hardware/
├── HARDWARE.md
└── hardware-schematic.svg
```

---

# 🧩 Core Design Principles

### 1. One-way provenance

Measured data can become demo-labelled data.

Demo data can **never** silently become real measured data.

```text
Real measurement
      │
      ▼
  isDemo = false

Demo / simulated value
      │
      ▼
  isDemo = true
```

### 2. Missing means missing

No fabricated defaults.

If a measurement does not exist:

```text
—
```

not:

```text
0
```

and not a guessed value.

### 3. Stable internal vocabulary

Storage, database records, exports and rules remain in one stable internal vocabulary.

Localization applies to presentation labels rather than mutating stored meaning.

---

# 📈 30-Day Trends

The application can track personal baselines for:

* ❤️ Heart rate
* 🫁 SpO₂
* 🌡️ Temperature

The trend view highlights deviations from a patient's own baseline rather than relying only on population-level reference values.

---

# 🆘 Emergency SOS

When emergency escalation occurs, the app can prepare an SMS containing:

* triage result
* relevant screening information
* location, when the user has consented to location access

The message is passed to the device messaging workflow.

The app does **not** silently send an emergency message without the corresponding user-controlled workflow.

---

# 🧪 Testing

The repository currently includes:

> **428 passing tests**

Testing covers both core application behavior and important edge cases, including UI rendering under increased font sizes and offline-map behavior.

Run the complete suite with:

```bash
flutter test
```

---

# 🛠️ Build From Source

## Requirements

* Flutter 3.47+
* Dart 3.13+
* Android SDK
* Android Studio
* A connected Android device or emulator

## Setup

```bash
git clone https://github.com/<your-username>/swasthyasetu-ai.git

cd swasthyasetu-ai

flutter pub get
```

## Run tests

```bash
flutter test
```

## Build release APKs

```bash
flutter build apk --release --split-per-abi
```

Generated APKs:

```text
build/app/outputs/flutter-apk/
```

## Run directly

```bash
flutter run --release
```

---

# 🤖 Optional Gemini Integration

Online AI explanations are optional.

### Build-time key

```bash
flutter build apk --release \
  --dart-define=GEMINI_API_KEY=your_key_here
```

### Runtime configuration

Open:

```text
Settings → AI
```

and provide a Google AI Studio key.

### Important

No API key is committed to the repository.

The app can be built and used without one.

---

# 🌍 Localization

Current interface languages:

* 🇬🇧 English
* 🇮🇳 Hindi
* 🇮🇳 Bengali

Localization files:

```text
lib/l10n/
├── app_en.arb
├── app_hi.arb
└── app_bn.arb
```

---

# 🔒 Data & Privacy

SwasthyaSetu is designed so that core screening data can remain on the device.

The application supports:

* local SQLite storage
* consent-gated synchronization
* optional location capture
* explicit online/offline AI labelling
* transparent permission handling

Offline operation does not require sending screening information to a remote server.

---

# 📊 At a Glance

<div align="center">

| 🧪 Tests | 📱 Android | 📡 BLE | 📴 Offline | 🗺️ Offline Maps |
| :------: | :--------: | :----: | :--------: | :--------------: |
|  **428** |  **7.0+**  |    ✅   |      ✅     |         ✅        |

|   🩺 Triage  |   💬 AI Explanation  | 🆘 SOS |  📈 Trends  | 🌐 Localization |
| :----------: | :------------------: | :----: | :---------: | :-------------: |
| **3 levels** | **Offline + Online** |    ✅   | **30 days** | **3 languages** |

</div>

---

# ⚠️ Medical Disclaimer

> **SwasthyaSetu AI is a screening and triage-support tool intended for trained community health workers.**
>
> It does **not** diagnose disease, prescribe treatment, or replace clinical judgment.
>
> Its risk bands are generated using fixed threshold rules and should not be treated as a medical diagnosis.
>
> **Do not use this software as the sole basis for medical decisions or as a replacement for emergency medical services.**

---

# 📜 License & Attribution

| Asset              | License                                                                        |
| ------------------ | ------------------------------------------------------------------------------ |
| Application code   | [MIT License](LICENSE)                                                         |
| OpenStreetMap data | © OpenStreetMap contributors • [ODbL](https://www.openstreetmap.org/copyright) |
| Inter typeface     | [SIL OFL 1.1](https://github.com/rsms/inter)                                   |

---

# 🤝 Contributing

Contributions, bug reports and feature requests are welcome.

Before submitting a change:

```bash
flutter pub get
flutter test
```

Then open an issue or pull request with a clear description of what changed and why.

---

# 🔗 Project Links

<div align="center">

[📦 Releases](../../releases)
[🐛 Report a Bug](../../issues)
[💡 Request a Feature](../../issues/new)
[📖 Documentation](../../wiki)
[🔒 Security](../../security/policy)

</div>

---

<div align="center">

### 🏥 SwasthyaSetu AI

**Technology for health workers, designed for places where connectivity cannot be assumed.**

Built with ❤️ for community health workers.

</div>
