import 'package:flutter/material.dart';

typedef BackupOperationErrorActionsBuilder = List<Widget> Function(
  BuildContext dialogContext,
);

Future<void> showBackupOperationErrorDialog({
  required BuildContext context,
  required String title,
  required String diagnostic,
  String? additionalMessage,
  BackupOperationErrorActionsBuilder? actionsBuilder,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        scrollable: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colors.error),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: colors.error),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(diagnostic),
            if (additionalMessage != null) ...[
              const SizedBox(height: 16),
              Text(additionalMessage),
            ],
          ],
        ),
        actions: actionsBuilder?.call(dialogContext) ??
            [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child:
                    Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
              ),
            ],
      );
    },
  );
}
