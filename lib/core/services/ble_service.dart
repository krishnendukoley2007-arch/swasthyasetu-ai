import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:swasthyasetu_ai/core/constants/app_constants.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';

/// Where the link to the sensor board currently is.
///
/// One enum for the whole layer, rather than a handful of booleans, because the
/// states are genuinely exclusive and the UI has to tell them apart: "searching"
/// and "reconnecting" look identical as a spinner but mean opposite things to a
/// worker holding a patient's finger on a sensor.
enum BleLinkStatus {
  /// No Bluetooth radio, or the platform has no BLE support at all.
  unsupported,

  /// Radio present, switched off.
  adapterOff,

  /// The OS refused the scan/connect permission.
  permissionDenied,

  /// Radio ready, nothing happening.
  idle,

  scanning,
  connecting,

  /// Connected at the GATT level; enumerating services.
  discovering,

  /// Services found; reading firmware and subscribing to notifications.
  handshaking,

  /// Frames are arriving.
  streaming,

  /// The link dropped and was not asked to. Retrying on a backoff.
  reconnecting,

  /// Gave up, or failed in a way retrying will not fix.
  failed,
}

/// A device seen in a scan.
///
/// Kept separate from the persisted [Device] model: a scan result is a radio
/// observation with an RSSI and no history, and conflating the two is how a
/// device the worker has never paired ends up rendered as though it were theirs.
class BleCandidate {
  final String id;
  final String name;
  final int rssi;

  /// Advertises the SwasthyaSetu service UUID, or carries the expected name
  /// prefix. False for the headphones and smart watches that will also show up.
  final bool isSensorBoard;

  const BleCandidate({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isSensorBoard,
  });

  /// Four coarse buckets. A precise dBm figure invites a worker to optimise a
  /// number that does not matter; what matters is "close enough to be reliable".
  int get signalBars {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -85) return 2;
    return 1;
  }

  String get displayName => name.trim().isEmpty ? 'Unnamed device' : name.trim();
}

/// Everything the UI needs to describe the link in one immutable object.
class BleLinkState {
  final BleLinkStatus status;
  final String? deviceId;
  final String? deviceName;

  /// As reported by the device-info characteristic. Null until the handshake
  /// reaches it, or if the board does not report one.
  final String? firmwareVersion;
  final FirmwareCompatibility? compatibility;

  /// Which retry this is, 1-based. Zero when not reconnecting.
  final int attempt;

  /// How long until the next retry, for a countdown the worker can watch
  /// instead of an unexplained pause.
  final Duration? retryIn;

  /// Human-readable failure detail. Never a raw exception string.
  final String? message;

  final int? batteryPercent;
  final DateTime? lastFrameAt;

  /// Sensor-contact bits from the most recent frame. A reading with the
  /// electrodes off the chest is not a rhythm, and the UI has to say so.
  final bool leadOff;
  final bool fingerOff;

  /// Count of ECG frames the radio dropped this session. Surfaced rather than
  /// hidden: a trace assembled across gaps has step discontinuities that look
  /// like ectopic beats.
  final int droppedEcgFrames;

  /// Whether the board actually offered the ECG streaming characteristic during
  /// discovery.
  ///
  /// This is the one honest statement the app can make about the board's
  /// hardware: it cannot see an AD8232 on a bus, but it can see whether the
  /// firmware exposes a channel for it. Firmware without it still measures pulse
  /// and temperature, so this is reported, not treated as a failure.
  final bool hasEcgChannel;

  const BleLinkState({
    this.status = BleLinkStatus.idle,
    this.deviceId,
    this.deviceName,
    this.firmwareVersion,
    this.compatibility,
    this.attempt = 0,
    this.retryIn,
    this.message,
    this.batteryPercent,
    this.lastFrameAt,
    this.leadOff = false,
    this.fingerOff = false,
    this.droppedEcgFrames = 0,
    this.hasEcgChannel = false,
  });

  BleLinkState copyWith({
    BleLinkStatus? status,
    String? deviceId,
    String? deviceName,
    String? firmwareVersion,
    FirmwareCompatibility? compatibility,
    int? attempt,
    Duration? retryIn,
    String? message,
    int? batteryPercent,
    DateTime? lastFrameAt,
    bool? leadOff,
    bool? fingerOff,
    int? droppedEcgFrames,
    bool? hasEcgChannel,
    bool clearRetry = false,
    bool clearMessage = false,
  }) =>
      BleLinkState(
        status: status ?? this.status,
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        compatibility: compatibility ?? this.compatibility,
        attempt: attempt ?? this.attempt,
        retryIn: clearRetry ? null : (retryIn ?? this.retryIn),
        message: clearMessage ? null : (message ?? this.message),
        batteryPercent: batteryPercent ?? this.batteryPercent,
        lastFrameAt: lastFrameAt ?? this.lastFrameAt,
        leadOff: leadOff ?? this.leadOff,
        fingerOff: fingerOff ?? this.fingerOff,
        droppedEcgFrames: droppedEcgFrames ?? this.droppedEcgFrames,
        hasEcgChannel: hasEcgChannel ?? this.hasEcgChannel,
      );

  /// Frames are arriving right now.
  bool get isLive => status == BleLinkStatus.streaming;

  /// Something is in flight; the UI should show progress, not an action.
  bool get isBusy =>
      status == BleLinkStatus.scanning ||
      status == BleLinkStatus.connecting ||
      status == BleLinkStatus.discovering ||
      status == BleLinkStatus.handshaking ||
      status == BleLinkStatus.reconnecting;

  /// The link is down but expected back. A screening in progress should pause,
  /// not abort — captured waveform data is still held.
  bool get isInterrupted => status == BleLinkStatus.reconnecting;

  /// Whether the radio can be used at all. Distinct from "not connected".
  bool get isRadioUsable =>
      status != BleLinkStatus.unsupported &&
      status != BleLinkStatus.adapterOff &&
      status != BleLinkStatus.permissionDenied;

  bool get hasFirmwareWarning => compatibility?.needsWarning ?? false;

  String get label => switch (status) {
        BleLinkStatus.unsupported => 'Bluetooth not available',
        BleLinkStatus.adapterOff => 'Bluetooth is off',
        BleLinkStatus.permissionDenied => 'Permission needed',
        BleLinkStatus.idle => 'Not connected',
        BleLinkStatus.scanning => 'Searching for devices',
        BleLinkStatus.connecting => 'Connecting',
        BleLinkStatus.discovering => 'Reading device services',
        BleLinkStatus.handshaking => 'Starting sensors',
        BleLinkStatus.streaming => 'Connected',
        BleLinkStatus.reconnecting => 'Reconnecting',
        BleLinkStatus.failed => 'Connection failed',
      };

  /// The sentence under the label. Written for someone holding a sensor, not for
  /// a developer reading a log.
  String get detail {
    if (message != null) return message!;
    return switch (status) {
      BleLinkStatus.unsupported =>
        'This phone has no Bluetooth Low Energy radio, so a sensor board cannot '
            'be used. Demo mode still works.',
      BleLinkStatus.adapterOff =>
        'Turn Bluetooth on to search for the sensor board.',
      BleLinkStatus.permissionDenied =>
        'Android needs the nearby-devices permission to find the sensor board. '
            'Grant it in app settings.',
      BleLinkStatus.idle => 'Choose a device to begin a screening.',
      BleLinkStatus.scanning => 'Hold the board within a metre of the phone.',
      BleLinkStatus.connecting => 'Pairing with $_deviceLabel.',
      BleLinkStatus.discovering => 'Checking which sensors this board has.',
      BleLinkStatus.handshaking => 'Asking the board to start measuring.',
      BleLinkStatus.streaming => 'Readings are arriving from $_deviceLabel.',
      BleLinkStatus.reconnecting => retryIn == null
          ? 'The link dropped. Trying again — captured readings are kept.'
          : 'The link dropped. Next try in ${retryIn!.inSeconds}s '
              '(attempt $attempt of ${BleBackoff.maxAttempts}). '
              'Captured readings are kept.',
      BleLinkStatus.failed =>
        'Could not reach the board after ${BleBackoff.maxAttempts} tries. '
            'Check that it is switched on and charged.',
    };
  }

  String get _deviceLabel => deviceName ?? 'the sensor board';
}

/// The live link to the SwasthyaSetu sensor board.
///
/// Three things make this more than a wrapper around `flutter_blue_plus`:
///
/// 1. **It never throws at the caller.** Every plugin entry point is guarded, and
///    a platform that has no BLE at all resolves to [BleLinkStatus.unsupported]
///    rather than an exception. Widget tests render the device screens with no
///    radio and no MethodChannel behind them, and a screening must not die
///    because a phone's Bluetooth stack misbehaved.
///
/// 2. **It reconnects on its own.** A board that slips out of range mid-screening
///    comes back without the worker touching anything, on the [BleBackoff]
///    schedule, and the state stream says exactly where in that schedule it is.
///
/// 3. **It holds the capture.** Waveform samples accumulate in the service, not
///    in a widget, so a drop and reconnect — or a rebuild — does not lose the
///    trace already recorded. This is the difference between "the link
///    hiccuped" and "do the screening again".
///
/// Demo mode is deliberately *not* in here. A simulated reading and a measured
/// one must not share a code path where a bug could swap them; the demo
/// generator lives in the screening UI and is labelled there.
class BleService {
  BleService();

  final _stateController = StreamController<BleLinkState>.broadcast();
  final _telemetryController = StreamController<TelemetryFrame>.broadcast();
  final _ecgController = StreamController<EcgFrame>.broadcast();
  final _candidatesController =
      StreamController<List<BleCandidate>>.broadcast();

  BleLinkState _state = const BleLinkState();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _vitalsChar;
  BluetoothCharacteristic? _ecgChar;
  BluetoothCharacteristic? _controlChar;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _vitalsSub;
  StreamSubscription<List<int>>? _ecgSub;

  Timer? _retryTimer;
  Timer? _retryTicker;

  /// True between an explicit [connect] and an explicit [disconnect]. This is
  /// what separates "the worker put it away" from "the link failed": only the
  /// second one triggers a reconnect.
  bool _wantConnection = false;

  bool _disposed = false;

  // ─────────────────────────────── Capture ───────────────────────────────

  final List<int> _capturedEcg = [];
  int? _lastEcgSequence;
  bool _capturing = false;

  BleLinkState get state => _state;
  Stream<BleLinkState> get states => _stateController.stream;
  Stream<TelemetryFrame> get telemetry => _telemetryController.stream;
  Stream<EcgFrame> get ecg => _ecgController.stream;
  Stream<List<BleCandidate>> get candidates => _candidatesController.stream;

  /// Every ECG sample captured since [beginCapture], across any number of
  /// dropped and re-established links.
  List<int> get capturedEcg => List.unmodifiable(_capturedEcg);

  bool get isCapturing => _capturing;

  /// Start accumulating waveform samples. Called when a screening begins.
  void beginCapture() {
    _capturedEcg.clear();
    _lastEcgSequence = null;
    _capturing = true;
    _emit(_state.copyWith(droppedEcgFrames: 0));
  }

  /// Stop accumulating and hand back what was captured. The buffer is cleared
  /// only here, never on a disconnect — that is the whole point.
  List<int> endCapture() {
    _capturing = false;
    final captured = List<int>.from(_capturedEcg);
    _capturedEcg.clear();
    _lastEcgSequence = null;
    return captured;
  }

  // ───────────────────────────── Availability ─────────────────────────────

  /// Probe the radio and settle the state to one of unsupported / adapterOff /
  /// idle. Safe to call repeatedly; safe to call in a test with no platform.
  Future<BleLinkStatus> refreshAvailability() async {
    if (_disposed) return _state.status;
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        _emit(_state.copyWith(status: BleLinkStatus.unsupported));
        return BleLinkStatus.unsupported;
      }
      final adapter = FlutterBluePlus.adapterStateNow;
      if (adapter == BluetoothAdapterState.unauthorized) {
        _emit(_state.copyWith(status: BleLinkStatus.permissionDenied));
        return BleLinkStatus.permissionDenied;
      }
      if (adapter != BluetoothAdapterState.on) {
        _emit(_state.copyWith(status: BleLinkStatus.adapterOff));
        return BleLinkStatus.adapterOff;
      }
      // Only promote to idle from a non-active state; never interrupt a live
      // link because something asked whether the radio exists.
      if (!_state.isLive && !_state.isBusy) {
        _emit(_state.copyWith(status: BleLinkStatus.idle, clearMessage: true));
      }
      return _state.status;
    } catch (_) {
      // No platform channel — a unit or widget test, or a desktop build.
      _emit(_state.copyWith(status: BleLinkStatus.unsupported));
      return BleLinkStatus.unsupported;
    }
  }

  // ─────────────────────────────── Scanning ───────────────────────────────

  /// Look for boards. Emits on [candidates] as results arrive.
  ///
  /// Unfiltered at the radio level on purpose: filtering by service UUID hides
  /// a board whose firmware advertises the wrong one, and a worker staring at an
  /// empty list has no way to tell that from "nothing is nearby". Everything is
  /// reported, with [BleCandidate.isSensorBoard] marking what the app recognises.
  Future<void> startScan({
    Duration timeout = AppConstants.bleScanTimeout,
  }) async {
    if (_disposed) return;

    final status = await refreshAvailability();
    if (status == BleLinkStatus.unsupported ||
        status == BleLinkStatus.adapterOff ||
        status == BleLinkStatus.permissionDenied) {
      _candidatesController.add(const []);
      return;
    }

    await _stopScanQuietly();
    _emit(_state.copyWith(status: BleLinkStatus.scanning, clearMessage: true));

    try {
      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) {
          final seen = <String, BleCandidate>{};
          for (final r in results) {
            final id = r.device.remoteId.str;
            final advertised = r.advertisementData.advName;
            final name = advertised.isNotEmpty ? advertised : r.device.platformName;
            seen[id] = BleCandidate(
              id: id,
              name: name,
              rssi: r.rssi,
              isSensorBoard: _looksLikeSensorBoard(
                name: name,
                serviceUuids: r.advertisementData.serviceUuids,
              ),
            );
          }
          final list = seen.values.toList()
            // Recognised boards first, then by signal: the thing the worker
            // came here to connect to should not be below their earbuds.
            ..sort((a, b) {
              if (a.isSensorBoard != b.isSensorBoard) {
                return a.isSensorBoard ? -1 : 1;
              }
              return b.rssi.compareTo(a.rssi);
            });
          if (!_candidatesController.isClosed) _candidatesController.add(list);
        },
        onError: (_) {
          if (!_candidatesController.isClosed) {
            _candidatesController.add(const []);
          }
        },
      );

      await FlutterBluePlus.startScan(timeout: timeout);

      // startScan returns when the timeout elapses. If nothing interrupted us,
      // settle back to idle so the button stops saying "searching".
      if (!_disposed && _state.status == BleLinkStatus.scanning) {
        _emit(_state.copyWith(status: BleLinkStatus.idle));
      }
    } catch (_) {
      await _stopScanQuietly();
      _emit(
        _state.copyWith(
          status: BleLinkStatus.failed,
          message: 'The Bluetooth scan could not be started. Check that '
              'Bluetooth and location permissions are granted, then try again.',
        ),
      );
    }
  }

  Future<void> stopScan() async {
    await _stopScanQuietly();
    if (!_disposed && _state.status == BleLinkStatus.scanning) {
      _emit(_state.copyWith(status: BleLinkStatus.idle));
    }
  }

  /// Whether a scan result is one of ours.
  ///
  /// Static and pure so the matching rule is unit-testable: it decides which
  /// entry in a list of a dozen radios the worker is told to tap.
  static bool matchesSensorBoard({
    required String name,
    List<String> serviceUuids = const [],
  }) =>
      _looksLikeSensorBoard(name: name, serviceUuids: serviceUuids);

  static bool _looksLikeSensorBoard({
    required String name,
    required List<dynamic> serviceUuids,
  }) {
    for (final uuid in serviceUuids) {
      final text = uuid is Guid ? uuid.str128 : uuid.toString();
      if (text.toLowerCase() ==
          AppConstants.deviceServiceUuid.toLowerCase()) {
        return true;
      }
      // Some stacks advertise the 16-bit alias only.
      if (text.toLowerCase() ==
          AppConstants.deviceServiceUuid.substring(4, 8).toLowerCase()) {
        return true;
      }
    }
    final lower = name.toLowerCase();
    return lower.startsWith('swasthyasetu') ||
        lower.startsWith('ssai') ||
        lower.startsWith('ss-');
  }

  // ─────────────────────────────── Connect ───────────────────────────────

  /// Connect, handshake, and start streaming.
  ///
  /// Returns true once frames are flowing. On failure the state carries a reason
  /// the worker can act on, and this returns false — callers do not need to
  /// catch anything.
  Future<bool> connect(String remoteId, {String? name}) async {
    if (_disposed) return false;

    await _stopScanQuietly();
    _cancelRetry();
    _wantConnection = true;

    _emit(
      _state.copyWith(
        status: BleLinkStatus.connecting,
        deviceId: remoteId,
        deviceName: name,
        attempt: 0,
        // Cleared rather than carried over: what the previous board offered says
        // nothing about this one.
        hasEcgChannel: false,
        clearRetry: true,
        clearMessage: true,
      ),
    );

    return _attemptConnect(remoteId);
  }

  Future<bool> _attemptConnect(String remoteId) async {
    try {
      final device = BluetoothDevice.fromId(remoteId);
      _device = device;

      await device.connect(timeout: const Duration(seconds: 20));

      // Watch for the link dropping from here on, not earlier: a failure during
      // connect() is reported by the throw, and a listener attached before the
      // connection exists would fire a spurious reconnect on the first
      // `disconnected` event the stream replays.
      await _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen(_onConnectionStateChange);

      _emit(_state.copyWith(status: BleLinkStatus.discovering));
      final services = await device.discoverServices();

      final service = services.firstWhere(
        (s) => s.uuid == Guid(AppConstants.deviceServiceUuid),
        orElse: () => throw const _HandshakeFailure(
          'This device does not expose the SwasthyaSetu sensor service. It is '
          'probably a different Bluetooth device with a similar name.',
        ),
      );

      _emit(_state.copyWith(status: BleLinkStatus.handshaking));

      BluetoothCharacteristic? charFor(String uuid) {
        final target = Guid(uuid);
        for (final c in service.characteristics) {
          if (c.uuid == target) return c;
        }
        return null;
      }

      _vitalsChar = charFor(AppConstants.liveVitalsCharUuid);
      _ecgChar = charFor(AppConstants.ecgStreamCharUuid);
      _controlChar = charFor(AppConstants.controlCharUuid);

      if (_vitalsChar == null) {
        throw const _HandshakeFailure(
          'The board exposes the sensor service but not the live-vitals '
          'channel. Its firmware is too old for this app version.',
        );
      }

      _emit(_state.copyWith(hasEcgChannel: _ecgChar != null));

      await _readFirmware(charFor(AppConstants.deviceInfoCharUuid));

      // Subscribe first, then ask the board to start: notifications that arrive
      // before the subscription exists are dropped by the OS, which presents as
      // a connected device that never sends anything.
      await _vitalsChar!.setNotifyValue(true);
      _vitalsSub = _vitalsChar!.onValueReceived.listen(_onVitalsFrame);

      if (_ecgChar != null) {
        await _ecgChar!.setNotifyValue(true);
        _ecgSub = _ecgChar!.onValueReceived.listen(_onEcgFrame);
      }

      if (_controlChar != null) {
        try {
          await _controlChar!.write(
            BleProtocol.startStreamCommand,
            withoutResponse: false,
          );
        } catch (_) {
          // Firmware 1.0 streams unprompted and has no control characteristic
          // behaviour. Not fatal: the notifications are already subscribed.
        }
      }

      _emit(
        _state.copyWith(
          status: BleLinkStatus.streaming,
          attempt: 0,
          clearRetry: true,
          clearMessage: true,
        ),
      );
      return true;
    } on _HandshakeFailure catch (e) {
      // A wrong device or incompatible firmware is not a transient fault, so
      // retrying it would just spin. Stop and say what is wrong.
      _wantConnection = false;
      await _teardownLink();
      _emit(
        _state.copyWith(status: BleLinkStatus.failed, message: e.message),
      );
      return false;
    } catch (_) {
      // Anything else — out of range, board asleep, GATT busy — is worth a
      // retry, so route it through the same backoff as a mid-screening drop.
      await _teardownLink();
      if (_wantConnection) {
        _scheduleRetry();
      } else {
        _emit(_state.copyWith(status: BleLinkStatus.idle));
      }
      return false;
    }
  }

  Future<void> _readFirmware(BluetoothCharacteristic? infoChar) async {
    if (infoChar == null) {
      _emit(
        _state.copyWith(compatibility: FirmwareCompatibility.unknown),
      );
      return;
    }
    try {
      final version = BleProtocol.parseFirmwareVersion(await infoChar.read());
      final compatibility = DeviceRepository.checkFirmware(version ?? 'UNKNOWN');
      _emit(
        _state.copyWith(
          firmwareVersion: version,
          compatibility: compatibility,
        ),
      );
      // Note what is *not* here: an incompatible firmware does not abort the
      // connection. A board one version behind still measures SpO2 correctly,
      // and refusing to talk to it would leave a worker with no device at all.
      // The warning is surfaced; the decision is theirs.
    } catch (_) {
      _emit(_state.copyWith(compatibility: FirmwareCompatibility.unknown));
    }
  }

  Future<void> disconnect() async {
    _wantConnection = false;
    _cancelRetry();

    if (_controlChar != null) {
      try {
        await _controlChar!.write(BleProtocol.stopStreamCommand);
      } catch (_) {
        // Best effort: the board idles its sensors on link loss anyway.
      }
    }

    await _teardownLink();
    try {
      await _device?.disconnect();
    } catch (_) {
      // Already gone.
    }
    _device = null;

    if (!_disposed) {
      _emit(
        BleLinkState(
          status: BleLinkStatus.idle,
          // Firmware and identity are kept: the worker just disconnected from a
          // known board, and blanking the card makes it look like a stranger.
          deviceId: _state.deviceId,
          deviceName: _state.deviceName,
          firmwareVersion: _state.firmwareVersion,
          compatibility: _state.compatibility,
        ),
      );
    }
  }

  // ────────────────────────────── Reconnection ──────────────────────────────

  void _onConnectionStateChange(BluetoothConnectionState state) {
    if (_disposed) return;
    if (state != BluetoothConnectionState.disconnected) return;

    // An expected disconnect is already handled by disconnect().
    if (!_wantConnection) return;

    _teardownNotifications();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || !_wantConnection) return;

    final attempt = _state.attempt + 1;
    if (attempt > BleBackoff.maxAttempts) {
      _wantConnection = false;
      _emit(
        _state.copyWith(
          status: BleLinkStatus.failed,
          attempt: BleBackoff.maxAttempts,
          clearRetry: true,
        ),
      );
      return;
    }

    final delay = BleBackoff.delayFor(attempt);
    _emit(
      _state.copyWith(
        status: BleLinkStatus.reconnecting,
        attempt: attempt,
        retryIn: delay,
        clearMessage: true,
      ),
    );

    // A countdown, not a silent pause: thirty seconds of an unexplained spinner
    // reads as a hang, and the worker power-cycles a board that was about to
    // come back on its own.
    _retryTicker?.cancel();
    var remaining = delay;
    _retryTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero || _disposed) {
        t.cancel();
        return;
      }
      if (_state.status == BleLinkStatus.reconnecting) {
        _emit(_state.copyWith(retryIn: remaining));
      }
    });

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTicker?.cancel();
      final id = _state.deviceId;
      if (_disposed || !_wantConnection || id == null) return;
      _emit(_state.copyWith(status: BleLinkStatus.connecting, clearRetry: true));
      _attemptConnect(id);
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryTicker?.cancel();
    _retryTicker = null;
  }

  // ──────────────────────────────── Frames ────────────────────────────────

  void _onVitalsFrame(List<int> bytes) {
    final frame = BleProtocol.parseTelemetry(bytes);
    // A frame that does not decode is dropped, not repaired. See BleProtocol.
    if (frame == null) return;

    _emit(
      _state.copyWith(
        // The first frame after a reconnect is what proves the link is really
        // back; the GATT callback only proves the radios are talking.
        status: BleLinkStatus.streaming,
        batteryPercent: frame.sample.batteryPercent,
        lastFrameAt: DateTime.now(),
        leadOff: frame.leadOff,
        fingerOff: frame.fingerOff,
        attempt: 0,
        clearRetry: true,
      ),
    );

    if (!_telemetryController.isClosed) _telemetryController.add(frame);
  }

  void _onEcgFrame(List<int> bytes) {
    final frame = BleProtocol.parseEcg(bytes);
    if (frame == null) return;

    if (_lastEcgSequence != null &&
        !BleProtocol.isContiguous(_lastEcgSequence!, frame.sequence)) {
      _emit(
        _state.copyWith(droppedEcgFrames: _state.droppedEcgFrames + 1),
      );
    }
    _lastEcgSequence = frame.sequence;

    if (_capturing) _capturedEcg.addAll(frame.samples);
    if (!_ecgController.isClosed) _ecgController.add(frame);
  }

  // ──────────────────────────────── Teardown ────────────────────────────────

  void _teardownNotifications() {
    _vitalsSub?.cancel();
    _vitalsSub = null;
    _ecgSub?.cancel();
    _ecgSub = null;
  }

  Future<void> _teardownLink() async {
    _teardownNotifications();
    _vitalsChar = null;
    _ecgChar = null;
    _controlChar = null;
  }

  Future<void> _stopScanQuietly() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Never scanning, or no platform. Either way there is nothing to stop.
    }
  }

  void _emit(BleLinkState next) {
    if (_disposed) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  Future<void> dispose() async {
    _disposed = true;
    _cancelRetry();
    _teardownNotifications();
    await _scanSub?.cancel();
    await _connectionSub?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await _device?.disconnect();
    } catch (_) {}
    await _stateController.close();
    await _telemetryController.close();
    await _ecgController.close();
    await _candidatesController.close();
  }
}

/// A failure that retrying cannot fix: wrong device, or firmware missing a
/// channel this app needs.
class _HandshakeFailure implements Exception {
  final String message;
  const _HandshakeFailure(this.message);
}
