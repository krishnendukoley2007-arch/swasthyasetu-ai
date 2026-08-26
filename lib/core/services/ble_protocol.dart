import 'dart:convert';
import 'dart:typed_data';

import 'package:swasthyasetu_ai/domain/models/health_sample.dart';

/// The wire format spoken by the SwasthyaSetu sensor board, and nothing else.
///
/// This file is deliberately free of `flutter_blue_plus`: parsing a byte array
/// is the part of the BLE layer most likely to be wrong, and it is the part
/// hardest to exercise on a real radio. Keeping it pure means every field,
/// endianness and out-of-range case is covered by a plain unit test that runs on
/// a laptop with no device in the room.
///
/// A malformed frame returns `null`. It never returns a partially-populated
/// sample: a heart rate parsed out of a truncated packet is indistinguishable
/// from a measured one once it reaches the triage engine, so the only safe
/// failure is no reading at all.
class BleProtocol {
  BleProtocol._();

  /// Frame type markers, byte 0 of every notification.
  static const int frameTelemetry = 0x01;
  static const int frameEcg = 0x02;

  /// Protocol revisions this build can decode. Byte 1 of every frame.
  ///
  /// Separate from the *firmware* version (which is a human-facing string read
  /// from the device-info characteristic): a firmware release can ship bug fixes
  /// without changing the wire format, and the app should not refuse those.
  static const int minProtocolVersion = 1;
  static const int maxProtocolVersion = 1;

  /// Fixed width of a telemetry frame. Anything else is not a telemetry frame.
  static const int telemetryFrameLength = 20;

  /// Bytes consumed by the ECG frame header before the samples begin.
  static const int ecgHeaderLength = 4;

  /// Sample rate the board claims for the ECG stream, used to turn a sample
  /// count into a duration. Declared here next to the parser rather than read
  /// from the packet, because firmware 1.x has no field for it.
  static const int ecgSampleRateHz = 250;

  // ─────────────────────────── Physiological limits ───────────────────────────
  //
  // Not clinical thresholds — those live in the rules engine. These are the
  // limits outside which a value cannot be a measurement at all, and is instead
  // a dropped bit, an unseated sensor, or a firmware placeholder. A reading that
  // fails these is passed on with `plausible: false` so the UI can say "sensor
  // is not reading" instead of drawing 0 bpm as though it were a bradycardia.

  static const int minHeartRate = 25;
  static const int maxHeartRate = 250;
  static const int minSpo2 = 50;
  static const int maxSpo2 = 100;
  static const double minTemperatureC = 20.0;
  static const double maxTemperatureC = 45.0;

  /// Decode a live-vitals notification.
  ///
  /// Layout, little-endian throughout (the ESP32 is little-endian, so the
  /// firmware can `memcpy` a packed struct straight onto the wire):
  ///
  /// ```text
  ///  0      uint8   frame type == 0x01
  ///  1      uint8   protocol version
  ///  2      uint8   heart rate, bpm
  ///  3      uint8   SpO2, percent
  ///  4..5   int16   temperature, hundredths of a degree C (3650 == 36.50)
  ///  6..7   uint16  last R-R interval, ms
  ///  8      uint8   ECG signal quality, 0..100
  ///  9      uint8   flags — bit0 R-peak, bit1 fall, bit2 lead off, bit3 finger off
  /// 10..11  uint16  pulse transit time, ms
  /// 12      uint8   estimated systolic, mmHg
  /// 13      uint8   estimated diastolic, mmHg
  /// 14      uint8   battery, percent
  /// 15      uint8   BP confidence — 0 low, 1 medium, 2 high
  /// 16..19  uint32  device uptime, ms
  /// ```
  static TelemetryFrame? parseTelemetry(List<int> bytes, {int? timestampMs}) {
    if (bytes.length != telemetryFrameLength) return null;
    if (bytes[0] != frameTelemetry) return null;
    if (!isSupportedProtocol(bytes[1])) return null;

    final data = ByteData.sublistView(Uint8List.fromList(bytes));

    final heartRate = bytes[2];
    final spo2 = bytes[3];
    final temperature = data.getInt16(4, Endian.little) / 100.0;
    final rrInterval = data.getUint16(6, Endian.little);
    final quality = bytes[8];
    final flags = bytes[9];
    final ptt = data.getUint16(10, Endian.little);
    final systolic = bytes[12];
    final diastolic = bytes[13];
    final battery = bytes[14];
    final confidence = bytes[15];
    final uptimeMs = data.getUint32(16, Endian.little);

    final plausible = heartRate >= minHeartRate &&
        heartRate <= maxHeartRate &&
        spo2 >= minSpo2 &&
        spo2 <= maxSpo2 &&
        temperature >= minTemperatureC &&
        temperature <= maxTemperatureC;

    return TelemetryFrame(
      sample: HealthSample(
        // The device clock is an uptime counter with no notion of the date, so
        // the phone stamps the wall-clock time. The board's own uptime is kept
        // separately for gap detection, not used as a timestamp.
        timestamp: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        heartRateBpm: heartRate,
        spo2Percent: spo2,
        temperatureC: temperature,
        ecgSignalQuality: (quality.clamp(0, 100)) / 100.0,
        rPeakDetected: flags & 0x01 != 0,
        rrIntervalMs: rrInterval,
        pttMs: ptt,
        estimatedSystolic: systolic,
        estimatedDiastolic: diastolic,
        bpConfidence: bpConfidenceLabel(confidence),
        batteryPercent: battery.clamp(0, 100),
        // Never set from a real frame. The flag exists so a demo reading can
        // never be mistaken for a measurement, and this path is the measurement.
        isDemo: false,
      ),
      fallDetected: flags & 0x02 != 0,
      leadOff: flags & 0x04 != 0,
      fingerOff: flags & 0x08 != 0,
      plausible: plausible,
      deviceUptimeMs: uptimeMs,
    );
  }

  /// Decode an ECG waveform notification into signed 16-bit samples.
  ///
  /// ```text
  ///  0      uint8   frame type == 0x02
  ///  1      uint8   protocol version
  ///  2..3   uint16  sequence number, wraps at 65535
  ///  4..    int16[] samples, little-endian
  /// ```
  ///
  /// The sequence number is what makes a dropped notification visible. BLE
  /// notifications are unacknowledged, so a gap here is normal under load — but
  /// silently concatenating across it would put a step discontinuity in the
  /// middle of a trace a worker is about to read as a rhythm.
  static EcgFrame? parseEcg(List<int> bytes) {
    if (bytes.length < ecgHeaderLength) return null;
    if (bytes[0] != frameEcg) return null;
    if (!isSupportedProtocol(bytes[1])) return null;

    final payloadLength = bytes.length - ecgHeaderLength;
    // A half sample means the frame was truncated mid-value.
    if (payloadLength <= 0 || payloadLength.isOdd) return null;

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final sequence = data.getUint16(2, Endian.little);

    final samples = <int>[];
    for (var offset = ecgHeaderLength; offset < bytes.length; offset += 2) {
      samples.add(data.getInt16(offset, Endian.little));
    }

    return EcgFrame(sequence: sequence, samples: samples);
  }

  /// Whether two consecutive ECG frames are contiguous, accounting for the
  /// 16-bit sequence counter wrapping back to zero.
  static bool isContiguous(int previousSequence, int nextSequence) =>
      nextSequence == (previousSequence + 1) & 0xFFFF;

  static bool isSupportedProtocol(int version) =>
      version >= minProtocolVersion && version <= maxProtocolVersion;

  static String bpConfidenceLabel(int code) => switch (code) {
        0 => 'LOW',
        1 => 'MEDIUM',
        2 => 'HIGH',
        // An unknown code is not upgraded to a confidence the app invented.
        _ => 'EXPERIMENTAL',
      };

  /// Pull a `major.minor.patch` firmware version out of the device-info
  /// characteristic.
  ///
  /// Firmware writes a free-form identification string — `"SwasthyaSetu
  /// ESP32 v1.2.0"` on the current release, but the prefix has changed between
  /// board revisions and will change again. Only the version is extracted, and a
  /// string with no version in it yields `null` rather than a guess, which the
  /// compatibility check reports honestly as "version unknown".
  static String? parseFirmwareVersion(List<int> bytes) {
    if (bytes.isEmpty) return null;
    final String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
    final match = RegExp(r'(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(text);
    if (match == null) return null;
    final patch = match.group(3);
    return patch == null
        ? '${match.group(1)}.${match.group(2)}.0'
        : '${match.group(1)}.${match.group(2)}.$patch';
  }

  /// The single-byte command that asks the board to begin streaming.
  ///
  /// Written to the control characteristic after subscription rather than
  /// before: the board starts sending on receipt, and notifications that arrive
  /// before the subscription exists are dropped by the OS.
  static List<int> get startStreamCommand => const [0xA1];

  /// Ask the board to stop streaming and idle its sensors. Sent on a clean
  /// disconnect so the LED goes out and the battery lasts the rest of the shift.
  static List<int> get stopStreamCommand => const [0xA0];
}

/// One decoded live-vitals frame: the reading, plus the sensor-state bits that
/// explain a reading rather than being part of it.
class TelemetryFrame {
  final HealthSample sample;

  /// The board's own MPU6050 saw an impact. Separate from the phone-side fall
  /// detector, and routed to the same SOS countdown.
  final bool fallDetected;

  /// ECG electrodes are not making contact. The rhythm classification is
  /// meaningless while this is set.
  final bool leadOff;

  /// No finger on the pulse oximeter. SpO2 and heart rate are meaningless while
  /// this is set.
  final bool fingerOff;

  /// Every value is inside the range a human body can produce. False means the
  /// frame decoded cleanly but describes something that is not a person —
  /// treat as a sensor fault, not as a vital sign.
  final bool plausible;

  final int deviceUptimeMs;

  const TelemetryFrame({
    required this.sample,
    required this.fallDetected,
    required this.leadOff,
    required this.fingerOff,
    required this.plausible,
    required this.deviceUptimeMs,
  });

  /// Whether this frame is fit to display as a vital sign.
  bool get isUsable => plausible && !fingerOff;
}

class EcgFrame {
  final int sequence;
  final List<int> samples;

  const EcgFrame({required this.sequence, required this.samples});

  Duration get duration => Duration(
        milliseconds:
            (samples.length * 1000 / BleProtocol.ecgSampleRateHz).round(),
      );
}

/// How long to wait before retry number `attempt`.
///
/// Exponential, because the two reasons a link drops need opposite treatment: a
/// phone that slipped into a pocket reconnects on the first retry, and a board
/// whose battery died will never reconnect no matter how often it is asked.
/// Retrying every 500 ms for five minutes flattens the phone battery on the
/// second case, which is the case where the worker most needs the phone alive.
class BleBackoff {
  BleBackoff._();

  static const Duration base = Duration(seconds: 1);

  /// Retries stop growing here. Half a minute is long enough to be cheap and
  /// short enough that walking back into range recovers without the worker
  /// having to know to press anything.
  static const Duration cap = Duration(seconds: 30);

  /// After this many failures the service gives up and says so.
  ///
  /// It stops rather than retrying forever because an indefinite "reconnecting…"
  /// spinner is a worse answer than "this device is gone, use another one" —
  /// the second is actionable and the first invites waiting.
  static const int maxAttempts = 6;

  /// 1s, 2s, 4s, 8s, 16s, 30s, then held at 30s.
  ///
  /// No random jitter: one phone talking to one board has no thundering-herd
  /// problem to solve, and a deterministic schedule is one a test can assert and
  /// a worker can learn the rhythm of.
  static Duration delayFor(int attempt) {
    if (attempt <= 1) return base;
    final exponent = attempt - 1;
    // 1 << 30 seconds is beyond any cap; stop doubling well before it overflows.
    if (exponent >= 20) return cap;
    final millis = base.inMilliseconds * (1 << exponent);
    return millis >= cap.inMilliseconds ? cap : Duration(milliseconds: millis);
  }

  /// Total time spent waiting before giving up, for the copy that tells the
  /// worker how long this will take.
  static Duration get totalBudget {
    var total = Duration.zero;
    for (var i = 1; i <= maxAttempts; i++) {
      total += delayFor(i);
    }
    return total;
  }
}
