import 'dart:async';
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

  int _readinessScore = 88;
  int _rmssdMs = 54;
  int _restingBpm = 58;

  void _startReadinessScan() {
    setState(() {
      _isScanning = true;
      _secondsLeft = 60;
    });

    if (_bleService.state == BleConnectionState.disconnected) {
      _bleService.startDemoSimulation();
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isScanning = false;
          _secondsLeft = 0;
          _readinessScore = 89;
          _rmssdMs = 58;
          _restingBpm = 56;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
                                : _readinessScore / 100.0,
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
                                  : '$_readinessScore',
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
                          : 'High Autonomic Balance (Prime Condition)',
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
                          ? 'Keep your finger on the AD8232 ECG contacts and stay still.'
                          : 'Your Central Nervous System is fully recovered. You are primed for heavy resistance training or high-intensity interval sprints.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: FitnessTheme.textSecondary,
                      ),
                    ),
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
                          '$_rmssdMs ms',
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
                          '$_restingBpm bpm',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: FitnessTheme.warmOrange,
                          ),
                        ),
                        const Text(
                          'morning baseline',
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
