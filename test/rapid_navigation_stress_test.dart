import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/features/debug/screens/edge_ai_benchmark_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/ecg_live_screen.dart';
import 'package:swasthyasetu_ai/features/screening/screens/heat_guardian_screen.dart';

import 'support/harness.dart';

void main() {
  group('Rapid Navigation & Lifecycle Stress Test (Failure-Mode 3.5)', () {
    testWidgets(
      'rapid switching between ECG Live, AI Benchmark, and Heat Guardian does not throw',
      (tester) async {
        final harness = await TestHarness.create();

        // Repeatedly mount and unmount screens in rapid succession without waiting
        for (int cycle = 0; cycle < 5; cycle++) {
          // 1. Mount ECG Live Screen
          await tester.pumpWidget(harness.wrap(const EcgLiveScreen()));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);

          // 2. Rapidly unmount and mount AI Benchmark Screen
          await tester.pumpWidget(harness.wrap(const EdgeAiBenchmarkScreen()));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);

          // 3. Rapidly unmount and mount Heat Guardian Screen
          await tester.pumpWidget(harness.wrap(const HeatGuardianScreen()));
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
        }

        // Final settle to ensure clean disposal of all animations and streams
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
