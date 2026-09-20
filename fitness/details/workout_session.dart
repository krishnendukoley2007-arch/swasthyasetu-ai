import 'heart_rate_zone.dart';

enum WorkoutType {
  squats('Squats', 'Strength / Lower Body', true),
  pushups('Push-Ups', 'Upper Body & Core', true),
  bicepCurls('Bicep Curls', 'Upper Body Strength', true),
  jumpingJacks('Jumping Jacks', 'Cardio / Agility', true),
  running('Running / Treadmill', 'Cardio Endurance', false),
  freeWorkout('Open Training', 'Full Body Conditioning', false);

  final String displayName;
  final String category;
  final bool hasRepCounting;

  const WorkoutType(this.displayName, this.category, this.hasRepCounting);
}

class WorkoutSession {
  final String id;
  final WorkoutType type;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final int totalReps;
  final double activeCalories;
  final int avgHeartRate;
  final int maxHeartRate;
  final double formAccuracy; // 0..100%
  final HeartRateZoneType dominantZone;

  const WorkoutSession({
    required this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.totalReps,
    required this.activeCalories,
    required this.avgHeartRate,
    required this.maxHeartRate,
    this.formAccuracy = 95.0,
    this.dominantZone = HeartRateZoneType.cardio,
  });

  bool get isActive => endTime == null;
}
