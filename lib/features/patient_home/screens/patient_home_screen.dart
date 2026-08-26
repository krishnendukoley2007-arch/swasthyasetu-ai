import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/device.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/domain/rules/health_report.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:swasthyasetu_ai/features/environment/widgets/environment_card.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

/// The patient's own home: connect the ESP32, run a self-check, understand
/// the result in plain words, reach help fast.
///
/// Deliberately not a trimmed copy of the clinician dashboard. The worker's
/// counts (today's screenings, sync queue) are meaningless to a person
/// checking their own pulse, so this screen is rebuilt around four questions
/// a patient actually asks: is my device on me, what did it say last time,
/// what does that mean for me, and who do I call if it goes wrong.
class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(authStateProvider).account;
    final patientAsync = ref.watch(myPatientProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: Text(
          'My Health',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [_buildMenu(context, ref)],
        elevation: 0,
      ),
      body: patientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildProfileError(context, ref),
        data: (patient) {
          if (patient == null || account == null) {
            return _buildProfileError(context, ref);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myPatientProvider);
              ref.invalidate(patientScreeningsProvider(patient.id));
              await Future<void>.delayed(const Duration(milliseconds: 150));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                _buildGreeting(context, account),
                const AppSpacing.vlg(),
                const EnvironmentCard(),
                const AppSpacing.vlg(),
                _buildDeviceCard(context, ref, patient),
                const AppSpacing.vlg(),
                _buildLatestResult(context, ref, patient),
                const AppSpacing.vlg(),
                _buildQuickLinks(context, patient),
                const AppSpacing.vlg(),
                _buildProfileCard(context, account),
                const AppSpacing.vlg(),
                _buildSosCard(context, patient),
                const AppSpacing.vlg(),
                _buildDisclaimer(context),
                const AppSpacing.vxl(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────── Greeting ─────────────────────────────

  Widget _buildGreeting(BuildContext context, UserAccount account) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${account.firstName}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const AppSpacing.vxs(),
        Text(
          'Run a check any time — it takes about a minute.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // ───────────────────────────── Device / self-check ─────────────────────────────

  Widget _buildDeviceCard(
      BuildContext context, WidgetRef ref, Patient patient) {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);
    final isLive = link.status == BleLinkStatus.streaming;
    final isBusy = switch (link.status) {
      BleLinkStatus.scanning ||
      BleLinkStatus.connecting ||
      BleLinkStatus.discovering ||
      BleLinkStatus.handshaking ||
      BleLinkStatus.reconnecting =>
        true,
      _ => false,
    };

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: (isLive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant)
                      .withValues(alpha: isLive ? 0.15 : 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  isLive
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  color: isLive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLive
                          ? (link.deviceName ?? 'SwasthyaSetu device')
                          : isBusy
                              ? 'Connecting…'
                              : 'Device not connected',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      isLive
                          ? 'Ready${link.batteryPercent != null ? ' · battery ${link.batteryPercent}%' : ''}'
                          : isBusy
                              ? 'Keep the device nearby'
                              : 'Connect the ESP32 sensor to start',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vlg(),
          AppButton(
            label: isLive ? 'Start Health Check' : 'Connect my device',
            icon: Icon(
                isLive
                    ? Icons.monitor_heart_rounded
                    : Icons.bluetooth_searching_rounded,
                size: 24),
            onPressed: isBusy
                ? null
                : () => isLive
                    ? _startSelfCheck(context, ref, patient, demo: false)
                    : context.push('/devices/scan'),
            minHeight: 56,
          ),
          if (!isLive) ...[
            const AppSpacing.vsm(),
            Center(
              child: AppTextButton(
                label: 'No device handy? Try with demo data',
                onPressed: () => _startSelfCheck(context, ref, patient,
                    demo: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A self-check skips the worker's pick-a-patient step entirely: the
  /// patient IS the subject, so the draft begins with them and the flow
  /// opens on live vitals — same pipeline, their own thresholds.
  void _startSelfCheck(
    BuildContext context,
    WidgetRef ref,
    Patient patient, {
    required bool demo,
  }) {
    final link = ref.read(bleLinkProvider);
    final Device device;
    if (!demo &&
        link.status == BleLinkStatus.streaming &&
        link.deviceId != null) {
      device = Device(
        id: link.deviceId!,
        name: link.deviceName ?? 'SwasthyaSetu device',
        macAddress: link.deviceId!,
        batteryPercent: link.batteryPercent ?? 0,
        isConnected: true,
        lastConnectedAt: DateTime.now(),
      );
    } else {
      device = Device.demo();
    }
    ref
        .read(screeningDraftProvider.notifier)
        .begin(patient: patient, device: device);
    context.go('/screening/live');
  }

  // ───────────────────────────── Latest result ─────────────────────────────

  Widget _buildLatestResult(
      BuildContext context, WidgetRef ref, Patient patient) {
    final theme = Theme.of(context);
    final screenings =
        ref.watch(patientScreeningsProvider(patient.id)).valueOrNull;
    final latest = (screenings == null || screenings.isEmpty)
        ? null
        : screenings.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'My latest result',
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        const AppSpacing.vsm(),
        AppCard(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: latest == null
              ? Column(
                  children: [
                    Icon(Icons.monitor_heart_outlined,
                        size: 42, color: theme.colorScheme.onSurfaceVariant),
                    const AppSpacing.vmd(),
                    Text(
                      'No checks yet',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      'Your first reading appears here, with a plain-words '
                      'explanation of what it means — and what you can safely '
                      'do at home.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingXs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppRiskBadge(
                          riskLevel: latest.riskLevel,
                          isCompact: true,
                        ),
                        Text(
                          relativeTime(latest.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const AppSpacing.vmd(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _vital(context, 'Heart rate',
                                latest.heartRate, 'bpm', Icons.favorite_rounded)),
                        Expanded(
                            child: _vital(context, 'SpO₂', latest.spo2, '%',
                                Icons.air_rounded)),
                        Expanded(
                            child: _vital(context, 'Temp', latest.temperature,
                                '°C', Icons.thermostat_rounded,
                                digits: 1)),
                      ],
                    ),
                    const AppSpacing.vlg(),
                    AppButton(
                      label: 'What does this mean for me?',
                      icon: const Icon(Icons.auto_awesome_rounded, size: 22),
                      onPressed: () => _explain(context, ref, patient, latest),
                      minHeight: 52,
                    ),
                    const AppSpacing.vsm(),
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlinedButton(
                            label: 'Full report',
                            icon: const Icon(Icons.description_outlined,
                                size: 20),
                            onPressed: () =>
                                context.push('/history/${latest.id}'),
                            minHeight: 48,
                          ),
                        ),
                        const AppSpacing.hmd(),
                        Expanded(
                          child: AppOutlinedButton(
                            label: 'Share with doctor',
                            icon: const Icon(Icons.share_rounded, size: 20),
                            onPressed: () => _shareReport(
                                ref, patient, screenings ?? const [], latest),
                            minHeight: 48,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _vital(BuildContext context, String label, num value, String unit,
      IconData icon,
      {int digits = 0}) {
    final theme = Theme.of(context);
    final shown = value <= 0 ? null : value.toStringAsFixed(digits);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const AppSpacing.vxs(),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            maxLines: 1,
            text: TextSpan(
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              children: [
                TextSpan(text: shown ?? '—'),
                if (shown != null)
                  TextSpan(
                    text: ' $unit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  /// Rebuilds the screening draft from the stored row so the explanation
  /// screen scores the real recorded vitals — never a demo stand-in — and its
  /// cache lookup by screening id reuses anything already written.
  void _explain(BuildContext context, WidgetRef ref, Patient patient,
      Screening screening) {
    final draft = ref.read(screeningDraftProvider.notifier);
    draft.begin(
      patient: patient,
      device: Device(
        id: screening.deviceId,
        name: screening.deviceId,
        macAddress: '',
        batteryPercent: 0,
        isConnected: false,
        lastConnectedAt: screening.timestamp,
        isDemo: screening.isDemo,
      ),
    );
    draft.setSample(
      HealthSample(
        timestamp: screening.timestamp.millisecondsSinceEpoch,
        heartRateBpm: screening.heartRate,
        spo2Percent: screening.spo2,
        temperatureC: screening.temperature,
        ecgSignalQuality: screening.ecgQualityScore,
        rPeakDetected: screening.rrIntervalMs > 0,
        rrIntervalMs: screening.rrIntervalMs,
        pttMs: screening.pttMs,
        estimatedSystolic: screening.estimatedSystolic,
        estimatedDiastolic: screening.estimatedDiastolic,
        bpConfidence: screening.bpConfidence,
        batteryPercent: 100,
      ),
    );
    draft.setSymptoms(
      screening.symptoms,
      duration: screening.symptomDuration,
      notes: screening.symptomNotes,
    );
    draft.markSaved(screening.id);
    context.push('/screening/ai-explanation');
  }

  /// Two doorways the patient uses weekly: how their body has been trending,
  /// and what the environment/nearby hazards advise today.
  Widget _buildQuickLinks(BuildContext context, Patient patient) {
    return Row(
      children: [
        Expanded(
          child: AppOutlinedButton(
            label: 'My trends',
            icon: const Icon(Icons.show_chart_rounded, size: 22),
            onPressed: () =>
                context.push('/trends?patientId=${patient.id}'),
            minHeight: 52,
          ),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: AppOutlinedButton(
            label: 'Health guides',
            icon: const Icon(Icons.health_and_safety_outlined, size: 22),
            onPressed: () => context.push('/advisories'),
            minHeight: 52,
          ),
        ),
      ],
    );
  }

  /// The real-world loop closer: a summary the patient can show — or WhatsApp
  /// — to a doctor. Built from stored rows only; leaves the phone only
  /// through the OS share sheet under the user's finger.
  Future<void> _shareReport(WidgetRef ref, Patient patient,
      List<Screening> screenings, Screening latest) async {
    final account = ref.read(authStateProvider).account;
    if (account == null) return;
    final env = ref.read(environmentProvider).valueOrNull;
    final text = HealthReport.build(
      account: account,
      patient: patient,
      latest: latest,
      trendNotes: TrendEngine.notes(screenings),
      environment: env?.reading,
    );
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: 'Health summary — ${patient.name}',
    ));
  }

  // ───────────────────────────── Profile ─────────────────────────────

  Widget _buildProfileCard(BuildContext context, UserAccount account) {
    final theme = Theme.of(context);
    String? bmiText;
    final bmi = account.bmi;
    if (bmi != null) {
      bmiText = 'BMI ${bmi.toStringAsFixed(1)}';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      onTap: () => context.push('/register/patient'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  color: theme.colorScheme.primary, size: 22),
              const AppSpacing.hsm(),
              Expanded(
                child: Text('My profile',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.edit_outlined,
                  color: theme.colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              if (account.age != null)
                AppBadge(label: '${account.age} yrs'),
              if (account.sex.isNotEmpty)
                AppBadge(label: account.sex == 'F' ? 'Female' : account.sex == 'M' ? 'Male' : 'Other'),
              if (account.heightCm != null)
                AppBadge(label: '${account.heightCm!.toStringAsFixed(0)} cm'),
              if (account.weightKg != null)
                AppBadge(label: '${account.weightKg!.toStringAsFixed(1)} kg'),
              if (bmiText != null)
                AppBadge(label: bmiText, color: theme.colorScheme.primary),
              ...(account.conditions
                  .map((c) => AppBadge(
                      label: c, color: theme.colorScheme.secondary))),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── SOS ─────────────────────────────

  Widget _buildSosCard(BuildContext context, Patient patient) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      border: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.4), width: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sos_rounded, color: theme.colorScheme.error, size: 26),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Feeling seriously unwell?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            'Alerts your emergency contact and shows the fastest help steps.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const AppSpacing.vmd(),
          AppButton(
            label: 'Emergency SOS',
            icon: const Icon(Icons.sos_rounded, size: 24),
            onPressed: () =>
                context.push('/emergency/sos?patientId=${patient.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    final theme = Theme.of(context);
    return AppFilledCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: theme.colorScheme.onTertiaryContainer, size: 20),
          const AppSpacing.hmd(),
          Expanded(
            child: Text(
              'This app screens — it does not diagnose. Home-care suggestions '
              'apply only when your result is not serious; a red result means '
              'seek a nurse or doctor now.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileError(BuildContext context, WidgetRef ref) {
    return AppCenteredScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const AppSpacing.vlg(),
          const Text('Could not load your profile.'),
          const AppSpacing.vmd(),
          AppOutlinedButton(
            label: 'Try again',
            onPressed: () => ref.invalidate(myPatientProvider),
            isExpanded: false,
          ),
        ],
    ),
    );
  }

  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            context.push('/register/patient');
            break;
          case 'settings':
            context.push('/settings');
            break;
          case 'signout':
            await ref.read(authStateProvider.notifier).signOut();
            // No navigation: the redirect hears the state change.
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 20),
            SizedBox(width: 12),
            Text('Edit my profile'),
          ]),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_rounded, size: 20),
            SizedBox(width: 12),
            Text('Settings'),
          ]),
        ),
        PopupMenuItem(
          value: 'signout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 20),
            SizedBox(width: 12),
            Text('Sign out'),
          ]),
        ),
      ],
    );
  }
}
