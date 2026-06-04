import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/offline_tts_model_manager.dart';
import 'package:anx_reader/service/tts/sentence_splitter.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Offline TTS engine based on sherpa-onnx.
///
/// Supports VITS-melo (zh-en bilingual) and VITS-aishell3 (174 voices)
/// model formats with sid-based voice selection.
class SherpaOnnxTtsEngine implements TtsEngine {
  OfflineTts? _tts;
  bool _initialized = false;
  bool _shouldStop = false;
  int _currentSid = 0;
  double _currentSpeed = 1.0;
  TtsModelType _currentModelType = TtsModelType.vitsMeloZhEn;

  /// Native bindings must be initialized exactly once per app lifetime.
  static bool _bindingsInitialized = false;

  AudioPlayer? _player;
  final StreamController<TtsProgress> _progressController =
      StreamController<TtsProgress>.broadcast();

  /// Optional: map role names to SIDs for multi-voice synthesis.
  /// Example: {' narrator': 0, ' Alice': 45, ' Bob': 89 }
  final Map<String, int> roleSidMap = {};

  @override
  String get name => 'Offline TTS';

  @override
  bool get requiresModelDownload => true;

  /// Set the model type to use. Call [init] after changing.
  void setModelType(TtsModelType type) {
    if (_initialized) {
      _tts?.free();
      _tts = null;
      _initialized = false;
    }
    _currentModelType = type;
  }

  /// Set the speaker ID (voice). For aishell3: 0-173.
  void setSid(int sid) {
    _currentSid = sid;
  }

  int get currentSid => _currentSid;

  int get maxSid => _currentModelType.sidCount - 1;

  @override
  Future<void> init() async {
    final log = TtsDebugLogger();
    if (_initialized) {
      log.log('SherpaONNX: already initialized');
      return;
    }

    log.log('SherpaONNX: init() started');

    String? modelPath;
    try {
      modelPath = await OfflineTtsModelManager().getModelPath(_currentModelType)
          ?? await OfflineTtsModelManager().findAnyModel();
    } catch (e) {
      log.log('SherpaONNX: model path lookup failed: $e');
      return;
    }

    if (modelPath == null) {
      log.log('SherpaONNX: 离线模型未下载');
      return;
    }
    log.log('SherpaONNX: modelPath=$modelPath');

    final dir = Directory(modelPath);
    if (!await dir.exists()) {
      log.log('SherpaONNX: 模型目录不存在: $modelPath');
      return;
    }

    final allFiles = await dir.list(recursive: true).toList();
    log.log('SherpaONNX: found ${allFiles.length} files');
    for (final f in allFiles.whereType<File>().take(20)) {
      log.log('  file: ${f.path}');
    }

    File? onnxFile;
    try {
      onnxFile = allFiles.whereType<File>().firstWhere(
        (f) => f.path.split(Platform.pathSeparator).last == 'model.onnx',
        orElse: () => allFiles.whereType<File>().firstWhere(
          (f) => f.path.endsWith('.onnx'),
          orElse: () => throw Exception('未找到 .onnx 文件'),
        ),
      );
    } catch (e) {
      log.log('SherpaONNX: .onnx file not found: $e');
      return;
    }

    File? tokensFile;
    try {
      tokensFile = allFiles.whereType<File>().firstWhere(
        (f) => f.path.split(Platform.pathSeparator).last.toLowerCase() == 'tokens.txt',
        orElse: () => allFiles.whereType<File>().firstWhere(
          (f) => f.path.toLowerCase().endsWith('tokens.txt'),
          orElse: () => throw Exception('未找到 tokens.txt 文件'),
        ),
      );
    } catch (e) {
      log.log('SherpaONNX: tokens.txt not found: $e');
      return;
    }

    log.log('SherpaONNX: onnx=${onnxFile.path}');
    log.log('SherpaONNX: tokens=${tokensFile.path}');

    if (!_bindingsInitialized) {
      log.log('SherpaONNX: calling initBindings()...');
      try {
        initBindings();
        _bindingsInitialized = true;
        log.log('SherpaONNX: initBindings() succeeded');
      } catch (e, stack) {
        log.log('SherpaONNX: initBindings() failed: $e');
        log.log(stack.toString());
        return;
      }
    } else {
      log.log('SherpaONNX: initBindings() already done, skipping');
    }

    log.log('SherpaONNX: creating OfflineTts config...');
    try {
      final config = OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          vits: OfflineTtsVitsModelConfig(
            model: onnxFile.path,
            tokens: tokensFile.path,
          ),
          numThreads: 4,
          debug: false,
          provider: 'cpu',
        ),
      );
      log.log('SherpaONNX: calling OfflineTts(config)...');
      _tts = OfflineTts(config);
      log.log('SherpaONNX: OfflineTts created successfully');
    } catch (e, stack) {
      log.log('SherpaONNX: OfflineTts creation failed: $e');
      log.log(stack.toString());
      return;
    }

    _initialized = true;
    log.log('SherpaONNX: init() completed successfully');
  }

  @override
  Future<void> speak(String text) async {
    final log = TtsDebugLogger();
    log.log('SherpaONNX: speak() called, text=${text.length} chars');

    if (!_initialized || _tts == null) {
      log.log('SherpaONNX: not initialized, calling init()...');
      await init();
      if (_tts == null) {
        log.log('SherpaONNX: init() did not produce _tts, aborting speak()');
        return;
      }
    }

    _shouldStop = false;

    final sentences = SentenceSplitter.split(text);
    if (sentences.isEmpty) {
      log.log('SherpaONNX: no sentences to speak');
      return;
    }
    log.log('SherpaONNX: sentences=${sentences.length}');

    for (int i = 0; i < sentences.length; i++) {
      if (_shouldStop) break;
      final sentence = sentences[i];
      if (sentence.trim().isEmpty) continue;

      log.log('SherpaONNX: generating sentence $i');
      GeneratedAudio? audio;
      try {
        audio = _tts!.generate(text: sentence, sid: _currentSid, speed: _currentSpeed);
        log.log('SherpaONNX: generated ${audio.samples.length} samples @ ${audio.sampleRate}Hz');
      } catch (e, stack) {
        log.log('SherpaONNX: generate error: $e');
        log.log(stack.toString());
        continue;
      }

      if (_shouldStop) break;
      if (audio.samples.isNotEmpty) {
        await _playAudio(audio);
      }
    }
    log.log('SherpaONNX: speak() done');
  }

  Future<AudioPlayer> _ensurePlayer() async {
    _player ??= AudioPlayer();
    return _player!;
  }

  Future<void> _playAudio(GeneratedAudio audio) async {
    final log = TtsDebugLogger();
    try {
      final player = await _ensurePlayer();
      final completer = Completer<void>();
      final wavBytes = _floatSamplesToWav(audio.samples, audio.sampleRate);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavBytes);
      log.log('SherpaONNX: wav written ${wavBytes.length} bytes');

      player.onPlayerComplete.first.then((_) {
        if (!completer.isCompleted) completer.complete();
      });

      await player.play(DeviceFileSource(tempFile.path));
      log.log('SherpaONNX: playing audio...');
      await completer.future;
      try { await tempFile.delete(); } catch (_) {}
    } catch (e, stack) {
      log.log('SherpaONNX: playAudio error: $e');
      log.log(stack.toString());
    }
  }

  Uint8List _floatSamplesToWav(Float32List samples, int sampleRate) {
    final pcmData = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcmData[i] = (samples[i].clamp(-1.0, 1.0) * 32767).toInt();
    }

    final pcmBytes = Uint8List(pcmData.length * 2);
    for (int i = 0; i < pcmData.length; i++) {
      pcmBytes[i * 2] = pcmData[i] & 0xFF;
      pcmBytes[i * 2 + 1] = (pcmData[i] >> 8) & 0xFF;
    }

    final dataSize = pcmBytes.length;
    final fileSize = 44 + dataSize;
    final buffer = ByteData(fileSize);

    buffer.setUint8(0, 0x52); buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46); buffer.setUint8(3, 0x46);
    buffer.setUint32(4, fileSize - 8, Endian.little);
    buffer.setUint8(8, 0x57); buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56); buffer.setUint8(11, 0x45);

    buffer.setUint8(12, 0x66); buffer.setUint8(13, 0x6D);
    buffer.setUint8(14, 0x74); buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);

    buffer.setUint8(36, 0x64); buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74); buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < pcmBytes.length; i++) {
      buffer.setUint8(44 + i, pcmBytes[i]);
    }

    return buffer.buffer.asUint8List();
  }

  /// Generate audio and return raw samples (for external use).
  Future<GeneratedAudio> generateRaw(String text, {int? sid, double? speed}) async {
    if (_tts == null) throw Exception('TTS not initialized');
    return _tts!.generate(
      text: text,
      sid: sid ?? _currentSid,
      speed: speed ?? _currentSpeed,
    );
  }

  @override
  Future<void> stop() async {
    _shouldStop = true;
    if (_player != null) await _player!.stop();
  }

  @override
  Future<void> pause() async {
    if (_player != null) await _player!.pause();
  }

  @override
  Future<void> resume() async {
    if (_player != null) await _player!.resume();
  }

  @override
  Stream<TtsProgress> get progressStream => _progressController.stream;

  @override
  Future<List<TtsVoice>> getVoices() async {
    final voices = <TtsVoice>[];
    for (int sid = 0; sid < _currentModelType.sidCount; sid++) {
      voices.add(TtsVoice(
        shortName: 'sid_$sid',
        name: 'Voice $sid',
        locale: 'zh-CN',
        gender: 'female',
        rawData: {'sid': sid},
      ));
    }
    return voices;
  }

  @override
  Future<void> setVoice(String voiceId) async {
    if (voiceId.startsWith('sid_')) {
      _currentSid = int.tryParse(voiceId.substring(4)) ?? 0;
    } else {
      _currentSid = int.tryParse(voiceId) ?? 0;
    }
  }

  @override
  Future<void> setSpeed(double rate) async {
    _currentSpeed = rate.clamp(0.5, 2.0);
  }

  @override
  Future<void> setPitch(double pitch) async {
    // Not directly controllable in VITS models
  }

  @override
  Future<void> dispose() async {
    _shouldStop = true;
    if (_player != null) await _player!.dispose();
    _player = null;
    _tts?.free();
    _tts = null;
    _initialized = false;
    await _progressController.close();
  }
}
