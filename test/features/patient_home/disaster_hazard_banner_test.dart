import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_hazard.dart';
import 'package:swasthyasetu_ai/features/environment/state/environment_providers.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/disaster_hazard_banner.dart';
import 'package:swasthyasetu_ai/features/patient_home/widgets/disaster_syndromic_sheet.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('DisasterHazardBanner renders calm sentinel by default', (
    tester,
  ) async {
    final harness = await TestHarness.create();
    await tester.useSmallPhone();

    await tester.pumpWidget(
      harness.wrap(
        const Scaffold(
          body: SingleChildScrollView(child: DisasterHazardBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Disaster Physiological Shield Active'), findsOneWidget);
    expect(find.text('Relief Mode'), findsOneWidget);
  });

  testWidgets(
    'DisasterHazardBanner renders active flood banner when override is active',
    (tester) async {
      final harness = await TestHarness.create(
        overrides: [
          disasterHazardOverrideProvider.overrideWith(
            (ref) => DisasterHazardOverride.floodReliefZone,
          ),
        ],
      );
      await tester.useSmallPhone();

      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: DisasterHazardBanner(
                heartRateBpm: 108,
                temperatureC: 38.5,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE FLOOD HAZARD'), findsOneWidget);
      expect(find.text('IMD RED ALERT'), findsOneWidget);
      expect(find.text('60s Syndromic Check'), findsOneWidget);
      expect(find.text('Safe Water & First Aid'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping 60s Syndromic Check opens bottom sheet with interactive questions',
    (tester) async {
      final harness = await TestHarness.create(
        overrides: [
          disasterHazardOverrideProvider.overrideWith(
            (ref) => DisasterHazardOverride.floodReliefZone,
          ),
        ],
      );
      await tester.useSmallPhone();

      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: DisasterHazardBanner(
                heartRateBpm: 110,
                temperatureC: 38.4,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 60s Syndromic Check
      await tester.tap(find.text('60s Syndromic Check'));
      await tester.pumpAndSettle();

      expect(find.byType(DisasterSyndromicSheet), findsOneWidget);
      expect(find.text('Post-Flood Syndromic Check'), findsOneWidget);

      final item2 = find.text('2. Sudden Watery Diarrhea or Vomiting');
      await tester.scrollUntilVisible(
        item2,
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      expect(item2, findsOneWidget);

      // Tap the watery diarrhea checkbox
      await tester.tap(item2);
      await tester.pumpAndSettle();

      // Scroll back up to verify updated triage card
      await tester.scrollUntilVisible(
        find.text('CRITICAL SYNDROMIC RISK'),
        -150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      // With diarrhea + tachycardia (HR 110), triage verdict updates to CRITICAL
      expect(find.text('CRITICAL SYNDROMIC RISK'), findsOneWidget);
      expect(find.textContaining('Cholera'), findsOneWidget);
    },
  );

  testWidgets(
    'DisasterHazardBanner renders at textScaleFactor 2.0 without pixel overflow',
    (tester) async {
      final harness = await TestHarness.create(
        overrides: [
          disasterHazardOverrideProvider.overrideWith(
            (ref) => DisasterHazardOverride.floodReliefZone,
          ),
        ],
      );
      await tester.useSmallPhone();

      // High accessibility scale 2.0
      await tester.pumpWidget(
        harness.wrap(
          const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: DisasterHazardBanner(
                  heartRateBpm: 92,
                  temperatureC: 37.1,
                ),
              ),
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DisasterHazardBanner), findsOneWidget);
      expect(find.text('ACTIVE FLOOD HAZARD'), findsOneWidget);
    },
  );
}
