import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/domain/rules/health_report.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';

UserAccount account({
  int? age = 29,
  String sex = 'F',
  double? height = 158,
  double? weight = 54,
  List<String> conditions = const ['Diabetes'],
  String? problems = 'dizzy since morning',
}) =>
    UserAccount(
      id: 'acc-1',
      email: 'mira@example.com',
      displayName: 'Mira Das',
      role: UserRole.patient,
      provider: AuthAccountProvider.email,
      age: age,
      sex: sex,
      heightCm: height,
      weightKg: weight,
      conditions: conditions,
      problems: problems,
      profileComplete: true,
      patientId: 'p1',
      createdAt: DateTime(2026, 1, 1),
      lastLoginAt: DateTime(2026, 8, 25),
    );

Patient patient() => Patient(
      id: 'p1',
      name: 'Mira Das',
      age: 29,
      sex: 'F',
      createdAt: DateTime(2026, 8, 1),
    );

Screening screening() => Screening(
      id: 's1',
      patientId: 'p1',
      deviceId: 'd1',
      timestamp: DateTime(2026, 8, 25, 11),
      heartRate: 87,
      spo2: 96,
      temperature: 37.4,
      ecgRhythm: 'SINUS_RHYTHM',
      ecgQualityScore: 0.9,
      rrIntervalMs: 690,
      symptoms: const ['Dizziness'],
      riskLevel: 'YELLOW',
      riskScore: 18,
      recommendedAction: 'Rest, hydrate, recheck tomorrow',
    );

void main() {
  group('HealthReport', () {
    test('contains identity, numbers, band and the disclaimer', () {
      final text = HealthReport.build(
        account: account(),
        patient: patient(),
        latest: screening(),
      );

      expect(text, contains('Mira Das'));
      expect(text, contains('29'));
      expect(text, contains('Diabetes'));
      expect(text, contains('Heart rate: 87 bpm'));
      expect(text, contains('SpO₂: 96%'));
      expect(text, contains('Temperature: 37.4 °C'));
      expect(text, contains('Triage band: YELLOW (score 18)'));
      expect(text, contains('Rest, hydrate, recheck tomorrow'));
      expect(text, contains('Symptoms: Dizziness'));
      expect(text.toLowerCase(), contains('not a medical diagnosis'));
    });

    test('experimental BP is labelled, not laundered as fact', () {
      final withBp = screening().copyWith(
        estimatedSystolic: 138,
        estimatedDiastolic: 88,
      );
      final text = HealthReport.build(
        account: account(),
        patient: patient(),
        latest: withBp,
      );
      expect(text, contains('EXPERIMENTAL'));
      expect(text, contains('138/88'));
    });

    test('trend notes and environment appear when present', () {
      final text = HealthReport.build(
        account: account(),
        patient: patient(),
        latest: screening(),
        trendNotes: const [
          BaselineNote('hr', 13, significant: true),
          BaselineNote('spo2', -3, significant: true),
        ],
        environment: EnvironmentReading(
          temperatureC: 39,
          apparentTemperatureC: 44,
          humidityPercent: 78,
          aqiUs: 121,
          fetchedAt: DateTime(2026, 8, 25, 10),
          source: 'cached',
        ),
      );

      expect(text, contains('13 bpm above usual'));
      expect(text, contains('3 pts below usual'));
      expect(text, contains('Feels like 44°C'));
      expect(text, contains('AQI 121'));
    });

    test('absent fields are omitted cleanly, never rendered as placeholders',
        () {
      final minimal = HealthReport.build(
        account: account(
          age: null,
          sex: '',
          height: null,
          weight: null,
          conditions: const [],
          problems: null,
        ),
        patient: patient(),
        latest: screening().copyWith(symptoms: const []),
      );

      expect(minimal, isNot(contains('Pre-existing')));
      expect(minimal, isNot(contains('Age:')));
      expect(minimal, isNot(contains('Build:')));
      expect(minimal, isNot(contains('Symptoms:')));
      expect(minimal, isNot(contains('TREND')));
      expect(minimal, isNot(contains('ENVIRONMENT')));
      // Identity and band still survive — they are why the report exists.
      expect(minimal, contains('Mira Das'));
      expect(minimal, contains('YELLOW'));
    });
  });
}
