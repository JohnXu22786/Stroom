import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

enum MessageSaveDestination { appFiles, device }

Future<MessageSaveDestination?> showMessageSaveDestinationDialog(
  BuildContext context,
) {
  return showDialog<MessageSaveDestination>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context)!.chatSaveMessage),
      icon: const Icon(Icons.save_outlined),
      semanticLabel: AppLocalizations.of(context)!.chatChooseSaveLocation,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppLocalizations.of(context)!.chatChooseSaveLocationLabel),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.chatSaveAppFile),
            onPressed: () =>
                Navigator.of(ctx).pop(MessageSaveDestination.appFiles),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.chatSaveDevice),
            onPressed: () =>
                Navigator.of(ctx).pop(MessageSaveDestination.device),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(AppLocalizations.of(context)!.actionCancel),
        ),
      ],
    ),
  );
}
