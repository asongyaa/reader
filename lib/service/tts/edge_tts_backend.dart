import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/service/tts/tts_service_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class EdgeTtsProvider extends TtsServiceProvider {
  static final EdgeTtsProvider _instance = EdgeTtsProvider._internal();

  factory EdgeTtsProvider() {
    return _instance;
  }

  EdgeTtsProvider._internal();

  static const String _host = 'speech.platform.bing.com';
  static const String _trustedClientToken =
      '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _voicesUrl =
      'https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _audioFormat =
      'audio-24khz-48kbitrate-mono-mp3';
  static const _uuid = Uuid();

  @override
  TtsEngineType get engineType => TtsEngineType.edge;

  @override
  String getLabel(BuildContext context) => 'Edge TTS';

  @override
  List<ConfigItem> getConfigItems(BuildContext context) {
    return [
      ConfigItem(
        key: 'tip',
        label: L10n.of(context).translateTip,
        type: ConfigItemType.tip,
        defaultValue: 'Edge TTS uses Microsoft Edge online voices.',
      ),
    ];
  }

  @override
  Map<String, dynamic> getConfig() {
    return {};
  }

  @override
  void saveConfig(Map<String, dynamic> config) {}

  @override
  Future<Uint8List> speak(
      String text, String? voice, double rate, double pitch) async {
    final requestId = _uuid.v4().replaceAll('-', '');
    final connectionId = _uuid.v4().replaceAll('-', '');
    final resolvedVoice = resolveVoice(voice);
    final locale = _parseLocaleFromVoice(resolvedVoice);
    final ssml = _buildSsml(text, resolvedVoice, locale, rate, pitch);

    final secMsGec = _computeSecMsGec();
    final muid = _generateMuid();

    final ws = await _connectWebSocket(
      connectionId: connectionId,
      secMsGec: secMsGec,
      muid: muid,
    );

    try {
      // Send config message
      final configMessage = _buildConfigMessage();
      ws.add(configMessage);

      // Send SSML message
      final ssmlMessage = _buildSsmlMessage(requestId, ssml);
      ws.add(ssmlMessage);

      // Collect audio chunks
      final audioChunks = <Uint8List>[];
      var turnEnded = false;

      await for (final message in ws) {
        if (turnEnded) break;

        if (message is String) {
          if (_isTurnEnd(message)) {
            turnEnded = true;
            break;
          }
        } else if (message is List<int>) {
          final bytes = Uint8List.fromList(message);
          final headerLen = _getHeaderLength(bytes);
          if (headerLen < bytes.length) {
            audioChunks.add(bytes.sublist(headerLen));
          }
        }
      }

      // Concatenate all audio chunks
      if (audioChunks.isEmpty) {
        return Uint8List(0);
      }
      final totalLength =
          audioChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final result = Uint8List(totalLength);
      var offset = 0;
      for (final chunk in audioChunks) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return result;
    } finally {
      await ws.close();
    }
  }

  Future<WebSocket> _connectWebSocket({
    required String connectionId,
    required String secMsGec,
    required String muid,
  }) async {
    final path =
        '/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=$_trustedClientToken&ConnectionId=$connectionId';
    final uri = Uri.parse('https://$_host:443$path');

    final client = HttpClient();

    final request = await client.openUrl('GET', uri);

    // WebSocket upgrade headers
    request.headers.set('Upgrade', 'websocket');
    request.headers.set('Connection', 'Upgrade');
    request.headers
        .set('Sec-WebSocket-Key', base64.encode(_randomBytes(16)));
    request.headers.set('Sec-WebSocket-Version', '13');

    // Edge TTS specific headers
    request.headers.set(
      'Origin',
      'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
    );
    request.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0',
    );
    request.headers.set('Sec-MS-GEC', secMsGec);
    request.headers.set('Sec-MS-GEC-Version', '1-143.0.3650.75');
    request.headers.set('Accept-Encoding', 'gzip, deflate, br, zstd');
    request.headers.set('Cookie', 'MUID=$muid');

    final response = await request.close();

    if (response.statusCode != HttpStatus.switchingProtocols) {
      client.close();
      throw Exception(
          'WebSocket upgrade failed: ${response.statusCode} ${response.reasonPhrase}');
    }

    final socket = await response.detachSocket();
    client.close();

    return WebSocket.fromUpgradedSocket(
      socket,
      serverSide: false,
    );
  }

  String _computeSecMsGec() {
    final now = DateTime.now().toUtc();
    final unixSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final windowsSeconds = unixSeconds + 11644473600;
    final roundedSeconds = (windowsSeconds ~/ 300) * 300;
    final fileTime = roundedSeconds * 10000000;
    final input = '${fileTime}6A5AA1D4EAFF4E9FB37E23D68491D6F4';
    final digest = sha256.convert(utf8.encode(input));
    return digest.toString().toUpperCase();
  }

  String _generateMuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String _buildConfigMessage() {
    final timestamp = _isoTimestamp();
    final configJson = jsonEncode({
      'context': {
        'synthesis': {
          'audio': {
            'metadataoptions': {
              'sentenceBoundaryEnabled': 'false',
              'wordBoundaryEnabled': 'false',
            },
            'outputFormat': _audioFormat,
          },
        },
      },
    });
    return 'X-Timestamp: $timestamp\r\n'
        'Content-Type: application/json; charset=utf-8\r\n'
        'Path: speech.config\r\n\r\n'
        '$configJson';
  }

  String _buildSsmlMessage(String requestId, String ssml) {
    final timestamp = _isoTimestamp();
    return 'X-RequestId: $requestId\r\n'
        'Content-Type: application/ssml+xml\r\n'
        'X-Timestamp: $timestamp\r\n'
        'Path: ssml\r\n\r\n'
        '$ssml';
  }

  String _buildSsml(
    String text,
    String voiceName,
    String locale,
    double rate,
    double pitch,
  ) {
    final rateStr = _rateToPercent(rate);
    final pitchStr = _toPercent(pitch);
    final escapedText = _escapeXml(text);
    return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="$locale">'
        '<voice name="$voiceName">'
        '<prosody rate="$rateStr" pitch="$pitchStr">'
        '$escapedText'
        '</prosody>'
        '</voice>'
        '</speak>';
  }

  String _rateToPercent(double rate) {
    final percent = ((rate - 1.0) * 100).round();
    return percent >= 0 ? '+$percent%' : '$percent%';
  }

  String _toPercent(double value) {
    final percent = ((value - 1.0) * 100).toInt();
    return percent >= 0 ? '+$percent%' : '$percent%';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _parseLocaleFromVoice(String voiceName) {
    final parts = voiceName.split('-');
    if (parts.length >= 2) {
      return '${parts[0]}-${parts[1]}';
    }
    return 'en-US';
  }

  String _isoTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }

  bool _isTurnEnd(String message) {
    final lines = message.split('\r\n');
    for (final line in lines) {
      if (line.startsWith('Path:')) {
        final path = line.substring(5).trim();
        return path == 'turn.end';
      }
    }
    return false;
  }

  int _getHeaderLength(Uint8List bytes) {
    if (bytes.length < 2) return 0;
    final headerLen = (bytes[0] << 8) | bytes[1];
    return 2 + headerLen;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
      final response = await http.get(
        Uri.parse(_voicesUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => convertVoiceModel(e)).toList();
      } else {
        throw Exception('Failed to load voices: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  TtsVoice convertVoiceModel(dynamic voiceData) {
    final shortName = voiceData['ShortName'] as String? ?? '';
    final localName = voiceData['LocalName'] as String? ??
        voiceData['Name'] as String? ??
        '';
    final friendlyName = _extractFriendlyName(shortName);
    return TtsVoice(
      shortName: shortName,
      name: friendlyName.isNotEmpty ? friendlyName : localName,
      locale: voiceData['Locale'] as String? ?? '',
      gender: voiceData['Gender'] as String? ?? '',
      rawData: voiceData is Map<String, dynamic> ? voiceData : null,
    );
  }

  String _extractFriendlyName(String shortName) {
    final parts = shortName.split('-');
    if (parts.length >= 3) {
      var name = parts[2];
      if (name.endsWith('Neural')) {
        name = name.substring(0, name.length - 6);
      }
      return name;
    }
    return shortName;
  }
}
