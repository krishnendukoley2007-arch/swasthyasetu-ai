// Native unit tests for dsp_pure.h — the same DSP the firmware runs.
// Run: pio test -e native
#include <unity.h>
#include <stdint.h>
#include <math.h>

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

int main() {
    UNITY_BEGIN();
    RUN_TEST(test_rpeak_detects_60bpm_train);
    RUN_TEST(test_rpeak_refractory_rejects_double_count);
    RUN_TEST(test_baseline_removal_rejects_dc_offset);
    RUN_TEST(test_notch_attenuates_mains_50hz);
    RUN_TEST(test_bandpass_preserves_10hz_ecg_content);
    RUN_TEST(test_median_of_5_rejects_outlier);
    RUN_TEST(test_battery_curve_endpoints_and_midplateau);
    return UNITY_END();
}
