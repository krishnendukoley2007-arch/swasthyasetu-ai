import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';

/// Context about the human being holding the phone, collected at onboarding
/// and registration.
///
/// Pure Dart, domain-layer: contains zero Flutter UI dependencies so it can be
/// unit-tested and serialized cleanly.
class PatientProfileContext {
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final String? bmiBand;
  final List<String> conditions;
  final String? problems;

  const PatientProfileContext({
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.bmiBand,
    this.conditions = const [],
    this.problems,
  });

  factory PatientProfileContext.fromAccount(UserAccount? account) {
    if (account == null) return const PatientProfileContext();
    return PatientProfileContext(
      age: account.age,
      sex: account.sex,
      heightCm: account.heightCm,
      weightKg: account.weightKg,
      bmi: account.bmi,
      bmiBand: account.bmiBand,
      conditions: account.conditions,
      problems: account.problems,
    );
  }

  factory PatientProfileContext.fromPatient(
    Patient? patient, {
    String? complaints,
  }) {
    if (patient == null) return const PatientProfileContext();
    return PatientProfileContext(
      age: patient.age,
      sex: patient.sex,
      conditions: patient.vulnerabilityFlags,
      problems: complaints ?? patient.notes,
    );
  }

  bool get isEmpty =>
      age == null &&
      (sex == null || sex!.isEmpty) &&
      heightCm == null &&
      weightKg == null &&
      conditions.isEmpty &&
      (problems == null || problems!.trim().isEmpty);

  /// Formats a dense, concise summary line for LLM prompts ("prompt should be less").
  String toPromptSummary() {
    final parts = <String>[];
    if (age != null) parts.add('Age: $age yrs');
    if (sex != null && sex!.isNotEmpty) parts.add('Sex: $sex');
    if (heightCm != null) {
      parts.add('Height: ${heightCm!.toStringAsFixed(0)} cm');
    }
    if (weightKg != null) {
      parts.add('Weight: ${weightKg!.toStringAsFixed(1)} kg');
    }
    if (bmi != null) {
      final bandStr = bmiBand != null ? ' ($bmiBand)' : '';
      parts.add('BMI: ${bmi!.toStringAsFixed(1)}$bandStr');
    }
    if (conditions.isNotEmpty) {
      parts.add('Known conditions: ${conditions.join(", ")}');
    }
    if (problems != null && problems!.trim().isNotEmpty) {
      parts.add('Patient complaints: "${problems!.trim()}"');
    }
    return parts.join(' | ');
  }
}
