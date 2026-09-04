# SwasthyaSetu AI

SwasthyaSetu AI is an offline-first Flutter application with companion ESP32 firmware for community health screening workflows.

This public repository is intentionally privacy-minimized for release hardening. It preserves buildable source code, tests, and essential project metadata while excluding detailed internal design documentation and hardware schematics.

## Repository scope

Included in this repository:

- Flutter/Dart application source (`lib/`, `assets/`, `android/`, `windows/`)
- Firmware source for the device (`firmware/`)
- Automated tests (`test/`)
- CI and security workflows (`.github/workflows/`)

## Build and test

### Flutter app

Prerequisites:

- Flutter SDK (stable)
- Android SDK (for Android builds)

Commands:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk
```

### Firmware

Prerequisite:

- PlatformIO

Commands:

```bash
cd firmware
pio run
```

## Security and privacy

- Do not commit secrets or credentials.
- Keep runtime keys/configuration outside source control.
- Report vulnerabilities through GitHub Security Advisories.

See `SECURITY.md` for reporting details.

## License

Licensed under the MIT License. See `LICENSE`.

## Medical use disclaimer

This project is intended as a screening-support aid and not as a medical diagnostic device.
