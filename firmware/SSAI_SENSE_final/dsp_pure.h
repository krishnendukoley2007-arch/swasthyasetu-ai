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
#include <math.h>
#include <stdint.h>

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
extern volatile bool showHeartIcon;
extern volatile uint16_t ecg_hr;
extern volatile uint16_t current_hr;
extern volatile uint16_t last_rr_ms;

// ------------------------------------------------------------------
// ECG sample-rate and mains frequency configuration
// ------------------------------------------------------------------
#define ECG_FS 250.0
#ifndef MAINS_FREQ_HZ
#define MAINS_FREQ_HZ 50.0 // set to 60.0 for 60 Hz mains regions
#endif

// ------------------------------------------------------------------
// Generic 2nd-order IIR biquad (Transposed Direct Form II)
// ------------------------------------------------------------------
struct Biquad {
  double b0, b1, b2; // feed-forward coefficients
  double a1, a2;     // feedback coefficients (a0 normalized to 1)
  double z1, z2;     // delay-line state
};

static double biquadProcess(Biquad *f, double x) {
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
  ecgLp40 = biquadLowpass(ECG_FS, 40.0, 0.7071);      // Butterworth
  ecgNotch = biquadNotch(ECG_FS, MAINS_FREQ_HZ, 8.0); // narrow notch
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
  if (alpha_n > alpha_max)
    alpha_n = alpha_max;
  if (alpha_n < alpha_min)
    alpha_n = alpha_min;
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
  // Peak condition: positive-to-negative slope transition above adaptive
  // threshold theta Enforce 360 ms absolute physiological refractory period
  // (equivalent to max 166 BPM)
  if (y_n > theta && slope_n_1 > 0 && slope_n < 0 &&
      (t_n - last_peak_time > 360)) {
    // T-wave suppression: if another peak occurs within 480ms and has less than
    // 75% of previous R-peak amplitude, reject it as ventricular repolarization
    // (T-wave)
    if ((t_n - last_peak_time < 480) && (y_n < last_peak_amp * 0.75)) {
      last_x = y_n;
      return;
    }

    uint16_t rr = (last_peak_time == 0) ? 0 : (t_n - last_peak_time);
    last_peak_time = t_n;
    last_peak_amp = y_n;
    showHeartIcon = true;

    if (rr >= 360 && rr <= 1800) { // Physiological window: 33 to 166 BPM
      last_rr_ms = rr;
      uint16_t inst_hr = (uint16_t)(60000.0 / rr);
      if (ecg_smoothed_hr < 30.0) {
        ecg_smoothed_hr = (double)inst_hr;
      } else {
        double delta = (double)inst_hr - ecg_smoothed_hr;
        // Slew-rate limit to prevent erratic swings from single noisy beats
        if (fabs(delta) > 15.0)
          delta = (delta > 0) ? 15.0 : -15.0;
        ecg_smoothed_hr += delta * 0.35;
      }
      ecg_hr = (uint16_t)(ecg_smoothed_hr + 0.5);
      if (ecg_hr > 220)
        ecg_hr = 220;
      if (ecg_hr < 35)
        ecg_hr = 0;
      current_hr = ecg_hr; // Update global
    }
    theta = 0.85 * theta + 0.15 * fabs(y_n);
    if (theta < 60.0)
      theta = 60.0;
  } else {
    if (t_n - last_peak_time > 100)
      showHeartIcon = false;
  }
  // If no beats for 3.5 seconds, reset smoothed rate
  if (last_peak_time > 0 && (t_n - last_peak_time > 3500)) {
    ecg_smoothed_hr = 0.0;
    current_hr = 0;
  }
  if (t_n - last_peak_time > 1500) {
    theta *= 0.98;
    if (theta < 60.0)
      theta = 60.0;
  }
  last_x = y_n;
}

// Full ECG DSP state reset (called when an ECG measurement starts, so
// filter delay-lines and the adaptive threshold don't carry stale
// charge from the previous session).
void resetEcgDsp() {
  b_n = f_fast = f_slow = 0.0;
  theta = 120.0;
  last_x = slope_n_1 = slope_n = 0.0;
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
  for (int i = 0; i < 5; i++)
    a[i] = in[i];
  for (int i = 1; i < 5; i++) {
    float key = a[i];
    int j = i - 1;
    while (j >= 0 && a[j] > key) {
      a[j + 1] = a[j];
      j--;
    }
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
  static const float pct[] = {0.f,  5.f,  10.f, 20.f, 30.f, 40.f,
                              50.f, 60.f, 70.f, 80.f, 90.f, 100.f};
  const int n = (int)(sizeof(volts) / sizeof(volts[0]));
  if (v <= volts[0])
    return 0;
  if (v >= volts[n - 1])
    return 100;
  for (int i = 1; i < n; i++) {
    if (v < volts[i]) {
      float t = (v - volts[i - 1]) / (volts[i] - volts[i - 1]);
      return (int)(pct[i - 1] + t * (pct[i] - pct[i - 1]));
    }
  }
  return 100;
}

// ------------------------------------------------------------------
// Photoplethysmography (PPG) SpO2 & Heart Rate Pure DSP
// ------------------------------------------------------------------
// Calibrated lookup table: SpO2 = -45.060*R^2 + 30.354*R + 94.845
// where R = (AC_red / DC_red) / (AC_ir / DC_ir) * 100
static const uint8_t swasthya_spo2_table[184] = {
    95, 95, 95, 96, 96, 96, 97, 97, 97, 97, 97, 98, 98, 98, 98, 98, 99, 99, 99, 99,
    99, 99, 99, 99, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,
    100, 100, 100, 100, 99, 99, 99, 99, 99, 99, 99, 99, 98, 98, 98, 98, 98, 98, 97, 97,
    97, 97, 96, 96, 96, 96, 95, 95, 95, 94, 94, 94, 93, 93, 93, 92, 92, 92, 91, 91,
    90, 90, 89, 89, 89, 88, 88, 87, 87, 86, 86, 85, 85, 84, 84, 83, 82, 82, 81, 81,
    80, 80, 79, 78, 78, 77, 76, 76, 75, 74, 74, 73, 72, 72, 71, 70, 69, 69, 68, 67,
    66, 66, 65, 64, 63, 62, 62, 61, 60, 59, 58, 57, 56, 56, 55, 54, 53, 52, 51, 50,
    49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 31, 30, 29,
    28, 27, 26, 25, 23, 22, 21, 20, 19, 17, 16, 15, 14, 12, 11, 10, 9, 7, 6, 5,
    3, 2, 1
};

static inline int32_t swasthya_i32_min(int32_t a, int32_t b) {
  return (a < b) ? a : b;
}

static inline int32_t swasthya_i32_max(int32_t a, int32_t b) {
  return (a > b) ? a : b;
}

static void swasthya_sort_ascend(int32_t *pn_x, int32_t n_size) {
  for (int32_t i = 1; i < n_size; i++) {
    int32_t n_temp = pn_x[i];
    int32_t j;
    for (j = i; j > 0 && n_temp < pn_x[j - 1]; j--)
      pn_x[j] = pn_x[j - 1];
    pn_x[j] = n_temp;
  }
}

static void swasthya_sort_indices_descend(const int32_t *pn_x, int32_t *pn_indx, int32_t n_size) {
  for (int32_t i = 1; i < n_size; i++) {
    int32_t n_temp = pn_indx[i];
    int32_t j;
    for (j = i; j > 0 && pn_x[n_temp] > pn_x[pn_indx[j - 1]]; j--)
      pn_indx[j] = pn_indx[j - 1];
    pn_indx[j] = n_temp;
  }
}

static void swasthya_peaks_above_min_height(int32_t *pn_locs, int32_t *n_npks, const int32_t *pn_x,
                                            int32_t n_size, int32_t n_min_height) {
  int32_t i = 1;
  *n_npks = 0;
  while (i < n_size - 1) {
    if (pn_x[i] > n_min_height && pn_x[i] > pn_x[i - 1]) {
      int32_t n_width = 1;
      while (i + n_width < n_size && pn_x[i] == pn_x[i + n_width])
        n_width++;
      if (pn_x[i] > pn_x[i + n_width] && (*n_npks) < 15) {
        pn_locs[(*n_npks)++] = i;
        i += n_width + 1;
      } else {
        i += n_width;
      }
    } else {
      i++;
    }
  }
}

static void swasthya_remove_close_peaks(int32_t *pn_locs, int32_t *pn_npks, const int32_t *pn_x,
                                        int32_t n_min_distance) {
  swasthya_sort_indices_descend(pn_x, pn_locs, *pn_npks);
  for (int32_t i = -1; i < *pn_npks; i++) {
    int32_t n_old_npks = *pn_npks;
    *pn_npks = i + 1;
    for (int32_t j = i + 1; j < n_old_npks; j++) {
      int32_t n_dist = pn_locs[j] - (i == -1 ? -1 : pn_locs[i]);
      if (n_dist > n_min_distance || n_dist < -n_min_distance)
        pn_locs[(*pn_npks)++] = pn_locs[j];
    }
  }
  swasthya_sort_ascend(pn_locs, *pn_npks);
}

static void swasthya_find_peaks(int32_t *pn_locs, int32_t *n_npks, const int32_t *pn_x,
                                int32_t n_size, int32_t n_min_height, int32_t n_min_distance,
                                int32_t n_max_num) {
  swasthya_peaks_above_min_height(pn_locs, n_npks, pn_x, n_size, n_min_height);
  swasthya_remove_close_peaks(pn_locs, n_npks, pn_x, n_min_distance);
  if (*n_npks > n_max_num)
    *n_npks = n_max_num;
}

static void swasthya_calculate_spo2_and_hr(const uint32_t *pun_ir_buffer, int32_t n_ir_buffer_length,
                                           const uint32_t *pun_red_buffer, int32_t *pn_spo2,
                                           int8_t *pch_spo2_valid, int32_t *pn_heart_rate,
                                           int8_t *pch_hr_valid, int32_t *pn_ratio = NULL) {
  if (n_ir_buffer_length < 100) {
    *pn_spo2 = -999;
    *pch_spo2_valid = 0;
    *pn_heart_rate = -999;
    *pch_hr_valid = 0;
    return;
  }

  uint32_t un_ir_mean = 0;
  for (int32_t k = 0; k < n_ir_buffer_length; k++) {
    un_ir_mean += pun_ir_buffer[k];
  }
  un_ir_mean /= n_ir_buffer_length;

  int32_t an_x[100];
  int32_t an_y[100];

  // Invert signal around mean so peak detector finds valleys (systolic dips)
  for (int32_t k = 0; k < n_ir_buffer_length; k++) {
    an_x[k] = -1 * ((int32_t)pun_ir_buffer[k] - (int32_t)un_ir_mean);
  }

  // 4-point moving average filter
  const int32_t ma4_size = 4;
  for (int32_t k = 0; k < 100 - ma4_size; k++) {
    an_x[k] = (an_x[k] + an_x[k + 1] + an_x[k + 2] + an_x[k + 3]) / 4;
  }

  // Calculate dynamic adaptive peak threshold from signal peak-to-peak amplitude
  int32_t min_x = an_x[0], max_x = an_x[0];
  for (int32_t k = 1; k < 100 - ma4_size; k++) {
    if (an_x[k] < min_x) min_x = an_x[k];
    if (an_x[k] > max_x) max_x = an_x[k];
  }
  int32_t p2p = max_x - min_x;
  // Threshold at 25% of AC swing above minimum, with noise floor floor of 15
  int32_t n_th1 = min_x + (p2p * 3) / 10;
  if (n_th1 < 15)
    n_th1 = 15;

  int32_t an_ir_valley_locs[15] = {0};
  int32_t n_npks = 0;
  // n_min_distance = 11 samples @ 25 sps (440 ms refractory period = 136 BPM ceiling).
  // This completely suppresses arterial dicrotic notch reflections (which occur ~150-220 ms after systolic peak).
  swasthya_find_peaks(an_ir_valley_locs, &n_npks, an_x, 100 - ma4_size, n_th1, 11, 15);

  int32_t n_peak_interval_sum = 0;
  if (n_npks >= 2) {
    for (int32_t k = 1; k < n_npks; k++) {
      n_peak_interval_sum += (an_ir_valley_locs[k] - an_ir_valley_locs[k - 1]);
    }
    n_peak_interval_sum /= (n_npks - 1);
    if (n_peak_interval_sum > 0) {
      *pn_heart_rate = (int32_t)((25 * 60) / n_peak_interval_sum);
      *pch_hr_valid = 1;
    } else {
      *pn_heart_rate = -999;
      *pch_hr_valid = 0;
    }
  } else {
    *pn_heart_rate = -999;
    *pch_hr_valid = 0;
  }

  // Load raw values for SpO2 calculation
  for (int32_t k = 0; k < n_ir_buffer_length; k++) {
    an_x[k] = (int32_t)pun_ir_buffer[k];
    an_y[k] = (int32_t)pun_red_buffer[k];
  }

  for (int32_t k = 0; k < n_npks; k++) {
    if (an_ir_valley_locs[k] >= 100) {
      *pn_spo2 = -999;
      *pch_spo2_valid = 0;
      return;
    }
  }

  int32_t an_ratio[5] = {0};
  int32_t n_i_ratio_count = 0;

  for (int32_t k = 0; k < n_npks - 1; k++) {
    int32_t v_start = an_ir_valley_locs[k];
    int32_t v_end = an_ir_valley_locs[k + 1];
    int32_t span = v_end - v_start;
    if (span > 3) {
      int32_t n_y_dc_max = -16777216;
      int32_t n_x_dc_max = -16777216;
      int32_t n_y_dc_max_idx = v_start;
      int32_t n_x_dc_max_idx = v_start;

      for (int32_t i = v_start; i < v_end; i++) {
        if (an_x[i] > n_x_dc_max) {
          n_x_dc_max = an_x[i];
          n_x_dc_max_idx = i;
        }
        if (an_y[i] > n_y_dc_max) {
          n_y_dc_max = an_y[i];
          n_y_dc_max_idx = i;
        }
      }

      // Compute Red AC component subtracting baseline
      int32_t n_y_ac = (an_y[v_end] - an_y[v_start]) * (n_y_dc_max_idx - v_start);
      n_y_ac = an_y[v_start] + n_y_ac / span;
      n_y_ac = an_y[n_y_dc_max_idx] - n_y_ac;

      // Compute IR AC component subtracting baseline
      // NOTE: Bug fix for Maxim line 179: index an_x with n_x_dc_max_idx (NOT n_y_dc_max_idx)
      int32_t n_x_ac = (an_x[v_end] - an_x[v_start]) * (n_x_dc_max_idx - v_start);
      n_x_ac = an_x[v_start] + n_x_ac / span;
      n_x_ac = an_x[n_x_dc_max_idx] - n_x_ac;

      int32_t n_nume = (n_y_ac * n_x_dc_max) >> 7;
      int32_t n_denom = (n_x_ac * n_y_dc_max) >> 7;
      if (n_denom > 0 && n_i_ratio_count < 5 && n_nume != 0) {
        an_ratio[n_i_ratio_count] = (n_nume * 100) / n_denom;
        n_i_ratio_count++;
      }
    }
  }

  swasthya_sort_ascend(an_ratio, n_i_ratio_count);
  int32_t n_middle_idx = n_i_ratio_count / 2;
  int32_t n_ratio_average = 0;
  if (n_middle_idx > 1) {
    n_ratio_average = (an_ratio[n_middle_idx - 1] + an_ratio[n_middle_idx]) / 2;
  } else if (n_i_ratio_count > 0) {
    n_ratio_average = an_ratio[n_middle_idx];
  }

  if (pn_ratio) {
    *pn_ratio = n_ratio_average;
  }

  if (n_ratio_average > 2 && n_ratio_average < 184) {
    *pn_spo2 = swasthya_spo2_table[n_ratio_average];
    *pch_spo2_valid = 1;
  } else {
    *pn_spo2 = -999;
    *pch_spo2_valid = 0;
  }
}

// ------------------------------------------------------------------
// Multi-Modal Signal Quality Index (SQI) & Dual-Rate Verification
// ------------------------------------------------------------------

enum DualRateConcordance {
  DUAL_CONCORDANT = 0,               // Rates match (|delta| <= 5 bpm), high confidence
  DUAL_ELECTRICAL_NOISE = 1,          // ECG elevated but low ECG SQI (motion/scratch)
  DUAL_OPTICAL_NOISE = 2,             // PPG elevated or erratic with low PPG SQI
  DUAL_PHYSIOLOGICAL_DIVERGENCE = 3,  // Both SQIs high, but rates differ > 8 bpm (pulse deficit/PVC)
  DUAL_INSUFFICIENT_DATA = 4          // One or both channels lack active signal
};

// Compute continuous ECG Signal Quality Index (0..100)
static inline uint8_t computeEcgSqi(double baseline_wander, double signal_amp,
                                    uint16_t last_rr_ms, bool lead_off) {
  if (lead_off)
    return 0;

  // 1. Baseline wander score (0..35 pts)
  double abs_wander = fabs(baseline_wander);
  int score_wander = 0;
  if (abs_wander < 50.0) {
    score_wander = 35;
  } else if (abs_wander < 250.0) {
    score_wander = (int)(35.0 - (abs_wander - 50.0) * (30.0 / 200.0));
  } else {
    score_wander = 5;
  }

  // 2. QRS Signal amplitude score (0..35 pts)
  int score_amp = 0;
  if (signal_amp >= 200.0 && signal_amp <= 3500.0) {
    score_amp = 35;
  } else if (signal_amp > 3500.0) {
    score_amp = 20; // potential baseline clip / high electrostatic noise
  } else if (signal_amp > 80.0) {
    score_amp = 20; // low amplitude biopotential
  } else {
    score_amp = 5;
  }

  // 3. Physiological R-R interval consistency (0..30 pts)
  int score_rr = 0;
  if (last_rr_ms >= 500 && last_rr_ms <= 1200) { // 50 to 120 BPM
    score_rr = 30;
  } else if (last_rr_ms >= 360 && last_rr_ms <= 1800) { // 33 to 166 BPM
    score_rr = 18;
  } else {
    score_rr = 5;
  }

  int total = score_wander + score_amp + score_rr;
  if (total > 100) total = 100;
  if (total < 0) total = 0;
  return (uint8_t)total;
}

// Compute continuous PPG Signal Quality Index (0..100)
static inline uint8_t computePpgSqi(float ir_dc, float ir_ac, uint16_t ppg_hr,
                                    bool ppg_low_signal, bool finger_present) {
  if (!finger_present || ir_dc < 25000.0f)
    return 0;
  if (ppg_low_signal)
    return 15;

  float pi_percent = (ir_dc > 0.0f) ? (ir_ac / ir_dc) * 100.0f : 0.0f;

  // 1. Perfusion Index score (0..40 pts)
  int score_pi = 0;
  if (pi_percent >= 0.50f) {
    score_pi = 40;
  } else if (pi_percent >= 0.20f) {
    score_pi = 30;
  } else if (pi_percent >= 0.10f) {
    score_pi = 20;
  } else {
    score_pi = 5;
  }

  // 2. Pulse rate physiological range (0..35 pts)
  int score_hr = 0;
  if (ppg_hr >= 50 && ppg_hr <= 110) {
    score_hr = 35;
  } else if (ppg_hr >= 40 && ppg_hr <= 160) {
    score_hr = 25;
  } else {
    score_hr = 10;
  }

  // 3. DC optical level stability (0..25 pts)
  int score_dc = 0;
  if (ir_dc >= 50000.0f && ir_dc <= 220000.0f) {
    score_dc = 25; // sweet spot of 18-bit ADC
  } else {
    score_dc = 12;
  }

  int total = score_pi + score_hr + score_dc;
  if (total > 100) total = 100;
  if (total < 0) total = 0;
  return (uint8_t)total;
}

// Dual-source Electrical (ECG) vs Optical (PPG) Heart Rate Cross-Verification
static inline DualRateConcordance verifyDualHeartRate(uint16_t ecg_hr, uint16_t ppg_hr,
                                                     uint8_t ecg_sqi, uint8_t ppg_sqi) {
  if (ecg_hr == 0 || ppg_hr == 0)
    return DUAL_INSUFFICIENT_DATA;

  int delta = (int)ecg_hr - (int)ppg_hr;
  int abs_delta = (delta < 0) ? -delta : delta;

  if (abs_delta <= 5)
    return DUAL_CONCORDANT;

  if (delta > 8 && ecg_sqi < 60)
    return DUAL_ELECTRICAL_NOISE;

  if (delta < -8 && ppg_sqi < 60)
    return DUAL_OPTICAL_NOISE;

  if (abs_delta > 8 && ecg_sqi >= 70 && ppg_sqi >= 70)
    return DUAL_PHYSIOLOGICAL_DIVERGENCE;

  if (abs_delta <= 8)
    return DUAL_CONCORDANT;

  return (ecg_sqi >= ppg_sqi) ? DUAL_OPTICAL_NOISE : DUAL_ELECTRICAL_NOISE;
}
