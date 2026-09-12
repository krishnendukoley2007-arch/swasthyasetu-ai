import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

/// Clinical Clarke Error Grid Analysis (EGA) for blood glucose estimation.
///
/// Clarke EGA (Clarke et al., Diabetes Care 1987) is the clinical gold standard
/// for assessing non-invasive / optical PPG-PTT glucose estimation accuracy:
/// - Zone A: Clinically accurate (within 20% of reference or <70 mg/dL)
/// - Zone B: Benign errors (unlikely to cause adverse clinical outcomes)
/// - Zone C: Overcorrection errors (would prompt unwarranted treatment)
/// - Zone D: Dangerous failure to detect hypo/hyperglycemia
/// - Zone E: Erroneous treatment (reversing hypo/hyperglycemia)
const _kResearchNotice =
    'RESEARCH TOOL · Requires paired reference glucometer values. Not for clinical treatment.';

class ClarkeErrorGridWidget extends StatelessWidget {
  final double estimatedGlucose;
  final double? referenceGlucose;
  final String title;

  const ClarkeErrorGridWidget({
    super.key,
    required this.estimatedGlucose,
    this.referenceGlucose,
    this.title = 'Clarke Error Grid Analysis (EGA)',
  });

  /// Evaluates which Clarke Zone a pair (ref, est) belongs to.
  static String evaluateZone(double ref, double est) {
    if ((ref <= 70 && est <= 70) || (est >= 0.8 * ref && est <= 1.2 * ref)) {
      return 'Zone A';
    }
    if ((ref >= 180 && est <= 70) || (ref <= 70 && est >= 180)) {
      return 'Zone E';
    }
    if ((ref >= 70 && ref <= 290 && est >= ref + 110) ||
        (ref >= 130 && ref <= 180 && est <= (7.0 / 5.0) * ref - 182)) {
      return 'Zone C';
    }
    if ((ref >= 240 && est >= 70 && est <= 180) ||
        (ref <= 70 && est >= 70 && est <= 180)) {
      return 'Zone D';
    }
    return 'Zone B';
  }

  static Color zoneColor(String zone) {
    switch (zone) {
      case 'Zone A':
        return const Color(0xFF00C853);
      case 'Zone B':
        return const Color(0xFF64DD17);
      case 'Zone C':
        return const Color(0xFFFFAB00);
      case 'Zone D':
        return const Color(0xFFFF6D00);
      case 'Zone E':
      default:
        return const Color(0xFFD50000);
    }
  }

  static String zoneDescription(String zone) {
    switch (zone) {
      case 'Zone A':
        return 'Clinically Accurate: Estimation is within ±20% of reference. Treatment decisions are safe and correct.';
      case 'Zone B':
        return 'Benign Errors: Values fall outside ±20% but would lead to benign or no treatment deviation.';
      case 'Zone C':
        return 'Overcorrection Risk: Result would lead to unnecessary or excessive clinical correction.';
      case 'Zone D':
        return 'Failure to Detect: Critical failure to flag hypoglycemia (<70) or hyperglycemia (>240).';
      case 'Zone E':
      default:
        return 'Erroneous Treatment: Highly hazardous mismatch (treating hypo as hyper or vice versa).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // If no reference laboratory glucose was provided, default to a clinical baseline of 100 mg/dL for demonstration
    final ref = referenceGlucose ?? 105.0;
    final currentZone = evaluateZone(ref, estimatedGlucose);
    final color = zoneColor(currentZone);

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
          // Research / Analytical calibration disclaimer banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _kResearchNotice,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(Icons.grid_4x4_rounded, size: 18, color: color),
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
                      'ISO 15197 Non-Invasive Accuracy Standard',
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
                  currentZone,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Clarke Grid Plot Canvas
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 260.0);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _ClarkeGridPainter(
                      refGlucose: ref,
                      estGlucose: estimatedGlucose,
                      pointColor: color,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Zone summary & Clinical interpretation
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Result: ${estimatedGlucose.toStringAsFixed(1)} mg/dL · Reference: ${ref.toStringAsFixed(1)} mg/dL',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        zoneDescription(currentZone),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Legend Bar (Zones A to E)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildLegendPill('Zone A (Safe)', const Color(0xFF00C853)),
              _buildLegendPill('Zone B (Benign)', const Color(0xFF64DD17)),
              _buildLegendPill('Zone C (Unneeded rx)', const Color(0xFFFFAB00)),
              _buildLegendPill('Zone D (Hypo missed)', const Color(0xFFFF6D00)),
              _buildLegendPill('Zone E (Wrong rx)', const Color(0xFFD50000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ClarkeGridPainter extends CustomPainter {
  final double refGlucose;
  final double estGlucose;
  final Color pointColor;

  _ClarkeGridPainter({
    required this.refGlucose,
    required this.estGlucose,
    required this.pointColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const maxVal = 400.0;

    // Background
    final bgPaint = Paint()..color = const Color(0xFF131A1E);
    final clipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(8),
    );
    canvas.drawRRect(clipRRect, bgPaint);

    // Coordinate converters
    double toX(double ref) => (ref / maxVal) * w;
    double toY(double est) => h - (est / maxVal) * h;

    // Draw Grid Lines (100, 200, 300, 400)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    for (double g = 100; g <= 300; g += 100) {
      canvas.drawLine(Offset(toX(g), 0), Offset(toX(g), h), gridPaint);
      canvas.drawLine(Offset(0, toY(g)), Offset(w, toY(g)), gridPaint);
    }

    // 45-degree identity line (y = x)
    final identityPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(toX(0), toY(0)),
      Offset(toX(maxVal), toY(maxVal)),
      identityPaint,
    );

    // Zone A Polygons: ±20% boundaries
    // y = 1.2x (from x=58.33 to 400), y = 0.8x (from x=70 to 400)
    // Box [0, 70] x [0, 70]
    final zoneAPath = Path();
    zoneAPath.moveTo(toX(0), toY(0));
    zoneAPath.lineTo(toX(70), toY(0));
    zoneAPath.lineTo(toX(70), toY(56));
    zoneAPath.lineTo(toX(400), toY(320));
    zoneAPath.lineTo(toX(400), toY(400));
    zoneAPath.lineTo(toX(333.3), toY(400));
    zoneAPath.lineTo(toX(58.33), toY(70));
    zoneAPath.lineTo(toX(0), toY(70));
    zoneAPath.close();

    final zoneAPaint = Paint()
      ..color = const Color(0xFF00C853).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(zoneAPath, zoneAPaint);

    // Boundary lines for Zone A
    final zoneABoundaryPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(zoneAPath, zoneABoundaryPaint);

    // Zone E (Upper Left triangle: ref <= 70, est >= 180)
    final zoneEUpper = Path()
      ..moveTo(toX(0), toY(180))
      ..lineTo(toX(70), toY(180))
      ..lineTo(toX(70), toY(400))
      ..lineTo(toX(0), toY(400))
      ..close();
    final zoneEPaint = Paint()
      ..color = const Color(0xFFD50000).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawPath(zoneEUpper, zoneEPaint);

    // Zone E (Lower Right: ref >= 180, est <= 70)
    final zoneELower = Path()
      ..moveTo(toX(180), toY(0))
      ..lineTo(toX(400), toY(0))
      ..lineTo(toX(400), toY(70))
      ..lineTo(toX(180), toY(70))
      ..close();
    canvas.drawPath(zoneELower, zoneEPaint);

    // Zone Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawText(
      String text,
      double x,
      double y,
      Color col, {
      double size = 11,
    }) {
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
          color: col,
          fontSize: size,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));
    }

    drawText('A', toX(200), toY(200) - 14, const Color(0xFF00E676));
    drawText('B', toX(120), toY(220), const Color(0xFF64DD17));
    drawText('B', toX(280), toY(180), const Color(0xFF64DD17));
    drawText('E', toX(25), toY(320), const Color(0xFFFF5252));
    drawText('E', toX(320), toY(35), const Color(0xFFFF5252));

    // Axis tick marks & text
    drawText('0', toX(5), toY(15), Colors.white38, size: 9);
    drawText('400', toX(375), toY(15), Colors.white38, size: 9);
    drawText('Ref (mg/dL) →', toX(150), h - 14, Colors.white60, size: 9.5);
    drawText('↑ Est', 4, toY(380), Colors.white60, size: 9.5);

    // Plot Patient Reading (refGlucose, estGlucose)
    final ptX = toX(refGlucose.clamp(0.0, maxVal));
    final ptY = toY(estGlucose.clamp(0.0, maxVal));

    // Pulsing outer halo
    final haloPaint = Paint()
      ..color = pointColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ptX, ptY), 10, haloPaint);

    final dotPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ptX, ptY), 5.5, dotPaint);

    final dotCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ptX, ptY), 2.2, dotCorePaint);
  }

  @override
  bool shouldRepaint(covariant _ClarkeGridPainter oldDelegate) {
    return oldDelegate.refGlucose != refGlucose ||
        oldDelegate.estGlucose != estGlucose ||
        oldDelegate.pointColor != pointColor;
  }
}
