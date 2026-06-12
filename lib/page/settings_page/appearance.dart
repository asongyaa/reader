import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

const List<Map<String, String>> languageOptions = [
  {'system': 'System'},
  {'English': 'en'},
  {'简体中文': 'zh-CN'},
  {'繁體中文': 'zh-TW'},
  {'文言文': 'zh-LZH'},
  {'Türkçe': 'tr'},
  {'Deutsch': 'de'},
  {'العربية': 'ar'},
  {'Русский': 'ru'},
  {'Français': 'fr'},
  {'Español': 'es'},
  {'Italiano': 'it'},
  {'Português': 'pt'},
  {'日本語': 'ja'},
  {'한국어': 'ko'},
  {'Română': 'ro'},
];

class AppearanceSetting extends StatefulWidget {
  const AppearanceSetting({super.key});

  @override
  State<AppearanceSetting> createState() => _AppearanceSettingState();
}

class _AppearanceSettingState extends State<AppearanceSetting> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // --- 主题 ---
        _sectionTitle(l10n.settingsAppearanceTheme, cs),
        _buildItem(
          title: l10n.settingsAppearanceThemeColor,
          onTap: () => showColorPickerDialog(context),
          cs: cs,
        ),
        _divider(cs),
        _buildSwitchItem(
          title: 'OLED Dark Mode',
          value: Prefs().trueDarkMode,
          onChanged: (v) => setState(() => Prefs().trueDarkMode = v),
          cs: cs,
        ),
        _divider(cs),
        _buildSwitchItem(
          title: l10n.eInkMode,
          value: Prefs().eInkMode,
          onChanged: (v) => setState(() {
            Prefs().saveThemeModeToPrefs('light');
            Prefs().eInkMode = v;
          }),
          cs: cs,
        ),

        // --- 显示 ---
        _sectionTitle(l10n.settingsAppearanceDisplay, cs),
        _buildSwitchItem(
          title: l10n.settingsAppearanceOpenBookAnimation,
          value: Prefs().openBookAnimation,
          onChanged: (v) => setState(() => Prefs().openBookAnimation = v),
          cs: cs,
        ),
        _divider(cs),
        _buildSwitchItem(
          title: l10n.settingsAdvancedAutoHideBottomBar,
          value: Prefs().autoHideBottomBar,
          onChanged: (v) {
            Prefs().autoHideBottomBar = v;
            setState(() {});
          },
          cs: cs,
        ),
        _divider(cs),
        _buildSwitchItem(
          title: l10n.reduceVibrationFeedback,
          value: Prefs().reduceVibrationFeedback,
          onChanged: (v) => setState(() => Prefs().reduceVibrationFeedback = v),
          cs: cs,
        ),
        _divider(cs),
        _buildSwitchItem(
          title: l10n.readingPageShowActionLabels,
          value: Prefs().showActionLabels,
          onChanged: (v) => setState(() => Prefs().showActionLabels = v),
          cs: cs,
          subtitle: l10n.readingPageShowActionLabelsTips,
        ),

        // --- 底部导航 ---
        _sectionTitle(l10n.settingsAppearanceBottomNavigatorShow, cs),
        _buildSwitchItem(
          title: l10n.navBarStatistics,
          value: Prefs().bottomNavigatorShowStatistics,
          onChanged: (v) =>
              setState(() => Prefs().bottomNavigatorShowStatistics = v),
          cs: cs,
        ),
        _divider(cs),
        _buildSwitchItem(
          title: l10n.navBarNotes,
          value: Prefs().bottomNavigatorShowNote,
          onChanged: (v) =>
              setState(() => Prefs().bottomNavigatorShowNote = v),
          cs: cs,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildItem({
    required String title,
    String? trailing,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 16, color: cs.onSurface))),
            if (trailing != null)
              Text(trailing,
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme cs,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 16, color: cs.onSurface)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitle,
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Divider(
        height: 1,
        indent: 24,
        endIndent: 24,
        color: cs.outlineVariant.withOpacity(0.5));
  }
}

Future<void> showColorPickerDialog(BuildContext context) async {
  final prefsProvider = Provider.of<Prefs>(context, listen: false);
  final currentColor = prefsProvider.themeColor;

  Color pickedColor = currentColor;

  await showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).settingsAppearanceThemeColor,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: pickedColor,
                  onColorChanged: (color) {
                    pickedColor = color;
                  },
                  enableAlpha: false,
                  displayThumbColor: true,
                  pickerAreaHeightPercent: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  child: Text(L10n.of(context).commonCancel),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text(L10n.of(context).commonOk),
                  onPressed: () {
                    prefsProvider.saveThemeToPrefs(pickedColor.value);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
