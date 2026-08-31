import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

// Extension for int to Duration (ms, s)
extension IntDurationExtension on int {
  Duration get ms => Duration(milliseconds: this);
  Duration get s => Duration(seconds: this);
}

class LiveVitalsScreen extends ConsumerStatefulWidget {
  const LiveVitalsScreen({super.key});

  @override
  ConsumerState<LiveVitalsScreen> createState() => _LiveVitalsScreenState();
}

class _LiveVitalsScreenState extends ConsumerState<LiveVitalsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ecgController;
  late AnimationController _progressController;
  late AnimationController _countdownController;
  late AnimationController _phaseController;
  late AnimationController _vitalAnimController;
  late AnimationController _particleController;

  bool _isScreening = false;
  bool _isPaused = false;

  /// True when the numbers on screen are synthesised rather than measured.
  ///
  /// Decided once, at the moment screening starts, from whether a board is
  /// actually streaming — and then held for the whole run. A mid-run
  /// disconnection raises the reconnecting banner; it never silently swaps
  /// generated numbers in behind a reading the worker already trusts.
  bool _isDemo = true;

  int _measurementCount = 0;
  int _secondsElapsed = 0;
  int _countdown = _screeningSeconds;

  late HealthSample _currentSample;

  /// One tick per second, driving the countdown and the progress bar. In live
  /// mode the vitals themselves update whenever a frame lands, which is not on
  /// any schedule this screen controls.
  Timer? _clock;

  StreamSubscription<TelemetryFrame>? _telemetrySub;
  StreamSubscription<EcgFrame>? _ecgSub;

  /// Counted, not assumed. Distinguishes "the board is slow" from "the board
  /// stopped" without waiting for the link state to change.
  int _framesReceived = 0;
  int _ecgFramesReceived = 0;
  DateTime? _lastFrameAt;
  bool _leadOff = false;
  bool _fingerOff = false;

  /// Recent heart rates, for the trend arrows. Three points is enough to tell a
  /// direction from jitter and short enough to react within a screening.
  final List<int> _hrTrail = <int>[];

/// Recent R-R intervals (ms) straight from the board, used to compute
/// RMSSD — the short-window heart-rate-variability figure — on the phone
/// rather than asking the firmware for another number over the wire.
final List<int> _rrWindow = <int>[];
int _rrRepeats = 0;
  final List<int> _spo2Trail = <int>[];
  final List<double> _tempTrail = <double>[];

  /// Nominal length of a screening run. Everything derived from it — the
  /// countdown, the progress bar, the ECG buffer size — reads it from here.
  static const int _screeningSeconds = 30;

  /// Acquisition rate of the ECG front-end. Every interval shown on this screen
  /// is derived from it, so the two can never drift.
  static const int _ecgSampleRateHz = 250;

  /// One second of ECG and one second of PPG. Allocated here rather than
  /// declared `late`: the generators below fill these buffers by index, so an
  /// unallocated list threw a LateInitializationError the moment the screen
  /// was opened.
  static const int _ecgSamples = _ecgSampleRateHz;
  static const int _ppgSamples = 100;
  static const int _ecgBaselineAdc = 1024;
  static const int _ppgBaselineAdc = 2048;

  List<int> _ecgWaveform = List.filled(_ecgSamples, _ecgBaselineAdc);
  final List<int> _ppgWaveform = List.filled(_ppgSamples, _ppgBaselineAdc);
  List<int> _ecgHistory = <int>[];

  /// The whole run is kept, not a two-second tail: the strip is written to a
  /// file when the screening is saved, and a clinician reviewing a rhythm needs
  /// more than the last two seconds of it. Thirty-five seconds at 250 Hz is
  /// about 17 KB as int16 — the run length plus headroom for a slow stop.
  static const int _ecgHistoryLimit = _ecgSampleRateHz * (_screeningSeconds + 5);

  final Random _random = Random();
  final List<_VitalParticle> _vitalParticles = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _ecgController = AnimationController(
      duration: const Duration(milliseconds: 40),
      vsync: this,
    )..repeat();

    _progressController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _phaseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _vitalAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _generateDemoECG();
    _generateDemoPPG();
    _initializeSample();
  }

  void _initializeSample() {
    _currentSample = HealthSample.demo(
      heartRateBpm: 72,
      spo2Percent: 98,
      temperatureC: 36.5,
      ecgSignalQuality: 0.95,
      rrIntervalMs: (60000 / 72).round(),
    );
  }

  @override
  void dispose() {
    // Ordered before the controllers: a frame arriving after the tickers are
    // gone would call setState on a disposed element.
    _clock?.cancel();
    _telemetrySub?.cancel();
    _ecgSub?.cancel();
    _pulseController.dispose();
    _ecgController.dispose();
    _progressController.dispose();
    _countdownController.dispose();
    _phaseController.dispose();
    _vitalAnimController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// Synthesises one second of ECG at [_ecgSampleRateHz], paced to [heartRate]
  /// so the strip and the rate printed beneath it always agree.
  ///
  /// The trace is the five deflections of a normal complex, each a Gaussian at
  /// its own offset within the beat. The earlier version packed a single beat
  /// into the first fifth of the buffer and left the remainder flat, which read
  /// as a dropped rhythm rather than as a trace.
  void _generateDemoECG({int heartRate = 72}) {
    final beatPeriod = 60 / heartRate;
    final samples = List<int>.filled(_ecgSamples, _ecgBaselineAdc);
    for (var i = 0; i < _ecgSamples; i++) {
      final phase = (i / _ecgSampleRateHz) % beatPeriod;
      var mv = 0.0;
      mv += 0.12 * _gaussian(phase - 0.200, 0.022); // P
      mv += -0.05 * _gaussian(phase - 0.362, 0.008); // Q
      mv += 1.00 * _gaussian(phase - 0.400, 0.010); // R
      mv += -0.18 * _gaussian(phase - 0.438, 0.009); // S
      mv += 0.25 * _gaussian(phase - 0.600, 0.045); // T
      samples[i] = (mv * 500 + _ecgBaselineAdc).round().clamp(0, 2047);
    }
    // A fresh list, so painters comparing the old and new buffer in
    // shouldRepaint actually see a change.
    _ecgWaveform = samples;
    if (_ecgHistory.isEmpty) _ecgHistory = List.from(samples);
  }

  /// Un-normalised Gaussian: peak height 1.0 at [x] == 0.
  ///
  /// The 1/(sigma·√2π) factor of the true density would scale the R wave to
  /// tens of millivolts and saturate the ADC into a flat-topped complex.
  double _gaussian(double x, double sigma) =>
      exp(-0.5 * (x / sigma) * (x / sigma));

  void _generateDemoPPG({int heartRate = 72}) {
    final samplesPerBeat = (100 * 60 / heartRate).round();
    for (int i = 0; i < 100; i++) {
      final beatPosition = i % samplesPerBeat;
      double ppg = 0;
      if (beatPosition < samplesPerBeat * 0.4) {
        final pulseT = beatPosition / (samplesPerBeat * 0.4) * 3.14159;
        ppg = 0.8 * sin(pulseT) + 0.1 * sin(2 * pulseT) + 0.05 * sin(3 * pulseT);
      }
      _ppgWaveform[i] = (ppg * 1000 + 2000).round().clamp(0, 4095);
    }
  }

  void _generateParticles() {
    for (int i = 0; i < 20; i++) {
      _vitalParticles.add(_VitalParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 3 + _random.nextDouble() * 5,
        speed: 0.05 + _random.nextDouble() * 0.15,
        opacity: 0.1 + _random.nextDouble() * 0.2,
        color: [
          AppTheme.primaryGreen,
          AppTheme.primaryGreenLight,
          AppTheme.secondaryTeal,
        ][_random.nextInt(3)],
      ));
    }
  }

  void _startScreening() {
    // Read once, here. Whether this run is a measurement or a demonstration is
    // settled before the first number appears and does not change afterwards.
    final live = ref.read(bleLinkProvider).isLive;

    setState(() {
      _isDemo = !live;
      _isScreening = true;
      _isPaused = false;
      _measurementCount = 0;
      _secondsElapsed = 0;
      _countdown = _screeningSeconds;
      _framesReceived = 0;
      _ecgFramesReceived = 0;
      _lastFrameAt = null;
      _leadOff = false;
      _fingerOff = false;
      _ecgHistory = <int>[];
      _hrTrail.clear();
      _rrWindow.clear();
      _rrRepeats = 0;
      _spo2Trail.clear();
      _tempTrail.clear();
      if (_isDemo) {
        // Reset to the resting baseline so a second demo run does not open on
        // the last run's closing numbers.
        _initializeSample();
        _generateDemoECG();
        _generateDemoPPG();
      } else {
        // No reading yet. Zeroed rather than seeded with the demo baseline: the
        // cards read "--" until a frame lands, and a worker never sees 72 BPM
        // for a patient nothing has measured.
        _currentSample = const HealthSample(
          timestamp: 0,
          heartRateBpm: 0,
          spo2Percent: 0,
          temperatureC: 0,
          ecgSignalQuality: 0,
          rPeakDetected: false,
          batteryPercent: 0,
        );
      }
    });

    _ecgController.repeat();
    _progressController.forward(from: 0);
    _countdownController.repeat();
    _phaseController.forward(from: 0);
    _vitalAnimController.forward(from: 0);

    _startClock();
    if (_isDemo) {
      _simulateMeasurements();
    } else {
      _startLiveCapture();
    }
  }

  /// The one-second tick. Owns the countdown and nothing else, so a slow board
  /// makes the vitals stale rather than making the timer wrong.
  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isScreening || _isPaused) return;
      setState(() {
        _secondsElapsed++;
        _countdown = max(0, _screeningSeconds - _secondsElapsed);
      });
    });
  }

  /// Subscribe to the board. Frames drive the display; the service accumulates
  /// the waveform independently so a dropped link does not lose the capture.
  void _startLiveCapture() {
    final service = ref.read(bleServiceProvider);
    service.beginCapture();

    _telemetrySub = service.telemetry.listen((frame) {
      if (!mounted || !_isScreening || _isPaused) return;
      setState(() {
        _framesReceived++;
        _measurementCount++;
        _lastFrameAt = DateTime.now();
        _leadOff = frame.leadOff;
        _fingerOff = frame.fingerOff;
        _currentSample = frame.sample;

        // Zero means "sensor not measured" on the wire, not a flatlined
        // patient. Trails only learn from measured values, or a disconnected
        // SpO2 sensor would drag the trend arrows to the floor.
        final s = frame.sample;
        if (s.heartRateBpm > 0) _hrTrail.add(s.heartRateBpm);
        if (s.spo2Percent > 0) _spo2Trail.add(s.spo2Percent);
        if (s.temperatureC > 0) _tempTrail.add(s.temperatureC);

        // RR history for HRV: each beat the board measured, oldest first.
        // 0 ms is the "no new beat" sentinel, not a 0-millisecond interval.
        if (s.rrIntervalMs > 0) {
          if (_rrWindow.isNotEmpty && s.rrIntervalMs == _rrWindow.last) {
            _rrRepeats++;
          } else {
            _rrRepeats = 0;
          }
          // A repeated value longer than 5 s is a stalled detector,
          // not a steady heart: stop feeding it to RMSSD.
          if (_rrRepeats < 20) {
            _rrWindow.add(s.rrIntervalMs);
            if (_rrWindow.length > 20) _rrWindow.removeAt(0);
          }
        }
        for (final trail in [_hrTrail, _spo2Trail]) {
          if (trail.length > _trailLength) trail.removeAt(0);
        }
        if (_tempTrail.length > _trailLength) _tempTrail.removeAt(0);

        _vitalAnimController.forward(from: 0);
      });
    });

    _ecgSub = service.ecg.listen((frame) {
      if (!mounted || !_isScreening || _isPaused) return;
      setState(() {
        _ecgFramesReceived++;
        _ecgHistory = [..._ecgHistory, ...frame.samples];
        if (_ecgHistory.length > _ecgHistoryLimit) {
          _ecgHistory = _ecgHistory.sublist(_ecgHistory.length - _ecgHistoryLimit);
        }
      });
    });
  }

  static const int _trailLength = 4;

  void _pauseScreening() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _ecgController.stop();
      _progressController.stop();
      _countdownController.stop();
      _phaseController.stop();
      _vitalAnimController.stop();
    } else {
      _ecgController.repeat();
      _progressController.forward();
      _countdownController.repeat();
      _phaseController.forward();
      _vitalAnimController.forward();
      // The live subscriptions were never cancelled — they simply dropped
      // frames while paused, which is what a pause means for a stream you do
      // not control. Only the demo loop has to be restarted.
      if (_isDemo) _simulateMeasurements();
    }
  }

  void _stopScreening() {
    _clock?.cancel();
    _ecgController.stop();
    _progressController.stop();
    _countdownController.stop();
    _phaseController.stop();
    _vitalAnimController.stop();

    // In live mode the service holds the authoritative buffer: it kept
    // accumulating across any reconnection, where `_ecgHistory` is only the
    // rolling window the strip draws.
    List<int> captured = _ecgHistory;
    if (!_isDemo) {
      _telemetrySub?.cancel();
      _telemetrySub = null;
      _ecgSub?.cancel();
      _ecgSub = null;
      final fromService = ref.read(bleServiceProvider).endCapture();
      if (fromService.isNotEmpty) captured = fromService;
    }

    setState(() => _isScreening = false);

    // The captured ECG goes into the draft, not into the route: it is the one
    // part of a screening measured in kilobytes, and it is written to a file
    // rather than a database column when the record is saved.
    ref.read(screeningDraftProvider.notifier).setSample(
          _currentSample,
          ecgSamples: List<int>.unmodifiable(captured),
          ecgSampleRate: _ecgSampleRateHz,
        );
    context.go('/screening/symptoms', extra: {'liveSample': _currentSample});
  }

  /// The demo generator. Runs only when no board is streaming, and every sample
  /// it produces carries `isDemo: true` so nothing downstream can mistake it for
  /// a measurement.
  Future<void> _simulateMeasurements() async {
    while (_isScreening && !_isPaused && mounted && _isDemo) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_isScreening || _isPaused) break;

      setState(() {
        _measurementCount++;

        final hrVariation = _random.nextInt(10) - 5;
        final spo2Variation = _random.nextInt(3) - 1;
        final tempVariation = (_random.nextDouble() - 0.5) * 0.4;

        final newHR = (72 + hrVariation).clamp(50, 120);
        final newSpO2 = (98 + spo2Variation).clamp(90, 100);
        final newTemp = (36.5 + tempVariation).clamp(35.0, 40.0);
        final newRR = (60000 / newHR).round();

        // Regenerated before the sample is built, so the strip carried on the
        // sample is the one paced to this tick's rate.
        _generateDemoECG(heartRate: newHR);

        _currentSample = HealthSample(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          heartRateBpm: newHR,
          spo2Percent: newSpO2,
          temperatureC: newTemp,
          ecgSignal: _ecgWaveform,
          ecgSignalQuality: 0.85 + _random.nextDouble() * 0.1,
          rPeakDetected: _measurementCount % 3 == 0,
          rrIntervalMs: newRR,
          pttMs: 200 + _random.nextInt(30),
          estimatedSystolic: 115 + _random.nextInt(20),
          estimatedDiastolic: 75 + _random.nextInt(15),
          bpConfidence: 'EXPERIMENTAL',
          batteryPercent: max(20, 85 - _measurementCount),
          isDemo: true,
        );

        assert((60000 / newHR - newRR).abs() / (60000 / newHR) < 0.01,
            'HR ($newHR BPM) and RR interval (${newRR}ms) must agree within 1%');

        _hrTrail.add(newHR);
        _spo2Trail.add(newSpO2);
        _tempTrail.add(newTemp);
        for (final trail in [_hrTrail, _spo2Trail]) {
          if (trail.length > _trailLength) trail.removeAt(0);
        }
        if (_tempTrail.length > _trailLength) _tempTrail.removeAt(0);

        _generateDemoPPG(heartRate: newHR);
        _updateECGHistory();
        _vitalAnimController.forward(from: 0);
      });
    }
  }

  void _updateECGHistory() {
    _ecgHistory = [..._ecgHistory, ..._ecgWaveform];
    if (_ecgHistory.length > _ecgHistoryLimit) {
      _ecgHistory = _ecgHistory.sublist(_ecgHistory.length - _ecgHistoryLimit);
    }
  }

  /// How long ago the last frame landed, or null in demo mode / before the
  /// first frame. Drives the stale-reading warning.
  Duration? get _sinceLastFrame {
    if (_isDemo || _lastFrameAt == null) return null;
    return DateTime.now().difference(_lastFrameAt!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: AppTheme.durationMd,
              child: Text(
                _isScreening ? 'Live Screening' : 'Ready to Screen',
                key: ValueKey(_isScreening),
              ),
            ),
            const SizedBox(height: 2),
            const ScreeningStepIndicator(current: 1),
          ],
        ),
        bottom: const ScreeningStepBar(current: 1),
        leading: _isScreening
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _showStopConfirmation,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/screening/new'),
              ),
        actions: [
          // Before a run the badge reflects what would happen if you pressed
          // start; during a run it reflects what is actually happening. It was
          // previously hardcoded to DEMO, which was right for the wrong reason
          // and would have stayed wrong once a board was attached.
          Builder(
            builder: (context) {
              final demo =
                  _isScreening ? _isDemo : !ref.watch(bleLinkProvider).isLive;
              final color = demo
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.primaryContainer;
              final onColor = demo
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onPrimaryContainer;
              return Container(
                margin: const EdgeInsets.only(right: AppTheme.spacingMd),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingXs),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  demo ? 'DEMO' : 'LIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onColor,
                  ),
                ),
              );
            },
          ),
        ],
        elevation: 0,
        scrolledUnderElevation: AppTheme.elevationLevel1,
      ),
      body: AnimatedSwitcher(
        duration: AppTheme.durationMd,
        switchInCurve: AppTheme.curveDecelerate,
        switchOutCurve: AppTheme.curveAccelerate,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: _isScreening ? _buildLiveScreeningView() : _buildPreScreeningView(),
      ),
    );
  }

  Widget _buildPreScreeningView() {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        children: [
          const AppSpacing.vxl(),
          _buildSensorStatusGrid()
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms, curve: AppTheme.curveDecelerate)
              .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
          const AppSpacing.vxl(),
          _buildInstructionCards()
              .animate()
              .fadeIn(duration: 600.ms, delay: 400.ms, curve: AppTheme.curveDecelerate)
              .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
          const AppSpacing.vxl(),
          _buildEstimatedTimeCard()
              .animate()
              .fadeIn(duration: 600.ms, delay: 600.ms, curve: AppTheme.curveDecelerate)
              .slideY(begin: 0.2, end: 0, curve: AppTheme.curveDecelerate),
          const AppSpacing.vxl(),
          _buildStartButton()
              .animate()
              .fadeIn(duration: 600.ms, delay: 800.ms, curve: AppTheme.curveSpring)
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), curve: AppTheme.curveSpring),
          const AppSpacing.vxl(),
        ],
      ),
    );
  }

  Widget _buildEstimatedTimeCard() {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      border: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(Icons.timer_outlined, color: theme.colorScheme.primary, size: 24),
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Screening Time',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const AppSpacing.vxs(),
                Text(
                  '30 seconds \u2022 3 measurement phases\nEnsure device has >20% battery',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorStatusGrid() {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);
    final live = link.isLive;

    // Every one of these three used to read "Ready" with `isConnected: true`
    // hardcoded, whether or not a board existed. What the app can actually
    // tell: the link is streaming, and whether the board advertised an ECG
    // channel. Individual sensor ICs are not enumerable over the protocol, so
    // the cards describe channels rather than claiming to have found chips.
    final sensors = [
      _SensorStatus(
        label: 'Heart Rate / SpO\u2082',
        icon: Icons.favorite_rounded,
        color: theme.colorScheme.primary,
        status: live ? 'Streaming' : 'No board',
        isConnected: live,
      ),
      _SensorStatus(
        label: 'ECG (3-Lead)',
        icon: Icons.monitor_heart_rounded,
        color: theme.colorScheme.secondary,
        status: !live
            ? 'No board'
            : link.hasEcgChannel
                ? 'Streaming'
                : 'Not offered',
        isConnected: live && link.hasEcgChannel,
      ),
      _SensorStatus(
        label: 'Temperature',
        icon: Icons.thermostat_rounded,
        color: theme.colorScheme.tertiary,
        status: live ? 'Streaming' : 'No board',
        isConnected: live,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor Status',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const AppSpacing.vmd(),
        AppStaggeredList(
          duration: AppTheme.durationMd,
          delay: const Duration(milliseconds: 100),
          children: sensors.map((sensor) => _buildAnimatedSensorCard(sensor)).toList(),
        ),
        if (!live) ...[
          const AppSpacing.vmd(),
          AppCard(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            border: BorderSide(
              color: theme.colorScheme.secondary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined,
                    color: theme.colorScheme.onSecondaryContainer, size: 22),
                const AppSpacing.hmd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demonstration mode',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const AppSpacing.vxs(),
                      Text(
                        'No board is streaming, so this run will show generated '
                        'readings. They are saved marked as demo data and must '
                        'not be used to make a decision about a patient.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const AppSpacing.vsm(),
                      AppOutlinedButton(
                        label: 'Connect a board',
                        icon: const Icon(Icons.bluetooth_searching_rounded),
                        minHeight: 44,
                        onPressed: () => context.go('/devices/scan'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnimatedSensorCard(_SensorStatus sensor) {
    final theme = Theme.of(context);

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPulseAnimation(
            minScale: 0.98,
            maxScale: 1.02,
            duration: const Duration(milliseconds: 1500),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [sensor.color.withValues(alpha: 0.2), sensor.color.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(sensor.icon, color: sensor.color, size: 32),
            ),
          ),
          const AppSpacing.vsm(),
          Flexible(
            child: Text(
              sensor.label,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const AppSpacing.vxs(),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppTheme.durationSm,
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: sensor.isConnected ? theme.colorScheme.primary : theme.colorScheme.error,
                    shape: BoxShape.circle,
                    boxShadow: sensor.isConnected ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                ),
                const AppSpacing.hxs(),
                Flexible(
                  child: Text(
                    sensor.status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: sensor.isConnected ? theme.colorScheme.primary : theme.colorScheme.error,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCards() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Guide',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const AppSpacing.vmd(),
        AppStaggeredList(
          duration: AppTheme.durationMd,
          delay: const Duration(milliseconds: 80),
          children: [
            _buildAnimatedInstructionRow('1', 'Place finger on PPG sensor', Icons.favorite_rounded, theme.colorScheme.primary),
            _buildAnimatedInstructionRow('2', 'Attach ECG electrodes (RA, LA, RL)', Icons.monitor_heart_rounded, theme.colorScheme.secondary),
            _buildAnimatedInstructionRow('3', 'Point temp sensor at forehead', Icons.thermostat_rounded, theme.colorScheme.tertiary),
            _buildAnimatedInstructionRow('4', 'Stay still for 30 seconds', Icons.accessibility_new_rounded, theme.colorScheme.primary.withValues(alpha: 0.8)),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedInstructionRow(String number, String text, IconData icon, Color color) {
    final theme = Theme.of(context);

    return AppRippleEffect(
      color: color.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Center(
                child: Text(
                  number,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
            const AppSpacing.hsm(),
            Icon(icon, size: 22, color: color),
            const AppSpacing.hsm(),
            Expanded(
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return AppButton(
      label: 'Start Screening',
      icon: const Icon(Icons.play_arrow_rounded, size: 28),
      onPressed: _startScreening,
      minWidth: double.infinity,
      minHeight: 64,
    );
  }

  Widget _buildLiveScreeningView() {
    return Column(
      children: [
        _buildProgressHeader(),
        if (!_isDemo) _buildLinkBanner(),
        _buildRhythmBanner(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                _buildVitalCardsRow(),
                const AppSpacing.vmd(),
                _buildECGCard(),
                const AppSpacing.vmd(),
                // The protocol carries no raw optical waveform, so in live mode
                // there is nothing to draw here. Shown only for the demo, where
                // the trace is honestly labelled as generated.
                if (_isDemo) ...[
                  _buildPPGCard(),
                  const AppSpacing.vmd(),
                ],
                _buildExperimentalBPCard(),
                const AppSpacing.vmd(),
                _buildSignalQualityCard(),
                const AppSpacing.vxl(),
              ],
            ),
          ),
        ),
        _buildControlBar(),
      ],
    );
  }

  /// Link health during a live run.
  ///
  /// Two failures matter and they look identical on a frozen vitals card: the
  /// link dropped, and the link is up but the board stopped sending. The banner
  /// names whichever it is, and says out loud that the waveform captured so far
  /// is being kept — otherwise a worker seeing "Reconnecting" assumes the
  /// screening is lost and starts over.
  Widget _buildLinkBanner() {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);
    final stale = _sinceLastFrame;

    final (message, color, icon) = switch (link.status) {
      BleLinkStatus.streaming when stale != null && stale.inSeconds >= 5 => (
          'The link is open but no reading has arrived for ${stale.inSeconds}s. '
              'Check the sensor is seated on the finger.',
          theme.colorScheme.tertiary,
          Icons.hourglass_empty_rounded,
        ),
      BleLinkStatus.streaming => (null, null, null),
      BleLinkStatus.reconnecting => (
          'Reconnecting to the board — attempt ${link.attempt}'
              '${link.retryIn != null ? ', retrying in ${link.retryIn!.inSeconds}s' : ''}. '
              'The $_ecgSeconds s captured so far is kept.',
          theme.colorScheme.tertiary,
          Icons.sync_problem_rounded,
        ),
      _ => (
          'The board is ${link.label.toLowerCase()}. '
              'The $_ecgSeconds s captured so far is kept.',
          theme.colorScheme.error,
          Icons.link_off_rounded,
        ),
    };

    if (message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      color: color!.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Beat-to-beat regularity, surfacing only when there is a real finding —
  /// a quiet row during a screening is worse than a loud one that is wrong.
  ///
  /// Two honest sources both already measured by the board: sustained high/low
  /// rate, and scatter across the RR window. It says "recheck", never
  /// "diagnosed": this is a screening aid, not a cardiologist.
  Widget _buildRhythmBanner() {
    if (!_isScreening || _isDemo) return const SizedBox.shrink();
    if (_rrWindow.length < 8) return const SizedBox.shrink();

    final hr = _currentSample.heartRateBpm;

    // Mean absolute successive RR difference over the window, ms.
    var scatter = 0.0;
    for (var i = 1; i < _rrWindow.length; i++) {
      scatter += (_rrWindow[i] - _rrWindow[i - 1]).abs();
    }
    scatter /= (_rrWindow.length - 1);

    final String? message;
    if (hr > 0 && hr < 45) {
      message = 'Heart rate has stayed below 45 bpm for several beats. '
          'Keep the patient seated and re-check in a minute.';
    } else if (hr > 0 && hr > 130) {
      message = 'Heart rate has stayed above 130 bpm for several beats. '
          'Keep the patient seated and re-check in a minute.';
    } else if (scatter > 150 && hr > 0) {
      message = 'The beat-to-beat timing is very uneven (±${scatter.round()} ms). '
          'Ask the patient to sit still and repeat the strip before deciding.';
    } else {
      message = null;
    }

    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      color: color.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.monitor_heart_outlined, color: color, size: 20),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Seconds of waveform held, for the banner. Rounded down so it never claims
  /// more than was captured.
  int get _ecgSeconds => _ecgHistory.length ~/ _ecgSampleRateHz;

  Widget _buildProgressHeader() {
    final theme = Theme.of(context);
    final progress = _secondsElapsed / _screeningSeconds;
    final phaseNames = ['Vitals Baseline', 'ECG Acquisition', 'Final Verification'];
    // Derived from elapsed time, not from a frame counter. In live mode frames
    // land at whatever rate the board manages, so counting them made the phase
    // label race ahead on a fast link and stall on a slow one.
    final currentPhase =
        (_secondsElapsed * 3 ~/ _screeningSeconds).clamp(0, 2);
    final subtitle = _isDemo
        ? '${phaseNames[currentPhase]} \u2022 generated readings'
        : '${phaseNames[currentPhase]} \u2022 $_framesReceived readings, '
            '$_ecgFramesReceived ECG frames';

    return AnimatedBuilder(
      animation: _phaseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Screening in Progress',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const AppSpacing.vxs(),
                        AnimatedSwitcher(
                          duration: AppTheme.durationMd,
                          child: Text(
                            subtitle,
                            key: ValueKey(subtitle),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCountdownTimer(),
                ],
              ),
              const AppSpacing.vsm(),
              AppLinearProgress(
                value: progress.clamp(0.0, 1.0),
                height: 6,
                showValue: true,
                valueLabel: '${_countdown}s remaining',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountdownTimer() {
    final theme = Theme.of(context);
    final isCritical = _countdown <= 10;

    return AnimatedBuilder(
      animation: _countdownController,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCritical
                  ? [theme.colorScheme.error, theme.colorScheme.error.withValues(alpha: 0.7)]
                  : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: (isCritical ? theme.colorScheme.error : theme.colorScheme.primary).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, color: theme.colorScheme.onPrimary, size: 18),
              const AppSpacing.hxs(),
              Text(
                '${_countdown}s',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// False in live mode until the first frame lands.
  ///
  /// Without this, the cards opened on "0 BPM" with the low-heart-rate alert
  /// lit \u2014 a red bradycardia warning for a patient nothing had measured yet.
  bool get _hasReading => _isDemo || _framesReceived > 0;

  Widget _buildVitalCardsRow() {
    final theme = Theme.of(context);
    final ready = _hasReading;

    // 0 on the wire means "sensor not measured" (no PPG / no thermopile
    // fitted), not a zero reading on a patient. Render "--" rather than a
    // number, and never trip an alert on it — a 0% SpO2 alarm for a sensor
    // that does not exist would be the app's own false emergency.
    final hr = _currentSample.heartRateBpm;
    final spo2 = _currentSample.spo2Percent;
    final tempC = _currentSample.temperatureC;

    final vitals = [
      _VitalData(
        label: 'Heart Rate',
        value: ready && hr > 0 ? hr.toString() : '--',
        unit: 'BPM',
        icon: Icons.favorite_rounded,
        color: theme.colorScheme.primary,
        alert: ready && hr > 0 && (hr > 100 || hr < 50),
        alertColor: theme.colorScheme.error,
        trend: _getHRTrend(),
      ),
      _VitalData(
        label: 'SpO₂',
        value: ready && spo2 > 0 ? spo2.toString() : '--',
        unit: '%',
        icon: Icons.air_rounded,
        color: theme.colorScheme.secondary,
        alert: ready && spo2 > 0 && spo2 < 95,
        alertColor: theme.colorScheme.error,
        trend: _getSpO2Trend(),
      ),
      _VitalData(
        label: 'Temperature',
        value: ready && tempC > 0 ? tempC.toStringAsFixed(1) : '--',
        unit: '°C',
        icon: Icons.thermostat_rounded,
        color: theme.colorScheme.tertiary,
        alert: ready && tempC > 0 && tempC >= 38.0,
        alertColor: theme.colorScheme.error,
        trend: _getTempTrend(),
      ),
    ];

    return AppStaggeredList(
      axis: Axis.horizontal,
      spacing: AppTheme.spacingMd,
      duration: AppTheme.durationMd,
      delay: const Duration(milliseconds: 100),
      children: vitals.map((vital) => Expanded(child: _buildAnimatedVitalCard(vital))).toList(),
    );
  }

  Widget _buildAnimatedVitalCard(_VitalData vital) {
    final theme = Theme.of(context);
    final displayColor = vital.alert ? vital.alertColor : vital.color;

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          Row(
            children: [
              AppPulseAnimation(
                minScale: 0.95,
                maxScale: 1.05,
                duration: const Duration(milliseconds: 1000),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: vital.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(vital.icon, color: vital.color, size: 24),
                ),
              ),
              const Spacer(),
              if (vital.alert)
                AppStatusBadge(
                  label: vital.alertColor == theme.colorScheme.error ? 'HIGH' : 'ATTN',
                  type: vital.alertColor == theme.colorScheme.error ? AppStatusType.error : AppStatusType.warning,
                  showDot: false,
                  animate: true,
                ),
            ],
          ),
          const AppSpacing.vmd(),
          AnimatedBuilder(
            animation: _vitalAnimController,
            builder: (context, child) {
              return Opacity(
                opacity: _vitalAnimController.value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _vitalAnimController.value)),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: displayColor,
                      ),
                      children: [
                        TextSpan(text: vital.value),
                        TextSpan(
                          text: ' ${vital.unit}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const AppSpacing.vxs(),
          Text(
            vital.label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const AppSpacing.vsm(),
          _buildTrendIndicator(vital.trend),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(_TrendDirection trend) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    switch (trend) {
      case _TrendDirection.up:
        icon = Icons.trending_up_rounded;
        color = theme.colorScheme.error;
        break;
      case _TrendDirection.down:
        icon = Icons.trending_down_rounded;
        color = theme.colorScheme.primary;
        break;
      case _TrendDirection.stable:
        icon = Icons.trending_flat_rounded;
        color = theme.colorScheme.primary;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const AppSpacing.hxs(),
        Text(
          trend == _TrendDirection.up ? 'Rising' : trend == _TrendDirection.down ? 'Falling' : 'Stable',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Direction of travel across the recent readings.
  ///
  /// The previous version returned `_random.nextBool() ? up : stable` for heart
  /// rate — an arrow pointing up on a coin flip, next to a number a health
  /// worker is being asked to act on. This compares the first and last readings
  /// held in the trail and calls anything inside [deadband] stable, so ordinary
  /// beat-to-beat jitter does not read as a rising rate.
  /// RMSSD in milliseconds over the recent RR window, or null when there
/// are too few beats to say anything honest. RMSSD is the standard
/// short-window HRV measure: root-mean-square of successive RR
/// differences. It needs no firmware support because the board already
/// reports each R-R interval and this is pure arithmetic on top.
double? _rmssdMs() {
  if (_rrWindow.length < 6) return null;
  var sumSquares = 0.0;
  var count = 0;
  for (var i = 1; i < _rrWindow.length; i++) {
    final d = (_rrWindow[i] - _rrWindow[i - 1]).toDouble();
    sumSquares += d * d;
    count++;
  }
  if (count == 0) return null;
  return sqrt(sumSquares / count);
}

_TrendDirection _trendOf(List<num> trail, num deadband) {
    if (trail.length < 2) return _TrendDirection.stable;
    final delta = trail.last - trail.first;
    if (delta.abs() < deadband) return _TrendDirection.stable;
    return delta > 0 ? _TrendDirection.up : _TrendDirection.down;
  }

  // Deadbands are the smallest change worth an arrow, not the sensor's
  // resolution: 4 BPM of sinus variation, 1% of SpO2 quantisation, and 0.2 °C
  // of skin-temperature drift are all normal in a resting patient.
  _TrendDirection _getHRTrend() => _trendOf(_hrTrail, 4);

  _TrendDirection _getSpO2Trend() => _trendOf(_spo2Trail, 2);

  _TrendDirection _getTempTrend() => _trendOf(_tempTrail, 0.2);

  Widget _buildECGCard() {
    final theme = Theme.of(context);
    final quality = _currentSample.ecgSignalQuality;
    // Neutral until a frame arrives: a quality of 0.0 with no reading behind it
    // rendered a red "POOR" badge before the board had said anything at all.
    final qualityColor = !_hasReading
        ? theme.colorScheme.onSurfaceVariant
        : quality >= 0.8
            ? theme.colorScheme.primary
            : quality >= 0.5
                ? theme.colorScheme.tertiary
                : theme.colorScheme.error;
    final qualityText = !_hasReading
        ? 'WAITING'
        : quality >= 0.8
            ? 'GOOD'
            : quality >= 0.5
                ? 'FAIR'
                : 'POOR';

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, color: theme.colorScheme.secondary, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                    'ECG Waveform (Lead I)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ),
              const Spacer(),
              AppPulseAnimation(
                minScale: 0.95,
                maxScale: 1.05,
                duration: const Duration(milliseconds: 1500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
                  decoration: BoxDecoration(
                    color: qualityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: qualityColor, shape: BoxShape.circle),
                      ),
                      const AppSpacing.hxs(),
                      Text(
                        qualityText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: qualityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          SizedBox(
            height: 160,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ecgController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _ECGWaveformPainter(
                      waveform: _ecgHistory,
                      color: theme.colorScheme.secondary,
                      animationValue: _ecgController.value,
                      gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),
            ),
          ),
          const AppSpacing.vsm(),
          AppStaggeredList(
            axis: Axis.horizontal,
            spacing: AppTheme.spacingMd,
            duration: AppTheme.durationMd,
            children: [
              _buildAnimatedECGInfo('Rate', _hasReading ? '${_currentSample.heartRateBpm} BPM' : '--', theme),
              _buildAnimatedECGInfo('RR Interval', _hasReading ? '${_currentSample.rrIntervalMs} ms' : '--', theme),
              // HRV from the RR window: '--' until ~6 beats have been seen.
              _buildAnimatedECGInfo('HRV (RMSSD)', () {
                final hrv = _rmssdMs();
                return _hasReading && hrv != null ? '${hrv.round()} ms' : '--';
              }(), theme),
              _buildAnimatedECGInfo('Quality', _hasReading ? '${(quality * 100).round()}%' : '--', theme),
              _buildAnimatedECGInfo('R-Peaks', !_hasReading ? '--' : _currentSample.rPeakDetected ? 'Detected' : 'Searching', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedECGInfo(String label, String value, ThemeData theme) {
    return AppRippleEffect(
      color: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Column(
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const AppSpacing.vxs(),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPPGCard() {
    final theme = Theme.of(context);

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: theme.colorScheme.primary, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                    'PPG Waveform (Pulse)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ),
              const Spacer(),
              AppPulseAnimation(
                minScale: 0.9,
                maxScale: 1.1,
                duration: const Duration(milliseconds: 800),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          SizedBox(
            height: 90,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _PPGWaveformPainter(
                    waveform: _ppgWaveform,
                    color: theme.colorScheme.primary,
                    gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
                AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _ParticlePainter(
                        particles: _vitalParticles,
                        animationValue: _particleController.value,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentalBPCard() {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      border: BorderSide(color: theme.colorScheme.tertiary.withValues(alpha: 0.3), width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                    'Experimental BP Estimation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  _currentSample.bpConfidence,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          AppStaggeredList(
            axis: Axis.horizontal,
            spacing: AppTheme.spacingMd,
            duration: AppTheme.durationMd,
            children: [
              _buildAnimatedBPValue('Systolic', _hasReading ? _currentSample.estimatedSystolic.toString() : '--', 'mmHg', theme.colorScheme.error),
              _buildAnimatedBPValue('Diastolic', _hasReading ? _currentSample.estimatedDiastolic.toString() : '--', 'mmHg', theme.colorScheme.secondary),
              _buildAnimatedBPValue('PTT', _hasReading ? _currentSample.pttMs.toString() : '--', 'ms', theme.colorScheme.primary),
            ],
          ),
          const AppSpacing.vmd(),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: theme.colorScheme.tertiary, size: 18),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    'PTT-based BP estimation is experimental and NOT for clinical use. Values may be inaccurate. Always validate with a calibrated cuff.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBPValue(String label, String value, String unit, Color color) {
    return AppRippleEffect(
      color: color.withValues(alpha: 0.2),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const AppSpacing.vxs(),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalQualityCard() {
    final theme = Theme.of(context);
    final ready = _hasReading;
    final ecgQuality = _currentSample.ecgSignalQuality;
    final batteryPercent = _currentSample.batteryPercent;

    Color qualityColor(double q) => q >= 0.8
        ? theme.colorScheme.primary
        : q >= 0.5
            ? theme.colorScheme.tertiary
            : theme.colorScheme.error;
    String qualityLabel(double q) =>
        q >= 0.8 ? 'GOOD' : q >= 0.5 ? 'FAIR' : 'POOR';

    // The middle slot used to read a hardcoded "PPG Quality 95% GOOD" on every
    // run, connected or not. Replaced with sensor contact, which the board
    // actually reports and which is the thing that explains a bad reading.
    final (contactValue, contactStatus, contactColor, contactIcon) = switch ((
      _isDemo,
      ready,
      _fingerOff,
      _leadOff
    )) {
      (true, _, _, _) => ('Demo', 'N/A', theme.colorScheme.onSurfaceVariant,
          Icons.science_outlined),
      (_, false, _, _) => ('--', 'WAITING',
          theme.colorScheme.onSurfaceVariant, Icons.touch_app_outlined),
      (_, _, true, _) => ('Off', 'NO FINGER', theme.colorScheme.error,
          Icons.do_not_touch_outlined),
      (_, _, _, true) => ('Partial', 'LEAD OFF', theme.colorScheme.tertiary,
          Icons.link_off_rounded),
      _ => ('On', 'OK', theme.colorScheme.primary, Icons.touch_app_rounded),
    };

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Signal Quality & Status',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const AppSpacing.vmd(),
          AppStaggeredList(
            axis: Axis.horizontal,
            spacing: AppTheme.spacingMd,
            duration: AppTheme.durationMd,
            children: [
              _buildAnimatedQualityItem(
                'ECG Quality',
                ready ? '${(ecgQuality * 100).round()}%' : '--',
                ready
                    ? qualityColor(ecgQuality)
                    : theme.colorScheme.onSurfaceVariant,
                ready ? qualityLabel(ecgQuality) : 'WAITING',
                Icons.monitor_heart_rounded,
              ),
              _buildAnimatedQualityItem(
                'Sensor contact',
                contactValue,
                contactColor,
                contactStatus,
                contactIcon,
              ),
              _buildAnimatedQualityItem(
                'Battery',
                ready ? '$batteryPercent%' : '--',
                !ready
                    ? theme.colorScheme.onSurfaceVariant
                    : batteryPercent > 20
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                !ready
                    ? 'WAITING'
                    : batteryPercent > 20
                        ? 'OK'
                        : 'LOW',
                ready && batteryPercent <= 20
                    ? Icons.battery_alert_rounded
                    : Icons.battery_std_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedQualityItem(String label, String value, Color color, String status, IconData icon) {
    final theme = Theme.of(context);

    return AppRippleEffect(
      color: color.withValues(alpha: 0.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const AppSpacing.hxs(),
              Expanded(
                child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          AppPulseAnimation(
            minScale: 0.98,
            maxScale: 1.02,
            duration: const Duration(milliseconds: 1500),
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
                children: [TextSpan(text: value)],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: AppTheme.spacingXs),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSm, vertical: AppTheme.spacingXs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              status,
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: AppOutlinedButton(
              label: _isPaused ? 'Resume' : 'Pause',
              icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 24),
              onPressed: _pauseScreening,
              minHeight: 56,
            ),
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: AppButton(
              label: 'Stop & Continue',
              icon: const Icon(Icons.stop_rounded, size: 24),
              onPressed: _stopScreening,
              minHeight: 56,
            ),
          ),
        ],
      ),
    );
  }

  void _showStopConfirmation() {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Screening?'),
        content: const Text('Current measurements will be saved. Continue to symptom collection?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _stopScreening();
            },
            child: const Text('Stop & Continue'),
          ),
        ],
      ),
    );
  }
}

class _SensorStatus {
  final String label;
  final IconData icon;
  final Color color;
  final String status;
  final bool isConnected;

  _SensorStatus({
    required this.label,
    required this.icon,
    required this.color,
    required this.status,
    required this.isConnected,
  });
}

class _VitalData {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool alert;
  final Color alertColor;
  final _TrendDirection trend;

  _VitalData({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.alert,
    required this.alertColor,
    required this.trend,
  });
}

enum _TrendDirection { up, down, stable }

class _VitalParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;

  _VitalParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_VitalParticle> particles;
  final double animationValue;

  _ParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = (particle.x + animationValue * particle.speed) % 1.0;
      final y = (particle.y - animationValue * particle.speed * 0.5) % 1.0;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ParticlePainter && oldDelegate.animationValue != animationValue;
  }
}

/// Draws the rolling ECG strip.
///
/// Auto-scaled to the buffer rather than divided by a fixed 2047: the demo
/// generator emits 12-bit ADC counts around a 1024 baseline, while a real board
/// sends signed int16 from the AD8232 front-end. A fixed divisor drew one of the
/// two clean off the canvas.
class _ECGWaveformPainter extends CustomPainter {
  final List<int> waveform;
  final Color color;
  final double animationValue;
  final Color gridColor;

  _ECGWaveformPainter({
    required this.waveform,
    required this.color,
    required this.animationValue,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 0; i <= 20; i++) {
      final x = size.width * i / 20;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // A single point cannot be a line, and an empty buffer made the old
    // `i / (length - 1)` divide by zero — which on a live link is the state the
    // strip is in for its first fraction of a second.
    if (waveform.length < 2) return;

    var lo = waveform.first;
    var hi = waveform.first;
    for (final v in waveform) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    // A flat trace has no range to scale by. Drawn down the middle instead of
    // dividing by zero.
    final span = (hi - lo) == 0 ? 1.0 : (hi - lo).toDouble();
    // 8% of the height at each edge, so an R wave at the top of the range is
    // not clipped flat against the border.
    const inset = 0.08;

    final path = Path();
    final visiblePoints =
        (waveform.length * (0.3 + 0.7 * animationValue)).round();
    final last = waveform.length - 1;

    for (int i = 0; i < visiblePoints && i < waveform.length; i++) {
      final x = (i / last) * size.width;
      final normalised = (waveform[i] - lo) / span;
      final y = size.height * (1 - inset - normalised * (1 - 2 * inset));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // The buffer is compared as well as the animation value: a new list with the
    // same animation phase is a new reading and has to be drawn.
    return oldDelegate is! _ECGWaveformPainter ||
        oldDelegate.animationValue != animationValue ||
        !identical(oldDelegate.waveform, waveform) ||
        oldDelegate.color != color;
  }
}

class _PPGWaveformPainter extends CustomPainter {
  final List<int> waveform;
  final Color color;
  final Color gridColor;

  _PPGWaveformPainter({
    required this.waveform,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (waveform.length < 2) return;

    final path = Path();
    final last = waveform.length - 1;
    for (int i = 0; i < waveform.length; i++) {
      final x = (i / last) * size.width;
      final y = size.height - (waveform[i] / 4095.0) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Was `false`, unconditionally — so the pulse trace was painted once and
    // then never updated again for the rest of the screening, however many
    // times the buffer was regenerated.
    return oldDelegate is! _PPGWaveformPainter ||
        !identical(oldDelegate.waveform, waveform) ||
        oldDelegate.color != color;
  }
}