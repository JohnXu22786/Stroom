import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/stroom_menu_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import '../providers/chat_manager_provider.dart';
import '../providers/provider_config.dart';
import '../services/chat_adapter.dart' show resolveModelRef;
import '../widgets/code_editor_field.dart';
import '../widgets/drag_sort_area.dart';
import 'assistant/assistant_defaults_tab.dart';
import 'assistant/assistant_shared.dart';
import 'assistant/built_in_prompt_selector.dart';
export 'assistant/assistant_shared.dart';

part 'assistant_selection_page_edit_dialog.dart';
part 'assistant_selection_page_edit_params_tab.dart';
part 'assistant_selection_page_add_custom_param.dart';
part 'assistant_selection_page_edit_custom_param.dart';

/// First page in the chat flow: select an assistant.
/// Displays assistants in a grid of cards, similar to Cherry Studio's design.
class AssistantSelectionPage extends ConsumerWidget {
  const AssistantSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistants = ref.watch(assistantProvider);
    final isLoading = ref.watch(assistantInitialLoadProvider).isLoading;
    final cs = Theme.of(context).colorScheme;
    final pressHighlightColor = cs.primary.withValues(alpha: 0.02);
    final dragHighlightColor = cs.primary.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.taskFlowUiChooseAssistant),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            // A storefront icon conveys that this entry opens the
            // built-in assistant "market".
            icon: const Icon(Icons.storefront),
            tooltip: AppLocalizations.of(context)!.builtInPromptMarketTitle,
            onPressed: () => showBuiltInPromptSelector(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)!.assistantCreateNew,
            onPressed: () => _showCreateAssistantDialog(context, ref),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : assistants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 64,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.assistantEmptyState,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(
                            AppLocalizations.of(context)!.assistantCreate),
                        onPressed: () =>
                            _showCreateAssistantDialog(context, ref),
                      ),
                    ],
                  ),
                )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 与话题页一致的提示文案：新加入的长按拖拽手势需要被发现
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.assistantReorderHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  DragSortArea(
                    // 与旧 GridView 相同的几何：
                    // SliverGridDelegateWithMaxCrossAxisExtent(
                    //   maxCrossAxisExtent: 220, spacing: 12, aspectRatio: 0.85)
                    wrap: false,
                    grid: true,
                    gridMaxCrossAxisExtent: 220,
                    gridCrossAxisSpacing: 12,
                    gridMainAxisSpacing: 12,
                    gridChildAspectRatio: 0.85,
                    dragDelay: const Duration(milliseconds: 600),
                    dragHighlightColor: dragHighlightColor,
                    draggedItemOpacity: 0.88,
                    values: [for (final a in assistants) a.id],
                    onReorder: (from, to) => ref
                        .read(assistantProvider.notifier)
                        .reorderAssistant(from, to),
                    itemBuilder: (context, index, id) {
                      final assistant = assistants[index];
                      return AssistantCard(
                        assistant: assistant,
                        pressHighlightColor: pressHighlightColor,
                        onTap: () =>
                            _onAssistantSelected(context, ref, assistant),
                        // 长按已让给拖拽排序，编辑/删除入口移到卡片右上角 ⋮
                        onMenu: () =>
                            _showAssistantMenu(context, ref, assistant),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  void _onAssistantSelected(
    BuildContext context,
    WidgetRef ref,
    Assistant assistant,
  ) {
    // Set the selected assistant
    ref.read(selectedAssistantIdProvider.notifier).state = assistant.id;
    // Navigate to topic selection within the chat tab's nested navigator
    Navigator.of(context).pushNamed('/topic-selection');
  }

  void _showCreateAssistantDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final promptController = TextEditingController(
      text: '你是一个有帮助的AI助手。请用中文回答用户的问题。',
    );
    String selectedEmoji = '🤖';
    final descriptionController = TextEditingController();

    void disposeControllers() {
      nameController.dispose();
      promptController.dispose();
      descriptionController.dispose();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.assistantCreateNew),
          content: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: AssistantEditorFields(
              nameController: nameController,
              descriptionController: descriptionController,
              promptController: promptController,
              selectedEmoji: selectedEmoji,
              onEmojiSelected: (e) => setDlgState(() => selectedEmoji = e),
              autofocusName: true,
              nameHint: AppLocalizations.of(context)!.assistantNewNameHint,
              descriptionHint:
                  AppLocalizations.of(context)!.assistantNewDescriptionHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                disposeControllers();
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context)!.batchDlgCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                ref.read(assistantProvider.notifier).createAssistant(
                      name: name,
                      prompt: promptController.text.trim(),
                      emoji: selectedEmoji,
                      description: descriptionController.text.trim(),
                    );
                disposeControllers();
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context)!.fileManagerCreate),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssistantMenu(
    BuildContext context,
    WidgetRef ref,
    Assistant assistant,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppLocalizations.of(context)!.imagePreviewEdit),
              onTap: () {
                Navigator.pop(ctx);
                showAssistantFullEditDialog(context, ref, assistant);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(
                AppLocalizations.of(context)!.fileManagerDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteAssistantConfirmation(context, ref, assistant);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAssistantConfirmation(
    BuildContext context,
    WidgetRef ref,
    Assistant assistant,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.assistantDeleteTitle),
        content: Text(
          AppLocalizations.of(context)!
              .assistantDeleteConfirmation(assistant.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.batchDlgCancel),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(assistantProvider.notifier)
                  .deleteAssistant(assistant.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.fileManagerDelete),
          ),
        ],
      ),
    );
  }
}
