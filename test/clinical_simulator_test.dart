import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/vernacular_guidance_service.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/offline_explainer.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/domain/simulator/clinical_scenario.dart';

void main() {
  group('Virtual Patient Clinical Scenarios', () {
    test('all 6 predefined clinical scenarios exist and have valid vitals', () {
      expect(ClinicalScenario.all.length, 6);

      for (final scenario in ClinicalScenario.all) {
        expect(scenario.name, isNotEmpty);
        expect(scenario.subtitle, isNotEmpty);
        expect(scenario.heartRateBpm, greaterThan(0));
        expect(scenario.spo2Percent, inInclusiveRange(70, 100));
        expect(scenario.temperatureC, inInclusiveRange(34.0, 43.0));
        expect(scenario.estimatedGlucose, greaterThan(0));
        expect(scenario.systolicBp, greaterThan(scenario.diastolicBp));
      }
    });

    test('hypoxemia pneumonia scenario produces RED triage alert', () {
      final scenario = ClinicalScenario.findById('hypoxemia_pneumonia');
      expect(scenario.expectedBand, RiskBand.red);

      final sample = HealthSample(
        timestamp: 0,
        heartRateBpm: scenario.heartRateBpm,
        spo2Percent: scenario.spo2Percent,
        temperatureC: scenario.temperatureC,
        estimatedGlucose: scenario.estimatedGlucose,
        estimatedSystolic: scenario.systolicBp,
        estimatedDiastolic: scenario.diastolicBp,
        ecgSignalQuality: scenario.ecgQuality,
        rPeakDetected: true,
        rrIntervalMs: (60000 / scenario.heartRateBpm).round(),
        batteryPercent: 90,
      );

      final assessment = RiskEngine.assess(
        sample: sample,
        symptoms: scenario.typicalSymptoms,
      );

      expect(assessment.band, RiskBand.red);
      expect(assessment.hasCritical, isTrue);
    });

    test('hyperglycemia DKA scenario triggers critical glucose rule and RED band', () {
      final scenario = ClinicalScenario.findById('hyperglycemia_dka');

      final sample = HealthSample(
        timestamp: 0,
        heartRateBpm: scenario.heartRateBpm,
        spo2Percent: scenario.spo2Percent,
        temperatureC: scenario.temperatureC,
        estimatedGlucose: scenario.estimatedGlucose,
        estimatedSystolic: scenario.systolicBp,
        estimatedDiastolic: scenario.diastolicBp,
        ecgSignalQuality: scenario.ecgQuality,
        rPeakDetected: true,
        rrIntervalMs: (60000 / scenario.heartRateBpm).round(),
        batteryPercent: 90,
      );

      final assessment = RiskEngine.assess(
        sample: sample,
        symptoms: scenario.typicalSymptoms,
      );

      expect(assessment.band, RiskBand.red);
      expect(assessment.ruleIds, contains(RuleId.glucoseHyperglycemiaCritical));
    });

    test('hypoglycemia shock scenario triggers hypoglycemia rule', () {
      final scenario = ClinicalScenario.findById('hypoglycemia_shock');

      final sample = HealthSample(
        timestamp: 0,
        heartRateBpm: scenario.heartRateBpm,
        spo2Percent: scenario.spo2Percent,
        temperatureC: scenario.temperatureC,
        estimatedGlucose: scenario.estimatedGlucose,
        estimatedSystolic: scenario.systolicBp,
        estimatedDiastolic: scenario.diastolicBp,
        ecgSignalQuality: scenario.ecgQuality,
        rPeakDetected: true,
        rrIntervalMs: (60000 / scenario.heartRateBpm).round(),
        batteryPercent: 90,
      );

      final assessment = RiskEngine.assess(
        sample: sample,
        symptoms: scenario.typicalSymptoms,
      );

      expect(assessment.ruleIds, contains(RuleId.glucoseHypoglycemia));
    });
  });

  group('OfflineExplainer Blood Glucose & BP Integration', () {
    test('OfflineExplainer includes blood glucose and blood pressure in summary', () {
      final sample = HealthSample(
        timestamp: 0,
        heartRateBpm: 72,
        spo2Percent: 98,
        temperatureC: 36.6,
        estimatedGlucose: 110,
        estimatedSystolic: 120,
        estimatedDiastolic: 80,
        ecgSignalQuality: 0.95,
        rPeakDetected: true,
        rrIntervalMs: 833,
        batteryPercent: 90,
      );

      final assessment = RiskEngine.assess(sample: sample, symptoms: const []);
      final explanation = OfflineExplainer.build(assessment: assessment, patientName: 'Meena');

      expect(explanation.summary, contains('blood glucose 110 mg/dL'));
      expect(explanation.summary, contains('blood pressure 120/80 mmHg'));
      expect(explanation.whyThisLevel, contains('Blood glucose inside expected range'));
    });

    test('OfflineExplainer provides hypoglycemia immediate dietary guidance', () {
      final sample = HealthSample(
        timestamp: 0,
        heartRateBpm: 72,
        spo2Percent: 98,
        temperatureC: 36.6,
        estimatedGlucose: 55,
        estimatedSystolic: 110,
        estimatedDiastolic: 70,
        ecgSignalQuality: 0.95,
        rPeakDetected: true,
        rrIntervalMs: 833,
        batteryPercent: 90,
      );

      final assessment = RiskEngine.assess(sample: sample, symptoms: const []);
      final explanation = OfflineExplainer.build(assessment: assessment);

      expect(explanation.safeNextSteps, contains('Immediate Hypoglycemia Guidance'));
      expect(explanation.safeNextSteps, contains('fast-acting sugar'));
      expect(explanation.questionsToAsk.any((q) => q.contains('sugary drink')), isTrue);
    });
  });

  group('ASHA Vernacular Guidance Service', () {
    test('generates localized guidance across Hindi, Bengali, and English', () {
      final sample = HealthSample(
        timestamp: 0,
        heartRateBpm: 125,
        spo2Percent: 85,
        temperatureC: 39.8,
        estimatedGlucose: 270,
        estimatedSystolic: 140,
        estimatedDiastolic: 90,
        ecgSignalQuality: 0.9,
        rPeakDetected: true,
        rrIntervalMs: 480,
        batteryPercent: 85,
      );

      final assessment = RiskEngine.assess(
        sample: sample,
        symptoms: const ['High Fever', 'Breathlessness'],
      );

      final allGuidance = VernacularGuidanceService.generateAll(
        assessment: assessment,
        patientName: 'Sunita Devi',
      );

      expect(allGuidance.containsKey('hi'), isTrue);
      expect(allGuidance.containsKey('bn'), isTrue);
      expect(allGuidance.containsKey('en'), isTrue);

      // Hindi
      final hi = allGuidance['hi']!;
      expect(hi.languageName, 'हिन्दी');
      expect(hi.spokenText, contains('Sunita Devi'));
      expect(hi.spokenText, contains('ऑक्सीजन'));
      expect(hi.dangerSigns, isNotEmpty);

      // Bengali
      final bn = allGuidance['bn']!;
      expect(bn.languageName, 'বাংলা');
      expect(bn.spokenText, contains('Sunita Devi'));
      expect(bn.spokenText, contains('অক্সিজেনের মাত্রা'));

      // English
      final en = allGuidance['en']!;
      expect(en.languageName, 'English');
      expect(en.spokenText, contains('Sunita Devi'));
      expect(en.spokenText, contains('Oxygen saturation'));
    });
  });
}
