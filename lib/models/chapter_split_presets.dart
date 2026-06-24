import 'package:anx_reader/models/chapter_split_rule.dart';

const String kDefaultChapterSplitRuleId = 'default_chapter_rule';

final List<ChapterSplitRule> builtinChapterSplitRules = [
  ChapterSplitRule(
    id: kDefaultChapterSplitRuleId,
    name: 'Default (mixed languages)',
    pattern:
        // 第X章 with title (negative lookahead rejects 的/了/中/里 etc.)
        r'^[ \t　]*第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇](?!的|了|中|里|内|前|后|上|下|间|时|所|来|去|到|地|得|着|过|和|与|及|等|个|名|种|件|条|次|场|位|本|段|首|辆|架|艘|只|匹|头|棵|朵|颗|粒|滴|项|款|批|群|堆|帮|伙|双|对|副|套|组|系列|代)[ \t　：:、，；\-—.·～~]*(?:\d+[ \t　]*)?.+$'
        // 第X章 standalone
        r'|^[ \t　]*第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇](?!的|了|中|里|内|前|后|上|下|间|时|所|来|去|到|地|得|着|过|和|与|及|等|个|名|种|件|条|次|场|位|本|段|首|辆|架|艘|只|匹|头|棵|朵|颗|粒|滴|项|款|批|群|堆|帮|伙|双|对|副|套|组|系列|代)[ \t　]*$'
        // 卷之X / 部之X with title
        r'|^[ \t　]*[卷部][ \t　]*之[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　：:、，；\-—.·～~]*(?:\d+[ \t　]*)?.+$'
        // 卷之X / 部之X standalone
        r'|^[ \t　]*[卷部][ \t　]*之[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*$'
        // Special keywords with title
        r'|^[ \t　]*(?:序[ \t　]*[章言]?|楔子|引[ \t　]*[子言]?|外传|后记|番外[ \t　]*篇?|终章|大结局|尾声)[ \t　：:、]*(?:\d+[ \t　]*)?\S.*$'
        // Special keywords standalone
        r'|^[ \t　]*(?:序[ \t　]*[章言]?|楔子|引[ \t　]*[子言]?|外传|后记|番外[ \t　]*篇?|终章|大结局|尾声)[ \t　]*$'
        // English keywords with content
        r'|^[ \t　]*(?:chap(?:ter)?|vol(?:ume)?|book|bk)[ \t　.:/\-—]*\d+(?:[ \t　：:.\-—/]\S*)*$'
        // English keywords standalone
        r'|^[ \t　]*(?:chap(?:ter)?|vol(?:ume)?|book|bk)[ \t　]*$',
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
      '第25章 25 季春',
      '第1章 01 慈孝元年 正月',
      '第    3章',
      '第3   章 标题',
      '第一章、缘起',
      '卷之一 风云初起',
      '外传',
      '大结局',
    ],
    isBuiltin: true,
    caseSensitive: false,
    multiLine: true,
  ),
  ChapterSplitRule(
    id: 'cn_only_numeric',
    name: 'Chinese (第X章)',
    pattern:
        // 第X章 with title (negative lookahead rejects 的/了/中/里 etc.)
        r'^\s*第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇](?!的|了|中|里|内|前|后|上|下|间|时|所|来|去|到|地|得|着|过|和|与|及|等|个|名|种|件|条|次|场|位|本|段|首|辆|架|艘|只|匹|头|棵|朵|颗|粒|滴|项|款|批|群|堆|帮|伙|双|对|副|套|组|系列|代)[ \t　：:、，；.\-—～~]*(?:\d+[ \t　]*)?.+$'
        // 第X章 standalone
        r'|^\s*第[ \t　]*[一二三四五六七八九十零〇百千万两\d]+[ \t　]*[章卷节回部集篇](?!的|了|中|里|内|前|后|上|下|间|时|所|来|去|到|地|得|着|过|和|与|及|等|个|名|种|件|条|次|场|位|本|段|首|辆|架|艘|只|匹|头|棵|朵|颗|粒|滴|项|款|批|群|堆|帮|伙|双|对|副|套|组|系列|代)[ \t　]*$',
    samples: [
      '第一章 少年出山',
      '第二十章 ：终极之战',
      '第 1 章 傻子',
      '第3章- 遗失的记忆',
      '第四卷 序章',
      '第三回 梁山聚义',
      '第二节 暗流涌动',
      '第25章 25 季春',
      '第1章 01 慈孝元年 正月',
      '第    3章',
      '第3   章 标题',
      '第一章、缘起',
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
