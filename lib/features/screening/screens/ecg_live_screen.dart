import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/rules/ecg_classifier.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

/// Where the samples on the strip came from.
///
/// Exactly one of these is true at any moment, the window is emptied whenever it
/// changes, and a recording is pinned to the value it started with. Those three
/// rules together are what stop a strip from being half measured and half drawn.
enum _EcgSource { board, generated }

/// Beat-to-beat scatter, in ms, at which the signal is called unusable.
///
/// Picked so the quality bands land on 0.8 and 0.5 — 0.5 being where
/// [EcgClassifier] stops trusting a rhythm call. One constant, so the header
/// pill cannot read "GOOD QUALITY" while the rhythm underneath it is being
/// suppressed as too noisy to interpret.
const double _kScatterCeilingMs = 240;

const List<String> _kLeads = ['Lead I', 'Lead II', 'Lead III'];

/// The ECG strip, drawn from whatever is actually producing samples.
///
/// This screen used to hardcode `_isDemo = true`, animate a synthetic trace into
/// view with a fake sweep, and answer "Save Strip" with a snackbar that saved
/// nothing. All three are gone: the source is read off the live link and latched
/// for the length of a recording, the strip is fed by real ECG frames when a
/// board is streaming, and saving attaches the captured samples to the screening
/// or explains why it cannot.
class EcgLiveScreen extends ConsumerStatefulWidget {
  const EcgLiveScreen({super.key});

  @override
  ConsumerState<EcgLiveScreen> createState() => _EcgLiveScreenState();
}

class _EcgLiveScreenState extends ConsumerState<EcgLiveScreen> {
  /// Acquisition rate of the ECG front-end, and the rate every interval on this
  /// screen is derived at. Taken from the wire protocol rather than restated
  /// here, so the header, the measurements and the saved blob cannot disagree
  /// about what a sample index means.
  static const int sampleRateHz = BleProtocol.ecgSampleRateHz;

  /// 4 s of trace — long enough for four or five beats, so the rhythm and the
  /// beat-to-beat scatter below the strip are measured over a real window rather
  /// than a single interval.
  static const int _windowSamples = sampleRateHz * 4;

  /// Longest strip this screen will hold. Bounded because the buffer is in RAM
  /// and a screening has no use for a five-minute trace.
  static const int _maxRecordSamples = sampleRateHz * 30;

  /// How often the generated trace extends itself, and by how much.
  ///
  /// 200 ms is a compromise: fast enough to read as a moving strip, slow enough
  /// that the trace is not repainted 25 times a second — at 40 ms the redraw
  /// read as flicker rather than as a monitor.
  static const Duration _generatorTick = Duration(milliseconds: 200);
  static const int _generatorChunk = sampleRateHz ~/ 5;

  /// Rate the generator paces its synthetic rhythm at.
  static const double _demoHeartRateBpm = 72;

  /// Midpoint and ceiling of the generator's output range, and its counts per
  /// millivolt. These describe the *generated* trace only — a board streams
  /// signed counts on a scale it never publishes, which is why nothing outside
  /// [_generate] assumes them any more.
  static const int _baselineAdc = 1024;
  static const int _fullScaleAdc = 2047;
  static const double _adcPerMv = 300;

  _EcgSource _source = _EcgSource.generated;

  /// The rolling window the strip draws, oldest first. Starts empty and fills
  /// from the right: an empty window means nothing has arrived yet, which is a
  /// different statement from a flat line.
  List<int> _window = const [];

  _EcgMetrics _metrics = _EcgMetrics.none;

  int _leadIndex = 0;

  /// Absolute sample index of the generator, so a chunk appended now continues
  /// the beat that was in progress instead of restarting it. Without this the
  /// strip showed a QRS every 200 ms and the measured rate was fiction.
  int _generatedIndex = 0;

  bool _recording = false;
  final List<int> _record = [];

  /// The source the current recording started on. A recording never switches:
  /// splicing generated samples into a measured strip — or the reverse — would
  /// produce a trace with no honest label.
  _EcgSource? _recordSource;

  /// True if the link left the streaming state at any point during a recording,
  /// so the strip has a gap in it. Reported rather than smoothed over.
  bool _recordInterrupted = false;

  /// `droppedEcgFrames` at the moment recording began, so the count shown is the
  /// number lost during *this* strip.
  int _dropBaseline = 0;

  String? _recordNote;
  String? _saveNote;
  bool _saveFailed = false;

  Timer? _generator;
  StreamSubscription<EcgFrame>? _frames;

  @override
  void initState() {
    super.initState();
    // Resolved before the first frame, so the badge is right on the first paint
    // rather than flipping from DEMO to LIVE a moment later.
    _attach(_resolveSource(ref.read(bleLinkProvider)));
  }

  @override
  void dispose() {
    _generator?.cancel();
    _frames?.cancel();
    super.dispose();
  }

  // ──────────────────────────────── Source ────────────────────────────────

  /// A board only counts as the source when it is streaming *and* reported an
  /// ECG characteristic. A connected board with no ECG channel cannot feed this
  /// screen, and pretending otherwise would leave the strip empty under a LIVE
  /// badge.
  _EcgSource _resolveSource(BleLinkState link) =>
      link.isLive && link.hasEcgChannel
          ? _EcgSource.board
          : _EcgSource.generated;

  /// Point the strip at [source] and drop whatever was on it.
  ///
  /// The window is cleared rather than carried over on purpose: samples from two
  /// different sources on one strip would make the trace unattributable.
  void _attach(_EcgSource source) {
    _generator?.cancel();
    _generator = null;
    _frames?.cancel();
    _frames = null;

    _source = source;
    _window = const [];
    _generatedIndex = 0;
    _metrics = _EcgMetrics.none;

    if (source == _EcgSource.board) {
      // The service's broadcast stream, not a fresh connection: the link is
      // owned app-wide and survives this screen coming and going.
      _frames = ref.read(bleServiceProvider).ecg.listen(_onFrame);
    } else {
      _generator = Timer.periodic(_generatorTick, (_) => _onGenerated());
    }
  }

  void _onLink(BleLinkState? previous, BleLinkState next) {
    final resolved = _resolveSource(next);

    if (_recording) {
      // Pinned for the length of the recording. If the board went away the trace
      // has a hole in it, and the honest response is to say so — not to start
      // generating samples into a buffer labelled as measured.
      if (_recordSource == _EcgSource.board &&
          resolved != _EcgSource.board &&
          !_recordInterrupted) {
        setState(() => _recordInterrupted = true);
      }
      return;
    }

    if (resolved != _source) setState(() => _attach(resolved));
  }

  void _onFrame(EcgFrame frame) {
    if (!mounted || _source != _EcgSource.board) return;
    setState(() => _append(frame.samples));
  }

  void _onGenerated() {
    if (!mounted || _source != _EcgSource.generated) return;
    setState(() => _append(_generate(_generatorChunk)));
  }

  /// Extend the window, and the recording if one is running.
  ///
  /// Must be called from inside a `setState`.
  void _append(List<int> samples) {
    if (samples.isEmpty) return;

    // A fresh list rather than an in-place write: the painter decides whether to
    // repaint by comparing against the list it last drew.
    final next = <int>[..._window, ...samples];
    _window = next.length > _windowSamples
        ? next.sublist(next.length - _windowSamples)
        : next;
    _metrics = _analyse(_window);

    if (!_recording) return;

    final room = _maxRecordSamples - _record.length;
    _record.addAll(samples.length <= room ? samples : samples.take(room));
    if (_record.length >= _maxRecordSamples) {
      _recording = false;
      _recordNote =
          'Recording stopped at the ${_maxRecordSamples ~/ sampleRateHz} s limit.';
    }
  }

  // ─────────────────────────────── Generator ───────────────────────────────

  /// Synthetic PQRST at [_demoHeartRateBpm], phase-continuous across calls.
  ///
  /// Timed in seconds against [sampleRateHz] because the intervals shown under
  /// the strip are measured back off this signal and have to mean something.
  List<int> _generate(int count) {
    const beatPeriod = 60 / _demoHeartRateBpm;
    // Leads see the same electrical event from different angles, so switching
    // lead changes the morphology instead of only relabelling the strip.
    final (gain, tGain) = switch (_leadIndex) {
      1 => (1.15, 1.2), // Lead II — tallest R, prominent T
      2 => (0.65, 0.7), // Lead III — smaller deflections
      _ => (1.0, 1.0), // Lead I
    };

    final out = List<int>.filled(count, _baselineAdc);
    for (var i = 0; i < count; i++) {
      final phase = ((_generatedIndex + i) / sampleRateHz) % beatPeriod;
      var mv = 0.0;
      mv += 0.12 * gain * _gaussian(phase - 0.20, 0.022); // P
      mv += -0.05 * gain * _gaussian(phase - 0.362, 0.008); // Q
      mv += 1.00 * gain * _gaussian(phase - 0.400, 0.010); // R
      mv += -0.18 * gain * _gaussian(phase - 0.438, 0.009); // S
      mv += 0.25 * tGain * _gaussian(phase - 0.600, 0.045); // T
      out[i] = (mv * _adcPerMv + _baselineAdc).round().clamp(0, _fullScaleAdc);
    }
    _generatedIndex += count;
    return out;
  }

  /// Unnormalised bell, so each coefficient above is the deflection in mV.
  ///
  /// The normalised form divides by `sigma * sqrt(2 * pi)`, which for a 10 ms
  /// QRS sigma scales the R wave to ~40 mV — it saturated the range and every
  /// complex came out flat-topped.
  double _gaussian(double x, double sigma) =>
      exp(-0.5 * (x / sigma) * (x / sigma));

  // ─────────────────────────────── Analysis ───────────────────────────────

  /// R-peak sample indices, found by a threshold scan with a refractory window.
  ///
  /// Deliberately simple rather than a full Pan-Tompkins chain: the peaks only
  /// need locating well enough to count beats and time the intervals shown below
  /// the strip.
  List<int> _detectRPeaks(List<int> samples) {
    const refractory = sampleRateHz ~/ 5; // 200 ms — no two R waves are closer
    final maxV = samples.reduce(max);
    final minV = samples.reduce(min);
    final p2p = maxV - minV;

    // Scale-free flat-line guard. The old fixed floor of 40 counts was tuned to
    // the generator's 300 counts/mV; a board streams signed counts on a scale it
    // never publishes, so the same number meant nothing there. A trace whose
    // entire excursion sits within a dozen deviations of its own noise has no
    // QRS standing out of it — for pure noise that ratio is about 9.6.
    final mad = _medianAbsoluteDeviation(samples);
    if (p2p < 12 * mad) return const [];
    if (p2p == 0) return const [];

    final threshold = minV + p2p * 0.6;

    final peaks = <int>[];
    var i = 0;
    while (i < samples.length) {
      if (samples[i] < threshold) {
        i++;
        continue;
      }
      var peak = i;
      while (i < samples.length && samples[i] >= threshold) {
        if (samples[i] > samples[peak]) peak = i;
        i++;
      }
      peaks.add(peak);
      i = peak + refractory;
    }
    return peaks;
  }

  _EcgMetrics _analyse(List<int> samples) {
    // Under a second of trace there is nothing to time. Reporting a rate off the
    // first fraction of a window would put a number on screen before the signal
    // could support one.
    if (samples.length < sampleRateHz) return _EcgMetrics.none;

    final peaks = _detectRPeaks(samples);
    if (peaks.length < 2) return _EcgMetrics.none;

    final intervals = <int>[
      for (var i = 1; i < peaks.length; i++)
        ((peaks[i] - peaks[i - 1]) * 1000 / sampleRateHz).round(),
    ];
    final meanRr = intervals.reduce((a, b) => a + b) / intervals.length;
    if (meanRr <= 0) return _EcgMetrics.unphysiologic(peaks.length);

    final rate = (60000 / meanRr).round();
    if (rate < BleProtocol.minHeartRate || rate > BleProtocol.maxHeartRate) {
      // Peaks were found, but not at a rate a heart beats at, so they are
      // artefacts. Report the count and nothing else: a physiologic-looking BPM
      // derived from noise is the one number on this screen that could send a
      // worker down the wrong path.
      return _EcgMetrics.unphysiologic(peaks.length);
    }

    // Mean absolute successive difference: the beat-to-beat scatter that
    // separates a regular sinus rhythm from a noisy or irregular trace.
    var scatter = 0.0;
    for (var i = 1; i < intervals.length; i++) {
      scatter += (intervals[i] - intervals[i - 1]).abs();
    }
    scatter = intervals.length > 1 ? scatter / (intervals.length - 1) : 0;

    return _EcgMetrics(
      beats: peaks.length,
      heartRateBpm: rate,
      rrIntervalMs: meanRr.round(),
      qrsDurationMs: _measureQrs(samples, peaks),
      rrScatterMs: scatter.round(),
      rrIntervals: intervals,
    );
  }

  /// Mean QRS width in ms, taken as the excursion above a quarter of the R
  /// amplitude on either side of each detected peak.
  int? _measureQrs(List<int> samples, List<int> peaks) {
    // Measured, not assumed. The generator sits at 1024; a real front-end
    // streams signed counts centred near zero. A hardcoded baseline measured the
    // QRS of exactly one of the two and silently returned nulls for the other.
    final baseline = _median(samples);

    var total = 0;
    var counted = 0;
    for (final peak in peaks) {
      final amplitude = samples[peak] - baseline;
      if (amplitude <= 0) continue;
      final cut = baseline + amplitude ~/ 4;
      var start = peak;
      while (start > 0 && samples[start] > cut) {
        start--;
      }
      var end = peak;
      while (end < samples.length - 1 && samples[end] > cut) {
        end++;
      }
      total += end - start;
      counted++;
    }
    if (counted == 0) return null;
    return ((total / counted) * 1000 / sampleRateHz).round();
  }

  int _median(List<int> samples) {
    final sorted = List<int>.of(samples)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Median absolute deviation — a noise estimate the R wave cannot inflate, the
  /// way a standard deviation would.
  double _medianAbsoluteDeviation(List<int> samples) {
    final centre = _median(samples);
    final deviations = samples.map((v) => (v - centre).abs()).toList()..sort();
    return deviations[deviations.length ~/ 2].toDouble();
  }

  // ──────────────────────────────── Actions ────────────────────────────────

  void _toggleRecording() {
    final link = ref.read(bleLinkProvider);

    if (_recording) {
      setState(() {
        _recording = false;
        _recordNote = null;
      });
      // The source was pinned while the strip ran; re-resolve it now, in case the
      // link came up or went away in the meantime.
      final resolved = _resolveSource(link);
      if (resolved != _source) setState(() => _attach(resolved));
      return;
    }

    setState(() {
      _recording = true;
      _record.clear();
      _recordSource = _source;
      _recordInterrupted = false;
      _dropBaseline = link.droppedEcgFrames;
      _recordNote = null;
      _saveNote = null;
      _saveFailed = false;
    });
  }

  /// Why saving is unavailable, or null when it will work.
  ///
  /// A reason, never a disabled button on its own: "why is this greyed out" is
  /// the question the old screen answered by claiming success instead.
  String? _saveBlocker(ScreeningDraft draft) {
    if (_recording) return 'Stop the recording before saving the strip.';
    if (_record.isEmpty) {
      return 'Nothing recorded yet. Tap Record strip to capture the trace.';
    }
    if (!draft.hasPatient) {
      return 'No screening in progress. Start one from a patient first — a strip '
          'with no patient has nothing to be saved to.';
    }
    if (draft.isSaved && _recordSource == _EcgSource.generated) {
      // The row is already written and cannot be re-flagged as demo from here,
      // so attaching a generated trace to it would leave a synthetic waveform on
      // a record that claims to be a measurement.
      return 'This screening is already recorded. A generated strip can only be '
          'attached to a screening still in progress.';
    }
    return null;
  }

  Future<void> _save() async {
    final draft = ref.read(screeningDraftProvider);
    final samples = List<int>.unmodifiable(_record);
    final generated = _recordSource == _EcgSource.generated;
    final seconds = (samples.length / sampleRateHz).toStringAsFixed(1);
    final size = '$seconds s (${samples.length} samples at $sampleRateHz Hz)';

    if (generated && !await _confirmGenerated()) return;
    if (!mounted) return;

    if (draft.isSaved) {
      // The screening row already exists, so the draft is no longer what gets
      // written — attach the blob to the stored record directly. Measured strips
      // only; the generated case is refused in [_saveBlocker].
      try {
        await ref.read(waveformStoreProvider).save(
              screeningId: draft.savedScreeningId!,
              type: 'ecg',
              samples: samples,
              durationMs: (samples.length * 1000 / sampleRateHz).round(),
              sampleRate: sampleRateHz,
            );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _saveFailed = true;
          _saveNote = 'Could not write the strip: $error';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _saveFailed = false;
        _saveNote = '$size written to the saved screening.';
      });
      return;
    }

    ref.read(screeningDraftProvider.notifier).setEcg(
          samples,
          sampleRate: sampleRateHz,
          generated: generated,
        );
    final demoNote = generated ? ' The screening is marked as a demo.' : '';
    setState(() {
      _saveFailed = false;
      _saveNote = '$size attached to ${draft.patient!.name}\'s screening. '
          'It is written to the record when the screening is saved.$demoNote';
    });
  }

  Future<bool> _confirmGenerated() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Attach a generated strip?'),
        content: const Text(
          'This trace was generated by the app, not measured from a patient. '
          'Attaching it marks the whole screening as a demo, so that nobody '
          'later reads it as a real recording.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Attach as demo'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _explain(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  // ───────────────────────────────── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<BleLinkState>(bleLinkProvider, _onLink);
    final link = ref.watch(bleLinkProvider);
    final draft = ref.watch(screeningDraftProvider);
    final onBoard = _source == _EcgSource.board;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Live View'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/screening/live'),
        ),
        actions: [
          _buildSourceBadge(onBoard),
          _buildLeadControl(onBoard),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderInfo(link, onBoard),
          Expanded(
            // Scrolls rather than compressing: the panels under the strip grow
            // with the system font size, and a fixed column had nowhere to put
            // them — the trace was squeezed towards zero height and the controls
            // ran off the bottom of the screen.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._buildBanners(link, onBoard),
                  SizedBox(
                    // The strip is a drawing surface, not text, so it keeps its
                    // height at every text scale.
                    height: 260,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _window.length < 2
                            ? _buildEmptyStrip(onBoard)
                            : CustomPaint(
                                size: Size.infinite,
                                painter: _EcgStripPainter(
                                  waveform: _window,
                                  capacity: _windowSamples,
                                  sampleRate: sampleRateHz,
                                  color: AppTheme.infoBlue,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // True by construction: the painter derives its divisions
                    // from the sample rate. The vertical scale cannot make the
                    // same promise — the board publishes no counts-per-mV — so
                    // it does not claim one.
                    '200 ms per division • amplitude auto-scaled to the window '
                    '(raw ADC counts, no mV calibration)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildMeasurementsPanel(),
                  const SizedBox(height: 16),
                  _buildControls(link, draft),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(bool onBoard) {
    final scheme = Theme.of(context).colorScheme;
    final live = onBoard;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: live
            ? AppTheme.primaryGreenContainer
            : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        live ? 'LIVE' : 'DEMO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: live
                  ? AppTheme.onPrimaryGreenContainer
                  : scheme.onSecondaryContainer,
            ),
      ),
    );
  }

  Widget _buildLeadControl(bool onBoard) {
    if (onBoard || _recording) {
      // An explaining button rather than a disabled one: a greyed control reads
      // as a bug, and "why can't I change lead" deserves a sentence.
      return IconButton(
        icon: const Icon(Icons.swap_horiz),
        tooltip: onBoard ? 'Single channel' : 'Recording',
        onPressed: () => _explain(
          onBoard
              ? 'The board streams one ECG channel and the protocol has no '
                  'lead-select command, so the app cannot switch leads. '
                  'Reposition the electrodes instead.'
              : 'Stop the recording to change lead — the strip would otherwise '
                  'hold two different morphologies.',
        ),
      );
    }

    return PopupMenuButton<String>(
      // Icon only, with the active lead named in the header panel below.
      // Carrying the lead name up here as well put two labelled actions in the
      // toolbar, which ran past the right edge as soon as the system font was
      // scaled up.
      icon: const Icon(Icons.swap_horiz),
      tooltip: 'Change lead',
      onSelected: (value) => setState(() {
        _leadIndex = _kLeads.indexOf(value);
        // The window is emptied, not relabelled: each lead has its own
        // morphology, and leaving the previous lead's samples on the strip would
        // attribute them to the new one.
        _window = const [];
        _generatedIndex = 0;
        _metrics = _EcgMetrics.none;
      }),
      itemBuilder: (context) => _kLeads
          .map((lead) => PopupMenuItem(
                value: lead,
                child: Row(
                  children: [
                    Icon(
                      lead == _kLeads[_leadIndex] ? Icons.check_rounded : null,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(lead)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildHeaderInfo(BleLinkState link, bool onBoard) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Theme colours rather than the light-mode constants this used: the
        // header was a white band with dark text on it in dark mode.
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.monitor_heart,
                color: AppTheme.infoBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ECG Monitoring',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  // The old line claimed "0.5-40 Hz filter" for every trace.
                  // The app filters nothing, and the board does not report its
                  // filter settings over the wire, so neither mode can honestly
                  // claim a band.
                  onBoard
                      ? '${link.deviceName ?? 'Sensor board'} • $sampleRateHz Hz '
                          '• as streamed'
                      : 'Generated ${_kLeads[_leadIndex]} • $sampleRateHz Hz '
                          '• not a measurement',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          // Flexible with a right-aligned child: the pill keeps its natural
          // width and stays flush right at normal text sizes, but is allowed to
          // give way and wrap its label instead of pushing the row off-screen
          // when the font is scaled up.
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _metrics.qualityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _metrics.qualityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        // Measured off the trace, not asserted: a hardcoded
                        // "GOOD QUALITY" tells the health worker nothing.
                        _metrics.qualityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _metrics.qualityColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Faults and provenance, stated above the strip where they cannot be missed.
  List<Widget> _buildBanners(BleLinkState link, bool onBoard) {
    final banners = <Widget>[];

    if (!onBoard) {
      banners.add(_note(
        'No board is streaming, so this trace is generated by the app. It is not '
        'a reading from any patient.',
        icon: Icons.science_outlined,
        color: AppTheme.warningAmber,
      ));
    } else {
      if (link.leadOff) {
        banners.add(_note(
          'The board reports the electrodes are off the skin. The trace below is '
          'whatever the front-end is picking up, not a cardiac signal.',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.errorRed,
        ));
      }
      if (!link.isLive) {
        banners.add(_note(
          '${link.label}. ${link.detail}',
          icon: Icons.link_off,
          color: AppTheme.warningAmber,
        ));
      }
    }

    if (banners.isEmpty) return const [];
    return [...banners, const SizedBox(height: 12)];
  }

  Widget _buildEmptyStrip(bool onBoard) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        // Not a flat line: a straight trace across the strip is asystole, and
        // drawing one because nothing has arrived yet would be the worst
        // possible placeholder on an ECG screen.
        onBoard
            ? 'Waiting for ECG frames from the board…'
            : 'Starting the generated trace…',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildMeasurementsPanel() {
    final scheme = Theme.of(context).colorScheme;
    // The window fills over four seconds, so the unit states the span the count
    // was actually taken over rather than always claiming 4 s.
    final windowSeconds = (_window.length / sampleRateHz).toStringAsFixed(1);
    final rhythm = _metrics.rhythm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Wrap, not Row: five readings do not fit across a 360 px screen
            // once the system font is scaled up, and reflowing onto a second
            // line keeps every label readable where a Row simply clipped them.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppTheme.spacingLg,
              runSpacing: AppTheme.spacingMd,
              children: [
                _buildMeasurement(
                    'Heart Rate', _metrics.heartRateBpm?.toString(), 'BPM'),
                _buildMeasurement(
                    'RR Interval', _metrics.rrIntervalMs?.toString(), 'ms'),
                _buildMeasurement(
                    'QRS Duration', _metrics.qrsDurationMs?.toString(), 'ms'),
                _buildMeasurement('Beats Detected', _metrics.beats?.toString(),
                    'in $windowSeconds s'),
                _buildMeasurement(
                    'RR Scatter', _metrics.rrScatterMs?.toString(), 'ms'),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_outline,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rhythm',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        rhythm == null
                            ? context.l10n.rhythmUnclassified
                            : ecgRhythmLabel(rhythm, context.l10n),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        // The classifier's own caveat, carried to the screen
                        // that shows its output.
                        'Rule-based summary of rate and regularity — not a '
                        'diagnosis.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurement(String label, String? value, String unit) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            children: [
              // An em dash where nothing was measured. Showing a plausible
              // number for a reading the signal never produced is the one
              // failure mode this screen must not have.
              TextSpan(text: value ?? '—'),
              if (value != null)
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BleLinkState link, ScreeningDraft draft) {
    final blocker = _saveBlocker(draft);
    final recordedSeconds = (_record.length / sampleRateHz).toStringAsFixed(1);
    final dropped = max(0, link.droppedEcgFrames - _dropBaseline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppOutlinedButton(
          label: _recording ? 'Stop recording' : 'Record strip',
          icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
          foregroundColor:
              _recording ? AppTheme.errorRed : AppTheme.primaryGreen,
          borderColor: _recording ? AppTheme.errorRed : AppTheme.primaryGreen,
          onPressed: _toggleRecording,
        ),
        if (_recording)
          _note(
            // A count of real samples, not a spinning icon: the old button
            // toggled a boolean and recorded nothing at all.
            '$recordedSeconds s captured (${_record.length} samples'
            '${_recordSource == _EcgSource.generated ? ', generated' : ''}).',
            icon: Icons.fiber_manual_record,
            color: AppTheme.errorRed,
          )
        else if (_record.isNotEmpty)
          _note(
            '$recordedSeconds s recorded '
            '${_recordSource == _EcgSource.generated ? '(generated)' : '(measured)'}.',
            icon: Icons.check_circle_outline,
          ),
        if (_recordInterrupted)
          _note(
            'The link dropped during this recording, so the strip has a gap in '
            'it. The samples either side of the gap are still what the board '
            'sent.',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.warningAmber,
          ),
        if (dropped > 0 && (_recording || _record.isNotEmpty))
          _note(
            '$dropped ECG frame${dropped == 1 ? '' : 's'} lost in transit during '
            'this strip.',
            icon: Icons.warning_amber_rounded,
            color: AppTheme.warningAmber,
          ),
        if (_recordNote != null)
          _note(_recordNote!, icon: Icons.info_outline),
        const SizedBox(height: 12),
        AppButton(
          label: 'Save strip',
          icon: const Icon(Icons.save),
          onPressed: blocker == null ? _save : null,
        ),
        if (blocker != null) _note(blocker),
        if (_saveNote != null)
          _note(
            _saveNote!,
            icon: _saveFailed ? Icons.error_outline : Icons.check_circle,
            color: _saveFailed ? AppTheme.errorRed : AppTheme.successGreen,
          ),
      ],
    );
  }

  Widget _note(String text, {IconData icon = Icons.info_outline, Color? color}) {
    final tint = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tint),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything the strip's own samples can tell us, and nothing they can't.
///
/// Every measurement is nullable so a lead that is off, unplugged or picking up
/// pure noise renders as "—" rather than inventing a physiologic-looking number.
class _EcgMetrics {
  const _EcgMetrics({
    this.beats,
    this.heartRateBpm,
    this.rrIntervalMs,
    this.qrsDurationMs,
    this.rrScatterMs,
    this.rrIntervals = const [],
  }) : unphysiologic = false;

  /// Peaks were found, but not at a rate a heart beats at — artefacts, so the
  /// count is reported and every derived number is withheld.
  const _EcgMetrics.unphysiologic(this.beats)
      : heartRateBpm = null,
        rrIntervalMs = null,
        qrsDurationMs = null,
        rrScatterMs = null,
        rrIntervals = const [],
        unphysiologic = true;

  static const _EcgMetrics none = _EcgMetrics();

  final int? beats;
  final int? heartRateBpm;
  final int? rrIntervalMs;
  final int? qrsDurationMs;

  /// Mean absolute difference between successive RR intervals.
  final int? rrScatterMs;

  /// The interval series itself, so the rhythm call can see irregularity that a
  /// mean would hide.
  final List<int> rrIntervals;

  final bool unphysiologic;

  bool get hasSignal => heartRateBpm != null;

  /// Signal quality as a 0–1 figure, read off beat-to-beat consistency.
  ///
  /// The single source for both the header pill and the rhythm call, so the two
  /// cannot contradict each other.
  double get quality {
    if (unphysiologic || !hasSignal) return 0;
    return (1 - (rrScatterMs ?? 0) / _kScatterCeilingMs).clamp(0, 1).toDouble();
  }

  String get qualityLabel {
    if (unphysiologic) return 'NOISY SIGNAL';
    if (!hasSignal) return 'NO SIGNAL';
    if (quality >= 0.8) return 'GOOD QUALITY';
    if (quality >= EcgClassifier.minUsableQuality) return 'FAIR QUALITY';
    return 'NOISY SIGNAL';
  }

  Color get qualityColor {
    if (unphysiologic) return AppTheme.errorRed;
    if (!hasSignal) return AppTheme.textSecondary;
    if (quality >= 0.8) return AppTheme.successGreen;
    if (quality >= EcgClassifier.minUsableQuality) return AppTheme.warningAmber;
    return AppTheme.errorRed;
  }

  /// The rhythm class, or null when the strip cannot support one.
  String? get rhythm {
    if (!hasSignal) return null;
    return EcgClassifier.classify(
      heartRate: heartRateBpm!,
      quality: quality,
      rrIntervalMs: rrIntervalMs ?? 0,
      rrIntervals: rrIntervals,
    );
  }
}

/// The strip itself: a right-aligned rolling window with a time-true grid.
///
/// Two things changed here. The trace no longer sweeps into view on an
/// animation — that reveal was drawn from a full buffer and misrepresented when
/// the samples arrived. And the vertical scale is measured off the window rather
/// than divided by a fixed 2047, which put every signed sample from a real
/// front-end off the top or bottom of the canvas.
class _EcgStripPainter extends CustomPainter {
  _EcgStripPainter({
    required this.waveform,
    required this.capacity,
    required this.sampleRate,
    required this.color,
  });

  /// Samples to draw, oldest first. Shorter than [capacity] until the window
  /// fills; the unfilled part is left blank.
  final List<int> waveform;
  final int capacity;
  final int sampleRate;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pxPerSample = capacity > 1 ? size.width / (capacity - 1) : size.width;
    final majorX = (sampleRate * 0.2) * pxPerSample; // 200 ms
    final minorX = majorX / 5; // 40 ms

    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    // Guarded: a degenerate width would otherwise spin here forever.
    if (minorX > 0.5) {
      for (var x = 0.0; x <= size.width; x += minorX) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }
    if (majorX > 0.5) {
      for (var x = 0.0; x <= size.width; x += majorX) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
      }
    }

    // Horizontal rules are decoration only. The trace is auto-scaled to the
    // window, so no line here stands for a fixed voltage — which is why the
    // caption under the strip does not claim one.
    final rowHeight = size.height / 10;
    for (var i = 0; i <= 10; i++) {
      final y = i * rowHeight;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i % 5 == 0 ? majorPaint : gridPaint);
    }

    if (waveform.length < 2) return;

    // Scaled to what is on screen. A fixed divisor is only correct for one
    // signal source; measuring the window is correct for both.
    var lo = waveform.first;
    var hi = waveform.first;
    for (final v in waveform) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = hi == lo ? 1.0 : (hi - lo).toDouble();
    const inset = 0.08;
    final usable = size.height * (1 - 2 * inset);
    final bottom = size.height * (1 - inset);

    // Newest sample at the right edge, so a partly-filled window grows leftwards
    // out of the blank rather than stretching to fit.
    final offset = capacity - waveform.length;

    final path = Path();
    for (var i = 0; i < waveform.length; i++) {
      final x = (offset + i) * pxPerSample;
      final y = bottom - ((waveform[i] - lo) / span) * usable;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // The waveform has to be part of this: appending samples or switching lead
    // replaces the list, and the strip would otherwise keep drawing the trace it
    // first saw.
    return oldDelegate is! _EcgStripPainter ||
        oldDelegate.waveform != waveform ||
        oldDelegate.capacity != capacity ||
        oldDelegate.sampleRate != sampleRate ||
        oldDelegate.color != color;
  }
}
