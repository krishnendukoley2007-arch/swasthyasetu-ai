import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/models/patient.dart';

/// The screening being taken right now, across the four screens it spans.
///
/// It exists because the flow used to lose its subject: the worker picked a
/// patient on the first step and `context.go('/screening/live')` carried none of
/// it forward, so the triage screen had no idea who it was assessing, scored
/// every reading against adult defaults, and saved nothing to the database. A
/// screening app that forgets which patient it screened is a demo.
///
/// Held in a provider rather than passed through `GoRouter.extra` because the
/// waveform is filled in on one screen, the symptoms on another, and the row is
/// written on a third — three writers, one record.
@immutable
class ScreeningDraft {
  /// Null when the flow was entered sideways (deep link, or the demo route
  /// opened directly). Screens must degrade to a read-only preview rather than
  /// inventing a patient.
  final Patient? patient;

  final String deviceId;
  final String deviceName;
  final bool isDemoDevice;

  final HealthSample? sample;

  /// Raw ECG as captured, at [ecgSampleRate]. Kept out of [sample] because it is
  /// the one field measured in kilobytes, and it goes to a file rather than a
  /// database column.
  final List<int> ecgSamples;
  final int ecgSampleRate;

  final List<String> symptoms;
  final String? symptomDuration;
  final String? symptomNotes;

  final DateTime? startedAt;

  /// Set once the row has been written, so revisiting triage does not create a
  /// second record for the same reading.
  final String? savedScreeningId;

  const ScreeningDraft({
    this.patient,
    this.deviceId = '',
    this.deviceName = '',
    this.isDemoDevice = true,
    this.sample,
    this.ecgSamples = const [],
    this.ecgSampleRate = 250,
    this.symptoms = const [],
    this.symptomDuration,
    this.symptomNotes,
    this.startedAt,
    this.savedScreeningId,
  });

  bool get hasPatient => patient != null;
  bool get isSaved => savedScreeningId != null;

  ScreeningDraft copyWith({
    Patient? patient,
    String? deviceId,
    String? deviceName,
    bool? isDemoDevice,
    HealthSample? sample,
    List<int>? ecgSamples,
    int? ecgSampleRate,
    List<String>? symptoms,
    String? symptomDuration,
    String? symptomNotes,
    DateTime? startedAt,
    String? savedScreeningId,
  }) =>
      ScreeningDraft(
        patient: patient ?? this.patient,
        deviceId: deviceId ?? this.deviceId,
        deviceName: deviceName ?? this.deviceName,
        isDemoDevice: isDemoDevice ?? this.isDemoDevice,
        sample: sample ?? this.sample,
        ecgSamples: ecgSamples ?? this.ecgSamples,
        ecgSampleRate: ecgSampleRate ?? this.ecgSampleRate,
        symptoms: symptoms ?? this.symptoms,
        symptomDuration: symptomDuration ?? this.symptomDuration,
        symptomNotes: symptomNotes ?? this.symptomNotes,
        startedAt: startedAt ?? this.startedAt,
        savedScreeningId: savedScreeningId ?? this.savedScreeningId,
      );
}

class ScreeningDraftController extends StateNotifier<ScreeningDraft> {
  ScreeningDraftController() : super(const ScreeningDraft());

  /// Starts a fresh draft. Deliberately replaces rather than merges: carrying a
  /// previous patient's symptoms into the next household visit would be the
  /// worst possible bug in this app.
  void begin({required Patient patient, Device? device}) {
    state = ScreeningDraft(
      patient: patient,
      deviceId: device?.id ?? '',
      deviceName: device?.name ?? '',
      isDemoDevice: device?.isDemo ?? true,
      startedAt: DateTime.now(),
    );
  }

  void setSample(
    HealthSample sample, {
    List<int>? ecgSamples,
    int? ecgSampleRate,
  }) {
    state = state.copyWith(
      sample: sample,
      ecgSamples: ecgSamples,
      ecgSampleRate: ecgSampleRate,
      startedAt: state.startedAt ?? DateTime.now(),
    );
  }

  /// Attach a waveform without touching the vitals.
  ///
  /// Separate from [setSample] because the ECG screen has a strip and no reason
  /// to have a [HealthSample]: forcing one through [setSample] would mean either
  /// inventing vitals or refusing to save a perfectly good trace.
  ///
  /// Pass `generated: true` for a trace the app drew rather than measured. That
  /// forces the draft to demo and cannot be undone here — provenance only ever
  /// moves towards "not a real reading", so a synthetic strip cannot launder a
  /// screening into looking measured.
  void setEcg(List<int> samples, {int? sampleRate, bool generated = false}) {
    state = state.copyWith(
      ecgSamples: samples,
      ecgSampleRate: sampleRate,
      isDemoDevice: generated ? true : null,
      startedAt: state.startedAt ?? DateTime.now(),
    );
  }

  void setSymptoms(
    List<String> symptoms, {
    String? duration,
    String? notes,
  }) {
    state = state.copyWith(
      symptoms: symptoms,
      symptomDuration: duration,
      symptomNotes: notes,
    );
  }

  void markSaved(String screeningId) {
    state = state.copyWith(savedScreeningId: screeningId);
  }

  void clear() => state = const ScreeningDraft();
}

final screeningDraftProvider =
    StateNotifierProvider<ScreeningDraftController, ScreeningDraft>(
  (ref) => ScreeningDraftController(),
);
