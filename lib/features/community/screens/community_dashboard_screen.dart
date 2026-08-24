import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/offline_tile_map.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/screening_repository.dart';

/// This worker's own screening activity, in aggregate.
///
/// Deliberately anonymous: every figure here is a count or a distribution, and
/// no patient name, ID or individual reading appears anywhere on the screen. It
/// is computed entirely from the local database, so it is fully populated with
/// the radio off — the sync indicator at the top reports what has and has not
/// left the device, which is different information from what the numbers say.
class CommunityDashboardScreen extends ConsumerWidget {
  const CommunityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aggregate = ref.watch(communityAggregateProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Community Overview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate',
            onPressed: () => ref.invalidate(communityAggregateProvider),
          ),
        ],
      ),
      body: aggregate.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorState(
          message: 'Could not compute the overview.',
          onRetry: () => ref.invalidate(communityAggregateProvider),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
          children: [
            const _AnonymityNote(),
            _SyncIndicatorCard(data: data),
            if (data.totalScreenings == 0)
              const Padding(
                padding: EdgeInsets.only(top: AppTheme.spacingXl),
                child: AppEmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Nothing to summarise yet',
                  subtitle:
                      'Complete a screening and this view fills in — offline, '
                      'from data already on this phone.',
                ),
              )
            else ...[
              _HeadlineCard(data: data),
              _RiskDistributionCard(data: data),
              _DailyTrendCard(data: data),
              _FrequencyCard(
                title: 'Most reported symptoms',
                icon: Icons.sick_outlined,
                counts: data.symptomFrequency,
                total: data.totalScreenings,
                emptyLabel: 'No symptoms have been recorded.',
              ),
              _FrequencyCard(
                title: 'Most triggered rules',
                icon: Icons.rule_folder_outlined,
                counts: data.topTriggeredRules,
                total: data.totalScreenings,
                emptyLabel: 'No triage rule has fired yet.',
              ),
              _GeoCard(data: data),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnonymityNote extends StatelessWidget {
  const _AnonymityNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: BorderSide.none,
      elevation: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              'Counts only — no names, no individual readings. Computed on this '
              'phone, so it works with no network.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncIndicatorCard extends ConsumerWidget {
  final CommunityAggregate data;

  const _SyncIndicatorCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lastSync = ref.watch(settingsProvider).lastSyncAt;
    final allLocal = data.syncedCount == 0 && data.totalScreenings > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allLocal ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Sync status',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              AppTextButton(
                label: 'Queue',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          // A Wrap of three counters: on a 360 px screen at 2.0x these cannot
          // share a single row, and each is meaningless truncated.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              AppPillLabel(
                label: '${data.syncedCount} synced',
                leadingIcon: Icons.cloud_done_outlined,
                color: theme.colorScheme.primary,
              ),
              AppPillLabel(
                label: '${data.pendingCount} queued',
                leadingIcon: Icons.schedule_rounded,
                color: theme.colorScheme.tertiary,
              ),
              if (data.failedCount > 0)
                AppPillLabel(
                  label: '${data.failedCount} failed',
                  leadingIcon: Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            lastSync == null
                ? 'Never synced. Everything below is held locally, which is a '
                    'working state — not an error.'
                : 'Last successful sync ${_relative(lastSync)}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _HeadlineCard extends StatelessWidget {
  final CommunityAggregate data;

  const _HeadlineCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highCount = data.riskDistribution['RED'] ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This device',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const AppSpacing.vsm(),
          // A Wrap of fixed-width stats rather than a Row of Expandeds: at 2.0x
          // three columns on a 360 px screen give each figure ~35 px, which
          // clips the number itself.
          Wrap(
            spacing: AppTheme.spacingLg,
            runSpacing: AppTheme.spacingMd,
            children: [
              _Stat(
                value: '${data.totalScreenings}',
                label: 'Screenings',
                icon: Icons.assignment_turned_in_outlined,
              ),
              _Stat(
                value: '${data.patientsScreened}',
                label: 'People seen',
                icon: Icons.people_outline_rounded,
              ),
              _Stat(
                value: '$highCount',
                label: 'High risk',
                icon: Icons.priority_high_rounded,
                color: theme.colorScheme.error,
              ),
            ],
          ),
          if (data.earliest != null && data.latest != null) ...[
            const AppSpacing.vsm(),
            Text(
              'Covering ${_d(data.earliest!)} to ${_d(data.latest!)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _d(DateTime t) => '${t.day}/${t.month}/${t.year}';
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? color;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const AppSpacing.hxs(),
            Text(
              value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: tint),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RiskDistributionCard extends StatelessWidget {
  final CommunityAggregate data;

  const _RiskDistributionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.totalScreenings;
    // Fixed order, so the bar reads the same every time regardless of which
    // band happens to be most common.
    const order = ['GREEN', 'YELLOW', 'RED'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_small_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Triage distribution',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          // One stacked bar: three slim slices communicate proportion faster
          // than a pie at this size, and it costs no vertical space.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final band in order)
                    if ((data.riskDistribution[band] ?? 0) > 0)
                      Expanded(
                        flex: data.riskDistribution[band]!,
                        child: ColoredBox(
                          color: RiskStyle.ofStorage(band).color,
                        ),
                      ),
                ],
              ),
            ),
          ),
          const AppSpacing.vmd(),
          for (final band in order)
            _BandRow(
              style: RiskStyle.ofStorage(band, context.l10n),
              count: data.riskDistribution[band] ?? 0,
              total: total,
            ),
        ],
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  final RiskStyle style;
  final int count;
  final int total;

  const _BandRow({
    required this.style,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0 : (count * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXs),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
          ),
          const AppSpacing.hsm(),
          // Flexible, so the band name wraps at large scales instead of pushing
          // the count off the card.
          Expanded(
            child: Text(
              // The humanised label, never the stored 'RED'.
              style.label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '$count · $pct%',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  final CommunityAggregate data;

  const _DailyTrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = data.dailyCounts;
    if (days.length < 2) return const SizedBox.shrink();

    final maxY = days
        .map((d) => d.total)
        .fold<int>(1, (a, b) => a > b ? a : b)
        .toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Screenings per day',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.2,
                // Axis labels and the grid are dropped: on a 360 px card they
                // are unreadable, and the shape is the information here.
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < days.length; i++)
                        FlSpot(i.toDouble(), days[i].total.toDouble()),
                    ],
                    isCurved: true,
                    barWidth: 3,
                    color: theme.colorScheme.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < days.length; i++)
                        FlSpot(i.toDouble(), days[i].high.toDouble()),
                    ],
                    isCurved: true,
                    barWidth: 2,
                    color: theme.colorScheme.error,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const AppSpacing.vsm(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            children: [
              AppPillLabel(
                label: 'All screenings',
                leadingIcon: Icons.circle,
                color: theme.colorScheme.primary,
              ),
              AppPillLabel(
                label: 'High risk',
                leadingIcon: Icons.circle,
                color: theme.colorScheme.error,
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            '${days.first.day.day}/${days.first.day.month} '
            '→ ${days.last.day.day}/${days.last.day.month}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> counts;
  final int total;
  final String emptyLabel;

  const _FrequencyCard({
    required this.title,
    required this.icon,
    required this.counts,
    required this.total,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = counts.entries.take(6).toList();
    final maxCount =
        top.isEmpty ? 1 : top.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (counts.length > top.length)
                Text(
                  'top ${top.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const AppSpacing.vsm(),
          if (top.isEmpty)
            Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final e in top)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingXs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.key, style: theme.textTheme.bodyMedium),
                        ),
                        const AppSpacing.hsm(),
                        Text(
                          '${e.value}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const AppSpacing.vxs(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      child: LinearProgressIndicator(
                        value: e.value / maxCount,
                        minHeight: 6,
                        backgroundColor: theme
                            .colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Where this worker has screened, if — and only if — location tagging was
/// consented to.
///
/// Renders real raster tiles out of an on-device MBTiles pack. When the pack has
/// nothing for this area — or there is no pack at all — it falls back to a
/// relative-position plot and *says so in the caption*, rather than drawing a
/// procedural coastline the worker might read as their district.
class _GeoCard extends ConsumerStatefulWidget {
  final CommunityAggregate data;

  const _GeoCard({required this.data});

  @override
  ConsumerState<_GeoCard> createState() => _GeoCardState();
}

class _GeoCardState extends ConsumerState<_GeoCard> {
  TileCoverage _coverage = TileCoverage.loading;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final theme = Theme.of(context);
    final consented = ref.watch(settingsProvider).locationConsent;

    if (!consented) {
      return AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const AppSpacing.hsm(),
            Expanded(
              child: Text(
                'Location tagging is off, so there is no map. Turn it on in '
                'Settings if you want to see where you have screened — it is '
                'off by default on purpose.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (data.geoPoints.isEmpty) {
      return AppCard(
        child: Text(
          'No screening carries a location yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.map_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Screening locations (${data.geoPoints.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          AspectRatio(
            aspectRatio: 1.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: OfflineTileMap(
                markers: [
                  for (final point in data.geoPoints)
                    MapMarker(
                      latitude: point.latitude,
                      longitude: point.longitude,
                      color: RiskStyle.ofStorage(point.riskLevel).color,
                    ),
                ],
                onCoverage: (coverage) {
                  if (mounted) setState(() => _coverage = coverage);
                },
              ),
            ),
          ),
          const AppSpacing.vsm(),
          Text(
            // The caption is generated from what was actually painted, so it
            // cannot claim terrain the pack did not supply.
            coverageCaption(_coverage, ref.watch(mapPacksProvider).valueOrNull),
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
