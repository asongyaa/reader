import 'package:anx_reader/models/chapter_split_rule.dart';

const String kDefaultChapterSplitRuleId = 'default_chapter_rule';

final List<ChapterSplitRule> builtinChapterSplitRules = [
  ChapterSplitRule(
    id: kDefaultChapterSplitRuleId,
    name: 'Default (mixed languages)',
    pattern:
        r'^[ \t　]*(第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇]|[卷部][ \t　]*[一二三四五六七八九十零〇百千万两\d]+|序[ \t　]*[章言]?|楔子|引[ \t　]*[子言]?|尾声|后记|番外|终章|尾声|chap(?:ter)\.?|vol(?:ume)?\.?|book|bk)[：:\t　\-—.·]*(?:\S.*)?$|^[ \t　]*(第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇]|[卷部][ \t　]*[一二三四五六七八九十零〇百千万两\d]+|序[ \t　]*[章言]?|楔子|引[ \t　]*[子言]?|尾声|后记|番外|终章|尾声|chap(?:ter)\.?|vol(?:ume)?\.?|book|bk)[ \t　]*$',
    samples: [
      '第一章 起始之地',
      '第 1 章 傻子',
      '第十二卷 风云再起',
      '第三节 阴谋初现',
      '第四回 梦里花落',
      '序章 黎明之前',
      '楔子',
      '后记',
      '终章',
      'Chapter 12: The Journey',
      'chap 3. another life',
      'Book 1 - Dawn of Era',
      'Vol.2 A new world',
      'bk 4 - outside sample',
      '  第三章 有空闲格',
    ],
    isBuiltin: true,
    caseSensitive: false,
    multiLine: true,
  ),
  ChapterSplitRule(
    id: 'cn_only_numeric',
    name: 'Chinese (第X章)',
    pattern:
        r'^\s*第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇](?:[：:\t　.\-—].*)?$',
    samples: [
      '第一章 少年出山',
      '第二十章 ：终极之战',
      '第 1 章 傻子',
      '第3章- 遗失的记忆',
      '第四卷 序章',
      '第三回 梁山聚义',
      '第二节 暗流涌动',
    ],
    isBuiltin: true,
    caseSensitive: false,
    multiLine: true,
  ),
  ChapterSplitRule(
    id: 'en_chapter_number',
    name: 'English (Chapter N)',
    pattern: r'^\s*chapter\s+\d+(?:[ .:-].*)?$',
    samples: [
      'Chapter 1: Beginning',
      'chapter 23 - A twist',
      'CHAPTER 99. Finale',
      'chapter one',
    ],
    isBuiltin: true,
    caseSensitive: false,
    multiLine: true,
  ),
  ChapterSplitRule(
    id: 'en_volume_number',
    name: 'English (Volume/Book)',
    pattern: r'^\s*(volume|book)\s+\d+(?:[ .:-].*)?$',
    samples: [
      'Volume 1: Arrival',
      'Book 2 - Secrets',
      'volume 03 introduction',
      'vol. 4',
    ],
    isBuiltin: true,
    caseSensitive: false,
    multiLine: true,
  ),
];

ChapterSplitRule getDefaultChapterSplitRule() {
  return builtinChapterSplitRules.firstWhere(
    (rule) => rule.id == kDefaultChapterSplitRuleId,
  );
}

ChapterSplitRule? findBuiltinChapterSplitRuleById(String id) {
  try {
    return builtinChapterSplitRules.firstWhere((rule) => rule.id == id);
  } catch (_) {
    return null;
  }
}
