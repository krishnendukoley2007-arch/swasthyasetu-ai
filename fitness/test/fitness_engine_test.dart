import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitpulse_ai/core/bluetooth/ble_protocol.dart';
import 'package:fitpulse_ai/core/motion/fatigue_tremor_engine.dart';
import 'package:fitpulse_ai/core/motion/placement_mode.dart';
import 'package:fitpulse_ai/core/motion/rep_counter_engine.dart';
import 'package:fitpulse_ai/domain/models/athletic_strain.dart';
import 'package:fitpulse_ai/domain/models/heart_rate_zone.dart';
import 'package:fitpulse_ai/domain/models/motion_telemetry.dart';
import 'package:fitpulse_ai/domain/models/workout_session.dart';

void main() {
  group('FitnessBleProtocol Tests', () {
    test('Decodes 20-byte Vitals Telemetry correctly', () {
      final bytes = Uint8List(20);
      final byteData = ByteData.sublistView(bytes);

      bytes[0] = 0x01; // frameTelemetry
      bytes[1] = 0x01; // version
      bytes[2] = 135; // HR 135 bpm
      bytes[3] = 98; // SpO2 98%
      byteData.setInt16(4, 3680, Endian.little); // 36.80 C
      byteData.setUint16(6, 444, Endian.little); // RR interval 444 ms
      bytes[14] = 92; // Battery 92%
      byteData.setUint32(16, 50000, Endian.little); // Uptime 50000 ms

      final vitals = FitnessBleProtocol.parseVitals(bytes);
      expect(vitals, isNotNull);
      expect(vitals!.heartRate, 135);
      expect(vitals.spo2, 98);
      expect(vitals.temperature, closeTo(36.8, 0.01));
      expect(vitals.batteryPercent, 92);
    });

    test('Decodes 20-byte Motion Telemetry correctly', () {
      final bytes = Uint8List(20);
      final byteData = ByteData.sublistView(bytes);

      bytes[0] = 0x03; // frameMotion
      bytes[1] = 0x01; // version
      byteData.setInt16(2, 105, Endian.little); // accelX = 1.05 G
      byteData.setInt16(4, -20, Endian.little); // accelY = -0.20 G
      byteData.setInt16(6, 98, Endian.little); // accelZ = 0.98 G
      byteData.setInt16(8, 450, Endian.little); // gyroX = 45.0 deg/s
      byteData.setInt16(10, 120, Endian.little); // gyroY = 12.0 deg/s
      byteData.setInt16(12, -50, Endian.little); // gyroZ = -5.0 deg/s
      byteData.setUint16(14, 15, Endian.little); // 15 reps
      bytes[16] = 28; // cadence 28
      bytes[17] = 85; // intensity 85%
      byteData.setUint16(18, 3420, Endian.little); // 3420 steps

      final motion = FitnessBleProtocol.parseMotion(bytes);
      expect(motion, isNotNull);
      expect(motion!.accelX, closeTo(1.05, 0.01));
      expect(motion.accelY, closeTo(-0.20, 0.01));
      expect(motion.gyroX, closeTo(45.0, 0.1));
      expect(motion.repCount, 15);
      expect(motion.cadence, 28);
      expect(motion.motionIntensity, 85);
      expect(motion.stepCount, 3420);
    });
  });

  group('Heart Rate Zone Calculation', () {
    test('Maps BPM to appropriate training zones', () {
      expect(HeartRateZone.getZoneForBpm(70, userAge: 25).type,
          HeartRateZoneType.rest);
      expect(HeartRateZone.getZoneForBpm(105, userAge: 25).type,
          HeartRateZoneType.warmup);
      expect(HeartRateZone.getZoneForBpm(125, userAge: 25).type,
          HeartRateZoneType.fatBurn);
      expect(HeartRateZone.getZoneForBpm(145, userAge: 25).type,
          HeartRateZoneType.cardio);
      expect(HeartRateZone.getZoneForBpm(165, userAge: 25).type,
          HeartRateZoneType.anaerobic);
      expect(HeartRateZone.getZoneForBpm(185, userAge: 25).type,
          HeartRateZoneType.peak);
    });
  });

  group('Rep Counter Engine Tests', () {
    test('Accurately tracks repetition phases and increments reps', () {
      final engine = RepCounterEngine(workoutType: WorkoutType.squats);

      engine.processSample(
        MotionTelemetry(
          accelX: 0,
          accelY: 0,
          accelZ: 1.0,
          gyroX: 0,
          gyroY: 0,
          gyroZ: 0,
          timestamp: DateTime.now(),
        ),
        0.0,
      );
      expect(engine.reps, 0);

      final curve = [
        1.1,
        1.3,
        1.5,
        1.7,
        1.6,
        1.4,
        1.1,
        0.9,
        0.85,
        0.85,
        0.85,
        0.85
      ];
      for (int i = 0; i < curve.length; i++) {
        engine.processSample(
          MotionTelemetry(
            accelX: 0,
            accelY: 0.1,
            accelZ: curve[i],
            gyroX: 0,
            gyroY: 10,
            gyroZ: 0,
            timestamp: DateTime.now(),
          ),
          1.0 + (i * 0.2),
        );
      }

      expect(engine.reps, 1);
      expect(engine.calories, greaterThan(0.0));
    });
  });

  group('Advanced Biomechanics & Sports Science Tests', () {
    test('PlacementTransformer adjusts coordinate mappings appropriately', () {
      final thigh = PlacementTransformer.transform(
        0.1,
        0.3,
        1.2,
        10.0,
        5.0,
        2.0,
        WearablePlacement.thighAnkle,
      );
      expect(thigh.primaryAccel, 1.2);
      expect(thigh.primaryGyro, 10.0);

      final chest = PlacementTransformer.transform(
        0.2,
        0.9,
        0.1,
        4.0,
        15.0,
        1.0,
        WearablePlacement.chestStrap,
      );
      expect(chest.primaryAccel, 0.9);
      expect(chest.primaryGyro, 15.0);
    });

    test('FatigueTremorEngine detects jitter variance', () {
      final engine = FatigueTremorEngine();

      for (int i = 0; i < 15; i++) {
        final res = engine.processTelemetry(MotionTelemetry(
          accelX: 0.1,
          accelY: 0.2,
          accelZ: 1.0,
          gyroX: (i % 2 == 0 ? 80.0 : -80.0), // high frequency jitter
          gyroY: (i % 2 == 0 ? -60.0 : 60.0),
          gyroZ: 10.0,
          timestamp: DateTime.now(),
        ));

        if (i > 8) {
          expect(res.tremorIndex, greaterThan(20.0));
        }
      }
    });

    test('AthleticStrain computes 0.0 - 21.0 logarithmic scale', () {
      final lightStrain = AthleticStrain.calculate(
        secondsInZone: {
          HeartRateZoneType.warmup: 300,
          HeartRateZoneType.fatBurn: 120,
        },
        totalReps: 15,
        morningRecoveryScore: 85,
      );
      expect(lightStrain.currentStrain, greaterThan(0.0));
      expect(lightStrain.currentStrain, lessThan(10.0));
      expect(lightStrain.targetStrain, 16.5);

      final heavyStrain = AthleticStrain.calculate(
        secondsInZone: {
          HeartRateZoneType.cardio: 1200,
          HeartRateZoneType.anaerobic: 600,
          HeartRateZoneType.peak: 300,
        },
        totalReps: 120,
        morningRecoveryScore: 60,
      );
      expect(heavyStrain.currentStrain, greaterThan(12.0));
      expect(heavyStrain.currentStrain, lessThanOrEqualTo(21.0));
    });
  });
}
