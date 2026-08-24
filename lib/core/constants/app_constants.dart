class AppConstants {
  static const String appName = 'SwasthyaSetu AI';
  static const String appSubtitle = 'AI-Powered Smart Health Monitoring & Community Early-Warning Platform';

  /// Kept in step with `pubspec.yaml` by hand — nothing generates it at build
  /// time here, so bumping one means bumping the other.
  static const String appVersion = '1.1.0';
  static const int appBuildNumber = 2;

  static const String deviceServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String deviceInfoCharUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String liveVitalsCharUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  static const String ecgStreamCharUuid = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';
  static const String controlCharUuid = '6e400005-b5a3-f393-e0a9-e50e24dcca9e';
  static const String statusCharUuid = '6e400006-b5a3-f393-e0a9-e50e24dcca9e';
  
  static const int ecgSamplingRate = 250;
  static const int ppgSamplingRate = 100;
  
  static const Duration bleScanTimeout = Duration(seconds: 10);
  static const Duration syncRetryBaseDelay = Duration(seconds: 5);
  static const int maxSyncRetries = 5;
  
  static const String demoModePrefix = 'DEMO_';
  
  static const List<String> symptomOptions = [
    'Fever',
    'Cough',
    'Dizziness',
    'Headache',
    'Breathlessness',
    'Chest discomfort',
    'Fatigue',
    'Vomiting',
    'Diarrhea',
    'Body pain',
    'Sore throat',
    'Other',
  ];
  
  static const Map<String, double> riskThresholds = {
    'spo2_critical': 90,
    'spo2_warning': 95,
    'hr_critical': 130,
    'hr_warning': 100,
    'temp_fever': 38.0,
    'temp_high': 39.0,
  };
}