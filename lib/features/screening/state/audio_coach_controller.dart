import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swasthyasetu_ai/core/providers/providers.dart';
import 'package:swasthyasetu_ai/core/services/audio_coach_scripts.dart';
import 'package:swasthyasetu_ai/core/services/audio_coach_service.dart';
import 'package:swasthyasetu_ai/domain/models/health_sample.dart';
import 'package:swasthyasetu_ai/domain/rules/risk_engine.dart';

final audioCoachServiceProvider = Provider<AudioCoachService>((ref) {
  final service = AudioCoachService();
  ref.onDispose(service.dispose);
  return service;
});

class AudioCoachState {
  final AudioCoachPlaybackState playbackState;
  final AudioCoachLanguage selectedLanguage;
  final bool isBreathingVoiceEnabled;

  const AudioCoachState({
    this.playbackState = const AudioCoachPlaybackState(),
    this.selectedLanguage = AudioCoachLanguage.hindi,
    this.isBreathingVoiceEnabled = true,
  });

  bool get isSpeaking => playbackState.isSpeaking;
  bool get isPaused => playbackState.isPaused;
  bool get isIdle => playbackState.isIdle;
  double get progress => playbackState.progress;
  String get spokenText => playbackState.text;

  AudioCoachState copyWith({
    AudioCoachPlaybackState? playbackState,
    AudioCoachLanguage? selectedLanguage,
    bool? isBreathingVoiceEnabled,
  }) {
    return AudioCoachState(
      playbackState: playbackState ?? this.playbackState,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isBreathingVoiceEnabled:
          isBreathingVoiceEnabled ?? this.isBreathingVoiceEnabled,
    );
  }
}

class AudioCoachNotifier extends StateNotifier<AudioCoachState> {
  final AudioCoachService _service;
  StreamSubscription<AudioCoachPlaybackState>? _subscription;

  AudioCoachNotifier(this._service, AudioCoachLanguage initialLanguage)
    : super(AudioCoachState(selectedLanguage: initialLanguage)) {
    _subscription = _service.stateStream.listen((playback) {
      state = state.copyWith(playbackState: playback);
    });
  }

  void setLanguage(AudioCoachLanguage language) {
    if (state.selectedLanguage == language) return;
    state = state.copyWith(selectedLanguage: language);
    // If currently playing, stop so next speech starts in new language
    if (state.isSpeaking) {
      _service.stop();
    }
  }

  void toggleBreathingVoice(bool enabled) {
    state = state.copyWith(isBreathingVoiceEnabled: enabled);
    if (!enabled && state.isSpeaking) {
      _service.stop();
    }
  }

  Future<void> speakWhatIsMySituation({
    required RiskBand band,
    required HealthSample sample,
    String? patientName,
    int? score,
    List<String> symptoms = const [],
    double? dehydrationScore,
    String? trajectorySummary,
  }) async {
    final script = AudioCoachScripts.whatIsMySituation(
      lang: state.selectedLanguage,
      band: band,
      sample: sample,
      patientName: patientName,
      score: score,
      symptoms: symptoms,
      dehydrationScore: dehydrationScore,
      trajectorySummary: trajectorySummary,
    );

    await _service.speak(text: script, language: state.selectedLanguage);
  }

  Future<void> speakHydration({
    bool isHotWeather = false,
    bool isElderly = false,
  }) async {
    final script = AudioCoachScripts.hydrationPrompt(
      lang: state.selectedLanguage,
      isHotWeather: isHotWeather,
      isElderly: isElderly,
    );

    await _service.speak(text: script, language: state.selectedLanguage);
  }

  Future<void> speakBreathingCue({required bool isInhaling}) async {
    if (!state.isBreathingVoiceEnabled) return;

    final script = isInhaling
        ? AudioCoachScripts.breathingInhaleCue(state.selectedLanguage)
        : AudioCoachScripts.breathingExhaleCue(state.selectedLanguage);

    await _service.speak(text: script, language: state.selectedLanguage);
  }

  Future<void> speakBreathingCompletion(int cycles) async {
    if (!state.isBreathingVoiceEnabled) return;

    final script = AudioCoachScripts.breathingCompletion(
      state.selectedLanguage,
      cycles,
    );

    await _service.speak(text: script, language: state.selectedLanguage);
  }

  Future<void> pause() => _service.pause();
  Future<void> resume() => _service.resume();
  Future<void> stop() => _service.stop();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final audioCoachControllerProvider =
    StateNotifierProvider<AudioCoachNotifier, AudioCoachState>((ref) {
      final service = ref.watch(audioCoachServiceProvider);
      final appLangCode = ref.watch(settingsProvider).locale.languageCode;
      final initialLang = AudioCoachLanguage.fromCode(appLangCode);

      return AudioCoachNotifier(service, initialLang);
    });
