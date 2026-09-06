import 'package:flutter/foundation.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// A predefined clinical scenario for the Virtual Patient Simulator.
///
/// Allows complete testing of triage rules, AI explanations, vernacular audio,
/// and clinical pathways without physical hardware.
@immutable
class ClinicalScenario {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final RiskBand expectedBand;
  final int heartRateBpm;
  final int spo2Percent;
  final double temperatureC;
  final int estimatedGlucose;
  final int systolicBp;
  final int diastolicBp;
  final List<String> typicalSymptoms;
  final bool isArrhythmia;
  final double ecgQuality;

  const ClinicalScenario({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.expectedBand,
    required this.heartRateBpm,
    required this.spo2Percent,
    required this.temperatureC,
    required this.estimatedGlucose,
    required this.systolicBp,
    required this.diastolicBp,
    this.typicalSymptoms = const [],
    this.isArrhythmia = false,
    this.ecgQuality = 0.95,
  });

  /// The standard catalog of clinical scenarios representing common rural Indian primary care cases.
  static const List<ClinicalScenario> all = [
    ClinicalScenario(
      id: 'normal_adult',
      name: 'Healthy Adult (Normal)',
      subtitle: 'HR 72, SpO2 98%, Temp 36.6°C, Glucose 95',
      description: 'Resting normal vitals inside standard clinical safety ranges.',
      expectedBand: RiskBand.green,
      heartRateBpm: 72,
      spo2Percent: 98,
      temperatureC: 36.6,
      estimatedGlucose: 95,
      systolicBp: 120,
      diastolicBp: 80,
      typicalSymptoms: [],
      isArrhythmia: false,
    ),
    ClinicalScenario(
      id: 'hypoxemia_pneumonia',
      name: 'Severe Hypoxemia (Pneumonia)',
      subtitle: 'HR 118, SpO2 84%, Temp 38.9°C, Glucose 105',
      description: 'Acute respiratory distress syndrome / severe pneumonia with dangerous oxygen desaturation.',
      expectedBand: RiskBand.red,
      heartRateBpm: 118,
      spo2Percent: 84,
      temperatureC: 38.9,
      estimatedGlucose: 105,
      systolicBp: 135,
      diastolicBp: 85,
      typicalSymptoms: ['Breathlessness', 'High Fever', 'Cough'],
      isArrhythmia: false,
    ),
    ClinicalScenario(
      id: 'hyperglycemia_dka',
      name: 'Diabetic Emergency (Hyperglycemia)',
      subtitle: 'Glucose 285 mg/dL, HR 104, SpO2 97%',
      description: 'Critical blood glucose above 250 mg/dL with tachycardia, alerting for Diabetic Ketoacidosis risk.',
      expectedBand: RiskBand.red,
      heartRateBpm: 104,
      spo2Percent: 97,
      temperatureC: 36.8,
      estimatedGlucose: 285,
      systolicBp: 145,
      diastolicBp: 92,
      typicalSymptoms: ['Extreme Thirst', 'Dizziness', 'Frequent Urination'],
      isArrhythmia: false,
    ),
    ClinicalScenario(
      id: 'hypoglycemia_shock',
      name: 'Hypoglycemic Shock (Severe Low Sugar)',
      subtitle: 'Glucose 52 mg/dL, HR 98, Cold Clammy Skin',
      description: 'Life-threatening hypoglycemia below 70 mg/dL requiring immediate fast-acting oral glucose.',
      expectedBand: RiskBand.red,
      heartRateBpm: 98,
      spo2Percent: 96,
      temperatureC: 35.8,
      estimatedGlucose: 52,
      systolicBp: 100,
      diastolicBp: 65,
      typicalSymptoms: ['Dizziness', 'Cold Sweats', 'Shakiness'],
      isArrhythmia: false,
    ),
    ClinicalScenario(
      id: 'heat_stroke',
      name: 'Heat Stroke (Hyperthermia Crisis)',
      subtitle: 'Temp 40.2°C, HR 136, Severe Dehydration',
      description: 'Extreme core temperature elevation during hot climatic conditions triggering multi-organ stress.',
      expectedBand: RiskBand.red,
      heartRateBpm: 136,
      spo2Percent: 94,
      temperatureC: 40.2,
      estimatedGlucose: 110,
      systolicBp: 105,
      diastolicBp: 70,
      typicalSymptoms: ['High Fever', 'Confusion', 'Dizziness'],
      isArrhythmia: false,
    ),
    ClinicalScenario(
      id: 'arrhythmia_afib',
      name: 'Cardiac Arrhythmia (Tachy / AFib)',
      subtitle: 'HR 145, Irregular RR intervals, SpO2 95%',
      description: 'Rapid, irregular heart rhythm exhibiting chaotic beat-to-beat scatter.',
      expectedBand: RiskBand.yellow,
      heartRateBpm: 145,
      spo2Percent: 95,
      temperatureC: 36.7,
      estimatedGlucose: 100,
      systolicBp: 130,
      diastolicBp: 85,
      typicalSymptoms: ['Palpitations', 'Chest Pain', 'Dizziness'],
      isArrhythmia: true,
    ),
  ];

  static ClinicalScenario get defaultScenario => all.first;

  static ClinicalScenario findById(String id) {
    return all.firstWhere(
      (s) => s.id == id,
      orElse: () => defaultScenario,
    );
  }
}
