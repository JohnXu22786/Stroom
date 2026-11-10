import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';

import '../pages/assistant_selection_page.dart';
import '../models/assistant.dart';
import '../providers/assistant_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_stream_provider.dart';
import '../providers/chat_manager_provider.dart';
import '../providers/provider_config.dart';
import '../services/assistant_catalog_service.dart';
import '../services/assistant_prompt_safety_review.dart';
import '../services/assistant_update_service.dart';
import '../services/assistant_tool_policy.dart';
import '../services/chat_adapter.dart' show resolveModelRef;
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
  bool _checkedRemoteAssistant = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSelectedAssistantForUpdate();
    });
  }

  Future<void> _checkSelectedAssistantForUpdate() async {
    if (_checkedRemoteAssistant || !mounted) return;
    _checkedRemoteAssistant = true;
    try {
      await ref.read(assistantInitialLoadProvider.future);
      if (!mounted) return;
      final assistant = ref.read(selectedAssistantProvider);
      if (assistant == null || assistant.remoteAssistantId == null) return;
      final update = await AssistantUpdateService.checkForUpdate(assistant);
      if (!mounted || update == null) return;
      if (assistant.remoteUpdatePolicy == 'automatic') {
        await _applyRemoteUpdate(assistant, update);
      } else {
        final isZh = Localizations.localeOf(context).languageCode == 'zh';
        final apply = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isZh ? '助手有更新' : 'Assistant update available'),
            content: Text(isZh
                ? '${assistant.name} 有新版本 ${update.definition.version}。现在查看并更新吗？'
                : '${assistant.name} has version ${update.definition.version}. Review and update now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(isZh ? '稍后' : 'Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isZh ? '更新' : 'Update'),
              ),
            ],
          ),
        );
        if (apply == true && mounted)
          await _applyRemoteUpdate(assistant, update);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.topicAssistantUpdateCheckFailed(
                error.toString(),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _applyRemoteUpdate(
    Assistant assistant,
    DownloadedRemoteAssistant update,
  ) async {
    final definition = update.definition;
    final requestedTools = definition.defaultToolNames;
    final supportedTools = supportedAssistantToolNames(
      ref.read(providerEntriesProvider),
    );
    if (requestedTools != null && !supportedTools.containsAll(requestedTools)) {
      throw FormatException('Update contains unsupported Stroom tool names.');
    }
    if (assistant.remoteSecurityReview) {
      final entries = ref.read(providerEntriesProvider);
      final review = await AssistantPromptSafetyReview.review(
        adapter: ref.read(chatStreamManagerProvider).adapter,
        entriesState: entries,
        assistantId: definition.id,
        prompt: definition.prompt,
        settings: definition.settings.toMap(),
      );
      if (!review.approved) {
        if (mounted) {
          final isZh = Localizations.localeOf(context).languageCode == 'zh';
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(isZh ? '安全审查未通过' : 'Safety review rejected update'),
              content: Text(review.reason),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(isZh ? '关闭' : 'Close'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    final entries = ref.read(providerEntriesProvider);
    final adapter = ref.read(chatStreamManagerProvider).adapter;
    final models = adapter.availableModels(entries);
    final remoteModel = resolveModelRef(
      models: models,
      modelId: definition.defaultModelId,
      providerName: definition.defaultProviderName,
      displayName: definition.defaultModelName,
    );
    final existingModel = resolveModelRef(
      models: models,
      modelId: assistant.defaultModelId,
      providerName: assistant.defaultProviderName,
      displayName: assistant.defaultModelName,
    );
    final replacement = Assistant(
      name: definition.name,
      description: definition.description,
      emoji: definition.emoji,
      prompt: definition.prompt,
      settings: definition.settings,
      defaultModelName: (remoteModel ?? existingModel)?.displayName,
      defaultModelId: (remoteModel ?? existingModel)?.modelId,
      defaultProviderName: (remoteModel ?? existingModel)?.providerName,
      defaultToolNames: requestedTools ?? assistant.defaultToolNames,
    );
    ref.read(assistantProvider.notifier).updateRemoteAssistant(
          localId: assistant.id,
          replacement: replacement,
          remoteVersion: definition.version,
          remoteFileUrl: update.fileUrl,
          remoteFormat: update.format,
          remoteSha256: update.sha256,
          remoteExtensions: definition.extensions,
        );
    if (mounted) {
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isZh ? '助手已更新' : 'Assistant updated')),
      );
    }
  }

  /// 置顶优先、块内保持原有顺序（稳定排序——Dart 的 List.sort 在元素
  /// 超过 33 个时使用不稳定快排，会任意重排等键元素，导致对话多时
  /// 顺序"自动乱掉"）。
  List<Conversation> _sortedConversations(List<Conversation> conversations) {
    return pinnedFirstStable(conversations);
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.conversationDeleteTitle),
        content: Text(l10n.conversationDeleteMany(_selectedIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.actionDelete),
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
        // 未发送的附件草稿文件一并清理（随对话删除，避免孤儿）
        for (final att in conv.draftAttachments) {
          try {
            await AttachmentStorage.deleteFile(att.storagePath);
          } catch (_) {
            // 非关键清理
          }
        }
      }
      // 图片压缩缓存按对话隔离存储：删除对话时整目录清理
      // （派生缓存，best-effort：失败不影响对话删除）
      try {
        await AttachmentStorage.deleteConversationCompressedImages(id);
      } catch (_) {
        // 非关键清理
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
    final l10n = AppLocalizations.of(context)!;
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == topic.id).firstOrNull;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.conversationDeleteTitle),
        content: Text(l10n.conversationDeleteNamed(
          topic.title.isEmpty ? l10n.conversationNew : topic.title,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.actionDelete),
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
      // 未发送的附件草稿文件一并清理（随对话删除，避免孤儿）
      for (final att in conv.draftAttachments) {
        try {
          await AttachmentStorage.deleteFile(att.storagePath);
        } catch (_) {
          // 非关键清理
        }
      }
    }
    // 图片压缩缓存按对话隔离存储：删除对话时整目录清理
    // （派生缓存，best-effort：失败不影响对话删除）
    try {
      await AttachmentStorage.deleteConversationCompressedImages(topic.id);
    } catch (_) {
      // 非关键清理
    }

    await ref.read(conversationsProvider.notifier).deleteConversation(topic.id);
  }

  void _renameTopic(String id, String currentTitle) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.conversationRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.conversationRenameHint,
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
            child: Text(l10n.actionCancel),
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
            child: Text(l10n.actionConfirm),
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            l10n.topicSelectionEmptyTitle,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(l10n.topicSelectionEmptyMessage,
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedAssistant = ref.watch(selectedAssistantProvider);
    final conversations = ref.watch(conversationsProvider);
    final isLoading = ref.watch(conversationsInitialLoadProvider).isLoading;
    final streamingConversations = ref.watch(streamingConversationsProvider);
    final activeConversationId = ref.watch(activeConversationIdProvider);
    final cs = Theme.of(context).colorScheme;

    final assistantTopics = _getAssistantTopics(conversations);
    final sorted = _sortedConversations(assistantTopics);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_selectionMode
            ? l10n.conversationSelected(_selectedIds.length)
            : l10n.conversationSelectTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
        actions: [
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.conversationSearch,
              onPressed: _showSearchPanel,
            ),
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: l10n.conversationDeleteSelected,
              onPressed: _selectedIds.isNotEmpty ? _batchDelete : null,
            ),
          IconButton(
            icon: Icon(
              _selectionMode ? Icons.close : Icons.checklist,
            ),
            tooltip: _selectionMode ? l10n.actionUnselect : l10n.actionSelect,
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
                  Text(l10n.topicSelectionNoAssistant,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.read(selectedAssistantIdProvider.notifier).state =
                          null;
                      Navigator.pop(context);
                    },
                    child: Text(l10n.topicSelectionBackToAssistants),
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
                    borderRadius: BorderRadius.circular(16),
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
                        tooltip: l10n.topicSelectionEditAssistant,
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
                  child: Text(
                    l10n.topicSelectionReorderHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),

                // Conversation list
                Expanded(
                  child: isLoading
                      ? TickerMode(
                          enabled: TickerMode.of(context) &&
                              ChatTabVisibility.of(context),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : sorted.isEmpty
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
                                // onReorderItem 的 newIndex 已是移除后的索引
                                // （框架会先移除 oldIndex 再计算插入位置），
                                // 不需要再手动减一。
                                final target = sorted[newIndex];
                                final realNew =
                                    convs.indexWhere((c) => c.id == target.id);
                                if (realOld >= 0 && realNew >= 0) {
                                  ref
                                      .read(conversationsProvider.notifier)
                                      .reorderConversation(realOld, realNew);
                                }
                              },
                              proxyDecorator: (child, index, animation) =>
                                  Material(
                                elevation: 2,
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                child: child,
                              ),
                              itemBuilder: (context, index) {
                                final topic = sorted[index];
                                final isRunning =
                                    streamingConversations.contains(topic.id);
                                final latestMessage = topic.messages.isEmpty
                                    ? null
                                    : topic.messages.last;
                                final isFailed = !isRunning &&
                                    latestMessage?.role == 'assistant' &&
                                    latestMessage?.isError == true;
                                final itemWidget = TopicItem(
                                  key: ValueKey('topic_${topic.id}'),
                                  topic: topic,
                                  selectionMode: _selectionMode,
                                  isSelected: _selectedIds.contains(topic.id),
                                  isActive: topic.id == activeConversationId,
                                  isRunning: isRunning,
                                  isFailed: isFailed,
                                  isUnread: !isRunning &&
                                      !isFailed &&
                                      topic.id != activeConversationId &&
                                      latestMessage?.role == 'assistant' &&
                                      latestMessage?.isStreaming == false &&
                                      latestMessage?.isError == false &&
                                      latestMessage?.id !=
                                          topic.lastReadMessageId,
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
                          label: Text(l10n.topicSelectionNewTopic),
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
