import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/storage_manager.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';
import 'package:swasthyasetu_ai/features/settings/screens/settings_screen.dart';

/// Settings is the screen most likely to overflow: it is nothing but rows of
/// label-plus-control, and the label is the part that grows when a worker turns
/// the system font up to read it in the sun.
///
/// The database-backed providers are overridden rather than stubbed at the DAO
/// level, so these tests never touch sqlite3 and run on the host.
class _FakeSettingsController extends StateNotifier<AppSettingsSnapshot>
    implements SettingsController {
  _FakeSettingsController(super.state);

  final calls = <String>[];

  @override
  Future<void> setEnvLocationConsent(bool granted) async {
    calls.add('setEnvLocationConsent:$granted');
    state = state.copyWith(envLocationConsent: granted);
  }

  @override
  Future<void> setLocale(Locale locale) async {
    calls.add('setLocale:${locale.languageCode}');
    state = state.copyWith(locale: locale);
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    calls.add('setThemeMode:${mode.name}');
    state = state.copyWith(themeMode: mode);
  }

  @override
  Future<void> setHighContrast(bool on) async {
    calls.add('setHighContrast:$on');
    state = state.copyWith(highContrast: on);
  }

  @override
  Future<void> setAudience(Audience audience) async {
    calls.add('setAudience:${audience.storageValue}');
    state = state.copyWith(audience: audience);
  }

  @override
  Future<void> setReducedMotion(bool on) async {
    calls.add('setReducedMotion:$on');
    state = state.copyWith(reducedMotion: on);
  }

  @override
  Future<void> setLocationConsent(bool granted) async {
    calls.add('setLocationConsent:$granted');
    state = state.copyWith(locationConsent: granted);
  }

  @override
  Future<void> setAiConsent(bool granted) async {
    calls.add('setAiConsent:$granted');
    state = state.copyWith(aiConsent: granted);
  }

  @override
  Future<void> setGeminiApiKey(String key) async {
    calls.add('setGeminiApiKey:${key.trim()}');
    state = state.copyWith(geminiApiKey: key.trim());
  }

  @override
  Future<void> setSyncConsent(bool granted) async {
    calls.add('setSyncConsent:$granted');
    state = state.copyWith(syncConsent: granted);
  }

  @override
  Future<void> setFallDetection(bool on) async {
    calls.add('setFallDetection:$on');
    state = state.copyWith(fallDetection: on);
  }

  @override
  Future<void> setAutoSuggestSos(bool on) async {
    calls.add('setAutoSuggestSos:$on');
    state = state.copyWith(autoSuggestSos: on);
  }

  @override
  Future<void> setSosCountdownSeconds(int seconds) async {
    calls.add('setSosCountdownSeconds:$seconds');
    state = state.copyWith(sosCountdownSeconds: seconds.clamp(5, 60));
  }

  @override
  Future<void> setDemoMode(bool on) async {
    calls.add('setDemoMode:$on');
    state = state.copyWith(demoMode: on);
  }

  @override
  Future<void> setLastDeviceId(String id) async {
    calls.add('setLastDeviceId:$id');
    state = state.copyWith(lastDeviceId: id);
  }

  @override
  Future<void> setWorkerProfile({
    String? name,
    String? id,
    String? facility,
  }) async {
    calls.add('setWorkerProfile:$name');
    state = state.copyWith(
      workerName: name ?? state.workerName,
      workerId: id ?? state.workerId,
      facility: facility ?? state.facility,
    );
  }

  @override
  Future<void> markSynced(DateTime at) async {
    calls.add('markSynced');
    state = state.copyWith(lastSyncAt: at);
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  late _FakeSettingsController controller;

  Widget harness({
    double textScale = 1.0,
    AppSettingsSnapshot? settings,
    List<EmergencyContact> contacts = const [],
    StorageUsage? usage,
    BpCalibration calibration = const BpCalibration(),
    List<Device> devices = const [],
    Audience? accountAudience,
  }) {
    controller = _FakeSettingsController(
      settings ?? const AppSettingsSnapshot(),
    );

    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => controller),
        // Signed in as [accountAudience], or nobody (the demo shell) when null.
        // The derivation from the account's role is covered in
        // scan_regressions_test; here the point is what the tile does with the
        // answer.
        if (accountAudience != null) ...[
          canChooseAudienceProvider.overrideWithValue(false),
          effectiveAudienceProvider.overrideWithValue(accountAudience),
        ],
        emergencyContactsProvider
            .overrideWith((ref) => Stream.value(contacts)),
        pairedDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        bpCalibrationProvider.overrideWith((ref) async => calibration),
        storageUsageProvider.overrideWith(
          (ref) async => usage ?? const StorageUsage.empty(),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 690),
          textScaler: TextScaler.linear(textScale),
        ),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
  }

  /// Brings [target] into view before interacting with it.
  ///
  /// The screen is a lazily-built `ListView`, so anything below the fold does
  /// not exist as a widget yet. Every test that touches a control past the first
  /// screenful has to scroll to it first — that is the app behaving correctly,
  /// not a test workaround.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('no overflow across the accessibility range', () {
    // 1.3–2.0 is the range §7 calls out; 1.0 is the baseline that must also hold.
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('renders at ${scale}x with nothing clipped', (tester) async {
        await tester.pumpWidget(harness(textScale: scale));
        await tester.pumpAndSettle();

        // Scroll the whole list: an overflow six sections down is still an
        // overflow, and only laid-out children throw.
        final list = find.byType(ListView);
        for (var i = 0; i < 12; i++) {
          await tester.drag(list, const Offset(0, -400));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'at ${scale}x');
        }
      });
    }

    testWidgets('the worker card holds a long facility name at 2.0x',
        (tester) async {
      await tester.pumpWidget(harness(
        textScale: 2.0,
        settings: const AppSettingsSnapshot(
          workerName: 'Sunita Kumari Das',
          workerId: 'ASHA-119284',
          facility: 'Bhangar-II Block Primary Health Centre, South 24 Parganas',
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('every control is bound to persisted state', () {
    testWidgets('the high-contrast switch writes through', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text('High contrast'));
      await tester.tap(find.text('High contrast'));
      await tester.pumpAndSettle();

      expect(controller.calls, contains('setHighContrast:true'));
      expect(controller.state.highContrast, isTrue);
    });

    testWidgets('demo mode writes through', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // Default is on, so a tap turns it off.
      await reveal(tester, find.text('Demo mode'));
      await tester.tap(find.text('Demo mode'));
      await tester.pumpAndSettle();

      expect(controller.calls, contains('setDemoMode:false'));
    });

    testWidgets('a consent switch reflects the snapshot, not a local default',
        (tester) async {
      await tester.pumpWidget(harness(
        settings: const AppSettingsSnapshot(locationConsent: true),
      ));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Tag screenings with location'));

      final tile = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('Tag screenings with location'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(tile.value, isTrue);
    });

    testWidgets('the language picker persists the chosen locale',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('App language'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('বাংলা'));
      await tester.pumpAndSettle();

      expect(controller.calls, contains('setLocale:bn'));
      expect(controller.state.locale.languageCode, 'bn');
    });

    testWidgets('the countdown picker persists the chosen seconds',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Cancel window'));
      await tester.tap(find.text('Cancel window'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 seconds').last);
      await tester.pumpAndSettle();

      expect(controller.calls, contains('setSosCountdownSeconds:30'));
    });
  });

  group('the nurse/patient mode is locked to the account', () {
    testWidgets('a signed-in account cannot tap its way to the other mode',
        (tester) async {
      await tester.pumpWidget(harness(
        accountAudience: Audience.nurse,
        // Deliberately mismatched: this is the state a nurse account reached by
        // switching the mode before the lock existed. The stored value must not
        // win over the account.
        settings: const AppSettingsSnapshot(audience: Audience.patient),
      ));
      await tester.pumpAndSettle();

      await reveal(tester, find.text(Audience.patient.label));
      await tester.tap(find.text(Audience.patient.label));
      await tester.pumpAndSettle();

      // The tap did nothing. The two prompts are not tone variants — the patient
      // one drops the ban on naming medicines and doses — so a nurse account
      // reaching it from Settings was a real escalation.
      expect(
        controller.calls.where((c) => c.startsWith('setAudience')),
        isEmpty,
      );
      // And the tile shows the account's mode, not the stale stored one.
      expect(find.text(Audience.nurse.label), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('the locked tile says why, and points at signing in again',
        (tester) async {
      await tester.pumpWidget(harness(accountAudience: Audience.patient));
      await tester.pumpAndSettle();

      await reveal(tester, find.text(Audience.patient.label));
      expect(
        find.textContaining('Sign in with a different account'),
        findsOneWidget,
      );
    });

    testWidgets('the demo shell keeps the choice', (tester) async {
      // No account, so nothing to enforce — the offline walkthrough still lets
      // a reviewer see both voices.
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text(Audience.patient.label));
      await tester.tap(find.text(Audience.patient.label));
      await tester.pumpAndSettle();

      expect(controller.calls, contains('setAudience:patient'));
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });
  });

  group('only the three shipped languages are offered', () {
    testWidgets('English, Hindi and Bengali — nothing unimplemented',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('App language'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsWidgets);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);

      // The old screen listed Marathi, Tamil and Telugu with no translations
      // behind them. Offering a language that does nothing is a lie.
      expect(find.text('Marathi'), findsNothing);
      expect(find.text('Tamil'), findsNothing);
      expect(find.text('Telugu'), findsNothing);
    });
  });

  group('state is reported honestly', () {
    testWidgets('warns when no contact can receive an SOS', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Emergency contacts'));

      expect(find.text('None yet — an SOS has nowhere to go'), findsOneWidget);
      expect(find.text('SOS not armed'), findsOneWidget);
    });

    testWidgets('drops the warning once a reachable contact exists',
        (tester) async {
      await tester.pumpWidget(harness(contacts: const [
        EmergencyContact(id: '1', name: 'Ward ANM', phone: '+919876543210'),
      ]));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Emergency contacts'));

      expect(find.text('1 contact saved'), findsOneWidget);
      expect(find.text('SOS not armed'), findsNothing);
    });

    testWidgets('an uncalibrated cuff says so rather than showing a blank date',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text('BP calibration'));

      expect(find.textContaining('Not calibrated'), findsOneWidget);
    });

    testWidgets('a fresh calibration shows its readings', (tester) async {
      await tester.pumpWidget(harness(
        calibration: BpCalibration(
          date: DateTime.now().subtract(const Duration(days: 1)),
          systolic: 118,
          diastolic: 76,
        ),
      ));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('BP calibration'));

      expect(find.textContaining('118/76'), findsOneWidget);
      expect(find.textContaining('yesterday'), findsOneWidget);
    });

    testWidgets('an empty device list does not claim a device is paired',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Paired devices'));

      expect(find.text('None paired yet'), findsOneWidget);
    });
  });

  group('nothing raw reaches the screen', () {
    testWidgets('no enum or storage token is rendered', (tester) async {
      await tester.pumpWidget(harness(
        settings: const AppSettingsSnapshot(themeMode: ThemeMode.dark),
      ));
      await tester.pumpAndSettle();

      // Sweep every Text on the screen for the shapes a raw value would take:
      // an ALL_CAPS storage token, or a Dart enum's `Enum.value` form. Repeated
      // down the list, because most of the screen starts off-stage.
      void sweep() {
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((s) => s.isNotEmpty);

        for (final s in texts) {
          expect(
            RegExp(r'^[A-Z][A-Z_]{3,}$').hasMatch(s),
            isFalse,
            reason: 'looks like a raw storage value: "$s"',
          );
          expect(
            s.contains('ThemeMode.') ||
                s.contains('CalibrationState.') ||
                s.contains('SosTrigger.') ||
                s.contains('Locale('),
            isFalse,
            reason: 'raw enum or object interpolated: "$s"',
          );
        }
      }

      sweep();
      for (var i = 0; i < 10; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pumpAndSettle();
        sweep();
      }
    });

    testWidgets('the threshold dialog humanises its map keys', (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Triage thresholds'));
      await tester.tap(find.text('Triage thresholds'));
      await tester.pumpAndSettle();

      // Scoped to the dialog: the screen behind it legitimately contains
      // "SwasthyaSetu" and "SpO2", which any naive camelCase check would flag.
      final inDialog = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();

      expect(inDialog, isNotEmpty);
      for (final s in inDialog) {
        expect(s, isNot(contains('_')), reason: 'unhumanised key: "$s"');
      }

      // And specifically: not one of the storage keys reaches the screen as-is.
      for (final key in AppConstants.riskThresholds.keys) {
        expect(
          inDialog,
          isNot(contains(key)),
          reason: 'raw threshold key "$key" rendered verbatim',
        );
      }
    });
  });
}
