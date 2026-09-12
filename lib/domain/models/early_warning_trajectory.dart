/// Domain models for the Longitudinal Early Warning Trajectory Engine.
///
/// Pure Dart: zero Flutter UI dependencies.
library;

import 'package:swasthyasetu_ai/domain/models/vulnerability_persona.dart';

/// Severity of the cumulative multi-day trajectory.
enum TrajectorySeverity {
  /// All physiological metrics within stable personal baselines.
  normal,

  /// Mild cumulative drift observed; continuous monitoring recommended.
  watchful,

  /// Significant physiological strain accumulating; early intervention needed.
  warning,

  /// Critical trajectory deviation; immediate cessation of exertion or clinical referral.
  critical;

  String get label => switch (this) {
    TrajectorySeverity.normal => 'Baseline Stable',
    TrajectorySeverity.watchful => 'Vigilance Advised',
    TrajectorySeverity.warning => 'Early Warning (Elevated)',
    TrajectorySeverity.critical => 'Impending Emergency Alert',
  };

  bool get isElevated =>
      this == TrajectorySeverity.warning || this == TrajectorySeverity.critical;
}

/// Post-flood epidemic incubation timeline phases.
enum PostDisasterPhase {
  none,

  /// Days 1–3: Acute Enteric & Dehydration sentinel (Cholera, E. coli).
  days1To3Enteric,

  /// Days 5–8: Spirochete & Leptospirosis watch (after floodwater contact).
  days5To8Leptospirosis,

  /// Days 10–14: Vector-borne sentinel (Dengue, Malaria in stagnant pools).
  days10To14VectorBorne;

  String get title => switch (this) {
    PostDisasterPhase.none => 'No Active Flood Watch',
    PostDisasterPhase.days1To3Enteric => 'Days 1–3: Acute Enteric Sentinel',
    PostDisasterPhase.days5To8Leptospirosis =>
      'Days 5–8: Leptospirosis Incubation Watch',
    PostDisasterPhase.days10To14VectorBorne =>
      'Days 10–14: Vector-Borne Outbreak Watch',
  };
}

/// Trajectory of cumulative thermal strain over 3 to 7 days.
class ThermalDebtTrajectory {
  /// Estimated cumulative thermal debt index (0 to 100).
  final double debtScore;

  /// Day-over-day upward drift in resting heart rate (bpm).
  final double restingHrDriftBpm;

  /// Count of consecutive days with high ambient thermal exposure (>38°C).
  final int extremeHeatDays;

  /// True if nocturnal HR fails to drop by at least 10% below daytime baseline.
  final bool nocturnalRecoveryDeficit;

  /// Flags impending heat exhaustion/collapse 24h prior to clinical breakdown.
  final bool impendingHeatCollapse;

  /// Plain-language clinical advisory.
  final String advisoryNote;

  const ThermalDebtTrajectory({
    required this.debtScore,
    required this.restingHrDriftBpm,
    required this.extremeHeatDays,
    required this.nocturnalRecoveryDeficit,
    required this.impendingHeatCollapse,
    required this.advisoryNote,
  });

  static const normal = ThermalDebtTrajectory(
    debtScore: 12.0,
    restingHrDriftBpm: 0.0,
    extremeHeatDays: 0,
    nocturnalRecoveryDeficit: false,
    impendingHeatCollapse: false,
    advisoryNote: 'Normal thermal balance. No cumulative heat strain detected.',
  );
}

/// Trajectory of cardiorespiratory strain following smog / particulate exposure.
class RespiratoryTrajectory {
  /// Trailing 48-hour PM2.5 particulate concentration (µg/m³).
  final double trailingPm25;

  /// SpO₂ baseline drop (percentage points) over the trailing 48 hours.
  /// (e.g. -2.5 indicates a 2.5% decrease).
  final double spo2Drop;

  /// Small-airway inflammatory index (0 to 100).
  final double inflammatoryIndex;

  /// Flags pre-bronchospasm / micro-airway constriction prior to acute asthma attack.
  final bool preBronchospasm;

  /// Plain-language clinical advisory.
  final String advisoryNote;

  const RespiratoryTrajectory({
    required this.trailingPm25,
    required this.spo2Drop,
    required this.inflammatoryIndex,
    required this.preBronchospasm,
    required this.advisoryNote,
  });

  static const normal = RespiratoryTrajectory(
    trailingPm25: 35.0,
    spo2Drop: 0.0,
    inflammatoryIndex: 10.0,
    preBronchospasm: false,
    advisoryNote:
        'Respiratory reserve intact. Minimal ambient particulate load.',
  );
}

/// Trajectory of post-disaster flood and waterborne/vector incubation.
class PostDisasterIncubationTrajectory {
  /// Days elapsed since the recorded flood event (if active).
  final int? daysPostFlood;

  /// Current timeline phase.
  final PostDisasterPhase phase;

  /// Active symptom checklist for user/worker inquiry.
  final List<String> symptomChecklist;

  /// Whether current phase warrants proactive screening.
  final bool isVigilanceActive;

  /// Plain-language clinical advisory.
  final String advisoryNote;

  const PostDisasterIncubationTrajectory({
    this.daysPostFlood,
    required this.phase,
    this.symptomChecklist = const [],
    required this.isVigilanceActive,
    required this.advisoryNote,
  });

  static const inactive = PostDisasterIncubationTrajectory(
    phase: PostDisasterPhase.none,
    isVigilanceActive: false,
    advisoryNote: 'No active flood inundation watch in this region.',
  );
}

/// Comprehensive multi-day trajectory evaluation for a user.
class TrajectoryAssessment {
  final TrajectorySeverity severity;
  final double compositeScore;
  final ThermalDebtTrajectory thermalDebt;
  final RespiratoryTrajectory respiratoryCurve;
  final PostDisasterIncubationTrajectory epidemicIncubation;
  final VulnerabilityPersona activePersona;
  final String actionableEarlyWarning;
  final String clinicalRationale;
  final DateTime evaluatedAt;

  const TrajectoryAssessment({
    required this.severity,
    required this.compositeScore,
    required this.thermalDebt,
    required this.respiratoryCurve,
    required this.epidemicIncubation,
    required this.activePersona,
    required this.actionableEarlyWarning,
    required this.clinicalRationale,
    required this.evaluatedAt,
  });

  /// True when the assessment calls for immediate proactive rest or medical check.
  bool get hasActiveEarlyWarning =>
      severity == TrajectorySeverity.warning ||
      severity == TrajectorySeverity.critical ||
      thermalDebt.impendingHeatCollapse ||
      respiratoryCurve.preBronchospasm;
}
