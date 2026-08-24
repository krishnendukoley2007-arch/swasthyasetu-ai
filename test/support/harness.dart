import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/seed_service.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/mappers/row_mappers.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/l10n/generated/app_localizations.dart';

/// A real SQLite database in memory, wired into the provider graph.
///
/// Widget tests exercise the same repositories and streams the app uses — a
/// fake repository would let a layout pass in tests while the real query shape
/// breaks it on device.
class TestHarness {
  TestHarness._(this.db, this.container);

  final AppDatabase db;
  final ProviderContainer container;

  /// [seed] gets a ready database to insert fixtures into before the first pump.
  static Future<TestHarness> create({
    Future<void> Function(AppDatabase db)? seed,
    List<Override> overrides = const [],
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    if (seed != null) await seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Bootstrap does file IO through path_provider, which has no
        // implementation in a unit test. The fixtures above stand in for it.
        bootstrapProvider.overrideWith((ref) async => const SeedReport()),
        ...overrides,
      ],
    );

    addTearDown(() {
      container.dispose();
      db.close();
    });

    return TestHarness._(db, container);
  }

  /// Wraps [child] in the app's theme, localizations and provider scope at a
  /// given text scale, on a deliberately small screen.
  Widget wrap(Widget child, {double textScale = 1.0, ThemeData? theme}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    );
  }

  /// Same as [wrap], but behind a real router.
  ///
  /// Several screens read `GoRouterState.of(context).extra`, which throws
  /// without a router above them — those cannot be pumped as a bare `home:`.
  Widget wrapRouted(
    Widget Function() builder, {
    double textScale = 1.0,
    Object? extra,
    ThemeData? theme,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => builder()),
        // Anything the screen navigates to lands here rather than throwing.
        GoRoute(path: '/:rest(.*)', builder: (_, __) => const SizedBox.shrink()),
      ],
      initialExtra: extra,
    );
    addTearDown(router.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }
}

/// The narrowest screen the app is expected to support. Overflow shows up here
/// first, so every layout test runs at this size.
const Size kSmallPhone = Size(360, 640);

/// The outdoor-readability theme, as Settings applies it.
final ThemeData highContrastLight = AppTheme.highContrast(AppTheme.lightTheme);

extension TesterSizing on WidgetTester {
  Future<void> useSmallPhone() async {
    await binding.setSurfaceSize(kSmallPhone);
    view.physicalSize = kSmallPhone;
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
      binding.setSurfaceSize(null);
    });
  }
}

/// Pumps [build] and fails if Flutter reported a layout overflow.
///
/// Overflow is a `FlutterError`, not an exception the widget throws, so it has
/// to be captured off `FlutterError.onError` rather than `takeException`.
///
/// Frames advance in small steps rather than one long jump: several screens
/// animate their content in, and a row can fit at rest while overflowing
/// halfway through the transition.
Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget Function() build, {
  int frames = 10,
  Duration step = const Duration(milliseconds: 400),
}) async {
  final captured = <String>{};
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      captured.add('${text.split('\n').first.trim()}  ←  ${_creatorOf(details)}');
    } else {
      previous?.call(details);
    }
  };

  try {
    await tester.pumpWidget(build());
    for (var i = 0; i < frames; i++) {
      await tester.pump(step);
    }
  } finally {
    FlutterError.onError = previous;
  }

  expect(
    captured,
    isEmpty,
    reason: 'Layout overflowed:\n${captured.join('\n')}',
  );
}

/// `file.dart:line` of the widget that overflowed.
///
/// Without this the failure says only "overflowed by 40 pixels", which is true
/// and useless. The source location is carried by the `DebugCreator` the
/// rendering library attaches, but only becomes readable once the widgets
/// library's transform expands it — that transform is what puts "the relevant
/// error-causing widget was …" into the console dump.
String _creatorOf(FlutterErrorDetails details) {
  final raw = details.informationCollector?.call();
  if (raw == null) return 'unknown location';
  final info = debugTransformDebugCreator(raw)
      .map((node) => node.toStringDeep())
      .join(' ');
  final matches = RegExp(r'(?:packages|lib)/([\w/]+\.dart):(\d+):\d+')
      .allMatches(info)
      .map((m) => '${m.group(1)!.split('/').last}:${m.group(2)}')
      // Effect wrappers from the animation package sit between the screen and
      // the box that actually overflowed; they are never the fix site.
      .where((s) => !s.startsWith('slide_effect') &&
          !s.startsWith('fade_effect') &&
          !s.startsWith('builder.dart'))
      .toSet();
  return matches.isEmpty ? 'unknown location' : matches.take(3).join(' < ');
}

// ─────────────────────────────── Fixtures ───────────────────────────────

/// A patient plus [screeningCount] screenings scored by the real engine.
///
/// Deliberately verbose vitals and a long name: the point of these fixtures is
/// to be the worst realistic case for a layout, not the tidiest.
Future<void> seedPatientWithHistory(
  AppDatabase db, {
  required String id,
  String name = 'Rukhsana Bibi Chowdhury',
  int age = 71,
  List<String> flags = const ['elderly', 'chronic', 'pregnant'],
  int screeningCount = 4,
}) async {
  final patient = Patient(
    id: id,
    name: name,
    age: age,
    sex: 'F',
    location: 'Bishnupur ward 4, Sundarban block',
    createdAt: DateTime(2026, 1, 1),
    lastScreenedAt: DateTime(2026, 8, 20),
    vulnerabilityFlags: flags,
  );
  await db.upsertPatient(patient.toCompanion());

  for (var i = 0; i < screeningCount; i++) {
    final at = DateTime(2026, 8, 20).subtract(Duration(days: i * 3));
    final sample = HealthSample(
      timestamp: at.millisecondsSinceEpoch,
      heartRateBpm: 88 + i * 9,
      spo2Percent: 97 - i * 3,
      temperatureC: 36.8 + i * 0.5,
      ecgSignalQuality: 0.81,
      rPeakDetected: true,
      rrIntervalMs: 680,
      pttMs: 210,
      estimatedSystolic: 138 + i,
      estimatedDiastolic: 88 + i,
      bpConfidence: 'LOW',
      batteryPercent: 74,
    );
    final assessment = RiskEngine.assessForPatient(
      sample: sample,
      symptoms: i == 0
          ? const []
          : const ['Cough', 'Shortness of breath', 'Dizziness', 'Fatigue'],
      patient: patient,
    );

    await db.upsertScreening(
      Screening(
        id: '$id-s$i',
        patientId: id,
        deviceId: 'DEMO_DEVICE_001',
        timestamp: at,
        heartRate: sample.heartRateBpm,
        spo2: sample.spo2Percent,
        temperature: sample.temperatureC,
        ecgRhythm: i.isEven ? 'SINUS_RHYTHM' : 'IRREGULAR',
        ecgQualityScore: sample.ecgSignalQuality,
        rrIntervalMs: sample.rrIntervalMs,
        pttMs: sample.pttMs,
        estimatedSystolic: sample.estimatedSystolic,
        estimatedDiastolic: sample.estimatedDiastolic,
        bpConfidence: sample.bpConfidence,
        symptoms: assessment.symptoms,
        symptomDuration: '3 days',
        riskLevel: assessment.band.storageValue,
        riskScore: assessment.score,
        triggeredRules: assessment.firedRules.map((r) => r.display).toList(),
        recommendedAction: assessment.recommendedAction,
        escalationLevel: assessment.escalationLevel,
        syncStatus: i == 0 ? 'FAILED' : 'PENDING',
        retryCount: i,
      ).toCompanion(),
    );
  }
}
