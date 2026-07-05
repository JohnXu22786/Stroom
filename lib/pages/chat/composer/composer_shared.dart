import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Character-based truncation helpers
// ═══════════════════════════════════════════════════════════════

const int _maxPartLength = 20;

/// Truncates a single part to at most [_maxPartLength] characters,
/// with "..." counting toward the limit.
String _truncatePart(String part) {
  if (part.length <= _maxPartLength) return part;
  return '${part.substring(0, _maxPartLength - 3)}...';
}

/// Truncates a display name in "modelName | vendorName" format so each
/// part is at most [_maxPartLength] characters (with "..." counting toward
/// that length). Falls back to simple truncation if no " | " separator.
String truncateDisplayName(String displayName) {
  const separator = ' | ';
  final sepIdx = displayName.lastIndexOf(separator);
  if (sepIdx <= 0) return _truncatePart(displayName);

  final modelPart = displayName.substring(0, sepIdx);
  final vendorPart = displayName.substring(sepIdx + separator.length);

  return '${_truncatePart(modelPart)}$separator${_truncatePart(vendorPart)}';
}

// ═══════════════════════════════════════════════════════════════
// SettingsChip
// ═══════════════════════════════════════════════════════════════

/// A small chip button for the settings row above the composer input.
/// Optionally shows a circular [badgeCount] badge (e.g. for enabled tools count).
class SettingsChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  /// When > 0, a small circular badge with this number is shown next to the
  /// label. When 0 or null, no badge is displayed.
  final int? badgeCount;

  const SettingsChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.enabled = true,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = !enabled;
    final showBadge = badgeCount != null && badgeCount! > 0;

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.08)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.1)
                : color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isDisabled ? Colors.grey.withOpacity(0.4) : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDisabled ? Colors.grey.withOpacity(0.4) : cs.onSurface,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              ChipBadge(count: badgeCount!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small circular badge showing a number.
class ChipBadge extends StatelessWidget {
  final int count;
  const ChipBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.tertiary,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ModelNameChip
// ═══════════════════════════════════════════════════════════════

/// A chip that displays the current model name with automatic proportional
/// truncation for long names. Falls back to "模型" when [displayName] is empty.
///
/// Uses [Flexible] + [LayoutBuilder] internally so the text always fits within
/// the available width, regardless of how the chip is constrained by its parent.
class ModelNameChip extends StatelessWidget {
  final String displayName;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const ModelNameChip({
    super.key,
    required this.displayName,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = !enabled;

    // Fallback label when no model name is available.
    final label = displayName.isNotEmpty ? displayName : '模型';
    // Pre-truncate to fixed max length per part (character-based).
    final displayText = truncateDisplayName(label);
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: isDisabled ? Colors.grey.withOpacity(0.4) : cs.onSurface,
    );

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.08)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.1)
                : color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 16,
                color: isDisabled ? Colors.grey.withOpacity(0.4) : color),
            const SizedBox(width: 4),
            Text(
              displayText,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
