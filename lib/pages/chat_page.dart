import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';

import '../models/chat_message.dart';
import '../services/chat_adapter.dart';
import '../providers/conversation_provider.dart';
import '../providers/provider_config.dart';
import 'provider_config_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  InMemoryChatController? _controller;
  late final User _currentUser;
  late final User _aiUser;
  late final ChatAdapter _adapter;
  final List<ChatMessage> _history = [];
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _currentUser = User(id: 'user1', name: 'You');
    _aiUser = User(id: 'ai1', name: 'Stroom');
    _adapter = ChatAdapter();
    _controller = InMemoryChatController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _saveMessages();
    _controller?.dispose();
    _adapter.dispose();
    super.dispose();
  }

  void _initialize() {
    _configureAdapter();
    _loadConversationMessages();
  }

  void _configureAdapter() {
    final entriesState = ref.read(providerEntriesProvider);
    _adapter.configure(entriesState);
    if (mounted) setState(() {});
  }

  Future<void> _loadConversationMessages() async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == activeId).firstOrNull;
    if (conv == null || conv.messages.isEmpty) return;

    _history.clear();
    for (final msg in conv.messages) {
      _history.add(msg);
      await _controller?.insertMessage(Message.text(
        id: msg.id,
        authorId: msg.role == 'user' ? _currentUser.id : _aiUser.id,
        text: msg.content,
        createdAt: msg.createdAt,
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveMessages() async {
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;
    await ref
        .read(conversationsProvider.notifier)
        .updateMessages(convId, [..._history]);
  }

  void _navigateToProviderConfig() {
    final entriesState = ref.read(providerEntriesProvider);
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderConfigPage(entryId: llmEntry.id),
        ),
      ).then((_) {
        if (mounted) _configureAdapter();
      });
    }
  }

  void _newConversation() {
    _saveMessages().then((_) {
      ref.read(conversationsProvider.notifier).createConversation();
      _history.clear();
      final newCtrl = InMemoryChatController();
      setState(() => _controller = newCtrl);
    });
  }

  void _showHistory() {
    final conversations = ref.read(conversationsProvider);
    final activeId = ref.read(activeConversationIdProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _buildHistoryPanel(conversations, activeId);
      },
    );
  }

  Future<void> _onMessageSend(String text) async {
    if (_isStreaming) return;
    _isStreaming = true;

    // Ensure a conversation exists
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) {
      ref.read(conversationsProvider.notifier).createConversation();
    }

    final userMsgId = 'u${DateTime.now().millisecondsSinceEpoch}';
    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';

    _history.add(ChatMessage(role: 'user', content: text, id: userMsgId));
    await _controller?.insertMessage(Message.text(
      id: userMsgId,
      authorId: _currentUser.id,
      text: text,
      createdAt: DateTime.now(),
    ));

    final placeholder = Message.textStream(
      id: aiMsgId,
      authorId: _aiUser.id,
      createdAt: DateTime.now(),
      streamId: aiMsgId,
    );
    await _controller?.insertMessage(placeholder);

    String fullReply = '';
    try {
      await for (final chunk in _adapter.sendStream(text, history: _history)) {
        fullReply += chunk;
        await _controller?.updateMessage(
          placeholder,
          Message.text(
            id: aiMsgId,
            authorId: _aiUser.id,
            text: fullReply,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      fullReply = '错误: $e';
      await _controller?.updateMessage(
        placeholder,
        Message.text(
          id: aiMsgId,
          authorId: _aiUser.id,
          text: fullReply,
          createdAt: DateTime.now(),
        ),
      );
    }

    _history
        .add(ChatMessage(role: 'assistant', content: fullReply, id: aiMsgId));
    _isStreaming = false;

    _saveMessages();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markdownConfig =
        isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    final adapterConfigured = _adapter.isConfigured;
    final controller = _controller;

    // Get conversation title
    final activeId = ref.watch(activeConversationIdProvider);
    final conversations = ref.watch(conversationsProvider);
    String title = '新对话';
    if (activeId != null) {
      final conv = conversations.where((c) => c.id == activeId).firstOrNull;
      if (conv != null && conv.title.isNotEmpty) title = conv.title;
    }

    return SafeArea(
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            // ── Top bar ──
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: '历史记录',
                    onPressed: _showHistory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新对话',
                    onPressed: _newConversation,
                  ),
                ],
              ),
            ),

            // ── Unconfigured banner ──
            if (!adapterConfigured)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withOpacity(0.3),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ 未配置聊天API — 前往设置',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToProviderConfig,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '设置',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Chat widget ──
            Expanded(
              child: controller == null
                  ? const SizedBox.shrink()
                  : Chat(
                      key: ValueKey(controller.hashCode),
                      currentUserId: _currentUser.id,
                      resolveUser: (id) async {
                        if (id == _currentUser.id) return _currentUser;
                        if (id == _aiUser.id) return _aiUser;
                        return null;
                      },
                      chatController: controller,
                      onMessageSend: _onMessageSend,
                      theme: isDark ? ChatTheme.dark() : ChatTheme.light(),
                      builders: Builders(
                        textMessageBuilder: (context, message, index,
                            {required bool isSentByMe,
                            MessageGroupStatus? groupStatus}) {
                          final isAi = message.authorId == _aiUser.id;

                          if (isAi) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[850]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: MarkdownWidget(
                                data: message.text,
                                selectable: true,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                config: markdownConfig.copy(configs: [
                                  PreConfig(theme: draculaTheme),
                                ]),
                              ),
                            );
                          }

                          return SimpleTextMessage(
                              message: message, index: index);
                        },
                        textStreamMessageBuilder: (context, message, index,
                            {required bool isSentByMe,
                            MessageGroupStatus? groupStatus}) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── History panel ──
  Widget _buildHistoryPanel(
      List<Conversation> conversations, String? activeId) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '历史记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${conversations.length} 个对话',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Text(
                        '暂无历史记录',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant.withOpacity(0.5)),
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final isActive = conv.id == activeId;
                        return _buildConversationItem(conv, isActive);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConversationItem(Conversation conv, bool isActive) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      selected: isActive,
      selectedTileColor: cs.primaryContainer.withOpacity(0.3),
      leading: Icon(
        isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
        color: isActive ? cs.primary : cs.onSurfaceVariant,
        size: 20,
      ),
      title: Text(
        conv.title.isEmpty ? '新对话' : conv.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: cs.onSurface,
        ),
      ),
      subtitle: Text(
        _formatDate(conv.updatedAt),
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            size: 18, color: cs.error.withOpacity(0.7)),
        tooltip: '删除',
        onPressed: () => _deleteConversation(conv.id),
      ),
      onTap: () {
        if (!isActive) {
          _saveMessages().then((_) {
            ref
                .read(conversationsProvider.notifier)
                .selectConversation(conv.id);
            _history.clear();
            final newCtrl = InMemoryChatController();
            setState(() => _controller = newCtrl);
            // Use post-frame callback to load messages after rebuild
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _loadConversationMessages());
          });
        }
        Navigator.of(context).pop();
      },
    );
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

  void _deleteConversation(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这个对话吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final wasActive = ref.read(activeConversationIdProvider) == id;
              ref.read(conversationsProvider.notifier).deleteConversation(id);
              if (wasActive) {
                _history.clear();
                final newCtrl = InMemoryChatController();
                setState(() => _controller = newCtrl);
              }
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
