/// Hardware diagnostics, reporting measurements.
///
/// The previous version of this screen ticked eleven named chip-level tests to
/// green on an 800 ms timer and then displayed the badge "ALL TESTS PASSED",
/// with no attached board and no code path that could fail. Everything shown
/// here now comes from [BleDiagnostics], which observes the link for a fixed
/// window and reports what actually arrived — including "not checked", which is
/// the honest answer when there is no board and the one the old screen could
/// never give.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_diagnostics.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

class DeviceDiagnosticsScreen extends ConsumerStatefulWidget {
  const DeviceDiagnosticsScreen({super.key});

  @override
  ConsumerState<DeviceDiagnosticsScreen> createState() =>
      _DeviceDiagnosticsScreenState();
}

class _DeviceDiagnosticsScreenState
    extends ConsumerState<DeviceDiagnosticsScreen> {
  DiagnosticReport _report = const DiagnosticReport(checks: kDiagnosticChecks);
  StreamSubscription<DiagnosticReport>? _sub;

  @override
  void dispose() {
    // Cancelling aborts the observation window; without this, backing out
    // mid-run leaves a 6-second timer writing into a disposed State.
    _sub?.cancel();
    super.dispose();
  }

  void _run() {
    _sub?.cancel();
    setState(() {
      _report = const DiagnosticReport(
        checks: kDiagnosticChecks,
        isRunning: true,
      );
    });
    _sub = BleDiagnostics().run(ref.read(bleServiceProvider)).listen(
          (report) {
            if (mounted) setState(() => _report = report);
          },
          onDone: () => _sub = null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Device diagnostics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/devices/connect'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              // The header scrolls with the list rather than being pinned above
              // it: at large text sizes the header and the action bar together
              // were taller than the screen, leaving the list a negative height.
              itemCount: _report.checks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _Header(report: _report);
                return _CheckCard(check: _report.checks[index - 1]);
              },
            ),
          ),
          _BottomActions(
            report: _report,
            onRun: _report.isRunning ? null : _run,
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final DiagnosticReport report;

  const _Header({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);

    // Green only for a clean, complete run. A run with skipped checks is not an
    // all-clear, and the old unconditional "ALL TESTS PASSED" badge was the
    // single most misleading thing on this screen.
    final (badge, badgeColor) = switch (report) {
      _ when report.isRunning => (null, null),
      _ when !report.isComplete => (null, null),
      _ when report.isConclusive => ('ALL CHECKS PASSED', theme.colorScheme.primary),
      _ when report.failed > 0 => ('${report.failed} FAILED', theme.colorScheme.error),
      _ => ('INCOMPLETE', theme.colorScheme.tertiary),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  Icons.build_circle_outlined,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Text(
                  'Hardware diagnostics',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            report.summary,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          // Board identity, live: name, firmware string and the battery figure
          // from the most recent telemetry frame. Hidden when nothing is
          // connected rather than showing stale numbers.
          if (link.deviceName != null) ...[
            const AppSpacing.vsm(),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                _metaChip(
                  theme,
                  Icons.memory_rounded,
                  link.firmwareVersion != null
                      ? 'Firmware ${link.firmwareVersion}'
                      : 'Firmware unknown',
                ),
                if (link.batteryPercent != null)
                  _metaChip(
                    theme,
                    Icons.battery_std_rounded,
                    'Battery ${link.batteryPercent}%',
                  ),
                _metaChip(
                  theme,
                  Icons.bluetooth_connected_rounded,
                  link.deviceName!,
                ),
              ],
            ),
          ],
          if (report.isRunning && report.remaining != null) ...[
            const AppSpacing.vxs(),
            Text(
              'Watching the link for ${report.remaining!.inSeconds}s more. '
              'Keep a finger on the sensor.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
          // Wrap, not Row: the badge next to the title clipped at 2.0x text
          // scale, and the badge is the part that carries the verdict.
          if (badge != null) ...[
            const AppSpacing.vsm(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: badgeColor!.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
          const AppSpacing.vsm(),
          Divider(color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _metaChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final DiagnosticCheck check;

  const _CheckCard({required this.check});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (check.outcome) {
      DiagnosticOutcome.pending => (
          Icons.radio_button_unchecked_rounded,
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      DiagnosticOutcome.running => (
          Icons.sync_rounded,
          theme.colorScheme.primary,
        ),
      DiagnosticOutcome.pass => (
          Icons.check_circle_rounded,
          theme.colorScheme.primary,
        ),
      DiagnosticOutcome.fail => (
          Icons.error_rounded,
          theme.colorScheme.error,
        ),
      DiagnosticOutcome.skipped => (
          Icons.remove_circle_outline_rounded,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        check.name,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const AppSpacing.hsm(),
                    Text(
                      check.category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const AppSpacing.vxs(),
                Text(
                  // The measurement replaces the description once there is one:
                  // "3 frames in 6s (0.5/s)" is more use than a restatement of
                  // what the check was for.
                  check.detail.isEmpty ? check.description : check.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: check.outcome == DiagnosticOutcome.fail
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (check.outcome == DiagnosticOutcome.running) ...[
            const AppSpacing.hsm(),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final DiagnosticReport report;
  final VoidCallback? onRun;

  const _BottomActions({required this.report, this.onRun});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: report.isRunning
                  ? 'Checking…'
                  : report.isComplete
                      ? 'Run checks again'
                      : 'Run checks',
              icon: const Icon(Icons.play_arrow_rounded),
              isLoading: report.isRunning,
              minHeight: 52,
              onPressed: onRun,
            ),
            if (report.isComplete && report.failed == 0) ...[
              const AppSpacing.vsm(),
              AppOutlinedButton(
                label: 'Start screening',
                icon: const Icon(Icons.medical_services_outlined),
                minHeight: 48,
                onPressed: () => context.go('/screening/new'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
