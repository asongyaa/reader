import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_debug_logger.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/service/tts/tts_service.dart' as tts_svc;
import 'package:anx_reader/widgets/reading_page/widget_title.dart';
import 'package:anx_reader/page/book_player/epub_player.dart';
import 'package:anx_reader/page/settings_page/narrate.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/more_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:icons_plus/icons_plus.dart';
import 'dart:async';

class TtsWidget extends StatefulWidget {
  const TtsWidget({super.key, required this.epubPlayerKey});

  final GlobalKey<EpubPlayerState> epubPlayerKey;

  @override
  State<TtsWidget> createState() => _TtsWidgetState();
}

class _TtsWidgetState extends State<TtsWidget> {
  double volume = TtsHandler().volume;
  double pitch = TtsHandler().pitch;
  double rate = TtsHandler().rate;
  double stopSeconds = 0;
  Timer? stopTimer;
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    if (TtsHandler().ttsStateNotifier.value != TtsStateEnum.playing) {
      // Defer until after the frame to ensure EpubPlayer state is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = widget.epubPlayerKey.currentState;
        if (state == null || !mounted) return;
        TtsHandler()
            .init(state.initTts, state.ttsNext, state.ttsPrev)
            .then((_) {
          TtsDebugLogger().log('TtsWidget: init completed OK');
          // Do NOT auto-play; let user tap the play button manually.
        }).catchError((e, stack) {
          TtsDebugLogger().log('TtsWidget: init error: $e');
          TtsDebugLogger().log(stack.toString());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('TTS 初始化失败: $e'), duration: const Duration(seconds: 5)),
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildLogPanel() {
    final logger = TtsDebugLogger();
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Column(
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
      ),
    );
  }

  String _getTtsServiceLabel(BuildContext context) {
    final engineTypeStr = Prefs().ttsEngineType;
    final engineType = TtsEngineType.values.firstWhere(
      (e) => e.name == engineTypeStr,
      orElse: () => TtsEngineType.system,
    );
    return tts_svc.getTtsEngineTypeLabel(context, engineType);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TtsStateEnum>(
      valueListenable: TtsHandler().ttsStateNotifier,
      builder: (context, ttsState, child) {
        Widget volume() {
          return Row(
            children: [
              Text(L10n.of(context).ttsVolume),
              Expanded(
                child: Slider(
                  value: TtsHandler().volume,
                  onChanged: (newVolume) {
                    setState(() {
                      TtsHandler().volume = newVolume;
                    });
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: TtsHandler().volume.toStringAsFixed(1),
                ),
              ),
            ],
          );
        }

        Widget pitch() {
          return Row(
            children: [
              Text(L10n.of(context).ttsPitch),
              Expanded(
                child: Slider(
                  value: TtsHandler().pitch,
                  onChanged: (newPitch) {
                    setState(() {
                      TtsHandler().pitch = newPitch;
                    });
                  },
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: TtsHandler().pitch.toStringAsFixed(1),
                ),
              ),
            ],
          );
        }

        Widget rate() {
          return Row(
            children: [
              Text(L10n.of(context).ttsRate),
              Expanded(
                child: Slider(
                  value: TtsHandler().rate,
                  onChanged: (newRate) {
                    setState(() {
                      TtsHandler().rate = newRate;
                    });
                  },
                  min: 0.0,
                  max: 2.0,
                  divisions: 10,
                  label: TtsHandler().rate.toStringAsFixed(1),
                ),
              ),
            ],
          );
        }

        Widget sliders() {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
            child: Column(
              children: [
                volume(),
                pitch(),
                rate(),
                Row(
                  children: [
                    Text(L10n.of(context).ttsType),
                    const Spacer(),
                    GestureDetector(
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
                          // Refresh state if needed when sheet closes
                          setState(() {});
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            _getTtsServiceLabel(context),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        Widget buttons() {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () async {
                  audioHandler.stop();
                  final state = widget.epubPlayerKey.currentState;
                  if (state != null) await state.ttsPrevSection();
                  TtsHandler().playPrevious();
                },
                icon: const Icon(EvaIcons.arrowhead_left),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () {
                  TtsHandler().playPrevious();
                },
                icon: const Icon(EvaIcons.chevron_left),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () async {
                  ttsState == TtsStateEnum.playing
                      ? audioHandler.pause()
                      : audioHandler.play();
                },
                icon: ttsState == TtsStateEnum.playing
                    ? const Icon(EvaIcons.pause_circle_outline)
                    : const Icon(EvaIcons.play_circle_outline),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                onPressed: () {
                  audioHandler.stop();
                },
                icon: const Icon(EvaIcons.stop_circle_outline),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () {
                  TtsHandler().playNext();
                },
                icon: const Icon(EvaIcons.chevron_right),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () async {
                  audioHandler.stop();
                  final state = widget.epubPlayerKey.currentState;
                  if (state != null) await state.ttsNextSection();
                  TtsHandler().playNext();
                },
                icon: const Icon(EvaIcons.arrowhead_right),
                splashRadius: 24,
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          );
        }

        Widget stopTimerWidget() {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
            child: Row(
              children: [
                const Icon(EvaIcons.clock_outline),
                const SizedBox(width: 10),
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
                Text(
                  L10n.of(context).ttsStopAfter((stopSeconds / 60).ceil()),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widgetTitle(
                L10n.of(context).ttsNarrator,
                ReadingSettings.style,
              ),
              buttons(),
              const Divider(),
              stopTimerWidget(),
              sliders(),
              const Divider(),
              _buildLogPanel(),
            ],
          ),
        ).animate().slideY(
          begin: 0.1,
          duration: 350.ms,
          curve: Curves.easeOut,
        ).fadeIn(
          duration: 300.ms,
          curve: Curves.easeOut,
        );
      },
    );
  }
}
