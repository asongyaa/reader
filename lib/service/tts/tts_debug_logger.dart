import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Simple ring-buffer logger for TTS diagnostics.
/// Collected logs can be displayed in the UI for user copying.
class TtsDebugLogger {
  static final TtsDebugLogger _instance = TtsDebugLogger._internal();
  factory TtsDebugLogger() => _instance;
  TtsDebugLogger._internal();

  final ListQueue<String> _logs = ListQueue<String>(200);
  final ValueNotifier<int> revision = ValueNotifier(0);

  void log(String msg) {
    final line = '[${DateTime.now().toIso8601String().substring(11, 23)}] $msg';
    if (_logs.length >= 200) _logs.removeFirst();
    _logs.add(line);
    revision.value++;
  }

  List<String> get logs => List.unmodifiable(_logs);

  String getLogsText() => _logs.join('\n');

  void clear() {
    _logs.clear();
    revision.value++;
  }
}
