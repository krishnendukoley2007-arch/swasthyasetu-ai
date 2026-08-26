/// Regression tests for the four defects found in the 2026-08-26 scan.
///
/// Every test here fails on the code as it was before that scan. They sit in one
/// file because they are one bug report, grouped by the symptom the user saw
/// rather than by the layer the fault lived in.
library;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/user_account.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

import 'support/harness.dart';

void main() {
  /// Lets AuthController's async `_restore` settle before a test acts on it.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  // ───────────────── 1. "I cannot save the emergency contact" ─────────────────

  group('emergency contacts', () {
    late AppDatabase db;
    late EmergencyRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = EmergencyRepository(db);
    });

    tearDown(() => db.close());

    test('a second primary contact saves without throwing', () async {
      // Registration writes the first one. This part always worked, which is
      // why the bug looked random: there was nobody to demote yet.
      await repo.saveContact(const EmergencyContact(
        id: 'EC-first',
        name: 'Soma',
        phone: '6290840738',
        isPrimary: true,
      ));

      // Editing the profile writes a second primary, and demoting the first
      // used to go through `insertOnConflictUpdate` with a companion carrying
      // only {id, isPrimary}. Drift validates that as an INSERT, found name and
      // phone missing, and threw InvalidDataException — which the screen caught
      // and showed as "Could not save the profile. Nothing was lost — try
      // again." Every save after the first failed.
      await repo.saveContact(const EmergencyContact(
        id: 'EC-second',
        name: 'Bikash',
        phone: '9876543210',
        isPrimary: true,
      ));

      final all = await repo.getContacts();
      expect(all.length, 2);
      expect(all.where((c) => c.isPrimary).map((c) => c.id), ['EC-second']);
    });

    test("demoting leaves the other contact's name and phone intact", () async {
      await repo.saveContact(const EmergencyContact(
        id: 'EC-first',
        name: 'Soma',
        phone: '6290840738',
        relation: 'Sister',
        isPrimary: true,
      ));
      await repo.saveContact(const EmergencyContact(
        id: 'EC-second',
        name: 'Bikash',
        phone: '9876543210',
        isPrimary: true,
      ));

      final demoted =
          (await repo.getContacts()).firstWhere((c) => c.id == 'EC-first');
      // An UPDATE touches one column. A partial upsert, had drift allowed one,
      // would have blanked the rest of the row — and SOS would dial nothing.
      expect(demoted.name, 'Soma');
      expect(demoted.phone, '6290840738');
      expect(demoted.relation, 'Sister');
      expect(demoted.isPrimary, isFalse);
    });

    test('re-saving the same contact stays one row', () async {
      await repo.saveContact(const EmergencyContact(
        id: 'EC-only',
        name: 'Soma',
        phone: '6290840738',
        isPrimary: true,
      ));
      await repo.saveContact(const EmergencyContact(
        id: 'EC-only',
        name: 'Soma Devi',
        phone: '6290840738',
        isPrimary: true,
      ));

      final all = await repo.getContacts();
      expect(all.length, 1);
      expect(all.single.name, 'Soma Devi');
      expect(all.single.isPrimary, isTrue);
    });

    test('explicitPrimaryContact does not invent a primary', () async {
      await repo.saveContact(const EmergencyContact(
        id: 'EC-plain',
        name: 'Neighbour',
        phone: '9000000000',
      ));

      // primaryContact() falls back to the first row so SOS always has someone.
      expect((await repo.primaryContact())?.id, 'EC-plain');
      // A caller about to *write* needs the truth, or the profile editor adopts
      // an unrelated contact as "the" emergency contact and overwrites them.
      expect(await repo.explicitPrimaryContact(), isNull);
    });
  });

  // ───────────────── 2. Nurse/patient mode could be switched ─────────────────

  group('audience follows the account, not the setting', () {
    /// A harness whose auth *and* settings controllers have finished their
    /// initial reads.
    ///
    /// Both load asynchronously from SQLite, and `SettingsController._load`
    /// assigns state unconditionally when it lands — so a write issued while
    /// that read is still in flight gets clobbered. On a phone the load happens
    /// behind the splash screen, long before anything can be tapped; in a test
    /// the two are microseconds apart.
    Future<TestHarness> readyHarness() async {
      final harness = await TestHarness.create();
      harness.container.read(authStateProvider);
      harness.container.read(settingsProvider);
      await settle();
      return harness;
    }

    test('a clinician account cannot be given the patient prompt', () async {
      final harness = await readyHarness();
      final container = harness.container;

      await container.read(authStateProvider.notifier).registerWithEmail(
            email: 'nurse@example.com',
            password: 'safe-pass',
            displayName: 'Field Worker',
            role: UserRole.clinician,
          );

      // Writing the setting is exactly what the Settings tile used to do.
      await container.read(settingsProvider.notifier).setAudience(
            Audience.patient,
          );
      expect(container.read(settingsProvider).audience, Audience.patient);

      // The prompt actually used comes from the role. The patient prompt
      // deliberately drops the ban on naming medicines and home remedies, so
      // this is access control and not a wording preference.
      expect(container.read(effectiveAudienceProvider), Audience.nurse);
      expect(container.read(canChooseAudienceProvider), isFalse);
    });

    test('a patient account cannot be given the clinical prompt', () async {
      final harness = await readyHarness();
      final container = harness.container;

      await container.read(authStateProvider.notifier).registerWithEmail(
            email: 'mira@example.com',
            password: 'safe-pass',
            displayName: 'Mira Das',
            role: UserRole.patient,
          );

      await container.read(settingsProvider.notifier).setAudience(
            Audience.nurse,
          );

      // Still held on the registration screen at this point — the gate must
      // apply from the moment the account exists, not only once it is complete.
      expect(container.read(authStateProvider).status, AuthStatus.needsProfile);
      expect(container.read(effectiveAudienceProvider), Audience.patient);
      expect(container.read(canChooseAudienceProvider), isFalse);
    });

    test('demo mode has no account, so the choice belongs to the user',
        () async {
      final harness = await readyHarness();
      final container = harness.container;

      container.read(authStateProvider.notifier).continueAsDemo();
      expect(container.read(effectiveAudienceProvider), Audience.nurse);
      expect(container.read(canChooseAudienceProvider), isTrue);

      await container.read(settingsProvider.notifier).setAudience(
            Audience.patient,
          );
      expect(container.read(effectiveAudienceProvider), Audience.patient);
    });

    test('signing out hands the choice back', () async {
      final harness = await readyHarness();
      final container = harness.container;

      final auth = container.read(authStateProvider.notifier);
      await auth.registerWithEmail(
        email: 'worker@example.com',
        password: 'safe-pass',
        displayName: 'Worker',
        role: UserRole.clinician,
      );
      expect(container.read(canChooseAudienceProvider), isFalse);

      await auth.signOut();
      expect(container.read(canChooseAudienceProvider), isTrue);
    });
  });

  // ───────────────── 3. "Sometimes it answers, sometimes not" ─────────────────

  group('Gemini transient failures', () {
    /// Fails the first [failures] requests with [status], then succeeds.
    /// [attempts] counts every request that reached the adapter.
    Dio dioFailing({
      required int failures,
      int status = 503,
      List<int>? attempts,
    }) {
      final dio = Dio();
      var seen = 0;
      dio.httpClientAdapter = _StubAdapter((_) {
        seen++;
        attempts?.add(seen);
        if (seen <= failures) {
          return _json('{"error":"unavailable"}', status);
        }
        return _json(
          '{"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}',
          200,
        );
      });
      return dio;
    }

    test('a 503 is retried instead of becoming a permanent failure', () async {
      final service = GeminiService(dio: dioFailing(failures: 1))
        ..setApiKey('AQ.test-key-long-enough-to-pass');

      final answer = await service.answerQuestion(
        assessment: _assessment,
        question: 'Will I be all right?',
      );

      // Before the fix there was no second attempt at all: one transient 503
      // from Flash and that question was answered offline forever. That is the
      // "answers, then doesn't, then does" the user described.
      expect(answer, 'ok');
      expect(service.lastFailure, isNull);
    });

    test('retries are bounded, then the failure is reported honestly',
        () async {
      final attempts = <int>[];
      final service = GeminiService(
        dio: dioFailing(failures: 99, attempts: attempts),
      )..setApiKey('AQ.test-key-long-enough-to-pass');

      final answer = await service.answerQuestion(
        assessment: _assessment,
        question: 'Will I be all right?',
      );

      expect(answer, isNull);
      expect(attempts.length, GeminiService.maxRetries + 1);
      // Not `network`. The phone reached Google perfectly well; Google said no.
      // Reporting that as "No connection. The phone could not reach Google"
      // sent workers hunting for signal they already had.
      expect(service.lastFailure, GeminiFailure.serverBusy);
      expect(service.lastFailure!.isWorthRetrying, isTrue);
    });

    test('a rejected key is not retried', () async {
      final attempts = <int>[];
      final service = GeminiService(
        dio: dioFailing(failures: 99, status: 403, attempts: attempts),
      )..setApiKey('AQ.bad-key-long-enough-to-pass');

      await service.answerQuestion(
        assessment: _assessment,
        question: 'anything',
      );

      expect(attempts.length, 1, reason: 'a bad key fails the same every time');
      expect(service.lastFailure, GeminiFailure.rejectedKey);
    });

    test('classify separates Google being busy from having no signal', () {
      DioException withStatus(int code) => DioException(
            requestOptions: RequestOptions(path: '/'),
            response: Response(
              requestOptions: RequestOptions(path: '/'),
              statusCode: code,
            ),
          );

      expect(GeminiService.classify(withStatus(503)), GeminiFailure.serverBusy);
      expect(GeminiService.classify(withStatus(500)), GeminiFailure.serverBusy);
      expect(GeminiService.classify(withStatus(429)), GeminiFailure.quota);
      expect(GeminiService.classify(withStatus(403)), GeminiFailure.rejectedKey);
      expect(
        GeminiService.classify(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionError,
        )),
        GeminiFailure.network,
      );
    });

    test('a connect failure is not retried — there is no route to try', () {
      expect(
        GeminiService.isRetryable(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionTimeout,
        )),
        isFalse,
      );
      // A read timeout means the request landed and the model was just slow, so
      // asking again is reasonable.
      expect(
        GeminiService.isRetryable(DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.receiveTimeout,
        )),
        isTrue,
      );
    });

    test('backoff grows between attempts', () {
      // Hammering a busy model instantly is how a 503 becomes three 503s.
      expect(
        GeminiService.backoffFor(1),
        greaterThan(GeminiService.backoffFor(0)),
      );
    });

    test('the read timeout is longer than the connect timeout', () {
      // One 12-second budget covered both phases before, so a thinking model on
      // a village connection was hung up on mid-answer.
      expect(
        GeminiService.receiveTimeout,
        greaterThan(GeminiService.connectTimeout),
      );
    });
  });

  // ───────────────── 4. The key no longer has to be pasted ─────────────────

  group('API key resolution', () {
    test('a key entered in Settings wins over the built-in one', () {
      final service = GeminiService()..setApiKey('AQ.entered-by-hand');
      expect(service.apiKey, 'AQ.entered-by-hand');
      expect(service.isConfigured, isTrue);
    });

    test('a blank Settings key falls through to the build-time key', () {
      // buildTimeKey is empty unless the APK was built with
      // --dart-define=GEMINI_API_KEY=..., which is how the shipped build stops
      // asking users to paste anything. Asserting the fallback order rather
      // than a literal keeps this true for both builds — and no key is written
      // into the repository to assert against.
      final service = GeminiService()..setApiKey('   ');
      expect(service.apiKey, GeminiService.buildTimeKey);
    });

    test('no credential is committed to the repository', () {
      // The shipped build gets its key from --dart-define at build time. If this
      // ever fails, someone pasted a live key into source.
      expect(GeminiService.shippedKey, isEmpty);
    });

    test('the current AQ. format is accepted and AIza is flagged', () {
      final current = GeminiService()..setApiKey('AQ.${'a' * 40}');
      expect(current.keyLooksLikeApiKey, isTrue);
      expect(current.keyIsLegacyStandard, isFalse);

      final legacy = GeminiService()..setApiKey('AIza${'a' * 35}');
      expect(legacy.keyLooksLikeApiKey, isTrue);
      // Google stops accepting Standard keys for the Gemini API in Sept 2026,
      // so this is the prefix that deserves the warning banner.
      expect(legacy.keyIsLegacyStandard, isTrue);
    });
  });
}

// ───────────────────────────────── Fixtures ─────────────────────────────────

/// A real assessment from the real engine — the Gemini tests only need
/// something to build a prompt from, and a hand-made one could drift from the
/// shape the engine actually produces.
final TriageAssessment _assessment = RiskEngine.assess(
  sample: const HealthSample(
    timestamp: 0,
    heartRateBpm: 112,
    spo2Percent: 91,
    temperatureC: 38.4,
    ecgSignalQuality: 0.9,
    rPeakDetected: true,
    rrIntervalMs: 536,
    batteryPercent: 80,
  ),
  symptoms: const ['Shortness of breath'],
);

/// Returns a canned [ResponseBody] per request, so retry behaviour can be
/// observed without a network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      respond(options);
}

/// A stubbed response that Dio will actually decode.
///
/// Without the content-type header Dio hands the body back as a raw String, the
/// `post<Map<String, dynamic>>` cast throws, and a perfectly good 200 looks like
/// a transport failure — which would make the retry tests pass for the wrong
/// reason.
ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
