import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/models/tb_group.dart';
import 'package:anx_reader/providers/book_list.dart';
import 'package:anx_reader/providers/tb_groups.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/page/search/search_page.dart';
import 'package:anx_reader/page/scan_books_page.dart';
import 'package:anx_reader/utils/get_path/get_temp_dir.dart';
import 'package:anx_reader/utils/platform_utils.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/tips/bookshelf_tips.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
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
  static const double _kTitleHeight = 34.0; // 2 lines of bodySmall
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

  void _showImportMenu() {
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
              '导入书籍',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('导入文件'),
              subtitle: const Text('从文件管理器选择'),
              onTap: () {
                Navigator.pop(ctx);
                _importBook();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('扫描文件夹'),
              subtitle: const Text('自动扫描本地电子书'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ScanBooksPage()));
              },
            ),
          ],
        ),
      ),
    );
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
        onLongPress: () => _showBookMenu(b),
        child: SizedBox(
          width: 100,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: BookCover(book: b),
          ),
        ),
      );

  void _showBookMenu(Book book) {
    final l10n = L10n.of(context);
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
              book.title,
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('加入合集'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                _showCollectionPicker(book);
              },
            ),
            if (book.groupId != 0)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('移出合集'),
                onTap: () {
                  ref.read(bookListProvider.notifier).removeFromGroup(book);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: Text(l10n.commonDelete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteBook(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context).commonDelete),
        content: Text('确定删除「${book.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.of(context).commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(L10n.of(context).commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await bookDao.updateBook(book.copyWith(isDeleted: true, updateTime: DateTime.now()));
    ref.read(bookListProvider.notifier).refresh();
    final file = File(book.fileFullPath);
    if (await file.exists()) await file.delete();
    final cover = File(book.coverFullPath);
    if (await cover.exists()) await cover.delete();
  }

  void _showCollectionPicker(Book book) async {
    final groups = ref.read(bookListProvider).valueOrNull ?? [];
    final allBooks = groups.expand((g) => g).toList();
    final tbGroups = await ref.read(groupDaoProvider.future);

    final existingGroupIds = <int>{};
    for (final b in allBooks) {
      if (b.groupId != 0) existingGroupIds.add(b.groupId);
    }

    String groupName(int gid) {
      final g = tbGroups.where((g) => g.id == gid);
      if (g.isNotEmpty && g.first.name != '...') return g.first.name;
      return '合集$gid';
    }

    if (!mounted) return;

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
              '选择合集',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (existingGroupIds.isNotEmpty)
              ...existingGroupIds.map((gid) => ListTile(
                    title: Text(groupName(gid)),
                    trailing: book.groupId == gid
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(bookListProvider.notifier).moveBook(book, gid);
                      Navigator.pop(ctx);
                      SmartDialog.showToast('已加入「${groupName(gid)}」');
                    },
                  )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('创建新合集'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateCollectionDialog(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCollectionDialog(Book book) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '创建新合集',
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '输入合集名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(L10n.of(context).commonCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx);
                    final newGroupId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    await ref.read(groupDaoProvider.notifier).insertGroup(newGroupId);
                    await ref.read(groupDaoProvider.notifier).updateGroup(
                      TbGroup(id: newGroupId, name: name),
                    );
                    ref.read(bookListProvider.notifier).moveBook(book, newGroupId);
                    SmartDialog.showToast('已加入「$name」');
                  },
                  child: Text(L10n.of(context).commonOk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// allBooks: simple grid, no cards
  Widget _buildAllBooks(List<Book> books) {
    if (books.isEmpty) return const Center(child: BookshelfTips());
    return LayoutBuilder(builder: (context, constraints) {
      const crossAxisSpacing = 12.0;
      const gridPadding = 40.0; // left 20 + right 20
      final itemWidth = (constraints.maxWidth - gridPadding - crossAxisSpacing * 2) / 3;
      // cover 2:3 ratio + title + gap
      final coverHeight = itemWidth * 3 / 2;
      final itemHeight = coverHeight + 4 + _kTitleHeight;
      final aspectRatio = itemWidth / itemHeight;

      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: aspectRatio,
          mainAxisSpacing: 12,
          crossAxisSpacing: crossAxisSpacing,
        ),
        itemCount: books.length,
        itemBuilder: (ctx, i) {
          final b = books[i];
          return GestureDetector(
            onTap: () => pushToReadingPage(ref, ctx, b),
            onLongPress: () => _showBookMenu(b),
            child: Column(children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: BookCover(book: b),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: _kTitleHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.bodySmall),
                ),
              ),
            ]),
          );
        },
      );
    });
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
    final flat = groups.expand((g) => g).toList();
    final tbGroups = ref.watch(groupDaoProvider).valueOrNull ?? [];
    final map = <String, List<Book>>{};
    for (final b in flat) {
      if (b.groupId == 0) {
        map.putIfAbsent('未分组', () => []).add(b);
      } else {
        final g = tbGroups.where((g) => g.id == b.groupId);
        final name = (g.isNotEmpty && g.first.name != '...') ? g.first.name : '合集${b.groupId}';
        map.putIfAbsent(name, () => []).add(b);
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
        IconButton(icon: const Icon(Icons.add), onPressed: _showImportMenu),
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
    const titleHeight = 34.0;
    const crossAxisSpacing = 12.0;
    const gridPadding = 32.0; // all 16 * 2
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - gridPadding - crossAxisSpacing * 2) / 3;
        final coverHeight = itemWidth * 3 / 2;
        final itemHeight = coverHeight + 4 + titleHeight;
        final aspectRatio = itemWidth / itemHeight;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: aspectRatio,
            mainAxisSpacing: 12,
            crossAxisSpacing: crossAxisSpacing,
          ),
          itemCount: books.length,
          itemBuilder: (ctx, i) {
            final b = books[i];
            return GestureDetector(
              onTap: () => pushToReadingPage(ref, ctx, b),
              child: Column(children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: BookCover(book: b),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: titleHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ),
              ]),
            );
          },
        );
      }),
    );
  }
}
