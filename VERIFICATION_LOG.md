# SwasthyaSetu AI — Physical Verification & System Log

> [!IMPORTANT]
> **Mandate 2.1 & 2.3 Provenance Separation:**  
> This document enforces strict separation between:
> 1. **Physically Verified by a Human on Real Hardware** (Bench testing by developer/operator with real sensors and Android smartphone).
> 2. **Automated Unit & Widget Tests** (Programmatic CI tests running in an automated sandbox environment).
> These two claims represent entirely distinct categories of evidence and must never be conflated.

---

## 1. Physical Bench Hardware Verification Log

**Lead Tester:** Krish  
**Date of Testing:** September 13, 2026  
**Test Environment:** Laboratory bench testing with physical hardware and real mobile device.

### 1.1 Equipment Under Test

| Equipment | Specification | Status |
| :--- | :--- | :--- |
| **Microcontroller Board** | ESP32-WROOM-32 Dev Module (DOIT ESP32 DEVKIT V1) | Confirmed physical bench unit |
| **Optical Vitals Sensor** | MAX30102 (Red: 660 nm, IR: 880 nm, I²C address `0x57`) | Connected on GPIO 21 (SDA) & GPIO 22 (SCL) |
| **ECG Front-End** | Lead I Capacitive Touch / Single-lead analog front-end | Connected to ADC1 (GPIO 34) |
| **Display** | 0.96" SSD1306 128x64 I²C OLED (`0x3C`) | 5-Page animated dashboard active |
| **Android Smartphone** | *[PENDING USER CONFIRMATION: Exact phone make/model]* | Running `SwasthyaSetu_AI_Final.apk` |
| **Host Workstation** | Windows PC running Google Chrome / Microsoft Edge | Tested with `tools/ecg_dashboard.html` |

---

### 1.2 Exact Physical Test Steps Performed

1. **Firmware Deployment:**
   - Flashed `firmware/SSAI_SENSE_final/SSAI_SENSE_final.ino` to the physical ESP32 over USB-C.
   - Verified serial output and confirmed OLED booted into `PAGE_VITALS` and `PAGE_SYS`.

2. **Optical MAX30102 Pulse Rate & $\text{SpO}_2$ Response:**
   - Finger placed on MAX30102 optical window.
   - Monitored real-time optical tracking.
   - **Observed Values:** Heart rate dynamic transition observed starting at $67\text{ bpm}$, moving through $70\text{ bpm}$, $75\text{ bpm}$, and stabilizing at $78\text{ bpm}$. Initial uncalibrated optical reading showed $100\%$ before DC/AC ratio filter settling.
   - *[PENDING USER CONFIRMATION: Exact stabilized SpO2 % value after calibration]*

3. **ECG Lead-Off Physical Response:**
   - Alternated physical finger contact on/off the ECG electrodes.
   - Confirmed lead-off detection physically triggers when hands are removed and recovers immediately when contact is re-established.
   - *[PENDING USER CONFIRMATION: Exact measured lead-off response latency in milliseconds]*

4. **Mobile Application Runtime Stability:**
   - Installed `SwasthyaSetu_AI_Final.apk` on physical Android smartphone.
   - Executed app navigation, screening wizards, and dashboard interactions.
   - Confirmed zero app crashes, freezes, or ANRs during real device session.

5. **Laptop Zero-Install Web-Bluetooth Workstation:**
   - Paired laptop browser (Chrome/Edge) with `SSAI-SENSE` over Web Bluetooth using `tools/ecg_dashboard.html`.
   - Verified real-time hex telemetry streaming, chart rendering, and CSV export.

---

## 2. Automated Test Suite Invariants (Synthetic Sandbox)

> [!NOTE]
> The following automated tests execute strictly within continuous integration / local development sandboxes (Dart VM, Flutter Test Runner, PlatformIO Native GCC). They prove algorithmic correctness, layout overflow immunity, and protocol parsing integrity, but do **not** replace physical human trials.

| Automated Test Suite | Test Runner | Result | Scope of Verification |
| :--- | :--- | :---: | :--- |
| **Flutter Full Test Suite** | `flutter test` | **564 / 564 PASSED** | Unit logic, clinical triage band invariants, protocol parsers, routing |
| **Accessibility Layout Suite** | `test/overflow_test.dart` | **128 / 128 PASSED** | Layout integrity at `textScaleFactor: 2.0` across 360x640 viewports |
| **Localization Guard** | `test/localization_guard_test.dart` | **PASSED** | Hardcoded string literal enforcement |
| **Firmware Pure DSP Suite** | `pio test -e native` | **12 / 12 PASSED** | C++ Pan-Tompkins QRS, dicrotic notch, SQI, and median filtering |
| **Static Code Analyzer** | `flutter analyze` | **0 ISSUES** | Dart linting, type safety, zero deprecation warnings |

---

## 3. Pending Physical Information to be Recorded

To ensure 100% factual accuracy without invented data, the following specific real-world values require direct logging from Krish:

- [ ] **Exact Smartphone Model:** (e.g., Samsung Galaxy S21 / Redmi Note 11 / OnePlus 9 / etc.)
- [ ] **Exact Android OS Version:** (e.g., Android 13 / Android 14)
- [ ] **Exact Final $\text{SpO}_2$ Reading Observed:** (e.g., 97%, 98%, 99%)
- [ ] **Estimated/Measured Lead-Off Response Time:** (e.g., < 200 ms)
