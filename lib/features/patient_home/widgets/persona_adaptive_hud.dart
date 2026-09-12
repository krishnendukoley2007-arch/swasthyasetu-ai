import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/vulnerability_persona.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:swasthyasetu_ai/features/patient_home/state/vulnerability_persona_controller.dart';

/// Dynamically adapts the upper dashboard HUD to the active vulnerability persona.
class PersonaAdaptiveHud extends ConsumerWidget {
  const PersonaAdaptiveHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(vulnerabilityPersonaProvider);

    return switch (persona) {
      VulnerabilityPersona.outdoorWorker => const _OutdoorWorkerHud(),
      VulnerabilityPersona.elderlyCitizen => const _ElderlyCitizenHud(),
      VulnerabilityPersona.chronicCondition => const _ChronicConditionHud(),
      VulnerabilityPersona.generalCommunity => const _GeneralCommunityHud(),
    };
  }
}

// ────────────────────────── 1. Outdoor Worker HUD ──────────────────────────
class _OutdoorWorkerHud extends ConsumerWidget {
  const _OutdoorWorkerHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final env = ref.watch(environmentProvider).valueOrNull?.reading;
    final loggedMl = ref.watch(outdoorWorkerHydrationMlProvider);
    final tempC = env?.temperatureC ?? 36.5;
    final isHot = tempC >= 38.0;

    final psiValue = isHot ? 5.6 : 3.2;
    final psiLabel = isHot ? 'Moderate Heat Strain' : 'Safe Thermal Load';
    final psiColor = isHot ? ClinicalPalette.amber : ClinicalPalette.teal;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ClinicalPalette.cardiacCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.wb_sunny_rounded,
                  size: 20,
                  color: ClinicalPalette.cardiacAccent(context),
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Field & Labor Heat Shield',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: psiColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'PSI $psiValue • $psiLabel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: psiColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingSm,
            children: [
              _HudTelemetryTile(
                icon: Icons.thermostat_rounded,
                label: 'Ambient Heat',
                value: '${tempC.toStringAsFixed(1)}°C',
                subtitle: 'WBGT 31.0°C',
                color: psiColor,
              ),
              _HudTelemetryTile(
                icon: Icons.local_drink_rounded,
                label: 'Hydration Intake',
                value: '${loggedMl}ml',
                subtitle: 'Goal: 2500ml',
                color: ClinicalPalette.cyan,
              ),
              _HudTelemetryTile(
                icon: Icons.timer_outlined,
                label: 'Rest Interval',
                value: isHot ? '45m / 15m' : '50m / 10m',
                subtitle: 'Work / Shaded Rest',
                color: ClinicalPalette.teal,
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(outdoorWorkerHydrationMlProvider.notifier)
                      .update((v) => v + 250);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Logged +250ml water. Hydration timer reset to 15m.',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('+250ml Water'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/screening/heat-guardian'),
                icon: const Icon(Icons.shield_rounded, size: 18),
                label: const Text('Heat Guardian'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────── 2. Elderly Citizen HUD ──────────────────────────
class _ElderlyCitizenHud extends StatelessWidget {
  const _ElderlyCitizenHud();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ClinicalPalette.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.elderly_rounded,
                  size: 20,
                  color: ClinicalPalette.teal,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Silent Risk & Fall Sentinel',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ClinicalPalette.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Vigilance Active',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ClinicalPalette.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: ClinicalPalette.tealBright,
                    shape: BoxShape.circle,
                  ),
                ),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    '24/7 Fall Detection: Sensor Sentinel Active',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const AppSpacing.vsm(),
          const Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingSm,
            children: [
              _HudTelemetryTile(
                icon: Icons.nightlight_round,
                label: 'Nocturnal Dipping',
                value: '12% Dipping',
                subtitle: 'Healthy Autonomic Drop',
                color: ClinicalPalette.cyan,
              ),
              _HudTelemetryTile(
                icon: Icons.favorite_rounded,
                label: 'Resting Pulse',
                value: '72 bpm',
                subtitle: 'Stable Rhythm',
                color: ClinicalPalette.teal,
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/emergency/contacts'),
                style: FilledButton.styleFrom(
                  backgroundColor: ClinicalPalette.coral,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Emergency Family Call'),
              ),
              IconButton.outlined(
                tooltip: 'Overnight Guardian',
                onPressed: () => context.push('/screening/overnight-guardian'),
                icon: const Icon(Icons.bedtime_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────── 3. Chronic Cardiopulmonary HUD ──────────────────────
class _ChronicConditionHud extends ConsumerWidget {
  const _ChronicConditionHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final env = ref.watch(environmentProvider).valueOrNull?.reading;
    final pm25 = env?.pm25 ?? 65.0;
    final isSmogElevated = pm25 >= 100.0;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ClinicalPalette.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.air_rounded,
                  size: 20,
                  color: ClinicalPalette.cyan,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cardiorespiratory Reserve Sentinel',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isSmogElevated
                                    ? ClinicalPalette.amber
                                    : ClinicalPalette.teal)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isSmogElevated ? 'Smog Alert' : 'Airway Intact',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSmogElevated
                              ? ClinicalPalette.amber
                              : ClinicalPalette.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingSm,
            children: [
              _HudTelemetryTile(
                icon: Icons.cloud_queue_rounded,
                label: 'Ambient PM2.5',
                value: '${pm25.toStringAsFixed(0)} µg/m³',
                subtitle: isSmogElevated ? 'Elevated Particulate' : 'Moderate',
                color: isSmogElevated
                    ? ClinicalPalette.amber
                    : ClinicalPalette.cyan,
              ),
              const _HudTelemetryTile(
                icon: Icons.bloodtype_outlined,
                label: 'Daytime SpO₂',
                value: '98%',
                subtitle: 'Airway Reserve Intact',
                color: ClinicalPalette.teal,
              ),
              const _HudTelemetryTile(
                icon: Icons.speed_rounded,
                label: 'Distress Index (CDI)',
                value: '1.4 · Low',
                subtitle: 'Autonomic Stability',
                color: ClinicalPalette.teal,
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      context.push('/screening/air-pollution-guardian'),
                  icon: const Icon(Icons.self_improvement_rounded, size: 18),
                  label: const Text('Start Guided Breathing (PEEP)'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────── 4. General Community HUD ──────────────────────
class _GeneralCommunityHud extends ConsumerWidget {
  const _GeneralCommunityHud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trajectory = ref.watch(earlyWarningTrajectoryProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ClinicalPalette.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  size: 20,
                  color: ClinicalPalette.teal,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community Resilience Sentinel',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ClinicalPalette.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        trajectory.severity.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ClinicalPalette.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          const Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingSm,
            children: [
              _HudTelemetryTile(
                icon: Icons.timeline_rounded,
                label: '7-Day Baseline',
                value: 'Stable',
                subtitle: 'Resting Vitals Normal',
                color: ClinicalPalette.teal,
              ),
              _HudTelemetryTile(
                icon: Icons.shield_outlined,
                label: 'Disease Outbreak',
                value: 'Sentinel Active',
                subtitle: 'Community Safe',
                color: ClinicalPalette.cyan,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudTelemetryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _HudTelemetryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
