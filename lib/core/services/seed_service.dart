import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show rootBundle;
import 'package:swasthyasetu_ai/core/services/waveform_store.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/patient_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/screening_repository.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

/// What a seed pass actually did, so the caller can log it rather than guess.
class SeedReport {
  final int guidelineChunks;
  final int patients;
  final int screenings;
  final int reconciledWaveforms;
  final bool seededDemoData;

  const SeedReport({
    this.guidelineChunks = 0,
    this.patients = 0,
    this.screenings = 0,
    this.reconciledWaveforms = 0,
    this.seededDemoData = false,
  });

  @override
  String toString() => 'SeedReport(guidelines: $guidelineChunks, '
      'patients: $patients, screenings: $screenings, '
      'reconciled: $reconciledWaveforms, demo: $seededDemoData)';
}

/// First-run preparation: guideline corpus, sensible defaults, and — only on a
/// genuinely empty database — a small demo roster.
///
/// Two rules govern everything here:
///
/// 1. **Idempotent.** Each step is version-gated, so a second launch is a
///    no-op and an upgrade re-seeds only what changed. Ids are stable, so even
///    a forced re-run overwrites rather than duplicates.
/// 2. **Never invent triage.** Demo screenings carry vitals and symptoms only;
///    the band and score come from [RiskEngine] exactly as they would for a
///    real reading. A hardcoded `riskLevel` would let demo data disagree with
///    the engine, which is precisely the bug this replaces.
class SeedService {
  SeedService({
    required AppDatabase db,
    required PatientRepository patients,
    required ScreeningRepository screenings,
    required DeviceRepository devices,
    required EmergencyRepository emergency,
    required SettingsRepository settings,
    required WaveformStore waveforms,
  })  : _db = db,
        _patients = patients,
        _screenings = screenings,
        _devices = devices,
        _emergency = emergency,
        _settings = settings,
        _waveforms = waveforms;

  final AppDatabase _db;
  final PatientRepository _patients;
  final ScreeningRepository _screenings;
  final DeviceRepository _devices;
  final EmergencyRepository _emergency;
  final SettingsRepository _settings;
  final WaveformStore _waveforms;

  /// Bump to re-seed the demo roster on upgrade.
  static const int demoDataVersion = 1;

  /// Must match `version` in `assets/guidelines/corpus.json`.
  static const int corpusVersion = 1;

  static const String corpusAsset = 'assets/guidelines/corpus.json';

  static const String demoDeviceId = 'DEMO_DEVICE_001';

  /// Runs every launch. Cheap when there is nothing to do.
  Future<SeedReport> run() async {
    final chunks = await _seedGuidelines();
    await _seedDefaults();
    final demo = await _seedDemoData();

    // Repairs blobs orphaned by a kill mid-save, and rows whose file vanished.
    final reconciled = await _waveforms.reconcile();

    return SeedReport(
      guidelineChunks: chunks,
      patients: demo.patients,
      screenings: demo.screenings,
      reconciledWaveforms: reconciled,
      seededDemoData: demo.seededDemoData,
    );
  }

  // ───────────────────────────── Guidelines ─────────────────────────────

  /// Loads the bundled corpus into `guideline_cache` so offline explanation has
  /// something to retrieve from. Returns the number of chunks written.
  Future<int> _seedGuidelines() async {
    final storedVersion =
        int.tryParse(await _settings.getString(SettingKeys.guidelineCorpusVersion) ?? '');
    final present = await _db.countGuidelineChunks();

    // Re-seed when the bundled corpus is newer, or when the table was wiped by
    // "Free up space" — the cache is a rebuildable derivative of an asset.
    if (storedVersion == corpusVersion && present > 0) return 0;

    final String raw;
    try {
      raw = await rootBundle.loadString(corpusAsset);
    } catch (_) {
      // A missing asset must not stop the app booting; offline explanation just
      // falls back to templated text with no citation.
      return 0;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return 0;
    final chunks = decoded['chunks'];
    if (chunks is! List) return 0;

    final companions = <GuidelineCacheCompanion>[];
    for (final entry in chunks) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['id'] as String?;
      final body = entry['body'] as String?;
      if (id == null || body == null || id.isEmpty || body.isEmpty) continue;

      final title = entry['title'] as String? ?? '';
      final tags = (entry['ruleTags'] as List?)?.whereType<String>().toList() ??
          const <String>[];

      companions.add(
        GuidelineCacheCompanion.insert(
          chunkId: id,
          source: entry['source'] as String? ?? 'UNKNOWN',
          title: Value(title),
          body: body,
          // Precomputed at seed time so retrieval never re-tokenises the corpus.
          keywords: Value(tokenise('$title $body').join(' ')),
          ruleTags: Value(jsonEncode(tags)),
        ),
      );
    }

    if (companions.isEmpty) return 0;

    await _db.replaceGuidelineCorpus(companions);
    await _settings.setInt(SettingKeys.guidelineCorpusVersion, corpusVersion);
    return companions.length;
  }

  /// Lowercased alphanumeric terms with stopwords and 1-character noise removed.
  ///
  /// Shared with the retriever — the query must be tokenised the same way the
  /// corpus was, or nothing ever matches.
  static List<String> tokenise(String input) {
    final terms = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9°%\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1 && !_stopwords.contains(t));
    return terms.toList(growable: false);
  }

  static const Set<String> _stopwords = {
    'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her',
    'was', 'one', 'our', 'out', 'his', 'has', 'had', 'that', 'this', 'with',
    'from', 'they', 'them', 'then', 'than', 'have', 'been', 'will', 'when',
    'what', 'which', 'their', 'there', 'would', 'could', 'should', 'about',
    'into', 'over', 'under', 'more', 'most', 'some', 'such', 'only', 'other',
    'also', 'because', 'while', 'does', 'each', 'being', 'very',
  };

  // ────────────────────────────── Defaults ──────────────────────────────

  /// Values the app needs on a fresh install. Every write is guarded, so a
  /// worker who deliberately removed the 108 contact does not get it back.
  Future<void> _seedDefaults() async {
    final done = await _settings.getString(_defaultsKey);
    if (done == '$demoDataVersion') return;

    if (await _settings.getString(SettingKeys.sosCountdownSeconds) == null) {
      // Ten seconds: long enough to cancel a false fall trigger, short enough
      // that a real emergency is not delayed.
      await _settings.setInt(SettingKeys.sosCountdownSeconds, 10);
    }

    if (await _settings.getString(SettingKeys.storageBudgetBytes) == null) {
      await _settings.setInt(SettingKeys.storageBudgetBytes, 200 * 1024 * 1024);
    }

    final contacts = await _emergency.getContacts();
    if (contacts.isEmpty) {
      // National numbers, not a person: safe to ship, useful with no signal
      // configuration, and immediately replaceable in Settings.
      await _emergency.saveContact(
        const EmergencyContact(
          id: 'default-108',
          name: 'Ambulance (108)',
          phone: '108',
          relation: 'Emergency service',
          isPrimary: true,
          sortOrder: 0,
        ),
      );
      await _emergency.saveContact(
        const EmergencyContact(
          id: 'default-112',
          name: 'Emergency helpline (112)',
          phone: '112',
          relation: 'Emergency service',
          sortOrder: 1,
        ),
      );
    }

    // The demo transmitter is always present as an explicit, labelled choice —
    // it is never mixed into the real BLE scan results.
    await _devices.remember(
      id: demoDeviceId,
      name: 'Demo transmitter',
      firmwareVersion: '1.0.0-demo',
      isDemo: true,
    );

    await _settings.setString(_defaultsKey, '$demoDataVersion');
  }

  static const String _defaultsKey = 'seed.defaults';

  // ────────────────────────────── Demo data ──────────────────────────────

  /// Seeds a small roster, but only when the database has no patients.
  ///
  /// Refusing to touch a non-empty database is the important part: a field
  /// worker with real records must never find invented patients alongside them.
  Future<SeedReport> _seedDemoData() async {
    final storedVersion =
        int.tryParse(await _settings.getString(SettingKeys.seededVersion) ?? '');
    if (storedVersion == demoDataVersion) return const SeedReport();

    if (await _db.countPatients() > 0) {
      // Real data present. Record the version so we stop asking.
      await _settings.setInt(SettingKeys.seededVersion, demoDataVersion);
      return const SeedReport();
    }

    final now = DateTime.now();
    var screeningCount = 0;

    for (final spec in _demoPatients) {
      final patient = await _patients.create(
        id: spec.id,
        name: spec.name,
        age: spec.age,
        sex: spec.sex,
        location: spec.location,
        vulnerabilityFlags: spec.flags,
        notes: spec.notes,
        isDemo: true,
      );

      for (var i = 0; i < spec.readings.length; i++) {
        final reading = spec.readings[i];
        // Oldest first so `last_screened_at` ends up on the newest reading.
        final at = now.subtract(reading.daysAgo);
        await _saveDemoScreening(
          patient: patient,
          reading: reading,
          at: at,
          index: screeningCount,
        );
        screeningCount++;
      }
    }

    // Most demo records read as already uploaded; the two newest stay pending so
    // the upload queue screen has something honest to show.
    final all = await _db.getAllScreenings(limit: 500);
    for (var i = 0; i < all.length; i++) {
      if (i < 2) continue;
      await _db.setScreeningSyncStatus(all[i].id, 'SYNCED');
      await _db.removeSyncItemsForRecord(all[i].id);
    }

    await _settings.setInt(SettingKeys.seededVersion, demoDataVersion);

    return SeedReport(
      patients: _demoPatients.length,
      screenings: screeningCount,
      seededDemoData: true,
    );
  }

  Future<void> _saveDemoScreening({
    required Patient patient,
    required _Reading reading,
    required DateTime at,
    required int index,
  }) async {
    final sample = HealthSample(
      timestamp: at.millisecondsSinceEpoch,
      heartRateBpm: reading.hr,
      spo2Percent: reading.spo2,
      temperatureC: reading.temp,
      ecgSignalQuality: reading.ecgQuality,
      rPeakDetected: reading.ecgQuality >= 0.5,
      rrIntervalMs: reading.hr > 0 ? (60000 / reading.hr).round() : 0,
      pttMs: reading.pttMs,
      estimatedSystolic: reading.systolic,
      estimatedDiastolic: reading.diastolic,
      bpConfidence: reading.systolic > 0 ? 'LOW' : 'EXPERIMENTAL',
      batteryPercent: 80,
      isDemo: true,
    );

    // The engine decides the band. Nothing here overrides it.
    final assessment = RiskEngine.assessForPatient(
      sample: sample,
      symptoms: reading.symptoms,
      patient: patient,
    );

    final screening = Screening(
      id: 'demo-s${index.toString().padLeft(3, '0')}',
      patientId: patient.id,
      deviceId: demoDeviceId,
      timestamp: at,
      heartRate: reading.hr,
      spo2: reading.spo2,
      temperature: reading.temp,
      ecgRhythm: reading.rhythm,
      ecgQualityScore: reading.ecgQuality,
      rrIntervalMs: sample.rrIntervalMs,
      pttMs: reading.pttMs,
      estimatedSystolic: reading.systolic,
      estimatedDiastolic: reading.diastolic,
      bpConfidence: sample.bpConfidence,
      symptoms: reading.symptoms,
      symptomDuration: reading.symptoms.isEmpty ? null : reading.duration,
      riskLevel: assessment.band.storageValue,
      riskScore: assessment.score,
      triggeredRules: assessment.firedRules.map((r) => r.display).toList(),
      recommendedAction: assessment.recommendedAction,
      escalationLevel: assessment.escalationLevel,
      isDemo: true,
    );

    await _screenings.save(
      screening,
      ecgSamples: _syntheticEcg(hr: reading.hr, seed: index),
      ppgSamples: _syntheticPpg(hr: reading.hr, seed: index),
      ppgSampleRate: 100,
    );
  }

  // ─────────────────────── Synthetic waveforms ───────────────────────

  /// Ten seconds of ECG-shaped int16 at 250 Hz.
  ///
  /// Not a physiological model — enough structure that the waveform viewer,
  /// the gzip round-trip and the retention downsampler all get realistic input.
  static List<int> _syntheticEcg({required int hr, required int seed}) {
    const sampleRate = WaveformStore.defaultSampleRate;
    const seconds = 10;
    final rng = math.Random(seed * 7919 + 13);
    final beatPeriod = sampleRate * 60 / (hr <= 0 ? 72 : hr);
    final out = <int>[];

    for (var i = 0; i < sampleRate * seconds; i++) {
      final phase = (i % beatPeriod) / beatPeriod;
      var v = 0.0;
      // P wave, QRS complex, T wave as three gaussians on a flat baseline.
      v += 90 * _gauss(phase, 0.16, 0.028);
      v -= 140 * _gauss(phase, 0.26, 0.010);
      v += 1000 * _gauss(phase, 0.30, 0.010);
      v -= 220 * _gauss(phase, 0.34, 0.012);
      v += 200 * _gauss(phase, 0.54, 0.055);
      // Baseline wander plus a little sensor noise.
      v += 40 * math.sin(i / sampleRate * 0.4 * 2 * math.pi);
      v += (rng.nextDouble() - 0.5) * 24;
      out.add(v.round().clamp(-32768, 32767));
    }
    return out;
  }

  /// Ten seconds of PPG-shaped int16 at 100 Hz, with the dicrotic notch that
  /// makes the pulse-transit-time estimate look plausible.
  static List<int> _syntheticPpg({required int hr, required int seed}) {
    const sampleRate = 100;
    const seconds = 10;
    final rng = math.Random(seed * 104729 + 7);
    final beatPeriod = sampleRate * 60 / (hr <= 0 ? 72 : hr);
    final out = <int>[];

    for (var i = 0; i < sampleRate * seconds; i++) {
      final phase = (i % beatPeriod) / beatPeriod;
      var v = 0.0;
      v += 900 * _gauss(phase, 0.22, 0.075);
      v += 260 * _gauss(phase, 0.46, 0.085);
      v += 1200; // DC offset, as a real optical sensor reports.
      v += 30 * math.sin(i / sampleRate * 0.25 * 2 * math.pi);
      v += (rng.nextDouble() - 0.5) * 18;
      out.add(v.round().clamp(-32768, 32767));
    }
    return out;
  }

  /// Unit-height gaussian, wrapped so a peak near phase 0 or 1 is continuous.
  static double _gauss(double x, double centre, double width) {
    var d = (x - centre).abs();
    if (d > 0.5) d = 1.0 - d;
    return math.exp(-(d * d) / (2 * width * width));
  }
}

// ──────────────────────────── Demo definitions ────────────────────────────

class _Reading {
  final Duration daysAgo;
  final int hr;
  final int spo2;
  final double temp;
  final String rhythm;
  final double ecgQuality;
  final int pttMs;
  final int systolic;
  final int diastolic;
  final List<String> symptoms;
  final String duration;

  const _Reading({
    required this.daysAgo,
    required this.hr,
    required this.spo2,
    required this.temp,
    this.rhythm = 'SINUS_RHYTHM',
    this.ecgQuality = 0.88,
    this.pttMs = 0,
    this.systolic = 0,
    this.diastolic = 0,
    this.symptoms = const [],
    this.duration = '2 days',
  });
}

class _DemoPatient {
  final String id;
  final String name;
  final int age;
  final String sex;
  final String location;
  final List<String> flags;
  final String? notes;
  final List<_Reading> readings;

  const _DemoPatient({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.location,
    this.flags = const [],
    this.notes,
    required this.readings,
  });
}

/// Six patients covering every band, both threshold-shifting flag, an
/// unscreened arrival, and a poor-quality trace — the states the UI has to
/// render correctly. Vitals only; the band is computed, never asserted.
const List<_DemoPatient> _demoPatients = [
  _DemoPatient(
    id: 'demo-p1',
    name: 'Anita Debnath',
    age: 34,
    sex: 'F',
    location: 'Bishnupur ward 4',
    readings: [
      _Reading(daysAgo: Duration(days: 21), hr: 78, spo2: 98, temp: 36.8),
      _Reading(daysAgo: Duration(days: 9), hr: 74, spo2: 99, temp: 36.6),
      _Reading(
        daysAgo: Duration(days: 2),
        hr: 82,
        spo2: 97,
        temp: 37.0,
        pttMs: 240,
        systolic: 118,
        diastolic: 76,
      ),
    ],
  ),
  _DemoPatient(
    id: 'demo-p2',
    name: 'Rafiqul Islam',
    age: 71,
    sex: 'M',
    location: 'Bishnupur ward 4',
    flags: ['chronic'],
    notes: 'Long-standing hypertension. Takes medication most days.',
    readings: [
      _Reading(
        daysAgo: Duration(days: 18),
        hr: 88,
        spo2: 95,
        temp: 36.9,
        pttMs: 205,
        systolic: 142,
        diastolic: 90,
      ),
      _Reading(
        daysAgo: Duration(days: 6),
        hr: 96,
        spo2: 93,
        temp: 37.4,
        symptoms: ['Cough', 'Shortness of breath'],
        duration: '4 days',
        pttMs: 198,
        systolic: 148,
        diastolic: 92,
      ),
      _Reading(
        daysAgo: Duration(days: 1),
        hr: 104,
        spo2: 91,
        temp: 37.9,
        symptoms: ['Cough', 'Shortness of breath', 'Fatigue'],
        duration: '6 days',
        ecgQuality: 0.72,
        pttMs: 192,
        systolic: 152,
        diastolic: 94,
      ),
    ],
  ),
  _DemoPatient(
    id: 'demo-p3',
    name: 'Sunita Kumari',
    age: 26,
    sex: 'F',
    location: 'Rampur block',
    flags: ['pregnant'],
    notes: 'Second trimester.',
    readings: [
      _Reading(daysAgo: Duration(days: 14), hr: 86, spo2: 98, temp: 36.7),
      _Reading(
        daysAgo: Duration(days: 3),
        hr: 92,
        spo2: 97,
        temp: 37.6,
        symptoms: ['Fever', 'Headache'],
        duration: '1 day',
      ),
    ],
  ),
  _DemoPatient(
    id: 'demo-p4',
    name: 'Mohan Lal Yadav',
    age: 58,
    sex: 'M',
    location: 'Rampur block',
    readings: [
      _Reading(daysAgo: Duration(days: 11), hr: 72, spo2: 98, temp: 36.5),
      _Reading(
        daysAgo: Duration(days: 4),
        hr: 128,
        spo2: 88,
        temp: 38.6,
        rhythm: 'IRREGULAR',
        ecgQuality: 0.66,
        symptoms: ['Chest pain', 'Shortness of breath', 'Dizziness'],
        duration: '5 hours',
      ),
    ],
  ),
  _DemoPatient(
    id: 'demo-p5',
    name: 'Fatima Bibi',
    age: 43,
    sex: 'F',
    location: 'Char Alexander',
    readings: [
      _Reading(
        daysAgo: Duration(days: 7),
        hr: 68,
        spo2: 96,
        temp: 36.4,
        // Deliberately poor trace: exercises the low-quality advisory path.
        rhythm: 'UNKNOWN',
        ecgQuality: 0.31,
      ),
    ],
  ),
  _DemoPatient(
    id: 'demo-p6',
    name: 'Bikash Roy',
    age: 19,
    sex: 'M',
    location: 'Char Alexander',
    // No readings: the patient list must handle "never screened" without a
    // sparkline or a stale timestamp.
    readings: [],
  ),
];
