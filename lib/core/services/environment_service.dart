import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';

/// Why a refresh came back with nothing.
///
/// Separate cases because each needs different words and a different button.
/// They used to be one silent null, so the card said "Needs a moment of
/// internet once" to a user whose internet was fine and whose GPS was off —
/// advice that could never work, with a Retry that could never succeed.
enum EnvFailure {
  /// The phone's location toggle is off. Nothing app-side can fix this.
  locationServicesOff,

  /// Android refused this app location access.
  permissionBlocked,

  /// Allowed and switched on, but no fix arrived in time — indoors, usually.
  noFix,

  /// Located fine; the weather service could not be reached or not understood.
  network;

  String get title => switch (this) {
        EnvFailure.locationServicesOff => 'Location is switched off',
        EnvFailure.permissionBlocked => 'Android blocked location access',
        EnvFailure.noFix => 'Could not find your location',
        EnvFailure.network => 'Could not reach the weather service',
      };

  String get detail => switch (this) {
        EnvFailure.locationServicesOff =>
          'Heat and air-quality alerts need your phone\'s location switched '
              'on. Turn it on once and this card fills in — your screenings '
              'are unaffected either way.',
        EnvFailure.permissionBlocked =>
          'Enable location for SwasthyaSetu in system settings to get heat '
              'and air-quality alerts for your area.',
        EnvFailure.noFix =>
          'Your phone could not get a location fix — this usually means being '
              'indoors. Near a window or outdoors it takes a few seconds.',
        EnvFailure.network =>
          'You appear to be online but the weather service did not answer. '
              'It is a free public service and is occasionally busy.',
      };
}

/// Local weather + air quality for the environment card and advisories.
///
/// Two deliberate choices:
///
/// 1. **Open-Meteo, unauthenticated.** No API key, no console project, no
///    quota dance — a user who just installed the APK gets working heat and
///    air alerts without reading a README. Endpoints return plain JSON.
///
/// 2. **Consent-gated, cached, never-blocking.** Location is only requested
///    when the user explicitly turns the feature on (same consent that gates
///    screening geotags). The last reading is written to the settings store
///    and served with its age when the network is absent — a heat warning
///    from this morning is still the right warning tonight. Any failure
///    anywhere degrades to null, never to an exception a screen must catch.
class EnvironmentService {
  EnvironmentService(this._db);

  final AppDatabase _db;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Why the last [refresh] produced no fresh reading. Null after a success, or
  /// before any attempt. Read by the card to choose its words.
  EnvFailure? lastFailure;

  // ──────────────────────────── Reads ────────────────────────────

  /// The cached reading, or null if one has never been fetched.
  Future<EnvironmentReading?> cached() async {
    final raw = await _db.getSetting(SettingKeys.envLastReading);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return EnvironmentReading.fromJson(decoded);
      }
    } on FormatException {
      // A corrupt blob is indistinguishable from "no data"; fall through.
    }
    return null;
  }

  /// Best-effort refresh. Returns the fresh reading on success, the cached
  /// one (marked stale by its own timestamp) when offline, null when there is
  /// nothing yet and the user has not granted location. Never throws.
  ///
  /// Sets [lastFailure] on every path that yields no fresh reading, so the card
  /// can name the actual obstacle instead of guessing at the network.
  Future<EnvironmentReading?> refresh() async {
    lastFailure = null;
    try {
      final position = await _position();
      if (position == null) return await cached();

      final reading = await _fetch(position.latitude, position.longitude);
      if (reading == null) {
        lastFailure = EnvFailure.network;
        return await cached();
      }

      await _db.setSetting(
          SettingKeys.envLastReading, jsonEncode(reading.toJson()));
      return reading;
    } catch (_) {
      lastFailure ??= EnvFailure.network;
      return cached();
    }
  }

  /// Whether the OS will let us locate at all, without asking again. The card
  /// uses this to decide between "Fetching" and "Turn on local weather".
  Future<bool> canLocate() async {
    final permission = await Geolocator.checkPermission();
    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => true,
      _ => false,
    };
  }

  /// Requests the OS permission. Called from the card's enable button — i.e.
  /// from user intent, never on startup.
  Future<bool> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ──────────────────────────── Internals ────────────────────────────

  Future<Position?> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      lastFailure = EnvFailure.locationServicesOff;
      return null;
    }
    if (!await canLocate()) {
      lastFailure = EnvFailure.permissionBlocked;
      return null;
    }
    // A last-known fix is plenty: heat advisories don't change across the
    // 800 m a cached GPS coordinate might be off by.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;
    try {
      // Only reached on a phone with no cached fix at all. `low` accuracy with
      // a 10-second limit routinely timed out indoors and the whole card fell
      // back to "needs internet"; `medium` will accept a network/cell fix,
      // which is ample for a weather grid square, and 25 seconds is long enough
      // to actually get one.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 25),
      );
    } catch (_) {
      lastFailure = EnvFailure.noFix;
      return null;
    }
  }

  String _describeWeatherCode(int code) {
    return switch (code) {
      0 => 'Clear Sky',
      1 => 'Mainly Clear',
      2 => 'Partly Cloudy',
      3 => 'Overcast',
      45 || 48 => 'Dense Fog',
      51 => 'Light Drizzle',
      53 => 'Moderate Drizzle',
      55 => 'Dense Drizzle',
      56 || 57 => 'Freezing Drizzle',
      61 => 'Light Rain',
      63 => 'Moderate Rain',
      65 => 'Heavy Rain',
      66 || 67 => 'Freezing Rain',
      71 => 'Slight Snowfall',
      73 => 'Moderate Snowfall',
      75 || 77 => 'Heavy Snowfall',
      80 => 'Slight Rain Showers',
      81 => 'Moderate Rain Showers',
      82 => 'Violent Rain Showers',
      85 || 86 => 'Snow Showers',
      95 => 'Thunderstorm',
      96 || 99 => 'Severe Thunderstorm & Hail',
      _ => 'Cloudy',
    };
  }

  Future<EnvironmentReading?> _fetch(double lat, double lng) async {
    final weather = await _dio.get<Map<String, dynamic>>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lng,
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,weather_code,wind_speed_10m',
        'timezone': 'auto',
      },
    );
    final current = weather.data?['current'];
    if (current is! Map<String, dynamic>) return null;
    final temp = (current['temperature_2m'] as num?)?.toDouble();
    final apparent = (current['apparent_temperature'] as num?)?.toDouble();
    final humidity = (current['relative_humidity_2m'] as num?)?.toDouble();
    if (temp == null || apparent == null || humidity == null) return null;

    final precipitation = (current['precipitation'] as num?)?.toDouble() ??
        (current['rain'] as num?)?.toDouble() ?? 0.0;
    final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
    final weatherDesc = _describeWeatherCode(weatherCode);
    final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;

    // Air quality is a separate API and a separate grid: a blank response
    // there must not sink a perfectly good weather reading.
    int? aqi;
    double? pm25;
    try {
      final air = await _dio.get<Map<String, dynamic>>(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current': 'pm2_5,us_aqi',
          'timezone': 'auto',
        },
      );
      final airCurrent = air.data?['current'];
      if (airCurrent is Map<String, dynamic>) {
        aqi = (airCurrent['us_aqi'] as num?)?.round();
        pm25 = (airCurrent['pm2_5'] as num?)?.toDouble();
      }
    } catch (_) {
      // Intentional: see comment above.
    }

    return EnvironmentReading(
      temperatureC: temp,
      apparentTemperatureC: apparent,
      humidityPercent: humidity,
      aqiUs: aqi,
      pm25: pm25,
      weatherCode: weatherCode,
      weatherDescription: weatherDesc,
      precipitationMm: precipitation,
      windSpeedKmh: windSpeed,
      fetchedAt: DateTime.now(),
      source: 'live',
    );
  }
}
