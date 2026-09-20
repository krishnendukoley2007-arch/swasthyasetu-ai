import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/models/motion_telemetry.dart';
import 'ble_protocol.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  simulated,
}

class FitnessBleService {
  static final FitnessBleService _instance = FitnessBleService._internal();
  factory FitnessBleService() => _instance;
  FitnessBleService._internal();

  BluetoothDevice? _connectedDevice;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  final _vitalsController = StreamController<FitnessVitalsData>.broadcast();
  Stream<FitnessVitalsData> get vitalsStream => _vitalsController.stream;

  final _motionController = StreamController<MotionTelemetry>.broadcast();
  Stream<MotionTelemetry> get motionStream => _motionController.stream;

  final _stateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  Timer? _simulationTimer;
  double _simTime = 0.0;
  int _simReps = 0;

  void _setState(BleConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Start BLE discovery for the SSAI / FitPulse hardware
  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      _setState(BleConnectionState.scanning);
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withNames: ['SSAI-SENSE', 'FITPULSE', 'SwasthyaSetu'],
      );
    } catch (e) {
      debugPrint('BLE Scan error: $e');
      _setState(BleConnectionState.disconnected);
    }
  }

  /// Connect to physical hardware device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _setState(BleConnectionState.connecting);
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      final services = await device.discoverServices();
      for (final service in services) {
        for (final c in service.characteristics) {
          if (c.properties.notify) {
            await c.setNotifyValue(true);
            c.lastValueStream.listen((bytes) {
              _handleIncomingPacket(bytes);
            });
          }
        }
      }

      _setState(BleConnectionState.connected);
      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      _setState(BleConnectionState.disconnected);
      return false;
    }
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

  /// Fallback demo simulation mode (enables instant app testing on phones or emulators)
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

      // Vitals modulation (Heart rate rises during workout)
      final simulatedHr = (115 + 25 * math.sin(_simTime / 20.0)).round();

      _vitalsController.add(FitnessVitalsData(
        heartRate: simulatedHr,
        spo2: 98,
        temperature: 36.8,
        rrIntervalMs: (60000 / simulatedHr).round(),
        batteryPercent: 88,
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
        cadence: 24,
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

  Future<void> disconnect() async {
    stopDemoSimulation();
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    _setState(BleConnectionState.disconnected);
  }
}
