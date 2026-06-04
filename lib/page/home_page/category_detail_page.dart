import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryDetailPage extends ConsumerStatefulWidget {
  const CategoryDetailPage({
    super.key,
    required this.initialFormat,
    required this.categorizedBooks,
  });

  final String initialFormat;
  final Map<String, List<Book>> categorizedBooks;

  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  @override
  Widget build(BuildContext context) {
    final formats = widget.categorizedBooks.keys.toList();
    final initialIndex = formats.indexOf(widget.initialFormat);

    return DefaultTabController(
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
      length: formats.length,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            isScrollable: true,
            tabs: formats.map((f) => Tab(text: f)).toList(),
          ),
        ),
        body: TabBarView(
          children: formats.map((format) {
            final books = widget.categorizedBooks[format]!;
            return _buildBooksList(books);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBooksList(List<Book> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return GestureDetector(
          onTap: () => pushToReadingPage(ref, context, book),
          child: Column(
            children: [
              BookCover(book: book, height: 150),
              const SizedBox(height: 4),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
