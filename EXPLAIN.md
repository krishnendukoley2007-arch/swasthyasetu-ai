# SwasthyaSetu AI — How It All Works

**A complete explanation of the system, written for everyone.**
If you are a judge, a teacher, a teammate, or just curious — start here.
No engineering background needed. Where a technical fact matters, we show the
real numbers, because the real numbers are what make this project honest.

---

## Table of Contents

1. [The 30-second version](#1-the-30-second-version)
2. [The big picture — one diagram of everything](#2-the-big-picture)
3. [Meet the hardware — what each part does](#3-meet-the-hardware)
4. [The journey of one heartbeat](#4-the-journey-of-one-heartbeat)
5. [Two languages of Bluetooth — the mistake we fixed](#5-two-languages-of-bluetooth)
6. [The BLE protocol — how phone and board talk](#6-the-ble-protocol)
7. [Inside the ESP32 firmware](#7-inside-the-esp32-firmware)
8. [Inside the phone app](#8-inside-the-phone-app)
9. [Why these exact pins](#9-why-these-exact-pins)
10. [Safety rules baked into the design](#10-safety-rules)
11. [What is real today vs. what is a placeholder](#11-real-vs-placeholder)
12. [The three app bugs we found and fixed](#12-the-three-app-bugs)
13. [What comes next](#13-what-comes-next)
14. [Glossary — every technical word, explained](#14-glossary)

---

## 1. The 30-second version

We built a **small electronic board** that sticks to a person's chest and
**measures their real heartbeat** (ECG). The board sends the heartbeat
**wirelessly to a normal Android phone**. The phone shows the ECG waveform,
the heart rate, and health advisories in the local language — and can raise
an SOS in an emergency.

The point of the project: **village health workers** (and families) get
hospital-style vital-sign screening with equipment that fits in a pocket,
works **offline** where there is no internet, and costs under ₹6,000.

The phone app is called **SwasthyaSetu AI**. The board is called
**SSAI-SENSE-01**.

---

## 2. The big picture

```
        THE BODY                THE BOARD                 THE PHONE
   ┌──────────────┐     ┌────────────────────┐     ┌───────────────────┐
   │              │     │                    │     │                   │
   │   Heart      │     │  AD8232   ESP32    │     │  SwasthyaSetu AI  │
   │  (electric   │────▶│  chip  ─▶ brain    │════▶│  Flutter app      │
   │   signal,    │wire │                    │BLE  │                   │
   │   ~1 mV)     │     │   OLED   Touch  LED│     │  screen · alerts  │
   │              │     │    show  press stat│     │  risk · SOS · AI  │
   └──────────────┘     └────────────────────┘     └───────────────────┘
        sensors            measure & send            understand & help
```

Three worlds, three jobs:

| World | Piece | Its only job |
|---|---|---|
| Body | Electrodes + AD8232 | Turn a tiny skin voltage into a clean signal |
| Board | ESP32 firmware | Measure 250 times/second, pack into bytes, broadcast |
| Phone | Flutter app | Catch the bytes, check they make sense, draw them, act on them |

Every part was chosen so that a failure anywhere is **visible**, not silent.
That theme — *honest about what we know and don't know* — runs through the
whole project, and you will see it again and again below.

---

## 3. Meet the hardware

### 3.1 ESP32 DevKit V1 — the brain
A small ₹380 computer-on-a-chip. It has a processor, memory, a radio
(Bluetooth + WiFi), and about 30 metal legs called **GPIO pins** that we
wire to sensors. It runs one program (called **firmware**) that we wrote
and uploaded with the Arduino IDE.

### 3.2 AD8232 — the heart-signal chip
A single-lead ECG front-end module (₹750). The heart's electrical signal on
the skin is about **1 millivolt** — a thousand times smaller than a AA
battery. The AD8232 amplifies it ~100×, filters out noise, and outputs a
clean wave between 0 and 3.3 V that the ESP32 can read. It also has two
"lead-off" outputs that say *"an electrode fell off"* — so the system can
never show you a dead flat line and pretend it is a heartbeat.

> **Safety note (hardware rule, copied from our hardware doc): never run an
> ECG while the board is plugged into a charger.** On battery power there is
> no electrical path to the mains at all. In demos we unplug first — and say
> why.

### 3.3 OLED display — the board's face
A 128×64 pixel screen (SSD1306, ₹210). It is the board's way of talking to
you without a phone: Bluetooth state, ECG signal status, touch state. If the
screen says `ECG: LEAD OFF`, you know to check electrodes before blaming the
app.

### 3.4 Touch sensor — the one-button interface
A capacitive pad (₹30). Current firmware uses it as a simple "I am here"
input shown on the OLED and serial log. It is a placeholder for the real
buttons in the final enclosure.

### 3.5 Built-in LED — the status light
The tiny blue LED on the ESP32 board blinks a code you can learn in one
minute:

| Blinks | Meaning |
|---|---|
| 3 flashes | Board just powered on, boot OK |
| 5 flashes | Phone connected over Bluetooth |
| 1 flash | Phone disconnected |

### 3.6 The wiring map (what is plugged where)

| ESP32 pin | Connected to | Why this pin (details in §9) |
|---|---|---|
| **GPIO 36 (VP)** | AD8232 `OUTPUT` (the ECG wave) | Analog-capable input pin |
| **GPIO 39 (VN)** | AD8232 `LO+` (lead-off +) | Input-only pin, perfect here |
| **GPIO 34** | AD8232 `LO−` (lead-off −) | Input-only pin |
| **GPIO 18** | AD8232 `SDN` (shutdown) | We can power the ECG chip off to save battery |
| **GPIO 21 / 22** | OLED SDA / SCL | The standard I²C (chip-to-chip bus) pins |
| **GPIO 4** | Touch sensor signal | A digital input |
| **GPIO 2** | Blue LED on the board | The built-in indicator |
| **3.3 V / GND** | All modules' power pins | One shared, battery-friendly supply |

---

## 4. The journey of one heartbeat

This is the single most important section. Follow one heartbeat from the
chest to the phone screen. Every number below is real and comes from the
code, not from a brochure.

### Stage 1 — Skin to chip
Two sticky electrodes on the chest pick up a ~1 mV voltage difference each
time the heart fires. The AD8232 amplifies it, removes slow drift and muscle
noise, and outputs a wave centered around 1.65 V.

### Stage 2 — Chip to a number (250 times every second)
Inside the ESP32, a **hardware timer** fires an alarm every **4 milliseconds**
— exactly 250 times per second. Each alarm runs a tiny routine that asks the
ADC (analog-to-digital converter): *"what voltage is on GPIO 36 right now?"*
The answer is a number from 0 to 4095. That number **is** the ECG at that
instant.

Why a hardware timer instead of "just read in a loop"? Because a loop jitters
— sometimes 3 ms, sometimes 6 ms. Jitter corrupts the time between beats,
and beat-to-beat timing is exactly what medicine cares about. The timer is a
metronome that cannot be distracted.

### Stage 3 — Numbers into a tiny bucket
Each new number lands in an 8-slot rotating buffer. As soon as 8 samples
collect (that takes 8 × 4 ms = 32 ms), they are sealed into an envelope.

### Stage 4 — The envelope (20 bytes, always)
Bluetooth Low Energy has a small letterbox: with the default settings, **one
notification can carry at most 20 bytes**. So every ECG envelope is exactly:

```
 byte 0     0x02            → "this is an ECG packet"
 byte 1     0x01            → protocol version 1
 byte 2-3   sequence number → 0, 1, 2, 3... so the phone can spot a lost packet
 byte 4-19  8 samples × 2 bytes = 16 bytes of actual heart data
```

8 samples every 32 ms = **31.25 envelopes per second**. A steady stream of
postcards, each with part of the wave.

### Stage 5 — Radio flight
The ESP32's BLE radio pushes each envelope to the phone. No pairing dance,
no cables — the phone asked for these envelopes once (see §6) and now they
just arrive.

### Stage 6 — The phone catches and checks
The app's BLE layer (`ble_service.dart`) receives each envelope and is
**suspicious by design**:

- Wrong length? → discard.
- Wrong type/version byte? → discard.
- Sequence number skipped? → count it as a dropped frame and *tell the user
  the trace has a gap* instead of drawing a lie.

Separate from the ECG postcards, the board also sends a 20-byte **telemetry
letter 4 times a second** with the summary numbers: heart rate, SpO₂,
temperature, lead-off flag, battery, quality score (the full layout is in
§6.3). The app sanity-checks these against biological limits — a "heart
rate" of 700 bpm is a broken sensor, not a patient, and the code refuses to
display it as a real reading.

### Stage 7 — Bytes become a picture
The ECG samples go to the **ECG live screen**, which draws them as the
scrolling green waveform you see. The telemetry letters update the number
cards (heart rate, etc.) on the vitals screen. From chest to pixel, the
whole trip takes a small fraction of a second.

### Stage 8 — Understanding, not just drawing
Above the display layer, the app runs its own judgement code:

- `ecg_classifier.dart` — looks at the rhythm's regularity and the signal
  quality, and labels the trace (e.g. NOISY when quality < 50 %).
- `risk_engine.dart` — combines vitals into an advisory score. Hard rule of
  the project: **this logic lives on the phone, never on the board**, and
  the board never decides anyone is sick. The board measures; the app
  interprets; a human decides.
- SOS, explanation in simple language, offline records, and trend charts
  sit on top.

---

## 5. Two languages of Bluetooth

Our first prototype used **Bluetooth Classic** (the old kind, used by audio
devices and the "Bluetooth Terminal" apps). It worked for a phone-to-board
text chat — but the real app could not use it, because the app speaks
**BLE** (Bluetooth Low Energy) with a specific structure called **GATT**.

A friendly analogy:

> **Bluetooth Classic** is a walkie-talkie: once paired, both sides just
> shout text at each other.
> **BLE + GATT** is a bulletin board with labelled boxes: the board posts
> specific items ("live vitals here", "ECG stream here", "write a command
> here"), and the phone subscribes to exactly the boxes it wants.

We rewrote the firmware to speak BLE properly. That is when the app could
finally see the board. **This is also why the board never appears in the
phone's Settings → Bluetooth list** — BLE devices are found *inside apps*,
not paired in system settings. That behavior confused us too at first; it is
normal.

---

## 6. The BLE protocol

This is the contract between board and phone. Both sides follow it exactly;
if either side breaks it, data is dropped instead of misread.

### 6.1 The board's name and address scheme
- The board advertises itself as **`SSAI-SENSE-01`**.
- The app recognises boards whose name starts with `swasthyasetu`, `ssai`,
  or `ss-` — **or** that advertise our service ID. Two independent ways to
  be found = less can go wrong at a demo.
- Every service and data channel has a UUID (a long unique ID). Ours all
  live under the base `6e4000XX-b5a3-f393-e0a9-e50e24dcca9e` — the
  standard "Nordic UART" family, chosen because it is battle-tested.

### 6.2 The six "mailboxes" (GATT table)

| Mailbox | UUID ends in | Direction | What flows |
|---|---|---|---|
| Service | `…0001` | — | The container declaring "I am a SwasthyaSetu board" |
| Device info | `…0002` | Phone **reads** | Firmware version string, e.g. `1.0.0` |
| Live vitals | `…0003` | Board → phone (**notify**) | 20-byte telemetry, 4×/second |
| ECG stream | `…0004` | Board → phone (**notify**) | 31.25 envelopes/second of raw ECG |
| Control | `…0005` | Phone → board (**write**) | `0xA1` = start streaming, `0xA0` = stop |
| Status | `…0006` | (reserved) | Future use |

**Notify** means: *"push data to me whenever you have it — I'll just
listen."* That is what makes realtime possible without constant asking.

### 6.3 The 20-byte telemetry letter (live vitals)

```
 byte 0      = 0x01               "I am a telemetry letter"
 byte 1      = 1                  protocol version
 byte 2      = heart rate (bpm)
 byte 3      = SpO₂ (%)
 byte 4-5    = temperature × 100 (°C)   → 3650 means 36.50 °C
 byte 6-7    = last R-R interval (ms)   time between two heartbeats
 byte 8      = signal quality 0–100
 byte 9      = flags: bit0=R-peak  bit1=fall  bit2=leads off  bit3=finger off
 byte 10-11  = pulse transit time (ms)  (research feature, see below)
 byte 12-13  = estimated blood pressure (experimental)
 byte 14     = battery %
 byte 15     = blood-pressure confidence. 0xFF = "experimental — DO NOT use
               this number for risk scoring"
 byte 16-19  = board uptime in ms (lets the phone detect reboots/gaps)
```

Why it matters for trust:
- The app **validates ranges** (HR must be 25–250, temperature 20–45 °C…).
  Out-of-range = flagged as implausible, not shown as truth.
- Setting byte 15 to `0xFF` is our honesty switch: the BP estimate is
  *real research*, but without per-person calibration against a cuff it is
  not a measurement — so we make the app ignore it on purpose.

### 6.4 The connect moment, step by step

```
PHONE                                          BOARD
  |                                              |
  |  1. scan: "anyone out there?"                |  (constantly advertising)
  |◀──────────── advertisement: SSAI-SENSE-01 ──|
  |  2. connect                                  |
  |─────────────────────────────────────────────▶|   LED: 5 flashes
  |  3. "show me your mailboxes" (discovery)     |
  |  4. "subscribe me to vitals + ECG"           |
  |  5. write 0xA1 → start streaming ───────────▶|   firmware: ecgStreaming = true
  |◀──────── telemetry 4×/s + ECG 31.25×/s ─────|   OLED: BLE: CONNECTED
```

If the link drops, the app does not panic: it retries on a backoff schedule
(1 s, 2 s, 4 s, 8 s, 16 s, 30 s — six attempts) while keeping any ECG
already captured, and the board keeps advertising so it can always be
re-found without a power cycle.

---

## 7. Inside the ESP32 firmware

The firmware (the `.ino` file you uploaded) does five jobs. Here is each in
plain words:

1. **Set up the pins and chips** — OLED, ADC, lead-off inputs, the shutdown
   pin (kept HIGH = AD8232 awake), LED, touch. Then a self-test: scan the
   I²C bus, print a PASS/FAIL list to the serial monitor, blink the LED 3
   times.

2. **Run the 250 Hz metronome** — a hardware timer interrupt. Every 4 ms
   it does exactly one thing: read the ECG voltage into the 8-slot buffer.
   It does *nothing else* in the interrupt, because interrupt time is sacred.

3. **Run the BLE post office** — create the six mailboxes from §6.2,
   advertise the name `SSAI-SENSE-01`, handle connect/disconnect (with the
   LED codes), and listen for the `0xA1`/`0xA0` start/stop commands.

4. **Ship the data** — in the main loop:
   - every 32 ms: if connected and told to stream, seal 8 samples into an
     ECG envelope and notify;
   - every 250 ms: assemble the 20-byte telemetry letter (with lead-off
     status, quality, uptime) and notify.

5. **Keep the human in the loop** — refresh the OLED 10×/second
   (BLE state · ECG state · live ADC number · touch state) and print a
   detailed status block to serial once a second. When hardware misbehaves,
   these two outputs are how we *saw* it (more in §12).

The code deliberately writes **zeros/placeholders** for sensors we have not
wired up yet (SpO₂, temperature) and marks BP as experimental — the app is
built to forgive exactly that, and §11 lists precisely what is real today.

---

## 8. Inside the phone app

The app is **Flutter** (one codebase, Android today). Three design rules
run through it:

1. **Never throw at the user.** Every radio call is guarded; failures become
   readable states ("Radio off", "Permission needed", "Reconnecting…"),
   not crashes.
2. **Bad data is worse than no data.** Parsers return *nothing* for a
   malformed letter rather than a half-guess. A guess could reach the
   triage engine and look like a real vital sign.
3. **Demo and real never mix.** A demo mode exists for training, is loudly
   labelled, lives in a different colour, and can never contaminate real
   screening records.

Key moving parts:

| Piece | What it does |
|---|---|
| `ble_service.dart` | The radio brain: scans, connects through a state machine (`scanning → connecting → discovering → handshaking → streaming`), reconnects on backoff, keeps ECG capture alive across drops |
| `ble_protocol.dart` | The translator: turns 20-byte letters into typed data, validates ranges and versions; pure and unit-tested with no phone needed |
| `permission_service.dart` | Politely asks Android for Bluetooth **and** location (Android 12+ needs both for BLE scanning) at the exact moment of need |
| Device screens | Scan screen (lists nearby boards, ours pinned to the top), connection screen (handshake progress with honest error text), diagnostics |
| Live screens | Real-time ECG waveform with quality label; vitals cards |
| Domain rules | `risk_engine.dart`, `ecg_classifier.dart`, fall/environment rules — the medical judgement, kept testable and separate |
| Everything offline | Local database, history, trends, sync queue for when internet appears |

---

## 9. Why these exact pins

Beginners sometimes ask "why not any GPIO?" Three hardware rules of the
ESP32 forced the map:

1. **The ECG analog signal must go to ADC1 pins (GPIO 32–39).**
   The other analog bank (ADC2) **stops working whenever the radio
   (WiFi/Bluetooth) is active** — a documented chip limitation. Our whole
   product is "measure *while* Bluetooth is on", so ADC2 is useless to us.
   (Our very first wiring used ADC2 pins 32/33 for lead detection and would
   have bitten us later; the final map does not.)

2. **GPIO 34/36/39 are input-only.** Perfect for sensor outputs; they
   physically cannot be misused as outputs. Lead-off signals and the analog
   wave belong there.

3. **GPIO 21/22 are the standard I²C pins**, where every ESP32 example and
   library expects the OLED. Using them means zero surprises.

---

## 10. Safety rules

Built in, not bolted on:

- **No ECG while charging.** Mains-connected measuring on a person is the
  classic way hobby ECG becomes dangerous. We demo unplugged, and the
  hardware plan monitors the charger's status pin to hard-disable the ECG
  front-end when plugged in.
- **Screening, not diagnosis.** Every screen says so. The system advises
  and escalates; it never prescribes.
- **Honest numbers only.** Quality score drops to 0 when electrodes fall
  off; implausible vitals are rejected; experimental measurements are
  labelled experimental and excluded from risk scoring.
- **Battery-first design** with protected cells and conservative charging.

---

## 11. Real vs. placeholder — today's honest status

| Feature | Status today | The truth |
|---|---|---|
| Bluetooth link phone ↔ board | ✅ **Real** | Connects, streams, reconnects |
| ECG waveform on screen | ✅ **Real signal path** | Genuine AD8232 analog data, 250 Hz, noise-checked |
| Lead-off detection | ✅ **Real** | OLED/app show LEAD OFF vs OK from hardware pins |
| OLED status display | ✅ **Real** | Live board state |
| LED status codes | ✅ **Real** | 3 / 5 / 1 blink vocabulary |
| Touch input | ✅ **Real** | Debounced; used as a simple input for now |
| Heart rate number | ⚠️ **Placeholder (72)** | Real R-peak detection engine is the next firmware task |
| SpO₂ (98 %) | ⚠️ **Placeholder** | Needs the MAX30102 optical sensor (arriving next) |
| Temperature (36.5 °C) | ⚠️ **Placeholder** | Needs the MLX90614 IR sensor |
| Blood pressure | 🔬 **Experimental** | Intentionally switched off in risk scoring (`0xFF`) |
| Fall detection | 🔜 **Planned** | Needs the MPU6050 motion sensor; thresholds already specified |

We prefer a short honest list over a long pretend one. The placeholders are
visible constants in the firmware — not hidden — and the app treats them
gracefully.

---

## 12. The three app bugs we found and fixed

Fair to mention in a presentation: this is what real engineering looks like.
Getting the hardware live exposed three genuine bugs in the app itself,
which we fixed in one afternoon:

1. **The app never asked for Bluetooth permission.** On Android 12+, an app
   must ask *at runtime*. Ours declared permissions but never requested
   them — the permission didn't even appear in the phone's settings pages.
   **Fix:** request at the exact moment the worker opens the scan screen.

2. **"Help me open Settings" crashed.** The helper that opens the phone's
   settings page accidentally called itself endlessly (a recursion bug that
   would have frozen the app the one time a user needed it).
   **Fix:** call the real system function.

3. **"Bluetooth is off" — when it was on.** The app read the radio's state
   from a cached value that only updates while someone listens to Android's
   state broadcast. Nobody listened, so it read "unknown" forever and showed
   it as "off". **Fix:** actively listen for the true state once, then
   decide.

Each bug hid behind a misleading symptom. The method that cracked them:
**trust the serial monitor, distrust assumptions** — the board's logs said
"advertising fine", a third-party scanner (nRF Connect) saw the board, and
two minutes of reading the app's own state machine found each lie.

---

## 13. What comes next

The full sensor board (already specified in `hardware/HARDWARE.md`):

- **MAX30102** → real SpO₂ and pulse by light (its own I²C bus, because its
  breakout's 1.8 V pull-ups don't mix with the others — detail documented).
- **MLX90614** → contactless forehead temperature.
- **MPU6050** → fall detection that survives the phone being asleep
  (deep-sleep trick: ~11 months of fall-watch on one charge — the flagship
  claim).
- **BME280** → ambient temperature/humidity/pressure for heat advisories.
- Battery + charger + proper power regulation, so it's a truly wearable
  device (~40 h realistic runtime; the math is in the hardware doc).

And firmware-side: the on-board R-peak detector plus filter chain (50 Hz
mains notch for India) so the heart-rate number becomes real, with the
phone doing rhythm classification on clean intervals.

---

## 14. Glossary

| Term | Plain meaning |
|---|---|
| **ECG** | The heart's electrical waveform; its shape and timing carry medical meaning |
| **ADC** | A measurer that turns a voltage into a number the chip can use (0–4095 here) |
| **GPIO** | A programmable pin on the ESP32 — an ear (input) or a hand (output) |
| **I²C** | A shared two-wire chatter line between chips; the OLED uses it |
| **Firmware** | The one program burned into the ESP32; it *is* the board's behaviour |
| **BLE** | Bluetooth Low Energy — small data, tiny battery |
| **GATT** | BLE's filing system: named mailboxes for reading, writing, and subscribing |
| **Notify / subscribe** | "Push it to me when you have it" — no repeated asking |
| **UUID** | A long unique ID naming each mailbox so phone and board agree |
| **Telemetry** | The 4×-per-second summary letter (HR, quality, battery…) |
| **Lead-off** | "An electrode came off the skin" — detected in hardware, never faked |
| **Timer interrupt** | The metronome: hardware pokes the chip every 4 ms to sample on time |
| **Backoff** | The polite retry rhythm after a dropped link: wait 1 s, then 2, 4, 8… |
| **Placeholder** | A clearly-marked stand-in value until the real sensor arrives |

---

*Built as a screening tool, not a diagnostic device. Every number on screen
is either measured, clearly a placeholder, or clearly experimental — and the
difference between those three categories is the soul of this project.*
