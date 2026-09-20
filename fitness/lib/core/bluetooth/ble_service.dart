import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/motion_telemetry.dart';
import '../services/permission_service.dart';
import 'ble_protocol.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
  simulated,
}

class FitnessBleService {
  static final FitnessBleService _instance = FitnessBleService._internal();
  factory FitnessBleService() => _instance;
  FitnessBleService._internal() {
    _initLifecycleListeners();
  }

  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String charTelemetryUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const String charMotionUuid = '0000ffe2-0000-1000-8000-00805f9b34fb';
  static const String _prefLastDeviceId = 'last_fitpulse_device_id';

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  final _vitalsController = StreamController<FitnessVitalsData>.broadcast();
  Stream<FitnessVitalsData> get vitalsStream => _vitalsController.stream;

  final _motionController = StreamController<MotionTelemetry>.broadcast();
  Stream<MotionTelemetry> get motionStream => _motionController.stream;

  final _stateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResultsStream =>
      _scanResultsController.stream;

  StreamSubscription? _scanSub;
  StreamSubscription? _isScanningSub;
  StreamSubscription? _connectionStateSub;
  final List<StreamSubscription> _charSubs = [];

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  bool _userExplicitDisconnect = false;

  Timer? _simulationTimer;
  double _simTime = 0.0;
  int _simReps = 0;

  void _setState(BleConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void _initLifecycleListeners() {
    // Listen to scanning status to ensure state does not get stuck in scanning
    _isScanningSub?.cancel();
    _isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && _state == BleConnectionState.scanning) {
        _setState(BleConnectionState.disconnected);
      }
    });
  }

  /// Automatically attempt discovery and connection to known or nearby FitPulse band
  Future<void> autoConnect() async {
    if (_state == BleConnectionState.connected ||
        _state == BleConnectionState.connecting ||
        _state == BleConnectionState.reconnecting) {
      return;
    }

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return;

      // 1. Request Runtime Bluetooth Permissions (Pops OS permission dialog!)
      final granted = await PermissionService.requestBluetoothPermissions();
      if (!granted) {
        debugPrint('[BLE] Bluetooth permissions not granted');
        _setState(BleConnectionState.disconnected);
        return;
      }

      // 2. If Bluetooth is off, prompt user to turn it on (Pops OS turn on dialog!)
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_prefLastDeviceId);

      await startScan(
        timeout: const Duration(seconds: 10),
        targetDeviceId: lastId,
        autoConnectFirstMatch: true,
      );
    } catch (e) {
      debugPrint('[BLE] autoConnect error: $e');
    }
  }

  /// Stream of Bluetooth radio state (on/off/turningOn/turningOff)
  Stream<BluetoothAdapterState> get adapterStateStream =>
      FlutterBluePlus.adapterState;

  /// Helper to trigger the OS dialog to turn on Bluetooth
  Future<void> requestTurnOn() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      debugPrint('[BLE] requestTurnOn error: $e');
    }
  }

  /// Start BLE discovery for the FitPulse / SSAI wearable
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
    String? targetDeviceId,
    bool autoConnectFirstMatch = false,
  }) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return;

      stopDemoSimulation();
      _userExplicitDisconnect = false;

      // Ensure permissions before scanning
      final granted = await PermissionService.requestBluetoothPermissions();
      if (!granted) {
        debugPrint('[BLE] Scan aborted: permissions denied');
        _setState(BleConnectionState.disconnected);
        return;
      }

      _setState(BleConnectionState.scanning);

      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        _scanResultsController.add(results);

        if (autoConnectFirstMatch && _state == BleConnectionState.scanning) {
          for (final r in results) {
            final advName = r.advertisementData.advName.toUpperCase();
            final platName = r.device.platformName.toUpperCase();
            final matchesTarget = targetDeviceId != null &&
                r.device.remoteId.str == targetDeviceId;
            final matchesName = advName.contains('FITPULSE') ||
                advName.contains('SSAI') ||
                platName.contains('FITPULSE') ||
                platName.contains('SSAI');
            final matchesService = r.advertisementData.serviceUuids.any(
              (u) => u.toString().toUpperCase().contains('FFE0'),
            );

            if (matchesTarget || matchesName || matchesService) {
              FlutterBluePlus.stopScan();
              connectToDevice(r.device);
              break;
            }
          }
        }
      });

      // Broad scan to ensure scan response PDUs are received on all Android chipsets
      await FlutterBluePlus.startScan(
        timeout: timeout,
      );
    } catch (e) {
      debugPrint('[BLE] Scan error: $e');
      _setState(BleConnectionState.disconnected);
    }
  }

  /// Connect to physical hardware device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      stopDemoSimulation();
      _userExplicitDisconnect = false;
      _cancelReconnect();
      await FlutterBluePlus.stopScan();

      _setState(BleConnectionState.connecting);

      // Listen to connection state lifecycle
      await _connectionStateSub?.cancel();
      _connectionStateSub = device.connectionState.listen((status) {
        if (status == BluetoothConnectionState.disconnected) {
          _teardownCharacteristics();
          if (!_userExplicitDisconnect) {
            _scheduleReconnect(device);
          } else {
            _connectedDevice = null;
            _connectedDeviceName = null;
            _setState(BleConnectionState.disconnected);
          }
        }
      });

      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      _connectedDeviceName =
          device.advName.isNotEmpty ? device.advName : 'FitPulse Band';

      // Persist last connected device ID
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLastDeviceId, device.remoteId.str);
      } catch (_) {}

      // Request larger MTU for higher fidelity telemetry
      try {
        await device.requestMtu(247);
      } catch (_) {}

      // Discover services and subscribe
      final services = await device.discoverServices();
      final targetService = services.firstWhere(
        (s) => s.uuid.toString().toUpperCase().contains('FFE0'),
        orElse: () =>
            throw Exception('FitPulse FFE0 Service not found on device'),
      );

      _teardownCharacteristics();
      for (final c in targetService.characteristics) {
        if (c.properties.notify) {
          await c.setNotifyValue(true);
          final sub = c.lastValueStream.listen((bytes) {
            _handleIncomingPacket(bytes);
          });
          _charSubs.add(sub);
        }
      }

      _reconnectAttempts = 0;
      _setState(BleConnectionState.connected);
      return true;
    } catch (e) {
      debugPrint('[BLE] Connection error: ');
      _teardownCharacteristics();
      _connectedDevice = null;
      _connectedDeviceName = null;
      _setState(BleConnectionState.disconnected);
      return false;
    }
  }

  void _scheduleReconnect(BluetoothDevice device) {
    if (_userExplicitDisconnect) return;

    _reconnectAttempts++;
    if (_reconnectAttempts > maxReconnectAttempts) {
      _reconnectAttempts = 0;
      _connectedDevice = null;
      _connectedDeviceName = null;
      _setState(BleConnectionState.disconnected);
      return;
    }

    _setState(BleConnectionState.reconnecting);
    final delaySeconds = math.min(
        1 << _reconnectAttempts, 16); // Exponential backoff: 2s, 4s, 8s, 16s
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      debugPrint('[BLE] Auto-reconnect attempt  of ...');
      final ok = await connectToDevice(device);
      if (!ok && !_userExplicitDisconnect) {
        _scheduleReconnect(device);
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  void _teardownCharacteristics() {
    for (final sub in _charSubs) {
      sub.cancel();
    }
    _charSubs.clear();
  }

  /// Disconnect cleanly
  Future<void> disconnect() async {
    _userExplicitDisconnect = true;
    _cancelReconnect();
    stopDemoSimulation();
    _teardownCharacteristics();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}

    await _connectionStateSub?.cancel();
    _connectedDevice = null;
    _connectedDeviceName = null;
    _setState(BleConnectionState.disconnected);
  }

  void _handleIncomingPacket(List<int> bytes) {
    if (bytes.isEmpty) return;

    if (bytes[0] == FitnessBleProtocol.frameTelemetry) {
      final vitals = FitnessBleProtocol.parseVitals(bytes);
      if (vitals != null) _vitalsController.add(vitals);
    } else if (bytes[0] == FitnessBleProtocol.frameMotion) {
      final motion = FitnessBleProtocol.parseMotion(bytes);
      if (motion != null) _motionController.add(motion);
    }
  }

  /// Explicit demo simulation mode (strictly user-initiated, visibly marked in UI)
  void startDemoSimulation() {
    stopDemoSimulation();
    _setState(BleConnectionState.simulated);

    _simulationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _simTime += 0.1;

      // Realistic workout motion waveform (sinusoidal squats / movement)
      const period = 2.5; // 2.5s per squat rep
      final phase = (_simTime % period) / period * 2 * math.pi;
      final accelZ = 1.0 + 0.6 * math.sin(phase);
      final accelY = 0.25 * math.cos(phase);
      final accelX = 0.1 * math.sin(phase * 2);

      final gyroY = 45.0 * math.cos(phase);
      final gyroX = 15.0 * math.sin(phase);
      final gyroZ = 10.0 * math.sin(phase * 0.5);

      if ((_simTime % period) < 0.15 && _simTime > 1.0) {
        _simReps++;
      }

      final mockHr = (130 + 15 * math.sin(_simTime / 15.0)).round();

      _vitalsController.add(FitnessVitalsData(
        heartRate: mockHr,
        spo2: 98,
        temperature: 36.8,
        rrIntervalMs: (60000 / mockHr).round(),
        batteryPercent: 92,
        uptimeMs: (_simTime * 1000).round(),
        timestamp: DateTime.now(),
      ));

      _motionController.add(MotionTelemetry(
        accelX: accelX,
        accelY: accelY,
        accelZ: accelZ,
        gyroX: gyroX,
        gyroY: gyroY,
        gyroZ: gyroZ,
        repCount: _simReps,
        cadence: (55 + 5 * math.sin(_simTime / 5.0)).round(),
        stepCount: (1200 + _simTime * 1.5).round(),
        motionIntensity: 78,
        timestamp: DateTime.now(),
      ));
    });
  }

  void stopDemoSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (_state == BleConnectionState.simulated) {
      _setState(BleConnectionState.disconnected);
    }
  }

  void dispose() {
    disconnect();
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _connectionStateSub?.cancel();
    _vitalsController.close();
    _motionController.close();
    _stateController.close();
    _scanResultsController.close();
  }
}
