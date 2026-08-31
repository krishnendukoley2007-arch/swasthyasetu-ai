import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/environment_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';

/// The heat-and-air card shown on both home screens.
///
/// Every state names its actual obstacle and offers the one button that can
/// clear it:
///   1. off — consent not granted → explain the benefit, one tap enables
///   2. an [EnvFailure] with no cached reading → its own words, its own action
///      (open location settings, open app settings, or retry). These used to be
///      collapsed into "needs a moment of internet", which told a user with
///      working data and switched-off GPS to do the one thing that wouldn't help
///   3. showing a reading → conditions + the worst advisory + link to guides.
///      A cached reading wins over any failure: yesterday's heat warning still
///      beats an error message
///
/// Nothing on this card is decorative: the tap target is the advisories
/// screen, and the enable button performs the full consent → OS permission →
/// refresh chain in one move, because asking users to configure this in
/// Settings went untested and unused.
class EnvironmentCard extends ConsumerStatefulWidget {
  const EnvironmentCard({super.key});

  @override
  ConsumerState<EnvironmentCard> createState() => _EnvironmentCardState();
}

class _EnvironmentCardState extends ConsumerState<EnvironmentCard> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final granted = await ref
          .read(environmentServiceProvider)
          .requestLocationPermission();
      await ref
          .read(settingsProvider.notifier)
          .setEnvLocationConsent(granted);
      // The provider watches consent — invalidation makes it fetch now rather
      // than on the next build cycle.
      ref.invalidate(environmentProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final env = ref.watch(environmentProvider);

    return env.when(
      loading: () => _shell(
        theme,
        icon: Icons.cloud_sync_rounded,
        title: 'Checking local conditions…',
        body: null,
      ),
      error: (_, __) => _shell(
        theme,
        icon: Icons.cloud_off_rounded,
        title: 'Weather check failed',
        body: 'Your screenings are not affected.',
        action: AppTextButton(
          label: 'Try again',
          onPressed: () => ref.invalidate(environmentProvider),
        ),
      ),
      data: (state) {
        if (!state.consentGranted) return _consentCard(theme);
        if (state.reading != null) return _readingCard(theme, state.reading!);

        // No reading yet. Which obstacle it is decides both the words and the
        // button — a Retry against a switched-off GPS can never succeed, and
        // offering one was the whole reason this card looked broken.
        final failure = state.failure;
        return _shell(
          theme,
          icon: switch (failure) {
            EnvFailure.locationServicesOff ||
            EnvFailure.permissionBlocked =>
              Icons.location_off_rounded,
            _ => Icons.cloud_off_rounded,
          },
          title: failure?.title ?? 'No weather data yet',
          body: failure?.detail ??
              'Needs a moment of internet once; after that the last reading '
                  'keeps working offline.',
          action: switch (failure) {
            EnvFailure.locationServicesOff => AppTextButton(
                label: 'Turn on',
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            EnvFailure.permissionBlocked => AppTextButton(
                label: 'Settings',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            _ => AppTextButton(
                label: 'Retry',
                onPressed: () => ref.invalidate(environmentProvider),
              ),
          },
        );
      },
    );
  }

  Widget _consentCard(ThemeData theme) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat_rounded,
                  color: theme.colorScheme.tertiary, size: 26),
              const AppSpacing.hmd(),
              Expanded(
                child: Text(
                  'Heat & air alerts for your area',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'This uses your location once to fetch local heat and air-quality '
            'levels, then works offline. Nothing is uploaded anywhere.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const AppSpacing.vmd(),
          AppButton(
            label: 'Turn on local weather',
            icon: const Icon(Icons.my_location_rounded, size: 20),
            isLoading: _busy,
            onPressed: _busy ? null : _enable,
            minHeight: 48,
          ),
        ],
      ),
    );
  }

  Widget _readingCard(ThemeData theme, EnvironmentReading r) {
    final advisoriesAsync = ref.watch(environmentAdvisoriesProvider);
    final advisories = advisoriesAsync.valueOrNull ?? const [];
    final worst = advisories.isEmpty ? null : advisories.first;

    final (levelColor, levelBg) = switch (worst?.level) {
      AdvisoryLevel.danger => (
          theme.colorScheme.onErrorContainer,
          theme.colorScheme.errorContainer
        ),
      AdvisoryLevel.warning => (
          theme.colorScheme.onErrorContainer,
          theme.colorScheme.errorContainer
        ),
      AdvisoryLevel.advice => (
          theme.colorScheme.onTertiaryContainer,
          theme.colorScheme.tertiaryContainer
        ),
      AdvisoryLevel.info || null => (
          theme.colorScheme.onPrimaryContainer,
          theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
        ),
    };

    final age = DateTime.now().difference(r.fetchedAt);
    final ageText = age.inMinutes < 1
        ? 'just now'
        : age.inMinutes < 60
            ? '${age.inMinutes} min ago'
            : '${age.inHours} h ago';

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/advisories'),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.thermostat_rounded,
                    color: theme.colorScheme.tertiary, size: 26),
                const AppSpacing.hmd(),
                Expanded(
                  child: Text(
                    'Around you now',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const AppSpacing.vmd(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                AppBadge(
                  label: 'Feels ${r.apparentTemperatureC.round()}°C',
                  icon: Icons.device_thermostat_rounded,
                ),
                AppBadge(
                  label: '${r.humidityPercent.round()}% humidity',
                  icon: Icons.water_drop_outlined,
                ),
                AppBadge(
                  label: r.aqiUs != null
                      ? 'AQI ${r.aqiUs}'
                      : 'AQI unavailable',
                  icon: Icons.air_rounded,
                ),
              ],
            ),
            if (worst != null) ...[
              const AppSpacing.vmd(),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: levelBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      (worst.level == AdvisoryLevel.warning ||
                              worst.level == AdvisoryLevel.danger)
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                      color: levelColor,
                      size: 20,
                    ),
                    const AppSpacing.hsm(),
                    Expanded(
                      child: Text(
                        worst.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: levelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const AppSpacing.vmd(),
              Text(
                'Conditions look fine for health today.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const AppSpacing.vsm(),
            Text(
              r.isLive
                  ? 'Live · updated $ageText'
                  : 'Offline · from $ageText',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shell(ThemeData theme,
      {required IconData icon,
      required String title,
      String? body,
      Widget? action}) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 24),
              const AppSpacing.hmd(),
              Expanded(
                child: Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (action != null) action,
            ],
          ),
          if (body != null) ...[
            const AppSpacing.vxs(),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
