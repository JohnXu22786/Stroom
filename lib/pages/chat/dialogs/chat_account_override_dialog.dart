import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';

class ChatAccountOverrideChoice {
  const ChatAccountOverrideChoice({
    required this.id,
    required this.name,
    required this.connectorType,
  });

  final String id;
  final String name;
  final String connectorType;
}

class ChatAccountOverrideDialog extends StatelessWidget {
  const ChatAccountOverrideDialog({
    required this.accounts,
    required this.selectedAccountId,
    super.key,
  });

  final List<ChatAccountOverrideChoice> accounts;
  final String? selectedAccountId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - 48).clamp(0.0, 420.0);
    return AlertDialog(
      title: Text(localizations?.llmAccountForThisRequest ?? '本轮使用账号'),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.65),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  selected: selectedAccountId == null,
                  title: Text(
                    localizations?.llmAccountUseModelGroup ?? '按模型组策略路由',
                  ),
                  trailing: selectedAccountId == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
                for (final account in accounts)
                  ListTile(
                    selected: account.id == selectedAccountId,
                    title: ConstrainedText(account.name, maxLines: 1),
                    subtitle: ConstrainedText(
                      account.connectorType,
                      maxLines: 1,
                    ),
                    trailing: account.id == selectedAccountId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(account.id),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations?.actionCancel ?? '取消'),
        ),
      ],
    );
  }
}
