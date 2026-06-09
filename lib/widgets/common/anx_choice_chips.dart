import 'package:flutter/material.dart';
import 'package:anx_reader/widgets/common/anx_segmented_button.dart';

class AnxChoiceChips<T> extends StatelessWidget {
  const AnxChoiceChips({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.enabled = true,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
  });

  final List<SegmentButtonItem<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool enabled;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: segments.map((segment) {
        final isSelected = selected.contains(segment.value);
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: 16,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                  child: segment.icon!,
                ),
                const SizedBox(width: 4),
              ],
              Text(segment.label),
            ],
          ),
          selected: isSelected,
          onSelected: enabled
              ? (value) {
                  onSelectionChanged?.call({segment.value});
                }
              : null,
          selectedColor: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(100),
          labelStyle: TextStyle(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withAlpha(120),
              width: 1,
            ),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        );
      }).toList(),
    );
  }
}
