import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/system_tts_engine.dart';
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
  String? get currentVoiceText => null;

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

    await _engine.init();
  }

  @override
  Future<void> speak({String? content}) async {
    updateTtsState(TtsStateEnum.playing);
    if (content != null && content.isNotEmpty) {
      await _engine.speak(content);
      return;
    }
    // Fetch from JS callbacks
    if (getHereFunction == null || getNextTextFunction == null) return;
    await getHereFunction!();
    final text = await getNextTextFunction!();
    if (text is String && text.isNotEmpty) {
      await _engine.speak(text);
    }
  }

  @override
  Future<dynamic> stop() async {
    updateTtsState(TtsStateEnum.stopped);
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
    await _engine.resume();
  }

  @override
  Future<void> prev() async {
    await stop();
    if (getPrevTextFunction == null) return;
    final text = await getPrevTextFunction!();
    if (text is String) {
      await speak(content: text);
    }
  }

  @override
  Future<void> next() async {
    await stop();
    if (getNextTextFunction == null) return;
    final text = await getNextTextFunction!();
    if (text is String) {
      await speak(content: text);
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
