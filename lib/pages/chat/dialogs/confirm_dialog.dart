import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

/// Shows a confirmation dialog for editing a user message or retrying an AI message.
Future<void> showRetryEditConfirmDialog({
  required BuildContext context,
  required bool isUser,
  required bool newerMessagesExist,
  required VoidCallback onEdit,
  required VoidCallback onRetry,
}) async {
  if (isUser) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.chatConfirmEditTitle),
        content: Text(
          newerMessagesExist
              ? AppLocalizations.of(context)!.chatConfirmEditDeleteFollowing
              : AppLocalizations.of(context)!.chatConfirmResend,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: Text(AppLocalizations.of(context)!.actionConfirm),
          ),
        ],
      ),
    );
  } else {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.chatConfirmRetryTitle),
        content: Text(
          newerMessagesExist
              ? AppLocalizations.of(context)!.chatConfirmRetryDeleteFollowing
              : AppLocalizations.of(context)!.chatConfirmRegenerate,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: Text(AppLocalizations.of(context)!.actionConfirm),
          ),
        ],
      ),
    );
  }
}

/// Shows a confirmation dialog for deleting a message.
Future<void> showDeleteConfirmDialog({
  required BuildContext context,
  required VoidCallback onDelete,
}) async {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context)!.chatDeleteMessageTitle),
      content: Text(AppLocalizations.of(context)!.chatDeleteMessageConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(context)!.actionCancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onDelete();
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(AppLocalizations.of(context)!.actionDelete),
        ),
      ],
    ),
  );
}
