import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/rules/environmental_rules.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';

EnvironmentReading reading({
  double apparent = 30,
  double temp = 30,
  double humidity = 50,
  int? aqi,
  DateTime? fetchedAt,
}) =>
    EnvironmentReading(
      temperatureC: temp,
      apparentTemperatureC: apparent,
      humidityPercent: humidity,
      aqiUs: aqi,
      pm25: null,
      fetchedAt: fetchedAt ?? DateTime.now(),
      source: 'live',
    );

void main() {
  group('EnvironmentalRules heat', () {
    test('ordinary conditions produce no advisory, not a fake one', () {
      expect(EnvironmentalRules.evaluate(reading()), isEmpty);
    });

    test('advice band starts at 32°C apparent for the general population',
        () {
      final adv = EnvironmentalRules.evaluate(reading(apparent: 33));
      expect(adv.single.id, 'heat_advice');
      expect(adv.single.level, AdvisoryLevel.advice);
    });

    test('a chronic patient is warned ~4°C earlier', () {
      final plain = EnvironmentalRules.evaluate(reading(apparent: 30));
      final vulnerable = EnvironmentalRules.evaluate(
        reading(apparent: 30),
        vulnerability: const {Vulnerability.chronic},
      );
      expect(plain, isEmpty);
      expect(vulnerable.single.level, AdvisoryLevel.advice);
      expect(vulnerable.single.title, contains('30'));
    });

    test('43°C apparent is a danger warning', () {
      final adv = EnvironmentalRules.evaluate(reading(apparent: 44));
      expect(adv.first.id, 'heat_danger');
      expect(adv.first.level, AdvisoryLevel.warning);
    });

    test('copy never invents a diagnosis: warnings are about conduct', () {
      final adv = EnvironmentalRules.evaluate(reading(apparent: 44));
      expect(adv.first.body, contains('drink water'));
      expect(adv.first.body, isNot(contains('you have')));
    });
  });

  group('EnvironmentalRules air', () {
    test('good air says nothing', () {
      expect(EnvironmentalRules.evaluate(reading(aqi: 40)), isEmpty);
    });

    test('moderate air only speaks to the vulnerable', () {
      // apparent 25 keeps heat silent so this test measures air alone.
      expect(EnvironmentalRules.evaluate(reading(apparent: 25, aqi: 80)),
          isEmpty);
      final adv = EnvironmentalRules.evaluate(
        reading(apparent: 25, aqi: 80),
        vulnerability: const {Vulnerability.chronic},
      );
      expect(adv.single.id, 'air_moderate');
      expect(adv.single.level, AdvisoryLevel.info);
    });

    test('AQI > 150 warns everyone', () {
      final adv = EnvironmentalRules.evaluate(reading(aqi: 170));
      expect(adv.single.id, 'air_bad');
      expect(adv.single.level, AdvisoryLevel.warning);
    });

    test('null AQI (off-grid location) is not a reading', () {
      expect(EnvironmentalRules.evaluate(reading()), isEmpty);
    });
  });

  group('combined', () {
    test('heat warning plus air advisory adds the combined note', () {
      final adv = EnvironmentalRules.evaluate(reading(apparent: 44, aqi: 170));
      expect(adv.map((a) => a.id),
          containsAll(['heat_danger', 'air_bad', 'combined_heat_air']));
      // Most serious first.
      expect(adv.first.level, AdvisoryLevel.warning);
    });

    test('worst-first ordering holds for mixed levels', () {
      final adv = EnvironmentalRules.evaluate(reading(apparent: 34, aqi: 170));
      expect(adv.map((a) => a.level).toList(),
          orderedEquals([AdvisoryLevel.warning, AdvisoryLevel.advice]));
    });
  });

  group('combine with vitals', () {
    final heat = EnvironmentalRules.evaluate(reading(apparent: 44));
    final air = EnvironmentalRules.evaluate(reading(apparent: 25, aqi: 170));
    const hrNote = BaselineNote('hr', 13, significant: true);
    const hrDown = BaselineNote('hr', -12, significant: true);
    const spo2Note = BaselineNote('spo2', -3, significant: true);

    test('heat plus rising pulse yields one combined warning, first', () {
      final combined = EnvironmentalRules.combineWithVitals(heat, [hrNote]);
      expect(combined.first.id, 'combined_heat_vitals');
      expect(combined.first.body, contains('13 bpm'));
    });

    test('no vitals deviation leaves the base advisories untouched', () {
      final identical = EnvironmentalRules.combineWithVitals(heat, const []);
      expect(identical, containsAll(heat));
      expect(identical.length, heat.length);
    });

    test('a pulse BELOW usual is not heat strain evidence', () {
      final same = EnvironmentalRules.combineWithVitals(heat, [hrDown]);
      expect(same.any((a) => a.id == 'combined_heat_vitals'), isFalse);
    });

    test('bad air plus SpO₂ drop yields the breathing warning', () {
      final combined = EnvironmentalRules.combineWithVitals(air, [spo2Note]);
      expect(combined.first.id, 'combined_air_vitals');
    });

    test('good environment cannot fabricate a combined warning', () {
      final calm = EnvironmentalRules.evaluate(reading(apparent: 25, aqi: 40));
      final combined =
          EnvironmentalRules.combineWithVitals(calm, [hrNote, spo2Note]);
      expect(combined, isEmpty);
    });
  });

  group('staleness', () {
    test('a cached reading older than 6h is honest about being stale', () {
      final stale = EnvironmentReading(
        temperatureC: 30,
        apparentTemperatureC: 30,
        humidityPercent: 50,
        fetchedAt: DateTime.now().subtract(const Duration(hours: 7)),
        source: 'cached',
      );
      expect(stale.isStale, isTrue);
      expect(stale.isLive, isFalse);
    });

    test('a fresh reading is neither stale nor mislabelled', () {
      expect(reading().isStale, isFalse);
      expect(reading().isLive, isTrue);
    });

    test('json round trip preserves every field', () {
      final original = reading(apparent: 36.5, humidity: 70, aqi: 88);
      final restored = EnvironmentReading.fromJson(original.toJson());
      expect(restored.apparentTemperatureC, 36.5);
      expect(restored.aqiUs, 88);
      expect(restored.source, 'live');
    });
  });
}
