import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/other_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/reading_settings.dart';
import 'package:anx_reader/widgets/reading_page/more_settings/style_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadingSettings extends ConsumerStatefulWidget {
  const ReadingSettings({super.key});

  @override
  ConsumerState<ReadingSettings> createState() => _ReadingSettingsState();
}

class _ReadingSettingsState extends ConsumerState<ReadingSettings> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        _sectionTitle(l10n.readingPageReading, cs),
        ReadingMoreSettings(),
        _sectionTitle(l10n.readingPageStyle, cs),
        StyleSettings(),
        _sectionTitle(l10n.readingPageOther, cs),
        OtherSettings(),
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
}
