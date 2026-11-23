import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'constrained_text.dart';

Future<bool> showTemporaryConversationEnableDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  // Keep action labels inside the default dialog and action insets.
  final maxActionButtonWidth =
      (MediaQuery.sizeOf(context).width - 128).clamp(64.0, double.infinity);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          actionsOverflowButtonSpacing: 8,
          title: Text(l10n.conversationEnableTemporary),
          content: Text(l10n.conversationTemporaryExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                maximumSize: Size.fromWidth(maxActionButtonWidth),
              ),
              child: ConstrainedText(
                l10n.actionCancel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                maximumSize: Size.fromWidth(maxActionButtonWidth),
              ),
              child: ConstrainedText(
                l10n.conversationEnableTemporary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ) ??
      false;
}
