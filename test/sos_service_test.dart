import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/sos_service.dart';
import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';

/// The message body and the `sms:` URI are the two things that must be exactly
/// right, because a worker under pressure will not proofread them and a garbled
/// recipient list means the SOS reaches nobody.
void main() {
  group('composeMessage — always present', () {
    test('leads with the emergency marker', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body.split('\n').first, 'EMERGENCY - SwasthyaSetu');
    });

    test('always ends with the not-a-diagnosis disclaimer', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body.split('\n').last, 'Screening tool, not a diagnosis.');
    });

    test('a completely empty payload still produces a sendable message', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body.split('\n'), hasLength(2));
      expect(body.trim(), isNotEmpty);
    });
  });

  group('composeMessage — optional fields are omitted, never blank', () {
    test('no patient means no Patient line at all', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body, isNot(contains('Patient:')));
    });

    test('a name with no age omits the age, not the line', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, patientName: 'Ratna Devi'),
      );
      expect(body, contains('Patient: Ratna Devi'));
      expect(body, isNot(contains('null')));
      expect(body, isNot(contains('Patient: Ratna Devi,')));
    });

    test('a whitespace-only name is treated as absent', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, patientName: '   '),
      );
      expect(body, isNot(contains('Patient:')));
    });

    test('an age with no name still reports the age', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, patientAge: 67),
      );
      expect(body, contains('Patient: 67y'));
    });

    test('no vitals means no Vitals line', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body, isNot(contains('Vitals:')));
    });

    test('a partial vitals set lists only what was measured', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, heartRate: 132),
      );
      expect(body, contains('Vitals: HR 132'));
      expect(body, isNot(contains('SpO2')));
      expect(body, isNot(contains('Temp')));
    });

    test('no risk band means no Triage line', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body, isNot(contains('Triage:')));
    });

    // Nothing in the payload is ever interpolated raw, so no stored enum value
    // can leak into a message a family member reads.
    test('never contains a raw stored band value', () {
      final body = SosService.composeMessage(
        const SosPayload(
          trigger: SosTrigger.manual,
          riskLabel: 'High Risk',
          riskScore: 78,
        ),
      );
      expect(body, contains('Triage: High Risk (78/100)'));
      expect(body, isNot(contains('RED')));
      expect(body, isNot(contains('YELLOW')));
      expect(body, isNot(contains('GREEN')));
    });

    test('a risk band with no score omits the parenthetical', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, riskLabel: 'High Risk'),
      );
      expect(body, contains('Triage: High Risk'));
      expect(body, isNot(contains('(')));
    });
  });

  group('composeMessage — vitals formatting', () {
    test('temperature is fixed to one decimal', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, temperature: 39.4567),
      );
      expect(body, contains('Temp 39.5C'));
    });

    test('a whole-number temperature still shows a decimal', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual, temperature: 38),
      );
      expect(body, contains('Temp 38.0C'));
    });

    test('all three vitals share one comma-separated line', () {
      final body = SosService.composeMessage(
        const SosPayload(
          trigger: SosTrigger.manual,
          heartRate: 128,
          spo2: 88,
          temperature: 39.1,
        ),
      );
      expect(body, contains('Vitals: HR 128, SpO2 88%, Temp 39.1C'));
    });
  });

  group('composeMessage — the fall trigger', () {
    test('a fall says so, so the recipient knows why nobody is answering', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.fallDetected),
      );
      expect(body, contains('Possible fall detected.'));
    });

    test('a manual SOS does not claim a fall', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body, isNot(contains('fall')));
    });

    test('a high-risk trigger does not claim a fall', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.highRisk),
      );
      expect(body, isNot(contains('fall')));
    });
  });

  group('composeMessage — location', () {
    test('is absent unless both coordinates are present', () {
      expect(
        SosService.composeMessage(
          const SosPayload(trigger: SosTrigger.manual, latitude: 22.5726),
        ),
        isNot(contains('Location:')),
      );
      expect(
        SosService.composeMessage(
          const SosPayload(trigger: SosTrigger.manual, longitude: 88.3639),
        ),
        isNot(contains('Location:')),
      );
    });

    test('renders a tappable maps link at five decimal places', () {
      // Five decimals is ~1 m, which is as precise as a phone GPS fix is
      // honest about anyway.
      final body = SosService.composeMessage(
        const SosPayload(
          trigger: SosTrigger.manual,
          latitude: 22.5726461,
          longitude: 88.3638782,
        ),
      );
      expect(
        body,
        contains('Location: https://maps.google.com/?q=22.57265,88.36388'),
      );
    });

    test('handles southern and western hemispheres', () {
      final body = SosService.composeMessage(
        const SosPayload(
          trigger: SosTrigger.manual,
          latitude: -33.86880,
          longitude: -70.12345,
        ),
      );
      expect(body, contains('q=-33.86880,-70.12345'));
    });
  });

  group('composeMessage — length', () {
    test('a full real-world payload fits in one SMS segment', () {
      final body = SosService.composeMessage(
        const SosPayload(
          trigger: SosTrigger.fallDetected,
          workerName: 'Sunita Das',
          patientName: 'Ratna Devi',
          patientAge: 67,
          riskLabel: 'High Risk',
          riskScore: 82,
          heartRate: 128,
          spo2: 87,
          temperature: 39.2,
          latitude: 22.572646,
          longitude: 88.363895,
        ),
      );

      // Not a style preference: a multi-segment SMS can arrive out of order, or
      // partly not at all, on a congested rural cell.
      expect(
        body.length,
        lessThanOrEqualTo(SosService.singleSegmentChars * 2),
        reason: 'a fully populated SOS must stay within two segments\n$body',
      );
    });

    test('the minimum message is tiny', () {
      final body = SosService.composeMessage(
        const SosPayload(trigger: SosTrigger.manual),
      );
      expect(body.length, lessThan(SosService.singleSegmentChars));
    });
  });

  group('smsUri', () {
    test('joins multiple recipients with commas', () {
      final uri = SosService.smsUri(['+91 98765 43210', '108'], 'hi');
      expect(uri.scheme, 'sms');
      expect(uri.path, '+919876543210,108');
    });

    test('strips formatting from numbers', () {
      final uri = SosService.smsUri(['+91-98765 43210'], 'hi');
      expect(uri.path, '+919876543210');
    });

    test('drops recipients that normalise to nothing', () {
      final uri = SosService.smsUri(['', '   ', '108'], 'hi');
      expect(uri.path, '108');
    });

    // The reason smsUri is hand-built rather than using Uri(queryParameters:):
    // that encoder turns a space into '+', which several Android messaging apps
    // paste into the message body literally.
    test('encodes spaces as %20, never as +', () {
      final uri = SosService.smsUri(['108'], 'Patient: Ratna Devi');
      final raw = uri.toString();
      expect(raw, contains('%20'));
      expect(
        raw.split('?body=').last,
        isNot(contains('+')),
        reason: 'a + here arrives as a literal + in the message',
      );
    });

    test('encodes newlines so the multi-line body survives the intent', () {
      final uri = SosService.smsUri(['108'], 'line one\nline two');
      expect(uri.toString(), contains('%0A'));
    });

    test('round-trips a real composed body unchanged', () {
      final body = SosService.composeMessage(
        const SosPayload(
          trigger: SosTrigger.fallDetected,
          patientName: 'Ratna Devi',
          patientAge: 67,
          heartRate: 128,
          latitude: 22.572646,
          longitude: 88.363895,
        ),
      );
      final uri = SosService.smsUri(['108'], body);
      final decoded =
          Uri.decodeComponent(uri.toString().split('?body=').last);
      expect(decoded, body);
    });
  });

  group('telUri', () {
    test('normalises before dialling', () {
      expect(SosService.telUri('+91 98765 43210').toString(),
          'tel:+919876543210');
    });

    test('leaves a short emergency number intact', () {
      expect(SosService.telUri('108').toString(), 'tel:108');
    });
  });

  group('SosDispatchResult', () {
    test('only composerOpened counts as success', () {
      expect(
        const SosDispatchResult(outcome: SosDispatchOutcome.composerOpened)
            .isSuccess,
        isTrue,
      );
      expect(
        const SosDispatchResult(outcome: SosDispatchOutcome.noContacts)
            .isSuccess,
        isFalse,
      );
      expect(
        const SosDispatchResult(outcome: SosDispatchOutcome.launchFailed)
            .isSuccess,
        isFalse,
      );
    });

    test('every failure explains itself and success stays silent', () {
      expect(
        const SosDispatchResult(outcome: SosDispatchOutcome.composerOpened)
            .failureReason,
        isEmpty,
      );
      for (final outcome in [
        SosDispatchOutcome.noContacts,
        SosDispatchOutcome.launchFailed,
      ]) {
        expect(
          SosDispatchResult(outcome: outcome).failureReason,
          isNotEmpty,
          reason: '$outcome must tell the worker what to do instead',
        );
      }
    });
  });

  group('EmergencyRepository.isDiallable — the SOS recipient gate', () {
    test('accepts the three-digit national emergency numbers', () {
      for (final n in ['108', '112', '104', '102']) {
        expect(EmergencyRepository.isDiallable(n), isTrue, reason: n);
      }
    });

    test('accepts a full mobile number in any formatting', () {
      for (final n in [
        '9876543210',
        '+91 98765 43210',
        '+91-98765-43210',
        '098765 43210',
      ]) {
        expect(EmergencyRepository.isDiallable(n), isTrue, reason: n);
      }
    });

    test('rejects what cannot be dialled', () {
      for (final n in ['', '  ', '12', 'not a number', '1234567890123456']) {
        expect(EmergencyRepository.isDiallable(n), isFalse, reason: '"$n"');
      }
    });
  });

  group('SosTrigger / SosStatus — humanised for display', () {
    test('every trigger has a human label that is not its storage value', () {
      for (final t in SosTrigger.values) {
        expect(t.label, isNotEmpty);
        expect(t.label, isNot(equals(t.storageValue)));
        expect(t.label, isNot(contains('_')));
      }
    });

    test('every status has a human label', () {
      for (final s in SosStatus.values) {
        expect(s.label, isNotEmpty);
        expect(s.label, isNot(contains('_')));
      }
    });

    test('storage values round-trip', () {
      for (final t in SosTrigger.values) {
        expect(SosTrigger.fromStorage(t.storageValue), t);
      }
      for (final s in SosStatus.values) {
        expect(SosStatus.fromStorage(s.storageValue), s);
      }
    });

    test('an unknown stored value falls back rather than throwing', () {
      expect(SosTrigger.fromStorage('WHAT'), SosTrigger.manual);
      expect(SosStatus.fromStorage(''), SosStatus.dispatched);
    });
  });
}
