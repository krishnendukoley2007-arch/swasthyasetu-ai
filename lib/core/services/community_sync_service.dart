import 'package:flutter/foundation.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';

/// Privacy whitelist for the community early-warning sync payload.
///
/// Under the privacy mandate defined in NEXT_PHASE_GUIDELINES.md,
/// the payload that leaves the phone is strictly limited to these 5 keys.
/// No patient IDs, names, exact coordinates, raw vitals, or device IDs
/// may EVER leave the device.
abstract final class CommunitySyncWhitelist {
  static const Set<String> allowedKeys = {
    'riskBand',
    'category',
    'geohashTruncated',
    'timeBucket',
    'isDemo',
  };

  /// Returns true if and only if [payload] contains exclusively allowed keys.
  static bool isStrictlyWhitelisted(Map<String, dynamic> payload) {
    for (final key in payload.keys) {
      if (!allowedKeys.contains(key)) return false;
    }
    return true;
  }
}

/// Anonymized community aggregate early-warning document.
@immutable
class CommunityAggregateRecord {
  final String riskBand;
  final String category;
  final String geohashTruncated;
  final String timeBucket;
  final bool isDemo;

  const CommunityAggregateRecord({
    required this.riskBand,
    required this.category,
    required this.geohashTruncated,
    required this.timeBucket,
    required this.isDemo,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'riskBand': riskBand,
      'category': category,
      'geohashTruncated': geohashTruncated,
      'timeBucket': timeBucket,
      'isDemo': isDemo,
    };
    assert(
      CommunitySyncWhitelist.isStrictlyWhitelisted(map),
      'Privacy violation: non-whitelisted key in community aggregate record',
    );
    return map;
  }

  factory CommunityAggregateRecord.fromJson(Map<String, dynamic> json) {
    return CommunityAggregateRecord(
      riskBand: json['riskBand'] as String? ?? 'green',
      category: json['category'] as String? ?? 'general',
      geohashTruncated: json['geohashTruncated'] as String? ?? 'unknown',
      timeBucket: json['timeBucket'] as String? ?? '',
      isDemo: json['isDemo'] as bool? ?? false,
    );
  }
}

/// Pure Dart geohash encoder/decoder for regional bounding-box privacy (~5 km precision).
abstract final class GeohashHelper {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes latitude and longitude into a truncated geohash.
  /// Standard precision of 5 characters gives ~4.9 km x 4.9 km sensitivity.
  static String encode(double lat, double lon, {int precision = 5}) {
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    final buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLon + maxLon) / 2;
        if (lon > mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat > mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return buffer.toString();
  }

  /// Decodes a geohash into its center coordinates `(latitude, longitude)`.
  static (double lat, double lon)? decode(String geohash) {
    if (geohash.isEmpty || geohash == 'unknown') return null;
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    bool isEven = true;

    for (int i = 0; i < geohash.length; i++) {
      final c = geohash[i].toLowerCase();
      final cd = _base32.indexOf(c);
      if (cd == -1) return null;
      for (int j = 0; j < 5; j++) {
        final mask = 1 << (4 - j);
        if (isEven) {
          if ((cd & mask) != 0) {
            minLon = (minLon + maxLon) / 2;
          } else {
            maxLon = (minLon + maxLon) / 2;
          }
        } else {
          if ((cd & mask) != 0) {
            minLat = (minLat + maxLat) / 2;
          } else {
            maxLat = (minLat + maxLat) / 2;
          }
        }
        isEven = !isEven;
      }
    }
    return ((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }
}

/// Represents an aggregated regional cluster of community screening indicators.
@immutable
class CommunityHotspotCluster {
  final String geohash;
  final double latitude;
  final double longitude;
  final int redCount;
  final int orangeCount;
  final int yellowCount;
  final int greenCount;
  final Map<String, int> categoryCounts;
  final bool isDemo;
  final String locationLabel;

  const CommunityHotspotCluster({
    required this.geohash,
    required this.latitude,
    required this.longitude,
    required this.redCount,
    required this.orangeCount,
    required this.yellowCount,
    required this.greenCount,
    required this.categoryCounts,
    required this.isDemo,
    required this.locationLabel,
  });

  int get totalScreenings => redCount + orangeCount + yellowCount + greenCount;

  String get dominantCategory {
    if (categoryCounts.isEmpty) return 'general';
    var topCat = 'general';
    var maxVal = -1;
    categoryCounts.forEach((cat, count) {
      if (count > maxVal) {
        maxVal = count;
        topCat = cat;
      }
    });
    return topCat;
  }

  String get primaryRiskBand {
    if (redCount > 0) return 'RED';
    if (orangeCount > 0) return 'ORANGE';
    if (yellowCount > 0) return 'YELLOW';
    return 'GREEN';
  }
}

/// Service governing community early-warning sync and aggregate hotspot views.
class CommunitySyncService {
  final List<CommunityAggregateRecord> _localQueue = [];

  /// Derives the clinical presentation category without leaking private diagnosis.
  static String deriveCategory({
    required List<String> symptoms,
    double? heartRate,
    double? spo2,
    double? temperature,
  }) {
    final symLower = symptoms.map((s) => s.toLowerCase()).toSet();

    if (symLower.any(
          (s) =>
              s.contains('heat') ||
              s.contains('fever') ||
              s.contains('dehydration') ||
              s.contains('sun'),
        ) ||
        (temperature != null && temperature >= 38.3)) {
      return 'heat';
    }

    if (symLower.any(
          (s) =>
              s.contains('breath') ||
              s.contains('cough') ||
              s.contains('asthma') ||
              s.contains('smoke'),
        ) ||
        (spo2 != null && spo2 < 93.0)) {
      return 'respiratory';
    }

    if (symLower.any(
          (s) =>
              s.contains('chest') ||
              s.contains('palpitation') ||
              s.contains('dizziness'),
        ) ||
        (heartRate != null && (heartRate > 115 || heartRate < 50))) {
      return 'cardiac';
    }

    return 'general';
  }

  /// Derives hour-bucketed UTC ISO8601 timestamp string.
  static String deriveHourBucket(DateTime time) {
    final utc = time.toUtc();
    final hourBucket = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    return hourBucket.toIso8601String();
  }

  /// Builds a strictly anonymized aggregate payload from a screening.
  /// Returns null if the user has not opted into community sync consent.
  static CommunityAggregateRecord? buildAggregatePayload({
    required Screening screening,
    required bool consentOptIn,
  }) {
    if (!consentOptIn) return null;

    final geohash = (screening.latitude != null && screening.longitude != null)
        ? GeohashHelper.encode(screening.latitude!, screening.longitude!)
        : 'unknown';

    final category = deriveCategory(
      symptoms: screening.symptoms,
      heartRate: screening.heartRate.toDouble(),
      spo2: screening.spo2.toDouble(),
      temperature: screening.temperature,
    );

    return CommunityAggregateRecord(
      riskBand: screening.riskLevel.toLowerCase(),
      category: category,
      geohashTruncated: geohash,
      timeBucket: deriveHourBucket(screening.timestamp),
      isDemo: screening.isDemo,
    );
  }

  /// Contributes an anonymized screening record to the local aggregate pool.
  Future<bool> contributeScreening({
    required Screening screening,
    required bool consentOptIn,
  }) async {
    final payload = buildAggregatePayload(
      screening: screening,
      consentOptIn: consentOptIn,
    );
    if (payload == null) return false;
    _localQueue.add(payload);
    return true;
  }

  /// Seeded demo hotspot clusters (Mandate 2.1: strictly labeled isDemo: true).
  /// Positioned at realistic rural/semi-rural community blocks in Eastern India.
  static List<CommunityHotspotCluster> get seededDemoHotspots {
    return [
      const CommunityHotspotCluster(
        geohash: 'tu42q',
        latitude: 23.23,
        longitude: 87.07,
        redCount: 1,
        orangeCount: 6,
        yellowCount: 8,
        greenCount: 15,
        categoryCounts: {'heat': 12, 'general': 18},
        isDemo: true,
        locationLabel: 'Bankura Rural Block IV',
      ),
      const CommunityHotspotCluster(
        geohash: 'tu498',
        latitude: 23.62,
        longitude: 87.12,
        redCount: 4,
        orangeCount: 5,
        yellowCount: 6,
        greenCount: 9,
        categoryCounts: {'respiratory': 14, 'general': 10},
        isDemo: true,
        locationLabel: 'Raniganj Mining Sub-district',
      ),
      const CommunityHotspotCluster(
        geohash: 'tu4cb',
        latitude: 23.52,
        longitude: 87.31,
        redCount: 2,
        orangeCount: 4,
        yellowCount: 7,
        greenCount: 20,
        categoryCounts: {'cardiac': 8, 'heat': 3, 'general': 22},
        isDemo: true,
        locationLabel: 'Durgapur Periphery Block',
      ),
      const CommunityHotspotCluster(
        geohash: 'tu586',
        latitude: 23.24,
        longitude: 87.86,
        redCount: 0,
        orangeCount: 1,
        yellowCount: 5,
        greenCount: 28,
        categoryCounts: {'general': 30, 'respiratory': 4},
        isDemo: true,
        locationLabel: 'Burdwan East Primary Center',
      ),
    ];
  }

  /// Fetches recent aggregate clusters, optionally filtered by category.
  Future<List<CommunityHotspotCluster>> getRecentHotspots({
    bool includeDemo = true,
    String? categoryFilter,
  }) async {
    final clusters = <CommunityHotspotCluster>[];
    if (includeDemo) {
      clusters.addAll(seededDemoHotspots);
    }

    // Merge any locally queued records
    for (final rec in _localQueue) {
      final center = GeohashHelper.decode(rec.geohashTruncated);
      if (center != null) {
        final isRed = rec.riskBand == 'red';
        final isOrange = rec.riskBand == 'orange';
        final isYellow = rec.riskBand == 'yellow';
        final isGreen = rec.riskBand == 'green';

        clusters.add(
          CommunityHotspotCluster(
            geohash: rec.geohashTruncated,
            latitude: center.$1,
            longitude: center.$2,
            redCount: isRed ? 1 : 0,
            orangeCount: isOrange ? 1 : 0,
            yellowCount: isYellow ? 1 : 0,
            greenCount: isGreen ? 1 : 0,
            categoryCounts: {rec.category: 1},
            isDemo: rec.isDemo,
            locationLabel: 'Local Live Cluster (${rec.geohashTruncated})',
          ),
        );
      }
    }

    if (categoryFilter == null ||
        categoryFilter.toLowerCase() == 'all' ||
        categoryFilter.isEmpty) {
      return clusters;
    }

    final catLower = categoryFilter.toLowerCase();
    return clusters
        .where(
          (c) =>
              (c.categoryCounts[catLower] ?? 0) > 0 ||
              c.dominantCategory.toLowerCase() == catLower,
        )
        .toList();
  }
}
