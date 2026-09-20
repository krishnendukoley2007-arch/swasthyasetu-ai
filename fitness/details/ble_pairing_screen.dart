import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/theme/fitness_theme.dart';

class BlePairingScreen extends StatefulWidget {
  const BlePairingScreen({super.key});

  @override
  State<BlePairingScreen> createState() => _BlePairingScreenState();
}

class _BlePairingScreenState extends State<BlePairingScreen> {
  final _bleService = FitnessBleService();
  final List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults.clear();
          _scanResults.addAll(results);
        });
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) {
        setState(() {
          _isScanning = scanning;
        });
      }
    });
  }

  void _startScan() {
    _scanResults.clear();
    _bleService.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FITNESS HARDWARE (BLE)'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: () {
              if (_isScanning) {
                FlutterBluePlus.stopScan();
              } else {
                _startScan();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Device Status Card
            StreamBuilder<BleConnectionState>(
              stream: _bleService.stateStream,
              initialData: _bleService.state,
              builder: (context, snapshot) {
                final state = snapshot.data ?? BleConnectionState.disconnected;
                final isConnected = state == BleConnectionState.connected;
                final isSimulated = state == BleConnectionState.simulated;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'WEARABLE CONNECTION',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: FitnessTheme.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (isConnected || isSimulated)
                                    ? FitnessTheme.neonLime
                                        .withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isConnected
                                    ? 'CONNECTED'
                                    : isSimulated
                                        ? 'DEMO MODE'
                                        : 'DISCONNECTED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (isConnected || isSimulated)
                                      ? FitnessTheme.neonLime
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isConnected
                              ? 'SSAI-SENSE Hardware (Dual BLE Telemetry)'
                              : isSimulated
                                  ? 'Synthesized Biomechanics & ECG Stream'
                                  : 'No Hardware Paired',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (isConnected || isSimulated)
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FitnessTheme.crimsonPeak,
                                    side: const BorderSide(
                                      color: FitnessTheme.crimsonPeak,
                                    ),
                                  ),
                                  onPressed: () {
                                    _bleService.disconnect();
                                  },
                                  child: const Text('DISCONNECT'),
                                ),
                              )
                            else ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.search),
                                  label: const Text('SCAN BLE'),
                                  onPressed: _startScan,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.smart_toy),
                                  label: const Text('DEMO MODE'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FitnessTheme.electricCyan,
                                    side: const BorderSide(
                                      color: FitnessTheme.electricCyan,
                                    ),
                                  ),
                                  onPressed: () {
                                    _bleService.startDemoSimulation();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Hardware Specs Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitnessTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FitnessTheme.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPATIBLE HARDWARE ARCHITECTURE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: FitnessTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• ESP32 Dual Core BLE 4.2 / 5.0'),
                  Text('• MPU-6050 6-Axis Motion Sensor (I2C 0x68)'),
                  Text('• MAX30102 PPG Pulse Oximeter (I2C 0x57)'),
                  Text('• AD8232 Single-Lead ECG (ADC GPIO 34)'),
                  Text('• SSD1306 0.96" OLED Display (I2C 0x3C)'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'DISCOVERED BLE DEVICES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: FitnessTheme.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),

            if (_scanResults.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FitnessTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FitnessTheme.border),
                ),
                child: Center(
                  child: Text(
                    _isScanning
                        ? 'Searching for SSAI-SENSE / FitPulse wearable...'
                        : 'No devices found. Tap "Scan BLE" or use "Demo Mode" for testing.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: FitnessTheme.textMuted),
                  ),
                ),
              )
            else
              ..._scanResults.map((result) {
                final name = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : 'Unknown BLE Device';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth,
                        color: FitnessTheme.electricCyan),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'RSSI: ${result.rssi} dBm | ${result.device.remoteId}'),
                    trailing: ElevatedButton(
                      child: const Text('CONNECT'),
                      onPressed: () async {
                        await _bleService.connectToDevice(result.device);
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
