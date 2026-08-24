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
    final vitals = 'heart rate ${s.heartRateBpm} beats per minute, '
        'oxygen ${s.spo2Percent}%, '
        'temperature ${s.temperatureC.toStringAsFixed(1)}°C';

    final scoring = assessment.scoringRules;

    return switch (assessment.band) {
      RiskBand.green => '$who screened as normal. Measured $vitals, and nothing '
          'crossed a screening threshold.',
      RiskBand.yellow => '$who needs attention, though not urgently. Measured '
          '$vitals. ${scoring.length} finding${scoring.length == 1 ? '' : 's'} '
          'pushed the score to ${assessment.score} out of 100.',
      RiskBand.red => '$who needs urgent care. Measured $vitals, and the score '
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

    // Guideline text goes in verbatim rather than paraphrased. Paraphrasing
    // clinical instructions offline, with no reviewer, is exactly the failure
    // mode this design is trying to avoid.
    for (final hit in retrieved.where((r) => r.matchedRule)) {
      steps.add('\n${hit.chunk.title} (${hit.chunk.source}):\n'
          '${hit.chunk.body}');
    }

    if (retrieved.where((r) => r.matchedRule).isEmpty && retrieved.isNotEmpty) {
      final first = retrieved.first;
      steps.add('\nRelated guidance — ${first.chunk.title} '
          '(${first.chunk.source}):\n${first.chunk.body}');
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
      questions.add('Is breathing harder than usual, or harder when lying flat?');
    }
    if (ids.any((id) => id.startsWith('temp'))) {
      questions.add('Any shivering, sweating at night, or recent travel?');
    }
    if (ids.any((id) => id.startsWith('hr_'))) {
      questions.add('Any racing heart, dizziness on standing, or fainting?');
    }
    if (ids.contains('bp_high')) {
      questions.add('Ever been told the blood pressure was high, and is there '
          'medicine for it?');
    }
    if (assessment.flags.contains(Vulnerability.pregnant)) {
      questions.add('How many months pregnant, and has there been any bleeding '
          'or reduced movement?');
    }
    if (assessment.flags.contains(Vulnerability.chronic)) {
      questions.add('Which long-term condition, and has the usual medicine been '
          'taken?');
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
}
