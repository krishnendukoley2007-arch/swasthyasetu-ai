import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/repositories/settings_repository.dart';

/// Why a sync attempt could not proceed, or how it went.
enum SyncOutcome {
  /// Uploaded and acknowledged by the server.
  uploaded,

  /// The device has no usable connection right now.
  offline,

  /// No upload endpoint has been configured, so there is nowhere to send to.
  noEndpoint,

  /// Reached the server but it refused or errored.
  rejected,

  /// Nothing was waiting.
  nothingToDo,
}

/// Result of one `syncAll()` run.
class SyncReport {
  final SyncOutcome outcome;
  final int uploaded;
  final int failed;
  final int remaining;
  final String? detail;

  const SyncReport({
    required this.outcome,
    this.uploaded = 0,
    this.failed = 0,
    this.remaining = 0,
    this.detail,
  });

  bool get didUpload => uploaded > 0;

  /// A sentence safe to show a health worker verbatim.
  String get message => switch (outcome) {
        SyncOutcome.uploaded =>
          'Uploaded $uploaded record${uploaded == 1 ? '' : 's'}.'
              '${failed > 0 ? ' $failed could not be sent and will be retried.' : ''}',
        SyncOutcome.nothingToDo => 'Everything is already uploaded.',
        SyncOutcome.offline =>
          'No connection. $remaining record${remaining == 1 ? '' : 's'} '
              'stay safely on this device and will upload automatically later.',
        SyncOutcome.noEndpoint =>
          'No upload server is configured, so records stay on this device. '
              'Nothing has been lost.',
        SyncOutcome.rejected =>
          'The server refused the upload${detail == null ? '' : ' ($detail)'}. '
              'Records are kept on this device and will be retried.',
      };
}

/// Uploads queued screenings when a server is configured and reachable.
///
/// This app is offline-first: sync is an optional convenience, never a
/// precondition. A failed sync must leave every local record intact — the only
/// thing that changes on failure is the attempt counter and the error string, so
/// the worker can see *why* it has not gone up yet.
class SyncService {
  SyncService(this._db, this._settings, {Dio? client})
      : _client = client ?? Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Content-Type': 'application/json'},
          ));

  final AppDatabase _db;
  final SettingsRepository _settings;
  final Dio _client;

  /// Give up on a record after this many tries so a permanently-bad row cannot
  /// block the queue forever. It stays in the DB and is still exportable.
  static const int maxAttempts = 8;

  Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  Future<String?> endpoint() async {
    final raw = (await _settings.getString(SettingKeys.syncEndpoint))?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  /// Attempts to upload everything queued. Never throws.
  Future<SyncReport> syncAll() async {
    final queued = await _db.getPendingSyncItems();
    final actionable =
        queued.where((q) => q.attempts < maxAttempts).toList(growable: false);
    if (actionable.isEmpty) {
      return SyncReport(
        outcome: SyncOutcome.nothingToDo,
        remaining: queued.length,
      );
    }

    final target = await endpoint();
    if (target == null) {
      return SyncReport(
        outcome: SyncOutcome.noEndpoint,
        remaining: actionable.length,
      );
    }

    if (!await hasConnection()) {
      return SyncReport(
        outcome: SyncOutcome.offline,
        remaining: actionable.length,
      );
    }

    var uploaded = 0;
    var failed = 0;
    String? lastDetail;

    for (final item in actionable) {
      final result = await _uploadOne(item, target);
      if (result == null) {
        uploaded++;
      } else {
        failed++;
        lastDetail = result;
      }
    }

    if (uploaded > 0) await _settings.markSynced(DateTime.now());

    return SyncReport(
      outcome: uploaded > 0 ? SyncOutcome.uploaded : SyncOutcome.rejected,
      uploaded: uploaded,
      failed: failed,
      remaining: failed,
      detail: lastDetail,
    );
  }

  /// Retries a single record, ignoring the attempt ceiling — this is an explicit
  /// user action, so their decision beats the backoff heuristic.
  Future<SyncReport> retry(String recordId) async {
    final all = await _db.getAllSyncItems();
    final item = all.where((q) => q.recordId == recordId).firstOrNull;
    if (item == null) {
      return const SyncReport(outcome: SyncOutcome.nothingToDo);
    }

    final target = await endpoint();
    if (target == null) {
      return const SyncReport(outcome: SyncOutcome.noEndpoint, remaining: 1);
    }
    if (!await hasConnection()) {
      return const SyncReport(outcome: SyncOutcome.offline, remaining: 1);
    }

    final error = await _uploadOne(item, target);
    if (error == null) {
      await _settings.markSynced(DateTime.now());
      return const SyncReport(outcome: SyncOutcome.uploaded, uploaded: 1);
    }
    return SyncReport(
      outcome: SyncOutcome.rejected,
      failed: 1,
      remaining: 1,
      detail: error,
    );
  }

  /// Returns null on success, or a short error string on failure.
  Future<String?> _uploadOne(SyncQueueRow item, String target) async {
    await _db.updateSyncItem(
      item.id,
      status: 'SYNCING',
      lastAttemptAt: DateTime.now(),
    );

    try {
      final payload = await _payloadFor(item);
      if (payload == null) {
        // The record vanished — drop the orphaned queue entry instead of
        // retrying it forever.
        await _db.removeSyncItem(item.id);
        return null;
      }

      final response = await _client.post<dynamic>(target, data: payload);
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'HTTP $code',
        );
      }

      await _db.setScreeningSyncStatus(item.recordId, 'SYNCED');
      await _db.removeSyncItem(item.id);
      return null;
    } catch (e) {
      final detail = _describe(e);
      await _db.updateSyncItem(
        item.id,
        status: 'FAILED',
        attempts: item.attempts + 1,
        lastError: detail,
        lastAttemptAt: DateTime.now(),
      );
      await _db.setScreeningSyncStatus(item.recordId, 'FAILED');
      return detail;
    }
  }

  Future<Map<String, dynamic>?> _payloadFor(SyncQueueRow item) async {
    if (item.entity != 'screenings') return null;
    final row = await _db.getScreening(item.recordId);
    if (row == null) return null;

    // Deliberately excludes the patient's name, phone and free-text notes.
    // The server receives the clinical record keyed by an opaque id; identity
    // stays on the device that collected it.
    return <String, dynamic>{
      'screening_id': row.id,
      'patient_ref': row.patientId,
      'device_id': row.deviceId,
      'recorded_at': row.timestamp.toUtc().toIso8601String(),
      'heart_rate': row.heartRate,
      'spo2': row.spo2,
      'temperature_c': row.temperature,
      'ecg_rhythm': row.ecgRhythm,
      'ecg_quality': row.ecgQualityScore,
      'bp_systolic_est': row.estimatedSystolic,
      'bp_diastolic_est': row.estimatedDiastolic,
      'bp_confidence': row.bpConfidence,
      'symptoms': row.symptoms,
      'risk_band': row.riskLevel,
      'risk_score': row.riskScore,
      'triggered_rules': row.triggeredRules,
      'escalation': row.escalationLevel,
      'app_schema': 1,
    };
  }

  static String _describe(Object error) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'timed out',
        DioExceptionType.connectionError => 'could not reach server',
        DioExceptionType.badResponse =>
          'server said ${error.response?.statusCode ?? '?'}',
        _ => error.message ?? 'network error',
      };
    }
    if (error is SocketException) return 'could not reach server';
    return error.toString().split('\n').first;
  }
}
