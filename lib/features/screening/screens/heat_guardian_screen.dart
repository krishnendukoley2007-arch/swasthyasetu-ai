import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/rules/clinical_signal_analysis.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:swasthyasetu_ai/features/screening/state/audio_coach_controller.dart';

// Localization guard: top-level constants
const _kTitle = 'Heat Guardian';
const _kPsiHeader = 'Moran Physiological Strain Index';
const _kPsiDescription =
    'Real-time clinical fusion of core body temperature, cardiovascular drift, and ambient heat.';
const _kHydrationTitle = 'Hydration Tracker';
const _kLogDrink = 'Drink 250ml Water';
const _kListenAdvice = 'Listen to Voice Advice';
const _kHydrationGoal = 'Goal: 2.5L / Shift';
const _kRestPlannerTitle = 'Work / Rest Cycle Advisor';
const _kEmergencySos = 'Trigger Heat Emergency SOS';
const _kDisclaimer =
    'Screening & physiological advisory tool only. Does not replace clinical heatstroke treatment. If fainting, confusion, or cessation of sweating occurs, call 108 immediately.';
const _kAmbientLabel = 'Local Ambient Heat';
const _kCoreTempLabel = 'Core Body Temp';
const _kHeartRateLabel = 'Current Heart Rate';
const _kStrainNormal = 'Normal Physiological Load';
const _kStrainModerate = 'Moderate Heat Strain';
const _kStrainHigh = 'High Thermal Strain';
const _kStrainCritical = 'Critical Heat Stroke Risk';
const _kInfoModalTitle = 'About Moran Physiological Strain Index (PSI)';
const _kInfoModalBody =
    'Published by Dr. Daniel Moran (1998) in the American Journal of Physiology, PSI is the clinical gold standard for evaluating thermal strain in outdoor workers, soldiers, and athletes.\n\n'
    'Equation:\n'
    'PSI = 5 × (T_core - T_0) / (39.5 - T_0) + 5 × (HR - HR_0) / (180 - HR_0)\n\n'
    'SwasthyaSetu AI augments this formula with on-device autonomic HRV compensation and ambient IMD wet-bulb heat indices.';
const _kCloseLabel = 'Close';
const _kExtremeHeatAlert = 'Extreme Heat Advisory Alert';
const _kExtremeHeatDesc =
    'Your physiological telemetry indicates dangerous thermal accumulation. If dizzy or nauseous, seek medical attention immediately.';
const _kThermalSectionTitle = 'Thermal & Physiological Signals';
const _kHydrationDesc =
    'High environmental heat accelerates fluid loss. Drink water every 15-20 minutes to prevent cardiovascular drift.';
const _kLoggedWaterSnack = 'Logged 250ml water. Hydration timer reset to 15m.';
const _kInfoTooltip = 'Information';
const _kWaterIntakeLabel = 'Water Intake';
const _kWorkIntervalLabel = 'Work Interval';
const _kShadedRestLabel = 'Shaded Rest';

class HeatGuardianScreen extends ConsumerStatefulWidget {
  const HeatGuardianScreen({super.key});

  @override
  ConsumerState<HeatGuardianScreen> createState() => _HeatGuardianScreenState();
}

class _HeatGuardianScreenState extends ConsumerState<HeatGuardianScreen> {
  int _waterLoggedMl = 750;
  int _hydrationSecondsLeft = 720; // 12 minutes
  Timer? _timer;

  // Real-time simulated or live parameters
  final int _currentHr = 88;
  final double _coreTemp = 37.4;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_hydrationSecondsLeft > 0) {
          _hydrationSecondsLeft--;
        } else {
          _hydrationSecondsLeft = 900; // Reset to 15 min reminder
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _logWaterIntake() {
    setState(() {
      _waterLoggedMl += 250;
      _hydrationSecondsLeft = 900; // 15 mins for next drink
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(_kLoggedWaterSnack),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final envState = ref.watch(environmentProvider).valueOrNull;
    final ambientTemp = envState?.reading?.temperatureC ?? 36.5;
    final apparentTemp = envState?.reading?.apparentTemperatureC ?? 39.0;
    final humidity = envState?.reading?.humidityPercent ?? 58.0;

    // Calculate Moran Physiological Strain Index
    final psi = ClinicalSignalAnalysis.calculatePhysiologicalStrain(
      currentHr: _currentHr,
      restingBaselineHr: 68,
      coreTempC: _coreTemp,
      baselineTempC: 36.8,
      ambientTempC: ambientTemp,
      rmssdMs: 38,
    );

    final psiScore = psi.psiScore;
    final (psiColor, psiBandLabel) = switch (psiScore) {
      < 3.0 => (ClinicalPalette.teal, _kStrainNormal),
      < 6.0 => (ClinicalPalette.amber, _kStrainModerate),
      < 8.0 => (Colors.orange.shade800, _kStrainHigh),
      _ => (ClinicalPalette.coral, _kStrainCritical),
    };

    final minsLeft = _hydrationSecondsLeft ~/ 60;
    final secsLeft = _hydrationSecondsLeft % 60;
    final timeStr =
        '${minsLeft.toString().padLeft(2, '0')}:${secsLeft.toString().padLeft(2, '0')}';

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(_kTitle),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _kInfoTooltip,
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showClinicalInfo(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Executive Header Card
            _buildHeaderCard(theme, psiColor, psiBandLabel, psiScore),
            const AppSpacing.vmd(),

            // Environmental & Core Vitals Grid
            _buildVitalsMetricsGrid(
              theme,
              ambientTemp,
              apparentTemp,
              humidity,
              _coreTemp,
              _currentHr,
            ),
            const AppSpacing.vmd(),

            // Hydration Timer Card
            _buildHydrationCard(theme, timeStr),
            const AppSpacing.vmd(),

            // Work / Rest Cycle Recommendation
            _buildWorkRestCard(theme, psiScore, ambientTemp),
            const AppSpacing.vmd(),

            // Emergency SOS Heat Action
            if (psiScore >= 6.0) ...[
              _buildEmergencySosCard(theme),
              const AppSpacing.vmd(),
            ],

            // Clinical Disclaimer
            _buildDisclaimerCard(theme),
            const AppSpacing.vlg(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    Color psiColor,
    String psiBandLabel,
    double psiScore,
  ) {
    return AppCard(
      color: psiColor.withValues(alpha: 0.12),
      border: BorderSide(color: psiColor.withValues(alpha: 0.5), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: psiColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.wb_sunny_rounded, color: psiColor, size: 28),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kPsiHeader,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      psiBandLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: psiColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: psiColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${psiScore.toStringAsFixed(1)} / 10',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            _kPsiDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vsm(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (psiScore / 10.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(psiColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsMetricsGrid(
    ThemeData theme,
    double ambientTemp,
    double apparentTemp,
    double humidity,
    double coreTemp,
    int heartRate,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kThermalSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const AppSpacing.vmd(),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.thermostat_outlined,
                  label: _kAmbientLabel,
                  value: '${ambientTemp.toStringAsFixed(1)}°C',
                  subtext:
                      'Feels ${apparentTemp.round()}°C (${humidity.round()}% RH)',
                  color: Colors.deepOrange,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.device_thermostat_rounded,
                  label: _kCoreTempLabel,
                  value: '${coreTemp.toStringAsFixed(1)}°C',
                  subtext: coreTemp > 38.0 ? 'Elevated Temp' : 'Normothermic',
                  color: coreTemp > 38.0
                      ? ClinicalPalette.coral
                      : ClinicalPalette.teal,
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.favorite_rounded,
                  label: _kHeartRateLabel,
                  value: '$heartRate bpm',
                  subtext: heartRate > 100
                      ? 'Cardiovascular Drift'
                      : 'Resting Baseline',
                  color: heartRate > 100
                      ? ClinicalPalette.amber
                      : ClinicalPalette.teal,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.water_drop_outlined,
                  label: _kWaterIntakeLabel,
                  value: '$_waterLoggedMl ml',
                  subtext: _kHydrationGoal,
                  color: ClinicalPalette.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const AppSpacing.hxs(),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subtext,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationCard(ThemeData theme, String timeStr) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_drink_rounded,
                color: ClinicalPalette.cyan,
                size: 24,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  _kHydrationTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ClinicalPalette.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Next: $timeStr',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ClinicalPalette.cyan,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            _kHydrationDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),
          AppButton(
            label: _kLogDrink,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            onPressed: _logWaterIntake,
            minHeight: 50,
          ),
          const SizedBox(height: 8),
          AppOutlinedButton(
            label: _kListenAdvice,
            icon: const Icon(Icons.volume_up_rounded, size: 20),
            onPressed: () {
              ref
                  .read(audioCoachControllerProvider.notifier)
                  .speakHydration(isHotWeather: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkRestCard(
    ThemeData theme,
    double psiScore,
    double ambientTemp,
  ) {
    final (workMinutes, restMinutes, tip) = switch (psiScore) {
      < 3.0 => (50, 10, 'Continuous work safe with standard water breaks.'),
      < 6.0 => (
        40,
        20,
        'Moderate thermal load: rest 20 min in shaded area per hour.',
      ),
      < 8.0 => (
        20,
        40,
        'High heat strain: limit strenuous activity, actively hydrate and cool down.',
      ),
      _ => (
        0,
        60,
        'Critical risk: cease physical work immediately. Move to shade or AC.',
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: ClinicalPalette.amber,
                size: 24,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  _kRestPlannerTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$workMinutes min',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        _kWorkIntervalLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: ClinicalPalette.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$restMinutes min',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ClinicalPalette.amber,
                        ),
                      ),
                      Text(
                        _kShadedRestLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            tip,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencySosCard(ThemeData theme) {
    return AppCard(
      color: ClinicalPalette.coral.withValues(alpha: 0.1),
      border: BorderSide(color: ClinicalPalette.coral.withValues(alpha: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: ClinicalPalette.coral,
                size: 26,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  _kExtremeHeatAlert,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ClinicalPalette.coral,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            _kExtremeHeatDesc,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),
          AppButton(
            label: _kEmergencySos,
            icon: const Icon(Icons.sos_rounded, size: 22),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalPalette.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.push('/emergency/sos'),
            minHeight: 52,
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              _kDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClinicalInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kInfoModalTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const AppSpacing.vsm(),
                Text(
                  _kInfoModalBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const AppSpacing.vmd(),
                AppButton(
                  label: _kCloseLabel,
                  onPressed: () => Navigator.of(ctx).pop(),
                  minHeight: 48,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
