/// Models for the automated disaster hazard detection and adaptive physiological shield.
///
/// Pure Dart — strictly zero Flutter UI dependencies.
library disaster_hazard;

/// Environmental hazard classification.
enum DisasterHazardType {
  none,
  flood,
  heatwave,
  severeAirPollution,
  cycloneStorm,
}

/// Clinical & civil defence severity of the hazard.
enum DisasterHazardSeverity { normal, advisory, warning, danger }

/// Manual override for field operation, drills, or relief camps in complete telecom blackout.
enum DisasterHazardOverride {
  autoDetect,
  floodReliefZone,
  heatwaveEmergencyZone,
  severeSmogZone,
  cycloneShelterZone,
  forceNormal,
}

/// 4-question waterborne & flood syndromic surveillance inputs.
class FloodSyndromicSurvey {
  final bool floodwaterExposure;
  final bool acuteWateryDiarrhea;
  final bool highFeverMusclePain;
  final bool openWoundsSkinInfection;

  const FloodSyndromicSurvey({
    this.floodwaterExposure = false,
    this.acuteWateryDiarrhea = false,
    this.highFeverMusclePain = false,
    this.openWoundsSkinInfection = false,
  });

  bool get hasAnySymptom =>
      acuteWateryDiarrhea || highFeverMusclePain || openWoundsSkinInfection;

  Map<String, dynamic> toJson() => {
    'floodwaterExposure': floodwaterExposure,
    'acuteWateryDiarrhea': acuteWateryDiarrhea,
    'highFeverMusclePain': highFeverMusclePain,
    'openWoundsSkinInfection': openWoundsSkinInfection,
  };

  factory FloodSyndromicSurvey.fromJson(Map<String, dynamic> json) =>
      FloodSyndromicSurvey(
        floodwaterExposure: json['floodwaterExposure'] as bool? ?? false,
        acuteWateryDiarrhea: json['acuteWateryDiarrhea'] as bool? ?? false,
        highFeverMusclePain: json['highFeverMusclePain'] as bool? ?? false,
        openWoundsSkinInfection:
            json['openWoundsSkinInfection'] as bool? ?? false,
      );

  FloodSyndromicSurvey copyWith({
    bool? floodwaterExposure,
    bool? acuteWateryDiarrhea,
    bool? highFeverMusclePain,
    bool? openWoundsSkinInfection,
  }) {
    return FloodSyndromicSurvey(
      floodwaterExposure: floodwaterExposure ?? this.floodwaterExposure,
      acuteWateryDiarrhea: acuteWateryDiarrhea ?? this.acuteWateryDiarrhea,
      highFeverMusclePain: highFeverMusclePain ?? this.highFeverMusclePain,
      openWoundsSkinInfection:
          openWoundsSkinInfection ?? this.openWoundsSkinInfection,
    );
  }
}

/// Risk grading from post-flood syndromic check.
enum SyndromicRiskLevel { low, moderate, high, critical }

/// Clinical recommendations and triage output for syndromic screening.
class SyndromicTriageResult {
  final SyndromicRiskLevel riskLevel;
  final String primaryConcern;
  final List<String> clinicalActions;
  final bool requiresImmediateReferral;
  final double? dehydrationScore; // 0 to 10

  const SyndromicTriageResult({
    required this.riskLevel,
    required this.primaryConcern,
    required this.clinicalActions,
    required this.requiresImmediateReferral,
    this.dehydrationScore,
  });
}

/// Complete contextual assessment produced by [DisasterHazardEngine].
class DisasterHazardAssessment {
  final DisasterHazardType activeHazard;
  final DisasterHazardSeverity severity;
  final String headline;
  final String triggerReason;
  final List<String> immediateConductSteps;
  final List<String> physiologicalWatchlist;
  final String? imdAlertLevel;
  final bool isManualOverride;

  const DisasterHazardAssessment({
    required this.activeHazard,
    required this.severity,
    required this.headline,
    required this.triggerReason,
    required this.immediateConductSteps,
    required this.physiologicalWatchlist,
    this.imdAlertLevel,
    this.isManualOverride = false,
  });

  bool get isDisasterActive => activeHazard != DisasterHazardType.none;

  static const DisasterHazardAssessment calm = DisasterHazardAssessment(
    activeHazard: DisasterHazardType.none,
    severity: DisasterHazardSeverity.normal,
    headline: 'Normal Environmental Conditions',
    triggerReason: 'No meteorological or sensor-based hazard active.',
    immediateConductSteps: [
      'Maintain standard hydration and daily routine.',
      'Disaster physiological shield remains on standby.',
    ],
    physiologicalWatchlist: ['Standard resting vitals'],
    imdAlertLevel: 'GREEN',
    isManualOverride: false,
  );
}
