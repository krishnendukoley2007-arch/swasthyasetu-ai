import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/data/repositories/auth_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:uuid/uuid.dart';

/// Where the session stands. The router's redirect reads exactly this:
///
/// - [unknown]: cold start, still reading SQLite — hold on the splash.
/// - [signedOut]: nobody is in — hold on /login.
/// - [needsProfile]: a patient with no registration profile yet — held on
///   /register/patient, because a screening without age/sex/body measurements
///   would be scored against defaults the app cannot defend.
/// - [signedIn]: route by role (patient → /my-health, clinician → /home).
/// - [demo]: the old demo entry, kept — a clinician shell with no account, so
///   the offline demo walkthrough still works with no setup at all.
enum AuthStatus { unknown, signedOut, needsProfile, signedIn, demo }

@immutable
class AuthState {
  final AuthStatus status;
  final UserAccount? account;

  const AuthState({required this.status, this.account});

  const AuthState.unknown()
      : status = AuthStatus.unknown,
        account = null;

  const AuthState.signedOut()
      : status = AuthStatus.signedOut,
        account = null;

  bool get isSignedIn =>
      status == AuthStatus.signedIn || status == AuthStatus.demo;

  AuthState copyWith({AuthStatus? status, UserAccount? account}) => AuthState(
        status: status ?? this.status,
        account: account ?? this.account,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.unknown()) {
    _restore();
  }

  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    try {
      final account = await _repo.activeAccount();
      state = _stateFor(account);
      if (account != null) _applyRoleSideEffects(account);
    } catch (_) {
      // A corrupt session row must never brick the app behind a spinner —
      // fall back to signed-out, the login screen is always reachable.
      state = const AuthState.signedOut();
    }
  }

  static AuthState _stateFor(UserAccount? account) {
    if (account == null) return const AuthState.signedOut();
    if (account.role == UserRole.patient && !account.profileComplete) {
      return AuthState(status: AuthStatus.needsProfile, account: account);
    }
    return AuthState(status: AuthStatus.signedIn, account: account);
  }

  /// Signing in is what chooses the AI's voice: patient accounts get plain
  /// language and safe home care; clinicians get referral wording. Everything
  /// downstream (`ai_explanation_screen`, chat) reads the audience from
  /// settings, so flipping it here re-voices the whole app in one move.
  void _applyRoleSideEffects(UserAccount account) {
    final settings = _ref.read(settingsProvider.notifier);
    settings.setAudience(
      account.role.isPatient ? Audience.patient : Audience.nurse,
    );
    if (!account.role.isPatient) {
      settings.setWorkerProfile(name: account.displayName);
    }
  }

  // ──────────────────────────── Email ────────────────────────────

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    if (displayName.trim().isEmpty) {
      throw const AuthException(AuthFailure.invalidEmail, 'Name is required');
    }
    final account = await _repo.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
    );
    _applyRoleSideEffects(account);
    state = _stateFor(account);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final account = await _repo.signInWithEmail(
      email: email,
      password: password,
    );
    _applyRoleSideEffects(account);
    state = _stateFor(account);
  }

  // ──────────────────────────── Google ────────────────────────────

  /// [roleForNewAccounts] comes from the card the user tapped before the
  /// Google sheet opened. Returning accounts ignore it — their stored role
  /// wins, so a patient can never promote themselves to clinician by tapping
  /// the other card.
  Future<void> signInWithGoogle({required UserRole roleForNewAccounts}) async {
    final identity =
        await _ref.read(googleAuthServiceProvider).signIn();
    if (identity.email.trim().isEmpty) {
      throw const AuthException(
        AuthFailure.googleUnavailable,
        'Google did not return an email address for this account.',
      );
    }
    final account = await _repo.signInWithGoogleIdentity(
      email: identity.email,
      displayName: identity.displayName,
      photoUrl: identity.photoUrl,
      roleForNewAccounts: roleForNewAccounts,
    );
    _applyRoleSideEffects(account);
    state = _stateFor(account);
  }

  // ─────────────────────── Patient registration ───────────────────────

  /// Completes the registration profile: the account row gets the body
  /// measurements and history, and a Patients row is created as this account's
  /// screening subject so the very first self-check is scored against the
  /// right age, sex and vulnerability thresholds.
  ///
  /// The emergency contact, when given, is written as the primary SOS contact
  /// the moment registration ends — a patient who collapses on screening one
  /// is not asked to configure SOS first.
  ///
  /// All three writes — patient row, emergency contact, account row — run in
  /// one transaction. They used to run in sequence, so a failure on the second
  /// left the patient row updated and the account row stale while the screen
  /// said "Nothing was lost". Either the whole profile lands or none of it
  /// does, and now the message is true.
  Future<void> completePatientProfile({
    required String displayName,
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
    required List<String> conditions,
    String? problems,
    String? emergencyName,
    String? emergencyPhone,
  }) async {
    final account = state.account;
    if (account == null) {
      throw const AuthException(AuthFailure.wrongCredentials);
    }

    final provisional = account.copyWith(
      age: age,
      sex: sex,
      heightCm: heightCm,
      weightKg: weightKg,
      conditions: conditions,
    );

    final bmi = provisional.bmi;
    final noteParts = <String>[
      'Self-registered account. Height ${heightCm.toStringAsFixed(0)} cm, '
          'weight ${weightKg.toStringAsFixed(1)} kg'
          '${bmi != null ? ', BMI ${bmi.toStringAsFixed(1)}' : ''}.',
    ];
    if (conditions.isNotEmpty) {
      noteParts.add('Conditions: ${conditions.join(', ')}.');
    }
    final complaint = problems?.trim();
    if (complaint != null && complaint.isNotEmpty) {
      noteParts.add('Reported problems: $complaint');
    }

    final patientId =
        'PAT-${const Uuid().v4().substring(0, 7).toUpperCase()}';
    final patients = _ref.read(patientRepositoryProvider);
    final emergency = _ref.read(emergencyRepositoryProvider);
    final linkedPatientId = account.patientId;

    final updated =
        await _ref.read(databaseProvider).transaction<UserAccount>(() async {
      String effectivePatientId;
      if (linkedPatientId != null) {
        // Editing (from My Health): update the row the screenings already point
        // at. Creating a second row would orphan the person's own history.
        final existing = await patients.getById(linkedPatientId);
        if (existing != null) {
          await patients.save(existing.copyWith(
            name: displayName.trim(),
            age: age,
            sex: sex,
            notes: noteParts.join(' '),
            vulnerabilityFlags: provisional.vulnerabilityFlags,
          ));
          effectivePatientId = linkedPatientId;
        } else {
          final created = await patients.create(
            id: patientId,
            name: displayName.trim(),
            age: age,
            sex: sex,
            notes: noteParts.join(' '),
            vulnerabilityFlags: provisional.vulnerabilityFlags,
          );
          effectivePatientId = created.id;
        }
      } else {
        final created = await patients.create(
          id: patientId,
          name: displayName.trim(),
          age: age,
          sex: sex,
          notes: noteParts.join(' '),
          vulnerabilityFlags: provisional.vulnerabilityFlags,
        );
        effectivePatientId = created.id;
      }

      final contactName = emergencyName?.trim() ?? '';
      final contactPhone = emergencyPhone?.trim() ?? '';
      if (contactName.isNotEmpty &&
          EmergencyRepository.isDiallable(contactPhone)) {
        // Reuse the existing primary's id. Minting a fresh `EC-<uuid>` on every
        // save filled the SOS list with copies of the same person, each edit
        // adding one more.
        final existingPrimary = await emergency.explicitPrimaryContact();
        await emergency.saveContact(
          EmergencyContact(
            id: existingPrimary?.id ?? 'EC-${const Uuid().v4()}',
            name: contactName,
            phone: contactPhone,
            relation: existingPrimary?.relation.isNotEmpty ?? false
                ? existingPrimary!.relation
                : 'Emergency contact',
            isPrimary: true,
          ),
        );
      }
      // Blank fields leave the SOS list alone rather than deleting anyone.
      // Removing a contact is what the Emergency contacts screen is for, and
      // silently dropping the only person an SOS can reach because a text field
      // was cleared is not a trade worth making.

      return _repo.completeProfile(
        accountId: account.id,
        displayName: displayName,
        age: age,
        sex: sex,
        heightCm: heightCm,
        weightKg: weightKg,
        conditions: conditions,
        problems: problems,
        patientId: effectivePatientId,
      );
    });

    state = _stateFor(updated);
  }

  // ──────────────────────────── Demo / out ────────────────────────────

  /// The demo entry the app has always had, now expressed as a role: a
  /// clinician shell with no account. Nothing is persisted, so the next cold
  /// start asks again — a demo that silently persisted would let a borrowed
  /// phone keep staff access.
  void continueAsDemo() {
    _ref.read(settingsProvider.notifier).setDemoMode(true);
    final settings = _ref.read(settingsProvider.notifier);
    settings.setAudience(Audience.nurse);
    state = const AuthState(status: AuthStatus.demo);
  }

  Future<void> signOut() async {
    final account = state.account;
    if (account?.provider == AuthAccountProvider.google) {
      await _ref.read(googleAuthServiceProvider).signOut();
    }
    await _repo.endSession();
    state = const AuthState.signedOut();
  }
}

// ───────────────────────────── Providers ─────────────────────────────

/// The single source of truth for "who is using this phone and where they
/// belong". The router's redirect watches this; login, registration and both
/// homes read from it.
final authStateProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

/// The signed-in account, or null. Convenience selector for widgets that only
/// need identity and don't care about the session state machine.
final currentAccountProvider = Provider<UserAccount?>(
  (ref) => ref.watch(authStateProvider).account,
);

/// The audience the app is actually allowed to speak in.
///
/// Derived from the signed-in account, not read off settings. The two prompts
/// are not tone variants: the patient one deliberately drops the ban on naming
/// medicines and home remedies, so "which voice" is an access-control decision
/// and a tappable setting is the wrong place to keep it — anyone could open
/// Settings after signing in as a nurse and unlock the more permissive prompt.
///
/// Demo mode has no account, and there the stored setting is all there is —
/// which is correct, because a demo shell is nobody's clinical record.
final effectiveAudienceProvider = Provider<Audience>((ref) {
  final account = ref.watch(authStateProvider).account;
  if (account == null) return ref.watch(settingsProvider).audience;
  return account.role.isPatient ? Audience.patient : Audience.nurse;
});

/// Whether the mode selector should accept taps. False for every real account:
/// the role chosen at sign-up decides, and changing it means signing in as
/// someone else.
final canChooseAudienceProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).account == null,
);

/// The Patients row the signed-in patient screens themselves as.
/// Null for clinicians (they screen others) and for incomplete profiles.
final myPatientProvider = FutureProvider<Patient?>((ref) async {
  final account = ref.watch(authStateProvider).account;
  final patientId = account?.patientId;
  if (account == null || patientId == null) return null;
  return ref.watch(patientRepositoryProvider).getById(patientId);
});
