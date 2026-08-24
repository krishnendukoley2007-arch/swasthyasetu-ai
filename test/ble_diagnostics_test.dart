import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/ble_diagnostics.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';

/// What the diagnostics pass is allowed to claim.
///
/// The screen this feeds replaced eleven checks that walked to green on a timer
/// with no board attached. The single most important property here is the one
/// the old code could not satisfy at all: **an unreachable board never yields a
/// pass.** Everything else is a measurement, and a measurement that could not be
/// taken is reported as "not checked".

/// A [BleService] with no radio behind it.
///
/// Subclassed rather than mocked: the real class is a plain object with an inert
/// constructor, and overriding four members is less machinery than a mock and
/// fails to compile if the surface changes.
class _FakeBleService extends BleService {
  _FakeBleService({
    this.availability = BleLinkStatus.idle,
    BleLinkState link = const BleLinkState(),
  }) : _link = link;

  final BleLinkStatus availability;
  BleLinkState _link;

  final _telemetryOut = StreamController<TelemetryFrame>.broadcast();
  final _ecgOut = StreamController<EcgFrame>.broadcast();

  @override
  BleLinkState get state => _link;

  @override
  Stream<TelemetryFrame> get telemetry => _telemetryOut.stream;

  @override
  Stream<EcgFrame> get ecg => _ecgOut.stream;

  @override
  Future<BleLinkStatus> refreshAvailability() async => availability;

  void emit(TelemetryFrame frame) => _telemetryOut.add(frame);
  void emitEcg(EcgFrame frame) => _ecgOut.add(frame);

  /// Simulate the service noticing a gap in the ECG sequence numbers.
  void dropEcgFrames(int n) =>
      _link = _link.copyWith(droppedEcgFrames: _link.droppedEcgFrames + n);

  Future<void> close() async {
    await _telemetryOut.close();
    await _ecgOut.close();
  }
}

/// A streaming link, the precondition for anything past the first three checks.
const _streaming = BleLinkState(
  status: BleLinkStatus.streaming,
  deviceId: 'AA:BB:CC:DD:EE:01',
  deviceName: 'SwasthyaSetu-01',
  firmwareVersion: '1.0.0',
  hasEcgChannel: true,
);

TelemetryFrame frame({
  int heartRate = 72,
  int spo2 = 98,
  double temperatureC = 36.6,
  int battery = 85,
  bool plausible = true,
  bool leadOff = false,
  bool fingerOff = false,
}) =>
    TelemetryFrame(
      sample: HealthSample(
        timestamp: 1700000000000,
        heartRateBpm: heartRate,
        spo2Percent: spo2,
        temperatureC: temperatureC,
        ecgSignalQuality: 0.9,
        rPeakDetected: true,
        batteryPercent: battery,
      ),
      fallDetected: false,
      leadOff: leadOff,
      fingerOff: fingerOff,
      plausible: plausible,
      deviceUptimeMs: 120000,
    );

/// Run the pass over a short window and return the final report.
///
/// The window is 300 ms rather than the production six seconds so the suite
/// stays fast; [BleDiagnostics] computes the frame rate from a fractional second
/// precisely so a window this short still reports a real number.
Future<DiagnosticReport> runDiagnostics(
  // ignore: library_private_types_in_public_api - a test helper, not an API.
  _FakeBleService service, {
  Duration window = const Duration(milliseconds: 300),
  // ignore: library_private_types_in_public_api
  void Function(_FakeBleService)? during,
}) async {
  final reports = <DiagnosticReport>[];
  final done = BleDiagnostics()
      .run(service, window: window)
      .listen(reports.add)
      .asFuture<void>();

  if (during != null) {
    // After the subscriptions are attached inside the run, before the window
    // closes. Frames emitted before the listen would be lost on a broadcast
    // stream, which is exactly what a real board would experience too.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    during(service);
  }

  await done;
  return reports.last;
}

DiagnosticCheck check(DiagnosticReport report, String id) =>
    report.checks.firstWhere((c) => c.id == id);

void main() {
  group('BleDiagnostics with no radio', () {
    test('an unsupported phone fails the radio check and skips the rest',
        () async {
      final service = _FakeBleService(availability: BleLinkStatus.unsupported);
      final report = await runDiagnostics(service);

      expect(check(report, 'radio').outcome, DiagnosticOutcome.fail);
      // The property that matters: nothing downstream is allowed to pass.
      expect(report.passed, 0);
      expect(
        report.checks.where((c) => c.outcome == DiagnosticOutcome.pass),
        isEmpty,
      );
      await service.close();
    });

    test('Bluetooth switched off is a failure with an actionable reason',
        () async {
      final service = _FakeBleService(availability: BleLinkStatus.adapterOff);
      final report = await runDiagnostics(service);

      expect(check(report, 'radio').detail, contains('switched off'));
      expect(check(report, 'telemetry').outcome, DiagnosticOutcome.skipped);
      expect(check(report, 'telemetry').detail, contains('Turn Bluetooth on'));
      await service.close();
    });

    test('a denied permission is not reported as a missing radio', () async {
      final service =
          _FakeBleService(availability: BleLinkStatus.permissionDenied);
      final report = await runDiagnostics(service);

      expect(check(report, 'radio').detail, contains('permission'));
      expect(check(report, 'radio').detail, isNot(contains('no Bluetooth')));
      await service.close();
    });
  });

  group('BleDiagnostics with a radio but no board', () {
    test('every check past the radio is skipped, and none of them pass',
        () async {
      final service = _FakeBleService(availability: BleLinkStatus.idle);
      final report = await runDiagnostics(service);

      expect(check(report, 'radio').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'link').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'link').detail, contains('No board'));

      // This is the regression that motivated the whole file. The old screen
      // reported eleven passes in exactly this state.
      for (final id in [
        'services',
        'firmware',
        'telemetry',
        'plausible',
        'pulse',
        'temperature',
        'ecg-channel',
        'ecg-frames',
        'ecg-leads',
        'battery',
      ]) {
        expect(check(report, id).outcome, DiagnosticOutcome.skipped,
            reason: '$id must not resolve without a board');
      }
      expect(report.passed, 1);
      await service.close();
    });

    test('the summary says so instead of implying an all-clear', () async {
      final service = _FakeBleService();
      final report = await runDiagnostics(service);

      expect(report.isConclusive, isFalse);
      expect(report.summary, isNot(contains('All')));
      expect(report.summary, contains('failed'));
      await service.close();
    });

    test('a connecting link is not treated as a streaming one', () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.connecting,
        link: const BleLinkState(status: BleLinkStatus.connecting),
      );
      final report = await runDiagnostics(service);

      expect(check(report, 'link').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'link').detail, contains('not streaming'));
      await service.close();
    });
  });

  group('BleDiagnostics with a healthy board', () {
    test('frames arriving make the data checks pass with their measurements',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service, during: (s) {
        for (var i = 0; i < 3; i++) {
          s.emit(frame());
        }
        s.emitEcg(const EcgFrame(sequence: 1, samples: [1, 2, 3, 4]));
      });

      expect(check(report, 'link').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'firmware').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'telemetry').outcome, DiagnosticOutcome.pass);
      // The detail is the measurement, not a restatement of the check.
      expect(check(report, 'telemetry').detail, contains('3 frames'));
      expect(check(report, 'plausible').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'temperature').detail, contains('36.6'));
      expect(check(report, 'battery').detail, contains('85%'));
      expect(check(report, 'ecg-frames').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'ecg-frames').detail, contains('4 samples'));
      expect(report.failed, 0);
      await service.close();
    });

    test('a link with no frames on it fails rather than passing quietly',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service);

      expect(check(report, 'link').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'telemetry').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'telemetry').detail, contains('No vitals frames'));
      // Derived checks are skipped, not failed: there is nothing to inspect,
      // which is a different statement from "the sensor is broken".
      expect(check(report, 'plausible').outcome, DiagnosticOutcome.skipped);
      expect(check(report, 'temperature').outcome, DiagnosticOutcome.skipped);
      await service.close();
    });

    test('a board with no ECG channel fails that check and skips its children',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming.copyWith(hasEcgChannel: false),
      );
      final report = await runDiagnostics(service, during: (s) => s.emit(frame()));

      expect(check(report, 'ecg-channel').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'ecg-frames').outcome, DiagnosticOutcome.skipped);
      expect(check(report, 'ecg-leads').outcome, DiagnosticOutcome.skipped);
      await service.close();
    });
  });

  group('BleDiagnostics reports faults it can see', () {
    test('a finger off the sensor is named, not averaged away', () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service, during: (s) {
        s.emit(frame(fingerOff: true));
        s.emit(frame(fingerOff: true));
      });

      expect(check(report, 'pulse').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'pulse').detail, contains('Rest a finger'));
      await service.close();
    });

    test('electrodes off the skin fail the lead check', () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service,
          during: (s) => s.emit(frame(leadOff: true)));

      expect(check(report, 'ecg-leads').outcome, DiagnosticOutcome.fail);
      await service.close();
    });

    test('implausible readings fail even though the frames arrived', () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service, during: (s) {
        s.emit(frame());
        s.emit(frame(heartRate: 250, plausible: false));
      });

      expect(check(report, 'telemetry').outcome, DiagnosticOutcome.pass);
      expect(check(report, 'plausible').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'plausible').detail, contains('1 of 2'));
      await service.close();
    });

    test('a temperature outside the sensor range is not reported as a mean',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      // 5 °C is below BleProtocol.minTemperatureC — an open thermopile, not a
      // hypothermic patient.
      final report = await runDiagnostics(service,
          during: (s) => s.emit(frame(temperatureC: 5, plausible: false)));

      expect(check(report, 'temperature').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'temperature').detail, isNot(contains('Mean')));
      await service.close();
    });

    test('a flat battery reading is called out as an ADC fault', () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service,
          during: (s) => s.emit(frame(battery: 0)));

      expect(check(report, 'battery').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'battery').detail, contains('ADC'));
      await service.close();
    });

    test('a nearly-flat battery fails before a screening round, not after',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service,
          during: (s) => s.emit(frame(battery: 15)));

      expect(check(report, 'battery').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'battery').detail, contains('charge'));
      await service.close();
    });

    test('dropped ECG sequence numbers fail the stream check', () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming,
      );
      final report = await runDiagnostics(service, during: (s) {
        s.emit(frame());
        s.emitEcg(const EcgFrame(sequence: 1, samples: [1, 2]));
        s.dropEcgFrames(2);
        s.emitEcg(const EcgFrame(sequence: 4, samples: [3, 4]));
      });

      expect(check(report, 'ecg-frames').outcome, DiagnosticOutcome.fail);
      expect(check(report, 'ecg-frames').detail, contains('2 dropped'));
      await service.close();
    });

    test('unsupported firmware fails without stopping the rest of the pass',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming.copyWith(firmwareVersion: '9.0.0'),
      );
      final report = await runDiagnostics(service,
          during: (s) => s.emit(frame()));

      expect(check(report, 'firmware').outcome, DiagnosticOutcome.fail);
      // The link still works; the pass carries on and reports real data.
      expect(check(report, 'telemetry').outcome, DiagnosticOutcome.pass);
      await service.close();
    });

    test('a board that reports no version is skipped, not assumed compatible',
        () async {
      final service = _FakeBleService(
        availability: BleLinkStatus.streaming,
        link: _streaming.copyWith(firmwareVersion: 'UNKNOWN'),
      );
      final report = await runDiagnostics(service);

      expect(check(report, 'firmware').outcome, DiagnosticOutcome.skipped);
      await service.close();
    });
  });

  group('DiagnosticReport', () {
    test('a fresh report is neither running nor complete', () {
      const report = DiagnosticReport(checks: kDiagnosticChecks);
      expect(report.isRunning, isFalse);
      expect(report.isComplete, isFalse);
      expect(report.summary, 'Not run yet.');
    });

    test('conclusive requires no failures AND no skips', () {
      final allPass = kDiagnosticChecks
          .map((c) => c.copyWith(outcome: DiagnosticOutcome.pass))
          .toList();
      expect(DiagnosticReport(checks: allPass).isConclusive, isTrue);

      final oneSkipped = [
        ...allPass.sublist(1),
        allPass.first.copyWith(outcome: DiagnosticOutcome.skipped),
      ];
      expect(DiagnosticReport(checks: oneSkipped).isConclusive, isFalse);
      expect(DiagnosticReport(checks: oneSkipped).summary,
          contains('could not be checked'));
    });

    test('every catalogue id is unique, so a check cannot shadow another', () {
      final ids = kDiagnosticChecks.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('no check claims to identify a sensor IC by name', () {
      // Nothing in the protocol enumerates chips. If a check name ever names
      // one again, it is inventing a fact.
      const invented = ['MAX30102', 'MLX90614', 'AD8232', 'ESP32', 'I2C', 'OLED'];
      for (final c in kDiagnosticChecks) {
        for (final chip in invented) {
          expect(c.name.toUpperCase(), isNot(contains(chip)),
              reason: '${c.id} names a part the board never reports');
        }
      }
    });
  });
}
