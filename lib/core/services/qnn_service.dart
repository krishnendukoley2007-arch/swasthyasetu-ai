import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/domain/rules/vitals_estimator.dart';

/// Execution backends for on-device vitals estimation.
enum VitalsInferenceBackend {
  snapdragonCpu, // Qualcomm Snapdragon device (CPU-based estimation)
  adrenoGpu, // Qualcomm Adreno GPU delegate (optional)
  genericCpu, // Standard ARM/x86 CPU (Physiological Physics Engine)
}

/// Backwards compatibility alias
typedef QnnExecutionBackend = VitalsInferenceBackend;

@immutable
class InferenceHardwareTelemetry {
  final String devicePlatform;
  final double latencyMs;
  final bool isOnDevice;
  final String privacyGuarantee;

  const InferenceHardwareTelemetry({
    required this.devicePlatform,
    required this.latencyMs,
    this.isOnDevice = true,
    this.privacyGuarantee = '100% On-Device — Zero Cloud Vitals',
  });
}

/// Backwards compatibility alias
typedef QnnHardwareTelemetry = InferenceHardwareTelemetry;

@immutable
class QnnInferenceResult {
  final int systolicBp;
  final int diastolicBp;
  final int glucoseMgDl;
  final String backendLabel;
  final double inferenceLatencyMs;
  final bool isNpuAccelerated;
  final InferenceHardwareTelemetry telemetry;

  const QnnInferenceResult({
    required this.systolicBp,
    required this.diastolicBp,
    required this.glucoseMgDl,
    required this.backendLabel,
    required this.inferenceLatencyMs,
    required this.isNpuAccelerated,
    required this.telemetry,
  });
}

/// On-Device Vitals Estimation & Inference Service.
///
/// Executes physiological and learned models on the local device CPU.
/// Honestly reports platform capabilities without claiming unverified hardware NPU delegates.
class VitalsInferenceService {
  bool _isQnnLoaded = false;
  VitalsInferenceBackend _backend = VitalsInferenceBackend.genericCpu;
  String? _loadedModelPath;

  VitalsInferenceService() {
    _initializeBackend();
  }

  bool get isQnnLoaded => _isQnnLoaded;
  VitalsInferenceBackend get backend => _backend;
  String? get loadedModelPath => _loadedModelPath;

  /// NPU acceleration is strictly false unless an actual delegate model is loaded and running.
  bool get isNpuAccelerated => false;

  String get backendName => switch (_backend) {
    VitalsInferenceBackend.snapdragonCpu =>
      'Qualcomm Snapdragon device (CPU-based estimation)',
    VitalsInferenceBackend.adrenoGpu => 'Qualcomm Adreno GPU',
    VitalsInferenceBackend.genericCpu =>
      'Standard CPU (Physiological Physics Engine)',
  };

  /// Initializes hardware detection honestly from /proc/cpuinfo.
  Future<void> _initializeBackend() async {
    try {
      if (Platform.isAndroid) {
        bool isSnapdragon = false;
        try {
          final cpuinfo = File('/proc/cpuinfo');
          if (cpuinfo.existsSync()) {
            final content = cpuinfo.readAsStringSync().toLowerCase();
            isSnapdragon =
                content.contains('qualcomm') ||
                content.contains('qcom') ||
                content.contains('snapdragon');
          }
        } catch (_) {
          isSnapdragon = false;
        }

        if (isSnapdragon) {
          _backend = VitalsInferenceBackend.snapdragonCpu;
          _isQnnLoaded = false;
          debugPrint(
            '[VitalsInference] Qualcomm Snapdragon device detected. Running CPU-based physiological engine.',
          );
        } else {
          _backend = VitalsInferenceBackend.genericCpu;
          _isQnnLoaded = false;
          debugPrint(
            '[VitalsInference] Standard CPU Architecture: Using Physiological Physics Engine.',
          );
        }
      } else {
        _backend = VitalsInferenceBackend.genericCpu;
        _isQnnLoaded = false;
      }
    } catch (e) {
      debugPrint(
        '[VitalsInference] Platform detection notice: $e. Using CPU engine.',
      );
      _backend = VitalsInferenceBackend.genericCpu;
      _isQnnLoaded = false;
    }
  }

  /// Runs on-device vitals estimation and measures genuine runtime execution latency.
  Future<QnnInferenceResult> predictVitals({
    required int pttMs,
    required int heartRate,
    required int spo2,
    required double tempC,
    int age = 35,
    double? bmi,
    int? calibratedSystolic,
    int? calibratedDiastolic,
    List<int> ppgWaveform = const [],
    List<int> ecgWaveform = const [],
  }) async {
    final stopwatch = Stopwatch()..start();

    final bpEst = VitalsEstimator.estimateBP(
      pttMs: pttMs,
      heartRate: heartRate,
      age: age,
      bmi: bmi,
      calibratedSystolic: calibratedSystolic,
      calibratedDiastolic: calibratedDiastolic,
    );

    final glucoseEst = VitalsEstimator.estimateGlucose(
      pttMs: pttMs,
      heartRate: heartRate,
      spo2: spo2,
      tempC: tempC,
      age: age,
      bmi: bmi,
    );

    stopwatch.stop();
    final measuredLatencyMs = stopwatch.elapsedMicroseconds / 1000.0;

    final telemetry = InferenceHardwareTelemetry(
      devicePlatform: backendName,
      latencyMs: measuredLatencyMs,
      isOnDevice: true,
      privacyGuarantee: '100% On-Device — Zero Cloud Vitals',
    );

    return QnnInferenceResult(
      systolicBp: bpEst.systolic,
      diastolicBp: bpEst.diastolic,
      glucoseMgDl: glucoseEst.glucoseMgDl,
      backendLabel: backendName,
      inferenceLatencyMs: measuredLatencyMs,
      isNpuAccelerated: isNpuAccelerated,
      telemetry: telemetry,
    );
  }

  /// Registers a custom pre-compiled model file (.onnx / .tflite / .bin) if loaded.
  void loadQnnModel(String path) {
    _loadedModelPath = path;
    _isQnnLoaded = File(path).existsSync();
    debugPrint(
      '[VitalsInference] Checked model at $path: exists=$_isQnnLoaded',
    );
  }
}

/// Backwards compatibility alias
typedef QnnVitalsService = VitalsInferenceService;

/// Riverpod provider for Vitals Inference Service
final vitalsInferenceServiceProvider = Provider<VitalsInferenceService>((ref) {
  return VitalsInferenceService();
});

/// Backwards compatibility provider
final qnnVitalsServiceProvider = vitalsInferenceServiceProvider;
