import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/fall_detection_service.dart';

/// Every case here drives the detector with an explicit clock rather than real
/// time, so the thresholds are actually being asserted instead of a race being
/// tolerated. The negative cases matter more than the positive one: a fall
/// detector that fires on ordinary handling gets switched off by the worker, and
/// then it is not protecting anyone.
void main() {
  final t0 = DateTime.utc(2026, 1, 1, 12);

  /// Feeds a run of identical samples at a fixed cadence, returning true if any
  /// of them triggered.
  bool feed(
    FallDetector d,
    double magnitude, {
    required DateTime from,
    required int count,
    Duration step = const Duration(milliseconds: 20),
  }) {
    var fired = false;
    for (var i = 0; i < count; i++) {
      if (d.addSample(magnitude, from.add(step * i))) fired = true;
    }
    return fired;
  }

  group('FallDetector — the two-part signature', () {
    test('fires on free fall followed by an impact', () {
      final d = FallDetector();

      // At rest.
      expect(d.addSample(9.8, t0), isFalse);
      expect(d.phase, FallPhase.idle);

      // 120 ms of near-zero g: unsupported.
      feed(d, 0.6, from: t0.add(const Duration(milliseconds: 20)), count: 6);
      expect(d.phase, FallPhase.freeFall);

      // Gravity returns — the fall has ended, now watching for the landing.
      expect(
        d.addSample(9.9, t0.add(const Duration(milliseconds: 140))),
        isFalse,
      );
      expect(d.phase, FallPhase.awaitingImpact);

      // The landing, 60 ms later.
      expect(
        d.addSample(31.0, t0.add(const Duration(milliseconds: 200))),
        isTrue,
      );
      // Detection resets the phase, so the tumble afterwards starts clean.
      expect(d.phase, FallPhase.idle);
    });

    test('does not fire on an impact with no free fall in front of it', () {
      final d = FallDetector();

      // Phone slapped down on a table: one big spike out of a resting state.
      feed(d, 9.8, from: t0, count: 5);
      final fired = d.addSample(
        40.0,
        t0.add(const Duration(milliseconds: 100)),
      );

      expect(fired, isFalse, reason: 'a bare spike is ordinary handling');
      expect(d.phase, FallPhase.idle);
    });

    test('does not fire on a free fall that never lands hard', () {
      final d = FallDetector();

      feed(d, 0.5, from: t0, count: 8);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 160)));
      expect(d.phase, FallPhase.awaitingImpact);

      // Dropped into a bag: a soft landing, well under the impact threshold,
      // for longer than the impact window allows.
      final fired = feed(
        d,
        12.0,
        from: t0.add(const Duration(milliseconds: 180)),
        count: 100,
      );

      expect(fired, isFalse);
      expect(d.phase, FallPhase.idle, reason: 'the window should have lapsed');
    });

    test('does not fire when the impact arrives after the window closes', () {
      final d = FallDetector(impactWindow: const Duration(milliseconds: 500));

      feed(d, 0.4, from: t0, count: 6);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 140)));
      expect(d.phase, FallPhase.awaitingImpact);

      // 900 ms after the fall ended: too late to be part of the same event.
      final fired = d.addSample(
        45.0,
        t0.add(const Duration(milliseconds: 1040)),
      );

      expect(fired, isFalse);
    });
  });

  group('FallDetector — free fall duration boundary', () {
    test('a collapse shorter than the minimum is discarded', () {
      final d = FallDetector(minFreeFallDuration: const Duration(milliseconds: 80));

      // 40 ms of low-g, then gravity back — a jolt, not a drop.
      d.addSample(1.0, t0);
      d.addSample(1.0, t0.add(const Duration(milliseconds: 20)));
      d.addSample(9.8, t0.add(const Duration(milliseconds: 40)));

      expect(
        d.phase,
        FallPhase.idle,
        reason: '40 ms is under the 80 ms floor, so it must not advance',
      );

      // Confirming it really was discarded: an impact now must not fire.
      expect(
        d.addSample(40.0, t0.add(const Duration(milliseconds: 60))),
        isFalse,
      );
    });

    test('a collapse exactly at the minimum is accepted', () {
      final d = FallDetector(minFreeFallDuration: const Duration(milliseconds: 80));

      d.addSample(1.0, t0);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 80)));

      expect(d.phase, FallPhase.awaitingImpact, reason: '>= is inclusive');
    });
  });

  group('FallDetector — threshold boundaries', () {
    test('magnitude exactly at the free-fall threshold is not a free fall', () {
      final d = FallDetector(freeFallThreshold: 4.0);
      d.addSample(4.0, t0);
      expect(d.phase, FallPhase.idle, reason: 'the check is strictly <');
    });

    test('magnitude just under the free-fall threshold is a free fall', () {
      final d = FallDetector(freeFallThreshold: 4.0);
      d.addSample(3.99, t0);
      expect(d.phase, FallPhase.freeFall);
    });

    test('impact exactly at the threshold fires', () {
      final d = FallDetector(impactThreshold: 26.0);
      feed(d, 1.0, from: t0, count: 6);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 140)));

      expect(
        d.addSample(26.0, t0.add(const Duration(milliseconds: 160))),
        isTrue,
        reason: 'the check is >=',
      );
    });

    test('impact just under the threshold does not fire', () {
      final d = FallDetector(impactThreshold: 26.0);
      feed(d, 1.0, from: t0, count: 6);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 140)));

      expect(
        d.addSample(25.99, t0.add(const Duration(milliseconds: 160))),
        isFalse,
      );
    });
  });

  group('FallDetector — refractory period', () {
    test('the tumble after a landing does not fire a second alert', () {
      final d = FallDetector(refractoryPeriod: const Duration(seconds: 20));

      // First fall.
      feed(d, 0.5, from: t0, count: 6);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 140)));
      expect(
        d.addSample(35.0, t0.add(const Duration(milliseconds: 160))),
        isTrue,
      );

      // A full second signature 2 s later — the body still settling.
      final second = t0.add(const Duration(seconds: 2));
      feed(d, 0.5, from: second, count: 6);
      d.addSample(9.8, second.add(const Duration(milliseconds: 140)));
      final fired = d.addSample(
        40.0,
        second.add(const Duration(milliseconds: 160)),
      );

      expect(fired, isFalse, reason: 'inside the refractory window');
    });

    test('a genuine second fall after the window does fire', () {
      final d = FallDetector(refractoryPeriod: const Duration(seconds: 20));

      feed(d, 0.5, from: t0, count: 6);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 140)));
      expect(
        d.addSample(35.0, t0.add(const Duration(milliseconds: 160))),
        isTrue,
      );

      final later = t0.add(const Duration(seconds: 25));
      feed(d, 0.5, from: later, count: 6);
      d.addSample(9.8, later.add(const Duration(milliseconds: 140)));

      expect(
        d.addSample(35.0, later.add(const Duration(milliseconds: 160))),
        isTrue,
      );
    });

    test('reset() clears the refractory window', () {
      final d = FallDetector();

      feed(d, 0.5, from: t0, count: 6);
      d.addSample(9.8, t0.add(const Duration(milliseconds: 140)));
      expect(
        d.addSample(35.0, t0.add(const Duration(milliseconds: 160))),
        isTrue,
      );

      d.reset();

      // 1 s later — normally suppressed, but re-arming must clear the block.
      final again = t0.add(const Duration(seconds: 1));
      feed(d, 0.5, from: again, count: 6);
      d.addSample(9.8, again.add(const Duration(milliseconds: 140)));

      expect(
        d.addSample(35.0, again.add(const Duration(milliseconds: 160))),
        isTrue,
      );
    });
  });

  group('FallDetector — realistic negative sequences', () {
    test('brisk walking never fires', () {
      final d = FallDetector();
      var fired = false;
      // 30 s of gait: 0.7 g–1.9 g oscillation at 20 ms, which is what a phone
      // in a hip pocket reads while walking.
      for (var i = 0; i < 1500; i++) {
        final phase = i % 25;
        final magnitude = phase < 12 ? 7.0 : 18.5;
        if (d.addSample(magnitude, t0.add(Duration(milliseconds: i * 20)))) {
          fired = true;
        }
      }
      expect(fired, isFalse);
    });

    test('taking the phone out of a pocket never fires', () {
      final d = FallDetector();
      var fired = false;
      // A brief low-g as the phone is lifted clear, then a firm regrip — the
      // classic false positive for single-threshold detectors.
      for (var i = 0; i < 3; i++) {
        if (d.addSample(2.5, t0.add(Duration(milliseconds: i * 20)))) {
          fired = true;
        }
      }
      // Regrip is well under 2.6 g.
      for (var i = 3; i < 20; i++) {
        if (d.addSample(16.0, t0.add(Duration(milliseconds: i * 20)))) {
          fired = true;
        }
      }
      expect(fired, isFalse);
    });
  });

  group('magnitudeOf', () {
    test('reads ~1 g for a phone at rest on a table', () {
      expect(
        FallDetector.magnitudeOf(0, 0, 9.81),
        closeTo(9.81, 0.001),
      );
    });

    test('combines all three axes', () {
      expect(FallDetector.magnitudeOf(3, 4, 0), closeTo(5.0, 0.001));
    });

    test('is zero in true free fall', () {
      expect(FallDetector.magnitudeOf(0, 0, 0), 0);
    });
  });

  group('FallEvent', () {
    test('reports peak in g as well as m/s²', () {
      final event = FallEvent(at: t0, peakMagnitude: 29.4);
      expect(event.peakG, closeTo(3.0, 0.01));
    });
  });
}
