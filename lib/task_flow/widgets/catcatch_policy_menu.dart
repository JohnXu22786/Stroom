import 'package:flutter/material.dart';

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

  static const _outputOptions = <String, String>{
    'video': '视频',
    'audio': '音频',
    'followDownstream': '视频或音频（按下游筛选）',
  };
  static const _selectionOptions = <String, String>{
    'manual': '手动',
    'automatic': '自动',
    'automaticWithPrompt': '自动并询问',
  };

  @override
  Widget build(BuildContext context) {
    final options = outputPolicy ? _outputOptions : _selectionOptions;
    return PopupMenuButton<String>(
      key: ValueKey(outputPolicy
          ? 'catcatch-output-policy'
          : 'catcatch-resource-selection-policy'),
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => options.entries
          .map((entry) => PopupMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ))
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
