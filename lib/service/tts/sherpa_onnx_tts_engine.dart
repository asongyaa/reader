import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/offline_tts_model_manager.dart';
import 'package:anx_reader/service/tts/sentence_splitter.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Offline TTS engine based on sherpa-onnx.
///
/// Supports Kokoro, Matcha, and VITS model families with automatic detection.
/// Uses parallel pre-generation to eliminate sentence-to-sentence delay.
class SherpaOnnxTtsEngine implements TtsEngine {
  OfflineTts? _tts;
  bool _initialized = false;
  bool _shouldStop = false;
  int _currentSid = 0;
  double _currentSpeed = 1.0;
  TtsModelType _currentModelType = TtsModelType.vitsMeloZhEn;

  /// Native bindings must be initialized exactly once per app lifetime.
  static bool _bindingsInitialized = false;

  /// Guard against repeated init failures until dispose() resets.
  bool _initFailed = false;

  AudioPlayer? _player;
  final StreamController<TtsProgress> _progressController =
      StreamController<TtsProgress>.broadcast();

  /// Optional: map role names to SIDs for multi-voice synthesis.
  final Map<String, int> roleSidMap = {};

  SherpaOnnxTtsEngine() {
    try {
      _currentSid = Prefs().offlineTtsSid;
    } catch (_) {
      _currentSid = 0;
    }
  }

  @override
  String get name => 'Offline TTS';

  @override
  bool get requiresModelDownload => true;

  @override
  bool get autoChainsSentences => false;

  /// Set the model type to use. Call [init] after changing.
  void setModelType(TtsModelType type) {
    if (_initialized) {
      _tts?.free();
      _tts = null;
      _initialized = false;
    }
    _currentModelType = type;
  }

  /// Set the speaker ID (voice).
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
    if (_initFailed) {
      log.log('SherpaONNX: init previously failed, skipping until dispose()');
      return;
    }

    log.log('SherpaONNX: init() started');

    String? modelPath;
    try {
      modelPath = await OfflineTtsModelManager().getModelPath(_currentModelType) ??
          await OfflineTtsModelManager().findAnyModel();
    } catch (e) {
      log.log('SherpaONNX: model path lookup failed: $e');
      _initFailed = true;
      return;
    }

    if (modelPath == null) {
      log.log('SherpaONNX: 离线模型未下载');
      _initFailed = true;
      return;
    }
    log.log('SherpaONNX: modelPath=$modelPath');

    final dir = Directory(modelPath);
    if (!await dir.exists()) {
      log.log('SherpaONNX: 模型目录不存在: $modelPath');
      _initFailed = true;
      return;
    }

    final allFiles = await dir.list(recursive: true).toList();
    log.log('SherpaONNX: found ${allFiles.length} files');
    for (final f in allFiles.whereType<File>().take(20)) {
      log.log('  file: ${f.path}');
    }

    // ── Locate model files ────────────────────────────────────────

    // Find any .onnx file (model.onnx preferred)
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
      _initFailed = true;
      return;
    }

    // Find tokens.txt
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
      _initFailed = true;
      return;
    }

    // Find voices.bin (Kokoro-specific)
    File? voicesBinFile;
    try {
      voicesBinFile = allFiles.whereType<File>().firstWhere(
        (f) => f.path.split(Platform.pathSeparator).last.toLowerCase() == 'voices.bin',
      );
    } catch (_) {
      voicesBinFile = null;
    }

    // Collect all lexicon*.txt files
    final lexiconFiles = allFiles.whereType<File>().where(
      (f) {
        final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.startsWith('lexicon') && name.endsWith('.txt');
      },
    ).toList();
    final lexiconPaths = lexiconFiles.map((f) => f.path).join(',');

    // Find espeak-ng-data dir exactly; avoid matching dirs like 'model_data'
    String? dataDir;
    try {
      final dataDirMatch = allFiles.whereType<Directory>().firstWhere(
        (d) => d.path.split(Platform.pathSeparator).last == 'espeak-ng-data',
      );
      dataDir = dataDirMatch.path;
    } catch (_) {
      dataDir = null;
    }

    // Find dict dir exactly
    String? dictDir;
    try {
      final dictDirMatch = allFiles.whereType<Directory>().firstWhere(
        (d) => d.path.split(Platform.pathSeparator).last == 'dict',
      );
      dictDir = dictDirMatch.path;
    } catch (_) {
      dictDir = null;
    }

    log.log('SherpaONNX: onnx=${onnxFile.path}');
    log.log('SherpaONNX: tokens=${tokensFile.path}');
    if (voicesBinFile != null) {
      log.log('SherpaONNX: voices.bin=${voicesBinFile.path}');
    }
    if (lexiconPaths.isNotEmpty) {
      log.log('SherpaONNX: lexicons=$lexiconPaths');
    }

    // ── Model size guard ─────────────────────────────────────────

    final onnxSize = await onnxFile.length();
    final onnxSizeMb = onnxSize / (1024 * 1024);
    log.log('SherpaONNX: ONNX size=${onnxSizeMb.toStringAsFixed(1)} MB');

    if (onnxSizeMb > 500) {
      log.log('SherpaONNX: 模型超过 500MB，拒绝加载');
      _initFailed = true;
      return;
    }

    // ── Auto-detect model architecture ───────────────────────────

    final hasVoicesBin = voicesBinFile != null;
    final metadataKeys = _extractOnnxMetadataKeys(onnxFile.path);
    log.log('SherpaONNX: metadata keys=$metadataKeys');

    // Check for vocoder files (Matcha indicator)
    File? vocoderFile;
    try {
      vocoderFile = allFiles.whereType<File>().firstWhere(
        (f) {
          final name = f.path.toLowerCase();
          return name.contains('vocoder') && name.endsWith('.onnx');
        },
      );
    } catch (_) {
      vocoderFile = null;
    }
    if (vocoderFile == null) {
      try {
        vocoderFile = allFiles.whereType<File>().firstWhere(
          (f) => f.path.toLowerCase().contains('hifigan') && f.path.endsWith('.onnx'),
        );
      } catch (_) {
        vocoderFile = null;
      }
    }

    late final OfflineTtsModelConfig modelConfig;

    if (hasVoicesBin) {
      // ── Kokoro ────────────────────────────────────────────────
      log.log('SherpaONNX: detected Kokoro model (voices.bin found)');

      if (!onnxFile.path.toLowerCase().contains('int8') && onnxSizeMb > 200) {
        log.log('SherpaONNX: WARNING Kokoro 非 int8 模型超过 200MB');
      }

      modelConfig = OfflineTtsModelConfig(
        kokoro: OfflineTtsKokoroModelConfig(
          model: onnxFile.path,
          voices: voicesBinFile!.path,
          tokens: tokensFile.path,
          dataDir: dataDir ?? '',
          dictDir: dictDir ?? '',
          lexicon: lexiconPaths,
          lang: '', // 多语言模型留空，避免外国口音
          lengthScale: 1.0,
        ),
        numThreads: 4,
        debug: false,
        provider: 'cpu',
      );
    } else if (vocoderFile != null) {
      // ── Matcha ────────────────────────────────────────────────
      log.log('SherpaONNX: detected Matcha model (vocoder explicitly found)');

      File? finalVocoder = vocoderFile;
      if (finalVocoder == null) {
        // Try to auto-download hifigan_v2.onnx
        log.log('SherpaONNX: Matcha 缺少 vocoder，尝试下载 hifigan_v2.onnx');
        try {
          final appDir = await getApplicationSupportDirectory();
          final vocoderPath = '${appDir.path}/tts_models/hifigan_v2.onnx';
          final vocoderFileLocal = File(vocoderPath);
          if (!await vocoderFileLocal.exists()) {
            await Dio().download(
              'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/hifigan_v2.onnx',
              vocoderPath,
            );
            log.log('SherpaONNX: downloaded hifigan_v2.onnx');
          }
          finalVocoder = vocoderFileLocal;
        } catch (e) {
          log.log('SherpaONNX: failed to download vocoder: $e');
          _initFailed = true;
          return;
        }
      }

      modelConfig = OfflineTtsModelConfig(
        matcha: OfflineTtsMatchaModelConfig(
          acousticModel: onnxFile.path,
          vocoder: finalVocoder.path,
          tokens: tokensFile.path,
          dataDir: dataDir ?? '',
          dictDir: dictDir ?? '',
          lexicon: lexiconPaths,
          noiseScale: 0.667,
          lengthScale: 1.0,
        ),
        numThreads: 4,
        debug: false,
        provider: 'cpu',
      );
    } else {
      // ── VITS (default) ────────────────────────────────────────
      log.log('SherpaONNX: detected VITS model (comment metadata present)');

      modelConfig = OfflineTtsModelConfig(
        vits: OfflineTtsVitsModelConfig(
          model: onnxFile.path,
          tokens: tokensFile.path,
          dataDir: dataDir ?? '',
          dictDir: dictDir ?? '',
          lexicon: lexiconPaths,
          noiseScale: 0.667,
          noiseScaleW: 0.8,
          lengthScale: 1.0,
        ),
        numThreads: 4,
        debug: false,
        provider: 'cpu',
      );
    }

    // ── Initialize bindings ─────────────────────────────────────

    if (!_bindingsInitialized) {
      log.log('SherpaONNX: calling initBindings()...');
      try {
        initBindings();
        _bindingsInitialized = true;
        log.log('SherpaONNX: initBindings() succeeded');
      } catch (e, stack) {
        log.log('SherpaONNX: initBindings() failed: $e');
        log.log(stack.toString());
        _initFailed = true;
        return;
      }
    } else {
      log.log('SherpaONNX: initBindings() already done, skipping');
    }

    // ── Create OfflineTts ───────────────────────────────────────

    log.log('SherpaONNX: creating OfflineTts config...');
    try {
      final config = OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
        silenceScale: 0.2,
      );
      log.log('SherpaONNX: calling OfflineTts(config)...');
      _tts = OfflineTts(config);
      log.log('SherpaONNX: OfflineTts created successfully');
    } catch (e, stack) {
      log.log('SherpaONNX: OfflineTts creation failed: $e');
      log.log(stack.toString());
      _initFailed = true;
      return;
    }

    _initialized = true;

    // ── SID clamp and Kokoro default ────────────────────────────

    int sidCount = 1;
    try {
      sidCount = _tts!.numSpeakers;
    } catch (_) {
      sidCount = 1;
    }
    if (sidCount <= 0) sidCount = 1;

    _currentSid = _currentSid.clamp(0, sidCount - 1);

    // Kokoro: default to sid=45 for Chinese voice
    if (hasVoicesBin && _currentSid == 0 && sidCount > 45) {
      _currentSid = 45;
      try {
        Prefs().offlineTtsSid = _currentSid;
      } catch (_) {}
    }

    log.log('SherpaONNX: init() completed successfully, speakers=$sidCount, sid=$_currentSid');
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

    // Pre-generate queue: up to 3 sentences ahead
    const int prebufferSize = 3;
    final prebuffer = <Future<GeneratedAudio?>>[];

    // Helper: fill prebuffer from given index
    void fillPrebuffer(int fromIndex) {
      while (prebuffer.length < prebufferSize) {
        final idx = fromIndex + prebuffer.length;
        if (idx >= sentences.length) break;
        final s = sentences[idx].trim();
        prebuffer.add(s.isEmpty ? Future.value(null) : _generateWithRetry(s, log));
      }
    }

    // Kick off initial pre-generation
    fillPrebuffer(0);

    for (int i = 0; i < sentences.length; i++) {
      if (_shouldStop) break;
      final sentence = sentences[i];
      if (sentence.trim().isEmpty) continue;

      // Pull audio from prebuffer (should already be ready or in-progress)
      final future = prebuffer.isNotEmpty ? prebuffer.removeAt(0) : _generateWithRetry(sentence, log);
      final audio = await future;

      if (_shouldStop) break;
      if (audio == null || audio.samples.isEmpty) {
        log.log('SherpaONNX: empty audio for sentence $i, skipped');
        continue;
      }

      // Launch next pre-generation before playing
      fillPrebuffer(i + 1);

      // Play
      await _playAudio(audio);
    }

    log.log('SherpaONNX: speak() done');
  }

  /// Generate with digit-to-Chinese fallback on empty result.
  Future<GeneratedAudio?> _generateWithRetry(String sentence, TtsDebugLogger log) async {
    if (_tts == null || _shouldStop) return null;

    GeneratedAudio? audio;
    try {
      audio = _tts!.generate(
        text: sentence,
        sid: _currentSid,
        speed: _currentSpeed,
      );
    } catch (_) {
      audio = null;
    }

    // If generation failed or returned empty, and sentence contains digits,
    // try converting digits to Chinese numerals and re-generate.
    if ((audio == null || audio.samples.isEmpty) && _containsDigit(sentence)) {
      final converted = _digitsToChinese(sentence);
      if (converted != sentence) {
        log.log('SherpaONNX: retry with converted digits: $converted');
        try {
          audio = _tts!.generate(
            text: converted,
            sid: _currentSid,
            speed: _currentSpeed,
          );
        } catch (_) {
          audio = null;
        }
      }
    }

    return audio;
  }

  static bool _containsDigit(String s) => s.contains(RegExp(r'[0-9]'));

  static final _digitMap = {
    '0': '零', '1': '一', '2': '二', '3': '三', '4': '四',
    '5': '五', '6': '六', '7': '七', '8': '八', '9': '九', '.': '点',
  };

  static String _digitsToChinese(String text) {
    return text.split('').map((c) => _digitMap[c] ?? c).join();
  }

  Future<AudioPlayer> _ensurePlayer() async {
    _player ??= AudioPlayer();
    return _player!;
  }

  Future<void> _playAudio(GeneratedAudio audio) async {
    final log = TtsDebugLogger();
    try {
      final player = await _ensurePlayer();
      final wavBytes = _floatSamplesToWav(audio.samples, audio.sampleRate);
      log.log('SherpaONNX: wav ${wavBytes.length} bytes ready');

      // Calculate audio duration from samples to avoid unreliable
      // onPlayerComplete events on consecutive plays.
      final durationMs = (audio.samples.length / audio.sampleRate * 1000).ceil();
      log.log('SherpaONNX: audio duration=${durationMs}ms');

      await player.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      log.log('SherpaONNX: playing audio...');

      // Wait for audio to finish playing, plus a small buffer.
      await Future.delayed(Duration(milliseconds: durationMs + 150));
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

    buffer.setUint8(0, 0x52);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46);
    buffer.setUint8(3, 0x46);
    buffer.setUint32(4, fileSize - 8, Endian.little);
    buffer.setUint8(8, 0x57);
    buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56);
    buffer.setUint8(11, 0x45);

    buffer.setUint8(12, 0x66);
    buffer.setUint8(13, 0x6D);
    buffer.setUint8(14, 0x74);
    buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);

    buffer.setUint8(36, 0x64);
    buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74);
    buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < pcmBytes.length; i++) {
      buffer.setUint8(44 + i, pcmBytes[i]);
    }

    return buffer.buffer.asUint8List();
  }

  /// Generate audio and return raw samples (for external use).
  Future<GeneratedAudio> generateRaw(String text,
      {int? sid, double? speed}) async {
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
    final mgr = OfflineTtsModelManager();

    // Reset _initFailed if model becomes available
    if (_initFailed) {
      final hasModel = await mgr.isAnyModelInstalled();
      if (hasModel) {
        _initFailed = false;
      }
    }

    if (!_initialized) {
      await init();
    }

    int sidCount;
    if (_initialized && _tts != null) {
      try {
        sidCount = _tts!.numSpeakers;
      } catch (_) {
        sidCount = 0;
      }
      if (sidCount <= 0) sidCount = 1;
    } else {
      return []; // 无模型或初始化失败
    }

    String displayName = await mgr.getInstalledModelName();
    if (displayName.isEmpty) displayName = 'Offline TTS';

    final voices = <TtsVoice>[];
    for (int sid = 0; sid < sidCount; sid++) {
      voices.add(TtsVoice(
        shortName: 'sid_$sid',
        name: '$displayName #$sid',
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
    try {
      Prefs().offlineTtsSid = _currentSid;
    } catch (_) {}
  }

  @override
  Future<void> setSpeed(double rate) async {
    _currentSpeed = rate.clamp(0.5, 2.0);
  }

  @override
  Future<void> setPitch(double pitch) async {
    // Not directly controllable in these models
  }

  @override
  Future<void> dispose() async {
    _shouldStop = true;
    if (_player != null) await _player!.dispose();
    _player = null;
    _tts?.free();
    _tts = null;
    _initialized = false;
    _initFailed = false;
    await _progressController.close();
  }

  /// Scan the first 1MB of an ONNX file for known VITS metadata keys.
  /// Used to distinguish VITS (has 'comment') from Matcha (no 'comment').
  Set<String> _extractOnnxMetadataKeys(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return {};
      final length = file.lengthSync();
      final readSize = length < 1024 * 1024 ? length : 1024 * 1024;
      final raf = file.openSync();
      final bytes = raf.readSync(readSize);
      raf.closeSync();

      final keys = <String>{};
      final content = String.fromCharCodes(bytes);
      final knownKeys = [
        'comment',
        'language',
        'sample_rate',
        'n_speakers',
        'version',
        'model_type',
      ];
      for (final key in knownKeys) {
        if (content.contains(key)) keys.add(key);
      }
      return keys;
    } catch (_) {
      return {};
    }
  }
}
