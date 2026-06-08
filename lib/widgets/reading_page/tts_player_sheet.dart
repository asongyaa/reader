import 'dart:async';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/models/current_reading_state.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/providers/current_reading.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/service/tts/tts_service.dart' as tts_svc;
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:anx_reader/page/settings_page/narrate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';

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
  bool _showLogs = false;
  bool _showMoreSettings = false;

  @override
  void initState() {
    super.initState();
    if (TtsHandler().ttsStateNotifier.value != TtsStateEnum.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = epubPlayerKey.currentState;
        if (state == null || !mounted) return;
        TtsHandler()
            .init(state.initTts, state.ttsNext, state.ttsPrev)
            .then((_) {
          TtsDebugLogger().log('TtsPlayerSheet: init completed OK');
        }).catchError((e, stack) {
          TtsDebugLogger().log('TtsPlayerSheet: init error: $e');
          TtsDebugLogger().log(stack.toString());
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

  String _getTtsServiceLabel(BuildContext context) {
    final serviceId = Prefs().ttsService;
    if (serviceId == 'system') {
      return L10n.of(context).ttsTypeSystem;
    }
    return tts_svc.getTtsService(serviceId).getLabel(context);
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
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInfoSection(CurrentReadingState currentReading) {
    final book = currentReading.book;

    return Column(
      children: [
        // Cover
        if (book != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: BookCover(
              book: book,
              height: 180,
              width: 130,
              radius: 12,
            ),
          )
        else
          const SizedBox(height: 180),
        // Book title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            book?.title ?? '',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        // Chapter title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            currentReading.chapterTitle ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

  Widget _buildProgressBar(CurrentReadingState currentReading) {
    final currentPage = currentReading.chapterCurrentPage ?? 0;
    final totalPages = currentReading.chapterTotalPages ?? 0;
    final progress =
        totalPages > 0 ? (currentPage / totalPages).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalPages > 0
                ? '$currentPage / $totalPages'
                : '',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainControls(bool isPlaying) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    Widget controlButton({
      required IconData icon,
      required VoidCallback onPressed,
      double size = 28,
      Color? color,
      String? tooltip,
    }) {
      return IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        color: color ?? onSurfaceColor,
        tooltip: tooltip,
        splashRadius: 28,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous chapter
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
          // Previous sentence
          controlButton(
            icon: EvaIcons.chevron_left,
            onPressed: () => TtsHandler().playPrevious(),
            tooltip: '上一句',
          ),
          // Play / Pause (large)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 32,
                color: Theme.of(context).colorScheme.onPrimary,
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
              splashRadius: 32,
            ),
          ),
          // Next sentence
          controlButton(
            icon: EvaIcons.chevron_right,
            onPressed: () => TtsHandler().playNext(),
            tooltip: '下一句',
          ),
          // Next chapter
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

  Widget _buildRateSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
      child: Row(
        children: [
          Icon(
            EvaIcons.clock_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            L10n.of(context).ttsRate,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Slider(
              value: rate,
              onChanged: (newRate) {
                setState(() {
                  rate = newRate;
                  TtsHandler().rate = newRate;
                });
              },
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${rate.toStringAsFixed(1)}x',
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${rate.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return Row(
      children: [
        Icon(
          EvaIcons.volume_down,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          L10n.of(context).ttsVolume,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: volume,
            onChanged: (newVolume) {
              setState(() {
                volume = newVolume;
                TtsHandler().volume = newVolume;
              });
            },
            min: 0.0,
            max: 1.0,
            divisions: 10,
            label: volume.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }

  Widget _buildPitchSlider() {
    return Row(
      children: [
        Icon(
          EvaIcons.music,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          L10n.of(context).ttsPitch,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: pitch,
            onChanged: (newPitch) {
              setState(() {
                pitch = newPitch;
                TtsHandler().pitch = newPitch;
              });
            },
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: pitch.toStringAsFixed(1),
          ),
        ),
      ],
    );
  }

  Widget _buildStopTimerWidget() {
    return Row(
      children: [
        Icon(
          EvaIcons.clock_outline,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          L10n.of(context).ttsStopAfter(0).split(' ')[0],
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: stopSeconds / 60,
            onChanged: (newValue) {
              setState(() {
                stopSeconds = newValue * 60;
                stopTimer?.cancel();

                if (stopSeconds > 0) {
                  stopTimer = Timer.periodic(
                    const Duration(seconds: 5),
                    (timer) {
                      if (stopSeconds > 5) {
                        stopSeconds -= 5;
                        if (mounted) {
                          setState(() {});
                        }
                        return;
                      } else {
                        TtsHandler().stop();
                        stopSeconds = 0;
                        timer.cancel();
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
                  );
                }
              });
            },
            min: 0.0,
            max: 60.0,
            label: L10n.of(context)
                .commonMinutesFull((stopSeconds / 60).round()),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            L10n.of(context).ttsStopAfter((stopSeconds / 60).ceil()),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildTtsServiceSelector() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            return FractionallySizedBox(
              heightFactor: 0.7,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: const NarrateSettings(),
              ),
            );
          },
        ).then((_) {
          if (mounted) setState(() {});
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              EvaIcons.settings_2_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              L10n.of(context).ttsType,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              _getTtsServiceLabel(context),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogPanel() {
    final logger = TtsDebugLogger();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _showLogs = !_showLogs),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  _showLogs ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'TTS 日志',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_showLogs)
                  TextButton(
                    onPressed: () {
                      final text = logger.getLogsText();
                      if (text.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('日志已复制到剪贴板')),
                        );
                      }
                    },
                    child: const Text('复制', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
        if (_showLogs)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              reverse: true,
              child: ValueListenableBuilder<int>(
                valueListenable: logger.revision,
                builder: (context, _, __) {
                  final logs = logger.logs;
                  if (logs.isEmpty) {
                    return const Text('暂无日志', style: TextStyle(fontSize: 11));
                  }
                  return SelectableText(
                    logs.join('\n'),
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMoreSettings() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _showMoreSettings = !_showMoreSettings),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  _showMoreSettings ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  L10n.of(context).settingsMoreSettings,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showMoreSettings)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVolumeSlider(),
                _buildPitchSlider(),
                _buildStopTimerWidget(),
                _buildTtsServiceSelector(),
                const Divider(),
                _buildLogPanel(),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentReading = ref.watch(currentReadingProvider);

    return ValueListenableBuilder<TtsStateEnum>(
      valueListenable: TtsHandler().ttsStateNotifier,
      builder: (context, ttsState, _) {
        final isPlaying = ttsState == TtsStateEnum.playing;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoSection(currentReading),
                      _buildProgressBar(currentReading),
                      _buildMainControls(isPlaying),
                      const Divider(indent: 32, endIndent: 32),
                      _buildRateSlider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: _buildMoreSettings(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
