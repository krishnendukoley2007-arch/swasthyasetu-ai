import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';

// Localization guard: top-level constants
const _kTitle = 'Overnight Guardian';
const _kStatusOptimal = 'Healthy Nocturnal Recovery';
const _kHrDipTitle = 'Nocturnal HR Dip';
const _kOdiTitle = 'Sleep SpO2 Stability (ODI)';
const _kEdrTitle = 'EDR Respiration Rate';
const _kDatasheetButton = 'Clinical Sensor Datasheet';
const _kStartSession = 'Start Overnight Monitoring';
const _kStopSession = 'Stop Monitoring Session';
const _kDisclaimer =
    'Screening & physiological trend advisor only. Does not replace clinical polysomnography (PSG) or diagnose sleep apnea. Consult a pulmonologist or cardiologist for chronic sleep disturbances.';
const _kDatasheetModalTitle =
    'Overnight Monitoring: Clinical Feasibility Datasheet';
const _kCloseLabel = 'Close Datasheet';
const _kDatasheetTooltip = 'Hardware Datasheet';
const _kRecoveryHeader = 'Nocturnal Vagal Recovery';
const _kBiomarkersHeader = 'Key Nocturnal Biomarkers';
const _kDutyCycleLabel = 'Duty Cycle';
const _kDutyCycleValue = '30s / 5m';
const _kProfileTitle = 'Continuous Nocturnal HR & SpO2 Trends';
const _kProfileDesc =
    'Drag your finger on the graph to inspect heart rate dipping and oxygenation at any hour.';
const _kEcgLiveTitle = 'Live Continuous ECG Tracing (Lead I)';
const _kEcgLiveSubtitle =
    '250 Hz Continuous Sweep · Adhesive Lead / Chest Strap Mode';
const _kLiveBadge = 'LIVE MONITORING';
const _kIdleBadge = 'STANDBY';
const _kTime11Pm = '11:00 PM';
const _kTime3Am = '03:00 AM';
const _kTime7Am = '07:00 AM';
const _kFeasibilityTitle = 'Continuous Nocturnal Feasibility Verified';
const _kFeasibilityBody =
    'Uses adhesive Ag/AgCl leads or chest strap for ECG. Finger PPG runs in 30-second duty cycles to conserve battery. Respiration is computed via EDR.';
const _kHrLegend = 'Heart Rate (BPM)';
const _kSpo2Legend = 'SpO2 Saturation (%)';
const _kHypoxiaAlertLabel = '90% Hypoxia Threshold';

class OvernightGuardianScreen extends ConsumerStatefulWidget {
  const OvernightGuardianScreen({super.key});

  @override
  ConsumerState<OvernightGuardianScreen> createState() =>
      _OvernightGuardianScreenState();
}

class _OvernightGuardianScreenState
    extends ConsumerState<OvernightGuardianScreen>
    with SingleTickerProviderStateMixin {
  bool _isMonitoring = true; // Active by default for immediate visualization
  late AnimationController _ecgSweepController;

  // Real-time simulated overnight vitals
  int _currentHr = 62;
  double _currentSpo2 = 98.2;
  final int _nocturnalDipPercent = 15; // Healthy is 10-20% dip
  final double _lowestSpo2 = 94.5;
  final int _respiratoryRate = 14;
  final double _odiScore = 1.8; // Events per hour (< 5 is normal)

  // Interactive scrubber state for Trend Graph
  double? _scrubNormalizedX;
  Timer? _vitalsTickTimer;

  // Real-time sweep buffer
  final List<double> _ecgWaveBuffer = List.filled(280, 0.0);
  int _sweepHead = 0;

  @override
  void initState() {
    super.initState();
    _ecgSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Pre-populate buffer with textbook clinical baseline so graph is immediately active
    final period = 60.0 / _currentHr;
    for (int i = 0; i < _ecgWaveBuffer.length; i++) {
      final sampleT = (i / _ecgWaveBuffer.length) * 3.2;
      final phase = (sampleT % period) / period;
      _ecgWaveBuffer[i] = _calculateClinicalEcg(phase);
    }
    // Erase initial gap ahead of 0
    for (int i = 1; i <= 14; i++) {
      _ecgWaveBuffer[i] = 0.0;
    }

    _ecgSweepController.addListener(_onSweepTick);

    // Subtle vitals fluctuation to make monitor feel organic and alive
    _vitalsTickTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_isMonitoring) return;
      setState(() {
        final rnd = math.Random();
        _currentHr = 60 + rnd.nextInt(5);
        _currentSpo2 = 97.5 + (rnd.nextDouble() * 1.5);
      });
    });
  }

  void _onSweepTick() {
    if (!_isMonitoring) return;
    final t = _ecgSweepController.value;
    final targetIdx = (t * (_ecgWaveBuffer.length - 1)).floor();
    if (targetIdx == _sweepHead) return;

    final period = 60.0 / _currentHr;
    final len = _ecgWaveBuffer.length;

    // Fill all intervening samples between _sweepHead and targetIdx so frame skips never drop samples
    int cur = (_sweepHead + 1) % len;
    while (cur != (targetIdx + 1) % len) {
      final sampleT = (cur / len) * 3.2;
      final phase = (sampleT % period) / period;
      _ecgWaveBuffer[cur] = _calculateClinicalEcg(phase);
      cur = (cur + 1) % len;
    }
    _sweepHead = targetIdx;

    // Erase 14 samples strictly ahead of the sweeping beam
    for (int i = 1; i <= 14; i++) {
      final clearIdx = (_sweepHead + i) % len;
      _ecgWaveBuffer[clearIdx] = 0.0;
    }
    setState(() {});
  }

  /// Calculates textbook clinical Lead I ECG waveform with realistic P-Q-R-S-T
  double _calculateClinicalEcg(double phase) {
    if (phase >= 0.10 && phase <= 0.22) {
      final x = (phase - 0.16) / 0.05;
      return 0.15 * math.exp(-x * x * 3.0); // P-wave
    } else if (phase >= 0.36 && phase <= 0.385) {
      final x = (phase - 0.375) / 0.012;
      return -0.15 * math.exp(-x * x * 4.0); // Q-dip
    } else if (phase >= 0.385 && phase <= 0.415) {
      final x = (phase - 0.40) / 0.010;
      return 1.18 * math.exp(-x * x * 3.8); // R-peak (+1.18 mV)
    } else if (phase >= 0.415 && phase <= 0.455) {
      final x = (phase - 0.43) / 0.014;
      return -0.32 * math.exp(-x * x * 4.0); // S-dip (-0.32 mV)
    } else if (phase >= 0.54 && phase <= 0.74) {
      final x = (phase - 0.64) / 0.08;
      return 0.28 * math.exp(-x * x * 2.2); // T-wave (+0.28 mV)
    }
    return 0.0; // Isoelectric baseline
  }

  @override
  void dispose() {
    _ecgSweepController.removeListener(_onSweepTick);
    _ecgSweepController.dispose();
    _vitalsTickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(_kTitle),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _kDatasheetTooltip,
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => _showDatasheetModal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Status HUD with Live Pulsing Beacon
            _buildHeroStatusCard(theme),
            const AppSpacing.vmd(),

            // ─── GRAPH 1: CONTINUOUS LIVE ECG WAVEFORM SWEEP ───
            _buildContinuousEcgCard(theme),
            const AppSpacing.vmd(),

            // ─── GRAPH 2: CONTINUOUS 8-HOUR DUAL HR & SPO2 TRENDS ───
            _buildContinuousTrendCard(theme),
            const AppSpacing.vmd(),

            // Nocturnal Biomarkers Summary Grid
            _buildMetricsGrid(theme),
            const AppSpacing.vmd(),

            // Feasibility Banner
            _buildFeasibilityBanner(theme),
            const AppSpacing.vmd(),

            // Action Buttons
            _buildActionControls(theme),
            const AppSpacing.vlg(),

            // Medical Disclaimer
            _buildDisclaimerCard(theme),
            const AppSpacing.vlg(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard(ThemeData theme) {
    final color = _nocturnalDipPercent >= 10
        ? ClinicalPalette.teal
        : ClinicalPalette.amber;

    return AppCard(
      color: color.withValues(alpha: 0.1),
      border: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.nightlight_round, color: color, size: 26),
              ),
              const AppSpacing.hmd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kRecoveryHeader,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _kStatusOptimal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _isMonitoring
                      ? ClinicalPalette.teal.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isMonitoring
                        ? ClinicalPalette.teal
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isMonitoring
                            ? ClinicalPalette.teal
                            : theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const AppSpacing.hxs(),
                    Text(
                      _isMonitoring ? _kLiveBadge : _kIdleBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _isMonitoring
                            ? ClinicalPalette.teal
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const AppSpacing.vsm(),
          Text(
            'Healthy nocturnal heart rate dip of $_nocturnalDipPercent% indicates restorative parasympathetic recovery and low cardiovascular risk.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// ─── GRAPH 1: Hospital-grade Continuous Live ECG Waveform Sweep ───
  Widget _buildContinuousEcgCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070C14), // Deep clinical navy-black
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: _isMonitoring
              ? ClinicalPalette.teal.withValues(alpha: 0.8)
              : const Color(0xFF334155),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top ECG Channel Telemetry Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: ClinicalPalette.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const AppSpacing.hsm(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _kEcgLiveTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _kEcgLiveSubtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Live Heartbeat Pulse Meter
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ClinicalPalette.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ClinicalPalette.teal.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: ClinicalPalette.teal,
                        size: 14,
                      ),
                      const AppSpacing.hxs(),
                      Text(
                        '$_currentHr BPM · ${_currentSpo2.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: ClinicalPalette.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 250 Hz Continuous ECG Sweep Canvas
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusLg),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                return SizedBox(
                  height: 145,
                  width: w,
                  child: CustomPaint(
                    size: Size(w, 145),
                    painter: _ContinuousEcgPainter(
                      waveBuffer: _ecgWaveBuffer,
                      sweepHead: _sweepHead,
                      isLive: _isMonitoring,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ─── GRAPH 2: Continuous 8-Hour Dual HR & SpO2 Trends ───
  Widget _buildContinuousTrendCard(ThemeData theme) {
    // Current scrubbed values
    final scrubX = _scrubNormalizedX ?? 0.52; // Default around 3 AM nadir
    final hourIndex = (scrubX * 47).round().clamp(0, 47);
    final scrubHour = 23 + (hourIndex * 10 / 60);
    final displayHour = (scrubHour % 24).floor();
    final displayMinute = ((hourIndex * 10) % 60);
    final timeFormatted =
        '${displayHour > 12 ? displayHour - 12 : (displayHour == 0 ? 12 : displayHour)}:${displayMinute.toString().padLeft(2, '0')} ${displayHour >= 12 && displayHour < 24 ? 'PM' : 'AM'}';

    // Interpolated vitals along the 8-hour curve
    final scrubHr = (72 - (15 * math.sin(scrubX * math.pi))).round();
    final scrubSpo2 = (98.5 - (1.2 * math.pow(math.sin(scrubX * math.pi), 2)))
        .toStringAsFixed(1);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  color: ClinicalPalette.cyan,
                  size: 24,
                ),
                const AppSpacing.hsm(),
                Expanded(
                  child: Text(
                    _kProfileTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const AppSpacing.vxs(),
            Text(
              _kProfileDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const AppSpacing.vsm(),

            // Graph Legends Row
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: ClinicalPalette.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const AppSpacing.hxs(),
                    Text(
                      _kHrLegend,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.teal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: ClinicalPalette.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const AppSpacing.hxs(),
                    Text(
                      _kSpo2Legend,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.cyan,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 2,
                      color: ClinicalPalette.amber,
                    ),
                    const AppSpacing.hxs(),
                    Text(
                      _kHypoxiaAlertLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.amber,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const AppSpacing.vsm(),

            // Scrubbed Readout Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ClinicalPalette.hairline(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14),
                      const AppSpacing.hxs(),
                      Text(
                        timeFormatted,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'HR: $scrubHr bpm',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ClinicalPalette.teal,
                        ),
                      ),
                      const AppSpacing.hmd(),
                      Text(
                        'SpO2: $scrubSpo2%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ClinicalPalette.cyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const AppSpacing.vsm(),

            // Interactive Trend Graph Canvas with LayoutBuilder for exact finite width
            LayoutBuilder(
              builder: (context, constraints) {
                final graphWidth = constraints.maxWidth;
                return GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _scrubNormalizedX =
                          (details.localPosition.dx / graphWidth).clamp(
                            0.0,
                            1.0,
                          );
                    });
                  },
                  onTapDown: (details) {
                    setState(() {
                      _scrubNormalizedX =
                          (details.localPosition.dx / graphWidth).clamp(
                            0.0,
                            1.0,
                          );
                    });
                  },
                  child: Container(
                    height: 175,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF070C14,
                      ), // Clinical midnight container
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ClinicalPalette.teal.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        size: Size(graphWidth, 175),
                        painter: _DualTrendGraphPainter(
                          scrubNormalizedX: scrubX,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const AppSpacing.vxs(),

            // Timeline Hours Axis
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _kTime11Pm,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _kTime3Am,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ClinicalPalette.teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _kTime7Am,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kBiomarkersHeader,
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
                  icon: Icons.trending_down_rounded,
                  label: _kHrDipTitle,
                  value: '$_nocturnalDipPercent% Dip',
                  subtext: 'Target: 10-20% (Normal Dipper)',
                  color: ClinicalPalette.teal,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.air_rounded,
                  label: _kOdiTitle,
                  value: '${_lowestSpo2.toStringAsFixed(1)}% min',
                  subtext: 'ODI: $_odiScore events/h (<5 Normal)',
                  color: ClinicalPalette.cyan,
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
                  icon: Icons.waves_rounded,
                  label: _kEdrTitle,
                  value: '$_respiratoryRate br/min',
                  subtext: 'ECG/PPG Amplitude Modulated',
                  color: theme.colorScheme.primary,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.battery_charging_full_rounded,
                  label: _kDutyCycleLabel,
                  value: _kDutyCycleValue,
                  subtext: '92% Battery Savings Over 8h',
                  color: ClinicalPalette.teal,
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

  Widget _buildFeasibilityBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: ClinicalPalette.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClinicalPalette.cyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: ClinicalPalette.cyan,
            size: 22,
          ),
          const AppSpacing.hsm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kFeasibilityTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ClinicalPalette.cyan,
                  ),
                ),
                const AppSpacing.vxs(),
                Text(
                  _kFeasibilityBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: _isMonitoring ? _kStopSession : _kStartSession,
          icon: Icon(
            _isMonitoring ? Icons.stop_circle_outlined : Icons.bedtime_outlined,
            size: 22,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isMonitoring
                ? ClinicalPalette.amber
                : theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isMonitoring = !_isMonitoring;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isMonitoring
                      ? 'Overnight Guardian activated: ECG & PPG streaming in Duty-Cycle mode.'
                      : 'Overnight Guardian session saved.',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          minHeight: 52,
        ),
        const AppSpacing.vmd(),
        AppOutlinedButton(
          label: _kDatasheetButton,
          icon: const Icon(Icons.menu_book_outlined, size: 20),
          onPressed: () => _showDatasheetModal(context),
          minHeight: 48,
        ),
      ],
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

  void _showDatasheetModal(BuildContext context) {
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
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                children: [
                  Text(
                    _kDatasheetModalTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const AppSpacing.vmd(),
                  _buildDatasheetRow(
                    theme,
                    sensor: '1. ECG (Heart Electrodes)',
                    handheldStatus:
                        'Unsuitable during sleep (Hands slip off plates)',
                    overnightSolution:
                        'Standard 3M Ag/AgCl adhesive snap leads or conductive elastic chest strap (Lead I).',
                    feasibility: 'FEASIBLE WITH STRAP / LEADS',
                    color: ClinicalPalette.teal,
                  ),
                  const AppSpacing.vmd(),
                  _buildDatasheetRow(
                    theme,
                    sensor: '2. Pulse Oximeter & HR (MAX30102 PPG)',
                    handheldStatus:
                        'Rigid plastic clip slips off; LEDs draw 40mA continuous.',
                    overnightSolution:
                        'Soft silicone finger cot + Epoch Duty Cycling: samples 30s every 5 min (92% power saving).',
                    feasibility: 'FEASIBLE WITH DUTY CYCLING',
                    color: ClinicalPalette.teal,
                  ),
                  const AppSpacing.vmd(),
                  _buildDatasheetRow(
                    theme,
                    sensor: '3. Respiration Rate Sensor',
                    handheldStatus:
                        'Nasal cannula or chest belt is cumbersome for sleep.',
                    overnightSolution:
                        'ECG-Derived Respiration (EDR) + Pulse Transit Time (PTT) modulation (Zero additional hardware).',
                    feasibility: '100% FEASIBLE VIA DSP',
                    color: ClinicalPalette.cyan,
                  ),
                  const AppSpacing.vmd(),
                  _buildDatasheetRow(
                    theme,
                    sensor: '4. Motion Artifact Rejection',
                    handheldStatus:
                        'Tossing & turning creates false arrhythmia flags.',
                    overnightSolution:
                        'On-device SQI gating: epochs with accelerometer motion > 0.3g are marked as movement artifact.',
                    feasibility: 'ROBUST ON-DEVICE SQI',
                    color: ClinicalPalette.teal,
                  ),
                  const AppSpacing.vlg(),
                  AppButton(
                    label: _kCloseLabel,
                    onPressed: () => Navigator.of(ctx).pop(),
                    minHeight: 48,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDatasheetRow(
    ThemeData theme, {
    required String sensor,
    required String handheldStatus,
    required String overnightSolution,
    required String feasibility,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClinicalPalette.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sensor,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  feasibility,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            'Dry Handheld limitation: $handheldStatus',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ClinicalPalette.amber,
              fontSize: 11,
            ),
          ),
          const AppSpacing.vxs(),
          Text(
            'Overnight Solution: $overnightSolution',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── REAL-TIME CLINICAL ECG WAVEFORM SWEEP PAINTER ───
class _ContinuousEcgPainter extends CustomPainter {
  final List<double> waveBuffer;
  final int sweepHead;
  final bool isLive;

  _ContinuousEcgPainter({
    required this.waveBuffer,
    required this.sweepHead,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw 5mm and 1mm Medical Grid Background
    final faintGrid = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    final majorGrid = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.55)
      ..strokeWidth = 0.8;

    const gridSize = 16.0;
    for (double x = 0; x < size.width; x += gridSize) {
      final isMajor = (x / gridSize).round() % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? majorGrid : faintGrid,
      );
    }
    for (double y = 0; y < size.height; y += gridSize) {
      final isMajor = (y / gridSize).round() % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? majorGrid : faintGrid,
      );
    }

    if (waveBuffer.isEmpty) return;

    final midY = size.height * 0.58;
    final scaleY = size.height * 0.38;
    final dx = size.width / (waveBuffer.length - 1);

    // 2. ECG Phosphorescent Waveform Path
    final ecgPaint = Paint()
      ..color = isLive ? const Color(0xFF10B981) : const Color(0xFF64748B)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool first = true;

    for (int i = 0; i < waveBuffer.length; i++) {
      final x = i * dx;
      final y = midY - (waveBuffer[i] * scaleY);

      // Skip the eraser gap ahead of the sweeping beam
      final gapAhead = (i - sweepHead + waveBuffer.length) % waveBuffer.length;
      if (gapAhead >= 1 && gapAhead <= 14) {
        first = true;
        continue;
      }

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow shadow for high-end monitor effect
    if (isLive) {
      final glowPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
        ..strokeWidth = 5.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawPath(path, glowPaint);
    }

    canvas.drawPath(path, ecgPaint);

    // 3. Sweeping Beam Head Bar
    if (isLive) {
      final headX = sweepHead * dx;
      final beamPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Color(0xFF34D399),
            Color(0xFF10B981),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(headX - 1, 0, 3, size.height))
        ..strokeWidth = 2.5;

      canvas.drawLine(Offset(headX, 0), Offset(headX, size.height), beamPaint);

      // Glowing dot at the exact current signal point
      final headY = midY - (waveBuffer[sweepHead] * scaleY);
      final dotPaint = Paint()..color = const Color(0xFF6EE7B7);
      canvas.drawCircle(Offset(headX, headY), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContinuousEcgPainter oldDelegate) => true;
}

/// ─── DUAL HR & SPO2 TREND GRAPH PAINTER ───
class _DualTrendGraphPainter extends CustomPainter {
  final double scrubNormalizedX;
  final ThemeData theme;

  _DualTrendGraphPainter({required this.scrubNormalizedX, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const totalPoints = 48; // Samples across 8 hours
    final dx = size.width / (totalPoints - 1);

    // 1. Shaded Nocturnal Dip Window (Deep sleep from 01:00 AM to 04:30 AM, ~25% to 68% of time)
    final nadirRect = Rect.fromLTRB(
      size.width * 0.25,
      0,
      size.width * 0.68,
      size.height,
    );
    final nadirPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.35);
    canvas.drawRect(nadirRect, nadirPaint);

    // 2. Grid & Scale Reference Lines
    final refLinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0;

    // Heart rate zone: 0 to height * 0.52
    // SpO2 zone: height * 0.52 to height
    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.52),
      refLinePaint,
    );

    // Subtle horizontal scale lines
    final faintLinePaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    canvas.drawLine(
      Offset(0, size.height * 0.14),
      Offset(size.width, size.height * 0.14),
      faintLinePaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.32),
      Offset(size.width, size.height * 0.32),
      faintLinePaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.74),
      Offset(size.width, size.height * 0.74),
      faintLinePaint,
    );

    // Dashed threshold line for 90% SpO2 (Hypoxia threshold)
    final dashedPaint = Paint()
      ..color = ClinicalPalette.amber.withValues(alpha: 0.8)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final hypoxiaY = size.height * 0.90;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, hypoxiaY),
        Offset(x + 4, hypoxiaY),
        dashedPaint,
      );
    }

    // 3. Build Heart Rate Path (Dipping Curve)
    final hrPath = Path();
    final hrGradientPath = Path();
    final hrPoints = <Offset>[];

    for (int i = 0; i < totalPoints; i++) {
      final nx = i / (totalPoints - 1);
      final x = i * dx;
      // Dipping curve: HR starts at 72, dips to 57 at 03:00 AM (nx ~ 0.5), rises back to 68
      final dip = 15.0 * math.sin(nx * math.pi);
      final noise = 1.2 * math.sin(i * 0.85);
      final hr = 72.0 - dip + noise; // 55 to 74 BPM

      // Map 50 BPM -> size.height * 0.48, 85 BPM -> size.height * 0.08
      final y =
          size.height * 0.48 - ((hr - 50.0) / 35.0) * (size.height * 0.40);
      hrPoints.add(Offset(x, y));

      if (i == 0) {
        hrPath.moveTo(x, y);
        hrGradientPath.moveTo(x, size.height * 0.52);
        hrGradientPath.lineTo(x, y);
      } else {
        hrPath.lineTo(x, y);
        hrGradientPath.lineTo(x, y);
      }
    }

    hrGradientPath.lineTo(size.width, size.height * 0.52);
    hrGradientPath.close();

    // Shaded Nocturnal Dip Gradient Fill
    final hrGradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ClinicalPalette.teal.withValues(alpha: 0.32),
          ClinicalPalette.teal.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.52));

    canvas.drawPath(hrGradientPath, hrGradientPaint);

    // Glow for HR trace
    final hrGlowPaint = Paint()
      ..color = ClinicalPalette.teal.withValues(alpha: 0.35)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(hrPath, hrGlowPaint);

    final hrStrokePaint = Paint()
      ..color = ClinicalPalette.teal
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(hrPath, hrStrokePaint);

    // 4. Build SpO2 Saturation Path
    final spo2Path = Path();
    final spo2Points = <Offset>[];

    for (int i = 0; i < totalPoints; i++) {
      final nx = i / (totalPoints - 1);
      final x = i * dx;
      // Steady 97.5% - 99.0% with slight dip at deep sleep
      final dip = 1.2 * math.pow(math.sin(nx * math.pi), 2);
      final noise = 0.35 * math.sin(i * 1.3);
      final spo2 = 98.6 - dip + noise;

      // Map 88% -> size.height * 0.95, 100% -> size.height * 0.58
      final y =
          size.height * 0.95 - ((spo2 - 88.0) / 12.0) * (size.height * 0.37);
      spo2Points.add(Offset(x, y));

      if (i == 0) {
        spo2Path.moveTo(x, y);
      } else {
        spo2Path.lineTo(x, y);
      }
    }

    // Glow for SpO2 trace
    final spo2GlowPaint = Paint()
      ..color = ClinicalPalette.cyan.withValues(alpha: 0.35)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(spo2Path, spo2GlowPaint);

    final spo2StrokePaint = Paint()
      ..color = ClinicalPalette.cyan
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(spo2Path, spo2StrokePaint);

    // 5. Interactive Vertical Scrubber Line & Crosshairs
    final scrubX = scrubNormalizedX * size.width;
    final scrubberPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.6;

    canvas.drawLine(
      Offset(scrubX, 0),
      Offset(scrubX, size.height),
      scrubberPaint,
    );

    // Find closest points for HR and SpO2 at scrub position
    final scrubIdx = (scrubNormalizedX * (totalPoints - 1)).round().clamp(
      0,
      totalPoints - 1,
    );
    final targetHrPoint = hrPoints[scrubIdx];
    final targetSpo2Point = spo2Points[scrubIdx];

    // Glowing anchor dot for HR
    final hrDotGlow = Paint()
      ..color = ClinicalPalette.teal.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(targetHrPoint, 7.0, hrDotGlow);
    canvas.drawCircle(targetHrPoint, 4.0, Paint()..color = Colors.white);

    // Glowing anchor dot for SpO2
    final spo2DotGlow = Paint()
      ..color = ClinicalPalette.cyan.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);
    canvas.drawCircle(targetSpo2Point, 7.0, spo2DotGlow);
    canvas.drawCircle(targetSpo2Point, 4.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DualTrendGraphPainter oldDelegate) =>
      oldDelegate.scrubNormalizedX != scrubNormalizedX;
}
