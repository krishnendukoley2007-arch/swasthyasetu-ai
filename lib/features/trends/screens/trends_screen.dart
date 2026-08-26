import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
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
                icon: Icons.favorite_rounded,
                color: theme.colorScheme.primary,
                trend: TrendEngine.heartRate(screenings),
              ),
              const AppSpacing.vlg(),
              _TrendCard(
                title: 'Blood oxygen (SpO₂)',
                unit: '%',
                icon: Icons.air_rounded,
                color: theme.colorScheme.secondary,
                trend: TrendEngine.spo2(screenings),
              ),
              const AppSpacing.vlg(),
              _TrendCard(
                title: 'Temperature',
                unit: '°C',
                icon: Icons.thermostat_rounded,
                color: theme.colorScheme.tertiary,
                trend: TrendEngine.temperature(screenings),
                fractionDigits: 1,
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
              Icon(Icons.insights_rounded,
                  color: theme.colorScheme.tertiary, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Worth noticing',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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
  final IconData icon;
  final Color color;
  final VitalTrend trend;
  final int fractionDigits;

  const _TrendCard({
    required this.title,
    required this.unit,
    required this.icon,
    required this.color,
    required this.trend,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trend.latest != null)
                AppBadge(
                  label:
                      '${trend.latest!.toStringAsFixed(fractionDigits)} $unit now',
                  color: color,
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
            SizedBox(
              height: 150,
              child: _buildChart(context),
            ),
            const AppSpacing.vsm(),
            // Wrap, not Row: three labels across 340 logical px only fit at
            // small text scales; at 2.0x the middle one must drop to its own
            // line instead of shoving 'today' off the edge.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                Text('30 days ago',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                if (trend.hasBaseline)
                  Text(
                    'Your usual: ${trend.average.toStringAsFixed(fractionDigits)} $unit',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                Text('today',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final theme = Theme.of(context);
    final points = trend.points;
    final values = points.map((p) => p.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    // Pad so a steady line is not cramped against the card edge.
    final pad = (maxY - minY == 0) ? maxY * 0.05 : (maxY - minY) * 0.25;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY - pad,
        maxY: maxY + pad,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
          // The "your usual" line — flat, dashed, quieter than the data.
          if (trend.hasBaseline)
            LineChartBarData(
              spots: [
                FlSpot(0, trend.average),
                FlSpot((points.length - 1).toDouble(), trend.average),
              ],
              isCurved: false,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              barWidth: 1.5,
              dashArray: const [6, 6],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
