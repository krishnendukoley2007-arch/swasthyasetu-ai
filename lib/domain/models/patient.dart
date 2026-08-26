class Patient {
  final String id;
  final String name;
  final int age;
  final String sex;
  final String? location;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastScreenedAt;
  final List<String> vulnerabilityFlags; // elderly, chronic, pregnant
  final bool isDemo;
  final String syncStatus;
  final int? retryCount;

  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    this.location,
    this.phone,
    this.notes,
    required this.createdAt,
    this.lastScreenedAt,
    this.vulnerabilityFlags = const [],
    this.isDemo = false,
    this.syncStatus = 'PENDING',
    this.retryCount,
  });

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'] as String,
    name: json['name'] as String,
    age: json['age'] as int,
    sex: json['sex'] as String,
    location: json['location'] as String?,
    phone: json['phone'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastScreenedAt: json['lastScreenedAt'] != null ? DateTime.parse(json['lastScreenedAt'] as String) : null,
    vulnerabilityFlags: (json['vulnerabilityFlags'] as List<dynamic>?)?.cast<String>() ?? [],
    isDemo: json['isDemo'] as bool? ?? false,
    syncStatus: json['syncStatus'] as String? ?? 'PENDING',
    retryCount: json['retryCount'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'sex': sex,
    'location': location,
    'phone': phone,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'lastScreenedAt': lastScreenedAt?.toIso8601String(),
    'vulnerabilityFlags': vulnerabilityFlags,
    'isDemo': isDemo,
    'syncStatus': syncStatus,
    'retryCount': retryCount,
  };

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? sex,
    String? location,
    String? phone,
    String? notes,
    DateTime? createdAt,
    DateTime? lastScreenedAt,
    List<String>? vulnerabilityFlags,
    bool? isDemo,
    String? syncStatus,
    int? retryCount,
  }) => Patient(
    id: id ?? this.id,
    name: name ?? this.name,
    age: age ?? this.age,
    sex: sex ?? this.sex,
    location: location ?? this.location,
    phone: phone ?? this.phone,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    lastScreenedAt: lastScreenedAt ?? this.lastScreenedAt,
    vulnerabilityFlags: vulnerabilityFlags ?? this.vulnerabilityFlags,
    isDemo: isDemo ?? this.isDemo,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
  );

  factory Patient.create({
    required String id,
    required String name,
    required int age,
    required String sex,
    String? location,
    String? phone,
    String? notes,
    List<String> vulnerabilityFlags = const [],
    bool isDemo = false,
  }) {
    final now = DateTime.now();
    return Patient(
      id: id,
      name: name,
      age: age,
      sex: sex,
      location: location,
      phone: phone,
      notes: notes,
      createdAt: now,
      lastScreenedAt: null,
      vulnerabilityFlags: vulnerabilityFlags,
      isDemo: isDemo,
      syncStatus: 'PENDING',
      retryCount: 0,
    );
  }

  bool get isElderly => vulnerabilityFlags.contains('elderly');
  bool get hasChronicCondition => vulnerabilityFlags.contains('chronic');
  bool get isPregnant => vulnerabilityFlags.contains('pregnant');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Patient &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          age == other.age &&
          sex == other.sex &&
          location == other.location &&
          phone == other.phone &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          lastScreenedAt == other.lastScreenedAt &&
          vulnerabilityFlags == other.vulnerabilityFlags &&
          isDemo == other.isDemo &&
          syncStatus == other.syncStatus &&
          retryCount == other.retryCount;

  @override
  int get hashCode => Object.hash(
    id, name, age, sex, location, phone, notes, createdAt, lastScreenedAt, vulnerabilityFlags, isDemo, syncStatus, retryCount
  );

  @override
  String toString() => 'Patient(id: $id, name: $name, age: $age, sex: $sex, location: $location, isDemo: $isDemo)';
}

/// One completed screening: raw vitals, reported symptoms, and the
/// deterministic triage verdict. The AI never writes to [riskLevel] or
/// [riskScore] - see `RiskEngine`.
class Screening {
  final String id;
  final String patientId;
  final String deviceId;
  final DateTime timestamp;

  final int heartRate;
  final int spo2;
  final double temperature;

  /// Rhythm classification from the on-device ECG summary, e.g.
  /// `SINUS_RHYTHM`, `TACHYCARDIA`, `BRADYCARDIA`, `IRREGULAR`, `UNKNOWN`.
  final String ecgRhythm;

  /// 0.0-1.0 signal-quality score. Below 0.5 the rhythm call is not trusted.
  final double ecgQualityScore;
  final int rrIntervalMs;

  final int pttMs;
  final int estimatedSystolic;
  final int estimatedDiastolic;
  final String bpConfidence;
  final DateTime? bpCalibratedAt;

  final List<String> symptoms;
  final String? symptomDuration;
  final String? symptomNotes;

  final String riskLevel;
  final int riskScore;
  final List<String> triggeredRules;
  final String recommendedAction;
  final String escalationLevel;

  final String? aiSummary;
  final String? aiExplanation;

  /// Only ever non-null when the worker consented to location tagging.
  final double? latitude;
  final double? longitude;

  final String syncStatus;
  final int retryCount;
  final bool isDemo;

  const Screening({
    required this.id,
    required this.patientId,
    required this.deviceId,
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    this.ecgRhythm = 'UNKNOWN',
    this.ecgQualityScore = 0.0,
    this.rrIntervalMs = 0,
    this.pttMs = 0,
    this.estimatedSystolic = 0,
    this.estimatedDiastolic = 0,
    this.bpConfidence = 'EXPERIMENTAL',
    this.bpCalibratedAt,
    this.symptoms = const [],
    this.symptomDuration,
    this.symptomNotes,
    required this.riskLevel,
    required this.riskScore,
    this.triggeredRules = const [],
    this.recommendedAction = '',
    this.escalationLevel = 'NONE',
    this.aiSummary,
    this.aiExplanation,
    this.latitude,
    this.longitude,
    this.syncStatus = 'PENDING',
    this.retryCount = 0,
    this.isDemo = false,
  });

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasBpEstimate => estimatedSystolic > 0 && estimatedDiastolic > 0;

  bool get isEcgTrustworthy => ecgQualityScore >= 0.5;

  /// Human-readable signal quality. Never interpolate [ecgQualityScore] raw
  /// into UI text.
  String get ecgQualityLabel {
    if (ecgQualityScore >= 0.85) return 'Excellent';
    if (ecgQualityScore >= 0.7) return 'Good';
    if (ecgQualityScore >= 0.5) return 'Fair';
    if (ecgQualityScore > 0) return 'Poor';
    return 'Not measured';
  }

  factory Screening.fromJson(Map<String, dynamic> json) => Screening(
    id: json['id'] as String,
    patientId: json['patientId'] as String,
    deviceId: json['deviceId'] as String? ?? 'UNKNOWN',
    timestamp: DateTime.parse(json['timestamp'] as String),
    heartRate: json['heartRate'] as int,
    spo2: json['spo2'] as int,
    temperature: (json['temperature'] as num).toDouble(),
    ecgRhythm: json['ecgRhythm'] as String? ?? 'UNKNOWN',
    ecgQualityScore: (json['ecgQualityScore'] as num?)?.toDouble() ?? 0.0,
    rrIntervalMs: json['rrIntervalMs'] as int? ?? 0,
    pttMs: json['pttMs'] as int? ?? 0,
    estimatedSystolic: json['estimatedSystolic'] as int? ?? 0,
    estimatedDiastolic: json['estimatedDiastolic'] as int? ?? 0,
    bpConfidence: json['bpConfidence'] as String? ?? 'EXPERIMENTAL',
    bpCalibratedAt: json['bpCalibratedAt'] != null
        ? DateTime.parse(json['bpCalibratedAt'] as String)
        : null,
    symptoms: (json['symptoms'] as List<dynamic>?)?.cast<String>() ?? const [],
    symptomDuration: json['symptomDuration'] as String?,
    symptomNotes: json['symptomNotes'] as String?,
    riskLevel: json['riskLevel'] as String,
    riskScore: json['riskScore'] as int,
    triggeredRules:
        (json['triggeredRules'] as List<dynamic>?)?.cast<String>() ?? const [],
    recommendedAction: json['recommendedAction'] as String? ?? '',
    escalationLevel: json['escalationLevel'] as String? ?? 'NONE',
    aiSummary: json['aiSummary'] as String?,
    aiExplanation: json['aiExplanation'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    syncStatus: json['syncStatus'] as String? ?? 'PENDING',
    retryCount: json['retryCount'] as int? ?? 0,
    isDemo: json['isDemo'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientId': patientId,
    'deviceId': deviceId,
    'timestamp': timestamp.toIso8601String(),
    'heartRate': heartRate,
    'spo2': spo2,
    'temperature': temperature,
    'ecgRhythm': ecgRhythm,
    'ecgQualityScore': ecgQualityScore,
    'rrIntervalMs': rrIntervalMs,
    'pttMs': pttMs,
    'estimatedSystolic': estimatedSystolic,
    'estimatedDiastolic': estimatedDiastolic,
    'bpConfidence': bpConfidence,
    'bpCalibratedAt': bpCalibratedAt?.toIso8601String(),
    'symptoms': symptoms,
    'symptomDuration': symptomDuration,
    'symptomNotes': symptomNotes,
    'riskLevel': riskLevel,
    'riskScore': riskScore,
    'triggeredRules': triggeredRules,
    'recommendedAction': recommendedAction,
    'escalationLevel': escalationLevel,
    'aiSummary': aiSummary,
    'aiExplanation': aiExplanation,
    'latitude': latitude,
    'longitude': longitude,
    'syncStatus': syncStatus,
    'retryCount': retryCount,
    'isDemo': isDemo,
  };

  Screening copyWith({
    String? id,
    String? patientId,
    String? deviceId,
    DateTime? timestamp,
    int? heartRate,
    int? spo2,
    double? temperature,
    String? ecgRhythm,
    double? ecgQualityScore,
    int? rrIntervalMs,
    int? pttMs,
    int? estimatedSystolic,
    int? estimatedDiastolic,
    String? bpConfidence,
    DateTime? bpCalibratedAt,
    List<String>? symptoms,
    String? symptomDuration,
    String? symptomNotes,
    String? riskLevel,
    int? riskScore,
    List<String>? triggeredRules,
    String? recommendedAction,
    String? escalationLevel,
    String? aiSummary,
    String? aiExplanation,
    double? latitude,
    double? longitude,
    String? syncStatus,
    int? retryCount,
    bool? isDemo,
  }) => Screening(
    id: id ?? this.id,
    patientId: patientId ?? this.patientId,
    deviceId: deviceId ?? this.deviceId,
    timestamp: timestamp ?? this.timestamp,
    heartRate: heartRate ?? this.heartRate,
    spo2: spo2 ?? this.spo2,
    temperature: temperature ?? this.temperature,
    ecgRhythm: ecgRhythm ?? this.ecgRhythm,
    ecgQualityScore: ecgQualityScore ?? this.ecgQualityScore,
    rrIntervalMs: rrIntervalMs ?? this.rrIntervalMs,
    pttMs: pttMs ?? this.pttMs,
    estimatedSystolic: estimatedSystolic ?? this.estimatedSystolic,
    estimatedDiastolic: estimatedDiastolic ?? this.estimatedDiastolic,
    bpConfidence: bpConfidence ?? this.bpConfidence,
    bpCalibratedAt: bpCalibratedAt ?? this.bpCalibratedAt,
    symptoms: symptoms ?? this.symptoms,
    symptomDuration: symptomDuration ?? this.symptomDuration,
    symptomNotes: symptomNotes ?? this.symptomNotes,
    riskLevel: riskLevel ?? this.riskLevel,
    riskScore: riskScore ?? this.riskScore,
    triggeredRules: triggeredRules ?? this.triggeredRules,
    recommendedAction: recommendedAction ?? this.recommendedAction,
    escalationLevel: escalationLevel ?? this.escalationLevel,
    aiSummary: aiSummary ?? this.aiSummary,
    aiExplanation: aiExplanation ?? this.aiExplanation,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    syncStatus: syncStatus ?? this.syncStatus,
    retryCount: retryCount ?? this.retryCount,
    isDemo: isDemo ?? this.isDemo,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Screening && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Screening($id, patient: $patientId, $riskLevel/$riskScore)';
}

class Device {
  final String id;
  final String name;
  final String macAddress;
  final int batteryPercent;
  final bool isConnected;
  final DateTime lastConnectedAt;
  final String firmwareVersion;
  final DateTime? calibrationDate; // for BP calibration
  final bool isDemo;

  const Device({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.batteryPercent,
    required this.isConnected,
    required this.lastConnectedAt,
    this.firmwareVersion = 'UNKNOWN',
    this.calibrationDate,
    this.isDemo = false,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    name: json['name'] as String,
    macAddress: json['macAddress'] as String,
    batteryPercent: json['batteryPercent'] as int,
    isConnected: json['isConnected'] as bool,
    lastConnectedAt: DateTime.parse(json['lastConnectedAt'] as String),
    firmwareVersion: json['firmwareVersion'] as String? ?? 'UNKNOWN',
    calibrationDate: json['calibrationDate'] != null ? DateTime.parse(json['calibrationDate'] as String) : null,
    isDemo: json['isDemo'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'macAddress': macAddress,
    'batteryPercent': batteryPercent,
    'isConnected': isConnected,
    'lastConnectedAt': lastConnectedAt.toIso8601String(),
    'firmwareVersion': firmwareVersion,
    'calibrationDate': calibrationDate?.toIso8601String(),
    'isDemo': isDemo,
  };

  Device copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? batteryPercent,
    bool? isConnected,
    DateTime? lastConnectedAt,
    String? firmwareVersion,
    DateTime? calibrationDate,
    bool? isDemo,
  }) => Device(
    id: id ?? this.id,
    name: name ?? this.name,
    macAddress: macAddress ?? this.macAddress,
    batteryPercent: batteryPercent ?? this.batteryPercent,
    isConnected: isConnected ?? this.isConnected,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    calibrationDate: calibrationDate ?? this.calibrationDate,
    isDemo: isDemo ?? this.isDemo,
  );

  factory Device.demo() => Device(
    id: 'DEMO_DEVICE_001',
    name: 'SwasthyaSetu Demo Device',
    macAddress: 'AA:BB:CC:DD:EE:FF',
    batteryPercent: 85,
    isConnected: true,
    lastConnectedAt: DateTime.now(),
    firmwareVersion: '1.0.0-demo',
    calibrationDate: null,
    isDemo: true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          macAddress == other.macAddress &&
          batteryPercent == other.batteryPercent &&
          isConnected == other.isConnected &&
          lastConnectedAt == other.lastConnectedAt &&
          firmwareVersion == other.firmwareVersion &&
          calibrationDate == other.calibrationDate &&
          isDemo == other.isDemo;

  @override
  int get hashCode => Object.hash(id, name, macAddress, batteryPercent, isConnected, lastConnectedAt, firmwareVersion, calibrationDate, isDemo);

  @override
  String toString() => 'Device(id: $id, name: $name, isConnected: $isConnected, battery: $batteryPercent%)';
}