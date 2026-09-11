import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/clinical_primitives.dart';

/// One point on a series. A null [v] is a BLE dropout: it renders as a gap in
/// the trace, never interpolated into a fake line.
class SeriesSample {
  const SeriesSample(this.t, this.v);
  final double t;
  final double? v;
}

/// A shaded y-range (e.g. the usual baseline band) with an optional label.
class ChartBand {
  const ChartBand({
    required this.from,
    required this.to,
    required this.color,
    this.label,
  });
  final double from, to;
  final Color color;
  final String? label;
}

/// Round-number y ticks for a readable axis.
List<double> niceTicks(double min, double max, int count) {
  if (max - min < 1e-9) max = min + 1;
  final step0 = (max - min) / count;
  final mag = math.pow(10, (math.log(step0) / math.ln10).floor()).toDouble();
  final n = step0 / mag;
  final step =
      (n < 1.5
          ? 1
          : n < 3
          ? 2
          : n < 7
          ? 5
          : 10) *
      mag;
  final out = <double>[];
  for (double v = (min / step).ceil() * step; v <= max + 1e-9; v += step) {
    out.add(v);
  }
  return out;
}

/// Clinical time-series chart.
///
/// * Null samples render as visible gaps — dropout is data.
/// * Y axis has real labelled ticks (tabular figures) carrying the metric's
///   scale; the x axis labels the time span.
/// * Scrubbing shows a value tooltip with unit; crossing a sample gives a
///   haptic tick.
/// * [reference] draws a dashed baseline ("your usual") that a deviating
///   trace visibly crosses.
class SeriesChart extends StatefulWidget {
  const SeriesChart({
    super.key,
    required this.data,
    required this.stroke,
    required this.unit,
    required this.xLabel,
    this.bands = const [],
    this.height = 170,
    this.reference,
    this.referenceLabel,
    this.yMin,
    this.yMax,
    this.yDecimals = 0,
    this.overlay,
    this.overlayStroke,
  });

  final List<SeriesSample> data;
  final Color stroke;
  final String unit;
  final String Function(double t) xLabel;
  final List<ChartBand> bands;
  final double height;
  final double? reference;
  final String? referenceLabel;
  final double? yMin, yMax;
  final int yDecimals;

  /// A second series drawn on the same axes — line only, no fill, no dots.
  /// Used for "total vs high-risk" style comparisons.
  final List<SeriesSample>? overlay;
  final Color? overlayStroke;

  @override
  State<SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<SeriesChart>
    with SingleTickerProviderStateMixin {
  static const padL = 40.0, padR = 12.0, padT = 12.0, padB = 20.0;

  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _drawn = false;
  int? _scrub;

  @override
  void initState() {
    super.initState();
    // Reduced motion (system or in-app) skips the draw-in: the chart appears
    // fully formed rather than animating.
    if (_drawn) return;
    _draw.forward();
    _drawn = true;
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  (double, double) _range() {
    final vals = [
      for (final s in widget.data)
        if (s.v != null) s.v!,
    ];
    if (widget.overlay != null) {
      for (final s in widget.overlay!) {
        if (s.v != null) vals.add(s.v!);
      }
    }
    for (final b in widget.bands) {
      vals.add(b.from);
      vals.add(b.to);
    }
    if (widget.reference != null) vals.add(widget.reference!);
    if (vals.isEmpty) return (0, 1);
    var lo = widget.yMin ?? vals.reduce(math.min);
    var hi = widget.yMax ?? vals.reduce(math.max);
    if (widget.yMin == null || widget.yMax == null) {
      final p = (hi - lo) * 0.12 + 0.5;
      if (widget.yMin == null) lo -= p;
      if (widget.yMax == null) hi += p;
    }
    return (lo, hi);
  }

  void _setScrub(double dx, double w) {
    final n = widget.data.length;
    if (n < 2) return;
    final i = ((dx - padL) / (w - padL - padR) * (n - 1)).round().clamp(
      0,
      n - 1,
    );
    if (i != _scrub) {
      HapticFeedback.selectionClick();
      setState(() => _scrub = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFE7EEF8) : const Color(0xFF0F1B2D);
    final grid = ink.withValues(alpha: 0.10);
    final label = ink.withValues(alpha: 0.55);
    final (lo, hi) = _range();
    final data = widget.data;

    if (data.length < 2 || data.where((s) => s.v != null).length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            '—  not enough readings in range',
            style: TextStyle(fontSize: 12, color: label),
          ),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (_, cons) {
          final w = cons.maxWidth;
          final innerW = w - padL - padR;
          final innerH = widget.height - padT - padB;
          double xFor(int i) => padL + i / (data.length - 1) * innerW;
          double yFor(double v) => padT + (1 - (v - lo) / (hi - lo)) * innerH;

          return Stack(
            children: [
              AnimatedBuilder(
                animation: _draw,
                builder: (_, __) => CustomPaint(
                  size: Size(w, widget.height),
                  painter: _SeriesPainter(
                    data: data,
                    stroke: widget.stroke,
                    bands: widget.bands,
                    ticks: niceTicks(lo, hi, 4),
                    yMin: lo,
                    yMax: hi,
                    yDecimals: widget.yDecimals,
                    progress: reduceMotion
                        ? 1.0
                        : Curves.easeOutCubic.transform(_draw.value),
                    reference: widget.reference,
                    referenceLabel: widget.referenceLabel,
                    overlay: widget.overlay,
                    overlayStroke: widget.overlayStroke,
                    xLabel: widget.xLabel,
                    grid: grid,
                    label: label,
                  ),
                ),
              ),
              if (_scrub != null) ...[
                Positioned(
                  left: xFor(_scrub!) - 0.5,
                  top: padT,
                  height: innerH,
                  width: 1,
                  child: Container(color: widget.stroke.withValues(alpha: 0.4)),
                ),
                if (data[_scrub!].v != null)
                  Positioned(
                    left: xFor(_scrub!) - 4,
                    top: yFor(data[_scrub!].v!) - 4,
                    width: 8,
                    height: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.stroke,
                        border: Border.all(color: ink, width: 1.5),
                      ),
                    ),
                  ),
                Positioned(
                  left: (xFor(_scrub!) + 10 + 132 > w)
                      ? xFor(_scrub!) - 142
                      : xFor(_scrub!) + 10,
                  top: 0,
                  width: 132,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ClinicalPalette.hairline(context),
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.xLabel(data[_scrub!].t),
                          style: TextStyle(fontSize: 10, color: label),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data[_scrub!].v == null
                              ? '—  gap'
                              : '${data[_scrub!].v!.toStringAsFixed(widget.yDecimals == 0 ? 1 : widget.yDecimals)} ${widget.unit}',
                          style: numTab(14, widget.stroke),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (e) => _setScrub(e.localPosition.dx, w),
                onHorizontalDragStart: (e) => _setScrub(e.localPosition.dx, w),
                onHorizontalDragUpdate: (e) => _setScrub(e.localPosition.dx, w),
                onHorizontalDragEnd: (_) => setState(() => _scrub = null),
                onTapUp: (_) => setState(() => _scrub = null),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.data,
    required this.stroke,
    required this.bands,
    required this.ticks,
    required this.yMin,
    required this.yMax,
    required this.yDecimals,
    required this.progress,
    required this.reference,
    required this.referenceLabel,
    required this.overlay,
    required this.overlayStroke,
    required this.xLabel,
    required this.grid,
    required this.label,
  });

  final List<SeriesSample> data;
  final Color stroke;
  final List<ChartBand> bands;
  final List<double> ticks;
  final double yMin, yMax, progress;
  final int yDecimals;
  final double? reference;
  final String? referenceLabel;
  final List<SeriesSample>? overlay;
  final Color? overlayStroke;
  final String Function(double) xLabel;
  final Color grid, label;

  void _text(
    Canvas c,
    String s,
    double x,
    double y, {
    double size = 10,
    bool right = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: label, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(right ? x - tp.width : x, y));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const padL = _SeriesChartState.padL,
        padR = _SeriesChartState.padR,
        padT = _SeriesChartState.padT,
        padB = _SeriesChartState.padB;
    final innerW = size.width - padL - padR;
    final innerH = size.height - padT - padB;
    final baseY = padT + innerH;
    double xFor(int i) => padL + i / (data.length - 1) * innerW;
    double yFor(double v) => padT + (1 - (v - yMin) / (yMax - yMin)) * innerH;

    // Reference bands behind everything.
    for (final b in bands) {
      final top = yFor(math.min(b.to, yMax));
      final bot = yFor(math.max(b.from, yMin));
      if (bot <= padT || top >= baseY) continue;
      canvas.drawRect(
        Rect.fromLTRB(padL, top, padL + innerW, bot),
        Paint()..color = b.color.withValues(alpha: 0.07),
      );
      if (b.label != null) {
        _text(canvas, b.label!, padL + innerW - 4, top + 3, size: 9);
      }
    }

    // Gridlines + y tick labels.
    for (final tk in ticks) {
      final y = yFor(tk);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + innerW, y),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
      _text(
        canvas,
        tk.toStringAsFixed(yDecimals),
        padL - 6,
        y - 5,
        right: true,
      );
    }

    // X axis: first, middle, last.
    final t0 = data.first.t, t1 = data.last.t;
    _text(canvas, xLabel(t0), padL, size.height - 13);
    _text(canvas, xLabel((t0 + t1) / 2), padL + innerW / 2, size.height - 13);
    _text(canvas, xLabel(t1), padL + innerW, size.height - 13, right: true);

    // Trace, clipped to the draw-in progress. Null samples split the path —
    // a gap is drawn, not bridged.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(padL, 0, padL + innerW * progress, size.height),
    );
    var run = <Offset>[];
    void flush() {
      if (run.length > 1) {
        final line = Path()..moveTo(run.first.dx, run.first.dy);
        for (final p in run.skip(1)) {
          line.lineTo(p.dx, p.dy);
        }
        final area = Path.from(line)
          ..lineTo(run.last.dx, baseY)
          ..lineTo(run.first.dx, baseY)
          ..close();
        canvas.drawPath(area, Paint()..color = stroke.withValues(alpha: 0.10));
        canvas.drawPath(
          line,
          Paint()
            ..color = stroke
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      run = [];
    }

    for (var i = 0; i < data.length; i++) {
      final v = data[i].v;
      if (v == null) {
        flush();
      } else {
        run.add(Offset(xFor(i), yFor(v)));
      }
    }
    flush();

    // Overlay series: same x axis as the main trace, line only.
    final ov = overlay, oc = overlayStroke;
    if (ov != null && ov.isNotEmpty && oc != null) {
      final n = ov.length;
      double oxFor(int i) => n > 1 ? padL + i / (n - 1) * innerW : padL;
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = ov[i].v;
        if (v == null) {
          started = false;
          continue;
        }
        final p = Offset(oxFor(i), yFor(v));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = oc
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();

    // Dashed baseline reference ("your usual").
    if (reference != null) {
      final y = yFor(reference!);
      final paint = Paint()
        ..color = stroke.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      var x = padL;
      while (x < padL + innerW) {
        canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
        x += 11;
      }
      if (referenceLabel != null) {
        _text(
          canvas,
          referenceLabel!,
          padL + innerW,
          y - 12,
          size: 9,
          right: true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter o) =>
      o.progress != progress || o.data != data;
}
