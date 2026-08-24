/// Rhythm classification for a captured ECG strip.
///
/// Deliberately small and rule-based. It is *not* a diagnostic algorithm — it
/// summarises what the screening measured (rate, beat-to-beat regularity,
/// signal quality) into the five classes the `screenings` table stores, so the
/// record and the history view have something better than `UNKNOWN` in them.
///
/// Quality gates everything: a strip the electrode barely touched can produce a
/// confident-looking rate, and calling that "irregular" would be worse than
/// admitting the signal was unusable.
library;

class EcgClassifier {
  /// Below this the rhythm call is not trusted at all.
  static const double minUsableQuality = 0.5;

  static const int bradycardiaBelow = 50;
  static const int tachycardiaAbove = 100;

  /// Beat-to-beat variation, as a fraction of the mean interval, above which
  /// the rhythm is flagged irregular. 12% is deliberately generous: normal
  /// respiratory variation reaches ~10% in young adults.
  static const double irregularityThreshold = 0.12;

  /// Classifies from the aggregate numbers a screening already carries.
  ///
  /// [rrIntervalMs] is the most recent R-R interval; pass [rrIntervals] instead
  /// when the whole series is available, which is the only way to see
  /// irregularity.
  static String classify({
    required int heartRate,
    required double quality,
    int rrIntervalMs = 0,
    List<int> rrIntervals = const [],
  }) {
    if (quality < minUsableQuality) return 'NOISY';
    if (heartRate <= 0) return 'UNKNOWN';

    if (rrIntervals.length >= 4 && _isIrregular(rrIntervals)) {
      return 'IRREGULAR';
    }

    if (heartRate < bradycardiaBelow) return 'BRADYCARDIA';
    if (heartRate > tachycardiaAbove) return 'TACHYCARDIA';

    // A single R-R that disagrees badly with the reported rate means one of the
    // two is wrong; say so rather than certifying a regular rhythm.
    if (rrIntervalMs > 0) {
      final impliedRate = 60000 / rrIntervalMs;
      if ((impliedRate - heartRate).abs() / heartRate > 0.25) {
        return 'IRREGULAR';
      }
    }

    return 'SINUS_RHYTHM';
  }

  static bool _isIrregular(List<int> intervals) {
    final usable = intervals.where((ms) => ms > 200 && ms < 3000).toList();
    if (usable.length < 4) return false;

    final mean = usable.reduce((a, b) => a + b) / usable.length;
    if (mean <= 0) return false;

    // Mean absolute successive difference, the cheap cousin of RMSSD. Chosen
    // over standard deviation because a steady rate that drifts across the
    // capture is not an arrhythmia, whereas beat-to-beat jumps are.
    var total = 0.0;
    for (var i = 1; i < usable.length; i++) {
      total += (usable[i] - usable[i - 1]).abs();
    }
    final meanSuccessiveDiff = total / (usable.length - 1);

    return meanSuccessiveDiff / mean > irregularityThreshold;
  }
}
