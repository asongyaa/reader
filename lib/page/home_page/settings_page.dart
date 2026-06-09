import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/settings_page/advanced.dart';
import 'package:anx_reader/page/settings_page/appearance.dart';
import 'package:anx_reader/page/settings_page/narrate.dart';
import 'package:anx_reader/page/settings_page/reading.dart';
import 'package:anx_reader/page/settings_page/storege.dart';
import 'package:anx_reader/page/settings_page/sync.dart';
import 'package:anx_reader/page/settings_page/translate.dart';
import 'package:anx_reader/utils/theme_mode_to_string.dart';
import 'package:anx_reader/widgets/common/anx_segmented_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  void _navigateTo(BuildContext context, String title, Widget body) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body,
        ),
      ),
    );
  }

  void _showThemePicker() {
    final current = themeModeToString(Prefs().themeMode);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(L10n.of(context).settingsAppearanceTheme,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              AnxSegmentedButton<String>(
                segments: <SegmentButtonItem<String>>[
                  SegmentButtonItem(
                    value: 'auto',
                    label: L10n.of(context).settingsSystemMode,
                    icon: const Icon(Icons.brightness_auto),
                  ),
                  SegmentButtonItem(
                    value: 'dark',
                    label: L10n.of(context).settingsDarkMode,
                    icon: const Icon(Icons.brightness_2),
                  ),
                  SegmentButtonItem(
                    value: 'light',
                    label: L10n.of(context).settingsLightMode,
                    icon: const Icon(Icons.brightness_5),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (Set<String> newSelection) {
                  Prefs().saveThemeModeToPrefs(newSelection.first);
                  setState(() {});
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeLabel() {
    final mode = themeModeToString(Prefs().themeMode);
    switch (mode) {
      case 'dark': return '已开启';
      case 'light': return '已关闭';
      default: return '跟随系统';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text('设置', style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  )),
                ],
              ),
            ),
            // Settings list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  _buildItem(title: '深色模式', trailing: _getThemeLabel(), onTap: _showThemePicker),
                  _divider(cs),
                  _buildItem(title: '语言设置', trailing: '默认设置', onTap: () {}),
                  _divider(cs),
                  _buildSwitchItem(
                    title: '选词震动',
                    value: !Prefs().reduceVibrationFeedback,
                    onChanged: (v) { setState(() => Prefs().reduceVibrationFeedback = !v); },
                  ),
                  _divider(cs),
                  _buildItem(title: l10n.settingsAppearance, onTap: () => _navigateTo(context, l10n.settingsAppearance, const AppearanceSetting())),
                  _divider(cs),
                  _buildItem(title: l10n.settingsReading, onTap: () => _navigateTo(context, l10n.settingsReading, const ReadingSettings())),
                  _divider(cs),
                  _buildItem(title: l10n.settingsNarrate, onTap: () => _navigateTo(context, l10n.settingsNarrate, const NarrateSettings())),
                  _divider(cs),
                  _buildItem(title: l10n.settingsTranslate, onTap: () => _navigateTo(context, l10n.settingsTranslate, const TranslateSetting())),
                  _divider(cs),
                  _buildItem(title: l10n.settingsSync, onTap: () => _navigateTo(context, l10n.settingsSync, const SyncSetting())),
                  _divider(cs),
                  _buildItem(title: l10n.storage, onTap: () => _navigateTo(context, l10n.storage, const StorageSettings())),
                  _divider(cs),
                  _buildItem(title: l10n.settingsAdvanced, onTap: () => _navigateTo(context, l10n.settingsAdvanced, const AdvancedSetting())),
                  _divider(cs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({required String title, String? trailing, required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: cs.onSurface))),
            if (trailing != null)
              Text(trailing, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: cs.onSurface))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Divider(height: 1, indent: 24, endIndent: 24, color: cs.outlineVariant.withOpacity(0.5));
  }
}
