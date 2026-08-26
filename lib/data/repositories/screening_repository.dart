import 'package:swasthyasetu_ai/core/services/waveform_store.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/mappers/row_mappers.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// A point on the community map. Deliberately carries no patient identifier —
/// only the coarse location, time, and risk band, which is all the aggregate
/// view is permitted to show.
class ScreeningGeoPoint {
  final double latitude;
  final double longitude;
  final String riskLevel;
  final DateTime timestamp;

  const ScreeningGeoPoint({
    required this.latitude,
    required this.longitude,
    required this.riskLevel,
    required this.timestamp,
  });
}

/// Aggregate, anonymised view of this device's screening activity. Computed
/// entirely from the local database so it works with no connectivity, and holds
/// no names, ages, phone numbers, or patient ids.
class CommunityAggregate {
  final int totalScreenings;
  final int patientsScreened;

  /// Risk band → count.
  final Map<String, int> riskDistribution;

  /// Symptom → number of screenings reporting it, highest first.
  final Map<String, int> symptomFrequency;

  /// Rule description → times triggered, highest first.
  final Map<String, int> topTriggeredRules;

  /// Oldest → newest, one entry per day.
  final List<DailyCount> dailyCounts;

  final List<ScreeningGeoPoint> geoPoints;

  final int syncedCount;
  final int pendingCount;
  final int failedCount;

  final DateTime? earliest;
  final DateTime? latest;

  const CommunityAggregate({
    required this.totalScreenings,
    required this.patientsScreened,
    required this.riskDistribution,
    required this.symptomFrequency,
    required this.topTriggeredRules,
    required this.dailyCounts,
    required this.geoPoints,
    required this.syncedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.earliest,
    required this.latest,
  });

  const CommunityAggregate.empty()
      : totalScreenings = 0,
        patientsScreened = 0,
        riskDistribution = const {},
        symptomFrequency = const {},
        topTriggeredRules = const {},
        dailyCounts = const [],
        geoPoints = const [],
        syncedCount = 0,
        pendingCount = 0,
        failedCount = 0,
        earliest = null,
        latest = null;

  int get highRiskCount => riskDistribution['RED'] ?? 0;
  int get elevatedCount => riskDistribution['YELLOW'] ?? 0;
  int get normalCount => riskDistribution['GREEN'] ?? 0;

  double get highRiskShare =>
      totalScreenings == 0 ? 0 : highRiskCount / totalScreenings;

  bool get isEmpty => totalScreenings == 0;
}

class DailyCount {
  final DateTime day;
  final int total;
  final int high;

  const DailyCount({required this.day, required this.total, required this.high});
}

class ScreeningRepository {
  ScreeningRepository(this._db, this._waveforms);

  final AppDatabase _db;
  final WaveformStore _waveforms;

  // ─────────────────────────────── Reads ───────────────────────────────

  Future<List<Screening>> getForPatient(String patientId, {int? limit}) async =>
      (await _db.getScreeningsForPatient(patientId, limit: limit))
          .map((r) => r.toModel())
          .toList();

  Stream<List<Screening>> watchForPatient(String patientId) => _db
      .watchScreeningsForPatient(patientId)
      .map((rows) => rows.map((r) => r.toModel()).toList());

  Future<Screening?> getById(String id) async =>
      (await _db.getScreening(id))?.toModel();

  Future<List<Screening>> getAll({int? limit}) async =>
      (await _db.getAllScreenings(limit: limit))
          .map((r) => r.toModel())
          .toList();

  Stream<List<Screening>> watchRecent({int limit = 50}) => _db
      .watchRecentScreenings(limit: limit)
      .map((rows) => rows.map((r) => r.toModel()).toList());

  /// Everything still owed to the server, newest first.
  ///
  /// Derived from the screening rows rather than the sync queue so a record
  /// whose queue entry was lost still shows up as pending — losing a queue row
  /// must never silently drop a patient's reading.
  Stream<List<Screening>> watchUnsynced() =>
      _db.watchRecentScreenings(limit: 500).map((rows) => rows
          .map((r) => r.toModel())
          .where((s) => s.syncStatus != 'SYNCED')
          .toList());

  Future<WaveformData?> loadWaveform(String screeningId, String type) =>
      _waveforms.load(screeningId, type);

  // ─────────────────────────────── Writes ───────────────────────────────

  /// Persists a screening atomically-enough: the row lands first, then the
  /// waveform blobs, then the sync entry. If the process dies between steps the
  /// worst case is an orphaned blob or a missing waveform — both are repaired by
  /// `WaveformStore.reconcile()` on next launch, and neither loses the vitals.
  Future<void> save(
    Screening screening, {
    List<int>? ecgSamples,
    List<int>? ppgSamples,
    int ecgSampleRate = WaveformStore.defaultSampleRate,
    int ppgSampleRate = 100,
  }) async {
    await _db.upsertScreening(screening.toCompanion());

    if (ecgSamples != null && ecgSamples.isNotEmpty) {
      await _waveforms.save(
        screeningId: screening.id,
        type: 'ecg',
        samples: ecgSamples,
        durationMs: (ecgSamples.length * 1000 / ecgSampleRate).round(),
        sampleRate: ecgSampleRate,
      );
    }
    if (ppgSamples != null && ppgSamples.isNotEmpty) {
      await _waveforms.save(
        screeningId: screening.id,
        type: 'ppg',
        samples: ppgSamples,
        durationMs: (ppgSamples.length * 1000 / ppgSampleRate).round(),
        sampleRate: ppgSampleRate,
      );
    }

    await _db.touchPatientLastScreened(screening.patientId, screening.timestamp);

    await _db.enqueueSync(
      SyncQueueCompanion.insert(
        id: 'screening-${screening.id}',
        entity: 'screenings',
        recordId: screening.id,
        operation: 'UPSERT',
        queuedAt: DateTime.now(),
      ),
    );

    // Keep the storage envelope honest as data accumulates rather than waiting
    // for the user to hit "Free up space".
    await _waveforms.applyRetentionPolicy(patientId: screening.patientId);
  }

  Future<void> delete(String screeningId) async {
    await _waveforms.deleteAllForScreening(screeningId);
    await _db.deleteExplanationsForScreening(screeningId);
    await _db.removeSyncItemsForRecord(screeningId);
    await _db.deleteScreeningRow(screeningId);
  }

  // ────────────────────────── Aggregates (local) ──────────────────────────

  Future<CommunityAggregate> aggregate({int days = 14}) async {
    final rows = await _db.getAllScreenings();
    if (rows.isEmpty) return const CommunityAggregate.empty();

    final risk = <String, int>{};
    final symptoms = <String, int>{};
    final rules = <String, int>{};
    final geo = <ScreeningGeoPoint>[];
    final patientIds = <String>{};
    var synced = 0, pending = 0, failed = 0;
    DateTime? earliest, latest;

    for (final row in rows) {
      patientIds.add(row.patientId);
      risk[row.riskLevel] = (risk[row.riskLevel] ?? 0) + 1;

      for (final s in decodeStringList(row.symptoms)) {
        symptoms[s] = (symptoms[s] ?? 0) + 1;
      }
      for (final r in decodeStringList(row.triggeredRules)) {
        rules[r] = (rules[r] ?? 0) + 1;
      }

      if (row.latitude != null && row.longitude != null) {
        geo.add(ScreeningGeoPoint(
          latitude: row.latitude!,
          longitude: row.longitude!,
          riskLevel: row.riskLevel,
          timestamp: row.timestamp,
        ));
      }

      switch (row.syncStatus) {
        case 'SYNCED':
          synced++;
        case 'FAILED':
          failed++;
        default:
          pending++;
      }

      if (earliest == null || row.timestamp.isBefore(earliest)) {
        earliest = row.timestamp;
      }
      if (latest == null || row.timestamp.isAfter(latest)) {
        latest = row.timestamp;
      }
    }

    return CommunityAggregate(
      totalScreenings: rows.length,
      patientsScreened: patientIds.length,
      riskDistribution: risk,
      symptomFrequency: _sortedByValueDesc(symptoms),
      topTriggeredRules: _sortedByValueDesc(rules, take: 8),
      dailyCounts: _dailyCounts(rows, days),
      geoPoints: geo,
      syncedCount: synced,
      pendingCount: pending,
      failedCount: failed,
      earliest: earliest,
      latest: latest,
    );
  }

  static List<DailyCount> _dailyCounts(List<ScreeningRow> rows, int days) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final buckets = <DateTime, List<ScreeningRow>>{};

    for (var i = days - 1; i >= 0; i--) {
      buckets[startOfToday.subtract(Duration(days: i))] = [];
    }
    for (final row in rows) {
      final day =
          DateTime(row.timestamp.year, row.timestamp.month, row.timestamp.day);
      buckets[day]?.add(row);
    }
    return buckets.entries
        .map((e) => DailyCount(
              day: e.key,
              total: e.value.length,
              high: e.value.where((r) => r.riskLevel == 'RED').length,
            ))
        .toList();
  }

  static Map<String, int> _sortedByValueDesc(Map<String, int> input,
      {int? take}) {
    final entries = input.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final limited = take == null ? entries : entries.take(take);
    return {for (final e in limited) e.key: e.value};
  }
}
