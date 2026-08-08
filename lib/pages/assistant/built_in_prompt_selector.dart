import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../providers/assistant_provider.dart';

/// Shows a dialog listing all built-in assistant prompts (the assistant
/// "market"). Tapping a card opens a detail panel where the user can review
/// the prompt before importing it as a regular, editable [Assistant].
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
    // Re-entrancy guard. Pointer taps during the route exit animation are
    // already blocked by the framework, but non-pointer activation (e.g.
    // keyboard/accessibility) could re-invoke this and import twice.
    if (_addingIndices.contains(index)) return;
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

  /// Opens the detail panel for a prompt. Tapping the small card no longer
  /// imports the prompt directly — the user reviews it here first.
  void _showPromptDetail(int index, BuiltInPrompt prompt) {
    showDialog(
      context: context,
      builder: (ctx) => _PromptDetailDialog(
        prompt: prompt,
        onAdd: () {
          // Guard BEFORE popping: a re-entrant invocation after the first
          // pop would pop the route beneath the dialogs.
          if (_addingIndices.contains(index)) return;
          Navigator.of(ctx).pop();
          _importPrompt(index, prompt);
        },
      ),
    );
  }

  /// Opens a read-only viewer with the full prompt text. The prompt is
  /// deliberately hidden on the list cards; this is where it can be viewed.
  void _showPromptViewer(BuiltInPrompt prompt) {
    showDialog(
      context: context,
      builder: (ctx) => _PromptViewerDialog(prompt: prompt),
    );
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
                  Icon(Icons.storefront, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    '助手市场',
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
                    onTap: isAdding
                        ? null
                        : () => _showPromptDetail(index, prompt),
                    onInfo: isAdding ? null : () => _showPromptViewer(prompt),
                    onAdd: isAdding ? null : () => _importPrompt(index, prompt),
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

/// A compact market card: emoji + name + description only. The prompt text
/// stays hidden — it is shown via the info icon (or in the detail panel).
class _PromptCard extends StatelessWidget {
  final BuiltInPrompt prompt;
  final bool isAdding;
  final VoidCallback? onTap;
  final VoidCallback? onInfo;
  final VoidCallback? onAdd;

  const _PromptCard({
    required this.prompt,
    required this.isAdding,
    required this.onTap,
    required this.onInfo,
    required this.onAdd,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Emoji
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child:
                      Text(prompt.emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              // Name and description (the prompt itself is not shown here)
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
                          maxLines: 2,
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
              const SizedBox(width: 6),
              // Info: view the full prompt
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: '查看提示词',
                onPressed: onInfo,
              ),
              const SizedBox(width: 4),
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
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  style: FilledButton.styleFrom(
                    // Compact so the card keeps room for the description
                    // on narrow screens.
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(48, 36),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail panel for a built-in prompt: name, full description, the prompt
/// text and the import action. Opened by tapping a card — importing happens
/// from here or from the card's 添加 button.
class _PromptDetailDialog extends StatelessWidget {
  final BuiltInPrompt prompt;
  final VoidCallback onAdd;

  const _PromptDetailDialog({required this.prompt, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      // Match the market dialog's insets so the stacked dialogs line up.
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        // Scroll as a whole on short screens; the prompt container inside
        // has its own bounded height and scrolls independently.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(prompt.emoji,
                            style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prompt.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                if (prompt.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '描述',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prompt.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurface,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '系统提示词',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                _PromptTextContainer(prompt: prompt, maxHeight: 240),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('添加助手'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Styled, scrollable container that shows a prompt's full text.
class _PromptTextContainer extends StatelessWidget {
  final BuiltInPrompt prompt;
  final double maxHeight;

  const _PromptTextContainer({required this.prompt, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: SingleChildScrollView(
        child: Text(
          prompt.prompt,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Read-only viewer for a prompt's full system prompt text.
class _PromptViewerDialog extends StatelessWidget {
  final BuiltInPrompt prompt;

  const _PromptViewerDialog({required this.prompt});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text(prompt.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '提示词 · ${prompt.name}',
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: _PromptTextContainer(prompt: prompt, maxHeight: 360),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
