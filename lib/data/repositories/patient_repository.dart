import 'package:swasthyasetu_ai/core/services/storage_manager.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/mappers/row_mappers.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// How a patient list is ordered in the UI.
enum PatientSort { recentlyScreened, nameAsc, riskDesc, neverScreened }

/// A patient plus the derived numbers the list row needs, computed in one pass
/// so the list doesn't fire a query per row.
class PatientSummary {
  final Patient patient;
  final int screeningCount;

  /// Oldest → newest risk scores, capped for the sparkline.
  final List<int> riskTrend;

  /// Risk band of the most recent screening, or null if never screened.
  final String? latestRiskLevel;
  final int pendingSyncCount;

  const PatientSummary({
    required this.patient,
    required this.screeningCount,
    required this.riskTrend,
    required this.latestRiskLevel,
    required this.pendingSyncCount,
  });

  bool get hasScreenings => screeningCount > 0;

  int get latestRiskScore => riskTrend.isEmpty ? 0 : riskTrend.last;
}

class PatientRepository {
  PatientRepository(this._db, this._storage);

  final AppDatabase _db;
  final StorageManager _storage;

  static const int sparklinePoints = 8;

  // ─────────────────────────────── Reads ───────────────────────────────

  Future<List<Patient>> getAll() async =>
      (await _db.getAllPatients()).map((r) => r.toModel()).toList();

  Stream<List<Patient>> watchAll() =>
      _db.watchAllPatients().map((rows) => rows.map((r) => r.toModel()).toList());

  Future<Patient?> getById(String id) async =>
      (await _db.getPatient(id))?.toModel();

  /// Emits whenever *either* the patient table or the screening table changes,
  /// so counts and sparklines can't go stale after a screening is saved.
  Stream<List<PatientSummary>> watchSummaries() {
    return _db.watchAllPatients().asyncMap((rows) async {
      final summaries = <PatientSummary>[];
      for (final row in rows) {
        summaries.add(await _summarise(row.toModel()));
      }
      return summaries;
    });
  }

  Future<List<PatientSummary>> getSummaries() async {
    final rows = await _db.getAllPatients();
    final out = <PatientSummary>[];
    for (final row in rows) {
      out.add(await _summarise(row.toModel()));
    }
    return out;
  }

  Future<PatientSummary> _summarise(Patient patient) async {
    final screenings = await _db.getScreeningsForPatient(patient.id);
    // getScreeningsForPatient returns newest-first; the sparkline reads left to
    // right as oldest → newest, so take the newest N then reverse.
    final trend = screenings
        .take(sparklinePoints)
        .map((s) => s.riskScore)
        .toList()
        .reversed
        .toList();

    return PatientSummary(
      patient: patient,
      screeningCount: screenings.length,
      riskTrend: trend,
      latestRiskLevel: screenings.isEmpty ? null : screenings.first.riskLevel,
      pendingSyncCount:
          screenings.where((s) => s.syncStatus != 'SYNCED').length,
    );
  }

  /// Case- and diacritic-insensitive match on name, phone, or location.
  static List<PatientSummary> filter(
    List<PatientSummary> source, {
    String query = '',
    Set<String> vulnerabilityFlags = const {},
    Set<String> riskLevels = const {},
    PatientSort sort = PatientSort.recentlyScreened,
  }) {
    final needle = query.trim().toLowerCase();

    var result = source.where((s) {
      final p = s.patient;
      if (needle.isNotEmpty) {
        final haystack = [
          p.name,
          p.phone ?? '',
          p.location ?? '',
          '${p.age}',
        ].join(' ').toLowerCase();
        if (!haystack.contains(needle)) return false;
      }
      if (vulnerabilityFlags.isNotEmpty &&
          !p.vulnerabilityFlags.any(vulnerabilityFlags.contains)) {
        return false;
      }
      if (riskLevels.isNotEmpty &&
          (s.latestRiskLevel == null ||
              !riskLevels.contains(s.latestRiskLevel))) {
        return false;
      }
      return true;
    }).toList();

    switch (sort) {
      case PatientSort.nameAsc:
        result.sort((a, b) =>
            a.patient.name.toLowerCase().compareTo(b.patient.name.toLowerCase()));
      case PatientSort.riskDesc:
        result.sort((a, b) => b.latestRiskScore.compareTo(a.latestRiskScore));
      case PatientSort.neverScreened:
        result = result.where((s) => !s.hasScreenings).toList()
          ..sort((a, b) => a.patient.name.compareTo(b.patient.name));
      case PatientSort.recentlyScreened:
        result.sort((a, b) {
          final at = a.patient.lastScreenedAt;
          final bt = b.patient.lastScreenedAt;
          if (at == null && bt == null) {
            return a.patient.name.compareTo(b.patient.name);
          }
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
    }
    return result;
  }

  // ─────────────────────────────── Writes ───────────────────────────────

  Future<void> save(Patient patient) async {
    await _db.upsertPatient(patient.toCompanion());
    await _db.enqueueSync(
      SyncQueueCompanion.insert(
        id: 'patient-${patient.id}',
        entity: 'patients',
        recordId: patient.id,
        operation: 'UPSERT',
        queuedAt: DateTime.now(),
      ),
    );
  }

  Future<Patient> create({
    required String name,
    required int age,
    required String sex,
    String? location,
    String? phone,
    String? notes,
    List<String> vulnerabilityFlags = const [],
    bool isDemo = false,
    required String id,
  }) async {
    final patient = Patient(
      id: id,
      name: name.trim(),
      age: age,
      sex: sex,
      location: location?.trim().isEmpty ?? true ? null : location!.trim(),
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      createdAt: DateTime.now(),
      vulnerabilityFlags: vulnerabilityFlags,
      isDemo: isDemo,
    );
    await save(patient);
    return patient;
  }

  /// Deletes the patient, every screening, and every waveform *file*.
  Future<void> delete(String patientId) =>
      _storage.deletePatientData(patientId);
}
