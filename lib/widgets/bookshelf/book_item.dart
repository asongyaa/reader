import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/enums/book_sync_status.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/providers/sync_status.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/widgets/bookshelf/book_bottom_sheet.dart';
import 'package:anx_reader/widgets/bookshelf/book_cover.dart';
import 'package:anx_reader/widgets/bookshelf/book_sync_status_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookItem extends ConsumerWidget {
  const BookItem({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleLongPress(BuildContext context) async {
      showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return BookBottomSheet(book: book);
          });
    }

    BookSyncStatusEnum bookSyncStatus =
        ref.watch(syncStatusProvider).whenOrNull(data: (data) {
              if (data.downloading.contains(book.id)) {
                return BookSyncStatusEnum.downloading;
              } else if (data.uploading.contains(book.id)) {
                return BookSyncStatusEnum.uploading;
              } else if (data.localOnly.contains(book.id)) {
                return BookSyncStatusEnum.localOnly;
              } else if (data.remoteOnly.contains(book.id)) {
                return BookSyncStatusEnum.remoteOnly;
              } else if (data.both.contains(book.id)) {
                return BookSyncStatusEnum.both;
              } else if (data.nonExistent.contains(book.id)) {
                return BookSyncStatusEnum.nonExistent;
              } else {
                return BookSyncStatusEnum.checking;
              }
            }) ??
            BookSyncStatusEnum.checking;

    return GestureDetector(
      onTap: () {
        pushToReadingPage(ref, context, book);
      },
      onLongPress: () {
        handleLongPress(context);
      },
      onSecondaryTap: () {
        handleLongPress(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Hero(
              tag: book.coverFullPath,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    if (!Prefs().eInkMode)
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withAlpha(30),
                        spreadRadius: 5,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: BookCover(book: book, height: 150),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 55,
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                      ),
                    ),
                    if (Prefs().webdavStatus)
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: BookSyncStatusIcon(
                          syncStatus: bookSyncStatus,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        book.author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w300,
                              fontSize: 9,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ),
                    ),
                    Text(
                      '${(book.readingPercentage * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w300,
                            fontSize: 9,
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(
            duration: 400.ms,
            curve: Curves.easeOut,
          ).slideY(
            begin: 0.1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}
