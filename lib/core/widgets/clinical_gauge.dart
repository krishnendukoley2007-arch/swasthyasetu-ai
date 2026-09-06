import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One segment of a gauge's range, e.g. a triage threshold band.
class ArcBand {
  const ArcBand(this.from, this.to, this.color);
  final double from, to; // on the gauge's 0–100 scale
  final Color color;
}

/// Semicircular band gauge (risk-score style). Gradient stroke is allowed
/// here by the design rules — gauges and CTAs are the exception.
///
/// The value animates in with a 900 ms ease-out; a bright marker dot sits on
/// the arc at the current reading.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.value,
    required this.bands,
    this.size = 148,
    this.child,
    this.semanticsLabel,
  });

  final double value; // 0–100
  final List<ArcBand> bands;
  final double size;
  final Widget? child;

  /// What a screen reader announces for this gauge, e.g.
  /// "Risk score 72 out of 100, urgent". Falls back to the raw value.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: semanticsLabel,
      value: semanticsLabel == null ? '${value.round()} of 100' : null,
      child: TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 100)),
      // Reduced motion: the gauge must still show the final value, just
      // without the sweep.
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size * 0.72,
        child: CustomPaint(
          painter: _GaugePainter(v, bands),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.18),
              child: child,
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.v, this.bands);
  final double v;
  final List<ArcBand> bands;

  static const _a0 = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(0, 0, size.width, size.width);
    final r = rect.deflate(9);
    double ang(double x) => _a0 + _sweep * (x / 100);

    for (final b in bands) {
      canvas.drawArc(
        r,
        ang(b.from),
        _sweep * ((b.to - b.from) / 100),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.butt
          ..color = b.color.withValues(alpha: 0.18),
      );
      final litTo = math.min(b.to, v);
      if (litTo > b.from) {
        canvas.drawArc(
          r,
          ang(b.from),
          _sweep * ((litTo - b.from) / 100),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..color = b.color,
        );
      }
    }

    final a = ang(v);
    final c = r.center;
    final p = Offset(
      c.dx + math.cos(a) * r.width / 2,
      c.dy + math.sin(a) * r.width / 2,
    );
    canvas.drawCircle(
      p,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.v != v;
}
