import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/service/tts/tts_service_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class EdgeTtsProvider extends TtsServiceProvider {
  static final EdgeTtsProvider _instance = EdgeTtsProvider._internal();

  factory EdgeTtsProvider() {
    return _instance;
  }

  EdgeTtsProvider._internal();

  static const String _wsUrl =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
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

    final wsUrl =
        '$_wsUrl?TrustedClientToken=$_trustedClientToken&ConnectionId=$connectionId';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    await channel.ready;

    // Send config message
    final configMessage = _buildConfigMessage();
    channel.sink.add(configMessage);

    // Send SSML message
    final ssmlMessage = _buildSsmlMessage(requestId, ssml);
    channel.sink.add(ssmlMessage);

    // Collect audio chunks
    final audioChunks = <Uint8List>[];
    var turnEnded = false;

    await for (final message in channel.stream) {
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

    await channel.sink.close();

    // Concatenate all audio chunks
    if (audioChunks.isEmpty) {
      return Uint8List(0);
    }
    final totalLength = audioChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in audioChunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
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
    final rateStr = _toPercent(rate);
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
    // e.g., "en-US-JennyNeural" -> "en-US"
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
    if (bytes.isEmpty) return 0;
    if (bytes[0] != 0x00) return 0;

    // Scan for consecutive two 0x00 bytes
    for (var i = 1; i < bytes.length - 1; i++) {
      if (bytes[i] == 0x00 && bytes[i + 1] == 0x00) {
        return i + 2;
      }
    }

    // Fallback: try big-endian header length at bytes[1..2]
    if (bytes.length >= 3) {
      final headerLen = (bytes[1] << 8) | bytes[2];
      if (headerLen > 0 && headerLen + 3 <= bytes.length) {
        return headerLen + 3;
      }
    }

    return 0;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    try {
      final response = await http.get(
        Uri.parse(_voicesUrl),
        headers: {
          'User-Agent': 'AnxReader',
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
    return TtsVoice(
      shortName: voiceData['ShortName'],
      name: voiceData['LocalName'] ?? voiceData['Name'],
      locale: voiceData['Locale'],
      gender: voiceData['Gender'],
      rawData: voiceData is Map<String, dynamic> ? voiceData : null,
    );
  }
}
