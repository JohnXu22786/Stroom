import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../providers/assistant_provider.dart';

/// Shows a dialog listing all built-in assistant prompts.
/// Users can tap one to import it as a regular, editable [Assistant].
void showBuiltInPromptSelector(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => const _BuiltInPromptSelectorDialog(),
  );
}

class _BuiltInPromptSelectorDialog extends ConsumerStatefulWidget {
  const _BuiltInPromptSelectorDialog();

  @override
  ConsumerState<_BuiltInPromptSelectorDialog> createState() =>
      _BuiltInPromptSelectorDialogState();
}

class _BuiltInPromptSelectorDialogState
    extends ConsumerState<_BuiltInPromptSelectorDialog> {
  /// Track which prompt indices are currently being added.
  final Set<int> _addingIndices = {};

  void _importPrompt(int index, BuiltInPrompt prompt) {
    // Mark as adding (shows a brief loading indicator)
    setState(() => _addingIndices.add(index));

    // Immediately create the assistant (synchronous operation)
    ref.read(assistantProvider.notifier).createAssistant(
          name: prompt.name,
          prompt: prompt.prompt,
          emoji: prompt.emoji,
          description: prompt.description,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    '内置助手',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // --- Prompt list ---
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: builtInPrompts.length,
                itemBuilder: (context, index) {
                  final prompt = builtInPrompts[index];
                  final isAdding = _addingIndices.contains(index);

                  return _PromptCard(
                    prompt: prompt,
                    isAdding: isAdding,
                    onTap: isAdding ? null : () => _importPrompt(index, prompt),
                  );
                },
              ),
            ),

            // --- Footer hint ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                '选择后将添加为普通助手，之后可自由编辑',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card that displays a built-in prompt in read-only mode.
class _PromptCard extends StatelessWidget {
  final BuiltInPrompt prompt;
  final bool isAdding;
  final VoidCallback? onTap;

  const _PromptCard({
    required this.prompt,
    required this.isAdding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: emoji + name + add indicator
              Row(
                children: [
                  // Emoji
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(prompt.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prompt.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        if (prompt.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              prompt.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Add button / loading indicator
                  if (isAdding)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.add_circle_outline,
                      size: 24,
                      color: cs.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Prompt text — read-only display in a container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainerHighest
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  prompt.prompt,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
