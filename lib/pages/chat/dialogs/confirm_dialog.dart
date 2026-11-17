import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

import '../../../widgets/constrained_text.dart';

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
        title: ConstrainedText(
          AppLocalizations.of(context)!.chatConfirmEditTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          newerMessagesExist
              ? AppLocalizations.of(context)!.chatConfirmEditDeleteFollowing
              : AppLocalizations.of(context)!.chatConfirmResend,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              AppLocalizations.of(context)!.actionCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: ConstrainedText(
              AppLocalizations.of(context)!.actionConfirm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  } else {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: ConstrainedText(
          AppLocalizations.of(context)!.chatConfirmRetryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          newerMessagesExist
              ? AppLocalizations.of(context)!.chatConfirmRetryDeleteFollowing
              : AppLocalizations.of(context)!.chatConfirmRegenerate,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: ConstrainedText(
              AppLocalizations.of(context)!.actionCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: ConstrainedText(
              AppLocalizations.of(context)!.actionConfirm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
      title: ConstrainedText(
        AppLocalizations.of(context)!.chatDeleteMessageTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: Text(AppLocalizations.of(context)!.chatDeleteMessageConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: ConstrainedText(
            AppLocalizations.of(context)!.actionCancel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onDelete();
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: ConstrainedText(
            AppLocalizations.of(context)!.actionDelete,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
