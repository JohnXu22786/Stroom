import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

Future<bool> showTemporaryConversationEnableDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.conversationEnableTemporary),
          content: Text(l10n.conversationTemporaryExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.conversationEnableTemporary),
            ),
          ],
        ),
      ) ??
      false;
}
