import 'dart:math';

/// RR-interval (beat-to-beat) extraction from a captured ECG strip.
///
/// Same philosophy as the live screen's detector: threshold scan with a
/// refractory window, and a scale-free flat-line guard so pure noise or a
/// disconnected lead yields no intervals at all rather than a plausible
/// tachogram. Returns intervals in milliseconds, oldest beat first. Empty
/// when the strip cannot support even one full interval — callers must treat
/// "fewer than 3 intervals" as "cannot draw a Poincaré plot".
List<int> rrIntervalsFromEcg(List<int> samples, int sampleRate) {
  if (samples.length < sampleRate * 2) return const [];

  var lo = samples.first, hi = samples.first;
  for (final v in samples) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  final p2p = hi - lo;
  if (p2p == 0) return const [];

  // Flat-line guard, scale-free: noise alone has a peak-to-peak/MAD ratio of
  // about 9.6; a real QRS stands well above that.
  final mad = _mad(samples);
  if (p2p < 12 * mad) return const [];

  final refractory = sampleRate ~/ 5; // 200 ms between R peaks
  final threshold = lo + (p2p * 0.6).round();

  final peaks = <int>[];
  var i = 0;
  while (i < samples.length) {
    if (samples[i] < threshold) {
      i++;
      continue;
    }
    var peak = i;
    while (i < samples.length && samples[i] >= threshold) {
      if (samples[i] > samples[peak]) peak = i;
      i++;
    }
    peaks.add(peak);
    i = peak + refractory;
  }

  if (peaks.length < 2) return const [];
  return [
    for (var k = 1; k < peaks.length; k++)
      ((peaks[k] - peaks[k - 1]) * 1000 / sampleRate).round(),
  ];
}

double _mad(List<int> samples) {
  final sorted = List<int>.of(samples)..sort();
  final centre = sorted[sorted.length ~/ 2];
  final deviations = samples.map((v) => (v - centre).abs()).toList()..sort();
  return max(1, deviations[deviations.length ~/ 2]).toDouble();
}
