import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/online_tts.dart';
import 'package:anx_reader/service/tts/sherpa_onnx_tts_engine.dart';
import 'package:anx_reader/service/tts/system_tts_engine.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
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
    final engineType = Prefs().ttsEngineType;
    final type = TtsEngineType.values.firstWhere(
      (e) => e.name == engineType,
      orElse: () => TtsEngineType.system,
    );
    TtsDebugLogger().log('TtsFactory: creating engine type=${type.name}');
    return switch (type) {
      TtsEngineType.system => TtsEngineAdapter(SystemTtsEngine()),
      TtsEngineType.edge => OnlineTts(),
      TtsEngineType.azure => OnlineTts(),
      TtsEngineType.sherpaOnnx => TtsEngineAdapter(SherpaOnnxTtsEngine()),
    };
  }

  Future<void> switchEngineType(String engineType, {bool forceRecreate = false}) async {
    if (!forceRecreate && _lastEngineType == engineType && _currentTts != null) return;
    if (_currentTts != null) {
      await _currentTts!.stop();
      await _currentTts!.dispose();
      _currentTts = null;
    }
    Prefs().ttsEngineType = engineType;
    _lastEngineType = engineType;
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
