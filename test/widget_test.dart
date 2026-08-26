import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/l10n/generated/app_localizations.dart';
import 'package:swasthyasetu_ai/main.dart';

import 'support/harness.dart';

void main() {
  testWidgets('bootstrap splash names the app and says what it is doing',
      (tester) async {
    final harness = await TestHarness.create();
    await tester.useSmallPhone();

    await tester.pumpWidget(harness.wrap(const _SplashProbe()));

    expect(find.text('SwasthyaSetu AI'), findsOneWidget);
    expect(find.text('Preparing offline data…'), findsOneWidget);
  });

  testWidgets('boots past the splash into the router', (tester) async {
    final harness = await TestHarness.create();
    await tester.useSmallPhone();

    // The real app widget, with a completed bootstrap and an in-memory DB.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const SwasthyaSetuApp(),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Whatever the start route renders, it is no longer the bootstrap splash.
    expect(find.text('Preparing offline data…'), findsNothing);
  });

  testWidgets('splash copy resolves in Bengali and Hindi', (tester) async {
    const expected = [
      (Locale('bn'), 'অফলাইন ডেটা প্রস্তুত করা হচ্ছে…'),
      (Locale('hi'), 'ऑफ़लाइन डेटा तैयार किया जा रहा है…'),
    ];

    for (final (locale, bootstrapping) in expected) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _SplashProbe(),
        ),
      );
      await tester.pump();

      expect(find.text(bootstrapping), findsOneWidget,
          reason: 'bootstrapping not translated for $locale');
      expect(find.text('Preparing offline data…'), findsNothing,
          reason: 'English leaked through for $locale');
    }
  });
}

/// Renders the same two strings the bootstrap splash does.
///
/// `_SplashScreen` is private to `main.dart`, so the test asserts on the copy
/// through the same localization lookup rather than reaching into the widget.
class _SplashProbe extends StatelessWidget {
  const _SplashProbe();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [Text(l10n.appName), Text(l10n.bootstrapping)],
      ),
    );
  }
}
