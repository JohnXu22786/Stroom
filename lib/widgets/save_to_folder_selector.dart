import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'constrained_text.dart';

/// A compact folder picker row for choosing where generated content is saved.
class SaveToFolderSelector extends StatelessWidget {
  const SaveToFolderSelector({
    super.key,
    required this.label,
    required this.folder,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String folder;
  final VoidCallback? onTap;
  final bool enabled;

  double _naturalTextWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    final folderStyle = TextStyle(
      fontSize: 12,
      color: cs.primary,
      fontWeight: FontWeight.w500,
    );
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const fixedWidth = 16 + 8 + 4 + 16;
              final availableTextWidth = constraints.maxWidth - fixedWidth;
              final labelWidth = _naturalTextWidth(context, label, labelStyle);
              final folderWidth = _naturalTextWidth(
                context,
                folder,
                folderStyle,
              );
              final combinedTextWidth = labelWidth + folderWidth;
              final labelSlotWidth = combinedTextWidth <= availableTextWidth
                  ? labelWidth
                  : math.min(
                      labelWidth,
                      availableTextWidth -
                          math.min(
                            folderWidth,
                            math.min(64.0, availableTextWidth * 0.25),
                          ),
                    );

              return Row(
                children: [
                  Icon(Icons.folder_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: labelSlotWidth,
                    child: ConstrainedText(
                      label,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ConstrainedText(
                      folder,
                      style: folderStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
