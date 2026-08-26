import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/environment_service.dart';
import 'package:swasthyasetu_ai/domain/models/disaster_advisory.dart';
import 'package:swasthyasetu_ai/domain/models/environment.dart';
import 'package:swasthyasetu_ai/domain/rules/environmental_rules.dart';
import 'package:swasthyasetu_ai/domain/rules/trend_engine.dart';
import 'package:swasthyasetu_ai/domain/rules/vulnerability.dart';
import 'package:swasthyasetu_ai/features/auth/state/auth_controller.dart';

/// Everything a home screen needs to render the environment card.
@immutable
class EnvironmentState {
  /// The user said yes in the app (our consent switch).
  final bool consentGranted;

  /// The OS said yes (location permission).
  final bool canLocate;

  /// Null when neither was true, the fetch failed, and nothing was cached.
  final EnvironmentReading? reading;

  /// Why there is no fresh reading, when there isn't one. Null on success.
  final EnvFailure? failure;

  const EnvironmentState({
    required this.consentGranted,
    required this.canLocate,
    this.reading,
    this.failure,
  });

  const EnvironmentState.noConsent()
      : consentGranted = false,
        canLocate = false,
        reading = null,
        failure = null;
}

final environmentServiceProvider = Provider<EnvironmentService>(
  (ref) => EnvironmentService(ref.watch(databaseProvider)),
);

/// The current environment for this device.
///
/// Consent is watched, not read: flipping the switch in the card re-runs this
/// immediately, so the card never has to poll. The fetch itself never throws
/// (see the service), which is why this is a plain FutureProvider.
final environmentProvider = FutureProvider<EnvironmentState>((ref) async {
  final consent = ref.watch(
      settingsProvider.select((s) => s.envLocationConsent));
  if (!consent) return const EnvironmentState.noConsent();

  final service = ref.watch(environmentServiceProvider);
  final canLocate = await service.canLocate();
  if (!canLocate) {
    return EnvironmentState(
      consentGranted: true,
      canLocate: false,
      reading: await service.cached(),
      failure: EnvFailure.permissionBlocked,
    );
  }

  final reading = await service.refresh();
  return EnvironmentState(
    consentGranted: true,
    canLocate: true,
    reading: reading,
    failure: service.lastFailure,
  );
});

/// Advisories for right now, personalised to the signed-in patient. A
/// clinician sees the general-population versions — advisories on their
/// dashboard are about the *area*, not the worker's body.
///
/// For patients this also folds in cross-domain insight: their own vitals
/// trend notes are combined with the environment rules, so "your pulse is
/// above your usual" and "it is dangerously hot" arrive as one honest
/// warning instead of two parallel cards neither of which adds up.
final environmentAdvisoriesProvider =
    Provider<AsyncValue<List<EnvironmentAdvisory>>>((ref) {
  final env = ref.watch(environmentProvider);
  final account = ref.watch(authStateProvider).account;
  final isPatient = account != null && account.role.isPatient;
  final flags = isPatient
      ? Vulnerability.parse(account.vulnerabilityFlags)
      : const <Vulnerability>{};

  // Watched so a fresh screening immediately re-evaluates combined insight.
  final screenings = (isPatient && account.patientId != null)
      ? ref.watch(patientScreeningsProvider(account.patientId!)).valueOrNull
      : null;

  return env.whenData((s) {
    final reading = s.reading;
    if (reading == null) return const <EnvironmentAdvisory>[];
    final base = EnvironmentalRules.evaluate(reading, vulnerability: flags);
    if (isPatient && screenings != null) {
      return EnvironmentalRules.combineWithVitals(
          base, TrendEngine.notes(screenings));
    }
    return base;
  });
});

/// The offline disaster guides bundled with the app.
final disasterAdvisoriesProvider =
    FutureProvider<List<DisasterAdvisory>>((ref) => loadDisasterAdvisories());
