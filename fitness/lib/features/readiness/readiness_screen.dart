import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/fitness_theme.dart';

class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  final _bleService = FitnessBleService();

  bool _isScanning = false;
  int _secondsLeft = 60;
  Timer? _countdownTimer;

  int? _readinessScore;
  int? _rmssdMs;
  int? _restingBpm;
  String? _statusNotice;

  final List<int> _capturedRrMs = [];
  final List<int> _capturedHeartRates = [];
  StreamSubscription? _vitalsSub;

  void _startReadinessScan() {
    _capturedRrMs.clear();
    _capturedHeartRates.clear();

    setState(() {
      _isScanning = true;
      _secondsLeft = 60;
      _statusNotice = null;
    });

    _vitalsSub?.cancel();
    _vitalsSub = _bleService.vitalsStream.listen((vitals) {
      if (vitals.rrIntervalMs >= 300 && vitals.rrIntervalMs <= 1800) {
        _capturedRrMs.add(vitals.rrIntervalMs);
      }
      if (vitals.heartRate > 35 && vitals.heartRate < 220) {
        _capturedHeartRates.add(vitals.heartRate);
      }
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        _vitalsSub?.cancel();

        if (_capturedRrMs.length >= 4) {
          double sumSqDiff = 0.0;
          for (int i = 0; i < _capturedRrMs.length - 1; i++) {
            final diff = _capturedRrMs[i + 1] - _capturedRrMs[i];
            sumSqDiff += diff * diff;
          }
          final computedRmssd =
              math.sqrt(sumSqDiff / (_capturedRrMs.length - 1));
          final avgBpm = _capturedHeartRates.isNotEmpty
              ? (_capturedHeartRates.reduce((a, b) => a + b) /
                      _capturedHeartRates.length)
                  .round()
              : 60;
          final score = (computedRmssd / 65.0 * 85.0).clamp(30.0, 99.0).round();

          setState(() {
            _isScanning = false;
            _secondsLeft = 0;
            _rmssdMs = computedRmssd.round();
            _restingBpm = avgBpm;
            _readinessScore = score;
            _statusNotice = _bleService.state == BleConnectionState.simulated
                ? 'SIMULATED DATA'
                : 'REAL HARDWARE ACQUISITION';
          });
        } else {
          setState(() {
            _isScanning = false;
            _secondsLeft = 0;
            _statusNotice =
                'No active ECG/PPG beats detected during scan. Ensure electrodes are attached.';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _vitalsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATHLETIC READINESS & HRV'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Score Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'DAILY RECOVERY & CNS STRAIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FitnessTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: _isScanning
                                ? (60 - _secondsLeft) / 60.0
                                : (_readinessScore != null
                                    ? _readinessScore! / 100.0
                                    : 0.0),
                            strokeWidth: 10,
                            backgroundColor: FitnessTheme.surfaceElevated,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              FitnessTheme.neonLime,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isScanning
                                  ? '$_secondsLeft s'
                                  : (_readinessScore != null
                                      ? '$_readinessScore'
                                      : '--'),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _isScanning ? 'RECORDING' : 'READINESS',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: FitnessTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isScanning
                          ? 'Measuring electrical ECG R-R intervals for autonomic balance...'
                          : (_readinessScore != null
                              ? 'Autonomic Balance Computed'
                              : 'Ready for HRV Scan'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: FitnessTheme.neonLime,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isScanning
                          ? 'Keep your finger or band in steady contact with the sensors.'
                          : (_readinessScore != null
                              ? 'Computed from real consecutive RR interval variance.'
                              : 'Tap "START 60s HRV SCAN" below to measure your physiological recovery from real hardware RR telemetry.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: FitnessTheme.textSecondary,
                      ),
                    ),
                    if (_statusNotice != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: FitnessTheme.neonLime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusNotice!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: FitnessTheme.neonLime,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Metrics Duo
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FitnessTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FitnessTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HRV (RMSSD)',
                          style: TextStyle(
                            fontSize: 11,
                            color: FitnessTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _rmssdMs != null ? '$_rmssdMs ms' : '--',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: FitnessTheme.electricCyan,
                          ),
                        ),
                        const Text(
                          'parasympathetic tone',
                          style: TextStyle(
                            fontSize: 11,
                            color: FitnessTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FitnessTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FitnessTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RESTING PULSE',
                          style: TextStyle(
                            fontSize: 11,
                            color: FitnessTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _restingBpm != null ? '$_restingBpm BPM' : '--',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: FitnessTheme.vividAmber,
                          ),
                        ),
                        const Text(
                          'autonomic baseline',
                          style: TextStyle(
                            fontSize: 11,
                            color: FitnessTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(_isScanning ? Icons.timer : Icons.favorite),
                label: Text(
                  _isScanning ? 'SCAN IN PROGRESS...' : 'START 60s ECG CHECK',
                ),
                onPressed: _isScanning ? null : _startReadinessScan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
