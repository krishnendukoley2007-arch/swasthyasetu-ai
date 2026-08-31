#pragma once
#ifndef CONFIG_H
#define CONFIG_H

// ====================================================================
// CONFIG
// ====================================================================

#define FIRMWARE_VERSION   "2.0.0"
#define PROTOCOL_VERSION   0x01           // wire format: do not change

#define TOUCH_ACTIVE_LOW   true           // TTP223: idle HIGH, touch LOW

#define SCREEN_WIDTH       128
#define SCREEN_HEIGHT      64
#define OLED_RESET         -1
#define OLED_ADDRESS       0x3C

#define ECG_OUT_PIN        36
#define ECG_LO_PLUS_PIN    39
#define ECG_LO_MINUS_PIN   34
#define ECG_SDN_PIN        18
#define TOUCH_PIN          4
#define LED_PIN            2
#define BATT_PIN           35

#define BATT_DIVIDER       2.0f
#define BATT_V_FULL        4.2f
#define BATT_V_EMPTY       3.0f
#define BATT_SAMPLE_MS     1000
#define BATT_MV_MIN        150            // pin below 150 mV = divider not wired

#define ECG_SAMPLE_HZ      250
#define ECG_FRAME_SAMPLES  8
#define TELEMETRY_MS       250

#define OLED_MS_IDLE       50             // 20 fps when not streaming
#define OLED_MS_STREAM     80             // 12 fps while ECG streams

#define TOUCH_DEBOUNCE_MS  20
#define HOLD_RECAL_MS      900
#define HOLD_SLEEP_MS      2500
#define TAP_GAP_MS         400

#define FAULT_TRIP_MS      8000
#define FAULT_CLEAR_MS     1500
#define TRANSITION_MS      220
#define RECAL_MS           1200

#define PAGE_LIVE   0
#define PAGE_RATE   1
#define PAGE_SCOPE  2
#define PAGE_POWER  3
#define PAGE_STATS  4
#define PAGE_ABOUT  5
#define PAGE_COUNT  6

#define RING_BITS  9
#define RING_SIZE  (1 << RING_BITS)
#define RING_MASK  (RING_SIZE - 1)

// ====================================================================
// BLE UUIDS (must match the app)
// ====================================================================
extern const char* SERVICE_UUID;
extern const char* DEVICE_INFO_UUID;
extern const char* LIVE_VITALS_UUID;
extern const char* ECG_STREAM_UUID;
extern const char* CONTROL_UUID;

#endif
