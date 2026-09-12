/// Builds an explanation with no network, from the rules that actually fired
/// plus retrieved guideline text.
///
/// The hard constraint from the design: **the rules engine decides the band, the
/// explanation only explains it.** Nothing here can change a score, a band, or a
/// recommended action — it reads the assessment and puts it into sentences. That
/// is also why this is a pure function over [TriageAssessment] rather than a
/// model call: the output is auditable, identical every time, and cannot
/// hallucinate a different triage decision than the one on the screen.
///
/// The templates are deliberately plain. A worker reading this is standing in a
/// doorway with a phone in one hand.
library;

import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/triage_result.dart';
import 'package:swasthyasetu_ai/domain/rules/guideline_retriever.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

class OfflineExplainer {
  static const String disclaimer =
      'This is a screening aid, not a diagnosis. The risk level comes from fixed '
      'clinical rules, not from AI. A qualified health professional must review '
      'any concerning result.';

  /// Text used for the retrieval query.
  ///
  /// Built from what the screening measured rather than from free text, so the
  /// query vocabulary matches the corpus vocabulary by construction.
  static String queryFor(TriageAssessment assessment) {
    final parts = <String>[
      for (final rule in assessment.firedRules) '${rule.title} ${rule.detail}',
      ...assessment.symptoms,
      for (final flag in assessment.flags) flag.id,
    ];
    return parts.join(' ');
  }

  static AIExplanation build({
    required TriageAssessment assessment,
    List<RetrievedChunk> retrieved = const [],
    String? patientName,
  }) {
    final band = assessment.band;
    final who = (patientName == null || patientName.trim().isEmpty)
        ? 'This person'
        : patientName.trim();

    return AIExplanation(
      summary: _summary(assessment, who),
      whyThisLevel: _whyThisLevel(assessment),
      safeNextSteps: _nextSteps(assessment, retrieved),
      whenToEscalate: _whenToEscalate(band, assessment),
      questionsToAsk: _questions(assessment),
      disclaimer: retrieved.isEmpty
          ? '$disclaimer\n\nOffline explanation — no internet was available, so '
                'this was written from the app\'s built-in rules.'
          : '$disclaimer\n\nOffline explanation, drawn from: '
                '${retrieved.map((r) => r.chunk.citation).join('; ')}.',
      isDemo: assessment.isDemo,
    );
  }

  static String _summary(TriageAssessment assessment, String who) {
    final s = assessment.sample;
    final vitalsList = <String>[
      'heart rate ${s.heartRateBpm} beats per minute',
      'oxygen ${s.spo2Percent}%',
      'temperature ${s.temperatureC.toStringAsFixed(1)}°C',
    ];
    if (s.estimatedGlucose > 0) {
      vitalsList.add('blood glucose ${s.estimatedGlucose} mg/dL');
    }
    if (s.estimatedSystolic > 0 && s.estimatedDiastolic > 0) {
      vitalsList.add(
        'blood pressure ${s.estimatedSystolic}/${s.estimatedDiastolic} mmHg',
      );
    }
    final vitals = vitalsList.join(', ');

    final scoring = assessment.scoringRules;

    return switch (assessment.band) {
      RiskBand.green =>
        '$who screened as normal. Measured $vitals, and nothing '
            'crossed a screening threshold.',
      RiskBand.yellow =>
        '$who needs attention, though not urgently. Measured '
            '$vitals. ${scoring.length} finding${scoring.length == 1 ? '' : 's'} '
            'pushed the score to ${assessment.score} out of 100.',
      RiskBand.red =>
        '$who needs urgent care. Measured $vitals, and the score '
            'reached ${assessment.score} out of 100. '
            '${assessment.hasCritical ? 'At least one reading is in the danger range.' : 'Several findings together put this in the urgent band.'}',
    };
  }

  static String _whyThisLevel(TriageAssessment assessment) {
    final scoring = assessment.scoringRules;

    if (scoring.isEmpty) {
      final lines = [
        'No rule was triggered. Every measured value sat inside the screening '
            'range for this person:',
        '• Oxygen at or above ${assessment.thresholds.spo2Warning}%',
        '• Heart rate between ${assessment.thresholds.hrLowWarning} and '
            '${assessment.thresholds.hrHighWarning} beats per minute',
        '• Temperature below '
            '${assessment.thresholds.tempFever.toStringAsFixed(1)}°C',
        if (assessment.sample.estimatedGlucose > 0)
          '• Blood glucose inside expected range (70–140 mg/dL)',
      ];
      return lines.join('\n');
    }

    final lines = <String>[
      'The score of ${assessment.score} out of 100 is the sum of these '
          'findings, largest first:',
    ];
    for (final rule in scoring) {
      lines.add('• ${rule.title} — ${rule.detail} (+${rule.points})');
    }

    // Vulnerability is the reason two identical readings can land in different
    // bands, so it is stated rather than left implicit.
    if (assessment.flags.isNotEmpty) {
      final names = assessment.flags.map(_flagLabel).join(', ');
      lines.add(
        '\nThresholds were adjusted for: $names. That is why a reading that '
        'would pass for a healthy adult was counted here.',
      );
    }

    final advisories = assessment.advisories;
    if (advisories.isNotEmpty) {
      lines.add(
        '\nAlso noted (did not change the score): '
        '${advisories.map((a) => a.title).join('; ')}.',
      );
    }

    return lines.join('\n');
  }

  static String _nextSteps(
    TriageAssessment assessment,
    List<RetrievedChunk> retrieved,
  ) {
    final steps = <String>[assessment.recommendedAction];

    final ids = assessment.ruleIds.toSet();
    if (ids.contains(RuleId.glucoseHypoglycemia)) {
      steps.add(
        '\nImmediate Hypoglycemia Guidance:\n'
        'If the person is conscious and able to swallow, give 15–20g of fast-acting sugar immediately '
        '(e.g., 3–4 teaspoons of sugar in water, sweet tea, or fruit juice). Re-check in 15 minutes. '
        'If unconscious, do NOT force food or fluids — transfer immediately to emergency medical care.',
      );
    } else if (ids.contains(RuleId.glucoseHyperglycemiaCritical) ||
        ids.contains(RuleId.glucoseHyperglycemiaHigh)) {
      steps.add(
        '\nImmediate Hyperglycemia Guidance:\n'
        'Ensure hydration with plain water if conscious. Check for diabetic crisis signs '
        '(frequent urination, deep rapid breathing, vomiting, fruity breath odor, confusion). '
        'Urgent referral to Community Health Centre / Medical Officer for blood test confirmation.',
      );
    }

    // Guideline text goes in verbatim rather than paraphrased. Paraphrasing
    // clinical instructions offline, with no reviewer, is exactly the failure
    // mode this design is trying to avoid.
    for (final hit in retrieved.where((r) => r.matchedRule)) {
      steps.add(
        '\n${hit.chunk.title} (${hit.chunk.source}):\n'
        '${hit.chunk.body}',
      );
    }

    if (retrieved.where((r) => r.matchedRule).isEmpty && retrieved.isNotEmpty) {
      final first = retrieved.first;
      steps.add(
        '\nRelated guidance — ${first.chunk.title} '
        '(${first.chunk.source}):\n${first.chunk.body}',
      );
    }

    return steps.join('\n');
  }

  static String _whenToEscalate(RiskBand band, TriageAssessment assessment) {
    const dangerSigns =
        'Go immediately, whatever the score says, if you see: struggling to '
        'breathe or breathing very fast, blue lips, chest pain, confusion, '
        'unable to stay awake, a fit, or unable to drink or keep anything down.';

    return switch (band) {
      RiskBand.red => 'Now. Do not wait for a change. $dangerSigns',
      RiskBand.yellow =>
        'Within 24 hours, sooner if anything worsens. $dangerSigns',
      RiskBand.green =>
        'Re-screen if new symptoms appear or the person feels worse. '
            '$dangerSigns',
    };
  }

  static List<String> _questions(TriageAssessment assessment) {
    final questions = <String>[
      'When did this start, and has it got worse since?',
      'Any medicine taken today, including anything from a local shop?',
    ];

    // Questions follow the findings, so the worker is prompted about the thing
    // the screening actually flagged.
    final ids = assessment.ruleIds.toSet();

    if (ids.any((id) => id.startsWith('spo2'))) {
      questions.add(
        'Is breathing harder than usual, or harder when lying flat?',
      );
    }
    if (ids.any((id) => id.startsWith('temp'))) {
      questions.add('Any shivering, sweating at night, or recent travel?');
    }
    if (ids.any((id) => id.startsWith('hr_'))) {
      questions.add('Any racing heart, dizziness on standing, or fainting?');
    }
    if (ids.contains(RuleId.bpHigh) ||
        ids.contains(RuleId.bpExperimentalAdvisory)) {
      questions.add(
        'Ever been told the blood pressure was high, and is there '
        'medicine for it?',
      );
    }
    if (ids.any((id) => id.startsWith('glucose'))) {
      questions.add(
        'When was the last meal or sugary drink taken, and is there any history of diabetes or medication?',
      );
    }
    if (assessment.flags.contains(Vulnerability.pregnant)) {
      questions.add(
        'How many months pregnant, and has there been any bleeding '
        'or reduced movement?',
      );
    }
    if (assessment.flags.contains(Vulnerability.chronic)) {
      questions.add(
        'Which long-term condition, and has the usual medicine been '
        'taken?',
      );
    }
    if (assessment.symptoms.isEmpty) {
      questions.add('Does anything feel wrong, even if it seems small?');
    }

    return questions;
  }

  static String _flagLabel(Vulnerability flag) => switch (flag) {
    Vulnerability.elderly => 'older age',
    Vulnerability.infant => 'infant',
    Vulnerability.pregnant => 'pregnancy',
    Vulnerability.chronic => 'a long-term condition',
    Vulnerability.immunocompromised => 'weakened immunity',
  };

  /// Answers clinical follow-up questions deterministically from on-device
  /// screening rules and guideline citations when online Gemini AI is unavailable.
  static String answerClinicalQuestion({
    required TriageAssessment assessment,
    required String question,
    List<RetrievedChunk> retrieved = const [],
  }) {
    final q = question.toLowerCase();
    final s = assessment.sample;
    final buf = StringBuffer();

    if (q.contains('heart') ||
        q.contains('pulse') ||
        q.contains('bpm') ||
        q.contains('ecg') ||
        q.contains('rate') ||
        q.contains('rhythm') ||
        q.contains('tachy') ||
        q.contains('brady') ||
        q.contains('palpitat')) {
      buf.writeln('Heart Rate & Cardiac Rhythm Analysis:');
      buf.writeln(
        '• Measured Heart Rate: ${s.heartRateBpm} BPM (Normal adult resting range: 60–100 BPM).',
      );
      if (s.heartRateBpm > 100) {
        buf.writeln(
          '• Tachycardia Note: Heart rate is elevated above 100 BPM. Common causes include fever, dehydration, anxiety, physical exertion, or cardiac rhythm irregularities.',
        );
      } else if (s.heartRateBpm < 50 && s.heartRateBpm > 0) {
        buf.writeln(
          '• Bradycardia Note: Heart rate is below 50 BPM. Common in well-conditioned athletes, but if accompanied by dizziness, syncope, or fatigue, clinical review is recommended.',
        );
      } else {
        buf.writeln(
          '• Rhythm is within standard physiological resting parameters.',
        );
      }
      if (s.rrIntervalMs > 0) {
        buf.writeln(
          '• R-R Interval: ${s.rrIntervalMs} ms (indicates consistent autonomic sinus cadence).',
        );
      }
      buf.writeln(
        '• Recommendation: If experiencing chest discomfort, lightheadedness, or shortness of breath, consult a medical professional immediately.',
      );
    } else if (q.contains('oxygen') ||
        q.contains('spo2') ||
        q.contains('breath') ||
        q.contains('hypox') ||
        q.contains('lung') ||
        q.contains('air') ||
        q.contains('apnea')) {
      buf.writeln('Blood Oxygen (SpO2) Assessment:');
      buf.writeln(
        '• Current SpO2 Saturation: ${s.spo2Percent}% (Optimal clinical baseline: 95–100%).',
      );
      if (s.spo2Percent < 90 && s.spo2Percent > 0) {
        buf.writeln(
          '• CRITICAL HYPOXIA: Oxygen saturation below 90% is a medical red flag requiring prompt clinical intervention and supplemental oxygen evaluation.',
        );
      } else if (s.spo2Percent < 95 && s.spo2Percent > 0) {
        buf.writeln(
          '• Mild Desaturation: Value is between 90–94%. Check sensor seating, warm fingers, sit upright, and re-screen in 5 minutes.',
        );
      } else {
        buf.writeln(
          '• Oxygenation is well-maintained and within the healthy therapeutic window.',
        );
      }
    } else if (q.contains('temp') ||
        q.contains('fever') ||
        q.contains('heat') ||
        q.contains('hot') ||
        q.contains('cold') ||
        q.contains('chill')) {
      buf.writeln('Body Temperature Evaluation:');
      buf.writeln(
        '• Measured Temperature: ${s.temperatureC.toStringAsFixed(1)}°C / ${(s.temperatureC * 9 / 5 + 32).toStringAsFixed(1)}°F.',
      );
      if (s.temperatureC >= 38.0) {
        buf.writeln(
          '• Pyrexia (Fever) Detected: Ensure adequate hydration with ORS or clean fluids, rest in a cool shaded area, and consider paracetamol per local primary health guidelines.',
        );
      } else if (s.temperatureC < 35.5 && s.temperatureC > 0) {
        buf.writeln(
          '• Hypothermia Warning: Temperature is subnormal. Keep patient warm with dry blankets.',
        );
      } else {
        buf.writeln('• Body temperature is normothermic.');
      }
    } else if (q.contains('do') ||
        q.contains('next') ||
        q.contains('action') ||
        q.contains('step') ||
        q.contains('plan') ||
        q.contains('treatment')) {
      buf.writeln('Recommended Action Plan:');
      buf.writeln(_nextSteps(assessment, retrieved));
    } else if (q.contains('hospital') ||
        q.contains('emergency') ||
        q.contains('danger') ||
        q.contains('doctor') ||
        q.contains('urgent') ||
        q.contains('risk')) {
      buf.writeln('Urgent Warning Signs & Escalation Criteria:');
      buf.writeln(_whenToEscalate(assessment.band, assessment));
    } else {
      buf.writeln('Clinical Screening Context:');
      buf.writeln(_whyThisLevel(assessment));
      if (retrieved.isNotEmpty) {
        buf.writeln('\nRelevant Guidance from Reference Corpus:');
        for (final r in retrieved.take(2)) {
          buf.writeln('• ${r.chunk.body.trim()} (${r.chunk.citation})');
        }
      }
    }

    buf.writeln(
      '\nNote: On-device screening guidance based on deterministic ICMR/WHO triage protocols. Not an autonomous clinical diagnosis.',
    );
    return buf.toString().trim();
  }

  /// A neutral fallback for the open chat when the online model is unavailable.
  ///
  /// The triage flow above gives assessment-bound guidance; the chat instead
  /// answers whatever the worker asked. With no assessment to anchor on, the
  /// safest on-device reply acknowledges that, points at what the phone does
  /// know (the latest screening, if any), and steers back to a clinician. This
  /// is never the primary path — the [GeminiService] only calls it when
  /// [GeminiService.generalChat] returns `null`.
  static String chatFallback({
    Screening? latest,
    bool grounded = false,
    String? question,
  }) {
    final buf = StringBuffer();
    final q = question?.toLowerCase() ?? '';

    if (q.contains('heart') || q.contains('pulse') || q.contains('ecg')) {
      buf.writeln('Cardiac & Pulse Guidance:');
      if (latest != null) {
        buf.writeln('• Latest Recorded Heart Rate: ${latest.heartRate} BPM.');
      }
      buf.writeln('• Normal resting heart rate range is 60–100 BPM.');
      buf.writeln(
        '• Heart rate above 100 at rest is tachycardia; below 50 is bradycardia.',
      );
      buf.writeln(
        '• For persistent palpitations, chest tightness, or irregular beats, consult a physician promptly.\n',
      );
    } else if (q.contains('oxygen') ||
        q.contains('spo2') ||
        q.contains('breath')) {
      buf.writeln('Oxygen Saturation (SpO2) Guidance:');
      if (latest != null) {
        buf.writeln(
          '• Latest Recorded SpO2: ${latest.spo2}% (Normal baseline: ≥95%).',
        );
      }
      buf.writeln(
        '• SpO2 below 94% indicates hypoxemia; below 90% is a medical emergency requiring oxygen support.\n',
      );
    } else if (q.contains('fever') ||
        q.contains('temp') ||
        q.contains('heat')) {
      buf.writeln('Body Temperature & Fever Guidance:');
      if (latest != null) {
        buf.writeln(
          '• Latest Recorded Temperature: ${latest.temperature.toStringAsFixed(1)}°C.',
        );
      }
      buf.writeln(
        '• Temperatures ≥38.0°C (100.4°F) represent fever. Maintain hydration, rest, and cooling measures.\n',
      );
    }

    if (latest == null) {
      buf.write(
        'Online AI is currently unreachable, and this phone does not '
        'have a screening on file to draw on.\n\n',
      );
    } else {
      buf.write(
        'Online AI is currently unreachable. What this phone does '
        'have on file is the latest screening: HR ${latest.heartRate} bpm, '
        'SpO2 ${latest.spo2}%, temp ${latest.temperature.toStringAsFixed(1)}°C, '
        'risk band ${latest.riskLevel} (score ${latest.riskScore}/100)'
        '${latest.symptoms.isEmpty ? '' : '; symptoms: ${latest.symptoms.join(', ')}'}.\n\n',
      );
    }
    buf.write(
      'General clinical advice:\n'
      '- For red-flag signs (chest pain, severe breathlessness, bluish lips, confusion, convulsions) seek immediate hospital care.\n'
      '- Re-screen whenever physical symptoms change.\n'
      '- For medication dosages or diagnostic confirmation, consult a qualified clinician.',
    );
    return buf.toString();
  }
}
