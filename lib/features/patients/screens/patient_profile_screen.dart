import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

/// One patient: their details, their vulnerability flags, their vitals trends
/// and their full screening timeline.
class PatientProfileScreen extends ConsumerWidget {
  final String patientId;

  const PatientProfileScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientProvider(patientId));
    final screeningsAsync = ref.watch(patientScreeningsProvider(patientId));

    return AppPageScaffold(
      appBar: AppBar(
        title: Text(
          patientAsync.valueOrNull?.name ?? 'Patient',
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.go('/patients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Trends',
            onPressed: () =>
                context.push('/trends?patientId=$patientId'),
          ),
        ],
      ),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load patient',
          subtitle: 'The local database did not respond.',
        ),
        data: (patient) {
          if (patient == null) {
            return AppEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Patient not found',
              subtitle: 'This record may have been deleted from this device.',
              action: AppOutlinedButton(
                label: 'Back to patients',
                isExpanded: false,
                onPressed: () => context.go('/patients'),
              ),
            );
          }

          final screenings = screeningsAsync.valueOrNull ?? const <Screening>[];

          return ListView(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            children: [
              _PatientHeader(patient: patient, screenings: screenings)
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: -0.06),
              const AppSpacing.vlg(),
              _DetailsCard(patient: patient)
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 80.ms),
              if (screenings.length >= 2) ...[
                const AppSpacing.vlg(),
                _TrendsCard(screenings: screenings)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 160.ms),
              ],
              const AppSpacing.vlg(),
              _TimelineSection(screenings: screenings, isLoading: screeningsAsync.isLoading)
                  .animate()
                  .fadeIn(duration: 300.ms, delay: 240.ms),
              const AppSpacing.vlg(),
              _Actions(patient: patient),
              const AppSpacing.vxxl(),
            ],
          );
        },
      ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  final Patient patient;
  final List<Screening> screenings;

  const _PatientHeader({required this.patient, required this.screenings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = screenings.isEmpty ? null : screenings.first;
    final risk = latest == null ? null : RiskStyle.ofStorage(latest.riskLevel, context.l10n);
    final flags = Vulnerability.parse(patient.vulnerabilityFlags);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor:
                    risk?.containerColor ?? theme.colorScheme.primaryContainer,
                child: Text(
                  initialsFor(patient.name),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        risk?.color ?? theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      '${patient.age} years · ${patient.sex}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (patient.isDemo) ...[
                      const AppSpacing.vxs(),
                      AppBadge(
                        label: 'Sample record',
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (flags.isNotEmpty) ...[
            const AppSpacing.vmd(),
            Text(
              'Risk thresholds adjusted for',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const AppSpacing.vxs(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                for (final flag in flags)
                  Tooltip(
                    message: flag.explanation,
                    child: AppBadge(
                      label: flag.label,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
          ],
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (risk != null)
                AppBadge(
                  label: 'Latest: ${risk.label}',
                  icon: risk.icon,
                  backgroundColor: risk.containerColor,
                  textColor: risk.color,
                ),
              AppBadge(
                label: patient.lastScreenedAt == null
                    ? 'Never screened'
                    : 'Screened ${relativeTime(patient.lastScreenedAt!)}',
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                textColor: theme.colorScheme.onSurfaceVariant,
              ),
              AppBadge(
                label: '${screenings.length} record'
                    '${screenings.length == 1 ? '' : 's'}',
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                textColor: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Patient patient;

  const _DetailsCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vmd(),
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Record ID',
            value: patient.id,
          ),
          if (patient.location != null && patient.location!.trim().isNotEmpty)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: patient.location!,
            ),
          if (patient.phone != null && patient.phone!.trim().isNotEmpty)
            _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: patient.phone!,
            ),
          if (patient.notes != null && patient.notes!.trim().isNotEmpty)
            _DetailRow(
              icon: Icons.note_alt_outlined,
              label: 'Notes',
              value: patient.notes!,
            ),
          _DetailRow(
            icon: Icons.event_outlined,
            label: 'Added',
            value: absoluteDate(patient.createdAt),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const AppSpacing.hmd(),
          // A label/value Row with two unbounded Texts is the classic overflow.
          // Give the label a share and let the value take the rest, both
          // wrapping rather than clipping.
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const AppSpacing.hsm(),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// HR / SpO₂ / temperature over time, plus the triage band history.
class _TrendsCard extends StatefulWidget {
  final List<Screening> screenings;

  const _TrendsCard({required this.screenings});

  @override
  State<_TrendsCard> createState() => _TrendsCardState();
}

enum _Metric { heartRate, spo2, temperature }

class _TrendsCardState extends State<_TrendsCard> {
  _Metric _metric = _Metric.heartRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `patientScreeningsProvider` yields newest-first; a chart reads left-to-
    // right in time, so reverse it.
    final ordered = widget.screenings.reversed.toList(growable: false);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trends',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const AppSpacing.vxs(),
          Text(
            'Last ${ordered.length} screenings, oldest first',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              for (final metric in _Metric.values)
                ChoiceChip(
                  label: Text(_label(metric)),
                  selected: _metric == metric,
                  onSelected: (_) => setState(() => _metric = metric),
                ),
            ],
          ),
          const AppSpacing.vmd(),
          SizedBox(
            height: 180,
            child: LineChart(_chartData(context, ordered)),
          ),
          const AppSpacing.vlg(),
          Text(
            'Triage band history',
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const AppSpacing.vsm(),
          // Fixed-height scroller: a Wrap of 50 dots would grow the card without
          // bound on a long-followed patient.
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ordered.length,
              separatorBuilder: (_, __) => const AppSpacing.hxs(),
              itemBuilder: (context, index) {
                final risk = RiskStyle.ofStorage(ordered[index].riskLevel, context.l10n);
                return Tooltip(
                  message: '${risk.label} · '
                      '${absoluteDate(ordered[index].timestamp)}',
                  child: Container(
                    width: 20,
                    decoration: BoxDecoration(
                      color: risk.color,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _label(_Metric metric) => switch (metric) {
        _Metric.heartRate => 'Heart rate',
        _Metric.spo2 => 'SpO₂',
        _Metric.temperature => 'Temperature',
      };

  double _valueOf(Screening s) => switch (_metric) {
        _Metric.heartRate => s.heartRate.toDouble(),
        _Metric.spo2 => s.spo2.toDouble(),
        _Metric.temperature => s.temperature,
      };

  String _unit() => switch (_metric) {
        _Metric.heartRate => 'bpm',
        _Metric.spo2 => '%',
        _Metric.temperature => '°C',
      };

  LineChartData _chartData(BuildContext context, List<Screening> ordered) {
    final theme = Theme.of(context);
    final values = ordered.map(_valueOf).toList(growable: false);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    // Pad the range so a flat series is a flat line in the middle of the chart
    // rather than a line pinned to an edge.
    final pad = (hi - lo).abs() < 0.001 ? _defaultPad() : (hi - lo) * 0.2;

    return LineChartData(
      minY: lo - pad,
      maxY: hi + pad,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                _metric == _Metric.temperature
                    ? value.toStringAsFixed(1)
                    : value.round().toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((spot) {
            final s = ordered[spot.x.toInt()];
            return LineTooltipItem(
              '${_valueOf(s).toStringAsFixed(_metric == _Metric.temperature ? 1 : 0)}'
              ' ${_unit()}\n${absoluteDate(s.timestamp)}',
              theme.textTheme.labelSmall ?? const TextStyle(),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < ordered.length; i++)
              FlSpot(i.toDouble(), _valueOf(ordered[i])),
          ],
          isCurved: true,
          curveSmoothness: 0.2,
          barWidth: 3,
          color: theme.colorScheme.primary,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 3.5,
              color: RiskStyle.ofStorage(
                ordered[spot.x.toInt()].riskLevel,
              ).color,
              strokeWidth: 0,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  double _defaultPad() => switch (_metric) {
        _Metric.heartRate => 10,
        _Metric.spo2 => 3,
        _Metric.temperature => 0.5,
      };
}

class _TimelineSection extends StatelessWidget {
  final List<Screening> screenings;
  final bool isLoading;

  const _TimelineSection({required this.screenings, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Screening timeline',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const AppSpacing.vmd(),
        if (screenings.isEmpty && !isLoading)
          AppCard(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Text(
              'No screenings recorded for this patient yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final screening in screenings)
            _TimelineTile(screening: screening),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final Screening screening;

  const _TimelineTile({required this.screening});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final risk = RiskStyle.ofStorage(screening.riskLevel, context.l10n);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      onTap: () => context.go('/history/${screening.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(risk.icon, color: risk.color, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${risk.label} · score ${screening.riskScore}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: risk.color,
                      ),
                      maxLines: 2,
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      absoluteDateTime(screening.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const AppSpacing.hxs(),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            '${screening.heartRate} bpm · ${screening.spo2}% · '
            '${screening.temperature.toStringAsFixed(1)} °C',
            style: theme.textTheme.bodyMedium,
          ),
          if (screening.triggeredRules.isNotEmpty) ...[
            const AppSpacing.vxs(),
            Text(
              screening.triggeredRules.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final Patient patient;

  const _Actions({required this.patient});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'New screening',
          icon: const Icon(Icons.monitor_heart_outlined),
          onPressed: () => context.go('/screening/new'),
        ),
        const AppSpacing.vmd(),
        AppOutlinedButton(
          label: 'Back to patients',
          icon: const Icon(Icons.people_outline_rounded),
          onPressed: () => context.go('/patients'),
        ),
      ],
    );
  }
}
