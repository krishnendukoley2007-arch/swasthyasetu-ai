import 'package:drift/drift.dart' show Value;
import 'package:swasthyasetu_ai/data/database/app_database.dart';
import 'package:swasthyasetu_ai/data/mappers/row_mappers.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// How stale a cuffless-BP calibration is allowed to get before the UI stops
/// presenting the estimate as usable. Two weeks is the figure in the build
/// report; past that the estimate is shown but explicitly flagged.
const Duration bpCalibrationValidity = Duration(days: 14);

enum CalibrationState { never, valid, stale }

class BpCalibration {
  final DateTime? date;
  final int? systolic;
  final int? diastolic;

  const BpCalibration({this.date, this.systolic, this.diastolic});

  CalibrationState get state {
    if (date == null || systolic == null || diastolic == null) {
      return CalibrationState.never;
    }
    return DateTime.now().difference(date!) > bpCalibrationValidity
        ? CalibrationState.stale
        : CalibrationState.valid;
  }

  String get label => switch (state) {
        CalibrationState.never => 'Not calibrated',
        CalibrationState.valid => 'Calibrated',
        CalibrationState.stale => 'Calibration expired',
      };

  int? get daysSince =>
      date == null ? null : DateTime.now().difference(date!).inDays;
}

class DeviceRepository {
  DeviceRepository(this._db);

  final AppDatabase _db;

  /// Firmware releases this app build knows how to parse. Anything outside the
  /// range still connects — it just gets a compatibility warning, because
  /// refusing to work in the field is worse than degrading.
  static const int minSupportedFirmwareMajor = 1;
  static const int maxSupportedFirmwareMajor = 1;

  Future<List<Device>> getAll() async =>
      (await _db.getAllDevices()).map((r) => r.toModel()).toList();

  Stream<List<Device>> watchAll() =>
      _db.watchAllDevices().map((rows) => rows.map((r) => r.toModel()).toList());

  Future<Device?> getById(String id) async =>
      (await _db.getDeviceRow(id))?.toModel();

  Future<void> save(Device device) => _db.upsertDevice(device.toCompanion());

  Future<void> remember({
    required String id,
    required String name,
    String macAddress = '',
    String firmwareVersion = 'UNKNOWN',
    bool isDemo = false,
  }) async {
    final existing = await _db.getDeviceRow(id);
    await _db.upsertDevice(
      DevicesCompanion.insert(
        id: id,
        name: name,
        macAddress: Value(macAddress),
        firmwareVersion: Value(firmwareVersion),
        isDemo: Value(isDemo),
        // Preserve anything the device already learned about itself.
        batteryPercent: Value(existing?.batteryPercent ?? 0),
        lastConnectedAt: Value(existing?.lastConnectedAt),
        calibrationDate: Value(existing?.calibrationDate),
        calibrationSystolic: Value(existing?.calibrationSystolic),
        calibrationDiastolic: Value(existing?.calibrationDiastolic),
      ),
    );
  }

  Future<void> markConnected(
    String id, {
    int? battery,
    String? firmware,
  }) =>
      _db.markDeviceConnected(id, battery: battery, firmware: firmware);

  Future<void> markAllDisconnected() => _db.markAllDevicesDisconnected();

  Future<void> forget(String id) => _db.deleteDeviceRow(id);

  // ───────────────────────────── Calibration ─────────────────────────────

  Future<BpCalibration> calibrationFor(String deviceId) async {
    final row = await _db.getDeviceRow(deviceId);
    if (row == null) return const BpCalibration();
    return BpCalibration(
      date: row.calibrationDate,
      systolic: row.calibrationSystolic,
      diastolic: row.calibrationDiastolic,
    );
  }

  Future<void> calibrate(
    String deviceId, {
    required int systolic,
    required int diastolic,
    DateTime? at,
  }) =>
      _db.setDeviceCalibration(
        deviceId,
        date: at ?? DateTime.now(),
        systolic: systolic,
        diastolic: diastolic,
      );

  /// Most recent calibration across all paired devices — what the Settings
  /// screen shows when no device is currently connected.
  Future<BpCalibration> latestCalibration() async {
    final rows = await _db.getAllDevices();
    final calibrated =
        rows.where((r) => r.calibrationDate != null).toList()
          ..sort((a, b) => b.calibrationDate!.compareTo(a.calibrationDate!));
    if (calibrated.isEmpty) return const BpCalibration();
    final r = calibrated.first;
    return BpCalibration(
      date: r.calibrationDate,
      systolic: r.calibrationSystolic,
      diastolic: r.calibrationDiastolic,
    );
  }

  // ────────────────────────── Firmware compatibility ──────────────────────────

  /// Parses `1.4.2`, `v1.4.2`, `SSAI-1.4` and friends. Returns null when the
  /// string carries no usable major version (including the `UNKNOWN` default).
  static int? firmwareMajor(String version) {
    final match = RegExp(r'(\d+)').firstMatch(version);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static FirmwareCompatibility checkFirmware(String version) {
    final major = firmwareMajor(version);
    if (major == null) return FirmwareCompatibility.unknown;
    if (major < minSupportedFirmwareMajor) return FirmwareCompatibility.tooOld;
    if (major > maxSupportedFirmwareMajor) return FirmwareCompatibility.tooNew;
    return FirmwareCompatibility.supported;
  }
}

enum FirmwareCompatibility {
  supported,
  tooOld,
  tooNew,
  unknown;

  bool get needsWarning => this != FirmwareCompatibility.supported;

  String get label => switch (this) {
        FirmwareCompatibility.supported => 'Compatible',
        FirmwareCompatibility.tooOld => 'Firmware out of date',
        FirmwareCompatibility.tooNew => 'App out of date',
        FirmwareCompatibility.unknown => 'Version unknown',
      };

  String get detail => switch (this) {
        FirmwareCompatibility.supported =>
          'This device reports a firmware version this app build supports.',
        FirmwareCompatibility.tooOld =>
          'This device runs firmware older than this app expects. Readings may '
              'be missing fields. Update the device firmware when possible.',
        FirmwareCompatibility.tooNew =>
          'This device runs newer firmware than this app build knows about. '
              'Some readings may not be shown. Update the app when possible.',
        FirmwareCompatibility.unknown =>
          'The device did not report a firmware version. Screening still works, '
              'but compatibility cannot be confirmed.',
      };
}
