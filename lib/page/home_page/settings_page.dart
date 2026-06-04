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
import 'package:anx_reader/widgets/settings/webdav_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);
    final themeLabel = themeModeToString(Prefs().themeMode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(l10n.navBarSettings,
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant, height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Column(
                    children: [
                      // Theme mode picker
                      ListTile(
                        leading: Icon(Icons.brightness_6, color: cs.primary),
                        title: Text(l10n.settingsAppearanceTheme),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(themeLabel,
                                style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: cs.primary),
                          ],
                        ),
                        onTap: _showThemePicker,
                      ),
                      Divider(color: cs.outlineVariant, height: 1),
                      // WebDAV switch
                      webdavSwitch(context, setState, ref),
                      Divider(color: cs.outlineVariant, height: 1),
                      // Settings list
                      ListTile(
                        leading: Icon(Icons.color_lens_outlined,
                            color: cs.primary),
                        title: Text(l10n.settingsAppearance),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(context,
                            l10n.settingsAppearance, const AppearanceSetting()),
                      ),
                      ListTile(
                        leading:
                            Icon(Icons.book_rounded, color: cs.primary),
                        title: Text(l10n.settingsReading),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(context, l10n.settingsReading,
                            const ReadingSettings()),
                      ),
                      ListTile(
                        leading:
                            Icon(Icons.sync_outlined, color: cs.primary),
                        title: Text(l10n.settingsSync),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(
                            context, l10n.settingsSync, const SyncSetting()),
                      ),
                      ListTile(
                        leading:
                            Icon(EvaIcons.headphones, color: cs.primary),
                        title: Text(l10n.settingsNarrate),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(context, l10n.settingsNarrate,
                            const NarrateSettings()),
                      ),
                      ListTile(
                        leading: Icon(Icons.translate_outlined,
                            color: cs.primary),
                        title: Text(l10n.settingsTranslate),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(context,
                            l10n.settingsTranslate, const TranslateSetting()),
                      ),
                      ListTile(
                        leading:
                            Icon(Icons.storage_outlined, color: cs.primary),
                        title: Text(l10n.storage),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(
                            context, l10n.storage, const StorageSettings()),
                      ),
                      ListTile(
                        leading:
                            Icon(Icons.shield_outlined, color: cs.primary),
                        title: Text(l10n.settingsAdvanced),
                        trailing:
                            Icon(Icons.chevron_right, color: cs.primary),
                        onTap: () => _navigateTo(context, l10n.settingsAdvanced,
                            const AdvancedSetting()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
