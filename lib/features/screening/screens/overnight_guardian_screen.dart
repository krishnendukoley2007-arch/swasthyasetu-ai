import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/overnight_report_exporter.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/theme/clinical_palette.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/rules/overnight_analysis_engine.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/dual_waveform_sweep_monitor.dart';

// Localization constants
const _kTitle = 'Overnight Guardian';
const _kRecoveryHeader = 'Nocturnal Vagal Recovery';
const _kBiomarkersHeader = 'Evaluated Nocturnal Biomarkers';
const _kDatasheetButton = 'Sensor Feasibility Datasheet';
const _kStartSession = 'Start Overnight Screening';
const _kStopSession = 'Stop & Run Clinical Analysis';
const _kDownloadPdf = 'Download Clinical Report (PDF)';
const _kExportCsv = 'Export Raw Data (CSV)';
const _kDisclaimer =
    'Screening & physiological trend advisor only. Does not replace clinical polysomnography (PSG) or diagnose sleep apnea. Consult a pulmonologist or cardiologist for chronic sleep disturbances.';
const _kDatasheetModalTitle =
    'Overnight Monitoring: Clinical Feasibility Datasheet';
const _kCloseLabel = 'Close Datasheet';
const _kDatasheetTooltip = 'Hardware Datasheet';
const _kProfileTitle = 'Continuous Nocturnal HR & SpO2 Trends';
const _kProfileDesc =
    'Drag across the timeline to inspect heart rate dipping, oxygenation, and detected anomalies.';

const _kLiveBadge = 'SCREENING ACTIVE';
const _kIdleBadge = 'STANDBY';
const _kHrLegend = 'Heart Rate (BPM)';
const _kSpo2Legend = 'SpO2 Saturation (%)';
const _kHypoxiaAlertLabel = '90% Hypoxia Threshold';
const _kModeDual = 'Dual (ECG + PPG)';
const _kModePpg = 'Pulse Oximeter (PPG)';
const _kModeEcg = 'Lead I ECG (250Hz)';

class OvernightGuardianScreen extends ConsumerStatefulWidget {
  const OvernightGuardianScreen({super.key});

  @override
  ConsumerState<OvernightGuardianScreen> createState() =>
      _OvernightGuardianScreenState();
}

class _OvernightGuardianScreenState
    extends ConsumerState<OvernightGuardianScreen> {
  // Session State
  bool _isScreening = false;
  DateTime? _sessionStartTime;
  DateTime? _lastRecordedPointTime;
  Duration _sessionElapsed = Duration.zero;
  Timer? _elapsedTimer;
  final List<OvernightDataPoint> _sessionPoints = [];
  OvernightSessionReport? _sessionReport;

  // Real-time sensor telemetry
  int? _liveHr;
  double? _liveSpo2;
  bool _leadOff = false;
  bool _fingerOff = false;
  bool _isExporting = false;

  // Hospital-grade live waveform channel mode
  // 0 = Split Dual Channel (ECG + PPG), 1 = Pulse Oximeter (PPG Pleth), 2 = Lead I ECG
  int _activeWaveformMode = 0;
  List<int>? _latestRawEcgSamples;

  // Stream Subscriptions
  StreamSubscription<TelemetryFrame>? _telemetrySub;
  StreamSubscription<EcgFrame>? _ecgSub;
  Timer? _demoFeedTimer;

  // Interactive scrubber state for Trend Graph
  double? _scrubNormalizedX;

  @override
  void initState() {
    super.initState();
    _connectHardwareStreams();
  }

  void _connectHardwareStreams() {
    final bleService = ref.read(bleServiceProvider);

    // Listen for live telemetry
    _telemetrySub = bleService.telemetry.listen((frame) {
      if (!mounted) return;
      final leadOff = frame.leadOff;
      final fingerOff = frame.fingerOff;

      setState(() {
        _leadOff = leadOff;
        _fingerOff = fingerOff;

        // Vitals can arrive from optical SpO2 sensor or AD8232 ECG
        final rawHr = frame.sample.heartRateBpm;
        final rawSpo2 = frame.sample.spo2Percent.toDouble();

        // Heart rate is valid from either optical sensor or ECG
        if (rawHr > 0 && (!leadOff || !fingerOff)) {
          _liveHr = rawHr;
        } else if (fingerOff && leadOff) {
          _liveHr = null;
        }

        // SpO2 is valid from optical pulse oximeter
        if (rawSpo2 > 0 && !fingerOff) {
          _liveSpo2 = rawSpo2;
        } else if (fingerOff) {
          _liveSpo2 = null;
        }
      });

      // Record point if screening is actively in progress (throttled to 2 Hz)
      if (_isScreening) {
        final now = DateTime.now();
        if (_lastRecordedPointTime == null ||
            now.difference(_lastRecordedPointTime!).inMilliseconds >= 500) {
          _lastRecordedPointTime = now;
          final hrVal = (!fingerOff && frame.sample.heartRateBpm > 0)
              ? frame.sample.heartRateBpm
              : (!leadOff && frame.sample.heartRateBpm > 0
                    ? frame.sample.heartRateBpm
                    : 0);
          final spo2Val = (!fingerOff && frame.sample.spo2Percent > 0)
              ? frame.sample.spo2Percent.toDouble()
              : 0.0;
          final point = OvernightDataPoint(
            timestamp: now,
            heartRate: hrVal,
            spo2: spo2Val,
            temperature: frame.sample.temperatureC,
            rrIntervalMs: frame.sample.rrIntervalMs,
            ecgQuality: frame.sample.ecgSignalQuality,
            leadOff: leadOff,
            fingerOff: fingerOff,
            isDemo: false,
          );
          _sessionPoints.add(point);
        }
      }
    });

    // Listen for live 250 Hz ECG chunks
    _ecgSub = bleService.ecg.listen((frame) {
      if (!mounted) return;
      setState(() {
        _latestRawEcgSamples = frame.samples;
      });
    });
  }

  void _toggleScreening(bool isLiveBoard) {
    if (_isScreening) {
      // STOP SCREENING AND RUN ANALYSIS
      _elapsedTimer?.cancel();
      _demoFeedTimer?.cancel();
      ref.read(bleServiceProvider).endCapture();
      ref
          .read(bleServiceProvider)
          .setMode(0, durationSec: 0); // Put hardware in standby

      // Analyze recorded session
      final report = OvernightAnalysisEngine.analyze(
        _sessionPoints,
        baselineDaytimeHr: 72,
      );

      setState(() {
        _isScreening = false;
        _sessionReport = report;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Overnight screening complete: ${report.events.length} clinical issues detected across ${report.totalDuration.inMinutes} minutes.',
          ),
          backgroundColor: ClinicalPalette.teal,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      // START SCREENING
      setState(() {
        _isScreening = true;
        _sessionStartTime = DateTime.now();
        _sessionElapsed = Duration.zero;
        _sessionPoints.clear();
        _sessionReport = null;
      });

      // Continuous Dual Mode (mode 4: ECG + SpO2, duration 0 = infinite continuous streaming)
      ref.read(bleServiceProvider).beginCapture(mode: 4, durationSec: 0);

      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isScreening) return;
        setState(() {
          _sessionElapsed = DateTime.now().difference(_sessionStartTime!);
        });
      });

      // If no live hardware is paired, feed simulated demo points with isDemo: true
      if (!isLiveBoard) {
        _startDemoFeed();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLiveBoard
                ? 'Overnight Guardian activated: streaming live from SSAI-SENSE hardware.'
                : 'Demo overnight screening started. Simulated data flagged with isDemo: true.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _startDemoFeed() {
    _demoFeedTimer?.cancel();
    int secondCounter = 0;
    _demoFeedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isScreening) {
        timer.cancel();
        return;
      }
      secondCounter++;
      final rnd = math.Random();

      // Simulate a gradual nocturnal dip (starts at 74, dips to 60)
      final phase = (secondCounter % 120) / 120.0;
      final dip = 14.0 * math.sin(phase * math.pi);
      final simHr = (74.0 - dip + rnd.nextInt(3)).round();

      // Transient desaturation at second 45-55
      final isDesat = (secondCounter % 60) >= 42 && (secondCounter % 60) <= 52;
      final simSpo2 = isDesat
          ? (88.5 + rnd.nextDouble())
          : (98.0 + (rnd.nextDouble() * 1.2));

      setState(() {
        _leadOff = false;
        _fingerOff = false;
        _liveHr = simHr;
        _liveSpo2 = double.parse(simSpo2.toStringAsFixed(1));
        _latestRawEcgSamples = _generateSyntheticEcgChunk(simHr);
      });

      _sessionPoints.add(
        OvernightDataPoint(
          timestamp: DateTime.now(),
          heartRate: simHr,
          spo2: simSpo2,
          temperature: 36.5,
          rrIntervalMs: (60000 / simHr).round(),
          ecgQuality: 0.95,
          leadOff: false,
          fingerOff: false,
          isDemo: true,
        ),
      );
    });
  }

  List<int> _generateSyntheticEcgChunk(int heartRate) {
    const rate = 250;
    final beatPeriod = 60.0 / heartRate;
    final samples = List<int>.filled(rate, 2048);
    for (var i = 0; i < rate; i++) {
      final phase = (i / rate) % beatPeriod;
      var mv = 0.0;
      mv += 0.12 * math.exp(-0.5 * math.pow((phase - 0.200) / 0.022, 2)); // P
      mv += -0.05 * math.exp(-0.5 * math.pow((phase - 0.362) / 0.008, 2)); // Q
      mv += 1.00 * math.exp(-0.5 * math.pow((phase - 0.400) / 0.010, 2)); // R
      mv += -0.18 * math.exp(-0.5 * math.pow((phase - 0.438) / 0.009, 2)); // S
      mv += 0.25 * math.exp(-0.5 * math.pow((phase - 0.600) / 0.045, 2)); // T
      samples[i] = (mv * 500 + 2048).round().clamp(0, 4095);
    }
    return samples;
  }

  Future<void> _exportPdfReport() async {
    if (_sessionReport == null) return;
    setState(() => _isExporting = true);
    try {
      await OvernightReportExporter.exportAndSharePdf(
        _sessionReport!,
        patientName: 'Ayushman Beneficiary',
        facilityName: 'Primary Health Centre (PHC) Sub-Centre',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated and ready to share')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsvData() async {
    if (_sessionReport == null) return;
    setState(() => _isExporting = true);
    try {
      await OvernightReportExporter.exportAndShareCsv(_sessionReport!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Raw CSV data exported and ready to share'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _ecgSub?.cancel();
    _elapsedTimer?.cancel();
    _demoFeedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = ref.watch(bleLinkProvider);
    final isLiveBoard = link.isLive;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(_kTitle),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _kDatasheetTooltip,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => _showDatasheetModal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── HARDWARE / DEMO PROVENANCE BANNER ───
            _buildHardwareStatusBanner(theme, link, isLiveBoard),
            const AppSpacing.vmd(),

            // ─── HERO STATUS CARD ───
            _buildHeroStatusCard(theme),
            const AppSpacing.vmd(),

            // ─── DUAL SENSOR CONTACT GATING HUD ───
            _buildSensorContactGatingHud(theme),
            const AppSpacing.vmd(),

            // ─── GRAPH 1: REAL-TIME DUAL-WAVEFORM MONITOR (ECG + PLETH PPG) ───
            _buildLiveWaveformMonitor(theme, isLiveBoard),
            const AppSpacing.vmd(),

            // ─── GRAPH 2: CONTINUOUS DUAL HR & SPO2 TRENDS WITH ANOMALY SCANNER ───
            _buildContinuousTrendCard(theme),
            const AppSpacing.vmd(),

            // ─── FLAGGED CLINICAL ISSUES & ANOMALIES CARD ───
            if (_sessionReport != null &&
                _sessionReport!.events.isNotEmpty) ...[
              _buildFlaggedIssuesCard(theme),
              const AppSpacing.vmd(),
            ],

            // ─── NOCTURNAL BIOMARKERS SUMMARY GRID ───
            _buildMetricsGrid(theme),
            const AppSpacing.vmd(),

            // ─── ACTION CONTROLS (START SCREENING / STOP & EXPORT) ───
            _buildActionControls(theme, isLiveBoard),
            const AppSpacing.vlg(),

            // ─── MEDICAL DISCLAIMER ───
            _buildDisclaimerCard(theme),
            const AppSpacing.vlg(),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareStatusBanner(
    ThemeData theme,
    BleLinkState link,
    bool isLiveBoard,
  ) {
    if (isLiveBoard) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ClinicalPalette.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: ClinicalPalette.teal.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bluetooth_connected_rounded,
              color: ClinicalPalette.teal,
              size: 20,
            ),
            const AppSpacing.hsm(),
            Expanded(
              child: Text(
                'Hardware Linked: ${link.deviceName ?? "SSAI-SENSE"} · Live Telemetry & 250 Hz ECG',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ClinicalPalette.teal,
                ),
              ),
            ),
            if (link.batteryPercent != null)
              Text(
                '${link.batteryPercent}% 🔋',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ClinicalPalette.teal,
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ClinicalPalette.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: ClinicalPalette.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: ClinicalPalette.amber,
            size: 20,
          ),
          const AppSpacing.hsm(),
          Expanded(
            child: Text(
              'DEMO MODE: Hardware Not Connected. Live screening simulates 250Hz signals flagged with isDemo: true.',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: ClinicalPalette.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatusCard(ThemeData theme) {
    final report = _sessionReport;
    final dip = report?.nocturnalDipPercent ?? 0.0;
    final isGood = dip >= 10.0;
    final color = report == null
        ? theme.colorScheme.primary
        : (isGood ? ClinicalPalette.teal : ClinicalPalette.amber);

    final statusText = report == null
        ? (_isScreening
              ? 'Screening In Progress...'
              : 'Standby — Ready to Monitor')
        : report.sleepRecoveryVerdict;

    return AppTactileCard(
      enableTilt: true,
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
                      statusText,
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
                  color: _isScreening
                      ? ClinicalPalette.teal.withValues(alpha: 0.15)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isScreening
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
                        color: _isScreening
                            ? ClinicalPalette.teal
                            : theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const AppSpacing.hxs(),
                    Text(
                      _isScreening ? _kLiveBadge : _kIdleBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _isScreening
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
          if (_isScreening)
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: ClinicalPalette.teal,
                ),
                const AppSpacing.hxs(),
                Expanded(
                  child: Text(
                    'Elapsed: ${_formatDuration(_sessionElapsed)} · Captured: ${_sessionPoints.length} points',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ClinicalPalette.teal,
                    ),
                  ),
                ),
              ],
            )
          else if (report != null)
            Text(
              report.triageRecommendation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            )
          else
            Text(
              'Attach the sensor strap or touch electrodes, then tap "Start Overnight Screening" below to evaluate nocturnal autonomic recovery and sleep apnea risk.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// ─── Multi-Sensor Touch / Contact Detection HUD ───
  Widget _buildSensorContactGatingHud(ThemeData theme) {
    final ecgContactOk = !_leadOff;
    final spo2ContactOk = !_fingerOff;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              const Icon(Icons.touch_app_rounded, size: 16),
              const AppSpacing.hxs(),
              Expanded(
                child: Text(
                  'Sensor Skin Contact Gating',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ecgContactOk
                      ? ClinicalPalette.teal
                      : ClinicalPalette.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const AppSpacing.hxs(),
              Expanded(
                child: Text(
                  ecgContactOk
                      ? 'ECG Electrodes: TOUCHING'
                      : 'ECG Leads: OFF CONTACT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ecgContactOk
                        ? ClinicalPalette.teal
                        : ClinicalPalette.amber,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: spo2ContactOk
                      ? ClinicalPalette.cyan
                      : ClinicalPalette.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const AppSpacing.hxs(),
              Expanded(
                child: Text(
                  spo2ContactOk
                      ? 'Optical PPG: TOUCHING'
                      : 'SpO2 Sensor: OFF CONTACT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: spo2ContactOk
                        ? ClinicalPalette.cyan
                        : ClinicalPalette.amber,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ─── GRAPH 1: Hospital-grade Dual-Waveform Monitor (ECG + Plethysmograph PPG) ───
  Widget _buildLiveWaveformMonitor(ThemeData theme, bool isLiveBoard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Waveform Channel Selector Tabs
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              _buildChannelPill(
                channelName: _kModeDual,
                mode: 0,
                icon: Icons.splitscreen_rounded,
                theme: theme,
              ),
              const AppSpacing.hxs(),
              _buildChannelPill(
                channelName: _kModePpg,
                mode: 1,
                icon: Icons.air_rounded,
                theme: theme,
              ),
              const AppSpacing.hxs(),
              _buildChannelPill(
                channelName: _kModeEcg,
                mode: 2,
                icon: Icons.monitor_heart_outlined,
                theme: theme,
              ),
            ],
          ),
        ),

        // Live Medical Dual Waveform Monitor
        DualWaveformSweepMonitor(
          heartRate: (_liveHr ?? 0).toDouble(),
          spo2: (_liveSpo2 ?? 0).toDouble(),
          isLive: isLiveBoard && _isScreening,
          activeMode: _activeWaveformMode,
          leadOff: _leadOff,
          fingerOff: _fingerOff,
          rawEcgSamples: _latestRawEcgSamples,
          beatDetected: _liveHr != null && _liveHr! > 0,
          showControls: true,
        ),
      ],
    );
  }

  Widget _buildChannelPill({
    required String channelName,
    required int mode,
    required IconData icon,
    required ThemeData theme,
  }) {
    final isSelected = _activeWaveformMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeWaveformMode = mode;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? ClinicalPalette.teal.withValues(alpha: 0.18)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? ClinicalPalette.teal
                  : ClinicalPalette.hairline(context),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? ClinicalPalette.teal
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  channelName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? ClinicalPalette.teal
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ─── GRAPH 2: Continuous Real Dual HR & SpO2 Trends With Anomaly Markers ───
  Widget _buildContinuousTrendCard(ThemeData theme) {
    final points = _sessionReport?.timeSeries ?? _sessionPoints;
    final events = _sessionReport?.events ?? const [];

    final hasData = points.isNotEmpty;

    // Interactive scrub calculation
    final scrubX = _scrubNormalizedX ?? 0.5;
    final scrubIdx = hasData
        ? (scrubX * (points.length - 1)).round().clamp(0, points.length - 1)
        : 0;

    final scrubPoint = hasData ? points[scrubIdx] : null;
    final timeFormatted = scrubPoint != null
        ? DateFormat('hh:mm a').format(scrubPoint.timestamp)
        : '—';

    final scrubHr = scrubPoint != null && scrubPoint.heartRate > 0
        ? '${scrubPoint.heartRate} bpm'
        : '—';
    final scrubSpo2 = scrubPoint != null && scrubPoint.spo2 > 0
        ? '${scrubPoint.spo2.toStringAsFixed(1)}%'
        : '—';

    return AppTactileCard(
      enableTilt: false,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth - (AppTheme.spacingMd * 2);
          return Padding(
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
                    _buildLegendItem(
                      ClinicalPalette.teal,
                      _kHrLegend,
                      maxW,
                      theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.teal,
                        fontSize: 10,
                      ),
                    ),
                    _buildLegendItem(
                      ClinicalPalette.cyan,
                      _kSpo2Legend,
                      maxW,
                      theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.cyan,
                        fontSize: 10,
                      ),
                    ),
                    _buildLegendItem(
                      ClinicalPalette.amber,
                      _kHypoxiaAlertLabel,
                      maxW,
                      theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: ClinicalPalette.amber,
                        fontSize: 10,
                      ),
                      isLine: true,
                    ),
                    if (events.isNotEmpty)
                      _buildLegendItem(
                        ClinicalPalette.coral,
                        'Issues (${events.length})',
                        maxW,
                        theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ClinicalPalette.coral,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const AppSpacing.vsm(),

                // Scrubbed Readout Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ClinicalPalette.hairline(context),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                      Text(
                        'HR: $scrubHr',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ClinicalPalette.teal,
                        ),
                      ),
                      Text(
                        'SpO2: $scrubSpo2',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: ClinicalPalette.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                const AppSpacing.vsm(),

                // Interactive Trend Graph Canvas
                LayoutBuilder(
                  builder: (context, constraints) {
                    final graphWidth = constraints.maxWidth;
                    if (!hasData) {
                      return Container(
                        constraints: const BoxConstraints(minHeight: 140),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF070C14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF334155),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.show_chart_rounded,
                                  color: Color(0xFF64748B),
                                  size: 28,
                                ),
                                const AppSpacing.vxs(),
                                Text(
                                  'No Overnight Recording Captured Yet',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const AppSpacing.vxs(),
                                Text(
                                  'Tap "Start Overnight Screening" below to begin recording real sensor trends.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

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
                          color: const Color(0xFF070C14),
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
                            painter: _RealDualTrendGraphPainter(
                              points: points,
                              events: events,
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
                if (hasData)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('hh:mm a').format(points.first.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Mid-session Nadir',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ClinicalPalette.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(points.last.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String text,
    double maxW,
    TextStyle? style, {
    bool isLine = false,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isLine ? 12 : 8,
            height: isLine ? 2 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: isLine ? BoxShape.rectangle : BoxShape.circle,
            ),
          ),
          const AppSpacing.hxs(),
          Flexible(child: Text(text, style: style)),
        ],
      ),
    );
  }

  /// ─── FLAGGED CLINICAL ISSUES CARD ───
  Widget _buildFlaggedIssuesCard(ThemeData theme) {
    final events = _sessionReport!.events;

    return AppTactileCard(
      enableTilt: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: ClinicalPalette.amber,
                size: 22,
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: Text(
                  'Detected Clinical Issues (${events.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const AppSpacing.vxs(),
          Text(
            'Physiological anomalies flagged during full-night automated scanning:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const AppSpacing.vsm(),
          ...events.take(6).map((e) {
            final timeStr = DateFormat('hh:mm:ss a').format(e.timestamp);
            final color = e.severity == 'critical'
                ? ClinicalPalette.coral
                : (e.severity == 'warning'
                      ? ClinicalPalette.amber
                      : ClinicalPalette.teal);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    e.severity == 'critical'
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color: color,
                    size: 18,
                  ),
                  const AppSpacing.hsm(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.title,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                            const AppSpacing.hxs(),
                            Text(
                              timeStr,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const AppSpacing.vxs(),
                        Text(
                          e.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
    final report = _sessionReport;

    final dipValue = report != null
        ? '${report.nocturnalDipPercent.toStringAsFixed(1)}% Dip'
        : '—';
    final dipSub = report != null
        ? report.nocturnalDipCategory
        : 'Target: 10-20% (Normal Dipper)';

    final odiValue = report != null
        ? '${report.lowestSpo2.toStringAsFixed(1)}% min'
        : '—';
    final odiSub = report != null
        ? 'ODI: ${report.odiScore.toStringAsFixed(1)}/h (${report.odiSeverity})'
        : 'Target: <5.0 events/h';

    final hrvValue = report != null ? 'SDNN: ${report.sdnn} ms' : '—';
    final hrvSub = report != null
        ? 'RMSSD: ${report.rmssd} ms · Respiration: ${report.respiratoryRate}/min'
        : 'Autonomic Vagal Modulation';

    return AppTactileCard(
      enableTilt: false,
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
                  label: 'Nocturnal HR Dip',
                  value: dipValue,
                  subtext: dipSub,
                  color: ClinicalPalette.teal,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.air_rounded,
                  label: 'Sleep SpO2 & Apnea (ODI)',
                  value: odiValue,
                  subtext: odiSub,
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
                  icon: Icons.favorite_border_rounded,
                  label: 'Autonomic HRV & EDR',
                  value: hrvValue,
                  subtext: hrvSub,
                  color: theme.colorScheme.primary,
                ),
              ),
              const AppSpacing.hsm(),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.timer_outlined,
                  label: 'Monitored Duration',
                  value: report != null
                      ? (report.totalDuration.inMinutes > 0
                            ? '${report.totalDuration.inMinutes} min'
                            : '${report.totalDuration.inSeconds} sec')
                      : (_isScreening ? _formatDuration(_sessionElapsed) : '—'),
                  subtext: report != null
                      ? (report.validContactDuration.inMinutes > 0
                            ? 'Valid Contact: ${report.validContactDuration.inMinutes} min'
                            : 'Valid Contact: ${report.validContactDuration.inSeconds} sec')
                      : 'Duty-cycled BLE streaming',
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

  Widget _buildActionControls(ThemeData theme, bool isLiveBoard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Start/Stop Screening Button
        AppButton(
          label: _isScreening ? _kStopSession : _kStartSession,
          icon: Icon(
            _isScreening
                ? Icons.stop_circle_outlined
                : Icons.play_circle_fill_rounded,
            size: 22,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isScreening
                ? ClinicalPalette.amber
                : theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _toggleScreening(isLiveBoard),
          minHeight: 52,
        ),

        // Download and Export Buttons (Surfaced when a report has been generated)
        if (_sessionReport != null) ...[
          const AppSpacing.vmd(),
          AppButton(
            label: _isExporting ? 'Generating Report...' : _kDownloadPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: ClinicalPalette.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: _isExporting ? null : _exportPdfReport,
            minHeight: 48,
          ),
          const AppSpacing.vsm(),
          AppOutlinedButton(
            label: _isExporting ? 'Exporting...' : _kExportCsv,
            icon: const Icon(Icons.file_download_outlined, size: 20),
            onPressed: _isExporting ? null : _exportCsvData,
            minHeight: 46,
          ),
        ],

        const AppSpacing.vmd(),
        AppOutlinedButton(
          label: _kDatasheetButton,
          icon: const Icon(Icons.menu_book_outlined, size: 20),
          onPressed: () => _showDatasheetModal(context),
          minHeight: 46,
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

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// ─── REAL DUAL HR & SPO2 TREND GRAPH PAINTER ───
class _RealDualTrendGraphPainter extends CustomPainter {
  final List<OvernightDataPoint> points;
  final List<OvernightIssueEvent> events;
  final double scrubNormalizedX;
  final ThemeData theme;

  _RealDualTrendGraphPainter({
    required this.points,
    required this.events,
    required this.scrubNormalizedX,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || points.isEmpty) return;
    final totalPoints = points.length;
    final dx = totalPoints > 1 ? size.width / (totalPoints - 1) : size.width;

    // 1. Shaded Deep sleep Nadir Window
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

    // 3. Plot Real Heart Rate Path
    final hrPath = Path();
    final hrGradientPath = Path();
    final hrPoints = <Offset>[];

    for (int i = 0; i < totalPoints; i++) {
      final x = i * dx;
      final hr = points[i].heartRate > 0 ? points[i].heartRate : 65;

      // Map 40 BPM -> size.height * 0.48, 120 BPM -> size.height * 0.08
      final y =
          size.height * 0.48 -
          ((hr - 40.0) / 80.0).clamp(0.0, 1.0) * (size.height * 0.40);
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

    final hrStrokePaint = Paint()
      ..color = ClinicalPalette.teal
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(hrPath, hrStrokePaint);

    // 4. Plot Real SpO2 Saturation Path
    final spo2Path = Path();
    final spo2Points = <Offset>[];

    for (int i = 0; i < totalPoints; i++) {
      final x = i * dx;
      final spo2 = points[i].spo2 > 0 ? points[i].spo2 : 98.0;

      // Map 80% -> size.height * 0.96, 100% -> size.height * 0.58
      final y =
          size.height * 0.96 -
          ((spo2 - 80.0) / 20.0).clamp(0.0, 1.0) * (size.height * 0.38);
      spo2Points.add(Offset(x, y));

      if (i == 0) {
        spo2Path.moveTo(x, y);
      } else {
        spo2Path.lineTo(x, y);
      }
    }

    final spo2StrokePaint = Paint()
      ..color = ClinicalPalette.cyan
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(spo2Path, spo2StrokePaint);

    // 5. Draw Detected Event Markers along the timeline
    if (events.isNotEmpty && totalPoints > 1) {
      final sessionStart = points.first.timestamp;
      final sessionDurationMs = points.last.timestamp
          .difference(sessionStart)
          .inMilliseconds;

      for (final event in events) {
        final eventOffsetMs = event.timestamp
            .difference(sessionStart)
            .inMilliseconds;
        final eventNormX = sessionDurationMs > 0
            ? (eventOffsetMs / sessionDurationMs).clamp(0.0, 1.0)
            : 0.5;
        final eventX = eventNormX * size.width;

        final isCrit = event.severity == 'critical';
        final markerColor = isCrit
            ? ClinicalPalette.coral
            : ClinicalPalette.amber;

        // Vertical indicator line
        final markerLinePaint = Paint()
          ..color = markerColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(eventX, 4),
          Offset(eventX, size.height - 4),
          markerLinePaint,
        );

        // Marker dot
        final dotPaint = Paint()..color = markerColor;
        canvas.drawCircle(Offset(eventX, 8), 4.0, dotPaint);
      }
    }

    // 6. Interactive Vertical Scrubber Line & Crosshairs
    final scrubX = scrubNormalizedX * size.width;
    final scrubberPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.6;

    canvas.drawLine(
      Offset(scrubX, 0),
      Offset(scrubX, size.height),
      scrubberPaint,
    );

    final scrubIdx = (scrubNormalizedX * (totalPoints - 1)).round().clamp(
      0,
      totalPoints - 1,
    );
    final targetHrPoint = hrPoints[scrubIdx];
    final targetSpo2Point = spo2Points[scrubIdx];

    // Anchors
    canvas.drawCircle(
      targetHrPoint,
      4.0,
      Paint()..color = ClinicalPalette.teal,
    );
    canvas.drawCircle(
      targetSpo2Point,
      4.0,
      Paint()..color = ClinicalPalette.cyan,
    );
  }

  @override
  bool shouldRepaint(covariant _RealDualTrendGraphPainter oldDelegate) => true;
}
