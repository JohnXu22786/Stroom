import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../widgets/constrained_text.dart';

/// Popup choices used by CatCatch's output and resource-selection settings.
class CatCatchPolicyMenu extends StatelessWidget {
  final bool outputPolicy;
  final String value;
  final ValueChanged<String> onSelected;

  const CatCatchPolicyMenu({
    super.key,
    required this.outputPolicy,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final options = outputPolicy
        ? <String, String>{
            'video': strings.taskFlowUiCatCatchVideo,
            'audio': strings.taskFlowUiCatCatchAudio,
            'followDownstream': strings.taskFlowUiCatCatchEither,
          }
        : <String, String>{
            'manual': strings.taskFlowUiManual,
            'automatic': strings.taskFlowUiAutomatic,
            'automaticWithPrompt': strings.taskFlowUiAutomaticPrompt,
          };
    return PopupMenuButton<String>(
      key: ValueKey(
        outputPolicy
            ? 'catcatch-output-policy'
            : 'catcatch-resource-selection-policy',
      ),
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => options.entries
          .map(
            (entry) => PopupMenuItem<String>(
              value: entry.key,
              child: ConstrainedText(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(options[value] ?? options.values.first)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
