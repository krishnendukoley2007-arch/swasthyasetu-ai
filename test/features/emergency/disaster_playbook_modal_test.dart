import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:swasthyasetu_ai/features/emergency/widgets/disaster_playbook_modal.dart';
import '../../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DisasterPlaybookModal Widget Tests', () {
    testWidgets(
      'Renders all-hazard playbook tabs and water purification by default',
      (tester) async {
        final harness = await TestHarness.create();

        await tester.pumpWidget(
          harness.wrap(
            const Scaffold(
              body: DisasterPlaybookModal(
                initialHazard: DisasterHazardType.flood,
              ),
            ),
            textScale: 1.0,
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('All-Hazard Offline Survival Playbook'),
          findsOneWidget,
        );
        expect(find.text('Drinking Water Decontamination'), findsOneWidget);
        expect(find.text('Rolling Boil Method'), findsOneWidget);
        expect(find.text('WHO Home ORS Preparation'), findsOneWidget);
        expect(find.text('Floods & Water'), findsOneWidget);
        expect(find.text('Heatwaves'), findsOneWidget);
      },
    );

    testWidgets('Switching tabs displays corresponding disaster protocol', (
      tester,
    ) async {
      final harness = await TestHarness.create();

      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: DisasterPlaybookModal(initialHazard: DisasterHazardType.none),
          ),
          textScale: 1.0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Heatwaves tab
      final heatChip = find.text('Heatwaves');
      expect(heatChip, findsOneWidget);
      await tester.tap(heatChip);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Heat Exhaustion vs Heatstroke'), findsOneWidget);
      expect(
        find.text('Work / Rest Ratios (Vidarbha / North India)'),
        findsOneWidget,
      );

      // Tap Toxic Smog tab
      final smogChip = find.text('Toxic Smog');
      expect(smogChip, findsOneWidget);
      await tester.tap(smogChip);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Respiratory Defense & Smog Enclosure'), findsOneWidget);
      expect(find.text('Certified Respirator Requirement'), findsOneWidget);

      // Tap Cyclones tab
      final cycloneChip = find.text('Cyclones');
      expect(cycloneChip, findsOneWidget);
      await tester.tap(cycloneChip);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Cyclone Shelter & Structural Protocols'),
        findsOneWidget,
      );
    });

    testWidgets('Auto-selects active hazard tab when initialHazard provided', (
      tester,
    ) async {
      final harness = await TestHarness.create();

      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: DisasterPlaybookModal(
              initialHazard: DisasterHazardType.severeAirPollution,
            ),
          ),
          textScale: 1.0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Respiratory Defense & Smog Enclosure'), findsOneWidget);
      expect(find.text('Certified Respirator Requirement'), findsOneWidget);
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
        harness.wrap(
          const Scaffold(
            body: DisasterPlaybookModal(
              initialHazard: DisasterHazardType.flood,
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('All-Hazard Offline Survival Playbook'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
