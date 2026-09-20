import 'dart:math' as math;

class MotionTelemetry {
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final int repCount;
  final int cadence;
  final int stepCount;
  final int motionIntensity; // 0 - 100
  final DateTime timestamp;

  const MotionTelemetry({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    this.repCount = 0,
    this.cadence = 0,
    this.stepCount = 0,
    this.motionIntensity = 0,
    required this.timestamp,
  });

  /// Total linear acceleration vector magnitude (in Gs or m/s²)
  double get totalAcceleration =>
      math.sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

  /// Total angular rate magnitude (in deg/s)
  double get totalAngularRate =>
      math.sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);

  /// Form stability / tilt angle pitch in degrees
  double get pitch =>
      math.atan2(accelX, math.sqrt(accelY * accelY + accelZ * accelZ)) *
      180.0 /
      math.pi;

  /// Form stability / tilt angle roll in degrees
  double get roll =>
      math.atan2(accelY, math.sqrt(accelX * accelX + accelZ * accelZ)) *
      180.0 /
      math.pi;

  factory MotionTelemetry.zero() {
    return MotionTelemetry(
      accelX: 0.0,
      accelY: 0.0,
      accelZ: 1.0,
      gyroX: 0.0,
      gyroY: 0.0,
      gyroZ: 0.0,
      repCount: 0,
      cadence: 0,
      stepCount: 0,
      motionIntensity: 0,
      timestamp: DateTime.now(),
    );
  }
}
