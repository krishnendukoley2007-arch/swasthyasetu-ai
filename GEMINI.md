# SwasthyaSetu AI — Workspace Instruction Manual (`GEMINI.md`)

This document outlines the foundational architectural mandates, development conventions, and environmental requirements for the SwasthyaSetu AI project. **These instructions are foundational mandates and take absolute precedence over general defaults.**

---

## 🚀 1. Environmental & Tooling Setup

### 1.1 Flutter Path Resolution
The Flutter SDK is installed locally at `C:\flutter\`. To execute any Flutter or Dart CLI tools (e.g., test runner, analyzer, formatter, build runner) within PowerShell, you **must prepend the binary folder to the environment PATH** of your session:

```powershell
# Prepend Flutter to PATH before running commands
$env:PATH = 'C:\flutter\bin;' + $env:PATH

# Verify installation
flutter --version
```

### 1.2 Core Commands
*   **Run All Tests:** `$env:PATH = 'C:\flutter\bin;' + $env:PATH; flutter test`
*   **Linter Check:** `$env:PATH = 'C:\flutter\bin;' + $env:PATH; flutter analyze`
*   **Code Formatting:** `$env:PATH = 'C:\flutter\bin;' + $env:PATH; dart format .`
*   **Code Generation (Drift DB/Riverpod):** `$env:PATH = 'C:\flutter\bin;' + $env:PATH; dart run build_runner build --delete-conflicting-outputs`

---

## 🏛️ 2. Architectural Principles (Strictly Enforced)

All modifications, features, and bug fixes must adhere to these four core design principles:

### 2.1 One-Way Provenance (`isDemo` Flag)
*   **Mandate:** Data can flow from measured/live to demo-flagged, but **never the reverse**.
*   **Practice:** The `isDemo` attribute on vitals and screenings must be strictly propagated. Simulated or demo readings must never be allowed to demote or masquerade as real, measured clinical measurements. Tests must verify that demo data is entirely isolated from actual diagnostic/triage records.

### 2.2 Storage Stays English (Single Vocabulary)
*   **Mandate:** Only user-facing *labels* and *UI strings* are translated.
*   **Practice:** The database (Drift/SQLite), exported files (JSON/CSV), and the triage rule engine share exactly **one English vocabulary**. A screening performed under a Bengali or Hindi localization must generate the exact same English keys and values in storage as one performed in English.

### 2.3 No Fabricated Gaps
*   **Mandate:** Missing or failed sensor values must render as `—` (em dash).
*   **Practice:** Never replace missing values with `0`, `null`, or an interpolated/plausible-looking guess. If a sensor measurement is missing or is excluded (e.g., experimental metrics), it must be explicitly represented as unmeasured.

### 2.4 Screening Support, Not Diagnosis
*   **Mandate:** The application is a screening/triage tool, not a diagnostic one.
*   **Practice:** Every vital screen, result screen, and health report must clearly display the required medical disclaimers. Its risk levels are based on deterministic thresholds, not clinical judgment.

### 2.5 AI Flags Are Advisory, Never Authoritative
*   **Mandate:** Any learned/statistical model output (an "AI flag") may be *displayed* alongside a screening result, but must **never** alter the deterministic triage band computed by `risk_engine.dart`.
*   **Practice:** AI flags are stored in a separate field (`aiAnomalyFlag`, `aiAnomalyScore`) from `riskBand`. `risk_engine.dart` must have zero import dependency on the AI module. A test must assert that feeding the same vitals with different AI flag values produces an identical `riskBand`.

---

## 🧪 3. Quality Assurance & Test Invariants

The codebase runs on an automated test suite containing over 440 tests. Every code change must maintain 100% test passing status and uphold the following critical test invariants:

### 3.1 Accessibility Scaling & Layout Integrity
*   **Invariant:** All screens must render at a high accessibility text scale factor (**`textScaleFactor: 2.0`**) and high contrast without any pixel overflow or clipping.
*   **Practice:** Avoid hardcoded container heights or non-wrapping layouts. Use flexible grids, `SingleChildScrollView`, and text-wrap layouts. Always run `overflow_test.dart` to verify layout compliance.

### 3.2 Map Honesty & Consent
*   **Invariant:** When user location consent is off, the map widget must explicitly display a "Location is OFF" message instead of rendering empty terrain. It is unacceptable to let the user assume there is no regional health data.

### 3.3 BLE Frame Integrity
*   **Invariant:** The custom binary protocol frame size between the ESP32 firmware and the Dart parser must remain exactly **20 bytes** (`static_assert(sizeof(telemetry_frame_t) == 20)`).
*   **Practice:** Any changes to packet structure or custom BLE characteristics must be verified in both `ble_protocol_test.dart` and `test_dsp.cpp` (firmware test).

---

## 📂 4. Project Directory Structure

Unlike standard monorepos, this workspace is structured with the Flutter application residing **directly in the root directory (`C:\nvdia\`)**:

*   `lib/core/` — Bluetooth LE services, offline maps, storage, sync, providers, themes, and routing.
*   `lib/data/` — Drift/SQLite database schema (`app_database.dart`), repositories, and row mappers.
*   `lib/domain/` — Domain models and the deterministic triage rule engine. **This folder must remain pure Dart without Flutter UI dependencies.**
*   `lib/features/` — Feature-focused screen modules (e.g., `screening`, `dashboard`, `patients`, `settings`, `emergency`).
*   `lib/l10n/` — ARB translation files (`app_en.arb`, `app_hi.arb`, `app_bn.arb`).
*   `test/` — Comprehensive unit, widget, and overflow tests.
*   `firmware/` — SSAI-SENSE ESP32 firmware sketch (ECG, touch, OLED, BLE, DSP).
*   `tools/` — Laptop dashboard (`ecg_dashboard.html`) for live Web-Bluetooth ECG viewing.
*   `website/` — Local offline web dashboard resources.

---

## 📝 5. Commits & Workflows

### 5.1 Pre-Commit Checklist
Before proposing or making a commit:
1.  Run `dart format .` to auto-format files.
2.  Run `flutter analyze` to ensure zero linter warnings or errors.
3.  Run `flutter test` to verify all 440+ tests pass.

### 5.2 Conventional Commits
Use standard conventional commits structure:
*   `feat:` (new features, e.g., SpO₂ integration)
*   `fix:` (bug fixes, e.g., resolving a layout overflow on high font scaling)
*   `refactor:` (pure structure refactoring)
*   `test:` (new tests or test fixes)
*   `docs:` (documentation updates)
