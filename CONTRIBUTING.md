# Contributing to SwasthyaSetu AI

Thank you for helping build an offline-first health screening tool for community health workers! This guide will get you set up.

## Quick Start

```bash
# 1. Fork & clone
git clone https://github.com/YOUR_USERNAME/swasthyasetu-ai.git
cd swasthyasetu-ai

# 2. Install Flutter (3.47.1) — see flutter.dev/docs/get-started/install
# 3. Get dependencies & generate code
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 4. Run tests (all must pass)
flutter test

# 5. Run the app
flutter run --release
```

## Development Workflow

### Branching
- `main` — protected, release-ready
- `develop` — integration branch for features
- Feature branches: `feature/short-description` from `develop`
- Bugfix branches: `fix/short-description` from `main` or `develop`

### Commits
Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
feat: add offline map tile import
fix: prevent demo data leaking into measured screenings
docs: update README with new APK names
test: add overflow tests for settings screen
refactor: extract triage rules into separate module
```

### Pull Requests
1. Target `develop` for features, `main` for hotfixes
2. Fill out the PR template completely
3. All CI checks must pass (analyze, test, backend lint)
4. Requires 1 approval before merge
5. Squash and merge preferred

## Code Standards

### Dart/Flutter
- **Formatter**: `dart format .` (run before commit)
- **Linter**: `flutter analyze` — zero warnings/errors
- **Tests**: Write tests for new logic; aim for >90% coverage on domain rules
- **Architecture**:
  - Domain rules are pure Dart — no Flutter deps
  - Repositories abstract storage; use Riverpod providers in UI
  - `isDemo` flag on all vitals/screenings — never demote to measured
  - Missing values render as `—` (em dash), never `0` or `null`

### Python (Backend)
- **Formatter**: `ruff format .`
- **Linter**: `ruff check .`
- **Type hints**: Required on all public functions
- **Tests**: `pytest` (add tests in `backend/app/tests/`)

### C++ (Firmware)
- **Standard**: C++17 (Arduino framework)
- **Style**: PlatformIO default (clang-format)
- **Modules**: Keep sensors, signal, comms, storage, UI, diagnostics separate

## Testing

```bash
# Flutter tests (from app/)
flutter test                    # all tests
flutter test test/unit/         # unit only
flutter test test/widget/       # widget only
flutter test --coverage         # with coverage

# Backend tests (from backend/)
python -m pytest                # all tests
python -m pytest -v             # verbose

# Firmware (from firmware/)
pio test                        # native tests (if added)
```

## Adding Translations

1. Edit `app/lib/l10n/app_en.arb` (source of truth)
2. Run `flutter gen-l10n` (auto-generates `.dart` files)
3. Translate `app_hi.arb` (Hindi) and `app_bn.arb` (Bengali)
3. Keys stay English; only values translate

## Adding Sensors / Hardware

1. Add driver in `firmware/src/sensors/`
2. Add signal processing in `firmware/src/signal/`
3. Update BLE protocol in `firmware/src/protocol/` + `app/lib/core/services/ble_protocol.dart`
4. Update `hardware/HARDWARE.md` with pinout, BOM, schematic
5. Add diagnostics in `firmware/src/diagnostics/`

## Security

- **No secrets in code** — API keys via `--dart-define` or runtime Settings
- **JWT secret** must be overridden in production `.env`
- **Report vulnerabilities** privately via [Security Advisory](https://github.com/krishnendukoley2007-arch/swasthyasetu-ai/security/advisories/new)

## Medical Disclaimer Reminder

> This is a **screening aid**, not a diagnostic tool. All changes to triage rules, explanations, or emergency flows must preserve:
> - Deterministic, threshold-based risk engine
> - Clear labeling of offline vs. online explanations
> - No clinical claims in UI or docs
> - Emergency SOS opens system apps (no silent send)

## Questions?

- Open a [Discussion](../../discussions) for design questions
- Open an [Issue](../../issues/new/choose) for bugs/features
- Check existing [Wiki](../../wiki) for architecture docs

---

**Remember**: Every line of code affects real health workers in low-resource settings. Keep it honest, keep it offline-first, keep it safe. 🏥