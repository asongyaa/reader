import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/home_page/notes_page.dart';
import 'package:anx_reader/page/home_page/settings_page.dart';
import 'package:anx_reader/page/home_page/statistics_page.dart';
import 'package:anx_reader/providers/total_reading_time.dart';
import 'package:anx_reader/widgets/common/async_skeleton_wrapper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key, this.controller});
  final ScrollController? controller;
  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          const SizedBox(height: 24),
          // Top cards row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildCard(
                    icon: Icons.edit_outlined,
                    title: '笔记',
                    subtitle: '0 条笔记',
                    onTap: () => Navigator.push(context,
                        CupertinoPageRoute(builder: (_) => const NotesPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCard(
                    icon: Icons.bar_chart_outlined,
                    title: '阅读统计',
                    subtitle: '',
                    subtitleWidget: const _ReadTimeSubtitle(),
                    onTap: () => Navigator.push(context,
                        CupertinoPageRoute(builder: (_) => const StatisticPage())),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // List items
          _buildListItem(
            icon: Icons.chat_bubble_outline,
            title: '意见反馈',
            onTap: () {},
          ),
          Divider(height: 1, indent: 24, endIndent: 24, color: cs.outlineVariant.withOpacity(0.5)),
          _buildListItem(
            icon: Icons.info_outline,
            title: '关于',
            onTap: () {},
          ),
          Divider(height: 1, indent: 24, endIndent: 24, color: cs.outlineVariant.withOpacity(0.5)),
          _buildListItem(
            icon: Icons.settings_outlined,
            title: L10n.of(context).navBarSettings,
            onTap: () => Navigator.push(context,
                CupertinoPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? subtitleWidget,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: cs.onSurface),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, color: cs.onSurface)),
            const SizedBox(height: 4),
            subtitleWidget ?? Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: cs.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 16, color: cs.onSurface)),
            ),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ReadTimeSubtitle extends ConsumerWidget {
  const _ReadTimeSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _CompactReadTime();
  }
}

class _CompactReadTime extends ConsumerWidget {
  const _CompactReadTime();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return AsyncSkeletonWrapper<int>(
      asyncValue: ref.watch(totalReadingTimeProvider),
      builder: (seconds, _) {
        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        return Text(
          '${L10n.of(context).commonHours(hours)}${L10n.of(context).commonMinutes(minutes)}',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        );
      },
    );
  }
}
