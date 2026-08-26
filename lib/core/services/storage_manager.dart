import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:swasthyasetu_ai/core/services/waveform_store.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// One line in the Settings storage breakdown.
class StorageCategory {
  final String id;
  final int bytes;
  final int itemCount;

  const StorageCategory({
    required this.id,
    required this.bytes,
    required this.itemCount,
  });

  String get formatted => formatBytes(bytes);
}

class StorageUsage {
  /// Logical size of patient rows (sum of field bytes).
  final int patients;

  /// Logical size of screening rows.
  final int screenings;

  /// Real on-disk size of the gzipped waveform directory.
  final int waveforms;

  /// Logical size of cached AI/offline explanations.
  final int explanations;

  /// Logical size of the bundled guideline corpus as indexed in SQLite.
  final int guidelineCache;

  /// Real on-disk size of imported offline map tiles.
  final int mapCache;

  /// Real on-disk size of `swasthyasetu.db`, including free pages.
  final int databaseFile;

  final int patientCount;
  final int screeningCount;
  final int waveformFileCount;
  final int guidelineChunkCount;

  /// The storage envelope this build is designed for.
  final int budgetBytes;

  const StorageUsage({
    required this.patients,
    required this.screenings,
    required this.waveforms,
    required this.explanations,
    required this.guidelineCache,
    required this.mapCache,
    required this.databaseFile,
    required this.patientCount,
    required this.screeningCount,
    required this.waveformFileCount,
    required this.guidelineChunkCount,
    required this.budgetBytes,
  });

  const StorageUsage.empty()
      : patients = 0,
        screenings = 0,
        waveforms = 0,
        explanations = 0,
        guidelineCache = 0,
        mapCache = 0,
        databaseFile = 0,
        patientCount = 0,
        screeningCount = 0,
        waveformFileCount = 0,
        guidelineChunkCount = 0,
        budgetBytes = StorageManager.defaultBudgetBytes;

  /// Real bytes this app occupies: the database file as it actually sits on
  /// disk, plus the two blob directories. Deliberately *not* the sum of the
  /// logical categories — that would double-count the DB.
  int get total => databaseFile + waveforms + mapCache;

  double get fractionOfBudget =>
      budgetBytes == 0 ? 0 : (total / budgetBytes).clamp(0.0, 1.0);

  bool get isNearCapacity => fractionOfBudget >= 0.9;

  int get remainingBytes => (budgetBytes - total).clamp(0, budgetBytes);

  /// How many more full-resolution screenings fit in the remaining budget,
  /// using the measured average rather than a guess. Falls back to the design
  /// figure of 30 KB/screening until there's real data to measure.
  int get projectedRemainingScreenings {
    final perScreening = screeningCount > 0 && waveforms > 0
        ? waveforms / screeningCount
        : 30 * 1024;
    if (perScreening <= 0) return 0;
    return (remainingBytes / perScreening).floor();
  }

  List<StorageCategory> get breakdown => [
        StorageCategory(id: 'patients', bytes: patients, itemCount: patientCount),
        StorageCategory(
            id: 'screenings', bytes: screenings, itemCount: screeningCount),
        StorageCategory(
            id: 'waveforms', bytes: waveforms, itemCount: waveformFileCount),
        StorageCategory(
            id: 'guidelines',
            bytes: guidelineCache,
            itemCount: guidelineChunkCount),
        StorageCategory(id: 'explanations', bytes: explanations, itemCount: 0),
        StorageCategory(id: 'mapTiles', bytes: mapCache, itemCount: 0),
      ];

  String get formattedTotal => formatBytes(total);
  String get formattedBudget => formatBytes(budgetBytes);
}

/// Outcome of a "Free up space" run, so the UI can report what actually
/// happened instead of a vague "done".
class ReclaimReport {
  final int downsampledBytes;
  final int orphanBytes;
  final int vacuumedBytes;
  final int mapTileBytes;

  const ReclaimReport({
    this.downsampledBytes = 0,
    this.orphanBytes = 0,
    this.vacuumedBytes = 0,
    this.mapTileBytes = 0,
  });

  int get total =>
      downsampledBytes + orphanBytes + vacuumedBytes + mapTileBytes;

  bool get reclaimedAnything => total > 0;
}

class StorageManager {
  StorageManager(this._db, this._waveforms);

  final AppDatabase _db;
  final WaveformStore _waveforms;

  /// 200 MB — the upper end of the design envelope.
  static const int defaultBudgetBytes = 200 * 1024 * 1024;
  static const String mapTilesDirName = 'map_tiles';
  static const String exportDirName = 'exports';

  static Future<Directory> mapTilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, mapTilesDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> exportsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, exportDirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ───────────────────────────── Accounting ─────────────────────────────

  Future<StorageUsage> getStorageUsage({
    int budgetBytes = defaultBudgetBytes,
  }) async {
    final patients = await _db.getAllPatients();
    final screenings = await _db.getAllScreenings();
    final chunks = await _db.getAllGuidelineChunks();

    var explanationBytes = 0;
    for (final s in screenings) {
      final e = await _db.getExplanation(s.id);
      if (e != null) {
        explanationBytes += _utf8Len(e.summary) +
            _utf8Len(e.whyThisLevel) +
            _utf8Len(e.safeNextSteps) +
            _utf8Len(e.whenToEscalate) +
            _utf8Len(e.questionsToAsk) +
            _utf8Len(e.citations) +
            _utf8Len(e.disclaimer);
      }
    }

    return StorageUsage(
      patients: patients.fold<int>(0, (sum, r) => sum + _patientRowBytes(r)),
      screenings:
          screenings.fold<int>(0, (sum, r) => sum + _screeningRowBytes(r)),
      waveforms: await _waveforms.totalBytesOnDisk(),
      explanations: explanationBytes,
      guidelineCache: chunks.fold<int>(
        0,
        (sum, c) =>
            sum +
            _utf8Len(c.body) +
            _utf8Len(c.keywords) +
            _utf8Len(c.title) +
            _utf8Len(c.ruleTags),
      ),
      mapCache: await _directorySize(await mapTilesDirectory()),
      databaseFile: await _db.databaseFileSize(),
      patientCount: patients.length,
      screeningCount: screenings.length,
      waveformFileCount: await _waveforms.fileCount(),
      guidelineChunkCount: chunks.length,
      budgetBytes: budgetBytes,
    );
  }

  /// True when the app is close to its own storage envelope. Shown as a startup
  /// banner. Note: querying OS-level free space needs a platform channel Flutter
  /// doesn't ship, so this is measured against [defaultBudgetBytes] — which is
  /// the number this build actually commits to.
  Future<bool> isNearCapacity() async =>
      (await getStorageUsage()).isNearCapacity;

  // ──────────────────────────── Reclaim space ────────────────────────────

  Future<ReclaimReport> freeUpSpace({
    bool downsampleOldWaveforms = true,
    bool removeOrphans = true,
    bool clearMapCache = false,
    bool compactDatabase = true,
    int keepFullResolutionPerPatient =
        WaveformStore.fullResolutionRetentionCount,
  }) async {
    var downsampled = 0;
    var orphans = 0;
    var maps = 0;
    var vacuumed = 0;

    if (downsampleOldWaveforms) {
      downsampled = await _waveforms.applyRetentionPolicyForAllPatients(
        keepFullResolution: keepFullResolutionPerPatient,
      );
    }
    if (removeOrphans) {
      orphans = await _waveforms.reconcile();
    }
    if (clearMapCache) {
      final dir = await mapTilesDirectory();
      maps = await _directorySize(dir);
      if (await dir.exists()) await dir.delete(recursive: true);
      await mapTilesDirectory();
    }
    if (compactDatabase) {
      final before = await _db.databaseFileSize();
      await _db.compact();
      final after = await _db.databaseFileSize();
      vacuumed = (before - after).clamp(0, before);
    }

    return ReclaimReport(
      downsampledBytes: downsampled,
      orphanBytes: orphans,
      mapTileBytes: maps,
      vacuumedBytes: vacuumed,
    );
  }

  // ─────────────────────────────── Export ───────────────────────────────
  // Only ever called from an explicit user tap. Nothing here runs on a timer,
  // on sync, or in the background — clinical data leaves the device only when
  // a human asks for it.

  Future<File> exportPatientJson(String patientId) async {
    final patient = await _db.getPatient(patientId);
    if (patient == null) {
      throw StateError('Patient $patientId not found');
    }
    final screenings = await _db.getScreeningsForPatient(patientId);

    final payload = <String, dynamic>{
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'generatedBy': 'SwasthyaSetu AI (screening prototype — not a diagnosis)',
      'patient': {
        'id': patient.id,
        'name': patient.name,
        'age': patient.age,
        'sex': patient.sex,
        'location': patient.location,
        'phone': patient.phone,
        'notes': patient.notes,
        'vulnerabilityFlags': jsonDecode(patient.vulnerabilityFlags),
        'createdAt': patient.createdAt.toIso8601String(),
        'lastScreenedAt': patient.lastScreenedAt?.toIso8601String(),
      },
      'screenings': [
        for (final s in screenings)
          {
            'id': s.id,
            'timestamp': s.timestamp.toIso8601String(),
            'deviceId': s.deviceId,
            'heartRateBpm': s.heartRate,
            'spo2Percent': s.spo2,
            'temperatureC': s.temperature,
            'ecgRhythm': s.ecgRhythm,
            'ecgQualityScore': s.ecgQualityScore,
            'rrIntervalMs': s.rrIntervalMs,
            'bpEstimate': {
              'systolic': s.estimatedSystolic,
              'diastolic': s.estimatedDiastolic,
              'confidence': s.bpConfidence,
              'calibratedAt': s.bpCalibratedAt?.toIso8601String(),
              'note': 'Cuffless PTT estimate — experimental, not a cuff reading',
            },
            'symptoms': jsonDecode(s.symptoms),
            'symptomDuration': s.symptomDuration,
            'symptomNotes': s.symptomNotes,
            'triage': {
              'riskLevel': s.riskLevel,
              'riskScore': s.riskScore,
              'triggeredRules': jsonDecode(s.triggeredRules),
              'recommendedAction': s.recommendedAction,
              'escalationLevel': s.escalationLevel,
            },
            'waveforms': [
              for (final b in await _db.getWaveformBlobsForScreening(s.id))
                {
                  'type': b.type,
                  'sampleRate': b.sampleRate,
                  'durationMs': b.durationMs,
                  'storedBytes': b.sizeBytes,
                  'isEnvelope': b.isDownsampled,
                },
            ],
          },
      ],
    };

    final dir = await exportsDirectory();
    final file = File(p.join(dir.path, _exportFileName(patient.name, 'json')));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file;
  }

  Future<File> exportPatientCsv(String patientId) async {
    final patient = await _db.getPatient(patientId);
    if (patient == null) {
      throw StateError('Patient $patientId not found');
    }
    final screenings = await _db.getScreeningsForPatient(patientId);

    final rows = <List<String>>[
      [
        'screening_id',
        'timestamp',
        'patient_name',
        'age',
        'sex',
        'heart_rate_bpm',
        'spo2_percent',
        'temperature_c',
        'ecg_rhythm',
        'ecg_quality_score',
        'bp_est_systolic',
        'bp_est_diastolic',
        'bp_confidence',
        'symptoms',
        'risk_band',
        'risk_score',
        'triggered_rules',
        'recommended_action',
        'device_id',
        'sync_status',
      ],
      for (final s in screenings)
        [
          s.id,
          s.timestamp.toIso8601String(),
          patient.name,
          '${patient.age}',
          patient.sex,
          '${s.heartRate}',
          '${s.spo2}',
          s.temperature.toStringAsFixed(1),
          s.ecgRhythm,
          s.ecgQualityScore.toStringAsFixed(2),
          '${s.estimatedSystolic}',
          '${s.estimatedDiastolic}',
          s.bpConfidence,
          (jsonDecode(s.symptoms) as List).join('; '),
          s.riskLevel,
          '${s.riskScore}',
          (jsonDecode(s.triggeredRules) as List).join('; '),
          s.recommendedAction,
          s.deviceId,
          s.syncStatus,
        ],
    ];

    final dir = await exportsDirectory();
    final file = File(p.join(dir.path, _exportFileName(patient.name, 'csv')));
    await file.writeAsString(
      rows.map((r) => r.map(_csvEscape).join(',')).join('\r\n'),
      flush: true,
    );
    return file;
  }

  /// Clears previously generated export files. Called after sharing so patient
  /// data doesn't linger in a directory other apps may be able to reach.
  Future<void> clearExports() async {
    final dir = await exportsDirectory();
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
  }

  // ─────────────────────────────── Deletion ───────────────────────────────

  /// Deletes a patient, every screening, every waveform *file*, cached
  /// explanations, queued sync entries and SOS log lines that reference them.
  Future<void> deletePatientData(String patientId) async {
    final screenings = await _db.getScreeningsForPatient(patientId);
    for (final s in screenings) {
      await _waveforms.deleteAllForScreening(s.id);
      await _db.deleteExplanationsForScreening(s.id);
      await _db.removeSyncItemsForRecord(s.id);
      await _db.deleteScreeningRow(s.id);
    }
    await _db.removeSyncItemsForRecord(patientId);
    await _db.deletePatientRow(patientId);
    await _db.compact();
  }

  /// Full wipe. Patient data and blobs go unconditionally; the guideline corpus
  /// and settings are opt-in because losing them costs offline capability, not
  /// privacy.
  Future<void> wipeAllData({
    bool includeGuidelineCorpus = false,
    bool includeMapTiles = true,
    bool includeSettings = false,
  }) async {
    await _waveforms.deleteEverything();
    await _db.deleteAllPatientData();

    if (includeGuidelineCorpus) await _db.clearGuidelineCache();
    if (includeMapTiles) {
      final dir = await mapTilesDirectory();
      if (await dir.exists()) await dir.delete(recursive: true);
      await mapTilesDirectory();
    }
    if (includeSettings) {
      await _db.delete(_db.appSettings).go();
    }
    await clearExports();
    await _db.compact();
  }

  // ─────────────────────────────── Helpers ───────────────────────────────

  static int _utf8Len(String s) => utf8.encode(s).length;

  static int _patientRowBytes(PatientRow r) =>
      _utf8Len(r.id) +
      _utf8Len(r.name) +
      _utf8Len(r.sex) +
      _utf8Len(r.location ?? '') +
      _utf8Len(r.phone ?? '') +
      _utf8Len(r.notes ?? '') +
      _utf8Len(r.vulnerabilityFlags) +
      _utf8Len(r.syncStatus) +
      // age, createdAt, lastScreenedAt, isDemo, retryCount
      8 * 5;

  static int _screeningRowBytes(ScreeningRow r) =>
      _utf8Len(r.id) +
      _utf8Len(r.patientId) +
      _utf8Len(r.deviceId) +
      _utf8Len(r.ecgRhythm) +
      _utf8Len(r.symptoms) +
      _utf8Len(r.symptomDuration ?? '') +
      _utf8Len(r.symptomNotes ?? '') +
      _utf8Len(r.riskLevel) +
      _utf8Len(r.triggeredRules) +
      _utf8Len(r.recommendedAction) +
      _utf8Len(r.escalationLevel) +
      _utf8Len(r.bpConfidence) +
      _utf8Len(r.syncStatus) +
      // 14 numeric/date columns
      8 * 14;

  static Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += (await entity.stat()).size;
    }
    return total;
  }

  static String _exportFileName(String patientName, String ext) {
    final safe = patientName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    return 'swasthyasetu_${safe.isEmpty ? 'patient' : safe}_$stamp.$ext';
  }

  static String _csvEscape(String value) {
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
