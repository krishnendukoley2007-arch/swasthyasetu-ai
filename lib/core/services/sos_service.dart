import 'package:swasthyasetu_ai/data/repositories/emergency_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

/// Where an SOS ends up. Kept separate from [SosStatus] because "the SMS app
/// opened" and "the message was delivered" are different claims, and this build
/// can only honestly make the first one.
enum SosDispatchOutcome {
  /// The messaging app was handed the recipients and the body.
  composerOpened,

  /// No contact is configured, so there was nothing to send.
  noContacts,

  /// The platform refused the `sms:` intent — no SIM, no messaging app, or the
  /// launch was denied.
  launchFailed,
}

class SosDispatchResult {
  final SosDispatchOutcome outcome;
  final List<EmergencyContact> recipients;
  final String message;
  final String? eventId;

  const SosDispatchResult({
    required this.outcome,
    this.recipients = const [],
    this.message = '',
    this.eventId,
  });

  bool get isSuccess => outcome == SosDispatchOutcome.composerOpened;

  String get failureReason => switch (outcome) {
        SosDispatchOutcome.composerOpened => '',
        SosDispatchOutcome.noContacts =>
          'No emergency contact is set up yet. Add one in Settings first.',
        SosDispatchOutcome.launchFailed =>
          'This phone could not open its messaging app. Try calling instead.',
      };
}

/// Everything an SOS message needs to say, gathered in one object so the body
/// can be composed and shown for review *before* anything is sent.
class SosPayload {
  final SosTrigger trigger;
  final String workerName;
  final String? patientName;
  final int? patientAge;
  final String? patientId;
  final String? screeningId;

  /// Humanised risk band ("High Risk"), never a raw stored `'RED'`.
  final String? riskLabel;
  final int? riskScore;
  final int? heartRate;
  final int? spo2;
  final double? temperature;

  /// Only ever populated when the worker has consented to location tagging.
  final double? latitude;
  final double? longitude;

  final String? extraNote;

  const SosPayload({
    required this.trigger,
    this.workerName = '',
    this.patientName,
    this.patientAge,
    this.patientId,
    this.screeningId,
    this.riskLabel,
    this.riskScore,
    this.heartRate,
    this.spo2,
    this.temperature,
    this.latitude,
    this.longitude,
    this.extraNote,
  });

  bool get hasLocation => latitude != null && longitude != null;
}

/// Sends emergency SMS through the platform messaging app.
///
/// SMS rather than a push or an HTTP call, deliberately: the deployment target
/// has no reliable data coverage, and an SOS that needs a working data
/// connection is an SOS that fails exactly when it is needed. A `sms:` intent
/// travels over the voice network and works at one bar with no data at all.
///
/// The app opens the composer rather than sending silently. Sending SMS without
/// user visibility needs a privileged permission that Play Store policy reserves
/// for default-SMS-handler apps, and a screening tool has no business holding
/// it. The trade is one extra tap under the countdown; the gain is that the
/// worker sees exactly what goes out and to whom.
class SosService {
  SosService(this._emergency);

  final EmergencyRepository _emergency;
  static const _uuid = Uuid();

  /// Kept short on purpose. A single SMS segment is 160 GSM-7 characters, and a
  /// message that splits can arrive out of order — or partly not at all — on a
  /// congested rural cell.
  static const int singleSegmentChars = 160;

  /// Builds the message body. Pure and synchronous so the UI can render exactly
  /// what will be sent, and so it can be unit-tested without a platform channel.
  static String composeMessage(SosPayload p) {
    final lines = <String>['EMERGENCY - SwasthyaSetu'];

    final who = [
      if (p.patientName != null && p.patientName!.trim().isNotEmpty)
        p.patientName!.trim(),
      if (p.patientAge != null) '${p.patientAge}y',
    ].join(', ');
    if (who.isNotEmpty) lines.add('Patient: $who');

    if (p.riskLabel != null) {
      lines.add(
        'Triage: ${p.riskLabel}'
        '${p.riskScore != null ? ' (${p.riskScore}/100)' : ''}',
      );
    }

    final vitals = [
      if (p.heartRate != null) 'HR ${p.heartRate}',
      if (p.spo2 != null) 'SpO2 ${p.spo2}%',
      if (p.temperature != null) 'Temp ${p.temperature!.toStringAsFixed(1)}C',
    ].join(', ');
    if (vitals.isNotEmpty) lines.add('Vitals: $vitals');

    if (p.trigger == SosTrigger.fallDetected) {
      lines.add('Possible fall detected.');
    }

    if (p.workerName.trim().isNotEmpty) {
      lines.add('Worker: ${p.workerName.trim()}');
    }

    if (p.hasLocation) {
      // A maps.google.com link rather than bare coordinates: the recipient is a
      // family member or an ASHA supervisor on a basic phone, and a tappable
      // link is the difference between "somewhere near here" and directions.
      final lat = p.latitude!.toStringAsFixed(5);
      final lon = p.longitude!.toStringAsFixed(5);
      lines.add('Location: https://maps.google.com/?q=$lat,$lon');
    }

    if (p.extraNote != null && p.extraNote!.trim().isNotEmpty) {
      lines.add(p.extraNote!.trim());
    }

    lines.add('Screening tool, not a diagnosis.');

    return lines.join('\n');
  }

  /// The `sms:` URI for [recipients] carrying [body].
  ///
  /// Built by hand rather than through `Uri(queryParameters:)` because that
  /// encodes a space as `+`, which several Android messaging apps paste into the
  /// message literally.
  static Uri smsUri(List<String> recipients, String body) {
    final numbers = recipients
        .map(EmergencyRepository.normalisePhone)
        .where((n) => n.isNotEmpty)
        .join(',');
    return Uri.parse('sms:$numbers?body=${Uri.encodeComponent(body)}');
  }

  static Uri telUri(String phone) =>
      Uri.parse('tel:${EmergencyRepository.normalisePhone(phone)}');

  /// Composes, launches and logs one SOS.
  ///
  /// The log entry is written even when the launch fails — an attempted SOS is
  /// exactly the kind of thing a supervisor needs to see afterwards.
  Future<SosDispatchResult> dispatch(SosPayload payload) async {
    final contacts = await _emergency.getContacts();
    final reachable =
        contacts.where((c) => EmergencyRepository.isDiallable(c.phone)).toList();
    final body = composeMessage(payload);

    if (reachable.isEmpty) {
      return SosDispatchResult(
        outcome: SosDispatchOutcome.noContacts,
        message: body,
      );
    }

    var launched = false;
    try {
      launched = await launchUrl(
        smsUri(reachable.map((c) => c.phone).toList(), body),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // A missing messaging app or a blocked intent surfaces as a
      // PlatformException. It is a failed send, not a crash.
      launched = false;
    }

    final eventId = _uuid.v4();
    await _emergency.logEvent(
      SosEvent(
        id: eventId,
        patientId: payload.patientId,
        screeningId: payload.screeningId,
        trigger: payload.trigger,
        triggeredAt: DateTime.now(),
        contactsNotified: reachable,
        message: body,
        status: launched ? SosStatus.dispatched : SosStatus.failed,
        latitude: payload.latitude,
        longitude: payload.longitude,
      ),
    );

    return SosDispatchResult(
      outcome: launched
          ? SosDispatchOutcome.composerOpened
          : SosDispatchOutcome.launchFailed,
      recipients: reachable,
      message: body,
      eventId: eventId,
    );
  }

  /// Records an SOS the worker stopped during the countdown.
  ///
  /// Logged rather than discarded: a run of cancelled fall alerts is the signal
  /// that the detector is too sensitive, and that is only visible if the
  /// cancellations are kept.
  Future<void> logCancellation(SosPayload payload) => _emergency.logEvent(
        SosEvent(
          id: _uuid.v4(),
          patientId: payload.patientId,
          screeningId: payload.screeningId,
          trigger: payload.trigger,
          triggeredAt: DateTime.now(),
          message: composeMessage(payload),
          status: SosStatus.cancelled,
        ),
      );

  /// Places a voice call. Offered alongside SMS because a call gets attention
  /// that a text message may not, and it needs no data connection either.
  Future<bool> call(String phone) async {
    try {
      return await launchUrl(telUri(phone), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
