import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/home_page/notes_page.dart';
import 'package:anx_reader/page/home_page/settings_page.dart';
import 'package:anx_reader/page/home_page/statistics_page.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/providers/sync.dart';
import 'package:anx_reader/widgets/bookshelf/sync_status_bottom_sheet.dart';
import 'package:anx_reader/widgets/statistic/statistics_dashboard_title.dart';
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
            const SizedBox(height: 16),
            // Reading stats card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledContainer(
                radius: 16,
                padding: const EdgeInsets.all(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (context) => const StatisticPage()),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            L10n.of(context).statisticAllTime,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const TotalReadTime(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Settings entry
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledContainer(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.note, color: cs.primary),
                      title: const Text('笔记'),
                      trailing:
                          Icon(Icons.chevron_right, color: cs.primary),
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) =>
                                  const NotesPage()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading:
                          Icon(Icons.settings_outlined, color: cs.primary),
                      title: Text(L10n.of(context).navBarSettings),
                      trailing: Icon(Icons.chevron_right, color: cs.primary),
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                    const _SyncListTile(),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _SyncListTile extends ConsumerWidget {
  const _SyncListTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isSyncing = ref.watch(syncProvider.select((s) => s.isSyncing));
    return ListTile(
      leading: Icon(isSyncing ? Icons.sync : Icons.sync, color: cs.primary),
      title: const Text('同步'),
      trailing: Icon(Icons.chevron_right, color: cs.primary),
      onTap: () => showSyncStatusBottomSheet(context),
    );
  }
}
