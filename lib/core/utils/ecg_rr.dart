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

  // 1. Five-point derivative to eliminate baseline drift & emphasize QRS steep slope:
  //    d[i] = (2*x[i] + x[i-1] - x[i-3] - 2*x[i-4]) / 8
  final diff = List<double>.filled(samples.length, 0.0);
  for (var i = 4; i < samples.length; i++) {
    diff[i] =
        (2.0 * samples[i] +
            samples[i - 1] -
            samples[i - 3] -
            2.0 * samples[i - 4]) /
        8.0;
  }

  // 2. Square signal to eliminate negative components and accentuate peaks:
  final sq = List<double>.generate(samples.length, (i) => diff[i] * diff[i]);

  // 3. Moving-window integration (~120 ms window):
  final win = (sampleRate * 0.12).round().clamp(4, 50);
  final integrated = List<double>.filled(samples.length, 0.0);
  double sum = 0.0;
  for (var i = 0; i < samples.length; i++) {
    sum += sq[i];
    if (i >= win) sum -= sq[i - win];
    integrated[i] = sum / win;
  }

  // 4. Determine adaptive threshold from signal energy:
  var maxVal = 0.0;
  for (final v in integrated) {
    if (v > maxVal) maxVal = v;
  }
  if (maxVal <= 0.0001) return const [];

  final threshold = maxVal * 0.28; // 28% of peak integrated amplitude
  final refractory = (sampleRate * 0.32)
      .round(); // 320 ms refractory period (max 187 BPM)

  final peaks = <int>[];
  var i = win;
  while (i < samples.length - win) {
    if (integrated[i] > threshold) {
      // Find local peak within refractory window
      var peakIdx = i;
      var peakVal = integrated[i];
      final searchEnd = min(samples.length - win, i + refractory);
      for (var j = i + 1; j < searchEnd; j++) {
        if (integrated[j] > peakVal) {
          peakVal = integrated[j];
          peakIdx = j;
        }
      }
      peaks.add(peakIdx);
      i = peakIdx + refractory;
    } else {
      i++;
    }
  }

  if (peaks.length < 2) return const [];

  // 5. Enforce physiological bounds: 330 ms (181 BPM) to 1800 ms (33 BPM)
  final intervals = <int>[];
  for (var k = 1; k < peaks.length; k++) {
    final ms = ((peaks[k] - peaks[k - 1]) * 1000 / sampleRate).round();
    if (ms >= 330 && ms <= 1800) {
      intervals.add(ms);
    }
  }
  return intervals;
}
