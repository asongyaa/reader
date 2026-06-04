import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookshelfOrganizeService {
  BookshelfOrganizeService();

  Future<void> applyPlan() async {
    // No-op after AI feature removal
  }
}

final bookshelfOrganizeServiceProvider =
    Provider<BookshelfOrganizeService>((ref) => BookshelfOrganizeService());
