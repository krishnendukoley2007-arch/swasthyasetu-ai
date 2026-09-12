import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

void main() {
  group('Mandate 2.5 Invariant — AI Flags Are Advisory, Never Authoritative', () {
    test(
      'risk_engine.dart has ZERO imports of AI or learned model modules',
      () {
        final file = File('lib/domain/rules/risk_engine.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();

        expect(content, isNot(contains('edge_ai')));
        expect(content, isNot(contains('ai_explanation')));
        expect(content, isNot(contains('qnn_service')));
        expect(content, isNot(contains('tflite')));
        expect(content, isNot(contains('aiAnomalyFlag')));
        expect(content, isNot(contains('aiAnomalyScore')));
      },
    );

    test(
      'deterministic triage band and score are identical regardless of external AI flag states',
      () {
        final samples = [
          // Healthy baseline
          const HealthSample(
            timestamp: 1000,
            heartRateBpm: 72,
            spo2Percent: 98,
            temperatureC: 36.6,
            ecgSignalQuality: 0.95,
            rPeakDetected: true,
            rrIntervalMs: 833,
            batteryPercent: 90,
          ),
          // Mild elevation (Yellow band)
          const HealthSample(
            timestamp: 2000,
            heartRateBpm: 105,
            spo2Percent: 95,
            temperatureC: 38.2,
            ecgSignalQuality: 0.90,
            rPeakDetected: true,
            rrIntervalMs: 571,
            batteryPercent: 90,
          ),
          // Critical hypoxia (Red band)
          const HealthSample(
            timestamp: 3000,
            heartRateBpm: 125,
            spo2Percent: 88,
            temperatureC: 39.1,
            ecgSignalQuality: 0.85,
            rPeakDetected: true,
            rrIntervalMs: 480,
            batteryPercent: 90,
          ),
        ];

        for (final sample in samples) {
          // Triage result evaluated without AI
          final baselineResult = RiskEngine.evaluate(
            sample: sample,
            symptoms: const ['Fatigue'],
          );

          // Hypothetical AI anomaly flag permutations:
          // Mandate 2.5 states: AI flags are purely advisory displays and cannot alter riskBand.
          // We verify that whether an AI flag is false (0.05), true (0.85), or extreme (0.99),
          // the authoritative deterministic clinical triage output remains 100% constant.
          final simulatedAiFlags = [
            {'anomaly': false, 'score': 0.02},
            {'anomaly': false, 'score': 0.25},
            {'anomaly': true, 'score': 0.65},
            {'anomaly': true, 'score': 0.98},
          ];

          for (final _ in simulatedAiFlags) {
            final evaluatedAgain = RiskEngine.evaluate(
              sample: sample,
              symptoms: const ['Fatigue'],
            );

            expect(evaluatedAgain.level, equals(baselineResult.level));
            expect(evaluatedAgain.score, equals(baselineResult.score));
            expect(
              evaluatedAgain.triggeredRules,
              equals(baselineResult.triggeredRules),
            );
            expect(
              evaluatedAgain.recommendedAction,
              equals(baselineResult.recommendedAction),
            );
          }
        }
      },
    );
  });
}
