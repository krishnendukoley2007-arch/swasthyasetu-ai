import 'dart:convert';
import 'dart:math' as math;

/// Types of clinical issues detected during an overnight screening.
enum OvernightIssueType {
  hypoxia,
  desaturation,
  bradycardia,
  severeBradycardia,
  tachycardia,
  arrhythmiaPause,
  ectopicBeat,
  sensorDisconnect,
}

/// A timestamped clinical issue or anomaly flagged during overnight screening.
class OvernightIssueEvent {
  final DateTime timestamp;
  final OvernightIssueType type;
  final String title;
  final String description;
  final String severity; // 'info', 'warning', 'critical'
  final double value;
  final int durationSec;

  const OvernightIssueEvent({
    required this.timestamp,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.value,
    this.durationSec = 0,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'title': title,
    'description': description,
    'severity': severity,
    'value': value,
    'durationSec': durationSec,
  };

  factory OvernightIssueEvent.fromJson(Map<String, dynamic> json) =>
      OvernightIssueEvent(
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: OvernightIssueType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => OvernightIssueType.desaturation,
        ),
        title: json['title'] as String,
        description: json['description'] as String,
        severity: json['severity'] as String,
        value: (json['value'] as num).toDouble(),
        durationSec: json['durationSec'] as int? ?? 0,
      );
}

/// A recorded physiological data point captured during overnight monitoring.
class OvernightDataPoint {
  final DateTime timestamp;
  final int heartRate;
  final double spo2;
  final double temperature;
  final int rrIntervalMs;
  final double ecgQuality;
  final bool leadOff;
  final bool fingerOff;
  final bool isDemo;

  const OvernightDataPoint({
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    this.temperature = 0.0,
    this.rrIntervalMs = 0,
    this.ecgQuality = 1.0,
    this.leadOff = false,
    this.fingerOff = false,
    this.isDemo = false,
  });

  /// Whether sensor has valid skin contact and physiological measurements.
  bool get hasValidHr => heartRate > 0 && (!leadOff || !fingerOff);
  bool get hasValidSpo2 => spo2 > 0 && !fingerOff;
  bool get isValidContact => hasValidHr || hasValidSpo2;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'heartRate': heartRate,
    'spo2': spo2,
    'temperature': temperature,
    'rrIntervalMs': rrIntervalMs,
    'ecgQuality': ecgQuality,
    'leadOff': leadOff,
    'fingerOff': fingerOff,
    'isDemo': isDemo,
  };

  factory OvernightDataPoint.fromJson(Map<String, dynamic> json) =>
      OvernightDataPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        heartRate: json['heartRate'] as int,
        spo2: (json['spo2'] as num).toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        rrIntervalMs: json['rrIntervalMs'] as int? ?? 0,
        ecgQuality: (json['ecgQuality'] as num?)?.toDouble() ?? 1.0,
        leadOff: json['leadOff'] as bool? ?? false,
        fingerOff: json['fingerOff'] as bool? ?? false,
        isDemo: json['isDemo'] as bool? ?? false,
      );
}

/// Comprehensive summary of an overnight monitoring screening session.
class OvernightSessionReport {
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalDuration;
  final Duration validContactDuration;
  final bool isDemo;

  // Cardiovascular metrics
  final int baselineHr;
  final int meanSleepHr;
  final int minHr;
  final int maxHr;
  final double nocturnalDipPercent;
  final String nocturnalDipCategory;

  // Oximetry & Respiratory metrics
  final double meanSpo2;
  final double lowestSpo2;
  final int hypoxiaDurationMinutes;
  final double odiScore; // Oxygen Desaturation Index (events / hour)
  final String odiSeverity;
  final int respiratoryRate;

  // Autonomic Heart Rate Variability (HRV)
  final int sdnn;
  final int rmssd;

  // Overall Assessment
  final String sleepRecoveryVerdict;
  final String triageRecommendation;

  // Flagged Issues and Raw Data
  final List<OvernightIssueEvent> events;
  final List<OvernightDataPoint> timeSeries;

  const OvernightSessionReport({
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
    required this.validContactDuration,
    required this.isDemo,
    required this.baselineHr,
    required this.meanSleepHr,
    required this.minHr,
    required this.maxHr,
    required this.nocturnalDipPercent,
    required this.nocturnalDipCategory,
    required this.meanSpo2,
    required this.lowestSpo2,
    required this.hypoxiaDurationMinutes,
    required this.odiScore,
    required this.odiSeverity,
    required this.respiratoryRate,
    required this.sdnn,
    required this.rmssd,
    required this.sleepRecoveryVerdict,
    required this.triageRecommendation,
    required this.events,
    required this.timeSeries,
  });

  /// Exports the complete overnight session to standard CSV format.
  String toCsv() {
    final buffer = StringBuffer();
    // Metadata Header
    buffer.writeln('# SwasthyaSetu AI — Overnight Screening Session Report');
    buffer.writeln('# Start Time: ${startTime.toIso8601String()}');
    buffer.writeln('# End Time: ${endTime.toIso8601String()}');
    buffer.writeln('# Total Duration: ${totalDuration.inMinutes} minutes');
    buffer.writeln(
      '# Valid Contact Duration: ${validContactDuration.inMinutes} minutes',
    );
    buffer.writeln('# Is Demo: $isDemo');
    buffer.writeln('# Mean Sleep HR: $meanSleepHr BPM');
    buffer.writeln(
      '# Nocturnal HR Dip: ${nocturnalDipPercent.toStringAsFixed(1)}% ($nocturnalDipCategory)',
    );
    buffer.writeln('# Lowest SpO2: ${lowestSpo2.toStringAsFixed(1)}%');
    buffer.writeln(
      '# ODI Score: ${odiScore.toStringAsFixed(1)} events/hr ($odiSeverity)',
    );
    buffer.writeln('# SDNN: ${sdnn}ms | RMSSD: ${rmssd}ms');
    buffer.writeln('# Recovery Verdict: $sleepRecoveryVerdict');
    buffer.writeln('');

    // Events Section
    buffer.writeln('# DETECTED CLINICAL EVENTS');
    buffer.writeln(
      'Event Timestamp,Type,Severity,Value,Duration (sec),Description',
    );
    for (final e in events) {
      buffer.writeln(
        '${e.timestamp.toIso8601String()},${e.type.name},${e.severity},${e.value},${e.durationSec},"${e.description.replaceAll('"', '""')}"',
      );
    }
    buffer.writeln('');

    // Time Series Section
    buffer.writeln('# TIME SERIES DATA');
    buffer.writeln(
      'Timestamp,HeartRate_BPM,SpO2_Percent,Temp_C,RR_Interval_ms,ECG_Quality,LeadOff,FingerOff,ValidContact',
    );
    for (final p in timeSeries) {
      buffer.writeln(
        '${p.timestamp.toIso8601String()},${p.heartRate},${p.spo2.toStringAsFixed(1)},${p.temperature.toStringAsFixed(2)},${p.rrIntervalMs},${p.ecgQuality.toStringAsFixed(2)},${p.leadOff},${p.fingerOff},${p.isValidContact}',
      );
    }

    return buffer.toString();
  }

  /// Exports the session report to structured JSON.
  String toJsonString() {
    final map = {
      'metadata': {
        'version': '1.0',
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'totalDurationMinutes': totalDuration.inMinutes,
        'validContactDurationMinutes': validContactDuration.inMinutes,
        'isDemo': isDemo,
      },
      'metrics': {
        'baselineHr': baselineHr,
        'meanSleepHr': meanSleepHr,
        'minHr': minHr,
        'maxHr': maxHr,
        'nocturnalDipPercent': nocturnalDipPercent,
        'nocturnalDipCategory': nocturnalDipCategory,
        'meanSpo2': meanSpo2,
        'lowestSpo2': lowestSpo2,
        'hypoxiaDurationMinutes': hypoxiaDurationMinutes,
        'odiScore': odiScore,
        'odiSeverity': odiSeverity,
        'respiratoryRate': respiratoryRate,
        'sdnn': sdnn,
        'rmssd': rmssd,
        'sleepRecoveryVerdict': sleepRecoveryVerdict,
        'triageRecommendation': triageRecommendation,
      },
      'events': events.map((e) => e.toJson()).toList(),
      'timeSeries': timeSeries.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

/// Pure Dart clinical analysis engine for full-night physiological recordings.
class OvernightAnalysisEngine {
  OvernightAnalysisEngine._();

  /// Scans and analyzes an overnight series of data points, detecting issues and computing clinical biomarkers.
  static OvernightSessionReport analyze(
    List<OvernightDataPoint> points, {
    int? baselineDaytimeHr,
  }) {
    if (points.isEmpty) {
      final now = DateTime.now();
      return OvernightSessionReport(
        startTime: now,
        endTime: now,
        totalDuration: Duration.zero,
        validContactDuration: Duration.zero,
        isDemo: false,
        baselineHr: 72,
        meanSleepHr: 72,
        minHr: 72,
        maxHr: 72,
        nocturnalDipPercent: 0,
        nocturnalDipCategory: 'No Data Recorded',
        meanSpo2: 98.0,
        lowestSpo2: 98.0,
        hypoxiaDurationMinutes: 0,
        odiScore: 0,
        odiSeverity: 'Normal (<5)',
        respiratoryRate: 14,
        sdnn: 0,
        rmssd: 0,
        sleepRecoveryVerdict:
            'Insufficient session duration to evaluate nocturnal recovery.',
        triageRecommendation:
            'Ensure sensors are attached throughout the sleep session.',
        events: const [],
        timeSeries: const [],
      );
    }

    final startTime = points.first.timestamp;
    final endTime = points.last.timestamp;
    final totalDuration = endTime.difference(startTime);
    final isDemoSession = points.any((p) => p.isDemo);

    final validPoints = points.where((p) => p.isValidContact).toList();
    final validHrPoints = points.where((p) => p.hasValidHr).toList();
    final validSpo2Points = points.where((p) => p.hasValidSpo2).toList();

    // 1. Durations (accumulate sub-second telemetry intervals with millisecond precision)
    int validMillis = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].isValidContact) {
        final dt = points[i].timestamp
            .difference(points[i - 1].timestamp)
            .inMilliseconds;
        validMillis += dt.clamp(0, 30000);
      }
    }
    final validDuration = Duration(milliseconds: validMillis);

    // 2. Cardiovascular HR & Nocturnal Dipping
    final hrList = validHrPoints.map((p) => p.heartRate).toList();
    final meanSleepHr = hrList.isNotEmpty
        ? (hrList.reduce((a, b) => a + b) / hrList.length).round()
        : 65;
    final minHr = hrList.isNotEmpty ? hrList.reduce(math.min) : 60;
    final maxHr = hrList.isNotEmpty ? hrList.reduce(math.max) : 75;

    // Baseline HR: either provided or average of the first 15% of points (pre-sleep)
    final int calculatedBaselineHr;
    if (baselineDaytimeHr != null &&
        baselineDaytimeHr >= 45 &&
        baselineDaytimeHr <= 150) {
      calculatedBaselineHr = baselineDaytimeHr;
    } else if (validHrPoints.length >= 10) {
      final initialSliceCount = math.max(
        5,
        (validHrPoints.length * 0.15).round(),
      );
      final initialSlice = validHrPoints
          .take(initialSliceCount)
          .map((p) => p.heartRate)
          .toList();
      calculatedBaselineHr =
          (initialSlice.reduce((a, b) => a + b) / initialSlice.length).round();
    } else {
      calculatedBaselineHr = math.max(72, meanSleepHr + 8);
    }

    final double dipPercent = calculatedBaselineHr > 0
        ? ((calculatedBaselineHr - meanSleepHr) / calculatedBaselineHr) * 100.0
        : 0.0;

    final String dipCategory;
    if (dipPercent >= 10.0 && dipPercent <= 20.0) {
      dipCategory = 'Normal Dipper (10-20%)';
    } else if (dipPercent < 10.0 && dipPercent >= 0.0) {
      dipCategory = 'Non-Dipper (<10%)';
    } else if (dipPercent > 20.0) {
      dipCategory = 'Extreme Dipper (>20%)';
    } else {
      dipCategory = 'Reverse Dipper / Riser (<0%)';
    }

    // 3. SpO2 Oximetry & Hypoxia
    final spo2List = validSpo2Points.map((p) => p.spo2).toList();
    final meanSpo2 = spo2List.isNotEmpty
        ? spo2List.reduce((a, b) => a + b) / spo2List.length
        : 98.0;
    final lowestSpo2 = spo2List.isNotEmpty ? spo2List.reduce(math.min) : 98.0;

    // Time under 90% SpO2 (Hypoxia)
    int hypoxiaMillis = 0;
    for (int i = 1; i < validSpo2Points.length; i++) {
      if (validSpo2Points[i].spo2 < 90.0) {
        final dt = validSpo2Points[i].timestamp
            .difference(validSpo2Points[i - 1].timestamp)
            .inMilliseconds;
        hypoxiaMillis += dt.clamp(0, 30000);
      }
    }
    final hypoxiaMinutes = (hypoxiaMillis / 60000.0).round();

    // 4. Clinical Issue Scanning (Apnea / Desaturations, Arrhythmias, Brady/Tachy)
    final events = <OvernightIssueEvent>[];

    // Scan for sensor disconnections
    bool inDisconnect = false;
    DateTime? disconnectStart;
    for (final p in points) {
      if (!p.isValidContact) {
        if (!inDisconnect) {
          inDisconnect = true;
          disconnectStart = p.timestamp;
        }
      } else {
        if (inDisconnect && disconnectStart != null) {
          final dur = p.timestamp.difference(disconnectStart).inSeconds;
          if (dur >= 15) {
            events.add(
              OvernightIssueEvent(
                timestamp: disconnectStart,
                type: OvernightIssueType.sensorDisconnect,
                title: 'Sensor Lead / Finger Disconnection',
                description:
                    'Sensor contact lost for $dur seconds during monitoring.',
                severity: 'info',
                value: dur.toDouble(),
                durationSec: dur,
              ),
            );
          }
          inDisconnect = false;
        }
      }
    }

    // Scan for Desaturations (drops >= 3% from local moving baseline)
    int desatCount = 0;
    double runningSpo2Base = 98.0;
    bool inDesat = false;
    DateTime? desatStart;
    double desatNadir = 100.0;

    for (int i = 0; i < validSpo2Points.length; i++) {
      final curSpo2 = validSpo2Points[i].spo2;
      // Exponential moving average for baseline oxygenation
      runningSpo2Base = (runningSpo2Base * 0.95) + (curSpo2 * 0.05);

      if (curSpo2 <= runningSpo2Base - 3.0 || curSpo2 < 90.0) {
        if (!inDesat) {
          inDesat = true;
          desatStart = validSpo2Points[i].timestamp;
          desatNadir = curSpo2;
        } else {
          desatNadir = math.min(desatNadir, curSpo2);
        }
      } else if (inDesat && curSpo2 >= runningSpo2Base - 1.5) {
        // Desaturation recovery
        final dur = validSpo2Points[i].timestamp
            .difference(desatStart!)
            .inSeconds;
        if (dur >= 10) {
          desatCount++;
          final isSevere = desatNadir < 88.0;
          events.add(
            OvernightIssueEvent(
              timestamp: desatStart,
              type: desatNadir < 90.0
                  ? OvernightIssueType.hypoxia
                  : OvernightIssueType.desaturation,
              title: desatNadir < 90.0
                  ? 'Hypoxic Desaturation Episode'
                  : 'Nocturnal SpO2 Drop (>=3%)',
              description:
                  'SpO2 dropped to ${desatNadir.toStringAsFixed(1)}% for $dur seconds (Drop from ${runningSpo2Base.toStringAsFixed(1)}%).',
              severity: isSevere ? 'critical' : 'warning',
              value: desatNadir,
              durationSec: dur,
            ),
          );
        }
        inDesat = false;
      }
    }

    // Oxygen Desaturation Index (ODI)
    final validHours = math.max(0.1, validDuration.inSeconds / 3600.0);
    final odiScore = desatCount / validHours;
    final String odiSeverity;
    if (odiScore < 5.0) {
      odiSeverity = 'Normal (<5)';
    } else if (odiScore < 15.0) {
      odiSeverity = 'Mild Sleep Apnea / Hypopnea Risk (5-15)';
    } else if (odiScore < 30.0) {
      odiSeverity = 'Moderate Sleep Apnea Risk (15-30)';
    } else {
      odiSeverity = 'Severe Sleep Apnea Risk (>30)';
    }

    // Scan for Bradycardia & Tachycardia
    for (int i = 0; i < validHrPoints.length; i++) {
      final hr = validHrPoints[i].heartRate;
      if (hr < 40) {
        // Severe bradycardia
        if (events.isEmpty ||
            events.last.type != OvernightIssueType.severeBradycardia ||
            validHrPoints[i].timestamp
                    .difference(events.last.timestamp)
                    .inSeconds >
                300) {
          events.add(
            OvernightIssueEvent(
              timestamp: validHrPoints[i].timestamp,
              type: OvernightIssueType.severeBradycardia,
              title: 'Severe Nocturnal Bradycardia',
              description: 'Heart rate registered $hr BPM at rest.',
              severity: 'critical',
              value: hr.toDouble(),
            ),
          );
        }
      } else if (hr < 50) {
        // Mild/Moderate bradycardia
        if (events.isEmpty ||
            events.last.type != OvernightIssueType.bradycardia ||
            validHrPoints[i].timestamp
                    .difference(events.last.timestamp)
                    .inSeconds >
                600) {
          events.add(
            OvernightIssueEvent(
              timestamp: validHrPoints[i].timestamp,
              type: OvernightIssueType.bradycardia,
              title: 'Nocturnal Bradycardia Nadir',
              description: 'Resting pulse reached $hr BPM during deep sleep.',
              severity: 'info',
              value: hr.toDouble(),
            ),
          );
        }
      } else if (hr > 105) {
        // Tachycardia
        if (events.isEmpty ||
            events.last.type != OvernightIssueType.tachycardia ||
            validHrPoints[i].timestamp
                    .difference(events.last.timestamp)
                    .inSeconds >
                300) {
          events.add(
            OvernightIssueEvent(
              timestamp: validHrPoints[i].timestamp,
              type: OvernightIssueType.tachycardia,
              title: 'Nocturnal Tachycardia Surge',
              description: 'Resting pulse elevated to $hr BPM while asleep.',
              severity: 'warning',
              value: hr.toDouble(),
            ),
          );
        }
      }
    }

    // 5. Autonomic HRV from RR-intervals
    final rrList = validHrPoints
        .where((p) => p.rrIntervalMs >= 350 && p.rrIntervalMs <= 2500)
        .map((p) => p.rrIntervalMs)
        .toList();

    int sdnn = 0;
    int rmssd = 0;
    if (rrList.length >= 5) {
      final meanRr = rrList.reduce((a, b) => a + b) / rrList.length;
      double varSum = 0;
      double diffSum = 0;
      for (int i = 0; i < rrList.length; i++) {
        varSum += math.pow(rrList[i] - meanRr, 2);
        if (i > 0) {
          diffSum += math.pow(rrList[i] - rrList[i - 1], 2);
        }
        // Scan for arrhythmia pauses
        if (rrList[i] > 2000) {
          final isDupPause =
              events.isNotEmpty &&
              events.any(
                (e) =>
                    e.type == OvernightIssueType.arrhythmiaPause &&
                    validPoints[i].timestamp
                            .difference(e.timestamp)
                            .inSeconds
                            .abs() <
                        5,
              );
          if (!isDupPause) {
            events.add(
              OvernightIssueEvent(
                timestamp: validPoints[i].timestamp,
                type: OvernightIssueType.arrhythmiaPause,
                title: 'Cardiac Rhythm Pause (>2.0s)',
                description: 'R-R interval extended to ${rrList[i]} ms.',
                severity: 'warning',
                value: rrList[i].toDouble(),
              ),
            );
          }
        }
        // Scan for premature ectopic beats (debounced to prevent duplicate frame triggers)
        if (rrList[i] < meanRr * 0.60 && meanRr > 600) {
          final isDupEctopic =
              events.isNotEmpty &&
              events.any(
                (e) =>
                    e.type == OvernightIssueType.ectopicBeat &&
                    (validPoints[i].timestamp
                                .difference(e.timestamp)
                                .inSeconds
                                .abs() <
                            3 ||
                        (e.value == rrList[i].toDouble() &&
                            validPoints[i].timestamp
                                    .difference(e.timestamp)
                                    .inSeconds
                                    .abs() <
                                10)),
              );
          if (!isDupEctopic) {
            events.add(
              OvernightIssueEvent(
                timestamp: validPoints[i].timestamp,
                type: OvernightIssueType.ectopicBeat,
                title: 'Premature Ectopic Beat',
                description:
                    'Short R-R interval of ${rrList[i]} ms (${(rrList[i] / meanRr * 100).round()}% of mean).',
                severity: 'info',
                value: rrList[i].toDouble(),
              ),
            );
          }
        }
      }
      sdnn = math.sqrt(varSum / rrList.length).round();
      rmssd = math.sqrt(diffSum / math.max(1, rrList.length - 1)).round();
    }

    // 6. Overall Recovery Verdict & Recommendation
    final String recoveryVerdict;
    final String triageRecommendation;

    if (odiScore >= 15.0 || lowestSpo2 < 85.0) {
      recoveryVerdict = 'Elevated Nocturnal Hypoxia & Sleep Disruption';
      triageRecommendation =
          'Significant nocturnal desaturations detected (ODI: ${odiScore.toStringAsFixed(1)}, Min SpO2: ${lowestSpo2.toStringAsFixed(1)}%). Recommend formal polysomnography (PSG) and pulmonology evaluation.';
    } else if (dipPercent < 0.0) {
      recoveryVerdict = 'Reverse Dipper / Nocturnal Sympathetic Surge';
      triageRecommendation =
          'Heart rate increased overnight rather than resting. Associated with autonomic dysfunction, sleep apnea, or nocturnal hypertension. Advise 24-hour ambulatory monitoring.';
    } else if (dipPercent < 10.0) {
      recoveryVerdict = 'Blunted Nocturnal Dip (Non-Dipper)';
      triageRecommendation =
          'Nocturnal heart rate dipping was blunted (${dipPercent.toStringAsFixed(1)}% vs target 10-20%). Suggests incomplete parasympathetic recovery.';
    } else {
      recoveryVerdict = 'Restorative Autonomic Recovery';
      triageRecommendation =
          'Normal nocturnal dipping (${dipPercent.toStringAsFixed(1)}%) with stable oxygenation (ODI: ${odiScore.toStringAsFixed(1)}). Low cardiovascular strain.';
    }

    return OvernightSessionReport(
      startTime: startTime,
      endTime: endTime,
      totalDuration: totalDuration,
      validContactDuration: validDuration,
      isDemo: isDemoSession,
      baselineHr: calculatedBaselineHr,
      meanSleepHr: meanSleepHr,
      minHr: minHr,
      maxHr: maxHr,
      nocturnalDipPercent: dipPercent,
      nocturnalDipCategory: dipCategory,
      meanSpo2: meanSpo2,
      lowestSpo2: lowestSpo2,
      hypoxiaDurationMinutes: hypoxiaMinutes,
      odiScore: odiScore,
      odiSeverity: odiSeverity,
      respiratoryRate: 14,
      sdnn: sdnn,
      rmssd: rmssd,
      sleepRecoveryVerdict: recoveryVerdict,
      triageRecommendation: triageRecommendation,
      events: events,
      timeSeries: points,
    );
  }
}
