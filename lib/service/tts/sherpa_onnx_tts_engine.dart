import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/offline_tts_model_manager.dart';
import 'package:anx_reader/service/tts/sentence_splitter.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Offline TTS engine based on sherpa-onnx.
///
/// Supports Kokoro, Matcha, and VITS model families with automatic detection.
/// Uses flutter_pcm_sound for PCM streaming playback with pre-generation
/// to achieve near-zero sentence-to-sentence delay.
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

  /// PCM playback state.
  bool _pcmSetup = false;
  int _pcmSampleRate = 0;

  /// Pre-generated PCM cache for the next sentence.
  List<int>? _nextPcmCache;
  int? _nextPcmSampleRate;
  String? _nextPcmText;

  /// Completer for drain-wait (remainingFrames == 0).
  Completer<void>? _drainCompleter;

  final StreamController<TtsProgress> _progressController =
      StreamController<TtsProgress>.broadcast();

  /// Peek callback: returns next text WITHOUT triggering highlight.
  /// Set by adapter, calls JS ttsPrepare().
  Future<String?> Function()? peekNextText;

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

    File? voicesBinFile;
    try {
      voicesBinFile = allFiles.whereType<File>().firstWhere(
        (f) => f.path.split(Platform.pathSeparator).last.toLowerCase() == 'voices.bin',
      );
    } catch (_) {
      voicesBinFile = null;
    }

    final lexiconFiles = allFiles.whereType<File>().where(
      (f) {
        final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.startsWith('lexicon') && name.endsWith('.txt');
      },
    ).toList();
    final lexiconPaths = lexiconFiles.map((f) => f.path).join(',');

    String? dataDir;
    try {
      final dataDirMatch = allFiles.whereType<Directory>().firstWhere(
        (d) => d.path.split(Platform.pathSeparator).last == 'espeak-ng-data',
      );
      dataDir = dataDirMatch.path;
    } catch (_) {
      dataDir = null;
    }

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
          lang: '',
          lengthScale: 1.0,
        ),
        numThreads: 4,
        debug: false,
        provider: 'cpu',
      );
    } else if (vocoderFile != null) {
      log.log('SherpaONNX: detected Matcha model (vocoder explicitly found)');

      modelConfig = OfflineTtsModelConfig(
        matcha: OfflineTtsMatchaModelConfig(
          acousticModel: onnxFile.path,
          vocoder: vocoderFile.path,
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
      log.log('SherpaONNX: detected VITS model (default fallback)');

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

    for (int i = 0; i < sentences.length; i++) {
      if (_shouldStop) break;
      final sentence = sentences[i];
      if (sentence.trim().isEmpty) continue;

      // 1. Check pre-generated cache or generate PCM
      List<int>? pcmData;
      if (_nextPcmCache != null &&
          _nextPcmSampleRate != null &&
          _nextPcmText == sentence) {
        pcmData = _nextPcmCache;
        _nextPcmCache = null;
        _nextPcmSampleRate = null;
        _nextPcmText = null;
        log.log('SherpaONNX: using cached PCM for sentence $i');
        // 300ms delay to let WebView render highlight
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        log.log('SherpaONNX: generating sentence $i');
        pcmData = await _generatePcm(sentence, log);
        if (pcmData == null) {
          log.log('SherpaONNX: failed to generate sentence $i');
          continue;
        }
      }

      if (_shouldStop) break;

      // 2. Setup FlutterPcmSound if needed
      final sampleRate = _pcmSampleRate;
      if (!_pcmSetup || _pcmSampleRate != sampleRate) {
        await FlutterPcmSound.release();
        await FlutterPcmSound.setup(
          sampleRate: sampleRate,
          channelCount: 1,
        );
        _pcmSetup = true;
        _pcmSampleRate = sampleRate;
        log.log('SherpaONNX: FlutterPcmSound setup @ ${sampleRate}Hz');
      }

      // 3. Feed PCM data
      if (pcmData == null) continue;
      final pcmArray = PcmArrayInt16.fromList(pcmData);
      await FlutterPcmSound.feed(pcmArray);
      log.log('SherpaONNX: fed ${pcmData.length} samples');

      // 4. Set up drain-wait callback
      _drainCompleter = Completer<void>();
      FlutterPcmSound.setFeedCallback((remainingFrames) {
        if (remainingFrames == 0 &&
            _drainCompleter != null &&
            !_drainCompleter!.isCompleted) {
          _drainCompleter!.complete();
        }
      });

      // 5. Start playback
      FlutterPcmSound.start();
      log.log('SherpaONNX: playback started');

      // 6. Pre-generate next sentence
      if (i + 1 < sentences.length) {
        _preGenerateNext(log);
      }

      // 7. Drain wait
      await _drainCompleter!.future;
      _drainCompleter = null;
      log.log('SherpaONNX: sentence $i playback completed');
    }

    log.log('SherpaONNX: speak() done');
  }

  /// Generate PCM Int16 data for a sentence.
  /// Converts digits to Chinese numerals before generating.
  Future<List<int>?> _generatePcm(String sentence, TtsDebugLogger log) async {
    if (_tts == null) return null;

    final processedText = _digitsToChinese(sentence);
    if (processedText != sentence) {
      log.log('SherpaONNX: digits converted: "$sentence" → "$processedText"');
    }

    try {
      final audio = _tts!.generate(
        text: processedText,
        sid: _currentSid,
        speed: _currentSpeed,
      );

      if (audio.samples.isEmpty) {
        log.log('SherpaONNX: empty audio for "$processedText"');
        return null;
      }

      // Convert Float32 to Int16
      final pcmData = List<int>.filled(audio.samples.length, 0);
      for (int i = 0; i < audio.samples.length; i++) {
        pcmData[i] = (audio.samples[i].clamp(-1.0, 1.0) * 32767).toInt();
      }

      _pcmSampleRate = audio.sampleRate;
      return pcmData;
    } catch (e, stack) {
      log.log('SherpaONNX: generate PCM error: $e');
      log.log(stack.toString());
      return null;
    }
  }

  /// Pre-generate PCM for the next sentence in the background.
  Future<void> _preGenerateNext(TtsDebugLogger log) async {
    if (peekNextText == null) return;

    // Yield to let playback start first
    await Future.delayed(Duration.zero);
    if (_shouldStop) return;

    try {
      final nextText = await peekNextText!();
      if (nextText == null || nextText.isEmpty) return;

      final pcm = await _generatePcm(nextText, log);
      if (pcm != null) {
        _nextPcmCache = pcm;
        _nextPcmSampleRate = _pcmSampleRate;
        _nextPcmText = nextText;
        log.log('SherpaONNX: pre-generated next sentence: "$nextText"');
      }
    } catch (e) {
      log.log('SherpaONNX: pre-generate error: $e');
    }
  }

  static final _digitMap = {
    '0': '零',
    '1': '一',
    '2': '二',
    '3': '三',
    '4': '四',
    '5': '五',
    '6': '六',
    '7': '七',
    '8': '八',
    '9': '九',
    '.': '点',
  };

  static String _digitsToChinese(String text) {
    return text.split('').map((c) => _digitMap[c] ?? c).join();
  }

  @override
  Future<void> stop() async {
    _shouldStop = true;
    await FlutterPcmSound.release();
    _pcmSetup = false;
    _nextPcmCache = null;
    _nextPcmSampleRate = null;
    _nextPcmText = null;
  }

  @override
  Future<void> pause() async {
    _shouldStop = true;
    await FlutterPcmSound.release();
    _pcmSetup = false;
  }

  @override
  Future<void> resume() async {
    // Resume is handled by adapter calling speak() with current text
  }

  @override
  Stream<TtsProgress> get progressStream => _progressController.stream;

  @override
  Future<List<TtsVoice>> getVoices() async {
    final mgr = OfflineTtsModelManager();

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
      return [];
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
    await FlutterPcmSound.release();
    _pcmSetup = false;
    _tts?.free();
    _tts = null;
    _initialized = false;
    _initFailed = false;
    _nextPcmCache = null;
    _nextPcmSampleRate = null;
    _nextPcmText = null;
    await _progressController.close();
  }

  /// Scan the first 1MB of an ONNX file for known VITS metadata keys.
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
