import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:swasthyasetu_ai/domain/rules/disaster_hazard_engine.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// 60-second Post-Flood Syndromic Surveillance modal sheet.
///
/// Assesses acute waterborne diarrhea, suspected leptospirosis, wound infection,
/// and dehydration using deterministic triage rules.
class DisasterSyndromicSheet extends ConsumerStatefulWidget {
  final int? heartRateBpm;
  final double? temperatureC;

  const DisasterSyndromicSheet({
    super.key,
    this.heartRateBpm,
    this.temperatureC,
  });

  static Future<void> show(
    BuildContext context, {
    int? heartRateBpm,
    double? temperatureC,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DisasterSyndromicSheet(
        heartRateBpm: heartRateBpm,
        temperatureC: temperatureC,
      ),
    );
  }

  @override
  ConsumerState<DisasterSyndromicSheet> createState() =>
      _DisasterSyndromicSheetState();
}

class _DisasterSyndromicSheetState
    extends ConsumerState<DisasterSyndromicSheet> {
  bool _showWaterPlaybook = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final survey = ref.watch(floodSyndromicSurveyProvider);

    final triageResult = DisasterHazardEngine.evaluateSyndromicSurvey(
      survey,
      heartRateBpm: widget.heartRateBpm,
      coreTemperatureC: widget.temperatureC,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingSm,
                  ),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_rounded,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const AppSpacing.hmd(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Post-Flood Syndromic Check',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Early warning for waterborne infection & dehydration',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const AppSpacing.vmd(),

                    // Live Triage Result Card
                    _buildTriageCard(context, triageResult),
                    const AppSpacing.vmd(),

                    // Section: 4 Disaster Syndromic Questions
                    Text(
                      'Disaster Symptom Checklist (Last 48 Hours)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      'Check any of the symptoms currently experienced:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const AppSpacing.vsm(),

                    _buildCheckboxTile(
                      context,
                      title: '1. Exposure to Floodwater',
                      subtitle:
                          'Waded or walked through stagnant or flowing floodwater.',
                      value: survey.floodwaterExposure,
                      onChanged: (val) {
                        ref.read(floodSyndromicSurveyProvider.notifier).state =
                            survey.copyWith(floodwaterExposure: val ?? false);
                      },
                    ),

                    _buildCheckboxTile(
                      context,
                      title: '2. Sudden Watery Diarrhea or Vomiting',
                      subtitle:
                          'Multiple loose watery stools, stomach cramps, or nausea.',
                      value: survey.acuteWateryDiarrhea,
                      highlightColor: Colors.deepOrange,
                      onChanged: (val) {
                        ref.read(floodSyndromicSurveyProvider.notifier).state =
                            survey.copyWith(acuteWateryDiarrhea: val ?? false);
                      },
                    ),

                    _buildCheckboxTile(
                      context,
                      title: '3. High Fever with Severe Calf/Muscle Pain',
                      subtitle:
                          'Fever accompanied by intense calf pain, backache, or bloodshot eyes (Leptospirosis watch).',
                      value: survey.highFeverMusclePain,
                      highlightColor: Colors.red,
                      onChanged: (val) {
                        ref.read(floodSyndromicSurveyProvider.notifier).state =
                            survey.copyWith(highFeverMusclePain: val ?? false);
                      },
                    ),

                    _buildCheckboxTile(
                      context,
                      title: '4. Open Cuts, Sores, or Macerated Feet',
                      subtitle:
                          'Skin abrasions, cuts from submerged debris, or trench foot maceration.',
                      value: survey.openWoundsSkinInfection,
                      onChanged: (val) {
                        ref
                            .read(floodSyndromicSurveyProvider.notifier)
                            .state = survey.copyWith(
                          openWoundsSkinInfection: val ?? false,
                        );
                      },
                    ),

                    const AppSpacing.vmd(),

                    // Actionable Steps Card
                    _buildActionsCard(context, triageResult),
                    const AppSpacing.vmd(),

                    // Expandable Safe Water Formulation Playbook
                    _buildSafeWaterPlaybook(context),
                    const AppSpacing.vmd(),

                    // Emergency Hotline Buttons
                    _buildEmergencyHotlineButtons(context),
                    const AppSpacing.vmd(),

                    // Medical Disclaimer
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        'Screening and syndromic early-warning advisory tool only. Does not replace clinical hospital diagnosis. In life-threatening emergencies or severe lethargy/unconsciousness, call 108 or 112 immediately.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const AppSpacing.vlg(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTriageCard(BuildContext context, SyndromicTriageResult result) {
    final theme = Theme.of(context);
    final (color, label, icon) = switch (result.riskLevel) {
      SyndromicRiskLevel.critical => (
        Colors.red,
        'CRITICAL SYNDROMIC RISK',
        Icons.emergency_rounded,
      ),
      SyndromicRiskLevel.high => (
        Colors.deepOrange,
        'HIGH WATERBORNE RISK',
        Icons.warning_amber_rounded,
      ),
      SyndromicRiskLevel.moderate => (
        Colors.amber.shade800,
        'MODERATE SYNDROMIC WATCH',
        Icons.info_outline_rounded,
      ),
      SyndromicRiskLevel.low => (
        AppTheme.riskGreen,
        'LOW SYNDROMIC RISK',
        Icons.check_circle_outline_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Icon(icon, color: Colors.white, size: 14),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.dehydrationScore != null &&
                  result.dehydrationScore! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Dehydration Index: ${result.dehydrationScore!.toStringAsFixed(1)} / 10',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            result.primaryConcern,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (widget.heartRateBpm != null || widget.temperatureC != null) ...[
            const AppSpacing.vxs(),
            Wrap(
              spacing: 12,
              children: [
                if (widget.heartRateBpm != null)
                  Text(
                    'Vitals Pulse: ${widget.heartRateBpm} BPM',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (widget.temperatureC != null)
                  Text(
                    'Core Temp: ${widget.temperatureC!.toStringAsFixed(1)}°C',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    Color? highlightColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: value
          ? (highlightColor ?? theme.colorScheme.primary).withValues(
              alpha: 0.08,
            )
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(
          color: value
              ? (highlightColor ?? theme.colorScheme.primary).withValues(
                  alpha: 0.5,
                )
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: highlightColor ?? theme.colorScheme.primary,
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, SyndromicTriageResult result) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_rounded,
                size: 18,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Immediate Clinical Action Plan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          ...result.clinicalActions.map(
            (act) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      act,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeWaterPlaybook(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: Colors.teal.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _showWaterPlaybook,
        onExpansionChanged: (exp) => setState(() => _showWaterPlaybook = exp),
        leading: const Icon(Icons.water_drop_rounded, color: Colors.teal),
        title: Text(
          'Safe Water & Home ORS Recipe',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.teal.shade900,
          ),
        ),
        subtitle: Text(
          'Emergency boiling, chlorine dosing, and homemade rehydration solution',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          _playbookRow(
            theme,
            '1. Rolling Boil:',
            'Boil drinking water vigorously for a minimum of 1 full minute. Cool in covered, clean containers.',
          ),
          const AppSpacing.vsm(),
          _playbookRow(
            theme,
            '2. Chlorination Tablets:',
            '1 Halazone / Chlorine tablet (approx. 0.5g) treats 20 Liters of water. Wait 30 minutes before drinking.',
          ),
          const AppSpacing.vsm(),
          _playbookRow(
            theme,
            '3. WHO Home ORS Recipe:',
            'In 1 Liter of clean boiled water, thoroughly mix:\n'
                '• 6 level teaspoons of Sugar\n'
                '• 1/2 level teaspoon of Salt\n'
                'Drink 1 glass after every loose stool to prevent fatal dehydration.',
          ),
        ],
      ),
    );
  }

  Widget _playbookRow(ThemeData theme, String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.teal.shade800,
          ),
        ),
        const SizedBox(height: 2),
        Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.3)),
      ],
    );
  }

  Widget _buildEmergencyHotlineButtons(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () => launchUrl(Uri.parse('tel:1078')),
          icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
          label: const Text('Call NDRF (1078)'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepOrange.shade800,
          ),
          onPressed: () => launchUrl(Uri.parse('tel:108')),
          icon: const Icon(Icons.local_hospital_rounded, size: 16),
          label: const Text('Ambulance (108)'),
        ),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse('tel:112')),
          icon: const Icon(Icons.call_rounded, size: 16),
          label: const Text('Police / Disaster (112)'),
        ),
      ],
    );
  }
}
