import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

import '../../../widgets/constrained_text.dart';

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
    super.key,
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
              ? Colors.grey.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDisabled ? Colors.grey.withValues(alpha: 0.4) : color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: ConstrainedText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDisabled
                      ? Colors.grey.withValues(alpha: 0.4)
                      : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              ChipBadge(count: badgeCount!, color: color),
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

  /// The background color of the badge circle. Should match the parent chip's
  /// accent color so the badge visually ties to the chip icon.
  final Color color;

  const ChipBadge({super.key, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

/// A chip that displays the current model name. When [displayName] is empty,
/// it shows the localized model fallback. Long names remain complete and move
/// within the available width when clipped.
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
    final label = displayName.isNotEmpty
        ? displayName
        : AppLocalizations.of(context)!.chatModelFallback;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: isDisabled ? Colors.grey.withValues(alpha: 0.4) : cs.onSurface,
    );

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withValues(alpha: 0.08)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withValues(alpha: 0.1)
                : color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 16,
              color: isDisabled ? Colors.grey.withValues(alpha: 0.4) : color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: ConstrainedText(
                label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
