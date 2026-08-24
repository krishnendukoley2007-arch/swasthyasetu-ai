/// Small inline charts used in list rows and summary cards.
library;

import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// A compact risk-score trend, oldest point on the left.
///
/// Takes scores already loaded by the caller — a list row must never kick off
/// its own database query, or scrolling 200 patients issues 200 queries.
/// `PatientSummary.riskTrend` supplies these.
class RiskSparkline extends StatelessWidget {
  final List<int> scores;
  final double width;
  final double height;

  const RiskSparkline({
    super.key,
    required this.scores,
    this.width = 56,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    // One point is not a trend, and zero points must still occupy the same slot
    // so rows with and without history stay aligned.
    if (scores.length < 2) {
      return SizedBox(
        width: width,
        height: height,
        child: scores.isEmpty
            ? null
            : Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _colorFor(scores.first),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          scores: scores,
          trackColor: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }

  static Color _colorFor(int score) =>
      switch (RiskEngine.bandForScore(score)) {
        RiskBand.green => AppTheme.riskGreen,
        RiskBand.yellow => AppTheme.riskYellow,
        RiskBand.red => AppTheme.riskRed,
      };
}

class _SparklinePainter extends CustomPainter {
  final List<int> scores;
  final Color trackColor;

  const _SparklinePainter({required this.scores, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed 0-100 domain rather than min/max of the data. An auto-scaled axis
    // would make a flat healthy series look like a dramatic swing.
    final domainMax = RiskEngine.maxScore.toDouble();
    final dx = size.width / (scores.length - 1);

    double yFor(int score) =>
        size.height -
        (score.clamp(0, RiskEngine.maxScore) / domainMax) * size.height;

    final points = <Offset>[
      for (var i = 0; i < scores.length; i++) Offset(i * dx, yFor(scores[i])),
    ];

    // Baseline at the GREEN/YELLOW boundary gives the line a reference to be
    // read against.
    canvas.drawLine(
      Offset(0, yFor(RiskEngine.greenMax)),
      Offset(size.width, yFor(RiskEngine.greenMax)),
      Paint()
        ..color = trackColor
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = RiskSparkline._colorFor(scores.last),
    );

    // Emphasise the latest reading — that is the number the worker acts on.
    canvas.drawCircle(
      points.last,
      3,
      Paint()..color = RiskSparkline._colorFor(scores.last),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.trackColor != trackColor ||
      old.scores.length != scores.length ||
      !_sameScores(old.scores, scores);

  static bool _sameScores(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
