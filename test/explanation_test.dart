import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/seed_service.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/ecg_classifier.dart';
import 'package:swasthyasetu_ai/domain/rules/guideline_retriever.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

/// The three pure pieces behind the offline explanation tier. None of them touch
/// a database, a network or a plugin, so they are tested directly — which is the
/// point of keeping them pure: a worker with no signal depends on this code
/// path, and it has to be provable without a device.

HealthSample sampleOf({
  int hr = 72,
  int spo2 = 98,
  double temp = 36.5,
  double ecgQuality = 0.95,
  int rrInterval = 833,
}) =>
    HealthSample(
      timestamp: 0,
      heartRateBpm: hr,
      spo2Percent: spo2,
      temperatureC: temp,
      ecgSignalQuality: ecgQuality,
      rPeakDetected: true,
      rrIntervalMs: rrInterval,
      batteryPercent: 90,
    );

GuidelineChunk chunk(
  String id, {
  String source = 'WHO IMCI',
  String title = '',
  String body = '',
  List<String> ruleTags = const [],
}) =>
    GuidelineChunk(
      id: id,
      source: source,
      title: title,
      body: body,
      keywords: SeedService.tokenise('$title $body'),
      ruleTags: ruleTags,
    );

void main() {
  group('EcgClassifier', () {
    test('poor signal is reported as noisy, never as a rhythm', () {
      // A classification derived from an unusable trace is worse than none: it
      // would be stored in the screening row and read as clinical fact.
      expect(
        EcgClassifier.classify(heartRate: 72, quality: 0.2),
        'NOISY',
      );
      expect(
        EcgClassifier.classify(heartRate: 150, quality: 0.49),
        'NOISY',
      );
    });

    test('a clean normal trace is sinus rhythm', () {
      expect(
        EcgClassifier.classify(heartRate: 72, quality: 0.95, rrIntervalMs: 833),
        'SINUS_RHYTHM',
      );
    });

    test('rate thresholds map to brady and tachy', () {
      expect(
        EcgClassifier.classify(heartRate: 45, quality: 0.9, rrIntervalMs: 1333),
        'BRADYCARDIA',
      );
      expect(
        EcgClassifier.classify(heartRate: 130, quality: 0.9, rrIntervalMs: 461),
        'TACHYCARDIA',
      );
      // The boundaries themselves are inside the normal range.
      expect(
        EcgClassifier.classify(heartRate: 50, quality: 0.9, rrIntervalMs: 1200),
        'SINUS_RHYTHM',
      );
      expect(
        EcgClassifier.classify(heartRate: 100, quality: 0.9, rrIntervalMs: 600),
        'SINUS_RHYTHM',
      );
    });

    test('beat-to-beat variation outranks the rate', () {
      // Alternating long and short intervals: the mean rate is unremarkable,
      // the rhythm is not.
      expect(
        EcgClassifier.classify(
          heartRate: 78,
          quality: 0.9,
          rrIntervals: const [800, 1200, 700, 1150, 720, 1180],
        ),
        'IRREGULAR',
      );
    });

    test('a steady rate is not called irregular', () {
      expect(
        EcgClassifier.classify(
          heartRate: 72,
          quality: 0.9,
          rrIntervals: const [830, 836, 828, 840, 833, 831],
        ),
        'SINUS_RHYTHM',
      );
    });
  });

  group('GuidelineRetriever', () {
    final corpus = [
      chunk(
        'spo2-low',
        title: 'Oxygen saturation below 90 percent',
        body: 'Refer urgently when oxygen saturation is below ninety percent.',
        ruleTags: const ['spo2_critical'],
      ),
      chunk(
        'fever',
        title: 'Fever in adults',
        body: 'Measure temperature and look for danger signs alongside fever.',
        ruleTags: const ['temp_fever'],
      ),
      chunk(
        'hydration',
        title: 'Oral rehydration',
        body: 'Give fluids frequently in small amounts to prevent dehydration.',
        ruleTags: const ['dehydration_symptoms'],
      ),
    ];

    test('an empty corpus returns nothing rather than throwing', () {
      final empty = GuidelineRetriever(const []);
      expect(empty.isEmpty, isTrue);
      expect(empty.search(queryTerms: const ['fever']), isEmpty);
    });

    test('a fired rule tag outranks a stronger text match', () {
      final index = GuidelineRetriever(corpus);
      // Every query word is in the fever chunk and none are in the SpO2 one,
      // yet the fired rule is what the worker actually needs to read.
      final hits = index.search(
        queryTerms: SeedService.tokenise('fever temperature danger signs'),
        ruleIds: const ['spo2_critical'],
      );

      expect(hits.first.chunk.id, 'spo2-low');
      expect(hits.first.matchedRule, isTrue);
      // Exactly the boost: it shares no vocabulary with the query at all, which
      // is the case the tag exists to rescue.
      expect(
        hits.first.score,
        greaterThanOrEqualTo(GuidelineRetriever.ruleTagBoost),
      );
    });

    test('unrelated chunks are dropped, not returned with a low score', () {
      final index = GuidelineRetriever(corpus);
      final hits = index.search(
        queryTerms: SeedService.tokenise('oxygen saturation'),
      );

      expect(hits, isNotEmpty);
      expect(hits.map((h) => h.chunk.id), isNot(contains('hydration')));
    });

    test('limit is honoured and ordering is stable across runs', () {
      final index = GuidelineRetriever(corpus);
      final terms = SeedService.tokenise('oxygen fever fluids');

      final first = index.search(queryTerms: terms, limit: 2);
      final second = index.search(queryTerms: terms, limit: 2);

      expect(first, hasLength(2));
      expect(
        first.map((h) => h.chunk.id).toList(),
        second.map((h) => h.chunk.id).toList(),
      );
    });

    test('the seed tokeniser and the query tokeniser agree', () {
      // If these ever diverge the retriever silently returns nothing, which is
      // indistinguishable from "no guideline covers this".
      final index = GuidelineRetriever(corpus);
      final assessment = RiskEngine.assess(
        sample: sampleOf(spo2: 86),
        symptoms: const [],
      );
      final hits = index.search(
        queryTerms: SeedService.tokenise(OfflineExplainer.queryFor(assessment)),
        ruleIds: assessment.ruleIds,
      );

      expect(hits, isNotEmpty);
    });
  });

  group('OfflineExplainer', () {
    test('a normal screening explains why nothing fired', () {
      final assessment =
          RiskEngine.assess(sample: sampleOf(), symptoms: const []);
      final explanation = OfflineExplainer.build(assessment: assessment);

      expect(explanation.summary, contains('screened as normal'));
      expect(explanation.whyThisLevel, contains('No rule was triggered'));
      expect(explanation.questionsToAsk, isNotEmpty);
      expect(explanation.disclaimer, contains(OfflineExplainer.disclaimer));
    });

    test('the explanation restates the engine, never re-scores it', () {
      final assessment = RiskEngine.assess(
        sample: sampleOf(spo2: 86, hr: 122, temp: 39.4),
        symptoms: const ['Breathlessness'],
      );
      final explanation = OfflineExplainer.build(assessment: assessment);

      expect(assessment.band, RiskBand.red);
      expect(explanation.summary, contains('${assessment.score} out of 100'));
      expect(explanation.summary, contains('needs urgent care'));
      // Every scoring rule is accounted for in the "why".
      for (final rule in assessment.scoringRules) {
        expect(explanation.whyThisLevel, contains(rule.title));
      }
      expect(explanation.whenToEscalate, startsWith('Now.'));
    });

    test('the patient name is used when given and never invented', () {
      final assessment =
          RiskEngine.assess(sample: sampleOf(), symptoms: const []);

      expect(
        OfflineExplainer.build(assessment: assessment, patientName: 'Asha')
            .summary,
        startsWith('Asha'),
      );
      expect(
        OfflineExplainer.build(assessment: assessment, patientName: '   ')
            .summary,
        startsWith('This person'),
      );
    });

    test('adjusted thresholds are stated, not left implicit', () {
      // Two identical readings landing in different bands is confusing unless
      // the reason is on the screen.
      final assessment = RiskEngine.assess(
        sample: sampleOf(spo2: 93),
        symptoms: const [],
        age: 70,
        flags: const {Vulnerability.chronic},
      );
      final explanation = OfflineExplainer.build(assessment: assessment);

      expect(explanation.whyThisLevel, contains('Thresholds were adjusted'));
      expect(explanation.whyThisLevel, contains('older age'));
      expect(explanation.whyThisLevel, contains('long-term condition'));
    });

    test('retrieved guideline text is quoted verbatim and cited', () {
      final assessment =
          RiskEngine.assess(sample: sampleOf(spo2: 86), symptoms: const []);
      final hit = RetrievedChunk(
        chunk: chunk(
          'spo2-low',
          title: 'Oxygen saturation below 90 percent',
          body: 'Refer urgently to the nearest facility.',
          ruleTags: const ['spo2_critical'],
        ),
        score: 20,
        matchedRule: true,
      );

      final explanation =
          OfflineExplainer.build(assessment: assessment, retrieved: [hit]);

      // Paraphrasing a clinical instruction with no reviewer is the failure
      // mode this whole path is built to avoid.
      expect(
        explanation.safeNextSteps,
        contains('Refer urgently to the nearest facility.'),
      );
      expect(explanation.disclaimer, contains(hit.chunk.citation));
    });

    test('questions follow the findings', () {
      final breathless = OfflineExplainer.build(
        assessment:
            RiskEngine.assess(sample: sampleOf(spo2: 86), symptoms: const []),
      );
      expect(
        breathless.questionsToAsk.any((q) => q.contains('breathing')),
        isTrue,
      );

      final pregnant = OfflineExplainer.build(
        assessment: RiskEngine.assess(
          sample: sampleOf(temp: 39.0),
          symptoms: const [],
          flags: const {Vulnerability.pregnant},
        ),
      );
      expect(
        pregnant.questionsToAsk.any((q) => q.contains('pregnant')),
        isTrue,
      );
    });

    test('the demo flag survives into the explanation', () {
      final assessment = RiskEngine.assess(
        sample: HealthSample.demo(
          heartRateBpm: 108,
          spo2Percent: 94,
          temperatureC: 38.3,
          ecgSignalQuality: 0.88,
          rrIntervalMs: 556,
        ),
        symptoms: const ['Fever'],
      );

      expect(OfflineExplainer.build(assessment: assessment).isDemo, isTrue);
    });
  });
}
