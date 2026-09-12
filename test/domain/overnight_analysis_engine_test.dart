import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/rules/overnight_analysis_engine.dart';

void main() {
  group('OvernightAnalysisEngine Tests', () {
    test('Empty points returns safe fallback report without errors', () {
      final report = OvernightAnalysisEngine.analyze([]);
      expect(report.totalDuration, Duration.zero);
      expect(report.events, isEmpty);
      expect(report.nocturnalDipPercent, 0.0);
      expect(report.odiScore, 0.0);
    });

    test('Normal dipper with stable oxygenation', () {
      final now = DateTime(2026, 9, 12, 23, 0);
      final points = <OvernightDataPoint>[];

      // 60 minutes session: baseline 75 BPM, deep sleep 63 BPM (~16% dip), SpO2 ~98%
      for (int i = 0; i < 60; i++) {
        final hr = i < 10 ? 75 : 63;
        points.add(
          OvernightDataPoint(
            timestamp: now.add(Duration(minutes: i)),
            heartRate: hr,
            spo2: 98.0,
            rrIntervalMs: (60000 / hr).round(),
            leadOff: false,
            fingerOff: false,
            isDemo: false,
          ),
        );
      }

      final report = OvernightAnalysisEngine.analyze(
        points,
        baselineDaytimeHr: 75,
      );

      expect(report.isDemo, isFalse);
      expect(report.meanSleepHr, 65);
      expect(report.nocturnalDipPercent, closeTo(13.3, 1.0));
      expect(report.nocturnalDipCategory, contains('Normal Dipper'));
      expect(report.odiScore, 0.0);
      expect(report.lowestSpo2, 98.0);
      expect(report.hypoxiaDurationMinutes, 0);
      expect(report.events, isEmpty);
    });

    test('Detects nocturnal desaturations and calculates ODI', () {
      final now = DateTime(2026, 9, 12, 23, 0);
      final points = <OvernightDataPoint>[];

      // 60 minutes: add 3 discrete desaturation drops (SpO2 dropping to 88% for 30s)
      for (int i = 0; i < 60; i++) {
        final isDesat1 = i >= 15 && i <= 17;
        final isDesat2 = i >= 30 && i <= 32;
        final isDesat3 = i >= 45 && i <= 47;
        final spo2 = (isDesat1 || isDesat2 || isDesat3) ? 88.0 : 98.0;

        points.add(
          OvernightDataPoint(
            timestamp: now.add(Duration(minutes: i)),
            heartRate: 64,
            spo2: spo2,
            rrIntervalMs: 937,
            leadOff: false,
            fingerOff: false,
          ),
        );
      }

      final report = OvernightAnalysisEngine.analyze(points);

      expect(report.lowestSpo2, 88.0);
      expect(
        report.events.any(
          (e) =>
              e.type == OvernightIssueType.hypoxia ||
              e.type == OvernightIssueType.desaturation,
        ),
        isTrue,
      );
      expect(report.odiScore, greaterThan(0));
    });

    test('Detects severe bradycardia and tachycardia spikes', () {
      final now = DateTime(2026, 9, 12, 23, 0);
      final points = <OvernightDataPoint>[
        OvernightDataPoint(
          timestamp: now,
          heartRate: 70,
          spo2: 98.0,
          rrIntervalMs: 857,
        ),
        OvernightDataPoint(
          timestamp: now.add(const Duration(minutes: 10)),
          heartRate: 38, // Severe bradycardia
          spo2: 97.0,
          rrIntervalMs: 1578,
        ),
        OvernightDataPoint(
          timestamp: now.add(const Duration(minutes: 20)),
          heartRate: 118, // Tachycardia
          spo2: 96.0,
          rrIntervalMs: 508,
        ),
      ];

      final report = OvernightAnalysisEngine.analyze(points);

      expect(
        report.events.any(
          (e) => e.type == OvernightIssueType.severeBradycardia,
        ),
        isTrue,
      );
      expect(
        report.events.any((e) => e.type == OvernightIssueType.tachycardia),
        isTrue,
      );
    });

    test('CSV and JSON export contain valid formatting and headers', () {
      final now = DateTime(2026, 9, 12, 23, 0);
      final points = [
        OvernightDataPoint(
          timestamp: now,
          heartRate: 65,
          spo2: 98.0,
          rrIntervalMs: 923,
          isDemo: false,
        ),
      ];

      final report = OvernightAnalysisEngine.analyze(points);
      final csv = report.toCsv();
      final jsonStr = report.toJsonString();

      expect(csv, contains('SwasthyaSetu AI'));
      expect(csv, contains('HeartRate_BPM'));
      expect(jsonStr, contains('"version": "1.0"'));
      expect(jsonStr, contains('"meanSleepHr": 65'));
    });

    test('Demo flag is preserved and propagated', () {
      final now = DateTime(2026, 9, 12, 23, 0);
      final points = [
        OvernightDataPoint(
          timestamp: now,
          heartRate: 65,
          spo2: 98.0,
          isDemo: true,
        ),
      ];

      final report = OvernightAnalysisEngine.analyze(points);
      expect(report.isDemo, isTrue);
      expect(report.toCsv(), contains('# Is Demo: true'));
    });
  });
}
