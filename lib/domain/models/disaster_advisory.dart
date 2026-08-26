import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One offline disaster-health guide.
///
/// Bundled as an asset (assets/guidelines/disaster_advisories.json), NOT
/// fetched: the whole point is being readable when a cyclone has knocked the
/// network out. Content follows public NDMA/WHO guidance and is written for
/// a lay reader — steps are actions, not theory.
class DisasterAdvisory {
  final String id;
  final String title;
  final String forWhom;
  final List<String> beforeSteps;
  final List<String> duringSteps;
  final List<String> afterSteps;
  final String helplines;

  const DisasterAdvisory({
    required this.id,
    required this.title,
    required this.forWhom,
    required this.beforeSteps,
    required this.duringSteps,
    required this.afterSteps,
    required this.helplines,
  });

  factory DisasterAdvisory.fromJson(Map<String, dynamic> json) {
    List<String> steps(String key) => ((json[key] as List<dynamic>?) ?? const [])
        .whereType<String>()
        .toList(growable: false);
    return DisasterAdvisory(
      id: json['id'] as String,
      title: json['title'] as String,
      forWhom: json['forWhom'] as String? ?? '',
      beforeSteps: steps('before'),
      duringSteps: steps('during'),
      afterSteps: steps('after'),
      helplines: json['helplines'] as String? ?? '',
    );
  }
}

/// Loaded lazily and parsed once per read — a few KB of JSON, the parse cost
/// is noise compared to the comfort of never caching wrongly.
Future<List<DisasterAdvisory>> loadDisasterAdvisories() async {
  final raw =
      await rootBundle.loadString('assets/guidelines/disaster_advisories.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final list = (decoded['advisories'] as List<dynamic>?) ?? const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(DisasterAdvisory.fromJson)
      .toList(growable: false);
}
