import 'package:anx_reader/service/tts/models/tts_voice.dart';

/// Abstract interface for all TTS engine implementations.
///
/// Concrete implementations:
/// - [SystemTtsEngine] - wraps flutter_tts (OS-level TTS)
/// - [SherpaOnnxTtsEngine] - offline on-device TTS (Phase 3)
abstract class TtsEngine {
  /// Human-readable engine name (e.g. "System TTS", "Offline TTS").
  String get name;

  /// Whether this engine requires downloading a model before use.
  bool get requiresModelDownload;

  /// Initialize the engine (load models, prepare audio resources).
  Future<void> init();

  /// Speak the given [text].
  Future<void> speak(String text);

  /// Stop speaking immediately.
  Future<void> stop();

  /// Pause speaking (supports resume).
  Future<void> pause();

  /// Resume from paused state.
  Future<void> resume();

  /// Stream of progress events during playback.
  Stream<TtsProgress> get progressStream;

  /// Get available voices for this engine.
  Future<List<TtsVoice>> getVoices();

  /// Select a voice by [voiceId].
  Future<void> setVoice(String voiceId);

  /// Set speech rate (speed). Range: 0.5 - 2.0
  Future<void> setSpeed(double rate);

  /// Set speech pitch. Range: 0.5 - 2.0
  Future<void> setPitch(double pitch);

  /// Release all resources.
  Future<void> dispose();

  /// Whether the engine internally chains to the next sentence after
  /// finishing the current one. System TTS does this via flutter_tts'
  /// completion handler; offline engines like SherpaONNX do not, and rely on
  /// the adapter to call back into the reader for the next sentence.
  bool get autoChainsSentences => false;
}

/// Progress information during TTS playback.
class TtsProgress {
  final int sentenceIndex;
  final int charStart;
  final int charEnd;
  final String currentText;

  const TtsProgress({
    required this.sentenceIndex,
    required this.charStart,
    required this.charEnd,
    required this.currentText,
  });
}

/// Unified enum for TTS engine types.
enum TtsEngineType {
  system,
  edge,
  azure,
  sherpaOnnx;

  String get label {
    return switch (this) {
      TtsEngineType.system => 'System TTS',
      TtsEngineType.edge => 'Edge TTS',
      TtsEngineType.azure => 'Azure TTS',
      TtsEngineType.sherpaOnnx => 'Offline TTS',
    };
  }

  bool get isOnline => this == TtsEngineType.edge || this == TtsEngineType.azure;

  bool get requiresConfig => this == TtsEngineType.azure;

  bool get requiresModelDownload => this == TtsEngineType.sherpaOnnx;
}

@Deprecated('Use TtsEngineType instead')
enum TtsEngineTypeEnum {
  system,
  sherpaOnnx;

  String get label {
    return switch (this) {
      TtsEngineTypeEnum.system => 'System TTS',
      TtsEngineTypeEnum.sherpaOnnx => 'Offline TTS',
    };
  }
}
