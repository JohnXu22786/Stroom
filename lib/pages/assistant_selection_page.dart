import 'dart:convert';

import 'package:flutter/material.dart';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('选择助手'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          IconButton(
            // A storefront icon conveys that this entry opens the
            // built-in assistant "market".
            icon: const Icon(Icons.storefront),
            tooltip: '助手市场',
            onPressed: () => showBuiltInPromptSelector(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建助手',
            onPressed: () => _showCreateAssistantDialog(context, ref),
          ),
        ],
      ),
      body: assistants.isEmpty
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
                    '暂无助手，请先创建',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('创建助手'),
                    onPressed: () => _showCreateAssistantDialog(context, ref),
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
                    child: Text(
                      '长按拖拽即可调整助手顺序',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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
                    values: [for (final a in assistants) a.id],
                    onReorder: (from, to) =>
                        ref.read(assistantProvider.notifier).reorderAssistant(
                              from,
                              to,
                            ),
                    itemBuilder: (context, index, id) {
                      final assistant = assistants[index];
                      return AssistantCard(
                        assistant: assistant,
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
          title: const Text('新建助手'),
          content: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: AssistantEditorFields(
              nameController: nameController,
              descriptionController: descriptionController,
              promptController: promptController,
              selectedEmoji: selectedEmoji,
              onEmojiSelected: (e) => setDlgState(() => selectedEmoji = e),
              autofocusName: true,
              nameHint: '输入助手名称',
              descriptionHint: '简短描述此助手的功能',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                disposeControllers();
                Navigator.pop(ctx);
              },
              child: const Text('取消'),
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
              child: const Text('创建'),
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
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                showAssistantFullEditDialog(context, ref, assistant);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(
                '删除',
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
        title: const Text('删除助手'),
        content: Text('确定要删除助手「${assistant.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
