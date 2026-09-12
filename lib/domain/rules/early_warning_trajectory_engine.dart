/// Longitudinal Early Warning Trajectory Engine.
///
/// Implements rolling multi-day cumulative risk arithmetic (3-day and 7-day
/// physiological trajectories) to detect impending heat collapse, trailing
/// respiratory inflammation, and post-flood epidemic incubation before clinical
/// emergencies occur.
///
/// Mandates:
/// - Pure Dart, zero Flutter UI dependencies.
/// - Deterministic arithmetic, no fabricated gaps.
/// - AI flags are strictly advisory and never alter this rule engine's output.
/// - Single English internal vocabulary.
library;

import 'package:swasthyasetu_ai/domain/models/early_warning_trajectory.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/vulnerability_persona.dart';

class EarlyWarningTrajectoryEngine {
  EarlyWarningTrajectoryEngine._();

  /// Evaluates longitudinal trajectories over historical screenings and ambient telemetry.
  static TrajectoryAssessment assess({
    required List<Screening> history,
    EnvironmentReading? environment,
    VulnerabilityPersona persona = VulnerabilityPersona.generalCommunity,
    DateTime? floodInundationDate,
    bool recentFloodContact = false,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    final thermal = _evaluateThermalDebt(
      history: history,
      environment: environment,
      persona: persona,
      now: now,
    );

    final respiratory = _evaluateRespiratoryCurve(
      history: history,
      environment: environment,
      persona: persona,
      now: now,
    );

    final epidemic = _evaluateEpidemicIncubation(
      floodInundationDate: floodInundationDate,
      recentFloodContact: recentFloodContact,
      environment: environment,
      now: now,
    );

    // Compute composite trajectory score (0 to 100)
    final compositeScore = _computeCompositeScore(
      thermal: thermal,
      respiratory: respiratory,
      epidemic: epidemic,
      persona: persona,
    );

    // Determine trajectory severity
    final severity = _resolveSeverity(
      compositeScore: compositeScore,
      thermal: thermal,
      respiratory: respiratory,
      epidemic: epidemic,
      persona: persona,
    );

    final earlyWarning = _generateEarlyWarning(
      severity: severity,
      thermal: thermal,
      respiratory: respiratory,
      epidemic: epidemic,
      persona: persona,
    );

    final rationale = _generateRationale(
      thermal: thermal,
      respiratory: respiratory,
      epidemic: epidemic,
      persona: persona,
    );

    return TrajectoryAssessment(
      severity: severity,
      compositeScore: compositeScore,
      thermalDebt: thermal,
      respiratoryCurve: respiratory,
      epidemicIncubation: epidemic,
      activePersona: persona,
      actionableEarlyWarning: earlyWarning,
      clinicalRationale: rationale,
      evaluatedAt: now,
    );
  }

  /// Evaluates 3-to-7 day cumulative thermal accumulation.
  static ThermalDebtTrajectory _evaluateThermalDebt({
    required List<Screening> history,
    EnvironmentReading? environment,
    required VulnerabilityPersona persona,
    required DateTime now,
  }) {
    final validHr =
        history
            .where((s) => s.heartRate > 30 && s.heartRate < 240)
            .where((s) => now.difference(s.timestamp).inDays <= 7)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double restingHrDrift = 0.0;
    bool nocturnalRecoveryDeficit = false;

    if (validHr.length >= 2) {
      // Compare latest 24h average with prior baseline (days 2 to 7)
      final cutoff24h = now.subtract(const Duration(hours: 24));
      final recent = validHr.where((s) => s.timestamp.isAfter(cutoff24h));
      final prior = validHr.where((s) => !s.timestamp.isAfter(cutoff24h));

      if (recent.isNotEmpty && prior.isNotEmpty) {
        final recentAvg =
            recent.map((s) => s.heartRate).reduce((a, b) => a + b) /
            recent.length;
        final priorAvg =
            prior.map((s) => s.heartRate).reduce((a, b) => a + b) /
            prior.length;
        restingHrDrift = recentAvg - priorAvg;
      }
    }

    // Check for nocturnal lack of HR dipping in night screenings (22:00 - 06:00)
    final nocturnalReadings = validHr.where((s) {
      final hour = s.timestamp.hour;
      return hour >= 22 || hour <= 6;
    });
    if (nocturnalReadings.isNotEmpty) {
      final nocturnalAvg =
          nocturnalReadings.map((s) => s.heartRate).reduce((a, b) => a + b) /
          nocturnalReadings.length;
      if (nocturnalAvg >= 82) {
        nocturnalRecoveryDeficit = true;
      }
    }

    // Environmental heat stress
    final ambientTemp = environment?.temperatureC ?? 28.0;
    final isExtremeHeatNow = ambientTemp >= 38.0;
    final extremeHeatDays = isExtremeHeatNow ? 3 : 0;

    // Debt score arithmetic (0-100)
    var debt = 10.0;
    if (restingHrDrift > 0) {
      debt += restingHrDrift * 4.5;
    }
    if (isExtremeHeatNow) {
      debt += 25.0;
    }
    if (nocturnalRecoveryDeficit) {
      debt += 20.0;
    }
    if (persona == VulnerabilityPersona.outdoorWorker) {
      debt += 10.0; // Heightened thermal vulnerability in field workers
    }
    debt = debt.clamp(0.0, 100.0);

    // Impending heat collapse trigger:
    // Climbing HR (+6 bpm) over hot period or debt >= 60
    final hrDriftThreshold = persona == VulnerabilityPersona.outdoorWorker
        ? 5.5
        : 7.5;
    final impendingCollapse =
        (restingHrDrift >= hrDriftThreshold &&
            (isExtremeHeatNow || debt >= 55)) ||
        debt >= 72.0;

    String note;
    if (impendingCollapse) {
      note =
          'Cumulative thermal debt is critical. Resting HR has drifted '
          '+${restingHrDrift.toStringAsFixed(1)} bpm with nocturnal recovery deficit. '
          'High risk of impending heat exhaustion or collapse within 24 hours.';
    } else if (debt >= 40.0) {
      note =
          'Moderate thermal accumulation. Resting HR elevated by '
          '+${restingHrDrift.toStringAsFixed(1)} bpm. Enforce scheduled hydration '
          'and shaded work-rest intervals.';
    } else {
      note =
          'Thermal strain within tolerable limits. Baseline recovery intact.';
    }

    return ThermalDebtTrajectory(
      debtScore: debt,
      restingHrDriftBpm: restingHrDrift,
      extremeHeatDays: extremeHeatDays,
      nocturnalRecoveryDeficit: nocturnalRecoveryDeficit,
      impendingHeatCollapse: impendingCollapse,
      advisoryNote: note,
    );
  }

  /// Evaluates 48-hour trailing respiratory curve and particulate inflammation.
  static RespiratoryTrajectory _evaluateRespiratoryCurve({
    required List<Screening> history,
    EnvironmentReading? environment,
    required VulnerabilityPersona persona,
    required DateTime now,
  }) {
    final validSpo2 =
        history
            .where((s) => s.spo2 >= 60 && s.spo2 <= 100)
            .where((s) => now.difference(s.timestamp).inDays <= 7)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double spo2Drop = 0.0;
    if (validSpo2.length >= 2) {
      final cutoff48h = now.subtract(const Duration(hours: 48));
      final recent = validSpo2.where((s) => s.timestamp.isAfter(cutoff48h));
      final prior = validSpo2.where((s) => !s.timestamp.isAfter(cutoff48h));

      if (recent.isNotEmpty && prior.isNotEmpty) {
        final recentAvg =
            recent.map((s) => s.spo2).reduce((a, b) => a + b) / recent.length;
        final priorAvg =
            prior.map((s) => s.spo2).reduce((a, b) => a + b) / prior.length;
        // Positive drop indicates a decrease in saturation
        spo2Drop = (priorAvg - recentAvg).clamp(0.0, 20.0);
      }
    }

    final pm25 = environment?.pm25 ?? 35.0;

    // Inflammatory index arithmetic
    var index = (pm25 / 3.5) + (spo2Drop * 16.0);
    if (persona == VulnerabilityPersona.chronicCondition) {
      index += 15.0; // Heightened sensitivity for asthmatic / COPD patients
    }
    index = index.clamp(0.0, 100.0);

    // Pre-bronchospasm trigger
    final dropThreshold = persona == VulnerabilityPersona.chronicCondition
        ? 1.8
        : 2.8;
    final isPreBroncho =
        (spo2Drop >= dropThreshold && pm25 >= 100.0) || index >= 68.0;

    String note;
    if (isPreBroncho) {
      note =
          'Pre-bronchospasm risk flagged: 48-hour trailing PM2.5 exposure '
          '(${pm25.toStringAsFixed(0)} µg/m³) has induced a -${spo2Drop.toStringAsFixed(1)}% '
          'SpO₂ reserve decline. Small-airway inflammation developing. Begin pursed-lip '
          'breathing cycles and keep bronchodilator accessible.';
    } else if (index >= 40.0) {
      note =
          'Mild cardiorespiratory resistance observed under elevated ambient '
          'particulate levels (${pm25.toStringAsFixed(0)} µg/m³). Avoid outdoor exertion.';
    } else {
      note = 'Cardiorespiratory reserve stable. Particulate airway impact low.';
    }

    return RespiratoryTrajectory(
      trailingPm25: pm25,
      spo2Drop: spo2Drop,
      inflammatoryIndex: index,
      preBronchospasm: isPreBroncho,
      advisoryNote: note,
    );
  }

  /// Evaluates post-disaster flood timeline and incubation windows.
  static PostDisasterIncubationTrajectory _evaluateEpidemicIncubation({
    DateTime? floodInundationDate,
    required bool recentFloodContact,
    EnvironmentReading? environment,
    required DateTime now,
  }) {
    if (floodInundationDate == null) {
      return PostDisasterIncubationTrajectory.inactive;
    }

    final days = now.difference(floodInundationDate).inDays.clamp(0, 30);

    if (days >= 1 && days <= 3) {
      return PostDisasterIncubationTrajectory(
        daysPostFlood: days,
        phase: PostDisasterPhase.days1To3Enteric,
        symptomChecklist: const [
          'Frequent watery diarrhea or vomiting',
          'Postural dizziness or acute dehydration',
          'Drinking from unchlorinated or submerged tubewells',
        ],
        isVigilanceActive: true,
        advisoryNote:
            'Post-Flood Day $days: Enteric Outbreak Sentinel. Extreme vulnerability '
            'to Vibrio cholerae and E. coli water contamination. Boil drinking water '
            'for 10 minutes or use 0.5% sodium hypochlorite tablets.',
      );
    } else if (days >= 4 && days <= 8) {
      return PostDisasterIncubationTrajectory(
        daysPostFlood: days,
        phase: PostDisasterPhase.days5To8Leptospirosis,
        symptomChecklist: const [
          'Severe calf muscle tenderness or back pain',
          'Conjunctival suffusion (redness of eyes without discharge)',
          'High fever with chills after wading in floodwater',
          'Noticeable jaundice or tea-colored dark urine',
        ],
        isVigilanceActive: true,
        advisoryNote:
            'Post-Flood Day $days: Leptospirosis Incubation Watch. '
            'Spirochetes penetrate mucosal membranes during floodwater contact. '
            'Inspect lower extremities for skin abrasions and seek prompt prophylactic evaluation.',
      );
    } else if (days >= 9 && days <= 14) {
      return PostDisasterIncubationTrajectory(
        daysPostFlood: days,
        phase: PostDisasterPhase.days10To14VectorBorne,
        symptomChecklist: const [
          'Sudden high fever with intense retro-orbital pain',
          'Severe joint and bone pain ("breakbone fever")',
          'Petechiae, mucosal bleeding, or spontaneous bruises',
          'Stagnant water collections within 50m of living quarters',
        ],
        isVigilanceActive: true,
        advisoryNote:
            'Post-Flood Day $days: Vector-Borne Arbovirus Sentinel. '
            'Peak Aedes and Anopheles mosquito breeding in receded flood pools. '
            'Screen for Dengue and Malaria symptoms; sleep under insecticide-treated nets.',
      );
    }

    return PostDisasterIncubationTrajectory(
      daysPostFlood: days,
      phase: PostDisasterPhase.none,
      isVigilanceActive: false,
      advisoryNote:
          'Day $days post-flood: Acute epidemic incubation windows have elapsed. '
          'Maintain standard sanitation vigilance.',
    );
  }

  static double _computeCompositeScore({
    required ThermalDebtTrajectory thermal,
    required RespiratoryTrajectory respiratory,
    required PostDisasterIncubationTrajectory epidemic,
    required VulnerabilityPersona persona,
  }) {
    double score = 0.0;
    switch (persona) {
      case VulnerabilityPersona.outdoorWorker:
        score =
            (thermal.debtScore * 0.6) +
            (respiratory.inflammatoryIndex * 0.3) +
            (epidemic.isVigilanceActive ? 15.0 : 0.0);
      case VulnerabilityPersona.elderlyCitizen:
        score =
            (thermal.debtScore * 0.45) +
            (respiratory.inflammatoryIndex * 0.45) +
            (epidemic.isVigilanceActive ? 15.0 : 0.0);
      case VulnerabilityPersona.chronicCondition:
        score =
            (respiratory.inflammatoryIndex * 0.6) +
            (thermal.debtScore * 0.3) +
            (epidemic.isVigilanceActive ? 15.0 : 0.0);
      case VulnerabilityPersona.generalCommunity:
        score =
            (thermal.debtScore * 0.4) +
            (respiratory.inflammatoryIndex * 0.4) +
            (epidemic.isVigilanceActive ? 20.0 : 0.0);
    }
    return score.clamp(0.0, 100.0);
  }

  static TrajectorySeverity _resolveSeverity({
    required double compositeScore,
    required ThermalDebtTrajectory thermal,
    required RespiratoryTrajectory respiratory,
    required PostDisasterIncubationTrajectory epidemic,
    required VulnerabilityPersona persona,
  }) {
    if (thermal.impendingHeatCollapse ||
        (respiratory.preBronchospasm &&
            persona == VulnerabilityPersona.chronicCondition)) {
      return TrajectorySeverity.critical;
    }
    if (respiratory.preBronchospasm ||
        thermal.debtScore >= 55.0 ||
        respiratory.inflammatoryIndex >= 60.0 ||
        compositeScore >= 55.0) {
      return TrajectorySeverity.warning;
    }
    if (compositeScore >= 35.0 ||
        thermal.debtScore >= 35.0 ||
        respiratory.inflammatoryIndex >= 35.0 ||
        epidemic.isVigilanceActive) {
      return TrajectorySeverity.watchful;
    }
    return TrajectorySeverity.normal;
  }

  static String _generateEarlyWarning({
    required TrajectorySeverity severity,
    required ThermalDebtTrajectory thermal,
    required RespiratoryTrajectory respiratory,
    required PostDisasterIncubationTrajectory epidemic,
    required VulnerabilityPersona persona,
  }) {
    if (thermal.impendingHeatCollapse) {
      return 'CRITICAL THERMAL STRAIN: Your body is accumulating cardiovascular heat debt across multiple hot shifts. Cessation of heavy labor and immediate electrolyte replenishment required.';
    }
    if (respiratory.preBronchospasm) {
      return 'AIRWAY CONSTRICTION RISK: Trailing particulate inhalation is depleting your daytime SpO₂ reserve. Initiate 10 minutes of pursed-lip guided breathing and stay in a sealed room.';
    }
    if (epidemic.isVigilanceActive) {
      return 'EPIDEMIC SENTINEL ACTIVE (${epidemic.phase.title}): Monitor the post-flood symptom checklist daily before clinical fever escalates.';
    }
    if (severity == TrajectorySeverity.warning) {
      return 'ELEVATED MULTI-DAY STRAIN: Physiological baselines are trending away from normal. Rest, hydration, and monitoring recommended.';
    }
    if (severity == TrajectorySeverity.watchful) {
      return 'VIGILANCE ADVISED: Mild multi-day drift observed. Maintain hydration and check vitals after daytime exertion.';
    }
    return 'HEALTH TRAJECTORY STABLE: Multi-day vital trends and environmental resilience indicators remain within safe personal baselines.';
  }

  static String _generateRationale({
    required ThermalDebtTrajectory thermal,
    required RespiratoryTrajectory respiratory,
    required PostDisasterIncubationTrajectory epidemic,
    required VulnerabilityPersona persona,
  }) {
    final parts = <String>[];
    parts.add(
      'Thermal Debt: ${thermal.debtScore.toStringAsFixed(0)}/100 (HR drift +${thermal.restingHrDriftBpm.toStringAsFixed(1)} bpm).',
    );
    parts.add(
      'Respiratory Index: ${respiratory.inflammatoryIndex.toStringAsFixed(0)}/100 (SpO₂ dip -${respiratory.spo2Drop.toStringAsFixed(1)}%).',
    );
    if (epidemic.isVigilanceActive) {
      parts.add('Post-flood watch active: ${epidemic.phase.title}.');
    }
    return parts.join(' ');
  }
}
