/**
 * dsp_pure.h — Pure (hardware-free) DSP for SwasthyaSetu AI.
 *
 * Everything in this header depends only on <stdint.h> and <math.h>:
 * no Arduino, no FreeRTOS, no BLE. That is what lets the same code run
 * both on the ESP32 (included from SSAI_SENSE_final.ino) and on the
 * host under `pio test -e native` (included from test/test_dsp.cpp).
 *
 * Contents:
 *   - ECG conditioning chain: 40 Hz low-pass + mains notch (50/60 Hz)
 *   - Adaptive baseline-wander removal
 *   - R-peak detection -> HR + RR interval
 *   - medianOf5 (MLX90614 glitch rejection)
 *   - batteryPercentFromVoltage (LiPo discharge-curve lookup)
 *
 * Globals defined here are single-instance: this header is included by
 * exactly one translation unit per build (the .ino, or the test runner).
 */
#pragma once
#include <stdint.h>
#include <math.h>

// ------------------------------------------------------------------
// Shared outputs (defined by the includer: the .ino or the test).
// detectRPeak() writes these; both build contexts must provide them.
//
// NOTE: declared `volatile` here to match the definitions in the .ino
// (where they are written on Core 0 and read on Core 1). A mismatched
// volatile qualifier between this extern declaration and the .ino's
// definition is a hard compile error ("conflicting declaration"), so
// this qualifier must always match whatever the includer uses.
// ------------------------------------------------------------------
extern volatile bool     showHeartIcon;
extern volatile uint16_t ecg_hr;
extern volatile uint16_t current_hr;
extern volatile uint16_t last_rr_ms;

// ------------------------------------------------------------------
// ECG sample-rate and mains frequency configuration
// ------------------------------------------------------------------
#define ECG_FS 250.0
#ifndef MAINS_FREQ_HZ
#define MAINS_FREQ_HZ 50.0   // set to 60.0 for 60 Hz mains regions
#endif

// ------------------------------------------------------------------
// Generic 2nd-order IIR biquad (Transposed Direct Form II)
// ------------------------------------------------------------------
struct Biquad {
    double b0, b1, b2; // feed-forward coefficients
    double a1, a2;     // feedback coefficients (a0 normalized to 1)
    double z1, z2;     // delay-line state
};

static double biquadProcess(Biquad* f, double x) {
    double y = f->b0 * x + f->z1;
    f->z1 = f->b1 * x - f->a1 * y + f->z2;
    f->z2 = f->b2 * x - f->a2 * y;
    return y;
}

// RBJ audio-EQ-cookbook low-pass
static Biquad biquadLowpass(double fs, double fc, double q) {
    double w0 = 2.0 * M_PI * fc / fs;
    double cw = cos(w0), sw = sin(w0);
    double alpha = sw / (2.0 * q);
    double a0 = 1.0 + alpha;
    Biquad f;
    f.b0 = (1.0 - cw) / 2.0 / a0;
    f.b1 = (1.0 - cw) / a0;
    f.b2 = f.b0;
    f.a1 = -2.0 * cw / a0;
    f.a2 = (1.0 - alpha) / a0;
    f.z1 = f.z2 = 0.0;
    return f;
}

// RBJ notch
static Biquad biquadNotch(double fs, double fc, double q) {
    double w0 = 2.0 * M_PI * fc / fs;
    double cw = cos(w0), sw = sin(w0);
    double alpha = sw / (2.0 * q);
    double a0 = 1.0 + alpha;
    Biquad f;
    f.b0 = 1.0 / a0;
    f.b1 = -2.0 * cw / a0;
    f.b2 = 1.0 / a0;
    f.a1 = -2.0 * cw / a0;
    f.a2 = (1.0 - alpha) / a0;
    f.z1 = f.z2 = 0.0;
    return f;
}

// ------------------------------------------------------------------
// ECG conditioning chain: mains notch -> 40 Hz low-pass
// Mains (50/60 Hz) sits outside the diagnostic ECG band (0.5-40 Hz)
// ------------------------------------------------------------------
Biquad ecgLp40;
Biquad ecgNotch;

void ecgConditioningInit() {
    ecgLp40  = biquadLowpass(ECG_FS, 40.0, 0.7071);         // Butterworth
    ecgNotch = biquadNotch(ECG_FS, MAINS_FREQ_HZ, 8.0);     // narrow notch
}

double ecgConditioningApply(double x) {
    return biquadProcess(&ecgLp40, biquadProcess(&ecgNotch, x));
}

// ------------------------------------------------------------------
// Adaptive baseline-wander removal (handles sub-0.5 Hz drift)
// ------------------------------------------------------------------
double b_n = 0, f_fast = 0, f_slow = 0;
const double alpha_min = 0.0005, alpha_max = 0.005;

double processECG_BaselineRemoval(double x_n) {
    f_fast = f_fast * 0.8 + x_n * 0.2;
    f_slow = f_slow * 0.99 + x_n * 0.01;
    double alpha_n = alpha_min + (fabs(f_fast - f_slow) * 0.00001);
    if(alpha_n > alpha_max) alpha_n = alpha_max;
    if(alpha_n < alpha_min) alpha_n = alpha_min;
    b_n = b_n * (1.0 - alpha_n) + f_slow * alpha_n;
    return x_n - b_n;
}

// ------------------------------------------------------------------
// R-peak detection (slope-sign change over adaptive threshold)
// ------------------------------------------------------------------
double theta = 120.0, last_x = 0, slope_n_1 = 0, slope_n = 0;
unsigned long last_peak_time = 0;
double ecg_smoothed_hr = 0.0;
double last_peak_amp = 0.0;

void detectRPeak(double y_n, unsigned long t_n) {
    slope_n_1 = slope_n;
    slope_n = y_n - last_x;
    // Peak condition: positive-to-negative slope transition above adaptive threshold theta
    if (y_n > theta && slope_n_1 > 0 && slope_n < 0 && (t_n - last_peak_time > 300)) {
        // T-wave suppression: if another peak occurs within 450ms and has less than 60%
        // of previous R-peak amplitude, reject it as ventricular repolarization (T-wave)
        if ((t_n - last_peak_time < 450) && (y_n < last_peak_amp * 0.60)) {
            last_x = y_n;
            return;
        }

        uint16_t rr = (last_peak_time == 0) ? 0 : (t_n - last_peak_time);
        last_peak_time = t_n;
        last_peak_amp = y_n;
        showHeartIcon = true;

        if (rr >= 300 && rr <= 1800) { // Physiological window: 33 to 200 BPM
            last_rr_ms = rr;
            uint16_t inst_hr = (uint16_t)(60000.0 / rr);
            if (ecg_smoothed_hr < 30.0) {
                ecg_smoothed_hr = (double)inst_hr;
            } else {
                double delta = (double)inst_hr - ecg_smoothed_hr;
                // Slew-rate limit to prevent erratic swings from single noisy beats
                if (fabs(delta) > 15.0) delta = (delta > 0) ? 15.0 : -15.0;
                ecg_smoothed_hr += delta * 0.35;
            }
            ecg_hr = (uint16_t)(ecg_smoothed_hr + 0.5);
            if (ecg_hr > 220) ecg_hr = 220;
            if (ecg_hr < 35)  ecg_hr = 0;
            current_hr = ecg_hr; // Update global
        }
        theta = 0.85 * theta + 0.15 * fabs(y_n);
        if (theta < 60.0) theta = 60.0;
    } else {
        if (t_n - last_peak_time > 100) showHeartIcon = false;
    }
    // If no beats for 3.5 seconds, reset smoothed rate
    if (last_peak_time > 0 && (t_n - last_peak_time > 3500)) {
        ecg_smoothed_hr = 0.0;
        current_hr = 0;
    }
    if (t_n - last_peak_time > 1500) {
        theta *= 0.98;
        if (theta < 60.0) theta = 60.0;
    }
    last_x = y_n;
}

// Full ECG DSP state reset (called when an ECG measurement starts, so
// filter delay-lines and the adaptive threshold don't carry stale
// charge from the previous session).
void resetEcgDsp() {
    b_n = f_fast = f_slow = 0.0;
    theta = 120.0; last_x = slope_n_1 = slope_n = 0.0;
    last_peak_time = 0;
    ecg_smoothed_hr = 0.0;
    last_peak_amp = 0.0;
    ecgConditioningInit();
}

// ------------------------------------------------------------------
// Median of 5 (MLX90614 glitch rejection)
// ------------------------------------------------------------------
float medianOf5(const float in[5]) {
    float a[5];
    for (int i = 0; i < 5; i++) a[i] = in[i];
    for (int i = 1; i < 5; i++) {
        float key = a[i];
        int j = i - 1;
        while (j >= 0 && a[j] > key) { a[j + 1] = a[j]; j--; }
        a[j + 1] = key;
    }
    return a[2];
}

// ------------------------------------------------------------------
// Single-cell LiPo open-circuit-voltage -> percent lookup.
// Far more honest than a linear 3.2..4.2 V map, because the discharge
// curve is flat in the middle and steep at both ends.
// ------------------------------------------------------------------
int batteryPercentFromVoltage(float v) {
    static const float volts[] = {3.20f, 3.45f, 3.60f, 3.70f, 3.75f, 3.80f,
                                  3.85f, 3.90f, 3.95f, 4.00f, 4.10f, 4.20f};
    static const float pct[]   = {   0.f,   5.f,  10.f,  20.f,  30.f,  40.f,
                                    50.f,  60.f,  70.f,  80.f,  90.f, 100.f};
    const int n = (int)(sizeof(volts) / sizeof(volts[0]));
    if (v <= volts[0])     return 0;
    if (v >= volts[n - 1]) return 100;
    for (int i = 1; i < n; i++) {
        if (v < volts[i]) {
            float t = (v - volts[i - 1]) / (volts[i] - volts[i - 1]);
            return (int)(pct[i - 1] + t * (pct[i] - pct[i - 1]));
        }
    }
    return 100;
}
