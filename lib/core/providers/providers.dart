import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/core/services/fall_detection_service.dart';
import 'package:swasthyasetu_ai/core/services/gemini_service.dart';
import 'package:swasthyasetu_ai/core/services/location_service.dart';
import 'package:swasthyasetu_ai/core/services/mbtiles_reader.dart';
import 'package:swasthyasetu_ai/core/services/seed_service.dart';
import 'package:swasthyasetu_ai/core/services/sos_service.dart';
import 'package:swasthyasetu_ai/core/services/storage_manager.dart';
import 'package:swasthyasetu_ai/core/services/sync_service.dart';
import 'package:swasthyasetu_ai/core/services/waveform_store.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/explanation_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/patient_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/screening_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// The single dependency-injection surface for the app. Everything stateful
/// hangs off `databaseProvider`, so a test can override that one provider with
/// an in-memory database and get a fully wired app.

// ───────────────────────────── Infrastructure ─────────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final waveformStoreProvider = Provider<WaveformStore>(
  (ref) => WaveformStore(ref.watch(databaseProvider)),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final storageManagerProvider = Provider<StorageManager>(
  (ref) => StorageManager(
    ref.watch(databaseProvider),
    ref.watch(waveformStoreProvider),
  ),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

// ───────────────────────────── Repositories ─────────────────────────────

final patientRepositoryProvider = Provider<PatientRepository>(
  (ref) => PatientRepository(
    ref.watch(databaseProvider),
    ref.watch(storageManagerProvider),
  ),
);

final screeningRepositoryProvider = Provider<ScreeningRepository>(
  (ref) => ScreeningRepository(
    ref.watch(databaseProvider),
    ref.watch(waveformStoreProvider),
  ),
);

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(databaseProvider)),
);

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final service = GeminiService();
  // Keep the credential in step with Settings, so pasting a key takes effect on
  // the next request instead of the next app launch. Done here rather than in
  // SettingsController so the settings layer stays unaware that a network
  // service exists at all.
  ref.listen<String>(
    settingsProvider.select((s) => s.geminiApiKey),
    (_, key) => service.setApiKey(key),
    fireImmediately: true,
  );
  return service;
});

final explanationRepositoryProvider = Provider<ExplanationRepository>(
  (ref) => ExplanationRepository(
    ref.watch(databaseProvider),
    ref.watch(geminiServiceProvider),
  ),
);

final emergencyRepositoryProvider = Provider<EmergencyRepository>(
  (ref) => EmergencyRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

// ───────────────────────────── Settings ─────────────────────────────

/// Settings are held in a notifier rather than read straight from the stream so
/// a toggle repaints instantly instead of waiting for the SQLite write to echo
/// back through the query stream.
class SettingsController extends StateNotifier<AppSettingsSnapshot> {
  SettingsController(this._repo) : super(const AppSettingsSnapshot()) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.load();
  }

  Future<void> refresh() => _load();

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _repo.setLocale(locale);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repo.setThemeMode(mode);
  }

  Future<void> setHighContrast(bool on) async {
    state = state.copyWith(highContrast: on);
    await _repo.setHighContrast(on);
  }

  Future<void> setReducedMotion(bool on) async {
    state = state.copyWith(reducedMotion: on);
    await _repo.setBool(SettingKeys.reducedMotion, on);
  }

  Future<void> setLocationConsent(bool granted) async {
    state = state.copyWith(locationConsent: granted);
    await _repo.setLocationConsent(granted);
  }

  Future<void> setAiConsent(bool granted) async {
    state = state.copyWith(aiConsent: granted);
    await _repo.setAiConsent(granted);
  }

  /// Trimmed, because a key pasted from a browser almost always arrives with a
  /// trailing newline and Google rejects it verbatim.
  Future<void> setGeminiApiKey(String key) async {
    final trimmed = key.trim();
    state = state.copyWith(geminiApiKey: trimmed);
    await _repo.setGeminiApiKey(trimmed);
  }

  Future<void> setSyncConsent(bool granted) async {
    state = state.copyWith(syncConsent: granted);
    await _repo.setBool(SettingKeys.syncConsent, granted);
  }

  Future<void> setFallDetection(bool on) async {
    state = state.copyWith(fallDetection: on);
    await _repo.setBool(SettingKeys.fallDetection, on);
  }

  Future<void> setAutoSuggestSos(bool on) async {
    state = state.copyWith(autoSuggestSos: on);
    await _repo.setBool(SettingKeys.autoSuggestSos, on);
  }

  /// Clamped rather than trusted. A zero-second countdown makes a false-positive
  /// fall alert unstoppable, and anything past a minute means a real fall goes
  /// unreported while the phone politely waits.
  Future<void> setSosCountdownSeconds(int seconds) async {
    final clamped = seconds.clamp(5, 60);
    state = state.copyWith(sosCountdownSeconds: clamped);
    await _repo.setInt(SettingKeys.sosCountdownSeconds, clamped);
  }

  Future<void> setDemoMode(bool on) async {
    state = state.copyWith(demoMode: on);
    await _repo.setBool(SettingKeys.demoMode, on);
  }

  Future<void> setLastDeviceId(String id) async {
    state = state.copyWith(lastDeviceId: id);
    await _repo.setString(SettingKeys.lastDeviceId, id);
  }

  Future<void> setWorkerProfile({
    String? name,
    String? id,
    String? facility,
  }) async {
    state = state.copyWith(
      workerName: name ?? state.workerName,
      workerId: id ?? state.workerId,
      facility: facility ?? state.facility,
    );
    if (name != null) await _repo.setString(SettingKeys.workerName, name);
    if (id != null) await _repo.setString(SettingKeys.workerId, id);
    if (facility != null) {
      await _repo.setString(SettingKeys.facility, facility);
    }
  }

  Future<void> markSynced(DateTime at) async {
    state = state.copyWith(lastSyncAt: at);
    await _repo.markSynced(at);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettingsSnapshot>(
  (ref) => SettingsController(ref.watch(settingsRepositoryProvider)),
);

/// Convenience selectors so widgets rebuild on one field, not the whole object.
final localeProvider =
    Provider<Locale>((ref) => ref.watch(settingsProvider).locale);

final themeModeProvider =
    Provider<ThemeMode>((ref) => ref.watch(settingsProvider).themeMode);

final highContrastProvider =
    Provider<bool>((ref) => ref.watch(settingsProvider).highContrast);

// ───────────────────────────── Patients ─────────────────────────────

final patientSummariesProvider = StreamProvider<List<PatientSummary>>(
  (ref) => ref.watch(patientRepositoryProvider).watchSummaries(),
);

final patientsProvider = StreamProvider<List<Patient>>(
  (ref) => ref.watch(patientRepositoryProvider).watchAll(),
);

final patientProvider = FutureProvider.family<Patient?, String>(
  (ref, id) => ref.watch(patientRepositoryProvider).getById(id),
);

/// `patientId` → display name, for screens that hold a screening but need to
/// name the person. One subscription for the whole list, rather than a lookup
/// per row.
final patientNamesProvider = Provider<Map<String, String>>((ref) {
  return ref.watch(patientsProvider).maybeWhen(
        data: (patients) => {for (final p in patients) p.id: p.name},
        orElse: () => const <String, String>{},
      );
});

/// Search + filter + sort state for the patient list.
@immutable
class PatientQuery {
  final String search;
  final Set<String> vulnerabilityFlags;
  final Set<String> riskLevels;
  final PatientSort sort;

  const PatientQuery({
    this.search = '',
    this.vulnerabilityFlags = const {},
    this.riskLevels = const {},
    this.sort = PatientSort.recentlyScreened,
  });

  bool get hasFilters =>
      search.trim().isNotEmpty ||
      vulnerabilityFlags.isNotEmpty ||
      riskLevels.isNotEmpty;

  PatientQuery copyWith({
    String? search,
    Set<String>? vulnerabilityFlags,
    Set<String>? riskLevels,
    PatientSort? sort,
  }) =>
      PatientQuery(
        search: search ?? this.search,
        vulnerabilityFlags: vulnerabilityFlags ?? this.vulnerabilityFlags,
        riskLevels: riskLevels ?? this.riskLevels,
        sort: sort ?? this.sort,
      );
}

class PatientQueryController extends StateNotifier<PatientQuery> {
  PatientQueryController() : super(const PatientQuery());

  void setSearch(String value) => state = state.copyWith(search: value);
  void setSort(PatientSort sort) => state = state.copyWith(sort: sort);

  void toggleFlag(String flag) {
    final next = {...state.vulnerabilityFlags};
    next.contains(flag) ? next.remove(flag) : next.add(flag);
    state = state.copyWith(vulnerabilityFlags: next);
  }

  void toggleRisk(String level) {
    final next = {...state.riskLevels};
    next.contains(level) ? next.remove(level) : next.add(level);
    state = state.copyWith(riskLevels: next);
  }

  void clear() => state = const PatientQuery();
}

final patientQueryProvider =
    StateNotifierProvider<PatientQueryController, PatientQuery>(
  (ref) => PatientQueryController(),
);

/// The list the UI actually renders: summaries from the DB, filtered in memory.
final filteredPatientsProvider = Provider<AsyncValue<List<PatientSummary>>>(
  (ref) {
    final summaries = ref.watch(patientSummariesProvider);
    final query = ref.watch(patientQueryProvider);
    return summaries.whenData(
      (list) => PatientRepository.filter(
        list,
        query: query.search,
        vulnerabilityFlags: query.vulnerabilityFlags,
        riskLevels: query.riskLevels,
        sort: query.sort,
      ),
    );
  },
);

// ───────────────────────────── Screenings ─────────────────────────────

final recentScreeningsProvider = StreamProvider<List<Screening>>(
  (ref) => ref.watch(screeningRepositoryProvider).watchRecent(),
);

/// Screenings still owed to a server, newest first.
final pendingScreeningsProvider = StreamProvider<List<Screening>>(
  (ref) => ref.watch(screeningRepositoryProvider).watchUnsynced(),
);

/// What the dashboard is allowed to claim.
///
/// It exists because the home screen used to hold `_todayScreenings = 3` and
/// `_totalPatients = 12` as fields — figures no one had measured, shown in the
/// same tiles a worker would use to decide whether the morning's round had been
/// recorded. Every number here is counted from rows that exist on this phone.
///
/// [ready] is false until both underlying streams have delivered. Until then the
/// tiles must show a placeholder rather than a zero, because "0 screenings
/// today" and "not loaded yet" are different statements.
@immutable
class DashboardStats {
  final int todayScreenings;
  final int pendingSync;
  final int highRiskToday;
  final int totalPatients;
  final DateTime? lastScreeningAt;
  final String? lastScreeningRisk;
  final bool ready;

  const DashboardStats({
    this.todayScreenings = 0,
    this.pendingSync = 0,
    this.highRiskToday = 0,
    this.totalPatients = 0,
    this.lastScreeningAt,
    this.lastScreeningRisk,
    this.ready = false,
  });
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final recent = ref.watch(recentScreeningsProvider);
  final pending = ref.watch(pendingScreeningsProvider);
  final patients = ref.watch(patientSummariesProvider);

  final screenings = recent.valueOrNull;
  if (screenings == null) return const DashboardStats();

  // Calendar day on this phone, not a rolling 24 hours: a worker asking "how
  // many today" means since midnight.
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final today =
      screenings.where((s) => !s.timestamp.isBefore(midnight)).toList();

  return DashboardStats(
    todayScreenings: today.length,
    pendingSync: pending.valueOrNull?.length ?? 0,
    highRiskToday: today.where((s) => s.riskLevel.toUpperCase() == 'RED').length,
    totalPatients: patients.valueOrNull?.length ?? 0,
    lastScreeningAt: screenings.isEmpty ? null : screenings.first.timestamp,
    lastScreeningRisk: screenings.isEmpty ? null : screenings.first.riskLevel,
    ready: true,
  );
});

final patientScreeningsProvider =
    StreamProvider.family<List<Screening>, String>(
  (ref, patientId) =>
      ref.watch(screeningRepositoryProvider).watchForPatient(patientId),
);

final screeningProvider = FutureProvider.family<Screening?, String>(
  (ref, id) => ref.watch(screeningRepositoryProvider).getById(id),
);

// ───────────────────────────── Devices ─────────────────────────────

final pairedDevicesProvider = StreamProvider<List<Device>>(
  (ref) => ref.watch(deviceRepositoryProvider).watchAll(),
);

/// One radio for the whole app.
///
/// Held at container level rather than per-screen so that walking from the scan
/// screen into a screening does not drop and re-establish the link, and so an
/// auto-reconnect in progress survives a navigation.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

/// The link state, seeded with the current value so a widget built mid-session
/// renders the real status on its first frame instead of a spinner.
final bleLinkStateProvider = StreamProvider<BleLinkState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.states;
});

/// Convenience accessor that never sits in a loading state.
final bleLinkProvider = Provider<BleLinkState>((ref) {
  final service = ref.watch(bleServiceProvider);
  return ref.watch(bleLinkStateProvider).maybeWhen(
        data: (s) => s,
        orElse: () => service.state,
      );
});

final bleCandidatesProvider = StreamProvider<List<BleCandidate>>(
  (ref) => ref.watch(bleServiceProvider).candidates,
);

final bpCalibrationProvider = FutureProvider<BpCalibration>(
  (ref) => ref.watch(deviceRepositoryProvider).latestCalibration(),
);

// ───────────────────────────── Emergency ─────────────────────────────

final emergencyContactsProvider = StreamProvider<List<EmergencyContact>>(
  (ref) => ref.watch(emergencyRepositoryProvider).watchContacts(),
);

final sosEventsProvider = StreamProvider<List<SosEvent>>(
  (ref) => ref.watch(emergencyRepositoryProvider).watchEvents(),
);

final sosServiceProvider = Provider<SosService>(
  (ref) => SosService(ref.watch(emergencyRepositoryProvider)),
);

/// One detector for the whole app, disposed with the container.
///
/// Held at this level rather than per-screen because a fall matters whether or
/// not the SOS screen happens to be open, and two concurrent subscriptions to
/// the accelerometer would double the battery cost for nothing.
final fallDetectionServiceProvider = Provider<FallDetectionService>((ref) {
  final service = FallDetectionService();
  ref.onDispose(service.dispose);
  return service;
});

/// True when at least one contact has a number that can actually be dialled.
/// The SOS button uses this to explain itself instead of failing on tap.
final hasReachableContactProvider = Provider<bool>((ref) {
  return ref.watch(emergencyContactsProvider).maybeWhen(
        data: (contacts) => contacts
            .any((c) => EmergencyRepository.isDiallable(c.phone)),
        orElse: () => false,
      );
});

// ───────────────────────────── Community / sync ─────────────────────────────

final communityAggregateProvider = FutureProvider<CommunityAggregate>((ref) {
  // Recompute whenever screenings change so the dashboard can't go stale.
  ref.watch(recentScreeningsProvider);
  return ref.watch(screeningRepositoryProvider).aggregate();
});

final syncQueueProvider = StreamProvider<List<SyncQueueRow>>(
  (ref) => ref.watch(databaseProvider).watchSyncQueue(),
);

final pendingSyncCountProvider = Provider<int>((ref) {
  final queue = ref.watch(syncQueueProvider);
  return queue.maybeWhen(
    data: (items) =>
        items.where((i) => i.status != 'SYNCED').length,
    orElse: () => 0,
  );
});

// ───────────────────────────── Storage ─────────────────────────────

final storageUsageProvider = FutureProvider<StorageUsage>((ref) {
  // Storage changes as screenings land, so track them.
  ref.watch(recentScreeningsProvider);
  return ref.watch(storageManagerProvider).getStorageUsage();
});

// ───────────────────────────── Bootstrap ─────────────────────────────

final seedServiceProvider = Provider<SeedService>(
  (ref) => SeedService(
    db: ref.watch(databaseProvider),
    patients: ref.watch(patientRepositoryProvider),
    screenings: ref.watch(screeningRepositoryProvider),
    devices: ref.watch(deviceRepositoryProvider),
    emergency: ref.watch(emergencyRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    waveforms: ref.watch(waveformStoreProvider),
  ),
);

/// Everything that must finish before the first screen is trustworthy: the
/// guideline corpus is in place, defaults exist, orphaned waveform blobs are
/// reconciled, and — on a fresh install only — a demo roster is present.
///
/// Held as a provider rather than run in `main()` so a failure surfaces as a
/// screen the worker can retry from, instead of a black window.
final bootstrapProvider = FutureProvider<SeedReport>((ref) async {
  final report = await ref.watch(seedServiceProvider).run();

  // The settings controller loaded before seeding wrote the defaults, so
  // re-read it: otherwise the first frame uses a snapshot that is already stale.
  await ref.read(settingsProvider.notifier).refresh();

  return report;
});

/// Whether to warn about disk pressure at startup. Resolves to `false` rather
/// than throwing, because a storage check must never block the app.
final lowStorageProvider = FutureProvider<bool>((ref) async {
  await ref.watch(bootstrapProvider.future);
  try {
    return await ref.watch(storageManagerProvider).isNearCapacity();
  } catch (_) {
    return false;
  }
});

/// What offline map coverage this install actually has.
///
/// Discovery touches the filesystem and SQLite, so it is a FutureProvider the
/// map card can show a spinner for; a failure resolves to "no packs" with the
/// reason attached rather than throwing, because a missing map must never take
/// the community dashboard down.
final mapPacksProvider = FutureProvider<MapTileAvailability>((ref) async {
  return discoverMapPacks();
});

/// An open reader for the best available pack, closed when nothing is watching.
///
/// "Best" = an imported pack over the bundled one, then deepest zoom. Null when
/// no usable pack exists, which is the signal for the honest no-tiles state.
final mapReaderProvider = FutureProvider<MbTilesReader?>((ref) async {
  final availability = await ref.watch(mapPacksProvider.future);
  final usable = availability.packs
      .where((pack) => pack.isRaster && pack.tileCount > 0)
      .toList();
  if (usable.isEmpty) return null;
  final pack = usable.first;
  final reader = MbTilesReader.open(pack.path, bundled: pack.bundled);
  ref.onDispose(() => reader?.close());
  return reader;
});
