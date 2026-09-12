import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/rules/disaster_hazard_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

void main() {
  group('DisasterHazardEngine - Hazard Classification', () {
    test('normal baseline returns calm assessment', () {
      final reading = EnvironmentReading(
        temperatureC: 24.0,
        apparentTemperatureC: 24.0,
        humidityPercent: 50.0,
        weatherCode: 0,
        weatherDescription: 'Clear Sky',
        precipitationMm: 0.0,
        windSpeedKmh: 10.0,
        aqiUs: 35,
        pm25: 8.0,
        fetchedAt: DateTime.now(),
        source: 'live',
      );

      final assessment = DisasterHazardEngine.assess(reading: reading);

      expect(assessment.activeHazard, DisasterHazardType.none);
      expect(assessment.severity, DisasterHazardSeverity.normal);
      expect(assessment.isDisasterActive, isFalse);
    });

    test('heavy precipitation triggers flood danger emergency', () {
      final floodReading = EnvironmentReading(
        temperatureC: 22.0,
        apparentTemperatureC: 22.0,
        humidityPercent: 95.0,
        weatherCode: 65, // Heavy Rain
        weatherDescription: 'Heavy Rain',
        precipitationMm: 35.0,
        windSpeedKmh: 20.0,
        fetchedAt: DateTime.now(),
        source: 'live',
      );

      final assessment = DisasterHazardEngine.assess(reading: floodReading);

      expect(assessment.activeHazard, DisasterHazardType.flood);
      expect(assessment.severity, DisasterHazardSeverity.danger);
      expect(assessment.isDisasterActive, isTrue);
      expect(assessment.triggerReason, contains('35.0 mm rain'));
      expect(
        assessment.physiologicalWatchlist,
        anyElement(contains('Tachycardia')),
      );
      expect(
        assessment.immediateConductSteps,
        anyElement(contains('high ground')),
      );
    });

    test('vulnerability lowers flood trigger threshold from 25mm to 15mm', () {
      final borderlineReading = EnvironmentReading(
        temperatureC: 23.0,
        apparentTemperatureC: 23.0,
        humidityPercent: 88.0,
        weatherCode: 63, // Moderate Rain
        weatherDescription: 'Moderate Rain',
        precipitationMm: 18.0,
        windSpeedKmh: 15.0,
        fetchedAt: DateTime.now(),
        source: 'live',
      );

      // Standard population gets warning, not danger
      final standard = DisasterHazardEngine.assess(reading: borderlineReading);
      expect(standard.activeHazard, DisasterHazardType.flood);
      expect(standard.severity, DisasterHazardSeverity.warning);

      // Vulnerable group gets shifted to danger
      final vulnerable = DisasterHazardEngine.assess(
        reading: borderlineReading,
        vulnerabilities: {Vulnerability.elderly},
      );
      expect(vulnerable.activeHazard, DisasterHazardType.flood);
      expect(vulnerable.severity, DisasterHazardSeverity.danger);
    });

    test(
      'rapid barometric drop triggers squall emergency even with null weather API',
      () {
        final assessment = DisasterHazardEngine.assess(
          reading: null,
          barometricDeltaHpa: -4.2, // Sudden 4.2 hPa drop over 3h on BME280
        );

        expect(assessment.activeHazard, DisasterHazardType.flood);
        expect(assessment.severity, DisasterHazardSeverity.danger);
        expect(assessment.headline, contains('Cloudburst / Squall'));
        expect(assessment.triggerReason, contains('-4.2 hPa'));
      },
    );

    test('extreme heat triggers heatwave emergency', () {
      final heatReading = EnvironmentReading(
        temperatureC: 43.0,
        apparentTemperatureC: 46.0,
        humidityPercent: 45.0,
        weatherCode: 0,
        weatherDescription: 'Clear',
        precipitationMm: 0.0,
        windSpeedKmh: 8.0,
        fetchedAt: DateTime.now(),
        source: 'live',
      );

      final assessment = DisasterHazardEngine.assess(reading: heatReading);

      expect(assessment.activeHazard, DisasterHazardType.heatwave);
      expect(assessment.severity, DisasterHazardSeverity.danger);
      expect(assessment.headline, contains('Heatwave'));
      expect(
        assessment.physiologicalWatchlist,
        anyElement(contains('Cardiovascular Drift')),
      );
    });

    test('severe AQI triggers toxic air emergency', () {
      final smogReading = EnvironmentReading(
        temperatureC: 18.0,
        apparentTemperatureC: 18.0,
        humidityPercent: 60.0,
        weatherCode: 45,
        weatherDescription: 'Dense Fog',
        precipitationMm: 0.0,
        windSpeedKmh: 5.0,
        aqiUs: 340,
        pm25: 185.0,
        fetchedAt: DateTime.now(),
        source: 'live',
      );

      final assessment = DisasterHazardEngine.assess(reading: smogReading);

      expect(assessment.activeHazard, DisasterHazardType.severeAirPollution);
      expect(assessment.severity, DisasterHazardSeverity.danger);
      expect(assessment.immediateConductSteps, anyElement(contains('N95')));
      expect(assessment.physiologicalWatchlist, anyElement(contains('SpO2')));
    });

    test('cyclone wind speed triggers storm hazard', () {
      final cycloneReading = EnvironmentReading(
        temperatureC: 26.0,
        apparentTemperatureC: 28.0,
        humidityPercent: 90.0,
        weatherCode: 95,
        weatherDescription: 'Thunderstorm',
        precipitationMm: 12.0,
        windSpeedKmh: 68.0, // Cyclonic gale
        fetchedAt: DateTime.now(),
        source: 'live',
      );

      final assessment = DisasterHazardEngine.assess(reading: cycloneReading);

      expect(assessment.activeHazard, DisasterHazardType.cycloneStorm);
      expect(assessment.severity, DisasterHazardSeverity.danger);
      expect(
        assessment.immediateConductSteps,
        anyElement(contains('interior room')),
      );
    });

    test(
      'manual relief camp override takes precedence during total blackout',
      () {
        final assessment = DisasterHazardEngine.assess(
          reading: null,
          override: DisasterHazardOverride.floodReliefZone,
        );

        expect(assessment.activeHazard, DisasterHazardType.flood);
        expect(assessment.severity, DisasterHazardSeverity.danger);
        expect(assessment.isManualOverride, isTrue);
        expect(assessment.headline, contains('Manual Camp Mode'));
      },
    );
  });

  group('DisasterHazardEngine - Syndromic Surveillance', () {
    test(
      'acute diarrhea with resting tachycardia indicates critical cholera / dehydration risk',
      () {
        const survey = FloodSyndromicSurvey(
          floodwaterExposure: true,
          acuteWateryDiarrhea: true,
        );

        final result = DisasterHazardEngine.evaluateSyndromicSurvey(
          survey,
          heartRateBpm: 112, // Tachycardic
          coreTemperatureC: 37.8,
        );

        expect(result.riskLevel, SyndromicRiskLevel.critical);
        expect(result.requiresImmediateReferral, isTrue);
        expect(result.primaryConcern, contains('Cholera'));
        expect(
          result.clinicalActions,
          anyElement(contains('WHO Oral Rehydration Salts')),
        );
        expect(result.dehydrationScore, greaterThanOrEqualTo(8.0));
      },
    );

    test(
      'floodwater exposure with high fever and calf pain flags suspected leptospirosis',
      () {
        const survey = FloodSyndromicSurvey(
          floodwaterExposure: true,
          acuteWateryDiarrhea: false,
          highFeverMusclePain: true,
        );

        final result = DisasterHazardEngine.evaluateSyndromicSurvey(
          survey,
          heartRateBpm: 88,
          coreTemperatureC: 38.9,
        );

        expect(result.riskLevel, SyndromicRiskLevel.high);
        expect(result.requiresImmediateReferral, isTrue);
        expect(result.primaryConcern, contains('Leptospirosis'));
        expect(result.clinicalActions, anyElement(contains('NDMA guidelines')));
      },
    );

    test(
      'open wound with floodwater contact flags cellulitis risk and tetanus check',
      () {
        const survey = FloodSyndromicSurvey(
          floodwaterExposure: true,
          openWoundsSkinInfection: true,
        );

        final result = DisasterHazardEngine.evaluateSyndromicSurvey(survey);

        expect(result.riskLevel, SyndromicRiskLevel.moderate);
        expect(result.requiresImmediateReferral, isFalse);
        expect(result.primaryConcern, contains('Wound Contamination'));
        expect(result.clinicalActions, anyElement(contains('tetanus')));
      },
    );

    test('hypothermia (< 35.5°C) prepends immediate warming guidance', () {
      const survey = FloodSyndromicSurvey(floodwaterExposure: true);

      final result = DisasterHazardEngine.evaluateSyndromicSurvey(
        survey,
        coreTemperatureC: 34.8,
      );

      expect(result.clinicalActions.first, contains('Hypothermia'));
      expect(result.clinicalActions.first, contains('Remove wet clothes'));
    });

    test(
      'asymptomatic individual produces low risk with safe water reinforcement',
      () {
        const survey = FloodSyndromicSurvey();

        final result = DisasterHazardEngine.evaluateSyndromicSurvey(survey);

        expect(result.riskLevel, SyndromicRiskLevel.low);
        expect(result.requiresImmediateReferral, isFalse);
        expect(result.dehydrationScore, 0.0);
      },
    );
  });

  group('DisasterHazardEngine - Dehydration Index', () {
    test(
      'calculates composite score combining HR drift, vomiting, and ambient heat',
      () {
        final score = DisasterHazardEngine.calculateDehydrationScore(
          currentHr: 104,
          restingBaselineHr: 72, // Delta = 32 bpm (> 25 -> +4.0)
          hasVomitingOrDiarrhea: true, // +3.5
          hasThirstOrDryMouth: true, // +1.5
          ambientTempC: 41.0, // +1.0
        );

        expect(score, closeTo(10.0, 0.1));
      },
    );

    test('resting hydrated state yields zero dehydration score', () {
      final score = DisasterHazardEngine.calculateDehydrationScore(
        currentHr: 68,
        restingBaselineHr: 70,
        ambientTempC: 26.0,
      );

      expect(score, 0.0);
    });
  });
}
