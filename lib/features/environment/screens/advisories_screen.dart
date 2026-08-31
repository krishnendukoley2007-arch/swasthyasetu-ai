import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_advisory.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';

/// Health alerts and disaster guides.
///
/// Two layers, one screen: on top, the live conditions at this location
/// (from the weather service, personalised to the signed-in patient); below,
/// the offline disaster guides — bundled in the APK, because the moment they
/// matter most is exactly when the network is least likely to exist.
class AdvisoriesScreen extends ConsumerWidget {
  const AdvisoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final env = ref.watch(environmentProvider).valueOrNull;
    final advisories =
        ref.watch(environmentAdvisoriesProvider).valueOrNull ?? const [];
    final guides = ref.watch(disasterAdvisoriesProvider).valueOrNull;

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Health alerts & guides')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        children: [
          const AppSectionHeader(
            title: 'Right now',
            subtitle: 'Live conditions around you',
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
          const AppSpacing.vsm(),
          _buildNowSection(theme, env, advisories),
          const AppSpacing.vxl(),
          const AppSectionHeader(
            title: 'Disaster health guides',
            subtitle: 'Work fully offline — read them before you need them',
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
          const AppSpacing.vsm(),
          if (guides == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingXl),
                child: CircularProgressIndicator(),
              ),
            )
          else
            ...guides.map(_GuideCard.new),
          const AppSpacing.vxl(),
          AppFilledCard(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Text(
              'These guides summarise public NDMA/WHO advice for common '
              'emergencies. They support, but never replace, instructions '
              'from local authorities and doctors.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const AppSpacing.vlg(),
        ],
      ),
    );
  }

  Widget _buildNowSection(ThemeData theme, EnvironmentState? env,
      List<EnvironmentAdvisory> advisories) {
    if (env == null || !env.consentGranted) {
      return AppCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Text(
          'Turn on local weather (from the card on your home screen) to see '
          'heat and air alerts for your area here.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
        ),
      );
    }
    final reading = env.reading;
    if (reading == null) {
      return AppCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Text(
          'No reading yet — this needs a moment of internet once, then works '
          'offline from the last reading.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
        ),
      );
    }
    if (advisories.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: theme.colorScheme.primary, size: 24),
            const AppSpacing.hmd(),
            Expanded(
              child: Text(
                'Conditions look fine for health right now (feels like '
                '${reading.apparentTemperatureC.round()}°C).',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final advisory in advisories) ...[
          _AdvisoryCard(advisory: advisory),
          const AppSpacing.vsm(),
        ],
      ],
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  final EnvironmentAdvisory advisory;

  const _AdvisoryCard({required this.advisory});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, container, icon) = switch (advisory.level) {
      AdvisoryLevel.danger => (
          theme.colorScheme.onErrorContainer,
          theme.colorScheme.errorContainer,
          Icons.warning_amber_rounded,
        ),
      AdvisoryLevel.warning => (
          theme.colorScheme.onErrorContainer,
          theme.colorScheme.errorContainer,
          Icons.warning_amber_rounded,
        ),
      AdvisoryLevel.advice => (
          theme.colorScheme.onTertiaryContainer,
          theme.colorScheme.tertiaryContainer,
          Icons.info_outline_rounded,
        ),
      AdvisoryLevel.info => (
          theme.colorScheme.onPrimaryContainer,
          theme.colorScheme.primaryContainer,
          Icons.tips_and_updates_outlined,
        ),
    };

    return AppCard(
      color: container,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  advisory.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            advisory.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final DisasterAdvisory guide;

  const _GuideCard(this.guide);

  IconData get _icon => switch (guide.id) {
        'heat_wave' => Icons.wb_sunny_rounded,
        'flood' => Icons.flood_rounded,
        'cyclone' => Icons.cyclone_rounded,
        'poor_air' => Icons.masks_rounded,
        'outbreak' => Icons.coronavirus_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Flat look: the card is the container, the tile manages its own pad.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(_icon, color: theme.colorScheme.primary),
          title: Text(
            guide.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: guide.forWhom.isEmpty
              ? null
              : Text(
                  'Matters most for: ${guide.forWhom}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
            vertical: AppTheme.spacingSm,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (guide.beforeSteps.isNotEmpty)
              _stepBlock(theme, 'Before', guide.beforeSteps),
            if (guide.duringSteps.isNotEmpty)
              _stepBlock(theme, 'During', guide.duringSteps),
            if (guide.afterSteps.isNotEmpty)
              _stepBlock(theme, 'After', guide.afterSteps),
            if (guide.helplines.isNotEmpty) ...[
              const AppSpacing.vmd(),
              AppFilledCard(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.call_rounded,
                        color: theme.colorScheme.primary, size: 18),
                    const AppSpacing.hsm(),
                    Expanded(
                      child: Text(
                        guide.helplines,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const AppSpacing.vmd(),
          ],
        ),
      ),
    );
  }

  Widget _stepBlock(ThemeData theme, String title, List<String> steps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const AppSpacing.vxs(),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const AppSpacing.hmd(),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
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
