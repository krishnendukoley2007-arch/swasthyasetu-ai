import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/seed_service.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

import 'support/harness.dart';

/// The auth layer gates who sees whose data on a shared field phone, so its
/// failure modes — wrong password, duplicate email, role confusion — are the
/// tests that matter, not the happy path alone.
void main() {
  /// Lets the controller's async `_restore` settle against the in-memory DB.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  group('AuthRepository', () {
    test('register → session is active → sign-in round trip works', () async {
      final harness = await TestHarness.create();
      final repo = harness.container.read(authRepositoryProvider);

      final account = await repo.registerWithEmail(
        email: 'Asha.Worker@Health.gov',
        password: 'monsoon-2026',
        displayName: 'Asha Worker',
        role: UserRole.clinician,
      );

      // Email is normalised: mixed case and keyboard auto-capitalisation must
      // not fork one person into two accounts.
      expect(account.email, 'asha.worker@health.gov');
      expect(await repo.activeAccountId(), account.id);

      await repo.endSession();
      final back = await repo.signInWithEmail(
        email: '  ASHA.WORKER@health.gov ',
        password: 'monsoon-2026',
      );
      expect(back.id, account.id);
    });

    test('wrong password is indistinguishable from unknown account', () async {
      final harness = await TestHarness.create();
      final repo = harness.container.read(authRepositoryProvider);

      await repo.registerWithEmail(
        email: 'nurse@example.com',
        password: 'correct horse',
        displayName: 'Nurse',
        role: UserRole.clinician,
      );

      for (final attempt in [
        () => repo.signInWithEmail(email: 'nurse@example.com', password: 'nope'),
        () => repo.signInWithEmail(email: 'ghost@example.com', password: 'nope'),
      ]) {
        await expectLater(
          attempt(),
          throwsA(isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.wrongCredentials,
          )),
        );
      }
    });

    test('duplicate email registration is refused', () async {
      final harness = await TestHarness.create();
      final repo = harness.container.read(authRepositoryProvider);
      await repo.registerWithEmail(
        email: 'me@example.com',
        password: 'first-pass',
        displayName: 'Me',
        role: UserRole.patient,
      );

      await expectLater(
        repo.registerWithEmail(
          email: 'me@example.com',
          password: 'second-pass',
          displayName: 'Also Me',
          role: UserRole.clinician,
        ),
        throwsA(isA<AuthException>()
            .having((e) => e.failure, 'failure', AuthFailure.emailInUse)),
      );
    });

    test('a Google identity cannot change the role an account registered with',
        () async {
      final harness = await TestHarness.create();
      final repo = harness.container.read(authRepositoryProvider);

      // Patient registers with email first…
      await repo.registerWithEmail(
        email: 'rin@example.com',
        password: 'secret-1',
        displayName: 'Rin',
        role: UserRole.patient,
      );
      await repo.endSession();

      // …then later taps "Continue with Google" from the clinician side.
      final again = await repo.signInWithGoogleIdentity(
        email: 'rin@example.com',
        displayName: 'Rin',
        roleForNewAccounts: UserRole.clinician,
      );

      // The stored role wins; the tap cannot promote her.
      expect(again.role, UserRole.patient);
    });
  });

  group('AuthController', () {
    test('signed out on a cold install', () async {
      final harness = await TestHarness.create();
      harness.container.read(authStateProvider.notifier);
      await settle();
      expect(harness.container.read(authStateProvider).status,
          AuthStatus.signedOut);
    });

    test('patient registration holds at needsProfile until the form is done',
        () async {
      final harness = await TestHarness.create();
      final auth = harness.container.read(authStateProvider.notifier);
      await settle();

      await auth.registerWithEmail(
        email: 'mira@example.com',
        password: 'safe-pass',
        displayName: 'Mira Das',
        role: UserRole.patient,
      );

      var state = harness.container.read(authStateProvider);
      expect(state.status, AuthStatus.needsProfile);
      // The AI voice flipped with the role.
      expect(harness.container.read(settingsProvider).audience,
          Audience.patient);

      await auth.completePatientProfile(
        displayName: 'Mira Das',
        age: 29,
        sex: 'F',
        heightCm: 158,
        weightKg: 54,
        conditions: const ['Diabetes'],
        problems: 'feeling dizzy since morning',
        emergencyName: 'Ravi Das',
        emergencyPhone: '+91 98765 43210',
      );

      state = harness.container.read(authStateProvider);
      expect(state.status, AuthStatus.signedIn);
      expect(state.account!.profileComplete, isTrue);

      // Linked screening subject exists, with the diabetes flag applied.
      final patient = await harness.container
          .read(myPatientProvider.future);
      expect(patient, isNotNull);
      expect(patient!.name, 'Mira Das');
      expect(patient.vulnerabilityFlags, contains('chronic'));
      expect(patient.notes, contains('BMI'));

      // Emergency contact landed as the primary SOS target.
      final contacts = await harness.container
          .read(emergencyRepositoryProvider)
          .getContacts();
      expect(contacts.single.isPrimary, isTrue);
      expect(contacts.single.phone, '+919876543210');
    });

    test('clinician registration signs straight in with nurse wording',
        () async {
      final harness = await TestHarness.create();
      final auth = harness.container.read(authStateProvider.notifier);
      await settle();

      await auth.registerWithEmail(
        email: 'worker@example.com',
        password: 'safe-pass',
        displayName: 'Field Worker',
        role: UserRole.clinician,
      );

      final state = harness.container.read(authStateProvider);
      expect(state.status, AuthStatus.signedIn);
      expect(harness.container.read(settingsProvider).audience,
          Audience.nurse);
    });

    test('sign out ends the session and returns to signed-out', () async {
      final harness = await TestHarness.create();
      final auth = harness.container.read(authStateProvider.notifier);
      await settle();

      await auth.registerWithEmail(
        email: 'm@example.com',
        password: 'safe-pass',
        displayName: 'M',
        role: UserRole.clinician,
      );
      await auth.signOut();

      expect(harness.container.read(authStateProvider).status,
          AuthStatus.signedOut);
    });

    test('session survives a simulated cold start', () async {
      final harness = await TestHarness.create();
      final auth = harness.container.read(authStateProvider.notifier);
      await settle();
      await auth.registerWithEmail(
        email: 'stay@example.com',
        password: 'safe-pass',
        displayName: 'Stay',
        role: UserRole.clinician,
      );

      // A second container over the SAME database is a cold start.
      final container2 = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(harness.db),
        bootstrapProvider.overrideWith((ref) async => const SeedReport()),
      ]);
      addTearDown(container2.dispose);
      final revived = container2.read(authStateProvider.notifier);
      await settle();
      expect(revived.state.status, AuthStatus.signedIn);
      expect(revived.state.account!.email, 'stay@example.com');
    });
  });
}
