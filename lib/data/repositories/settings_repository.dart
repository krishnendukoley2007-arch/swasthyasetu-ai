import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/domain/models/audience.dart';
import 'package:swasthyasetu_ai/domain/models/vulnerability_persona.dart';

/// Every persisted preference key in one place. Strings are namespaced so a
/// stray `getSetting('language')` from some other layer can't collide.
abstract final class SettingKeys {
  static const locale = 'pref.locale';
  static const themeMode = 'pref.themeMode';
  static const highContrast = 'pref.highContrast';
  static const reducedMotion = 'pref.reducedMotion';
  static const vulnerabilityPersona = 'pref.vulnerabilityPersona';

  static const workerName = 'profile.workerName';
  static const workerId = 'profile.workerId';
  static const facility = 'profile.facility';

  static const locationConsent = 'consent.location';
  static const aiConsent = 'consent.onlineAi';
  static const syncConsent = 'consent.sync';

  /// Whether the phone may locate itself to fetch local heat/air conditions.
  /// Separate from [locationConsent] (screening geotags) on purpose: agreeing
  /// to weather alerts must not silently turn screening geotags on too.
  static const envLocationConsent = 'consent.envWeather';

  /// Whether anonymized aggregate indicators (truncated geohash, hour-bucket,
  /// risk band, category) may be contributed to the community early-warning map.
  /// Strictly opt-in, default false.
  static const communitySyncConsent = 'consent.communitySync';

  static const fallDetection = 'sos.fallDetection';
  static const autoSuggestSos = 'sos.autoSuggestOnHighRisk';
  static const sosCountdownSeconds = 'sos.countdownSeconds';

  static const lastDeviceId = 'ble.lastDeviceId';
  static const demoMode = 'ble.demoMode';

  static const seededVersion = 'seed.version';
  static const guidelineCorpusVersion = 'seed.guidelineVersion';
  static const storageBudgetBytes = 'storage.budgetBytes';
  static const lastSyncAt = 'sync.lastSuccessAt';

  /// Where queued screenings are POSTed. Empty by default: with no server
  /// configured the app is fully usable and simply keeps everything locally.
  static const syncEndpoint = 'sync.endpoint';

  /// The worker's own Gemini credential, entered in Settings.
  ///
  /// Stored here rather than compiled in so it can be replaced or revoked
  /// without shipping a new APK — which matters because Google's short-lived
  /// tokens expire in minutes, and a build-time constant would strand the app
  /// with a dead credential until someone rebuilt it.
  static const geminiApiKey = 'ai.geminiApiKey';

  /// Whether explanations are written for a nurse or for the patient.
  ///
  /// Persisted per device, because it is a property of who holds the phone, not
  /// of any one screening.
  static const audience = 'ai.audience';

  /// The signed-in account, or absent when signed out. Login state lives in
  /// the settings table rather than the accounts table because it is a
  /// per-device session pointer, not a property of the account itself.
  static const authActiveAccountId = 'auth.activeAccountId';

  /// Last environmental reading as JSON (see `EnvironmentReading`). Cached so
  /// the environment card survives exactly as long as the advice is worth —
  /// a heat-wave warning from this morning is still true tonight, even with
  /// the network gone.
  static const envLastReading = 'env.lastReading';

  /// Reference cuff blood pressure calibration for PTT-based trend estimation.
  static const bpCalibrationSystolic = 'bp.calibrationSystolic';
  static const bpCalibrationDiastolic = 'bp.calibrationDiastolic';
  static const bpCalibrationAt = 'bp.calibrationAt';
}

/// The full settings snapshot. Read once into memory at startup — these are all
/// tiny scalars, and reading them as a batch avoids a query per widget build.
@immutable
class AppSettingsSnapshot {
  final Locale locale;
  final ThemeMode themeMode;
  final bool highContrast;
  final bool reducedMotion;

  final String workerName;
  final String workerId;
  final String facility;

  final bool locationConsent;
  final bool aiConsent;
  final bool syncConsent;

  /// Whether anonymized aggregate indicators may be contributed to the
  /// community early-warning map. Strictly opt-in, defaults to false.
  final bool communitySyncConsent;

  /// Local weather / AQI lookups. See [SettingKeys.envLocationConsent].
  final bool envLocationConsent;

  final bool fallDetection;
  final bool autoSuggestSos;
  final int sosCountdownSeconds;

  final String? lastDeviceId;
  final bool demoMode;

  final int storageBudgetBytes;
  final DateTime? lastSyncAt;

  /// Empty when the worker has not entered one. Never logged, never synced, and
  /// deliberately not part of any export.
  final String geminiApiKey;

  /// Who explanations are written for. Nurse by default, so an existing install
  /// keeps the wording it had.
  final Audience audience;
  final VulnerabilityPersona vulnerabilityPersona;

  /// Reference cuff calibration for PTT blood pressure estimation
  final int? bpCalibrationSystolic;
  final int? bpCalibrationDiastolic;
  final DateTime? bpCalibrationAt;

  bool get isBpCalibrated =>
      bpCalibrationSystolic != null &&
      bpCalibrationDiastolic != null &&
      bpCalibrationSystolic! > 0 &&
      bpCalibrationDiastolic! > 0;

  const AppSettingsSnapshot({
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.system,
    this.highContrast = false,
    this.reducedMotion = false,
    this.workerName = '',
    this.workerId = '',
    this.facility = '',
    this.locationConsent = false,
    this.aiConsent = false,
    this.syncConsent = true,
    this.communitySyncConsent = false,
    this.envLocationConsent = false,
    this.fallDetection = false,
    this.autoSuggestSos = true,
    this.sosCountdownSeconds = 10,
    this.lastDeviceId,
    this.demoMode = true,
    this.storageBudgetBytes = 200 * 1024 * 1024,
    this.lastSyncAt,
    this.geminiApiKey = '',
    this.audience = Audience.nurse,
    this.vulnerabilityPersona = VulnerabilityPersona.generalCommunity,
    this.bpCalibrationSystolic,
    this.bpCalibrationDiastolic,
    this.bpCalibrationAt,
  });

  factory AppSettingsSnapshot.fromMap(Map<String, String> m) {
    bool flag(String key, bool fallback) => switch (m[key]) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };

    return AppSettingsSnapshot(
      locale: Locale(m[SettingKeys.locale] ?? 'en'),
      themeMode: _themeModeFrom(m[SettingKeys.themeMode]),
      highContrast: flag(SettingKeys.highContrast, false),
      reducedMotion: flag(SettingKeys.reducedMotion, false),
      workerName: m[SettingKeys.workerName] ?? '',
      workerId: m[SettingKeys.workerId] ?? '',
      facility: m[SettingKeys.facility] ?? '',
      locationConsent: flag(SettingKeys.locationConsent, false),
      aiConsent: flag(SettingKeys.aiConsent, false),
      syncConsent: flag(SettingKeys.syncConsent, true),
      communitySyncConsent: flag(SettingKeys.communitySyncConsent, false),
      envLocationConsent: flag(SettingKeys.envLocationConsent, false),
      fallDetection: flag(SettingKeys.fallDetection, false),
      autoSuggestSos: flag(SettingKeys.autoSuggestSos, true),
      sosCountdownSeconds:
          int.tryParse(m[SettingKeys.sosCountdownSeconds] ?? '') ?? 10,
      lastDeviceId: m[SettingKeys.lastDeviceId],
      demoMode: flag(SettingKeys.demoMode, true),
      storageBudgetBytes:
          int.tryParse(m[SettingKeys.storageBudgetBytes] ?? '') ??
          200 * 1024 * 1024,
      lastSyncAt: DateTime.tryParse(m[SettingKeys.lastSyncAt] ?? ''),
      geminiApiKey: m[SettingKeys.geminiApiKey] ?? '',
      audience: Audience.fromStorage(m[SettingKeys.audience]),
      vulnerabilityPersona: VulnerabilityPersona.fromStorage(
        m[SettingKeys.vulnerabilityPersona],
      ),
      bpCalibrationSystolic: int.tryParse(
        m[SettingKeys.bpCalibrationSystolic] ?? '',
      ),
      bpCalibrationDiastolic: int.tryParse(
        m[SettingKeys.bpCalibrationDiastolic] ?? '',
      ),
      bpCalibrationAt: DateTime.tryParse(m[SettingKeys.bpCalibrationAt] ?? ''),
    );
  }

  static ThemeMode _themeModeFrom(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String themeModeToStorage(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  bool get hasWorkerProfile => workerName.trim().isNotEmpty;

  AppSettingsSnapshot copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? highContrast,
    bool? reducedMotion,
    String? workerName,
    String? workerId,
    String? facility,
    bool? locationConsent,
    bool? aiConsent,
    bool? syncConsent,
    bool? communitySyncConsent,
    bool? envLocationConsent,
    bool? fallDetection,
    bool? autoSuggestSos,
    int? sosCountdownSeconds,
    String? lastDeviceId,
    bool? demoMode,
    int? storageBudgetBytes,
    DateTime? lastSyncAt,
    String? geminiApiKey,
    Audience? audience,
    VulnerabilityPersona? vulnerabilityPersona,
    int? bpCalibrationSystolic,
    int? bpCalibrationDiastolic,
    DateTime? bpCalibrationAt,
  }) => AppSettingsSnapshot(
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    workerName: workerName ?? this.workerName,
    workerId: workerId ?? this.workerId,
    facility: facility ?? this.facility,
    locationConsent: locationConsent ?? this.locationConsent,
    aiConsent: aiConsent ?? this.aiConsent,
    syncConsent: syncConsent ?? this.syncConsent,
    communitySyncConsent: communitySyncConsent ?? this.communitySyncConsent,
    envLocationConsent: envLocationConsent ?? this.envLocationConsent,
    fallDetection: fallDetection ?? this.fallDetection,
    autoSuggestSos: autoSuggestSos ?? this.autoSuggestSos,
    sosCountdownSeconds: sosCountdownSeconds ?? this.sosCountdownSeconds,
    lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    demoMode: demoMode ?? this.demoMode,
    storageBudgetBytes: storageBudgetBytes ?? this.storageBudgetBytes,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    audience: audience ?? this.audience,
    vulnerabilityPersona: vulnerabilityPersona ?? this.vulnerabilityPersona,
    bpCalibrationSystolic: bpCalibrationSystolic ?? this.bpCalibrationSystolic,
    bpCalibrationDiastolic:
        bpCalibrationDiastolic ?? this.bpCalibrationDiastolic,
    bpCalibrationAt: bpCalibrationAt ?? this.bpCalibrationAt,
  );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<AppSettingsSnapshot> load() async =>
      AppSettingsSnapshot.fromMap(await _db.getAllSettings());

  Stream<AppSettingsSnapshot> watch() =>
      _db.watchSettings().map(AppSettingsSnapshot.fromMap);

  Future<void> setString(String key, String value) =>
      _db.setSetting(key, value);

  Future<void> setBool(String key, bool value) =>
      _db.setSetting(key, value ? 'true' : 'false');

  Future<void> setInt(String key, int value) => _db.setSetting(key, '$value');

  Future<String?> getString(String key) => _db.getSetting(key);

  Future<bool> getBool(String key, {bool fallback = false}) async =>
      switch (await _db.getSetting(key)) {
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  Future<void> remove(String key) => _db.deleteSetting(key);

  // Typed conveniences for the settings the UI touches most.

  Future<void> setLocale(Locale locale) =>
      setString(SettingKeys.locale, locale.languageCode);

  Future<void> setThemeMode(ThemeMode mode) => setString(
    SettingKeys.themeMode,
    AppSettingsSnapshot.themeModeToStorage(mode),
  );

  Future<void> setHighContrast(bool on) =>
      setBool(SettingKeys.highContrast, on);

  Future<void> setLocationConsent(bool granted) =>
      setBool(SettingKeys.locationConsent, granted);

  Future<void> setEnvLocationConsent(bool granted) =>
      setBool(SettingKeys.envLocationConsent, granted);

  Future<void> setAiConsent(bool granted) =>
      setBool(SettingKeys.aiConsent, granted);

  Future<void> setCommunitySyncConsent(bool granted) =>
      setBool(SettingKeys.communitySyncConsent, granted);

  Future<void> setGeminiApiKey(String key) =>
      setString(SettingKeys.geminiApiKey, key.trim());

  Future<void> setAudience(Audience audience) =>
      setString(SettingKeys.audience, audience.storageValue);

  Future<void> setVulnerabilityPersona(VulnerabilityPersona persona) =>
      setString(SettingKeys.vulnerabilityPersona, persona.storageValue);

  Future<void> markSynced(DateTime at) =>
      setString(SettingKeys.lastSyncAt, at.toIso8601String());

  Future<void> saveBpCalibration(int systolic, int diastolic) async {
    await setInt(SettingKeys.bpCalibrationSystolic, systolic);
    await setInt(SettingKeys.bpCalibrationDiastolic, diastolic);
    await setString(
      SettingKeys.bpCalibrationAt,
      DateTime.now().toIso8601String(),
    );
  }
}
