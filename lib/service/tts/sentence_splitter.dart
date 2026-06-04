/// Utility for splitting text into sentences for TTS playback.
class SentenceSplitter {
  /// Split [text] into sentences.
  ///
  /// Handles Chinese (。！？) and English (.!?) punctuation,
  /// with special cases for quotes, ellipsis, and decimal numbers.
  static List<String> split(String text) {
    if (text.isEmpty) return [];

    // Split on sentence-ending punctuation, keeping the delimiter
    final parts = <String>[];
    final buffer = StringBuffer();
    final chars = text.split('');

    for (int i = 0; i < chars.length; i++) {
      buffer.write(chars[i]);

      // Check for sentence-ending punctuation
      if (_isSentenceEnd(chars[i], i, chars)) {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          parts.add(sentence);
        }
        buffer.clear();
      }
    }

    // Add remaining text
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      parts.add(remaining);
    }

    return parts;
  }

  static bool _isSentenceEnd(String char, int index, List<String> chars) {
    // Chinese sentence endings
    if (char == '。' || char == '！' || char == '？') return true;

    // English sentence endings
    if (char == '.' || char == '!' || char == '?') {
      // Handle decimal numbers (e.g., 3.14)
      if (char == '.') {
        // Not a sentence end if between digits
        if (index > 0 && _isDigit(chars[index - 1])) {
          if (index + 1 < chars.length && _isDigit(chars[index + 1])) {
            return false;
          }
        }
        // Not a sentence end in abbreviations like Mr. Dr. etc.
        if (index > 0 && index + 1 < chars.length) {
          final prev = chars[index - 1].toLowerCase();
          if (prev == 'm' || prev == 'd' || prev == 'r' || prev == 's') {
            if (index + 1 < chars.length && chars[index + 1] == ' ') {
              return false;
            }
          }
        }
      }
      return true;
    }

    // Ellipsis
    if (char == '…') return true;

    // Newline or paragraph break
    if (char == '\n' || char == '\r') {
      if (index + 1 < chars.length &&
          chars[index + 1] == '\n') {
        return true;
      }
      return true;
    }

    return false;
  }

  static bool _isDigit(String char) {
    return char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  }
}
