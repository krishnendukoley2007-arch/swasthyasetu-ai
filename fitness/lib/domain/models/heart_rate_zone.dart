import 'package:flutter/material.dart';

enum HeartRateZoneType {
  rest,
  warmup,
  fatBurn,
  cardio,
  anaerobic,
  peak,
}

class HeartRateZone {
  final HeartRateZoneType type;
  final String label;
  final int minBpm;
  final int maxBpm;
  final Color color;
  final String benefit;

  const HeartRateZone({
    required this.type,
    required this.label,
    required this.minBpm,
    required this.maxBpm,
    required this.color,
    required this.benefit,
  });

  static List<HeartRateZone> calculateZones({int userAge = 25}) {
    final maxHr = 220 - userAge;
    return [
      HeartRateZone(
        type: HeartRateZoneType.rest,
        label: 'Resting / Recovery',
        minBpm: 0,
        maxBpm: (maxHr * 0.50).round(),
        color: const Color(0xFF78909C),
        benefit: 'Active recovery and baseline health',
      ),
      HeartRateZone(
        type: HeartRateZoneType.warmup,
        label: 'Warm Up',
        minBpm: (maxHr * 0.50).round() + 1,
        maxBpm: (maxHr * 0.60).round(),
        color: const Color(0xFF00E5FF),
        benefit: 'Improves endurance & prepares body',
      ),
      HeartRateZone(
        type: HeartRateZoneType.fatBurn,
        label: 'Fat Burn',
        minBpm: (maxHr * 0.60).round() + 1,
        maxBpm: (maxHr * 0.70).round(),
        color: const Color(0xFF00E676),
        benefit: 'Maximizes fat utilization & basic aerobic capacity',
      ),
      HeartRateZone(
        type: HeartRateZoneType.cardio,
        label: 'Aerobic / Cardio',
        minBpm: (maxHr * 0.70).round() + 1,
        maxBpm: (maxHr * 0.80).round(),
        color: const Color(0xFFFFD600),
        benefit: 'Builds cardiovascular stamina & lung capacity',
      ),
      HeartRateZone(
        type: HeartRateZoneType.anaerobic,
        label: 'Anaerobic',
        minBpm: (maxHr * 0.80).round() + 1,
        maxBpm: (maxHr * 0.90).round(),
        color: const Color(0xFFFF9100),
        benefit: 'Enhances lactic acid threshold & high-speed endurance',
      ),
      HeartRateZone(
        type: HeartRateZoneType.peak,
        label: 'Peak Performance',
        minBpm: (maxHr * 0.90).round() + 1,
        maxBpm: maxHr,
        color: const Color(0xFFFF1744),
        benefit: 'Maximal oxygen consumption (VO2 Max) bursts',
      ),
    ];
  }

  static HeartRateZone getZoneForBpm(int bpm, {int userAge = 25}) {
    final zones = calculateZones(userAge: userAge);
    for (final zone in zones.reversed) {
      if (bpm >= zone.minBpm) {
        return zone;
      }
    }
    return zones.first;
  }
}
