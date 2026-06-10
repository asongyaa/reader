import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/service/tts/tts_service_provider.dart';
import 'package:flutter/material.dart';

String getTtsEngineTypeLabel(BuildContext context, TtsEngineType type) {
  return switch (type) {
    TtsEngineType.system => L10n.of(context).settingsNarrateSystemTts,
    TtsEngineType.edge => 'Edge TTS',
    TtsEngineType.azure => L10n.of(context).settingsNarrateAzureTts,
    TtsEngineType.sherpaOnnx => L10n.of(context).ttsTypeInternal,
  };
}

TtsServiceProvider? getOnlineTtsProvider(TtsEngineType type) {
  if (!type.isOnline) return null;
  return getTtsServiceProvider(type);
}
