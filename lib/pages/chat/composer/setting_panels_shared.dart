import 'package:flutter/material.dart';

/// A chip/button for selecting a reasoning parameter option.
class OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? cs.onPrimaryContainer
                : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
