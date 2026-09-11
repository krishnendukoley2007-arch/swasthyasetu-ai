import 'package:flutter/material.dart';

import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/clinical_primitives.dart';

/// A recorded ECG strip, drawn from the samples actually captured during the
/// screening — never synthesised. If nothing was recorded, the caller should
/// not render this card at all.
class RecordedEcgCard extends StatelessWidget {
  const RecordedEcgCard({
    super.key,
    required this.samples,
    required this.sampleRate,
    required this.generated,
  });

  final List<int> samples;
  final int sampleRate;

  /// True when the samples came from the app's generator, not a board.
  final bool generated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = samples.length / sampleRate;
    final traceColor = generated ? ClinicalPalette.amber : ClinicalPalette.teal;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClinicalPalette.hairline(context)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Overline('ECG · RECORDED STRIP')),
              ProvenanceTag(generated ? Provenance.demo : Provenance.measured),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${seconds.toStringAsFixed(1)} s · $sampleRate Hz',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ClinicalPalette.muted(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _RecordedStripPainter(
                samples: samples,
                color: traceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordedStripPainter extends CustomPainter {
  _RecordedStripPainter({required this.samples, required this.color});

  final List<int> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    var lo = samples.first, hi = samples.first;
    for (final v in samples) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = hi == lo ? 1.0 : (hi - lo).toDouble();
    const inset = 0.08;
    final usable = size.height * (1 - 2 * inset);
    final bottom = size.height * (1 - inset);
    final step = size.width / (samples.length - 1);

    // Faint 200 ms-ish columns for orientation only.
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += size.width / 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final y = bottom - ((samples[i] - lo) / span) * usable;
      if (i == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(i * step, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RecordedStripPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.color != color;
}
