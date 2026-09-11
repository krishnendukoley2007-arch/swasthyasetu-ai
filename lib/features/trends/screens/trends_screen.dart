import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';

/// "My Trends" — a personal vitals history turned into something a person can
/// act on.
///
/// Three charts (heart rate, SpO₂, temperature) over the last 30 days, each
/// against the user's own average with the latest reading called out. The
/// honest states matter as much as the chart: fewer than two readings shows
/// how to earn the chart, not a fake flat line.
class TrendsScreen extends ConsumerWidget {
  final String patientId;

  const TrendsScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screeningsAsync = ref.watch(patientScreeningsProvider(patientId));

    return AppPageScaffold(
      appBar: AppBar(title: const Text('My trends')),
      body: screeningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load history.')),
        data: (screenings) {
          final notes = TrendEngine.notes(screenings);
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            children: [
              if (notes.isNotEmpty) ...[
                _NotesCard(notes: notes),
                const AppSpacing.vlg(),
              ],
              _TrendCard(
                title: 'Heart rate',
                unit: 'bpm',
                fractionDigits: 0,
                color: ClinicalPalette.coral,
                trend: TrendEngine.heartRate(screenings),
              ),
              const AppSpacing.vlg(),
              _TrendCard(
                title: 'Blood oxygen (SpO₂)',
                unit: '%',
                fractionDigits: 0,
                color: ClinicalPalette.cyan,
                trend: TrendEngine.spo2(screenings),
              ),
              const AppSpacing.vlg(),
              _TrendCard(
                title: 'Temperature',
                unit: '°C',
                fractionDigits: 1,
                color: ClinicalPalette.amber,
                trend: TrendEngine.temperature(screenings),
              ),
              const AppSpacing.vlg(),
              AppFilledCard(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Text(
                  'Trends compare you to your own usual, not to a textbook. '
                  'A steady change over days matters more than one odd '
                  'reading — share this screen with a doctor if something '
                  'keeps drifting.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              const AppSpacing.vlg(),
            ],
          );
        },
      ),
    );
  }
}

/// The significant deviations, in plain words, at the top of the screen.
class _NotesCard extends StatelessWidget {
  final List<BaselineNote> notes;

  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String sentence(BaselineNote n) {
      final direction = n.delta > 0 ? 'above' : 'below';
      return switch (n.metricId) {
        'hr' =>
          'Your latest pulse is ${n.delta.abs().round()} bpm $direction your usual.',
        'spo2' =>
          'Your latest SpO₂ is ${n.delta.abs().toStringAsFixed(0)} points $direction your usual.',
        _ =>
          'Your latest temperature is ${n.delta.abs().toStringAsFixed(1)}°C $direction your usual.',
      };
    }

    return AppCard(
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: theme.colorScheme.tertiary,
                size: 22,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Worth noticing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingXs),
              child: Text(
                sentence(n),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          const AppSpacing.vxs(),
          Text(
            'If this persists for another check or you feel unwell, consult '
            'a nurse or doctor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final String unit;
  final Color color;
  final VitalTrend trend;
  final int fractionDigits;

  const _TrendCard({
    required this.title,
    required this.unit,
    required this.color,
    required this.trend,
    this.fractionDigits = 0,
  });

  List<SeriesSample> get _samples => [
    for (var i = 0; i < trend.points.length; i++)
      SeriesSample(
        trend.points[i].at.millisecondsSinceEpoch.toDouble(),
        trend.points[i].value,
      ),
  ];

  String _xLabel(double t) {
    final d = DateTime.fromMillisecondsSinceEpoch(t.round());
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = trend.delta;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: overlined metric, provenance, then the readout itself.
          Row(
            children: [
              Expanded(child: Overline(title.toUpperCase())),
              const ProvenanceTag(Provenance.measured),
            ],
          ),
          const AppSpacing.vsm(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (trend.latest != null)
                UnitNumber(
                  trend.latest!.toStringAsFixed(fractionDigits),
                  unit,
                  size: 26,
                  color: color,
                )
              else
                Text(
                  '—',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (delta != null && trend.points.length >= 2)
                DeltaChip(
                  delta: delta,
                  unit: unit,
                  decimals: fractionDigits,
                  // SpO₂ down is bad; HR/temp both directions can be.
                  positiveIsGood: unit == '%',
                  neutralEpsilon: fractionDigits == 0 ? 0.5 : 0.05,
                ),
            ],
          ),
          const AppSpacing.vmd(),
          if (trend.points.length < 2)
            SizedBox(
              height: 96,
              child: Center(
                child: Text(
                  'Take a few health checks and your trend will appear here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            SeriesChart(
              data: _samples,
              stroke: color,
              unit: unit,
              xLabel: _xLabel,
              yDecimals: fractionDigits,
              height: 170,
              reference: trend.average,
              referenceLabel: trend.hasBaseline
                  ? 'usual ${trend.average.toStringAsFixed(fractionDigits)} $unit'
                  : null,
            ),
            const AppSpacing.vxs(),
            // Sparse-dot cadence note: screening happens occasionally, not
            // continuously, so say what the axis actually is.
            Text(
              '${trend.points.length} readings · last 30 days',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
