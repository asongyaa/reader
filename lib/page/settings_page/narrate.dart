import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/providers/tts_providers.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/online_tts.dart';
import 'package:anx_reader/service/tts/system_tts.dart';
import 'package:anx_reader/service/tts/tts_factory.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/tts_handler.dart';
import 'package:anx_reader/service/tts/tts_service.dart';
import 'package:anx_reader/service/tts/tts_service_provider.dart';
import 'package:anx_reader/utils/get_current_language_code.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/widgets/common/anx_button.dart';
import 'package:anx_reader/widgets/common/anx_segmented_button.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/settings/service_config_form.dart';
import 'package:anx_reader/widgets/settings/settings_section.dart';
import 'package:anx_reader/widgets/settings/settings_tile.dart';
import 'package:anx_reader/service/tts/offline_tts_model_manager.dart';
import 'package:anx_reader/service/tts/tts_engine.dart';
import 'package:anx_reader/service/tts/tts_engine_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NarrateSettings extends ConsumerStatefulWidget {
  const NarrateSettings({super.key});

  @override
  ConsumerState<NarrateSettings> createState() => _NarrateSettingsState();
}

class _NarrateSettingsState extends ConsumerState<NarrateSettings>
    with TickerProviderStateMixin {
  String? selectedVoiceModel;
  Map<String, List<TtsVoice>> groupedVoices = {};
  Set<String> expandedGroups = {};
  final ScrollController _scrollController = ScrollController();
  String? _highlightedModel;
  late AnimationController _highlightAnimationController;
  late Animation<Color?> _highlightAnimation;
  TtsVoice? _currentModelDetails;
  String? _currentModelLanguageGroup;

  final Map<String, GlobalKey> _languageKeys = {};
  bool _showVoiceList = true;
  TabController? _voiceTabController;

  final Map<String, bool> _modelLoadingStates = {};
  Future<void> _testSpeak(String text, String? voiceShortName) async {
    if (voiceShortName != null) {
      if (_modelLoadingStates[voiceShortName] == true) return;
      setState(() {
        _modelLoadingStates[voiceShortName] = true;
      });
    }

    try {
      final handler = TtsHandler();
      if (handler.isPlaying || handler.ttsStateNotifier.value == TtsStateEnum.paused) {
        await handler.stop();
      }
      final tts = TtsFactory().current;
      if (tts is OnlineTts) {
        if (voiceShortName != null) {
          await tts.speakWithVoice(text, voiceShortName);
        } else {
          await tts.speak(content: text);
        }
      } else if (tts is SystemTts) {
        if (voiceShortName != null) {
          await tts.speakWithVoice(text, voiceShortName);
        } else {
          await tts.speak(content: text);
        }
      } else if (tts is TtsEngineAdapter) {
        if (voiceShortName != null) {
          await tts.setVoice(voiceShortName);
        }
        await tts.init(() {}, () async => text, () async => text);
        await tts.speak(content: text);
      }
    } catch (e) {
      AnxLog.severe('TTS Test Speak Error: \$e');
      if (mounted) {
        final errorColor = Theme.of(context).colorScheme.error;
        SmartDialog.show(
          useSystem: true,
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: errorColor),
                const SizedBox(width: 8),
                Text(L10n.of(dialogContext).commonError),
              ],
            ),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: Text(L10n.of(dialogContext).commonOk),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (voiceShortName != null) {
            _modelLoadingStates[voiceShortName] = false;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _highlightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _updateSelectedVoiceFromEngine();
  }

  void _updateSelectedVoiceFromEngine() {
    final engineTypeStr = Prefs().ttsEngineType;
    final engineType = TtsEngineType.values.firstWhere(
      (e) => e.name == engineTypeStr,
      orElse: () => TtsEngineType.system,
    );
    if (engineType == TtsEngineType.sherpaOnnx) {
      selectedVoiceModel = 'sid_${Prefs().offlineTtsSid}';
    } else if (engineType.isOnline) {
      final voice = getTtsServiceProvider(engineType).getSelectedVoice();
      selectedVoiceModel = voice.isNotEmpty
          ? voice
          : getTtsServiceProvider(engineType).resolveVoice(null);
    } else {
      selectedVoiceModel = Prefs().getTtsVoiceModel('system');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _highlightAnimation = ColorTween(
      begin: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
      end: Colors.transparent,
    ).animate(_highlightAnimationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _highlightedModel = null;
          });
        }
      });
  }

  @override
  void dispose() {
    _voiceTabController?.dispose();
    _scrollController.dispose();
    _highlightAnimationController.dispose();
    super.dispose();
  }

  void _updateCurrentModelDetails(List<TtsVoice> voices) {
    if (selectedVoiceModel != null) {
      for (var voice in voices) {
        if (voice.shortName == selectedVoiceModel) {
          _currentModelDetails = voice;
          break;
        }
      }

      for (var entry in groupedVoices.entries) {
        for (var voice in entry.value) {
          if (voice.shortName == selectedVoiceModel) {
            _currentModelLanguageGroup = entry.key;
            break;
          }
        }
        if (_currentModelLanguageGroup != null) break;
      }
    }
  }

  void _scrollToSelectedModel() {
    if (selectedVoiceModel == null || _currentModelLanguageGroup == null) {
      return;
    }

    if (!expandedGroups.contains(_currentModelLanguageGroup)) {
      setState(() {
        expandedGroups.add(_currentModelLanguageGroup!);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _languageKeys[_currentModelLanguageGroup];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }

      setState(() {
        _highlightedModel = selectedVoiceModel;
      });
      _highlightAnimationController.reset();
      _highlightAnimationController.forward();
    });
  }

  void _groupVoicesByLanguage(List<TtsVoice> voices) {
    groupedVoices.clear();

    for (var voice in voices) {
      String locale = voice.locale;
      String languageName = _getLanguageNameFromLocale(locale);

      if (!groupedVoices.containsKey(languageName)) {
        groupedVoices[languageName] = [];
      }

      groupedVoices[languageName]!.add(voice);
    }
  }

  String _getLanguageNameFromLocale(String locale) {
    if (locale.isEmpty) return 'Unknown';
    String langCode = locale.split('-')[0].toLowerCase();

    const Map<String, String> languageMap = {
      'ar': 'العربية',
      'bg': 'Български',
      'ca': 'Català',
      'cs': 'Čeština',
      'da': 'Dansk',
      'de': 'Deutsch',
      'el': 'Ελληνικά',
      'en': 'English',
      'es': 'Español',
      'et': 'Eesti',
      'fi': 'Suomi',
      'fr': 'Français',
      'gl': 'Galego',
      'gu': 'ગુજરાતી',
      'he': 'עברית',
      'hi': 'हिन्दी',
      'hr': 'Hrvatski',
      'hu': 'Magyar',
      'id': 'Bahasa Indonesia',
      'it': 'Italiano',
      'ja': '日本語',
      'ko': '한국어',
      'lt': 'Lietuvių',
      'lv': 'Latviešu',
      'ms': 'Bahasa Melayu',
      'mt': 'Malti',
      'nb': 'Norsk bokmål',
      'nl': 'Nederlands',
      'pl': 'Polski',
      'pt': 'Português',
      'ro': 'Română',
      'ru': 'Русский',
      'sk': 'Slovenčina',
      'sl': 'Slovenščina',
      'sv': 'Svenska',
      'ta': 'தமிழ்',
      'te': 'తెలుగు',
      'th': 'ไทย',
      'tr': 'Türkçe',
      'uk': 'Українська',
      'ur': 'اردو',
      'vi': 'Tiếng Việt',
      'zh': '中文',
      'yue': '粵語',
      'wuu': '吳語',
    };

    return languageMap[langCode] ?? locale;
  }

  void _toggleGroup(String languageName) {
    setState(() {
      if (expandedGroups.contains(languageName)) {
        expandedGroups.remove(languageName);
      } else {
        expandedGroups.add(languageName);
      }
    });
  }

  void _selectVoiceModel(String shortName) {
    final engineTypeStr = ref.read(ttsEngineTypeProvider);
    final engineType = TtsEngineType.values.firstWhere(
      (e) => e.name == engineTypeStr,
      orElse: () => TtsEngineType.system,
    );
    if (engineType == TtsEngineType.sherpaOnnx) {
      TtsHandler().tts.setVoice(shortName);
      setState(() {
        selectedVoiceModel = shortName;
      });
      _showVoiceSelectedToast(shortName);
      return;
    }

    if (engineType.isOnline) {
      final provider = getTtsServiceProvider(engineType);
      final hasVoiceField = provider.getConfig().containsKey('voice');
      if (hasVoiceField) {
        ref
            .read(onlineTtsConfigProvider(engineType.name).notifier)
            .updateConfig('voice', shortName);
      }
      provider.setSelectedVoice(shortName);
      setState(() {
        selectedVoiceModel = shortName;
      });
      _showVoiceSelectedToast(shortName);
      return;
    }

    // system
    Prefs().setTtsVoiceModel('system', shortName);
    setState(() {
      selectedVoiceModel = shortName;
    });
    _showVoiceSelectedToast(shortName);
  }

  void _showVoiceSelectedToast(String shortName) {
    String voiceName = shortName;
    for (final voices in groupedVoices.values) {
      for (final voice in voices) {
        if (voice.shortName == shortName) {
          voiceName = voice.name;
          break;
        }
      }
      if (voiceName != shortName) break;
    }
    SmartDialog.showToast('语音模型: $voiceName 设置成功');
  }

  IconData _getGenderIcon(String gender) {
    switch (gender.toLowerCase()) {
      case 'female':
        return Icons.female;
      case 'male':
        return Icons.male;
      default:
        return Icons.person;
    }
  }

  String _getCurrentModelDisplayName() {
    if (_currentModelDetails == null) {
      return L10n.of(context).settingsNarrateVoiceModelNotSelected;
    }
    return _currentModelDetails!.name;
  }

  String _getCurrentModelLanguageName() {
    if (_currentModelDetails == null) return '';
    return _currentModelDetails!.locale;
  }

  String _getCurrentModelGender() {
    if (_currentModelDetails == null) return '';
    return _currentModelDetails!.gender;
  }

  IconData _getEngineTypeIcon(TtsEngineType type) {
    return switch (type) {
      TtsEngineType.system => Icons.volume_up,
      TtsEngineType.edge => Icons.language,
      TtsEngineType.azure => Icons.cloud,
      TtsEngineType.sherpaOnnx => Icons.wifi_off,
    };
  }

  String _getEngineTypeSubtitle(TtsEngineType type) {
    return switch (type) {
      TtsEngineType.system => L10n.of(context).ttsTypeSystemSubtitle,
      TtsEngineType.edge => L10n.of(context).ttsTypeEdgeSubtitle,
      TtsEngineType.azure => L10n.of(context).ttsTypeAzureSubtitle,
      TtsEngineType.sherpaOnnx => L10n.of(context).ttsTypeOfflineSubtitle,
    };
  }

  void _showEngineTypePicker() {
    final currentEngineTypeStr = Prefs().ttsEngineType;
    final currentEngineType = TtsEngineType.values.firstWhere(
      (e) => e.name == currentEngineTypeStr,
      orElse: () => TtsEngineType.system,
    );

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
              L10n.of(ctx).ttsType,
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...TtsEngineType.values.map((type) => ListTile(
                  title: Text(getTtsEngineTypeLabel(ctx, type)),
                  trailing: type == currentEngineType
                      ? Icon(Icons.check,
                          color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (type == currentEngineType) return;

                    await TtsHandler().switchEngineType(type.name);
                    ref.read(ttsEngineTypeProvider.notifier).state =
                        type.name;
                    _updateSelectedVoiceFromEngine();
                    setState(() {});
                    ref.refresh(ttsVoicesProvider);
                    SmartDialog.showToast('引擎已切换，建议重启应用以确保播放正常');
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engineTypeStr = ref.watch(ttsEngineTypeProvider);
    final engineType = TtsEngineType.values.firstWhere(
      (e) => e.name == engineTypeStr,
      orElse: () => TtsEngineType.system,
    );

    // Listen to config changes to refresh voice list (only effective when online)
    ref.listen(onlineTtsConfigProvider(engineType.name), (prev, next) {
      if (prev != next && engineType.isOnline) {
        ref.refresh(ttsVoicesProvider);
        setState(() {
          selectedVoiceModel =
              getTtsServiceProvider(engineType).getSelectedVoice();
        });
      }
    });

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 50.0),
      children: [
        // --- TTS Engine Type ---
        SettingsSection(
          title: Text(L10n.of(context).ttsType),
          tiles: [
            SettingsTile.navigation(
              leading: Icon(_getEngineTypeIcon(engineType)),
              title: Text(getTtsEngineTypeLabel(context, engineType)),
              value: Text(_getEngineTypeSubtitle(engineType)),
              onPressed: (_) => _showEngineTypePicker(),
            ),
            if (engineType.isOnline)
              CustomSettingsTile(
                  child: _buildConfigSection(engineType.name)),
            if (engineType == TtsEngineType.sherpaOnnx)
              CustomSettingsTile(
                child: _ModelDownloadCard(
                  onModelDeleted: () {
                    ref.refresh(ttsVoicesProvider);
                    setState(() {
                      selectedVoiceModel = null;
                    });
                  },
                  onModelChanged: () async {
                    await TtsFactory().switchEngineType(
                      TtsEngineType.sherpaOnnx.name,
                      forceRecreate: true,
                    );
                    ref.refresh(ttsVoicesProvider);
                    setState(() {
                      selectedVoiceModel = 'sid_${Prefs().offlineTtsSid}';
                    });
                  },
                ),
              ),
          ],
        ),

        // --- Audio Settings ---
        SettingsSection(
          title: Text(L10n.of(context).settingsNarrateTtsService),
          tiles: [
            SettingsTile.switchTile(
                title: Text(L10n.of(context).allowMixing),
                description: Text(L10n.of(context).enableMixTip),
                initialValue: Prefs().allowMixWithOtherAudio,
                onToggle: (value) {
                  Prefs().allowMixWithOtherAudio = value;
                  setState(() {});
                }),
          ],
        ),

        // --- Voice Models ---
        SettingsSection(
          title: Text(L10n.of(context).settingsNarrateTtsVoiceModels),
          tiles: [
            CustomSettingsTile(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [..._buildVoiceListContent()],
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildConfigSection(String engineTypeName) {
    final engineType = TtsEngineType.values.firstWhere(
      (e) => e.name == engineTypeName,
      orElse: () => TtsEngineType.system,
    );
    if (!engineType.isOnline) return const SizedBox.shrink();

    final provider = getTtsServiceProvider(engineType);
    final configItems = provider.getConfigItems(context);
    if (configItems.isEmpty) return const SizedBox.shrink();

    final config = ref.watch(onlineTtsConfigProvider(engineTypeName));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: ServiceConfigForm(
        configItems: configItems,
        initialConfig: config,
        onConfigChanged: (newConfig) {
          for (var entry in newConfig.entries) {
            ref
                .read(onlineTtsConfigProvider(engineTypeName).notifier)
                .updateConfig(entry.key, entry.value);
          }
        },
      ),
    );
  }

  String _getAutoTestText(Locale locale) {
    if (locale.languageCode == 'zh') {
      return '读万卷书，行万里路';
    }
    return 'Hello, this is a test.';
  }

  String _getLangCodeFromName(String languageName) {
    const Map<String, String> reverseMap = {
      'العربية': 'ar',
      'Български': 'bg',
      'Català': 'ca',
      'Čeština': 'cs',
      'Dansk': 'da',
      'Deutsch': 'de',
      'Ελληνικά': 'el',
      'English': 'en',
      'Español': 'es',
      'Eesti': 'et',
      'Suomi': 'fi',
      'Français': 'fr',
      'Galego': 'gl',
      'ગુજરાતી': 'gu',
      'עברית': 'he',
      'हिन्दी': 'hi',
      'Hrvatski': 'hr',
      'Magyar': 'hu',
      'Bahasa Indonesia': 'id',
      'Italiano': 'it',
      '日本語': 'ja',
      '한국어': 'ko',
      'Lietuvių': 'lt',
      'Latviešu': 'lv',
      'Bahasa Melayu': 'ms',
      'Malti': 'mt',
      'Norsk bokmål': 'nb',
      'Nederlands': 'nl',
      'Polski': 'pl',
      'Português': 'pt',
      'Română': 'ro',
      'Русский': 'ru',
      'Slovenčina': 'sk',
      'Slovenščina': 'sl',
      'Svenska': 'sv',
      'தமிழ்': 'ta',
      'తెలుగు': 'te',
      'ไทย': 'th',
      'Türkçe': 'tr',
      'Українська': 'uk',
      'اردو': 'ur',
      'Tiếng Việt': 'vi',
      '中文': 'zh',
      '粵語': 'yue',
      '吳語': 'wuu',
    };
    return reverseMap[languageName] ?? languageName.toLowerCase();
  }

  Widget _buildVoiceListItem(TtsVoice voice, String testText) {
    final shortName = voice.shortName;
    final isSelected = selectedVoiceModel == shortName;

    String localizedGender = voice.gender.toLowerCase() == 'female'
        ? L10n.of(context).settingsNarrateVoiceModelFemale
        : voice.gender.toLowerCase() == 'male'
            ? L10n.of(context).settingsNarrateVoiceModelMale
            : voice.gender;

    final displayText = '${voice.name}-$localizedGender ${voice.locale}';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        displayText,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: _modelLoadingStates[shortName] == true
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 20),
            onPressed: () => _testSpeak(testText, shortName),
            tooltip: L10n.of(context).commonTest,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          if (isSelected)
            Icon(Icons.check, size: 20, color: Theme.of(context).colorScheme.primary),
        ],
      ),
      onTap: () => _selectVoiceModel(shortName),
      selected: isSelected,
    );
  }

  Widget _buildVoiceListForTab(List<TtsVoice> voices, String testText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: voices.map((voice) => _buildVoiceListItem(voice, testText)).toList(),
    );
  }

  List<Widget> _buildVoiceListContent() {
    final voicesAsync = ref.watch(ttsVoicesProvider);

    return voicesAsync.when(
      data: (voices) {
        if (voices.isEmpty) {
          return [
            Center(child: Text(L10n.of(context).settingsNarrateNoVoicesFound))
          ];
        }

        _groupVoicesByLanguage(voices);
        _updateCurrentModelDetails(voices);

        final currentLocale = Localizations.localeOf(context);
        final currentLangCode = currentLocale.languageCode;
        var sortedEntries = groupedVoices.entries.toList()
          ..sort((a, b) {
            final aCode = _getLangCodeFromName(a.key);
            final bCode = _getLangCodeFromName(b.key);
            if (aCode == currentLangCode) return -1;
            if (bCode == currentLangCode) return 1;
            return a.key.compareTo(b.key);
          });

        final testText = _getAutoTestText(currentLocale);

        if (_voiceTabController == null ||
            _voiceTabController!.length != sortedEntries.length) {
          _voiceTabController?.dispose();
          _voiceTabController =
              TabController(length: sortedEntries.length, vsync: this);
        }

        return [
          TabBar(
            controller: _voiceTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: sortedEntries.map((e) => Tab(text: e.key)).toList(),
          ),
          AnimatedBuilder(
            animation: _voiceTabController!,
            builder: (context, child) {
              final index = _voiceTabController!.index;
              return _buildVoiceListForTab(
                  sortedEntries[index].value, testText);
            },
          ),
        ];
      },
      loading: () => [const Center(child: CircularProgressIndicator())],
      error: (err, stack) => [Center(child: Text('Error: \$err'))],
    );
  }

}

class _ModelDownloadCard extends StatefulWidget {
  final VoidCallback? onModelDeleted;
  final VoidCallback? onModelChanged;

  const _ModelDownloadCard({this.onModelDeleted, this.onModelChanged});

  @override
  State<_ModelDownloadCard> createState() => _ModelDownloadCardState();
}

class _ModelDownloadCardState extends State<_ModelDownloadCard> {
  final OfflineTtsModelManager _modelManager = OfflineTtsModelManager();
  bool? _isDownloaded;
  String _modelName = '';
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importStatus = '';

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final downloaded = await _modelManager.isAnyModelInstalled();
    final name = await _modelManager.getInstalledModelName();
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        _modelName = name;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _modelManager.downloadModel(
        type: TtsModelType.vitsMeloZhEn,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );
      await _checkModelStatus();
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
        });
        widget.onModelChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        SmartDialog.show(
          useSystem: true,
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (dialogContext) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error,
                    color: Theme.of(dialogContext).colorScheme.error),
                const SizedBox(width: 8),
                const Text('Download Failed'),
              ],
            ),
            content: Text('\$e'),
            actions: [
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: Text(L10n.of(dialogContext).commonOk),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _importFromFile() async {
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatus = '正在读取文件...';
    });

    try {
      await _modelManager.importFromFile(
        onProgress: (progress) {
          if (mounted) {
            setState(() { _importProgress = progress; });
          }
        },
        onStatus: (msg) {
          if (mounted) {
            setState(() { _importStatus = msg; });
          }
        },
      );

      await _checkModelStatus();
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        widget.onModelChanged?.call();
        SmartDialog.show(
          useSystem: true,
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (dialogContext) => AlertDialog(
            title: Row(children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text('导入成功'),
            ]),
            content: const Text('离线语音模型已就绪，即可开始使用。'),
            actions: [
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: Text(L10n.of(dialogContext).commonOk),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isImporting = false; });
        SmartDialog.show(
          useSystem: true,
          animationType: SmartAnimationType.centerFade_otherSlide,
          builder: (dialogContext) => AlertDialog(
            title: Row(children: [
              Icon(Icons.error, color: Theme.of(dialogContext).colorScheme.error),
              const SizedBox(width: 8),
              const Text('导入失败'),
            ]),
            content: Text('\$e'),
            actions: [
              TextButton(
                onPressed: () => SmartDialog.dismiss(),
                child: Text(L10n.of(dialogContext).commonOk),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteModel() async {
    await _modelManager.deleteAllModels();
    await _checkModelStatus();
    if (mounted) {
      setState(() {});
      widget.onModelDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloaded == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  _isDownloaded!
                      ? Icons.check_circle
                      : Icons.cloud_download,
                  key: ValueKey('model_icon_\$_isDownloaded'),
                  color: _isDownloaded!
                      ? Colors.green
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDownloaded! ? '模型已安装' : '离线 TTS 模型',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (_isDownloaded! && _modelName.isNotEmpty)
                      Text(
                        _modelName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isDownloading || _isImporting) ...[
            const SizedBox(height: 12),
            if (_isImporting) ...[
              Text(_importStatus, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            LinearProgressIndicator(value: _isDownloading ? _downloadProgress : _importProgress),
            const SizedBox(height: 8),
            Text(
              _isDownloading
                  ? '\${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : '\${(_importProgress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              _isDownloaded!
                  ? '离线语音模型已就绪'
                  : '下载或导入离线语音模型，\n即可开始使用离线 TTS。',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          if (!_isDownloading && !_isImporting)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _isDownloaded!
                    ? [
                        AnxButton(
                          type: AnxButtonType.outlined,
                          onPressed: _deleteModel,
                          child: const Text('删除模型'),
                        ),
                      ]
                    : [
                        AnxButton(
                          onPressed: _startDownload,
                          child: const Text('下载'),
                        ),
                        AnxButton(
                          type: AnxButtonType.outlined,
                          onPressed: _importFromFile,
                          child: const Text('从文件导入'),
                        ),
                      ],
              ),
            ),
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('导入中请勿离开页面...', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
