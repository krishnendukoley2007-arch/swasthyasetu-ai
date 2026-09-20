import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/fitness_theme.dart';
import '../../domain/models/motion_telemetry.dart';

class MotionLabScreen extends StatefulWidget {
  const MotionLabScreen({super.key});

  @override
  State<MotionLabScreen> createState() => _MotionLabScreenState();
}

class _MotionLabScreenState extends State<MotionLabScreen> {
  final _bleService = FitnessBleService();
  StreamSubscription<MotionTelemetry>? _motionSub;

  MotionTelemetry _motion = MotionTelemetry.zero();
  double _pitchOffset = 0.0;
  double _rollOffset = 0.0;

  StreamSubscription<BleConnectionState>? _stateSub;

  @override
  void initState() {
    super.initState();
    // Honest zero-fake data policy: Never auto-start simulation

    _stateSub = _bleService.stateStream.listen((_) {
      if (mounted) setState(() {});
    });

    _motionSub = _bleService.motionStream.listen((data) {
      if (mounted) {
        setState(() {
          _motion = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _motionSub?.cancel();
    super.dispose();
  }

  void _calibrateZero() {
    setState(() {
      _pitchOffset = _motion.pitch;
      _rollOffset = _motion.roll;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gyroscope & Accelerometer zero-point calibrated!'),
        backgroundColor: FitnessTheme.neonLime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final correctedPitch = (_motion.pitch - _pitchOffset).clamp(-90.0, 90.0);
    final correctedRoll = (_motion.roll - _rollOffset).clamp(-90.0, 90.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('6-AXIS MOTION LAB (MPU6050)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Calibrate Zero Level',
            onPressed: _calibrateZero,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection / Source Status Banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _bleService.state == BleConnectionState.connected
                    ? FitnessTheme.neonLime.withValues(alpha: 0.12)
                    : (_bleService.state == BleConnectionState.simulated
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Colors.redAccent.withValues(alpha: 0.10)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _bleService.state == BleConnectionState.connected
                      ? FitnessTheme.neonLime
                      : (_bleService.state == BleConnectionState.simulated
                          ? Colors.amber
                          : Colors.redAccent),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _bleService.state == BleConnectionState.connected
                        ? Icons.bluetooth_connected
                        : (_bleService.state == BleConnectionState.simulated
                            ? Icons.science
                            : Icons.bluetooth_disabled),
                    color: _bleService.state == BleConnectionState.connected
                        ? FitnessTheme.neonLime
                        : (_bleService.state == BleConnectionState.simulated
                            ? Colors.amber
                            : Colors.redAccent),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _bleService.state == BleConnectionState.connected
                          ? 'LIVE HARDWARE STREAM (MPU-6050)'
                          : (_bleService.state == BleConnectionState.simulated
                              ? 'SIMULATED DEMO DATA'
                              : 'NO WEARABLE CONNECTED'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: _bleService.state == BleConnectionState.connected
                            ? FitnessTheme.neonLime
                            : (_bleService.state == BleConnectionState.simulated
                                ? Colors.amber
                                : Colors.redAccent),
                      ),
                    ),
                  ),
                  if (_bleService.state == BleConnectionState.disconnected) ...[
                    TextButton(
                      onPressed: () => _bleService.autoConnect(),
                      child: const Text('CONNECT',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: FitnessTheme.electricCyan)),
                    ),
                    TextButton(
                      onPressed: () => _bleService.startDemoSimulation(),
                      child: const Text('TRY DEMO',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber)),
                    ),
                  ] else if (_bleService.state ==
                      BleConnectionState.simulated) ...[
                    TextButton(
                      onPressed: () => _bleService.stopDemoSimulation(),
                      child: const Text('STOP DEMO',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent)),
                    ),
                  ],
                ],
              ),
            ),

            // Attitude / Artificial Horizon Indicator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'POSTURE & TILT ORIENTATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: FitnessTheme.textSecondary,
                          ),
                        ),
                        Icon(Icons.threed_rotation,
                            color: FitnessTheme.neonLime),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: AttitudeIndicatorPainter(
                          pitch: correctedPitch,
                          roll: correctedRoll,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAngleBadge(
                            'PITCH', '${correctedPitch.toStringAsFixed(1)}°'),
                        _buildAngleBadge(
                            'ROLL', '${correctedRoll.toStringAsFixed(1)}°'),
                        _buildAngleBadge(
                          'MAGNITUDE',
                          '${_motion.totalAcceleration.toStringAsFixed(2)} G',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3-Axis Accelerometer (Linear Dynamics)
            const Text(
              'ACCELEROMETER (G-FORCE)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: FitnessTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildAxisMeter('AXIS X (Lateral)', _motion.accelX, -2.0, 2.0, 'G',
                FitnessTheme.electricCyan),
            _buildAxisMeter('AXIS Y (Longitudinal)', _motion.accelY, -2.0, 2.0,
                'G', FitnessTheme.neonLime),
            _buildAxisMeter('AXIS Z (Vertical Gravity)', _motion.accelZ, -2.0,
                2.0, 'G', FitnessTheme.vividAmber),

            const SizedBox(height: 20),

            // 3-Axis Gyroscope (Angular Rates)
            const Text(
              'GYROSCOPE (ANGULAR VELOCITY)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: FitnessTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildAxisMeter('ROLL RATE (GX)', _motion.gyroX, -250.0, 250.0,
                '°/s', FitnessTheme.electricCyan),
            _buildAxisMeter('PITCH RATE (GY)', _motion.gyroY, -250.0, 250.0,
                '°/s', FitnessTheme.neonLime),
            _buildAxisMeter('YAW RATE (GZ)', _motion.gyroZ, -250.0, 250.0,
                '°/s', FitnessTheme.vividAmber),

            const SizedBox(height: 24),

            // Motion Metrics Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FitnessTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FitnessTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DEVICE CADENCE',
                            style: TextStyle(
                                fontSize: 11,
                                color: FitnessTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text('${_motion.cadence}',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                        const Text('steps/min',
                            style: TextStyle(
                                fontSize: 11, color: FitnessTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FitnessTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FitnessTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HARDWARE REPS',
                            style: TextStyle(
                                fontSize: 11,
                                color: FitnessTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text('${_motion.repCount}',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: FitnessTheme.neonLime)),
                        const Text('firmware counted',
                            style: TextStyle(
                                fontSize: 11, color: FitnessTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngleBadge(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: FitnessTheme.textSecondary,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAxisMeter(String name, double val, double min, double max,
      String unit, Color barColor) {
    final norm = ((val - min) / (max - min)).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${val.toStringAsFixed(2)} $unit',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: barColor)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: norm,
                backgroundColor: FitnessTheme.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttitudeIndicatorPainter extends CustomPainter {
  final double pitch;
  final double roll;

  AttitudeIndicatorPainter({required this.pitch, required this.roll});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height * 0.45;

    // Background circle
    final bgPaint = Paint()
      ..color = FitnessTheme.surfaceElevated
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final borderPaint = Paint()
      ..color = FitnessTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Save canvas state for roll & pitch rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-roll * 0.0174533); // convert to radians

    final pitchOffset = (pitch / 90.0) * radius;

    // Horizon line
    final horizonPaint = Paint()
      ..color = FitnessTheme.neonLime
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(-radius * 0.8, pitchOffset),
      Offset(radius * 0.8, pitchOffset),
      horizonPaint,
    );

    // Center pitch crosshair
    final crossPaint = Paint()
      ..color = FitnessTheme.electricCyan
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(-12, 0), const Offset(12, 0), crossPaint);
    canvas.drawLine(const Offset(0, -12), const Offset(0, 12), crossPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AttitudeIndicatorPainter oldDelegate) =>
      oldDelegate.pitch != pitch || oldDelegate.roll != roll;
}
