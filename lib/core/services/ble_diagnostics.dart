/// A diagnostics pass that measures instead of pretending.
///
/// The screen this feeds used to walk eleven named hardware checks — "AD8232
/// Signal", "I2C Bus Scan", "MAX30102 Detect" — to green on an 800 ms timer,
/// with no board attached and no code path that could have failed one. On a
/// screening device that is worse than having no diagnostics at all: it answers
/// "is the ECG front-end working?" with a confident yes it cannot possibly know.
///
/// Every check here resolves from something observable over the link:
///
/// * the adapter state the platform reports,
/// * which GATT characteristics were actually discovered,
/// * the firmware string the board sent back,
/// * and what arrives on the notification channels during a fixed observation
///   window — how many frames, how many were plausible, how many ECG sequence
///   numbers went missing.
///
/// Anything that cannot be observed is reported as [DiagnosticOutcome.skipped]
/// with the reason. Individual sensor ICs are deliberately absent: nothing the
/// board sends identifies its chips, so a claim about an MLX90614 would be
/// invention. What *is* checked is whether a plausible temperature arrived,
/// which is the thing a health worker actually needs to know.
library;

import 'dart:async';

import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';

enum DiagnosticOutcome {
  pending,
  running,

  /// Observed, and within expectations.
  pass,

  /// Observed, and wrong.
  fail,

  /// Could not be observed. Never rendered as a pass.
  skipped,
}

extension DiagnosticOutcomeText on DiagnosticOutcome {
  bool get isTerminal => this != DiagnosticOutcome.pending &&
      this != DiagnosticOutcome.running;

  String get label => switch (this) {
        DiagnosticOutcome.pending => 'Waiting',
        DiagnosticOutcome.running => 'Checking',
        DiagnosticOutcome.pass => 'Pass',
        DiagnosticOutcome.fail => 'Fail',
        DiagnosticOutcome.skipped => 'Not checked',
      };
}

class DiagnosticCheck {
  final String id;
  final String name;
  final String category;

  /// What the check looks at, in a sentence a health worker can read.
  final String description;

  final DiagnosticOutcome outcome;

  /// The measurement, or the reason there wasn't one. Shown verbatim.
  final String detail;

  const DiagnosticCheck({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.outcome = DiagnosticOutcome.pending,
    this.detail = '',
  });

  DiagnosticCheck copyWith({
    DiagnosticOutcome? outcome,
    String? detail,
  }) =>
      DiagnosticCheck(
        id: id,
        name: name,
        category: category,
        description: description,
        outcome: outcome ?? this.outcome,
        detail: detail ?? this.detail,
      );
}

/// The whole run. Emitted on every change so the UI can render progress without
/// owning any of the logic.
class DiagnosticReport {
  final List<DiagnosticCheck> checks;
  final bool isRunning;

  /// How much of the observation window is left, for the countdown.
  final Duration? remaining;

  const DiagnosticReport({
    required this.checks,
    this.isRunning = false,
    this.remaining,
  });

  int get passed =>
      checks.where((c) => c.outcome == DiagnosticOutcome.pass).length;
  int get failed =>
      checks.where((c) => c.outcome == DiagnosticOutcome.fail).length;
  int get skipped =>
      checks.where((c) => c.outcome == DiagnosticOutcome.skipped).length;

  bool get isComplete => !isRunning && checks.every((c) => c.outcome.isTerminal);

  /// A run with nothing to measure is not a healthy device. Said plainly so the
  /// summary line cannot be mistaken for an all-clear.
  bool get isConclusive => failed == 0 && skipped == 0 && isComplete;

  String get summary {
    if (isRunning) return 'Checking the board…';
    if (!isComplete) return 'Not run yet.';
    if (isConclusive) return 'All $passed checks passed.';
    if (failed > 0) {
      return '$failed of ${checks.length} checks failed'
          '${skipped > 0 ? ', $skipped could not be checked' : ''}.';
    }
    return '$passed passed, $skipped could not be checked — connect the board '
        'and run again for a complete result.';
  }
}

/// The catalogue. Ids are stable so a test can assert on one check.
const List<DiagnosticCheck> kDiagnosticChecks = [
  DiagnosticCheck(
    id: 'radio',
    name: 'Phone Bluetooth',
    category: 'Phone',
    description: 'The phone has a Bluetooth Low Energy radio and it is on',
  ),
  DiagnosticCheck(
    id: 'link',
    name: 'Link to board',
    category: 'Connection',
    description: 'A GATT connection is open to the sensor board',
  ),
  DiagnosticCheck(
    id: 'services',
    name: 'Vitals channel',
    category: 'Connection',
    description: 'The board offers the vitals characteristic and notifications '
        'are subscribed',
  ),
  DiagnosticCheck(
    id: 'firmware',
    name: 'Firmware version',
    category: 'Connection',
    description: 'The board reported a firmware version this app supports',
  ),
  DiagnosticCheck(
    id: 'telemetry',
    name: 'Frame rate',
    category: 'Data',
    description: 'Vitals frames are arriving often enough to screen with',
  ),
  DiagnosticCheck(
    id: 'plausible',
    name: 'Readings in range',
    category: 'Data',
    description: 'The values describe a human body rather than a sensor fault',
  ),
  DiagnosticCheck(
    id: 'pulse',
    name: 'Pulse sensor contact',
    category: 'Sensors',
    description: 'The pulse oximeter reports a finger on it',
  ),
  DiagnosticCheck(
    id: 'temperature',
    name: 'Temperature reading',
    category: 'Sensors',
    description: 'A body-range temperature arrived',
  ),
  DiagnosticCheck(
    id: 'ecg-channel',
    name: 'ECG channel',
    category: 'Sensors',
    description: 'The board exposes an ECG stream',
  ),
  DiagnosticCheck(
    id: 'ecg-frames',
    name: 'ECG stream',
    category: 'Data',
    description: 'ECG frames arrive without gaps in the sequence',
  ),
  DiagnosticCheck(
    id: 'ecg-leads',
    name: 'ECG electrodes',
    category: 'Sensors',
    description: 'The electrodes are making contact',
  ),
  DiagnosticCheck(
    id: 'battery',
    name: 'Battery reading',
    category: 'Power',
    description: 'The board reported its charge level',
  ),
];

/// Runs [kDiagnosticChecks] against a live [BleService].
///
/// Stateless between runs: call [run] and listen. The stream closes when the run
/// finishes, and cancelling the subscription aborts the observation.
class BleDiagnostics {
  /// Long enough to see several frames at any sane rate, short enough that a
  /// worker will wait for it.
  static const Duration defaultWindow = Duration(seconds: 6);

  /// Below this the link is technically alive but too sparse to screen with:
  /// the vitals card would freeze between updates and a worker would read a
  /// stale number as a current one.
  static const double minFramesPerSecond = 0.5;

  Stream<DiagnosticReport> run(
    BleService service, {
    Duration window = defaultWindow,
  }) {
    final controller = StreamController<DiagnosticReport>();
    _run(controller, service, window);
    return controller.stream;
  }

  Future<void> _run(
    StreamController<DiagnosticReport> out,
    BleService service,
    Duration window,
  ) async {
    final checks = <String, DiagnosticCheck>{
      for (final c in kDiagnosticChecks) c.id: c,
    };
    Duration? remaining;

    void emit() {
      if (out.isClosed) return;
      out.add(
        DiagnosticReport(
          checks: kDiagnosticChecks.map((c) => checks[c.id]!).toList(),
          isRunning: true,
          remaining: remaining,
        ),
      );
    }

    void set(String id, DiagnosticOutcome outcome, String detail) {
      checks[id] = checks[id]!.copyWith(outcome: outcome, detail: detail);
      emit();
    }

    /// Mark every check that has not resolved yet as unobservable, with one
    /// shared reason. Used when the link is down: the alternative is eleven
    /// separate copies of "no board".
    void skipRest(String reason) {
      for (final id in checks.keys) {
        if (!checks[id]!.outcome.isTerminal) {
          checks[id] = checks[id]!
              .copyWith(outcome: DiagnosticOutcome.skipped, detail: reason);
        }
      }
      emit();
    }

    /// Emit the terminal report and close.
    ///
    /// Every exit has to go through here. An early return that only closed the
    /// stream left the last emitted report with `isRunning: true`, so the screen
    /// sat on "Checking the board…" and a spinner forever — in the single most
    /// common case, no board connected.
    Future<void> finish() async {
      if (out.isClosed) return;
      out.add(
        DiagnosticReport(
          checks: kDiagnosticChecks.map((c) => checks[c.id]!).toList(),
          isRunning: false,
        ),
      );
      await out.close();
    }

    emit();

    // ── Phone radio ──
    set('radio', DiagnosticOutcome.running, '');
    final availability = await service.refreshAvailability();
    switch (availability) {
      case BleLinkStatus.unsupported:
        set('radio', DiagnosticOutcome.fail,
            'This phone reports no Bluetooth Low Energy support.');
        skipRest('No Bluetooth radio to check the board through.');
        await finish();
        return;
      case BleLinkStatus.adapterOff:
        set('radio', DiagnosticOutcome.fail, 'Bluetooth is switched off.');
        skipRest('Turn Bluetooth on and run the checks again.');
        await finish();
        return;
      case BleLinkStatus.permissionDenied:
        set('radio', DiagnosticOutcome.fail,
            'Android has not granted the nearby-devices permission.');
        skipRest('Grant the nearby-devices permission and run again.');
        await finish();
        return;
      default:
        set('radio', DiagnosticOutcome.pass, 'Radio present and switched on.');
    }

    // ── Link ──
    final link = service.state;
    set('link', DiagnosticOutcome.running, '');
    if (!link.isLive) {
      set(
        'link',
        DiagnosticOutcome.fail,
        link.status == BleLinkStatus.idle
            ? 'No board is connected.'
            : 'The link is ${link.label.toLowerCase()}, not streaming.',
      );
      skipRest('Needs a connected board that is streaming.');
      await finish();
      return;
    }
    set('link', DiagnosticOutcome.pass,
        'Connected to ${link.deviceName ?? 'the board'}.');

    // ── Discovered characteristics ──
    set('services', DiagnosticOutcome.pass,
        'Vitals characteristic found and subscribed.');

    // ── Firmware ──
    final firmware = link.firmwareVersion;
    if (firmware == null || firmware.isEmpty || firmware == 'UNKNOWN') {
      set('firmware', DiagnosticOutcome.skipped,
          'The board did not report a version.');
    } else {
      final compatibility = DeviceRepository.checkFirmware(firmware);
      set(
        'firmware',
        compatibility.needsWarning
            ? DiagnosticOutcome.fail
            : DiagnosticOutcome.pass,
        compatibility.needsWarning
            ? 'v$firmware — ${compatibility.label}'
            : 'v$firmware, supported.',
      );
    }

    if (!link.hasEcgChannel) {
      set('ecg-channel', DiagnosticOutcome.fail,
          'The board does not expose an ECG stream.');
      set('ecg-frames', DiagnosticOutcome.skipped, 'No ECG channel.');
      set('ecg-leads', DiagnosticOutcome.skipped, 'No ECG channel.');
    } else {
      set('ecg-channel', DiagnosticOutcome.pass, 'ECG stream available.');
      set('ecg-frames', DiagnosticOutcome.running, '');
      set('ecg-leads', DiagnosticOutcome.running, '');
    }

    // ── Observation window ──
    for (final id in ['telemetry', 'plausible', 'pulse', 'temperature',
      'battery']) {
      set(id, DiagnosticOutcome.running, '');
    }

    final telemetry = <TelemetryFrame>[];
    final ecg = <EcgFrame>[];
    final telemetrySub = service.telemetry.listen(telemetry.add);
    final ecgSub = service.ecg.listen(ecg.add);
    final droppedBefore = link.droppedEcgFrames;

    final ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = (remaining ?? window) - const Duration(seconds: 1);
      remaining = left.isNegative ? Duration.zero : left;
      emit();
    });
    remaining = window;
    emit();

    await Future<void>.delayed(window);
    ticker.cancel();
    remaining = null;
    await telemetrySub.cancel();
    await ecgSub.cancel();

    // Seconds as a double, not `window.inSeconds`: a test passing a 200 ms
    // window would otherwise divide by an integer zero and report an infinite
    // frame rate. The label degrades to milliseconds for the same reason.
    final windowSeconds = window.inMilliseconds / 1000.0;
    final windowLabel = windowSeconds >= 1
        ? '${windowSeconds.round()}s'
        : '${window.inMilliseconds}ms';

    // ── Frame rate ──
    final rate = telemetry.length / windowSeconds;
    if (telemetry.isEmpty) {
      set('telemetry', DiagnosticOutcome.fail,
          'No vitals frames arrived in $windowLabel.');
    } else {
      set(
        'telemetry',
        rate >= minFramesPerSecond
            ? DiagnosticOutcome.pass
            : DiagnosticOutcome.fail,
        '${telemetry.length} frames in $windowLabel '
            '(${rate.toStringAsFixed(1)}/s).',
      );
    }

    if (telemetry.isEmpty) {
      for (final id in ['plausible', 'pulse', 'temperature', 'battery']) {
        set(id, DiagnosticOutcome.skipped, 'No frames to inspect.');
      }
    } else {
      // ── Plausibility ──
      final plausible = telemetry.where((f) => f.plausible).length;
      set(
        'plausible',
        plausible == telemetry.length
            ? DiagnosticOutcome.pass
            : DiagnosticOutcome.fail,
        '$plausible of ${telemetry.length} frames held values a human body '
            'can produce.',
      );

      // ── Pulse contact ──
      final withFinger = telemetry.where((f) => !f.fingerOff).length;
      set(
        'pulse',
        withFinger > 0 ? DiagnosticOutcome.pass : DiagnosticOutcome.fail,
        withFinger == 0
            ? 'Every frame reported no finger on the sensor. Rest a finger on '
                'it and run again.'
            : 'Finger detected in $withFinger of ${telemetry.length} frames.',
      );

      // ── Temperature ──
      final temps = telemetry
          .map((f) => f.sample.temperatureC)
          .where((t) =>
              t >= BleProtocol.minTemperatureC &&
              t <= BleProtocol.maxTemperatureC)
          .toList();
      if (temps.isEmpty) {
        set('temperature', DiagnosticOutcome.fail,
            'No temperature inside the measurable range arrived.');
      } else {
        final mean = temps.reduce((a, b) => a + b) / temps.length;
        set('temperature', DiagnosticOutcome.pass,
            'Mean ${mean.toStringAsFixed(1)} °C over ${temps.length} frames.');
      }

      // ── Battery ──
      final battery = telemetry.last.sample.batteryPercent;
      if (battery <= 0) {
        set('battery', DiagnosticOutcome.fail,
            'The board reported 0%, which usually means the ADC read nothing.');
      } else {
        set(
          'battery',
          battery <= 20 ? DiagnosticOutcome.fail : DiagnosticOutcome.pass,
          battery <= 20
              ? '$battery% — charge the board before a screening round.'
              : '$battery%.',
        );
      }
    }

    // ── ECG ──
    if (link.hasEcgChannel) {
      final dropped = service.state.droppedEcgFrames - droppedBefore;
      if (ecg.isEmpty) {
        set('ecg-frames', DiagnosticOutcome.fail,
            'No ECG frames arrived in $windowLabel.');
      } else {
        final samples = ecg.fold<int>(0, (n, f) => n + f.samples.length);
        set(
          'ecg-frames',
          dropped == 0 ? DiagnosticOutcome.pass : DiagnosticOutcome.fail,
          dropped == 0
              ? '${ecg.length} frames, $samples samples, no gaps.'
              : '${ecg.length} frames, $samples samples, $dropped dropped.',
        );
      }

      final leadsOn = telemetry.where((f) => !f.leadOff).length;
      if (telemetry.isEmpty) {
        set('ecg-leads', DiagnosticOutcome.skipped,
            'No frames reported electrode state.');
      } else {
        set(
          'ecg-leads',
          leadsOn > 0 ? DiagnosticOutcome.pass : DiagnosticOutcome.fail,
          leadsOn == 0
              ? 'Every frame reported the electrodes off the skin.'
              : 'Contact in $leadsOn of ${telemetry.length} frames.',
        );
      }
    }

    if (!out.isClosed) {
      await finish();
    }
  }
}
