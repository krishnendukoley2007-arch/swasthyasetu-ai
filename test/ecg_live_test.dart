import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/waveform_store.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/features/screening/screens/ecg_live_screen.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

import 'support/harness.dart';

/// What the ECG strip is allowed to claim.
///
/// This screen previously hardcoded `_isDemo = true`, drew a synthetic trace no
/// matter what the radio was doing, toggled an `_isRecording` flag that captured
/// nothing, and answered "Save Strip" with a snackbar reading "ECG strip saved to
/// screening" while writing nothing anywhere. The properties below are the ones
/// that failure mode could not satisfy:
///
///  * the badge follows the link, not a constant;
///  * a strip only exists once samples arrive;
///  * every reading under the strip is derived from those samples;
///  * saving either persists the recording or says why it cannot.

/// A [BleService] with no radio behind it.
///
/// Subclassed rather than mocked, matching `ble_diagnostics_test.dart`: the real
/// class is a plain object with an inert constructor, so overriding four members
/// is less machinery than a mock and stops compiling if the surface changes.
class _FakeBleService extends BleService {
  _FakeBleService({BleLinkState link = const BleLinkState()}) : _link = link;

  BleLinkState _link;
  final _stateOut = StreamController<BleLinkState>.broadcast();
  final _ecgOut = StreamController<EcgFrame>.broadcast();

  @override
  BleLinkState get state => _link;

  @override
  Stream<BleLinkState> get states => _stateOut.stream;

  @override
  Stream<EcgFrame> get ecg => _ecgOut.stream;

  @override
  Future<BleLinkStatus> refreshAvailability() async => _link.status;

  void emitEcg(EcgFrame frame) => _ecgOut.add(frame);

  void emitLink(BleLinkState link) {
    _link = link;
    _stateOut.add(link);
  }

  @override
  Future<void> dispose() async {
    await _stateOut.close();
    await _ecgOut.close();
  }
}

const _streaming = BleLinkState(
  status: BleLinkStatus.streaming,
  deviceId: 'AA:BB:CC:DD:EE:01',
  deviceName: 'SwasthyaSetu-01',
  firmwareVersion: '1.0.0',
  hasEcgChannel: true,
);

final _patient = Patient(
  id: 'p1',
  name: 'Rukhsana Bibi',
  age: 54,
  sex: 'F',
  location: 'Bishnupur ward 4',
  createdAt: DateTime(2026, 1, 1),
);

final _realDevice = Device(
  id: 'AA:BB:CC:DD:EE:01',
  name: 'SwasthyaSetu-01',
  macAddress: 'AA:BB:CC:DD:EE:01',
  batteryPercent: 82,
  isConnected: true,
  lastConnectedAt: DateTime(2026, 8, 24),
  isDemo: false,
);

/// A [WaveformStore] that records the call instead of writing to disk.
///
/// The real one compresses to the app documents directory through
/// `path_provider`, which has no implementation under `flutter test`, so the
/// already-saved branch could not otherwise be exercised at all.
class _RecordingWaveformStore extends WaveformStore {
  _RecordingWaveformStore(super.db, {this.fail = false});

  final bool fail;
  final calls = <Map<String, Object?>>[];

  @override
  Future<WaveformSaveResult> save({
    required String screeningId,
    required String type,
    required List<int> samples,
    required int durationMs,
    int sampleRate = WaveformStore.defaultSampleRate,
    bool isEnvelope = false,
  }) async {
    calls.add({
      'screeningId': screeningId,
      'type': type,
      'samples': samples.length,
      'durationMs': durationMs,
      'sampleRate': sampleRate,
    });
    if (fail) throw StateError('disk full');
    return WaveformSaveResult(
      fileName: '$screeningId-$type.gz',
      rawBytes: samples.length * 2,
      storedBytes: samples.length,
    );
  }
}

/// One second of board-shaped ECG: signed counts centred near zero, on a scale
/// the app is never told.
///
/// Deliberately not the app's own generator output. The old painter divided every
/// sample by a fixed 2047 and the old QRS measurement subtracted a fixed 1024
/// baseline, both of which are only correct for the synthetic trace — a signal
/// like this one went off the canvas and measured no QRS at all.
///
/// [bpm] must divide 250 Hz into a whole number of samples so the expected
/// interval is exact and peak detection has no rounding slack to hide in.
EcgFrame _beats(int sequence, {int count = 250, double bpm = 75}) {
  final period = 60 / bpm;
  final samples = List<int>.filled(count, 0);
  for (var i = 0; i < count; i++) {
    final t = (sequence * count + i) / BleProtocol.ecgSampleRateHz;
    final phase = t % period;
    var mv = 0.0;
    mv += 1.00 * exp(-0.5 * pow((phase - 0.400) / 0.010, 2)); // R
    mv += -0.18 * exp(-0.5 * pow((phase - 0.438) / 0.009, 2)); // S
    mv += 0.25 * exp(-0.5 * pow((phase - 0.600) / 0.045, 2)); // T
    samples[i] = (mv * 900 - 40).round();
  }
  return EcgFrame(sequence: sequence, samples: samples);
}

Future<TestHarness> _harness(
  _FakeBleService service, {
  Patient? patient,
  Device? device,
  bool fakeStore = false,
  bool storeFails = false,
}) async {
  final harness = await TestHarness.create(
    overrides: [
      bleServiceProvider.overrideWithValue(service),
      if (fakeStore)
        waveformStoreProvider.overrideWith((ref) => _RecordingWaveformStore(
              ref.watch(databaseProvider),
              fail: storeFails,
            )),
    ],
  );
  if (patient != null) {
    harness.container
        .read(screeningDraftProvider.notifier)
        .begin(patient: patient, device: device);
  }
  return harness;
}

/// Feed [frames] one-second chunks, rebuilding between each.
Future<void> _stream(
  WidgetTester tester,
  _FakeBleService service,
  int frames, {
  double bpm = 75,
}) async {
  for (var i = 0; i < frames; i++) {
    service.emitEcg(_beats(i, bpm: bpm));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Scroll [finder] into view and tap it.
///
/// The controls sit below the fold on a 360×640 screen — which is the point of
/// the body being scrollable — so a bare `tap` lands outside the viewport.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Let a dialog transition finish without waiting for the app to go quiet.
///
/// `pumpAndSettle` cannot be used on this screen in demo mode: the generator
/// ticks every 200 ms for as long as the screen is mounted, so the tree never
/// settles and the call would spin until its timeout.
Future<void> _settleDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The reading shown under [label] in the measurements panel, as plain text.
///
/// The value and its unit are one [RichText] so the unit can be styled down, and
/// `find.text` does not see into those — this reads the span instead.
String _reading(WidgetTester tester, String label) {
  final column =
      find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  for (final rich in tester.widgetList<RichText>(
    find.descendant(of: column, matching: find.byType(RichText)),
  )) {
    final plain = rich.text.toPlainText();
    if (plain != label) return plain;
  }
  fail('no reading rendered under "$label"');
}

const _readings = [
  'Heart Rate',
  'RR Interval',
  'QRS Duration',
  'Beats Detected',
  'RR Scatter',
];

void main() {
  group('provenance', () {
    testWidgets('no board streaming reads DEMO, and says the trace is generated',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService();
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('DEMO'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      expect(
        find.textContaining('generated by the app'),
        findsOneWidget,
        reason: 'a synthetic trace has to say so on the strip, not only in a '
            'three-letter badge',
      );
      expect(
        find.textContaining('not a measurement'),
        findsOneWidget,
        reason: 'the header used to claim a 0.5-40 Hz filter for this trace',
      );
    });

    testWidgets('a streaming board with an ECG channel reads LIVE',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await tester.pump();

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('DEMO'), findsNothing);
      expect(find.textContaining('SwasthyaSetu-01'), findsOneWidget);
      expect(find.textContaining('generated by the app'), findsNothing);
    });

    testWidgets('a connected board with no ECG channel is not LIVE',
        (tester) async {
      await tester.useSmallPhone();
      // The distinction a status badge alone cannot make: the link is up, but
      // nothing will ever arrive on it, so LIVE over an empty strip would be a
      // claim the worker has no way to see through.
      final service = _FakeBleService(
        link: _streaming.copyWith(hasEcgChannel: false),
      );
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await tester.pump();

      expect(find.text('DEMO'), findsOneWidget);
    });

    testWidgets('losing the board mid-session switches the strip to generated',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 2);
      expect(find.text('LIVE'), findsOneWidget);

      service.emitLink(const BleLinkState(status: BleLinkStatus.idle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('DEMO'), findsOneWidget);
      expect(find.textContaining('generated by the app'), findsOneWidget);
    });
  });

  group('measurements', () {
    testWidgets('every reading is an em dash until signal arrives',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await tester.pump();

      expect(find.textContaining('Waiting for ECG frames'), findsOneWidget);
      expect(find.text('NO SIGNAL'), findsOneWidget);
      // The old screen showed a rate computed off its own generator no matter
      // what the radio was doing.
      for (final label in _readings) {
        expect(_reading(tester, label), '—', reason: '$label was not measured');
      }
      expect(find.text('Not classified'), findsOneWidget);
    });

    testWidgets('derives rate, interval and rhythm from the frames it was sent',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 5, bpm: 75);

      expect(find.textContaining('Waiting for ECG frames'), findsNothing);
      // 75 bpm at 250 Hz is exactly 200 samples between R waves.
      expect(_reading(tester, 'Heart Rate'), '75 BPM');
      expect(_reading(tester, 'RR Interval'), '800 ms');
      expect(_reading(tester, 'RR Scatter'), '0 ms');
      expect(_reading(tester, 'Beats Detected'), '5 in 4.0 s');
      // A QRS measured off a signed trace. The old code subtracted a hardcoded
      // 1024 baseline, so the amplitude came out negative here and the reading
      // was always '—'.
      expect(_reading(tester, 'QRS Duration'), endsWith(' ms'));
      expect(_reading(tester, 'QRS Duration'), isNot('—'));

      expect(find.text('GOOD QUALITY'), findsOneWidget);
      expect(find.text('Regular rhythm'), findsOneWidget);
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('calls a fast rhythm fast', (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 5, bpm: 120);

      expect(_reading(tester, 'Heart Rate'), '120 BPM');
      expect(find.text('Fast rhythm'), findsOneWidget);
    });

    testWidgets('a flat channel reports no signal rather than a rate',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      for (var i = 0; i < 5; i++) {
        service.emitEcg(EcgFrame(sequence: i, samples: List.filled(250, -40)));
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(find.text('NO SIGNAL'), findsOneWidget);
      for (final label in _readings) {
        expect(_reading(tester, label), '—');
      }
    });

    testWidgets('electrodes off the skin is stated above the strip',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming.copyWith(leadOff: true));
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 3);

      expect(find.textContaining('electrodes are off the skin'), findsOneWidget);
      // Still LIVE — the samples are real, they are just not cardiac.
      expect(find.text('LIVE'), findsOneWidget);
    });
  });

  group('recording', () {
    testWidgets('counts the samples it captured', (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service, patient: _patient);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 2);

      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 3);

      // Three one-second frames arrived while recording, and the count says so.
      // The old button flipped a boolean and captured nothing.
      expect(find.textContaining('750 samples'), findsOneWidget);

      await _tap(tester, find.text('Stop recording'));
      expect(find.textContaining('3.0 s recorded (measured)'), findsOneWidget);
    });

    testWidgets('samples that arrived before recording are not counted in',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service, patient: _patient);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 4);
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 1);
      await _tap(tester, find.text('Stop recording'));

      // The rolling window held four seconds; the strip is the one second asked
      // for. Saving the window instead would attach a trace the worker never
      // chose to record.
      expect(find.textContaining('1.0 s recorded'), findsOneWidget);
      await _tap(tester, find.text('Save strip'));
      expect(harness.container.read(screeningDraftProvider).ecgSamples.length, 250);
    });

    testWidgets('reports a link drop during a recording as a gap',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service, patient: _patient);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 1);
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 1);

      service.emitLink(const BleLinkState(status: BleLinkStatus.reconnecting));
      await tester.pump();

      expect(
        find.textContaining('link dropped during this recording'),
        findsOneWidget,
      );
      // Pinned to the source it started on: the generator must not quietly fill
      // the gap in a buffer the save note will describe as measured.
      expect(find.textContaining(', generated'), findsNothing);
      expect(
        find.text('Stop recording'),
        findsOneWidget,
        reason: 'a dropped link must not leave Stop unpressable',
      );

      await _tap(tester, find.text('Stop recording'));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('surfaces frames lost in transit', (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service, patient: _patient);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 1);

      service.emitLink(_streaming.copyWith(droppedEcgFrames: 4));
      await tester.pump();

      expect(
        find.textContaining('4 ECG frames lost in transit'),
        findsOneWidget,
      );
    });

    testWidgets('lead switching is refused while a board is streaming',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await tester.pump();

      // The screen used to offer three leads over a single-channel stream and
      // relabel the same trace when one was picked.
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();

      expect(find.text('Lead II'), findsNothing);
      expect(find.textContaining('no lead-select command'), findsOneWidget);
    });

    testWidgets('lead switching on the generated trace clears the strip',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService();
      final harness = await _harness(service);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Lead I'), findsNothing); // header names it inline
      expect(find.textContaining('Generated Lead I •'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await _settleDialog(tester);
      await tester.tap(find.text('Lead III').last);
      await tester.pump();

      expect(find.textContaining('Generated Lead III •'), findsOneWidget);
      // Each lead has its own morphology; leaving the previous lead's samples on
      // the strip would attribute them to the new one.
      expect(find.textContaining('Starting the generated trace'), findsOneWidget);
      for (final label in _readings) {
        expect(_reading(tester, label), '—');
      }
    });
  });

  group('saving', () {
    testWidgets('refuses with a reason when nothing was recorded',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service, patient: _patient);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 2);

      expect(find.textContaining('Nothing recorded yet'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save strip'))
            .onPressed,
        isNull,
      );

      await _tap(tester, find.text('Save strip'));

      // The old handler answered this exact state with "ECG strip saved to
      // screening".
      expect(find.textContaining('saved'), findsNothing);
      expect(harness.container.read(screeningDraftProvider).ecgSamples, isEmpty);
    });

    testWidgets('refuses with a reason when there is no patient',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service); // no draft started

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _stream(tester, service, 1);
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 1);
      await _tap(tester, find.text('Stop recording'));

      expect(find.textContaining('No screening in progress'), findsOneWidget);
    });

    testWidgets('refuses while the recording is still running', (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(service, patient: _patient);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 2);

      expect(find.textContaining('Stop the recording before saving'),
          findsOneWidget);
      expect(harness.container.read(screeningDraftProvider).ecgSamples, isEmpty);
    });

    testWidgets('a measured strip lands in the draft at the real rate',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness =
          await _harness(service, patient: _patient, device: _realDevice);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 3);
      await _tap(tester, find.text('Stop recording'));

      await _tap(tester, find.text('Save strip'));

      final draft = harness.container.read(screeningDraftProvider);
      expect(draft.ecgSamples.length, 750);
      expect(draft.ecgSampleRate, BleProtocol.ecgSampleRateHz);
      expect(
        draft.isDemoDevice,
        isFalse,
        reason: 'a measured strip must not mark the screening as a demo',
      );
      // The confirmation quotes what was written rather than a fixed sentence.
      expect(find.textContaining('3.0 s (750 samples at 250 Hz)'), findsOneWidget);
      expect(find.textContaining('Rukhsana Bibi'), findsOneWidget);
    });

    testWidgets('a generated strip needs confirming and forces demo',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(); // no board
      // A real device, so the draft starts out claiming to be a measurement.
      final harness =
          await _harness(service, patient: _patient, device: _realDevice);
      expect(harness.container.read(screeningDraftProvider).isDemoDevice, isFalse);

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await tester.pump(const Duration(seconds: 2));
      await _tap(tester, find.text('Stop recording'));

      await _tap(tester, find.text('Save strip'));
      await _settleDialog(tester);
      expect(find.text('Attach a generated strip?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await _settleDialog(tester);
      expect(
        harness.container.read(screeningDraftProvider).ecgSamples,
        isEmpty,
        reason: 'cancelling has to leave the record untouched',
      );

      await _tap(tester, find.text('Save strip'));
      await _settleDialog(tester);
      await tester.tap(find.text('Attach as demo'));
      await _settleDialog(tester);

      final draft = harness.container.read(screeningDraftProvider);
      expect(draft.ecgSamples, isNotEmpty);
      expect(
        draft.isDemoDevice,
        isTrue,
        reason: 'a generated waveform on a real device still makes the whole '
            'screening a demo',
      );
      expect(find.textContaining('marked as a demo'), findsOneWidget);
    });

    testWidgets('will not attach a generated strip to a saved screening',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService();
      final harness = await _harness(service, patient: _patient);
      harness.container.read(screeningDraftProvider.notifier).markSaved('s1');

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await tester.pump(const Duration(seconds: 2));
      await _tap(tester, find.text('Stop recording'));

      // The stored row cannot be re-flagged as a demo from this screen, so the
      // only honest answer is to refuse.
      expect(find.textContaining('already recorded'), findsOneWidget);
    });

    testWidgets('a measured strip on a saved screening is written to the blob',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(
        service,
        patient: _patient,
        device: _realDevice,
        fakeStore: true,
      );
      // Once the row exists the draft is no longer what gets written, so the
      // strip has to reach the store directly or it is lost.
      harness.container.read(screeningDraftProvider.notifier).markSaved('s1');

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 2);
      await _tap(tester, find.text('Stop recording'));
      await _tap(tester, find.text('Save strip'));
      await tester.pump();

      final store =
          harness.container.read(waveformStoreProvider) as _RecordingWaveformStore;
      expect(store.calls, hasLength(1));
      expect(store.calls.single, {
        'screeningId': 's1',
        'type': 'ecg',
        'samples': 500,
        'durationMs': 2000,
        'sampleRate': 250,
      });
      expect(
        find.textContaining('written to the saved screening'),
        findsOneWidget,
      );
    });

    testWidgets('a failed write says so instead of claiming success',
        (tester) async {
      await tester.useSmallPhone();
      final service = _FakeBleService(link: _streaming);
      final harness = await _harness(
        service,
        patient: _patient,
        device: _realDevice,
        fakeStore: true,
        storeFails: true,
      );
      harness.container.read(screeningDraftProvider.notifier).markSaved('s1');

      await tester.pumpWidget(harness.wrapRouted(() => const EcgLiveScreen()));
      await _tap(tester, find.text('Record strip'));
      await _stream(tester, service, 2);
      await _tap(tester, find.text('Stop recording'));
      await _tap(tester, find.text('Save strip'));
      await tester.pump();

      // The whole point of the rewrite: the screen reports what happened.
      expect(find.textContaining('Could not write the strip'), findsOneWidget);
      expect(find.textContaining('disk full'), findsOneWidget);
      expect(find.textContaining('written to the saved screening'), findsNothing);
    });
  });
}
