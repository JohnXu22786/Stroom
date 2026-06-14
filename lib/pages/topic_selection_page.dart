import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assistant.dart';
import '../pages/assistant_selection_page.dart';
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

/// Helper: format a DateTime to a readable string.
String _formatDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

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
        content: Text('确定要删除对话「${topic.title.isEmpty ? '新对话' : topic.title}」吗？'),
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

    ref.read(conversationsProvider.notifier)
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
      builder: (ctx) => _SearchPanel(
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
              size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            '暂无对话',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text('创建一个新对话开始对话',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withOpacity(0.7))),
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
                        tooltip: '编辑助手',
                        onPressed: () {
                          showAssistantFullEditDialog(
                              context, ref, selectedAssistant);
                        },
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
                          onReorder: (oldIndex, newIndex) {
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
                            final itemWidget = _TopicItem(
                              key: ValueKey('topic_${topic.id}'),
                              topic: topic,
                              selectionMode: _selectionMode,
                              isSelected: _selectedIds.contains(topic.id),
                              isActive: topic.id == ref.watch(activeConversationIdProvider),
                              onTap: () {
                                if (_selectionMode) {
                                  _toggleSelection(topic.id);
                                } else {
                                  _onTopicSelected(topic);
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

// ============================================================================
// Search Panel - Bottom Sheet for searching conversations
// ============================================================================

class _SearchPanel extends StatefulWidget {
  final List<Conversation> conversations;
  final void Function(Conversation) onConversationSelected;

  const _SearchPanel({
    required this.conversations,
    required this.onConversationSelected,
  });

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchByContent = false;
  String _query = '';

  List<Conversation> get _filteredConversations {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return [];

    final sorted = List<Conversation>.from(widget.conversations);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return sorted.where((c) {
      final displayTitle = c.title.isEmpty ? '新对话' : c.title;
      if (!_searchByContent) {
        // Search by title only
        return displayTitle.toLowerCase().contains(query);
      } else {
        // Search by title OR content
        if (displayTitle.toLowerCase().contains(query)) return true;
        return _countMessageMatches(c, query) > 0;
      }
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredConversations;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Text(
                      '搜索对话',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search text field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '输入关键词...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 12),

              // Toggle: search by title or content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('搜标题'),
                      selected: !_searchByContent,
                      onSelected: (_) => setState(() => _searchByContent = false),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('搜内容'),
                      selected: _searchByContent,
                      onSelected: (_) => setState(() => _searchByContent = true),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                    const Spacer(),
                    if (_query.isNotEmpty)
                      Text(
                        '${filtered.length} 个结果',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Results list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 40,
                                color: cs.onSurfaceVariant.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? '输入关键词开始搜索'
                                  : '没有找到匹配的对话',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final conv = filtered[index];
                          return _buildSearchResultCard(conv, cs);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultCard(Conversation conv, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = conv.title.isEmpty ? '新对话' : conv.title;
    final matchCount = _countMessageMatches(conv, _query);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cs.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onConversationSelected(conv),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  conv.isPinned
                      ? Icons.push_pin
                      : Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: conv.isPinned
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conv.isPinned)
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
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        // Show match count badge when searching by content
                        if (_searchByContent && matchCount > 0)
                          _buildMatchBadge(cs, matchCount),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatDate(conv.updatedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (conv.messages.length > 0) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.message_outlined,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            '${conv.messages.length}',
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
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchBadge(ColorScheme cs, int matchCount) {
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
}

// ============================================================================
// Conversation item widget - Card-based UI with conversations page features
// ============================================================================

class _TopicItem extends StatelessWidget {
  final Conversation topic;
  final bool selectionMode;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPinToggle;
  final VoidCallback onRename;
  final VoidCallback onAutoRename;
  final VoidCallback onSelectionToggle;

  const _TopicItem({
    super.key,
    required this.topic,
    required this.selectionMode,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
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
}
