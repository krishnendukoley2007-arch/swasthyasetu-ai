import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:swasthyasetu_ai/data/database/app_database.dart';

/// A person the worker can reach in an emergency. Stored locally only — contacts
/// are never uploaded, because the sync payload is aggregate/clinical data and
/// personal phone numbers have no business in it.
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;
  final int sortOrder;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = '',
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relation,
    bool? isPrimary,
    int? sortOrder,
  }) =>
      EmergencyContact(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
        isPrimary: isPrimary ?? this.isPrimary,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};
}

/// What set an SOS in motion. Kept as an enum so it can never be interpolated
/// raw into the UI.
enum SosTrigger {
  manual,
  fallDetected,
  highRisk;

  String get storageValue => switch (this) {
        SosTrigger.manual => 'MANUAL',
        SosTrigger.fallDetected => 'FALL_DETECTED',
        SosTrigger.highRisk => 'HIGH_RISK',
      };

  String get label => switch (this) {
        SosTrigger.manual => 'Sent manually',
        SosTrigger.fallDetected => 'Fall detected',
        SosTrigger.highRisk => 'High-risk reading',
      };

  static SosTrigger fromStorage(String raw) => switch (raw) {
        'FALL_DETECTED' => SosTrigger.fallDetected,
        'HIGH_RISK' => SosTrigger.highRisk,
        _ => SosTrigger.manual,
      };
}

enum SosStatus {
  dispatched,
  cancelled,
  failed;

  String get storageValue => switch (this) {
        SosStatus.dispatched => 'DISPATCHED',
        SosStatus.cancelled => 'CANCELLED',
        SosStatus.failed => 'FAILED',
      };

  String get label => switch (this) {
        SosStatus.dispatched => 'Sent',
        SosStatus.cancelled => 'Cancelled',
        SosStatus.failed => 'Failed to send',
      };

  static SosStatus fromStorage(String raw) => switch (raw) {
        'CANCELLED' => SosStatus.cancelled,
        'FAILED' => SosStatus.failed,
        _ => SosStatus.dispatched,
      };
}

/// One entry in the SOS log: who was notified, when, for which reading.
class SosEvent {
  final String id;
  final String? patientId;
  final String? screeningId;
  final SosTrigger trigger;
  final DateTime triggeredAt;
  final List<EmergencyContact> contactsNotified;
  final String message;
  final SosStatus status;
  final double? latitude;
  final double? longitude;

  const SosEvent({
    required this.id,
    required this.trigger,
    required this.triggeredAt,
    this.patientId,
    this.screeningId,
    this.contactsNotified = const [],
    this.message = '',
    this.status = SosStatus.dispatched,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  String get recipientSummary {
    if (contactsNotified.isEmpty) return 'No contacts';
    if (contactsNotified.length == 1) return contactsNotified.first.name;
    return '${contactsNotified.first.name} +${contactsNotified.length - 1} more';
  }
}

class EmergencyRepository {
  EmergencyRepository(this._db);

  final AppDatabase _db;

  // ───────────────────────────── Contacts ─────────────────────────────

  Future<List<EmergencyContact>> getContacts() async =>
      (await _db.getEmergencyContacts()).map(_toContact).toList();

  Stream<List<EmergencyContact>> watchContacts() =>
      _db.watchEmergencyContacts().map((rows) => rows.map(_toContact).toList());

  Future<EmergencyContact?> primaryContact() async {
    final all = await getContacts();
    if (all.isEmpty) return null;
    return all.firstWhere((c) => c.isPrimary, orElse: () => all.first);
  }

  Future<void> saveContact(EmergencyContact contact) async {
    // Exactly one primary. Demoting the others here keeps the invariant in one
    // place instead of trusting every call site to do it.
    if (contact.isPrimary) {
      for (final existing in await getContacts()) {
        if (existing.id != contact.id && existing.isPrimary) {
          await _db.upsertEmergencyContact(
            EmergencyContactsCompanion(
              id: Value(existing.id),
              isPrimary: const Value(false),
            ),
          );
        }
      }
    }
    await _db.upsertEmergencyContact(
      EmergencyContactsCompanion.insert(
        id: contact.id,
        name: contact.name.trim(),
        phone: normalisePhone(contact.phone),
        relation: Value(contact.relation.trim()),
        isPrimary: Value(contact.isPrimary),
        sortOrder: Value(contact.sortOrder),
      ),
    );
  }

  Future<void> deleteContact(String id) => _db.deleteEmergencyContact(id);

  /// Strips spaces, dashes, and brackets so `sms:` URIs are always well-formed.
  /// Leading `+` is preserved — it matters for international dialling.
  static String normalisePhone(String raw) {
    final trimmed = raw.trim();
    final plus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return plus ? '+$digits' : digits;
  }

  static bool isDiallable(String raw) {
    final digits = normalisePhone(raw).replaceAll('+', '');
    // Short codes (108, 112) are as valid as a 10-digit mobile here.
    return digits.length >= 3 && digits.length <= 15;
  }

  // ───────────────────────────── SOS log ─────────────────────────────

  Future<List<SosEvent>> getEvents({int limit = 100}) async =>
      (await _db.getSosEvents(limit: limit)).map(_toEvent).toList();

  Stream<List<SosEvent>> watchEvents() =>
      _db.watchSosEvents().map((rows) => rows.map(_toEvent).toList());

  Future<void> logEvent(SosEvent event) => _db.insertSosEvent(
        SosEventsCompanion.insert(
          id: event.id,
          trigger: event.trigger.storageValue,
          triggeredAt: event.triggeredAt,
          patientId: Value(event.patientId),
          screeningId: Value(event.screeningId),
          contactsNotified: Value(
            jsonEncode(event.contactsNotified.map((c) => c.toJson()).toList()),
          ),
          message: Value(event.message),
          status: Value(event.status.storageValue),
          latitude: Value(event.latitude),
          longitude: Value(event.longitude),
        ),
      );

  Future<void> clearLog() => _db.clearSosEvents();

  // ───────────────────────────── Mapping ─────────────────────────────

  static EmergencyContact _toContact(EmergencyContactRow r) => EmergencyContact(
        id: r.id,
        name: r.name,
        phone: r.phone,
        relation: r.relation,
        isPrimary: r.isPrimary,
        sortOrder: r.sortOrder,
      );

  static SosEvent _toEvent(SosEventRow r) => SosEvent(
        id: r.id,
        patientId: r.patientId,
        screeningId: r.screeningId,
        trigger: SosTrigger.fromStorage(r.trigger),
        triggeredAt: r.triggeredAt,
        contactsNotified: _decodeContacts(r.contactsNotified),
        message: r.message,
        status: SosStatus.fromStorage(r.status),
        latitude: r.latitude,
        longitude: r.longitude,
      );

  static List<EmergencyContact> _decodeContacts(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map((m) {
        return EmergencyContact(
          id: '${m['phone'] ?? ''}',
          name: '${m['name'] ?? 'Contact'}',
          phone: '${m['phone'] ?? ''}',
        );
      }).toList();
    } on FormatException {
      return const [];
    }
  }
}
