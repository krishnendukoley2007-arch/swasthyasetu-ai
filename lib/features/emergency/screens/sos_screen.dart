import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/sos_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';

/// The emergency screen: arm, count down, send.
///
/// The countdown is the whole point of this design. A fall detector that fires
/// straight into an SMS blast is worse than no fall detector — the false
/// positives train the worker to disable it, and then the true positive has
/// nothing listening. Ten cancellable seconds keeps the automation useful.
class SosScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final String? screeningId;

  /// Set when the app itself raised the alarm (fall, or a high-risk reading), in
  /// which case the countdown starts on its own.
  final SosTrigger trigger;
  final bool autoStart;

  const SosScreen({
    super.key,
    this.patientId,
    this.screeningId,
    this.trigger = SosTrigger.manual,
    this.autoStart = false,
  });

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  Timer? _countdown;
  int _secondsLeft = 0;
  bool _sending = false;
  SosDispatchResult? _result;

  bool get _isCountingDown => _countdown != null;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      // After the first frame: the countdown reads the persisted duration from
      // the settings snapshot, which is not available during initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown();
      });
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  SosPayload _buildPayload() {
    final settings = ref.read(settingsProvider);
    final patient = widget.patientId == null
        ? null
        : ref.read(patientProvider(widget.patientId!)).valueOrNull;
    final screening = widget.screeningId == null
        ? null
        : ref.read(screeningProvider(widget.screeningId!)).valueOrNull;

    return SosPayload(
      trigger: widget.trigger,
      workerName: settings.workerName,
      patientName: patient?.name,
      patientAge: patient?.age,
      patientId: widget.patientId,
      screeningId: widget.screeningId,
      // The humanised band, never the stored 'RED'.
      riskLabel: screening == null
          ? null
          : RiskStyle.ofStorage(screening.riskLevel, context.l10n).label,
      riskScore: screening?.riskScore,
      heartRate: screening?.heartRate,
      spo2: screening?.spo2,
      temperature: screening?.temperature,
      // Only ever attached when the worker has consented to location tagging,
      // and only from a reading that already carries a geotag. Nothing here
      // asks the GPS for a fresh fix.
      latitude: settings.locationConsent ? screening?.latitude : null,
      longitude: settings.locationConsent ? screening?.longitude : null,
    );
  }

  void _startCountdown() {
    final seconds = ref.read(settingsProvider).sosCountdownSeconds;
    setState(() => _secondsLeft = seconds);
    HapticFeedback.heavyImpact();

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _countdown = null;
        _send();
        return;
      }
      setState(() => _secondsLeft--);
      HapticFeedback.selectionClick();
    });
    setState(() {});
  }

  void _cancelCountdown() {
    _countdown?.cancel();
    _countdown = null;
    HapticFeedback.mediumImpact();
    // Logged, not discarded — a run of cancelled fall alerts is the only signal
    // that the detector needs retuning.
    ref.read(sosServiceProvider).logCancellation(_buildPayload());
    setState(() => _secondsLeft = 0);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final result = await ref.read(sosServiceProvider).dispatch(_buildPayload());
    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = ref.watch(emergencyContactsProvider).valueOrNull ?? const [];
    final reachable = contacts
        .where((c) => EmergencyRepository.isDiallable(c.phone))
        .toList();
    final payload = _buildPayload();

    return AppPageScaffold(
      appBar: AppBar(
        title: Text(context.l10n.sosTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // Backing out during a countdown must not silently let it run on.
          onPressed: () {
            if (_isCountingDown) _cancelCountdown();
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingXl),
        children: [
          if (_result != null)
            _ResultCard(
              result: _result!,
              onRetry: () => setState(() => _result = null),
            )
          else if (_isCountingDown)
            _CountdownCard(
              secondsLeft: _secondsLeft,
              total: ref.watch(settingsProvider).sosCountdownSeconds,
              trigger: widget.trigger,
              onCancel: _cancelCountdown,
              onSendNow: () {
                _countdown?.cancel();
                _countdown = null;
                _send();
              },
            )
          else
            _ArmCard(
              sending: _sending,
              hasRecipients: reachable.isNotEmpty,
              onArm: _startCountdown,
            ),
          const AppSpacing.vmd(),
          _RecipientsCard(recipients: reachable),
          const AppSpacing.vmd(),
          _MessagePreviewCard(body: SosService.composeMessage(payload)),
          const AppSpacing.vlg(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            child: Text(
              context.l10n.sosRecentActivity,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const AppSpacing.vxs(),
          const _SosHistorySection(),
        ],
      ),
    );
  }
}

class _ArmCard extends StatelessWidget {
  final bool sending;
  final bool hasRecipients;
  final VoidCallback onArm;

  const _ArmCard({
    required this.sending,
    required this.hasRecipients,
    required this.onArm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
      border: BorderSide(
        color: theme.colorScheme.error.withValues(alpha: 0.35),
        width: 1,
      ),
      child: Column(
        children: [
          Icon(
            Icons.sos_rounded,
            size: 56,
            color: theme.colorScheme.error,
          ),
          const AppSpacing.vmd(),
          Text(
            context.l10n.sosSendSms,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            hasRecipients
                ? 'Works without internet. You get a countdown to cancel, then '
                    'your messaging app opens with everything filled in.'
                : context.l10n.sosNoContactsBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vlg(),
          if (sending)
            const CircularProgressIndicator()
          else if (hasRecipients)
            AppButton(
              label: context.l10n.sosStart,
              icon: const Icon(Icons.warning_amber_rounded),
              onPressed: onArm,
              minHeight: 60,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            )
          else
            AppOutlinedButton(
              label: 'Add a contact',
              icon: const Icon(Icons.person_add_alt_rounded),
              minHeight: 56,
              onPressed: () => context.push('/emergency/contacts'),
            ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final int secondsLeft;
  final int total;
  final SosTrigger trigger;
  final VoidCallback onCancel;
  final VoidCallback onSendNow;

  const _CountdownCard({
    required this.secondsLeft,
    required this.total,
    required this.trigger,
    required this.onCancel,
    required this.onSendNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total <= 0 ? 0.0 : secondsLeft / total;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      border: BorderSide(color: theme.colorScheme.error, width: 2),
      child: Column(
        children: [
          // Humanised, never the raw enum name.
          Text(
            trigger.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vmd(),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor:
                        theme.colorScheme.error.withValues(alpha: 0.15),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.colorScheme.error),
                  ),
                ),
                // FittedBox, so the numeral shrinks to the ring instead of
                // overflowing it when the system font is scaled to 2.0x.
                FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    child: Text(
                      '$secondsLeft',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const AppSpacing.vmd(),
          Text(
            'Sending in $secondsLeft second${secondsLeft == 1 ? '' : 's'}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vlg(),
          // Cancel is the big, full-width, first-reachable control. If this
          // fired by mistake, stopping it must be the easiest thing on screen.
          AppButton(
            label: context.l10n.actionCancel,
            icon: const Icon(Icons.close_rounded),
            onPressed: onCancel,
            minHeight: 64,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
          ),
          const AppSpacing.vsm(),
          AppTextButton(label: context.l10n.sosSendNow, onPressed: onSendNow),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SosDispatchResult result;
  final VoidCallback onRetry;

  const _ResultCard({required this.result, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = result.isSuccess;
    final accent = ok ? theme.colorScheme.primary : theme.colorScheme.error;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      color: accent.withValues(alpha: 0.12),
      border: BorderSide(color: accent.withValues(alpha: 0.4), width: 1),
      child: Column(
        children: [
          Icon(
            ok ? Icons.mark_email_read_outlined : Icons.error_outline_rounded,
            size: 48,
            color: accent,
          ),
          const AppSpacing.vmd(),
          Text(
            ok ? context.l10n.sosMessagingAppOpened : context.l10n.sosCouldNotSend,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: accent),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vsm(),
          Text(
            ok
                ? 'Press send in your messaging app to deliver it to '
                    '${result.recipients.length} contact'
                    '${result.recipients.length == 1 ? '' : 's'}. '
                    'This attempt is recorded in the SOS log either way.'
                : result.failureReason,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const AppSpacing.vlg(),
          AppOutlinedButton(
            label: ok ? context.l10n.actionBack : context.l10n.actionRetry,
            onPressed: onRetry,
            minHeight: 52,
          ),
        ],
      ),
    );
  }
}

class _RecipientsCard extends StatelessWidget {
  final List<EmergencyContact> recipients;

  const _RecipientsCard({required this.recipients});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Will be messaged (${recipients.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          if (recipients.isEmpty)
            Text(
              'No contacts configured.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                for (final c in recipients)
                  AppPillLabel(
                    label: '${c.name} · ${c.phone}',
                    leadingIcon: c.isPrimary
                        ? Icons.star_rounded
                        : Icons.person_outline_rounded,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MessagePreviewCard extends StatelessWidget {
  final String body;

  const _MessagePreviewCard({required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = (body.length / SosService.singleSegmentChars).ceil();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sms_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  context.l10n.sosMessagePreview,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              // Worth surfacing: on a congested rural cell a multi-part SMS can
              // arrive out of order, or partly not at all.
              Text(
                '${body.length} chars · $segments SMS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosHistorySection extends ConsumerWidget {
  const _SosHistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(sosEventsProvider);
    final names = ref.watch(patientNamesProvider);

    return events.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Text(
          'Could not read the SOS log.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppCard(
            child: Text(
              'No SOS has been raised on this device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final e in list.take(20))
              _SosEventTile(event: e, patientName: names[e.patientId]),
          ],
        );
      },
    );
  }
}

class _SosEventTile extends StatelessWidget {
  final SosEvent event;
  final String? patientName;

  const _SosEventTile({required this.event, this.patientName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (event.status) {
      SosStatus.dispatched => (
          Icons.check_circle_outline_rounded,
          theme.colorScheme.primary,
        ),
      SosStatus.cancelled => (
          Icons.cancel_outlined,
          theme.colorScheme.onSurfaceVariant,
        ),
      SosStatus.failed => (
          Icons.error_outline_rounded,
          theme.colorScheme.error,
        ),
    };

    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Both humanised through the enum's own label.
                Text(
                  '${event.status.label} · ${event.trigger.label}',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const AppSpacing.vxs(),
                Text(
                  _formatWhen(event.triggeredAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const AppSpacing.vxs(),
                Wrap(
                  spacing: AppTheme.spacingSm,
                  runSpacing: AppTheme.spacingXs,
                  children: [
                    AppPillLabel(
                      label: event.recipientSummary,
                      leadingIcon: Icons.groups_outlined,
                    ),
                    if (patientName != null)
                      AppPillLabel(
                        label: patientName!,
                        leadingIcon: Icons.person_outline_rounded,
                      ),
                    if (event.hasLocation)
                      AppPillLabel(
                        label: context.l10n.sosLocationShared,
                        leadingIcon: Icons.place_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatWhen(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day}/${at.month}/${at.year} at $hh:$mm';
  }
}
