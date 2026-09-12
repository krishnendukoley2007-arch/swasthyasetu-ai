import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/features/screening/screens/air_pollution_guardian_screen.dart';
import '../../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AirPollutionGuardianScreen Widget Tests', () {
    testWidgets(
      'Renders NAQI header, telemetry grid, and pursed-lip breathing metronome',
      (tester) async {
        final harness = await TestHarness.create();

        await tester.pumpWidget(
          harness.wrap(const AirPollutionGuardianScreen(), textScale: 1.0),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Air Pollution & Respiratory Guardian'),
          findsOneWidget,
        );
        expect(find.text('Ambient Air Quality Index (NAQI)'), findsOneWidget);
        expect(find.text('Pursed-Lip Breathing Metronome'), findsOneWidget);
        expect(find.text('Start Guided Breathing'), findsOneWidget);
        expect(find.text('Pollution Defense Protocols'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Start Guided Breathing toggles metronome active state',
      (tester) async {
        final harness = await TestHarness.create();

        await tester.pumpWidget(
          harness.wrap(const AirPollutionGuardianScreen(), textScale: 1.0),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final startButton = find.text('Start Guided Breathing');
        expect(startButton, findsOneWidget);

        await tester.ensureVisible(startButton);
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(startButton);
        await tester.pump(const Duration(milliseconds: 100));

        // Breathing active state should show Pause button and phase guidance
        expect(find.text('Pause Breathing Metronome'), findsOneWidget);
        expect(find.textContaining('slowly through nose'), findsOneWidget);

        // Tap pause button
        final pauseButton = find.text('Pause Breathing Metronome');
        await tester.tap(pauseButton);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Start Guided Breathing'), findsOneWidget);
      },
    );

    testWidgets('High font scaling 2.0x renders without overflow', (
      tester,
    ) async {
      final harness = await TestHarness.create();

      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        harness.wrap(const AirPollutionGuardianScreen(), textScale: 2.0),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Air Pollution & Respiratory Guardian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
