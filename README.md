#                                             🏥 SwasthyaSetu AI

<div align="center">

![Version](https://img.shields.io/badge/version-1.3.0%20%28build%204%29-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Android%207.0%2B-green?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-purple?style=for-the-badge)
![Offline](https://img.shields.io/badge/works%20offline-yes-brightgreen?style=for-the-badge)
![Tests](https://img.shields.io/badge/tests-428%20passing-success?style=for-the-badge)

**🌍 An offline-first AI-powered health screening platform for community health workers**

*Record vitals → Get triage → Understand in plain language → Act fast — all without internet and available additional online explanations*

</div>

---

## 📱 Install on Your Phone (No Computer Needed!)

<div align="center">

| APK | Size | Architecture | Best For |
|-----|------|--------------|----------|
| 🎯 **`SwasthyaSetu-fixed.apk`** | ~74 MB | Universal (all) | **Recommended — works everywhere** |
| ⚡ `app-release-arm64.apk` | ~32 MB | 64-bit ARM | Most phones since 2018 |
| 📦 `app-release.apk` | ~74 MB | Universal (all) | Alternative universal build |

</div>

### 🚀 Quick Install Steps

1. **Open** the [Releases page](../../releases) on your Android phone
2. **Download** `SwasthyaSetu-fixed.apk` (or your preferred variant)
3. **Tap** the file → Android shows security warning → **Settings → Allow from this source** → **Install**
4. **Open** the app → **Grant permissions** when prompted (all optional!)

> ⚠️ **Two honest warnings:**
> - **Debug-signed APK** — Android warns "unverified developer" (normal for field builds, not Play Store)
> - **No sensor board = Demo mode** — Phone alone **cannot** measure heart rate/SpO₂; simulated readings show `🧪 DEMO` badge

---

## ✨ What It Actually Does

| Feature | Description | Offline? |
|---------|-------------|:--------:|
| 🩺 **Screening** | Heart rate, SpO₂, temperature, single-lead ECG via Bluetooth LE sensor board | ✅ |
| 🎯 **Triage** | Deterministic rule engine → **🟢 Routine / 🟡 Soon / 🔴 Urgent** + escalation level | ✅ |
| 💬 **Explanation** | **Two tiers:** "Explained offline" (local corpus) or "Explained online" (Gemini AI) — always labeled | ✅/🌐 |
| 👥 **Patients** | Multiple profiles with full screening history in local SQLite | ✅ |
| 🆘 **Emergency SOS** | Composes SMS with triage result + location (if consented) → opens messaging app | ✅ |
| 📉 **Fall Detection** | Phone accelerometer + sensor board IMU (when connected) | ✅ |
| 🗺️ **Offline Map** | Real OpenStreetMap tiles (bundled MBTiles) — country-level, no data needed | ✅ |
| ☁️ **Sync** | Optional, consent-gated upload when online | 🌐 |
| 🌡️ **Environment Alerts** | Heat & air-quality advisories from Open-Meteo (no API key), personalized to patient | 🌐/✅ |
| 📈 **30-Day Trends** | Personal baselines for HR/SpO₂/Temp with deviation highlighting | ✅ |

---

## 🛡️ Permissions — All Optional, All Transparent

| Permission | Why? | If Denied |
|------------|------|-----------|
| 🔵 **Bluetooth / Nearby Devices** | Connect to sensor board | Vitals stay in demo mode |
| 📍 **Location** | Tag screenings for community map | Map disabled; screenings save without coords |
| 🌐 **Internet** | Online AI explanations + optional sync | Everything else works; offline explanations used |
| 📷 **Camera** | Scan patient/device QR codes | Enter details manually |
| ⚙️ **Foreground Service** | Keep BLE alive during screening | Session may drop if you switch apps |

> 🔒 **Location consent is OFF by default** — the map explicitly says when it's off instead of showing empty terrain.

---

## 🏗️ Build It Yourself

```bash
# Prerequisites: Flutter 3.47+ / Dart 3.13+ (Android SDK via Android Studio)
git clone https://github.com/<your-username>/swasthyasetu-ai.git
cd swasthyasetu-ai

flutter pub get                    # 📦 Install dependencies
flutter test                       # ✅ 428 tests — all should pass!
flutter build apk --release --split-per-abi  # 📱 APKs in build/app/outputs/flutter-apk/

# Or run directly on connected device:
flutter run --release
```

### 🔑 Optional: Enable Online AI Explanations
```bash
# Compile-time (builds key into APK):
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key_here

# Or at runtime: Settings → AI → paste Google AI Studio key
```
*No key committed. No key required to build/run.*

### 🗺️ Optional: Better Offline Map
- Bundled: `assets/map/india_lowzoom.mbtiles` (~690 KB, zoom 0–6)
- Add detail: Drop any `.mbtiles` file into device's `map_tiles` folder
- Imported packs take priority; map caption shows active source
- Generator script: `tool/build_map_pack.py`

---

## 📂 Project Structure

```
lib/
├── core/           🔧 Services (BLE, SMS/SOS, storage, sync, MBTiles), theme, routing, providers
├── data/           💾 Drift/SQLite database, repositories, row mappers
├── domain/         🧠 Models + deterministic triage rule engine
├── features/       🎯 Per-screen modules: dashboard, patients, screening, history, emergency, community, settings
├── l10n/           🌐 app_en.arb / app_hi.arb / app_bn.arb (all UI text)
test/               🧪 428 tests (overflow @ 2.0x font, offline-map honesty, etc.)
assets/
├── guidelines/     📚 Offline explanation corpus
├── map/            🗺️ Bundled OSM tile pack
└── fonts/          🔤 Inter (bundled — vitals never render in OEM fonts)
```

### 🏛️ Architecture Principles

| Principle | What It Means |
|-----------|---------------|
| 🔄 **One-way provenance** | Measured → demo-flagged, never reverse. `isDemo` prevents simulated data masquerading as real |
| 🇬🇧 **Storage stays English** | Only labels translate; DB, exports, rules share one vocabulary |
| ❌ **No fabricated gaps** | Missing values render as `—`, never `0` or guesses |

---

## 🔧 Hardware (For Real Vitals)

<div align="center">

| Component | Purpose | Reference |
|-----------|---------|-----------|
| 💓 **MAX30102** | Pulse oximetry (HR + SpO₂) | PPG sensor |
| 📊 **AD8232** | Single-lead ECG | Raw waveform |
| 🌡️ **MLX90614 / DS18B20** | Body temperature | Contactless / contact |
| 📡 **ESP32** | BLE + WiFi + MQTT | Main MCU |

</div>

**App connects by service UUID** → honest link state (scanning/connecting/connected/lost) → diagnostics screen measures real sample rates.

📖 **Full hardware docs:** [`hardware/HARDWARE.md`](hardware/HARDWARE.md)  
📐 **Wiring diagram:** [`hardware/hardware-schematic.svg`](hardware/hardware-schematic.svg)

*Without the board → app runs in clearly labeled demo mode.*

---

## 📜 License & Attribution

| Asset | License |
|-------|---------|
| Application code | [MIT](LICENSE) |
| Bundled map tiles | © OpenStreetMap contributors • [ODbL](https://www.openstreetmap.org/copyright) |
| Inter typeface | [SIL OFL 1.1](https://github.com/rsms/inter) |

---

## ⚠️ Medical Disclaimer

> **This software is a screening and triage-support tool for trained community health workers.**  
> It does **not** diagnose, treat, or prescribe. Its risk bands come from **fixed threshold rules**, not clinical judgment.  
> **Do not use as sole basis for care decisions. Do not use in place of emergency services.**

---

<div align="center">

**Built with ❤️ for community health workers everywhere**

[🐛 Report Bug](../../issues) • [💡 Request Feature](../../issues/new) • [📖 Wiki](../../wiki) • [🔒 Security](../../security/policy)

</div>
