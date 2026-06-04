import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_provider.dart';
import '../services/attachment_storage.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});

  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  bool _showSearch = false;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.month}/${date.day}';
  }

  List<Conversation> _sortedConversations(List<Conversation> conversations) {
    final sorted = List<Conversation>.from(conversations);
    sorted.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  List<Conversation> _filteredConversations(List<Conversation> conversations) {
    final query = _searchController.text.trim().toLowerCase();
    var result = _sortedConversations(conversations);
    if (query.isNotEmpty) {
      result = result
          .where((c) {
            final displayTitle = c.title.isEmpty ? '新对话' : c.title;
            return displayTitle.toLowerCase().contains(query);
          })
          .toList();
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

  void _deleteConversation(String id) async {
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == id).firstOrNull;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？此操作无法撤销。'),
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

    if (conv != null) {
      for (final msg in conv.messages) {
        for (final att in msg.attachments) {
          await AttachmentStorage.deleteFile(att.storagePath);
        }
      }
    }

    await ref.read(conversationsProvider.notifier).deleteConversation(id);
  }

  void _renameConversation(String id, String currentTitle) {
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

  void _navigateToConversation(Conversation conv, String? activeId) {
    if (conv.id != activeId) {
      ref
          .read(conversationsProvider.notifier)
          .selectConversation(conv.id);
    }
    Navigator.of(context).pop();
  }

  Widget _buildEmptyState(ColorScheme cs) {
    final query = _searchController.text.trim();
    return Center(
      child: Text(
        query.isNotEmpty ? '没有找到匹配的对话' : '暂无历史记录',
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final conversations = ref.watch(conversationsProvider);
    final activeId = ref.watch(activeConversationIdProvider);
    final filtered = _filteredConversations(conversations);

    return Scaffold(
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
                  hintText: '搜索对话...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                ),
                onChanged: (_) => setState(() {}),
              ),
            )
          : AppBar(
              title: Text(
                _selectionMode ? '已选 ${_selectedIds.length} 个' : '对话历史',
              ),
              actions: [
                if (!_selectionMode)
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: '搜索',
                    onPressed: () => setState(() => _showSearch = true),
                  ),
                if (!_selectionMode)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新对话',
                    onPressed: () {
                      ref
                          .read(conversationsProvider.notifier)
                          .createConversation();
                      Navigator.of(context).pop();
                    },
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
      body: filtered.isEmpty
          ? _buildEmptyState(cs)
          : _searchController.text.trim().isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    final isActive = conv.id == activeId;
                    return _buildConversationItem(
                        conv, isActive, cs, index, activeId);
                  },
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    final convs = ref.read(conversationsProvider);
                    final item = filtered[oldIndex];
                    final realOld =
                        convs.indexWhere((c) => c.id == item.id);
                    if (newIndex >= filtered.length) {
                      newIndex = filtered.length - 1;
                    }
                    final target = filtered[newIndex];
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
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
              itemBuilder: (context, index) {
                final conv = filtered[index];
                final isActive = conv.id == activeId;
                return _buildConversationItem(
                    conv, isActive, cs, index, activeId);
              },
            ),
      floatingActionButton: _selectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _batchDelete,
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              icon: const Icon(Icons.delete),
              label: Text('删除 ${_selectedIds.length} 个'),
            )
          : null,
    );
  }

  Widget _buildConversationItem(
      Conversation conv, bool isActive, ColorScheme cs, int index, String? activeId) {
    return ListTile(
        key: ValueKey('tile_${conv.id}'),
        selected: isActive,
        selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
        leading: _selectionMode
            ? Checkbox(
                value: _selectedIds.contains(conv.id),
                onChanged: (_) => _toggleSelection(conv.id),
              )
            : ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: cs.onSurfaceVariant,
                ),
              ),
        title: Row(
          children: [
            if (conv.isPinned)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.push_pin,
                    size: 14, color: cs.primary),
              ),
            Expanded(
              child: Text(
                conv.title.isEmpty ? '新对话' : conv.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          _formatDate(conv.updatedAt),
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: _selectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      conv.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 18,
                      color: conv.isPinned
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    tooltip: conv.isPinned ? '取消置顶' : '置顶',
                    onPressed: () {
                      ref
                          .read(conversationsProvider.notifier)
                          .togglePin(conv.id);
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: cs.onSurfaceVariant),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _renameConversation(
                              conv.id, conv.title);
                          break;
                        case 'auto_rename':
                          ref
                              .read(conversationsProvider.notifier)
                              .autoRenameConversation(conv.id);
                          break;
                        case 'pin':
                          ref
                              .read(conversationsProvider.notifier)
                              .togglePin(conv.id);
                          break;
                        case 'delete':
                          _deleteConversation(conv.id);
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
                        child: Text(
                            '自动命名',
                            style: TextStyle(
                                color: cs.onSurface)),
                      ),
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(conv.isPinned
                            ? '取消置顶'
                            : '置顶'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('删除',
                            style:
                                TextStyle(color: cs.error)),
                      ),
                    ],
                  ),
                ],
              ),
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(conv.id);
          } else {
            _navigateToConversation(conv, activeId);
          }
        },
        onLongPress: () {
          if (!_selectionMode) {
            _toggleSelectionMode();
            _selectedIds.add(conv.id);
          }
        },
      );
  }
}