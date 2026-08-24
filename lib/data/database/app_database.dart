import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

part 'app_database.g.dart';

/// Row classes are suffixed `Row` so they never collide with the hand-written
/// domain models (`Patient`, `Device`, `Screening`, ...). The domain models stay
/// the transport/UI type; `*Row` is strictly the persistence type. Mapping lives
/// in `lib/data/repositories/`.

@DataClassName('PatientRow')
class Patients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get age => integer()();
  TextColumn get sex => text()();
  TextColumn get location => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastScreenedAt => dateTime().nullable()();

  /// JSON array of vulnerability flag ids: `elderly`, `chronic`, `pregnant`,
  /// `infant`, `immunocompromised`. These shift rule thresholds — see
  /// `RiskEngine.thresholdsFor`.
  TextColumn get vulnerabilityFlags =>
      text().withDefault(const Constant('[]'))();
  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ScreeningRow')
class Screenings extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().references(Patients, #id)();
  TextColumn get deviceId => text().withDefault(const Constant('UNKNOWN'))();
  DateTimeColumn get timestamp => dateTime()();

  // Vitals
  IntColumn get heartRate => integer()();
  IntColumn get spo2 => integer()();
  RealColumn get temperature => real()();

  // ECG summary
  TextColumn get ecgRhythm => text().withDefault(const Constant('UNKNOWN'))();
  RealColumn get ecgQualityScore => real().withDefault(const Constant(0.0))();
  IntColumn get rrIntervalMs => integer().withDefault(const Constant(0))();

  // Cuffless BP estimate (experimental, per-user calibrated)
  IntColumn get pttMs => integer().withDefault(const Constant(0))();
  IntColumn get estimatedSystolic => integer().withDefault(const Constant(0))();
  IntColumn get estimatedDiastolic => integer().withDefault(const Constant(0))();
  TextColumn get bpConfidence =>
      text().withDefault(const Constant('EXPERIMENTAL'))();
  DateTimeColumn get bpCalibratedAt => dateTime().nullable()();

  // Reported symptoms
  TextColumn get symptoms => text().withDefault(const Constant('[]'))();
  TextColumn get symptomDuration => text().nullable()();
  TextColumn get symptomNotes => text().nullable()();

  // Deterministic triage output
  TextColumn get riskLevel => text()();
  IntColumn get riskScore => integer()();
  TextColumn get triggeredRules => text().withDefault(const Constant('[]'))();
  TextColumn get recommendedAction => text().withDefault(const Constant(''))();
  TextColumn get escalationLevel => text().withDefault(const Constant('NONE'))();

  // Optional geotag — only written when the worker has consented (DPDPA).
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metadata only. The actual samples live on disk as gzipped int16 —
/// see `WaveformStore`.
@DataClassName('WaveformBlobRow')
class WaveformBlobs extends Table {
  TextColumn get screeningId => text()();
  TextColumn get type => text()(); // 'ecg' | 'ppg'
  TextColumn get filePath => text()();
  IntColumn get durationMs => integer()();
  IntColumn get sampleRate => integer()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  BoolColumn get isDownsampled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {screeningId, type};
}

@DataClassName('DeviceRow')
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get macAddress => text().withDefault(const Constant(''))();
  IntColumn get batteryPercent => integer().withDefault(const Constant(0))();
  BoolColumn get isConnected => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();
  TextColumn get firmwareVersion =>
      text().withDefault(const Constant('UNKNOWN'))();

  /// Last time cuffless BP was calibrated against a reference cuff.
  DateTimeColumn get calibrationDate => dateTime().nullable()();
  IntColumn get calibrationSystolic => integer().nullable()();
  IntColumn get calibrationDiastolic => integer().nullable()();
  BoolColumn get isDemo => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  TextColumn get id => text()();

  /// `table_name` — the getter can't be called `tableName`, that's taken by
  /// drift's own `Table` API.
  TextColumn get entity => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // INSERT | UPDATE | DELETE
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bundled clinical guideline corpus, indexed for offline retrieval.
@DataClassName('GuidelineChunkRow')
class GuidelineCache extends Table {
  TextColumn get chunkId => text()();
  TextColumn get source => text()(); // WHO_IMCI, NDMA, ICMR, ...
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Can't be named `text` — collides with drift's `Table.text()` builder.
  TextColumn get body => text()();

  /// Space-separated normalised terms, precomputed at seed time so retrieval
  /// doesn't re-tokenise the whole corpus on every query.
  TextColumn get keywords => text().withDefault(const Constant(''))();

  /// JSON array of rule ids this chunk explains, e.g. `["spo2_critical"]`.
  TextColumn get ruleTags => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {chunkId};
}

/// Cached AI/offline explanation, one row per screening per source.
@DataClassName('ExplanationRow')
class Explanations extends Table {
  TextColumn get screeningId => text()();
  TextColumn get source => text()(); // 'gemini' | 'offline'
  TextColumn get summary => text()();
  TextColumn get whyThisLevel => text()();
  TextColumn get safeNextSteps => text()(); // JSON array
  TextColumn get whenToEscalate => text()();
  TextColumn get questionsToAsk => text()(); // JSON array
  TextColumn get citations => text().withDefault(const Constant('[]'))();
  TextColumn get disclaimer => text()();
  TextColumn get modelName => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {screeningId, source};
}

@DataClassName('EmergencyContactRow')
class EmergencyContacts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get relation => text().withDefault(const Constant(''))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SosEventRow')
class SosEvents extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text().nullable()();
  TextColumn get screeningId => text().nullable()();

  /// MANUAL | FALL_DETECTED | HIGH_RISK
  TextColumn get trigger => text()();
  DateTimeColumn get triggeredAt => dateTime()();

  /// JSON array of `{name, phone}` actually dispatched to.
  TextColumn get contactsNotified => text().withDefault(const Constant('[]'))();
  TextColumn get message => text().withDefault(const Constant(''))();

  /// DISPATCHED | CANCELLED | FAILED
  TextColumn get status => text().withDefault(const Constant('DISPATCHED'))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Patients,
    Screenings,
    WaveformBlobs,
    Devices,
    SyncQueue,
    GuidelineCache,
    Explanations,
    EmergencyContacts,
    SosEvents,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test / in-memory constructor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ───────────────────────────── Patients ─────────────────────────────

  Future<int> upsertPatient(PatientsCompanion patient) =>
      into(patients).insertOnConflictUpdate(patient);

  Future<void> deletePatientRow(String id) =>
      (delete(patients)..where((t) => t.id.equals(id))).go();

  Future<PatientRow?> getPatient(String id) =>
      (select(patients)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<PatientRow>> getAllPatients({bool includeDemo = true}) {
    final q = select(patients);
    if (!includeDemo) q.where((t) => t.isDemo.equals(false));
    q.orderBy([
      (t) => OrderingTerm(expression: t.lastScreenedAt, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
    return q.get();
  }

  Stream<List<PatientRow>> watchAllPatients() {
    return (select(patients)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastScreenedAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  Future<void> touchPatientLastScreened(String patientId, DateTime at) =>
      (update(patients)..where((t) => t.id.equals(patientId)))
          .write(PatientsCompanion(lastScreenedAt: Value(at)));

  Future<int> countPatients() async {
    final count = patients.id.count();
    final row = await (selectOnly(patients)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  // ──────────────────────────── Screenings ────────────────────────────

  Future<int> upsertScreening(ScreeningsCompanion screening) =>
      into(screenings).insertOnConflictUpdate(screening);

  Future<void> deleteScreeningRow(String id) =>
      (delete(screenings)..where((t) => t.id.equals(id))).go();

  Future<ScreeningRow?> getScreening(String id) =>
      (select(screenings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ScreeningRow>> getScreeningsForPatient(String patientId,
      {int? limit}) {
    final q = select(screenings)
      ..where((t) => t.patientId.equals(patientId))
      ..orderBy(
          [(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Stream<List<ScreeningRow>> watchScreeningsForPatient(String patientId) =>
      (select(screenings)
            ..where((t) => t.patientId.equals(patientId))
            ..orderBy([
              (t) => OrderingTerm(
                  expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .watch();

  Future<List<ScreeningRow>> getAllScreenings({int? limit}) {
    final q = select(screenings)
      ..orderBy(
          [(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Stream<List<ScreeningRow>> watchRecentScreenings({int limit = 50}) =>
      (select(screenings)
            ..orderBy([
              (t) => OrderingTerm(
                  expression: t.timestamp, mode: OrderingMode.desc)
            ])
            ..limit(limit))
          .watch();

  Future<List<ScreeningRow>> getScreeningsSince(DateTime since) =>
      (select(screenings)
            ..where((t) => t.timestamp.isBiggerOrEqualValue(since))
            ..orderBy([
              (t) => OrderingTerm(
                  expression: t.timestamp, mode: OrderingMode.desc)
            ]))
          .get();

  Future<List<ScreeningRow>> getScreeningsBySyncStatus(String status) =>
      (select(screenings)
            ..where((t) => t.syncStatus.equals(status))
            ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
          .get();

  Future<void> setScreeningSyncStatus(String id, String status,
          {int? attempts}) =>
      (update(screenings)..where((t) => t.id.equals(id))).write(
        ScreeningsCompanion(
          syncStatus: Value(status),
          retryCount:
              attempts != null ? Value(attempts) : const Value.absent(),
        ),
      );

  Future<int> countScreenings() async {
    final count = screenings.id.count();
    final row = await (selectOnly(screenings)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countScreeningsForPatient(String patientId) async {
    final count = screenings.id.count();
    final row = await (selectOnly(screenings)
          ..addColumns([count])
          ..where(screenings.patientId.equals(patientId)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Risk-band histogram over all stored screenings — used by the community
  /// dashboard. Aggregate only; no identifiers leave this query.
  Future<Map<String, int>> riskDistribution({DateTime? since}) async {
    final count = screenings.id.count();
    final q = selectOnly(screenings)
      ..addColumns([screenings.riskLevel, count])
      ..groupBy([screenings.riskLevel]);
    if (since != null) {
      q.where(screenings.timestamp.isBiggerOrEqualValue(since));
    }
    final rows = await q.get();
    return {
      for (final r in rows)
        (r.read(screenings.riskLevel) ?? 'UNKNOWN'): r.read(count) ?? 0,
    };
  }

  // ───────────────────────── Waveform metadata ─────────────────────────

  Future<int> upsertWaveformBlob(WaveformBlobsCompanion blob) =>
      into(waveformBlobs).insertOnConflictUpdate(blob);

  Future<void> deleteWaveformBlobsForScreening(String screeningId) =>
      (delete(waveformBlobs)..where((t) => t.screeningId.equals(screeningId)))
          .go();

  Future<WaveformBlobRow?> getWaveformBlob(String screeningId, String type) =>
      (select(waveformBlobs)
            ..where((t) => t.screeningId.equals(screeningId) & t.type.equals(type)))
          .getSingleOrNull();

  Future<List<WaveformBlobRow>> getWaveformBlobsForScreening(
          String screeningId) =>
      (select(waveformBlobs)..where((t) => t.screeningId.equals(screeningId)))
          .get();

  Future<List<WaveformBlobRow>> getAllWaveformBlobs() =>
      select(waveformBlobs).get();

  Future<int> totalWaveformBytes() async {
    final sum = waveformBlobs.sizeBytes.sum();
    final row =
        await (selectOnly(waveformBlobs)..addColumns([sum])).getSingle();
    return (row.read(sum) ?? 0).toInt();
  }

  // ────────────────────────────── Devices ──────────────────────────────

  Future<int> upsertDevice(DevicesCompanion device) =>
      into(devices).insertOnConflictUpdate(device);

  Future<void> deleteDeviceRow(String id) =>
      (delete(devices)..where((t) => t.id.equals(id))).go();

  Future<DeviceRow?> getDeviceRow(String id) =>
      (select(devices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<DeviceRow>> getAllDevices() => (select(devices)
        ..orderBy([
          (t) => OrderingTerm(
              expression: t.lastConnectedAt, mode: OrderingMode.desc)
        ]))
      .get();

  Stream<List<DeviceRow>> watchAllDevices() => select(devices).watch();

  Future<void> markDeviceConnected(
    String id, {
    DateTime? at,
    int? battery,
    String? firmware,
  }) =>
      (update(devices)..where((t) => t.id.equals(id))).write(
        DevicesCompanion(
          isConnected: const Value(true),
          lastConnectedAt: Value(at ?? DateTime.now()),
          batteryPercent:
              battery != null ? Value(battery) : const Value.absent(),
          firmwareVersion:
              firmware != null ? Value(firmware) : const Value.absent(),
        ),
      );

  Future<void> markAllDevicesDisconnected() =>
      update(devices).write(const DevicesCompanion(isConnected: Value(false)));

  Future<void> setDeviceCalibration(
    String id, {
    required DateTime date,
    required int systolic,
    required int diastolic,
  }) =>
      (update(devices)..where((t) => t.id.equals(id))).write(
        DevicesCompanion(
          calibrationDate: Value(date),
          calibrationSystolic: Value(systolic),
          calibrationDiastolic: Value(diastolic),
        ),
      );

  // ───────────────────────────── Sync queue ─────────────────────────────

  Future<int> enqueueSync(SyncQueueCompanion item) =>
      into(syncQueue).insertOnConflictUpdate(item);

  Future<List<SyncQueueRow>> getPendingSyncItems() => (select(syncQueue)
        ..where((t) => t.status.equals('PENDING') | t.status.equals('FAILED'))
        ..orderBy([(t) => OrderingTerm(expression: t.queuedAt)]))
      .get();

  Future<List<SyncQueueRow>> getAllSyncItems() => (select(syncQueue)
        ..orderBy(
            [(t) => OrderingTerm(expression: t.queuedAt, mode: OrderingMode.desc)]))
      .get();

  Stream<List<SyncQueueRow>> watchSyncQueue() => (select(syncQueue)
        ..orderBy(
            [(t) => OrderingTerm(expression: t.queuedAt, mode: OrderingMode.desc)]))
      .watch();

  Future<void> removeSyncItem(String id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<void> removeSyncItemsForRecord(String recordId) =>
      (delete(syncQueue)..where((t) => t.recordId.equals(recordId))).go();

  Future<void> updateSyncItem(
    String id, {
    int? attempts,
    String? lastError,
    String? status,
    DateTime? lastAttemptAt,
  }) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(
          attempts: attempts != null ? Value(attempts) : const Value.absent(),
          lastError: lastError != null ? Value(lastError) : const Value.absent(),
          status: status != null ? Value(status) : const Value.absent(),
          lastAttemptAt: lastAttemptAt != null
              ? Value(lastAttemptAt)
              : const Value.absent(),
        ),
      );

  Future<int> countPendingSync() async {
    final count = syncQueue.id.count();
    final row = await (selectOnly(syncQueue)
          ..addColumns([count])
          ..where(syncQueue.status.equals('PENDING') |
              syncQueue.status.equals('FAILED')))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ────────────────────────── Guideline corpus ──────────────────────────

  Future<void> replaceGuidelineCorpus(
          List<GuidelineCacheCompanion> chunks) async =>
      transaction(() async {
        await delete(guidelineCache).go();
        await batch((b) => b.insertAll(guidelineCache, chunks));
      });

  Future<List<GuidelineChunkRow>> getAllGuidelineChunks() =>
      select(guidelineCache).get();

  Future<int> countGuidelineChunks() async {
    final count = guidelineCache.chunkId.count();
    final row =
        await (selectOnly(guidelineCache)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> guidelineCacheBytes() async {
    final rows = await select(guidelineCache).get();
    return rows.fold<int>(
      0,
      (sum, r) =>
          sum + r.body.length + r.keywords.length + r.title.length + r.ruleTags.length,
    );
  }

  Future<void> clearGuidelineCache() => delete(guidelineCache).go();

  // ──────────────────────────── Explanations ────────────────────────────

  Future<int> upsertExplanation(ExplanationsCompanion e) =>
      into(explanations).insertOnConflictUpdate(e);

  Future<ExplanationRow?> getExplanation(String screeningId,
          {String? source}) async {
    final q = select(explanations)
      ..where((t) => t.screeningId.equals(screeningId));
    if (source != null) q.where((t) => t.source.equals(source));
    q.orderBy(
        [(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);
    q.limit(1);
    final rows = await q.get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> deleteExplanationsForScreening(String screeningId) =>
      (delete(explanations)..where((t) => t.screeningId.equals(screeningId)))
          .go();

  // ───────────────────────── Emergency contacts ─────────────────────────

  Future<int> upsertEmergencyContact(EmergencyContactsCompanion c) =>
      into(emergencyContacts).insertOnConflictUpdate(c);

  Future<void> deleteEmergencyContact(String id) =>
      (delete(emergencyContacts)..where((t) => t.id.equals(id))).go();

  Future<List<EmergencyContactRow>> getEmergencyContacts() =>
      (select(emergencyContacts)
            ..orderBy([
              (t) => OrderingTerm(
                  expression: t.isPrimary, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.sortOrder),
            ]))
          .get();

  Stream<List<EmergencyContactRow>> watchEmergencyContacts() =>
      (select(emergencyContacts)
            ..orderBy([
              (t) => OrderingTerm(
                  expression: t.isPrimary, mode: OrderingMode.desc),
              (t) => OrderingTerm(expression: t.sortOrder),
            ]))
          .watch();

  // ────────────────────────────── SOS log ──────────────────────────────

  Future<int> insertSosEvent(SosEventsCompanion e) =>
      into(sosEvents).insertOnConflictUpdate(e);

  Future<List<SosEventRow>> getSosEvents({int limit = 100}) => (select(sosEvents)
        ..orderBy([
          (t) => OrderingTerm(expression: t.triggeredAt, mode: OrderingMode.desc)
        ])
        ..limit(limit))
      .get();

  Stream<List<SosEventRow>> watchSosEvents() => (select(sosEvents)
        ..orderBy([
          (t) => OrderingTerm(expression: t.triggeredAt, mode: OrderingMode.desc)
        ])
        ..limit(100))
      .watch();

  Future<void> clearSosEvents() => delete(sosEvents).go();

  // ────────────────────────────── Settings ──────────────────────────────

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(key: Value(key), value: Value(value)));

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, String>> getAllSettings() async {
    final rows = await select(appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Stream<Map<String, String>> watchSettings() => select(appSettings)
      .watch()
      .map((rows) => {for (final r in rows) r.key: r.value});

  Future<void> deleteSetting(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  // ───────────────────────────── Whole-DB ops ─────────────────────────────

  /// Deletes every patient-derived row. Guideline corpus and settings survive —
  /// wiping those is a separate, explicit action.
  Future<void> deleteAllPatientData() => transaction(() async {
        await delete(sosEvents).go();
        await delete(explanations).go();
        await delete(waveformBlobs).go();
        await delete(syncQueue).go();
        await delete(screenings).go();
        await delete(patients).go();
      });

  Future<int> databaseFileSize() async {
    final f = await _databaseFile();
    return await f.exists() ? (await f.stat()).size : 0;
  }

  /// Reclaims pages freed by deletes so Settings reports honest numbers.
  Future<void> compact() => customStatement('VACUUM');
}

Future<File> _databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'swasthyasetu.db'));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await _databaseFile();
    // Larger temp store keeps VACUUM off the (possibly tiny) /tmp partition.
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    return NativeDatabase.createInBackground(file);
  });
}
