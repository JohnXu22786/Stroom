import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/chat_provider.dart';

import '../services/chat_service.dart' show ChatService;
import '../providers/conversation_provider.dart';
import 'chat_provider_config_page.dart';
import '../widgets/chat/avatar_widget.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/markdown_renderer.dart';
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
/// │  StreamingAssistantBubble   │  ← 仅流式推送时显示, 独立重建
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
  bool _userScrolledAway = false;

  static const List<String> _suggestions = [
    '写一首诗',
    '解释量子计算',
    '帮我调试代码',
    '写一个故事',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // Allow 50px threshold for "near bottom"
    if (currentScroll >= maxScroll - 50) {
      _userScrolledAway = false;
    } else {
      _userScrolledAway = true;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 自动滚到底部 — streaming 中使用 jumpTo, 完成时使用 animateTo
  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (instant) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
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
    _scrollToBottom(instant: true);
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
    // 先创建对话（设置新 activeId），再清空消息，
    // 避免 persistence listener 以旧 ID 保存空列表。
    ref.read(conversationsProvider.notifier).createConversation();
    ref.read(chatProvider.notifier).clearMessages();
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
    // ── 细粒度的 select 监听, 避免整个页面因流式推送而重建 ──
    final messages = ref.watch(chatProvider.select((s) => s.messages));
    final isResponding =
        ref.watch(chatProvider.select((s) => s.isAssistantResponding));
    final conversations = ref.watch(conversationsProvider);
    final activeId = ref.watch(activeConversationIdProvider);
    final title = _getTitle(conversations, activeId);

    // Build subtitle from selected config
    String modelSubtitle = '';
    final configs = ref.watch(chatConfigsProvider);
    final selectedConfigId = ref.watch(selectedChatConfigIdProvider);
    if (selectedConfigId != null) {
      final config = configs.where((c) => c.id == selectedConfigId).firstOrNull;
      if (config != null) {
        final modelName = config.selectedModelId.isNotEmpty
            ? config.selectedModelId
            : (config.models.isNotEmpty ? config.models.first.modelId : '未选择');
        modelSubtitle = 'Model: $modelName';
      }
    }

    // ── 仅在用户消息添加或流式完成时持久化 ──
    ref.listen(chatProvider.select((s) => s.messages),
        (List<ChatMessage>? prev, List<ChatMessage> next) {
      final currentId = ref.read(activeConversationIdProvider);
      if (currentId == null) return;

      // 空状态变更时持久化
      if (next.isEmpty) {
        ref
            .read(conversationsProvider.notifier)
            .updateMessages(currentId, next);
        return;
      }

      // 消息列表增长时持久化（用户发送消息 | 流式完成，新增 assistant 消息）
      // 注意：新架构中 isStreaming 只在 ChatState 层面跟踪，
      // messages 中的消息 isStreaming 始终为 false。
      if (prev != null && next.length > prev.length) {
        ref
            .read(conversationsProvider.notifier)
            .updateMessages(currentId, next);
      }
    });

    // ── 监听对话切换，加载对应消息 ──
    // 仅在 messages 为空时才加载（避免新建对话时覆盖刚发送的消息）
    ref.listen<String?>(activeConversationIdProvider,
        (String? prev, String? next) {
      if (next != null && next != prev) {
        final currentMessages = ref.read(chatProvider).messages;
        if (currentMessages.isNotEmpty) return;
        final convs = ref.read(conversationsProvider);
        final conv = convs.where((c) => c.id == next).firstOrNull;
        if (conv != null) {
          ref.read(chatProvider.notifier).loadMessages(conv.messages);
        }
      }
    });

    // ── 流式结束: 平滑滚底 ──
    ref.listen(chatProvider.select((s) => s.isAssistantResponding),
        (bool? prev, bool next) {
      if (prev == true && next == false) {
        _userScrolledAway = false;
        _scrollToBottom(instant: false);
      }
    });

    // ── 流式内容变化: 用户未离开底部时立即跳转 ──
    ref.listen(chatProvider.select((s) => s.streamingAssistantContent),
        (String? prev, String next) {
      if (next.isNotEmpty && !_userScrolledAway) {
        _scrollToBottom(instant: true);
      }
    });

    // ── Wire up ChatService when config changes ──
    final chatService = ref.watch(chatServiceProvider);

    ref.listen<ChatService?>(chatServiceProvider, (prev, next) {
      ref.read(chatProvider.notifier).setChatService(next);
    });

    return SafeArea(
      child: Container(
        // Page body background: one level below cs.surface → subtle layering
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            // ── 顶部标题栏 ──
            ChatHeader(
              title: title,
              subtitle: modelSubtitle.isNotEmpty ? modelSubtitle : null,
              onMenuTap: null,
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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

            // ── 未配置聊天API提示 ──
            if (chatService == null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.3),
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatProviderConfigPage(),
                          ),
                        );
                      },
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

            // ── 消息列表（流式消息在 ListView 内作为最后一条）──
            Expanded(
              child: messages.isEmpty && !isResponding
                  ? _buildEmptyState(context, chatService: chatService)
                  : _buildMessageList(messages, isResponding: isResponding),
            ),

            // ── 底部输入栏 ──
            ChatInputBar(
              onSend: _sendMessage,
              isLoading: isResponding,
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // History panel
  // ========================================================================

  /// Shows the conversation history panel as a modal bottom sheet.
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
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
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
            // List
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
                          color: cs.outlineVariant.withValues(alpha: 0.5)),
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
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
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
            size: 18, color: cs.error.withValues(alpha: 0.7)),
        tooltip: '删除',
        onPressed: () => _deleteConversation(conv.id),
      ),
      onTap: () {
        if (!isActive) {
          // 先切换 activeId，再加载目标对话的消息。
          // 顺序很重要：先切换 ID 可避免 persistence listener 以旧 ID 保存。
          ref.read(conversationsProvider.notifier).selectConversation(conv.id);
          ref.read(chatProvider.notifier).loadMessages(conv.messages);
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
                ref.read(chatProvider.notifier).clearMessages();
              }
              Navigator.of(context).pop(); // close dialog
            },
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ========================================================================

  /// Claude-inspired empty state: heading + subtitle + suggestion chips.
  Widget _buildEmptyState(BuildContext context, {ChatService? chatService}) {
    final cs = Theme.of(context).colorScheme;
    final hasService = chatService != null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasService) ...[
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
            ] else ...[
              Icon(Icons.chat_bubble_outline,
                  size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                '请先在设置中配置聊天供应商',
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '没有可用的聊天服务，请添加API配置',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatProviderConfigPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('前往设置'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 消息列表 — thin scrollbar + increased padding.
  ///
  /// [isResponding] 为 true 时在 ListView 末尾附加一个流式消息气泡。
  /// 该气泡使用 [Consumer] 独立监听 [streamingAssistantContent]，
  /// 避免列表因流式刷新而整体重建。
  Widget _buildMessageList(
    List<ChatMessage> messages, {
    required bool isResponding,
  }) {
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
        itemCount: messages.length + (isResponding ? 1 : 0),
        itemBuilder: (context, index) {
          // 流式消息气泡 — Consumer 独立监听, 不触发列表重建
          if (isResponding && index == messages.length) {
            return Consumer(builder: (context, ref, _) {
              final content = ref.watch(
                  chatProvider.select((s) => s.streamingAssistantContent));
              return _buildStreamingBubble(content);
            });
          }

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

  /// 流式推送气泡 — 类似 AI 消息气泡, 无 hover 操作, 始终显示输入指示器
  Widget _buildStreamingBubble(String content) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AvatarWidget(name: 'S', size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stroom',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                // 增量 markdown 渲染（内容为空时隐藏渲染器）
                if (content.isNotEmpty)
                  DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      color: cs.onSurface,
                      height: 1.7,
                    ),
                    child: MarkdownRenderer(
                      data: content,
                      selectable: true,
                    ),
                  ),
                const SizedBox(height: 6),
                // 始终显示输入指示器（代替 hover 操作按钮）
                const _StreamingTypingIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 三跳点弹跳输入指示器
class _StreamingTypingIndicator extends StatefulWidget {
  const _StreamingTypingIndicator();

  @override
  State<_StreamingTypingIndicator> createState() =>
      _StreamingTypingIndicatorState();
}

class _StreamingTypingIndicatorState extends State<_StreamingTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 1/3 of the animation cycle
            final t = (_controller.value + i / 3) % 1.0;
            // Triangle wave: bounce scale from 0.4 → 1.0 → 0.4
            final scale = 0.4 + 0.6 * (t < 0.5 ? t * 2 : (1.0 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
