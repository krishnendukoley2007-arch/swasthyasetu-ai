import 'package:flutter/material.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/fitness_theme.dart';
import '../../domain/models/heart_rate_zone.dart';
import '../../domain/models/workout_session.dart';
import '../motion_lab/motion_lab_screen.dart';
import '../pairing/ble_pairing_screen.dart';
import '../workout/live_workout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _bleService = FitnessBleService();
  int _currentBpm = 74;
  final int _currentCalories = 380;
  final int _dailySteps = 5420;

  // Athletic Strain vs Recovery state
  final double _dailyStrain = 13.8;
  final double _targetStrain = 16.5;
  final int _morningRecovery = 88;

  @override
  void initState() {
    super.initState();
    _bleService.vitalsStream.listen((vitals) {
      if (mounted) {
        setState(() {
          _currentBpm = vitals.heartRate;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentZone = HeartRateZone.getZoneForBpm(_currentBpm);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: FitnessTheme.neonLime),
            SizedBox(width: 8),
            Text('FITPULSE AI',
                style:
                    TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            tooltip: 'Sensor Hardware',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlePairingScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: '6-Axis Motion Lab',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MotionLabScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sensor Status Banner
            StreamBuilder<BleConnectionState>(
              stream: _bleService.stateStream,
              initialData: _bleService.state,
              builder: (context, snapshot) {
                final state = snapshot.data ?? BleConnectionState.disconnected;
                final isLive = state == BleConnectionState.connected ||
                    state == BleConnectionState.simulated;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isLive
                        ? FitnessTheme.neonLime.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLive ? FitnessTheme.neonLime : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLive ? Icons.sensors : Icons.sensors_off,
                        color: isLive ? FitnessTheme.neonLime : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isLive
                              ? (state == BleConnectionState.simulated
                                  ? 'Device: ESP32 + MPU6050 (Live Stream)'
                                  : 'Device: SSAI-SENSE Hardware Connected')
                              : 'No Wearable Connected — Tap to Pair',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      if (!isLive)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BlePairingScreen(),
                              ),
                            );
                          },
                          child: const Text('PAIR'),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Whoop-Style Daily Strain vs. Recovery Dual Dial
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FitnessTheme.surface, FitnessTheme.surfaceElevated],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FitnessTheme.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DAILY STRAIN VS RECOVERY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: FitnessTheme.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FitnessTheme.neonLime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'OPTIMAL OVERREACH',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: FitnessTheme.neonLime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Dual Ring Visual
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Strain Ring
                            SizedBox(
                              width: 90,
                              height: 90,
                              child: CircularProgressIndicator(
                                value: (_dailyStrain / 21.0).clamp(0.0, 1.0),
                                strokeWidth: 8,
                                backgroundColor: FitnessTheme.surfaceElevated,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    FitnessTheme.electricCyan),
                              ),
                            ),
                            // Inner Recovery Ring
                            SizedBox(
                              width: 66,
                              height: 66,
                              child: CircularProgressIndicator(
                                value:
                                    (_morningRecovery / 100.0).clamp(0.0, 1.0),
                                strokeWidth: 6,
                                backgroundColor: FitnessTheme.surfaceElevated,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    FitnessTheme.neonLime),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_dailyStrain',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900),
                                ),
                                const Text('STRAIN',
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: FitnessTheme.textSecondary,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: FitnessTheme.electricCyan,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(
                                  'Current Strain: $_dailyStrain / $_targetStrain',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: FitnessTheme.neonLime,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(
                                  'Morning Recovery: $_morningRecovery% (Prime)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Target strain achieved for muscular & aerobic adaptation without overtraining.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: FitnessTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Heart Rate & Zone Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REAL-TIME PULSE ZONE',
                              style: TextStyle(
                                color: FitnessTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Electrical ECG / PPG Telemetry',
                              style: TextStyle(
                                color: FitnessTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: currentZone.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: currentZone.color),
                          ),
                          child: Text(
                            currentZone.label.toUpperCase(),
                            style: TextStyle(
                              color: currentZone.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Icon(Icons.favorite,
                            color: currentZone.color, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          '$_currentBpm',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'BPM',
                          style: TextStyle(
                            fontSize: 16,
                            color: FitnessTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentZone.benefit,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: FitnessTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daily Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'CALORIES',
                    value: '$_currentCalories',
                    unit: 'kcal',
                    icon: Icons.local_fire_department,
                    color: FitnessTheme.warmOrange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'STEPS',
                    value: '$_dailySteps',
                    unit: 'steps',
                    icon: Icons.directions_walk,
                    color: FitnessTheme.electricCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    title: 'FORM',
                    value: '96%',
                    unit: 'quality',
                    icon: Icons.verified,
                    color: FitnessTheme.neonLime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Start Exercise Section
            const Text(
              'START COACHED WORKOUT',
              style: TextStyle(
                color: FitnessTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),

            ...WorkoutType.values.map((workout) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: FitnessTheme.surfaceElevated,
                      foregroundColor: FitnessTheme.neonLime,
                      child: Icon(_getWorkoutIcon(workout), size: 22),
                    ),
                    title: Text(
                      workout.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      workout.category,
                      style: const TextStyle(
                          color: FitnessTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.play_circle_fill,
                      color: FitnessTheme.neonLime,
                      size: 34,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LiveWorkoutScreen(workoutType: workout),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FitnessTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FitnessTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '$unit ($title)',
            style: const TextStyle(
                fontSize: 9,
                color: FitnessTheme.textSecondary,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  IconData _getWorkoutIcon(WorkoutType type) {
    switch (type) {
      case WorkoutType.squats:
        return Icons.fitness_center;
      case WorkoutType.pushups:
        return Icons.sports_gymnastics;
      case WorkoutType.bicepCurls:
        return Icons.sports_martial_arts;
      case WorkoutType.jumpingJacks:
        return Icons.accessibility_new;
      case WorkoutType.running:
        return Icons.directions_run;
      case WorkoutType.freeWorkout:
        return Icons.timer;
    }
  }
}
