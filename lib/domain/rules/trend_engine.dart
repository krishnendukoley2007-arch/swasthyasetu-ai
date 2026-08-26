import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// One point on a vitals-trend chart, oldest first.
class TrendPoint {
  final DateTime at;
  final double value;

  const TrendPoint(this.at, this.value);
}

/// What the history says about one vital, honestly nullable: a mean over
/// zero readings is not a baseline, and the UI must not invent one.
class VitalTrend {
  final List<TrendPoint> points;
  final double average;
  final double? latest;

  /// latest − average. Null with no latest.
  final double? delta;

  const VitalTrend({
    required this.points,
    required this.average,
    this.latest,
    this.delta,
  });

  /// True when there are at least 3 PRIOR readings behind the latest — the
  /// minimum for "your usual" to mean anything at all.
  bool get hasBaseline => points.length >= 4;
}

/// The significance bands: a real deviation from one's own normal is worth
/// noting; day-to-day jitter is noise and must not be rendered as an alert.
class BaselineNote {
  /// 'hr' | 'spo2' | 'temp' — stable ids, never rendered raw.
  final String metricId;
  final double delta;

  /// True when the shift is worth a sentence on the dashboard.
  final bool significant;

  const BaselineNote(this.metricId, this.delta, {required this.significant});
}

/// Personal baseline arithmetic over stored screenings.
///
/// This is what "tracking changes in health patterns" means in code: not a
/// model, just careful, honest statistics — averages over the user's own
/// history, against significance bands big enough that ordinary jitter cannot
/// trip them. Anything ML-shaped here would need a corpus this dataset does
/// not have; the average is the defensible thing.
class TrendEngine {
  TrendEngine._();

  /// How far back "your usual" reaches. A month is long enough for a baseline
  /// to be stable and short enough to move when health genuinely changes.
  static const Duration window = Duration(days: 30);

  static VitalTrend heartRate(List<Screening> screenings) =>
      _extract(screenings, (s) => s.heartRate.toDouble(), minValue: 20);

  static VitalTrend spo2(List<Screening> screenings) =>
      _extract(screenings, (s) => s.spo2.toDouble(), minValue: 50);

  static VitalTrend temperature(List<Screening> screenings) =>
      _extract(screenings, (s) => s.temperature, minValue: 30);

  /// Deviations worth a sentence on the dashboard, in [significant] only.
  /// Thresholds are wide on purpose: ±10 bpm, −2 points of SpO₂, +0.7°C are
  /// physiological shifts, not measurement noise.
  static List<BaselineNote> notes(List<Screening> screenings) {
    final out = <BaselineNote>[];

    final hr = heartRate(screenings);
    final hrDelta = hr.delta;
    if (hr.hasBaseline && hrDelta != null && hrDelta.abs() >= 10) {
      out.add(BaselineNote('hr', hrDelta, significant: true));
    }

    final s = spo2(screenings);
    final sDelta = s.delta;
    if (s.hasBaseline && sDelta != null && sDelta <= -2) {
      out.add(BaselineNote('spo2', sDelta, significant: true));
    }

    final t = temperature(screenings);
    final tDelta = t.delta;
    if (t.hasBaseline && tDelta != null && tDelta >= 0.7) {
      out.add(BaselineNote('temp', tDelta, significant: true));
    }

    return out;
  }

  static VitalTrend _extract(
    List<Screening> screenings,
    double Function(Screening) pick, {
    required double minValue,
  }) {
    final cutoff = DateTime.now().subtract(window);
    // Zero is the not-measured sentinel on these columns — never plot it.
    final points = screenings
        .where((s) =>
            !s.timestamp.isBefore(cutoff) && pick(s) >= minValue && pick(s) > 0)
        .map((s) => TrendPoint(s.timestamp, pick(s)))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at)); // oldest first, for the chart

    if (points.isEmpty) {
      return const VitalTrend(points: [], average: 0);
    }
    // The baseline is the mean of the PRIOR readings only. Including the
    // newest reading would pull "usual" toward the very deviation we are
    // trying to notice — a sick week's reading must not redefine normal.
    final latest = points.last.value;
    final priors = points.length > 1
        ? points.sublist(0, points.length - 1).map((p) => p.value).toList()
        : const <double>[];
    final average = priors.isEmpty
        ? 0.0
        : priors.reduce((a, b) => a + b) / priors.length.toDouble();
    return VitalTrend(
      points: points,
      average: average,
      latest: latest,
      delta: priors.isEmpty ? null : latest - average,
    );
  }
}
