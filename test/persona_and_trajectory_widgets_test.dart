import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/early_warning_trajectory_card.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/persona_adaptive_hud.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/vulnerability_persona_selector.dart';

import 'support/harness.dart';

void main() {
  group('Vulnerability Persona & Trajectory Widgets', () {
    testWidgets('VulnerabilityPersonaSelector renders all four persona pills', (
      tester,
    ) async {
      final harness = await TestHarness.create();

      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: SingleChildScrollView(child: VulnerabilityPersonaSelector()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vulnerability Companion Mode'), findsOneWidget);
      expect(find.text('Outdoor Worker'), findsOneWidget);
      expect(find.text('Elderly'), findsOneWidget);
      expect(find.text('Chronic Care'), findsOneWidget);
      expect(find.text('General'), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping a persona pill switches active persona in settings', (
      tester,
    ) async {
      final harness = await TestHarness.create();

      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  VulnerabilityPersonaSelector(),
                  PersonaAdaptiveHud(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Outdoor Worker' pill
      await tester.tap(find.text('Outdoor Worker'));
      await tester.pumpAndSettle();

      // PersonaAdaptiveHud should now display the Field & Labor Heat Shield
      expect(find.text('Field & Labor Heat Shield'), findsOneWidget);
      expect(find.text('+250ml Water'), findsOneWidget);
      expect(find.text('Heat Guardian'), findsOneWidget);

      // Tap '+250ml Water' button
      await tester.tap(find.text('+250ml Water'));
      await tester.pumpAndSettle();

      // Tap 'Elderly' pill
      await tester.tap(find.text('Elderly'));
      await tester.pumpAndSettle();

      expect(find.text('Silent Risk & Fall Sentinel'), findsOneWidget);
      expect(find.text('Emergency Family Call'), findsOneWidget);

      // Tap 'Chronic Care' pill
      await tester.tap(find.text('Chronic Care'));
      await tester.pumpAndSettle();

      expect(find.text('Cardiorespiratory Reserve Sentinel'), findsOneWidget);
      expect(find.text('Start Guided Breathing (PEEP)'), findsOneWidget);
    });

    testWidgets(
      'EarlyWarningTrajectoryCard renders 7-day radar and telemetry rows',
      (tester) async {
        final harness = await TestHarness.create();

        await tester.pumpWidget(
          harness.wrap(
            const Scaffold(
              body: SingleChildScrollView(child: EarlyWarningTrajectoryCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('7-Day Early Warning Radar'), findsOneWidget);
        expect(find.text('Cumulative Multi-Day Trajectory'), findsOneWidget);
        expect(find.text('Cumulative Thermal Debt Index'), findsOneWidget);
        expect(find.text('Trailing Respiratory Curve'), findsOneWidget);
        expect(
          find.text('Post-Flood Incubation Watch (Days 1–14)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'High accessibility text scaling 2.0x renders all companion widgets without overflow',
      (tester) async {
        final harness = await TestHarness.create();

        tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          harness.wrap(
            const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    VulnerabilityPersonaSelector(),
                    SizedBox(height: 16),
                    PersonaAdaptiveHud(),
                    SizedBox(height: 16),
                    EarlyWarningTrajectoryCard(),
                  ],
                ),
              ),
            ),
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
