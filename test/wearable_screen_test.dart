import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/features/devices/screens/smartwatch_hub_screen.dart';
import 'package:swasthyasetu_ai/features/wearable/screens/wearable_screen.dart';

import 'support/harness.dart';

void main() {
  group('WearableScreen — Widget & Visual Presentation', () {
    testWidgets('renders circular smartwatch interface with SOS button', (
      tester,
    ) async {
      final harness = await TestHarness.create();
      await tester.useSmallPhone();

      await tester.pumpWidget(harness.wrap(const WearableScreen()));
      await tester.pump();

      // Top badge and metrics
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('SOS ALERT'), findsOneWidget);
      // Gaps rule: null vitals initially render as '—'
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('displays live vitals when wearable service is updated', (
      tester,
    ) async {
      final harness = await TestHarness.create();
      await tester.useSmallPhone();

      final wearable = harness.container.read(wearableServiceProvider);
      wearable.updateFromVitals(
        heartRate: 78,
        spo2: 99,
        temperature: 36.7,
        battery: 88,
        isDemo: true,
      );

      await tester.pumpWidget(harness.wrap(const WearableScreen()));
      await tester.pump();

      expect(find.text('78'), findsOneWidget);
      expect(find.text('99%'), findsOneWidget);
      expect(find.text('36.7°C'), findsOneWidget);
      expect(find.text('DEMO'), findsOneWidget);
    });

    testWidgets('shows critical alert overlay when emergency alert is active', (
      tester,
    ) async {
      final harness = await TestHarness.create();
      await tester.useSmallPhone();

      final wearable = harness.container.read(wearableServiceProvider);
      wearable.triggerWristAlert(
        'Critical arrhythmia detected',
        isEmergency: true,
      );

      await tester.pumpWidget(harness.wrap(const WearableScreen()));
      await tester.pump();

      expect(find.text('CRITICAL ALERT'), findsOneWidget);
      expect(find.text('Critical arrhythmia detected'), findsOneWidget);
      expect(find.text('MUTE'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);

      // Tapping mute dismisses the alert overlay
      await tester.tap(find.text('MUTE'));
      await tester.pump();

      expect(find.text('CRITICAL ALERT'), findsNothing);
    });

    testWidgets(
      'upholds Rule 3.1: renders cleanly under accessibility textScale: 2.0 without overflow',
      (tester) async {
        final harness = await TestHarness.create();
        await tester.useSmallPhone();

        await tester.pumpWidget(
          harness.wrap(const WearableScreen(), textScale: 2.0),
        );
        await tester.pump();

        expect(find.text('SOS ALERT'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SmartwatchHubScreen — Companion Hub & Simulator', () {
    testWidgets('renders smartwatch hub with interactive simulator', (
      tester,
    ) async {
      final harness = await TestHarness.create();
      await tester.useSmallPhone();

      await tester.pumpWidget(harness.wrap(const SmartwatchHubScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Smartwatch Companion Hub'), findsOneWidget);
      expect(find.text('LIVE SMARTWATCH DISPLAY'), findsOneWidget);
      expect(find.text('Background Watch Sensor Baseline'), findsOneWidget);
      expect(find.text('Wrist Haptic Alerts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'SmartwatchHubScreen renders without overflow at textScale: 2.0',
      (tester) async {
        final harness = await TestHarness.create();
        await tester.useSmallPhone();

        await tester.pumpWidget(
          harness.wrap(const SmartwatchHubScreen(), textScale: 2.0),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Smartwatch Companion Hub'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
