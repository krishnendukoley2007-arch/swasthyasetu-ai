import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:swasthyasetu_ai/core/services/fall_detection_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';

/// An interactive testing panel that connects directly to the phone's physical
/// accelerometer (`sensors_plus`) to simulate and test fall detection in real-time.
///
/// Features:
/// - Real-time 3-axis (X, Y, Z) and total magnitude (g-force) display
/// - Visual indication of the free-fall threshold (< 0.4 g) and impact threshold (> 2.6 g)
/// - One-tap synthetic fall simulation that verifies the state machine
/// - Direct trigger of the SOS emergency flow when a fall is confirmed
class PhoneFallSimulatorSheet extends ConsumerStatefulWidget {
  const PhoneFallSimulatorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => const PhoneFallSimulatorSheet(),
    );
  }

  @override
  ConsumerState<PhoneFallSimulatorSheet> createState() => _PhoneFallSimulatorSheetState();
}

class _PhoneFallSimulatorSheetState extends ConsumerState<PhoneFallSimulatorSheet> {
  StreamSubscription<AccelerometerEvent>? _sub;
  final FallDetector _detector = FallDetector();

  double _x = 0;
  double _y = 0;
  double _z = 9.8;
  double _magnitude = 9.8;
  double _peakG = 1.0;
  bool _fallTriggered = false;
  String _statusText = 'Monitoring accelerometer motion...';

  // Rolling history for mini-sparkline
  final List<double> _history = List.filled(40, 9.8);

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    try {
      _sub = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 40))
          .listen((event) {
        if (!mounted) return;
        final mag = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final g = mag / 9.81;

        final isFall = _detector.addSample(mag, DateTime.now());

        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;
          _magnitude = mag;
          _peakG = math.max(_peakG, g);

          _history.removeAt(0);
          _history.add(mag);

          if (_detector.phase == FallPhase.freeFall) {
            _statusText = '⚠️ FREE FALL DETECTED (< 0.4 g)';
          } else if (_detector.phase == FallPhase.awaitingImpact) {
            _statusText = '⚡ Awaiting Impact Spike...';
          } else if (isFall) {
            _fallTriggered = true;
            _statusText = '🚨 FALL CONFIRMED! Impact: ${g.toStringAsFixed(1)} g';
          } else if (!_fallTriggered) {
            _statusText = 'Normal motion. Shake or simulate drop.';
          }
        });
      }, onError: (err) {
        if (mounted) {
          setState(() {
            _statusText = 'Sensors unavailable on this platform ($err)';
          });
        }
      });
    } catch (e) {
      _statusText = 'Accelerometer sensor uninitialized: $e';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _simulateSyntheticFall() {
    // A synthetic sequence:
    // 1. Earth rest (9.8 m/s²)
    // 2. Free fall for 120ms (0.5 m/s²)
    // 3. Impact spike (32 m/s² ~ 3.3 g)
    final now = DateTime.now();
    _detector.addSample(9.8, now);
    _detector.addSample(1.2, now.add(const Duration(milliseconds: 40)));
    _detector.addSample(0.8, now.add(const Duration(milliseconds: 90)));
    _detector.addSample(2.1, now.add(const Duration(milliseconds: 140)));
    final detected = _detector.addSample(34.5, now.add(const Duration(milliseconds: 220)));

    setState(() {
      _peakG = 3.5;
      _fallTriggered = true;
      _statusText = detected
          ? '🚨 SIMULATED FALL DETECTED! (Impact: 3.5 g)'
          : 'Simulation completed';
    });
  }

  void _triggerSos() {
    Navigator.of(context).pop();
    final query = <String, String>{
      'trigger': SosTrigger.fallDetected.storageValue,
      'autoStart': 'true',
    };
    final uri = Uri(path: '/emergency/sos', queryParameters: query);
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gForce = _magnitude / 9.81;
    final isCritical = gForce > 2.6 || gForce < 0.4;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.vibration_rounded, color: theme.colorScheme.primary),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    'Phone IMU Fall Detector Simulator',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const AppSpacing.vsm(),
            Text(
              'Tests the onboard phone accelerometer for elderly & lone-worker fall detection (Zero Hardware Required).',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const AppSpacing.vmd(),

            // G-Force Meter
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: isCritical
                    ? AppTheme.riskRedContainer
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: isCritical ? AppTheme.riskRed : theme.colorScheme.outlineVariant,
                  width: isCritical ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current G-Force', style: theme.textTheme.labelMedium),
                      Text('Peak: ${_peakG.toStringAsFixed(2)} g',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${gForce.toStringAsFixed(2)} g',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isCritical ? AppTheme.riskRed : theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '|a| = ${_magnitude.toStringAsFixed(1)} m/s² (X: ${_x.toStringAsFixed(1)}, Y: ${_y.toStringAsFixed(1)}, Z: ${_z.toStringAsFixed(1)})',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (gForce / 4.0).clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation(
                      isCritical ? AppTheme.riskRed : theme.colorScheme.primary,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.0g (Freefall)', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                      Text('1.0g (Rest)', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                      Text('2.6g+ (Impact)', style: TextStyle(fontSize: 10, color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const AppSpacing.vmd(),

            // Live status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 8),
              decoration: BoxDecoration(
                color: _fallTriggered ? AppTheme.riskRedContainer : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: _fallTriggered ? AppTheme.riskRed : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _fallTriggered ? Icons.warning_rounded : Icons.info_outline_rounded,
                    color: _fallTriggered ? AppTheme.riskRed : theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _fallTriggered ? AppTheme.riskRed : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const AppSpacing.vlg(),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: 'Simulate Fall',
                    icon: const Icon(Icons.flash_on_rounded),
                    onPressed: _simulateSyntheticFall,
                  ),
                ),
                const AppSpacing.hmd(),
                Expanded(
                  child: AppButton(
                    label: 'Trigger SOS',
                    icon: const Icon(Icons.emergency_rounded),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.riskRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    onPressed: _triggerSos,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
