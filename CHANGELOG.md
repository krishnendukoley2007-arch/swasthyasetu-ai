# Changelog

All notable changes to SwasthyaSetu AI are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.0] — 2026-08

### Fixed
- BLE connection stability and reconnect handling
- Live vitals no longer display misleading `0` — unavailable values now show `—`
- Navigation and advisory flow polish

### Added
- Firmware `SSAI_SENSE_01` v1.5: animated boot splash (rings, typewriter, beating heart),
  live screen with pulsating heart, ECG strip, BP estimate, and battery percentage
- `tools/ecg_dashboard.html` — Web-Bluetooth laptop dashboard for demos and hardware checks
- Diagnostics screen: real sample-rate measurement, honest link state
- `SECURITY.md`

### Tests
- 430/430 passing (`flutter test`)

## [1.3.0]

### Added
- Offline map with bundled MBTiles tile pack
- 30-day personal baselines and trends
- Environment (heat / air-quality) advisories
- Emergency SOS via SMS
- Fall detection
