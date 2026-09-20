import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/bluetooth/ble_service.dart';
import '../../core/services/permission_service.dart';
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
  bool _permissionsGranted = true;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  StreamSubscription? _scanResultsSub;
  StreamSubscription? _isScanningSub;
  StreamSubscription? _adapterSub;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _listenStreams();

    // Auto-search immediately on entering screen
    _startScan();
  }

  Future<void> _listenStreams() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return;

      _adapterSub = _bleService.adapterStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _adapterState = state;
          });
        }
      });

      _scanResultsSub = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults.clear();
            _scanResults.addAll(results);
          });
        }
      });

      _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
        if (mounted) {
          setState(() {
            _isScanning = scanning;
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _checkPermissions() async {
    final hasPerm = await PermissionService.hasBluetoothPermissions();
    if (mounted) {
      setState(() {
        _permissionsGranted = hasPerm;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await PermissionService.requestBluetoothPermissions();
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
      });
      if (granted) {
        _startScan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Bluetooth permissions are required to scan for sensors.'),
            action: SnackBarAction(
              label: 'SETTINGS',
              onPressed: () => PermissionService.openSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    super.dispose();
  }

  void _startScan() {
    _scanResults.clear();
    _bleService.startScan(timeout: const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    final isBluetoothOff = _adapterState == BluetoothAdapterState.off;

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
            // Bluetooth Disabled Alert Card
            if (isBluetoothOff) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_disabled,
                        color: Colors.redAccent, size: 28),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BLUETOOTH IS OFF',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.redAccent),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Enable Bluetooth to scan and pair with your ESP32.',
                            style: TextStyle(
                                fontSize: 11,
                                color: FitnessTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _bleService.requestTurnOn(),
                      child: const Text('TURN ON',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Missing Permissions Alert Card
            if (!_permissionsGranted) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.orange, size: 28),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERMISSIONS REQUIRED',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.orange),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Allow Nearby Devices permission to detect your ESP32.',
                            style: TextStyle(
                                fontSize: 11,
                                color: FitnessTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: _requestPermissions,
                      child: const Text('GRANT',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // Current Device Status Card
            StreamBuilder<BleConnectionState>(
              stream: _bleService.stateStream,
              initialData: _bleService.state,
              builder: (context, snapshot) {
                final state = snapshot.data ?? BleConnectionState.disconnected;
                final isConnected = state == BleConnectionState.connected;
                final isSimulated = state == BleConnectionState.simulated;
                final isScanning = state == BleConnectionState.scanning;

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
                                    : (isScanning
                                        ? FitnessTheme.electricCyan
                                            .withValues(alpha: 0.2)
                                        : Colors.orange.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isConnected
                                    ? 'CONNECTED'
                                    : isSimulated
                                        ? 'DEMO MODE'
                                        : (isScanning
                                            ? 'SCANNING...'
                                            : 'DISCONNECTED'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (isConnected || isSimulated)
                                      ? FitnessTheme.neonLime
                                      : (isScanning
                                          ? FitnessTheme.electricCyan
                                          : Colors.orange),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isConnected
                              ? (_bleService.connectedDeviceName ??
                                  'FitPulse AI Wearable')
                              : (isSimulated
                                  ? 'Synthesized Biomechanics & ECG Stream'
                                  : 'No Hardware Paired'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isConnected) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Service UUID: FFE0 | Telemetry (FFE1) & Motion (FFE2) Active',
                            style: TextStyle(
                                fontSize: 11,
                                color: FitnessTheme.neonLime
                                    .withValues(alpha: 0.8)),
                          ),
                        ],
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
                                  label: Text(
                                      _isScanning ? 'SCANNING...' : 'SCAN BLE'),
                                  onPressed: _isScanning ? null : _startScan,
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

            // How to Connect Guide Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitnessTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FitnessTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline,
                          color: FitnessTheme.electricCyan, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'HOW TO CONNECT YOUR ESP32',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: FitnessTheme.electricCyan,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow('1',
                      'Plug in ESP32 via USB. Verify OLED shows "BLE: ADV [FFE0]".'),
                  const SizedBox(height: 8),
                  _buildStepRow('2',
                      'Keep phone Bluetooth ON. The app connects automatically.'),
                  const SizedBox(height: 8),
                  _buildStepRow('3',
                      'Or tap "SCAN BLE" below and tap "CONNECT" next to FITPULSE-AI.'),
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
                  child: Column(
                    children: [
                      Icon(
                        _isScanning ? Icons.radar : Icons.bluetooth_searching,
                        color: _isScanning
                            ? FitnessTheme.electricCyan
                            : FitnessTheme.textMuted,
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isScanning
                            ? 'Scanning for FITPULSE-AI / SSAI wearable...'
                            : 'No devices found yet.\nEnsure ESP32 is powered on and tap "SCAN BLE".',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: FitnessTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._scanResults.map((result) {
                final advName = result.advertisementData.advName;
                final platName = result.device.platformName;
                final displayName = advName.isNotEmpty
                    ? advName
                    : (platName.isNotEmpty
                        ? platName
                        : 'Unknown Device (${result.device.remoteId.str.substring(0, 5)}...)');

                final isFitPulse =
                    displayName.toUpperCase().contains('FITPULSE') ||
                        displayName.toUpperCase().contains('SSAI') ||
                        result.advertisementData.serviceUuids.any(
                            (u) => u.toString().toUpperCase().contains('FFE0'));

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isFitPulse
                          ? FitnessTheme.neonLime
                          : FitnessTheme.border,
                      width: isFitPulse ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isFitPulse
                          ? FitnessTheme.neonLime.withValues(alpha: 0.2)
                          : FitnessTheme.surface,
                      child: Icon(
                        isFitPulse ? Icons.watch : Icons.bluetooth,
                        color: isFitPulse
                            ? FitnessTheme.neonLime
                            : FitnessTheme.textSecondary,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isFitPulse
                                  ? FitnessTheme.neonLime
                                  : Colors.white,
                            ),
                          ),
                        ),
                        if (isFitPulse)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  FitnessTheme.neonLime.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'COMPATIBLE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: FitnessTheme.neonLime,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Signal: ${result.rssi} dBm  •  ID: ${result.device.remoteId}',
                        style: const TextStyle(
                            fontSize: 11, color: FitnessTheme.textMuted),
                      ),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFitPulse
                            ? FitnessTheme.neonLime
                            : FitnessTheme.surface,
                        foregroundColor:
                            isFitPulse ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('CONNECT',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11)),
                      onPressed: () async {
                        await _bleService.connectToDevice(result.device);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Connected to $displayName'),
                              backgroundColor: FitnessTheme.neonLime,
                            ),
                          );
                        }
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

  Widget _buildStepRow(String stepNum, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FitnessTheme.electricCyan.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            stepNum,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: FitnessTheme.electricCyan,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
                fontSize: 12, color: FitnessTheme.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}
