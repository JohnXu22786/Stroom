import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/message_bubble.dart';

/// Claude-style chat page.
///
/// Layout:
/// ┌─────────────────────────────┐
/// │        ChatHeader            │  ← 对话标题 + 操作
/// ├─────────────────────────────┤
/// │                             │
/// │    MessageBubble (user)     │
/// │    MessageBubble (assistant)│
/// │    ...                      │  ← ListView, 自动滚底, 细滚动条
/// │                             │
/// ├─────────────────────────────┤
/// │       ChatInputBar          │  ← 输入 + 发送
/// └─────────────────────────────┘
///
/// Empty state mimics Claude: heading ("你好！"), subtitle, suggestion chips.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ScrollController _scrollController = ScrollController();

  static const List<String> _suggestions = [
    '写一首诗',
    '解释量子计算',
    '帮我调试代码',
    '写一个故事',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 自动滚到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 发送消息
  void _sendMessage(String text) {
    final chatNotifier = ref.read(chatProvider.notifier);
    final convId = ref.read(activeConversationIdProvider);

    // 如果没有对话，先创建一个
    if (convId == null) {
      ref.read(conversationsProvider.notifier).createConversation();
    }

    chatNotifier.sendMessage(text);
  }

  /// 重试最后一条
  void _retryLast() {
    ref.read(chatProvider.notifier).retryLast();
    _scrollToBottom();
  }

  /// 复制消息内容
  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 新建对话
  void _newConversation() {
    ref.read(chatProvider.notifier).clearMessages();
    ref.read(conversationsProvider.notifier).createConversation();
  }

  /// 获取当前对话标题
  String _getTitle(
    List<Conversation> conversations,
    String? activeId,
  ) {
    if (activeId == null) return '新对话';
    final conv = conversations.where((c) => c.id == activeId).firstOrNull;
    if (conv == null) return '新对话';
    if (conv.title.isEmpty) return '新对话';
    return conv.title;
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final conversations = ref.watch(conversationsProvider);
    final activeId = ref.watch(activeConversationIdProvider);
    final title = _getTitle(conversations, activeId);

    // 仅在用户消息添加或流式完成时持久化
    ref.listen(chatProvider, (List<ChatMessage>? prev, List<ChatMessage> next) {
      final currentId = ref.read(activeConversationIdProvider);
      if (currentId == null) return;

      // 空状态变更时持久化
      if (next.isEmpty) {
        ref
            .read(conversationsProvider.notifier)
            .updateMessages(currentId, next);
        return;
      }

      final last = next.last;
      final wasStreaming =
          prev != null && prev.isNotEmpty && prev.last.isStreaming;
      final nowStreaming = last.isStreaming;

      // 仅在用户发送消息或流式完成时持久化
      if (last.role == 'user' || (wasStreaming && !nowStreaming)) {
        ref
            .read(conversationsProvider.notifier)
            .updateMessages(currentId, next);
      }
    });

    // 监听对话切换，加载对应消息
    // 仅在 chatProvider 为空时才加载（避免新建对话时覆盖刚发送的消息）
    ref.listen<String?>(activeConversationIdProvider,
        (String? prev, String? next) {
      if (next != null && next != prev) {
        final currentMessages = ref.read(chatProvider);
        if (currentMessages.isNotEmpty) return;
        final convs = ref.read(conversationsProvider);
        final conv = convs.where((c) => c.id == next).firstOrNull;
        if (conv != null) {
          ref.read(chatProvider.notifier).loadMessages(conv.messages);
        }
      }
    });

    final isStreaming =
        messages.any((m) => m.role == 'assistant' && m.isStreaming);

    return SafeArea(
      child: Container(
        // Page body background: one level below cs.surface → subtle layering
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            // ── 顶部标题栏 ──
            ChatHeader(
              title: title,
              onMenuTap: null,
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '新对话',
                    onPressed: _newConversation,
                  ),
                ],
              ),
            ),

            // ── 消息列表 ──
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState(context)
                  : _buildMessageList(messages),
            ),

            // ── 底部输入栏 ──
            ChatInputBar(
              onSend: _sendMessage,
              isLoading: isStreaming,
            ),
          ],
        ),
      ),
    );
  }

  /// Claude-inspired empty state: heading + subtitle + suggestion chips.
  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '你好！',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '有什么我可以帮助你的吗？',
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _suggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: () => _sendMessage(suggestion),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 消息列表 — thin scrollbar + increased padding.
  Widget _buildMessageList(List<ChatMessage> messages) {
    // 监听消息变化自动滚底
    ref.listen(chatProvider, (_, next) {
      if (next.isNotEmpty) _scrollToBottom();
    });

    return RawScrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(2),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          top: 16,
          bottom: 16,
          left: 12,
          right: 12,
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          final isLastAssistant =
              msg.role == 'assistant' && index == messages.length - 1;
          return MessageBubble(
            message: msg,
            onCopy:
                msg.content.isNotEmpty ? () => _copyMessage(msg.content) : null,
            onRetry: isLastAssistant && !msg.isStreaming ? _retryLast : null,
          );
        },
      ),
    );
  }
}
