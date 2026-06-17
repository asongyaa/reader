import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tts_providers.g.dart';

final ttsEngineTypeProvider = StateProvider<String>((ref) {
  return Prefs().ttsEngineType;
});

@Riverpod(keepAlive: true)
Future<List<TtsVoice>> ttsVoices(Ref ref) async {
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
