import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Proportional truncation helpers
// ═══════════════════════════════════════════════════════════════

/// Proportinally truncates a display name in "modelName | vendorName" format
/// so it fits within [maxWidth] pixels.
///
/// Uses character-count-based proportional allocation between the model name
/// and vendor name parts, then verifies the result fits within [maxWidth]
/// pixels (using [painter]). If the result is still too wide, it progressively
/// reduces available characters until it fits.
///
/// Each part retains at least 2 characters. Truncated parts get "..." appended.
/// Falls back to standard ellipsis truncation if no " | " separator is found.
String truncateDisplayName(
  String displayName,
  double maxWidth,
  TextPainter painter,
) {
  // Preserve the text style for reuse.
  final TextStyle? textStyle = painter.text?.style;
  final style = textStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  final direction = painter.textDirection ?? TextDirection.ltr;

  // Quick check: if it already fits, return as-is.
  painter.text = TextSpan(text: displayName, style: style);
  painter.layout();
  if (painter.width <= maxWidth) return displayName;

  const separator = ' | ';
  final sepIdx = displayName.lastIndexOf(separator);
  if (sepIdx <= 0) {
    return _truncateSimple(displayName, maxWidth, style, direction);
  }

  final modelPart = displayName.substring(0, sepIdx);
  final vendorPart = displayName.substring(sepIdx + separator.length);
  const minChars = 2;

  // Iterate from a generous budget downward until it fits.
  for (int totalBudget = modelPart.length + vendorPart.length + 6;
       totalBudget >= minChars * 2 + 6;
       totalBudget--) {
    final modelBudget =
        _proportionalAlloc(totalBudget, modelPart.length, vendorPart.length, minChars + 3);
    final vendorBudget = totalBudget - modelBudget;

    final modelTextLen = modelBudget >= modelPart.length
        ? modelPart.length
        : modelBudget - 3;
    final vendorTextLen = vendorBudget >= vendorPart.length
        ? vendorPart.length
        : vendorBudget - 3;

    final truncatedModel = modelTextLen >= modelPart.length
        ? modelPart
        : '${modelPart.substring(0, modelTextLen)}...';
    final truncatedVendor = vendorTextLen >= vendorPart.length
        ? vendorPart
        : '${vendorPart.substring(0, vendorTextLen)}...';

    final candidate = '$truncatedModel$separator$truncatedVendor';
    painter.text = TextSpan(text: candidate, style: style);
    painter.layout();
    if (painter.width <= maxWidth) return candidate;
  }

  // Absolute fallback: minimum viable result (each part at minChars or original
  // if already shorter). Verify it fits; if even the minimum overflows, return
  // it anyway — there is nothing more to truncate.
  final fbModel = modelPart.length <= minChars
      ? modelPart
      : '${modelPart.substring(0, minChars)}...';
  final fbVendor = vendorPart.length <= minChars
      ? vendorPart
      : '${vendorPart.substring(0, minChars)}...';
  final fallback = '$fbModel$separator$fbVendor';
  painter.text = TextSpan(text: fallback, style: style);
  painter.layout();
  return fallback;
}

/// Allocates [totalBudget] characters proportionally between two parts based on
/// their original lengths. Each part gets at least [minChars] characters.
int _proportionalAlloc(
  int totalBudget,
  int part1Len,
  int part2Len,
  int minChars,
) {
  if (totalBudget < 2 * minChars) {
    // Not enough budget for both minimums; split evenly ensuring each gets at
    // least 1, and neither exceeds totalBudget - 1.
    final half = (totalBudget / 2).ceil();
    return half.clamp(1, totalBudget - 1);
  }
  if (part1Len + part2Len == 0) return totalBudget ~/ 2;
  final ratio = part1Len / (part1Len + part2Len);
  var alloc = (totalBudget * ratio).round();
  // Ensure minChars for both parts and respect the upper bound.
  alloc = alloc.clamp(minChars, totalBudget - minChars);
  return alloc;
}

/// Simple ellipsis truncation (fallback when no separator found).
String _truncateSimple(
  String text,
  double maxWidth,
  TextStyle style,
  TextDirection direction,
) {
  for (int len = text.length; len >= 1; len--) {
    final candidate = '${text.substring(0, len)}...';
    final tp = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: direction,
    )..layout();
    if (tp.width <= maxWidth) return candidate;
  }
  return '...';
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
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.red,
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
            // Flexible + LayoutBuilder ensures the text fits within the
            // remaining space after icon and padding, regardless of the
            // chip's overall width constraint from the parent Wrap.
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final style = TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        isDisabled ? Colors.grey.withOpacity(0.4) : cs.onSurface,
                  );
                  final painter = TextPainter(
                    text: TextSpan(text: label, style: style),
                    textDirection: Directionality.of(context),
                  )..layout();

                  final displayText = painter.width <= availableWidth
                      ? label
                      : truncateDisplayName(label, availableWidth, painter);

                  return Text(
                    displayText,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
