import 'dart:math' as math;
import 'package:flutter/foundation.dart';

@immutable
class BpEstimate {
  final int systolic;
  final int diastolic;
  final String confidence;

  const BpEstimate({
    required this.systolic,
    required this.diastolic,
    this.confidence = 'EXPERIMENTAL',
  });

  bool get isValid => systolic > 0 && diastolic > 0;
}

@immutable
class GlucoseEstimate {
  final int glucoseMgDl;
  final String confidence;

  const GlucoseEstimate({
    required this.glucoseMgDl,
    this.confidence = 'EXPERIMENTAL',
  });

  bool get isValid => glucoseMgDl > 0;

  /// Classification according to ADA guidelines
  String get category {
    if (glucoseMgDl <= 0) return 'UNKNOWN';
    if (glucoseMgDl < 70) return 'HYPOGLYCEMIA';
    if (glucoseMgDl <= 140) return 'NORMAL';
    if (glucoseMgDl <= 180) return 'ELEVATED';
    if (glucoseMgDl <= 250) return 'HIGH';
    return 'CRITICAL_HIGH';
  }
}

/// Physiological Estimation Engine
///
/// Computes non-invasive estimates for:
/// 1. Blood Pressure (SBP/DBP in mmHg) via PTT (Pulse Transit Time)
/// 2. Blood Glucose (mg/dL) via Vascular Contraction & Autonomic Features
class VitalsEstimator {
  const VitalsEstimator._();

  /// Estimates Blood Pressure (Systolic & Diastolic) from PTT (ms), HR, Age, and BMI.
  static BpEstimate estimateBP({
    required int pttMs,
    required int heartRate,
    int age = 35,
    double? bmi,
  }) {
    if (pttMs <= 0 || heartRate <= 0) {
      return const BpEstimate(systolic: 0, diastolic: 0, confidence: 'INVALID');
    }

    final effectiveBmi = bmi ?? 23.0;
    final clampedPtt = math.max(100, math.min(380, pttMs));

    // Moens-Korteweg / Bramwell-Hill logarithmic formula calibrated for PPG/ECG
    final logPttRatio = math.log(220.0 / clampedPtt);
    final hrDelta = (heartRate - 72) * 0.12;
    final ageDelta = (age - 30) * 0.20;
    final bmiDelta = (effectiveBmi - 23.0) * 0.30;

    final sbp = (118.0 + (28.0 * logPttRatio) + hrDelta + ageDelta + bmiDelta).round();
    final dbp = (78.0 + (16.0 * logPttRatio) + (hrDelta * 0.7) + (ageDelta * 0.7) + (bmiDelta * 0.7)).round();

    final clampedSbp = sbp.clamp(80, 220);
    final clampedDbp = dbp.clamp(50, 130);

    return BpEstimate(
      systolic: clampedSbp,
      diastolic: clampedDbp,
      confidence: 'EXPERIMENTAL',
    );
  }

  /// Estimates Non-Invasive Blood Glucose (mg/dL) from PPG/ECG features.
  ///
  /// Based on vascular contraction signal analysis (Non-Invasive Glucose Estimation research).
  static GlucoseEstimate estimateGlucose({
    required int pttMs,
    required int heartRate,
    required int spo2,
    required double tempC,
    int age = 35,
    double? bmi,
    double ecgQuality = 1.0,
  }) {
    if (heartRate <= 0 || spo2 <= 0) {
      return const GlucoseEstimate(glucoseMgDl: 0, confidence: 'INVALID');
    }

    final effectiveBmi = bmi ?? 23.0;
    final effectivePtt = pttMs > 0 ? pttMs : 210;

    // Baseline fasting/normoglycemic baseline = 95 mg/dL
    const double baseline = 95.0;
    final ageComponent = (age - 30) * 0.35;
    final bmiComponent = (effectiveBmi - 22.0) * 0.90;
    final pttComponent = (210 - effectivePtt) * 0.32; // Higher arterial stiffness (lower PTT) correlates with higher glucose
    final hrComponent = (heartRate - 72) * 0.28;
    final spo2Component = (98 - spo2) * 1.2;
    final tempComponent = (tempC > 0 ? (tempC - 36.5) * 2.5 : 0.0);

    final rawGlucose = baseline + ageComponent + bmiComponent + pttComponent + hrComponent + spo2Component + tempComponent;
    final glucoseMgDl = rawGlucose.round().clamp(65, 320);

    final confidence = (ecgQuality < 0.5 || pttMs <= 0) ? 'LOW_CONFIDENCE' : 'EXPERIMENTAL';

    return GlucoseEstimate(
      glucoseMgDl: glucoseMgDl,
      confidence: confidence,
    );
  }
}
