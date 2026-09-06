# Changelog

All notable changes to SwasthyaSetu AI are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.1] — 2026-08-31

### Fixed
- **Hazardous air was never announced** — the AQI 300+ ("Hazardous"/"Severe" on
  the CPCB and US-EPA scales) advisory was unreachable: every lower band matched
  first, so a Delhi-winter reading of 350 showed the same "Unhealthy air — avoid
  outdoor exercise" copy as 151. The severe band is now checked first, carries
  its own `danger` level, and no longer collides with the warning advisory's id.
- **Shared device and emergency screens no longer wear the patient tab bar** —
  `/devices/scan`, `/devices/connect`, `/devices/diagnostics` and
  `/emergency/contacts` are reached from clinician and demo surfaces too, but sat
  inside the patient shell. A clinician tapping "Connect device" on Home got the
  patient bottom bar, and tapping one of its tabs bounced them back to Home. They
  are top-level routes again; the patient keeps dedicated `/my-device` and
  `/my-help` tabs, which clinician and demo sessions are guarded away from.
- Re-tapping the current bottom-bar tab now pops that branch back to its root
  instead of doing nothing.

### Changed
- Version bumped to `1.4.1+6`

## [1.4.0] — 2026-08-31

### Added
- **Product design assets** — `hardware/design/`: 3D enclosure render, top-view
  enclosure layout with labelled sensor arms, and the full EasyEDA circuit schematic
- **Interactive README** — collapsible sections, Mermaid architecture and triage
  diagrams, image galleries, anchor table of contents, download table for every
  built APK variant
- **Modular firmware** — `SSAI_SENSE_01` split into `BLEHandler`, `DisplayHandler`,
  `EcgSensor`, `TouchHandler`, `State` and `Config.h`, plus a `platformio.ini`
- `tools/ecg_dashboard.html` — Web-Bluetooth laptop dashboard for demos and hardware checks
- Diagnostics screen: measures the *actual* achieved BLE sample rate, not the advertised one
- Environmental advisories screen and disaster advisory corpus
- Screening step indicator widget
- `SECURITY.md`

### Fixed
- BLE connection stability and reconnect handling
- Live vitals no longer display a misleading `0` — unavailable values now render as `—`
- README pin map corrected to match `firmware/SSAI_SENSE_01/Config.h`
  (GPIO 36/39/34/18 for the AD8232, 4 for touch, 21/22 for I²C, 35 for battery sense)
- Navigation and advisory flow polish

### Changed
- Version bumped to `1.4.0+5`

### Tests
- **428/428 passing** (`flutter test`)

## [1.3.0]

### Added
- Offline map with bundled MBTiles tile pack
- 30-day personal baselines and trends
- Environment (heat / air-quality) advisories
- Emergency SOS via SMS
- Fall detection
