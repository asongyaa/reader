import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BookshelfTips extends StatelessWidget {
  const BookshelfTips({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 80,
            color: cs.primary.withAlpha(80),
          ).animate().fadeIn(
            duration: 600.ms,
            curve: Curves.easeOut,
          ).scaleXY(
            begin: 0.6,
            end: 1.0,
            duration: 600.ms,
            curve: Curves.easeOut,
          ),
          const SizedBox(height: 24),
          Text(
            L10n.of(context).bookshelfTips_1,
            style: textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(
            duration: 400.ms,
            delay: 200.ms,
            curve: Curves.easeOut,
          ).slideY(
            begin: 0.1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOut,
          ),
          const SizedBox(height: 8),
          Text(
            L10n.of(context).bookshelfTips_2,
            style: textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ).animate().fadeIn(
            duration: 400.ms,
            delay: 400.ms,
            curve: Curves.easeOut,
          ).slideY(
            begin: 0.1,
            end: 0,
            duration: 400.ms,
            curve: Curves.easeOut,
          ),
        ],
      ),
    );
  }
}
