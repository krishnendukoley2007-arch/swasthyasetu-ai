import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';

/// Result of persisting one waveform.
class WaveformSaveResult {
  final String fileName;
  final int rawBytes;
  final int storedBytes;

  const WaveformSaveResult({
    required this.fileName,
    required this.rawBytes,
    required this.storedBytes,
  });

  double get compressionRatio => rawBytes == 0 ? 0 : storedBytes / rawBytes;
}

/// A decoded waveform plus enough metadata to plot it correctly.
class WaveformData {
  final Int16List samples;
  final int sampleRate;
  final int durationMs;

  /// When true, [samples] is not a uniform time series: it holds
  /// `[min, max, avg]` triplets, one triplet per
  /// [WaveformStore.downsampleWindowMs] of original signal. Plot as an
  /// envelope, not a line.
  final bool isEnvelope;

  const WaveformData({
    required this.samples,
    required this.sampleRate,
    required this.durationMs,
    this.isEnvelope = false,
  });

  int get windowCount => isEnvelope ? samples.length ~/ 3 : samples.length;
}

/// Stores ECG/PPG sample arrays as gzipped little-endian int16 files on disk,
/// outside SQLite. Rationale: a 10 s ECG at 250 Hz is 2,500 samples = 5,000
/// raw bytes; gzip typically lands ~12–18 KB per screening for ECG+PPG
/// together. Keeping these out of the DB row keeps queries fast and lets the
/// retention policy reclaim space without ever rewriting the database.
///
/// Capacity arithmetic behind the 150–200 MB target:
///   ~30 KB/screening (ECG + PPG, gzipped)
///   200 MB / 30 KB  ≈ 6,800 screenings at full resolution
/// Older screenings are downsampled to a min/max/avg envelope (~1/40th the
/// size), so real-world capacity is far higher — see [applyRetentionPolicy].
class WaveformStore {
  WaveformStore(this._db);

  final AppDatabase _db;

  static const int defaultSampleRate = 250;
  static const String directoryName = 'waveforms';

  /// Most recent N screenings per patient keep full-resolution samples.
  static const int fullResolutionRetentionCount = 20;

  /// Envelope window for downsampled (older) waveforms.
  static const int downsampleWindowMs = 5000;

  static const Set<String> supportedTypes = {'ecg', 'ppg'};

  // ─────────────────────────────── Paths ───────────────────────────────

  /// Public on purpose — `StorageManager` needs it to size and clear the dir.
  static Future<Directory> waveformsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, directoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String fileNameFor(String screeningId, String type) =>
      '$screeningId-$type.gz';

  Future<File> _fileFor(String screeningId, String type) async {
    final dir = await waveformsDirectory();
    return File(p.join(dir.path, fileNameFor(screeningId, type)));
  }

  // ────────────────────────────── Write path ──────────────────────────────

  /// Compresses [samples] to disk and upserts the matching metadata row.
  Future<WaveformSaveResult> save({
    required String screeningId,
    required String type,
    required List<int> samples,
    required int durationMs,
    int sampleRate = defaultSampleRate,
    bool isEnvelope = false,
  }) async {
    assert(supportedTypes.contains(type), 'unsupported waveform type: $type');

    final file = await _fileFor(screeningId, type);
    final raw = _encodeInt16(samples);
    final compressed = gzip.encode(raw);
    await file.writeAsBytes(compressed, flush: true);

    await _db.upsertWaveformBlob(
      WaveformBlobsCompanion(
        screeningId: Value(screeningId),
        type: Value(type),
        filePath: Value(fileNameFor(screeningId, type)),
        durationMs: Value(durationMs),
        sampleRate: Value(sampleRate),
        sizeBytes: Value(compressed.length),
        isDownsampled: Value(isEnvelope),
        createdAt: Value(DateTime.now()),
      ),
    );

    return WaveformSaveResult(
      fileName: fileNameFor(screeningId, type),
      rawBytes: raw.length,
      storedBytes: compressed.length,
    );
  }

  // ────────────────────────────── Read path ──────────────────────────────

  Future<WaveformData?> load(String screeningId, String type) async {
    final meta = await _db.getWaveformBlob(screeningId, type);
    final samples = await loadSamples(screeningId, type);
    if (samples == null) return null;

    return WaveformData(
      samples: samples,
      sampleRate: meta?.sampleRate ?? defaultSampleRate,
      durationMs: meta?.durationMs ??
          (samples.length * 1000 ~/ defaultSampleRate),
      isEnvelope: meta?.isDownsampled ?? false,
    );
  }

  /// Raw sample access with no DB round-trip — used by export.
  Future<Int16List?> loadSamples(String screeningId, String type) async {
    final file = await _fileFor(screeningId, type);
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      return _decodeInt16(gzip.decode(bytes));
    } on FormatException {
      // Truncated/corrupt blob — treat as absent rather than crashing a screen.
      return null;
    } on FileSystemException {
      return null;
    }
  }

  // ───────────────────────────── Delete path ─────────────────────────────

  Future<void> delete(String screeningId, String type) async {
    final file = await _fileFor(screeningId, type);
    if (await file.exists()) await file.delete();
  }

  /// Deletes blob files *and* metadata rows for a screening.
  Future<void> deleteAllForScreening(String screeningId) async {
    for (final type in supportedTypes) {
      await delete(screeningId, type);
    }
    await _db.deleteWaveformBlobsForScreening(screeningId);
  }

  /// Nukes the whole waveform directory and every metadata row.
  Future<void> deleteEverything() async {
    final dir = await waveformsDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    for (final blob in await _db.getAllWaveformBlobs()) {
      await _db.deleteWaveformBlobsForScreening(blob.screeningId);
    }
  }

  /// Removes blob files that have no metadata row, and metadata rows whose file
  /// is gone. Both directions can happen after a crash mid-write.
  Future<int> reconcile() async {
    var reclaimed = 0;
    final dir = await waveformsDirectory();
    final blobs = await _db.getAllWaveformBlobs();
    final known = blobs.map((b) => b.filePath).toSet();

    await for (final entity in dir.list()) {
      if (entity is File && !known.contains(p.basename(entity.path))) {
        reclaimed += (await entity.stat()).size;
        await entity.delete();
      }
    }

    for (final blob in blobs) {
      final f = File(p.join(dir.path, blob.filePath));
      if (!await f.exists()) {
        await _db.deleteWaveformBlobsForScreening(blob.screeningId);
      }
    }
    return reclaimed;
  }

  // ─────────────────────────── Retention policy ───────────────────────────

  /// Keeps full-resolution samples for the most recent
  /// [keepFullResolution] screenings of [patientId] and collapses everything
  /// older to a min/max/avg envelope. Returns bytes reclaimed.
  ///
  /// Idempotent: already-downsampled blobs are skipped.
  Future<int> applyRetentionPolicy({
    required String patientId,
    int keepFullResolution = fullResolutionRetentionCount,
  }) async {
    final screenings = await _db.getScreeningsForPatient(patientId);
    if (screenings.length <= keepFullResolution) return 0;

    final older = screenings.skip(keepFullResolution);
    var reclaimed = 0;

    for (final screening in older) {
      for (final type in supportedTypes) {
        final meta = await _db.getWaveformBlob(screening.id, type);
        if (meta == null || meta.isDownsampled) continue;

        final samples = await loadSamples(screening.id, type);
        if (samples == null) continue;

        final before = meta.sizeBytes;
        final envelope = downsampleToEnvelope(
          samples,
          sampleRate: meta.sampleRate,
          windowMs: downsampleWindowMs,
        );

        final result = await save(
          screeningId: screening.id,
          type: type,
          samples: envelope,
          durationMs: meta.durationMs,
          sampleRate: meta.sampleRate,
          isEnvelope: true,
        );
        reclaimed += (before - result.storedBytes).clamp(0, before);
      }
    }
    return reclaimed;
  }

  /// Runs [applyRetentionPolicy] for every patient. Returns bytes reclaimed.
  Future<int> applyRetentionPolicyForAllPatients({
    int keepFullResolution = fullResolutionRetentionCount,
  }) async {
    var reclaimed = 0;
    for (final patient in await _db.getAllPatients()) {
      reclaimed += await applyRetentionPolicy(
        patientId: patient.id,
        keepFullResolution: keepFullResolution,
      );
    }
    return reclaimed;
  }

  // ───────────────────────────── Accounting ─────────────────────────────

  /// Sums actual file sizes on disk (not the cached `sizeBytes` column) so
  /// Settings can't drift out of sync with reality.
  Future<int> totalBytesOnDisk() async {
    final dir = await waveformsDirectory();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += (await entity.stat()).size;
    }
    return total;
  }

  Future<int> bytesForScreenings(Iterable<String> screeningIds) async {
    final dir = await waveformsDirectory();
    var total = 0;
    for (final id in screeningIds) {
      for (final type in supportedTypes) {
        final f = File(p.join(dir.path, fileNameFor(id, type)));
        if (await f.exists()) total += (await f.stat()).size;
      }
    }
    return total;
  }

  Future<int> fileCount() async {
    final dir = await waveformsDirectory();
    if (!await dir.exists()) return 0;
    return dir.list().where((e) => e is File).length;
  }

  // ────────────────────────────── Codecs ──────────────────────────────

  static Uint8List _encodeInt16(List<int> samples) {
    final data = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      // Clamp rather than let setInt16 throw on out-of-range ADC glitches.
      data.setInt16(i * 2, samples[i].clamp(-32768, 32767), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static Int16List _decodeInt16(List<int> bytes) {
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final count = data.lengthInBytes ~/ 2;
    final out = Int16List(count);
    for (var i = 0; i < count; i++) {
      out[i] = data.getInt16(i * 2, Endian.little);
    }
    return out;
  }

  /// Collapses a uniform series into `[min, max, avg]` triplets, one per
  /// [windowMs] of signal. Exposed for unit testing.
  static Int16List downsampleToEnvelope(
    List<int> samples, {
    required int sampleRate,
    int windowMs = downsampleWindowMs,
  }) {
    if (samples.isEmpty) return Int16List(0);
    final perWindow = (sampleRate * windowMs / 1000).round().clamp(1, 1 << 24);

    final out = <int>[];
    for (var start = 0; start < samples.length; start += perWindow) {
      final end = (start + perWindow).clamp(0, samples.length);
      var min = samples[start];
      var max = samples[start];
      var sum = 0;
      for (var i = start; i < end; i++) {
        final v = samples[i];
        if (v < min) min = v;
        if (v > max) max = v;
        sum += v;
      }
      out
        ..add(min)
        ..add(max)
        ..add((sum / (end - start)).round());
    }
    return Int16List.fromList(out);
  }
}
