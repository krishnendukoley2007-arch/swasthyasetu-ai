import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthyasetu_ai/core/services/audio_coach_scripts.dart';
import 'package:swasthyasetu_ai/core/services/audio_coach_service.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';
import 'package:swasthyasetu_ai/features/screening/state/audio_coach_controller.dart';
import 'package:swasthyasetu_ai/features/screening/widgets/what_is_my_situation_card.dart';

void main() {
  group('AudioCoachLanguage tests', () {
    test('fromCode maps language codes correctly', () {
      expect(AudioCoachLanguage.fromCode('hi'), AudioCoachLanguage.hindi);
      expect(AudioCoachLanguage.fromCode('hi-IN'), AudioCoachLanguage.hindi);
      expect(AudioCoachLanguage.fromCode('bn'), AudioCoachLanguage.bengali);
      expect(AudioCoachLanguage.fromCode('bn-in'), AudioCoachLanguage.bengali);
      expect(AudioCoachLanguage.fromCode('en'), AudioCoachLanguage.english);
      expect(AudioCoachLanguage.fromCode('other'), AudioCoachLanguage.english);
    });

    test('ttsLocale matches standards', () {
      expect(AudioCoachLanguage.hindi.ttsLocale, 'hi-IN');
      expect(AudioCoachLanguage.bengali.ttsLocale, 'bn-IN');
      expect(AudioCoachLanguage.english.ttsLocale, 'en-IN');
    });
  });

  group('AudioCoachScripts tests', () {
    test('breathing scripts return non-empty strings across all languages', () {
      for (final lang in AudioCoachLanguage.values) {
        expect(AudioCoachScripts.breathingSessionStart(lang), isNotEmpty);
        expect(AudioCoachScripts.breathingInhaleCue(lang), isNotEmpty);
        expect(AudioCoachScripts.breathingExhaleCue(lang), isNotEmpty);
        expect(AudioCoachScripts.breathingCompletion(lang, 5), contains('5'));
      }
    });

    test(
      'hydration scripts return specific advice for heatwave and elderly',
      () {
        final hindiHot = AudioCoachScripts.hydrationPrompt(
          lang: AudioCoachLanguage.hindi,
          isHotWeather: true,
        );
        expect(hindiHot, contains('धूप'));
        expect(hindiHot, contains('पानी'));

        final bengaliElderly = AudioCoachScripts.hydrationPrompt(
          lang: AudioCoachLanguage.bengali,
          isElderly: true,
        );
        expect(bengaliElderly, contains('পিপাসা'));

        final englishGeneral = AudioCoachScripts.hydrationPrompt(
          lang: AudioCoachLanguage.english,
        );
        expect(englishGeneral, contains('clean water'));
      },
    );

    test(
      'whatIsMySituation generates empathetic human-like scripts for all bands',
      () {
        final sample = HealthSample.demo(
          heartRateBpm: 74,
          spo2Percent: 98,
          temperatureC: 36.6,
          ecgSignalQuality: 0.95,
          rrIntervalMs: 810,
        );

        // Hindi Green
        final hiGreen = AudioCoachScripts.whatIsMySituation(
          lang: AudioCoachLanguage.hindi,
          band: RiskBand.green,
          sample: sample,
          patientName: 'सुनीता देवी',
        );
        expect(hiGreen, contains('सुनीता देवी'));
        expect(hiGreen, contains('74'));
        expect(hiGreen, contains('98'));
        expect(hiGreen, contains('सामान्य'));

        // Bengali Yellow
        final bnYellow = AudioCoachScripts.whatIsMySituation(
          lang: AudioCoachLanguage.bengali,
          band: RiskBand.yellow,
          sample: sample,
          patientName: 'রহিম মিয়া',
        );
        expect(bnYellow, contains('রহিম মিয়া'));
        expect(bnYellow, contains('নজর দেওয়া'));

        // English Red
        final redSample = HealthSample.demo(
          heartRateBpm: 125,
          spo2Percent: 88,
          temperatureC: 39.2,
          ecgSignalQuality: 0.85,
          rrIntervalMs: 480,
        );
        final enRed = AudioCoachScripts.whatIsMySituation(
          lang: AudioCoachLanguage.english,
          band: RiskBand.red,
          sample: redSample,
          dehydrationScore: 4.5,
        );
        expect(enRed, contains('108 ambulance'));
        expect(enRed, contains('critical strain'));
        expect(enRed, contains('dehydration'));
      },
    );
  });

  group('AudioCoachService & Notifier tests', () {
    test('AudioCoachService handles speech lifecycle in test mode', () async {
      final service = AudioCoachService(isTestMode: true);

      expect(service.currentState.isIdle, isTrue);

      await service.speak(text: 'नमस्ते', language: AudioCoachLanguage.hindi);

      expect(service.currentState.status, AudioCoachStatus.speaking);
      expect(service.currentState.progress, 0.5);

      await service.pause();
      expect(service.currentState.status, AudioCoachStatus.paused);

      await service.resume();
      expect(service.currentState.status, AudioCoachStatus.speaking);

      await service.stop();
      expect(service.currentState.status, AudioCoachStatus.idle);

      service.dispose();
    });

    test('AudioCoachNotifier triggers situation assessment speech', () async {
      final service = AudioCoachService(isTestMode: true);
      final notifier = AudioCoachNotifier(service, AudioCoachLanguage.hindi);

      final sample = HealthSample.demo(
        heartRateBpm: 72,
        spo2Percent: 97,
        temperatureC: 36.6,
        ecgSignalQuality: 0.9,
        rrIntervalMs: 830,
      );

      await notifier.speakWhatIsMySituation(
        band: RiskBand.green,
        sample: sample,
        patientName: 'चाची',
      );

      expect(notifier.state.spokenText, contains('चाची'));
      expect(notifier.state.selectedLanguage, AudioCoachLanguage.hindi);

      notifier.setLanguage(AudioCoachLanguage.bengali);
      expect(notifier.state.selectedLanguage, AudioCoachLanguage.bengali);

      notifier.toggleBreathingVoice(false);
      expect(notifier.state.isBreathingVoiceEnabled, isFalse);

      notifier.dispose();
    });
  });

  group('WhatIsMySituationCard widget tests', () {
    testWidgets(
      'renders properly and allows language switching and transcript viewing',
      (tester) async {
        final testService = AudioCoachService(isTestMode: true);
        final sample = HealthSample.demo(
          heartRateBpm: 78,
          spo2Percent: 98,
          temperatureC: 36.6,
          ecgSignalQuality: 0.92,
          rrIntervalMs: 770,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioCoachServiceProvider.overrideWithValue(testService),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WhatIsMySituationCard(
                    band: RiskBand.green,
                    sample: sample,
                    patientName: 'आरती',
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Card is displayed with audio button
        expect(find.byIcon(Icons.record_voice_over_rounded), findsOneWidget);
        expect(
          find.byType(ChoiceChip),
          findsNWidgets(3),
        ); // Hindi, Bengali, English

        // Tap Bengali language chip
        await tester.tap(find.text('বাংলা'));
        await tester.pumpAndSettle();

        // Verify title switches to Bengali
        expect(find.text('শুনে নিন: আমার অবস্থা কেমন?'), findsOneWidget);

        // Tap Play/Listen button
        final playButton = find.byType(FilledButton);
        expect(playButton, findsOneWidget);
        await tester.tap(playButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Expand transcript
        final viewTextButton = find.text('বক্তব্য লেখা দেখুন (View Text)');
        expect(viewTextButton, findsOneWidget);
        await tester.tap(viewTextButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Spoken text appears in the transcript
        expect(find.textContaining('স্বাস্থ্য সাথী'), findsWidgets);
      },
    );
  });
}
