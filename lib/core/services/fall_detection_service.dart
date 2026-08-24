import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Phases of the free-fall → impact signature this detector looks for.
enum FallPhase {
  /// Nothing unusual. Acceleration magnitude is somewhere around 1 g.
  idle,

  /// Magnitude has collapsed towards zero — the phone is unsupported.
  freeFall,

  /// A free fall ended; watching for the impact spike that should follow.
  awaitingImpact,
}

/// The pure state machine behind fall detection.
///
/// Split out from the sensor stream on purpose: a fall is a *sequence* over
/// time, so the only way to have any confidence in the thresholds is to feed
/// synthetic sequences through them in a unit test. Nothing in here touches a
/// platform channel.
///
/// A fall is accepted only on the full two-part signature — a collapse towards
/// 0 g followed within a short window by an impact spike. A single spike is not
/// enough: setting the phone down hard, or dropping it into a bag, produces one
/// of those several times an hour. The free fall in front of it is what
/// separates a person going down from a phone being handled.
class FallDetector {
  /// Below this the phone is effectively unsupported. Earth gravity reads
  /// ~9.81 m/s² at rest, and a true free fall reads near 0; 4.0 leaves room for
  /// the tumbling that a real fall always has.
  final double freeFallThreshold;

  /// Above this counts as the landing. ~2.6 g — firmly past the 1.5–2 g a brisk
  /// walk or a pocket transfer generates.
  final double impactThreshold;

  /// A collapse shorter than this is sensor noise, not a fall. ~80 ms of free
  /// fall is roughly 3 cm of drop.
  final Duration minFreeFallDuration;

  /// How long after a free fall an impact still counts as part of it.
  final Duration impactWindow;

  /// No second detection inside this window. Without it, the tumble after a
  /// landing fires the same alert three or four times.
  final Duration refractoryPeriod;

  FallDetector({
    this.freeFallThreshold = 4.0,
    this.impactThreshold = 26.0,
    this.minFreeFallDuration = const Duration(milliseconds: 80),
    this.impactWindow = const Duration(milliseconds: 1200),
    this.refractoryPeriod = const Duration(seconds: 20),
  });

  FallPhase _phase = FallPhase.idle;
  DateTime? _freeFallStart;
  DateTime? _freeFallEnd;
  DateTime? _lastDetection;

  FallPhase get phase => _phase;

  /// Peak magnitude seen since the last reset, for the alert's detail line.
  double _peakMagnitude = 0;
  double get peakMagnitude => _peakMagnitude;

  /// Feeds one sample. Returns true exactly once per detected fall.
  ///
  /// [at] is passed in rather than read from the clock so tests can drive the
  /// sequence deterministically.
  bool addSample(double magnitude, DateTime at) {
    if (_lastDetection != null &&
        at.difference(_lastDetection!) < refractoryPeriod) {
      return false;
    }

    switch (_phase) {
      case FallPhase.idle:
        if (magnitude < freeFallThreshold) {
          _phase = FallPhase.freeFall;
          _freeFallStart = at;
          _peakMagnitude = magnitude;
        }

      case FallPhase.freeFall:
        _peakMagnitude = math.max(_peakMagnitude, magnitude);
        if (magnitude >= freeFallThreshold) {
          final fellFor = at.difference(_freeFallStart ?? at);
          if (fellFor >= minFreeFallDuration) {
            _phase = FallPhase.awaitingImpact;
            _freeFallEnd = at;
          } else {
            // Too brief to be a drop — a jolt, or a noisy sample.
            _reset();
          }
        }

      case FallPhase.awaitingImpact:
        _peakMagnitude = math.max(_peakMagnitude, magnitude);
        if (at.difference(_freeFallEnd ?? at) > impactWindow) {
          // Fell, then nothing hit. Most likely the phone was tossed onto
          // something soft.
          _reset();
          return false;
        }
        if (magnitude >= impactThreshold) {
          _lastDetection = at;
          _reset();
          return true;
        }
    }
    return false;
  }

  void _reset() {
    _phase = FallPhase.idle;
    _freeFallStart = null;
    _freeFallEnd = null;
  }

  /// Clears the refractory window too — used when the worker re-arms detection.
  void reset() {
    _reset();
    _lastDetection = null;
    _peakMagnitude = 0;
  }

  static double magnitudeOf(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}

/// Wires the phone accelerometer to a [FallDetector] and reports detections.
///
/// This complements — rather than replaces — the MPU6050 on the sensor device:
/// the phone is in the worker's pocket, the cuff is on the patient, and either
/// can be the one that goes down. Both feed the same SOS flow.
class FallDetectionService {
  FallDetectionService({FallDetector? detector})
      : _detector = detector ?? FallDetector();

  final FallDetector _detector;
  StreamSubscription<AccelerometerEvent>? _sub;
  final _detections = StreamController<FallEvent>.broadcast();

  /// Emits once per detected fall. Broadcast so both a listening screen and a
  /// background coordinator can watch without competing for the subscription.
  Stream<FallEvent> get detections => _detections.stream;

  bool get isRunning => _sub != null;

  /// Starts listening. Safe to call twice; the second call is a no-op.
  ///
  /// Returns false when the platform has no accelerometer (or is a test host),
  /// so the caller can leave the toggle off instead of showing it as armed.
  Future<bool> start() async {
    if (_sub != null) return true;
    try {
      _detector.reset();
      _sub = accelerometerEventStream(
        // Game interval is ~20 ms. The normal interval (~200 ms) is far too
        // coarse: an 80 ms free fall would land between two samples.
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        _onSample,
        onError: (Object _) => stop(),
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      _sub = null;
      return false;
    }
  }

  void _onSample(AccelerometerEvent e) {
    final magnitude = FallDetector.magnitudeOf(e.x, e.y, e.z);
    if (_detector.addSample(magnitude, DateTime.now())) {
      _detections.add(
        FallEvent(at: DateTime.now(), peakMagnitude: _detector.peakMagnitude),
      );
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _detections.close();
  }
}

class FallEvent {
  final DateTime at;
  final double peakMagnitude;

  const FallEvent({required this.at, required this.peakMagnitude});

  /// Impact expressed in g, which is how the number is worth showing to a human.
  double get peakG => peakMagnitude / 9.80665;
}
