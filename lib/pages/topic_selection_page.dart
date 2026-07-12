import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pages/assistant_selection_page.dart';
import '../providers/assistant_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/llm/assistant_avatar.dart';
import '../widgets/search_panel.dart';
import '../widgets/topic_item.dart';
import '../services/attachment_storage.dart';

/// Merged page: after selecting an assistant, choose or create a conversation.
/// Features: card-based UI, selection mode, pin, rename, reorder, search panel.
class TopicSelectionPage extends ConsumerStatefulWidget {
  const TopicSelectionPage({super.key});

  @override
  ConsumerState<TopicSelectionPage> createState() => _TopicSelectionPageState();
}

class _TopicSelectionPageState extends ConsumerState<TopicSelectionPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  List<Conversation> _sortedConversations(List<Conversation> conversations) {
    final sorted = List<Conversation>.from(conversations);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });
    return sorted;
  }

  List<Conversation> _getAssistantTopics(List<Conversation> allConversations) {
    final assistantId = ref.watch(selectedAssistantIdProvider);
    return allConversations
        .where((c) => c.assistantId == assistantId || c.assistantId == null)
        .toList();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 个对话吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final convs = ref.read(conversationsProvider);
    for (final id in _selectedIds) {
      final conv = convs.where((c) => c.id == id).firstOrNull;
      if (conv != null) {
        for (final msg in conv.messages) {
          for (final att in msg.attachments) {
            await AttachmentStorage.deleteFile(att.storagePath);
          }
        }
      }
    }

    await ref
        .read(conversationsProvider.notifier)
        .batchDelete(_selectedIds.toList());
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _deleteTopic(Conversation topic) async {
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == topic.id).firstOrNull;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content:
            Text('确定要删除对话「${topic.title.isEmpty ? '新对话' : topic.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (conv != null) {
      for (final msg in conv.messages) {
        for (final att in msg.attachments) {
          await AttachmentStorage.deleteFile(att.storagePath);
        }
      }
    }

    await ref.read(conversationsProvider.notifier).deleteConversation(topic.id);
  }

  void _renameTopic(String id, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref
                  .read(conversationsProvider.notifier)
                  .renameConversation(id, value.trim());
            }
            controller.dispose();
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                ref
                    .read(conversationsProvider.notifier)
                    .renameConversation(id, value);
              }
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _createNewTopic() {
    final assistantId = ref.read(selectedAssistantIdProvider);
    if (assistantId == null) return;

    ref
        .read(conversationsProvider.notifier)
        .createConversation(assistantId: assistantId);

    Navigator.of(context).pushNamed('/chat');
  }

  void _onTopicSelected(Conversation topic) {
    ref.read(conversationsProvider.notifier).selectConversation(topic.id);
    Navigator.of(context).pushNamed('/chat');
  }

  void _showSearchPanel() {
    final conversations = ref.read(conversationsProvider);
    final assistantTopics = _getAssistantTopics(conversations);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SearchPanel(
        conversations: assistantTopics,
        onConversationSelected: (conv) {
          Navigator.of(ctx).pop();
          _onTopicSelected(conv);
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            '暂无对话',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text('创建一个新对话开始对话',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAssistant = ref.watch(selectedAssistantProvider);
    final conversations = ref.watch(conversationsProvider);
    final cs = Theme.of(context).colorScheme;

    final assistantTopics = _getAssistantTopics(conversations);
    final sorted = _sortedConversations(assistantTopics);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_selectionMode ? '已选 ${_selectedIds.length} 个' : '选择对话'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: _showSearchPanel,
            ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除选中',
              onPressed: _selectedIds.isNotEmpty ? _batchDelete : null,
            ),
          IconButton(
            icon: Icon(
              _selectionMode ? Icons.close : Icons.checklist,
            ),
            tooltip: _selectionMode ? '取消选择' : '选择',
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      body: selectedAssistant == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('未选择助手', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.read(selectedAssistantIdProvider.notifier).state =
                          null;
                      Navigator.pop(context);
                    },
                    child: const Text('返回选择助手'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Selected assistant info bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primaryContainer,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      AssistantAvatar(
                        assistant: selectedAssistant,
                        size: 40,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAssistant.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            if (selectedAssistant.description.isNotEmpty)
                              Text(
                                selectedAssistant.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: '编辑助手',
                        onPressed: () {
                          showAssistantFullEditDialog(
                              context, ref, selectedAssistant);
                        },
                      ),
                    ],
                  ),
                ),

                // Fixed hint: long-press drag to reorder
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '长按拖拽即可调整对话顺序',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Conversation list
                Expanded(
                  child: sorted.isEmpty
                      ? _buildEmptyState(cs)
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: sorted.length,
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            final convs = ref.read(conversationsProvider);
                            final item = sorted[oldIndex];
                            final realOld =
                                convs.indexWhere((c) => c.id == item.id);
                            // Flutter's onReorder provides newIndex as the
                            // position in the list before removal. When
                            // dragging downward, decrement by 1 because
                            // the item was removed from above, shifting
                            // remaining items down.
                            if (oldIndex < newIndex) {
                              newIndex--;
                            }
                            final target = sorted[newIndex];
                            final realNew =
                                convs.indexWhere((c) => c.id == target.id);
                            if (realOld >= 0 && realNew >= 0) {
                              ref
                                  .read(conversationsProvider.notifier)
                                  .reorderConversation(realOld, realNew);
                            }
                          },
                          proxyDecorator: (child, index, animation) => Material(
                            elevation: 2,
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            child: child,
                          ),
                          itemBuilder: (context, index) {
                            final topic = sorted[index];
                            final itemWidget = TopicItem(
                              key: ValueKey('topic_${topic.id}'),
                              topic: topic,
                              selectionMode: _selectionMode,
                              isSelected: _selectedIds.contains(topic.id),
                              isActive: topic.id ==
                                  ref.watch(activeConversationIdProvider),
                              onTap: () {
                                if (_selectionMode) {
                                  _toggleSelection(topic.id);
                                } else {
                                  _onTopicSelected(topic);
                                }
                              },
                              onDelete: () => _deleteTopic(topic),
                              onPinToggle: () {
                                ref
                                    .read(conversationsProvider.notifier)
                                    .togglePin(topic.id);
                              },
                              onRename: () =>
                                  _renameTopic(topic.id, topic.title),
                              onAutoRename: () {
                                ref
                                    .read(conversationsProvider.notifier)
                                    .autoRenameConversation(topic.id);
                              },
                              onSelectionToggle: () =>
                                  _toggleSelection(topic.id),
                            );
                            // When NOT in selection mode, wrap in long-press drag listener
                            if (!_selectionMode) {
                              return ReorderableDelayedDragStartListener(
                                index: index,
                                key: ValueKey('drag_${topic.id}'),
                                child: itemWidget,
                              );
                            }
                            return itemWidget;
                          },
                        ),
                ),

                // Bottom: create new conversation button
                if (!_selectionMode)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('新话题'),
                          onPressed: _createNewTopic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
