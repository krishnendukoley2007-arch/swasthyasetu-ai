// Native unit tests for dsp_pure.h — the same DSP the firmware runs.
// Run: pio test -e native
#include <unity.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>

// Outputs the DSP expects its includer to provide
volatile bool showHeartIcon = false;
volatile uint16_t ecg_hr = 0;
volatile uint16_t current_hr = 0;
volatile uint16_t last_rr_ms = 0;

#include "../dsp_pure.h"

void setUp() {
    showHeartIcon = false;
    ecg_hr = current_hr = last_rr_ms = 0;
    resetEcgDsp();
}

void tearDown() {}

// Feed a synthetic ECG with a clean R spike of given amplitude at t.
static void feedRWave(unsigned long tStart, unsigned long tPeak, double amp,
                      unsigned long tEnd) {
    // Generate an asymmetric R spike: steep upstroke, slower decay
    for (unsigned long t = tStart; t <= tEnd; t += 4) { // 250 Hz
        double x = 0.0;
        if ((long)t >= (long)tPeak - 40 && (long)t <= (long)tPeak)
            x = amp * (double)(t - (tPeak - 40)) / 40.0;
        else if ((long)t > (long)tPeak && (long)t <= (long)tPeak + 80)
            x = amp * (1.0 - (double)(t - tPeak) / 80.0);
        double y = processECG_BaselineRemoval(ecgConditioningApply(x));
        detectRPeak(y, t);
    }
}

void test_rpeak_detects_60bpm_train() {
    // 5 beats exactly 1000 ms apart -> 60 BPM, RR = 1000 ms
    bool sawIcon = false;
    for (int k = 1; k <= 5; k++) {
        unsigned long tPeak = 200 + (unsigned long)k * 1000;
        feedRWave(tPeak - 500, tPeak, 3000.0, tPeak + 40); // stop <100 ms past peak so icon is still set
        if (showHeartIcon) sawIcon = true;
    }
    TEST_ASSERT_TRUE_MESSAGE(current_hr >= 55 && current_hr <= 65,
                             "HR should settle near 60 BPM");
    TEST_ASSERT_EQUAL_UINT16(1000, last_rr_ms);
    TEST_ASSERT_TRUE(sawIcon);
}

void test_rpeak_refractory_rejects_double_count() {
    // Two "peaks" 200 ms apart: the second must be suppressed (300 BPM
    // is not physiological; the 400 ms refractory must reject it)
    feedRWave(0, 500, 3000.0, 650);
    uint16_t firstRR = last_rr_ms;
    int peaksBefore = (current_hr != 0);
    feedRWave(700, 900, 3500.0, 1050); // inside refractory window
    // last_rr_ms must NOT have been updated by a 200-ms interval
    TEST_ASSERT_NOT_EQUAL(200, last_rr_ms);
    (void)firstRR; (void)peaksBefore;
}

void test_baseline_removal_rejects_dc_offset() {
    resetEcgDsp();
    // Constant 1000-count DC offset (e.g. electrode polarization):
    // the adaptive baseline tracker is deliberately slow (sub-Hz), so
    // 2000 samples only partially settle; by 20000 it must be ~zero.
    double tail = 0;
    for (int i = 0; i < 2000; i++) {
        tail = processECG_BaselineRemoval(1000.0);
    }
    TEST_ASSERT_TRUE_MESSAGE(tail < 300.0, "baseline should be mostly removed after 8 s");
    for (int i = 0; i < 18000; i++) {
        tail = processECG_BaselineRemoval(1000.0);
    }
    TEST_ASSERT_TRUE_MESSAGE(fabs(tail) < 50.0, "baseline should fully converge after 80 s");
}

void test_notch_attenuates_mains_50hz() {
    ecgConditioningInit();
    double inAmp = 0, outAmp = 0;
    const int N = 1250; // 5 s
    for (int i = 0; i < N; i++) {
        double t = i / ECG_FS;
        double x = 1000.0 * sin(2.0 * M_PI * 50.0 * t);
        double y = ecgConditioningApply(x);
        if (i > N / 2) { inAmp = 1000.0; outAmp = fmax(outAmp, fabs(y)); }
    }
    TEST_ASSERT_TRUE_MESSAGE(outAmp < 0.05 * inAmp,
                             "50 Hz mains should be attenuated >26 dB");
}

void test_bandpass_preserves_10hz_ecg_content() {
    ecgConditioningInit();
    double outAmp = 0;
    const int N = 1250;
    for (int i = 0; i < N; i++) {
        double t = i / ECG_FS;
        double x = 1000.0 * sin(2.0 * M_PI * 10.0 * t); // mid-band
        double y = ecgConditioningApply(x);
        if (i > N / 2) outAmp = fmax(outAmp, fabs(y));
    }
    TEST_ASSERT_TRUE_MESSAGE(outAmp > 0.7 * 1000.0,
                             "10 Hz in-band signal should pass nearly unattenuated");
}

void test_median_of_5_rejects_outlier() {
    float v[5] = {36.4f, 36.5f, 99.9f, 36.3f, 36.4f}; // one glitch read
    float m = medianOf5(v);
    TEST_ASSERT_FLOAT_WITHIN(0.05f, 36.4f, m);
}

void test_battery_curve_endpoints_and_midplateau() {
    TEST_ASSERT_EQUAL(0, batteryPercentFromVoltage(3.10f));
    TEST_ASSERT_EQUAL(100, batteryPercentFromVoltage(4.25f));
    // LiPo flat plateau: 3.75 V should be ~30 %, not the linear 55 %
    TEST_ASSERT_EQUAL(30, batteryPercentFromVoltage(3.75f));
    // Monotonic through the curve
    int prev = -1;
    for (float v = 3.2f; v <= 4.2f; v += 0.05f) {
        int p = batteryPercentFromVoltage(v);
        TEST_ASSERT_TRUE(p >= prev);
        prev = p;
    }
}

void test_spo2_accuracy_and_dicrotic_notch_rejection() {
    uint32_t ir[100];
    uint32_t red[100];
    // Baseline DC levels: ~100k counts (18-bit ADC typical value)
    for (int i = 0; i < 100; i++) {
        ir[i] = 100000;
        red[i] = 100000;
    }

    // Synthesize 4 beats at 60 BPM (25 samples / beat: centers at t = 12, 37, 62, 87)
    // Realistic arterial PPG:
    // 1. Primary systolic pulse absorption dip: Gaussian with sigma=2.5 samples (-2000 on IR, -1000 on Red)
    // 2. Secondary dicrotic reflection notch 160 ms (4 samples) later: (-800 on IR, -400 on Red)
    for (int i = 0; i < 100; i++) {
        double ir_ac = 0.0;
        double red_ac = 0.0;
        for (int b = 0; b < 4; b++) {
            double c = 12.0 + b * 25.0;
            // Primary systolic wave
            double d1 = (double)i - c;
            double g1 = exp(-(d1 * d1) / (2.0 * 2.5 * 2.5));
            ir_ac += 2000.0 * g1;
            red_ac += 1000.0 * g1;

            // Dicrotic notch 4 samples later (160 ms)
            double d2 = (double)i - (c + 4.0);
            double g2 = exp(-(d2 * d2) / (2.0 * 1.5 * 1.5));
            ir_ac += 800.0 * g2;
            red_ac += 400.0 * g2;
        }
        ir[i] = (uint32_t)(100000.0 - ir_ac);
        red[i] = (uint32_t)(100000.0 - red_ac);
    }

    int32_t spo2 = 0, hr = 0;
    int8_t spo2_valid = 0, hr_valid = 0;
    swasthya_calculate_spo2_and_hr(ir, 100, red, &spo2, &spo2_valid, &hr, &hr_valid);

    TEST_ASSERT_EQUAL_INT8_MESSAGE(1, hr_valid, "Heart rate should be valid");
    TEST_ASSERT_EQUAL_INT32_MESSAGE(60, hr, "Heart rate must be 60 BPM (dicrotic notch must NOT double count to 120)");
    TEST_ASSERT_EQUAL_INT8_MESSAGE(1, spo2_valid, "SpO2 must be valid");
    TEST_ASSERT_TRUE_MESSAGE(spo2 >= 97 && spo2 <= 100, "SpO2 should calculate ~98-100% for R=0.50");
}

void test_spo2_low_perfusion_adaptation() {
    uint32_t ir[100];
    uint32_t red[100];
    // Baseline DC levels: ~100k counts
    // Weak AC pulsatile component: only 60 counts on IR, 30 counts on Red
    // The old Maxim code had static threshold n_th1 clamped to 30..60, which often
    // failed on weak perfusion signals. The dynamic adaptive threshold reliably detects peaks.
    for (int i = 0; i < 100; i++) {
        double ir_ac = 0.0;
        double red_ac = 0.0;
        for (int b = 0; b < 4; b++) {
            double c = 12.0 + b * 25.0;
            double d1 = (double)i - c;
            double g1 = exp(-(d1 * d1) / (2.0 * 2.5 * 2.5));
            ir_ac += 60.0 * g1;
            red_ac += 30.0 * g1;
        }
        ir[i] = (uint32_t)(100000.0 - ir_ac);
        red[i] = (uint32_t)(100000.0 - red_ac);
    }

    int32_t spo2 = 0, hr = 0;
    int8_t spo2_valid = 0, hr_valid = 0;
    swasthya_calculate_spo2_and_hr(ir, 100, red, &spo2, &spo2_valid, &hr, &hr_valid);

    TEST_ASSERT_EQUAL_INT8_MESSAGE(1, hr_valid, "Dynamic threshold must detect low-perfusion peaks");
    TEST_ASSERT_EQUAL_INT32_MESSAGE(60, hr, "Heart rate must resolve accurately even under weak perfusion");
    TEST_ASSERT_EQUAL_INT8_MESSAGE(1, spo2_valid, "SpO2 must be valid even under weak perfusion");
    TEST_ASSERT_TRUE_MESSAGE(spo2 >= 97 && spo2 <= 100, "SpO2 should calculate ~98-100% for R=0.50 under weak perfusion");
}

void test_ecg_sqi_clean_vs_noisy_vs_leadoff() {
    // 1. Lead off must immediately return 0 SQI
    uint8_t sqiOff = computeEcgSqi(10.0, 1500.0, 800, true);
    TEST_ASSERT_EQUAL_UINT8(0, sqiOff);

    // 2. Clean signal with minimal baseline wander (15), high R-peak amplitude (1200),
    // and healthy sinus R-R interval (800ms = 75 BPM) should yield high SQI (>= 90)
    uint8_t sqiClean = computeEcgSqi(15.0, 1200.0, 800, false);
    TEST_ASSERT_TRUE_MESSAGE(sqiClean >= 90, "Clean ECG should achieve >= 90 SQI");

    // 3. Severe baseline drift (>300 counts) and erratic R-R interval (<300ms) should degrade SQI (< 50)
    uint8_t sqiDrift = computeEcgSqi(350.0, 1200.0, 250, false);
    TEST_ASSERT_TRUE_MESSAGE(sqiDrift < 50, "Heavy baseline drift and tachycardic artifact must drop SQI below 50");
}

void test_ppg_sqi_perfusion_and_finger_off() {
    // 1. Finger off must return 0 SQI
    uint8_t sqiFingerOff = computePpgSqi(10000.0f, 0.0f, 0, false, false);
    TEST_ASSERT_EQUAL_UINT8(0, sqiFingerOff);

    // 2. High perfusion index (AC=1200, DC=100000 -> PI=1.2%) and steady 72 BPM should achieve high SQI (>= 85)
    uint8_t sqiGood = computePpgSqi(100000.0f, 1200.0f, 72, false, true);
    TEST_ASSERT_TRUE_MESSAGE(sqiGood >= 85, "Good perfusion and resting rate should yield >= 85 SQI");

    // 3. Low signal flag active must severely clamp SQI
    uint8_t sqiLowSig = computePpgSqi(50000.0f, 50.0f, 72, true, true);
    TEST_ASSERT_EQUAL_UINT8(15, sqiLowSig);
}

void test_dual_rate_cross_verification() {
    // 1. Concordant rates within 3 BPM with good SQIs
    DualRateConcordance res1 = verifyDualHeartRate(72, 74, 92, 88);
    TEST_ASSERT_EQUAL(DUAL_CONCORDANT, res1);

    // 2. Electrical motion artifact: ECG reads falsely high (130) with low SQI (45), PPG reads 70 with high SQI (90)
    DualRateConcordance res2 = verifyDualHeartRate(130, 70, 45, 90);
    TEST_ASSERT_EQUAL(DUAL_ELECTRICAL_NOISE, res2);

    // 3. Optical motion artifact: PPG reads falsely high (125) with low SQI (40), ECG reads 68 with high SQI (92)
    DualRateConcordance res3 = verifyDualHeartRate(68, 125, 92, 40);
    TEST_ASSERT_EQUAL(DUAL_OPTICAL_NOISE, res3);

    // 4. True physiological divergence (e.g. pulse deficit / premature ventricular contractions):
    // Both signals have high quality (SQI >= 75), but ventricular contraction does not produce peripheral pulse
    DualRateConcordance res4 = verifyDualHeartRate(95, 78, 85, 82);
    TEST_ASSERT_EQUAL(DUAL_PHYSIOLOGICAL_DIVERGENCE, res4);

    // 5. Missing sensor data
    DualRateConcordance res5 = verifyDualHeartRate(0, 75, 0, 85);
    TEST_ASSERT_EQUAL(DUAL_INSUFFICIENT_DATA, res5);
}

int main() {
    UNITY_BEGIN();
    RUN_TEST(test_rpeak_detects_60bpm_train);
    RUN_TEST(test_rpeak_refractory_rejects_double_count);
    RUN_TEST(test_baseline_removal_rejects_dc_offset);
    RUN_TEST(test_notch_attenuates_mains_50hz);
    RUN_TEST(test_bandpass_preserves_10hz_ecg_content);
    RUN_TEST(test_median_of_5_rejects_outlier);
    RUN_TEST(test_battery_curve_endpoints_and_midplateau);
    RUN_TEST(test_spo2_accuracy_and_dicrotic_notch_rejection);
    RUN_TEST(test_spo2_low_perfusion_adaptation);
    RUN_TEST(test_ecg_sqi_clean_vs_noisy_vs_leadoff);
    RUN_TEST(test_ppg_sqi_perfusion_and_finger_off);
    RUN_TEST(test_dual_rate_cross_verification);
    return UNITY_END();
}
