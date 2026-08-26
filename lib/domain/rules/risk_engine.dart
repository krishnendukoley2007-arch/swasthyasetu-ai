/// Deterministic, rules-first triage.
///
/// This file is the only thing in the app permitted to decide a risk band. The
/// language model never writes to [TriageResult.level] or
/// [TriageResult.score] — it is handed a finished assessment and asked to
/// explain it in plain language. That boundary is the safety property the whole
/// design rests on, so keep it: no network calls, no randomness, no clock reads
/// beyond what the caller passes in.
///
/// Scoring is additive with a hard cap of 100, and the band follows from the
/// score alone:
///
/// | score  | band   |
/// |--------|--------|
/// | 0–30   | GREEN  |
/// | 31–60  | YELLOW |
/// | 61–100 | RED    |
///
/// Any rule of [RuleSeverity.critical] additionally *floors* the score at 61,
/// so a single life-threatening reading cannot be averaged away by otherwise
/// normal vitals. Because the floor moves the score rather than overriding the
/// band, `band == bandForScore(score)` always holds — the UI can never show a
/// RED card next to a score of 40.
library;

import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

enum RiskBand {
  green,
  yellow,
  red;

  String get storageValue => switch (this) {
        RiskBand.green => 'GREEN',
        RiskBand.yellow => 'YELLOW',
        RiskBand.red => 'RED',
      };

  String get label => switch (this) {
        RiskBand.green => 'Normal',
        RiskBand.yellow => 'Needs attention',
        RiskBand.red => 'Urgent',
      };

  static RiskBand fromStorage(String raw) => switch (raw) {
        'RED' => RiskBand.red,
        'YELLOW' => RiskBand.yellow,
        _ => RiskBand.green,
      };
}

enum RuleSeverity {
  /// Recorded and shown, contributes no points. Data-quality notes live here:
  /// a bad sensor contact is not a symptom and must not raise a patient's risk.
  advisory,
  warning,
  critical;

  String get label => switch (this) {
        RuleSeverity.advisory => 'Note',
        RuleSeverity.warning => 'Warning',
        RuleSeverity.critical => 'Critical',
      };
}

/// Stable identifiers for every rule. Persisted in `screenings.triggered_rules`
/// alongside the display text and used to look up guideline chunks offline, so
/// renaming one is a migration — add a new id instead.
abstract final class RuleId {
  static const spo2Critical = 'spo2_critical';
  static const spo2Warning = 'spo2_warning';
  static const spo2NotMeasured = 'spo2_not_measured';
  static const hrTachyCritical = 'hr_tachy_critical';
  static const hrTachyWarning = 'hr_tachy_warning';
  static const hrBradyCritical = 'hr_brady_critical';
  static const hrBradyWarning = 'hr_brady_warning';
  static const tempHigh = 'temp_high';
  static const tempFever = 'temp_fever';
  static const tempLow = 'temp_low';
  static const sepsisScreen = 'sepsis_screen';
  static const ecgIrregular = 'ecg_irregular';
  static const ecgPoorQuality = 'ecg_poor_quality';
  static const bpHigh = 'bp_high';
  static const respiratorySymptoms = 'respiratory_symptoms';
  static const redFlagSymptoms = 'red_flag_symptoms';
  static const multipleSymptoms = 'multiple_symptoms';
  static const dehydrationSymptoms = 'dehydration_symptoms';
  static const vulnerabilityElderly = 'vuln_elderly';
  static const vulnerabilityChronic = 'vuln_chronic';
  static const vulnerabilityPregnant = 'vuln_pregnant';
  static const vulnerabilityInfant = 'vuln_infant';
  static const vulnerabilityImmuno = 'vuln_immunocompromised';
}

/// One rule that fired, with everything needed to explain it without
/// re-deriving anything.
class FiredRule {
  final String id;
  final RuleSeverity severity;
  final int points;

  /// Short human-readable headline, e.g. `Oxygen saturation critically low`.
  final String title;

  /// What was measured and what it was compared against.
  final String detail;

  const FiredRule({
    required this.id,
    required this.severity,
    required this.points,
    required this.title,
    required this.detail,
  });

  bool get isCritical => severity == RuleSeverity.critical;

  /// The form persisted in `triggered_rules` and shown in lists.
  String get display => '$title — $detail';

  @override
  String toString() => 'FiredRule($id, +$points, ${severity.name})';
}

/// A complete assessment. Wraps the legacy [TriageResult] so existing screens
/// keep working, while exposing the structured rule list the explanation layer
/// and the guideline retriever need.
class TriageAssessment {
  final RiskBand band;
  final int score;
  final List<FiredRule> firedRules;
  final VitalThresholds thresholds;
  final String recommendedAction;
  final String escalationLevel;
  final HealthSample sample;
  final List<String> symptoms;
  final Set<Vulnerability> flags;
  final bool isDemo;

  const TriageAssessment({
    required this.band,
    required this.score,
    required this.firedRules,
    required this.thresholds,
    required this.recommendedAction,
    required this.escalationLevel,
    required this.sample,
    required this.symptoms,
    required this.flags,
    required this.isDemo,
  });

  List<String> get ruleIds => firedRules.map((r) => r.id).toList();

  List<FiredRule> get criticalRules =>
      firedRules.where((r) => r.isCritical).toList();

  bool get hasCritical => firedRules.any((r) => r.isCritical);

  /// Rules that actually moved the score, worst first — the "why this level"
  /// list. Advisories are excluded because they explain data quality, not risk.
  List<FiredRule> get scoringRules {
    final list = firedRules.where((r) => r.points > 0).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    return list;
  }

  List<FiredRule> get advisories =>
      firedRules.where((r) => r.severity == RuleSeverity.advisory).toList();

  TriageResult toResult() => TriageResult(
        level: band.storageValue,
        score: score,
        triggeredRules: firedRules.map((r) => r.display).toList(),
        recommendedAction: recommendedAction,
        escalationLevel: escalationLevel,
        vitals: {
          'heart_rate': sample.heartRateBpm,
          'spo2': sample.spo2Percent,
          'temperature': sample.temperatureC,
          'ecg_quality': sample.ecgSignalQuality,
        },
        symptoms: symptoms,
        isDemo: isDemo,
      );
}

class RiskEngine {
  const RiskEngine._();

  /// Inclusive upper bound of the GREEN band.
  static const int greenMax = 30;

  /// Inclusive upper bound of the YELLOW band.
  static const int yellowMax = 60;

  /// Score a critical rule floors the total at — the first point of RED.
  static const int criticalFloor = 61;

  static const int maxScore = 100;

  static RiskBand bandForScore(int score) {
    if (score <= greenMax) return RiskBand.green;
    if (score <= yellowMax) return RiskBand.yellow;
    return RiskBand.red;
  }

  /// Symptoms that raise concern on their own, matched case-insensitively
  /// against [AppConstants.symptomOptions].
  static const Set<String> _respiratorySymptoms = {
    'breathlessness',
    'cough',
    'sore throat',
  };

  /// Any one of these is a documented danger sign, not just a data point.
  static const Set<String> _redFlagSymptoms = {
    'chest discomfort',
    'chest pain',
    'confusion',
    'unable to drink',
    'convulsions',
    'severe bleeding',
  };

  static const Set<String> _dehydrationSymptoms = {
    'vomiting',
    'diarrhea',
    'diarrhoea',
    'dizziness',
  };

  // ─────────────────────────────── Entry points ───────────────────────────────

  static TriageAssessment assess({
    required HealthSample sample,
    required List<String> symptoms,
    int age = 30,
    Set<Vulnerability> flags = const {},
  }) {
    final thresholds = VitalThresholds.forPatient(age: age, flags: flags);
    final effectiveFlags = _effectiveFlags(age: age, flags: flags);
    final fired = <FiredRule>[];

    _evaluateOxygen(sample, thresholds, fired);
    _evaluateHeartRate(sample, thresholds, fired);
    _evaluateTemperature(sample, thresholds, fired);
    _evaluateSepsisScreen(sample, thresholds, fired);
    _evaluateEcg(sample, fired);
    _evaluateBloodPressure(sample, fired);
    _evaluateSymptoms(symptoms, fired);
    _evaluateVulnerability(effectiveFlags, fired);

    var score = fired.fold<int>(0, (sum, r) => sum + r.points);
    final hasCritical = fired.any((r) => r.isCritical);
    if (hasCritical && score < criticalFloor) score = criticalFloor;
    score = score.clamp(0, maxScore);

    final band = bandForScore(score);

    return TriageAssessment(
      band: band,
      score: score,
      firedRules: fired,
      thresholds: thresholds,
      recommendedAction: recommendedActionFor(band),
      escalationLevel: escalationLevelFor(band),
      sample: sample,
      symptoms: symptoms,
      flags: effectiveFlags,
      isDemo: sample.isDemo,
    );
  }

  static TriageAssessment assessForPatient({
    required HealthSample sample,
    required List<String> symptoms,
    required Patient patient,
  }) =>
      assess(
        sample: sample,
        symptoms: symptoms,
        age: patient.age,
        flags: Vulnerability.parse(patient.vulnerabilityFlags),
      );

  /// Legacy shape, kept so older call sites compile. Prefer [assess].
  static TriageResult evaluate({
    required HealthSample sample,
    required List<String> symptoms,
    List<String> vulnerabilityFlags = const [],
    int age = 30,
  }) =>
      assess(
        sample: sample,
        symptoms: symptoms,
        age: age,
        flags: Vulnerability.parse(vulnerabilityFlags),
      ).toResult();

  static TriageResult evaluateWithPatient({
    required HealthSample sample,
    required List<String> symptoms,
    required Patient patient,
  }) =>
      assessForPatient(sample: sample, symptoms: symptoms, patient: patient)
          .toResult();

  static Set<Vulnerability> _effectiveFlags({
    required int age,
    required Set<Vulnerability> flags,
  }) {
    final out = {...flags};
    if (age >= 65) out.add(Vulnerability.elderly);
    if (age < 1) out.add(Vulnerability.infant);
    return out;
  }

  // ─────────────────────────────── Rules ───────────────────────────────

  static void _evaluateOxygen(
    HealthSample s,
    VitalThresholds t,
    List<FiredRule> out,
  ) {
    // A zero reading means "not measured", not "no oxygen". Treating it as a
    // value would fire critical hypoxaemia on every unmeasured screening.
    if (s.spo2Percent <= 0) {
      out.add(const FiredRule(
        id: RuleId.spo2NotMeasured,
        severity: RuleSeverity.advisory,
        points: 0,
        title: 'Oxygen saturation not measured',
        detail: 'No usable SpO₂ reading was captured for this screening.',
      ));
      return;
    }

    if (s.spo2Percent < t.spo2Critical) {
      out.add(FiredRule(
        id: RuleId.spo2Critical,
        severity: RuleSeverity.critical,
        points: 45,
        title: 'Oxygen saturation critically low',
        detail: 'Measured ${s.spo2Percent}%, below the '
            '${t.spo2Critical}% critical limit for this patient.',
      ));
    } else if (s.spo2Percent < t.spo2Warning) {
      out.add(FiredRule(
        id: RuleId.spo2Warning,
        severity: RuleSeverity.warning,
        points: 15,
        title: 'Oxygen saturation below normal',
        detail: 'Measured ${s.spo2Percent}%, below the '
            '${t.spo2Warning}% expected minimum for this patient.',
      ));
    }
  }

  static void _evaluateHeartRate(
    HealthSample s,
    VitalThresholds t,
    List<FiredRule> out,
  ) {
    if (s.heartRateBpm <= 0) return;

    if (s.heartRateBpm > t.hrHighCritical) {
      out.add(FiredRule(
        id: RuleId.hrTachyCritical,
        severity: RuleSeverity.critical,
        points: 35,
        title: 'Heart rate severely elevated',
        detail: 'Measured ${s.heartRateBpm} bpm, above the '
            '${t.hrHighCritical} bpm critical limit for this patient.',
      ));
    } else if (s.heartRateBpm > t.hrHighWarning) {
      out.add(FiredRule(
        id: RuleId.hrTachyWarning,
        severity: RuleSeverity.warning,
        points: 10,
        title: 'Heart rate elevated',
        detail: 'Measured ${s.heartRateBpm} bpm, above the '
            '${t.hrHighWarning} bpm expected maximum for this patient.',
      ));
    } else if (s.heartRateBpm < t.hrLowCritical) {
      out.add(FiredRule(
        id: RuleId.hrBradyCritical,
        severity: RuleSeverity.critical,
        points: 35,
        title: 'Heart rate severely low',
        detail: 'Measured ${s.heartRateBpm} bpm, below the '
            '${t.hrLowCritical} bpm critical limit for this patient.',
      ));
    } else if (s.heartRateBpm < t.hrLowWarning) {
      out.add(FiredRule(
        id: RuleId.hrBradyWarning,
        severity: RuleSeverity.warning,
        points: 10,
        title: 'Heart rate low',
        detail: 'Measured ${s.heartRateBpm} bpm, below the '
            '${t.hrLowWarning} bpm expected minimum for this patient.',
      ));
    }
  }

  static void _evaluateTemperature(
    HealthSample s,
    VitalThresholds t,
    List<FiredRule> out,
  ) {
    if (s.temperatureC <= 0) return;

    if (s.temperatureC < t.tempLow) {
      out.add(FiredRule(
        id: RuleId.tempLow,
        severity: RuleSeverity.critical,
        points: 30,
        title: 'Body temperature too low',
        detail: 'Measured ${_temp(s.temperatureC)}, below the '
            '${_temp(t.tempLow)} hypothermia limit.',
      ));
    } else if (s.temperatureC >= t.tempHigh) {
      out.add(FiredRule(
        id: RuleId.tempHigh,
        severity: RuleSeverity.warning,
        points: 25,
        title: 'High fever',
        detail: 'Measured ${_temp(s.temperatureC)}, at or above the '
            '${_temp(t.tempHigh)} high-fever limit for this patient.',
      ));
    } else if (s.temperatureC >= t.tempFever) {
      out.add(FiredRule(
        id: RuleId.tempFever,
        severity: RuleSeverity.warning,
        points: 10,
        title: 'Fever',
        detail: 'Measured ${_temp(s.temperatureC)}, at or above the '
            '${_temp(t.tempFever)} fever limit for this patient.',
      ));
    }
  }

  /// Fever + tachycardia + hypoxaemia together is the classic screen. Firing it
  /// in addition to the individual rules is intentional: the combination carries
  /// information the parts do not.
  static void _evaluateSepsisScreen(
    HealthSample s,
    VitalThresholds t,
    List<FiredRule> out,
  ) {
    if (s.spo2Percent <= 0 || s.heartRateBpm <= 0 || s.temperatureC <= 0) return;

    final feverish = s.temperatureC >= t.tempFever;
    final tachycardic = s.heartRateBpm > t.hrHighWarning;
    final hypoxaemic = s.spo2Percent < t.spo2Warning;

    if (feverish && tachycardic && hypoxaemic) {
      out.add(const FiredRule(
        id: RuleId.sepsisScreen,
        severity: RuleSeverity.critical,
        points: 30,
        title: 'Fever with fast pulse and low oxygen',
        detail: 'All three together can indicate a serious infection spreading '
            'through the body. This combination needs same-day assessment.',
      ));
    }
  }

  static void _evaluateEcg(HealthSample s, List<FiredRule> out) {
    if (s.ecgSignalQuality <= 0) return;

    // Poor contact is a measurement problem. It gets recorded so the reading is
    // not over-trusted, but it adds no risk points — the patient is not sicker
    // because an electrode was dry.
    if (s.ecgSignalQuality < 0.5) {
      out.add(FiredRule(
        id: RuleId.ecgPoorQuality,
        severity: RuleSeverity.advisory,
        points: 0,
        title: 'ECG signal quality poor',
        detail: 'Rhythm analysis is unreliable at this signal quality '
            '(${(s.ecgSignalQuality * 100).round()}%). Re-check electrode '
            'contact and repeat if a rhythm assessment is needed.',
      ));
      return;
    }

    // Only trust an irregularity call when the signal was good enough to make
    // it. rrIntervalMs of 0 means no R-peak pair was measured.
    if (s.rrIntervalMs > 0 && !s.rPeakDetected) {
      out.add(const FiredRule(
        id: RuleId.ecgIrregular,
        severity: RuleSeverity.warning,
        points: 20,
        title: 'Irregular rhythm detected',
        detail: 'The beat-to-beat interval was inconsistent. This is a '
            'screening signal only and needs a proper ECG to interpret.',
      ));
    }
  }

  /// Cuffless BP is explicitly experimental in this build, so it can raise a
  /// warning but never a critical. It must not be the reason someone is sent to
  /// hospital on its own.
  static void _evaluateBloodPressure(HealthSample s, List<FiredRule> out) {
    if (s.estimatedSystolic <= 0 || s.bpConfidence == 'EXPERIMENTAL') return;

    if (s.estimatedSystolic >= 180 || s.estimatedDiastolic >= 110) {
      out.add(FiredRule(
        id: RuleId.bpHigh,
        severity: RuleSeverity.warning,
        points: 20,
        title: 'Estimated blood pressure very high',
        detail: 'Estimated ${s.estimatedSystolic}/${s.estimatedDiastolic} mmHg. '
            'This is an uncalibrated estimate — confirm with a cuff before '
            'acting on it.',
      ));
    }
  }

  static void _evaluateSymptoms(List<String> symptoms, List<FiredRule> out) {
    final normalised = symptoms
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (normalised.isEmpty) return;

    final redFlags =
        normalised.where(_redFlagSymptoms.contains).toList()..sort();
    if (redFlags.isNotEmpty) {
      out.add(FiredRule(
        id: RuleId.redFlagSymptoms,
        severity: RuleSeverity.critical,
        points: 25,
        title: 'Danger sign reported',
        detail: '${_humanList(redFlags)} — reported danger '
            'sign${redFlags.length > 1 ? 's' : ''} that warrant assessment '
            'regardless of the measured vitals.',
      ));
    }

    final respiratory = normalised
        .where(_respiratorySymptoms.contains)
        .where((s) => !_redFlagSymptoms.contains(s))
        .toList()
      ..sort();
    if (respiratory.isNotEmpty) {
      // Capped so a long symptom checklist cannot dominate the measured vitals.
      final points = (respiratory.length * 5).clamp(0, 15);
      out.add(FiredRule(
        id: RuleId.respiratorySymptoms,
        severity: RuleSeverity.warning,
        points: points,
        title: 'Respiratory symptoms reported',
        detail: _humanList(respiratory),
      ));
    }

    final dehydration =
        normalised.where(_dehydrationSymptoms.contains).toList()..sort();
    if (dehydration.length >= 2) {
      out.add(FiredRule(
        id: RuleId.dehydrationSymptoms,
        severity: RuleSeverity.warning,
        points: 15,
        title: 'Possible dehydration',
        detail: '${_humanList(dehydration)} together raise the risk of fluid '
            'loss, especially in hot weather or after flooding.',
      ));
    }

    if (normalised.length >= 3) {
      out.add(FiredRule(
        id: RuleId.multipleSymptoms,
        severity: RuleSeverity.warning,
        points: 10,
        title: 'Several symptoms at once',
        detail: '${normalised.length} symptoms reported together.',
      ));
    }
  }

  static void _evaluateVulnerability(
    Set<Vulnerability> flags,
    List<FiredRule> out,
  ) {
    // Sorted by enum index so the rule list is stable regardless of set order.
    final ordered = flags.toList()..sort((a, b) => a.index.compareTo(b.index));
    for (final flag in ordered) {
      out.add(FiredRule(
        id: _vulnerabilityRuleId(flag),
        severity: RuleSeverity.warning,
        points: flag.riskPoints,
        title: '${flag.label}: thresholds adjusted',
        detail: flag.explanation,
      ));
    }
  }

  static String _vulnerabilityRuleId(Vulnerability v) => switch (v) {
        Vulnerability.elderly => RuleId.vulnerabilityElderly,
        Vulnerability.chronic => RuleId.vulnerabilityChronic,
        Vulnerability.pregnant => RuleId.vulnerabilityPregnant,
        Vulnerability.infant => RuleId.vulnerabilityInfant,
        Vulnerability.immunocompromised => RuleId.vulnerabilityImmuno,
      };

  // ─────────────────────────────── Outputs ───────────────────────────────

  static String recommendedActionFor(RiskBand band) => switch (band) {
        RiskBand.green =>
          'Readings are within the expected range for this patient. Continue '
              'routine monitoring.',
        RiskBand.yellow =>
          'Some readings need attention. Arrange a health-worker or clinic '
              'review, and screen again if anything changes.',
        RiskBand.red =>
          'Readings are concerning. Arrange prompt medical assessment — do not '
              'wait for symptoms to worsen.',
      };

  static String escalationLevelFor(RiskBand band) => switch (band) {
        RiskBand.green => 'NONE',
        RiskBand.yellow => 'CLINIC_VISIT',
        RiskBand.red => 'EMERGENCY',
      };

  static String _temp(double c) => '${c.toStringAsFixed(1)}°C';

  static String _humanList(List<String> items) {
    final capitalised = items.map((s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    }).toList();
    if (capitalised.length == 1) return capitalised.first;
    if (capitalised.length == 2) return '${capitalised[0]} and ${capitalised[1]}';
    return '${capitalised.sublist(0, capitalised.length - 1).join(', ')} '
        'and ${capitalised.last}';
  }

  /// Plain-language description per rule id, used by the offline explainer when
  /// no guideline chunk matches.
  static const Map<String, String> ruleDescriptions = {
    RuleId.spo2Critical:
        'Oxygen saturation below the critical limit means the blood is not '
            'carrying enough oxygen. This needs urgent assessment.',
    RuleId.spo2Warning:
        'Oxygen saturation slightly below normal can be an early sign of a '
            'chest infection or breathing problem.',
    RuleId.hrTachyCritical:
        'A very fast pulse at rest can accompany serious infection, '
            'dehydration, blood loss, or a heart rhythm problem.',
    RuleId.hrTachyWarning:
        'A raised pulse at rest is common with fever, pain, anxiety, or '
            'dehydration, and is worth re-checking when calm.',
    RuleId.hrBradyCritical:
        'A very slow pulse can reduce blood flow to the brain and needs '
            'assessment, particularly with dizziness or fainting.',
    RuleId.hrBradyWarning:
        'A slow pulse can be normal in fit adults, but is worth noting '
            'alongside any dizziness or tiredness.',
    RuleId.tempHigh:
        'High fever increases fluid loss and can indicate a significant '
            'infection.',
    RuleId.tempFever:
        'Fever is the body responding to infection. Fluids, rest, and '
            'monitoring are the first steps.',
    RuleId.tempLow:
        'Low body temperature can follow cold exposure, severe infection, or '
            'shock, and is dangerous in the very young and very old.',
    RuleId.sepsisScreen:
        'Fever, a fast pulse, and low oxygen together can mean an infection is '
            'affecting the whole body. This needs same-day assessment.',
    RuleId.ecgIrregular:
        'An irregular beat-to-beat interval can indicate a rhythm disturbance. '
            'A proper ECG is needed to interpret it.',
    RuleId.ecgPoorQuality:
        'The ECG trace was too noisy to analyse. This says nothing about the '
            'heart — it means the electrodes need better contact.',
    RuleId.spo2NotMeasured:
        'No oxygen reading was captured. Re-seat the finger sensor and repeat '
            'the measurement before relying on this screening.',
    RuleId.bpHigh:
        'A very high blood-pressure estimate should be confirmed with a cuff '
            'before any action is taken.',
    RuleId.respiratorySymptoms:
        'Breathing symptoms alongside abnormal vitals raise the concern for a '
            'chest infection.',
    RuleId.redFlagSymptoms:
        'Certain symptoms are treated as danger signs on their own and warrant '
            'assessment even when vitals look normal.',
    RuleId.multipleSymptoms:
        'Several symptoms together make significant illness more likely than '
            'any one alone.',
    RuleId.dehydrationSymptoms:
        'Vomiting, loose stools, and dizziness together suggest fluid loss. '
            'Oral rehydration is the immediate priority.',
    RuleId.vulnerabilityElderly:
        'Older adults have less physiological reserve, so thresholds are '
            'tightened and fever may be less pronounced.',
    RuleId.vulnerabilityChronic:
        'An existing long-term condition raises the concern attached to the '
            'same set of readings.',
    RuleId.vulnerabilityPregnant:
        'Pregnancy raises resting pulse normally, so heart-rate limits are '
            'raised while fever limits are lowered.',
    RuleId.vulnerabilityInfant:
        'Infants normally have a much faster pulse, and any fever in an infant '
            'is treated as significant.',
    RuleId.vulnerabilityImmuno:
        'A weakened immune system means infection can progress quickly with '
            'fewer outward signs.',
  };

  /// Legacy accessor kept for the debug screen.
  static Map<String, dynamic> getRuleDescriptions() => ruleDescriptions;
}
