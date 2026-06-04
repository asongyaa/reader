import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/system_tts_engine.dart';
import 'package:anx_reader/service/tts/tts_engine_adapter.dart';
import 'package:flutter/material.dart';

class TtsFactory {
  static final TtsFactory _instance = TtsFactory._internal();

  factory TtsFactory() {
    return _instance;
  }

  TtsFactory._internal();

  BaseTts? _currentTts;
  String? _lastEngineType;

  BaseTts get current {
    final engineType = Prefs().ttsEngineType;
    if (_currentTts != null && _lastEngineType == engineType) {
      return _currentTts!;
    }
    _currentTts?.dispose();
    _lastEngineType = engineType;
    _currentTts = createTts();
    return _currentTts!;
  }

  BaseTts createTts() {
    // Force SystemTTS as the stable default.
    // SherpaOnnx initBindings() has a known native crash on Android
    // (https://github.com/k2-fsa/sherpa-onnx/issues/1915).
    // Offline TTS remains available via settings but is not the default
    // until the upstream library fix lands.
    return TtsEngineAdapter(SystemTtsEngine());
  }

  Future<void> switchTtsType(String serviceId) async {
    if (Prefs().ttsService == serviceId) return;

    if (_currentTts != null) {
      await _currentTts!.stop();
      await _currentTts!.dispose();
      _currentTts = null;
    }

    Prefs().ttsService = serviceId;
    _currentTts = createTts();
  }

  Future<void> dispose() async {
    if (_currentTts != null) {
      await _currentTts!.stop();
      await _currentTts!.dispose();
      _currentTts = null;
    }
  }

  ValueNotifier<TtsStateEnum> get ttsStateNotifier {
    return current.ttsStateNotifier;
  }
}
