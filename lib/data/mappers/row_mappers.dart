import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// Row ↔ domain-model conversion. Kept in one place so the JSON-in-TEXT
/// encoding of list columns is defined exactly once.
///
/// Lists are stored as JSON arrays rather than comma-joined strings so a symptom
/// or rule description containing a comma can't silently split into two.

List<String> decodeStringList(String raw) {
  if (raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((e) => '$e').toList();
    return const [];
  } on FormatException {
    // Tolerate legacy comma-joined values rather than losing the row.
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}

String encodeStringList(List<String> values) => jsonEncode(values);

extension PatientRowMapper on PatientRow {
  Patient toModel() => Patient(
        id: id,
        name: name,
        age: age,
        sex: sex,
        location: location,
        phone: phone,
        notes: notes,
        createdAt: createdAt,
        lastScreenedAt: lastScreenedAt,
        vulnerabilityFlags: decodeStringList(vulnerabilityFlags),
        isDemo: isDemo,
        syncStatus: syncStatus,
        retryCount: retryCount,
      );
}

extension PatientModelMapper on Patient {
  PatientsCompanion toCompanion() => PatientsCompanion(
        id: Value(id),
        name: Value(name),
        age: Value(age),
        sex: Value(sex),
        location: Value(location),
        phone: Value(phone),
        notes: Value(notes),
        createdAt: Value(createdAt),
        lastScreenedAt: Value(lastScreenedAt),
        vulnerabilityFlags: Value(encodeStringList(vulnerabilityFlags)),
        isDemo: Value(isDemo),
        syncStatus: Value(syncStatus),
        retryCount: Value(retryCount ?? 0),
      );
}

extension ScreeningRowMapper on ScreeningRow {
  Screening toModel() => Screening(
        id: id,
        patientId: patientId,
        deviceId: deviceId,
        timestamp: timestamp,
        heartRate: heartRate,
        spo2: spo2,
        temperature: temperature,
        ecgRhythm: ecgRhythm,
        ecgQualityScore: ecgQualityScore,
        rrIntervalMs: rrIntervalMs,
        pttMs: pttMs,
        estimatedSystolic: estimatedSystolic,
        estimatedDiastolic: estimatedDiastolic,
        bpConfidence: bpConfidence,
        bpCalibratedAt: bpCalibratedAt,
        symptoms: decodeStringList(symptoms),
        symptomDuration: symptomDuration,
        symptomNotes: symptomNotes,
        riskLevel: riskLevel,
        riskScore: riskScore,
        triggeredRules: decodeStringList(triggeredRules),
        recommendedAction: recommendedAction,
        escalationLevel: escalationLevel,
        latitude: latitude,
        longitude: longitude,
        syncStatus: syncStatus,
        retryCount: retryCount,
        isDemo: isDemo,
      );
}

extension ScreeningModelMapper on Screening {
  ScreeningsCompanion toCompanion() => ScreeningsCompanion(
        id: Value(id),
        patientId: Value(patientId),
        deviceId: Value(deviceId),
        timestamp: Value(timestamp),
        heartRate: Value(heartRate),
        spo2: Value(spo2),
        temperature: Value(temperature),
        ecgRhythm: Value(ecgRhythm),
        ecgQualityScore: Value(ecgQualityScore),
        rrIntervalMs: Value(rrIntervalMs),
        pttMs: Value(pttMs),
        estimatedSystolic: Value(estimatedSystolic),
        estimatedDiastolic: Value(estimatedDiastolic),
        bpConfidence: Value(bpConfidence),
        bpCalibratedAt: Value(bpCalibratedAt),
        symptoms: Value(encodeStringList(symptoms)),
        symptomDuration: Value(symptomDuration),
        symptomNotes: Value(symptomNotes),
        riskLevel: Value(riskLevel),
        riskScore: Value(riskScore),
        triggeredRules: Value(encodeStringList(triggeredRules)),
        recommendedAction: Value(recommendedAction),
        escalationLevel: Value(escalationLevel),
        latitude: Value(latitude),
        longitude: Value(longitude),
        syncStatus: Value(syncStatus),
        retryCount: Value(retryCount),
        isDemo: Value(isDemo),
      );
}

extension DeviceRowMapper on DeviceRow {
  Device toModel() => Device(
        id: id,
        name: name,
        macAddress: macAddress,
        batteryPercent: batteryPercent,
        isConnected: isConnected,
        lastConnectedAt: lastConnectedAt ?? createdAtFallback,
        firmwareVersion: firmwareVersion,
        calibrationDate: calibrationDate,
        isDemo: isDemo,
      );

  /// `Device.lastConnectedAt` is non-nullable in the domain model but nullable
  /// in storage (a paired-but-never-connected device is a real state). Epoch is
  /// used as the sentinel; UI checks `lastConnectedAt.year > 1971`.
  DateTime get createdAtFallback => DateTime.fromMillisecondsSinceEpoch(0);
}

extension DeviceModelMapper on Device {
  DevicesCompanion toCompanion() => DevicesCompanion(
        id: Value(id),
        name: Value(name),
        macAddress: Value(macAddress),
        batteryPercent: Value(batteryPercent),
        isConnected: Value(isConnected),
        lastConnectedAt: Value(
          lastConnectedAt.millisecondsSinceEpoch == 0 ? null : lastConnectedAt,
        ),
        firmwareVersion: Value(firmwareVersion),
        calibrationDate: Value(calibrationDate),
        isDemo: Value(isDemo),
      );

  bool get hasEverConnected => lastConnectedAt.millisecondsSinceEpoch > 0;
}
