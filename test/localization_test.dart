import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/utils/l10n_extensions.dart';
import 'package:swasthyasetu_ai/core/utils/risk_presentation.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/l10n/generated/app_localizations.dart';

/// What the three shipped locales must guarantee.
///
/// The .arb files held two keys each before this pass, so every screen was
/// English regardless of the language a worker had chosen. The properties below
/// are the ones that make the setting mean something: the critical-path keys
/// resolve in all three languages, none of them silently falls back to English,
/// and the triage vocabulary — the words a worker acts on — is translated rather
/// than left in the source language.

const _locales = [Locale('en'), Locale('hi'), Locale('bn')];

/// One representative key per critical path.
List<String Function(AppLocalizations)> get _criticalKeys => [
      (l) => l.navHome,
      (l) => l.navPatients,
      (l) => l.navScreening,
      (l) => l.navSos,
      (l) => l.navSettings,
      (l) => l.homeOverview,
      (l) => l.homeStatToday,
      (l) => l.homeStatPending,
      (l) => l.screeningNewTitle,
      (l) => l.screeningStepPlaceFinger,
      (l) => l.screeningNoBoard,
      (l) => l.symptomsTitle,
      (l) => l.symptomsContinue,
      (l) => l.triageTitle,
      (l) => l.triageBandGreen,
      (l) => l.triageBandYellow,
      (l) => l.triageBandRed,
      (l) => l.triageNotADiagnosis,
      (l) => l.escalationEmergency,
      (l) => l.sosTitle,
      (l) => l.sosStart,
      (l) => l.sosNoContactsBody,
      (l) => l.consentTitle,
      (l) => l.consentLocation,
      (l) => l.consentAi,
      (l) => l.consentSync,
      (l) => l.actionCancel,
      (l) => l.actionRetry,
    ];

Future<AppLocalizations> _load(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  group('supported locales', () {
    test('every locale declared in main is actually shipped', () {
      for (final locale in _locales) {
        expect(
          AppLocalizations.supportedLocales
              .any((l) => l.languageCode == locale.languageCode),
          isTrue,
          reason: '${locale.languageCode} is offered in settings but not built',
        );
      }
    });

    for (final locale in _locales) {
      test('${locale.languageCode} resolves every critical-path key', () async {
        final l10n = await _load(locale);
        for (var i = 0; i < _criticalKeys.length; i++) {
          final value = _criticalKeys[i](l10n);
          expect(value.trim(), isNotEmpty,
              reason: 'key #$i is empty in ${locale.languageCode}');
        }
      });
    }

    test('hi and bn are not silently serving the English strings', () async {
      final en = await _load(const Locale('en'));
      for (final locale in [const Locale('hi'), const Locale('bn')]) {
        final other = await _load(locale);
        var identical = 0;
        for (final key in _criticalKeys) {
          if (key(en) == key(other)) identical++;
        }
        // A handful of collisions would be legitimate (brand names, "SOS").
        // Wholesale equality means the .arb never got translated.
        expect(identical, lessThan(_criticalKeys.length ~/ 4),
            reason: '${locale.languageCode} matches English on $identical of '
                '${_criticalKeys.length} keys');
      }
    });
  });

  group('triage vocabulary', () {
    test('every band, sync state and escalation level has a word in each locale',
        () async {
      for (final locale in _locales) {
        final l10n = await _load(locale);
        for (final band in RiskBand.values) {
          expect(l10n.riskBandLabel(band).trim(), isNotEmpty);
          expect(l10n.riskBandShortLabel(band).trim(), isNotEmpty);
        }
        for (final status in ['PENDING', 'SYNCED', 'SYNCING', 'FAILED']) {
          expect(l10n.syncStatusLabel(status).trim(), isNotEmpty);
        }
        for (final level in ['EMERGENCY', 'CLINIC_VISIT', 'FOLLOW_UP']) {
          expect(l10n.escalationText(level).trim(), isNotEmpty);
        }
        for (final rhythm in [
          'SINUS_RHYTHM',
          'TACHYCARDIA',
          'BRADYCARDIA',
          'IRREGULAR',
          'NOISY',
        ]) {
          expect(l10n.ecgRhythmText(rhythm).trim(), isNotEmpty);
        }
      }
    });

    test('an unknown code falls through to a real word, never a blank',
        () async {
      final l10n = await _load(const Locale('bn'));
      expect(l10n.ecgRhythmText('SOMETHING_NEW'), l10n.rhythmUnclassified);
      expect(l10n.escalationText('WHATEVER'), l10n.escalationRoutine);
      expect(l10n.syncStatusLabel(''), l10n.syncWaiting);
      expect(l10n.bpConfidenceText('X'), l10n.bpExperimental);
    });

    test('RiskStyle keeps its colours and icons when it is localized', () async {
      final l10n = await _load(const Locale('hi'));
      for (final band in RiskBand.values) {
        final plain = RiskStyle.of(band);
        final localized = RiskStyle.of(band, l10n);
        expect(localized.color, plain.color);
        expect(localized.icon, plain.icon);
        expect(localized.band, plain.band);
        expect(localized.label, l10n.riskBandLabel(band));
        expect(localized.label, isNot(plain.label));
      }
    });

    test('omitting the localizations leaves the English wording intact', () {
      // Contextless callers — exports, logs, the SMS body — still get a word.
      expect(RiskStyle.ofStorage('RED').label, 'Urgent');
      expect(escalationLabel('EMERGENCY'), 'Seek care now');
      expect(ecgRhythmLabel('TACHYCARDIA'), 'Fast rhythm');
      expect(bpConfidenceLabel('CALIBRATED'), 'Calibrated estimate');
      expect(SyncStyle.of('FAILED').label, 'Upload failed');
    });

    test('symptom durations translate for display but not for storage',
        () async {
      final l10n = await _load(const Locale('bn'));
      // The stored form is what the rule engine and the exports see.
      expect(l10n.symptomDurationText('1-3 days'), isNot('1-3 days'));
      // Anything unrecognised is shown as stored rather than dropped.
      expect(l10n.symptomDurationText('since Tuesday'), 'since Tuesday');
    });
  });
}
