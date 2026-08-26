import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/sync_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';

/// Everything captured but not yet uploaded.
///
/// The point of this screen is reassurance: a worker with no signal needs to see
/// that their readings are safe on the device, not an error wall. Nothing here
/// can delete a record.
class PendingSyncScreen extends ConsumerStatefulWidget {
  const PendingSyncScreen({super.key});

  @override
  ConsumerState<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends ConsumerState<PendingSyncScreen> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingScreeningsProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Waiting to upload'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.go('/home'),
        ),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not read the queue',
          subtitle: 'Your records are still stored on this device.',
        ),
        data: (pending) => Column(
          children: [
            Expanded(
              // The header scrolls with the queue rather than sitting pinned
              // above it: header plus action bar exceeded the screen height at
              // large text sizes, leaving the list nothing to lay out in.
              child: pending.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      children: [
                        const _Header(count: 0)
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: -0.1),
                        const AppEmptyState(
                          icon: Icons.cloud_done_rounded,
                          title: 'All caught up',
                          subtitle: 'Every screening on this device has been '
                              'uploaded.',
                        ).animate().fadeIn(duration: 400.ms),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      itemCount: pending.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _Header(count: pending.length)
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: -0.1);
                        }
                        final screening = pending[index - 1];
                        return _PendingCard(
                          screening: screening,
                          onRetry: () => _retry(screening),
                        )
                            .animate()
                            .fadeIn(
                              duration: 300.ms,
                              delay: (60 * ((index - 1) % 8)).ms,
                            )
                            .slideX(begin: 0.06);
                      },
                    ),
            ),
            _BottomActions(
              isSyncing: _isSyncing,
              canSync: pending.isNotEmpty,
              onSync: _syncAll,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  Future<void> _syncAll() async {
    setState(() => _isSyncing = true);
    final report = await ref.read(syncServiceProvider).syncAll();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    _report(report);
  }

  Future<void> _retry(Screening screening) async {
    final report = await ref.read(syncServiceProvider).retry(screening.id);
    if (!mounted) return;
    _report(report);
  }

  void _report(SyncReport report) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(report.message),
        duration: const Duration(seconds: 5),
        backgroundColor: report.outcome == SyncOutcome.uploaded
            ? theme.colorScheme.primary
            : theme.colorScheme.secondaryContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;

  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allClear = count == 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: allClear
                  ? AppTheme.riskGreenContainer
                  : theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Icon(
              allClear ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: allClear ? AppTheme.riskGreen : theme.colorScheme.tertiary,
              size: 26,
            ),
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allClear
                      ? 'Nothing waiting'
                      : '$count record${count == 1 ? '' : 's'} waiting',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                ),
                const AppSpacing.vxs(),
                Text(
                  allClear
                      ? 'Screenings upload automatically when a connection is '
                          'available.'
                      : 'These are saved on this device. Nothing is lost while '
                          'you are offline.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _PendingCard extends StatelessWidget {
  final Screening screening;
  final VoidCallback onRetry;

  const _PendingCard({required this.screening, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final risk = RiskStyle.ofStorage(screening.riskLevel, context.l10n);
    final sync = SyncStyle.of(screening.syncStatus, context.l10n);

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
                width: 40,
                height: 40,
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
                      // Humanised band, never the raw 'RED'.
                      risk.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: risk.color,
                      ),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      '${screening.heartRate} bpm · ${screening.spo2}% · '
                      '${screening.temperature.toStringAsFixed(1)} °C',
                      style: theme.textTheme.bodyMedium,
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
            ],
          ),
          const AppSpacing.vsm(),
          // Wrap so the status chip and the retry button drop to a second line
          // at large text scales instead of overflowing the row.
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingXs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: sync.label,
                icon: sync.icon,
                backgroundColor: sync.color.withValues(alpha: 0.12),
                textColor: sync.color,
              ),
              if (screening.retryCount > 0)
                Text(
                  '${screening.retryCount} attempt'
                  '${screening.retryCount == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (screening.syncStatus == 'FAILED')
                AppTextButton(
                  label: 'Retry',
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  onPressed: onRetry,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isSyncing;
  final bool canSync;
  final VoidCallback onSync;

  const _BottomActions({
    required this.isSyncing,
    required this.canSync,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AppOutlinedButton(
                label: isSyncing ? 'Uploading…' : 'Upload now',
                icon: isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                onPressed: isSyncing || !canSync ? null : onSync,
              ),
            ),
            const AppSpacing.hmd(),
            Expanded(
              child: AppButton(
                label: 'Done',
                icon: const Icon(Icons.home_rounded),
                onPressed: isSyncing ? null : () => context.go('/home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
