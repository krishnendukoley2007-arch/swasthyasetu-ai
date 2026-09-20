import 'dart:math' as math;
import 'heart_rate_zone.dart';

class AthleticStrain {
  final double currentStrain; // 0.0 to 21.0
  final double targetStrain; // based on morning recovery
  final int totalWorkJoules;
  final Map<HeartRateZoneType, int> secondsInZone;

  const AthleticStrain({
    required this.currentStrain,
    required this.targetStrain,
    required this.totalWorkJoules,
    required this.secondsInZone,
  });

  /// Computes Whoop-style non-linear cardiovascular & mechanical strain (0.0 - 21.0)
  static AthleticStrain calculate({
    required Map<HeartRateZoneType, int> secondsInZone,
    required int totalReps,
    required int morningRecoveryScore, // 0..100
  }) {
    // 1. Cardiovascular load calculation
    double cardioLoad = 0.0;
    cardioLoad += (secondsInZone[HeartRateZoneType.warmup] ?? 0) * 1.0;
    cardioLoad += (secondsInZone[HeartRateZoneType.fatBurn] ?? 0) * 2.5;
    cardioLoad += (secondsInZone[HeartRateZoneType.cardio] ?? 0) * 6.0;
    cardioLoad += (secondsInZone[HeartRateZoneType.anaerobic] ?? 0) * 14.0;
    cardioLoad += (secondsInZone[HeartRateZoneType.peak] ?? 0) * 32.0;

    // 2. Mechanical load (Reps * estimated muscular impulse)
    final mechanicalLoad = totalReps * 45.0;
    final totalLoad = cardioLoad + mechanicalLoad;

    // Logarithmic scale mapping to 0..21.0
    // As load approaches infinity, strain asymptotically approaches 21.0
    final strain =
        (21.0 * (1.0 - math.exp(-0.00035 * totalLoad))).clamp(0.0, 21.0);

    // Target strain derived from morning autonomic readiness
    double target;
    if (morningRecoveryScore >= 80) {
      target = 16.5; // High readiness -> Overreach & build
    } else if (morningRecoveryScore >= 50) {
      target = 12.0; // Maintenance
    } else {
      target = 8.0; // Active recovery
    }

    return AthleticStrain(
      currentStrain: strain,
      targetStrain: target,
      totalWorkJoules: (totalLoad * 2.8).round(),
      secondsInZone: secondsInZone,
    );
  }

  String get strainCategory {
    if (currentStrain < 6.0) return 'Light / Rest';
    if (currentStrain < 10.0) return 'Moderate Activity';
    if (currentStrain < 14.0) return 'Strenuous Workout';
    if (currentStrain < 18.0) return 'High Overload';
    return 'All-Out Exhaustion';
  }
}
