import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/text_alignment.dart';
import 'package:anx_reader/enums/writing_mode.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/book_style.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/custom_css_editor.dart';
import 'package:anx_reader/widgets/step_slider.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class StyleSettings extends StatefulWidget {
  const StyleSettings({super.key});

  @override
  State<StyleSettings> createState() => _StyleSettingsState();
}

class _StyleSettingsState extends State<StyleSettings> {
  void _showSliderSheet({
    required BuildContext context,
    required String title,
    required double value,
    required double min,
    required double max,
    required double step,
    required ValueChanged<double> onChanged,
    required String Function(double) thumbLabel,
    List<double>? tickLabels,
    String? leftText,
    String? rightText,
  }) {
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
              Text(title,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              StepSlider(
                value: value,
                min: min,
                max: max,
                step: step,
                onChanged: (v) {
                  setSheetState(() {});
                  onChanged(v);
                },
                thumbLabel: thumbLabel,
                tickLabels: tickLabels,
                leftText: leftText,
                rightText: rightText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget useBookStylesSwitch() {
      return SwitchListTile(
        title: Text(L10n.of(context).useBookStyles),
        subtitle: Text(
          L10n.of(context).useBookStylesDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: Prefs().useBookStyles,
        onChanged: (bool value) {
          setState(() {
            Prefs().useBookStyles = value;
            epubPlayerKey.currentState?.changeStyle(Prefs().bookStyle);
          });
        },
      );
    }

    Widget textIndent(BookStyle bookStyle, StateSetter setState) {
      bool enabled = !Prefs().useBookStyles;
      return InkWell(
        onTap: enabled
            ? () => _showSliderSheet(
                  context: context,
                  title: L10n.of(context).readingPageIndent,
                  value: bookStyle.indent,
                  min: -0.5,
                  max: 8,
                  step: 0.5,
                  onChanged: (v) {
                    setState(() {
                      bookStyle.indent = v;
                      epubPlayerKey.currentState?.changeStyle(bookStyle);
                      Prefs().saveBookStyleToPrefs(bookStyle);
                    });
                  },
                  thumbLabel: (v) => v < 0
                      ? L10n.of(context).readingPageIndentNoChange
                      : v.toStringAsFixed(1),
                  tickLabels: const [2, 4, 6],
                  leftText: '无',
                  rightText: '8',
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              const Icon(Icons.format_indent_increase, size: 20),
              const SizedBox(width: 8),
              Text(L10n.of(context).readingPageIndent),
              const Spacer(),
              Text(
                bookStyle.indent < 0
                    ? L10n.of(context).readingPageIndentNoChange
                    : bookStyle.indent.toStringAsFixed(1),
                style: TextStyle(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).disabledColor),
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
      );
    }

    Widget sideMarginSlider(BookStyle bookStyle, StateSetter setState) {
      return InkWell(
        onTap: () => _showSliderSheet(
          context: context,
          title: Prefs().writingMode == WritingModeEnum.verticalRl
              ? L10n.of(context).readingPageVerticleMargin
              : L10n.of(context).readingPageSideMargin,
          value: bookStyle.sideMargin,
          min: 0,
          max: 20,
          step: 1,
          onChanged: (v) {
            setState(() {
              bookStyle.sideMargin = v;
              epubPlayerKey.currentState?.changeStyle(bookStyle);
              Prefs().saveBookStyleToPrefs(bookStyle);
            });
          },
          thumbLabel: (v) => v.toStringAsFixed(0),
          tickLabels: const [5, 10, 15],
          leftText: '0',
          rightText: '20',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(
                Prefs().writingMode == WritingModeEnum.verticalRl
                    ? Bootstrap.arrows_vertical
                    : Bootstrap.arrows,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(Prefs().writingMode == WritingModeEnum.verticalRl
                  ? L10n.of(context).readingPageVerticleMargin
                  : L10n.of(context).readingPageSideMargin),
              const Spacer(),
              Text(
                bookStyle.sideMargin.toStringAsFixed(0),
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

    Widget topMarginSlider(BookStyle bookStyle, StateSetter setState) {
      final label = Prefs().writingMode == WritingModeEnum.verticalRl
          ? L10n.of(context).readingPageRightMargin
          : L10n.of(context).readingPageTopMargin;
      return InkWell(
        onTap: () => _showSliderSheet(
          context: context,
          title: label,
          value: bookStyle.topMargin,
          min: 0,
          max: 200,
          step: 20,
          onChanged: (v) {
            setState(() {
              bookStyle.topMargin = v;
              epubPlayerKey.currentState?.changeStyle(bookStyle);
              Prefs().saveBookStyleToPrefs(bookStyle);
            });
          },
          thumbLabel: (v) => (v / 20).toStringAsFixed(0),
          tickLabels: const [60, 100, 140],
          leftText: '0',
          rightText: '200',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(
                Prefs().writingMode == WritingModeEnum.verticalRl
                    ? Bootstrap.chevron_bar_right
                    : Bootstrap.chevron_bar_up,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(label),
              const Spacer(),
              Text(
                (bookStyle.topMargin / 20).toStringAsFixed(0),
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

    Widget bottomMarginSlider(BookStyle bookStyle, StateSetter setState) {
      final label = Prefs().writingMode == WritingModeEnum.verticalRl
          ? L10n.of(context).readingPageLeftMargin
          : L10n.of(context).readingPageBottomMargin;
      return InkWell(
        onTap: () => _showSliderSheet(
          context: context,
          title: label,
          value: bookStyle.bottomMargin,
          min: 0,
          max: 200,
          step: 20,
          onChanged: (v) {
            setState(() {
              bookStyle.bottomMargin = v;
              epubPlayerKey.currentState?.changeStyle(bookStyle);
              Prefs().saveBookStyleToPrefs(bookStyle);
            });
          },
          thumbLabel: (v) => (v / 20).toStringAsFixed(0),
          tickLabels: const [60, 100, 140],
          leftText: '0',
          rightText: '200',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(
                Prefs().writingMode == WritingModeEnum.verticalRl
                    ? Bootstrap.chevron_bar_left
                    : Bootstrap.chevron_bar_down,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(label),
              const Spacer(),
              Text(
                (bookStyle.bottomMargin / 20).toStringAsFixed(0),
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

    Widget letterSpacingSlider(BookStyle bookStyle, StateSetter setState) {
      bool enabled = !Prefs().useBookStyles;
      return InkWell(
        onTap: enabled
            ? () => _showSliderSheet(
                  context: context,
                  title: L10n.of(context).readingPageLetterSpacing,
                  value: bookStyle.letterSpacing,
                  min: -3,
                  max: 7,
                  step: 1,
                  onChanged: (v) {
                    setState(() {
                      bookStyle.letterSpacing = v;
                      epubPlayerKey.currentState?.changeStyle(bookStyle);
                      Prefs().saveBookStyleToPrefs(bookStyle);
                    });
                  },
                  thumbLabel: (v) => v.toString(),
                  tickLabels: const [0, 3],
                  leftText: '-3',
                  rightText: '7',
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              const Icon(Icons.compare_arrows, size: 20),
              const SizedBox(width: 8),
              Text(L10n.of(context).readingPageLetterSpacing),
              const Spacer(),
              Text(
                bookStyle.letterSpacing.toString(),
                style: TextStyle(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).disabledColor),
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
      );
    }

    Widget fontWeightSlider(BookStyle bookStyle, StateSetter setState) {
      bool enabled = !Prefs().useBookStyles;
      return InkWell(
        onTap: enabled
            ? () => _showSliderSheet(
                  context: context,
                  title: L10n.of(context).readingPageFontWeight,
                  value: bookStyle.fontWeight,
                  min: 100,
                  max: 900,
                  step: 100,
                  onChanged: (v) {
                    setState(() {
                      bookStyle.fontWeight = v;
                      epubPlayerKey.currentState?.changeStyle(bookStyle);
                      Prefs().saveBookStyleToPrefs(bookStyle);
                    });
                  },
                  thumbLabel: (v) => v.toStringAsFixed(0),
                  tickLabels: const [300, 500, 700],
                  leftText: '细',
                  rightText: '粗',
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              const Icon(Icons.format_bold, size: 20),
              const SizedBox(width: 8),
              Text(L10n.of(context).readingPageFontWeight),
              const Spacer(),
              Text(
                bookStyle.fontWeight.toStringAsFixed(0),
                style: TextStyle(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).disabledColor),
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
      );
    }

    Widget headingFontSizeSlider(BookStyle bookStyle, StateSetter setState) {
      bool enabled = !Prefs().useBookStyles;
      return InkWell(
        onTap: enabled
            ? () => _showSliderSheet(
                  context: context,
                  title: L10n.of(context).headingFontSize,
                  value: bookStyle.headingFontSize,
                  min: 0.5,
                  max: 2.0,
                  step: 0.1,
                  onChanged: (v) {
                    setState(() {
                      bookStyle.headingFontSize = v;
                      epubPlayerKey.currentState?.changeStyle(bookStyle);
                      Prefs().saveBookStyleToPrefs(bookStyle);
                    });
                  },
                  thumbLabel: (v) => v.toStringAsFixed(1),
                  tickLabels: const [1.0, 1.5],
                  leftText: '小',
                  rightText: '大',
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              const Icon(Icons.title, size: 20),
              const SizedBox(width: 8),
              Text(L10n.of(context).headingFontSize),
              const Spacer(),
              Text(
                bookStyle.headingFontSize.toStringAsFixed(1),
                style: TextStyle(
                    color: enabled
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).disabledColor),
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
      );
    }

    Widget textAlignment() {
      final items = [
        {
          "text": L10n.of(context).textAlignmentAuto,
          "value": TextAlignmentEnum.auto
        },
        {
          "text": L10n.of(context).textAlignmentLeft,
          "value": TextAlignmentEnum.left
        },
        {
          "text": L10n.of(context).textAlignmentCenter,
          "value": TextAlignmentEnum.center
        },
        {
          "text": L10n.of(context).textAlignmentRight,
          "value": TextAlignmentEnum.right
        },
        {
          "text": L10n.of(context).textAlignmentJustify,
          "value": TextAlignmentEnum.justify
        },
      ];

      String currentLabel() {
        final current = Prefs().textAlignment;
        return items.firstWhere((i) => i["value"] == current)["text"] as String;
      }

      return StatefulBuilder(
        builder: (context, setState) => InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.of(context).textAlignment,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    ...items.map((item) {
                      final isSelected =
                          item["value"] == Prefs().textAlignment;
                      return ListTile(
                        title: Text(item["text"] as String),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: Theme.of(ctx).colorScheme.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            Prefs().textAlignment =
                                item["value"] as TextAlignmentEnum;
                            epubPlayerKey.currentState
                                ?.changeStyle(Prefs().bookStyle);
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Text(L10n.of(context).textAlignment,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  currentLabel(),
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
        ),
      );
    }

    Widget sliders() {
      BookStyle bookStyle = Prefs().bookStyle;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => Column(
          children: [
            textIndent(bookStyle, setState),
            sideMarginSlider(bookStyle, setState),
            topMarginSlider(bookStyle, setState),
            bottomMarginSlider(bookStyle, setState),
            letterSpacingSlider(bookStyle, setState),
            fontWeightSlider(bookStyle, setState),
            headingFontSizeSlider(bookStyle, setState),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          useBookStylesSwitch(),
          const Divider(),
          sliders(),
          const SizedBox(height: 16),
          const Divider(),
          textAlignment(),
          CustomCSSEditor(),
        ],
      ),
    );
  }
}
