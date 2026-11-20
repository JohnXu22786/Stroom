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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Flexible(
                child: ConstrainedText(
                  label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ConstrainedText(
                  folder,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
