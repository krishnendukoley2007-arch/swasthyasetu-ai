import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/edge_ai_service.dart';

void main() {
  group('EdgeAiService — On-Device 1D-CNN Rhythm Anomaly Detection', () {
    late EdgeAiService service;

    setUp(() {
      service = EdgeAiService();
    });

    test(
      'inference completes within tight latency budget (< 25 ms on host)',
      () async {
        // 250 samples (1 second at 250 Hz)
        final normalBeats = List<int>.generate(250, (i) {
          return (2048 + 500 * math.sin(2 * math.pi * i / 250)).round();
        });

        final result = await service.evaluateRhythmWindow(
          ecgSamples: normalBeats,
          isDemo: false,
        );

        expect(result.latencyMs, lessThan(25.0));
        expect(result.windowSamples, equals(EdgeAiService.kWindowSize));
        expect(result.inferenceBackend, contains('Autoencoder'));
      },
    );

    test(
      'deterministic inference: identical input yields exact same anomaly score',
      () async {
        final samples = List<int>.generate(128, (i) => (2048 + (i % 50) * 10));

        final run1 = await service.evaluateRhythmWindow(ecgSamples: samples);
        final run2 = await service.evaluateRhythmWindow(ecgSamples: samples);

        expect(run1.anomalyScore, equals(run2.anomalyScore));
        expect(run1.isAnomaly, equals(run2.isAnomaly));
      },
    );

    test('normal periodic rhythm evaluates below anomaly threshold', () async {
      // 128 samples (~0.5s beat window at 250 Hz) with physiologic P-QRS-T complexes
      final normalRhythm = List<int>.generate(128, (i) {
        final t = i * (0.512 / 128.0);
        final pWave =
            220.0 * math.exp(-math.pow(t - 0.15, 2) / (2 * 0.022 * 0.022));
        final qWave =
            -250.0 * math.exp(-math.pow(t - 0.228, 2) / (2 * 0.010 * 0.010));
        final rWave =
            1600.0 * math.exp(-math.pow(t - 0.250, 2) / (2 * 0.016 * 0.016));
        final sWave =
            -350.0 * math.exp(-math.pow(t - 0.272, 2) / (2 * 0.012 * 0.012));
        final tWave =
            380.0 * math.exp(-math.pow(t - 0.400, 2) / (2 * 0.038 * 0.038));
        return (2048 + pWave + qWave + rWave + sWave + tWave).round();
      });

      final result = await service.evaluateRhythmWindow(
        ecgSamples: normalRhythm,
        threshold: EdgeAiService.kDefaultAnomalyThreshold,
      );

      expect(result.isAnomaly, isFalse);
      expect(
        result.anomalyScore,
        lessThan(EdgeAiService.kDefaultAnomalyThreshold),
      );
      expect(result.advisoryMessage, contains('matches normal sinus baseline'));
    });

    test(
      'highly erratic/chaotic pattern flags an anomaly above threshold',
      () async {
        // High-frequency random noise / fibrillatory flutter
        final rng = math.Random(42);
        final chaoticPattern = List<int>.generate(
          128,
          (_) => rng.nextInt(4096),
        );

        final result = await service.evaluateRhythmWindow(
          ecgSamples: chaoticPattern,
          threshold: EdgeAiService.kDefaultAnomalyThreshold,
        );

        expect(result.isAnomaly, isTrue);
        expect(
          result.anomalyScore,
          greaterThanOrEqualTo(EdgeAiService.kDefaultAnomalyThreshold),
        );
        expect(
          result.advisoryMessage,
          contains('differs from normal sinus baseline'),
        );
      },
    );

    test('gracefully handles small or empty windows', () async {
      final emptyResult = await service.evaluateRhythmWindow(
        ecgSamples: const [],
      );
      expect(emptyResult.isAnomaly, isFalse);
      expect(emptyResult.windowSamples, equals(0));

      final shortResult = await service.evaluateRhythmWindow(
        ecgSamples: List<int>.filled(100, 2048),
      );
      expect(shortResult.isAnomaly, isFalse);
      expect(shortResult.windowSamples, equals(100));
    });

    test('isDemo flag is faithfully propagated (Mandate 2.1)', () async {
      final samples = List<int>.filled(128, 2048);

      final demoResult = await service.evaluateRhythmWindow(
        ecgSamples: samples,
        isDemo: true,
      );
      expect(demoResult.isDemo, isTrue);

      final liveResult = await service.evaluateRhythmWindow(
        ecgSamples: samples,
        isDemo: false,
      );
      expect(liveResult.isDemo, isFalse);
    });

    test(
      'Synthetic Sinus Baseline pattern: normal sinus beat reconstructs with high fidelity (MSE < 0.05)',
      () async {
        final nsrRecord = EdgeAiService.record100Nsr;
        final eval = await service.evaluateDetailedWindow(
          ecgSamples: nsrRecord.samples,
        );

        expect(eval.isAnomaly, isFalse);
        expect(eval.mse, lessThan(0.05));
        expect(
          eval.advisoryMessage,
          contains('concordant with normal sinus baseline'),
        );
      },
    );

    test(
      'Synthetic PVC Ectopic pattern: wide bizarre ventricular ectopic beat flags anomaly (MSE > 0.10)',
      () async {
        final pvcRecord = EdgeAiService.record119Pvc;
        final eval = await service.evaluateDetailedWindow(
          ecgSamples: pvcRecord.samples,
        );

        expect(eval.isAnomaly, isTrue);
        expect(eval.mse, greaterThan(0.10));
        expect(
          eval.advisoryMessage,
          contains('Atypical rhythm morphology flagged'),
        );
      },
    );

    test(
      'Synthetic AFib Ripple pattern: fibrillatory baseline ripple flags anomaly (MSE >= 0.06)',
      () async {
        final afibRecord = EdgeAiService.record201Afib;
        final eval = await service.evaluateDetailedWindow(
          ecgSamples: afibRecord.samples,
        );

        expect(eval.isAnomaly, isTrue);
        expect(eval.mse, greaterThanOrEqualTo(0.06));
      },
    );

    test(
      'evaluateDetailedWindow: exports 128-sample waveforms, squared residuals, and throughput',
      () async {
        final nsrRecord = EdgeAiService.record100Nsr;
        final eval = await service.evaluateDetailedWindow(
          ecgSamples: nsrRecord.samples,
        );

        expect(eval.inputNormalized.length, equals(128));
        expect(eval.reconstructed.length, equals(128));
        expect(eval.perSampleSquaredResidual.length, equals(128));
        expect(eval.parameterCount, equals(119));
        expect(eval.modelSizeBytes, equals(1840));
        expect(eval.throughputBps, greaterThan(100.0));
        expect(eval.hardwareBackend, contains('Qualcomm Snapdragon'));
      },
    );

    test('measured latency across 500 iterations via Stopwatch', () async {
      final samples = EdgeAiService.record100Nsr.samples;

      // Warmup 50 runs
      for (int i = 0; i < 50; i++) {
        await service.evaluateDetailedWindow(ecgSamples: samples);
      }

      const int n = 500;
      final sw = Stopwatch()..start();
      for (int i = 0; i < n; i++) {
        await service.evaluateDetailedWindow(ecgSamples: samples);
      }
      sw.stop();

      final avgMs = (sw.elapsedMicroseconds / n) / 1000.0;
      final throughput = 1000.0 / avgMs;
      // print to console for factual verification
      // ignore: avoid_print
      print(
        'ACTUAL MEASURED BENCHMARK: Latency = ${avgMs.toStringAsFixed(3)} ms/beat | Throughput = ${throughput.toStringAsFixed(0)} beats/sec',
      );

      expect(avgMs, lessThan(5.0)); // Well under mobile real-time threshold
    });
  });
}
