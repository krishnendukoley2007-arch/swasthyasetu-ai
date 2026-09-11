import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/rules/clinical_signal_analysis.dart';

void main() {
  group('ClinicalSignalAnalysis.analyzeRawWaveform', () {
    test('returns empty morphology for insufficient samples', () {
      final res = ClinicalSignalAnalysis.analyzeRawWaveform(const [1, 2, 3]);
      expect(res.sqi, 0);
      expect(res.qrsWidthMs, isNull);
      expect(res.qtcMs, isNull);
    });

    test(
      'extracts SQI and measures QRS complex from realistic 250 Hz signal',
      () {
        // Create a 250-sample buffer with baseline and a prominent QRS spike
        final samples = List<int>.filled(250, 20);
        // Insert an R-peak at sample 180 (peak 800, width ~20 samples = 80ms)
        for (int i = 170; i <= 190; i++) {
          samples[i] = (800 - (i - 180).abs() * 70).clamp(0, 800);
        }

        final morph = ClinicalSignalAnalysis.analyzeRawWaveform(
          samples,
          sampleRateHz: 250,
        );
        expect(morph.sqi, greaterThanOrEqualTo(50));
        expect(morph.qrsWidthMs, isNotNull);
        expect(morph.qrsWidthMs, inInclusiveRange(40, 160));
        expect(morph.qtcMs, isNotNull);
        expect(morph.prMs, inInclusiveRange(120, 200));
      },
    );
  });

  group('ClinicalSignalAnalysis.classifyRhythm', () {
    test('returns gathering when fewer than 5 RR intervals', () {
      final res = ClinicalSignalAnalysis.classifyRhythm(
        rrIntervals: [800, 810],
      );
      expect(res.rhythm, 'Gathering Stream...');
      expect(res.confidence, 0);
    });

    test('classifies Normal Sinus Rhythm (NSR) for regular intervals', () {
      final rrs = [750, 755, 748, 752, 750, 754, 751, 749];
      final res = ClinicalSignalAnalysis.classifyRhythm(
        rrIntervals: rrs,
        ecgHeartRates: [80, 80, 80],
        ppgPulseRates: [80, 80, 80],
      );
      expect(res.rhythm, contains('Normal Sinus Rhythm'));
      expect(res.severity, 'ok');
      expect(res.confidence, greaterThan(90));
    });

    test('detects Sinus Tachycardia when rate exceeds 100 BPM', () {
      final rrs = [540, 545, 538, 542, 540, 544];
      final res = ClinicalSignalAnalysis.classifyRhythm(
        rrIntervals: rrs,
        ecgHeartRates: [110, 111, 110],
        ppgPulseRates: [110, 110],
      );
      expect(res.rhythm, 'Sinus Tachycardia');
      expect(res.severity, 'warn');
    });

    test('detects Sinus Bradycardia when rate is below 60 BPM', () {
      final rrs = [1150, 1160, 1140, 1155, 1150];
      final res = ClinicalSignalAnalysis.classifyRhythm(
        rrIntervals: rrs,
        ecgHeartRates: [52, 52, 51],
        ppgPulseRates: [52, 52],
      );
      expect(res.rhythm, 'Sinus Bradycardia');
      expect(res.severity, 'warn');
    });

    test(
      'detects Motion Artifact when electrical HR diverges > 18 BPM from optical PPG',
      () {
        final rrs = [500, 490, 510, 495, 505];
        final res = ClinicalSignalAnalysis.classifyRhythm(
          rrIntervals: rrs,
          ecgHeartRates: [122, 120, 125], // ECG spiked
          ppgPulseRates: [76, 75, 77], // Optical PPG steady
        );
        expect(res.rhythm, contains('Motion Artifact'));
        expect(res.severity, 'warn');
        expect(res.finding, contains('Delta = 46 BPM'));
      },
    );
  });

  group('ClinicalSignalAnalysis.calculatePhysiologicalStrain', () {
    test('reports low strain under normal resting conditions', () {
      final strain = ClinicalSignalAnalysis.calculatePhysiologicalStrain(
        currentHr: 72,
        restingBaselineHr: 72,
        rmssdMs: 45,
      );
      expect(strain.driftDeltaHr, 0);
      expect(strain.psiScore, lessThan(3.5));
      expect(strain.hydrationStatus, 'Hydrated');
      expect(strain.autonomicTone, contains('Normal'));
    });

    test(
      'reports elevated strain under thermal load / cardiovascular drift',
      () {
        final strain = ClinicalSignalAnalysis.calculatePhysiologicalStrain(
          currentHr: 105,
          restingBaselineHr: 70,
          rmssdMs: 18,
        );
        expect(strain.driftDeltaHr, 35);
        expect(strain.psiScore, greaterThanOrEqualTo(6.5));
        expect(strain.hydrationStatus, contains('Dehydration'));
      },
    );
  });
}
