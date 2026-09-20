import 'package:flutter/material.dart';
import '../../core/theme/fitness_theme.dart';
import '../../domain/models/heart_rate_zone.dart';
import '../../domain/models/workout_session.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final WorkoutType workoutType;
  final int totalReps;
  final Duration duration;
  final double calories;
  final double formScore; // 0..100%
  final int peakBpm;
  final int recoveryBpm60s; // BPM after 60 seconds
  final double strainAdded;
  final Map<HeartRateZoneType, int> zoneTimes;

  const WorkoutSummaryScreen({
    super.key,
    required this.workoutType,
    required this.totalReps,
    required this.duration,
    required this.calories,
    required this.formScore,
    required this.peakBpm,
    required this.recoveryBpm60s,
    required this.strainAdded,
    required this.zoneTimes,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getFormGrade() {
    if (formScore >= 95.0) return 'GRADE A+';
    if (formScore >= 88.0) return 'GRADE A';
    if (formScore >= 78.0) return 'GRADE B';
    return 'GRADE C';
  }

  @override
  Widget build(BuildContext context) {
    final hrrDrop = peakBpm - recoveryBpm60s;
    final isEliteHrr = hrrDrop >= 25;

    return Scaffold(
      backgroundColor: FitnessTheme.background,
      appBar: AppBar(
        title: const Text('WORKOUT VICTORY CARD'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Victory Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    FitnessTheme.surface,
                    FitnessTheme.surfaceElevated,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: FitnessTheme.neonLime.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: FitnessTheme.neonLime.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events,
                      color: FitnessTheme.vividAmber, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    workoutType.displayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: FitnessTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getFormGrade(),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: FitnessTheme.neonLime,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '${formScore.toStringAsFixed(0)}% Gyroscope Biomechanical Consistency',
                    style: const TextStyle(
                      fontSize: 12,
                      color: FitnessTheme.textSecondary,
                    ),
                  ),
                  const Divider(height: 32, color: FitnessTheme.border),

                  // Metrics Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('COMPLETED', '$totalReps reps'),
                      _buildSummaryStat('DURATION', _formatDuration(duration)),
                      _buildSummaryStat(
                          'ENERGY', '${calories.toStringAsFixed(1)} kcal'),
                      _buildSummaryStat(
                          'STRAIN', '+${strainAdded.toStringAsFixed(1)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 60-Second Heart Rate Recovery (HRR) Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '60s HEART RATE RECOVERY (HRR)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: FitnessTheme.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isEliteHrr
                                    ? FitnessTheme.neonLime
                                    : FitnessTheme.vividAmber)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isEliteHrr ? 'ELITE RECOVERY' : 'MODERATE',
                            style: TextStyle(
                              color: isEliteHrr
                                  ? FitnessTheme.neonLime
                                  : FitnessTheme.vividAmber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHrrPoint(
                            'PEAK BPM', '$peakBpm', FitnessTheme.crimsonPeak),
                        const Icon(Icons.arrow_forward,
                            color: FitnessTheme.textMuted, size: 20),
                        _buildHrrPoint('AT 60 SECONDS', '$recoveryBpm60s',
                            FitnessTheme.electricCyan),
                        const Icon(Icons.arrow_forward,
                            color: FitnessTheme.textMuted, size: 20),
                        _buildHrrPoint(
                            'HRR DROP', '-$hrrDrop BPM', FitnessTheme.neonLime),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isEliteHrr
                          ? 'Outstanding cardiovascular recovery. Your parasympathetic autonomic nervous system rapidly drops your heart rate, indicating top-tier aerobic conditioning.'
                          : 'Standard aerobic recovery. Continued HIIT and cardiovascular training will accelerate your 60-second recovery slope.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FitnessTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Unlocked Badges
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: FitnessTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FitnessTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACHIEVEMENTS UNLOCKED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: FitnessTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(Icons.bolt, '3-1-1 TEMPO MASTERY',
                          FitnessTheme.neonLime),
                      _buildBadge(Icons.favorite, 'CARDIO OVERLOAD',
                          FitnessTheme.electricCyan),
                      _buildBadge(Icons.verified, 'ZERO CHEATING DETECTED',
                          FitnessTheme.vividAmber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('SHARE CARD'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FitnessTheme.electricCyan,
                      side: const BorderSide(color: FitnessTheme.electricCyan),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Victory Card exported to clipboard & gallery!'),
                          backgroundColor: FitnessTheme.neonLime,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('DONE'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // back to workout
                      Navigator.pop(context); // back to dashboard
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: FitnessTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHrrPoint(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: FitnessTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
