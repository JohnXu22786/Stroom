import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../services/attachment_storage.dart';
import '../widgets/file_preview.dart';

import '../models/chat_message.dart';
import '../services/chat_adapter.dart';
import '../providers/conversation_provider.dart';
import '../providers/provider_config.dart';
import 'provider_config_page.dart';

final _isStreamingProvider = StateProvider<bool>((ref) => false);

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
  int _selectedModelIndex = 0;
  bool _cancelledByUser = false;
  String _lastUserMessage = '';
  List<Attachment> _lastAttachments = [];

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
    _controller?.dispose();
    _adapter.dispose();
    super.dispose();
  }

  void _initialize() {
    _configureAdapter();
    // Restore saved model selection
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt('selected_model_index');
      if (saved != null) {
        final entriesState = ref.read(providerEntriesProvider);
        final models = _adapter.availableModels(entriesState);
        if (saved >= 0 && saved < models.length) {
          final model = models[saved];
          _adapter.selectModel(
              entriesState, model.configIndex, model.modelIndex);
          setState(() => _selectedModelIndex = saved);
        }
      }
    });
    _loadConversationMessages();
  }

  void _configureAdapter() {
    final entriesState = ref.read(providerEntriesProvider);
    _adapter.configure(entriesState);
    // Sync selected model index with adapter state
    final models = _adapter.availableModels(entriesState);
    final idx = models.indexWhere(
      (m) =>
          m.configIndex == _adapter.currentConfigIndex &&
          m.modelIndex == _adapter.currentModelIndex,
    );
    _selectedModelIndex = idx >= 0 ? idx : 0;
    if (mounted) setState(() {});
  }

  Future<void> _loadConversationMessages() async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == activeId).firstOrNull;
    if (conv == null || conv.messages.isEmpty) return;

    _history.clear();
    _controller?.dispose();
    final newCtrl = InMemoryChatController();
    _controller = newCtrl;
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
    try {
      final convId = ref.read(activeConversationIdProvider);
      if (convId == null) return;
      await ref
          .read(conversationsProvider.notifier)
          .updateMessages(convId, [..._history]);
    } catch (e) {
      debugPrint('_saveMessages failed: $e');
    }
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
    if (ref.read(_isStreamingProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请等待当前消息生成完成')),
        );
      }
      return;
    }
    _saveMessages().then((_) {
      ref.read(conversationsProvider.notifier).createConversation();
      _history.clear();
      _controller?.dispose();
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

  Future<void> _onMessageSend(String text, List<Attachment> attachments) async {
    _lastUserMessage = text;
    _lastAttachments = List.from(attachments);
    if (ref.read(_isStreamingProvider)) return;
    ref.read(_isStreamingProvider.notifier).state = true;
    if (mounted) setState(() {});
    _cancelledByUser = false;

    // Ensure a conversation exists
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) {
      ref.read(conversationsProvider.notifier).createConversation();
    }

    final userMsgId = 'u${DateTime.now().millisecondsSinceEpoch}';
    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';

    _history.add(ChatMessage(role: 'user', content: text, id: userMsgId, attachments: attachments));
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
    DateTime lastUpdate = DateTime.now();
    const minInterval = Duration(milliseconds: 50);

    void updateMessage(String content) {
      _controller?.updateMessage(
        placeholder,
        Message.text(
          id: aiMsgId,
          authorId: _aiUser.id,
          text: content,
          createdAt: DateTime.now(),
        ),
      );
    }

    try {
      final stream = _adapter.sendStream(text, history: _history);
      await for (final chunk in stream) {
        if (_cancelledByUser) break;
        fullReply += chunk;
        final now = DateTime.now();
        if (now.difference(lastUpdate) >= minInterval) {
          lastUpdate = now;
          updateMessage(fullReply);
        }
      }
    } catch (e) {
      if (!_cancelledByUser) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败: $e')),
          );
        }
        fullReply = '';
      }
    } finally {
      updateMessage(fullReply);
    }

    if (fullReply.isNotEmpty) {
      _history.add(
          ChatMessage(role: 'assistant', content: fullReply, id: aiMsgId));
    }
    ref.read(_isStreamingProvider.notifier).state = false;
    _cancelledByUser = false;
    if (mounted) setState(() {});

    await _saveMessages();
  }

  Future<void> _deleteMessage(String messageId) async {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final msg = _history[index];

    for (final att in msg.attachments) {
      final isReferencedElsewhere = _history.asMap().entries.any(
        (entry) => entry.key != index && entry.value.attachments.any(
          (a) => a.storagePath == att.storagePath,
        ),
      );
      if (!isReferencedElsewhere) {
        await AttachmentStorage.deleteFile(att.storagePath);
      }
    }

    setState(() {
      _history.removeAt(index);
    });

    final msgToRemove = _controller?.messages.where((m) => m.id == messageId).firstOrNull;
    if (msgToRemove != null) {
      await _controller?.removeMessage(msgToRemove);
    }

    _saveMessages();
  }

  void _confirmDeleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(messageId);
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

  Widget _buildMessageAttachmentPreview(Attachment att) {
    final isImage = att.fileType == 'image';
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      margin: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImage
                ? FutureBuilder<Uint8List?>(
                    future: AttachmentStorage.readFile(att.storagePath),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.done &&
                          snap.hasData &&
                          snap.data != null) {
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      }
                      return Icon(Icons.image_outlined, size: 18,
                          color: cs.onSurfaceVariant);
                    },
                  )
                : Icon(Icons.insert_drive_file_outlined, size: 18,
                    color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 1),
          Text(
            att.fileName.length > 8
                ? '${att.fileName.substring(0, 7)}…'
                : att.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _stopStreaming() {
    _cancelledByUser = true;
    _adapter.cancel();
    ref.read(_isStreamingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markdownConfig =
        isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    final adapterConfigured = _adapter.isConfigured;
    final controller = _controller;
    final isStreaming = ref.watch(_isStreamingProvider);

    // Reactively load messages when the active conversation changes
    ref.listen(activeConversationIdProvider, (prev, next) {
      if (next != null && next != prev) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadConversationMessages();
        });
      }
    });

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
                  // ── Model selector ──
                  if (adapterConfigured) _buildModelSelector(),
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
                  // ── Stop button ──
                  if (isStreaming)
                    IconButton(
                      icon: Icon(Icons.stop_circle_outlined,
                          color: Colors.red[400]),
                      tooltip: '停止生成',
                      onPressed: _stopStreaming,
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
                      onMessageSend: (text) => _onMessageSend(text, []),
                      theme: isDark ? ChatTheme.dark() : ChatTheme.light(),
                      builders: Builders(
                        composerBuilder: (context) => _ChatComposer(
                          onSend: _onMessageSend,
                          onStop: _stopStreaming,
                        ),
                        textMessageBuilder: (context, message, index,
                            {required bool isSentByMe,
                            MessageGroupStatus? groupStatus}) {
                          final isAi = message.authorId == _aiUser.id;

                          if (isAi) {
                            if (message.text.startsWith('错误:')) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? Colors.grey[850]
                                          : Colors.grey[100])!
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      message.text,
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _onMessageSend(_lastUserMessage, List.from(_lastAttachments)),
                                      icon: Icon(Icons.refresh, size: 16),
                                      label: const Text('重试',
                                          style: TextStyle(fontSize: 13)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red[700],
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Stack(
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 2),
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    config: markdownConfig.copy(configs: [
                                      PreConfig(theme: draculaTheme),
                                    ]),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.copy, size: 16),
                                        tooltip: '复制',
                                        style: IconButton.styleFrom(
                                          foregroundColor: Colors.grey[500],
                                          padding: const EdgeInsets.all(4),
                                          minimumSize: const Size(28, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: message.text));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('已复制'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close, size: 16),
                                        tooltip: '删除',
                                        style: IconButton.styleFrom(
                                          foregroundColor: Colors.grey[500],
                                          padding: const EdgeInsets.all(4),
                                          minimumSize: const Size(28, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () =>
                                            _confirmDeleteMessage(message.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          final chatMsg = _history.where((m) => m.id == message.id).firstOrNull;
                          final hasAttachments = chatMsg?.attachments.isNotEmpty == true;

                          return Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SimpleTextMessage(message: message, index: index),
                                  if (hasAttachments)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                                      child: SizedBox(
                                        height: 56,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: chatMsg!.attachments.length,
                                          itemBuilder: (ctx, i) {
                                            final att = chatMsg.attachments[i];
                                            return _buildMessageAttachmentPreview(att);
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  icon: Icon(Icons.close, size: 16),
                                  tooltip: '删除',
                                  style: IconButton.styleFrom(
                                    foregroundColor: Colors.grey[500],
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(28, 28),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _confirmDeleteMessage(message.id),
                                ),
                              ),
                            ],
                          );
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

  // ── Model selector widget ──
  Widget _buildModelSelector() {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    if (models.length <= 1) return const SizedBox.shrink();

    final clampedIndex = _selectedModelIndex.clamp(0, models.length - 1);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        height: 32,
        child: DropdownButton<int>(
          value: clampedIndex,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onChanged: (idx) {
            if (idx == null) return;
            final model = models[idx];
            _adapter.selectModel(
                entriesState, model.configIndex, model.modelIndex);
            setState(() => _selectedModelIndex = idx);
            // Persist selection
            SharedPreferences.getInstance().then((prefs) {
              prefs.setInt('selected_model_index', idx);
            });
          },
          items: List.generate(models.length, (i) {
            final model = models[i];
            return DropdownMenuItem<int>(
              value: i,
              child: Text(
                model.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: cs.onSurfaceVariant.withOpacity(0.7)),
            tooltip: '重命名',
            onPressed: () => _renameConversation(conv.id, conv.title),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: cs.error.withOpacity(0.7)),
            tooltip: '删除',
            onPressed: () => _deleteConversation(conv.id),
          ),
        ],
      ),
      onTap: () {
        if (ref.read(_isStreamingProvider)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请等待当前消息生成完成')),
            );
          }
          return;
        }
        if (!isActive) {
          _saveMessages().then((_) {
            ref
                .read(conversationsProvider.notifier)
                .selectConversation(conv.id);
            _history.clear();
            _controller?.dispose();
            final newCtrl = InMemoryChatController();
            setState(() => _controller = newCtrl);
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

  void _renameConversation(String id, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
            onPressed: () async {
              final convs = ref.read(conversationsProvider);
              final conv = convs.where((c) => c.id == id).firstOrNull;
              if (conv != null) {
                for (final msg in conv.messages) {
                  for (final att in msg.attachments) {
                    await AttachmentStorage.deleteFile(att.storagePath);
                  }
                }
              }
              final wasActive = ref.read(activeConversationIdProvider) == id;
              await ref.read(conversationsProvider.notifier).deleteConversation(id);
              if (wasActive) {
                _history.clear();
                _controller?.dispose();
                final newCtrl = InMemoryChatController();
                setState(() => _controller = newCtrl);
              }
              if (mounted) Navigator.of(context).pop();
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

class _ChatComposer extends ConsumerStatefulWidget {
  final Future<void> Function(String text, List<Attachment> attachments) onSend;
  final VoidCallback onStop;

  const _ChatComposer({
    required this.onSend,
    required this.onStop,
  });

  @override
  ConsumerState<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<_ChatComposer> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final List<Attachment> _pendingAttachments = [];
  final Map<String, Uint8List> _pendingImageBytes = {};

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) return;
    widget.onSend(text.trim(), [..._pendingAttachments]);
    _pendingAttachments.clear();
    _pendingImageBytes.clear();
    _textController.clear();
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('相册'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('文件'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromFilePicker();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _addPendingAttachment(file.name, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        await _addPendingAttachment(file.name, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _pickFromFilePicker() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;
      await _addPendingAttachment(file.name, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _addPendingAttachment(String fileName, Uint8List bytes) async {
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final fileType = mimeType.startsWith('image/')
        ? 'image'
        : mimeType.startsWith('video/')
            ? 'video'
            : mimeType.startsWith('audio/')
                ? 'audio'
                : 'document';
    final storagePath = await AttachmentStorage.saveFile(fileName, bytes);
    final hash = AttachmentStorage.computeHash(bytes);
    final att = Attachment(
      fileName: fileName,
      mimeType: mimeType,
      fileType: fileType,
      hash: hash,
      storagePath: storagePath,
      fileSize: bytes.length,
    );
    if (fileType == 'image') {
      _pendingImageBytes[att.id] = bytes;
    }
    setState(() {
      _pendingAttachments.add(att);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导入 $fileName'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: 8,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.top + 48,
          ),
          duration: const Duration(seconds: 2),
          dismissDirection: DismissDirection.up,
        ),
      );
    }
  }

  void _removePendingAttachment(int index) {
    final att = _pendingAttachments[index];
    _pendingImageBytes.remove(att.id);
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = ref.watch(_isStreamingProvider);
    final hasText = _textController.text.trim().isNotEmpty;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAttachments)
            Container(
              height: 80,
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                itemBuilder: (ctx, i) {
                  final att = _pendingAttachments[i];
                  return FilePreviewChip(
                    attachment: att,
                    imageBytes: _pendingImageBytes[att.id],
                    onRemove: () => _removePendingAttachment(i),
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 4,
              right: 4,
              top: hasAttachments ? 4 : 8,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file_outlined, color: cs.onSurfaceVariant),
                  tooltip: '附件',
                  onPressed: isStreaming ? null : _showAttachmentPicker,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _handleSubmitted,
                    onChanged: (_) => setState(() {}),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHigh.withOpacity(0.8),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (isStreaming)
                  IconButton(
                    icon: Icon(Icons.stop_circle_outlined, color: Colors.red[400]),
                    tooltip: '停止生成',
                    onPressed: widget.onStop,
                  )
                else
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: cs.primary),
                    tooltip: '发送',
                    onPressed: (hasText || hasAttachments)
                        ? () => _handleSubmitted(_textController.text)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
