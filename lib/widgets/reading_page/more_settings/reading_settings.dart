import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/convert_chinese_mode.dart';
import 'package:anx_reader/enums/reading_info.dart';
import 'package:anx_reader/enums/translation_mode.dart';
import 'package:anx_reader/enums/writing_mode.dart';
import 'package:anx_reader/enums/code_highlight_theme.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/reading_info.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/page/settings_page/subpage/fonts.dart';
import 'package:anx_reader/widgets/step_slider.dart';
import 'package:flutter/material.dart';

class ReadingMoreSettings extends StatefulWidget {
  const ReadingMoreSettings({super.key});

  @override
  State<ReadingMoreSettings> createState() => _ReadingMoreSettingsState();
}

class _ReadingMoreSettingsState extends State<ReadingMoreSettings> {
  final isReading =
      epubPlayerKey.currentState != null && epubPlayerKey.currentState!.mounted;

  void _showFixedSheet({
    required String title,
    required List<Widget> children,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.5,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetItem({
    required String title,
    required String currentLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(
              currentLabel,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    Widget downloadFonts() {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.downloadFonts),
        leading: const Icon(Icons.font_download_outlined),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FontsSettingPage(),
            ),
          );
        },
      );
    }

    // --- 写作方向 ---
    Widget writingMode() {
      String label() {
        final m = Prefs().writingMode;
        if (m == WritingModeEnum.auto) return l10n.readingPageWritingDirectionAuto;
        if (m == WritingModeEnum.verticalRl) return l10n.readingPageWritingDirectionVertical;
        return l10n.readingPageWritingDirectionHorizontal;
      }

      return StatefulBuilder(
        builder: (context, setState) => _buildSheetItem(
          title: l10n.readingPageWritingDirection,
          currentLabel: label(),
          onTap: () {
            final items = [
              {'label': l10n.readingPageWritingDirectionAuto, 'value': WritingModeEnum.auto},
              {'label': l10n.readingPageWritingDirectionVertical, 'value': WritingModeEnum.verticalRl},
              {'label': l10n.readingPageWritingDirectionHorizontal, 'value': WritingModeEnum.horizontalTb},
            ];
            _showFixedSheet(
              title: l10n.readingPageWritingDirection,
              children: items.map((item) {
                final isSelected = item['value'] == Prefs().writingMode;
                return ListTile(
                  title: Text(item['label'] as String),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      final newBookStyle = Prefs().bookStyle.copyWith(maxColumnCount: 1);
                      Prefs().saveBookStyleToPrefs(newBookStyle);
                      Prefs().writingMode = item['value'] as WritingModeEnum;
                      epubPlayerKey.currentState?.changeStyle(newBookStyle);
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        ),
      );
    }

    // --- 翻译模式 ---
    Widget translationMode() {
      String label() {
        if (!isReading) return l10n.readingPageOriginal;
        final mode = Prefs().getBookTranslationMode(
            epubPlayerKey.currentState!.widget.book.id);
        if (mode == TranslationModeEnum.translationOnly) return l10n.translationOnly;
        if (mode == TranslationModeEnum.bilingual) return l10n.bilingual;
        return l10n.readingPageOriginal;
      }

      return StatefulBuilder(
        builder: (context, setState) => _buildSheetItem(
          title: l10n.translationMode,
          currentLabel: label(),
          onTap: () {
            if (!isReading) return;
            final items = [
              {'label': l10n.readingPageOriginal, 'value': TranslationModeEnum.off},
              {'label': l10n.translationOnly, 'value': TranslationModeEnum.translationOnly},
              {'label': l10n.bilingual, 'value': TranslationModeEnum.bilingual},
            ];
            final currentMode = Prefs().getBookTranslationMode(
                epubPlayerKey.currentState!.widget.book.id);
            _showFixedSheet(
              title: l10n.translationMode,
              children: items.map((item) {
                final isSelected = item['value'] == currentMode;
                return ListTile(
                  title: Text(item['label'] as String),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      final bookId = epubPlayerKey.currentState!.widget.book.id;
                      final newMode = item['value'] as TranslationModeEnum;
                      Prefs().setBookTranslationMode(bookId, newMode);
                      epubPlayerKey.currentState?.setTranslationMode(newMode);
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        ),
      );
    }

    // --- 列数 ---
    Widget columnCount() {
      String label() {
        final c = Prefs().bookStyle.maxColumnCount;
        if (c == 0) return l10n.readingPageAuto;
        if (c == 1) return l10n.readingPageSingle;
        return l10n.readingPageDouble;
      }

      return StatefulBuilder(
        builder: (context, setState) => _buildSheetItem(
          title: l10n.readingPageColumnCount,
          currentLabel: label(),
          onTap: () {
            final items = [
              {'label': l10n.readingPageAuto, 'value': 0},
              {'label': l10n.readingPageSingle, 'value': 1},
              {'label': l10n.readingPageDouble, 'value': 2},
            ];
            _showFixedSheet(
              title: l10n.readingPageColumnCount,
              children: items.map((item) {
                final isSelected = item['value'] == Prefs().bookStyle.maxColumnCount;
                return ListTile(
                  title: Text(item['label'] as String),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      final newBookStyle = Prefs()
                          .bookStyle
                          .copyWith(maxColumnCount: item['value'] as int);
                      Prefs().saveBookStyleToPrefs(newBookStyle);
                      epubPlayerKey.currentState?.changeStyle(newBookStyle);
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        ),
      );
    }

    // --- 列数切换阈值 ---
    Widget columnThreshold() {
      bool enabled = Prefs().bookStyle.maxColumnCount == 0;
      return StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: enabled
                  ? () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setSheetState) => Padding(
                            padding: EdgeInsets.fromLTRB(24, 24, 24,
                                MediaQuery.of(ctx).padding.bottom + 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.readingPageColumnThreshold,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 20),
                                StepSlider(
                                  value: Prefs().bookStyle.columnThreshold,
                                  min: 400,
                                  max: 1200,
                                  step: 20,
                                  onChanged: (v) {
                                    setSheetState(() {});
                                    setState(() {
                                      final newBookStyle = Prefs()
                                          .bookStyle
                                          .copyWith(columnThreshold: v);
                                      Prefs().saveBookStyleToPrefs(newBookStyle);
                                      epubPlayerKey.currentState
                                          ?.changeStyle(newBookStyle);
                                    });
                                  },
                                  thumbLabel: (v) => '${v.toInt()}px',
                                  tickLabels: const [600, 800, 1000],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.readingPageColumnThreshold,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text(
                      '${Prefs().bookStyle.columnThreshold.toInt()}px',
                      style: TextStyle(
                        color: enabled
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: enabled
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).disabledColor,
                    ),
                  ],
                ),
              ),
            ),
            if (enabled)
              Text(
                l10n.readingPageColumnThresholdTip,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
          ],
        ),
      );
    }

    // --- 简繁转换 ---
    Widget convertChinese() {
      String label() {
        final m = Prefs().readingRules.convertChineseMode;
        if (m == ConvertChineseMode.t2s) return l10n.readingPageSimplified;
        if (m == ConvertChineseMode.s2t) return l10n.readingPageTraditional;
        return l10n.readingPageOriginal;
      }

      return StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetItem(
              title: l10n.readingPageConvertChinese,
              currentLabel: label(),
              onTap: () {
                final items = [
                  {'label': l10n.readingPageOriginal, 'value': ConvertChineseMode.none},
                  {'label': l10n.readingPageSimplified, 'value': ConvertChineseMode.t2s},
                  {'label': l10n.readingPageTraditional, 'value': ConvertChineseMode.s2t},
                ];
                _showFixedSheet(
                  title: l10n.readingPageConvertChinese,
                  children: [
                    ...items.map((item) {
                      final isSelected = item['value'] == Prefs().readingRules.convertChineseMode;
                      return ListTile(
                        title: Text(item['label'] as String),
                        trailing: isSelected
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            Prefs().readingRules = Prefs()
                                .readingRules
                                .copyWith(convertChineseMode: item['value'] as ConvertChineseMode);
                            epubPlayerKey.currentState
                                ?.changeReadingRules(Prefs().readingRules);
                          });
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.readingPageConvertChineseTips,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    // --- 代码高亮主题 ---
    Widget codeHighlightTheme() {
      String label() {
        final t = Prefs().codeHighlightTheme;
        if (t == CodeHighlightThemeEnum.off) return l10n.codeHighlightOff;
        return t.displayName;
      }

      return StatefulBuilder(
        builder: (context, setState) => _buildSheetItem(
          title: l10n.codeHighlightTheme,
          currentLabel: label(),
          onTap: () {
            final allThemes = [
              CodeHighlightThemeEnum.off,
              CodeHighlightThemeEnum.defaultTheme,
              CodeHighlightThemeEnum.github,
              CodeHighlightThemeEnum.oneLight,
              CodeHighlightThemeEnum.materialLight,
              CodeHighlightThemeEnum.vsDark,
              CodeHighlightThemeEnum.oneDark,
              CodeHighlightThemeEnum.dracula,
              CodeHighlightThemeEnum.materialDark,
              CodeHighlightThemeEnum.nord,
              CodeHighlightThemeEnum.nightOwl,
              CodeHighlightThemeEnum.solarizedDark,
              CodeHighlightThemeEnum.atomDark,
            ];
            _showFixedSheet(
              title: l10n.codeHighlightTheme,
              children: allThemes.map((theme) {
                final isSelected = Prefs().codeHighlightTheme == theme;
                final name = theme == CodeHighlightThemeEnum.off
                    ? l10n.codeHighlightOff
                    : theme.displayName;
                return ListTile(
                  title: Text(name),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      Prefs().codeHighlightTheme = theme;
                      epubPlayerKey.currentState?.changeStyle(null);
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        ),
      );
    }

    // --- 页眉页脚信息选择 ---
    Widget buildInfoItem(
      String label,
      ReadingInfoEnum currentValue,
      Function(ReadingInfoEnum) onChanged,
    ) {
      return InkWell(
        onTap: () {
          _showFixedSheet(
            title: label,
            children: ReadingInfoEnum.values.map((info) {
              final isSelected = info == currentValue;
              return ListTile(
                title: Text(info.getL10n(context)),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  onChanged(info);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                currentValue.getL10n(context),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    Widget readingInfo() {
      return StatefulBuilder(
        builder: (context, setState) {
          void updateReadingInfo(ReadingInfoModel info) {
            Prefs().readingInfo = info;
            epubPlayerKey.currentState?.changeReadingInfo();
          }

          Widget buildSliderItem({
            required String label,
            required double value,
            required double min,
            required double max,
            required double step,
            required List<double> tickLabels,
            required ValueChanged<double> onChanged,
          }) {
            return InkWell(
              onTap: () {
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
                            label,
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          StepSlider(
                            value: value,
                            min: min,
                            max: max,
                            step: step,
                            onChanged: (v) {
                              setSheetState(() {});
                              setState(() {
                                onChanged(v);
                                epubPlayerKey.currentState?.changeReadingInfo();
                              });
                            },
                            thumbLabel: (v) => v.toStringAsFixed(0),
                            tickLabels: tickLabels,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(label),
                    const Spacer(),
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          }

          Widget buildSectionSettings({
            required String title,
            required ReadingInfoSectionModel section,
            required ValueChanged<ReadingInfoSectionModel> onChanged,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                buildInfoItem(
                  l10n.readingPageLeft,
                  section.left,
                  (value) {
                    setState(() => onChanged(section.copyWith(left: value)));
                  },
                ),
                buildInfoItem(
                  l10n.readingPageCenter,
                  section.center,
                  (value) {
                    setState(() => onChanged(section.copyWith(center: value)));
                  },
                ),
                buildInfoItem(
                  l10n.readingPageRight,
                  section.right,
                  (value) {
                    setState(() => onChanged(section.copyWith(right: value)));
                  },
                ),
                buildSliderItem(
                  label: l10n.readingSettingsMargin,
                  value: section.verticalMargin,
                  min: 0, max: 80, step: 2,
                  tickLabels: const [20, 40, 60],
                  onChanged: (value) =>
                      onChanged(section.copyWith(verticalMargin: value)),
                ),
                buildSliderItem(
                  label: l10n.readingPageLeftMargin,
                  value: section.leftMargin,
                  min: 0, max: 80, step: 2,
                  tickLabels: const [20, 40, 60],
                  onChanged: (value) =>
                      onChanged(section.copyWith(leftMargin: value)),
                ),
                buildSliderItem(
                  label: l10n.readingPageRightMargin,
                  value: section.rightMargin,
                  min: 0, max: 80, step: 2,
                  tickLabels: const [20, 40, 60],
                  onChanged: (value) =>
                      onChanged(section.copyWith(rightMargin: value)),
                ),
                buildSliderItem(
                  label: l10n.readingPageFontSize,
                  value: section.fontSize,
                  min: 8, max: 24, step: 1,
                  tickLabels: const [12, 16, 20],
                  onChanged: (value) =>
                      onChanged(section.copyWith(fontSize: value)),
                ),
              ],
            );
          }

          final readingInfo = Prefs().readingInfo;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSectionSettings(
                title: l10n.readingPageHeaderSettings,
                section: readingInfo.header,
                onChanged: (section) {
                  updateReadingInfo(readingInfo.copyWith(header: section));
                },
              ),
              const Divider(),
              buildSectionSettings(
                title: l10n.readingPageFooterSettings,
                section: readingInfo.footer,
                onChanged: (section) {
                  updateReadingInfo(readingInfo.copyWith(footer: section));
                },
              ),
            ],
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          downloadFonts(),
          const Divider(height: 20),
          writingMode(),
          translationMode(),
          columnCount(),
          columnThreshold(),
          convertChinese(),
          codeHighlightTheme(),
          const Divider(height: 15),
          readingInfo(),
        ],
      ),
    );
  }
}
