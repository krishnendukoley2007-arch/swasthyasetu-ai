import 'package:flutter/material.dart';

import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';

/// Tabular-figure numeric style — digits share one width so a live readout
/// doesn't jitter horizontally as it changes. Every number on a monitoring
/// surface should use this.
TextStyle numTab(double size, Color color,
        {FontWeight weight = FontWeight.w700}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.3,
      height: 1.05,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// A pulsing placeholder block used instead of a spinner while content loads.
/// Mimics the shape of the incoming layout so the page doesn't jump when data
/// arrives.
class ClinicalSkeleton extends StatefulWidget {
  const ClinicalSkeleton({super.key, this.width, this.height = 16, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  State<ClinicalSkeleton> createState() => _ClinicalSkeletonState();
}

class _ClinicalSkeletonState extends State<ClinicalSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: 0.35 + 0.35 * _c.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: ClinicalPalette.hairline(context),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Small-caps section label ("HEART RATE"). Carries no data, so it must never
/// be the only place a unit appears.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: color ?? ClinicalPalette.muted(context),
        ),
      );
}

/// A value that is meaningless without its unit — so the unit is part of the
/// same widget, baseline-aligned, in reduced size.
class UnitNumber extends StatelessWidget {
  const UnitNumber(this.value, this.unit,
      {super.key, this.size = 26, this.color});
  final String value;
  final String unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: numTab(size, color ??
                  (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFE7EEF8)
                      : const Color(0xFF0F1B2D)))),
          const SizedBox(width: 3),
          Text(
            unit,
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w600,
              color: ClinicalPalette.muted(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}

/// Where a number came from. A reading and a simulation must never share a
/// face — the tag is small, permanent, and unambiguous.
enum Provenance { measured, demo }

class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag(this.p, {super.key});
  final Provenance p;

  @override
  Widget build(BuildContext context) {
    final (label, col) = switch (p) {
      Provenance.measured => ('MEASURED', ClinicalPalette.teal),
      Provenance.demo => ('DEMO', ClinicalPalette.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: col,
        ),
      ),
    );
  }
}

/// A small delta badge ("↑ 4 bpm vs usual"). Teal when the change is good for
/// the metric, coral when it is not, faint when within noise.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.delta,
    this.unit = '',
    this.positiveIsGood = true,
    this.decimals = 0,
    this.neutralEpsilon = 0.05,
  });

  final double delta;
  final String unit;
  final bool positiveIsGood;
  final int decimals;
  final double neutralEpsilon;

  @override
  Widget build(BuildContext context) {
    final neutral = delta.abs() < neutralEpsilon;
    final good = delta > 0 ? positiveIsGood : !positiveIsGood;
    final col = neutral
        ? ClinicalPalette.faint(context)
        : (good ? ClinicalPalette.teal : ClinicalPalette.coral);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: col.withValues(alpha: 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            neutral
                ? Icons.remove_rounded
                : delta > 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
            size: 11,
            color: col,
          ),
          const SizedBox(width: 2),
          Text(
            '${delta.abs().toStringAsFixed(decimals)}$unit',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: col,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
