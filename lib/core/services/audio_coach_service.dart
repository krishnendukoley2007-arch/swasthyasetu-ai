import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:swasthyasetu_ai/core/services/audio_coach_scripts.dart';

/// Playback status of the audio coach.
enum AudioCoachStatus { idle, speaking, paused, completed, error }

/// Represents the current reactive state of spoken voice guidance.
@immutable
class AudioCoachPlaybackState {
  final AudioCoachStatus status;
  final AudioCoachLanguage language;
  final String text;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;

  const AudioCoachPlaybackState({
    this.status = AudioCoachStatus.idle,
    this.language = AudioCoachLanguage.hindi,
    this.text = '',
    this.progress = 0.0,
    this.errorMessage,
  });

  bool get isSpeaking => status == AudioCoachStatus.speaking;
  bool get isPaused => status == AudioCoachStatus.paused;
  bool get isIdle => status == AudioCoachStatus.idle;

  AudioCoachPlaybackState copyWith({
    AudioCoachStatus? status,
    AudioCoachLanguage? language,
    String? text,
    double? progress,
    String? errorMessage,
  }) {
    return AudioCoachPlaybackState(
      status: status ?? this.status,
      language: language ?? this.language,
      text: text ?? this.text,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
    );
  }
}

/// Offline Multilingual Audio Coach Service.
///
/// Wraps Android's native offline TTS engine using `flutter_tts` with
/// parameters specifically calibrated for a compassionate, human-like voice cadence:
/// - Speech Rate: 0.45 (soothing, unhurried cadence for rural elders)
/// - Pitch: 1.0 (natural human tone)
/// - Offline locales: `hi-IN` (Hindi), `bn-IN` (Bengali), `en-IN` (English)
class AudioCoachService {
  final FlutterTts _tts;
  final bool _isTestMode;

  final _stateController =
      StreamController<AudioCoachPlaybackState>.broadcast();
  AudioCoachPlaybackState _currentState = const AudioCoachPlaybackState();

  AudioCoachPlaybackState get currentState => _currentState;
  Stream<AudioCoachPlaybackState> get stateStream => _stateController.stream;

  AudioCoachService({FlutterTts? tts, bool isTestMode = false})
    : _tts = tts ?? FlutterTts(),
      _isTestMode = isTestMode {
    _initTts();
  }

  void _initTts() {
    if (_isTestMode) return;

    try {
      _tts.setStartHandler(() {
        _updateState(_currentState.copyWith(status: AudioCoachStatus.speaking));
      });

      _tts.setCompletionHandler(() {
        _updateState(
          _currentState.copyWith(
            status: AudioCoachStatus.completed,
            progress: 1.0,
          ),
        );
      });

      _tts.setCancelHandler(() {
        _updateState(_currentState.copyWith(status: AudioCoachStatus.idle));
      });

      _tts.setPauseHandler(() {
        _updateState(_currentState.copyWith(status: AudioCoachStatus.paused));
      });

      _tts.setContinueHandler(() {
        _updateState(_currentState.copyWith(status: AudioCoachStatus.speaking));
      });

      _tts.setErrorHandler((msg) {
        _updateState(
          _currentState.copyWith(
            status: AudioCoachStatus.error,
            errorMessage: msg.toString(),
          ),
        );
      });

      _tts.setProgressHandler((text, start, end, word) {
        if (text.isNotEmpty) {
          final p = (end / text.length).clamp(0.0, 1.0);
          _updateState(_currentState.copyWith(progress: p));
        }
      });
    } catch (_) {
      // Safe fallback if platform channels are unavailable in headless runs
    }
  }

  void _updateState(AudioCoachPlaybackState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_currentState);
    }
  }

  /// Speaks the given text in the requested language.
  Future<void> speak({
    required String text,
    AudioCoachLanguage language = AudioCoachLanguage.hindi,
  }) async {
    if (text.trim().isEmpty) return;

    _updateState(
      _currentState.copyWith(
        status: AudioCoachStatus.speaking,
        language: language,
        text: text,
        progress: 0.0,
      ),
    );

    if (_isTestMode) {
      // Test environment simulation: enter speaking state
      _updateState(
        _currentState.copyWith(
          status: AudioCoachStatus.speaking,
          progress: 0.5,
        ),
      );
      return;
    }

    try {
      await _tts.stop();
      await _tts.setLanguage(language.ttsLocale);

      // Calibrated soothing human-like cadence for rural community health
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Attempt on-device speech synthesis
      await _tts.speak(text);
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: AudioCoachStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Pauses current speech playback.
  Future<void> pause() async {
    if (_currentState.status != AudioCoachStatus.speaking) return;

    if (_isTestMode) {
      _updateState(_currentState.copyWith(status: AudioCoachStatus.paused));
      return;
    }

    try {
      await _tts.pause();
      _updateState(_currentState.copyWith(status: AudioCoachStatus.paused));
    } catch (_) {
      _updateState(_currentState.copyWith(status: AudioCoachStatus.paused));
    }
  }

  /// Resumes speech if paused.
  Future<void> resume() async {
    if (_currentState.status != AudioCoachStatus.paused) return;

    if (_isTestMode) {
      _updateState(_currentState.copyWith(status: AudioCoachStatus.speaking));
      return;
    }

    try {
      if (_currentState.text.isNotEmpty) {
        await speak(text: _currentState.text, language: _currentState.language);
      }
    } catch (_) {}
  }

  /// Stops playback and resets state to idle.
  Future<void> stop() async {
    if (_isTestMode) {
      _updateState(_currentState.copyWith(status: AudioCoachStatus.idle));
      return;
    }

    try {
      await _tts.stop();
    } catch (_) {}

    _updateState(
      _currentState.copyWith(status: AudioCoachStatus.idle, progress: 0.0),
    );
  }

  void dispose() {
    stop();
    _stateController.close();
  }
}
