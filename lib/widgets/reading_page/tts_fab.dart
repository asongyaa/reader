import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/widgets/reading_page/tts_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:icons_plus/icons_plus.dart';

class TtsFab extends StatelessWidget {
  const TtsFab({super.key});

  void _openPlayerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SizedBox.expand(
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: const TtsPlayerSheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TtsStateEnum>(
      valueListenable: TtsHandler().ttsStateNotifier,
      builder: (context, ttsState, _) {
        final ttsActive =
            ttsState == TtsStateEnum.playing || ttsState == TtsStateEnum.paused;

        return FloatingActionButton(
          heroTag: null,
          mini: true,
          onPressed: () => _openPlayerSheet(context),
          backgroundColor: ttsActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          foregroundColor: ttsActive
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurface,
          elevation: 4,
          child: Icon(
            ttsActive ? EvaIcons.headphones : EvaIcons.headphones_outline,
            size: 22,
          ),
        );
      },
    ).animate().scale(
      begin: const Offset(0.85, 0.85),
      duration: 400.ms,
      curve: Curves.easeOut,
    ).fadeIn(
      duration: 300.ms,
      curve: Curves.easeOut,
    );
  }
}
