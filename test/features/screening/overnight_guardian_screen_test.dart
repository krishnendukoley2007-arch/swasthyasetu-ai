import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/features/screening/screens/overnight_guardian_screen.dart';
import '../../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OvernightGuardianScreen Widget Tests', () {
    testWidgets(
      'Renders standby state, contact indicators, and start screening button',
      (tester) async {
        final harness = await TestHarness.create();

        await tester.pumpWidget(
          harness.wrap(const OvernightGuardianScreen(), textScale: 1.0),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Overnight Guardian'), findsOneWidget);
        expect(find.text('STANDBY'), findsOneWidget);
        expect(find.text('Sensor Skin Contact Gating'), findsOneWidget);
        expect(find.text('Start Overnight Screening'), findsOneWidget);
        expect(
          find.text('No Overnight Recording Captured Yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Tapping Start Overnight Screening toggles active state', (
      tester,
    ) async {
      final harness = await TestHarness.create();

      await tester.pumpWidget(
        harness.wrap(const OvernightGuardianScreen(), textScale: 1.0),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final startButton = find.text('Start Overnight Screening');
      expect(startButton, findsOneWidget);

      await tester.ensureVisible(startButton);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(startButton);
      await tester.pump(const Duration(milliseconds: 100));

      // Now should show active monitoring state
      expect(find.text('SCREENING ACTIVE'), findsOneWidget);
      expect(find.text('Stop & Run Clinical Analysis'), findsOneWidget);

      // Tap stop to run analysis
      final stopButton = find.text('Stop & Run Clinical Analysis');
      await tester.ensureVisible(stopButton);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(stopButton);
      await tester.pump(const Duration(milliseconds: 100));

      // Analysis should complete
      expect(find.text('Start Overnight Screening'), findsOneWidget);
    });

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
        harness.wrap(const OvernightGuardianScreen(), textScale: 2.0),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Overnight Guardian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
