import 'dart:typed_data';
import '../../domain/models/motion_telemetry.dart';

class FitnessVitalsData {
  final int heartRate;
  final int spo2;
  final double temperature;
  final int rrIntervalMs;
  final int batteryPercent;
  final int uptimeMs;
  final DateTime timestamp;

  const FitnessVitalsData({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.rrIntervalMs,
    required this.batteryPercent,
    required this.uptimeMs,
    required this.timestamp,
  });
}

class FitnessBleProtocol {
  FitnessBleProtocol._();

  static const int frameTelemetry = 0x01;
  static const int frameMotion = 0x03;
  static const int frameLength = 20;

  /// Parse the 20-byte Vitals Telemetry frame from the ESP32
  static FitnessVitalsData? parseVitals(List<int> bytes) {
    if (bytes.length != frameLength) return null;
    if (bytes[0] != frameTelemetry) return null;

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final hr = bytes[2];
    final spo2 = bytes[3];
    final temp = data.getInt16(4, Endian.little) / 100.0;
    final rr = data.getUint16(6, Endian.little);
    final battery = bytes[14];
    final uptime = data.getUint32(16, Endian.little);

    return FitnessVitalsData(
      heartRate: hr,
      spo2: spo2,
      temperature: temp,
      rrIntervalMs: rr,
      batteryPercent: battery,
      uptimeMs: uptime,
      timestamp: DateTime.now(),
    );
  }

  /// Parse the 20-byte Motion & Gyro Telemetry frame from the ESP32 (MPU6050)
  static MotionTelemetry? parseMotion(List<int> bytes) {
    if (bytes.length != frameLength) return null;
    if (bytes[0] != frameMotion) return null;

    final data = ByteData.sublistView(Uint8List.fromList(bytes));

    // Accel is transmitted as int16 scaled by 100 (e.g. 100 = 1.00 G)
    final ax = data.getInt16(2, Endian.little) / 100.0;
    final ay = data.getInt16(4, Endian.little) / 100.0;
    final az = data.getInt16(6, Endian.little) / 100.0;

    // Gyro is transmitted as int16 scaled by 10 (e.g. 150 = 15.0 deg/s)
    final gx = data.getInt16(8, Endian.little) / 10.0;
    final gy = data.getInt16(10, Endian.little) / 10.0;
    final gz = data.getInt16(12, Endian.little) / 10.0;

    final reps = data.getUint16(14, Endian.little);
    final cadence = bytes[16];
    final intensity = bytes[17];
    final steps = data.getUint16(18, Endian.little);

    return MotionTelemetry(
      accelX: ax,
      accelY: ay,
      accelZ: az,
      gyroX: gx,
      gyroY: gy,
      gyroZ: gz,
      repCount: reps,
      cadence: cadence,
      motionIntensity: intensity,
      stepCount: steps,
      timestamp: DateTime.now(),
    );
  }
}
