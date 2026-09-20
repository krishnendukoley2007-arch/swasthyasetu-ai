# SwasthyaSetu AI — Hardware Build Report

**Revision 2.0 — 2026-08-27**
Board: `SSAI-SENSE-01`
Target problem statement: SIH **26181** (Qualcomm Inc, Category: Hardware, Theme: MedTech/BioTech/HealthTech)

This document is the **authoritative build reference**. The netlist tables in
§6 are the source of truth for wiring; `hardware-schematic.svg` is a visual aid
derived from them. The BLE frame layout in §14 is transcribed byte-for-byte
from [ble_protocol.dart](../lib/core/services/ble_protocol.dart) — if the two
ever disagree, the Dart file wins, because that is what ships on the phone.

---

## 0. Errata against Revision 1 — read this before buying anything

Revision 1 of this file described a device that **cannot power on**. Five defects,
in severity order:

| # | Rev-1 statement | Why it is wrong | Fix |
|---|---|---|---|
| **E1** | Power chain `Li-ion 3.7 V → TP4056 → AMS1117-3.3 → ESP32 3V3` | **Fatal.** AMS1117-3.3 needs V<sub>in</sub> ≥ 4.4 V (1.1 V dropout at 800 mA). A Li-ion cell spans 4.2 V→3.0 V, so the regulator is *never* in regulation. Output sags with the cell, ESP32 browns out on the first BLE transmit burst, and below ~3.6 V the board is simply dead — with 60 % of the battery unused. | §5: buck-boost (TPS63020) **or** boost → DevKit VIN. Never an LDO fed from a bare cell. |
| **E2** | MLX90614 accuracy "±0.2 °C" | Only the **DCI/DCC** medical variant achieves ±0.2 °C, and only over 36–38 °C. The cheap **BAA** on every ₹400 breakout is ±0.5 °C with a 90° field of view — at 3 cm it averages a 6 cm circle of forehead, hair and air. | §10: buy DCI for a fever claim, or state ±0.5 °C honestly. |
| **E3** | MPU6050 `INT` absent from the pin map | Without it the IMU must be polled, so the ESP32 can never deep-sleep — and 24/7 fall detection is the one thing this board offers that the phone cannot. | §6: `INT` → **GPIO33** (RTC-capable, `ext1` wake). |
| **E4** | `LO+`/`LO−` on GPIO32/33 with 10 kΩ pull-downs | Burns both RTC wake pins on signals that never need to wake anything, and pull-downs on AD8232 **push-pull** outputs just waste current. | §6: `LO+`→GPIO39, `LO−`→GPIO34, no pull-downs. |
| **E5** | All four I²C devices on one bus | The purple GY-MAX30102 breakout references its pull-ups to its own **1.8 V** rail. Sharing a 3.3 V bus back-drives that rail through the pull-ups. | §7: MAX30102 on a **separate** I²C bus (GPIO26/27). |

Two Rev-1 choices were already correct and are kept: ECG analog → **GPIO34…36**
and battery sense → **GPIO35**, both on **ADC1**. (ADC2 is unusable whenever the
WiFi radio is active — a hardware erratum, not a driver bug.)

**Correction to earlier verbal advice:** if you heard "use an MCP1700" from me
during the audit, ignore it. MCP1700 sources 250 mA; the ESP32 pulls ~240 mA on
BLE bursts and up to ~500 mA on WiFi. It would brown out. Use the parts in §5.

---

## 1. What this board is for

The phone already does screening. The board exists to do the three things a
phone **cannot**:

1. **Continuous vitals while the phone is asleep or in a pocket** — HR, SpO₂,
   skin temperature, single-lead ECG, streamed over BLE.
2. **Fall detection that survives the screen going off.** Android kills
   foreground accelerometer streams; a coin-cell-class MCU with a motion
   interrupt does not sleep through a fall. This is the board's headline claim.
3. **Body-worn measurements no camera can fake** — a real ECG lead, a real
   reflectance PPG, a real IR skin temperature.

Everything else (triage, LLM explanation, SOS, advisories) stays on the phone.
The board is a *sensor*, not a diagnostician. It never computes a risk band —
that boundary is enforced in [risk_engine.dart](../lib/domain/rules/risk_engine.dart)
and the firmware must not attempt to cross it.

---

## 2. System architecture

```
                    ┌───────────────────────────────────────┐
   3-lead ECG ─────▶│ AD8232 analog front end (0.5–40 Hz)   │──▶ ADC1_CH0 (GPIO36)
   electrodes       │  LO+ / LO− leads-off, SDN shutdown     │──▶ GPIO39 / GPIO34
                    └───────────────────────────────────────┘◀── GPIO18 (SDN)

   fingertip ──────▶ MAX30102  (PPG red+IR, 100 Hz) ── I²C1 (GPIO26/27) + INT GPIO19
   forehead  ──────▶ MLX90614  (IR skin temp)       ── I²C0 (GPIO21/22) @ 0x5A
   body      ──────▶ MPU6050   (accel/gyro, fall)   ── I²C0 @ 0x68  + INT GPIO33
   ambient   ──────▶ BME280    (T / RH / pressure)  ── I²C0 @ 0x76
   display   ◀───── SSD1306    (128×64 OLED)        ── I²C0 @ 0x3C
   air (opt) ──────▶ PMS5003   (PM2.5)              ── UART2 (GPIO16/17)

                    ┌───────────────────────────────────────┐
                    │  ESP32-WROOM-32  (dual core, BLE 4.2) │
                    │  core0: sensor sampling + DSP          │
                    │  core1: BLE NUS notify @ 31.25 Hz      │
                    └───────────────────────────────────────┘
                                     │  BLE GATT, 20-byte frames
                                     ▼
                    Android app — flutter_blue_plus, ble_service.dart
```

**Deliberate split:** ECG filtering, R-peak detection and SpO₂ ratio-of-ratios
run **on the ESP32** (fixed sample timing, no OS jitter). Rhythm
*classification* runs on the phone in
[ecg_classifier.dart](../lib/domain/rules/ecg_classifier.dart), because that is
where it can be unit-tested and where the audit trail lives.

---

## 3. Bill of materials — India sourcing, ₹ (Aug 2026)

Prices are typical Robu.in / ElectronicsComp / Amazon.in retail for qty 1.

### 3.1 Core build (required)

| Ref | Part | Exact part number to order | Qty | ₹ ea | ₹ |
|---|---|---|---|---|---|
| U1 | MCU dev board | **ESP32-WROOM-32 DevKit V1**, 30-pin | 1 | 380 | 380 |
| U2 | ECG front end | **AD8232 heart-rate monitor breakout** (SparkFun-compatible, with 3.5 mm jack) | 1 | 750 | 750 |
| U3 | PPG / SpO₂ | **MAX30102** breakout (GY-MAX30102, purple PCB) | 1 | 420 | 420 |
| U4 | IR temperature | **MLX90614ESF-BAA** breakout (see §10 for DCI upgrade) | 1 | 460 | 460 |
| U5 | IMU | **MPU-6050** breakout (GY-521) | 1 | 130 | 130 |
| U6 | Ambient env | **BME280** breakout, I²C, 3.3 V | 1 | 320 | 320 |
| U7 | Display | **SSD1306 0.96″ 128×64 OLED**, I²C, 4-pin | 1 | 210 | 210 |
| U8 | Charger | **TP4056 + DW01A protection module**, micro-USB, with load-sharing | 1 | 60 | 60 |
| U9 | Regulator | **TPS63020 buck-boost module**, 3.3 V out, 2 A (see §5 Option A) | 1 | 420 | 420 |
| BT1 | Cell | **18650 Li-ion 3000 mAh**, protected, genuine (Samsung 30Q / LG MJ1) | 1 | 550 | 550 |
| — | Holder | 18650 single-cell holder, PCB mount | 1 | 40 | 40 |
| — | ECG electrodes | **Ag/AgCl disposable ECG pads**, pack of 50 | 1 | 350 | 350 |
| — | ECG cable | 3-lead snap cable, 3.5 mm TRS plug | 1 | 380 | 380 |
| BZ1 | Buzzer | Active piezo buzzer, 3.3 V, 85 dB | 1 | 35 | 35 |
| SW1 | Button | 6×6 mm tactile push button + cap | 2 | 8 | 16 |
| — | Passives | 100 kΩ ×3, 4.7 kΩ ×4, 10 kΩ ×2, 100 nF ×4, 10 µF ×2, 100 µF ×1 (all 0805 or through-hole) | — | — | 120 |
| — | Wiring | 22 AWG silicone hookup wire, 5 colours, 2 m each | — | — | 180 |
| — | Board | 7×9 cm double-sided prototype PCB ×2 | — | — | 90 |
| — | Headers | 2.54 mm male + female strips, 40-pin ×4 | — | — | 100 |
| **Core subtotal** | | | | | **₹ 5,011** |

### 3.2 Optional / stretch

| Part | Why | ₹ |
|---|---|---|
| **MLX90614ESF-DCI** (5° FOV, ±0.2 °C medical) | Only way to honestly claim fever detection | 1,650 |
| **PMS5003** laser PM2.5 sensor | Turns the pollution advisory from "Open-Meteo says" into a measured local number — a genuine PS-26181 differentiator | 1,450 |
| **DS3231** RTC module | Timestamps survive a flat battery; matters for the audit trail | 120 |
| **Micro-SD module** | Local ring buffer when the phone is out of range | 90 |
| 25 mm black-painted copper sphere + thermistor | DIY black-globe for **real WBGT** (§11.3) | 250 |
| 3D-printed enclosure (PETG, outsourced print) | — | 600 |

### 3.3 Budget summary

| Configuration | ₹ | ≈ USD |
|---|---|---|
| Core build only | 5,011 | $57 |
| Core + DCI temperature sensor | 6,661 | $76 |
| Core + DCI + PMS5003 + RTC + SD | 8,321 | $95 |
| Full demo set incl. enclosure, spare cell, second build | ~12,500 | $142 |

**Buy two of everything cheap** (ESP32, MPU6050, OLED, MAX30102). At a
hackathon, a dead breakout at 03:00 with no spare has ended more projects than
bad code. Total spare cost ≈ ₹1,200.

---

## 4. ESP32 pin constraints — why the map in §6 is what it is

These are hardware facts about ESP32-WROOM-32, not preferences. Violating them
produces boards that boot sometimes.

| Pins | Constraint | Consequence for this design |
|---|---|---|
| GPIO 6–11 | Wired to the SPI flash die inside the module | **Never expose. Never use.** Not brought out on the DevKit anyway. |
| GPIO 34, 35, 36(VP), 37, 38, 39(VN) | **Input only.** No output driver, **no internal pull-up/pull-down** | Perfect for ADC and for AD8232's push-pull `LO+`/`LO−`. Useless for anything needing a pull-up — hence MAX30102 `INT` goes to GPIO19, not GPIO34. |
| ADC2 = GPIO 0,2,4,12–15,25–27 | **Unusable while WiFi is active** (hardware erratum) | All analog inputs must be **ADC1** = GPIO 32–39. ECG→36, battery→35. |
| GPIO 0, 2, 5, 12, 15 | **Strapping pins** sampled at reset | GPIO0 must be high to boot (it has a pull-up + BOOT button). GPIO12 selects flash voltage — pulling it high can **brick the module**. Avoid 0/12/15 entirely; GPIO2 is safe as an *output* to the onboard LED, GPIO5 left spare. |
| GPIO 1 (TX0), 3 (RX0) | USB-serial console | Leave free for flashing and logs. |
| RTC GPIOs: 0,2,4,12–15,25–27,32–39 | Only these can wake from deep sleep | Fall wake on **GPIO33**, button wake on **GPIO32**. Both RTC. |
| GPIO 16, 17 | Used for PSRAM on **WROVER** modules | Fine on WROOM-32 (no PSRAM). If you substitute a WROVER, move the PMS5003 UART to GPIO 4/5. |
| ADC full scale | ~0–3.1 V usable with 11 dB attenuation; non-linear at both rails | Battery divider is sized to land mid-range (§12). Never feed a raw 4.2 V to any pin. |

`ext1` deep-sleep wake on the original ESP32 supports only `ANY_HIGH` or
`ALL_LOW`. Two independent wake sources therefore need **matching active-high
polarity**, which is why the MPU6050 `INT` is configured push-pull active-**high**
and SW1 is wired to **3V3** with a pull-down to GND (§6.7). Do not wire the
button to ground "the normal way" — it breaks `ext1`.

---

## 5. Power architecture

### 5.1 Load budget (measured-typical, ESP32-WROOM-32 @ 3.3 V)

| State | ESP32 | AD8232 | MAX30102 | MLX90614 | MPU6050 | BME280 | OLED | Total |
|---|---|---|---|---|---|---|---|---|
| **Streaming** (BLE notify 31 Hz, ECG+PPG on, OLED on) | 90 mA avg / 240 mA peak | 0.2 mA | 12 mA | 1.5 mA | 3.9 mA | 0.7 mA | 22 mA | **≈ 130 mA avg** |
| **Monitoring** (BLE connected, PPG duty-cycled 1-in-10, OLED off) | 55 mA | 0.2 mA | 1.5 mA | 1.5 mA | 3.9 mA | 0.7 mA | 0 | **≈ 63 mA** |
| **Idle** (BLE advertising, sensors in low power) | 25 mA | 0 (SDN) | 0.7 mA | 2 µA | 0.4 mA | 0.3 µA | 0 | **≈ 26 mA** |
| **Deep sleep** (fall-watch only) | 10 µA | 0 (SDN) | 0.7 µA | 2.5 µA | 10 µA (cycle mode) | 0.1 µA | 0 | **≈ 25 µA** |

Peak transient: the ESP32 draws **~240 mA for ~2 ms** on each BLE TX and up to
**500 mA** if WiFi provisioning is ever enabled. The regulator must survive that
without dipping below 3.0 V, and a **100 µF bulk + 100 nF** across 3V3 at the
module is what actually absorbs it. Skip that capacitor and you get random
reboots that look like firmware bugs.

### 5.2 Runtime on a 3000 mAh cell

Usable energy at 85 % converter efficiency, 90 % of nameplate capacity:
`3000 mAh × 3.7 V × 0.90 × 0.85 ÷ 3.3 V ≈ 2570 mAh @ 3.3 V`

| Mode | Current | Runtime |
|---|---|---|
| Continuous streaming | 130 mA | **≈ 19.8 h** |
| Monitoring (realistic all-day wear) | 63 mA | **≈ 40 h** |
| Idle / advertising | 26 mA | ≈ 99 h |
| Deep sleep, fall-watch only | 25 µA | **≈ 11 months** |

**That last row is the demo.** A phone cannot watch for a fall for 11 months on
one charge. Lead with it.

### 5.3 Option A — buck-boost (recommended)

```
  18650 (3.0–4.2 V)
      │
      ├──▶ TP4056 + DW01A  ◀── micro-USB 5 V charge in
      │     (BAT+/BAT−, protection MOSFETs)
      │
      ▼
  TPS63020 buck-boost module  ── 3.3 V, up to 2 A ──▶  3V3 rail
      │                                                  │
      └── input 100 µF                       output 100 µF + 100 nF
```

The TPS63020 **boosts** when the cell is below 3.3 V and **bucks** when above,
so the rail is a flat 3.3 V from 4.2 V all the way down to ~2.5 V. You use the
whole cell. Feed the ESP32 DevKit's **3V3 pin** directly (bypassing its onboard
AMS1117) and jumper nothing else to VIN.

> **Do not** connect 5 V to VIN *and* 3.3 V to 3V3 at the same time. You will
> back-drive the DevKit's onboard regulator through its output pin.

### 5.4 Option B — boost to 5 V, use the onboard regulator (simplest)

```
  18650 → TP4056/DW01A → MT3608 boost (set to 5.0 V) → DevKit VIN(5V) pin
                                                        → onboard AMS1117 → 3V3
```

Two conversions in series, so efficiency drops to ~72 % and streaming runtime
falls to **≈ 14.8 h**. But it needs zero rework of the DevKit and is the
fastest path to a working board. **Set the MT3608 trimpot to 5.0 V with a
multimeter *before* connecting it to the ESP32** — it ships anywhere from 5 V to
28 V and 28 V will destroy the module instantly.

### 5.5 Option C — what NOT to do

`Li-ion → AMS1117-3.3 → ESP32`. This was Revision 1. See **E1**. Any LDO with
>0.3 V dropout fed from a bare Li-ion cell is a non-functional design.

### 5.6 Decoupling — non-negotiable

| Location | Part | Purpose |
|---|---|---|
| 3V3 rail at ESP32 module pins | **100 µF** electrolytic/tantalum **+ 100 nF** ceramic | absorbs the 240 mA BLE transient |
| Each sensor breakout VCC→GND | **100 nF** ceramic, at the breakout | local high-frequency |
| AD8232 VCC→GND | **10 µF + 100 nF** | ECG front end is the noise-sensitive one; give it its own bulk |
| Regulator input | 100 µF | source impedance of a long battery wire |

---

## 6. Complete GPIO map and netlist

### 6.1 Pin assignment table

| GPIO | Net name | Dir | Peripheral | Attached to | Notes |
|---|---|---|---|---|---|
| **21** | `I2C0_SDA` | I/O | I²C bus 0 | MLX90614, MPU6050, BME280, SSD1306 | 4.7 kΩ pull-up to 3V3 |
| **22** | `I2C0_SCL` | I/O | I²C bus 0 | ″ | 4.7 kΩ pull-up to 3V3 |
| **26** | `I2C1_SDA` | I/O | I²C bus 1 | MAX30102 **only** | breakout has its own 1.8 V-referenced pull-ups — add none |
| **27** | `I2C1_SCL` | I/O | I²C bus 1 | MAX30102 **only** | ″ |
| **36** | `ECG_OUT` | **in** | ADC1_CH0 (SENSOR_VP) | AD8232 `OUTPUT` | analog, 0–3.3 V, 250 Hz sampled |
| **35** | `VBAT_SENSE` | **in** | ADC1_CH7 | battery divider midpoint | 100 k/100 k + 100 nF |
| **39** | `ECG_LO_P` | **in** | — (SENSOR_VN) | AD8232 `LO+` | push-pull, **no** pull resistor |
| **34** | `ECG_LO_N` | **in** | — | AD8232 `LO−` | push-pull, **no** pull resistor |
| **18** | `ECG_SDN` | out | — | AD8232 `SDN` | **active LOW** = shutdown. Drive HIGH to enable. |
| **19** | `PPG_INT` | in | — | MAX30102 `INT` | open-drain → needs `INPUT_PULLUP`, so it cannot live on 34–39 |
| **33** | `IMU_INT` | in | RTC GPIO | MPU6050 `INT` | **active HIGH**, push-pull → `ext1` wake source |
| **32** | `BTN_MAIN` | in | RTC GPIO | SW1 | **switch to 3V3**, 100 kΩ pull-down to GND → `ext1` wake |
| **25** | `BUZZ` | out | LEDC ch0 | BZ1 base/gate | 2 kHz PWM via NPN or direct if buzzer <20 mA |
| **2** | `LED_STAT` | out | — | onboard blue LED | strapping pin — output only, never read at boot |
| **4** | `CHG_STAT` | in | RTC GPIO | TP4056 `CHRG` pad | open-drain, `INPUT_PULLUP`. LOW = charging → §13 interlock |
| **16** | `PM_RX` | in | UART2 RX | PMS5003 `TXD` (opt) | move to GPIO4/5 on WROVER |
| **17** | `PM_TX` | out | UART2 TX | PMS5003 `RXD` (opt) | ″ |
| **13** | `SW2` | in | — | SW2 (mode/mark) | `INPUT_PULLUP`, switch to GND |
| 5, 14, 23 | — | — | — | spare | 5 is a strapping pin; prefer 14/23 first |
| 0, 1, 3, 12, 15 | reserved | — | boot / console / flash-voltage | **do not use** | see §4 |

### 6.2 Net-by-net wiring — U1 ESP32 DevKit V1

| From (ESP32 DevKit pin) | To | Wire colour |
|---|---|---|
| `3V3` | 3V3 rail (from TPS63020 OUT) | red |
| `GND` (any two) | GND rail | black |
| `GPIO21` | I²C0 SDA rail | blue |
| `GPIO22` | I²C0 SCL rail | yellow |
| `GPIO26` | U3 MAX30102 `SDA` | blue/white |
| `GPIO27` | U3 MAX30102 `SCL` | yellow/white |
| `GPIO36 (VP)` | U2 AD8232 `OUTPUT` | white |
| `GPIO39 (VN)` | U2 AD8232 `LO+` | orange |
| `GPIO34` | U2 AD8232 `LO−` | orange/white |
| `GPIO18` | U2 AD8232 `SDN` | green |
| `GPIO19` | U3 MAX30102 `INT` | violet |
| `GPIO33` | U5 MPU6050 `INT` | grey |
| `GPIO32` | SW1 common | brown |
| `GPIO35` | battery divider midpoint | pink |
| `GPIO25` | BZ1 drive | green/white |
| `GPIO4` | U8 TP4056 `CHRG` test pad | grey/white |
| `GPIO13` | SW2 common | brown/white |
| `GPIO16` / `GPIO17` | U-opt PMS5003 `TXD` / `RXD` | — |

### 6.3 U2 — AD8232 ECG breakout

| AD8232 pin | Connect to | Notes |
|---|---|---|
| `3.3V` | 3V3 rail | add 10 µF + 100 nF locally |
| `GND` | GND rail | **single-point star to the analog ground** — see §8.4 |
| `OUTPUT` | GPIO36 | analog, ~1.5 V quiescent (mid-rail) |
| `LO+` | GPIO39 | HIGH = that electrode is off the body |
| `LO−` | GPIO34 | ″ |
| `SDN` | GPIO18 | LOW = shut down (≈ 0 µA). Firmware holds it HIGH only while measuring. |
| `RA` / `LA` / `RL` | 3.5 m jack tip / ring / sleeve | via the supplied cable; do **not** rewire |

The breakout already implements the recommended network: 0.5 Hz high-pass
(two-pole), 40 Hz low-pass, gain ≈ 100, and the **RLD** (right-leg drive)
common-mode feedback. Do not modify it. If your board version exposes only
`RA/LA/RL` pads and no jack, solder the snap cable directly.

### 6.4 U3 — MAX30102 PPG breakout (separate bus)

| MAX30102 pin | Connect to |
|---|---|
| `VIN` | 3V3 rail (the breakout has its own 1.8 V + 3.3 V LDOs on board) |
| `GND` | GND rail |
| `SDA` | GPIO26 |
| `SCL` | GPIO27 |
| `INT` | GPIO19 |
| `RD` / `IRD` | leave unconnected |

**Why a second bus (E5):** the common purple GY-MAX30102 board pulls SDA/SCL up
to its internal **1.8 V** rail. Put it on a bus with 3.3 V pull-ups and current
flows backwards into that rail through the pull-ups; the symptom is a device
that answers `0x57` intermittently and corrupts other devices' transactions.
Isolating it on `Wire1` with **no external pull-ups** is the clean fix and costs
two GPIOs you were not otherwise using.

If you have the **red Maxim-reference** breakout (3.3 V-referenced pull-ups),
you may put it on I²C0 at `0x57` and free GPIO26/27. Verify with a multimeter:
probe SDA to GND with the board powered — 1.8 V means separate bus, 3.3 V means
shared is safe.

### 6.5 U4 — MLX90614 IR temperature

| MLX90614 pin | Connect to |
|---|---|
| `VIN` | 3V3 rail |
| `GND` | GND rail |
| `SDA` | I²C0 SDA (GPIO21) |
| `SCL` | I²C0 SCL (GPIO22) |

Fixed address `0x5A`. It is an **SMBus** device: clock it at **≤ 100 kHz** and
insert a ≥ 1.44 ms idle between transactions, otherwise it NAKs. This caps the
whole of I²C0 at 100 kHz — which is why the OLED is the slowest thing on the
board and why its refresh is limited to 4 Hz in firmware.

### 6.6 U5 — MPU6050 IMU

| MPU6050 pin | Connect to |
|---|---|
| `VCC` | 3V3 rail (GY-521 has an onboard LDO; 3.3 V in is fine) |
| `GND` | GND rail |
| `SDA` / `SCL` | I²C0 (GPIO21 / GPIO22) |
| `INT` | GPIO33 |
| `AD0` | GND → address `0x68` |
| `XDA` / `XCL` / `INT`-aux | leave unconnected |

### 6.7 SW1 — wake button (note the unusual polarity)

```
        3V3 ──┬── SW1 ──┬── GPIO32
              │         │
              │        100 kΩ
              │         │
             GND ───────┴── GND
```

Pressed = **HIGH**. This is deliberate: `ext1` deep-sleep wake with two sources
requires all of them active-high (§4). Add a 100 nF from GPIO32 to GND for
debounce; also debounce 30 ms in firmware.

SW2 on GPIO13 is conventional (switch to GND, `INPUT_PULLUP`) because it never
needs to wake the chip.

### 6.8 U7 — SSD1306 OLED

| OLED pin | Connect to |
|---|---|
| `VCC` | 3V3 rail |
| `GND` | GND rail |
| `SDA` / `SCL` | I²C0 |

Address `0x3C` (a few clones are `0x3D`; the bring-up scan in §16 tells you).

### 6.9 BZ1 — buzzer

An active piezo buzzer drawing <20 mA may be driven straight from GPIO25.
Anything louder needs a switch:

```
  GPIO25 ──1 kΩ── B│ 2N2222 / BC547
                    C ── BZ1 − ,  BZ1 + ── 3V3
                    E ── GND
  Flyback: 1N4148 across BZ1, cathode to 3V3
```

Drive it with **LEDC at 2–2.7 kHz** (piezo resonance), not `digitalWrite` — a
static high produces a click, not a tone.

---

## 7. I²C bus plan

### 7.1 Address map

| Bus | Speed | Address | Device | Conflict? |
|---|---|---|---|---|
| I²C0 (21/22) | **100 kHz** | `0x3C` | SSD1306 OLED | — |
| I²C0 | 100 kHz | `0x5A` | MLX90614 | fixed, not changeable |
| I²C0 | 100 kHz | `0x68` | MPU6050 (`AD0`=GND) | `0x69` if AD0 high |
| I²C0 | 100 kHz | `0x76` | BME280 (`SDO`=GND) | `0x77` if SDO high. **BMP280 clones also use 0x76** — check chip ID reads `0x60`, not `0x58` |
| I²C1 (26/27) | 400 kHz | `0x57` | MAX30102 | isolated bus, see §6.4 |

No address collisions. The bus speed is set by the MLX90614's SMBus timing, not
by the fastest device.

### 7.2 Pull-up sizing for I²C0

Four devices, ~25 cm of hookup wire, ~10 pF/device + ~50 pF wiring ≈ **90 pF**
bus capacitance. I²C standard mode requires t<sub>r</sub> ≤ 1000 ns:

```
R_max = t_r / (0.8473 × C_b) = 1000 ns / (0.8473 × 90 pF) ≈ 13.1 kΩ
R_min = (3.3 V − 0.4 V) / 3 mA ≈ 967 Ω
```

**Use 4.7 kΩ** — comfortably inside the window (t<sub>r</sub> ≈ 359 ns) and the
value already fitted to most breakouts.

Critical caveat: **each breakout ships with its own pull-ups**, typically
4.7 kΩ or 10 kΩ. Four boards in parallel at 4.7 kΩ gives **1.175 kΩ** — near the
current limit and hard on the ESP32's open-drain pads. Either:

- **(preferred)** desolder the SDA/SCL pull-ups from **three** of the four
  breakouts and keep one pair, **or**
- fit no external pull-ups at all and accept the parallel combination, having
  first measured it: power the bus, read the voltage across a known 1 kΩ from
  SDA to GND, and confirm the effective pull-up is ≥ 2 kΩ.

Do not add external 4.7 kΩ *on top of* four onboard pairs. That is how a bus
ends up at 940 Ω and works only when it feels like it.

### 7.3 Bus hygiene

- Keep SDA/SCL as a **twisted pair with a ground wire**, not a loose bundle.
- Route them **away from** the ECG analog line (GPIO36) and from the buzzer.
- Total wire length under 30 cm at 100 kHz. Beyond that, add a PCA9615 or
  shorten it.

---

## 8. ECG front end

### 8.1 Electrode placement

Three-lead Einthoven Lead I, which is what the AD8232 breakout's `RA/LA/RL`
mapping expects:

| Cable | Electrode | Body site |
|---|---|---|
| `RA` (red) | right arm | just below the right clavicle, on the muscle, not bone |
| `LA` (yellow) | left arm | just below the left clavicle, mirrored |
| `RL` (green/black) | reference / RLD | lower left ribcage or left hip bone |

For a finger-pad demo (fast, poor quality): `RA` → right index, `LA` → left
index, `RL` → right thumb. Expect quality scores of 40–60; say so on screen
rather than smoothing it.

Skin prep matters more than any firmware change: wipe with alcohol, let it dry,
use **fresh gel** pads. A dry or reused pad is a 10× noise increase.

### 8.2 Sampling

- **250 Hz exactly**, driven by a hardware timer ISR on core 0 — *not* by
  `delay()` in a loop. Jitter directly corrupts R-R intervals, and R-R feeds
  [ecg_classifier.dart](../lib/domain/rules/ecg_classifier.dart)'s
  `irregularityThreshold = 0.12`. 4 ms of jitter on a 800 ms interval is 0.5 % —
  tolerable; 40 ms is not.
- 250 Hz is a Nyquist limit of 125 Hz. Adequate for rate and rhythm
  (AHA minimum for rhythm monitoring is 150 Hz sampling), **not** adequate for
  ST-segment morphology. Never claim diagnostic-grade.
- `analogRead()` on ADC1 with `ADC_ATTEN_DB_11`, 12-bit. Take the ESP32's ADC
  non-linearity seriously: run `esp_adc_cal_characterize()` once at boot and use
  `esp_adc_cal_raw_to_voltage()`, or accept a few percent of amplitude error
  (which is harmless here — we care about timing, not absolute millivolts).

### 8.3 Digital filtering chain (firmware, in this order)

1. **DC baseline removal** — single-pole high-pass, f<sub>c</sub> = 0.5 Hz.
   The AD8232 already does this in analog; a second stage kills residual
   electrode drift.
2. **50 Hz notch** — biquad, Q ≈ 30. **India is 50 Hz mains, not 60.** This is
   the single highest-value filter on the board; without it a mains-coupled
   trace looks like ventricular flutter.
3. **Low-pass** — 40 Hz, 2-pole Butterworth. Removes EMG.
4. **R-peak detection** — Pan-Tompkins-lite: differentiate → square →
   150 ms moving-window integrate → adaptive threshold at 0.6 × running peak,
   with a **200 ms refractory** (physiological maximum ≈ 300 bpm).
5. **Quality score 0–100**, reported in telemetry byte 8:
   - start at 100
   - `LO+` or `LO−` asserted → **0** (and set flags bit 2)
   - subtract from residual 50 Hz power after the notch
   - subtract when the R-peak amplitude/noise-floor ratio < 5
   - subtract when successive R-R differ by > 50 %
   The phone treats < 50 as unusable (`minUsableQuality = 0.5`), so this number
   must be honest. Reporting 80 for a bad trace is worse than reporting 20.

### 8.4 Analog grounding

Wire the AD8232's `GND` to the **regulator's ground terminal directly** with its
own wire — do not daisy-chain it after the OLED and buzzer grounds. Return
current from a 22 mA OLED refresh through a shared ground wire shows up as
millivolts of noise on a signal whose features are millivolts. One wire, one
star point. This costs nothing and is the difference between a clean trace and
an unusable one.

Keep the ECG output wire **short (<10 cm)**, and if you can, run it as a
coax-style pair with a ground wire twisted around it.

---

## 9. PPG / SpO₂ — and an honesty boundary

### 9.1 Configuration (MAX30102 registers)

| Setting | Value | Reason |
|---|---|---|
| Mode | SpO₂ (red + IR) | `0x09` = 0b011 |
| Sample rate | **100 Hz** | matches `ppgSamplingRate = 100` in [app_constants.dart](../lib/core/constants/app_constants.dart) |
| Pulse width | 411 µs (18-bit) | best SNR |
| LED current | 6.4–12.6 mA, **auto-adjusted** | fixed current fails on both very dark and very light skin |
| ADC range | 16384 nA | |
| Sample averaging | 4 | 100 Hz effective output from 400 Hz internal |
| FIFO almost-full | 17 | `INT` on GPIO19 → no polling |

### 9.2 Finger-present gating

Compute **perfusion index** = (AC amplitude / DC level) × 100 on the IR channel.
- PI < 0.2 → no finger, or no perfusion. Set flags **bit 3** and report SpO₂ = 0.
- `0` is the app's "not measured" sentinel and
  [risk_engine.dart](../lib/domain/rules/risk_engine.dart) scores it as an
  *advisory* worth 0 points, not as a critical hypoxia. Emitting a made-up 97 %
  instead is the single worst thing this firmware could do.

### 9.3 The calibration problem — state it, don't hide it

SpO₂ from a reflectance PPG needs an empirical curve:
`R = (AC_red/DC_red) / (AC_ir/DC_ir)`, then `SpO₂ ≈ a − b·R`.

Every commercial pulse oximeter derives `a, b` from a **controlled desaturation
study** on human volunteers breathing hypoxic gas mixtures — which you cannot
and must not do. The literature default `SpO₂ = 110 − 25·R` is accurate to about
**±4 %** on light skin at rest and degrades badly with motion, cold hands, and
darker skin pigmentation (a documented, published bias).

**What to do instead:**
1. Ship `110 − 25R` as the starting curve.
2. Do a **paired comparison** against a ₹1,200 fingertip oximeter over 30
   readings across 5 people, plot yours vs. reference, and fit your own `a, b`
   by least squares. Put the scatter plot and the mean absolute error in your
   presentation. That single slide is worth more than any feature.
3. Report your measured MAE on screen. If it is ±4 %, say ±4 %.
4. Below **SpO₂ 90 %** — exactly where the reading matters most — an uncalibrated
   reflectance sensor is least reliable. Say so in the UI.

A judge who asks "how do you know it's right?" and gets "we compared against a
reference and here is our error" beats one who gets a confident number.

---

## 10. Temperature — the part-number decision (E2)

| Variant | FOV | Accuracy | Spot Ø at 3 cm | ₹ | Verdict |
|---|---|---|---|---|---|
| **MLX90614ESF-BAA** | 90° | ±0.5 °C (±0.2 in 36–38 °C band under lab conditions) | **6 cm** | 460 | On every cheap breakout. Averages forehead + hair + air. Usable as a **trend**, not a fever threshold. |
| **MLX90614ESF-DCI** | **5°** | **±0.2 °C** medical-accuracy | **0.26 cm** | 1,650 | The only variant that supports a fever claim. Buy this one. |

[risk_engine.dart](../lib/domain/rules/risk_engine.dart) awards **+25** for
`tempHigh` and **+30 critical** for `tempLow`. With a ±0.5 °C sensor, a true
37.6 °C can read 38.1 °C and cross a scoring boundary. Either spend the ₹1,190
or widen the firmware's reporting so the phone knows the uncertainty.

### Measurement procedure (either variant)

1. Distance **2–3 cm**, perpendicular to a **dry** forehead (temporal artery
   area, not the centre of the brow).
2. Read `T_ambient` as well as `T_object`. If `|T_obj − T_amb| > 15 °C`, the
   sensor's own thermal gradient adds error — wait 30 s.
3. Emissivity: skin ≈ **0.98**; the MLX ships set to 1.0. Correct in firmware,
   or write 0.98 into EEPROM register `0x24` once.
4. Take **8 readings at 2 Hz, use the median**. Single IR readings are noisy.
5. Skin temperature is **~0.5–1.0 °C below core**. Do not silently add an
   offset to fake a core reading — report skin temperature and let the app label
   it as such.
6. Ambient sanity gate: below 16 °C ambient, forehead skin temperature
   diverges from core so far that the reading is meaningless. Report `0`
   (not-measured) rather than a number.

Telemetry encodes this as `int16` hundredths of a °C (36.50 °C → `3650`), and
`ble_protocol.dart` rejects anything outside **20.0–45.0 °C**.

---

## 11. Environmental sensing

### 11.1 BME280

I²C0 `0x76`. Gives ambient temperature ±1 °C, humidity ±3 % RH, pressure
±1 hPa. Mount it **outside the enclosure airflow path of the ESP32** — the
module self-heats 3–5 °C and will read the enclosure, not the air. A vent slot
and 2 cm of standoff is enough.

Verify the chip ID at register `0xD0`: **`0x60` = BME280** (has humidity),
`0x58` = BMP280 (pressure only, no humidity — a very common substitution on
Indian marketplaces). Without humidity there is no heat index.

### 11.2 Heat index — fix the app bug while you are here

[environmental_rules.dart:144-146](../lib/domain/rules/environmental_rules.dart)
has both the `≥ heatDangerC (43)` and `≥ heatWarningC (38)` branches returning
`AdvisoryLevel.warning`, and `_heatAdvisory` maps `warning` to a single card
`'heat_danger'`. **46 °C and 38 °C render identically.** The danger tier is dead
code. This is worth fixing regardless of hardware, because heat is the flagship
hazard in PS 26181.

Compute on-device, from measured T and RH:

- **Heat Index** (Rothfusz, valid ≥ 26.7 °C):
  `HI = -8.78469476 + 1.61139411·T + 2.33854884·R − 0.14611605·T·R − 0.012308094·T² − 0.016424828·R² + 0.002211732·T²·R + 0.00072546·T·R² − 0.000003582·T²·R²` (T in °C, R in %)
- **Humidex** (simpler, Canadian):
  `H = T + 0.5555 × (6.11 × e^(5417.753 × (1/273.16 − 1/T_dew)) − 10)`

### 11.3 WBGT — the differentiator worth ₹250

Every weather app reports temperature. **Nobody reports WBGT**, and WBGT is
what Indian labour law, sports medicine and the NDMA heat-action plans actually
use, because it includes **radiant load** — standing in the sun versus in shade
at the same air temperature.

`WBGT_outdoor = 0.7·T_wet + 0.2·T_globe + 0.1·T_dry`

Build the globe sensor for ₹250:
1. A 25 mm hollow copper ball (plumbing supply), painted **matte black**.
2. A 10 kΩ NTC thermistor epoxied at its centre, wired to **GPIO32… no** — GPIO32
   is the wake button. Use a spare **ADC1** pin: move the thermistor to
   **GPIO37 or GPIO38** if your DevKit breaks them out; on the common 30-pin
   DevKit it does not, so use **GPIO34** and move `ECG_LO_N` to GPIO38, or
   accept the two-pin-shortage and drop the OLED's I²C in favour of an
   ADS1115 external ADC on I²C0 (`0x48`) for both the globe and the wet bulb.
   The ADS1115 route is cleaner and costs ₹180.
3. `T_wet` from a second thermistor with a wetted cotton wick, or estimate it
   from BME280 T + RH via Stull's approximation (accurate to ±0.3 °C for
   RH > 20 %).

Being the only team at the hackathon that measures WBGT rather than reading it
off an API is a real, defensible claim about outdoor worker safety.

### 11.4 PMS5003 (optional, ₹1,450)

UART2, 9600 8N1, GPIO16 RX / GPIO17 TX. Emits a 32-byte frame every ~1 s
starting `0x42 0x4D`; verify the checksum (sum of the first 30 bytes).

Two things matter:
- It needs **5 V** and draws **~100 mA** with the fan running. Tap it before the
  3.3 V regulator, from the boost output or the USB rail — never from 3V3.
- Duty-cycle it: `SET` pin low to sleep, wake for 30 s before each reading
  (the fan needs ~30 s to stabilise). Continuous operation costs you ~11 h of
  battery life and wears the fan out.

A measured local PM2.5 beats an interpolated Open-Meteo grid value by a wide
margin in a city where the nearest CPCB station is 8 km away — and
[environment_service.dart](../lib/core/services/environment_service.dart)
currently has no measured source at all.

---

## 12. Battery monitoring

```
  BAT+ ──┬── 100 kΩ ──┬── 100 kΩ ── GND
         │            │
      (to reg)     GPIO35 ──┬── 100 nF ── GND
                            └── (ADC1_CH7)
```

- Divider ratio 0.5: **4.2 V → 2.10 V**, **3.0 V → 1.50 V**. Both sit in the
  ESP32 ADC's well-behaved region with 11 dB attenuation. Do not use a 10 k/10 k
  divider — 165 µA of constant drain flattens the cell in storage; 100 k/100 k
  draws 21 µA.
- The 100 nF is required: the ADC's sampling capacitor causes a measurable
  kickback on a high-impedance source.
- Sample **64 times and average**, and only when the radio is idle. The ESP32's
  ADC noise floor is roughly ±20 mV; a single read will make your battery
  percentage flicker.
- Convert with a **Li-ion discharge curve**, not a linear map. A linear
  4.2→3.0 V map reports 50 % when the cell is actually at 75 %. Use a lookup
  table:

  | V | % | | V | % |
  |---|---|---|---|---|
  | 4.20 | 100 | | 3.70 | 40 |
  | 4.10 | 90 | | 3.65 | 30 |
  | 4.00 | 80 | | 3.60 | 20 |
  | 3.90 | 65 | | 3.50 | 10 |
  | 3.80 | 55 | | 3.30 | 5 |
  | 3.75 | 45 | | 3.00 | 0 |

  Interpolate linearly between rows, and read only under a steady load
  (voltage sags ~80 mV during a BLE burst — sample between them).

Telemetry byte 14 carries the percentage, 0–100.

---

## 13. Charging, protection and the electrode interlock

### 13.1 Charge circuit

`TP4056 + DW01A` module, micro-USB in:

| TP4056 pad | To |
|---|---|
| `IN+` / `IN−` | micro-USB (on-module) |
| `B+` / `B−` | 18650 holder + / − |
| `OUT+` / `OUT−` | regulator input (only if the module has load-sharing; see below) |
| `CHRG` | GPIO4 (open-drain, LOW while charging) |
| `STDBY` | optional status LED |

Set the charge current with `R_prog`: the stock 1.2 kΩ gives **1 A**, which is
0.33 C on a 3000 mAh cell — correct. Do not fit a smaller resistor.

**Load sharing:** the bare TP4056 does *not* isolate the load during charge. If
you power the board from `B+` while charging, the charger cannot terminate
properly and the cell can be over-charged. Either buy the variant with
load-sharing (a P-FET and a Schottky, marked "with protection + load sharing"),
or **enforce a firmware rule: no measurement while `CHG_STAT` is LOW.**

### 13.2 The safety interlock — the most important paragraph here

**Never take an ECG while the board is plugged into a USB charger.**

With USB connected, the patient's chest electrodes share a ground reference with
mains earth through the charger. A cheap unisolated phone charger can leak
hundreds of microamps to earth. That current path runs through the patient.
Medical devices solve this with an isolation barrier (ISO7841, ADuM, or a
transformer-isolated supply); you are not building one.

Firmware **must**:

```c
if (digitalRead(CHG_STAT) == LOW) {       // charger present
    digitalWrite(ECG_SDN, LOW);           // AD8232 hard off
    ecg_streaming_enabled = false;
    oled_banner("UNPLUG CHARGER TO MEASURE");
    // telemetry byte 8 (quality) = 0, flags bit 2 (lead off) set
}
```

Put a printed label on the enclosure saying the same thing. In a demo, be the
team that unplugs the charger before touching the electrodes and *says why* — it
is the single clearest signal that you understand what you built.

### 13.3 The rest of the safety rules

- **Battery only** during any measurement on a person.
- **Never mains-powered** from an unisolated supply while electrodes are on skin.
- Total leakage to the subject must stay under **10 µA** (IEC 60601-1 for
  type CF applied parts). Battery operation with no earth reference is what
  gets you there; you cannot measure this without an electrical safety analyser,
  so rely on isolation by construction and say that is what you did.
- **Ag/AgCl disposable electrodes only.** Never bare copper, never reused pads.
  One pad, one person, one session.
- 18650 handling: **protected cells only**, correct polarity (reversed = fire),
  never charge a cell that is swollen, dented, or has been below 2.5 V. Charge
  on a hard non-flammable surface for the first few cycles.
- Add a **1.5 A polyfuse** in series with `B+`. ₹15, and it is the difference
  between a mistake and a fire.
- **This is not a medical device.** No CDSCO registration, no IEC 60601
  certification, no clinical validation. Every screen and this document must say
  screening, not diagnosis — which the app already does correctly.

---

## 14. BLE protocol — implementation spec

Transcribed from [ble_protocol.dart](../lib/core/services/ble_protocol.dart) and
[app_constants.dart](../lib/core/constants/app_constants.dart). **The firmware
must match this exactly**; the app validates lengths and version and drops
malformed frames silently.

### 14.1 GATT table

Nordic-UART-style custom base: `6e4000XX-b5a3-f393-e0a9-e50e24dcca9e`

| Handle | UUID suffix | Properties | Payload |
|---|---|---|---|
| Service | `…0001` | — | primary service, **must be in the advertisement** |
| Device info | `…0002` | Read | UTF-8 firmware version, e.g. `"1.0.0"`, parsed by `parseFirmwareVersion` with regex `(\d+)\.(\d+)(?:\.(\d+))?` |
| Live vitals | `…0003` | **Notify** | 20-byte telemetry frame (§14.2) |
| ECG stream | `…0004` | **Notify** | 4-byte header + int16 samples (§14.3) |
| Control | `…0005` | Write | `0xA1` = start stream, `0xA0` = stop stream |
| Status | `…0006` | Read / Notify | reserved |

### 14.2 Telemetry frame — exactly 20 bytes, little-endian

```
 offset  type     field                          notes
 ------  -------  -----------------------------  -----------------------------------
   0     uint8    frame type                     must be 0x01
   1     uint8    protocol version               must be 1 (app min=max=1)
   2     uint8    heart rate, bpm                plausible 25–250, else dropped
   3     uint8    SpO2, percent                  plausible 50–100; 0 = not measured
   4..5  int16    temperature, hundredths °C     3650 == 36.50 °C; range 2000–4500
   6..7  uint16   last R-R interval, ms
   8     uint8    ECG signal quality             0..100  (<50 → app calls it NOISY)
   9     uint8    flags                          bit0 R-peak this frame
                                                 bit1 fall detected
                                                 bit2 ECG lead off
                                                 bit3 finger off (PPG)
  10..11 uint16   pulse transit time, ms
  12     uint8    estimated systolic, mmHg
  13     uint8    estimated diastolic, mmHg
  14     uint8    battery, percent
  15     uint8    BP confidence                  0=LOW 1=MEDIUM 2=HIGH
                                                 anything else → 'EXPERIMENTAL'
  16..19 uint32   device uptime, ms
```

Notify at **4 Hz**. Any frame whose length ≠ 20, whose type ≠ `0x01`, or whose
version ≠ 1 is discarded by the app without a user-visible error, so a length
bug looks exactly like a dead sensor. Assert `sizeof(telemetry_t) == 20` at
compile time and pack the struct (`__attribute__((packed))`).

**Byte 15 is a safety valve.** Write **any value ≥ 3** (use `0xFF`) and
[risk_engine.dart](../lib/domain/rules/risk_engine.dart)'s
`_evaluateBloodPressure` returns early — the cuffless BP estimate contributes
**zero** to the risk score. Ship it that way. See §15.

### 14.3 ECG frame

```
 offset  type       field
 ------  ---------  -------------------------------------------
   0     uint8      frame type == 0x02
   1     uint8      protocol version == 1
   2..3  uint16     sequence number, wraps at 65535
   4..   int16[]    samples, little-endian; payload length must be EVEN
```

**Hard constraint — 8 samples per frame, no more.**
[ble_service.dart](../lib/core/services/ble_service.dart) never calls
`requestMtu()`, so the negotiated ATT MTU stays at the BLE default of **23
bytes**, giving **20 bytes of notification payload**. Therefore:

```
20 bytes − 4 header = 16 bytes = 8 × int16 samples
250 Hz ÷ 8 samples = 31.25 notifications per second
```

At a 15 ms connection interval with 4 packets per event you have ~266 notify
slots/s — 31.25/s is comfortable. Send 9 samples and every ECG frame is
silently dropped.

The app checks continuity with `isContiguous(prev, next) => next == (prev+1) & 0xFFFF`
and flags gaps, so **increment the sequence number on every frame, including
dropped ones**, and let the phone show the gap honestly.

*Optimisation available later:* if you add `requestMtu(247)` on the app side you
can carry 121 samples/frame and drop to 2 notifies/s, cutting radio power
substantially. Do not do it unilaterally in firmware — the app must request it,
and the current build does not.

### 14.4 Advertising

`ble_service.dart:480-482` accepts a device when the lowercased name starts with
`swasthyasetu`, `ssai`, or `ss-`, **or** when the service UUID `…0001` is in the
advertisement. It reads `advertisementData.advName` first, then `platformName`.

Advertise as **`SSAI-SENSE-01`** *and* include the service UUID — two
independent ways to be found. Do not prefix the name with `DEMO_`; that prefix
(`demoModePrefix`) is reserved for the app's synthetic device and will make your
real hardware's data get tagged `isDemo`, which propagates into the stored
record and marks a genuine screening as fake.

Interval 100 ms while unconnected. Once connected, request a connection interval
of 15–30 ms so 31.25 notifies/s fit.

### 14.5 Reconnection

The app's `BleBackoff` retries at **1, 2, 4, 8, 16, 30 s** (base 1 s, cap 30 s,
6 attempts). Firmware should therefore keep advertising indefinitely after a
disconnect and never require a power cycle to be re-found.

---

## 15. Cuffless blood pressure — keep it experimental

PTT (pulse transit time) between the ECG R-peak and the PPG foot correlates with
blood pressure, and you can compute it here because both signals are on the same
clock:

```
PTT = t(PPG foot) − t(ECG R-peak)      [ms, byte 10..11]
SBP ≈ a − b·ln(PTT)      per-subject a, b from a calibration against a real cuff
```

The honest position: **PTT-based BP requires per-subject calibration against a
validated cuff, drifts within hours, and is invalid during motion.** No
regulator anywhere has cleared a cuffless PTT device for unsupervised use.

So:
- **Compute and transmit PTT** in bytes 10–11 — it is a real, interesting,
  correctly-measured number.
- Transmit systolic/diastolic estimates in bytes 12–13 only if you have
  calibrated against a cuff for that specific person.
- Set byte 15 to **`0xFF`** so the label reads `EXPERIMENTAL` and the risk
  engine skips it entirely.
- On screen: "Experimental — not a blood pressure measurement."

This is a feature, not a limitation. Show the judges you measured something
genuinely hard, and that you know exactly why you are not allowed to act on it.
Teams that quietly report a fabricated 120/80 lose credibility the moment
someone asks how it was validated.

---

## 16. Assembly order

Build in this sequence. Each checkpoint must pass before you solder the next
stage — debugging a fully assembled board is an order of magnitude harder.

| # | Step | Checkpoint |
|---|---|---|
| 1 | **Power stage alone.** TP4056 + cell + regulator. No ESP32 yet. | Multimeter reads **3.30 V ±0.05 V** at the output, with the cell at 4.1 V *and* again at 3.4 V (run it down or use a bench supply). If it sags, stop — you have the E1 problem. |
| 2 | Add the 100 µF + 100 nF at the future ESP32 position. | Still 3.30 V. |
| 3 | **ESP32 only.** Blink GPIO2. | Blinks; USB serial shows the boot log at 115200 with no `Brownout detector was triggered`. |
| 4 | **I²C0 bus + OLED only.** | `i2c_scanner` finds exactly `0x3C`. |
| 5 | Add MLX90614. | Scanner finds `0x3C`, `0x5A`. Ambient reads within 2 °C of a room thermometer. |
| 6 | Add MPU6050 (+ `INT` wire). | Scanner adds `0x68`. Accel magnitude ≈ 9.8 m/s² at rest; ≈ 0 when you drop the board 20 cm onto a cushion. |
| 7 | Add BME280. | Scanner adds `0x76`. Chip ID at `0xD0` reads **`0x60`** (not `0x58`). |
| 8 | **Re-measure the bus pull-up** (§7.2) now that four boards are on it. | Effective pull-up ≥ 2 kΩ. Desolder onboard resistors if not. |
| 9 | **I²C1 + MAX30102.** | Second scanner on `Wire1` finds `0x57`. Raw IR count jumps > 50 000 when a finger covers it. |
| 10 | **AD8232**, `SDN` held HIGH, no electrodes. | `LO+` and `LO−` both read **HIGH** (leads off). `OUTPUT` sits near mid-rail (~1.5 V, ADC ≈ 1800–2000). |
| 11 | Attach electrodes to a person. | `LO+`/`LO−` go **LOW**. Raw ADC swings visibly with each heartbeat. |
| 12 | Buzzer, buttons, battery divider. | Tone at 2 kHz. SW1 pressed reads **HIGH** (not low — §6.7). GPIO35 raw ≈ 2200 at 4.1 V cell. |
| 13 | **BLE**: advertise, connect from the app, stream telemetry. | App's device scan lists `SSAI-SENSE-01`; live vitals screen shows moving numbers. |
| 14 | ECG stream at 8 samples/frame. | ECG live screen draws a continuous trace with **no gap warnings**. |
| 15 | Deep sleep + `ext1` wake. | Current drops to < 100 µA (measure with a µA-capable meter in series, or a Nordic PPK). Drop test wakes it; button wakes it. |

### Firmware bring-up self-test

Run at every boot, print to serial and show a pass/fail grid on the OLED:

1. I²C0 scan == {`0x3C`, `0x5A`, `0x68`, `0x76`}
2. I²C1 scan == {`0x57`}
3. MAX30102 part ID (reg `0xFF`) == `0x15`
4. MPU6050 `WHO_AM_I` (reg `0x75`) == `0x68`
5. BME280 chip ID (reg `0xD0`) == `0x60`
6. MLX90614 ambient within 0–50 °C
7. AD8232 `OUTPUT` ADC within 1200–2800 with `SDN` HIGH and leads off
8. `LO+` and `LO−` both HIGH with no electrodes attached
9. Battery ADC implies 3.0–4.3 V
10. `sizeof(telemetry_frame_t) == 20` — a **static assert**, checked at compile time
11. ECG timer ISR fired 250 ±2 times in the first second

Test 10 catches the single most likely integration bug on the whole board:
a struct the compiler padded to 24 bytes, producing frames the app throws away
without a word.

---

## 17. Firmware architecture

### 17.1 Task layout (ESP-IDF / Arduino-ESP32 with FreeRTOS)

| Core | Task | Priority | Period | Job |
|---|---|---|---|---|
| 0 | `ecg_isr` (hardware timer) | ISR | **4 ms** | one `adc1_get_raw()` → ring buffer. Nothing else. |
| 0 | `ecg_dsp` | 5 | 32 ms | filter chain, R-peak detect, quality score, fill 8-sample frames |
| 0 | `ppg_task` | 4 | on `INT` | drain MAX30102 FIFO, SpO₂ ratio, perfusion index |
| 0 | `imu_task` | 6 | 10 ms when armed | fall state machine (§17.2) |
| 1 | `ble_notify` | 3 | 32 ms / 250 ms | push ECG frames (31.25 Hz) and telemetry (4 Hz) |
| 1 | `slow_task` | 2 | 1 s | MLX90614, BME280, battery, OLED, charger interlock |

Pinning DSP to core 0 and the radio to core 1 is what keeps the 250 Hz ISR from
jittering when the BLE stack does its work. Do not put both on core 0.

### 17.2 Fall detection — must match the phone's tested thresholds

The app's [fall_detection_service.dart](../lib/core/services/fall_detection_service.dart)
already implements and unit-tests a three-phase state machine. **Port these exact
constants** so the board and the phone agree and so the existing tests document
the firmware too:

| Constant | App value | ±8 g raw LSB (4096 LSB/g) |
|---|---|---|
| `freeFallThreshold` | 4.0 m/s² (0.408 g) | **1671** |
| `impactThreshold` | 26.0 m/s² (2.651 g) | **10859** |
| `minFreeFallDuration` | 80 ms | 8 samples @ 100 Hz |
| `impactWindow` | 1200 ms | — |
| `refractoryPeriod` | 20 s | — |

State machine: `idle` → (|a| < 4.0 for ≥ 80 ms) → `freeFall` → (|a| back above
4.0) → `awaitingImpact` → (|a| ≥ 26.0 within 1200 ms) → **FALL**, then 20 s
refractory. A bare impact spike with no preceding free fall is **not** a fall —
that is what stops "phone set down hard" firing an SOS several times an hour.

Set `AFS_SEL = 2` (**±8 g**). At ±4 g a 2.65 g impact is only 1.35 g from
clipping and real falls exceed it.

On detection: set telemetry **flags bit 1**, sound the buzzer, and hold the flag
set for 30 s so a 4 Hz-polling phone cannot miss it.

Add a post-impact **stillness check** as a firmware-only refinement: if |a|
stays within 1 g ± 0.3 g and low-variance for 2 s after the impact, raise
confidence; if the person picks the device straight back up, they are probably
fine. Report it as a separate confidence bit if you extend the protocol — do not
repurpose an existing flag bit, because the app parses fixed offsets.

### 17.3 Deep sleep

```c
// Arm before sleeping
mpu6050_set_motion_interrupt(MOT_THR, MOT_DUR);  // active HIGH, push-pull
mpu6050_enter_cycle_mode(LP_WAKE_CTRL_20HZ);     // accel-only, ~10 µA
digitalWrite(ECG_SDN, LOW);                       // AD8232 off
max30102_shutdown();                              // 0.7 µA
ssd1306_display_off();

esp_sleep_enable_ext1_wakeup(
    (1ULL << GPIO_NUM_33) | (1ULL << GPIO_NUM_32),   // IMU INT, button
    ESP_EXT1_WAKEUP_ANY_HIGH);                       // both active-high (§4)
esp_sleep_enable_timer_wakeup(15 * 60 * 1000000ULL); // 15-min heartbeat
esp_deep_sleep_start();
```

On wake: read `esp_sleep_get_ext1_wakeup_status()` to learn *which* pin fired,
sample the accelerometer at 100 Hz for 3 s, run the §17.2 state machine, and go
back to sleep if it was a false alarm. The MPU6050's built-in free-fall
interrupt is famously unreliable — use its **motion** interrupt purely as a
wake trigger and do the actual classification on the ESP32. That is the design
decision that makes 25 µA and real fall detection coexist.

### 17.4 PlatformIO configuration

`firmware/platformio.ini` (this directory does not exist yet — creating it also
fixes the red **Check Firmware (PlatformIO)** CI job):

```ini
[env:esp32dev]
platform = espressif32@6.5.0
board = esp32dev
framework = arduino
monitor_speed = 115200
upload_speed = 921600

build_flags =
    -DCORE_DEBUG_LEVEL=3
    -DPROTOCOL_VERSION=1
    -DFIRMWARE_VERSION=\"1.0.0\"

lib_deps =
    sparkfun/SparkFun MAX3010x Pulse and Proximity Sensor Library@^1.1.2
    adafruit/Adafruit MLX90614 Library@^2.1.5
    adafruit/Adafruit MPU6050@^2.2.6
    adafruit/Adafruit BME280 Library@^2.2.4
    adafruit/Adafruit SSD1306@^2.5.9
    h2zero/NimBLE-Arduino@^1.4.1
```

Use **NimBLE**, not the bundled Bluedroid stack: it saves roughly 100 kB of
flash and noticeably less RAM, which matters once the ECG ring buffers are in.

### 17.5 Suggested source layout

```
firmware/
├── platformio.ini
├── include/
│   ├── ble_protocol.h      ← the packed structs + static_assert(sizeof == 20)
│   ├── pins.h              ← §6.1 as #defines, single source of truth
│   └── config.h
└── src/
    ├── main.cpp
    ├── ecg.cpp             ← ISR, filter chain, R-peak, quality
    ├── ppg.cpp             ← MAX30102, SpO2, perfusion index
    ├── imu.cpp             ← fall state machine (mirrors the Dart one)
    ├── env.cpp             ← MLX90614, BME280, heat index, WBGT
    ├── power.cpp           ← battery curve, charger interlock, deep sleep
    ├── ble_server.cpp      ← NimBLE GATT, notify scheduling
    └── display.cpp
```

Keep `ble_protocol.h` a mechanical transcription of the Dart file and add a
comment in both pointing at the other. Two files, one wire format, and a
compile-time assert on the size.

---

## 18. Validation and calibration protocol

Do these before the hackathon and put the numbers on a slide. Measured error
beats claimed accuracy every time.

| Measurement | Reference | Protocol | Accept |
|---|---|---|---|
| **Heart rate** | ₹1,200 fingertip pulse oximeter | 20 paired readings, 5 subjects, seated at rest | MAE < 3 bpm; Bland–Altman limits within ±5 bpm |
| **SpO₂** | same oximeter | 30 paired readings, 5 subjects, include one cold-hand and one darker-skin subject | report your **measured** MAE; fit your own `a, b` (§9.3) |
| **Skin temperature** | clinical digital thermometer (axillary) + room thermometer | 20 readings; log ambient each time | BAA: ±0.5 °C. DCI: ±0.2 °C |
| **ECG rate** | manual R-peak count on a 30 s printed strip | 5 strips | R-peak detector within 1 beat of manual count |
| **ECG timing** | function generator, 1 Hz square wave into `RA/LA` (through a 1 MΩ + 100 kΩ divider — **never** connect a generator to a person's electrodes) | measure detected R-R | 1000 ms ±5 ms |
| **Fall detection** | drop the device from 1.2 m onto a cushion, 20 trials; then 50 "activities of daily living" (sitting fast, stairs, pocket transfer, setting it on a table) | count both | sensitivity ≥ 90 % on drops; **false positives ≤ 2 per 50 ADLs** — this second number is the one that decides whether anyone keeps the feature on |
| **Battery runtime** | log uptime + battery% every minute to serial until shutdown | one full discharge, streaming mode | within 20 % of the §5.2 prediction |
| **Deep-sleep current** | µA meter in series with `B+`, or a Nordic PPK II | 5-minute average | < 100 µA |
| **BLE frame integrity** | app's ECG gap counter over 10 min | continuous stream | < 0.1 % dropped frames |

Two things to bring to the table, physically: the **Bland–Altman plot** for HR
and SpO₂, and the **false-positive count** for fall detection. Those two artefacts
are what separate a project from a prototype.

---

## 19. Troubleshooting

| Symptom | Most likely cause | Check |
|---|---|---|
| ESP32 reboots on BLE connect | Missing bulk capacitor; regulator cannot supply the 240 mA transient | Add 100 µF + 100 nF at 3V3 (§5.6). Look for `Brownout detector was triggered` in the serial log. |
| Board dies when the cell drops below ~3.6 V | **E1** — an LDO is in the power path | Replace with buck-boost or boost (§5.3/§5.4) |
| I²C scan finds nothing | SDA/SCL swapped, or no pull-ups at all | Measure 3.3 V on both lines idle; swap and retry |
| I²C scan is intermittent, devices come and go | Parallel pull-ups too strong, or MAX30102 on the shared bus (**E5**) | §7.2 measurement; move MAX30102 to `Wire1` |
| BME280 has no humidity | It is a BMP280 clone | Read reg `0xD0`; `0x58` = BMP280, demand a refund |
| ECG trace is a clean 50 Hz sine | Mains coupling, no notch filter | Implement §8.3 step 2; check `RL` electrode is actually attached |
| ECG baseline wanders off-screen | Dry or reused electrode; cable tugging | Fresh gel pad, secure the cable with tape, verify the 0.5 Hz high-pass |
| ECG noisy only when the OLED refreshes | Shared ground return | Star-ground the AD8232 (§8.4) |
| `LO+`/`LO−` always HIGH | Electrode not making contact, or `SDN` is LOW | Confirm GPIO18 is driven HIGH; check pad gel |
| SpO₂ reads 99 % always | Perfusion-index gate missing — you are reading the DC level | Implement §9.2; verify AC amplitude > 0 |
| SpO₂ wildly wrong on one person | Uncalibrated curve + skin-tone bias | §9.3; report the error honestly |
| Temperature reads 5 °C low | Distance too great, or 90° FOV averaging in cool air | 2–3 cm, perpendicular; set emissivity 0.98 |
| App never lists the device | Name doesn't match the filter, or service UUID absent from the advertisement | Advertise `SSAI-SENSE-01` **and** the `…0001` UUID (§14.4) |
| Telemetry arrives but nothing renders | Frame is not exactly 20 bytes (struct padding) or version ≠ 1 | `static_assert(sizeof(telemetry_frame_t) == 20)` |
| ECG stream connects but draws nothing | > 8 samples per frame — payload exceeds the 20-byte MTU limit | §14.3 |
| ECG shows constant gap warnings | Sequence number not incrementing, or notify queue overflowing | Increment on every frame; check the connection interval is ≤ 30 ms |
| Deep sleep draws 5 mA | A sensor was not shut down, or the OLED is still on | §17.3; the AD8232 `SDN` and MAX30102 shutdown are the usual culprits |
| Won't wake on a fall | Wired the button to GND, so `ext1 ANY_HIGH` never triggers | §6.7 — button goes to **3V3** with a pull-down |
| Random resets when flashing | GPIO12 pulled high by your wiring | Never use GPIO12 (§4) |

---

## 20. Enclosure

Two-part build, because the ECG cable and the fingertip sensor want to be in
different places:

**Main unit** (chest, on a strap): 85 × 55 × 25 mm. Contents: ESP32, AD8232,
MPU6050, battery, charger, regulator, OLED window, two buttons, buzzer grille.
Cutouts: micro-USB, 3.5 mm ECG jack, OLED window, vent slots over the BME280
(kept 2 cm from the ESP32 to avoid self-heating).

**Fingertip clip** (tethered, 40 cm of 4-core cable): MAX30102 facing the pad,
with an opaque shroud. Ambient light leaking onto the photodiode is the number
one cause of a bad PPG — a matte-black shroud is worth more than any filter.

The MLX90614 needs a clear line of sight with **no window** — glass and acrylic
are opaque to 5–14 µm IR. Leave an open port, or use a proper IR-transparent
window (Si or Ge, expensive). An open 8 mm hole is the practical answer.

Print in **PETG**, not PLA: a device worn against a body in an Indian summer
sees 45 °C ambient plus body heat, and PLA softens around 60 °C.

For the hackathon itself, a laser-cut acrylic sandwich with standoffs is faster,
looks deliberate, and lets judges see the sensors — which is an advantage, not a
compromise.

---

## 21. Honest known limitations

State these before anyone asks. Every one of them is a design boundary you chose
knowingly, and saying so is what makes the rest of your claims credible.

1. **Not a medical device.** No CDSCO registration, no IEC 60601 certification,
   no clinical validation, no ethics approval. Screening only.
2. **ECG is single-lead, 250 Hz.** Adequate for rate and rhythm regularity.
   Cannot assess ST segments, cannot detect ischaemia, cannot substitute for a
   12-lead. The classifier says `SINUS_RHYTHM` / `IRREGULAR` / `NOISY`, never a
   diagnosis.
3. **SpO₂ is uncalibrated** unless you do §9.3, and is least reliable below
   90 % — precisely where it matters. Known skin-pigmentation bias.
4. **Temperature is skin, not core**, and ±0.5 °C on the BAA part. Ambient
   below 16 °C makes it meaningless.
5. **BP is experimental and contributes nothing to triage.** By design (§15).
6. **No galvanic isolation.** Battery-only operation during measurement is the
   entire safety argument. Charging and measuring are mutually exclusive, and
   firmware enforces it (§13.2).
7. **Fall detection has false positives.** Measure the rate (§18) and show it.
   A detector nobody leaves switched on has 0 % sensitivity in the field.
8. **BLE range ~10 m** line-of-sight, less through a body. The board is a
   companion to a phone in the same room or pocket, not a telemetry base
   station.
9. **No on-board data retention** without the optional SD module — if the phone
   is out of range, those samples are gone.
10. **Consumer breakouts, not qualified components.** No temperature
    compensation across the range, no traceable calibration, batch-to-batch
    variation. Two builds will not read identically; measure both.

---

## 22. What to do next, in order

1. **Order the core BOM** (§3.1), plus spares of the four cheap boards. ₹6,200
   total gets you a build and a backup.
2. **Build the power stage first and verify it at 3.4 V cell voltage** (§16
   step 1). This is where Revision 1 failed, and no amount of firmware fixes it.
3. **Create `firmware/platformio.ini`** (§17.4). It also turns the red
   *Check Firmware (PlatformIO)* CI job green, which currently fails because the
   directory does not exist.
4. **Transcribe `ble_protocol.h` from the Dart file** and add the
   `static_assert`. Do this before writing any sensor code — it is the interface
   everything else has to satisfy.
5. **Bring up in the §16 order**, running the self-test at every step.
6. **Run the §18 validation** and produce the two artefacts: the Bland–Altman
   plot and the fall-detection false-positive count.
7. **Fix the heat-danger tier** in
   [environmental_rules.dart:144](../lib/domain/rules/environmental_rules.dart) —
   the flagship hazard in PS 26181 currently has a dead severity level.
8. **Decide on the DCI temperature sensor and the PMS5003.** Together they are
   ₹3,100 and they are what let you say "we measure it" instead of "we look it
   up" — in a Qualcomm *hardware*-category problem statement, that distinction
   is the whole point.

---

*Revision 2.0 — supersedes Revision 1 entirely. Netlist in §6 and BLE spec in
§14 are authoritative. Report measured numbers, never claimed ones.*
