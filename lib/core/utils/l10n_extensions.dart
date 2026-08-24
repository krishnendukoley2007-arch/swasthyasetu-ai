/// The bridge between the generated `AppLocalizations` and the rest of the app.
///
/// Two things live here.
///
/// `context.l10n` exists so a widget can reach a string in one word instead of
/// `AppLocalizations.of(context)`. It is a getter, not a cached field, because
/// the locale can change while the app is running and a cached reference would
/// keep serving the old language.
///
/// The vocabulary extension exists because the triage words are needed from
/// places that have no `BuildContext` — `risk_presentation.dart` is a pure
/// function file, and a switch over `RiskBand` cannot look up a translation on
/// its own. Rather than thread a context through those helpers, they take an
/// optional `AppLocalizations` and fall back to English. That fallback is the
/// reason a missed call site degrades to the wrong language rather than to a
/// crash or an empty label in front of a health worker.
library;

import 'package:flutter/widgets.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/l10n/generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The clinical vocabulary, keyed off the same storage strings the database and
/// the rule engine already use.
///
/// Every method takes the raw stored form and is total: an unrecognised code
/// resolves to the same "not classified"/"routine" wording the English helpers
/// use, so a firmware or schema change cannot produce a blank label.
extension AppVocabulary on AppLocalizations {
  String riskBandLabel(RiskBand band) => switch (band) {
        RiskBand.green => triageBandGreen,
        RiskBand.yellow => triageBandYellow,
        RiskBand.red => triageBandRed,
      };

  String riskBandShortLabel(RiskBand band) => switch (band) {
        RiskBand.green => triageBandGreenShort,
        RiskBand.yellow => triageBandYellowShort,
        RiskBand.red => triageBandRedShort,
      };

  String syncStatusLabel(String raw) => switch (raw.toUpperCase()) {
        'SYNCED' => syncUploaded,
        'SYNCING' => syncUploading,
        'FAILED' => syncFailed,
        _ => syncWaiting,
      };

  String escalationText(String raw) => switch (raw.toUpperCase()) {
        'EMERGENCY' => escalationEmergency,
        'CLINIC_VISIT' => escalationClinicVisit,
        'FOLLOW_UP' => escalationFollowUp,
        _ => escalationRoutine,
      };

  String ecgRhythmText(String raw) => switch (raw.toUpperCase()) {
        'SINUS_RHYTHM' => rhythmRegular,
        'TACHYCARDIA' => rhythmFast,
        'BRADYCARDIA' => rhythmSlow,
        'IRREGULAR' => rhythmIrregular,
        'NOISY' => rhythmNoisy,
        _ => rhythmUnclassified,
      };

  String bpConfidenceText(String raw) => switch (raw.toUpperCase()) {
        'CALIBRATED' => bpCalibrated,
        'ESTIMATED' => bpEstimated,
        _ => bpExperimental,
      };

  String symptomDurationText(String raw) => switch (raw) {
        '< 24 hours' => durationUnder24h,
        '1-3 days' => duration1to3Days,
        '4-7 days' => duration4to7Days,
        '1-2 weeks' => duration1to2Weeks,
        '> 2 weeks' => durationOver2Weeks,
        // Free-typed or legacy values are shown as stored rather than dropped.
        _ => raw,
      };
}
