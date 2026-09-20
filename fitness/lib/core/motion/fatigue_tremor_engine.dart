import 'dart:math' as math;
import '../../domain/models/motion_telemetry.dart';

enum TremorSeverity { fresh, moderate, highFatigue, imminentFailure }

class FatigueTremorResult {
  final double tremorIndex; // 0.0 to 100.0%
  final TremorSeverity severity;
  final String coachingAdvice;
  final bool shouldAlert;

  const FatigueTremorResult({
    required this.tremorIndex,
    required this.severity,
    required this.coachingAdvice,
    required this.shouldAlert,
  });
}

class FatigueTremorEngine {
  final List<double> _jitterHistory = [];
  static const int _historyCapacity = 20;

  double _prevGx = 0.0;
  double _prevGy = 0.0;
  double _prevGz = 0.0;
  double _smoothedTremorScore = 15.0;

  void reset() {
    _jitterHistory.clear();
    _prevGx = 0.0;
    _prevGy = 0.0;
    _prevGz = 0.0;
    _smoothedTremorScore = 15.0;
  }

  /// Evaluates high-frequency micro-jitter from 3-axis gyro telemetry
  FatigueTremorResult processTelemetry(MotionTelemetry sample) {
    // 1. Calculate delta jerk in angular rates (high-frequency derivative)
    final dGx = sample.gyroX - _prevGx;
    final dGy = sample.gyroY - _prevGy;
    final dGz = sample.gyroZ - _prevGz;

    _prevGx = sample.gyroX;
    _prevGy = sample.gyroY;
    _prevGz = sample.gyroZ;

    final jerkMagnitude = math.sqrt(dGx * dGx + dGy * dGy + dGz * dGz);

    // 2. Window buffer for variance
    _jitterHistory.add(jerkMagnitude);
    if (_jitterHistory.length > _historyCapacity) {
      _jitterHistory.removeAt(0);
    }

    if (_jitterHistory.length < 5) {
      return const FatigueTremorResult(
        tremorIndex: 12.0,
        severity: TremorSeverity.fresh,
        coachingAdvice: 'Motor units primed. Smooth execution.',
        shouldAlert: false,
      );
    }

    // 3. Compute spectral jitter variance
    final mean = _jitterHistory.reduce((a, b) => a + b) / _jitterHistory.length;
    double varianceSum = 0.0;
    for (final val in _jitterHistory) {
      varianceSum += (val - mean) * (val - mean);
    }
    final variance = varianceSum / _jitterHistory.length;

    // Normalizing variance into 0-100% index
    final rawIndex = (math.sqrt(variance) * 2.8).clamp(5.0, 100.0);
    _smoothedTremorScore = _smoothedTremorScore * 0.85 + rawIndex * 0.15;

    TremorSeverity severity;
    String advice;
    bool alert = false;

    if (_smoothedTremorScore < 40.0) {
      severity = TremorSeverity.fresh;
      advice = 'Smooth neural firing. High stability.';
    } else if (_smoothedTremorScore < 65.0) {
      severity = TremorSeverity.moderate;
      advice = 'Motor unit recruitment rising. Maintain controlled tempo.';
    } else if (_smoothedTremorScore < 82.0) {
      severity = TremorSeverity.highFatigue;
      advice =
          'Neuromuscular fatigue detected! Squeeze core and avoid momentum.';
      alert = true;
    } else {
      severity = TremorSeverity.imminentFailure;
      advice = 'Critical muscle tremor. Failure imminent. Rack weight safely.';
      alert = true;
    }

    return FatigueTremorResult(
      tremorIndex: _smoothedTremorScore,
      severity: severity,
      coachingAdvice: advice,
      shouldAlert: alert,
    );
  }
}
