import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';
import 'package:swasthyasetu_ai/features/debug/screens/edge_ai_benchmark_screen.dart';

void main() {
  group('EdgeAiBenchmarkScreen Widget & Accessibility Tests', () {
    Widget createWidgetUnderTest({double textScale = 1.0}) {
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 640),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const EdgeAiBenchmarkScreen(),
          ),
        ),
      );
    }

    testWidgets('renders benchmark screen with all cards, chips, and metrics', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify title & architecture banner
      expect(find.text('On-Device AI Benchmark'), findsOneWidget);
      expect(find.text('Qualcomm Snapdragon & NPU Pipeline'), findsOneWidget);

      // Verify profile selector chips
      expect(find.text('Sinus Baseline'), findsOneWidget);
      expect(find.text('PVC Ectopic'), findsOneWidget);
      expect(find.text('AFib Ripple'), findsOneWidget);
      expect(find.text('Live ESP32 Stream'), findsOneWidget);

      // Verify metrics
      expect(find.text('Inference Latency'), findsOneWidget);
      expect(find.text('Peak Throughput'), findsOneWidget);
      expect(find.text('Reconstruction MSE'), findsOneWidget);
      expect(find.text('Model Footprint'), findsOneWidget);

      // Verify Mandate 2.5 governance disclaimer
      expect(
        find.text('Mandate 2.5 — Advisory Edge AI Compliance'),
        findsOneWidget,
      );
    });

    testWidgets(
      'switching between synthetic benchmark profiles updates evaluation',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Initial state: Sinus Baseline (expected normal)
        expect(find.text('Normal Sinus Rhythm (NSR)'), findsOneWidget);
        expect(find.text('EXPECTED NORMAL'), findsOneWidget);

        // Tap on PVC Ectopic
        await tester.tap(find.text('PVC Ectopic'));
        await tester.pumpAndSettle();

        expect(
          find.text('Premature Ventricular Contraction (PVC)'),
          findsOneWidget,
        );
        expect(find.text('EXPECTED ANOMALY'), findsOneWidget);
        expect(find.text('ANOMALY FLAGGED'), findsOneWidget);

        // Tap on AFib Ripple
        await tester.tap(find.text('AFib Ripple'));
        await tester.pumpAndSettle();

        expect(find.text('Atrial Fibrillation (AFib)'), findsOneWidget);
      },
    );

    testWidgets(
      'accessibility scaling 2.0x renders without overflow (Mandate 3.1)',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest(textScale: 2.0));
        await tester.pumpAndSettle();

        // Must render cleanly with zero flutter overflow exceptions
        expect(tester.takeException(), isNull);
        expect(find.text('On-Device AI Benchmark'), findsOneWidget);
        expect(
          find.text('Mandate 2.5 — Advisory Edge AI Compliance'),
          findsOneWidget,
        );
      },
    );
  });
}
