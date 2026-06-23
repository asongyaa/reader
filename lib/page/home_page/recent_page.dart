import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';

class RecentPage extends ConsumerStatefulWidget {
  const RecentPage({super.key, this.controller});
  final ScrollController? controller;
  @override
  ConsumerState<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends ConsumerState<RecentPage>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _scrollController = widget.controller ?? ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final booksAsync = ref.watch(bookListProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    Widget body;
    if (booksAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (booksAsync.hasError || !booksAsync.hasValue) {
      body = Center(child: Text('Error: ${booksAsync.error}', style: TextStyle(color: cs.error)));
    } else {
      final all = booksAsync.requireValue.expand((g) => g).toList()
        ..sort((a, b) => b.updateTime.compareTo(a.updateTime));
      if (all.isEmpty) {
        body = Center(child: Text('暂无阅读记录', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)));
      } else {
        final now = DateTime.now();
        final current = all.firstWhere(
          (b) => b.readingPercentage > 0.02,
          orElse: () => all.first,
        );
        final rest = all.where((b) => b.id != current.id).toList();

        final thisWeek = rest
            .where((b) => b.updateTime.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
        final thisMonth = rest
            .where((b) => b.updateTime.isAfter(now.subtract(const Duration(days: 30))) &&
                !b.updateTime.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
        final older = rest
            .where((b) => !b.updateTime.isAfter(now.subtract(const Duration(days: 30))))
            .toList();

        final hasAnyContent = thisWeek.isNotEmpty || thisMonth.isNotEmpty || older.isNotEmpty;

        body = ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 80),
          children: [
            _buildCurrent(context, current, cs),
            const SizedBox(height: 16),
            if (thisWeek.isNotEmpty) ...[
              _buildSection(context, '本周', thisWeek, cs),
              const SizedBox(height: 12),
            ],
            if (thisMonth.isNotEmpty) ...[
              _buildSection(context, '本月', thisMonth, cs),
              const SizedBox(height: 12),
            ],
            if (older.isNotEmpty) ...[
              _buildSection(context, '更早', older, cs),
              const SizedBox(height: 12),
            ],
            if (!hasAnyContent)
              Center(child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('暂无已读书籍', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
              )),
          ],
        );
      }
    }

    return Column(children: [
      Expanded(child: body),
    ]);
  }

  Widget _buildCurrent(BuildContext ctx, Book book, ColorScheme cs) {
    final pct = ((book.readingPercentage).clamp(0.0, 1.0) * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => pushToReadingPage(ref, ctx, book),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              BookCover(book: book, width: 80, height: 110, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('阅读进度 $pct%', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: book.readingPercentage.clamp(0.0, 1.0), minHeight: 5),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => pushToReadingPage(ref, ctx, book),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('继续阅读'),
                        style: FilledButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext ctx, String title, List<Book> books, ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(title, style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 130,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: books.length,
          itemBuilder: (_, i) {
            final b = books[i];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => pushToReadingPage(ref, ctx, b),
                child: Column(children: [
                    BookCover(book: b, width: 70, height: 95, radius: 6),
                  const SizedBox(height: 4),
                  SizedBox(width: 70, child: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
