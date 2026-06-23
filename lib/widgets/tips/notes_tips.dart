import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:flutter/material.dart';

class NotesTips extends StatelessWidget {
  const NotesTips({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note_outlined,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            L10n.of(context).notesTips_1,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            L10n.of(context).notesTips_2,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
