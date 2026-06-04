import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/page/search/search_page.dart';
import 'package:anx_reader/utils/get_path/get_temp_dir.dart';
import 'package:anx_reader/utils/platform_utils.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/tips/bookshelf_tips.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// ── Category mode enum ───────────────────────────────────────────
enum _CategoryMode {
  allBooks, format, author, collection, progress,
}

extension _CategoryModeExt on _CategoryMode {
  String get label => switch (this) {
    _CategoryMode.allBooks   => '全部书籍',
    _CategoryMode.format     => '格式',
    _CategoryMode.author     => '作者',
    _CategoryMode.collection => '合集',
    _CategoryMode.progress   => '阅读进度',
  };
  IconData get icon => switch (this) {
    _CategoryMode.allBooks   => Icons.library_books,
    _CategoryMode.format     => Icons.description,
    _CategoryMode.author     => Icons.person,
    _CategoryMode.collection => Icons.folder,
    _CategoryMode.progress   => Icons.trending_up,
  };
}

// ── Widget ────────────────────────────────────────────────────────
class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key, this.controller});
  final ScrollController? controller;
  @override ConsumerState<BookshelfPage> createState() => BookshelfPageState();
}

class BookshelfPageState extends ConsumerState<BookshelfPage>
    with AutomaticKeepAliveClientMixin {
  late final _scrollController = widget.controller ?? ScrollController();
  _CategoryMode _currentCategory = _CategoryMode.allBooks;

  @override bool get wantKeepAlive => true;

  // ── Helpers ──────────────────────────────────────────────────────
  String _getFormat(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'epub') return 'EPUB';
    if (ext == 'pdf')  return 'PDF';
    if (ext == 'txt' || ext == 'text') return 'TXT';
    if (ext == 'mobi') return 'MOBI';
    if (ext == 'azw3') return 'AZW3';
    if (ext == 'djvu') return 'DJVU';
    if (ext == 'cbz' || ext == 'cbr') return 'COMIC';
    return 'OTHER';
  }

  Future<File> _copyToTempFile({required String src, required String name}) async {
    final tmp = await getAnxTempDir();
    final target = File(p.join(tmp.path, name));
    if (await target.exists()) await target.delete();
    return File(src).copy(target.path);
  }

  Future<void> _importBook() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: true);
    if (result == null || !mounted) return;
    List<File> fileList;
    if (!AnxPlatform.isAndroid) {
      fileList = await Future.wait(
        result.files.map((f) => _copyToTempFile(src: f.path!, name: f.name)));
    } else {
      fileList = result.files.map((f) => File(f.path!)).toList();
    }
    if (!mounted) return;
    importBookList(fileList, context, ref);
  }

  // ── Category menu ───────────────────────────────────────────────
  void _showCategoryMenu() {
    showMenu<_CategoryMode>(
      context: context,
      position: RelativeRect.fromLTRB(0, 100, 0, 0),
      items: _CategoryMode.values.map((m) => PopupMenuItem(
        value: m,
        child: Text(m.label),
      )).toList(),
    ).then((m) {
      if (m != null && m != _currentCategory) setState(() => _currentCategory = m);
    });
  }

  // ── Body builders ───────────────────────────────────────────────
  Widget _bookTap(Book b, BuildContext ctx) =>
      GestureDetector(
        onTap: () => pushToReadingPage(ref, ctx, b),
        child: BookCover(book: b, width: 100, height: 150),
      );

  /// allBooks: simple grid, no cards
  Widget _buildAllBooks(List<Book> books) {
    if (books.isEmpty) return const Center(child: BookshelfTips());
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.55, mainAxisSpacing: 16, crossAxisSpacing: 12),
      itemCount: books.length,
      itemBuilder: (ctx, i) {
        final b = books[i];
        return GestureDetector(
          onTap: () => pushToReadingPage(ref, ctx, b),
          child: Column(children: [
            BookCover(book: b, height: 150),
            const SizedBox(height: 4),
            Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.bodySmall),
          ]),
        );
      },
    );
  }

  /// Card with title + horizontal book row (max 4)
  Widget _buildCard(String title, List<Book> books) {
    final display = books.take(4).toList();
    final hasMore = books.length > 4;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FilledContainer(
        radius: 16, padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (hasMore)
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => _SeeAllPage(title: title, books: books))),
                child: Text('更多 >', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: display.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    scrollDirection: Axis.horizontal, itemCount: display.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) => _bookTap(display[i], ctx),
                  ),
          ),
        ]),
      ),
    );
  }

  /// format view
  Widget _buildFormatView(List<Book> books) {
    final map = <String, List<Book>>{};
    for (final b in books) map.putIfAbsent(_getFormat(b.filePath), () => []).add(b);
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const Center(child: BookshelfTips());
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return _buildCard(e.key, e.value);
      },
    );
  }

  /// author view
  Widget _buildAuthorView(List<Book> books) {
    final map = <String, List<Book>>{};
    for (final b in books) {
      final author = b.author.isEmpty ? '未知' : b.author;
      map.putIfAbsent(author, () => []).add(b);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const Center(child: BookshelfTips());
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return _buildCard(e.key, e.value);
      },
    );
  }

  /// collection view (using groupId from DB)
  Widget _buildCollectionView(List<List<Book>> groups) {
    // Flatten groups
    final flat = groups.expand((g) => g).toList();
    final map = <String, List<Book>>{};
    for (final b in flat) {
      if (b.groupId == 0) {
        map.putIfAbsent('未分组', () => []).add(b);
      } else {
        map.putIfAbsent('合集${b.groupId}', () => []).add(b);
      }
    }
    final entries = map.entries.toList();
    if (entries.isEmpty) return const Center(child: BookshelfTips());
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return _buildCard(e.key, e.value);
      },
    );
  }

  /// progress view: three sections
  Widget _buildProgressView(List<Book> books) {
    final notStarted = books.where((b) => b.readingPercentage <= 0.02).toList();
    final inProgress = books.where((b) => b.readingPercentage > 0.02 && b.readingPercentage < 0.98).toList();
    final finished   = books.where((b) => b.readingPercentage >= 0.98).toList();
    if (books.isEmpty) return const Center(child: BookshelfTips());
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      children: [
        if (inProgress.isNotEmpty) _buildProgressSection('进行中', inProgress),
        if (finished.isNotEmpty)   _buildProgressSection('已读完', finished),
        if (notStarted.isNotEmpty) _buildProgressSection('未开始', notStarted),
      ],
    );
  }

  Widget _buildProgressSection(String title, List<Book> books) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FilledContainer(
        radius: 16, padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal, itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) => _bookTap(books[i], ctx),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Main build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    final body = ref.watch(bookListProvider).when(
      data: (groups) {
        final allBooks = groups.expand((g) => g).toList();
        switch (_currentCategory) {
          case _CategoryMode.allBooks:   return _buildAllBooks(allBooks);
          case _CategoryMode.format:     return _buildFormatView(allBooks);
          case _CategoryMode.author:     return _buildAuthorView(allBooks);
          case _CategoryMode.collection: return _buildCollectionView(groups);
          case _CategoryMode.progress:   return _buildProgressView(allBooks);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(height: 34, child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchPage())),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withAlpha(120), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const SizedBox(width: 10),
            Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(L10n.of(context).searchBooksOrNotes,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor)),
          ]),
        ),
      )),
    );

    final appBar = AppBar(
      forceMaterialTransparency: true,
      title: GestureDetector(
        onTap: _showCategoryMenu,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_currentCategory.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 18, color: cs.primary),
        ]),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _importBook),
      ],
    );

    return Container(
      decoration: Prefs().eInkMode ? null : BoxDecoration(
        gradient: RadialGradient(
          tileMode: TileMode.clamp, center: Alignment.topRight, radius: 1,
          colors: [cs.primary.withAlpha(5), Theme.of(context).scaffoldBackgroundColor],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: Column(children: [searchBar, Expanded(child: body)]),
      ),
    );
  }
}

// ── "See All" page ────────────────────────────────────────────────
class _SeeAllPage extends ConsumerWidget {
  final String title;
  final List<Book> books;
  const _SeeAllPage({required this.title, required this.books});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.55, mainAxisSpacing: 16, crossAxisSpacing: 12),
        itemCount: books.length,
        itemBuilder: (ctx, i) {
          final b = books[i];
          return GestureDetector(
            onTap: () => pushToReadingPage(ref, ctx, b),
            child: Column(children: [
              BookCover(book: b, height: 150),
              const SizedBox(height: 4),
              Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall),
            ]),
          );
        },
      ),
    );
  }
}
