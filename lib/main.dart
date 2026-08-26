import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/routing/app_router.dart';
import 'package:swasthyasetu_ai/core/services/error_handler_service.dart';
import 'package:swasthyasetu_ai/core/services/fall_alarm_coordinator.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/l10n/generated/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorHandlerService.initialize();
  runApp(const ProviderScope(child: SwasthyaSetuApp()));
}

class SwasthyaSetuApp extends ConsumerWidget {
  const SwasthyaSetuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final highContrast = ref.watch(highContrastProvider);
    final router = ref.watch(routerProvider);

    ThemeData resolve(ThemeData base) =>
        highContrast ? AppTheme.highContrast(base) : base;

    return MaterialApp.router(
      title: 'SwasthyaSetu AI',
      theme: resolve(AppTheme.lightTheme),
      darkTheme: resolve(AppTheme.darkTheme),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        // No textScaler clamp here. Squeezing the system font size back to 1.2×
        // hides overflow rather than fixing it, and it overrides an
        // accessibility setting the user deliberately chose — layouts are built
        // to survive 2.0× instead.
        return _Bootstrap(
          child: FallAlarmListener(
            child: ErrorBoundary(
              fallbackBuilder: (error, stack, onRetry) => _DefaultErrorFallback(
                error: error,
                stack: stack,
                onRetry: onRetry,
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

/// Holds the first frame until the local database is ready.
///
/// Every screen reads from SQLite, so showing the router before the guideline
/// corpus and defaults are in place would flash empty states at the worker. The
/// wait is short — on a warm install it is a single settings read.
class _Bootstrap extends ConsumerWidget {
  final Widget child;

  const _Bootstrap({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);

    return boot.when(
      data: (_) => child,
      loading: () => const _SplashScreen(),
      // A seed failure is recoverable: the database exists, only the extras
      // failed. Say so plainly and let the worker carry on or retry.
      error: (error, _) => _BootstrapFailure(
        error: error,
        onRetry: () => ref.invalidate(bootstrapProvider),
        onContinue: () => ref.read(_bypassBootstrapProvider.notifier).state = true,
        bypassed: ref.watch(_bypassBootstrapProvider),
        child: child,
      ),
    );
  }
}

/// Set when the worker chooses to continue past a failed seed. Deliberately not
/// persisted: the next launch tries again.
final _bypassBootstrapProvider = StateProvider<bool>((ref) => false);

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                l10n.appName,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                l10n.bootstrapping,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXl),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(minHeight: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapFailure extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onContinue;
  final bool bypassed;
  final Widget child;

  const _BootstrapFailure({
    required this.error,
    required this.onRetry,
    required this.onContinue,
    required this.bypassed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (bypassed) return child;

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 56,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  'Offline data could not be prepared',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Text(
                  'Screening still works. The offline guideline reference may '
                  'be unavailable until this succeeds.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingXl),
                Wrap(
                  spacing: AppTheme.spacingMd,
                  runSpacing: AppTheme.spacingSm,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continue anyway'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultErrorFallback extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  final VoidCallback onRetry;

  const _DefaultErrorFallback({
    required this.error,
    this.stack,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          // Scrollable: at 2.0 text scale on a short screen this column is
          // taller than the viewport, and an error screen that itself overflows
          // is worse than the original error.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart App'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
