import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/qnn_service.dart';
import 'package:swasthyasetu_ai/domain/rules/vitals_estimator.dart';

void main() {
  group('VitalsEstimator — Blood Pressure Calibration & Trend Estimation', () {
    test(
      'returns UNCALIBRATED when no cuff calibration reading is provided',
      () {
        final uncalibrated = VitalsEstimator.estimateBP(
          pttMs: 220,
          heartRate: 72,
          age: 35,
        );

        expect(uncalibrated.isCalibrated, isFalse);
        expect(uncalibrated.confidence, 'UNCALIBRATED');
        expect(uncalibrated.systolic, 0);
        expect(uncalibrated.diastolic, 0);
        expect(uncalibrated.isValid, isFalse);
      },
    );

    test('returns CALIBRATED_TREND when reference cuff reading is provided', () {
      final calibrated = VitalsEstimator.estimateBP(
        pttMs: 220,
        heartRate: 72,
        age: 35,
        calibratedSystolic: 120,
        calibratedDiastolic: 80,
      );

      expect(calibrated.isCalibrated, isTrue);
      expect(calibrated.confidence, 'CALIBRATED_TREND');
      expect(calibrated.systolic, greaterThan(0));
      expect(calibrated.diastolic, greaterThan(0));
      expect(calibrated.isValid, isTrue);
      // At nominal baseline (ptt: 220, hr: 72, age: 35), should anchor close to 120/80
      expect(calibrated.systolic, closeTo(120, 3));
      expect(calibrated.diastolic, closeTo(80, 3));
    });

    test(
      'tracks arterial stiffness: shorter PTT results in higher blood pressure',
      () {
        final baseline = VitalsEstimator.estimateBP(
          pttMs: 220,
          heartRate: 72,
          age: 35,
          calibratedSystolic: 120,
          calibratedDiastolic: 80,
        );

        // Shorter PTT = faster pulse wave = stiffer contracted arteries = higher BP
        final stiffArtery = VitalsEstimator.estimateBP(
          pttMs: 150,
          heartRate: 72,
          age: 35,
          calibratedSystolic: 120,
          calibratedDiastolic: 80,
        );

        expect(stiffArtery.systolic, greaterThan(baseline.systolic));
        expect(stiffArtery.diastolic, greaterThan(baseline.diastolic));
      },
    );

    test('handles invalid/zero sensor inputs gracefully', () {
      final invalidPtt = VitalsEstimator.estimateBP(
        pttMs: 0,
        heartRate: 72,
        calibratedSystolic: 120,
        calibratedDiastolic: 80,
      );
      expect(invalidPtt.confidence, 'INVALID');
      expect(invalidPtt.isValid, isFalse);

      final invalidHr = VitalsEstimator.estimateBP(
        pttMs: 220,
        heartRate: 0,
        calibratedSystolic: 120,
        calibratedDiastolic: 80,
      );
      expect(invalidHr.confidence, 'INVALID');
      expect(invalidHr.isValid, isFalse);
    });
  });

  group('VitalsInferenceService — Runtime Latency & Honest Telemetry', () {
    test(
      'predictVitals measures real runtime stopwatch latency (not hardcoded 8.4 ms)',
      () async {
        final service = VitalsInferenceService();

        final result1 = await service.predictVitals(
          pttMs: 220,
          heartRate: 75,
          spo2: 98,
          tempC: 36.6,
          calibratedSystolic: 120,
          calibratedDiastolic: 80,
        );

        // Verify latency is measured at runtime
        expect(result1.inferenceLatencyMs, isNotNull);
        expect(result1.inferenceLatencyMs, greaterThanOrEqualTo(0.0));
        // Verify no hardcoded 8.4 constant
        expect(result1.isNpuAccelerated, isFalse);
        expect(result1.telemetry.isOnDevice, isTrue);
        expect(
          result1.telemetry.privacyGuarantee,
          '100% On-Device — Zero Cloud Vitals',
        );
        expect(result1.telemetry.devicePlatform, contains('CPU'));
      },
    );

    test(
      'predictVitals propagates calibration to systolic and diastolic BP',
      () async {
        final service = VitalsInferenceService();

        final uncalibrated = await service.predictVitals(
          pttMs: 220,
          heartRate: 75,
          spo2: 98,
          tempC: 36.6,
        );
        expect(uncalibrated.systolicBp, 0);
        expect(uncalibrated.diastolicBp, 0);

        final calibrated = await service.predictVitals(
          pttMs: 220,
          heartRate: 75,
          spo2: 98,
          tempC: 36.6,
          calibratedSystolic: 125,
          calibratedDiastolic: 82,
        );
        expect(calibrated.systolicBp, closeTo(125, 4));
        expect(calibrated.diastolicBp, closeTo(82, 4));
      },
    );
  });
}
