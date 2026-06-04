// Shim for Flutter 3.44 where ExtendSelectionByPageIntent was removed.
import 'package:flutter/widgets.dart';

/// An intent to extend the selection by a page.
///
/// This class was removed from Flutter 3.44+, so we define it locally
/// for compatibility.
class ExtendSelectionByPageIntent extends DirectionalTextEditingIntent {
  const ExtendSelectionByPageIntent({required bool forward})
      : super(forward);
}
