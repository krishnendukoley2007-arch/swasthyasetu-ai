import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

/// A reading that fires no rules at all, so each test can move exactly one
/// variable and attribute the result to it.
HealthSample healthy({
  int hr = 72,
  int spo2 = 98,
  double temp = 36.5,
  double ecgQuality = 0.95,
  bool rPeak = true,
  int rrInterval = 833,
}) =>
    HealthSample(
      timestamp: 0,
      heartRateBpm: hr,
      spo2Percent: spo2,
      temperatureC: temp,
      ecgSignalQuality: ecgQuality,
      rPeakDetected: rPeak,
      rrIntervalMs: rrInterval,
      batteryPercent: 90,
    );

TriageAssessment assess(
  HealthSample sample, {
  List<String> symptoms = const [],
  int age = 30,
  Set<Vulnerability> flags = const {},
}) =>
    RiskEngine.assess(
      sample: sample,
      symptoms: symptoms,
      age: age,
      flags: flags,
    );

bool fired(TriageAssessment a, String ruleId) => a.ruleIds.contains(ruleId);

void main() {
  group('band boundaries', () {
    // The documented contract: 0-30 GREEN, 31-60 YELLOW, 61-100 RED.
    test('every documented boundary score maps to the right band', () {
      expect(RiskEngine.bandForScore(0), RiskBand.green);
      expect(RiskEngine.bandForScore(30), RiskBand.green);
      expect(RiskEngine.bandForScore(31), RiskBand.yellow);
      expect(RiskEngine.bandForScore(60), RiskBand.yellow);
      expect(RiskEngine.bandForScore(61), RiskBand.red);
      expect(RiskEngine.bandForScore(100), RiskBand.red);
    });

    test('band is always consistent with the returned score', () {
      // Sweep a wide space of readings and assert the invariant the UI relies
      // on: you can never get a RED card next to a score of 40.
      for (var hr = 30; hr <= 200; hr += 7) {
        for (var spo2 = 70; spo2 <= 100; spo2 += 3) {
          for (final temp in [34.0, 36.5, 38.2, 39.5, 41.0]) {
            final a = assess(healthy(hr: hr, spo2: spo2, temp: temp));
            expect(
              a.band,
              RiskEngine.bandForScore(a.score),
              reason: 'hr=$hr spo2=$spo2 temp=$temp scored ${a.score} '
                  'but was banded ${a.band.storageValue}',
            );
            expect(a.score, inInclusiveRange(0, 100));
          }
        }
      }
    });

    test('score never exceeds 100 even when everything fires at once', () {
      final a = assess(
        healthy(hr: 195, spo2: 72, temp: 41.0, ecgQuality: 0.9, rPeak: false),
        symptoms: const [
          'Fever',
          'Cough',
          'Breathlessness',
          'Chest discomfort',
          'Vomiting',
          'Diarrhea',
          'Dizziness',
        ],
        age: 80,
        flags: {Vulnerability.chronic, Vulnerability.immunocompromised},
      );
      expect(a.score, 100);
      expect(a.band, RiskBand.red);
    });

    test('a fully normal reading is GREEN with no scoring rules', () {
      final a = assess(healthy());
      expect(a.band, RiskBand.green);
      expect(a.score, 0);
      expect(a.scoringRules, isEmpty);
    });
  });

  group('critical floor', () {
    test('a lone critical rule forces RED even though its points are < 61', () {
      // spo2_critical is worth 45 points. On its own that would band YELLOW,
      // which would be wrong for a saturation of 85%.
      final a = assess(healthy(spo2: 85));
      expect(fired(a, RuleId.spo2Critical), isTrue);
      expect(a.hasCritical, isTrue);
      expect(a.score, greaterThanOrEqualTo(RiskEngine.criticalFloor));
      expect(a.band, RiskBand.red);
    });

    test('the floor lifts the score rather than overriding the band', () {
      final a = assess(healthy(spo2: 85));
      expect(a.score, RiskEngine.criticalFloor);
      expect(a.band, RiskEngine.bandForScore(a.score));
    });

    test('the floor does not lower an already-higher score', () {
      final a = assess(healthy(spo2: 80, hr: 150, temp: 40.0));
      expect(a.score, greaterThan(RiskEngine.criticalFloor));
    });
  });

  group('SpO2 thresholds (adult)', () {
    const t = VitalThresholds.adult;

    test('at the warning threshold exactly, nothing fires', () {
      final a = assess(healthy(spo2: t.spo2Warning)); // 95
      expect(fired(a, RuleId.spo2Warning), isFalse);
      expect(fired(a, RuleId.spo2Critical), isFalse);
    });

    test('one below the warning threshold fires the warning only', () {
      final a = assess(healthy(spo2: t.spo2Warning - 1)); // 94
      expect(fired(a, RuleId.spo2Warning), isTrue);
      expect(fired(a, RuleId.spo2Critical), isFalse);
      expect(a.band, RiskBand.green, reason: '15 points is inside GREEN');
    });

    test('at the critical threshold exactly, only the warning fires', () {
      final a = assess(healthy(spo2: t.spo2Critical)); // 90
      expect(fired(a, RuleId.spo2Critical), isFalse);
      expect(fired(a, RuleId.spo2Warning), isTrue);
    });

    test('one below the critical threshold fires critical, not warning', () {
      final a = assess(healthy(spo2: t.spo2Critical - 1)); // 89
      expect(fired(a, RuleId.spo2Critical), isTrue);
      expect(fired(a, RuleId.spo2Warning), isFalse,
          reason: 'the bands are exclusive, not cumulative');
      expect(a.band, RiskBand.red);
    });

    test('an unmeasured SpO2 is an advisory, not critical hypoxaemia', () {
      // The bug this guards: treating 0 as a value fires critical hypoxaemia on
      // every screening where the finger sensor was not used.
      final a = assess(healthy(spo2: 0));
      expect(fired(a, RuleId.spo2Critical), isFalse);
      expect(fired(a, RuleId.spo2NotMeasured), isTrue);
      expect(a.band, RiskBand.green);
      expect(a.score, 0);
    });
  });

  group('heart-rate thresholds (adult)', () {
    const t = VitalThresholds.adult;

    test('at the high warning threshold exactly, nothing fires', () {
      expect(fired(assess(healthy(hr: t.hrHighWarning)), RuleId.hrTachyWarning),
          isFalse); // 100
    });

    test('one above the high warning fires tachycardia warning', () {
      final a = assess(healthy(hr: t.hrHighWarning + 1)); // 101
      expect(fired(a, RuleId.hrTachyWarning), isTrue);
      expect(fired(a, RuleId.hrTachyCritical), isFalse);
    });

    test('at the high critical threshold exactly, only the warning fires', () {
      final a = assess(healthy(hr: t.hrHighCritical)); // 130
      expect(fired(a, RuleId.hrTachyCritical), isFalse);
      expect(fired(a, RuleId.hrTachyWarning), isTrue);
    });

    test('one above the high critical fires critical tachycardia', () {
      final a = assess(healthy(hr: t.hrHighCritical + 1)); // 131
      expect(fired(a, RuleId.hrTachyCritical), isTrue);
      expect(a.band, RiskBand.red);
    });

    test('at the low warning threshold exactly, nothing fires', () {
      expect(fired(assess(healthy(hr: t.hrLowWarning)), RuleId.hrBradyWarning),
          isFalse); // 55
    });

    test('one below the low warning fires bradycardia warning', () {
      final a = assess(healthy(hr: t.hrLowWarning - 1)); // 54
      expect(fired(a, RuleId.hrBradyWarning), isTrue);
      expect(fired(a, RuleId.hrBradyCritical), isFalse);
    });

    test('at the low critical threshold exactly, only the warning fires', () {
      final a = assess(healthy(hr: t.hrLowCritical)); // 45
      expect(fired(a, RuleId.hrBradyCritical), isFalse);
      expect(fired(a, RuleId.hrBradyWarning), isTrue);
    });

    test('one below the low critical fires critical bradycardia', () {
      final a = assess(healthy(hr: t.hrLowCritical - 1)); // 44
      expect(fired(a, RuleId.hrBradyCritical), isTrue);
      expect(a.band, RiskBand.red);
    });

    test('bradycardia is detected at all — the old engine had no low-HR rule', () {
      expect(fired(assess(healthy(hr: 38)), RuleId.hrBradyCritical), isTrue);
    });

    test('high and low rules are mutually exclusive', () {
      for (var hr = 20; hr <= 220; hr++) {
        final ids = assess(healthy(hr: hr)).ruleIds;
        final high = ids.contains(RuleId.hrTachyWarning) ||
            ids.contains(RuleId.hrTachyCritical);
        final low = ids.contains(RuleId.hrBradyWarning) ||
            ids.contains(RuleId.hrBradyCritical);
        expect(high && low, isFalse, reason: 'hr=$hr fired both directions');
      }
    });

    test('an unmeasured heart rate fires nothing', () {
      final ids = assess(healthy(hr: 0)).ruleIds;
      expect(ids, isNot(contains(RuleId.hrBradyCritical)));
      expect(ids, isNot(contains(RuleId.hrBradyWarning)));
    });
  });

  group('temperature thresholds (adult)', () {
    const t = VitalThresholds.adult;

    test('just below the fever threshold, nothing fires', () {
      final a = assess(healthy(temp: 37.9));
      expect(fired(a, RuleId.tempFever), isFalse);
      expect(fired(a, RuleId.tempHigh), isFalse);
    });

    test('at the fever threshold exactly, fever fires (inclusive)', () {
      final a = assess(healthy(temp: t.tempFever)); // 38.0
      expect(fired(a, RuleId.tempFever), isTrue);
      expect(fired(a, RuleId.tempHigh), isFalse);
    });

    test('just below the high-fever threshold, only fever fires', () {
      final a = assess(healthy(temp: 38.9));
      expect(fired(a, RuleId.tempFever), isTrue);
      expect(fired(a, RuleId.tempHigh), isFalse);
    });

    test('at the high-fever threshold exactly, high fever fires (inclusive)', () {
      final a = assess(healthy(temp: t.tempHigh)); // 39.0
      expect(fired(a, RuleId.tempHigh), isTrue);
      expect(fired(a, RuleId.tempFever), isFalse);
    });

    test('at the hypothermia threshold exactly, nothing fires', () {
      expect(fired(assess(healthy(temp: t.tempLow)), RuleId.tempLow),
          isFalse); // 35.0
    });

    test('just below the hypothermia threshold fires critical', () {
      final a = assess(healthy(temp: 34.9));
      expect(fired(a, RuleId.tempLow), isTrue);
      expect(a.band, RiskBand.red);
    });

    test('an unmeasured temperature fires nothing', () {
      final ids = assess(healthy(temp: 0)).ruleIds;
      expect(ids, isNot(contains(RuleId.tempLow)));
      expect(ids, isNot(contains(RuleId.tempFever)));
    });
  });

  group('ECG rules', () {
    test('poor signal quality adds zero risk points', () {
      // A dry electrode does not make the patient sicker. The old engine added
      // 5 points of risk for a measurement problem.
      final a = assess(healthy(ecgQuality: 0.3));
      expect(fired(a, RuleId.ecgPoorQuality), isTrue);
      expect(a.score, 0);
      expect(a.band, RiskBand.green);
      expect(a.advisories.map((r) => r.id), contains(RuleId.ecgPoorQuality));
    });

    test('at the quality threshold exactly, the advisory does not fire', () {
      expect(fired(assess(healthy(ecgQuality: 0.5)), RuleId.ecgPoorQuality),
          isFalse);
    });

    test('irregular rhythm is not claimed when the signal is too poor to judge',
        () {
      final a = assess(healthy(ecgQuality: 0.2, rPeak: false));
      expect(fired(a, RuleId.ecgIrregular), isFalse);
      expect(fired(a, RuleId.ecgPoorQuality), isTrue);
    });

    test('irregular rhythm fires on good signal with no R-peak lock', () {
      final a = assess(healthy(ecgQuality: 0.9, rPeak: false));
      expect(fired(a, RuleId.ecgIrregular), isTrue);
    });

    test('no ECG attempted fires nothing', () {
      final ids = assess(healthy(ecgQuality: 0, rPeak: false)).ruleIds;
      expect(ids, isNot(contains(RuleId.ecgIrregular)));
      expect(ids, isNot(contains(RuleId.ecgPoorQuality)));
    });
  });

  group('blood pressure (cuffless estimate)', () {
    HealthSample withBp(int sys, int dia, {String confidence = 'ESTIMATED'}) =>
        HealthSample(
          timestamp: 0,
          heartRateBpm: 72,
          spo2Percent: 98,
          temperatureC: 36.5,
          ecgSignalQuality: 0.95,
          rPeakDetected: true,
          rrIntervalMs: 833,
          estimatedSystolic: sys,
          estimatedDiastolic: dia,
          bpConfidence: confidence,
          batteryPercent: 90,
        );

    test('an experimental-confidence estimate is ignored entirely', () {
      // The build ships with bpConfidence EXPERIMENTAL, so an uncalibrated cuff
      // estimate must not be able to influence triage at all.
      final a = assess(withBp(190, 120, confidence: 'EXPERIMENTAL'));
      expect(fired(a, RuleId.bpHigh), isFalse);
      expect(a.score, 0);
    });

    test('a very high estimate fires a warning, never a critical', () {
      final a = assess(withBp(190, 120));
      expect(fired(a, RuleId.bpHigh), isTrue);
      final rule = a.firedRules.firstWhere((r) => r.id == RuleId.bpHigh);
      expect(rule.severity, isNot(RuleSeverity.critical),
          reason: 'an uncalibrated estimate must not send anyone to hospital '
              'on its own');
      expect(a.band, RiskBand.green, reason: '20 points is inside GREEN');
    });

    test('systolic and diastolic each trip the rule independently', () {
      expect(fired(assess(withBp(180, 80)), RuleId.bpHigh), isTrue);
      expect(fired(assess(withBp(140, 110)), RuleId.bpHigh), isTrue);
      expect(fired(assess(withBp(179, 109)), RuleId.bpHigh), isFalse);
    });

    test('an unmeasured BP fires nothing', () {
      expect(fired(assess(withBp(0, 0)), RuleId.bpHigh), isFalse);
    });
  });

  group('sepsis screen', () {
    test('fires only when fever, tachycardia and hypoxaemia coincide', () {
      final all = assess(healthy(temp: 38.5, hr: 110, spo2: 93));
      expect(fired(all, RuleId.sepsisScreen), isTrue);
      expect(all.band, RiskBand.red);

      expect(fired(assess(healthy(temp: 38.5, hr: 110, spo2: 98)),
          RuleId.sepsisScreen), isFalse);
      expect(fired(assess(healthy(temp: 36.5, hr: 110, spo2: 93)),
          RuleId.sepsisScreen), isFalse);
      expect(fired(assess(healthy(temp: 38.5, hr: 80, spo2: 93)),
          RuleId.sepsisScreen), isFalse);
    });

    test('does not fire when a component was never measured', () {
      expect(fired(assess(healthy(temp: 38.5, hr: 110, spo2: 0)),
          RuleId.sepsisScreen), isFalse);
    });
  });

  group('symptom rules', () {
    test('a danger sign alone reaches RED with normal vitals', () {
      final a = assess(healthy(), symptoms: const ['Chest discomfort']);
      expect(fired(a, RuleId.redFlagSymptoms), isTrue);
      expect(a.band, RiskBand.red);
    });

    test('respiratory symptom points are capped', () {
      final a = assess(healthy(),
          symptoms: const ['Cough', 'Breathlessness', 'Sore throat']);
      final rule =
          a.firedRules.firstWhere((r) => r.id == RuleId.respiratorySymptoms);
      expect(rule.points, lessThanOrEqualTo(15));
    });

    test('three or more symptoms fires the multiple-symptoms rule', () {
      expect(
          fired(
              assess(healthy(),
                  symptoms: const ['Fever', 'Cough', 'Body pain']),
              RuleId.multipleSymptoms),
          isTrue);
      expect(
          fired(assess(healthy(), symptoms: const ['Fever', 'Cough']),
              RuleId.multipleSymptoms),
          isFalse);
    });

    test('two dehydration symptoms fire, one does not', () {
      expect(
          fired(assess(healthy(), symptoms: const ['Vomiting', 'Diarrhea']),
              RuleId.dehydrationSymptoms),
          isTrue);
      expect(
          fired(assess(healthy(), symptoms: const ['Vomiting']),
              RuleId.dehydrationSymptoms),
          isFalse);
    });

    test('symptom matching is case- and whitespace-insensitive', () {
      final a = assess(healthy(), symptoms: const ['  BREATHLESSNESS  ']);
      expect(fired(a, RuleId.respiratorySymptoms), isTrue);
    });

    test('duplicate symptoms are not double-counted', () {
      final once = assess(healthy(), symptoms: const ['Cough']);
      final twice = assess(healthy(), symptoms: const ['Cough', 'cough']);
      expect(twice.score, once.score);
    });

    test('empty and blank symptom entries are ignored', () {
      final a = assess(healthy(), symptoms: const ['', '   ']);
      expect(a.score, 0);
      expect(a.band, RiskBand.green);
    });
  });

  group('vulnerability-adjusted thresholds', () {
    test('elderly flag tightens SpO2 so the same reading escalates', () {
      // 93% is unremarkable for an adult and a warning for an elderly patient.
      expect(fired(assess(healthy(spo2: 93)), RuleId.spo2Warning), isTrue);
      final elderly = assess(healthy(spo2: 93), age: 70);
      expect(elderly.thresholds.spo2Warning, 96);
      expect(elderly.thresholds.spo2Critical, 91);
      expect(elderly.score, greaterThan(assess(healthy(spo2: 93)).score));
    });

    test('92% SpO2 is a warning for an adult but critical for an elderly patient',
        () {
      expect(fired(assess(healthy(spo2: 92)), RuleId.spo2Warning), isTrue);
      final elderly = assess(healthy(spo2: 90), age: 70);
      expect(fired(elderly, RuleId.spo2Critical), isTrue);
      expect(elderly.band, RiskBand.red);
    });

    test('age alone implies the elderly flag with no box ticked', () {
      // Guards against a data-entry omission triaging an 80-year-old on adult
      // defaults.
      final a = assess(healthy(), age: 80);
      expect(a.flags, contains(Vulnerability.elderly));
      expect(a.thresholds.isAdjusted, isTrue);
    });

    test('the elderly boundary is 65 inclusive', () {
      expect(assess(healthy(), age: 64).flags, isNot(contains(Vulnerability.elderly)));
      expect(assess(healthy(), age: 65).flags, contains(Vulnerability.elderly));
    });

    test('elderly fever threshold is lowered, not raised', () {
      final a = assess(healthy(temp: 37.8), age: 70);
      expect(a.thresholds.tempFever, 37.7);
      expect(fired(a, RuleId.tempFever), isTrue);
      expect(fired(assess(healthy(temp: 37.8)), RuleId.tempFever), isFalse);
    });

    test('pregnancy raises HR limits instead of tightening them', () {
      // A resting pulse of 105 is normal in pregnancy. Tightening here would
      // fire tachycardia on every routine screening.
      expect(fired(assess(healthy(hr: 105)), RuleId.hrTachyWarning), isTrue);
      final pregnant = assess(healthy(hr: 105), flags: {Vulnerability.pregnant});
      expect(pregnant.thresholds.hrHighWarning, 110);
      expect(fired(pregnant, RuleId.hrTachyWarning), isFalse);
    });

    test('pregnancy still lowers the fever threshold', () {
      final a = assess(healthy(temp: 37.6), flags: {Vulnerability.pregnant});
      expect(a.thresholds.tempFever, 37.5);
      expect(fired(a, RuleId.tempFever), isTrue);
    });

    test('pregnancy HR shift survives a co-occurring elderly flag', () {
      // The physiological shift owns the vital; the caution flag must not
      // silently undo it.
      final a = assess(healthy(),
          age: 70, flags: {Vulnerability.pregnant, Vulnerability.elderly});
      expect(a.thresholds.hrHighWarning, 110);
      expect(a.thresholds.spo2Warning, 96, reason: 'elderly still tightens SpO2');
    });

    test('infant physiology raises HR limits far above adult', () {
      final a = assess(healthy(hr: 140), age: 0);
      expect(a.flags, contains(Vulnerability.infant));
      expect(a.thresholds.hrHighWarning, 160);
      expect(fired(a, RuleId.hrTachyWarning), isFalse);
      expect(fired(assess(healthy(hr: 140)), RuleId.hrTachyCritical), isTrue);
    });

    test('infant flag beats pregnancy if both are somehow set', () {
      final a = assess(healthy(), age: 0, flags: {Vulnerability.pregnant});
      expect(a.thresholds.hrHighWarning, 160);
    });

    test('immunocompromised lowers the fever threshold', () {
      final a =
          assess(healthy(temp: 37.6), flags: {Vulnerability.immunocompromised});
      expect(a.thresholds.tempFever, 37.5);
      expect(fired(a, RuleId.tempFever), isTrue);
    });

    test('chronic tightens HR and SpO2', () {
      final a = assess(healthy(), flags: {Vulnerability.chronic});
      expect(a.thresholds.hrHighWarning, 95);
      expect(a.thresholds.spo2Warning, 96);
    });

    test('threshold resolution does not depend on flag set order', () {
      final combos = [
        {Vulnerability.elderly, Vulnerability.chronic},
        {Vulnerability.chronic, Vulnerability.elderly},
      ];
      final results = combos
          .map((f) => VitalThresholds.forPatient(age: 30, flags: f).toString())
          .toSet();
      expect(results.length, 1, reason: 'order changed the thresholds');
    });

    test('each flag contributes its documented points', () {
      // Each sample must be unremarkable *under that flag's own thresholds* —
      // 72 bpm is normal for an adult and bradycardic for an infant, so a
      // single shared sample would fire a rule and inflate the score.
      final samples = <Vulnerability, HealthSample>{
        Vulnerability.elderly: healthy(),
        Vulnerability.chronic: healthy(),
        Vulnerability.pregnant: healthy(),
        Vulnerability.infant: healthy(hr: 130),
        Vulnerability.immunocompromised: healthy(),
      };
      for (final flag in Vulnerability.values) {
        final a = assess(samples[flag]!, flags: {flag});
        expect(a.score, flag.riskPoints,
            reason: '${flag.id} should contribute exactly its riskPoints, '
                'but also fired ${a.scoringRules.map((r) => r.id)}');
      }
    });

    test('adult defaults are genuinely unadjusted', () {
      expect(assess(healthy(), age: 30).thresholds.isAdjusted, isFalse);
    });
  });

  group('regressions from the previous engine', () {
    test('evaluate() does not throw on the double/int threshold map', () {
      // The old engine did Map<String,int>.from(Map<String,double>), which threw
      // a TypeError on every single call.
      expect(() => RiskEngine.evaluate(sample: healthy(), symptoms: const []),
          returnsNormally);
    });

    test('the pregnancy fever rule is reachable', () {
      // It previously compared degrees Celsius against 375, so it could only
      // fire at 375 C.
      final a = assess(healthy(temp: 38.0), flags: {Vulnerability.pregnant});
      expect(fired(a, RuleId.tempFever), isTrue);
    });

    test('legacy evaluate() agrees with assess() on band and score', () {
      final sample = healthy(spo2: 88, hr: 120, temp: 38.6);
      final legacy =
          RiskEngine.evaluate(sample: sample, symptoms: const ['Cough']);
      final modern = assess(sample, symptoms: const ['Cough']);
      expect(legacy.level, modern.band.storageValue);
      expect(legacy.score, modern.score);
    });

    test('the same input always produces the same output', () {
      final sample = healthy(spo2: 91, hr: 118, temp: 38.4);
      const symptoms = ['Cough', 'Fever', 'Dizziness'];
      final first = assess(sample, symptoms: symptoms, age: 70);
      for (var i = 0; i < 20; i++) {
        final again = assess(sample, symptoms: symptoms, age: 70);
        expect(again.score, first.score);
        expect(again.band, first.band);
        expect(again.ruleIds, first.ruleIds,
            reason: 'rule order must be stable for cached explanations');
      }
    });

    test('every fired rule has a plain-language description', () {
      // The offline explainer falls back to these, so a missing entry is a
      // silently empty explanation card.
      final a = assess(
        healthy(spo2: 85, hr: 140, temp: 39.5, ecgQuality: 0.3),
        symptoms: const ['Cough', 'Chest discomfort', 'Vomiting', 'Diarrhea'],
        age: 75,
        flags: {Vulnerability.chronic, Vulnerability.immunocompromised},
      );
      for (final id in a.ruleIds) {
        expect(RiskEngine.ruleDescriptions.containsKey(id), isTrue,
            reason: 'no description for rule "$id"');
      }
    });

    test('no rule display string leaks a raw enum or identifier', () {
      final a = assess(
        healthy(spo2: 85, hr: 140, temp: 39.5),
        symptoms: const ['Cough', 'Chest discomfort'],
        age: 75,
        flags: {Vulnerability.pregnant},
      );
      for (final rule in a.firedRules) {
        expect(rule.display, isNot(contains('Vulnerability.')));
        expect(rule.display, isNot(contains('RiskBand.')));
        expect(rule.display, isNot(contains('_')),
            reason: 'snake_case in "${rule.display}" looks like a raw id');
      }
    });
  });

  group('recommended action and escalation', () {
    test('each band maps to a distinct action and escalation level', () {
      final actions =
          RiskBand.values.map(RiskEngine.recommendedActionFor).toSet();
      expect(actions.length, RiskBand.values.length);

      expect(RiskEngine.escalationLevelFor(RiskBand.green), 'NONE');
      expect(RiskEngine.escalationLevelFor(RiskBand.yellow), 'CLINIC_VISIT');
      expect(RiskEngine.escalationLevelFor(RiskBand.red), 'EMERGENCY');
    });

    test('no recommended action claims to diagnose', () {
      for (final band in RiskBand.values) {
        final text = RiskEngine.recommendedActionFor(band).toLowerCase();
        for (final banned in ['diagnos', 'you have', 'confirmed']) {
          expect(text.contains(banned), isFalse,
              reason: '"$banned" in ${band.storageValue} action text');
        }
      }
    });

    test('toResult round-trips band, score and rule text', () {
      final a = assess(healthy(spo2: 88), symptoms: const ['Cough']);
      final r = a.toResult();
      expect(r.level, a.band.storageValue);
      expect(r.score, a.score);
      expect(r.triggeredRules.length, a.firedRules.length);
      expect(r.escalationLevel, a.escalationLevel);
    });
  });
}
