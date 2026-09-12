import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/early_warning_trajectory.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/vulnerability_persona.dart';
import 'package:swasthyasetu_ai/domain/rules/early_warning_trajectory_engine.dart';

Screening createMockScreening({
  required String id,
  required DateTime timestamp,
  required int hr,
  required int spo2,
  double temp = 36.6,
}) => Screening(
  id: id,
  patientId: 'patient-test',
  deviceId: 'device-test',
  timestamp: timestamp,
  heartRate: hr,
  spo2: spo2,
  temperature: temp,
  riskLevel: 'GREEN',
  riskScore: 0,
  isDemo: true,
);

void main() {
  final now = DateTime(2026, 9, 12, 14, 0);

  group('EarlyWarningTrajectoryEngine', () {
    test('stable vitals and mild environment produce normal trajectory', () {
      final history = [
        createMockScreening(
          id: 's-1',
          timestamp: now.subtract(const Duration(days: 4)),
          hr: 70,
          spo2: 98,
        ),
        createMockScreening(
          id: 's-2',
          timestamp: now.subtract(const Duration(days: 3)),
          hr: 72,
          spo2: 98,
        ),
        createMockScreening(
          id: 's-3',
          timestamp: now.subtract(const Duration(days: 1)),
          hr: 71,
          spo2: 97,
        ),
        createMockScreening(
          id: 's-4',
          timestamp: now.subtract(const Duration(hours: 3)),
          hr: 72,
          spo2: 98,
        ),
      ];

      final env = EnvironmentReading(
        temperatureC: 27.0,
        apparentTemperatureC: 27.0,
        humidityPercent: 45.0,
        pm25: 25.0,
        source: 'live',
        fetchedAt: now,
      );

      final assessment = EarlyWarningTrajectoryEngine.assess(
        history: history,
        environment: env,
        persona: VulnerabilityPersona.generalCommunity,
        currentTime: now,
      );

      expect(assessment.severity, equals(TrajectorySeverity.normal));
      expect(assessment.thermalDebt.impendingHeatCollapse, isFalse);
      expect(assessment.respiratoryCurve.preBronchospasm, isFalse);
      expect(assessment.hasActiveEarlyWarning, isFalse);
    });

    test(
      'climbing resting HR during extreme heat triggers impending heat collapse',
      () {
        // Prior baseline HR: 68-70 bpm. Recent HR: 80 bpm (+10-12 bpm drift).
        // Nighttime screening showing nocturnal recovery deficit (84 bpm).
        final history = [
          createMockScreening(
            id: 's-1',
            timestamp: now.subtract(const Duration(days: 4, hours: 2)),
            hr: 68,
            spo2: 98,
          ),
          createMockScreening(
            id: 's-2',
            timestamp: now.subtract(const Duration(days: 3, hours: 2)),
            hr: 70,
            spo2: 97,
          ),
          createMockScreening(
            id: 's-3',
            timestamp: DateTime(
              now.year,
              now.month,
              now.day - 1,
              23,
              30,
            ), // nocturnal
            hr: 84,
            spo2: 97,
          ),
          createMockScreening(
            id: 's-4',
            timestamp: now.subtract(const Duration(hours: 2)),
            hr: 82,
            spo2: 97,
          ),
        ];

        final hotEnv = EnvironmentReading(
          temperatureC: 41.5,
          apparentTemperatureC: 46.0,
          humidityPercent: 55.0,
          pm25: 35.0,
          source: 'live',
          weatherDescription: 'Severe Heatwave',
          fetchedAt: now,
        );

        final assessment = EarlyWarningTrajectoryEngine.assess(
          history: history,
          environment: hotEnv,
          persona: VulnerabilityPersona.outdoorWorker,
          currentTime: now,
        );

        expect(assessment.thermalDebt.restingHrDriftBpm, greaterThan(8.0));
        expect(assessment.thermalDebt.nocturnalRecoveryDeficit, isTrue);
        expect(assessment.thermalDebt.impendingHeatCollapse, isTrue);
        expect(assessment.severity, equals(TrajectorySeverity.critical));
        expect(assessment.hasActiveEarlyWarning, isTrue);
        expect(
          assessment.actionableEarlyWarning,
          contains('CRITICAL THERMAL STRAIN'),
        );
      },
    );

    test(
      'trailing PM2.5 elevation with gradual SpO2 dip triggers pre-bronchospasm',
      () {
        // Baseline SpO2 4 days ago: 98%. Trailing 48h SpO2: 94.5% (-3.5% drop).
        final history = [
          createMockScreening(
            id: 's-1',
            timestamp: now.subtract(const Duration(days: 4)),
            hr: 72,
            spo2: 98,
          ),
          createMockScreening(
            id: 's-2',
            timestamp: now.subtract(const Duration(days: 3)),
            hr: 74,
            spo2: 98,
          ),
          createMockScreening(
            id: 's-3',
            timestamp: now.subtract(const Duration(hours: 20)),
            hr: 76,
            spo2: 95,
          ),
          createMockScreening(
            id: 's-4',
            timestamp: now.subtract(const Duration(hours: 2)),
            hr: 78,
            spo2: 94,
          ),
        ];

        final smogEnv = EnvironmentReading(
          temperatureC: 22.0,
          apparentTemperatureC: 22.0,
          humidityPercent: 60.0,
          pm25: 220.0, // Severe smog
          source: 'live',
          weatherDescription: 'Toxic Smog Inversion',
          fetchedAt: now,
        );

        final assessment = EarlyWarningTrajectoryEngine.assess(
          history: history,
          environment: smogEnv,
          persona: VulnerabilityPersona.chronicCondition,
          currentTime: now,
        );

        expect(assessment.respiratoryCurve.spo2Drop, greaterThanOrEqualTo(2.5));
        expect(assessment.respiratoryCurve.preBronchospasm, isTrue);
        expect(assessment.severity, equals(TrajectorySeverity.critical));
        expect(assessment.hasActiveEarlyWarning, isTrue);
        expect(
          assessment.actionableEarlyWarning,
          contains('AIRWAY CONSTRICTION RISK'),
        );
      },
    );

    test('post-flood timeline accurately shifts incubation phases', () {
      final history = [
        createMockScreening(
          id: 's-1',
          timestamp: now.subtract(const Duration(hours: 1)),
          hr: 74,
          spo2: 98,
        ),
      ];

      // Day 2 post-flood: Enteric Sentinel
      final assessmentDay2 = EarlyWarningTrajectoryEngine.assess(
        history: history,
        floodInundationDate: now.subtract(const Duration(days: 2)),
        currentTime: now,
      );
      expect(
        assessmentDay2.epidemicIncubation.phase,
        equals(PostDisasterPhase.days1To3Enteric),
      );
      expect(
        assessmentDay2.epidemicIncubation.symptomChecklist,
        contains('Frequent watery diarrhea or vomiting'),
      );

      // Day 6 post-flood: Leptospirosis Watch
      final assessmentDay6 = EarlyWarningTrajectoryEngine.assess(
        history: history,
        floodInundationDate: now.subtract(const Duration(days: 6)),
        currentTime: now,
      );
      expect(
        assessmentDay6.epidemicIncubation.phase,
        equals(PostDisasterPhase.days5To8Leptospirosis),
      );
      expect(
        assessmentDay6.epidemicIncubation.symptomChecklist,
        contains('Severe calf muscle tenderness or back pain'),
      );

      // Day 12 post-flood: Vector-borne Watch
      final assessmentDay12 = EarlyWarningTrajectoryEngine.assess(
        history: history,
        floodInundationDate: now.subtract(const Duration(days: 12)),
        currentTime: now,
      );
      expect(
        assessmentDay12.epidemicIncubation.phase,
        equals(PostDisasterPhase.days10To14VectorBorne),
      );
      expect(
        assessmentDay12.epidemicIncubation.symptomChecklist,
        contains('Sudden high fever with intense retro-orbital pain'),
      );
    });

    test(
      'Invariant 2.5: AI flags never alter deterministic trajectory severity',
      () {
        final history1 = [
          createMockScreening(
            id: 's-1',
            timestamp: now.subtract(const Duration(hours: 2)),
            hr: 75,
            spo2: 97,
          ),
        ];

        final result1 = EarlyWarningTrajectoryEngine.assess(
          history: history1,
          currentTime: now,
        );

        final result2 = EarlyWarningTrajectoryEngine.assess(
          history: history1,
          currentTime: now,
        );

        expect(result1.severity, equals(result2.severity));
        expect(result1.compositeScore, equals(result2.compositeScore));
      },
    );
  });
}
