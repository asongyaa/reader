import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/sherpa_onnx_tts_engine.dart';
import 'package:anx_reader/service/tts/system_tts_engine.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:flutter/material.dart';

/// Adapter that wraps a [TtsEngine] to conform to the legacy [BaseTts] API.
///
/// This allows incremental migration: existing callers (TtsHandler, widgets)
/// continue to work through the adapter while the engine implementation
/// already uses the new TtsEngine interface.
class TtsEngineAdapter extends BaseTts {
  final TtsEngine _engine;

  TtsEngineAdapter(this._engine);

  // Callbacks for sentence navigation (set by TtsHandler)
  Function? getHereFunction;
  Function? getNextTextFunction;
  Function? getPrevTextFunction;

  String? _currentVoiceText;

  /// Notifies UI when the currently spoken sentence changes.
  final ValueNotifier<String?> currentSentenceNotifier = ValueNotifier(null);

  @override
  final ValueNotifier<TtsStateEnum> ttsStateNotifier =
      ValueNotifier<TtsStateEnum>(TtsStateEnum.stopped);

  @override
  void updateTtsState(TtsStateEnum newState) {
    ttsStateNotifier.value = newState;
  }

  @override
  bool get isPlaying => ttsStateNotifier.value == TtsStateEnum.playing;

  @override
  String? get currentVoiceText => _currentVoiceText;

  void _setCurrentText(String? text) {
    _currentVoiceText = text;
    currentSentenceNotifier.value = text;
  }

  @override
  double get volume => 1.0;
  @override
  set volume(double v) {}

  @override
  double get pitch => 1.0;
  @override
  set pitch(double p) {}

  @override
  double get rate => 1.0;
  @override
  set rate(double r) {}

  @override
  Future<void> init(Function getCurrentText, Function getNextText,
      Function getPrevText) async {
    getHereFunction = getCurrentText;
    getNextTextFunction = getNextText;
    getPrevTextFunction = getPrevText;

    final engine = _engine;
    if (engine is SystemTtsEngine) {
      engine.setCallbacks(
        getHere: getCurrentText,
        getNextText: getNextText,
        getPrevText: getPrevText,
      );
    }

    if (engine is SherpaOnnxTtsEngine) {
      engine.peekNextText = () async {
        try {
          final state = epubPlayerKey.currentState;
          if (state == null) return null;
          final text = await state.ttsPrepare();
          if (text.isNotEmpty) return text;
        } catch (_) {}
        return null;
      };
    }

    await _engine.init();
  }

  @override
  Future<void> setVoice(String voiceId) async {
    await _engine.setVoice(voiceId);
  }

  @override
  Future<void> speak({String? content}) async {
    updateTtsState(TtsStateEnum.playing);
    if (content != null && content.isNotEmpty) {
      _setCurrentText(content);
      await _engine.speak(content);
      // 单句试听完成后重置状态，避免污染全局阅读页状态
      if (ttsStateNotifier.value == TtsStateEnum.playing) {
        updateTtsState(TtsStateEnum.stopped);
      }
      return;
    }
    if (getHereFunction == null || getNextTextFunction == null) {
      TtsDebugLogger().log('TtsEngineAdapter: missing callbacks, abort speak');
      return;
    }
    try { await getHereFunction!(); } catch (_) {}

    String? text;
    try {
      final result = await getNextTextFunction!();
      if (result is String) text = result;
    } catch (e) {
      TtsDebugLogger().log('TtsEngineAdapter: getNextText error: $e');
    }
    if (text == null || text.isEmpty) {
      TtsDebugLogger().log('TtsEngineAdapter: no initial text, abort speak');
      return;
    }

    _setCurrentText(text);
    await _engine.speak(text);

    if (_engine.autoChainsSentences) return;

    // 引擎不自动链式播放，适配器自己驱动
    while (ttsStateNotifier.value == TtsStateEnum.playing) {
      String? next;
      try {
        final result = await getNextTextFunction!();
        if (result is String) next = result;
      } catch (e) {
        TtsDebugLogger().log('TtsEngineAdapter: chain getNextText error: $e');
        break;
      }
      if (next == null || next.isEmpty) break;
      if (ttsStateNotifier.value != TtsStateEnum.playing) break;
      _setCurrentText(next);
      await _engine.speak(next);
    }
  }

  @override
  Future<dynamic> stop() async {
    updateTtsState(TtsStateEnum.stopped);
    _setCurrentText(null);
    await _engine.stop();
    return 0;
  }

  @override
  Future<void> pause() async {
    await _engine.pause();
    updateTtsState(TtsStateEnum.paused);
  }

  @override
  Future<void> resume() async {
    updateTtsState(TtsStateEnum.playing);
    if (_engine is SherpaOnnxTtsEngine) {
      // 从当前句重新播放
      String? current;
      try {
        final result = await getHereFunction!();
        if (result is String && result.isNotEmpty) current = result;
      } catch (_) {}
      if (current != null) {
        _setCurrentText(current);
        await _engine.speak(current);
      }
      // 继续链式播放
      while (ttsStateNotifier.value == TtsStateEnum.playing) {
        final result = await getNextTextFunction!();
        if (result is! String || result.isEmpty) break;
        _setCurrentText(result);
        await _engine.speak(result);
      }
    } else {
      await _engine.resume();
    }
  }

  @override
  Future<void> prev() async {
    await _engine.stop();
    if (getPrevTextFunction == null) return;
    final text = await getPrevTextFunction!();
    if (text is String && text.isNotEmpty) {
      _setCurrentText(text);
      updateTtsState(TtsStateEnum.playing);
      await _engine.speak(text);
    }
  }

  @override
  Future<void> next() async {
    await _engine.stop();
    if (getNextTextFunction == null) return;
    final text = await getNextTextFunction!();
    if (text is String && text.isNotEmpty) {
      _setCurrentText(text);
      updateTtsState(TtsStateEnum.playing);
      await _engine.speak(text);
    }
  }

  @override
  Future<void> restart() async {
    await stop();
    await speak();
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    return await _engine.getVoices();
  }

  @override
  Future<void> dispose() async {
    await _engine.dispose();
  }
}
