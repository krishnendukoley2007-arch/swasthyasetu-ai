# Hardware Documentation

## Bill of Materials (BOM)

### Core Components

| Qty | Component | Description | Approx. Cost |
|-----|-----------|-------------|--------------|
| 1 | ESP32-WROOM-32 DevKit | Main microcontroller board | $8-12 |
| 1 | MAX30102 Breakout | Heart rate/SpO₂ sensor | $5-8 |
| 1 | AD8232 Breakout | Single-lead ECG sensor | $10-15 |
| 1 | MLX90614 Breakout | IR temperature sensor | $8-12 |
| 1 | SSD1306 0.96" OLED | 128x64 I2C display | $3-5 |
| 1 | Li-ion 18650 + Holder | Rechargeable battery | $3-5 |
| 1 | TP4056 Module | Battery charging/protection | $1-2 |
| 1 | AMS1117 3.3V | Voltage regulator | $0.50 |
| 3 | ECG Snap Electrodes | Disposable electrodes | $2-5/set |
| 1 | Tactile Switch | User button (6x6mm) | $0.20 |
| 1 | Piezo Buzzer | 5V active buzzer | $0.30 |
| 1 | Slide Switch | Power switch | $0.30 |
| - | Resistors/Capacitors | Various (see schematic) | $1-2 |
| - | Perfboard/PCB | Custom or breadboard | $2-5 |

**Total Estimated Cost: $45-75**

### Optional Components
- 3D Printed Enclosure
- Lanyard/strap
- Silicone finger sleeve for MAX30102

## Pin Mapping

```
ESP32-WROOM-32
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│     3V3  ●──────────────────────────────────────● GND      │
│     EN   ●                                      ● GPIO23   │
│     VP   ●                                      ● GPIO22 ──┐│
│     VN   ●                                      ● GPIO21 ──┤│ I2C Bus
│     GPIO34 ◀── AD8232 OUTPUT (ECG)              ● GPIO19   ││
│     GPIO35 ◀── Battery ADC                       ● GPIO18   ││
│     GPIO32 ◀── AD8232 LO+                        ● GPIO5    ││
│     GPIO33 ◀── AD8232 LO-                        ● GPIO17   ││
│     GPIO25 ──▶ Buzzer                            ● GPIO16   ││
│     GPIO26                                       ● GPIO4    ││
│     GPIO27 ◀── User Button (Pull-up)             ● GPIO0    ││
│     GPIO14                                       ● GPIO2    ││
│     GPIO12                                       ● GPIO15   ││
│     GND   ●──────────────────────────────────────● GND      │
└─────────────────────────────────────────────────────────────┘

I2C Devices (Shared on GPIO21/GPIO22):
  • MAX30102  @ 0x57 (auto-detect)
  • MLX90614  @ 0x5A
  • SSD1306   @ 0x3C
```

## Schematic Notes

### Power Supply
```
Li-ion (3.7V) → TP4056 → AMS1117 3.3V → ESP32 3V3 pin
                    ↓
              Battery ADC divider (100k/100k) → GPIO35
```

### MAX30102
- VCC → 3.3V
- GND → GND
- SDA → GPIO21
- SCL → GPIO22
- INT → Not connected (polling mode)

### MLX90614
- VCC → 3.3V
- GND → GND
- SDA → GPIO21
- SCL → GPIO22

### AD8232
- 3.3V → 3.3V
- GND → GND
- OUTPUT → GPIO34 (ADC1_CH6)
- LO+ → GPIO32 (Input, Pull-down)
- LO- → GPIO33 (Input, Pull-down)
- SDN → Not connected (always enabled)

### SSD1306 OLED
- VCC → 3.3V
- GND → GND
- SDA → GPIO21
- SCL → GPIO22

### User Interface
- Button: GPIO27 — GND (Internal pull-up enabled)
- Buzzer: GPIO25 → Buzzer + → 3.3V (or use transistor for passive buzzer)

### Battery Monitoring
- Voltage divider: 100kΩ + 100kΩ across battery
- Midpoint → GPIO35 (ADC1_CH7)
- Formula: Vbat = ADC * 3.3 / 4095 * 2

## Assembly Instructions

### 1. Prepare Components
- Verify all components with multimeter
- Check ESP32 DevKit pins match schematic
- Tin all wire ends

### 2. Power Circuit
1. Solder TP4056 to perfboard
2. Connect Li-ion holder to TP4056 B+/B-
3. Connect TP4056 OUT+ to AMS1117 VIN
4. Connect AMS1117 VOUT to ESP32 3V3 rail
5. Add 10µF + 0.1µF capacitors on 3.3V rail

### 3. I2C Bus
1. Run SDA (GPIO21) and SCL (GPIO22) as parallel traces
2. Add 4.7kΩ pull-up resistors on both lines to 3.3V
3. Connect all three I2C devices in parallel

### 4. AD8232 ECG
1. Connect OUTPUT to GPIO34
2. Connect LO+ to GPIO32, LO- to GPIO33
2. Add 10kΩ pull-down on LO+/LO-
3. Connect electrode pads to AD8232 IN+/IN-/REF

### 5. User Interface
1. Button: GPIO27 to GND (enable internal pull-up in code)
2. Buzzer: GPIO25 through 100Ω resistor to GND

### 6. Battery ADC
1. 100kΩ from battery + to GPIO35
2. 100kΩ from GPIO35 to GND
3. 0.1µF capacitor from GPIO35 to GND

### 7. Enclosure
- 3D print case with:
  - Finger cutout for MAX30102
  - Window for OLED
  - Button access
  - Electrode cable ports
  - Battery compartment

## Firmware Configuration

### PlatformIO (Optional)
```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps = 
    adafruit/Adafruit MAX3010x@^1.1.0
    adafruit/Adafruit MLX90614@^2.1.0
    adafruit/Adafruit SSD1306@^2.5.0
    bblanchon/ArduinoJson@^6.21.0
```

### ESP-IDF (Recommended)
```bash
idf.py set-target esp32
idf.py menuconfig  # Configure partitions, flash size
idf.py build flash monitor
```

## Testing & Validation

### Continuity Checks
- [ ] All GND pins connected
- [ ] 3.3V rail continuity
- [ ] I2C SDA/SCL not shorted
- [ ] ADC pins not shorted to GND/VCC
- [ ] Button: GPIO27 ↔ GND (open when released)

### Power-On Test
1. Insert charged Li-ion
2. Slide power switch ON
3. ESP32 LED should blink
4. OLED should show "SwasthyaSetu AI"
5. Measure 3.3V rail: 3.25-3.35V

### Sensor Verification
Run firmware self-test (TEST 1-11):
1. ESP32 Boot ✓
2. I2C Scan (3+ devices) ✓
3. MAX30102 detected ✓
4. MLX90614 detected ✓
5. OLED detected ✓
6. AD8232 signal in range ✓
7. LO+/LO- detection ✓
8. BLE advertising ✓
9. BLE packet TX ✓
10. Battery measurement ✓
11. Full screening cycle ✓

### ECG Signal Quality
With electrodes on RA/LA/LL:
- Amplitude: 0.5-2 mV typical
- Baseline: Stable, no 50/60 Hz hum
- R-peaks: Clear, regular intervals
- SNR: > 10 dB

### SpO₂ Verification
- Finger properly placed, still
- Red/IR waveforms visible
- SpO₂ reads 95-100% on healthy subject
- Perfusion index > 0.5%

### Temperature Verification
- Ambient: ~25°C
- Forehead: 36-37°C
- Accuracy: ±0.2°C vs reference thermometer

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| No I2C devices found | Pull-ups missing, wrong pins | Check 4.7kΩ on SDA/SCL, verify GPIO21/22 |
| MAX30102 not detected | Wrong address, power issue | Try 0x57/0x58, check 3.3V |
| ECG flatline | AD8232 not powered, pin wrong | Check 3.3V, GPIO34, LO pins |
| ECG noisy | 50/60 Hz interference | Enable notch filter, check grounding |
| SpO₂ reads 0 | Finger not placed, LED issue | Check MAX30102 LED current |
| Temp reads -273°C | MLX90614 comm failure | Check I2C, try 0x5A/0x5B |
| OLED blank | Wrong address, power | Check 0x3C, 3.3V, pull-ups |
| BLE not connecting | Device name, UUID | Verify Nordic UART UUIDs |
| Battery reads 0% | Divider wrong, ADC pin | Check 100k/100k, GPIO35 |

## Safety Notes

- **Battery**: Use protected Li-ion cells only
- **Isolation**: AD8232 provides basic isolation; not medical-grade
- **Electrodes**: Use only disposable Ag/AgCl snap electrodes
- **Cleaning**: Wipe sensors with 70% isopropyl between patients
- **Disposal**: Follow local e-waste and medical waste regulations