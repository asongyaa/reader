import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Supported TTS model types.
enum TtsModelType {
  vitsMeloZhEn(
    displayName: 'VITS-melo (中英双语)',
    dirName: 'vits-melo-tts-zh_en',
    expectedFiles: ['model.onnx', 'model.onnx.data', 'tokens.txt'],
    defaultSid: 0,
    sidCount: 1,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-melo-tts-zh_en.tar.bz2',
  ),
  vitsAishell3(
    displayName: 'VITS-aishell3 (174种中文音色)',
    dirName: 'vits-zh-aishell3',
    expectedFiles: ['model.onnx', 'tokens.txt'],
    defaultSid: 0,
    sidCount: 174,
    downloadUrl: '',
  );

  final String displayName;
  final String dirName;
  final List<String> expectedFiles;
  final int defaultSid;
  final int sidCount;
  final String downloadUrl;

  const TtsModelType({
    required this.displayName,
    required this.dirName,
    required this.expectedFiles,
    required this.defaultSid,
    required this.sidCount,
    required this.downloadUrl,
  });
}

/// Manages downloading, importing, extracting, verifying, and deleting
/// offline TTS models.
class OfflineTtsModelManager {
  OfflineTtsModelManager._();
  static final OfflineTtsModelManager _instance = OfflineTtsModelManager._();
  factory OfflineTtsModelManager() => _instance;

  static const String _customModelDir = 'custom_model';

  /// The root directory where all models are stored.
  Future<Directory> get _modelsDir async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/tts_models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get the model directory for a specific type, null if not downloaded.
  Future<String?> getModelPath([TtsModelType type = TtsModelType.vitsMeloZhEn]) async {
    if (!await isModelDownloaded(type)) return null;
    final dir = await _modelsDir;
    return '${dir.path}/${type.dirName}';
  }

  /// Check if a specific model is downloaded and valid.
  /// Relaxed: accepts any *.onnx if model.onnx is missing;
  /// model.onnx.data is optional.
  Future<bool> isModelDownloaded([TtsModelType type = TtsModelType.vitsMeloZhEn]) async {
    try {
      final dir = await _modelsDir;
      final modelDir = Directory('${dir.path}/${type.dirName}');
      if (!await modelDir.exists()) return false;

      // Must have tokens.txt
      if (!await File('${modelDir.path}/tokens.txt').exists()) return false;

      // Must have model.onnx or any *.onnx
      final hasModelOnnx = await File('${modelDir.path}/model.onnx').exists();
      if (hasModelOnnx) return true;

      final anyOnnx = await modelDir
          .list(recursive: false)
          .any((f) => f is File && f.path.endsWith('.onnx'));
      return anyOnnx;
    } catch (_) {
      return false;
    }
  }

  /// List all downloaded model types.
  Future<List<TtsModelType>> listDownloadedModels() async {
    final results = <TtsModelType>[];
    for (final type in TtsModelType.values) {
      if (await isModelDownloaded(type)) {
        results.add(type);
      }
    }
    return results;
  }

  /// Download a model from its URL with progress callback.
  Future<void> downloadModel({
    required TtsModelType type,
    void Function(double progress)? onProgress,
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call('Downloading ${type.displayName}...');
    final dir = await _modelsDir;
    final downloadPath = '${dir.path}/${type.dirName}.tar.bz2';

    await Dio().download(
      type.downloadUrl,
      downloadPath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total * 0.9);
        }
      },
    );

    onStatus?.call('Extracting...');
    if (onProgress != null) onProgress(0.9);
    await _extractArchive(downloadPath, dir.path);

    final extractedDir = _findExtractedDir(dir.path, type.dirName);
    if (extractedDir != null && extractedDir != '${dir.path}/${type.dirName}') {
      await Directory(extractedDir).rename('${dir.path}/${type.dirName}');
    }

    await File(downloadPath).delete();
    if (onProgress != null) onProgress(1.0);
    onStatus?.call('Done');
  }

  /// Import a model archive from local storage.
  /// The [type] parameter is optional and only used for API compatibility.
  /// All imported models are extracted to the custom_model/ directory.
  Future<void> importFromFile({
    TtsModelType? type,
    void Function(double progress)? onProgress,
    void Function(String message)? onStatus,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: '选择离线语音模型 (zip/tar.bz2/bz2)',
    );

    if (result == null || result.files.isEmpty) {
      onStatus?.call('Cancelled');
      return;
    }

    final sourcePath = result.files.single.path!;
    final sourceName = sourcePath.toLowerCase();
    if (!sourceName.endsWith('.zip') &&
        !sourceName.endsWith('.tar.bz2') &&
        !sourceName.endsWith('.bz2') &&
        !sourceName.endsWith('.tar.gz') &&
        !sourceName.endsWith('.tgz')) {
      onStatus?.call('不支持的文件格式，请选择 zip/bz2/tar.bz2 文件');
      return;
    }

    onStatus?.call('正在读取文件...');
    if (onProgress != null) onProgress(0.05);

    final dir = await _modelsDir;
    final customDir = Directory('${dir.path}/$_customModelDir');
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    // Clean up old custom model files
    await _clearDirectory(customDir);

    final copyPath = '${dir.path}/import_temp';
    await File(sourcePath).copy(copyPath);

    onStatus?.call('正在后台解压...');
    if (onProgress != null) onProgress(0.1);

    // Extract in background to avoid blocking the UI
    await Isolate.run(() => _extractInBackground(copyPath, customDir.path));

    if (onProgress != null) onProgress(0.85);

    // Clean up temp copy
    try {
      await File(copyPath).delete();
    } catch (_) {}

    // Auto-promote single-level directory
    final entries = await customDir.list().toList();
    final subdirs = entries.whereType<Directory>().toList();
    final files = entries.whereType<File>().toList();
    if (subdirs.length == 1 && files.isEmpty) {
      // Single subdirectory: promote contents up
      final sub = subdirs.first;
      final subEntries = await sub.list().toList();
      for (final e in subEntries) {
        final name = e.path.split(Platform.pathSeparator).last;
        await e.rename('${customDir.path}${Platform.pathSeparator}$name');
      }
      await sub.delete(recursive: true);
    }

    // Validate
    final isValid = await _dirContainsOnnxAndTokens(customDir);
    if (!isValid) {
      onStatus?.call('模型文件不完整');
      if (onProgress != null) onProgress(1.0);
      throw Exception('模型文件不完整，缺少 .onnx 或 tokens.txt');
    }

    if (onProgress != null) onProgress(1.0);
    onStatus?.call('模型导入成功');
  }

  /// Delete a downloaded model by type.
  Future<void> deleteModel([TtsModelType type = TtsModelType.vitsMeloZhEn]) async {
    final dir = await _modelsDir;
    final modelDir = Directory('${dir.path}/${type.dirName}');
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
  }

  /// Delete all models including custom_model.
  Future<void> deleteAllModels() async {
    final dir = await _modelsDir;
    for (final type in TtsModelType.values) {
      final modelDir = Directory('${dir.path}/${type.dirName}');
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
    }
    final customDir = Directory('${dir.path}/$_customModelDir');
    if (await customDir.exists()) {
      await customDir.delete(recursive: true);
    }
  }

  /// Get the model's estimated size.
  int get estimatedModelSize => 160 * 1024 * 1024;

  /// Check if a custom model is installed.
  Future<bool> isCustomModelInstalled() async {
    final dir = await _modelsDir;
    final customDir = Directory('${dir.path}/$_customModelDir');
    if (!await customDir.exists()) return false;
    return _dirContainsOnnxAndTokens(customDir);
  }

  /// Check if any model is installed (predefined or custom).
  Future<bool> isAnyModelInstalled() async {
    for (final type in TtsModelType.values) {
      if (await isModelDownloaded(type)) return true;
    }
    if (await isCustomModelInstalled()) return true;
    return false;
  }

  /// Find any installed model path: custom first, then predefined.
  Future<String?> findAnyModel() async {
    final dir = await _modelsDir;
    final customDir = Directory('${dir.path}/$_customModelDir');
    if (await customDir.exists() &&
        await _dirContainsOnnxAndTokens(customDir)) {
      return customDir.path;
    }
    for (final type in TtsModelType.values) {
      final path = await getModelPath(type);
      if (path != null) return path;
    }
    return null;
  }

  /// Get a friendly display name for the currently installed model.
  Future<String> getInstalledModelName() async {
    final dir = await _modelsDir;
    final customDir = Directory('${dir.path}/$_customModelDir');
    if (await customDir.exists() &&
        await _dirContainsOnnxAndTokens(customDir)) {
      return 'Custom Model';
    }
    for (final type in TtsModelType.values) {
      if (await isModelDownloaded(type)) {
        return type.displayName;
      }
    }
    return '';
  }

  // ── Internal helpers ──────────────────────────────────────────

  /// Check if a directory contains at least one .onnx and one tokens.txt.
  /// If [requireVoicesBin] is true, also requires voices.bin.
  Future<bool> _dirContainsOnnxAndTokens(Directory dir,
      {bool requireVoicesBin = false}) async {
    if (!await dir.exists()) return false;
    bool hasOnnx = false;
    bool hasTokens = false;
    bool hasVoicesBin = false;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
      if (name.endsWith('.onnx')) hasOnnx = true;
      if (name == 'tokens.txt') hasTokens = true;
      if (name == 'voices.bin') hasVoicesBin = true;
    }
    if (requireVoicesBin && !hasVoicesBin) return false;
    return hasOnnx && hasTokens;
  }

  Future<void> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<void> _extractArchive(String archivePath, String outputDir) async {
    final bytes = await File(archivePath).readAsBytes();
    _extractBytes(bytes, archivePath.toLowerCase(), outputDir);
  }

  /// Find the extracted directory that matches the expected name.
  String? _findExtractedDir(String parentDir, String expectedName) {
    final parent = Directory(parentDir);
    final entries = parent.listSync().whereType<Directory>().toList();
    for (final entry in entries) {
      if (entry.path.endsWith('/$expectedName') ||
          entry.path.endsWith('\\$expectedName')) {
        return entry.path;
      }
    }
    if (entries.length == 1) return entries.first.path;
    return null;
  }
}

/// Background extraction — runs in an Isolate.
/// Takes [archivePath] and [outputDir] as strings since isolates
/// can't pass objects.
void _extractInBackground(String archivePath, String outputDir) {
  final bytes = File(archivePath).readAsBytesSync();
  _extractBytesStatic(bytes, archivePath.toLowerCase(), outputDir);
}

/// Pure function: extract archive bytes to files.
/// Auto-detects format from file magic bytes, falling back to extension check.
void _extractBytesStatic(Uint8List bytes, String archiveName, String outputDir) {
  // Try to detect format from file content (magic bytes), then fall back to extension.
  final isZip = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  final isBzip2 = bytes.length >= 3 && bytes[0] == 0x42 && bytes[1] == 0x5A && bytes[2] == 0x68;
  final isGzip = bytes.length >= 3 && bytes[0] == 0x1F && bytes[1] == 0x8B;
  final isTarRaw = !isZip && !isBzip2 && !isGzip && archiveName.endsWith('.tar');

  Archive archive;

  if (isZip) {
    archive = ZipDecoder().decodeBytes(bytes);
  } else if (isBzip2) {
    final decompressed = BZip2Decoder().decodeBytes(bytes);
    try {
      archive = TarDecoder().decodeBytes(decompressed);
    } catch (_) {
      final outBasename = archiveName.split('/').last.replaceAll(
          RegExp(r'\.(?:bz2|tar\.bz2|tbz2)$', caseSensitive: false), '');
      if (outBasename.isEmpty || outBasename == archiveName) {
        File('$outputDir/model_data').writeAsBytesSync(decompressed);
      } else {
        File('$outputDir/$outBasename').writeAsBytesSync(decompressed);
      }
      return;
    }
  } else if (isGzip) {
    final decompressed = GZipDecoder().decodeBytes(bytes);
    archive = TarDecoder().decodeBytes(decompressed);
  } else if (isTarRaw) {
    archive = TarDecoder().decodeBytes(bytes);
  } else {
    // Last resort: try all decoders
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_1) {
      try {
        final d = BZip2Decoder().decodeBytes(bytes);
        try {
          archive = TarDecoder().decodeBytes(d);
        } catch (_2) {
          File('$outputDir/model_data').writeAsBytesSync(d);
          return;
        }
      } catch (_3) {
        try {
          final d = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(d);
        } catch (_4) {
          throw Exception('无法识别文件格式，请确认选择了正确的模型压缩包');
        }
      }
    }
  }

  for (final file in archive) {
    if (file.isFile) {
      final outPath = '$outputDir/${file.name}';
      final outFile = File(outPath);
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
    }
  }
}

/// Instance method wrapper kept for download use.
void _extractBytes(Uint8List bytes, String archiveName, String outputDir) {
  _extractBytesStatic(bytes, archiveName, outputDir);
}
