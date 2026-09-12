import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:swasthyasetu_ai/features/emergency/widgets/disaster_playbook_modal.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/disaster_syndromic_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dynamic, accessible hazard banner mounted on the Patient Home screen and
/// Clinician Dashboard.
///
/// Automatically adapts when a natural disaster (flood, heatwave, smog, cyclone)
/// is detected via Open-Meteo, BME280 barometric telemetry, or manual relief camp override.
class DisasterHazardBanner extends ConsumerWidget {
  final int? heartRateBpm;
  final double? temperatureC;

  const DisasterHazardBanner({super.key, this.heartRateBpm, this.temperatureC});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessment = ref.watch(disasterHazardProvider);

    if (!assessment.isDisasterActive) {
      return _buildCalmSentinelBar(context, ref, assessment);
    }

    return _buildActiveHazardBanner(context, ref, assessment);
  }

  /// When conditions are normal: renders a reassuring, non-alarmist standby banner
  /// with a test/relief-camp override affordance for health workers.
  Widget _buildCalmSentinelBar(
    BuildContext context,
    WidgetRef ref,
    DisasterHazardAssessment assessment,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.riskGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.riskGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Disaster Physiological Shield Active',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Normal baseline · Monitoring storms, heatwaves & air hazards',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _showZoneOverrideModal(context, ref),
              child: Text(
                'Relief Mode',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// When an environmental hazard is active: renders high-contrast, hazard-specific UI.
  Widget _buildActiveHazardBanner(
    BuildContext context,
    WidgetRef ref,
    DisasterHazardAssessment assessment,
  ) {
    final theme = Theme.of(context);

    final (
      Color headerColor,
      Color accentColor,
      IconData hazardIcon,
      String typeLabel,
    ) = switch (assessment.activeHazard) {
      DisasterHazardType.flood => (
        const Color(0xFF0D47A1),
        Colors.lightBlueAccent,
        Icons.flood_rounded,
        'ACTIVE FLOOD HAZARD',
      ),
      DisasterHazardType.heatwave => (
        const Color(0xFFBF360C),
        Colors.amberAccent,
        Icons.wb_sunny_rounded,
        'EXTREME HEAT EMERGENCY',
      ),
      DisasterHazardType.severeAirPollution => (
        const Color(0xFF37474F),
        Colors.tealAccent,
        Icons.masks_rounded,
        'TOXIC AIR QUALITY EMERGENCY',
      ),
      DisasterHazardType.cycloneStorm => (
        const Color(0xFF004D40),
        Colors.cyanAccent,
        Icons.cyclone_rounded,
        'SEVERE CYCLONE STORM HAZARD',
      ),
      DisasterHazardType.none => (
        Colors.blueGrey,
        Colors.white,
        Icons.info_outline,
        'HAZARD ALERT',
      ),
    };

    final isDanger = assessment.severity == DisasterHazardSeverity.danger;

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Badge, IMD Level, Zone Override Indicator
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        Icon(hazardIcon, color: accentColor, size: 14),
                        Text(
                          typeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (assessment.imdAlertLevel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDanger
                            ? Colors.redAccent.shade700
                            : Colors.deepOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'IMD ${assessment.imdAlertLevel} ALERT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () => _showZoneOverrideModal(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Icon(
                            assessment.isManualOverride
                                ? Icons.edit_location_alt_rounded
                                : Icons.tune_rounded,
                            color: Colors.white70,
                            size: 12,
                          ),
                          Text(
                            assessment.isManualOverride
                                ? 'Override Active'
                                : 'Auto Mode',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const AppSpacing.vsm(),

              // Headline & Trigger
              Text(
                assessment.headline,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                assessment.triggerReason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
              const AppSpacing.vsm(),

              // Physiological Watchlist Chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: assessment.physiologicalWatchlist.take(3).map((w) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '• $w',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const AppSpacing.vmd(),

              // Action Buttons Row (Wrapping gracefully for textScaleFactor: 2.0)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (assessment.activeHazard == DisasterHazardType.flood)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: headerColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        DisasterSyndromicSheet.show(
                          context,
                          heartRateBpm: heartRateBpm,
                          temperatureC: temperatureC,
                        );
                      },
                      icon: const Icon(Icons.checklist_rounded, size: 16),
                      label: const Text(
                        '60s Syndromic Check',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),

                  if (assessment.activeHazard == DisasterHazardType.heatwave)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: headerColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => context.push('/screening/heat-guardian'),
                      icon: const Icon(Icons.speed_rounded, size: 16),
                      label: const Text(
                        'Moran PSI Heat Guardian',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),

                  if (assessment.activeHazard ==
                      DisasterHazardType.severeAirPollution)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: headerColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () =>
                          context.push('/screening/air-pollution-guardian'),
                      icon: const Icon(Icons.air_rounded, size: 16),
                      label: const Text(
                        'Air Pollution Guardian',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      DisasterPlaybookModal.show(
                        context,
                        initialHazard: assessment.activeHazard,
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Safe Water & First Aid'),
                  ),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => launchUrl(Uri.parse('tel:1078')),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call NDRF (1078)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal dialog allowing frontline ASHA workers or test users to manually
  /// override the disaster zone mode during drills or total telecom blackout.
  void _showZoneOverrideModal(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentOverride = ref.read(disasterHazardOverrideProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Disaster Zone Mode (Relief Camp / Drill)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Override environmental detection during internet blackouts or for field triage drills:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const AppSpacing.vsm(),
                _overrideTile(
                  ctx,
                  ref,
                  title: 'Auto-Detect (Sensor & Open-Meteo)',
                  subtitle:
                      'Default: Fuses live weather and SSAI-SENSE BME280 sensor',
                  value: DisasterHazardOverride.autoDetect,
                  current: currentOverride,
                ),
                _overrideTile(
                  ctx,
                  ref,
                  title: '🌊 Flood Relief Camp Zone',
                  subtitle:
                      'Forces post-flood waterborne triage, safe water & hypothermia watch',
                  value: DisasterHazardOverride.floodReliefZone,
                  current: currentOverride,
                ),
                _overrideTile(
                  ctx,
                  ref,
                  title: '☀️ Severe Heatwave Emergency Zone',
                  subtitle:
                      'Forces Moran PSI thermal load, hydration timer & drift watch',
                  value: DisasterHazardOverride.heatwaveEmergencyZone,
                  current: currentOverride,
                ),
                _overrideTile(
                  ctx,
                  ref,
                  title: '🌫️ Toxic Smog / Air Pollution Zone',
                  subtitle: 'Forces respiratory shield, SpO2 & N95 advisory',
                  value: DisasterHazardOverride.severeSmogZone,
                  current: currentOverride,
                ),
                _overrideTile(
                  ctx,
                  ref,
                  title: '🟢 Force Normal Conditions',
                  subtitle: 'Mutes all disaster warnings for normal day use',
                  value: DisasterHazardOverride.forceNormal,
                  current: currentOverride,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _overrideTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required DisasterHazardOverride value,
    required DisasterHazardOverride current,
  }) {
    final theme = Theme.of(context);
    final isSelected = value == current;

    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: () {
        ref.read(disasterHazardOverrideProvider.notifier).state = value;
        Navigator.of(context).pop();
      },
    );
  }
}
