import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/assistant.dart';
import '../../models/built_in_prompts.dart';
import '../../providers/assistant_provider.dart';
import '../../services/assistant_catalog_service.dart';
import 'assistant_remote_source_dialog.dart';

import '../../widgets/constrained_text.dart';

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
    final strings = AppLocalizations.of(context)!;
    final prompts = localizedBuiltInPrompts(strings);
    final size = MediaQuery.sizeOf(context);
    final panelHeight = (size.height - 48).clamp(0.0, 900.0).toDouble();
    final panelWidth = (size.width - 48).clamp(0.0, 720.0).toDouble();

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final panel = SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () {
                          final tabs = DefaultTabController.of(context);
                          if (tabs.index == 1) {
                            tabs.animateTo(0);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: ConstrainedText(
                          strings.assistantAddTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.builtInPromptClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(3),
                      indicator: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      labelColor: cs.onPrimary,
                      unselectedLabelColor: cs.onSurfaceVariant,
                      tabs: [
                        Tab(
                          child: _AssistantSourceTab(
                            icon: Icons.storefront_outlined,
                            label: strings.assistantBuiltInTab,
                          ),
                        ),
                        Tab(
                          child: _AssistantSourceTab(
                            icon: Icons.link,
                            label: strings.assistantImportTab,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _BuiltInPromptList(
                        prompts: prompts,
                        addingIndices: _addingIndices,
                        onPromptTap: _showPromptDetail,
                        onPromptInfo: _showPromptViewer,
                        onPromptAdd: _importPrompt,
                      ),
                      _AssistantImportTab(
                        onImport: () => showAssistantRemoteSourceDialog(
                          context,
                          ref,
                          initialUrl: kDefaultAssistantCatalogUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (size.width < 600) {
            return Dialog.fullscreen(backgroundColor: cs.surface, child: panel);
          }

          return Dialog(
            backgroundColor: cs.surface,
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: panelWidth,
              height: panelHeight,
              child: panel,
            ),
          );
        },
      ),
    );
  }
}

class _AssistantSourceTab extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AssistantSourceTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

class _BuiltInPromptList extends StatelessWidget {
  final List<BuiltInPrompt> prompts;
  final Set<int> addingIndices;
  final void Function(int index, BuiltInPrompt prompt) onPromptTap;
  final void Function(BuiltInPrompt prompt) onPromptInfo;
  final void Function(int index, BuiltInPrompt prompt) onPromptAdd;

  const _BuiltInPromptList({
    required this.prompts,
    required this.addingIndices,
    required this.onPromptTap,
    required this.onPromptInfo,
    required this.onPromptAdd,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: ConstrainedText(
            strings.assistantBuiltInHint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: prompts.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 16, endIndent: 8),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              final isAdding = addingIndices.contains(index);
              return _BuiltInPromptRow(
                prompt: prompt,
                isAdding: isAdding,
                onTap: isAdding ? null : () => onPromptTap(index, prompt),
                onInfo: isAdding ? null : () => onPromptInfo(prompt),
                onAdd: isAdding ? null : () => onPromptAdd(index, prompt),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BuiltInPromptRow extends StatelessWidget {
  final BuiltInPrompt prompt;
  final bool isAdding;
  final VoidCallback? onTap;
  final VoidCallback? onInfo;
  final VoidCallback? onAdd;

  const _BuiltInPromptRow({
    required this.prompt,
    required this.isAdding,
    required this.onTap,
    required this.onInfo,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(prompt.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedText(
                    prompt.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  if (prompt.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    ConstrainedText(
                      prompt.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: strings.builtInPromptView,
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
              visualDensity: VisualDensity.compact,
            ),
            if (isAdding)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: ConstrainedText(
                  strings.builtInPromptAdd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(48, 36),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssistantImportTab extends StatelessWidget {
  final VoidCallback onImport;

  const _AssistantImportTab({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.link, size: 48, color: colorScheme.primary),
          const SizedBox(height: 20),
          ConstrainedText(
            strings.assistantImportTab,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            strings.assistantImportHint,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.download),
            label: ConstrainedText(
              strings.assistantImportAction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    final strings = AppLocalizations.of(context)!;

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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          prompt.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
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
                      tooltip: strings.builtInPromptClose,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                if (prompt.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.builtInPromptDescriptionHeading,
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
                  strings.builtInPromptSystemPromptHeading,
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
                    label: ConstrainedText(
                      strings.builtInPromptAddAssistant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        child: Text(
          prompt.prompt,
          style: TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurface),
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
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          Text(prompt.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: ConstrainedText(
              strings.builtInPromptViewerTitle(prompt.name),
              maxLines: 1,
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
          child: ConstrainedText(
            strings.builtInPromptClose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
