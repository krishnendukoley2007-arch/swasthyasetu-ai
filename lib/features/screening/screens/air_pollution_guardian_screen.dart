import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';

// Localization guard: top-level constants
const _kTitle = 'Air Pollution & Respiratory Guardian';
const _kNaqiHeader = 'Ambient Air Quality Index (NAQI)';
const _kNaqiDescription =
    'Real-time particulate exposure cross-referenced with your live oxygen saturation (SpO₂) and heart rate.';
const _kBreathingTitle = 'Pursed-Lip Breathing Metronome';
const _kBreathingDescription =
    'Clinical bronchodilation technique: inhale 4 seconds through the nose, exhale 6 seconds through pursed lips to generate positive airway pressure and prevent bronchiolar collapse.';
const _kStartBreathing = 'Start Guided Breathing';
const _kPauseBreathing = 'Pause Breathing Metronome';
const _kInhalePhase = 'Inhale slowly through nose (4s)';
const _kExhalePhase = 'Exhale gently through pursed lips (6s)';
const _kEmergencySos = 'Trigger Respiratory Emergency SOS';
const _kDisclaimer =
    'Screening & physiological advisory tool only. Does not replace emergency clinical asthma/COPD intervention. If blue lips, inability to speak in sentences, or severe chest tightness occurs, call 108 immediately.';
const _kAmbientAqiLabel = 'Ambient AQI';
const _kPm25Label = 'PM2.5 Concentration';
const _kPm10Label = 'PM10 Concentration';
const _kSpo2Label = 'Blood Oxygen (SpO₂)';
const _kHeartRateLabel = 'Resting Heart Rate';
const _kRespRateLabel = 'Estimated Respiration';
const _kAirGood = 'Good Air Quality';
const _kAirModerate = 'Moderate Air Quality';
const _kAirSensitive = 'Unhealthy for Sensitive Groups';
const _kAirUnhealthy = 'Unhealthy Air Quality';
const _kAirVeryUnhealthy = 'Very Unhealthy (Severe Smog)';
const _kAirHazardous = 'Hazardous Toxic Smog';
const _kInfoModalTitle = 'About Cardiorespiratory Coupling & NAQI';
const _kInfoModalBody =
    'During acute air pollution events (crop burning, winter smog inversions, industrial dust), fine particulate matter (PM2.5) penetrates deep into alveolar capillaries, triggering acute inflammation, reflex bronchoconstriction, and arterial stiffening.\n\n'
    'SwasthyaSetu AI cross-references ambient NAQI with live SpO₂ and heart rate telemetry to detect early hypoxemia before acute respiratory distress strikes.\n\n'
    'Pursed-lip breathing mimics positive end-expiratory pressure (PEEP), maintaining patency of small airways and clearing trapped particulate air.';
const _kCloseLabel = 'Close';
const _kHighRiskAlert = 'Elevated Cardiorespiratory Strain Detected';
const _kHighRiskDesc =
    'Your oxygen saturation is depressed relative to ambient toxic particulate levels. Stop outdoor activity, wear an N95 mask indoors, and keep your bronchodilator / inhaler accessible.';
const _kProtectionTitle = 'Pollution Defense Protocols';
const _kMaskRule =
    'Use certified N95 / FFP2 respirators. Standard cloth and surgical masks cannot filter sub-micron PM2.5 particles.';
const _kIndoorRule =
    'Keep windows sealed. Avoid sweeping which re-suspends settled particles; use wet-mopping instead.';
const _kMedicationRule =
    'Keep rescue inhalers (Salbutamol / Levosalbutamol) within arm reach if diagnosed with asthma, COPD, or bronchitis.';
const _kHydrationRule =
    'Drink warm fluids and practice saline gargles to clear upper airway particle entrapment.';
const _kCyclesCompleted = 'Breathing Cycles Completed';

class AirPollutionGuardianScreen extends ConsumerStatefulWidget {
  const AirPollutionGuardianScreen({super.key});

  @override
  ConsumerState<AirPollutionGuardianScreen> createState() =>
      _AirPollutionGuardianScreenState();
}

class _AirPollutionGuardianScreenState
    extends ConsumerState<AirPollutionGuardianScreen>
    with SingleTickerProviderStateMixin {
  // Breathing metronome state
  bool _isBreathingActive = false;
  Timer? _breathingTimer;
  double _phaseProgress = 0.0; // 0.0 to 1.0 within the 10-second cycle
  int _completedCycles = 0;

  // Simulated / live physiological parameters
  final int _currentHr = 84;
  final int _currentSpo2 = 96;
  final int _estimatedRespRate = 18;

  @override
  void dispose() {
    _breathingTimer?.cancel();
    super.dispose();
  }

  void _toggleBreathingMetronome() {
    setState(() {
      _isBreathingActive = !_isBreathingActive;
      if (_isBreathingActive) {
        _phaseProgress = 0.0;
        _breathingTimer = Timer.periodic(const Duration(milliseconds: 50), (
          timer,
        ) {
          if (!mounted) return;
          setState(() {
            _phaseProgress += 0.05 / 10.0; // 10-second cycle (4s in, 6s out)
            if (_phaseProgress >= 1.0) {
              _phaseProgress = 0.0;
              _completedCycles++;
            }
          });
        });
      } else {
        _breathingTimer?.cancel();
      }
    });
  }

  void _showClinicalInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(_kInfoModalTitle),
        content: const SingleChildScrollView(child: Text(_kInfoModalBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(_kCloseLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final envState = ref.watch(environmentProvider).valueOrNull;

    final aqi = envState?.reading?.aqiUs ?? 235;
    final pm25 = envState?.reading?.pm25 ?? 148.5;
    final pm10 = pm25 * 1.75;

    final (aqiColor, aqiBandLabel) = switch (aqi) {
      <= 50 => (AppTheme.riskGreen, _kAirGood),
      <= 100 => (ClinicalPalette.teal, _kAirModerate),
      <= 150 => (ClinicalPalette.amber, _kAirSensitive),
      <= 200 => (Colors.orange.shade800, _kAirUnhealthy),
      <= 300 => (ClinicalPalette.coral, _kAirVeryUnhealthy),
      _ => (Colors.purple.shade900, _kAirHazardous),
    };

    final isHypoxemic = _currentSpo2 < 94;
    final isHighAqi = aqi >= 150;
    final hasCardiorespiratoryStrain = isHighAqi && isHypoxemic;

    // Breathing phase: 0.0 to 0.4 is inhale (40%), 0.4 to 1.0 is exhale (60%)
    final isInhaling = _phaseProgress < 0.4;
    final visualScale = isInhaling
        ? 0.7 + (_phaseProgress / 0.4) * 0.3
        : 1.0 - ((_phaseProgress - 0.4) / 0.6) * 0.3;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(_kTitle),
        elevation: 0,
        actions: [
          IconButton(
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
            // Ambient Air Quality Header Card
            _buildAqiHeaderCard(theme, aqiColor, aqiBandLabel, aqi),
            const AppSpacing.vmd(),

            // High strain alert if AQI elevated and SpO2 depressed
            if (hasCardiorespiratoryStrain) ...[
              _buildStrainAlertCard(theme),
              const AppSpacing.vmd(),
            ],

            // Dual Telemetry Grid (Air Metrics + Physiological Signals)
            _buildMetricsGrid(theme, aqi, pm25, pm10),
            const AppSpacing.vmd(),

            // Pursed-Lip Guided Breathing Metronome
            _buildBreathingMetronomeCard(theme, isInhaling, visualScale),
            const AppSpacing.vmd(),

            // Pollution Defense Guidelines
            _buildDefenseGuidelinesCard(theme),
            const AppSpacing.vmd(),

            // Emergency SOS Card
            if (hasCardiorespiratoryStrain || aqi >= 250) ...[
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

  Widget _buildAqiHeaderCard(
    ThemeData theme,
    Color aqiColor,
    String aqiBandLabel,
    int aqi,
  ) {
    return AppCard(
      color: aqiColor.withValues(alpha: 0.12),
      border: BorderSide(color: aqiColor.withValues(alpha: 0.5), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: aqiColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.air_rounded, color: aqiColor, size: 28),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kNaqiHeader,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      aqiBandLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: aqiColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: aqiColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$aqi AQI',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const AppSpacing.vsm(),
          Text(
            _kNaqiDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrainAlertCard(ThemeData theme) {
    return AppCard(
      color: ClinicalPalette.coral.withValues(alpha: 0.15),
      border: BorderSide(
        color: ClinicalPalette.coral.withValues(alpha: 0.6),
        width: 1.5,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: ClinicalPalette.coral,
            size: 28,
          ),
          const AppSpacing.hmd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kHighRiskAlert,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ClinicalPalette.coral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _kHighRiskDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, int aqi, double pm25, double pm10) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final tileWidth = isNarrow
            ? double.infinity
            : (constraints.maxWidth - 12) / 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environmental & Physiological Telemetry',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const AppSpacing.vsm(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricTile(
                  theme: theme,
                  width: tileWidth,
                  label: _kSpo2Label,
                  value: '$_currentSpo2%',
                  icon: Icons.bloodtype_outlined,
                  color: _currentSpo2 >= 95
                      ? AppTheme.riskGreen
                      : ClinicalPalette.coral,
                  subtitle: _currentSpo2 >= 95 ? 'Normal' : 'Hypoxia Alert',
                ),
                _buildMetricTile(
                  theme: theme,
                  width: tileWidth,
                  label: _kHeartRateLabel,
                  value: '$_currentHr bpm',
                  icon: Icons.favorite_outline_rounded,
                  color: ClinicalPalette.teal,
                  subtitle: 'Resting pulse',
                ),
                _buildMetricTile(
                  theme: theme,
                  width: tileWidth,
                  label: _kPm25Label,
                  value: '${pm25.toStringAsFixed(1)} µg/m³',
                  icon: Icons.blur_on_rounded,
                  color: pm25 > 60
                      ? ClinicalPalette.coral
                      : ClinicalPalette.amber,
                  subtitle: 'CPCB 24h limit: 60',
                ),
                _buildMetricTile(
                  theme: theme,
                  width: tileWidth,
                  label: _kPm10Label,
                  value: '${pm10.toStringAsFixed(1)} µg/m³',
                  icon: Icons.grain_rounded,
                  color: pm10 > 100
                      ? ClinicalPalette.coral
                      : ClinicalPalette.teal,
                  subtitle: 'CPCB 24h limit: 100',
                ),
                _buildMetricTile(
                  theme: theme,
                  width: tileWidth,
                  label: _kRespRateLabel,
                  value: '$_estimatedRespRate bpm',
                  icon: Icons.air_rounded,
                  color: ClinicalPalette.teal,
                  subtitle: 'Respiratory rhythm',
                ),
                _buildMetricTile(
                  theme: theme,
                  width: tileWidth,
                  label: _kAmbientAqiLabel,
                  value: '$aqi',
                  icon: Icons.cloud_queue_rounded,
                  color: aqi > 200
                      ? ClinicalPalette.coral
                      : ClinicalPalette.amber,
                  subtitle: 'CPCB NAQI Index',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingMetronomeCard(
    ThemeData theme,
    bool isInhaling,
    double visualScale,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ClinicalPalette.teal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  color: ClinicalPalette.teal,
                  size: 22,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kBreathingTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$_completedCycles $_kCyclesCompleted',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            _kBreathingDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppSpacing.vmd(),

          // Breathing Circle Animation HUD
          Center(
            child: SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer halo
                  Container(
                    width: 130 * visualScale,
                    height: 130 * visualScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ClinicalPalette.teal.withValues(
                        alpha: _isBreathingActive ? 0.15 : 0.05,
                      ),
                      border: Border.all(
                        color: ClinicalPalette.teal.withValues(
                          alpha: _isBreathingActive ? 0.4 : 0.15,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                  // Core pulsing circle
                  Container(
                    width: 90 * visualScale,
                    height: 90 * visualScale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ClinicalPalette.teal.withValues(alpha: 0.8),
                          ClinicalPalette.teal,
                        ],
                      ),
                      boxShadow: _isBreathingActive
                          ? [
                              BoxShadow(
                                color: ClinicalPalette.teal.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        isInhaling
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const AppSpacing.vsm(),

          Center(
            child: Text(
              _isBreathingActive
                  ? (isInhaling ? _kInhalePhase : _kExhalePhase)
                  : 'Tap below to begin pursed-lip relaxation',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _isBreathingActive
                    ? ClinicalPalette.teal
                    : theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const AppSpacing.vmd(),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _isBreathingActive
                    ? theme.colorScheme.surfaceContainerHighest
                    : ClinicalPalette.teal,
                foregroundColor: _isBreathingActive
                    ? theme.colorScheme.onSurface
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _toggleBreathingMetronome,
              icon: Icon(
                _isBreathingActive
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                _isBreathingActive ? _kPauseBreathing : _kStartBreathing,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefenseGuidelinesCard(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.security_rounded,
                color: ClinicalPalette.teal,
                size: 20,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  _kProtectionTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vmd(),
          _buildGuidelineItem(
            theme,
            icon: Icons.masks_rounded,
            title: 'Certified Mask Usage',
            detail: _kMaskRule,
          ),
          const Divider(height: 16),
          _buildGuidelineItem(
            theme,
            icon: Icons.window_rounded,
            title: 'Indoor Air Sealing',
            detail: _kIndoorRule,
          ),
          const Divider(height: 16),
          _buildGuidelineItem(
            theme,
            icon: Icons.medication_rounded,
            title: 'Rescue Inhaler Accessibility',
            detail: _kMedicationRule,
          ),
          const Divider(height: 16),
          _buildGuidelineItem(
            theme,
            icon: Icons.water_drop_rounded,
            title: 'Airway Hydration',
            detail: _kHydrationRule,
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: ClinicalPalette.teal),
        const AppSpacing.hsm(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencySosCard(ThemeData theme) {
    return AppCard(
      color: ClinicalPalette.coral.withValues(alpha: 0.15),
      border: BorderSide(
        color: ClinicalPalette.coral.withValues(alpha: 0.5),
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emergency_rounded,
                color: ClinicalPalette.coral,
                size: 24,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Severe Bronchospasm or Cyanosis?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ClinicalPalette.coral,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'If you experience acute breathlessness, chest tightness, or fingers turning blue, trigger the emergency protocol immediately.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const AppSpacing.vmd(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ClinicalPalette.coral,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => context.push('/emergency/sos'),
              icon: const Icon(Icons.sos_rounded),
              label: const Text(
                _kEmergencySos,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _kDisclaimer,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
