class TriageResult {
  final String level;
  final int score;
  final List<String> triggeredRules;
  final String recommendedAction;
  final String escalationLevel;
  final Map<String, dynamic> vitals;
  final List<String> symptoms;
  final bool isDemo;

  const TriageResult({
    required this.level,
    required this.score,
    required this.triggeredRules,
    required this.recommendedAction,
    required this.escalationLevel,
    required this.vitals,
    required this.symptoms,
    this.isDemo = false,
  });

  factory TriageResult.fromJson(Map<String, dynamic> json) => TriageResult(
    level: json['level'] as String,
    score: json['score'] as int,
    triggeredRules: (json['triggeredRules'] as List<dynamic>?)?.cast<String>() ?? [],
    recommendedAction: json['recommendedAction'] as String,
    escalationLevel: json['escalationLevel'] as String,
    vitals: (json['vitals'] as Map<String, dynamic>?) ?? {},
    symptoms: (json['symptoms'] as List<dynamic>?)?.cast<String>() ?? [],
    isDemo: json['isDemo'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'level': level,
    'score': score,
    'triggeredRules': triggeredRules,
    'recommendedAction': recommendedAction,
    'escalationLevel': escalationLevel,
    'vitals': vitals,
    'symptoms': symptoms,
    'isDemo': isDemo,
  };

  TriageResult copyWith({
    String? level,
    int? score,
    List<String>? triggeredRules,
    String? recommendedAction,
    String? escalationLevel,
    Map<String, dynamic>? vitals,
    List<String>? symptoms,
    bool? isDemo,
  }) => TriageResult(
    level: level ?? this.level,
    score: score ?? this.score,
    triggeredRules: triggeredRules ?? this.triggeredRules,
    recommendedAction: recommendedAction ?? this.recommendedAction,
    escalationLevel: escalationLevel ?? this.escalationLevel,
    vitals: vitals ?? this.vitals,
    symptoms: symptoms ?? this.symptoms,
    isDemo: isDemo ?? this.isDemo,
  );

  factory TriageResult.normal({bool isDemo = false}) => TriageResult(
    level: 'GREEN',
    score: 20,
    triggeredRules: [],
    recommendedAction: 'Vitals within normal range. Continue routine monitoring.',
    escalationLevel: 'NONE',
    vitals: {},
    symptoms: [],
    isDemo: isDemo,
  );

  factory TriageResult.attention({
    required Map<String, dynamic> vitals,
    required List<String> symptoms,
    required List<String> triggeredRules,
    bool isDemo = false,
  }) => TriageResult(
    level: 'YELLOW',
    // Must sit inside the YELLOW band (31-60). The previous value of 65 landed
    // in RED once bands moved to 0-30/31-60/61-100, so the card and the score
    // disagreed. See RiskEngine.bandForScore.
    score: 45,
    triggeredRules: triggeredRules,
    recommendedAction: 'Some measurements require attention. Consult healthcare professional. Continue monitoring.',
    escalationLevel: 'CLINIC_VISIT',
    vitals: vitals,
    symptoms: symptoms,
    isDemo: isDemo,
  );

  factory TriageResult.urgent({
    required Map<String, dynamic> vitals,
    required List<String> symptoms,
    required List<String> triggeredRules,
    bool isDemo = false,
  }) => TriageResult(
    level: 'RED',
    score: 90,
    triggeredRules: triggeredRules,
    recommendedAction: 'Potentially concerning measurements detected. Seek prompt medical assessment.',
    escalationLevel: 'EMERGENCY',
    vitals: vitals,
    symptoms: symptoms,
    isDemo: isDemo,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriageResult &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          score == other.score &&
          triggeredRules == other.triggeredRules &&
          recommendedAction == other.recommendedAction &&
          escalationLevel == other.escalationLevel &&
          vitals == other.vitals &&
          symptoms == other.symptoms &&
          isDemo == other.isDemo;

  @override
  int get hashCode => Object.hash(level, score, triggeredRules, recommendedAction, escalationLevel, vitals, symptoms, isDemo);
}

class AIExplanation {
  final String summary;
  final String whyThisLevel;
  final String safeNextSteps;
  final String whenToEscalate;
  final List<String> questionsToAsk;
  final String disclaimer;
  final bool isDemo;

  const AIExplanation({
    required this.summary,
    required this.whyThisLevel,
    required this.safeNextSteps,
    required this.whenToEscalate,
    required this.questionsToAsk,
    required this.disclaimer,
    this.isDemo = false,
  });

  factory AIExplanation.fromJson(Map<String, dynamic> json) => AIExplanation(
    summary: json['summary'] as String,
    whyThisLevel: json['whyThisLevel'] as String,
    safeNextSteps: json['safeNextSteps'] as String,
    whenToEscalate: json['whenToEscalate'] as String,
    questionsToAsk: (json['questionsToAsk'] as List<dynamic>?)?.cast<String>() ?? [],
    disclaimer: json['disclaimer'] as String,
    isDemo: json['isDemo'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'whyThisLevel': whyThisLevel,
    'safeNextSteps': safeNextSteps,
    'whenToEscalate': whenToEscalate,
    'questionsToAsk': questionsToAsk,
    'disclaimer': disclaimer,
    'isDemo': isDemo,
  };

  AIExplanation copyWith({
    String? summary,
    String? whyThisLevel,
    String? safeNextSteps,
    String? whenToEscalate,
    List<String>? questionsToAsk,
    String? disclaimer,
    bool? isDemo,
  }) => AIExplanation(
    summary: summary ?? this.summary,
    whyThisLevel: whyThisLevel ?? this.whyThisLevel,
    safeNextSteps: safeNextSteps ?? this.safeNextSteps,
    whenToEscalate: whenToEscalate ?? this.whenToEscalate,
    questionsToAsk: questionsToAsk ?? this.questionsToAsk,
    disclaimer: disclaimer ?? this.disclaimer,
    isDemo: isDemo ?? this.isDemo,
  );

  factory AIExplanation.demo({required String triageLevel}) => AIExplanation(
    summary: 'Your screening shows a $triageLevel risk level based on the measured vital signs and reported symptoms.',
    whyThisLevel: 'The deterministic risk engine evaluated your heart rate, oxygen saturation, temperature, and symptoms against established screening thresholds.',
    safeNextSteps: triageLevel == 'RED'
        ? 'Seek immediate medical attention. Do not delay.'
        : triageLevel == 'YELLOW'
        ? 'Schedule a consultation with a healthcare provider within 24 hours. Continue monitoring your symptoms.'
        : 'Continue routine self-care and monitoring. Maintain healthy habits.',
    whenToEscalate: triageLevel == 'RED'
        ? 'If symptoms worsen: difficulty breathing, chest pain, confusion, or inability to stay awake.'
        : triageLevel == 'YELLOW'
        ? 'If symptoms persist beyond 48 hours, worsen, or new symptoms develop.'
        : 'If new concerning symptoms develop.',
    questionsToAsk: [
      'How long have you had these symptoms?',
      'Have you taken any medication?',
      'Do you have any pre-existing conditions?',
      'Have you been in contact with anyone ill recently?',
    ],
    disclaimer: 'This is a screening/triage assessment tool, NOT a medical diagnosis. Results should be reviewed by a qualified healthcare professional. The AI explanation is for informational purposes only and does not replace clinical judgment.',
    isDemo: true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIExplanation &&
          runtimeType == other.runtimeType &&
          summary == other.summary &&
          whyThisLevel == other.whyThisLevel &&
          safeNextSteps == other.safeNextSteps &&
          whenToEscalate == other.whenToEscalate &&
          questionsToAsk == other.questionsToAsk &&
          disclaimer == other.disclaimer &&
          isDemo == other.isDemo;

  @override
  int get hashCode => Object.hash(summary, whyThisLevel, safeNextSteps, whenToEscalate, questionsToAsk, disclaimer, isDemo);
}