import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Proportional truncation helpers
// ═══════════════════════════════════════════════════════════════

/// Proportinally truncates a display name in "modelName | vendorName" format
/// so it fits within [maxWidth] pixels.
///
/// Uses pixel-width-based proportional allocation between the model name
/// and vendor name parts, then verifies the result fits within [maxWidth]
/// pixels (using [painter]). If the result is still too wide, it progressively
/// reduces available characters until it fits.
///
/// Each part retains at least 2 characters. Truncated parts get "..." appended.
/// Falls back to standard ellipsis truncation if no " | " separator is found.
///
/// Unlike character-count-based allocation, this function measures actual pixel
/// widths of each part, so wide characters (e.g. Chinese) are allocated more
/// budget proportionally than narrow characters (e.g. ASCII).
String truncateDisplayName(
  String displayName,
  double maxWidth,
  TextPainter painter,
) {
  // Preserve the text style for reuse.
  final TextStyle? textStyle = painter.text?.style;
  final style =
      textStyle ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
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

  // Quick check: if even the minimum fits, early-exit into allocation search.
  // If the minimum doesn't fit, the allocation loop will still find the best
  // possible result (preserving separator format), even if it slightly overflows.
  return _findBestAllocation(modelPart, vendorPart, maxWidth, style, direction,
      minChars: minChars);
}

/// Iteratively finds the best proportional allocation between model and vendor
/// parts to fit within [maxWidth]. Uses pixel-width ratios for allocation.
String _findBestAllocation(
  String modelPart,
  String vendorPart,
  double maxWidth,
  TextStyle style,
  TextDirection direction, {
  required int minChars,
}) {
  const separator = ' | ';

  // Measure pixel widths once, before looping.
  final modelWidth = _measureWidth(modelPart, style, direction);
  final vendorWidth = _measureWidth(vendorPart, style, direction);

  // Iterate from a generous character budget downward until it fits.
  // The lower bound is minChars * 2 (without +6 overhead) to allow
  // the budget to go low enough to actually trigger truncation for
  // short strings (e.g., "AAAA | BB" where full model is only 4 chars).
  for (int totalBudget = modelPart.length + vendorPart.length + 6;
      totalBudget >= minChars * 2;
      totalBudget--) {
    // Use pixel width ratio for proportional allocation
    final modelBudget = _proportionalAllocByWidth(totalBudget,
        modelWidth: modelWidth,
        vendorWidth: vendorWidth,
        minChars: minChars + 3);
    final vendorBudget = totalBudget - modelBudget;

    final modelTextLen = modelBudget >= modelPart.length
        ? modelPart.length
        : (modelBudget - 3).clamp(0, modelPart.length);
    final vendorTextLen = vendorBudget >= vendorPart.length
        ? vendorPart.length
        : (vendorBudget - 3).clamp(0, vendorPart.length);

    final truncatedModel =
        _truncatePart(modelPart, modelTextLen, modelPart.length);
    final truncatedVendor =
        _truncatePart(vendorPart, vendorTextLen, vendorPart.length);

    // Skip candidates where a part would have fewer than minChars visible
    // characters. The fallback at the end will enforce the minimum.
    final modelVisible = truncatedModel.replaceAll('...', '');
    final vendorVisible = truncatedVendor.replaceAll('...', '');
    if (modelVisible.length < minChars && modelPart.length >= minChars)
      continue;
    if (vendorVisible.length < minChars && vendorPart.length >= minChars)
      continue;

    final candidate = '$truncatedModel$separator$truncatedVendor';
    final tp = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: direction,
    )..layout();
    if (tp.width <= maxWidth) return candidate;
  }

  // Absolute fallback: minimum viable result with at least minChars per part.
  // The fallback may slightly overflow the constraint, but guarantees the
  // format is preserved and both parts are visible.
  final fbModel = modelPart.length <= minChars
      ? modelPart
      : '${modelPart.substring(0, minChars)}...';
  final fbVendor = vendorPart.length <= minChars
      ? vendorPart
      : '${vendorPart.substring(0, minChars)}...';
  final fallback = '$fbModel$separator$fbVendor';
  return fallback;
}

/// Truncates [part] to [textLen] characters and appends "...", but only if the
/// result is actually shorter than the original. If truncation + "..." would
/// not save space, returns the original part unchanged.
String _truncatePart(String part, int textLen, int originalLen) {
  if (textLen >= originalLen) return part;
  // Adding "..." costs 3 chars of overhead. Only truncate if the result
  // (textLen + 3) is genuinely shorter than the original.
  if (textLen + 3 >= originalLen) return part;
  if (textLen <= 0) return '...';
  return '${part.substring(0, textLen)}...';
}

/// Measures the pixel width of [text] using the given [style] and [direction].
double _measureWidth(String text, TextStyle style, TextDirection direction) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
  )..layout();
  return tp.width;
}

/// Allocates [totalBudget] characters proportionally between two parts based on
/// their pixel widths. Each part gets at least [minChars] characters.
int _proportionalAllocByWidth(
  int totalBudget, {
  required double modelWidth,
  required double vendorWidth,
  required int minChars,
}) {
  if (totalBudget < 2 * minChars) {
    // Not enough budget for both minimums; split evenly.
    final half = (totalBudget / 2).ceil();
    return half.clamp(1, totalBudget - 1);
  }
  final pixelTotal = modelWidth + vendorWidth;
  if (pixelTotal <= 0)
    return (totalBudget ~/ 2).clamp(minChars, totalBudget - minChars);
  final ratio = modelWidth / pixelTotal;
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
          mainAxisSize: MainAxisSize.max,
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
                    color: isDisabled
                        ? Colors.grey.withOpacity(0.4)
                        : cs.onSurface,
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
