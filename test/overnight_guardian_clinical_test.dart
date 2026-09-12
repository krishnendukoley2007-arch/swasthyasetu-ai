import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/domain/rules/overnight_analysis_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

HealthSample createSample({
  int hr = 72,
  int spo2 = 98,
  double temp = 36.6,
  int rr = 833,
  double ecgQuality = 0.95,
}) => HealthSample(
  timestamp: 0,
  heartRateBpm: hr,
  spo2Percent: spo2,
  temperatureC: temp,
  rrIntervalMs: rr,
  ecgSignalQuality: ecgQuality,
  rPeakDetected: true,
  batteryPercent: 90,
);

void main() {
  group('BLE Dual Mode Protocol Mandate', () {
    test(
      'setModeDualCommand transmits opcode 0x04 with duration 0 (continuous)',
      () {
        final cmd = BleProtocol.setModeDualCommand;
        expect(cmd, equals([0x04, 0x00, 0x00]));
      },
    );

    test('buildModeCommand generates valid continuous dual command bytes', () {
      final cmd = BleProtocol.buildModeCommand(4, durationSec: 0);
      expect(cmd, equals([0x04, 0x00, 0x00]));
    });

    test('isModePlausible validates sysState 4 (Dual Continuous Mode)', () {
      final frame = TelemetryFrame(
        sample: createSample(hr: 72, spo2: 98),
        fallDetected: false,
        leadOff: false,
        fingerOff: false,
        plausible: true,
        deviceUptimeMs: 12000,
        sysState: 4,
      );

      expect(frame.isModePlausible, isTrue);
    });

    test(
      'isModePlausible allows valid vitals if either ECG or SpO2 has valid contact in Dual Mode',
      () {
        // Finger off optical sensor, but ECG lead is on with plausible HR
        final frameEcgOnly = TelemetryFrame(
          sample: createSample(hr: 78, spo2: 0, rr: 769),
          fallDetected: false,
          leadOff: false,
          fingerOff: true,
          plausible: true,
          deviceUptimeMs: 25000,
          sysState: 4,
        );
        expect(frameEcgOnly.isModePlausible, isTrue);

        // Lead off ECG, but finger is on pulse oximeter with plausible SpO2
        final frameSpo2Only = TelemetryFrame(
          sample: createSample(hr: 0, spo2: 97, rr: 0),
          fallDetected: false,
          leadOff: true,
          fingerOff: false,
          plausible: true,
          deviceUptimeMs: 30000,
          sysState: 4,
        );
        expect(frameSpo2Only.isModePlausible, isTrue);
      },
    );
  });

  group('OvernightDataPoint & Multi-Sensor Contact Invariants', () {
    final now = DateTime.now();

    test('validates contact correctly when both sensors are active', () {
      final point = OvernightDataPoint(
        timestamp: now,
        heartRate: 68,
        spo2: 97.5,
        leadOff: false,
        fingerOff: false,
      );
      expect(point.hasValidHr, isTrue);
      expect(point.hasValidSpo2, isTrue);
      expect(point.isValidContact, isTrue);
    });

    test('validates contact when only pulse oximeter is attached', () {
      final point = OvernightDataPoint(
        timestamp: now,
        heartRate: 70,
        spo2: 98.0,
        leadOff: true,
        fingerOff: false,
      );
      expect(point.hasValidHr, isTrue);
      expect(point.hasValidSpo2, isTrue);
      expect(point.isValidContact, isTrue);
    });

    test('validates contact when only ECG electrodes are attached', () {
      final point = OvernightDataPoint(
        timestamp: now,
        heartRate: 64,
        spo2: 0.0,
        leadOff: false,
        fingerOff: true,
      );
      expect(point.hasValidHr, isTrue);
      expect(point.hasValidSpo2, isFalse);
      expect(point.isValidContact, isTrue);
    });

    test('identifies invalid contact when both sensors are detached', () {
      final point = OvernightDataPoint(
        timestamp: now,
        heartRate: 0,
        spo2: 0.0,
        leadOff: true,
        fingerOff: true,
      );
      expect(point.hasValidHr, isFalse);
      expect(point.hasValidSpo2, isFalse);
      expect(point.isValidContact, isFalse);
    });
  });

  group('OvernightAnalysisEngine Clinical Analysis', () {
    test(
      'computes proper metrics and detects nocturnal dipping on real session data',
      () {
        final baseTime = DateTime(2026, 9, 12, 23, 0);
        final points = <OvernightDataPoint>[];

        // Simulate a 30-minute nocturnal recording (1 sample per 10s = 180 points)
        for (int i = 0; i < 180; i++) {
          final t = baseTime.add(Duration(seconds: i * 10));
          // Normal nocturnal dip: baseline 80 dips to ~62
          final hr = (80 - 18 * (i / 180)).round();
          // SpO2 steady around 97%, with a transient dip to 88% around point 90
          final isDip = i >= 90 && i <= 95;
          final spo2 = isDip ? 88.0 : 97.5;

          points.add(
            OvernightDataPoint(
              timestamp: t,
              heartRate: hr,
              spo2: spo2,
              rrIntervalMs: (60000 / hr).round(),
              leadOff: false,
              fingerOff: false,
            ),
          );
        }

        final report = OvernightAnalysisEngine.analyze(
          points,
          baselineDaytimeHr: 80,
        );

        expect(report.totalDuration.inMinutes, equals(29));
        expect(report.validContactDuration.inMinutes, greaterThanOrEqualTo(28));
        expect(report.meanSleepHr, lessThan(75));
        expect(report.nocturnalDipPercent, greaterThan(10.0));
        expect(report.lowestSpo2, equals(88.0));
        expect(report.events, isNotEmpty);
        expect(
          report.events.any(
            (e) =>
                e.type == OvernightIssueType.hypoxia ||
                e.type == OvernightIssueType.desaturation,
          ),
          isTrue,
        );
      },
    );

    test(
      'analyzes pulse oximeter-only sessions without zero-value failure',
      () {
        final baseTime = DateTime(2026, 9, 12, 23, 0);
        final points = <OvernightDataPoint>[];

        for (int i = 0; i < 60; i++) {
          points.add(
            OvernightDataPoint(
              timestamp: baseTime.add(Duration(seconds: i * 10)),
              heartRate: 72,
              spo2: 98.0,
              leadOff: true, // ECG detached
              fingerOff: false, // Pulse oximeter firmly attached
            ),
          );
        }

        final report = OvernightAnalysisEngine.analyze(points);
        expect(report.meanSleepHr, equals(72));
        expect(report.meanSpo2, equals(98.0));
        expect(report.validContactDuration.inSeconds, greaterThan(0));
      },
    );
  });

  group('OfflineExplainer Clinical Question Answering', () {
    final sample = createSample(hr: 108, spo2: 93, temp: 38.6, rr: 555);
    final assessment = RiskEngine.assess(sample: sample, symptoms: const []);

    test('answers heart rate and ECG questions with clinical context', () {
      final ans = OfflineExplainer.answerClinicalQuestion(
        assessment: assessment,
        question: 'What is my heart rate and is my ECG rhythm dangerous?',
      );
      expect(ans, contains('Heart Rate'));
      expect(ans, contains('108 BPM'));
      expect(ans, contains('Tachycardia'));
    });

    test('answers oxygen and SpO2 questions with WHO thresholds', () {
      final ans = OfflineExplainer.answerClinicalQuestion(
        assessment: assessment,
        question: 'Is my oxygen level too low?',
      );
      expect(ans, contains('SpO2'));
      expect(ans, contains('93%'));
      expect(ans, contains('Desaturation'));
    });

    test('answers fever and temperature questions with cooling guidelines', () {
      final ans = OfflineExplainer.answerClinicalQuestion(
        assessment: assessment,
        question: 'I have a high fever, what should I do?',
      );
      expect(ans, contains('Temperature'));
      expect(ans, contains('38.6°C'));
      expect(ans, contains('Pyrexia'));
      expect(ans, contains('hydration'));
    });

    test(
      'answers emergency and hospital referral questions with red flags',
      () {
        final ans = OfflineExplainer.answerClinicalQuestion(
          assessment: assessment,
          question: 'Should I go to the emergency hospital immediately?',
        );
        expect(ans, contains('Warning Signs'));
        expect(ans, contains('Escalation'));
      },
    );

    test(
      'chatFallback provides targeted guidance even when online AI is disconnected',
      () {
        final fallback = OfflineExplainer.chatFallback(
          question: 'Tell me about my heart rate and pulse',
        );
        expect(fallback, contains('Cardiac & Pulse Guidance'));
        expect(fallback, contains('60–100 BPM'));
      },
    );
  });
}
