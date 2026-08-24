class HealthSample {
  final int timestamp;
  final int heartRateBpm;
  final int spo2Percent;
  final double temperatureC;
  final List<int> ecgSignal;
  final double ecgSignalQuality;
  final bool rPeakDetected;
  final int rrIntervalMs;
  final int pttMs;
  final int estimatedSystolic;
  final int estimatedDiastolic;
  final String bpConfidence;
  final int batteryPercent;
  final bool isDemo;

  const HealthSample({
    required this.timestamp,
    required this.heartRateBpm,
    required this.spo2Percent,
    required this.temperatureC,
    this.ecgSignal = const [],
    required this.ecgSignalQuality,
    required this.rPeakDetected,
    this.rrIntervalMs = 0,
    this.pttMs = 0,
    this.estimatedSystolic = 0,
    this.estimatedDiastolic = 0,
    this.bpConfidence = 'EXPERIMENTAL',
    required this.batteryPercent,
    this.isDemo = false,
  });

  factory HealthSample.fromJson(Map<String, dynamic> json) => HealthSample(
    timestamp: json['timestamp'] as int,
    heartRateBpm: json['heartRateBpm'] as int,
    spo2Percent: json['spo2Percent'] as int,
    temperatureC: (json['temperatureC'] as num).toDouble(),
    ecgSignal: (json['ecgSignal'] as List<dynamic>?)?.cast<int>() ?? [],
    ecgSignalQuality: (json['ecgSignalQuality'] as num).toDouble(),
    rPeakDetected: json['rPeakDetected'] as bool,
    rrIntervalMs: json['rrIntervalMs'] as int? ?? 0,
    pttMs: json['pttMs'] as int? ?? 0,
    estimatedSystolic: json['estimatedSystolic'] as int? ?? 0,
    estimatedDiastolic: json['estimatedDiastolic'] as int? ?? 0,
    bpConfidence: json['bpConfidence'] as String? ?? 'EXPERIMENTAL',
    batteryPercent: json['batteryPercent'] as int,
    isDemo: json['isDemo'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'heartRateBpm': heartRateBpm,
    'spo2Percent': spo2Percent,
    'temperatureC': temperatureC,
    'ecgSignal': ecgSignal,
    'ecgSignalQuality': ecgSignalQuality,
    'rPeakDetected': rPeakDetected,
    'rrIntervalMs': rrIntervalMs,
    'pttMs': pttMs,
    'estimatedSystolic': estimatedSystolic,
    'estimatedDiastolic': estimatedDiastolic,
    'bpConfidence': bpConfidence,
    'batteryPercent': batteryPercent,
    'isDemo': isDemo,
  };

  HealthSample copyWith({
    int? timestamp,
    int? heartRateBpm,
    int? spo2Percent,
    double? temperatureC,
    List<int>? ecgSignal,
    double? ecgSignalQuality,
    bool? rPeakDetected,
    int? rrIntervalMs,
    int? pttMs,
    int? estimatedSystolic,
    int? estimatedDiastolic,
    String? bpConfidence,
    int? batteryPercent,
    bool? isDemo,
  }) => HealthSample(
    timestamp: timestamp ?? this.timestamp,
    heartRateBpm: heartRateBpm ?? this.heartRateBpm,
    spo2Percent: spo2Percent ?? this.spo2Percent,
    temperatureC: temperatureC ?? this.temperatureC,
    ecgSignal: ecgSignal ?? this.ecgSignal,
    ecgSignalQuality: ecgSignalQuality ?? this.ecgSignalQuality,
    rPeakDetected: rPeakDetected ?? this.rPeakDetected,
    rrIntervalMs: rrIntervalMs ?? this.rrIntervalMs,
    pttMs: pttMs ?? this.pttMs,
    estimatedSystolic: estimatedSystolic ?? this.estimatedSystolic,
    estimatedDiastolic: estimatedDiastolic ?? this.estimatedDiastolic,
    bpConfidence: bpConfidence ?? this.bpConfidence,
    batteryPercent: batteryPercent ?? this.batteryPercent,
    isDemo: isDemo ?? this.isDemo,
  );

  factory HealthSample.demo({
    int? timestamp,
    int heartRateBpm = 72,
    int spo2Percent = 98,
    double temperatureC = 36.5,
    List<int> ecgSignal = const [],
    double ecgSignalQuality = 0.95,
    bool rPeakDetected = true,
    int rrIntervalMs = 833,
    int pttMs = 200,
    int estimatedSystolic = 120,
    int estimatedDiastolic = 80,
    String bpConfidence = 'EXPERIMENTAL',
    int batteryPercent = 85,
  }) {
    return HealthSample(
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      heartRateBpm: heartRateBpm,
      spo2Percent: spo2Percent,
      temperatureC: temperatureC,
      ecgSignal: ecgSignal,
      ecgSignalQuality: ecgSignalQuality,
      rPeakDetected: rPeakDetected,
      rrIntervalMs: rrIntervalMs,
      pttMs: pttMs,
      estimatedSystolic: estimatedSystolic,
      estimatedDiastolic: estimatedDiastolic,
      bpConfidence: bpConfidence,
      batteryPercent: batteryPercent,
      isDemo: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthSample &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          heartRateBpm == other.heartRateBpm &&
          spo2Percent == other.spo2Percent &&
          temperatureC == other.temperatureC &&
          ecgSignal == other.ecgSignal &&
          ecgSignalQuality == other.ecgSignalQuality &&
          rPeakDetected == other.rPeakDetected &&
          rrIntervalMs == other.rrIntervalMs &&
          pttMs == other.pttMs &&
          estimatedSystolic == other.estimatedSystolic &&
          estimatedDiastolic == other.estimatedDiastolic &&
          bpConfidence == other.bpConfidence &&
          batteryPercent == other.batteryPercent &&
          isDemo == other.isDemo;

  @override
  int get hashCode => Object.hash(
    timestamp, heartRateBpm, spo2Percent, temperatureC, ecgSignal,
    ecgSignalQuality, rPeakDetected, rrIntervalMs, pttMs,
    estimatedSystolic, estimatedDiastolic, bpConfidence, batteryPercent, isDemo
  );
}

class VitalSigns {
  final int heartRate;
  final int spo2;
  final double temperature;
  final String ecgQuality;
  final int battery;
  final bool isConnected;
  final bool isDemo;

  const VitalSigns({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.ecgQuality,
    required this.battery,
    required this.isConnected,
    required this.isDemo,
  });

  factory VitalSigns.fromJson(Map<String, dynamic> json) => VitalSigns(
    heartRate: json['heartRate'] as int,
    spo2: json['spo2'] as int,
    temperature: (json['temperature'] as num).toDouble(),
    ecgQuality: json['ecgQuality'] as String,
    battery: json['battery'] as int,
    isConnected: json['isConnected'] as bool,
    isDemo: json['isDemo'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'heartRate': heartRate,
    'spo2': spo2,
    'temperature': temperature,
    'ecgQuality': ecgQuality,
    'battery': battery,
    'isConnected': isConnected,
    'isDemo': isDemo,
  };

  VitalSigns copyWith({
    int? heartRate,
    int? spo2,
    double? temperature,
    String? ecgQuality,
    int? battery,
    bool? isConnected,
    bool? isDemo,
  }) => VitalSigns(
    heartRate: heartRate ?? this.heartRate,
    spo2: spo2 ?? this.spo2,
    temperature: temperature ?? this.temperature,
    ecgQuality: ecgQuality ?? this.ecgQuality,
    battery: battery ?? this.battery,
    isConnected: isConnected ?? this.isConnected,
    isDemo: isDemo ?? this.isDemo,
  );

  factory VitalSigns.demo() => const VitalSigns(
    heartRate: 72,
    spo2: 98,
    temperature: 36.5,
    ecgQuality: 'GOOD',
    battery: 85,
    isConnected: true,
    isDemo: true,
  );

  factory VitalSigns.disconnected() => const VitalSigns(
    heartRate: 0,
    spo2: 0,
    temperature: 0,
    ecgQuality: 'DISCONNECTED',
    battery: 0,
    isConnected: false,
    isDemo: false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VitalSigns &&
          runtimeType == other.runtimeType &&
          heartRate == other.heartRate &&
          spo2 == other.spo2 &&
          temperature == other.temperature &&
          ecgQuality == other.ecgQuality &&
          battery == other.battery &&
          isConnected == other.isConnected &&
          isDemo == other.isDemo;

  @override
  int get hashCode => Object.hash(heartRate, spo2, temperature, ecgQuality, battery, isConnected, isDemo);
}