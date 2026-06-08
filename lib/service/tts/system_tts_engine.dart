import 'dart:async';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/utils/platform_utils.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// System TTS engine implementation wrapping [FlutterTts].
///
/// This is the only file that should directly import `flutter_tts`.
/// All other code uses [TtsEngine] interface.
class SystemTtsEngine implements TtsEngine {
  final FlutterTts _flutterTts = FlutterTts();

  final StreamController<TtsProgress> _progressController =
      StreamController<TtsProgress>.broadcast();

  String? _currentVoiceText;
  String? _prevVoiceText;

  // ── Chaining callbacks (mirroring old SystemTts) ──────────────
  bool restarting = false;
  Function? getHereFunction;
  Function? getNextTextFunction;
  Function? getPrevTextFunction;

  bool get isIOS => AnxPlatform.isIOS;
  bool get isAndroid => AnxPlatform.isAndroid;
  bool get isWindows => AnxPlatform.isWindows;
  bool get isWeb => kIsWeb;

  @override
  String get name => 'System TTS';

  @override
  bool get requiresModelDownload => false;

  @override
  bool get autoChainsSentences => true;

  // ── TtsEngine interface ───────────────────────────────────────

  @override
  Future<void> init() async {
    try {
      await _setAwaitOptions();

      if (isAndroid) {
        await _getDefaultEngine();
        await _getDefaultVoice();
      }

      _flutterTts.setStartHandler(() async {
        if (!isAndroid) return;
        _prevVoiceText = _currentVoiceText;
        final state = epubPlayerKey.currentState;
        if (state == null) return;
        _currentVoiceText = await state.ttsPrepare();
        if (_currentVoiceText?.isNotEmpty ?? false) {
          await _flutterTts.speak(_currentVoiceText!);
        }
      });

      _flutterTts.setCompletionHandler(() async {
        if (!isAndroid) return;
        if (_currentVoiceText?.isEmpty ?? true) {
          if (getNextTextFunction == null) return;
          _currentVoiceText = await getNextTextFunction!();
          if (_currentVoiceText?.isNotEmpty ?? false) {
            await _setAwaitOptions();
            await _flutterTts.setVolume(Prefs().ttsVolume);
            await _flutterTts.setSpeechRate(Prefs().ttsRate);
            await _flutterTts.setPitch(Prefs().ttsPitch);
            await _flutterTts.speak(_currentVoiceText!);
          }
        } else {
          // Next sentence already queued by startHandler, just advance cursor
          if (getNextTextFunction != null) await getNextTextFunction!();
        }
      });
    } catch (e, stack) {
      debugPrint('SystemTtsEngine init error: $e\n$stack');
    }
  }

  /// Public setter for callbacks, called by TtsEngineAdapter.
  void setCallbacks({
    required Function getHere,
    required Function getNextText,
    required Function getPrevText,
  }) {
    getHereFunction = getHere;
    getNextTextFunction = getNextText;
    getPrevTextFunction = getPrevText;
  }

  @override
  Future<void> speak(String text) async {
    try {
      // Called with the FIRST sentence from the adapter.
      _currentVoiceText = text;

      await _setAwaitOptions();
      await _flutterTts.setVolume(Prefs().ttsVolume);
      await _flutterTts.setSpeechRate(Prefs().ttsRate);
      await _flutterTts.setPitch(Prefs().ttsPitch);

      if (_currentVoiceText != null) {
        await _flutterTts.speak(_currentVoiceText!);
      }

      // Non-Android: chain next sentence immediately after current finishes
      if (!isAndroid) {
        if (getNextTextFunction == null) return;
        _currentVoiceText = await getNextTextFunction!();
        if (_currentVoiceText?.isNotEmpty ?? false) {
          await speak(_currentVoiceText!);
        }
      }
    } catch (e, stack) {
      debugPrint('SystemTtsEngine speak error: $e\n$stack');
    }
  }

  /// Speak with a specific voice (used in settings preview).
  Future<void> speakWithVoice(String content, String voiceShortName) async {
    await stop();
    await _flutterTts.setVolume(Prefs().ttsVolume);
    await _flutterTts.setSpeechRate(Prefs().ttsRate);
    await _flutterTts.setPitch(Prefs().ttsPitch);
    await _flutterTts.setVoice({'name': voiceShortName});
    await _flutterTts.speak(content);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
    _currentVoiceText = null;
  }

  @override
  Future<void> pause() async {
    await _flutterTts.stop();
  }

  @override
  Future<void> resume() async {
    if (isAndroid && _prevVoiceText != null) {
      await speak(_prevVoiceText!);
    } else if (_currentVoiceText != null) {
      await speak(_currentVoiceText!);
    }
  }

  // ── Navigation methods ───────────────────────────────────────

  Future<void> prev() async {
    if (restarting) return;
    restarting = true;
    await stop();
    if (getPrevTextFunction == null) {
      restarting = false;
      return;
    }
    _currentVoiceText = await getPrevTextFunction!();
    if (_currentVoiceText?.isNotEmpty ?? false) {
      await speak(_currentVoiceText!);
    }
    restarting = false;
  }

  Future<void> next() async {
    if (restarting) return;
    restarting = true;
    await stop();
    if (getNextTextFunction == null) {
      restarting = false;
      return;
    }
    _currentVoiceText = await getNextTextFunction!();
    if (_currentVoiceText?.isNotEmpty ?? false) {
      await speak(_currentVoiceText!);
    }
    restarting = false;
  }

  @override
  Stream<TtsProgress> get progressStream => _progressController.stream;

  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        return voices.map((e) {
          final map = Map<String, dynamic>.from(e);
          return TtsVoice(
            shortName: map['name'] ?? '',
            name: map['name'] ?? '',
            locale: map['locale']?.replaceAll('_', '-') ?? '',
            gender: map['gender']?.toString().toLowerCase() ?? '',
            rawData: map,
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> setVoice(String voiceId) async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        for (final voice in voices) {
          final map = Map<String, dynamic>.from(voice);
          if (map['name'] == voiceId) {
            await _flutterTts.setVoice({
              'name': map['name'],
              'locale': map['locale'],
            });
            return;
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> setSpeed(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> dispose() async {
    await _flutterTts.stop();
    await _progressController.close();
  }

  // ── Internal helpers ──────────────────────────────────────────

  Future<void> _setAwaitOptions() async {
    await _flutterTts.awaitSpeakCompletion(true);
    if (isAndroid) {
      await _flutterTts.awaitSynthCompletion(true);
      await _flutterTts.setQueueMode(1);
    }
  }

  Future<void> _getDefaultEngine() async {
    await _flutterTts.getDefaultEngine;
  }

  Future<void> _getDefaultVoice() async {
    await _flutterTts.getDefaultVoice;
  }
}
