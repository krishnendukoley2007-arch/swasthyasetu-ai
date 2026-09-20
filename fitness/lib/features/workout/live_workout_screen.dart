import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/motion/audio_coach_engine.dart';
import '../../core/motion/fatigue_tremor_engine.dart';
import '../../core/motion/placement_mode.dart';
import '../../core/motion/rep_counter_engine.dart';
import '../../core/theme/fitness_theme.dart';
import '../../core/widgets/biomechanical_avatar_painter.dart';
import '../../domain/models/athletic_strain.dart';
import '../../domain/models/heart_rate_zone.dart';
import '../../domain/models/workout_session.dart';
import 'workout_summary_screen.dart';

class LiveWorkoutScreen extends StatefulWidget {
  final WorkoutType workoutType;

  const LiveWorkoutScreen({super.key, required this.workoutType});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  final _bleService = FitnessBleService();
  final _audioCoach = AudioCoachEngine();
  final _tremorEngine = FatigueTremorEngine();
  late final RepCounterEngine _repEngine;

  WearablePlacement _placement = WearablePlacement.forearmWrist;

  StreamSubscription? _motionSub;
  StreamSubscription? _vitalsSub;

  int _bpm = 120;
  int _peakBpm = 120;
  int _reps = 0;
  double _calories = 0.0;
  double _formScore = 95.0;
  RepPhase _phase = RepPhase.idle;
  int _secondsElapsed = 0;
  Timer? _ticker;
  bool _isPaused = false;

  double _pitch = 0.0;
  double _roll = 0.0;
  double _jointAngle = 0.0;
  double _tremorIndex = 14.0;
  String _tremorAdvice = 'Smooth neural control';
  bool _tremorAlert = false;

  final Map<HeartRateZoneType, int> _zoneSeconds = {
    HeartRateZoneType.rest: 0,
    HeartRateZoneType.warmup: 0,
    HeartRateZoneType.fatBurn: 0,
    HeartRateZoneType.cardio: 0,
    HeartRateZoneType.anaerobic: 0,
    HeartRateZoneType.peak: 0,
  };

  final List<double> _waveformPoints = List.filled(40, 0.0);
  bool _show3dAvatar = true;

  @override
  void initState() {
    super.initState();
    _repEngine = RepCounterEngine(workoutType: widget.workoutType);

    _audioCoach.init();
    _audioCoach.speak(
        'Workout started! Get in position for ${widget.workoutType.displayName}.',
        highPriority: true);

    _startTimer();

    _vitalsSub = _bleService.vitalsStream.listen((vitals) {
      if (mounted && !_isPaused) {
        setState(() {
          _bpm = vitals.heartRate;
          if (_bpm > _peakBpm) _peakBpm = _bpm;
        });
      }
    });

    _motionSub = _bleService.motionStream.listen((motion) {
      if (mounted && !_isPaused) {
        final result = _repEngine.processSample(
          motion,
          _secondsElapsed.toDouble(),
        );

        // Biomechanical transformation according to placement
        final transformed = PlacementTransformer.transform(
          motion.accelX,
          motion.accelY,
          motion.accelZ,
          motion.gyroX,
          motion.gyroY,
          motion.gyroZ,
          _placement,
        );

        // Fatigue Tremor Evaluation
        final tremor = _tremorEngine.processTelemetry(motion);

        setState(() {
          if (result.totalReps > _reps) {
            _audioCoach.speakRepCount(result.totalReps);
          }

          _reps = result.totalReps;
          _phase = result.currentPhase;
          _formScore = result.formQuality;
          _calories = result.activeCalories;

          _pitch = motion.pitch;
          _roll = motion.roll;
          _jointAngle = transformed.jointAngle;

          _tremorIndex = tremor.tremorIndex;
          _tremorAdvice = tremor.coachingAdvice;
          _tremorAlert = tremor.shouldAlert;

          _waveformPoints.removeAt(0);
          _waveformPoints.add(motion.totalAcceleration);
        });

        if (tremor.shouldAlert && _tremorIndex > 82.0) {
          _audioCoach.speakPostureAlert(
              'Muscle tremor high! Control your eccentric descent!');
        }
      }
    });
  }

  void _startTimer() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isPaused) {
        setState(() {
          _secondsElapsed++;
          final zone = HeartRateZone.getZoneForBpm(_bpm);
          _zoneSeconds[zone.type] = (_zoneSeconds[zone.type] ?? 0) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _motionSub?.cancel();
    _vitalsSub?.cancel();
    _audioCoach.stop();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _finishWorkout() {
    _ticker?.cancel();
    _audioCoach.speak('Workout completed! Excellent athletic performance.',
        highPriority: true);

    // Compute estimated recovery drop (typically 20-35 BPM drop in 60s)
    final recoveryBpm = (_peakBpm - 28).clamp(65, _peakBpm);
    final strain = AthleticStrain.calculate(
      secondsInZone: _zoneSeconds,
      totalReps: _reps,
      morningRecoveryScore: 80,
    ).currentStrain;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          workoutType: widget.workoutType,
          totalReps: _reps,
          duration: Duration(seconds: _secondsElapsed),
          calories: _calories,
          formScore: _formScore,
          peakBpm: _peakBpm,
          recoveryBpm60s: recoveryBpm,
          strainAdded: strain,
          zoneTimes: _zoneSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone = HeartRateZone.getZoneForBpm(_bpm);

    return Scaffold(
      backgroundColor: FitnessTheme.background,
      appBar: AppBar(
        title: Text(widget.workoutType.displayName.toUpperCase()),
        actions: [
          IconButton(
            icon:
                Icon(_audioCoach.isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip:
                _audioCoach.isMuted ? 'Unmute Audio Coach' : 'Mute Audio Coach',
            onPressed: () {
              setState(() {
                _audioCoach.toggleMute();
              });
            },
          ),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Placement Selector & Zone HUD Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: FitnessTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: zone.color.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite, color: zone.color, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              '$_bpm BPM',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: zone.color,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: zone.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            zone.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: zone.color,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_secondsElapsed),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FitnessTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: FitnessTheme.border),

                    // Placement selector row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SENSOR PLACEMENT:',
                          style: TextStyle(
                            fontSize: 10,
                            color: FitnessTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<WearablePlacement>(
                          value: _placement,
                          dropdownColor: FitnessTheme.surfaceElevated,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: FitnessTheme.electricCyan),
                          style: const TextStyle(
                            color: FitnessTheme.electricCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          items: WearablePlacement.values.map((p) {
                            return DropdownMenuItem(
                                value: p, child: Text(p.label));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _placement = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Giant Rep Counter
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: FitnessTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FitnessTheme.border),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.workoutType.hasRepCounting
                          ? 'COMPLETED REPS'
                          : 'ELAPSED DURATION',
                      style: const TextStyle(
                        color: FitnessTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      widget.workoutType.hasRepCounting
                          ? '$_reps'
                          : _formatDuration(_secondsElapsed),
                      style: TextStyle(
                        fontSize: 76,
                        fontWeight: FontWeight.w900,
                        color: FitnessTheme.neonLime,
                        letterSpacing: -2,
                        shadows: [
                          Shadow(
                            color: FitnessTheme.neonLime.withValues(alpha: 0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPhaseColor(_phase).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _getPhaseColor(_phase)),
                      ),
                      child: Text(
                        _getPhaseText(_phase),
                        style: TextStyle(
                          color: _getPhaseColor(_phase),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Interactive Biomechanical Avatar / Waveform Switcher
              Container(
                height: 160,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitnessTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FitnessTheme.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _show3dAvatar
                              ? 'BIOMECHANICAL 3D SKELETON & JOINT HUD'
                              : '6-AXIS REAL-TIME MOTION STREAM',
                          style: const TextStyle(
                            fontSize: 10,
                            color: FitnessTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _show3dAvatar = !_show3dAvatar;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: FitnessTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _show3dAvatar
                                  ? 'SWITCH TO GRAPH'
                                  : 'SWITCH TO 3D',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: FitnessTheme.electricCyan,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _show3dAvatar
                          ? CustomPaint(
                              painter: BiomechanicalAvatarPainter(
                                workoutType: widget.workoutType,
                                pitch: _pitch,
                                roll: _roll,
                                jointAngle: _jointAngle,
                                formQuality: _formScore,
                              ),
                              child: Container(),
                            )
                          : CustomPaint(
                              painter: MotionWaveformPainter(
                                samples: _waveformPoints,
                                color: FitnessTheme.electricCyan,
                              ),
                              child: Container(),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Fatigue Tremor Index (FTI) Alert Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _tremorAlert
                      ? FitnessTheme.crimsonPeak.withValues(alpha: 0.15)
                      : FitnessTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _tremorAlert
                        ? FitnessTheme.crimsonPeak
                        : FitnessTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _tremorAlert ? Icons.warning : Icons.accessibility,
                      color: _tremorAlert
                          ? FitnessTheme.crimsonPeak
                          : FitnessTheme.electricCyan,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'FATIGUE TREMOR INDEX (FTI)',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: FitnessTheme.textSecondary),
                              ),
                              Text(
                                '${_tremorIndex.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _tremorAlert
                                      ? FitnessTheme.crimsonPeak
                                      : FitnessTheme.neonLime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tremorAdvice,
                            style: TextStyle(
                              fontSize: 11,
                              color: _tremorAlert
                                  ? FitnessTheme.crimsonPeak
                                  : FitnessTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Metrics Row: Calories & Form Accuracy
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBox(
                      title: 'ENERGY',
                      value: _calories.toStringAsFixed(1),
                      unit: 'kcal burned',
                      icon: Icons.local_fire_department,
                      color: FitnessTheme.warmOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricBox(
                      title: 'FORM STABILITY',
                      value: '${_formScore.round()}%',
                      unit: 'joint alignment',
                      icon: Icons.verified,
                      color: FitnessTheme.neonLime,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Finish Workout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('FINISH WORKOUT & VIEW VICTORY CARD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FitnessTheme.crimsonPeak,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _finishWorkout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox({
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FitnessTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      color: FitnessTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(unit,
              style:
                  const TextStyle(fontSize: 10, color: FitnessTheme.textMuted)),
        ],
      ),
    );
  }

  String _getPhaseText(RepPhase phase) {
    switch (phase) {
      case RepPhase.idle:
        return 'READY — BEGIN MOVEMENT';
      case RepPhase.eccentric:
        return 'LOWERING (DOWN)';
      case RepPhase.peakInflexion:
        return 'MAX INFLECTION';
      case RepPhase.concentric:
        return 'DRIVING UP (POWER)';
      case RepPhase.completed:
        return 'REP COUNTED!';
    }
  }

  Color _getPhaseColor(RepPhase phase) {
    switch (phase) {
      case RepPhase.idle:
        return FitnessTheme.textSecondary;
      case RepPhase.eccentric:
        return FitnessTheme.electricCyan;
      case RepPhase.peakInflexion:
        return FitnessTheme.vividAmber;
      case RepPhase.concentric:
        return FitnessTheme.neonLime;
      case RepPhase.completed:
        return FitnessTheme.neonLime;
    }
  }
}

class MotionWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  MotionWaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final dx = size.width / (samples.length - 1);
    final midY = size.height / 2;

    for (int i = 0; i < samples.length; i++) {
      final normalized = (samples[i] - 1.0) * (size.height / 2.5);
      final y = (midY - normalized).clamp(2.0, size.height - 2.0);

      if (i == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(i * dx, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MotionWaveformPainter oldDelegate) => true;
}
