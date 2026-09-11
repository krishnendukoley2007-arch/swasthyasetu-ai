import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Clinical Poincaré Plot ($RR_n$ vs $RR_{n+1}$) for Heart Rate Variability (HRV).
///
/// Maps consecutive RR intervals to instantly diagnose:
/// - Vagal tone & Parasympathetic modulation (SD1 semi-minor axis)
/// - Sympathetic tone & overall autonomic variance (SD2 semi-major axis)
/// - Autonomic balance ratio (SD1 / SD2)
/// - Arrhythmias: Atrial Fibrillation exhibits an amorphous "cloud", ectopy produces 4-point clusters
class PoincarePlotWidget extends StatelessWidget {
  final List<int>? rrIntervalsMs;
  final double heartRateBpm;
  final bool hasArrhythmia;
  final String title;

  const PoincarePlotWidget({
    super.key,
    this.rrIntervalsMs,
    this.heartRateBpm = 72,
    this.hasArrhythmia = false,
    this.title = 'Poincaré Plot (RR Interval HRV)',
  });

  /// Generates synthetic RR intervals if actual raw tachogram isn't passed
  List<int> _getEffectiveRR() {
    if (rrIntervalsMs != null && rrIntervalsMs!.length >= 10) {
      return rrIntervalsMs!;
    }
    // Synthesize 60 beats based on heartRateBpm and arrhythmia state
    final meanRR = (60000.0 / heartRateBpm.clamp(40.0, 180.0)).round();
    final rng = math.Random(42);
    final list = <int>[];

    for (int i = 0; i < 60; i++) {
      if (hasArrhythmia) {
        // High chaotic dispersion for AFib / arrhythmia
        final jitter = (rng.nextDouble() - 0.5) * (meanRR * 0.45);
        list.add((meanRR + jitter).round().clamp(350, 1400));
      } else {
        // Normal respiratory sinus arrhythmia (RSA) + mild autonomic jitter
        final rsa = 40.0 * math.sin(i * 0.3);
        final jitter = (rng.nextDouble() - 0.5) * 20.0;
        list.add((meanRR + rsa + jitter).round().clamp(400, 1300));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rrs = _getEffectiveRR();

    // Compute SD1, SD2, and SD1/SD2
    final metrics = _calculatePoincareMetrics(rrs);

    final statusColor = hasArrhythmia
        ? AppTheme.riskRed
        : (metrics.sdRatio < 0.25 || metrics.sdRatio > 0.85
              ? AppTheme.riskYellow
              : AppTheme.riskGreen);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.bubble_chart_rounded,
                  size: 18,
                  color: statusColor,
                ),
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
                      'Autonomic Parasympathetic vs Sympathetic Dynamics',
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
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  hasArrhythmia ? 'ARRHYTHMIA' : 'SINUS RHYTHM',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Poincaré Canvas
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _PoincarePainter(
                  rrList: rrs,
                  metrics: metrics,
                  hasArrhythmia: hasArrhythmia,
                  accentColor: statusColor,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // HRV Telemetry Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  label: 'SD1 (Short-term)',
                  value: '${metrics.sd1.toStringAsFixed(1)} ms',
                  sub: 'Vagal tone',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  label: 'SD2 (Long-term)',
                  value: '${metrics.sd2.toStringAsFixed(1)} ms',
                  sub: 'Sympathetic tone',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  label: 'SD1/SD2 Ratio',
                  value: metrics.sdRatio.toStringAsFixed(2),
                  sub: 'Target 0.35 - 0.75',
                  highlightColor: statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Clinical Diagnostic Insight
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasArrhythmia
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasArrhythmia
                        ? 'Broad chaotic cloud dispersion observed. Lack of identity-line clustering indicates ectopic beats or irregular rhythm (e.g., Atrial Fibrillation).'
                        : 'Elongated torpedo ellipse aligned along identity axis (r = 1.0). Demonstrates robust parasympathetic autonomic modulation and healthy sinus variability.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required String sub,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlightColor ?? theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 9,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static _PoincareMetrics _calculatePoincareMetrics(List<int> rrs) {
    if (rrs.length < 2) {
      return _PoincareMetrics(meanRR: 800, sd1: 25, sd2: 60, sdRatio: 0.42);
    }

    final double mean = rrs.reduce((a, b) => a + b) / rrs.length;

    // Variance of RR
    double sumVar = 0.0;
    for (final r in rrs) {
      sumVar += math.pow(r - mean, 2);
    }
    final varRR = sumVar / (rrs.length - 1);

    // Differences: RR_{n+1} - RR_n
    final diffs = <double>[];
    for (int i = 0; i < rrs.length - 1; i++) {
      diffs.add((rrs[i + 1] - rrs[i]).toDouble());
    }

    double diffMean = diffs.reduce((a, b) => a + b) / diffs.length;
    double sumDiffVar = 0.0;
    for (final d in diffs) {
      sumDiffVar += math.pow(d - diffMean, 2);
    }
    final varDiff = sumDiffVar / (diffs.length - 1);

    // SD1 = sqrt(0.5 * Var(RR_n - RR_{n+1}))
    final sd1 = math.sqrt(math.max(1.0, 0.5 * varDiff));
    // SD2 = sqrt(2 * Var(RR) - 0.5 * Var(RR_n - RR_{n+1}))
    final sd2 = math.sqrt(math.max(1.0, 2 * varRR - 0.5 * varDiff));
    final ratio = sd2 > 0 ? (sd1 / sd2) : 0.0;

    return _PoincareMetrics(meanRR: mean, sd1: sd1, sd2: sd2, sdRatio: ratio);
  }
}

class _PoincareMetrics {
  final double meanRR;
  final double sd1;
  final double sd2;
  final double sdRatio;

  _PoincareMetrics({
    required this.meanRR,
    required this.sd1,
    required this.sd2,
    required this.sdRatio,
  });
}

class _PoincarePainter extends CustomPainter {
  final List<int> rrList;
  final _PoincareMetrics metrics;
  final bool hasArrhythmia;
  final Color accentColor;

  _PoincarePainter({
    required this.rrList,
    required this.metrics,
    required this.hasArrhythmia,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Minimum & maximum RR window [400 ms, 1400 ms]
    const minRR = 400.0;
    const maxRR = 1400.0;

    // Dark canvas background
    final bgPaint = Paint()..color = const Color(0xFF0F171A);
    final clipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(clipRRect, bgPaint);

    double toX(double rr) => ((rr - minRR) / (maxRR - minRR)) * w;
    double toY(double rr) => h - (((rr - minRR) / (maxRR - minRR)) * h);

    // 1. Grid Lines (every 200 ms: 600, 800, 1000, 1200)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    for (double g = 600; g <= 1200; g += 200) {
      canvas.drawLine(Offset(toX(g), 0), Offset(toX(g), h), gridPaint);
      canvas.drawLine(Offset(0, toY(g)), Offset(w, toY(g)), gridPaint);
    }

    // 2. Identity Line: RR_n = RR_{n+1}
    final identityPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(toX(minRR), toY(minRR)),
      Offset(toX(maxRR), toY(maxRR)),
      identityPaint,
    );

    // 3. Draw Confidence Ellipse (centered at (meanRR, meanRR))
    final cx = toX(metrics.meanRR);
    final cy = toY(metrics.meanRR);

    canvas.save();
    canvas.translate(cx, cy);
    // Rotate by -45 degrees (line of identity in canvas coordinates where y is inverted)
    canvas.rotate(-math.pi / 4.0);

    // Ellipse radius in pixels
    final rx = (metrics.sd2 * 2.0 / (maxRR - minRR)) * w;
    final ry = (metrics.sd1 * 2.0 / (maxRR - minRR)) * h;

    final ellipseFillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final ellipseStrokePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final ellipseRect = Rect.fromCenter(
      center: Offset.zero,
      width: rx * 2,
      height: ry * 2,
    );
    canvas.drawOval(ellipseRect, ellipseFillPaint);
    canvas.drawOval(ellipseRect, ellipseStrokePaint);

    canvas.restore();

    // 4. Plot RR Scatter Points (RR_n, RR_{n+1})
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rrList.length - 1; i++) {
      final x = toX(rrList[i].toDouble().clamp(minRR, maxRR));
      final y = toY(rrList[i + 1].toDouble().clamp(minRR, maxRR));
      canvas.drawCircle(Offset(x, y), 3.0, dotPaint);
    }

    // 5. Draw Axis Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(String text, double x, double y) {
      tp.text = TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white60, fontSize: 9.5),
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));
    }

    drawLabel('RR_n (ms) →', toX(850), h - 14);
    drawLabel('↑ RR_n+1', 4, toY(1350));
    drawLabel('Line of Identity', toX(1020), toY(1100));
  }

  @override
  bool shouldRepaint(covariant _PoincarePainter oldDelegate) {
    return oldDelegate.rrList != rrList ||
        oldDelegate.hasArrhythmia != hasArrhythmia ||
        oldDelegate.accentColor != accentColor;
  }
}
