import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/pdf_clinical_report_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/device.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/domain/rules/health_report.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:swasthyasetu_ai/features/environment/widgets/environment_card.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/disaster_hazard_banner.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';

/// The patient's own home: connect the ESP32, run a self-check, understand
/// the result in plain words, reach help fast.
///
/// Deliberately not a trimmed copy of the clinician dashboard. The worker's
/// counts (today's screenings, sync queue) are meaningless to a person
/// checking their own pulse, so this screen is rebuilt around four questions
/// a patient actually asks: is my device on me, what did it say last time,
/// what does that mean for me, and who do I call if it goes wrong.
// Localization guard: top-level constants
const _kHeatGuardianTitle = 'Heat Guardian';
const _kHeatGuardianSubtitle = 'Moran PSI, heat stress & hydration timer';
const _kAirGuardianTitle = 'Air Guardian';
const _kAirGuardianSubtitle = 'NAQI smog, SpO₂ & breathing coach';
const _kOvernightGuardianTitle = 'Overnight Guardian';
const _kOvernightGuardianSubtitle = 'Sleep HR dipping & apnea screening';
const _kDisasterMeshBadge = 'Disaster BLE Mesh: Offline Relay Ready';
const _kContinuousClimateTitle = 'Continuous & Climate Guardians';
const _kPsiSafeBadge = 'PSI 3.2 · Normal';
const _kAqiLiveBadge = 'NAQI Sentinel';
const _kDualGraphsBadge = 'Dual Graphs Live';
const _kLiveSentinelBadge = 'AI Sentinel Active';

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
          context.l10n.patientHomeTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [_buildMenu(context, ref)],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/general-chat'),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: Text(context.l10n.aiChat),
        backgroundColor: theme.colorScheme.tertiaryContainer,
        foregroundColor: theme.colorScheme.onTertiaryContainer,
      ),
      body: patientAsync.when(
        // Skeletons mimic the page's real blocks, so first paint doesn't
        // flash a bare spinner mid-screen.
        loading: () => ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: const [
            ClinicalSkeleton(height: 26, width: 180),
            AppSpacing.vlg(),
            ClinicalSkeleton(height: 84, radius: 16),
            AppSpacing.vmd(),
            ClinicalSkeleton(height: 150, radius: 16),
            AppSpacing.vmd(),
            ClinicalSkeleton(height: 200, radius: 16),
          ],
        ),
        error: (_, __) => _buildProfileError(context, ref),
        data: (patient) {
          if (patient == null || account == null) {
            return _buildProfileError(context, ref);
          }
          final latestScreening = ref
              .watch(patientScreeningsProvider(patient.id))
              .valueOrNull
              ?.firstOrNull;

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
                const AppSpacing.vmd(),
                DisasterHazardBanner(
                  heartRateBpm: latestScreening?.heartRate,
                  temperatureC: latestScreening?.temperature,
                ),
                const AppSpacing.vlg(),
                // The single primary state of the whole app: is this patient
                // okay TODAY. Everything else on this page is secondary.
                _buildTodayCard(context, ref, patient),
                const AppSpacing.vlg(),
                _buildCommunityCard(context),
                const AppSpacing.vlg(),
                const EnvironmentCard(),
                const AppSpacing.vlg(),
                _buildGuardianModes(context),
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
        ? context.l10n.greetingMorning
        : hour < 17
        ? context.l10n.greetingAfternoon
        : context.l10n.greetingEvening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${account.firstName}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const AppSpacing.vxs(),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              context.l10n.patientHomeTagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ClinicalPalette.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ClinicalPalette.teal.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: ClinicalPalette.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _kLiveSentinelBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.teal,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────── Today's answer ───────────────────────────

  /// The home screen's one primary state: am I okay TODAY.
  ///
  /// Everything else on this page is history, settings, or navigation. This
  /// card answers the question a patient opens the app with, and offers the
  /// single action that answers it when nothing has been recorded yet.
  Widget _buildTodayCard(BuildContext context, WidgetRef ref, Patient patient) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final screenings = ref
        .watch(patientScreeningsProvider(patient.id))
        .valueOrNull;
    final now = DateTime.now();
    Screening? today;
    if (screenings != null) {
      for (final s in screenings) {
        final t = s.timestamp;
        if (t.year == now.year && t.month == now.month && t.day == now.day) {
          today = s;
          break;
        }
      }
    }

    if (today == null) {
      return AppElevatedCard(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.todayNoCheck,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const AppSpacing.vxs(),
            Text(
              l10n.todayNoCheckBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const AppSpacing.vmd(),
            AppButton(
              label: l10n.todayStartCheck,
              icon: const Icon(Icons.play_arrow_rounded),
              minHeight: 60,
              onPressed: () =>
                  _startSelfCheck(context, ref, patient, demo: false),
            ),
            Center(
              child: AppTextButton(
                label: l10n.screeningUseDemoDevice,
                onPressed: () =>
                    _startSelfCheck(context, ref, patient, demo: true),
              ),
            ),
          ],
        ),
      );
    }

    final style = RiskStyle.ofStorage(today.riskLevel, l10n);
    final band = RiskBand.fromStorage(today.riskLevel);
    final headline = switch (band) {
      RiskBand.green => l10n.todayOk,
      RiskBand.yellow => l10n.todayAttention,
      RiskBand.red => l10n.todayUrgent,
    };
    final icon = switch (band) {
      RiskBand.green => Icons.check_circle_rounded,
      RiskBand.yellow => Icons.warning_amber_rounded,
      RiskBand.red => Icons.emergency_rounded,
    };

    return AppElevatedCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      color: style.containerColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: style.color, size: 28),
              const AppSpacing.hsm(),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    headline,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: style.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            '${style.label} · ${relativeTime(today.timestamp)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),
          if (band == RiskBand.red)
            AppButton(
              label: l10n.triageSendSos,
              icon: const Icon(Icons.sos_rounded),
              minHeight: 60,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => context.push(
                '/emergency/sos?patientId=${patient.id}&screeningId=${today!.id}',
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.todayViewResult,
                    icon: const Icon(Icons.chevron_right_rounded),
                    minHeight: 56,
                    onPressed: () => context.push('/history/${today!.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Download PDF Report',
                  style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                  onPressed: () async {
                    await PdfClinicalReportService.exportAndShareReport(
                      patient: patient,
                      screening: today!,
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      onTap: () => context.push('/community-hotspot'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: Color(0xFF06B6D4),
                  size: 24,
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community Early-Warning Network',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Regional Heat, Hazard & Health Hotspots',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const AppSpacing.vmd(),
          Text(
            'Explore anonymized community health clusters, environmental heat waves, and localized air quality alerts in your district.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const AppSpacing.vmd(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: Color(0xFF10B981),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Zero Personal Data Leaves Device',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── Device / self-check ─────────────────────────────

  Widget _buildDeviceCard(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);
    final isLive = link.status == BleLinkStatus.streaming;
    final isBusy = switch (link.status) {
      BleLinkStatus.scanning ||
      BleLinkStatus.connecting ||
      BleLinkStatus.discovering ||
      BleLinkStatus.handshaking ||
      BleLinkStatus.reconnecting => true,
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
                  color:
                      (isLive
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
                          ? context.l10n.deviceConnecting
                          : context.l10n.deviceNotConnected,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      isLive
                          ? (link.batteryPercent != null
                                ? context.l10n.deviceReadyBattery(
                                    link.batteryPercent!,
                                  )
                                : context.l10n.deviceKeepNearby)
                          : isBusy
                          ? context.l10n.deviceKeepNearby
                          : context.l10n.deviceConnectHint,
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
            label: isLive
                ? context.l10n.startHealthCheck
                : context.l10n.connectMyDevice,
            icon: Icon(
              isLive
                  ? Icons.monitor_heart_rounded
                  : Icons.bluetooth_searching_rounded,
              size: 24,
            ),
            onPressed: isBusy
                ? null
                : () => isLive
                      ? _startSelfCheck(context, ref, patient, demo: false)
                      : context.go('/my-device'),
            minHeight: 56,
          ),
          if (!isLive) ...[
            const AppSpacing.vsm(),
            Center(
              child: AppTextButton(
                label: context.l10n.tryWithDemoData,
                onPressed: () =>
                    _startSelfCheck(context, ref, patient, demo: true),
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
    context.push('/screening/live');
  }

  // ───────────────────────────── Latest result ─────────────────────────────

  Widget _buildLatestResult(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
  ) {
    final theme = Theme.of(context);
    final screenings = ref
        .watch(patientScreeningsProvider(patient.id))
        .valueOrNull;
    final latest = (screenings == null || screenings.isEmpty)
        ? null
        : screenings.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: context.l10n.myLatestResult,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
        const AppSpacing.vsm(),
        AppCard(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: latest == null
              ? Column(
                  children: [
                    Icon(
                      Icons.monitor_heart_outlined,
                      size: 42,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const AppSpacing.vmd(),
                    Text(
                      context.l10n.noChecksYet,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const AppSpacing.vxs(),
                    Text(
                      context.l10n.noChecksYetBody,
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
                          child: _vital(
                            context,
                            context.l10n.vitalHeartRate,
                            latest.heartRate,
                            'bpm',
                            Icons.favorite_rounded,
                          ),
                        ),
                        Expanded(
                          child: _vital(
                            context,
                            context.l10n.vitalSpo2,
                            latest.spo2,
                            '%',
                            Icons.air_rounded,
                          ),
                        ),
                        Expanded(
                          child: _vital(
                            context,
                            context.l10n.vitalTemperature,
                            latest.temperature,
                            '°C',
                            Icons.thermostat_rounded,
                            digits: 1,
                          ),
                        ),
                      ],
                    ),
                    const AppSpacing.vlg(),
                    AppButton(
                      label: context.l10n.explainMeaning,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 22),
                      onPressed: () => _explain(context, ref, patient, latest),
                      minHeight: 52,
                    ),
                    const AppSpacing.vsm(),
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlinedButton(
                            label: context.l10n.fullReport,
                            icon: const Icon(
                              Icons.description_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                context.push('/history/${latest.id}'),
                            minHeight: 48,
                          ),
                        ),
                        const AppSpacing.hmd(),
                        Expanded(
                          child: AppOutlinedButton(
                            label: context.l10n.shareWithDoctor,
                            icon: const Icon(Icons.share_rounded, size: 20),
                            onPressed: () => _shareReport(
                              ref,
                              patient,
                              screenings ?? const [],
                              latest,
                            ),
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

  Widget _vital(
    BuildContext context,
    String label,
    num value,
    String unit,
    IconData icon, {
    int digits = 0,
  }) {
    final theme = Theme.of(context);
    final shown = value <= 0 ? null : value.toStringAsFixed(digits);
    final isHeart = icon == Icons.favorite_rounded;
    final iconColor = isHeart
        ? (theme.brightness == Brightness.dark
              ? AppTheme.cardiacCoralDark
              : AppTheme.cardiacCoral)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const AppSpacing.vxs(),
          RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
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

  /// Rebuilds the screening draft from the stored row so the explanation
  /// screen scores the real recorded vitals — never a demo stand-in — and its
  /// cache lookup by screening id reuses anything already written.
  void _explain(
    BuildContext context,
    WidgetRef ref,
    Patient patient,
    Screening screening,
  ) {
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
            label: context.l10n.myTrends,
            icon: const Icon(Icons.show_chart_rounded, size: 22),
            onPressed: () => context.push('/trends?patientId=${patient.id}'),
            minHeight: 52,
          ),
        ),
        const AppSpacing.hmd(),
        Expanded(
          child: AppOutlinedButton(
            label: context.l10n.healthGuides,
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
  Future<void> _shareReport(
    WidgetRef ref,
    Patient patient,
    List<Screening> screenings,
    Screening latest,
  ) async {
    try {
      await PdfClinicalReportService.exportAndShareReport(
        patient: patient,
        screening: latest,
      );
    } catch (_) {
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
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject:
              'Health summary — ${patient.name}', // share-sheet only, not UI copy
        ),
      );
    }
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
              Icon(
                Icons.person_outline_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  context.l10n.myProfile,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.edit_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
          const AppSpacing.vmd(),
          Wrap(
            spacing: AppTheme.spacingSm,
            runSpacing: AppTheme.spacingSm,
            children: [
              if (account.age != null) AppBadge(label: '${account.age} yrs'),
              if (account.sex.isNotEmpty)
                AppBadge(
                  label: account.sex == 'F'
                      ? context.l10n.sexFemale
                      : account.sex == 'M'
                      ? context.l10n.sexMale
                      : context.l10n.sexOther,
                ),
              if (account.heightCm != null)
                AppBadge(label: '${account.heightCm!.toStringAsFixed(0)} cm'),
              if (account.weightKg != null)
                AppBadge(label: '${account.weightKg!.toStringAsFixed(1)} kg'),
              if (bmiText != null)
                AppBadge(label: bmiText, color: theme.colorScheme.primary),
              ...(account.conditions.map(
                (c) => AppBadge(label: c, color: theme.colorScheme.secondary),
              )),
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
        color: theme.colorScheme.error.withValues(alpha: 0.4),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sos_rounded, color: theme.colorScheme.error, size: 26),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  context.l10n.feelingUnwell,
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
            context.l10n.sosExplainer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),
          AppButton(
            label: context.l10n.navSos,
            icon: const Icon(Icons.sos_rounded, size: 24),
            onPressed: () =>
                context.push('/emergency/sos?patientId=${patient.id}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              // SOS is the largest touch target on this screen, by design.
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          const AppSpacing.vsm(),
          Row(
            children: [
              Icon(
                Icons.cell_tower_rounded,
                size: 15,
                color: theme.colorScheme.error,
              ),
              const AppSpacing.hxs(),
              Expanded(
                child: Text(
                  _kDisasterMeshBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianModes(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _kContinuousClimateTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const AppSpacing.vmd(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Card 1: Heat Guardian
              SizedBox(
                width: 175,
                child: AppCard(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  onTap: () => context.push('/screening/heat-guardian'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8C00), Color(0xFFFF5722)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepOrange.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.wb_sunny_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _kPsiSafeBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.deepOrange,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const AppSpacing.vmd(),
                      Text(
                        _kHeatGuardianTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const AppSpacing.vxs(),
                      Text(
                        _kHeatGuardianSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Card 2: Air Pollution Guardian
              SizedBox(
                width: 175,
                child: AppCard(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  onTap: () =>
                      context.push('/screening/air-pollution-guardian'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00897B), Color(0xFF004D40)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.air_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _kAqiLiveBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.teal,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const AppSpacing.vmd(),
                      Text(
                        _kAirGuardianTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const AppSpacing.vxs(),
                      Text(
                        _kAirGuardianSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Card 3: Overnight Guardian
              SizedBox(
                width: 175,
                child: AppCard(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  onTap: () => context.push('/screening/overnight-guardian'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.indigo.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.nightlight_round,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _kDualGraphsBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.indigo,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const AppSpacing.vmd(),
                      Text(
                        _kOvernightGuardianTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const AppSpacing.vxs(),
                      Text(
                        _kOvernightGuardianSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    final theme = Theme.of(context);
    return AppFilledCard(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.onTertiaryContainer,
            size: 20,
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Text(
              context.l10n.patientHomeDisclaimer,
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
          Text(context.l10n.profileLoadError),
          const AppSpacing.vmd(),
          AppOutlinedButton(
            label: context.l10n.actionRetry,
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
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
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
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 20),
              const SizedBox(width: 12),
              Text(context.l10n.editMyProfile),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings_rounded, size: 20),
              const SizedBox(width: 12),
              Text(context.l10n.settingsTitle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 20),
              const SizedBox(width: 12),
              Text(context.l10n.signOut),
            ],
          ),
        ),
      ],
    );
  }
}
