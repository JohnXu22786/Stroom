import 'package:flutter/material.dart';

import '../widgets/constrained_text.dart';

/// Header and controls for the audio player's source text card.
class AudioSourceHeader extends StatelessWidget {
  const AudioSourceHeader({
    super.key,
    required this.title,
    required this.hasSource,
    required this.emptyMessage,
    required this.uploadLabel,
    required this.editLabel,
    required this.fontSize,
    required this.onUpload,
    required this.onDecreaseFontSize,
    required this.onIncreaseFontSize,
    required this.canDecreaseFontSize,
    required this.canIncreaseFontSize,
  });

  final String title;
  final bool hasSource;
  final String emptyMessage;
  final String uploadLabel;
  final String editLabel;
  final int fontSize;
  final VoidCallback onUpload;
  final VoidCallback onDecreaseFontSize;
  final VoidCallback onIncreaseFontSize;
  final bool canDecreaseFontSize;
  final bool canIncreaseFontSize;

  Widget _action(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onUpload,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: ConstrainedText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    if (!hasSource) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            emptyMessage,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          _action(context, Icons.upload_file, uploadLabel),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        _action(context, Icons.edit, editLabel),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$fontSize',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: canDecreaseFontSize ? onDecreaseFontSize : null,
              child: Icon(
                Icons.text_decrease,
                size: 20,
                color:
                    canDecreaseFontSize ? Colors.grey[700] : Colors.grey[300],
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: canIncreaseFontSize ? onIncreaseFontSize : null,
              child: Icon(
                Icons.text_increase,
                size: 20,
                color:
                    canIncreaseFontSize ? Colors.grey[700] : Colors.grey[300],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = _actions(context);
        final constrainedTitle = ConstrainedText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        );
        if (constraints.maxWidth < 400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: constrainedTitle,
              ),
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerEnd, child: actions),
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [constrainedTitle, actions],
        );
      },
    );
  }
}
