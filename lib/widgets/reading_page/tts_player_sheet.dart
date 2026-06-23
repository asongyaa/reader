import 'dart:async';

import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/models/current_reading_state.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/providers/current_reading.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:anx_reader/widgets/step_slider.dart';

class TtsPlayerSheet extends ConsumerStatefulWidget {
  const TtsPlayerSheet({super.key});

  @override
  ConsumerState<TtsPlayerSheet> createState() => _TtsPlayerSheetState();
}

class _TtsPlayerSheetState extends ConsumerState<TtsPlayerSheet> {
  double volume = TtsHandler().volume;
  double pitch = TtsHandler().pitch;
  double rate = TtsHandler().rate;
  double stopSeconds = 0;
  Timer? stopTimer;

  @override
  void initState() {
    super.initState();
    if (TtsHandler().ttsStateNotifier.value != TtsStateEnum.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = epubPlayerKey.currentState;
        if (state == null || !mounted) return;
        TtsHandler()
            .init(state.initTts, state.ttsNext, state.ttsPrev)
            .catchError((e, stack) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('TTS 初始化失败: $e'),
                  duration: const Duration(seconds: 5)),
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    stopTimer?.cancel();
    super.dispose();
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: L10n.of(context).close,
          ),
          const Expanded(
            child: Center(
              child: Text('听书'),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCover(CurrentReadingState currentReading) {
    final book = currentReading.book;
    if (book == null) {
      return const SizedBox(height: 220, width: 155);
    }
    return BookCover(
      book: book,
      height: 220,
      width: 155,
      radius: 12,
    );
  }

  Widget _buildBookInfo(CurrentReadingState currentReading) {
    final book = currentReading.book;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            book?.title ?? '',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            currentReading.chapterTitle ?? '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _actionChip(
            label: '${rate.toStringAsFixed(1)}x',
            icon: EvaIcons.activity,
            onTap: _showRateSheet,
          ),
          _actionChip(
            label: stopSeconds > 0
                ? '${(stopSeconds / 60).ceil()}m'
                : '定时',
            icon: EvaIcons.clock_outline,
            onTap: _showTimerSheet,
          ),
          _actionChip(
            label: '${(volume * 100).toInt()}%',
            icon: EvaIcons.volume_down,
            onTap: _showVolumeSheet,
          ),
          _actionChip(
            label: pitch.toStringAsFixed(1),
            icon: EvaIcons.music,
            onTap: _showPitchSheet,
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.surfaceContainerHighest,
      side: BorderSide.none,
      avatar: Icon(icon, size: 14, color: cs.onSurfaceVariant),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
    );
  }

  void _showRateSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '语速设置',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              StepSlider(
                value: rate,
                min: 0.5,
                max: 2.5,
                step: 0.1,
                onChanged: (v) {
                  setSheetState(() {});
                  setState(() {
                    rate = v;
                    TtsHandler().rate = v;
                  });
                },
                thumbLabel: (v) => v.toStringAsFixed(1),
                tickLabels: const [1.0, 1.5, 2.0],
                leftText: '慢',
                rightText: '快',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '定时关闭',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              StepSlider(
                value: (stopSeconds / 60).roundToDouble().clamp(0, 60),
                min: 0,
                max: 60,
                step: 5,
                onChanged: (v) {
                  setSheetState(() {});
                  setState(() {
                    stopSeconds = v * 60;
                    stopTimer?.cancel();
                    if (stopSeconds > 0) {
                      stopTimer = Timer.periodic(
                        const Duration(seconds: 5),
                        (timer) {
                          if (stopSeconds > 5) {
                            stopSeconds -= 5;
                            if (mounted) setState(() {});
                          } else {
                            TtsHandler().stop();
                            stopSeconds = 0;
                            timer.cancel();
                            if (mounted) setState(() {});
                          }
                        },
                      );
                    }
                  });
                },
                thumbLabel: (v) => v == 0 ? '关' : '${v.toInt()}',
                tickLabels: const [15, 30, 45],
                leftText: '关',
                rightText: '60m',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVolumeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '音量设置',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              StepSlider(
                value: volume,
                min: 0.0,
                max: 1.0,
                step: 0.1,
                onChanged: (v) {
                  setSheetState(() {});
                  setState(() {
                    volume = v;
                    TtsHandler().volume = v;
                  });
                },
                thumbLabel: (v) => '${(v * 100).toInt()}%',
                tickLabels: const [0.3, 0.5, 0.8],
                leftText: '静音',
                rightText: '最大',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPitchSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '音调设置',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              StepSlider(
                value: pitch,
                min: 0.5,
                max: 2.0,
                step: 0.1,
                onChanged: (v) {
                  setSheetState(() {});
                  setState(() {
                    pitch = v;
                    TtsHandler().pitch = v;
                  });
                },
                thumbLabel: (v) => v.toStringAsFixed(1),
                tickLabels: const [0.8, 1.0, 1.5],
                leftText: '低',
                rightText: '高',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(CurrentReadingState currentReading) {
    final progress = (currentReading.percentage ?? 0.0).clamp(0.0, 1.0);
    final chapter = currentReading.chapterTitle ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Expanded(
                child: Text(
                  chapter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainControls(bool isPlaying) {
    final cs = Theme.of(context).colorScheme;

    Widget controlButton({
      required IconData icon,
      required VoidCallback onPressed,
      double size = 24,
      Color? color,
      String? tooltip,
    }) {
      return IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        color: color ?? cs.onSurface,
        tooltip: tooltip,
        splashRadius: 24,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          controlButton(
            icon: EvaIcons.arrowhead_left,
            onPressed: () async {
              audioHandler.stop();
              final state = epubPlayerKey.currentState;
              if (state != null) await state.ttsPrevSection();
              TtsHandler().playPrevious();
            },
            tooltip: '上一章',
          ),
          controlButton(
            icon: EvaIcons.chevron_left,
            onPressed: () => TtsHandler().playPrevious(),
            tooltip: '上一句',
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary,
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 28,
                color: cs.onPrimary,
              ),
              onPressed: () async {
                if (isPlaying) {
                  await audioHandler.pause();
                } else {
                  await audioHandler.play();
                }
              },
              tooltip: isPlaying
                  ? L10n.of(context).commonPause
                  : '播放',
              splashRadius: 28,
            ),
          ),
          controlButton(
            icon: EvaIcons.chevron_right,
            onPressed: () => TtsHandler().playNext(),
            tooltip: '下一句',
          ),
          controlButton(
            icon: EvaIcons.arrowhead_right,
            onPressed: () async {
              audioHandler.stop();
              final state = epubPlayerKey.currentState;
              if (state != null) await state.ttsNextSection();
              TtsHandler().playNext();
            },
            tooltip: '下一章',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentReading = ref.watch(currentReadingProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<TtsStateEnum>(
      valueListenable: TtsHandler().ttsStateNotifier,
      builder: (context, ttsState, _) {
        final isPlaying = ttsState == TtsStateEnum.playing;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: bottomPadding + 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _buildCover(currentReading),
                    const SizedBox(height: 20),
                    _buildBookInfo(currentReading),
                    const SizedBox(height: 20),
                    _buildProgressBar(currentReading),
                    const SizedBox(height: 12),
                    _buildMainControls(isPlaying),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
