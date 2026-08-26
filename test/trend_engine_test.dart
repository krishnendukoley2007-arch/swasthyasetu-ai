import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';

Screening s(int daysAgo,
        {int hr = 72, int spo2 = 98, double temp = 36.6}) =>
    Screening(
      id: 's-$daysAgo',
      patientId: 'p1',
      deviceId: 'd1',
      timestamp: DateTime.now().subtract(Duration(days: daysAgo)),
      heartRate: hr,
      spo2: spo2,
      temperature: temp,
      riskLevel: 'GREEN',
      riskScore: 0,
    );

void main() {
  group('TrendEngine', () {
    test('empty history is empty, never a fake baseline', () {
      final trend = TrendEngine.heartRate(const []);
      expect(trend.points, isEmpty);
      expect(trend.hasBaseline, isFalse);
      expect(trend.latest, isNull);
      expect(TrendEngine.notes(const []), isEmpty);
    });

    test('one, two or three readings are not called a baseline', () {
      expect(TrendEngine.heartRate([s(0), s(2)]).hasBaseline, isFalse);
      expect(TrendEngine.heartRate([s(0), s(1), s(2)]).hasBaseline, isFalse);
    });

    test('average and delta come from prior readings, latest excluded', () {
      final list = [s(0, hr: 90), s(1, hr: 75), s(2, hr: 75), s(3, hr: 75)];
      final trend = TrendEngine.heartRate(list);
      // Baseline = mean of the three priors (75); latest is not folded into
      // its own comparison.
      expect(trend.average, closeTo(75.0, 0.01));
      expect(trend.latest, 90);
      expect(trend.delta, closeTo(15.0, 0.01));
      expect(trend.hasBaseline, isTrue);
    });

    test('a reading over 30 days old does not count as "usual" anymore', () {
      final list = [s(0, hr: 80), s(31, hr: 60), s(45, hr: 60)];
      final trend = TrendEngine.heartRate(list);
      expect(trend.points.length, 1);
    });

    test('zero is a not-measured sentinel, never plotted', () {
      final list = [s(0, hr: 0), s(1, hr: 74), s(2, hr: 76), s(3, hr: 75)];
      final trend = TrendEngine.heartRate(list);
      expect(trend.points.length, 3);
      // Oldest-first: 75 (3d), 76 (2d), 74 (latest) → baseline = (75+76)/2.
      expect(trend.average, closeTo(75.5, 0.01));
    });

    test('ordinary jitter does not raise a note', () {
      final list = [s(0, hr: 76), s(1, hr: 74), s(2, hr: 75), s(3, hr: 74)];
      expect(TrendEngine.notes(list), isEmpty);
    });

    test('latest 13 bpm above usual is a significant HR note', () {
      final list = [s(0, hr: 87), s(1, hr: 74), s(2, hr: 74), s(3, hr: 74)];
      final notes = TrendEngine.notes(list);
      expect(notes.single.metricId, 'hr');
      expect(notes.single.significant, isTrue);
    });

    test('one-point SpO₂ drift raises no note; a real drop does', () {
      final base = [s(1, spo2: 98), s(2, spo2: 98), s(3, spo2: 98)];
      expect(TrendEngine.notes([s(0, spo2: 97), ...base]), isEmpty);
      final notes = TrendEngine.notes([s(0, spo2: 95), ...base]);
      expect(notes.single.metricId, 'spo2');
    });

    test('points come out oldest first, so charts read left to right', () {
      final trend = TrendEngine.heartRate([s(0), s(3), s(1), s(2)]);
      for (var i = 1; i < trend.points.length; i++) {
        expect(trend.points[i].at.isAfter(trend.points[i - 1].at), isTrue);
      }
    });
  });
}
