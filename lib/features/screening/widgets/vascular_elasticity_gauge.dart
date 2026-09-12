import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Clinical Vascular Elasticity & Pulse Transit Time (PTT) Speedometer Gauge.
///
/// Illustrates:
/// - Pulse Transit Time (PTT): Time elapsed from ECG R-wave to peripheral PPG arrival
/// - Pulse Wave Velocity (PWV): Derived via Moens-Korteweg equation ($PWV = L / PTT$)
/// - Arterial stiffness and non-invasive Blood Pressure estimation foundation
class VascularElasticityGauge extends StatelessWidget {
  final double pttMs;
  final int? systolicBp;
  final int? diastolicBp;
  final String title;

  const VascularElasticityGauge({
    super.key,
    this.pttMs = 215.0,
    this.systolicBp,
    this.diastolicBp,
    this.title = 'Vascular Elasticity & PTT Speedometer',
  });

  /// Computes Pulse Wave Velocity (PWV in m/s) assuming nominal arterial path L = 0.85 m
  double get pwv => (0.85 / (pttMs / 1000.0)).clamp(3.0, 16.0);

  String get stiffnessClassification {
    if (pwv < 7.0) return 'Optimal Elasticity';
    if (pwv < 9.5) return 'Moderate Arterial Stiffness';
    return 'High Arterial Stiffness (Rigid)';
  }

  Color get classificationColor {
    if (pwv < 7.0) return const Color(0xFF00C853);
    if (pwv < 9.5) return const Color(0xFFFFAB00);
    return const Color(0xFFD50000);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = classificationColor;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.shadowLevel1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(Icons.speed_rounded, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'ECG R-Peak to PPG Transit Synchrony',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  stiffnessClassification.split(' ').first.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Speedometer Canvas
          Center(
            child: SizedBox(
              width: 240,
              height: 135,
              child: CustomPaint(
                painter: _VascularGaugePainter(pwv: pwv, stiffnessColor: color),
              ),
            ),
          ),

          // Numerical Readout Row
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      pwv.toStringAsFixed(1),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'm/s PWV',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Pulse Transit Time: ${pttMs.toStringAsFixed(0)} ms',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // BP Correlation & Physiological Derivation Box
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.monitor_heart_outlined,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cuffless BP Derivation Mechanism',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (systolicBp != null && diastolicBp != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$systolicBp / $diastolicBp mmHg',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'As ventricular pressure increases during systole, arterial wall tension rises, accelerating pulse wave velocity ($pwv m/s) and shortening transit time (${pttMs.round()} ms). Bramwell-Hill logarithmic regression translates this directly into calibrated systolic/diastolic pressure without an arm cuff.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VascularGaugePainter extends CustomPainter {
  final double pwv;
  final Color stiffnessColor;

  _VascularGaugePainter({required this.pwv, required this.stiffnessColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2.0, h - 10);
    final radius = math.min(w / 2.0 - 15, h - 20);

    const minPWV = 4.0;
    const maxPWV = 14.0;

    // Arc from 180 degrees (math.pi) to 0 degrees (0)
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background track arc
    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Colored Segments:
    // 1. Green (4.0 to 7.0) -> fraction 3.0 / 10.0 = 0.30
    // 2. Amber (7.0 to 9.5) -> fraction 2.5 / 10.0 = 0.25
    // 3. Red   (9.5 to 14.0)-> fraction 4.5 / 10.0 = 0.45

    void drawSegment(double fromPWV, double toPWV, Color col) {
      final fStart = (fromPWV - minPWV) / (maxPWV - minPWV);
      final fEnd = (toPWV - minPWV) / (maxPWV - minPWV);
      final aStart = startAngle + (fStart * sweepAngle);
      final aSweep = (fEnd - fStart) * sweepAngle;

      final segPaint = Paint()
        ..color = col.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        aStart,
        aSweep,
        false,
        segPaint,
      );
    }

    drawSegment(4.0, 7.0, const Color(0xFF00C853));
    drawSegment(7.0, 9.5, const Color(0xFFFFAB00));
    drawSegment(9.5, 14.0, const Color(0xFFD50000));

    // Needle pointer
    final pwvClamped = pwv.clamp(minPWV, maxPWV);
    final needleFraction = (pwvClamped - minPWV) / (maxPWV - minPWV);
    final needleAngle = startAngle + (needleFraction * sweepAngle);

    final needleLength = radius - 8;
    final needleTip = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleTip, needlePaint);

    // Center pivot knob
    final knobPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 6, knobPaint);

    final knobCorePaint = Paint()..color = const Color(0xFF0F171A);
    canvas.drawCircle(center, 3, knobCorePaint);

    // Tick labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawTick(String text, double x, double y) {
      tp.text = TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));
    }

    drawTick('4 m/s', 10, h - 22);
    drawTick('Elastic', 30, h - 45);
    drawTick('Stiff', w - 55, h - 45);
    drawTick('14 m/s', w - 38, h - 22);
  }

  @override
  bool shouldRepaint(covariant _VascularGaugePainter oldDelegate) {
    return oldDelegate.pwv != pwv ||
        oldDelegate.stiffnessColor != stiffnessColor;
  }
}
