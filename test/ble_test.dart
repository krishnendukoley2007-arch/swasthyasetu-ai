import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/ble_protocol.dart';
import 'package:swasthyasetu_ai/core/services/ble_service.dart';
import 'package:swasthyasetu_ai/data/repositories/device_repository.dart';

/// The BLE layer's decision-making, tested without a radio.
///
/// Everything here is reachable with a byte array and an integer, which is why
/// it was written as pure functions in the first place: the alternative is
/// discovering that the temperature field was read big-endian while standing in
/// a village with one board and no debugger.

/// Build a well-formed telemetry frame. Named parameters mirror the wire layout
/// so a test reads like the packet it is describing.
List<int> telemetryFrame({
  int type = BleProtocol.frameTelemetry,
  int version = 1,
  int heartRate = 72,
  int spo2 = 98,
  int temperatureCentiC = 3650,
  int rrIntervalMs = 833,
  int quality = 95,
  int flags = 0x01,
  int pttMs = 200,
  int systolic = 120,
  int diastolic = 80,
  int battery = 85,
  int bpConfidence = 1,
  int uptimeMs = 120000,
}) {
  final bytes = Uint8List(BleProtocol.telemetryFrameLength);
  final data = ByteData.sublistView(bytes);
  bytes[0] = type;
  bytes[1] = version;
  bytes[2] = heartRate;
  bytes[3] = spo2;
  data.setInt16(4, temperatureCentiC, Endian.little);
  data.setUint16(6, rrIntervalMs, Endian.little);
  bytes[8] = quality;
  bytes[9] = flags;
  data.setUint16(10, pttMs, Endian.little);
  bytes[12] = systolic;
  bytes[13] = diastolic;
  bytes[14] = battery;
  bytes[15] = bpConfidence;
  data.setUint32(16, uptimeMs, Endian.little);
  return bytes;
}

List<int> ecgFrame({
  int type = BleProtocol.frameEcg,
  int version = 1,
  int sequence = 1,
  List<int> samples = const [100, -100, 2000, -2000],
}) {
  final bytes = Uint8List(BleProtocol.ecgHeaderLength + samples.length * 2);
  final data = ByteData.sublistView(bytes);
  bytes[0] = type;
  bytes[1] = version;
  data.setUint16(2, sequence, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(BleProtocol.ecgHeaderLength + i * 2, samples[i], Endian.little);
  }
  return bytes;
}

void main() {
  group('BleProtocol.parseTelemetry', () {
    test('a well-formed frame decodes every field', () {
      final frame = BleProtocol.parseTelemetry(
        telemetryFrame(),
        timestampMs: 1700000000000,
      );

      expect(frame, isNotNull);
      final sample = frame!.sample;
      expect(sample.timestamp, 1700000000000);
      expect(sample.heartRateBpm, 72);
      expect(sample.spo2Percent, 98);
      expect(sample.temperatureC, closeTo(36.5, 0.001));
      expect(sample.rrIntervalMs, 833);
      expect(sample.ecgSignalQuality, closeTo(0.95, 0.001));
      expect(sample.rPeakDetected, isTrue);
      expect(sample.pttMs, 200);
      expect(sample.estimatedSystolic, 120);
      expect(sample.estimatedDiastolic, 80);
      expect(sample.bpConfidence, 'MEDIUM');
      expect(sample.batteryPercent, 85);
      expect(frame.deviceUptimeMs, 120000);
      expect(frame.plausible, isTrue);
      expect(frame.isUsable, isTrue);
    });

    test('a measured sample is never marked as demo', () {
      // The whole reliability story rests on this flag. If a real frame could
      // set it, or a demo reading could clear it, the "DEMO" label on screen
      // stops meaning anything.
      final frame = BleProtocol.parseTelemetry(telemetryFrame());
      expect(frame!.sample.isDemo, isFalse);
    });

    test('temperature is signed, so a cold sensor does not read as 600 degrees', () {
      // -5.00 C. Read as unsigned this is 64,036 hundredths.
      final frame = BleProtocol.parseTelemetry(
        telemetryFrame(temperatureCentiC: -500),
      );
      expect(frame!.sample.temperatureC, closeTo(-5.0, 0.001));
      // And it is correctly flagged as not a human reading.
      expect(frame.plausible, isFalse);
    });

    test('multi-byte fields are little-endian', () {
      // 0x0341 == 833. A big-endian read gives 0x4103 == 16643, which is a
      // plausible-looking number and therefore the dangerous kind of wrong.
      final frame = BleProtocol.parseTelemetry(
        telemetryFrame(rrIntervalMs: 833, pttMs: 300, uptimeMs: 0x01020304),
      );
      expect(frame!.sample.rrIntervalMs, 833);
      expect(frame.sample.pttMs, 300);
      expect(frame.deviceUptimeMs, 0x01020304);
    });

    test('a truncated frame yields nothing rather than a partial reading', () {
      final short = telemetryFrame().sublist(0, 12);
      expect(BleProtocol.parseTelemetry(short), isNull);
      expect(BleProtocol.parseTelemetry(const []), isNull);
    });

    test('an over-long frame is rejected too', () {
      // Extra bytes mean the layout is not the one this build knows, even if the
      // prefix happens to parse.
      final long = [...telemetryFrame(), 0x00, 0x00];
      expect(BleProtocol.parseTelemetry(long), isNull);
    });

    test('the wrong frame type is not decoded as telemetry', () {
      expect(
        BleProtocol.parseTelemetry(telemetryFrame(type: BleProtocol.frameEcg)),
        isNull,
      );
    });

    test('an unsupported protocol version is refused', () {
      // Refusing beats guessing: a version bump exists precisely because a field
      // moved, and decoding it with the old layout produces confident nonsense.
      expect(BleProtocol.parseTelemetry(telemetryFrame(version: 0)), isNull);
      expect(BleProtocol.parseTelemetry(telemetryFrame(version: 2)), isNull);
      expect(BleProtocol.parseTelemetry(telemetryFrame(version: 1)), isNotNull);
    });

    test('flags are decoded independently', () {
      final all = BleProtocol.parseTelemetry(telemetryFrame(flags: 0x0F))!;
      expect(all.sample.rPeakDetected, isTrue);
      expect(all.fallDetected, isTrue);
      expect(all.leadOff, isTrue);
      expect(all.fingerOff, isTrue);

      final none = BleProtocol.parseTelemetry(telemetryFrame(flags: 0x00))!;
      expect(none.sample.rPeakDetected, isFalse);
      expect(none.fallDetected, isFalse);
      expect(none.leadOff, isFalse);
      expect(none.fingerOff, isFalse);

      // Fall only — the bit that routes into the SOS countdown.
      final fall = BleProtocol.parseTelemetry(telemetryFrame(flags: 0x02))!;
      expect(fall.fallDetected, isTrue);
      expect(fall.leadOff, isFalse);
    });

    test('impossible vitals decode but are marked implausible', () {
      // A zero heart rate is what an unseated sensor sends. Drawing it as a
      // reading would put "0 bpm" in front of a worker as though it were a
      // measurement of a person, so it is flagged instead of hidden or clamped.
      final flat = BleProtocol.parseTelemetry(telemetryFrame(heartRate: 0))!;
      expect(flat.plausible, isFalse);
      expect(flat.sample.heartRateBpm, 0);

      expect(
        BleProtocol.parseTelemetry(telemetryFrame(spo2: 0))!.plausible,
        isFalse,
      );
      expect(
        BleProtocol.parseTelemetry(telemetryFrame(temperatureCentiC: 0))!
            .plausible,
        isFalse,
      );
      // 250 bpm is the documented ceiling and is still accepted.
      expect(
        BleProtocol.parseTelemetry(telemetryFrame(heartRate: 250))!.plausible,
        isTrue,
      );
    });

    test('a finger off the sensor makes the frame unusable, not implausible', () {
      // Different things: the numbers may be in range, they are just not of a
      // person's finger.
      final frame =
          BleProtocol.parseTelemetry(telemetryFrame(flags: 0x08 | 0x01))!;
      expect(frame.plausible, isTrue);
      expect(frame.fingerOff, isTrue);
      expect(frame.isUsable, isFalse);
    });

    test('an unknown BP confidence code is not upgraded to a real one', () {
      expect(
        BleProtocol.parseTelemetry(telemetryFrame(bpConfidence: 7))!
            .sample
            .bpConfidence,
        'EXPERIMENTAL',
      );
      expect(BleProtocol.bpConfidenceLabel(0), 'LOW');
      expect(BleProtocol.bpConfidenceLabel(2), 'HIGH');
    });

    test('battery and quality are clamped into their declared ranges', () {
      final frame =
          BleProtocol.parseTelemetry(telemetryFrame(battery: 200, quality: 200))!;
      expect(frame.sample.batteryPercent, 100);
      expect(frame.sample.ecgSignalQuality, 1.0);
    });
  });

  group('BleProtocol.parseEcg', () {
    test('signed samples round-trip through the wire format', () {
      final frame = BleProtocol.parseEcg(
        ecgFrame(sequence: 42, samples: const [0, 1, -1, 32767, -32768]),
      );

      expect(frame, isNotNull);
      expect(frame!.sequence, 42);
      expect(frame.samples, const [0, 1, -1, 32767, -32768]);
    });

    test('a header with no samples is not a frame', () {
      expect(BleProtocol.parseEcg(ecgFrame(samples: const [])), isNull);
    });

    test('a frame cut mid-sample is refused', () {
      // An odd payload length means the last value lost a byte. Keeping the
      // whole-sample prefix would be defensible; inventing the missing byte is
      // not, and telling the difference later is impossible.
      final odd = [...ecgFrame(samples: const [100, 200]), 0x7F];
      expect(BleProtocol.parseEcg(odd), isNull);
    });

    test('the wrong type and version are refused', () {
      expect(
        BleProtocol.parseEcg(ecgFrame(type: BleProtocol.frameTelemetry)),
        isNull,
      );
      expect(BleProtocol.parseEcg(ecgFrame(version: 9)), isNull);
    });

    test('duration is derived from the declared sample rate', () {
      // 250 samples at 250 Hz is one second.
      final frame = BleProtocol.parseEcg(
        ecgFrame(samples: List.filled(250, 0)),
      )!;
      expect(frame.duration, const Duration(seconds: 1));
    });

    test('sequence contiguity survives the 16-bit wrap', () {
      expect(BleProtocol.isContiguous(1, 2), isTrue);
      expect(BleProtocol.isContiguous(1, 3), isFalse);
      // A dropped frame at the wrap point is the case a naive `prev + 1` misses,
      // and it produces a spurious gap warning once every 65,536 frames.
      expect(BleProtocol.isContiguous(65535, 0), isTrue);
      expect(BleProtocol.isContiguous(65535, 1), isFalse);
    });
  });

  group('BleProtocol.parseFirmwareVersion', () {
    test('a version is pulled out of a free-form identification string', () {
      expect(
        BleProtocol.parseFirmwareVersion(
          utf8.encode('SwasthyaSetu ESP32 v1.2.0'),
        ),
        '1.2.0',
      );
      expect(
        BleProtocol.parseFirmwareVersion(utf8.encode('SSAI-BOARD 2.4.11-rc1')),
        '2.4.11',
      );
    });

    test('a two-part version gains an explicit zero patch', () {
      // So that string comparison and display are consistent, rather than "1.2"
      // and "1.2.0" appearing as two different firmwares in the device list.
      expect(BleProtocol.parseFirmwareVersion(utf8.encode('v1.4')), '1.4.0');
    });

    test('a string with no version yields null, not a guess', () {
      expect(BleProtocol.parseFirmwareVersion(utf8.encode('SwasthyaSetu')), isNull);
      expect(BleProtocol.parseFirmwareVersion(const []), isNull);
    });

    test('malformed bytes do not throw', () {
      // A board mid-flash can return anything at all.
      expect(
        () => BleProtocol.parseFirmwareVersion(const [0xFF, 0xFE, 0xC0]),
        returnsNormally,
      );
    });

    test('a parsed version feeds the compatibility check', () {
      final version =
          BleProtocol.parseFirmwareVersion(utf8.encode('board v1.0.3'))!;
      expect(
        DeviceRepository.checkFirmware(version),
        FirmwareCompatibility.supported,
      );
      // And a board from the next generation is reported as the app being old,
      // which is the accurate direction of blame.
      expect(
        DeviceRepository.checkFirmware(
          BleProtocol.parseFirmwareVersion(utf8.encode('v2.0.0'))!,
        ),
        FirmwareCompatibility.tooNew,
      );
      // An unreadable version is "unknown", never assumed compatible.
      expect(
        DeviceRepository.checkFirmware('UNKNOWN'),
        FirmwareCompatibility.unknown,
      );
    });
  });

  group('BleBackoff', () {
    test('delays double from one second and stop at the cap', () {
      expect(BleBackoff.delayFor(1), const Duration(seconds: 1));
      expect(BleBackoff.delayFor(2), const Duration(seconds: 2));
      expect(BleBackoff.delayFor(3), const Duration(seconds: 4));
      expect(BleBackoff.delayFor(4), const Duration(seconds: 8));
      expect(BleBackoff.delayFor(5), const Duration(seconds: 16));
      // 32s would exceed the cap.
      expect(BleBackoff.delayFor(6), BleBackoff.cap);
      expect(BleBackoff.delayFor(7), BleBackoff.cap);
    });

    test('a nonsense attempt number does not produce a nonsense delay', () {
      // Retrying immediately in a tight loop is the failure mode that flattens
      // a phone battery, and attempt 0 or -1 is exactly how that bug arrives.
      expect(BleBackoff.delayFor(0), BleBackoff.base);
      expect(BleBackoff.delayFor(-5), BleBackoff.base);
      // And a runaway counter must not overflow into a negative duration.
      expect(BleBackoff.delayFor(1000), BleBackoff.cap);
      expect(BleBackoff.delayFor(1000).isNegative, isFalse);
    });

    test('the schedule is deterministic', () {
      // No jitter: one phone and one board have no herd to avoid, and a fixed
      // rhythm is one a worker can learn and a test can assert.
      expect(BleBackoff.delayFor(4), BleBackoff.delayFor(4));
    });

    test('giving up takes about a minute, not forever', () {
      // An endless "reconnecting…" spinner is a worse answer than "the board is
      // gone, use another one", because only the second is actionable.
      expect(BleBackoff.maxAttempts, 6);
      expect(BleBackoff.totalBudget, const Duration(seconds: 61));
      expect(BleBackoff.totalBudget.inMinutes, lessThanOrEqualTo(2));
    });
  });

  group('BleService.matchesSensorBoard', () {
    test('the advertised service UUID identifies a board', () {
      expect(
        BleService.matchesSensorBoard(
          name: 'Anonymous',
          serviceUuids: const ['6e400001-b5a3-f393-e0a9-e50e24dcca9e'],
        ),
        isTrue,
      );
      // UUIDs are case-insensitive on the wire; some stacks upper-case them.
      expect(
        BleService.matchesSensorBoard(
          name: '',
          serviceUuids: const ['6E400001-B5A3-F393-E0A9-E50E24DCCA9E'],
        ),
        isTrue,
      );
    });

    test('the name prefix identifies a board that advertises no service', () {
      // Firmware 1.0 shipped without the service UUID in the advertisement
      // packet, so name matching is the fallback for boards already in the field.
      expect(
        BleService.matchesSensorBoard(name: 'SwasthyaSetu Pro #A4B2'),
        isTrue,
      );
      expect(BleService.matchesSensorBoard(name: 'ssai-0031'), isTrue);
    });

    test('other radios in the room are not claimed', () {
      // The scan deliberately shows everything nearby, so this predicate is the
      // only thing separating the board from a worker's earbuds in the list.
      expect(BleService.matchesSensorBoard(name: 'Galaxy Buds'), isFalse);
      expect(BleService.matchesSensorBoard(name: 'Mi Band 5'), isFalse);
      expect(BleService.matchesSensorBoard(name: ''), isFalse);
      expect(
        BleService.matchesSensorBoard(
          name: 'Some Sensor',
          serviceUuids: const ['0000180d-0000-1000-8000-00805f9b34fb'],
        ),
        isFalse,
      );
    });
  });

  group('BleCandidate', () {
    test('signal strength maps to bars, strongest first', () {
      BleCandidate at(int rssi) => BleCandidate(
            id: 'x',
            name: 'board',
            rssi: rssi,
            isSensorBoard: true,
          );

      expect(at(-40).signalBars, 4);
      expect(at(-60).signalBars, 4);
      expect(at(-61).signalBars, 3);
      expect(at(-70).signalBars, 3);
      expect(at(-80).signalBars, 2);
      expect(at(-95).signalBars, 1);
    });

    test('an unnamed radio gets a label rather than an empty row', () {
      expect(
        const BleCandidate(id: 'x', name: '  ', rssi: -50, isSensorBoard: false)
            .displayName,
        'Unnamed device',
      );
    });
  });

  group('BleLinkState', () {
    test('reconnecting is interrupted, not failed', () {
      // A screening in progress must pause on this state and resume, because the
      // waveform captured so far is still held.
      const state = BleLinkState(
        status: BleLinkStatus.reconnecting,
        attempt: 2,
        retryIn: Duration(seconds: 2),
      );
      expect(state.isInterrupted, isTrue);
      expect(state.isBusy, isTrue);
      expect(state.isLive, isFalse);
      expect(state.detail, contains('Captured readings are kept'));
      expect(state.detail, contains('attempt 2 of 6'));
    });

    test('an unusable radio is distinguished from a device not connected', () {
      // "Bluetooth is off" and "not connected" need different buttons; collapsing
      // them sends a worker hunting for a device that the phone cannot see.
      expect(
        const BleLinkState(status: BleLinkStatus.adapterOff).isRadioUsable,
        isFalse,
      );
      expect(
        const BleLinkState(status: BleLinkStatus.unsupported).isRadioUsable,
        isFalse,
      );
      expect(
        const BleLinkState(status: BleLinkStatus.permissionDenied).isRadioUsable,
        isFalse,
      );
      expect(const BleLinkState(status: BleLinkStatus.idle).isRadioUsable, isTrue);
    });

    test('every status has a label and a detail a worker can act on', () {
      for (final status in BleLinkStatus.values) {
        final state = BleLinkState(status: status, deviceName: 'Board #1');
        expect(state.label, isNotEmpty, reason: '$status has no label');
        expect(state.detail, isNotEmpty, reason: '$status has no detail');
        // No enum names leaking into the UI.
        expect(state.label, isNot(contains('BleLinkStatus')));
        expect(state.detail, isNot(contains('BleLinkStatus')));
      }
    });

    test('an explicit message wins over the canned detail', () {
      const state = BleLinkState(
        status: BleLinkStatus.failed,
        message: 'This device does not expose the SwasthyaSetu sensor service.',
      );
      expect(state.detail, startsWith('This device does not expose'));
    });

    test('a firmware warning is surfaced without blocking the link', () {
      const state = BleLinkState(
        status: BleLinkStatus.streaming,
        firmwareVersion: '2.0.0',
        compatibility: FirmwareCompatibility.tooNew,
      );
      // Streaming and warning at the same time is the intended combination: a
      // board one version out still measures SpO2, and refusing it would leave
      // the worker with no device at all.
      expect(state.isLive, isTrue);
      expect(state.hasFirmwareWarning, isTrue);
    });

    test('copyWith can clear the retry countdown and the message', () {
      const state = BleLinkState(
        status: BleLinkStatus.reconnecting,
        retryIn: Duration(seconds: 4),
        message: 'dropped',
      );
      final cleared = state.copyWith(
        status: BleLinkStatus.streaming,
        clearRetry: true,
        clearMessage: true,
      );
      expect(cleared.retryIn, isNull);
      expect(cleared.message, isNull);
      expect(cleared.detail, isNot(contains('dropped')));
    });
  });
}
