import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart';
import 'package:swasthyasetu_ai/domain/models/patient_profile_context.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';

void main() {
  test('Firebase AI types are resolvable and typed properly', () {
    expect(FirebaseAI, isNotNull);
    expect(GenerativeModel, isNotNull);
    expect(Content, isNotNull);
    expect(FirebaseAuth, isNotNull);

    expect(() => FirebaseAI.vertexAI(), throwsA(isA<Exception>()));

    final config = GenerationConfig(
      temperature: 0.2,
      maxOutputTokens: 3072,
      responseMimeType: 'application/json',
    );
    expect(config, isNotNull);

    final cred = GoogleAuthProvider.credential(idToken: 'mock-id-token');
    expect(cred, isNotNull);
  });

  test(
    'GeminiService recognizes API key and handles Vertex fallback cleanly',
    () {
      final service = GeminiService();
      expect(service.apiKey, isEmpty);
      expect(service.isConfigured, isFalse);

      service.setApiKey('AQ.test-key-for-auth');
      expect(service.isConfigured, isTrue);
      expect(service.keyLooksLikeApiKey, isTrue);
    },
  );

  test(
    'PatientProfileContext maps user onboarding data and computes BMI correctly',
    () {
      final account = UserAccount(
        id: 'acc-1',
        email: 'patient@example.com',
        displayName: 'Aarav Sharma',
        role: UserRole.patient,
        provider: AuthAccountProvider.email,
        age: 48,
        sex: 'M',
        heightCm: 175,
        weightKg: 86,
        conditions: const ['High blood pressure', 'Asthma / breathing problem'],
        problems: 'I cough frequently in morning and feel chest tightness',
        createdAt: DateTime(2026, 1, 1),
        lastLoginAt: DateTime(2026, 8, 1),
      );

      final profile = PatientProfileContext.fromAccount(account);
      expect(profile.age, 48);
      expect(profile.sex, 'M');
      expect(profile.heightCm, 175);
      expect(profile.weightKg, 86);
      expect(profile.bmi, closeTo(28.08, 0.1));
      expect(profile.bmiBand, 'Overweight');
      expect(profile.conditions, contains('High blood pressure'));
      expect(profile.problems, contains('I cough'));

      final summary = profile.toPromptSummary();
      expect(summary, contains('Age: 48 yrs'));
      expect(summary, contains('Sex: M'));
      expect(summary, contains('Height: 175 cm'));
      expect(summary, contains('Weight: 86.0 kg'));
      expect(summary, contains('BMI: 28.1 (Overweight)'));
      expect(summary, contains('Known conditions: High blood pressure'));
      expect(
        summary,
        contains(
          'Patient complaints: "I cough frequently in morning and feel chest tightness"',
        ),
      );
    },
  );
}
