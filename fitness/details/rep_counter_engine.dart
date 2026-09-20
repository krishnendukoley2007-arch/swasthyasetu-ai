import 'dart:math' as math;
import '../../domain/models/workout_session.dart';
import '../../domain/models/motion_telemetry.dart';

enum RepPhase { idle, eccentric, peakInflexion, concentric, completed }

class RepAnalysisResult {
  final int totalReps;
  final RepPhase currentPhase;
  final double formQuality; // 0..100%
  final double cadenceRpm; // Reps per minute
  final double activeCalories;

  const RepAnalysisResult({
    required this.totalReps,
    required this.currentPhase,
    required this.formQuality,
    required this.cadenceRpm,
    required this.activeCalories,
  });
}

class RepCounterEngine {
  final WorkoutType workoutType;

  int _reps = 0;
  RepPhase _phase = RepPhase.idle;
  double _lastPeakTime = 0.0;
  double _formStabilityScore = 96.0;
  double _caloriesBurned = 0.0;

  // Adaptive thresholding window
  final List<double> _signalBuffer = [];
  static const int _bufferWindow = 5;

  RepCounterEngine({required this.workoutType});

  int get reps => _reps;
  RepPhase get currentPhase => _phase;
  double get formQuality => _formStabilityScore;
  double get calories => _caloriesBurned;

  void reset() {
    _reps = 0;
    _phase = RepPhase.idle;
    _signalBuffer.clear();
    _lastPeakTime = 0.0;
    _formStabilityScore = 96.0;
    _caloriesBurned = 0.0;
  }

  /// Ingests a new motion frame (either from ESP32 MPU6050 or Phone Sensor)
  RepAnalysisResult processSample(MotionTelemetry sample, double timeSeconds) {
    // 1. Select the primary motion axis based on the chosen exercise
    double primarySignal;
    switch (workoutType) {
      case WorkoutType.squats:
        // Squats have dominant vertical translation (accel Z) and knee/hip pitch
        primarySignal = sample.accelZ + (sample.pitch.abs() / 90.0);
        break;
      case WorkoutType.bicepCurls:
        // Bicep curls have dominant pitch rotation and arm acceleration
        primarySignal = sample.gyroY.abs() / 50.0 + sample.accelY;
        break;
      case WorkoutType.pushups:
        // Pushups involve chest lowering (accel Z) and posture tilt
        primarySignal = sample.accelZ.abs() + (sample.accelX.abs() * 0.5);
        break;
      case WorkoutType.jumpingJacks:
        // Jumping jacks exhibit high multi-axial dynamic magnitude
        primarySignal = sample.totalAcceleration;
        break;
      default:
        primarySignal = sample.totalAcceleration;
    }

    // 2. Smooth signal using short moving average
    _signalBuffer.add(primarySignal);
    if (_signalBuffer.length > _bufferWindow) {
      _signalBuffer.removeAt(0);
    }
    final smoothed =
        _signalBuffer.reduce((a, b) => a + b) / _signalBuffer.length;

    // 3. Peak/Valley state machine with hysteresis
    const double thresholdTrigger = 1.25;
    const double thresholdReset = 0.95;

    if (smoothed > thresholdTrigger &&
        (_phase == RepPhase.idle || _phase == RepPhase.concentric)) {
      _phase = RepPhase.eccentric;
    }

    if (_phase == RepPhase.eccentric && smoothed < thresholdReset) {
      // Completed full repetition inflection
      _phase = RepPhase.completed;
      _reps++;

      // Evaluate rep cadence & form stability
      if (_lastPeakTime > 0.0) {
        final durationOfRep = timeSeconds - _lastPeakTime;
        if (durationOfRep > 0.8 && durationOfRep < 6.0) {
          // Stable rhythm: reward form quality
          _formStabilityScore = math.min(
            100.0,
            _formStabilityScore * 0.9 + 10.0,
          );
        } else {
          // Jerky or too fast: slight penalty
          _formStabilityScore = math.max(65.0, _formStabilityScore - 3.0);
        }
      }
      _lastPeakTime = timeSeconds;

      // Estimate active energy burned per rep (typically 0.35 - 0.55 kcal per rep)
      _caloriesBurned += (workoutType == WorkoutType.squats ? 0.48 : 0.38);

      _phase = RepPhase.concentric;
    }

    // Calculate Rep Cadence (RPM)
    double cadence = 0.0;
    if (_lastPeakTime > 0.0 && timeSeconds > _lastPeakTime) {
      final elapsed = timeSeconds - _lastPeakTime;
      if (elapsed < 10.0) {
        cadence = 60.0 / math.max(1.0, elapsed);
      }
    }

    return RepAnalysisResult(
      totalReps: _reps,
      currentPhase: _phase,
      formQuality: _formStabilityScore,
      cadenceRpm: cadence,
      activeCalories: _caloriesBurned,
    );
  }
}
