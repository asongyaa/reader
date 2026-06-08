import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/sherpa_onnx_tts_engine.dart';
import 'package:anx_reader/service/tts/system_tts_engine.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_providers.g.dart';

@riverpod
class TtsService extends _$TtsService {
  @override
  String build() {
    return Prefs().ttsService;
  }

  void setService(String serviceId) {
    Prefs().ttsService = serviceId;
    state = serviceId;
  }
}

@riverpod
Future<List<TtsVoice>> ttsVoices(Ref ref) async {
  ref.watch(ttsServiceProvider);
  ref.watch(ttsEngineTypeProvider);
  final tts = TtsFactory().current;
  return await tts.getVoices();
}

@riverpod
class OnlineTtsConfig extends _$OnlineTtsConfig {
  @override
  Map<String, dynamic> build(String serviceId) {
    return Prefs().getOnlineTtsConfig(serviceId);
  }

  void updateConfig(String key, dynamic value) {
    final current = Map<String, dynamic>.from(state);
    current[key] = value;
    Prefs().saveOnlineTtsConfig(serviceId, current);
    state = current;
  }
}

/// Provider for the current TTS engine type.
@riverpod
class TtsEngineType extends _$TtsEngineType {
  @override
  TtsEngineTypeEnum build() {
    final stored = Prefs().ttsEngineType;
    return TtsEngineTypeEnum.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => TtsEngineTypeEnum.system,
    );
  }

  void setEngine(TtsEngineTypeEnum type) {
    Prefs().ttsEngineType = type.name;
    state = type;
  }
}

/// Provider that creates and manages the current TTS engine.
///
/// Currently returns [SystemTtsEngine]. When engine type changes,
/// disposes the old engine and creates the new one.
@riverpod
TtsEngine ttsEngine(Ref ref) {
  final engineType = ref.watch(ttsEngineTypeProvider);
  final engine = _createEngine(engineType);
  ref.onDispose(() => engine.dispose());
  return engine;
}

TtsEngine _createEngine(TtsEngineTypeEnum type) {
  return switch (type) {
    TtsEngineTypeEnum.system => SystemTtsEngine(),
    TtsEngineTypeEnum.sherpaOnnx => _createPlaceholderEngine(),
  };
}

TtsEngine _createPlaceholderEngine() {
  return SherpaOnnxTtsEngine();
}

