import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

/// Environmental risk rules, separate from the screening engine on purpose:
/// a heat wave is a standing condition of the environment, not an event in
/// one reading, and it exists whether or not the user just screened.
///
/// Thresholds follow the public-health conventions the app can defend:
/// apparent (humidity-adjusted) temperature bands for heat stress, US AQI
/// bands for air. Vulnerability (elderly, chronic disease, pregnancy) shifts
/// every band one step earlier — the same API a heat-warning system applies
/// to its risk population.
class EnvironmentalRules {
  EnvironmentalRules._();

  /// Apparent temperature (°C) at which each band starts, standard population.
  static const double heatAdviceC = 32.0;
  static const double heatWarningC = 38.0;
  static const double heatDangerC = 43.0;

  /// Vulnerable users are warned ~4°C earlier; consistent with how heat
  /// action plans treat their risk population.
  static const double vulnerableShiftC = 4.0;

  static const List<AdvisoryLevel> _ordered = [
    AdvisoryLevel.danger,
    AdvisoryLevel.warning,
    AdvisoryLevel.advice,
    AdvisoryLevel.info,
  ];

  /// Advisories that apply right now, most serious first. Empty list means
  /// conditions are ordinary — the UI renders a calm "conditions fine" card,
  /// not an empty hole.
  static List<EnvironmentAdvisory> evaluate(
    EnvironmentReading reading, {
    Set<Vulnerability> vulnerability = const {},
  }) {
    final out = <EnvironmentAdvisory>[];
    final vulnerable = vulnerability.isNotEmpty;

    final heat = _heatLevel(reading.apparentTemperatureC, vulnerable);
    if (heat != null) out.add(_heatAdvisory(heat, reading, vulnerable));

    final aqi = reading.aqiUs;
    if (aqi != null) {
      final air = _airLevel(aqi, vulnerable);
      if (air != null) out.add(_airAdvisory(air, aqi, vulnerable));
    }

    // When heat AND air are both bad, one extra line on the combined risk is
    // worth more than a third card.
    if ((heat == AdvisoryLevel.danger || heat == AdvisoryLevel.warning) &&
        out.length > 1) {
      out.add(const EnvironmentAdvisory(
        level: AdvisoryLevel.warning,
        id: 'combined_heat_air',
        title: 'Heat and poor air together',
        body:
            'Hot, polluted air strains the heart and lungs at once. Stay '
            'indoors in the afternoon, drink water every hour, and keep '
            'windows closed if outdoor air is worse than indoor.',
      ));
    }

    out.sort((a, b) =>
        _ordered.indexOf(a.level).compareTo(_ordered.indexOf(b.level)));
    return out;
  }

  /// The single highest level in play, or null. The homes use this to decide
  /// whether the environment card shouts or whispers.
  static AdvisoryLevel? highestLevel(List<EnvironmentAdvisory> advisories) =>
      advisories.isEmpty ? null : advisories.first.level;

  // ─────────────────────── Environment × your body ───────────────────────

  /// The cross-domain insight: environment advisories say what the air and
  /// heat are doing; the user's own vital deviations say whether their body
  /// is responding. When both are present, one honest combined sentence beats
  /// two parallel warnings — "your pulse is above your usual AND it's 41°"
  /// is the early heat-strain picture, not a coincidence to scroll past.
  ///
  /// Only fires for the patient audience (clinician advisories are about the
  /// area, caller passes no notes for them anyway) and requires a significant
  /// trend note, so jitter cannot combine into a fake warning.
  static List<EnvironmentAdvisory> combineWithVitals(
    List<EnvironmentAdvisory> advisories,
    List<BaselineNote> notes,
  ) {
    final heatActive = advisories.any(
        (a) => a.id.startsWith('heat_') && a.level != AdvisoryLevel.info);
    final hrAbove = notes.any(
        (n) => n.metricId == 'hr' && n.significant && n.delta > 0);

    final airActive = advisories
        .any((a) => a.id.startsWith('air_') && a.level != AdvisoryLevel.info);
    final spo2Dropped = notes.any(
        (n) => n.metricId == 'spo2' && n.significant && n.delta < 0);

    if (!heatActive && !airActive) return advisories;

    final out = List<EnvironmentAdvisory>.of(advisories);
    if (heatActive && hrAbove) {
      final bpm = notes
          .firstWhere((n) => n.metricId == 'hr' && n.significant)
          .delta
          .abs()
          .round();
      out.insert(
        0,
        EnvironmentAdvisory(
          level: AdvisoryLevel.warning,
          id: 'combined_heat_vitals',
          title: 'Your body may be feeling this heat',
          body: 'Your pulse is about $bpm bpm above your usual and today is '
              'hot. That combination can be early heat strain: get to shade '
              'or indoors, sip water every few minutes, rest, and check '
              'yourself again in half an hour. If you get confused, faint, or '
              'stop sweating while hot, that is an emergency — call 108.',
        ),
      );
    }
    if (airActive && spo2Dropped) {
      out.insert(
        0,
        const EnvironmentAdvisory(
          level: AdvisoryLevel.warning,
          id: 'combined_air_vitals',
          title: 'Your breathing may be feeling this air',
          body: 'Your blood-oxygen is below your usual while the air quality '
              'is poor. Stay indoors, avoid exertion, and if breathing feels '
              'hard or your lips or fingertips darken, seek medical help '
              'immediately.',
        ),
      );
    }
    return out;
  }

  // ───────────────────────────── Heat ─────────────────────────────

  static AdvisoryLevel? _heatLevel(double apparentC, bool vulnerable) {
    final shift = vulnerable ? vulnerableShiftC : 0.0;
    if (apparentC >= heatDangerC - shift) return AdvisoryLevel.danger;
    if (apparentC >= heatWarningC - shift) return AdvisoryLevel.warning;
    if (apparentC >= heatAdviceC - shift) return AdvisoryLevel.advice;
    return null;
  }

  static EnvironmentAdvisory _heatAdvisory(
      AdvisoryLevel level, EnvironmentReading r, bool vulnerable) {
    final feels = r.apparentTemperatureC.round();
    final who = vulnerable
        ? ' You are in the group heat affects first — take this a step more '
            'seriously than others around you.'
        : '';
    return switch (level) {
      AdvisoryLevel.danger => EnvironmentAdvisory(
          level: level,
          id: 'heat_danger',
          title: 'Extreme heat danger (feels like $feels°C)',
          body: 'Stay indoors. Drink water every 15 minutes even if not '
              'thirsty. Cancel all outdoor activity. Cool yourself with wet '
              'cloths, fans, or cool showers. Check on elderly and children '
              'every 30 minutes. Confusion, fainting, or hot dry skin = '
              'call 108 immediately.$who',
        ),
      AdvisoryLevel.warning => EnvironmentAdvisory(
          level: level,
          id: 'heat_warning',
          title: 'Dangerous heat (feels like $feels°C)',
          body: 'Stay indoors as much as possible, drink water regularly even '
              'if not thirsty, avoid outdoor work in the afternoon, and check '
              'on elderly and children.$who',
        ),
      AdvisoryLevel.advice => EnvironmentAdvisory(
          level: level,
          id: 'heat_advice',
          title: 'Hot day (feels like $feels°C)',
          body: 'Drink a glass of water every hour, schedule hard outdoor work '
              'for morning or evening, and watch for headache or dizziness '
              '— early heat-stress signs.$who',
        ),
      AdvisoryLevel.info => const EnvironmentAdvisory(
          level: AdvisoryLevel.info,
          id: 'heat_info',
          title: 'Warm conditions',
          body: 'Ordinary warmth — keep normal hydration habits.',
        ),
    };
  }

  // ───────────────────────────── Air ─────────────────────────────

  static AdvisoryLevel? _airLevel(int aqi, bool vulnerable) {
    if (aqi <= 50) return null;
    if (vulnerable && aqi > 100) return AdvisoryLevel.warning;
    if (aqi > 150) return AdvisoryLevel.warning;
    if (aqi > 100) return AdvisoryLevel.advice;
    // 51–100: only the sensitive group hears about it.
    return vulnerable ? AdvisoryLevel.info : null;
  }

  static EnvironmentAdvisory _airAdvisory(
      AdvisoryLevel level, int aqi, bool vulnerable) {
    final who = vulnerable
        ? ' With your health history, this air level means extra care for you.'
        : '';
    return switch (level) {
      AdvisoryLevel.danger => EnvironmentAdvisory(
          level: AdvisoryLevel.warning,
          id: 'air_bad',
          title: 'Hazardous air (AQI $aqi)',
          body: 'Stay indoors, use air purifiers if available, avoid all '
              'outdoor activity, and use your reliever inhaler as prescribed '
              'if you have asthma. This level is rare and indicates a severe '
              'pollution event.$who',
        ),
      AdvisoryLevel.warning => EnvironmentAdvisory(
          level: level,
          id: 'air_bad',
          title: 'Unhealthy air (AQI $aqi)',
          body: 'Avoid outdoor exercise, keep windows closed, wear a '
              'well-fitting mask if you must go out, and use your reliever '
              'inhaler as prescribed if you have asthma.$who',
        ),
      AdvisoryLevel.advice => EnvironmentAdvisory(
          level: level,
          id: 'air_sensitive',
          title: 'Air may bother sensitive people (AQI $aqi)',
          body: 'People with asthma, heart conditions or breathing trouble '
              'should cut outdoor exertion today.$who',
        ),
      AdvisoryLevel.info => EnvironmentAdvisory(
          level: level,
          id: 'air_moderate',
          title: 'Moderate air (AQI $aqi)',
          body: 'Acceptable for most; if you are sensitive, notice any '
              'cough or breathing discomfort.$who',
        ),
    };
  }
}
