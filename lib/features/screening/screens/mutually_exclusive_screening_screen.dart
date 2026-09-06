import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/core/widgets/index.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vitals_estimator.dart';
import 'package:swasthyasetu_ai/domain/simulator/clinical_scenario.dart';
import 'package:swasthyasetu_ai/features/screening/state/screening_draft.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/dual_waveform_sweep_monitor.dart';

// Let's implement our own simple ECG painter to be safe, since it's private in live_vitals_screen.dart

class MutuallyExclusiveScreeningScreen extends ConsumerStatefulWidget {
  const MutuallyExclusiveScreeningScreen({super.key});

  @override
  ConsumerState<MutuallyExclusiveScreeningScreen> createState() => _MutuallyExclusiveScreeningScreenState();
}

class _MutuallyExclusiveScreeningScreenState extends ConsumerState<MutuallyExclusiveScreeningScreen> with TickerProviderStateMixin {
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

  // Live values
  int _liveHr = 0;
  int _liveSpo2 = 0;
  double _liveTemp = 0.0;
  
  List<int> _ecgBuffer = [];
  StreamSubscription? _telemetrySub;
  StreamSubscription? _ecgSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleService = ref.read(bleServiceProvider);
      _telemetrySub = bleService.telemetry.listen((frame) {
        if (!mounted || !_isMeasuring) return;
        setState(() {
          final s = frame.sample;
          if (_activeMode == 1) {
            if (s.heartRateBpm > 0) _liveHr = s.heartRateBpm;
            if (s.spo2Percent > 0) _liveSpo2 = s.spo2Percent;
          } else if (_activeMode == 3) {
            if (s.temperatureC > 0) _liveTemp = s.temperatureC;
          }
          if (s.rrIntervalMs > 0) _finalRr = s.rrIntervalMs;
          if (s.ecgSignalQuality > 0) _finalEcgQuality = s.ecgSignalQuality;
        });
      });
      
      _ecgSub = bleService.ecg.listen((frame) {
        if (!mounted || !_isMeasuring || _activeMode != 2) return;
        setState(() {
          _ecgBuffer.addAll(frame.samples);
          if (_ecgBuffer.length > 250 * 5) {
             _ecgBuffer = _ecgBuffer.sublist(_ecgBuffer.length - 250 * 5); // 5s trailing window
          }
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
    final beatPeriod = 60 / heartRate;
    final samples = List<int>.filled(rate, 2048);
    for (var i = 0; i < rate; i++) {
      final phase = (i / rate) % beatPeriod;
      var mv = 0.0;
      mv += 0.12 * exp(-0.5 * pow((phase - 0.200) / 0.022, 2)); // P
      mv += -0.05 * exp(-0.5 * pow((phase - 0.362) / 0.008, 2)); // Q
      mv += 1.00 * exp(-0.5 * pow((phase - 0.400) / 0.010, 2)); // R
      mv += -0.18 * exp(-0.5 * pow((phase - 0.438) / 0.009, 2)); // S
      mv += 0.25 * exp(-0.5 * pow((phase - 0.600) / 0.045, 2)); // T
      samples[i] = (mv * 500 + 2048).round().clamp(0, 4095);
    }
    return samples;
  }

  void _openScenarioSelector() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
                  child: Row(
                    children: [
                      Icon(Icons.science_rounded, color: theme.colorScheme.primary),
                      const AppSpacing.hsm(),
                      Text(
                        'Virtual Patient Simulator',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg, vertical: 4),
                  child: Text(
                    'Select a clinical scenario for zero-hardware testing:',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                          child: Icon(Icons.medical_information_rounded, color: bandColor, size: 20),
                        ),
                        title: Text(
                          scenario.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text('${scenario.subtitle}\n${scenario.description}'),
                        isThreeLine: true,
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: bandColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                ),
                                child: Text(
                                  scenario.expectedBand.name.toUpperCase(),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: bandColor),
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
                              content: Text('Switched to scenario: ${scenario.name}'),
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
    final random = Random();

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
          _finalRr = _selectedScenario.isArrhythmia ? 650 : (60000 / _selectedScenario.heartRateBpm).round();
        } else if (mode == 3) {
          _liveTemp = _selectedScenario.temperatureC;
        }
      }
    });
    
    if (isLive) {
      final bleService = ref.read(bleServiceProvider);
      bleService.beginCapture(mode: mode);
    }
    
    _measurementTimer?.cancel();
    _measurementTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsRemaining--;

        if (!isLive) {
          if (_activeMode == 1) {
            _liveHr = (_selectedScenario.heartRateBpm + random.nextInt(5) - 2).clamp(40, 200);
            _liveSpo2 = (_selectedScenario.spo2Percent + random.nextInt(3) - 1).clamp(70, 100);
          } else if (_activeMode == 2) {
            _ecgBuffer.addAll(_generateSyntheticEcgChunk(_selectedScenario.heartRateBpm));
            if (_ecgBuffer.length > 250 * 5) {
              _ecgBuffer = _ecgBuffer.sublist(_ecgBuffer.length - 250 * 5);
            }
          } else if (_activeMode == 3) {
            _liveTemp = _selectedScenario.temperatureC + (random.nextDouble() - 0.5) * 0.2;
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
      bleService.setMode(0); // Return to IDLE
    }
    
    setState(() {
      _isMeasuring = false;
      if (_activeMode == 1) {
        _finalHr = _liveHr > 0 ? _liveHr : _selectedScenario.heartRateBpm;
        _finalSpo2 = _liveSpo2 > 0 ? _liveSpo2 : _selectedScenario.spo2Percent;
      } else if (_activeMode == 2) {
        if (isLive) {
          _finalEcg = ref.read(bleServiceProvider).endCapture();
        } else {
          _finalEcg = _ecgBuffer.isNotEmpty
              ? List.from(_ecgBuffer)
              : _generateSyntheticEcgChunk(_selectedScenario.heartRateBpm);
          _finalRr ??= _selectedScenario.isArrhythmia ? 650 : (60000 / _selectedScenario.heartRateBpm).round();
          _finalEcgQuality ??= _selectedScenario.ecgQuality;
        }
      } else if (_activeMode == 3) {
        _finalTemp = _liveTemp > 0 ? _liveTemp : _selectedScenario.temperatureC;
      }
      _activeMode = 0;
    });
  }
  
  void _finishScreening() {
    final isLive = ref.read(bleLinkProvider).isLive;
    final hr = _finalHr ?? (_liveHr > 0 ? _liveHr : _selectedScenario.heartRateBpm);
    final spo2 = _finalSpo2 ?? (_liveSpo2 > 0 ? _liveSpo2 : _selectedScenario.spo2Percent);
    final temp = _finalTemp ?? (_liveTemp > 0 ? _liveTemp : _selectedScenario.temperatureC);

    final ptt = 200 + (60000 / hr * 0.25).round();
    final bpEst = VitalsEstimator.estimateBP(pttMs: ptt, heartRate: hr);
    final glucoseEst = VitalsEstimator.estimateGlucose(pttMs: ptt, heartRate: hr, spo2: spo2, tempC: temp);

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
      estimatedDiastolic: isLive ? bpEst.diastolic : _selectedScenario.diastolicBp,
      estimatedGlucose: isLive ? glucoseEst.glucoseMgDl : _selectedScenario.estimatedGlucose,
      bpConfidence: 'EXPERIMENTAL',
      glucoseConfidence: 'EXPERIMENTAL',
      batteryPercent: ref.read(bleServiceProvider).state.batteryPercent ?? 100,
      isDemo: !isLive,
    );
    
    // Ensure draft has a patient attached so TriageResultScreen persists to SQLite
    if (!ref.read(screeningDraftProvider).hasPatient) {
      ref.read(screeningDraftProvider.notifier).begin(
        patient: Patient.create(
          id: 'PT-${DateTime.now().millisecondsSinceEpoch}',
          name: 'Walk-In Patient',
          age: 35,
          sex: 'M',
        ),
      );
    }

    if (!isLive && _selectedScenario.typicalSymptoms.isNotEmpty && ref.read(screeningDraftProvider).symptoms.isEmpty) {
      ref.read(screeningDraftProvider.notifier).setSymptoms(_selectedScenario.typicalSymptoms);
    }

    ref.read(screeningDraftProvider.notifier).setSample(
      sample,
      ecgSamples: _finalEcg,
      ecgSampleRate: 250,
    );
    context.go('/screening/symptoms', extra: {'liveSample': sample});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(bleLinkProvider).isLive;
    final inDemo = !isConnected || _demoMode;

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Sequential Vitals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_isMeasuring) _stopMeasurement();
            context.go('/home');
          },
        ),
        actions: [
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
                'DEMO',
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
            Tab(icon: Icon(Icons.monitor_heart), text: 'ECG'),
            Tab(icon: Icon(Icons.thermostat), text: 'Temp'),
          ],
        ),
      ),
      body: (!isConnected && !_demoMode) 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth_disabled, size: 64, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Device Disconnected', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'No ESP32 board connected.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.science_rounded),
                        label: const Text('Start Simulator Demo'),
                        onPressed: () => setState(() => _demoMode = true),
                      ),
                      const SizedBox(width: 12),
                      AppButton(label: 'Connect Board', onPressed: () => context.go('/devices/scan')),
                    ],
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: _isMeasuring ? const NeverScrollableScrollPhysics() : null,
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
                )
              ],
            ),
    );
  }

  Widget _buildPulseOxTab(ThemeData theme) {
    return _buildMeasurementTab(
      mode: 1,
      title: 'SpO2 & Heart Rate',
      theme: theme,
      hasResult: _finalHr != null,
      resultText: _finalHr != null ? 'HR: $_finalHr bpm   •   SpO₂: $_finalSpo2%' : null,
      liveContent: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLiveMetric(theme, 'Live HR', '$_liveHr', 'bpm', Icons.favorite, theme.colorScheme.primary),
          _buildLiveMetric(theme, 'Live SpO₂', '$_liveSpo2', '%', Icons.air, theme.colorScheme.secondary),
        ],
      )
    );
  }

  Widget _buildEcgTab(ThemeData theme) {
    return _buildMeasurementTab(
      mode: 2,
      title: 'Electrocardiogram & PPG Sweep',
      theme: theme,
      hasResult: _finalEcg.isNotEmpty,
      resultText: _finalEcg.isNotEmpty ? 'ECG Captured (${(_finalEcg.length / 250).toStringAsFixed(1)}s)' : null,
      liveContent: Column(
        children: [
          DualWaveformSweepMonitor(
            heartRate: (_finalHr ?? (_liveHr > 0 ? _liveHr : 72)).toDouble(),
            spo2: (_finalSpo2 ?? (_liveSpo2 > 0 ? _liveSpo2 : 98)).toDouble(),
            isLive: !_demoMode,
          ),
        ],
      ),
    );
  }

  Widget _buildTempTab(ThemeData theme) {
    return _buildMeasurementTab(
      mode: 3,
      title: 'Body Temperature',
      theme: theme,
      hasResult: _finalTemp != null,
      resultText: _finalTemp != null ? 'Temperature: ${_finalTemp!.toStringAsFixed(1)} °C' : null,
      liveContent: _buildLiveMetric(theme, 'Live Temp', _liveTemp.toStringAsFixed(1), '°C', Icons.thermostat, theme.colorScheme.tertiary),
    );
  }

  Widget _buildLiveMetric(ThemeData theme, String label, String value, String unit, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: theme.textTheme.displaySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(unit, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildMeasurementTab({
    required int mode, 
    required String title, 
    required ThemeData theme,
    required bool hasResult,
    String? resultText,
    required Widget liveContent,
  }) {
    bool isThisMeasuring = _isMeasuring && _activeMode == mode;
    bool isOtherMeasuring = _isMeasuring && _activeMode != mode;
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          
          if (isThisMeasuring) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180, height: 180,
                  child: CircularProgressIndicator(
                    value: (30 - _secondsRemaining) / 30,
                    strokeWidth: 12,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_secondsRemaining', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    Text('seconds', style: theme.textTheme.labelLarge),
                  ],
                ),
              ]
            ),
            const SizedBox(height: 48),
            liveContent,
          ] else if (hasResult) ...[
            AppElevatedCard(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  Text('Measurement Complete', style: theme.textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(resultText!, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            const SizedBox(height: 48),
            AppOutlinedButton(
              label: 'Retake Measurement',
              icon: const Icon(Icons.refresh),
              onPressed: isOtherMeasuring ? null : () => _startMeasurement(mode),
            ),
          ] else ...[
            Icon(Icons.touch_app, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 32),
            AppButton(
              label: 'Start 30s Measurement',
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              onPressed: isOtherMeasuring ? null : () => _startMeasurement(mode),
              minWidth: double.infinity,
              minHeight: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isOtherMeasuring ? 'Another measurement is in progress' : 'Ensure sensor is placed correctly before starting',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ]
        ],
      ),
    );
  }
}


