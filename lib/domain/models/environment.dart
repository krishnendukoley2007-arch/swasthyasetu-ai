/// One environmental reading at the phone's location.
///
/// Source is explicit because the two paths have different trust profiles:
/// `live` came from the Open-Meteo API moments ago; `cached` may be hours old
/// and is shown with its age rather than pretending to be current. Null when
/// neither exists — the UI then shows the "turn on local weather" affordance
/// instead of fake numbers.
class EnvironmentReading {
  final double temperatureC;

  /// Temperature the body actually experiences (humidity-adjusted). This, not
  /// the air temperature, drives heat-stress advice: 35°C at 80% humidity is a
  /// different physiological event than 35°C dry.
  final double apparentTemperatureC;
  final double humidityPercent;

  /// US AQI for particulate pollution. Null when the air-quality station grid
  /// has no value at this coordinate.
  final int? aqiUs;
  final double? pm25;

  final DateTime fetchedAt;

  /// 'live' or 'cached' — never silent about which one this is.
  final String source;

  const EnvironmentReading({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.humidityPercent,
    this.aqiUs,
    this.pm25,
    required this.fetchedAt,
    required this.source,
  });

  bool get isLive => source == 'live';

  /// Local advisories go stale slower than a weather app cares about — a
  /// heat-wave warning from this morning is still the right warning tonight.
  static const Duration freshFor = Duration(hours: 6);

  bool get isStale => DateTime.now().difference(fetchedAt) > freshFor;

  Map<String, dynamic> toJson() => {
        'temperatureC': temperatureC,
        'apparentTemperatureC': apparentTemperatureC,
        'humidityPercent': humidityPercent,
        'aqiUs': aqiUs,
        'pm25': pm25,
        'fetchedAt': fetchedAt.toIso8601String(),
        'source': source,
      };

  factory EnvironmentReading.fromJson(Map<String, dynamic> json) =>
      EnvironmentReading(
        temperatureC: (json['temperatureC'] as num).toDouble(),
        apparentTemperatureC: (json['apparentTemperatureC'] as num).toDouble(),
        humidityPercent: (json['humidityPercent'] as num).toDouble(),
        aqiUs: (json['aqiUs'] as num?)?.round(),
        pm25: (json['pm25'] as num?)?.toDouble(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        source: json['source'] as String? ?? 'cached',
      );
}

/// How seriously an environmental advisory should press itself onto the home
/// screen. The order is the sort order when several apply.
enum AdvisoryLevel { info, advice, warning }

/// One environmental advisory, ready to render. The rule layer produces these;
/// screens never re-derive them.
class EnvironmentAdvisory {
  final AdvisoryLevel level;

  /// Stable machine id — the tests assert on these, and they never reach the
  /// UI as text.
  final String id;
  final String title;
  final String body;

  const EnvironmentAdvisory({
    required this.level,
    required this.id,
    required this.title,
    required this.body,
  });
}
