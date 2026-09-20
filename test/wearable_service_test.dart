import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/wearable_service.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WearableService — Connection & State', () {
    test('initial state is disconnected with default preferences', () {
      final service = WearableService();
      final state = service.state;

      expect(state.status, WearableStatus.disconnected);
      expect(state.isConnected, isFalse);
      expect(state.vibrateOnCriticalTriage, isTrue);
      expect(state.vibrateOnArrhythmia, isTrue);
      expect(state.vibrateOnFall, isTrue);
      expect(state.isEmergencyAlertActive, isFalse);
    });

    test('connectToWearable updates device info and state', () async {
      final service = WearableService();
      await service.connectToWearable(
        deviceName: 'Pixel Watch 2',
        platform: WearablePlatform.wearOs,
        isDemo: false,
      );

      final state = service.state;
      expect(state.status, WearableStatus.connected);
      expect(state.isConnected, isTrue);
      expect(state.deviceName, 'Pixel Watch 2');
      expect(state.platform, WearablePlatform.wearOs);
      expect(state.isDemo, isFalse);
    });

    test(
      'disconnect clears connection and any active emergency alerts',
      () async {
        final service = WearableService();
        await service.connectToWearable();
        service.triggerWristAlert('Test alert');
        expect(service.state.isEmergencyAlertActive, isTrue);

        service.disconnect();
        expect(service.state.status, WearableStatus.disconnected);
        expect(service.state.isConnected, isFalse);
        expect(service.state.isEmergencyAlertActive, isFalse);
        expect(service.state.lastAlertReason, isNull);
      },
    );
  });

  group('WearableService — Mandate 2.3: No Fabricated Gaps (Em-dash)', () {
    test('missing or null vitals render strictly as em-dash', () {
      const emptySnapshot = WearableSnapshot(
        heartRate: null,
        spo2: null,
        temperature: null,
        sensorBoardBattery: null,
      );

      expect(emptySnapshot.heartRateText, '—');
      expect(emptySnapshot.spo2Text, '—');
      expect(emptySnapshot.temperatureText, '—');
      expect(emptySnapshot.sensorBatteryText, '—');
    });

    test('valid vitals render with their proper numerical units', () {
      const populatedSnapshot = WearableSnapshot(
        heartRate: 75,
        spo2: 98,
        temperature: 36.8,
        sensorBoardBattery: 85,
      );

      expect(populatedSnapshot.heartRateText, '75');
      expect(populatedSnapshot.spo2Text, '98%');
      expect(populatedSnapshot.temperatureText, '36.8°C');
      expect(populatedSnapshot.sensorBatteryText, '85%');
    });
  });

  group('WearableService — Mandate 2.1: One-Way Provenance (isDemo)', () {
    test('isDemo flag is strictly preserved during vitals updates', () {
      final service = WearableService();

      // Ingest live vitals
      service.updateFromVitals(heartRate: 70, spo2: 99, isDemo: false);
      expect(service.state.isDemo, isFalse);

      // Ingest simulated demo vitals
      service.updateFromVitals(heartRate: 140, spo2: 88, isDemo: true);
      expect(service.state.isDemo, isTrue);
    });
  });

  group('WearableService — Deterministic Triage & Emergency Alerts', () {
    test('normal vitals produce Green band without emergency alert', () {
      final service = WearableService();
      service.updateFromVitals(
        heartRate: 72,
        spo2: 98,
        temperature: 36.6,
        isDemo: false,
      );

      expect(service.state.triageBand, RiskBand.green);
      expect(service.state.isEmergencyAlertActive, isFalse);
    });

    test(
      'critical hypoxemia (SpO2 < 90) triggers RED band and emergency wrist alert',
      () {
        final service = WearableService();
        service.updateFromVitals(heartRate: 80, spo2: 86, isDemo: false);

        expect(service.state.triageBand, RiskBand.red);
        expect(service.state.isEmergencyAlertActive, isTrue);
        expect(service.state.lastAlertReason, contains('SpO2 86%'));
      },
    );

    test('critical tachycardia (HR > 130) triggers RED band and alert', () {
      final service = WearableService();
      service.updateFromVitals(heartRate: 145, spo2: 97, isDemo: false);

      expect(service.state.triageBand, RiskBand.red);
      expect(service.state.isEmergencyAlertActive, isTrue);
    });

    test(
      'dismissWristAlert silences active alert while keeping vitals intact',
      () {
        final service = WearableService();
        service.triggerWristAlert('Emergency warning');
        expect(service.state.isEmergencyAlertActive, isTrue);

        service.dismissWristAlert();
        expect(service.state.isEmergencyAlertActive, isFalse);
        expect(service.state.lastAlertReason, isNull);
      },
    );
  });

  group('WearableService — Smartwatch Baseline Sensor Ingestion', () {
    test(
      'updateWristSensorBaseline stores 24/7 resting HR and daily steps',
      () {
        final service = WearableService();
        service.updateWristSensorBaseline(
          restingHeartRate: 64,
          dailySteps: 8420,
        );

        expect(service.state.wristRestingHeartRate, 64);
        expect(service.state.restingHeartRateText, '64 bpm');
        expect(service.state.dailySteps, 8420);
        expect(service.state.dailyStepsText, '8420 steps');
      },
    );
  });
}
