import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/rules/clinical_signal_analysis.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vitals_estimator.dart';
import 'package:swasthyasetu_ai/domain/simulator/clinical_scenario.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/dual_waveform_sweep_monitor.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/screening_exit_button.dart';

const _simTitle = 'Virtual Patient Simulator';
const _simSubtitle = 'Select a clinical scenario for zero-hardware testing:';
const _demoBadge = 'DEMO';
const _rawMorphologyLabel = 'RAW 250 Hz MORPHOLOGY';
const _sensorDetachedTitle = 'Body Temp Sensor Detached / Offline';
const _sensorDetachedDesc =
    'Infrared temperature sensor detached. Reconnect when replaced.';
const _pausedEcgTouch =
    'Timer paused: Hold all 3 electrode terminals with firm skin contact';
const _pausedPpgTouch =
    'Timer paused: Rest fingertip firmly on MAX30102 optical sensor';

/// Clinical Mutually Exclusive Screening Screen.
///
/// Features:
/// - Real 250 Hz Lead I ECG Oscilloscope from hardware BLE stream
/// - Real MAX30102 Arterial PPG Plethysmograph with finger contact detection
/// - Morphological analysis: QRS duration, Bazett QTc, PR interval, SQI
/// - Dual-Source Heart Rate Consensus (Electrical ECG vs Optical PPG)
/// - AI / ML Rhythm Classification & Physiological Strain Index
/// - Mutually exclusive hardware sensor isolation matching ESP32 firmware v3
class MutuallyExclusiveScreeningScreen extends ConsumerStatefulWidget {
  const MutuallyExclusiveScreeningScreen({super.key});

  @override
  ConsumerState<MutuallyExclusiveScreeningScreen> createState() =>
      _MutuallyExclusiveScreeningScreenState();
}

class _MutuallyExclusiveScreeningScreenState
    extends ConsumerState<MutuallyExclusiveScreeningScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  bool _demoMode = false;
  ClinicalScenario _selectedScenario = ClinicalScenario.defaultScenario;

  int _activeMode = 0; // 0 = Idle, 1 = SpO2, 2 = ECG, 3 = Temp
  bool _isMeasuring = false;
  int _secondsRemaining = 30;
  Timer? _measurementTimer;

  // Final captured values
  int? _finalHr;
  int? _finalSpo2;
  double? _finalTemp;
  List<int> _finalEcg = [];
  int? _finalRr;
  double? _finalEcgQuality;

  // Live sensor streams
  int _liveHr = 0;
  int _liveSpo2 = 0;
  double _liveTemp = 0.0;
  int _ecgHr = 0;
  int _ppgHr = 0;

  bool _leadOff = true;
  bool _fingerOff = true;
  bool _beatDetected = false;
  bool _spo2Stabilized = false;
  bool _ppgLowSignal = false;

  final List<int> _rrHistory = [];
  final List<int> _ecgHrHistory = [];
  final List<int> _ppgHrHistory = [];
  List<int> _ecgBuffer = [];

  SignalMorphology _morphology = SignalMorphology.empty;
  AiRhythmVerdict _aiVerdict = AiRhythmVerdict.gathering;
  PhysiologicalStrain _strain = PhysiologicalStrain.initial;
  final int _restingBaselineHr = 72;

  StreamSubscription? _telemetrySub;
  StreamSubscription? _ecgSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = ref.read(bleServiceProvider);

      // Listen to 20-byte wire telemetry frames
      _telemetrySub = bleService.telemetry.listen((frame) {
        if (!mounted || !_isMeasuring) return;
        setState(() {
          final s = frame.sample;
          _leadOff = frame.leadOff;
          _fingerOff = frame.fingerOff;
          _beatDetected = s.rPeakDetected;
          _spo2Stabilized = frame.spo2Stabilized;
          _ppgLowSignal = frame.ppgLowSignal;

          if (_activeMode == 2) {
            // ECG mode: AD8232 electrical rate
            if (frame.leadOff) {
              _ecgBuffer.clear();
              _morphology = SignalMorphology.empty;
              _liveHr = 0;
            } else if (s.heartRateBpm > 0) {
              _ecgHr = s.heartRateBpm;
              _liveHr = s.heartRateBpm;
              _ecgHrHistory.add(_ecgHr);
              if (_ecgHrHistory.length > 60) _ecgHrHistory.removeAt(0);
            }
          } else if (_activeMode == 1) {
            // SpO2 mode: MAX30102 arterial optical pulse rate
            if (!frame.fingerOff && s.heartRateBpm > 0 && s.spo2Percent >= 70) {
              _ppgHr = s.heartRateBpm;
              _liveHr = s.heartRateBpm;
              _ppgHrHistory.add(_ppgHr);
              if (_ppgHrHistory.length > 60) _ppgHrHistory.removeAt(0);
              _liveSpo2 = s.spo2Percent;
            } else if (frame.fingerOff) {
              _liveSpo2 = 0;
              _liveHr = 0;
            }
          } else if (_activeMode == 3) {
            if (s.temperatureC > 0) _liveTemp = s.temperatureC;
          }

          if (s.rrIntervalMs >= 300 && s.rrIntervalMs <= 2500) {
            _finalRr = s.rrIntervalMs;
            _rrHistory.add(s.rrIntervalMs);
            if (_rrHistory.length > 60) _rrHistory.removeAt(0);
          }
          if (s.ecgSignalQuality > 0) _finalEcgQuality = s.ecgSignalQuality;

          // Compute AI rhythm verdict and physiological strain live
          if (_rrHistory.length >= 4) {
            _aiVerdict = ClinicalSignalAnalysis.classifyRhythm(
              rrIntervals: _rrHistory,
              ecgHeartRates: _ecgHrHistory,
              ppgPulseRates: _ppgHrHistory,
            );
            _strain = ClinicalSignalAnalysis.calculatePhysiologicalStrain(
              currentHr: _liveHr > 0 ? _liveHr : _restingBaselineHr,
              restingBaselineHr: _restingBaselineHr,
              rmssdMs: _aiVerdict.rmssd,
            );
          }
        });
      });

      // Listen to 250 Hz Lead I ECG waveform frames
      _ecgSub = bleService.ecg.listen((frame) {
        if (!mounted || !_isMeasuring || _activeMode != 2) return;
        setState(() {
          if (_leadOff) {
            _ecgBuffer.clear();
            _morphology = SignalMorphology.empty;
            return;
          }
          _ecgBuffer.addAll(frame.samples);
          if (_ecgBuffer.length > 250 * 5) {
            _ecgBuffer = _ecgBuffer.sublist(_ecgBuffer.length - 250 * 5);
          }
          _morphology = ClinicalSignalAnalysis.analyzeRawWaveform(
            _ecgBuffer,
            currentRrMs: _finalRr,
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _measurementTimer?.cancel();
    _telemetrySub?.cancel();
    _ecgSub?.cancel();
    super.dispose();
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

  void _openScenarioSelector() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXl),
        ),
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.science_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const AppSpacing.hsm(),
                      Text(
                        _simTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingLg,
                    vertical: 4,
                  ),
                  child: Text(
                    _simSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: ClinicalScenario.all.length,
                    itemBuilder: (context, index) {
                      final scenario = ClinicalScenario.all[index];
                      final isSelected = scenario.id == _selectedScenario.id;
                      final bandColor = switch (scenario.expectedBand) {
                        RiskBand.red => AppTheme.riskRed,
                        RiskBand.yellow => AppTheme.riskYellow,
                        RiskBand.green => AppTheme.riskGreen,
                      };

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bandColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.medical_information_rounded,
                            color: bandColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          scenario.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${scenario.subtitle}\n${scenario.description}',
                        ),
                        isThreeLine: true,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: bandColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  scenario.expectedBand.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: bandColor,
                                  ),
                                ),
                              ),
                        onTap: () {
                          setState(() {
                            _selectedScenario = scenario;
                            _demoMode = true;
                          });
                          Navigator.of(bottomSheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Switched to scenario: ${scenario.name}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startMeasurement(int mode) {
    final isLive = ref.read(bleLinkProvider).isLive;
    final random = math.Random();

    setState(() {
      _activeMode = mode;
      _isMeasuring = true;
      _secondsRemaining = (mode == 3) ? 5 : 30;
      if (mode == 2) _ecgBuffer.clear();

      if (!isLive) {
        if (mode == 1) {
          _liveHr = _selectedScenario.heartRateBpm;
          _liveSpo2 = _selectedScenario.spo2Percent;
        } else if (mode == 2) {
          _finalEcgQuality = _selectedScenario.ecgQuality;
          _finalRr = _selectedScenario.isArrhythmia
              ? 650
              : (60000 / _selectedScenario.heartRateBpm).round();
        } else if (mode == 3) {
          _liveTemp = _selectedScenario.temperatureC;
        }
      }
    });

    if (isLive) {
      final bleService = ref.read(bleServiceProvider);
      bleService.beginCapture(mode: mode, durationSec: _secondsRemaining);
    }

    _measurementTimer?.cancel();
    _measurementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        // Contact-Gated Timer: Only decrement when electrodes / finger make actual skin contact
        final isContactActive =
            !isLive ||
            (_activeMode == 2 && !_leadOff && _ecgBuffer.isNotEmpty) ||
            (_activeMode == 1 && !_fingerOff && _liveHr > 0) ||
            (_activeMode == 3);

        if (isContactActive) {
          _secondsRemaining--;
        }

        if (!isLive) {
          if (_activeMode == 1) {
            _liveHr = (_selectedScenario.heartRateBpm + random.nextInt(5) - 2)
                .clamp(40, 200);
            _liveSpo2 = (_selectedScenario.spo2Percent + random.nextInt(3) - 1)
                .clamp(70, 100);
          } else if (_activeMode == 2) {
            if (_demoMode) {
              _ecgBuffer.addAll(
                _generateSyntheticEcgChunk(_selectedScenario.heartRateBpm),
              );
              if (_ecgBuffer.length > 250 * 5) {
                _ecgBuffer = _ecgBuffer.sublist(_ecgBuffer.length - 250 * 5);
              }
            } else {
              _ecgBuffer.clear();
            }
          } else if (_activeMode == 3) {
            _liveTemp =
                _selectedScenario.temperatureC +
                (random.nextDouble() - 0.5) * 0.2;
          }
        }

        if (_secondsRemaining <= 0) {
          _stopMeasurement();
        }
      });
    });
  }

  void _stopMeasurement() {
    _measurementTimer?.cancel();
    final isLive = ref.read(bleLinkProvider).isLive;
    if (isLive) {
      final bleService = ref.read(bleServiceProvider);
      bleService.setMode(0, durationSec: 0); // Return to IDLE
    }

    setState(() {
      _isMeasuring = false;
      if (_activeMode == 1) {
        _finalHr = _liveHr > 0 ? _liveHr : _selectedScenario.heartRateBpm;
        _finalSpo2 = _liveSpo2 > 0 ? _liveSpo2 : _selectedScenario.spo2Percent;
      } else if (_activeMode == 2) {
        if (isLive) {
          _finalEcg = ref.read(bleServiceProvider).endCapture();
          if (_finalEcg.isEmpty && _ecgBuffer.isNotEmpty) {
            _finalEcg = List.from(_ecgBuffer);
          }
          if (_liveHr > 0) _finalHr = _liveHr;
        } else {
          _finalEcg = _ecgBuffer.isNotEmpty
              ? List.from(_ecgBuffer)
              : _generateSyntheticEcgChunk(_selectedScenario.heartRateBpm);
          _finalRr ??= _selectedScenario.isArrhythmia
              ? 650
              : (60000 / _selectedScenario.heartRateBpm).round();
          _finalEcgQuality ??= _selectedScenario.ecgQuality;
          _finalHr = _selectedScenario.heartRateBpm;
        }
      } else if (_activeMode == 3) {
        _finalTemp = _liveTemp > 0 ? _liveTemp : _selectedScenario.temperatureC;
      }
      _activeMode = 0;
    });
  }

  void _finishScreening() {
    final isLive = ref.read(bleLinkProvider).isLive;
    final hr =
        _finalHr ?? (_liveHr > 0 ? _liveHr : _selectedScenario.heartRateBpm);
    final spo2 =
        _finalSpo2 ??
        (_liveSpo2 > 0 ? _liveSpo2 : _selectedScenario.spo2Percent);
    final temp =
        _finalTemp ??
        (_liveTemp > 0 ? _liveTemp : _selectedScenario.temperatureC);

    final ptt = 200 + (60000 / hr * 0.25).round();
    final bpEst = VitalsEstimator.estimateBP(pttMs: ptt, heartRate: hr);
    final glucoseEst = VitalsEstimator.estimateGlucose(
      pttMs: ptt,
      heartRate: hr,
      spo2: spo2,
      tempC: temp,
    );

    final sample = HealthSample(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      heartRateBpm: hr,
      spo2Percent: spo2,
      temperatureC: temp,
      ecgSignalQuality: _finalEcgQuality ?? _selectedScenario.ecgQuality,
      rPeakDetected: false,
      rrIntervalMs: _finalRr ?? (60000 / hr).round(),
      pttMs: ptt,
      estimatedSystolic: isLive ? bpEst.systolic : _selectedScenario.systolicBp,
      estimatedDiastolic: isLive
          ? bpEst.diastolic
          : _selectedScenario.diastolicBp,
      estimatedGlucose: isLive
          ? glucoseEst.glucoseMgDl
          : _selectedScenario.estimatedGlucose,
      bpConfidence: 'EXPERIMENTAL',
      glucoseConfidence: 'EXPERIMENTAL',
      batteryPercent: ref.read(bleServiceProvider).state.batteryPercent ?? 100,
      isDemo: !isLive,
    );

    // Ensure draft has a patient attached so TriageResultScreen persists to SQLite
    if (!ref.read(screeningDraftProvider).hasPatient) {
      ref
          .read(screeningDraftProvider.notifier)
          .begin(
            patient: Patient.create(
              id: 'PT-${DateTime.now().millisecondsSinceEpoch}',
              name: 'Walk-In Patient',
              age: 35,
              sex: 'M',
            ),
          );
    }

    if (!isLive &&
        _selectedScenario.typicalSymptoms.isNotEmpty &&
        ref.read(screeningDraftProvider).symptoms.isEmpty) {
      ref
          .read(screeningDraftProvider.notifier)
          .setSymptoms(_selectedScenario.typicalSymptoms);
    }

    ref
        .read(screeningDraftProvider.notifier)
        .setSample(sample, ecgSamples: _finalEcg, ecgSampleRate: 250);
    context.go('/screening/symptoms', extra: {'liveSample': sample});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(bleLinkProvider).isLive;
    final inDemo = !isConnected || _demoMode;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Clinical Vital Signs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_isMeasuring) _stopMeasurement();
            context.go('/home');
          },
        ),
        actions: [
          const ScreeningExitButton(),
          if (inDemo) ...[
            IconButton(
              icon: const Icon(Icons.science_rounded),
              tooltip: 'Simulate Clinical Scenario',
              onPressed: _openScenarioSelector,
            ),
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                _demoBadge,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 4,
          tabs: const [
            Tab(icon: Icon(Icons.favorite), text: 'Pulse Ox'),
            Tab(icon: Icon(Icons.monitor_heart), text: 'ECG Lead I'),
            Tab(icon: Icon(Icons.thermostat), text: 'Temp'),
          ],
        ),
      ),
      body: (!isConnected && !_demoMode)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Device Disconnected',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No ESP32 sensor board connected.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.science_rounded),
                          label: const Text('Start Simulator Demo'),
                          onPressed: () => setState(() => _demoMode = true),
                        ),
                        AppButton(
                          label: 'Connect Board',
                          onPressed: () => context.go('/devices/scan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: _isMeasuring
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    children: [
                      _buildPulseOxTab(theme),
                      _buildEcgTab(theme),
                      _buildTempTab(theme),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: AppButton(
                    label: 'Finish & Proceed',
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _isMeasuring ? null : _finishScreening,
                    minWidth: double.infinity,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPulseOxTab(ThemeData theme) {
    final deltaHr = (_ecgHr > 0 && _ppgHr > 0) ? (_ecgHr - _ppgHr).abs() : null;

    return _buildMeasurementTab(
      mode: 1,
      tabTitle: 'SpO2 & Optical Pulse Wave (PPG)',
      theme: theme,
      hasResult: _finalHr != null && _finalSpo2 != null,
      resultText: _finalHr != null
          ? 'Pulse Rate: $_finalHr BPM   •   SpO₂: $_finalSpo2%'
          : null,
      liveContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dual-Source Consensus Banner
          if (deltaHr != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: deltaHr <= 5
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: deltaHr <= 5
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    deltaHr <= 5
                        ? Icons.check_circle_rounded
                        : Icons.info_outline,
                    size: 16,
                    color: deltaHr <= 5
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deltaHr <= 5
                          ? 'Dual Consensus: High stroke volume agreement (Δ = $deltaHr BPM)'
                          : 'Dual Divergence: Δ = $deltaHr BPM (Assessing motion artifact)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: deltaHr <= 5
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Real-Time Arterial Pulse Waveform Monitor
          DualWaveformSweepMonitor(
            heartRate: (_liveHr > 0 ? _liveHr : (_finalHr ?? 72)).toDouble(),
            spo2: (_liveSpo2 > 0 ? _liveSpo2 : (_finalSpo2 ?? 98)).toDouble(),
            isLive: !_demoMode,
            activeMode: 1,
            fingerOff: _fingerOff,
            beatDetected: _beatDetected,
          ),
          const SizedBox(height: 12),

          // Live Numerical Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLiveMetric(
                theme,
                'Pulse Rate (PPG)',
                _liveHr > 0 ? '$_liveHr' : '—',
                'BPM',
                Icons.favorite_rounded,
                const Color(0xFF06B6D4),
              ),
              _buildLiveMetric(
                theme,
                'Blood Oxygen (SpO₂)',
                _liveSpo2 > 0 ? '$_liveSpo2' : '—',
                '%',
                Icons.air_rounded,
                const Color(0xFF06B6D4),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Signal Quality & Stabilization Indicators
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _spo2Stabilized ? Icons.lock_rounded : Icons.sync_rounded,
                      size: 15,
                      color: _spo2Stabilized
                          ? const Color(0xFF10B981)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _spo2Stabilized
                          ? 'Signal Stabilized (Locked)'
                          : (_ppgLowSignal
                                ? 'Low Perfusion (Hold Still)'
                                : 'Stabilizing Capillary Baseline...'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _spo2Stabilized
                            ? const Color(0xFF10B981)
                            : (_ppgLowSignal
                                  ? const Color(0xFFF59E0B)
                                  : theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Strain: ${_strain.loadDescription}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _strain.psiScore < 3.5
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcgTab(ThemeData theme) {
    return _buildMeasurementTab(
      mode: 2,
      tabTitle: 'Lead I ECG (250 Hz Raw Stream)',
      theme: theme,
      hasResult: _finalEcg.isNotEmpty,
      resultText: _finalEcg.isNotEmpty
          ? 'ECG Captured (${(_finalEcg.length / 250).toStringAsFixed(1)}s • ${_finalHr ?? _liveHr} BPM)'
          : null,
      liveContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Real-time Lead I ECG Oscilloscope
          DualWaveformSweepMonitor(
            heartRate: (_liveHr > 0 ? _liveHr : (_finalHr ?? 72)).toDouble(),
            spo2: (_liveSpo2 > 0 ? _liveSpo2 : (_finalSpo2 ?? 98)).toDouble(),
            isLive: !_demoMode,
            activeMode: 2,
            rawEcgSamples: _ecgBuffer,
            leadOff: _leadOff,
            qrsWidthMs: _morphology.qrsWidthMs,
            qtcMs: _morphology.qtcMs,
            sqi: _morphology.sqi,
            rhythmName: _aiVerdict.rhythm,
            aiConfidence: _aiVerdict.confidence,
          ),
          const SizedBox(height: 12),

          // Live Morphological Scanner Metrics Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1524),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2E48)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _rawMorphologyLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'SQI: ${_morphology.sqi}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: _morphology.sqi >= 80
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMorphologyItem(
                        'QRS Width',
                        _morphology.qrsWidthMs != null
                            ? '${_morphology.qrsWidthMs} ms'
                            : '—',
                        const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 14),
                      _buildMorphologyItem(
                        'QTc (Bazett)',
                        _morphology.qtcMs != null
                            ? '${_morphology.qtcMs} ms'
                            : '—',
                        const Color(0xFFA855F7),
                      ),
                      const SizedBox(width: 14),
                      _buildMorphologyItem(
                        'PR Interval',
                        _morphology.prMs != null
                            ? '${_morphology.prMs} ms'
                            : '—',
                        const Color(0xFF06B6D4),
                      ),
                      const SizedBox(width: 14),
                      _buildMorphologyItem(
                        'ECG HR',
                        _liveHr > 0 ? '$_liveHr BPM' : '—',
                        const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // AI / ML Rhythm Classifier Verdict Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1524),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🧠 ', style: TextStyle(fontSize: 13)),
                        Text(
                          _aiVerdict.rhythm,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF60A5FA),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_aiVerdict.confidence.toStringAsFixed(1)}% CONF',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _aiVerdict.finding,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
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

  Widget _buildMorphologyItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTempTab(ThemeData theme) {
    final hasTemp = _finalTemp != null && _finalTemp! > 0;
    return _buildMeasurementTab(
      mode: 3,
      tabTitle: 'Body Temperature (Infrared)',
      theme: theme,
      hasResult: hasTemp,
      resultText: hasTemp
          ? 'Temperature: ${_finalTemp!.toStringAsFixed(1)} °C'
          : null,
      liveContent: _liveTemp > 0
          ? _buildLiveMetric(
              theme,
              'Live Temp',
              _liveTemp.toStringAsFixed(1),
              '°C',
              Icons.thermostat_rounded,
              theme.colorScheme.tertiary,
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.thermostat_outlined,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sensorDetachedTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sensorDetachedDesc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLiveMetric(
    ThemeData theme,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementTab({
    required int mode,
    required String tabTitle,
    required ThemeData theme,
    required bool hasResult,
    String? resultText,
    required Widget liveContent,
  }) {
    bool isThisMeasuring = _isMeasuring && _activeMode == mode;
    bool isOtherMeasuring = _isMeasuring && _activeMode != mode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tabTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isThisMeasuring) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (ref.watch(bleLinkProvider).isLive &&
                            ((mode == 2 && _leadOff) ||
                                (mode == 1 && _fingerOff)))
                        ? Colors.amber.withValues(alpha: 0.2)
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (ref.watch(bleLinkProvider).isLive &&
                                ((mode == 2 && _leadOff) ||
                                    (mode == 1 && _fingerOff)))
                            ? Icons.pause_circle_rounded
                            : Icons.play_arrow_rounded,
                        size: 14,
                        color:
                            (ref.watch(bleLinkProvider).isLive &&
                                ((mode == 2 && _leadOff) ||
                                    (mode == 1 && _fingerOff)))
                            ? Colors.amber[800]
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_secondsRemaining}s',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              (ref.watch(bleLinkProvider).isLive &&
                                  ((mode == 2 && _leadOff) ||
                                      (mode == 1 && _fingerOff)))
                              ? Colors.amber[900]
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          if (isThisMeasuring) ...[
            if (ref.watch(bleLinkProvider).isLive &&
                ((mode == 2 && _leadOff) || (mode == 1 && _fingerOff))) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mode == 2 ? _pausedEcgTouch : _pausedPpgTouch,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (30 - _secondsRemaining) / 30,
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            liveContent,
            const SizedBox(height: 16),
            AppButton(
              label: 'Stop Measurement',
              icon: const Icon(Icons.stop_rounded),
              onPressed: _stopMeasurement,
              minWidth: double.infinity,
            ),
          ] else if (hasResult) ...[
            AppElevatedCard(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Measurement Complete',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    resultText!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppOutlinedButton(
              label: 'Retake Measurement',
              icon: const Icon(Icons.refresh),
              onPressed: isOtherMeasuring
                  ? null
                  : () => _startMeasurement(mode),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.25,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    mode == 1
                        ? Icons.favorite_rounded
                        : (mode == 2
                              ? Icons.monitor_heart_rounded
                              : Icons.thermostat_rounded),
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    mode == 1
                        ? 'Place fingertip on MAX30102 sensor'
                        : (mode == 2
                              ? 'Attach ECG electrodes to chest/limbs'
                              : 'Position infrared sensor near forehead'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Start ${mode == 3 ? "5s" : "30s"} Measurement',
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: isOtherMeasuring
                        ? null
                        : () => _startMeasurement(mode),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
