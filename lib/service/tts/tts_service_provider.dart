import 'dart:typed_data';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/config/service_provider.dart';
import 'package:anx_reader/service/tts/azure_tts_backend.dart';
import 'package:anx_reader/service/tts/edge_tts_backend.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:flutter/widgets.dart';

export 'package:anx_reader/service/config/config_item.dart';

/// Base class for all TTS service providers.
///
/// Subclasses must implement:
/// - [engineType]: The TTS engine type enum value.
/// - [getLabel]: The display label.
/// - For online TTS services:
///   - [speak]: Generate speech audio from text.
///   - [getVoices]: Get available voices.
///   - [getConfigItems]: Configuration items.
///   - [getConfig] / [saveConfig]: Configuration management.
abstract class TtsServiceProvider extends ServiceProvider<TtsEngineType> {
  @override
  TtsEngineType get service => engineType;

  String get serviceId => engineType.name;

  TtsEngineType get engineType;

  /// The display label for this service.
  @override
  String getLabel(BuildContext context);

  /// Generate speech audio from text.
  /// Only required for online TTS services.
  /// System TTS doesn't use this method.
  Future<Uint8List> speak(
      String text, String? voice, double rate, double pitch) async {
    throw UnimplementedError('speak() not implemented for $engineType');
  }

  /// Get available voices for this TTS service.
  /// Returns empty list for system TTS (handled separately).
  Future<List<TtsVoice>> getVoices() async {
    return [];
  }

  /// Convert voice data from API response to TtsVoice model.
  /// Only needed for online TTS services.
  TtsVoice convertVoiceModel(dynamic voiceData) {
    throw UnimplementedError(
        'convertVoiceModel() not implemented for $engineType');
  }

  /// Get the currently selected voice for this service.
  String getSelectedVoice() {
    return Prefs().getTtsVoiceModel(serviceId);
  }

  /// Persist the selected voice for this service.
  void setSelectedVoice(String voice) {
    Prefs().setTtsVoiceModel(serviceId, voice);
  }

  /// Resolve the voice to use, optionally overriding the saved selection.
  String resolveVoice(String? voiceOverride) {
    if (voiceOverride != null && voiceOverride.isNotEmpty) {
      return voiceOverride;
    }
    final selected = getSelectedVoice();
    if (selected.isEmpty) {
      return _fallbackVoice;
    }
    return selected;
  }

  String get _fallbackVoice {
    if (engineType == TtsEngineType.edge) return 'zh-CN-XiaoxiaoNeural';
    if (engineType == TtsEngineType.azure) return 'zh-CN-XiaoxiaoNeural';
    return '';
  }
}

TtsServiceProvider getTtsServiceProvider(TtsEngineType engineType) {
  return switch (engineType) {
    TtsEngineType.edge => EdgeTtsProvider(),
    TtsEngineType.azure => AzureTtsProvider(),
    TtsEngineType.system => throw ArgumentError(
        'System TTS does not use TtsServiceProvider'),
    TtsEngineType.sherpaOnnx => throw ArgumentError(
        'Offline TTS does not use TtsServiceProvider'),
  };
}
