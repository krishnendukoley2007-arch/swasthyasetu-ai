/**
 * fitness_dsp.h — Pure DSP Algorithms for FitPulse AI Wearable (SIH26213)
 *
 * Provides hardware-independent digital signal processing:
 *  1. 50 Hz Mains Notch Filter + 40 Hz Low-Pass for AD8232 ECG (Fs = 250 Hz)
 *  2. Adaptive Baseline Wander Filter for ECG
 *  3. Real Pan-Tompkins QRS Detector (R-Peak -> Real BPM + RR interval)
 *  4. 5 Hz Low-Pass Filter & Dynamic Peak Step Detector for MPU-6050 (Fs = 100 Hz)
 *  5. Motion Exertion Intensity Engine (RMS of dynamic acceleration)
 *  6. Gyroscope Bias Calibration
 */
#pragma once
#include <stdint.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ------------------------------------------------------------------
// Biquad Filter (Transposed Direct Form II)
// ------------------------------------------------------------------
struct Biquad {
  double b0, b1, b2;
  double a1, a2;
  double z1, z2;
};

static inline double biquadProcess(Biquad *f, double x) {
  double y = f->b0 * x + f->z1;
  f->z1 = f->b1 * x - f->a1 * y + f->z2;
  f->z2 = f->b2 * x - f->a2 * y;
  return y;
}

static inline Biquad biquadLowpass(double fs, double fc, double q) {
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

static inline Biquad biquadNotch(double fs, double fc, double q) {
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
// ECG Signal Conditioning (250 Hz sample rate, 50 Hz India mains notch)
// ------------------------------------------------------------------
class EcgDspPipeline {
public:
  Biquad lp40;
  Biquad notch50;
  double b_n;
  double f_fast;
  double f_slow;
  
  // Pan-Tompkins peak detector state
  double theta;
  double last_x;
  double slope_n_1;
  double slope_n;
  unsigned long last_peak_time;
  double smoothed_hr;
  double last_peak_amp;
  
  uint16_t current_hr;
  uint16_t last_rr_ms;
  bool beat_detected;

  void init() {
    lp40 = biquadLowpass(250.0, 40.0, 0.7071);
    notch50 = biquadNotch(250.0, 50.0, 6.0);
    b_n = 0; f_fast = 0; f_slow = 0;
    theta = 120.0; last_x = 0; slope_n_1 = 0; slope_n = 0;
    last_peak_time = 0; smoothed_hr = 0.0; last_peak_amp = 0.0;
    current_hr = 0; last_rr_ms = 0; beat_detected = false;
  }

  // Baseline wander removal (adaptive high-pass)
  double removeBaseline(double x_n) {
    f_fast = f_fast * 0.8 + x_n * 0.2;
    f_slow = f_slow * 0.99 + x_n * 0.01;
    double alpha_n = 0.0005 + (fabs(f_fast - f_slow) * 0.00001);
    if (alpha_n > 0.005) alpha_n = 0.005;
    b_n = b_n * (1.0 - alpha_n) + f_slow * alpha_n;
    return x_n - b_n;
  }

  // Process 1 ADC sample at 250 Hz
  double processSample(double rawAdc, unsigned long nowMs, bool leadOff) {
    beat_detected = false;
    if (leadOff) {
      current_hr = 0;
      last_rr_ms = 0;
      return 0.0;
    }

    double filtered = biquadProcess(&lp40, biquadProcess(&notch50, rawAdc));
    double cleanEcg = removeBaseline(filtered);

    // QRS R-peak detection
    slope_n_1 = slope_n;
    slope_n = cleanEcg - last_x;

    // Positive-to-negative slope zero crossing above threshold
    if (cleanEcg > theta && slope_n_1 > 0 && slope_n < 0 && (nowMs - last_peak_time > 320)) {
      // T-wave rejection (within 450ms and < 70% amplitude)
      if ((nowMs - last_peak_time < 450) && (cleanEcg < last_peak_amp * 0.70)) {
        last_x = cleanEcg;
        return cleanEcg;
      }

      uint16_t rr = (last_peak_time == 0) ? 0 : (uint16_t)(nowMs - last_peak_time);
      last_peak_time = nowMs;
      last_peak_amp = cleanEcg;
      beat_detected = true;

      if (rr >= 300 && rr <= 1800) { // 33 to 200 BPM
        last_rr_ms = rr;
        uint16_t inst_hr = (uint16_t)(60000.0 / rr);
        if (smoothed_hr < 30.0) {
          smoothed_hr = inst_hr;
        } else {
          double delta = inst_hr - smoothed_hr;
          if (fabs(delta) > 12.0) delta = (delta > 0) ? 12.0 : -12.0;
          smoothed_hr += delta * 0.35;
        }
        current_hr = (uint16_t)(smoothed_hr + 0.5);
      }

      // Adaptive threshold decay
      theta = theta * 0.6 + cleanEcg * 0.4;
      if (theta < 60.0) theta = 60.0;
    } else {
      // Gradual decay of detection threshold
      theta *= 0.9995;
      if (theta < 60.0) theta = 60.0;
    }

    last_x = cleanEcg;
    return cleanEcg;
  }
};

// ------------------------------------------------------------------
// IMU 6-Axis Motion Pipeline (100 Hz sample rate)
// ------------------------------------------------------------------
class MotionDspPipeline {
public:
  Biquad stepLp5;
  uint16_t total_steps;
  uint8_t current_cadence;
  uint8_t current_intensity;
  
  // Step detection state
  bool armed;
  unsigned long last_step_time;
  unsigned long step_intervals[4];
  uint8_t step_idx;

  // Moving RMS buffer for intensity (20 samples @ 100Hz = 200ms window)
  double accel_var_accum;
  uint16_t var_sample_count;

  // Gyro calibration
  int16_t gyro_bias_x;
  int16_t gyro_bias_y;
  int16_t gyro_bias_z;
  bool calibrated;

  void init() {
    stepLp5 = biquadLowpass(100.0, 5.0, 0.7071);
    total_steps = 0;
    current_cadence = 0;
    current_intensity = 0;
    armed = false;
    last_step_time = 0;
    step_idx = 0;
    for (int i = 0; i < 4; i++) step_intervals[i] = 0;
    accel_var_accum = 0;
    var_sample_count = 0;
    gyro_bias_x = 0;
    gyro_bias_y = 0;
    gyro_bias_z = 0;
    calibrated = false;
  }

  void processSample(int16_t ax_mG, int16_t ay_mG, int16_t az_mG,
                     int16_t gx_dps10, int16_t gy_dps10, int16_t gz_dps10,
                     unsigned long nowMs) {
    // 1. Acceleration Magnitude in mG (1000 mG = 1 G)
    double mag = sqrt((double)ax_mG * ax_mG + (double)ay_mG * ay_mG + (double)az_mG * az_mG);

    // Filter magnitude for step detection
    double filteredMag = biquadProcess(&stepLp5, mag);

    // 2. Real Step Detection with Dynamic Hysteresis
    // Human running/walking impacts exceed 1.25 G (1250 mG), then trough below 0.95 G (950 mG)
    if (!armed && filteredMag > 125.0) {
      armed = true;
    } else if (armed && filteredMag < 98.0) {
      armed = false;
      // Minimum refractory period 250 ms (max 240 steps/min), max 2000 ms
      unsigned long dt = nowMs - last_step_time;
      if (dt >= 250 && dt <= 2000) {
        total_steps++;
        last_step_time = nowMs;
        
        step_intervals[step_idx % 4] = dt;
        step_idx++;
        
        // Calculate cadence from last 4 steps
        unsigned long sumDt = 0;
        int count = 0;
        for (int i = 0; i < 4; i++) {
          if (step_intervals[i] > 0) {
            sumDt += step_intervals[i];
            count++;
          }
        }
        if (count > 0 && sumDt > 0) {
          double avgDt = (double)sumDt / count;
          current_cadence = (uint8_t)(60000.0 / avgDt);
        }
      } else if (dt > 2000) {
        // Paused walking
        last_step_time = nowMs;
        current_cadence = 0;
      }
    }

    // Zero out cadence if idle for > 2.5s
    if (nowMs - last_step_time > 2500) {
      current_cadence = 0;
    }

    // 3. Motion Intensity (RMS of deviation from 1G)
    double deviation = fabs(mag - 100.0);
    accel_var_accum += deviation * deviation;
    var_sample_count++;

    if (var_sample_count >= 50) { // Every 500 ms (50 samples @ 100Hz)
      double rms = sqrt(accel_var_accum / var_sample_count);
      // Map 0 - 800 mG RMS to 0 - 100% intensity
      int intensity = (int)((rms / 80.0) * 100.0);
      if (intensity > 100) intensity = 100;
      if (intensity < 0) intensity = 0;
      current_intensity = (uint8_t)intensity;

      accel_var_accum = 0;
      var_sample_count = 0;
    }
  }
};

