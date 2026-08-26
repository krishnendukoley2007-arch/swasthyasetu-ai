import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/core/widgets/risk_sparkline.dart';
import 'package:swasthyasetu_ai/data/repositories/patient_repository.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

/// The patient roster.
///
/// Reads [PatientSummary] rows, which already carry the screening count and the
/// risk trend, so a row never issues its own query — scrolling a few hundred
/// patients stays at one stream subscription.
class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(filteredPatientsProvider);
    final query = ref.watch(patientQueryProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: query.hasFilters,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter and sort',
            onPressed: () => _openFilterSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/patients/add'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add patient'),
      ),
      body: Column(
        children: [
          _SearchField(
            value: query.search,
            onChanged: (v) =>
                ref.read(patientQueryProvider.notifier).setSearch(v),
          ),
          if (query.hasFilters) _ActiveFilterBar(query: query, ref: ref),
          Expanded(
            child: patientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _LoadFailure(
                onRetry: () => ref.invalidate(patientSummariesProvider),
              ),
              data: (summaries) {
                if (summaries.isEmpty) {
                  return _EmptyState(hasFilters: query.hasFilters, ref: ref);
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: AppTheme.spacingMd,
                    right: AppTheme.spacingMd,
                    top: AppTheme.spacingSm,
                    // Clear the FAB so the last row is always reachable.
                    bottom: AppTheme.spacingXxl * 2,
                  ),
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    return _PatientCard(summary: summary)
                        .animate()
                        .fadeIn(
                          duration: 220.ms,
                          // Cap the stagger: with 200 patients an
                          // index-proportional delay would leave the last row
                          // invisible for half a minute.
                          delay: (20 * (index % 8)).ms,
                        )
                        .slideY(begin: 0.04, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _SearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.value, required this.onChanged});

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingXs,
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search name, ID or village',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
          isDense: true,
        ),
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {}); // toggles the clear button
        },
      ),
    );
  }
}

class _ActiveFilterBar extends StatelessWidget {
  final PatientQuery query;
  final WidgetRef ref;

  const _ActiveFilterBar({required this.query, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = <String>[
      ...query.riskLevels.map((r) => RiskStyle.ofStorage(r, context.l10n).label),
      ...query.vulnerabilityFlags
          .map((f) => Vulnerability.fromId(f)?.shortLabel)
          .whereType<String>(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Row(
        children: [
          Expanded(
            child: Text(
              labels.isEmpty ? 'Search filter active' : labels.join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const AppSpacing.hsm(),
          AppTextButton(
            label: 'Clear',
            onPressed: () => ref.read(patientQueryProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final PatientSummary summary;

  const _PatientCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patient = summary.patient;
    final flags = Vulnerability.parse(patient.vulnerabilityFlags);
    final risk = summary.latestRiskLevel == null
        ? null
        : RiskStyle.ofStorage(summary.latestRiskLevel!, context.l10n);

    // At large text scales a fixed-height row cannot hold the content, so the
    // sparkline column drops out entirely rather than squeezing the name.
    final showTrend = MediaQuery.textScalerOf(context).scale(14) < 22;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      onTap: () => context.go('/patients/${patient.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor:
                risk?.containerColor ?? theme.colorScheme.primaryContainer,
            child: Text(
              initialsFor(patient.name),
              style: theme.textTheme.titleMedium?.copyWith(
                color: risk?.color ?? theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const AppSpacing.vxs(),
                Text(
                  // Age and sex are humanised, never raw enum values.
                  '${patient.age} yrs · ${patient.sex}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (flags.isNotEmpty) ...[
                  const AppSpacing.vxs(),
                  // Wrap, not Row: three flags at 2.0 text scale overflowed the
                  // old fixed Row.
                  Wrap(
                    spacing: AppTheme.spacingXs,
                    runSpacing: AppTheme.spacingXs,
                    children: [
                      for (final flag in flags)
                        AppBadge(
                          label: flag.shortLabel,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          textColor: theme.colorScheme.onSecondaryContainer,
                        ),
                    ],
                  ),
                ],
                const AppSpacing.vxs(),
                _SubtitleLine(summary: summary),
              ],
            ),
          ),
          if (showTrend) ...[
            const AppSpacing.hsm(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RiskSparkline(scores: summary.riskTrend),
                if (risk != null) ...[
                  const AppSpacing.vxs(),
                  Icon(risk.icon, size: 16, color: risk.color),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SubtitleLine extends StatelessWidget {
  final PatientSummary summary;

  const _SubtitleLine({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastScreened = summary.patient.lastScreenedAt;
    final parts = <String>[
      if (lastScreened == null)
        'Never screened'
      else
        'Screened ${relativeTime(lastScreened)}',
      if (summary.screeningCount > 0)
        '${summary.screeningCount} record${summary.screeningCount == 1 ? '' : 's'}',
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (summary.pendingSyncCount > 0) ...[
          const AppSpacing.hxs(),
          const Icon(
            Icons.cloud_queue_outlined,
            size: 14,
            color: AppTheme.riskYellow,
          ),
        ],
      ],
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = ref.watch(patientQueryProvider);
    final controller = ref.read(patientQueryProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingLg,
          0,
          AppTheme.spacingLg,
          AppTheme.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort by', style: theme.textTheme.titleSmall),
            const AppSpacing.vsm(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                for (final sort in PatientSort.values)
                  ChoiceChip(
                    label: Text(_sortLabel(sort)),
                    selected: query.sort == sort,
                    onSelected: (_) => controller.setSort(sort),
                  ),
              ],
            ),
            const AppSpacing.vlg(),
            Text('Latest risk', style: theme.textTheme.titleSmall),
            const AppSpacing.vsm(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                for (final level in const ['RED', 'YELLOW', 'GREEN'])
                  FilterChip(
                    label: Text(RiskStyle.ofStorage(level, context.l10n).label),
                    avatar: Icon(
                      RiskStyle.ofStorage(level).icon,
                      size: 18,
                      color: RiskStyle.ofStorage(level).color,
                    ),
                    selected: query.riskLevels.contains(level),
                    onSelected: (_) => controller.toggleRisk(level),
                  ),
              ],
            ),
            const AppSpacing.vlg(),
            Text('Vulnerability', style: theme.textTheme.titleSmall),
            const AppSpacing.vsm(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                for (final flag in Vulnerability.values)
                  FilterChip(
                    label: Text(flag.shortLabel),
                    selected: query.vulnerabilityFlags.contains(flag.id),
                    onSelected: (_) => controller.toggleFlag(flag.id),
                  ),
              ],
            ),
            const AppSpacing.vlg(),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: 'Clear all',
                    onPressed: controller.clear,
                  ),
                ),
                const AppSpacing.hmd(),
                Expanded(
                  child: AppButton(
                    label: 'Done',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _sortLabel(PatientSort sort) => switch (sort) {
        PatientSort.recentlyScreened => 'Recently screened',
        PatientSort.nameAsc => 'Name (A–Z)',
        PatientSort.riskDesc => 'Highest risk',
        PatientSort.neverScreened => 'Never screened',
      };
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final WidgetRef ref;

  const _EmptyState({required this.hasFilters, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (hasFilters) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'No patient matches the current search and filters.',
        action: AppOutlinedButton(
          label: 'Clear filters',
          onPressed: () => ref.read(patientQueryProvider.notifier).clear(),
          isExpanded: false,
        ),
      );
    }

    return AppEmptyState(
      icon: Icons.groups_outlined,
      title: 'No patients yet',
      subtitle:
          'Add the first patient to start screening. Everything is stored on '
          'this device and works without a network.',
      action: AppButton(
        label: 'Add patient',
        icon: const Icon(Icons.person_add_alt_1_rounded),
        onPressed: () => context.go('/patients/add'),
        isExpanded: false,
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadFailure({required this.onRetry});

  @override
  Widget build(BuildContext context) => AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load patients',
        subtitle: 'The local database did not respond. No data has been lost.',
        action: AppOutlinedButton(
          label: 'Try again',
          onPressed: onRetry,
          isExpanded: false,
        ),
      );
}
