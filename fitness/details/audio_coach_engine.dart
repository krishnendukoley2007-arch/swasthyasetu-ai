import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioCoachEngine {
  static final AudioCoachEngine _instance = AudioCoachEngine._internal();
  factory AudioCoachEngine() => _instance;
  AudioCoachEngine._internal();

  FlutterTts? _tts;
  bool _isMuted = false;
  bool _isInitialized = false;

  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 3200);

  bool get isMuted => _isMuted;

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _tts?.stop();
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _tts = FlutterTts();
      await _tts?.setLanguage('en-US');
      await _tts?.setSpeechRate(0.52); // crisp athletic cadence
      await _tts?.setVolume(1.0);
      await _tts?.setPitch(1.06); // energetic tone
      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS init error (mock fallback active): $e');
    }
  }

  Future<void> speak(String phrase, {bool highPriority = false}) async {
    if (_isMuted) return;

    final now = DateTime.now();
    if (!highPriority && now.difference(_lastSpokenTime) < _cooldown) {
      return; // Skip if speaking too quickly
    }

    _lastSpokenTime = now;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _tts?.stop();
      await _tts?.speak(phrase);
    } catch (e) {
      debugPrint('AudioCoach speak error: $e');
    }
  }

  void speakRepCount(int rep) {
    if (rep % 5 == 0) {
      speak('$rep reps complete! Outstanding pace!', highPriority: true);
    } else if (rep == 1) {
      speak('First rep locked in!');
    }
  }

  void speakPostureAlert(String alert) {
    speak(alert, highPriority: true);
  }

  void speakZoneChange(String zoneLabel) {
    speak('Entering $zoneLabel Zone!');
  }

  void stop() {
    _tts?.stop();
  }
}
