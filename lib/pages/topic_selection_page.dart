import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/llm/assistant_avatar.dart';
import '../services/attachment_storage.dart';

/// Helper: count message content matches in a conversation for a query.
int _countMessageMatches(Conversation conv, String query) {
  if (query.isEmpty) return 0;
  final lowerQuery = query.toLowerCase();
  int count = 0;
  for (final msg in conv.messages) {
    final lowerContent = msg.content.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lowerContent.indexOf(lowerQuery, start);
      if (idx == -1) break;
      count++;
      start = idx + lowerQuery.length;
    }
  }
  return count;
}

/// Merged page: after selecting an assistant, choose or create a topic (conversation).
/// Combines the card-based UI of TopicSelectionPage with the features from
/// ConversationsPage (search, selection mode, pin, rename, reorder, etc.).
class TopicSelectionPage extends ConsumerStatefulWidget {
  const TopicSelectionPage({super.key});

  @override
  ConsumerState<TopicSelectionPage> createState() => _TopicSelectionPageState();
}

class _TopicSelectionPageState extends ConsumerState<TopicSelectionPage> {
  bool _showSearch = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _sortedConversations(List<Conversation> conversations) {
    final sorted = List<Conversation>.from(conversations);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });
    return sorted;
  }

  List<Conversation> _getFilteredTopics(List<Conversation> assistantTopics) {
    final query = _searchController.text.trim().toLowerCase();
    _searchQuery = query;
    var result = _sortedConversations(assistantTopics);
    if (query.isNotEmpty) {
      result = result.where((c) {
        final displayTitle = c.title.isEmpty ? '新对话' : c.title;
        if (displayTitle.toLowerCase().contains(query)) return true;
        if (_countMessageMatches(c, query) > 0) return true;
        return false;
      }).toList();
    }
    return result;
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
        title: const Text('删除话题'),
        content: Text('确定要删除话题「${topic.title.isEmpty ? '新话题' : topic.title}」吗？'),
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
        title: const Text('重命名话题'),
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

    ref.read(conversationsProvider.notifier)
        .createConversation(assistantId: assistantId);

    Navigator.of(context).pushNamed('/chat');
  }

  void _onTopicSelected(Conversation topic) {
    ref.read(conversationsProvider.notifier).selectConversation(topic.id);
    Navigator.of(context).pushNamed('/chat');
  }

  Widget _buildEmptyState(ColorScheme cs) {
    final query = _searchController.text.trim();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty ? '没有找到匹配的话题' : '暂无话题',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          if (query.isEmpty) ...[
            const SizedBox(height: 8),
            Text('创建一个新话题开始对话',
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant.withOpacity(0.7))),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAssistant = ref.watch(selectedAssistantProvider);
    final conversations = ref.watch(conversationsProvider);
    final cs = Theme.of(context).colorScheme;

    final assistantId = ref.watch(selectedAssistantIdProvider);
    final assistantTopics = conversations
        .where((c) => c.assistantId == assistantId || c.assistantId == null)
        .toList();
    final filtered = _getFilteredTopics(assistantTopics);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _showSearch
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showSearch = false;
                    _searchController.clear();
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索话题...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                ),
                onChanged: (value) => setState(() {}),
              ),
            )
          : AppBar(
              title: Row(
                children: [
                  if (selectedAssistant != null) ...[
                    AssistantAvatar(
                      assistant: selectedAssistant,
                      size: 28,
                      borderRadius: 8,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(_selectionMode ? '已选 ${_selectedIds.length} 个' : '选择话题'),
                ],
              ),
              centerTitle: false,
              elevation: 0,
              backgroundColor: cs.surface,
              actions: [
                if (!_selectionMode)
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: '搜索',
                    onPressed: () => setState(() => _showSearch = true),
                  ),
                if (_selectionMode)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '删除选中',
                    onPressed:
                        _selectedIds.isNotEmpty ? _batchDelete : null,
                  ),
                IconButton(
                  icon: Icon(
                    _selectionMode
                        ? Icons.close
                        : Icons.checklist,
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
                      size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('未选择助手',
                      style: TextStyle(color: cs.onSurfaceVariant)),
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
                    color: cs.primaryContainer.withOpacity(0.3),
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
                        tooltip: '选择助手',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Topic list
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(cs)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final topic = filtered[index];
                            return _TopicItem(
                              topic: topic,
                              selectionMode: _selectionMode,
                              isSelected: _selectedIds.contains(topic.id),
                              isActive: topic.id == ref.watch(activeConversationIdProvider),
                              searchQuery: _searchQuery,
                              onTap: () {
                                if (_selectionMode) {
                                  _toggleSelection(topic.id);
                                } else {
                                  _onTopicSelected(topic);
                                }
                              },
                              onLongPress: () {
                                if (!_selectionMode) {
                                  _toggleSelectionMode();
                                  _selectedIds.add(topic.id);
                                }
                              },
                              onDelete: () => _deleteTopic(topic),
                              onPinToggle: () {
                                ref.read(conversationsProvider.notifier)
                                    .togglePin(topic.id);
                              },
                              onRename: () => _renameTopic(topic.id, topic.title),
                              onAutoRename: () {
                                ref.read(conversationsProvider.notifier)
                                    .autoRenameConversation(topic.id);
                              },
                              onSelectionToggle: () => _toggleSelection(topic.id),
                            );
                          },
                        ),
                ),

                // Bottom: create new topic button
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

// ============================================================================
// Topic item widget - Card-based UI with ConversationsPage features
// ============================================================================

class _TopicItem extends StatelessWidget {
  final Conversation topic;
  final bool selectionMode;
  final bool isSelected;
  final bool isActive;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onPinToggle;
  final VoidCallback onRename;
  final VoidCallback onAutoRename;
  final VoidCallback onSelectionToggle;

  const _TopicItem({
    required this.topic,
    required this.selectionMode,
    required this.isSelected,
    required this.isActive,
    required this.searchQuery,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onPinToggle,
    required this.onRename,
    required this.onAutoRename,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = topic.title.isEmpty ? '新话题' : topic.title;
    final subtitle = _formatDate(topic.updatedAt);
    final msgCount = topic.messages.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive
          ? cs.primaryContainer.withOpacity(0.2)
          : (isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? cs.primary.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.5),
          width: isActive ? 1.0 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Selection checkbox or icon
              if (selectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionToggle(),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    topic.isPinned
                        ? Icons.push_pin
                        : Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: topic.isPinned
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 12),
              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (topic.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin,
                                size: 12, color: cs.primary),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        // Match count badge when searching
                        if (searchQuery.isNotEmpty)
                          _buildMatchBadge(cs),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (msgCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.message_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            '$msgCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (!selectionMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        topic.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 18,
                        color: topic.isPinned
                            ? cs.primary
                            : cs.onSurfaceVariant.withOpacity(0.7),
                      ),
                      tooltip: topic.isPinned ? '取消置顶' : '置顶',
                      onPressed: onPinToggle,
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: cs.onSurfaceVariant),
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            onRename();
                            break;
                          case 'auto_rename':
                            onAutoRename();
                            break;
                          case 'pin':
                            onPinToggle();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('重命名'),
                        ),
                        PopupMenuItem(
                          value: 'auto_rename',
                          child: Text('自动命名',
                              style: TextStyle(color: cs.onSurface)),
                        ),
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(topic.isPinned ? '取消置顶' : '置顶'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除',
                              style: TextStyle(color: cs.error)),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchBadge(ColorScheme cs) {
    final matchCount = _countMessageMatches(topic, searchQuery);
    if (matchCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$matchCount',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
