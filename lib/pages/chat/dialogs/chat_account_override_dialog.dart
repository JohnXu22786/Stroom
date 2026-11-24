import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';

/// Account shown as an explicit option for the next Chat request.
class ChatAccountOverrideChoice {
  const ChatAccountOverrideChoice({
    required this.id,
    required this.displayName,
    required this.connectorType,
  });

  final String id;
  final String displayName;
  final String connectorType;
}

/// Shows the one-request account selector. An empty result selects the model
/// group's routing policy; `null` means the user dismissed the dialog.
Future<String?> showChatAccountOverrideDialog({
  required BuildContext context,
  required List<ChatAccountOverrideChoice> accounts,
  required String? selectedAccountId,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        AppLocalizations.of(dialogContext)?.llmAccountForThisRequest ??
            '本轮使用账号',
      ),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              selected: selectedAccountId == null,
              leading: Icon(
                selectedAccountId == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(
                AppLocalizations.of(dialogContext)?.llmAccountUseModelGroup ??
                    '按模型组策略路由',
              ),
              onTap: () => Navigator.of(dialogContext).pop(''),
            ),
            for (final account in accounts)
              ListTile(
                selected: account.id == selectedAccountId,
                leading: Icon(
                  account.id == selectedAccountId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(account.displayName),
                subtitle: Text(account.connectorType),
                selectedTileColor: Theme.of(dialogContext)
                    .colorScheme
                    .secondaryContainer,
                iconColor: account.id == selectedAccountId
                    ? Theme.of(dialogContext).colorScheme.primary
                    : Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                onTap: () => Navigator.of(dialogContext).pop(account.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.of(dialogContext)?.actionCancel ?? '取消'),
        ),
      ],
    ),
  );
}
