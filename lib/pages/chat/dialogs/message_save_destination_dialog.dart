import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

import '../../../widgets/constrained_text.dart';

enum MessageSaveDestination { appFiles, device }

Future<MessageSaveDestination?> showMessageSaveDestinationDialog(
  BuildContext context,
) {
  return showDialog<MessageSaveDestination>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: ConstrainedText(
        AppLocalizations.of(context)!.chatSaveMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
            label: ConstrainedText(
              AppLocalizations.of(context)!.chatSaveAppFile,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
          child: ConstrainedText(
            AppLocalizations.of(context)!.actionCancel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
