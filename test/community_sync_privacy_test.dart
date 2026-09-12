import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/community_sync_service.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/screening.dart';

void main() {
  group('Community Sync Privacy & Schema Invariants (Mandate 2.1 & Phase 5)', () {
    test('Consent toggle defaults to OFF (opt-in, not opt-out)', () {
      const snapshot = AppSettingsSnapshot();
      expect(
        snapshot.communitySyncConsent,
        isFalse,
        reason: 'Community sync consent must default to false for privacy',
      );

      final fromEmptyMap = AppSettingsSnapshot.fromMap(const {});
      expect(
        fromEmptyMap.communitySyncConsent,
        isFalse,
        reason: 'Empty storage must default communitySyncConsent to false',
      );
    });

    test('Payload builder returns null when consent is false', () {
      final screening = Screening(
        id: 'screen-123',
        patientId: 'pat-456',
        deviceId: 'SSAI-01',
        timestamp: DateTime.utc(2026, 9, 12, 14, 30),
        heartRate: 110,
        spo2: 91,
        temperature: 38.6,
        latitude: 23.235678,
        longitude: 87.078912,
        riskLevel: 'RED',
        riskScore: 7,
        isDemo: false,
      );

      final payload = CommunitySyncService.buildAggregatePayload(
        screening: screening,
        consentOptIn: false,
      );

      expect(
        payload,
        isNull,
        reason: 'Must not build payload when consent is false',
      );
    });

    test(
      'Payload builder returns strictly whitelisted schema when consent is true',
      () {
        final screening = Screening(
          id: 'screen-123',
          patientId: 'pat-456',
          deviceId: 'SSAI-01',
          timestamp: DateTime.utc(2026, 9, 12, 14, 30),
          heartRate: 110,
          spo2: 91,
          temperature: 38.6,
          latitude: 23.235678,
          longitude: 87.078912,
          riskLevel: 'RED',
          riskScore: 7,
          isDemo: false,
        );

        final payload = CommunitySyncService.buildAggregatePayload(
          screening: screening,
          consentOptIn: true,
        );

        expect(payload, isNotNull);
        final json = payload!.toJson();

        // Assert whitelist
        expect(
          CommunitySyncWhitelist.isStrictlyWhitelisted(json),
          isTrue,
          reason: 'Payload must strictly contain only whitelisted keys',
        );

        expect(json.keys.toSet(), equals(CommunitySyncWhitelist.allowedKeys));

        // Assert explicit absence of prohibited privacy-invasive keys
        final prohibitedKeys = [
          'patientId',
          'patient_id',
          'name',
          'patientName',
          'heartRate',
          'heart_rate',
          'spo2',
          'temperature',
          'temperatureC',
          'latitude',
          'lat',
          'longitude',
          'lon',
          'deviceId',
          'device_id',
          'ecgSamples',
          'symptoms',
          'notes',
        ];

        for (final key in prohibitedKeys) {
          expect(
            json.containsKey(key),
            isFalse,
            reason: 'Payload must never contain private key "$key"',
          );
        }
      },
    );

    test('Payload strictly rejects injected unauthorized fields', () {
      final badPayload = <String, dynamic>{
        'riskBand': 'red',
        'category': 'heat',
        'geohashTruncated': 'tu42q',
        'timeBucket': '2026-09-12T14:00:00.000Z',
        'isDemo': false,
        'patientId': 'leak_attempt_pat_999',
      };

      expect(
        CommunitySyncWhitelist.isStrictlyWhitelisted(badPayload),
        isFalse,
        reason:
            'Whitelist validator must reject any payload containing unauthorized keys',
      );
    });

    test('isDemo flag is strictly preserved (Mandate 2.1)', () {
      final liveScreening = Screening(
        id: 's1',
        patientId: 'p1',
        deviceId: 'SSAI-01',
        timestamp: DateTime.utc(2026, 9, 12, 10, 0),
        heartRate: 72,
        spo2: 98,
        temperature: 36.6,
        riskLevel: 'GREEN',
        riskScore: 0,
        isDemo: false,
      );

      final livePayload = CommunitySyncService.buildAggregatePayload(
        screening: liveScreening,
        consentOptIn: true,
      );
      expect(livePayload!.isDemo, isFalse);

      final demoScreening = Screening(
        id: 's2',
        patientId: 'p2',
        deviceId: 'SSAI-01',
        timestamp: DateTime.utc(2026, 9, 12, 10, 0),
        heartRate: 72,
        spo2: 98,
        temperature: 36.6,
        riskLevel: 'GREEN',
        riskScore: 0,
        isDemo: true,
      );

      final demoPayload = CommunitySyncService.buildAggregatePayload(
        screening: demoScreening,
        consentOptIn: true,
      );
      expect(demoPayload!.isDemo, isTrue);
    });

    test(
      'Geohash encoding yields 5-character truncated precision (~5km area)',
      () {
        final geohash = GeohashHelper.encode(
          23.235678,
          87.078912,
          precision: 5,
        );
        expect(geohash.length, equals(5));

        final center = GeohashHelper.decode(geohash);
        expect(center, isNotNull);
        // Center coordinates must be within ~0.05 degrees (~5km) of original point
        expect((center!.$1 - 23.235678).abs(), lessThan(0.06));
        expect((center.$2 - 87.078912).abs(), lessThan(0.06));
      },
    );

    test(
      'Category derivation correctly groups clinical presentation without leaking raw values',
      () {
        expect(
          CommunitySyncService.deriveCategory(
            symptoms: ['Fever', 'Heat stroke'],
            temperature: 38.8,
          ),
          equals('heat'),
        );

        expect(
          CommunitySyncService.deriveCategory(
            symptoms: ['Cough', 'Shortness of breath'],
            spo2: 91,
          ),
          equals('respiratory'),
        );

        expect(
          CommunitySyncService.deriveCategory(
            symptoms: ['Chest pain', 'Palpitations'],
            heartRate: 130,
          ),
          equals('cardiac'),
        );

        expect(
          CommunitySyncService.deriveCategory(
            symptoms: ['Mild headache'],
            heartRate: 72,
            spo2: 98,
            temperature: 36.6,
          ),
          equals('general'),
        );
      },
    );

    test('deriveHourBucket truncates minutes and seconds to UTC hour', () {
      final time = DateTime.utc(2026, 9, 12, 14, 47, 52, 123);
      final bucket = CommunitySyncService.deriveHourBucket(time);
      expect(bucket, equals('2026-09-12T14:00:00.000Z'));
    });
  });
}
