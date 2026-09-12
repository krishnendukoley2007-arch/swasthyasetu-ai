import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

/// Pure Dart deterministic rule engine for automated natural hazard classification
/// and adaptive disaster physiological surveillance.
///
/// Strictly zero Flutter UI dependencies.
class DisasterHazardEngine {
  DisasterHazardEngine._();

  /// Rain precipitation thresholds (mm)
  static const double floodRainThresholdStandardMm = 25.0;
  static const double floodRainThresholdVulnerableMm = 15.0;
  static const double waterloggingWatchStandardMm = 12.0;
  static const double waterloggingWatchVulnerableMm = 8.0;

  /// Barometric pressure rapid drop (hPa per 3 hours) indicating squall,
  /// cloudburst, or severe cyclonic depression. Measured by on-board BME280.
  static const double barometricSquallDropHpa = -3.5;

  /// Apparent temperature thresholds (°C)
  static const double heatwaveDangerStandardC = 43.0;
  static const double heatwaveDangerVulnerableC = 39.0;
  static const double heatwaveWarningStandardC = 38.0;
  static const double heatwaveWarningVulnerableC = 34.0;

  /// Air quality AQI thresholds
  static const int aqiHazardousThreshold = 300;
  static const int aqiUnhealthyThreshold = 200;
  static const int aqiSensitiveThreshold = 100;

  /// Wind speed threshold for cyclonic storm (km/h)
  static const double cycloneWindSpeedKmh = 55.0;

  /// Evaluates environmental signals and classifies active disaster hazard.
  static DisasterHazardAssessment assess({
    EnvironmentReading? reading,
    Set<Vulnerability> vulnerabilities = const {},
    double? barometricDeltaHpa,
    DisasterHazardOverride override = DisasterHazardOverride.autoDetect,
  }) {
    // 1. Handle Manual ASHA / Relief Camp Override (crucial for telecom blackouts)
    if (override != DisasterHazardOverride.autoDetect) {
      return _evaluateOverride(override);
    }

    final vulnerable = vulnerabilities.isNotEmpty;

    // 2. Hardware BME280 Barometer Emergency Trigger
    // Even if Open-Meteo API is unreachable or has lag, a rapid barometric drop
    // detected by the local sensor triggers an immediate flood/squall hazard.
    final hasBarometricSquall =
        barometricDeltaHpa != null &&
        barometricDeltaHpa <= barometricSquallDropHpa;

    if (reading == null) {
      if (hasBarometricSquall) {
        return DisasterHazardAssessment(
          activeHazard: DisasterHazardType.flood,
          severity: DisasterHazardSeverity.danger,
          headline: 'Severe Cloudburst / Squall Hazard Detected',
          triggerReason:
              'Rapid barometric pressure drop (${barometricDeltaHpa.toStringAsFixed(1)} hPa in 3h) '
              'detected by on-board SSAI-SENSE BME280 sensor.',
          immediateConductSteps: const [
            'Seek immediate reinforced shelter above ground level.',
            'Expect sudden cloudburst, violent squall, or flash flooding.',
            'Store emergency water and secure waterproof essentials.',
          ],
          physiologicalWatchlist: const [
            'Hypothermia Drop (< 35.5°C)',
            'Trauma & Sudden Falls via MPU6050',
            'Cardiovascular Stress (Tachycardia)',
          ],
          imdAlertLevel: 'RED',
          isManualOverride: false,
        );
      }
      return DisasterHazardAssessment.calm;
    }

    // 3. Flood & Inundation Evaluation
    final rainThreshold = vulnerable
        ? floodRainThresholdVulnerableMm
        : floodRainThresholdStandardMm;

    final isViolentRainCode =
        reading.weatherCode == 65 || // Heavy Rain
        reading.weatherCode == 82 || // Violent Rain Showers
        reading.weatherCode == 96 || // Severe Thunderstorm with Hail
        reading.weatherCode == 99;

    final isSevereFlood =
        reading.precipitationMm >= rainThreshold ||
        isViolentRainCode ||
        hasBarometricSquall;

    if (isSevereFlood) {
      final triggerDetail = hasBarometricSquall
          ? 'Barometric drop ${barometricDeltaHpa.toStringAsFixed(1)} hPa + ${reading.weatherDescription}'
          : '${reading.precipitationMm > 0 ? '${reading.precipitationMm.toStringAsFixed(1)} mm rain' : reading.weatherDescription} (IMD High Inundation Risk)';

      return DisasterHazardAssessment(
        activeHazard: DisasterHazardType.flood,
        severity: DisasterHazardSeverity.danger,
        headline: 'Active Flash Flood & Inundation Emergency',
        triggerReason: triggerDetail,
        immediateConductSteps: const [
          'Move to designated high ground immediately — do not attempt to cross moving water.',
          'Boil all drinking water for at least 1 minute or use chlorine purification tablets.',
          'Administer WHO ORS immediately if experiencing watery diarrhea or vomiting.',
          'Inspect feet and limbs for cuts; avoid stagnant floodwater to prevent Leptospirosis.',
        ],
        physiologicalWatchlist: const [
          'Resting Tachycardia (HR > 100 bpm: Early dehydration or septic infection)',
          'Core Temperature Drop (< 35.5°C: Wet exposure hypothermia)',
          'Core Temperature Spike (> 38.0°C: Waterborne bacterial infection)',
          'Narrowed Pulse Pressure (< 25 mmHg: Hypovolemic shock warning)',
        ],
        imdAlertLevel: reading.imdAlertLevel == 'GREEN'
            ? 'RED'
            : reading.imdAlertLevel,
        isManualOverride: false,
      );
    }

    // 4. Cyclone & Severe Storm Evaluation (High Wind Danger)
    if (reading.windSpeedKmh >= cycloneWindSpeedKmh ||
        (reading.windSpeedKmh >= 40.0 && reading.weatherCode >= 95)) {
      return DisasterHazardAssessment(
        activeHazard: DisasterHazardType.cycloneStorm,
        severity: DisasterHazardSeverity.danger,
        headline: 'Severe Cyclonic Storm & Gale Hazard',
        triggerReason:
            'Violent wind gusts (${reading.windSpeedKmh.toStringAsFixed(1)} km/h) '
            'and severe convective storm activity.',
        immediateConductSteps: const [
          'Shelter in the strongest interior room away from glass windows and tin roofs.',
          'Keep battery radio and torch ready; unplug high-voltage electrical appliances.',
          'If building structure fails, take shelter under sturdy furniture or mattress.',
        ],
        physiologicalWatchlist: const [
          'Panic & Anxiety Induced Tachycardia',
          'Trauma & Sudden Fall Interrupts via MPU6050 IMU',
        ],
        imdAlertLevel: 'RED',
        isManualOverride: false,
      );
    }

    // 5. Moderate Waterlogging Watch
    final watchThreshold = vulnerable
        ? waterloggingWatchVulnerableMm
        : waterloggingWatchStandardMm;
    if (reading.precipitationMm >= watchThreshold ||
        reading.isHeavyRainOrFloodRisk) {
      return DisasterHazardAssessment(
        activeHazard: DisasterHazardType.flood,
        severity: DisasterHazardSeverity.warning,
        headline: 'Heavy Rainfall & Waterlogging Alert',
        triggerReason:
            'Sustained precipitation (${reading.precipitationMm.toStringAsFixed(1)} mm) '
            'elevating waterlogging, pathogen run-off, and drinking water contamination risk.',
        immediateConductSteps: const [
          'Store at least 3 days of clean drinking water in covered containers.',
          'Avoid low-lying underpasses, open stormwater drains, and basement areas.',
          'Keep emergency contact numbers (NDRF 1078, Ambulance 108) offline.',
        ],
        physiologicalWatchlist: const [
          'Resting Heart Rate',
          'Core Body Temperature',
          'Hydration Balance',
        ],
        imdAlertLevel: reading.imdAlertLevel,
        isManualOverride: false,
      );
    }

    // 5. Heatwave Evaluation
    final heatDangerC = vulnerable
        ? heatwaveDangerVulnerableC
        : heatwaveDangerStandardC;
    final heatWarningC = vulnerable
        ? heatwaveWarningVulnerableC
        : heatwaveWarningStandardC;

    if (reading.apparentTemperatureC >= heatDangerC ||
        reading.temperatureC >= 44.0) {
      return DisasterHazardAssessment(
        activeHazard: DisasterHazardType.heatwave,
        severity: DisasterHazardSeverity.danger,
        headline: 'Extreme Heatwave Emergency (Moran PSI > 7.5 Risk)',
        triggerReason:
            'Apparent temperature feels like ${reading.apparentTemperatureC.round()}°C '
            'at ${reading.humidityPercent.round()}% humidity. Extreme thermal storage.',
        immediateConductSteps: const [
          'Stay indoors in well-ventilated, shaded rooms; suspend all strenuous physical activity.',
          'Sip 250 ml water or ORS every 15 minutes even in the absence of thirst.',
          'Apply cool wet cloths to neck, wrists, and ankles to accelerate evaporative cooling.',
          'Emergency: Fainting, confusion, or cessation of sweating -> Call 108 immediately.',
        ],
        physiologicalWatchlist: const [
          'Core Body Temp (> 38.5°C: Critical heat stroke danger)',
          'Cardiovascular Drift (HR climbing > 20 bpm unprovoked by activity)',
          'Autonomic HRV Suppression (RMSSD < 18 ms: Severe thermal strain)',
        ],
        imdAlertLevel: 'RED',
        isManualOverride: false,
      );
    } else if (reading.apparentTemperatureC >= heatWarningC ||
        reading.temperatureC >= 40.0) {
      return DisasterHazardAssessment(
        activeHazard: DisasterHazardType.heatwave,
        severity: DisasterHazardSeverity.warning,
        headline: 'Dangerous Heatwave Alert',
        triggerReason:
            'High environmental thermal load (feels like ${reading.apparentTemperatureC.round()}°C). '
            'Accelerated dehydration and cardiovascular drift risk.',
        immediateConductSteps: const [
          'Drink water regularly every 20-30 minutes; carry oral rehydration salts.',
          'Rest in shade during peak heat hours (11:00 AM - 4:00 PM).',
          'Watch for headache, dizziness, and muscle cramps — early heat exhaustion signs.',
        ],
        physiologicalWatchlist: const [
          'Moran Physiological Strain Index (PSI)',
          'Core Infrared Temp (MLX90614)',
          '15-Minute Hydration Countdown',
        ],
        imdAlertLevel: 'ORANGE',
        isManualOverride: false,
      );
    }

    // 6. Severe Air Pollution / Smog Evaluation
    final aqi = reading.aqiUs;
    if (aqi != null) {
      if (aqi >= aqiHazardousThreshold ||
          (reading.pm25 != null && reading.pm25! >= 150.0)) {
        return DisasterHazardAssessment(
          activeHazard: DisasterHazardType.severeAirPollution,
          severity: DisasterHazardSeverity.danger,
          headline: 'Hazardous Toxic Smog Emergency',
          triggerReason:
              'Extreme particulate pollution (AQI $aqi${reading.pm25 != null ? ', PM2.5 ${reading.pm25!.toStringAsFixed(1)} µg/m³' : ''}).',
          immediateConductSteps: const [
            'Remain indoors with windows and doors tightly sealed; run air purifiers if available.',
            'Wear a tightly fitted N95 respirator if outdoor transit is unavoidable.',
            'Asthma/COPD patients: verify reliever inhaler is within immediate reach.',
            'Use guided pursed-lip breathing if experiencing acute bronchospasm.',
          ],
          physiologicalWatchlist: const [
            'Pulse Oximeter SpO2 (< 93%: Immediate hypoxemia alarm)',
            'Respiratory Rate (> 24 breaths/min: Respiratory distress)',
          ],
          imdAlertLevel: 'RED',
          isManualOverride: false,
        );
      } else if (aqi >= aqiUnhealthyThreshold ||
          (vulnerable && aqi >= aqiSensitiveThreshold)) {
        return DisasterHazardAssessment(
          activeHazard: DisasterHazardType.severeAirPollution,
          severity: DisasterHazardSeverity.warning,
          headline: 'Unhealthy Air Quality Advisory',
          triggerReason:
              'Elevated particulate pollution (AQI $aqi). Respiratory strain on lungs and heart.',
          immediateConductSteps: const [
            'Curtail strenuous outdoor exercise and prolonged exposure.',
            'Wear a protective mask outdoors and keep reliever medications handy.',
          ],
          physiologicalWatchlist: const [
            'Blood Oxygen SpO2',
            'Resting Respiratory Rate',
          ],
          imdAlertLevel: 'ORANGE',
          isManualOverride: false,
        );
      }
    }

    // 7. Normal / Calm Baseline
    return DisasterHazardAssessment(
      activeHazard: DisasterHazardType.none,
      severity: DisasterHazardSeverity.normal,
      headline: 'Normal Environmental Conditions',
      triggerReason: 'No severe meteorological hazard detected.',
      immediateConductSteps: const [
        'Maintain regular hydration and daily routine.',
        'Disaster physiological shield remains on active background watch.',
      ],
      physiologicalWatchlist: const ['Standard resting vitals'],
      imdAlertLevel: reading.imdAlertLevel,
      isManualOverride: false,
    );
  }

  /// Evaluates 4-question waterborne syndromic surveillance during flood disasters.
  static SyndromicTriageResult evaluateSyndromicSurvey(
    FloodSyndromicSurvey survey, {
    int? heartRateBpm,
    double? coreTemperatureC,
  }) {
    final actions = <String>[];
    SyndromicRiskLevel riskLevel;
    String primaryConcern;
    bool referral = false;
    double dehydrationScore = 0.0;

    final hasTachycardia = heartRateBpm != null && heartRateBpm > 100;
    final hasFever = coreTemperatureC != null && coreTemperatureC >= 38.0;
    final hasHypothermia = coreTemperatureC != null && coreTemperatureC < 35.5;

    if (survey.acuteWateryDiarrhea) {
      if (hasTachycardia || hasFever) {
        riskLevel = SyndromicRiskLevel.critical;
        primaryConcern =
            'Severe Acute Dehydration & Probable Waterborne Infection (Cholera / Dysentery)';
        referral = true;
        dehydrationScore = 8.5;
        actions.add(
          'Administer WHO Oral Rehydration Salts (ORS) immediately: 1 full glass after every loose stool.',
        );
        actions.add(
          'Tachycardia (HR $heartRateBpm bpm) indicates hemodynamic fluid depletion. Visit nearest disaster medical camp immediately for intravenous resuscitation.',
        );
        actions.add(
          'Strictly drink only rolling-boiled (≥ 1 min) or chlorinated water; isolate utensils.',
        );
      } else {
        riskLevel = SyndromicRiskLevel.high;
        primaryConcern =
            'Waterborne Acute Gastroenteritis / Moderate Dehydration Risk';
        referral = false;
        dehydrationScore = 6.0;
        actions.add(
          'Start WHO ORS rehydration immediately: sip frequently throughout the day.',
        );
        actions.add(
          'Strictly consume rolling-boiled water (≥ 1 minute) or use chlorine purification tablets.',
        );
        actions.add(
          'Monitor pulse rate and urination frequency. If urine is dark or absent for > 6h, seek urgent care.',
        );
      }
    } else if (survey.highFeverMusclePain && survey.floodwaterExposure) {
      riskLevel = SyndromicRiskLevel.high;
      primaryConcern = 'Suspected Leptospirosis / Floodwater Febrile Syndrome';
      referral = true;
      dehydrationScore = 4.0;
      actions.add(
        'Floodwater contact with high fever and severe calf/back pain is a hallmark clinical indicator of Leptospirosis.',
      );
      actions.add(
        'Report to the relief camp medical officer promptly for diagnostic evaluation and early antibiotic therapy (Doxycycline protocol per NDMA guidelines).',
      );
      actions.add(
        'Avoid NSAIDs like ibuprofen if dengue co-infection is possible; use paracetamol for fever control.',
      );
    } else if (survey.openWoundsSkinInfection && survey.floodwaterExposure) {
      riskLevel = SyndromicRiskLevel.moderate;
      primaryConcern =
          'Floodwater Wound Contamination & Bacterial Cellulitis Risk';
      referral = false;
      dehydrationScore = 2.0;
      actions.add(
        'Wash wounds thoroughly with clean soap and boiled water for at least 5 minutes.',
      );
      actions.add(
        'Apply povidone-iodine antiseptic and keep the limb elevated and dry with a clean waterproof dressing.',
      );
      actions.add(
        'Verify tetanus immunization status at the relief tent if injured by submerged debris.',
      );
    } else if (survey.floodwaterExposure) {
      riskLevel = SyndromicRiskLevel.moderate;
      primaryConcern = 'Floodwater Pathogen Exposure (Asymptomatic)';
      referral = false;
      dehydrationScore = 1.0;
      actions.add(
        'Bathe thoroughly with clean water and soap; dry skin completely to prevent fungal maceration (trench foot).',
      );
      actions.add(
        'Do not consume food that came into contact with floodwater.',
      );
      actions.add('Monitor body temperature daily for the next 7 days.');
    } else {
      riskLevel = SyndromicRiskLevel.low;
      primaryConcern = 'No Active Waterborne Infection Detected';
      referral = false;
      dehydrationScore = 0.0;
      actions.add('Continue boiling or chlorinating all drinking water.');
      actions.add(
        'Maintain protective hand hygiene before handling food or water.',
      );
    }

    if (hasHypothermia) {
      actions.insert(
        0,
        'Core temperature (${coreTemperatureC.toStringAsFixed(1)}°C) indicates Hypothermia. '
        'Remove wet clothes immediately, wrap in dry layered blankets, and drink warm safe fluids.',
      );
    }

    return SyndromicTriageResult(
      riskLevel: riskLevel,
      primaryConcern: primaryConcern,
      clinicalActions: actions,
      requiresImmediateReferral: referral,
      dehydrationScore: dehydrationScore,
    );
  }

  /// Fuses physiological telemetry and subjective symptoms into a quantified
  /// Clinical Dehydration Score (0.0 to 10.0).
  static double calculateDehydrationScore({
    int? currentHr,
    int? restingBaselineHr,
    bool hasThirstOrDryMouth = false,
    bool hasVomitingOrDiarrhea = false,
    double? ambientTempC,
  }) {
    double score = 0.0;

    // 1. Cardiovascular drift component
    if (currentHr != null) {
      final base = restingBaselineHr ?? 72;
      final delta = currentHr - base;
      if (delta > 25) {
        score += 4.0;
      } else if (delta > 15) {
        score += 2.5;
      } else if (delta > 8) {
        score += 1.0;
      }
    }

    // 2. Symptom component
    if (hasVomitingOrDiarrhea) score += 3.5;
    if (hasThirstOrDryMouth) score += 1.5;

    // 3. Ambient heat penalty
    if (ambientTempC != null && ambientTempC > 38.0) {
      score += 1.0;
    }

    return score.clamp(0.0, 10.0);
  }

  static DisasterHazardAssessment _evaluateOverride(
    DisasterHazardOverride override,
  ) {
    return switch (override) {
      DisasterHazardOverride.floodReliefZone => const DisasterHazardAssessment(
        activeHazard: DisasterHazardType.flood,
        severity: DisasterHazardSeverity.danger,
        headline: 'Active Flood Relief Zone (Manual Camp Mode)',
        triggerReason:
            'ASHA / Relief Worker Manual Override: Flood Disaster Protocol Active.',
        immediateConductSteps: [
          'Boil all drinking water for at least 1 minute or use chlorine tablets.',
          'Perform 60-second syndromic check for waterborne diarrhea and leptospirosis.',
          'Administer WHO ORS to anyone experiencing loose stools or vomiting.',
          'Keep feet dry and inspect for cuts or fungal maceration.',
        ],
        physiologicalWatchlist: [
          'Resting Tachycardia (Dehydration & Sepsis)',
          'Core Temp Drop (Hypothermia) or Spike (Infection)',
          'Clinical Dehydration Score',
        ],
        imdAlertLevel: 'RED',
        isManualOverride: true,
      ),
      DisasterHazardOverride.heatwaveEmergencyZone =>
        const DisasterHazardAssessment(
          activeHazard: DisasterHazardType.heatwave,
          severity: DisasterHazardSeverity.danger,
          headline: 'Severe Heatwave Emergency (Manual Camp Mode)',
          triggerReason:
              'ASHA / Relief Worker Manual Override: Heat Emergency Protocol Active.',
          immediateConductSteps: [
            'Stay in shaded or cooled relief shelter.',
            'Enforce mandatory 15-minute hydration cycles (250 ml water/ORS).',
            'Monitor vulnerable elderly and outdoor workers for confusion or cessation of sweating.',
          ],
          physiologicalWatchlist: [
            'Moran Physiological Strain Index (PSI)',
            'Core Infrared Body Temperature',
            'Autonomic RMSSD Suppression',
          ],
          imdAlertLevel: 'RED',
          isManualOverride: true,
        ),
      DisasterHazardOverride.severeSmogZone => const DisasterHazardAssessment(
        activeHazard: DisasterHazardType.severeAirPollution,
        severity: DisasterHazardSeverity.danger,
        headline: 'Severe Toxic Smog Alert (Manual Mode)',
        triggerReason:
            'Manual Hazard Override: Air Pollution Emergency Protocol Active.',
        immediateConductSteps: [
          'Remain indoors with air filtration.',
          'Distribute N95 respirators to vulnerable individuals.',
          'Initiate pursed-lip breathing exercises for respiratory distress.',
        ],
        physiologicalWatchlist: [
          'Blood Oxygen SpO2 (< 93% Alarm)',
          'Respiratory Rate (> 24 breaths/min)',
        ],
        imdAlertLevel: 'RED',
        isManualOverride: true,
      ),
      DisasterHazardOverride.cycloneShelterZone =>
        const DisasterHazardAssessment(
          activeHazard: DisasterHazardType.cycloneStorm,
          severity: DisasterHazardSeverity.danger,
          headline: 'Cyclone Shelter Protocol (Manual Mode)',
          triggerReason:
              'Manual Hazard Override: Cyclonic Storm Shelter Protocol Active.',
          immediateConductSteps: [
            'Remain inside reinforced cyclone shelter until official all-clear.',
            'Keep emergency offline radios active for civil defence updates.',
          ],
          physiologicalWatchlist: [
            'Tachycardia & Panic Stress',
            'Fall & Impact Trauma Detection',
          ],
          imdAlertLevel: 'RED',
          isManualOverride: true,
        ),
      DisasterHazardOverride.forceNormal => DisasterHazardAssessment.calm,
      DisasterHazardOverride.autoDetect => DisasterHazardAssessment.calm,
    };
  }
}
