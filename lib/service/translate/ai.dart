import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/enums/lang_list.dart';
import 'package:anx_reader/main.dart';
import 'package:anx_reader/service/config/config_item.dart';
import 'package:anx_reader/service/translate/index.dart';
import 'package:flutter/material.dart';

class AiTranslateProvider extends TranslateServiceProvider {
  @override
  TranslateService get service => TranslateService.ai;

  @override
  String getLabel(BuildContext context) => L10n.of(context).navBarAI;

  /// AI translation uses native language names (e.g., "简体中文", "English")
  /// instead of ISO codes for better prompt understanding.
  @override
  String mapLanguageCode(LangListEnum lang) => lang.nativeName;

  @override
  Widget translate(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) {
    return Text(L10n.of(navigatorKey.currentContext!).translateError);
  }

  @override
  Stream<String> translateStream(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) async* {
    yield L10n.of(navigatorKey.currentContext!).translateError;
  }

  @override
  List<ConfigItem> getConfigItems(BuildContext context) {
    return [
      ConfigItem(
        key: 'tip',
        label: 'Tip',
        type: ConfigItemType.tip,
        defaultValue:
            L10n.of(navigatorKey.currentContext!).settingsTranslateAiTip,
      ),
    ];
  }
}
