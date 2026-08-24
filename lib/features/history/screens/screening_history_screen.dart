import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';

/// Every screening recorded on this device, newest first.
class ScreeningHistoryScreen extends ConsumerStatefulWidget {
  const ScreeningHistoryScreen({super.key});

  @override
  ConsumerState<ScreeningHistoryScreen> createState() =>
      _ScreeningHistoryScreenState();
}

class _ScreeningHistoryScreenState
    extends ConsumerState<ScreeningHistoryScreen> {
  /// Empty means "all bands".
  final Set<String> _bands = {};
  String? _patientId;

  @override
  Widget build(BuildContext context) {
    final screeningsAsync = ref.watch(recentScreeningsProvider);
    final names = ref.watch(patientNamesProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Screening history'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.go('/home'),
        ),
      ),
      body: screeningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load history',
          subtitle: 'The local database did not respond.',
        ),
        data: (all) {
          final filtered = all.where((s) {
            final bandOk = _bands.isEmpty || _bands.contains(s.riskLevel);
            final patientOk = _patientId == null || s.patientId == _patientId;
            return bandOk && patientOk;
          }).toList(growable: false);

          return Column(
            children: [
              _FilterBar(
                bands: _bands,
                patientId: _patientId,
                names: names,
                onToggleBand: (band) => setState(() {
                  _bands.contains(band)
                      ? _bands.remove(band)
                      : _bands.add(band);
                }),
                onPatient: (id) => setState(() => _patientId = id),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.08),
              Expanded(
                child: all.isEmpty
                    ? AppEmptyState(
                        icon: Icons.history_outlined,
                        title: 'No screenings yet',
                        subtitle:
                            'Completed screenings appear here and stay on this '
                            'device.',
                        action: AppButton(
                          label: 'Start a screening',
                          icon: const Icon(Icons.play_arrow_rounded),
                          isExpanded: false,
                          onPressed: () => context.go('/screening/new'),
                        ),
                      )
                    : filtered.isEmpty
                        ? AppEmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'No matches',
                            subtitle: 'No screening matches these filters.',
                            action: AppOutlinedButton(
                              label: 'Clear filters',
                              isExpanded: false,
                              onPressed: () => setState(() {
                                _bands.clear();
                                _patientId = null;
                              }),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppTheme.spacingMd),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _ScreeningCard(
                              screening: filtered[index],
                              patientName: names[filtered[index].patientId],
                            )
                                .animate()
                                .fadeIn(
                                  duration: 280.ms,
                                  delay: (40 * (index % 8)).ms,
                                )
                                .slideX(begin: 0.05),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final Set<String> bands;
  final String? patientId;
  final Map<String, String> names;
  final ValueChanged<String> onToggleBand;
  final ValueChanged<String?> onPatient;

  const _FilterBar({
    required this.bands,
    required this.patientId,
    required this.names,
    required this.onToggleBand,
    required this.onPatient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap rather than a fixed Row: three band chips plus the patient
          // dropdown overflowed at large text scales.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              for (final band in const ['RED', 'YELLOW', 'GREEN'])
                FilterChip(
                  label: Text(RiskStyle.ofStorage(band, context.l10n).label),
                  avatar: Icon(
                    RiskStyle.ofStorage(band).icon,
                    size: 18,
                    color: RiskStyle.ofStorage(band).color,
                  ),
                  selected: bands.contains(band),
                  onSelected: (_) => onToggleBand(band),
                ),
            ],
          ),
          if (names.isNotEmpty) ...[
            const AppSpacing.vsm(),
            DropdownButtonFormField<String?>(
              initialValue: patientId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Patient',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('All patients'),
                ),
                for (final entry in names.entries)
                  DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onPatient,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScreeningCard extends StatelessWidget {
  final Screening screening;
  final String? patientName;

  const _ScreeningCard({required this.screening, this.patientName});

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: risk.containerColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(risk.icon, color: risk.color, size: 22),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName ?? 'Unknown patient',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      // Humanised band + score, never the stored 'RED'.
                      '${risk.label} · score ${screening.riskScore}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: risk.color,
                        fontWeight: FontWeight.w600,
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
              if (screening.isDemo) ...[
                const AppSpacing.hxs(),
                AppBadge(
                  label: 'Demo',
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  textColor: theme.colorScheme.onTertiaryContainer,
                ),
              ],
            ],
          ),
          const AppSpacing.vmd(),
          // The old fixed Row of three-to-four vital chips was one of the
          // guaranteed overflows. Wrap lets them reflow instead.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              _VitalChip(
                label: 'HR',
                value: '${screening.heartRate} bpm',
                icon: Icons.favorite_rounded,
                color: theme.colorScheme.primary,
              ),
              _VitalChip(
                label: 'SpO₂',
                value: '${screening.spo2}%',
                icon: Icons.air_rounded,
                color: theme.colorScheme.secondary,
              ),
              _VitalChip(
                label: 'Temp',
                value: '${screening.temperature.toStringAsFixed(1)} °C',
                icon: Icons.thermostat_rounded,
                color: theme.colorScheme.tertiary,
              ),
              if (screening.hasBpEstimate)
                _VitalChip(
                  label: 'BP',
                  value: '${screening.estimatedSystolic}/'
                      '${screening.estimatedDiastolic}',
                  icon: Icons.monitor_heart_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          if (screening.symptoms.isNotEmpty) ...[
            const AppSpacing.vsm(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                for (final symptom in screening.symptoms)
                  AppBadge(
                    label: symptom,
                    backgroundColor: theme
                        .colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    textColor: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ],
          const AppSpacing.vsm(),
          Row(
            children: [
              Expanded(
                child: Text(
                  screening.recommendedAction,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: risk.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const AppSpacing.hxs(),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _VitalChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const AppSpacing.hxs(),
          // No hardcoded fontSize — it must scale with the accessibility
          // setting. Flexible so it can also wrap: the parent Wrap bounds the
          // chip's width, but a non-flex child of a Row is measured against
          // infinity and would push straight through that bound.
          Flexible(
            child: Text(
              '$label $value',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
