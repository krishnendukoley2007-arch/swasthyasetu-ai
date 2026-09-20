# FitPulse AI — Hardware & Sensor Integration Guide
**AICTE MIC-Student Innovation — Fitness & Sports (Problem Statement ID: 26213)**
*Title: "Ideas that can boost fitness activities and assist in keeping fit"*

---

## 1. System Overview

FitPulse AI pairs an **ESP32 dual-core biometric wearable hub** with an advanced **6-axis IMU (MPU-6050 Gyroscope & Accelerometer)**, clinical-grade **ECG (AD8232)**, and optical **PPG (MAX30102)** to provide real-time athletic guidance, automatic rep counting, heart rate zone management, and injury-prevention form coaching.

```
                   +---------------------------------------+
                   |          ESP32 DEVKIT V1              |
                   |   (Dual 240MHz Core, BLE 4.2/5.0)     |
                   +-------+-----------------------+-------+
                           |                       |
                  Shared I2C Bus                   Analog ADC1
               (SDA: GPIO 21, SCL: GPIO 22)        (Pin: GPIO 34)
                           |                       |
            +--------------+--------------+        |
            |              |              |        v
            v              v              v     +---------------------+
     +------------+ +------------+ +----------+ | AD8232 ECG Sensor   |
     |  MPU-6050  | |  MAX30102  | | SSD1306  | | (Single-Lead R-Peak |
     | 6-Axis IMU | | Pulse-Ox   | | 0.96"    | |  Zero-Lag Pulse &   |
     | (0x68 I2C) | | (0x57 I2C) | | OLED     | |  HRV Readiness)     |
     +------------+ +------------+ | (0x3C)   | +---------------------+
                                   +----------+
```

---

## 2. Complete Pinout & Wiring Table

| Component | Pin Name | ESP32 GPIO Pin | Function / Description |
| :--- | :--- | :--- | :--- |
| **MPU-6050** | VCC | 3V3 | Power (3.3V regulated) |
| | GND | GND | Ground |
| | SCL | GPIO 22 | I2C Clock (shared 400kHz bus) |
| | SDA | GPIO 21 | I2C Data (shared 400kHz bus) |
| | AD0 | GND | I2C Address select (`0x68`) |
| | INT | GPIO 19 | Hardware Motion Wake / Interrupt |
| **MAX30102** | VIN | 3V3 | Power (3.3V) |
| | GND | GND | Ground |
| | SCL | GPIO 22 | I2C Clock (shared bus, address `0x57`) |
| | SDA | GPIO 21 | I2C Data (shared bus, address `0x57`) |
| | INT | GPIO 4 | Sample Ready Interrupt |
| **AD8232 ECG** | 3.3V | 3V3 | Analog power |
| | GND | GND | Ground |
| | OUTPUT | GPIO 34 | Analog ECG Voltage (ADC1_CH6) |
| | LO+ | GPIO 32 | Lead-Off positive detection |
| | LO- | GPIO 35 | Lead-Off negative detection |
| **SSD1306 OLED**| VCC | 3V3 | Power |
| | GND | GND | Ground |
| | SCL | GPIO 22 | I2C Clock (address `0x3C`) |
| | SDA | GPIO 21 | I2C Data (address `0x3C`) |

---

## 3. Sensor I2C Address Conflict Validation

The I2C bus features zero address collision across all modules:
- `0x3C`: SSD1306 OLED Screen
- `0x57`: MAX30102 Optical PPG Sensor
- `0x5A`: MLX90614 Infrared Skin/Body Temperature Sensor
- `0x68`: MPU-6050 6-Axis Gyroscope & Accelerometer (AD0 pulled to GND)

---

## 4. Biomechanical Wearable Placement

1. **Forearm / Upper Arm Band (Recommended for Strength & Lifting)**:
   - Optimal for Bicep Curls, Overhead Press, Push-ups, and Bench Press.
   - Accurately captures arm angular velocity and range of motion.
2. **Chest Strap Mount (Recommended for Cardio & HIIT)**:
   - Gold-standard electrical ECG electrode contact on chest pectorals.
   - Cleanest vertical oscillation and ground impact detection for running and sprints.
