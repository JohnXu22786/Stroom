import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/camera_choice_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../services/attachment_storage.dart';
import '../widgets/file_preview.dart';

import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../services/chat_adapter.dart';
import '../services/chat_service.dart';
import '../providers/conversation_provider.dart';
import '../providers/provider_config.dart';
import '../pages/camera_page.dart';
import '../widgets/llm/jumping_dots.dart';
import '../widgets/llm/tool_call_card.dart';
import 'conversations_page.dart';
import 'provider_config_page.dart';
import '../utils/data_sanitizer.dart';

sealed class _MessageSegment {}

class _TextSegment extends _MessageSegment {
  final String text;
  _TextSegment(this.text);
}

class _ToolCallSegment extends _MessageSegment {
  final ToolCallData data;
  _ToolCallSegment(this.data);
}

class _SearchMatch {
  final String messageId;
  final int matchStart;
  final int matchEnd;
  _SearchMatch(this.messageId, this.matchStart, this.matchEnd);
}

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
  bool _reasoningEnabled = false;
  final Map<String, String> _reasoningContents = {};
  final Map<String, List<_MessageSegment>> _chatSegments = {};
  String? _streamingMsgId;

  bool _isSearching = false;
  String _searchQuery = '';
  final List<_SearchMatch> _searchMatches = [];
  int _currentMatchIndex = 0;
  final TextEditingController _searchTextController = TextEditingController();
  final Map<String, GlobalKey> _messageKeys = {};

  bool _developerMode = false;
  final Map<String, bool> _expandedErrors = {};

  static bool _toolsRegistered = false;

  @override
  void initState() {
    super.initState();
    _currentUser = User(id: 'user1', name: 'You');
    _aiUser = User(id: 'ai1', name: 'Stroom');
    _adapter = ChatAdapter();
    _controller = InMemoryChatController();

    if (!_toolsRegistered) {
      _toolsRegistered = true;
      ChatService.registerTool(
        const ToolDefinition(
          name: 'calculator',
          description: 'Evaluate a math expression and return the result',
          parameters: {
            'type': 'object',
            'properties': {
              'expression': {
                'type': 'string',
                'description': 'A math expression to evaluate e.g. 2 + 2',
              },
            },
            'required': ['expression'],
          },
        ),
        _executeCalculator,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  String _executeCalculator(Map<String, dynamic> args) {
    try {
      final expr = (args['expression'] as String?) ?? '';
      final sanitized = expr.replaceAll(' ', '');
      final double result;
      if (sanitized.contains('+')) {
        final parts = sanitized.split('+');
        result = parts.map((p) => double.parse(p)).reduce((a, b) => a + b);
      } else if (sanitized.contains('*')) {
        final parts = sanitized.split('*');
        result = parts.map((p) => double.parse(p)).reduce((a, b) => a * b);
      } else if (sanitized.contains('/')) {
        final nums = sanitized.split('/').map((p) => double.parse(p)).toList();
        result = nums.reduce((a, b) => a / b);
      } else if (sanitized.contains('-')) {
        final parts = sanitized.split('-');
        result = parts.map((p) => double.parse(p)).reduce((a, b) => a - b);
      } else {
        result = double.parse(sanitized);
      }
      return result.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _adapter.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  void _initialize() {
    _configureAdapter();
    // Restore saved model selection — clear stale index if out of range
    SharedPreferences.getInstance().then((prefs) {
      // Restore saved model selection — clear stale index if out of range
      final saved = prefs.getInt('selected_model_index');
      if (saved != null) {
        final entriesState = ref.read(providerEntriesProvider);
        final models = _adapter.availableModels(entriesState);
        if (saved >= 0 && saved < models.length) {
          final model = models[saved];
          _adapter.selectModel(
              entriesState, model.configIndex, model.modelIndex);
          setState(() => _selectedModelIndex = saved);
        } else {
          prefs.remove('selected_model_index');
        }
        } else {
          prefs.remove('selected_model_index');
        }
      }
      // Restore saved reasoning toggle
      final savedReasoning = prefs.getBool('reasoning_enabled');
      if (savedReasoning != null) {
        setState(() => _reasoningEnabled = savedReasoning);
      }
    });
    _loadConversationMessages();
  }

  void _configureAdapter() {
    final entriesState = ref.read(providerEntriesProvider);
    _adapter.configure(entriesState);
    final models = _adapter.availableModels(entriesState);
    final idx = models.indexWhere(
      (m) =>
          m.configIndex == _adapter.currentConfigIndex &&
          m.modelIndex == _adapter.currentModelIndex,
    );
    // Sync selected model index with adapter state
    _selectedModelIndex = idx >= 0 ? idx : 0;
    if (mounted) setState(() {});
  }

  Future<void> _loadConversationMessages() async {
    try {
      final activeId = ref.read(activeConversationIdProvider);
      if (activeId == null) return;

      final convs = ref.read(conversationsProvider);
      final conv = convs.where((c) => c.id == activeId).firstOrNull;
      if (conv == null || conv.messages.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      _history.clear();
      _chatSegments.clear();
      _streamingMsgId = null;
      _controller?.dispose();
      _messageKeys.clear();
      _expandedErrors.clear();
      _searchTextController.clear();
      _isSearching = false;
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = 0;
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
    } catch (e, s) {
      debugPrint('[ChatPage] _loadConversationMessages error: $e\n$s');
    }
  }

  Future<void> _saveMessages() async {
    try {
    // Ensure a conversation exists
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
      _chatSegments.clear();
      _streamingMsgId = null;
      _controller?.dispose();
      final newCtrl = InMemoryChatController();
      setState(() => _controller = newCtrl);
    });
  }

  void _showHistory() {
    _saveMessages().then((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConversationsPage()),
      ).then((_) {
        if (!mounted) return;
        _loadConversationMessages();
      });
    });
  }

  Future<void> _onMessageSend(String text, List<Attachment> attachments) async {
    if (ref.read(_isStreamingProvider)) return;

    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) {
      ref.read(conversationsProvider.notifier).createConversation();
    }

    final userMsgId = 'u${DateTime.now().millisecondsSinceEpoch}';

    _history.add(ChatMessage(
        role: 'user', content: text, id: userMsgId, attachments: attachments));
    await _controller?.insertMessage(Message.text(
      id: userMsgId,
      authorId: _currentUser.id,
      text: text,
      createdAt: DateTime.now(),
    ));

    await _startStreaming(text);
  }

  Future<void> _startStreaming(String text) async {
    if (ref.read(_isStreamingProvider)) return;
    ref.read(_isStreamingProvider.notifier).state = true;
    if (mounted) setState(() {});
    _cancelledByUser = false;

    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';
    _streamingMsgId = aiMsgId;
    _chatSegments[aiMsgId] = [];
    String textBeforeToolCall = '';

    final placeholder = Message.textStream(
      id: aiMsgId,
      authorId: _aiUser.id,
      createdAt: DateTime.now(),
      streamId: aiMsgId,
    );
    await _controller?.insertMessage(placeholder);

    String fullReply = '';
    String reasoningBuffer = '';
    DateTime lastUpdate = DateTime.now();
    const minInterval = Duration(milliseconds: 50);
    bool hasReceivedFirstToken = false;
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;

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
      final stream = _adapter.sendStreamWithTools(
        text,
        history: _history,
        reasoning: _reasoningEnabled,
        tools: const [
          ToolDefinition(
            name: 'calculator',
            description: 'Evaluate a math expression and return the result',
            parameters: {
              'type': 'object',
              'properties': {
                'expression': {
                  'type': 'string',
                  'description': 'A math expression to evaluate e.g. 2 + 2',
                },
              },
              'required': ['expression'],
            },
          ),
        ],
      );

      await for (final event in stream) {
        if (_cancelledByUser) break;

        switch (event) {
          case TextEvent e:
            if (!hasReceivedFirstToken) {
              hasReceivedFirstToken = true;
              if (mounted) setState(() {});
            }
            fullReply += e.text;
            textBeforeToolCall += e.text;
            final now = DateTime.now();
            if (now.difference(lastUpdate) >= minInterval) {
              lastUpdate = now;
              updateMessage(fullReply);
            }

          case ToolCallStartEvent e:
            // Flush accumulated text before tool call as a segment
            if (textBeforeToolCall.isNotEmpty) {
              _chatSegments[aiMsgId]!.add(
                _TextSegment(textBeforeToolCall),
              );
              textBeforeToolCall = '';
            }
            _chatSegments[aiMsgId]!.add(
              _ToolCallSegment(
                e.toolCall.copyWith(status: ToolCallStatus.running),
              ),
            );
            if (mounted) setState(() {});

          case ToolCallCompleteEvent e:
            final segs = _chatSegments[aiMsgId] ?? [];
            for (var i = segs.length - 1; i >= 0; i--) {
              final seg = segs[i];
              if (seg is _ToolCallSegment && seg.data.id == e.toolCallId) {
                segs[i] = _ToolCallSegment(
                  seg.data.copyWith(
                    status: ToolCallStatus.completed,
                    result: e.result,
                  ),
                );
                break;
              }
            }
            if (mounted) setState(() {});
        }
      }
    } catch (e, s) {
      if (!_cancelledByUser) {
        debugPrint('[ChatPage] streaming error: $e\n$s');
        final errorMsg = _formatErrorMessage(e);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg.replaceAll('错误: ', '').split('\n')[0],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        fullReply = errorMsg;
        // Capture full request/response raw data for error detail display
        final reqBody = _adapter.lastRequestBody;
        final headers = _adapter.lastRequestHeaders;
        final url = _adapter.lastRequestUrl;
        if (reqBody != null || headers != null || url != null) {
          rawRequestCapture = {};
          if (url != null) rawRequestCapture!['url'] = url;
          if (headers != null) rawRequestCapture!['headers'] = headers;
          if (reqBody != null) rawRequestCapture!['body'] = reqBody;
        }
        final respData = _adapter.lastResponseData;
        final statusCode = _adapter.lastResponseStatusCode;
        if (respData != null || statusCode != null) {
          rawResponseCapture = {};
          if (statusCode != null) rawResponseCapture!['statusCode'] = statusCode;
          if (respData != null) rawResponseCapture!['data'] = respData;
        }
      }
    } finally {
      // Flush remaining text after last tool call as a segment
      if (textBeforeToolCall.isNotEmpty) {
        _chatSegments[aiMsgId]!.add(_TextSegment(textBeforeToolCall));
      }
      // Mark any still-running tool calls as cancelled
      for (var i = 0; i < (_chatSegments[aiMsgId]?.length ?? 0); i++) {
        final seg = _chatSegments[aiMsgId]![i];
        if (seg is _ToolCallSegment && seg.data.status == ToolCallStatus.running) {
          _chatSegments[aiMsgId]![i] = _ToolCallSegment(
            seg.data.copyWith(
              status: ToolCallStatus.error,
              result: 'Cancelled',
            ),
          );
        }
      }
      // Final update — ensure last chunk is shown
      if (fullReply.isNotEmpty) {
        updateMessage(fullReply);
      }
      if (_reasoningEnabled) {
        reasoningBuffer = _adapter.reasoningContent;
      }
    }

    if (fullReply.isNotEmpty) {
      final isError = fullReply.startsWith('错误:');
      final msg = ChatMessage(
        role: 'assistant',
        content: fullReply,
        id: aiMsgId,
        isError: isError,
        reasoningContent:
            reasoningBuffer.isNotEmpty ? reasoningBuffer : null,
        rawRequest: isError ? rawRequestCapture : null,
        rawResponse: isError ? rawResponseCapture : null,
      );
      _history.add(msg);
      if (reasoningBuffer.isNotEmpty) {
        _reasoningContents[aiMsgId] = reasoningBuffer;
      }
    }
    _streamingMsgId = null;
    ref.read(_isStreamingProvider.notifier).state = false;
    _cancelledByUser = false;
    if (mounted) setState(() {});

    await _saveMessages();
  }

  void _confirmRetryOrEdit(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    if (ref.read(_isStreamingProvider)) return;

    final msg = _history[index];
    final isUser = msg.role == 'user';
    final newerMessagesExist = index < _history.length - 1;

    if (isUser) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('编辑消息'),
          content: Text(
            newerMessagesExist
                ? '确定要编辑这条消息吗？此操作将删除此消息及之后的所有消息。'
                : '确定要重新发送这条消息吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _editUserMessage(messageId);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('重试'),
          content: Text(
            newerMessagesExist
                ? '确定要重试这条回复吗？此操作将删除此消息及之后的所有消息。'
                : '确定要重新生成回复吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _retryAssistantMessage(messageId);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _editUserMessage(String messageId) async {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1 || index >= _history.length) return;
    final msg = _history[index];

    // Remove this message and all after from history
    try {
      if (index < _history.length) {
        final removed = _history.sublist(index);
        _history.removeRange(index, _history.length);
        for (final r in removed) {
          final ctrlMsg =
              _controller?.messages.where((m) => m.id == r.id).firstOrNull;
          if (ctrlMsg != null) {
            await _controller?.removeMessage(ctrlMsg);
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatPage] _editUserMessage remove failed: $e');
    }

    // Re-send with same content (acts as edit)
    await _onMessageSend(msg.content, msg.attachments);
  }

  void _showEditMessageDialog(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final msg = _history[index];
    final editingController = TextEditingController(text: msg.content);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '编辑消息',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      editingController.dispose();
                      Navigator.pop(ctx);
                    },
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: editingController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '编辑消息...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('发送'),
                  onPressed: () {
                    final newText = editingController.text.trim();
                    editingController.dispose();
                    Navigator.pop(ctx);
                    if (newText.isEmpty) return;
                    // Replace message content and re-send
                    _editUserMessageWithText(messageId, newText);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editUserMessageWithText(String messageId, String newText) async {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1 || index >= _history.length) return;
    final msg = _history[index];

    // Remove this message and all after from history
    try {
      if (index < _history.length) {
        final removed = _history.sublist(index);
        _history.removeRange(index, _history.length);
        for (final r in removed) {
          final ctrlMsg =
              _controller?.messages.where((m) => m.id == r.id).firstOrNull;
          if (ctrlMsg != null) {
            await _controller?.removeMessage(ctrlMsg);
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatPage] _editUserMessageWithText remove failed: $e');
    }

    // Send with edited text
    await _onMessageSend(newText, msg.attachments);
  }

  Future<void> _retryAssistantMessage(String messageId) async {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1 || index == 0 || index >= _history.length) return;

    // Remove this assistant message and all after from history
    try {
      if (index < _history.length) {
        final removed = _history.sublist(index);
        _history.removeRange(index, _history.length);
        for (final r in removed) {
          final ctrlMsg =
              _controller?.messages.where((m) => m.id == r.id).firstOrNull;
          if (ctrlMsg != null) {
            await _controller?.removeMessage(ctrlMsg);
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatPage] _retryAssistantMessage remove failed: $e');
    }

    // Re-generate using the preceding user message
    final userMsg = _history[index - 1];
    await _startStreaming(userMsg.content);
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
    return GestureDetector(
      onTap: () => _showAttachmentPreview(att),
      child: Container(
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
      ),
    );
  }

  void _showAttachmentPreview(Attachment att) async {
    final data = await AttachmentStorage.readFile(att.storagePath);
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法加载文件')),
        );
      }
      return;
    }
    if (!mounted) return;
    final isImage = att.fileType == 'image';
    if (isImage) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(
                    data,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('无法加载图片', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  att.fileName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(att.fileName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('类型: ${att.mimeType}'),
              const SizedBox(height: 4),
              Text('大小: ${_formatFileSize(att.fileSize)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _stopStreaming() {
    _cancelledByUser = true;
    _adapter.cancel();
    ref.read(_isStreamingProvider.notifier).state = false;
  }

  /// 格式化错误信息，分类显示友好的提示并保留原始错误
  String _formatErrorMessage(Object error) {
    return formatChatErrorMessage(error);
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchMatches.clear();
      _currentMatchIndex = 0;
      if (query.isEmpty) return;
      final lowerQuery = query.toLowerCase();
      for (final msg in _history) {
        final text = msg.content;
        final lowerContent = text.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerContent.indexOf(lowerQuery, start);
          if (idx == -1) break;
          _searchMatches.add(_SearchMatch(msg.id, idx, idx + query.length));
          start = idx + query.length;
        }
      }
    });
    if (_searchMatches.isNotEmpty) {
      _scrollToCurrentMatch();
    }
  }

  void _scrollToCurrentMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) return;
    final match = _searchMatches[_currentMatchIndex];
    final key = _messageKeys[match.messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, alignment: 0.3);
    }
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _scrollToCurrentMatch();
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = 0;
      _searchTextController.clear();
    });
  }

  Widget _buildHighlightedText(String text, String messageId, {Color? textColor}) {
    if (_searchQuery.isEmpty) {
      return SelectableText(text, style: textColor != null ? TextStyle(color: textColor) : null);
    }
    final matches = _searchMatches.where((m) => m.messageId == messageId).toList();
    if (matches.isEmpty) {
      return SelectableText(text, style: textColor != null ? TextStyle(color: textColor) : null);
    }
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      if (match.matchStart > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.matchStart)));
      }
      final matchText = text.substring(match.matchStart, match.matchEnd);
      final isCurrent = _searchMatches.indexOf(match) == _currentMatchIndex;
      spans.add(TextSpan(
        text: matchText,
        style: TextStyle(
          backgroundColor: isCurrent ? Colors.orangeAccent : Colors.yellow,
          color: Colors.black87,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        ),
      ));
      lastEnd = match.matchEnd;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return SelectableText.rich(
      TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  void _showJsonInspection(String msgId) {
    final chatMsg = _history.where((m) => m.id == msgId).firstOrNull;
    if (chatMsg == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final encoder = const JsonEncoder.withIndent('  ');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: DefaultTabController(
          length: 2,
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      const Text(
                        'JSON 审查',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Request'),
                    Tab(text: 'Response'),
                  ],
                ),
                Flexible(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          chatMsg.rawRequest != null
                              ? encoder.convert(
                                  DataSanitizer.sanitizeForDisplay(chatMsg.rawRequest))
                              : '无请求数据',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          chatMsg.rawResponse != null
                              ? encoder.convert(
                                  DataSanitizer.sanitizeForDisplay(chatMsg.rawResponse))
                              : '无响应数据',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

    // Re-configure adapter when provider entries change (e.g. after load completes)
    ref.listen(providerEntriesProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _configureAdapter();
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
                    child: GestureDetector(
                      onLongPress: () => setState(() => _developerMode = !_developerMode),
                      child: Row(
                        children: [
                          Flexible(
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
                          if (_developerMode)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'DEV',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // ── Search toggle ──
                  IconButton(
                    icon: Icon(
                      _isSearching ? Icons.search_off : Icons.search,
                      color: _isSearching
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: '搜索消息',
                    onPressed: () => setState(() => _isSearching = !_isSearching),
                  ),
                  // ── Model selector ──
                  if (adapterConfigured) _buildModelSelector(),
                  // ── Reasoning toggle ──
                  if (adapterConfigured)
                    IconButton(
                      icon: Icon(
                        Icons.psychology,
                        color: _reasoningEnabled
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: _reasoningEnabled ? '推理已开启' : '推理',
                      onPressed: () {
                        setState(() =>
                            _reasoningEnabled = !_reasoningEnabled);
                        SharedPreferences.getInstance().then((prefs) =>
                            prefs.setBool(
                                'reasoning_enabled', _reasoningEnabled));
                      },
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

            // ── Search bar ──
            if (_isSearching)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _searchTextController,
                          autofocus: true,
                          onChanged: _performSearch,
                          decoration: const InputDecoration(
                            hintText: '搜索消息...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (_searchMatches.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_currentMatchIndex + 1}/${_searchMatches.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      tooltip: '上一个',
                      onPressed: _previousMatch,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      tooltip: '下一个',
                      onPressed: _nextMatch,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: '关闭搜索',
                      onPressed: _closeSearch,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
composerBuilder: (context) => ChatComposerWidget(
  onSend: _onMessageSend,
  onStop: _stopStreaming,
),
                        textMessageBuilder: (context, message, index,
                            {required bool isSentByMe,
                            MessageGroupStatus? groupStatus}) {
                          final isAi = message.authorId == _aiUser.id;

                          Widget messageBubble;
                          if (isAi) {
                            final chatMsg = _history.where((m) => m.id == message.id).firstOrNull;
                            if ((chatMsg?.isError == true) || message.text.startsWith('错误:')) {
                              messageBubble = Container(
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.error_outline,
                                            size: 14, color: Colors.red[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '发送失败',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      message.text.replaceAll('错误: ', ''),
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (chatMsg != null &&
                                        (chatMsg.rawRequest != null ||
                                            chatMsg.rawResponse != null))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: TextButton.icon(
                                          icon: const Icon(
                                            Icons.preview,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            '查看详细错误',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () =>
                                              _showErrorDetailDialog(
                                            context,
                                            message.id,
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            } else {
                              final reasoningText = _reasoningContents[message.id];
                              final segments = _chatSegments[message.id];
                              final isWaitingForFirstToken =
                                  message.id == _streamingMsgId &&
                                  message.text.isEmpty &&
                                  isStreaming;
                              final hasSearchMatch = _isSearching &&
                                  _searchQuery.isNotEmpty &&
                                  _searchMatches.any((m) => m.messageId == message.id);

                              messageBubble = Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[850]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (reasoningText != null)
                                      _ReasoningSection(reasoningText: reasoningText),
                                    // Show JumpingDots while waiting for first token
                                    if (isWaitingForFirstToken)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: JumpingDotsProgressIndicator(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      )
                                    else if (segments != null && segments.isNotEmpty)
                                      // Segments: text and tool calls in order
                                      ...segments.map((seg) => switch (seg) {
                                            _TextSegment s => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: hasSearchMatch
                                                ? _buildHighlightedText(s.text, message.id)
                                                : MarkdownWidget(
                                                    data: s.text,
                                                    selectable: true,
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    config: markdownConfig.copy(configs: [
                                                      PreConfig(theme: draculaTheme),
                                                    ]),
                                                  ),
                                            ),
                                            _ToolCallSegment s => ToolCallCard(data: s.data),
                                          })
                                    else if (hasSearchMatch)
                                      _buildHighlightedText(message.text, message.id)
                                    else
                                      MarkdownWidget(
                                        data: message.text,
                                        selectable: true,
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        config: markdownConfig.copy(configs: [
                                          PreConfig(theme: draculaTheme),
                                        ]),
                                      ),
                                  ],
                                ),
                              );
                            }
                          } else {
                            final chatMsg = _history.where((m) => m.id == message.id).firstOrNull;
                            final hasAttachments = chatMsg?.attachments.isNotEmpty == true;
                            final hasSearchMatch = _isSearching &&
                                _searchQuery.isNotEmpty &&
                                _searchMatches.any((m) => m.messageId == message.id);
                            messageBubble = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasSearchMatch)
                                  _buildHighlightedText(message.text, message.id)
                                else
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
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                key: _messageKeys.putIfAbsent(message.id, () => GlobalKey()),
                                child: messageBubble,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2, bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ActionButton(
                                      icon: Icons.copy,
                                      tooltip: '复制',
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
                                    const SizedBox(width: 2),
                                    if (isAi)
                                      _ActionButton(
                                        icon: Icons.refresh,
                                        tooltip: '重试',
                                        onPressed: () =>
                                            _confirmRetryOrEdit(message.id),
                                      )
                                    else
                                      _ActionButton(
                                        icon: Icons.edit_outlined,
                                        tooltip: '编辑',
                                        onPressed: () =>
                                            _showEditMessageDialog(message.id),
                                      ),
                                    const SizedBox(width: 2),
                                    if (_developerMode && isAi && _history.any((m) => m.id == message.id && (m.rawRequest != null || m.rawResponse != null)))
                                      _ActionButton(
                                        icon: Icons.code,
                                        tooltip: 'JSON 审查',
                                        onPressed: () => _showJsonInspection(message.id),
                                      ),
                                    const SizedBox(width: 2),
                                    _ActionButton(
                                      icon: Icons.delete_outline,
                                      tooltip: '删除',
                                      onPressed: () =>
                                          _confirmDeleteMessage(message.id),
                                    ),
                                  ],
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

  Widget _buildJsonBlock(String label, dynamic data, bool isDark) {
    final encoder = const JsonEncoder.withIndent('  ');
    final sanitized = DataSanitizer.sanitizeForDisplay(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            encoder.convert(sanitized),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  void _showErrorDetailDialog(BuildContext context, String messageId) {
    final chatMsg = _history.where((m) => m.id == messageId).firstOrNull;
    if (chatMsg == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawRequest = chatMsg.rawRequest;
    final rawResponse = chatMsg.rawResponse;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      '错误详情',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Body with tabs or scrollable content
              Flexible(
                child: rawRequest != null || rawResponse != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        children: [
                          if (rawRequest != null) ...[
                            _buildJsonBlock('请求 (Request)', rawRequest, isDark),
                            const SizedBox(height: 12),
                          ],
                          if (rawResponse != null)
                            _buildJsonBlock('响应 (Response)', rawResponse, isDark),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            '无详细数据',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ),
              ),
            ],
          ),
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
    // Re-sync if clampedIndex differs from selected (e.g. models changed)
    if (clampedIndex != _selectedModelIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final model = models.length > clampedIndex ? models[clampedIndex] : null;
          if (model != null) {
            _adapter.selectModel(
                entriesState, model.configIndex, model.modelIndex);
            setState(() => _selectedModelIndex = clampedIndex);
          }
        }
      });
    }

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
            if (idx == null || idx >= models.length) return;
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
}

/// 格式化聊天错误信息，分类显示友好的提示并保留原始错误
String formatChatErrorMessage(Object error) {
  final errorStr = error.toString();

  if (errorStr.contains('请先配置聊天供应商')) {
    return '错误: 聊天 API 未配置，请先前往设置页面配置';
  }

  if (errorStr.contains('API key not configured')) {
    return '错误: API Key 未配置，请检查设置';
  }

  if (errorStr.contains('无法连接到服务器') ||
      errorStr.contains('连接错误')) {
    return '错误: 无法连接到服务器，请检查网络连接和 API 地址\n$errorStr';
  }

  if (errorStr.contains('SocketException') ||
      errorStr.contains('Connection refused') ||
      errorStr.contains('连接失败')) {
    return '错误: 网络连接失败，请检查网络连接\n$errorStr';
  }

  if (errorStr.contains('timeout') || errorStr.contains('超时')) {
    return '错误: 连接超时，服务器无响应\n$errorStr';
  }

  if (errorStr.contains('HTTP ')) {
    return '错误: $errorStr';
  }

  return '错误: $errorStr';
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: Colors.grey[500],
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(28, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
    );
  }
}

class _ReasoningSection extends StatefulWidget {
  final String reasoningText;
  const _ReasoningSection({required this.reasoningText});

  @override
  State<_ReasoningSection> createState() => _ReasoningSectionState();
}

class _ReasoningSectionState extends State<_ReasoningSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.chevron_right,
                  size: 16,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Text(
                  '推理过程',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Text(
                widget.reasoningText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatComposerWidget extends ConsumerStatefulWidget {
  final void Function(String text, List<Attachment> attachments) onSend;
  final VoidCallback onStop;

  const ChatComposerWidget({
    required this.onSend,
    required this.onStop,
  });

  @override
  ConsumerState<ChatComposerWidget> createState() => ChatComposerWidgetState();
}

class ChatComposerWidgetState extends ConsumerState<ChatComposerWidget> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final List<Attachment> _pendingAttachments = [];
  final Map<String, Uint8List> _pendingImageBytes = {};
  final GlobalKey _composerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportComposerHeight());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _reportComposerHeight() {
    if (!mounted) return;
    final renderBox = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final height = renderBox.size.height;
      final bottomSafeArea = MediaQuery.of(context).padding.bottom;
      try {
        context.read<ComposerHeightNotifier>().setHeight(height - bottomSafeArea);
      } catch (_) {}
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) return;
    widget.onSend(text.trim(), [..._pendingAttachments]);
    _pendingAttachments.clear();
    _pendingImageBytes.clear();
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportComposerHeight());
  }

  void _showComposerFullscreenEditor() {
    final editingController = TextEditingController(text: _textController.text);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '编辑消息',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      editingController.dispose();
                      Navigator.pop(ctx);
                    },
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: editingController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('发送'),
                  onPressed: () {
                    final text = editingController.text;
                    editingController.dispose();
                    Navigator.pop(ctx);
                    _handleSubmitted(text);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  _showGalleryPicker();
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

  void _showGalleryPicker() {
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
                leading: const Icon(Icons.photo_album_outlined),
                title: const Text('系统相册'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('应用相册'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromAppGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    final choice = await showCameraChoiceDialog(context);
    if (choice == null) return;
    try {
      if (choice == CameraChoice.app) {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const CameraPage()),
        );
        if (result != null && result.isNotEmpty) {
          final file = File(result);
          final bytes = await file.readAsBytes();
          final fileName = result.split(RegExp(r'[/\\]')).last;
          await _addPendingAttachment(fileName, bytes);
        }
      } else {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.camera);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        await _addPendingAttachment(file.name, bytes);
      }
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

  Future<void> _pickFromAppGallery() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportComposerHeight());
  }

  void _removePendingAttachment(int index) {
    final att = _pendingAttachments[index];
    _pendingImageBytes.remove(att.id);
    setState(() {
      _pendingAttachments.removeAt(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportComposerHeight());
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
        key: _composerKey,
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
                      suffixIcon: IconButton(
                        icon: Icon(Icons.fullscreen, size: 20, color: cs.onSurfaceVariant),
                        tooltip: '全屏编辑',
                        onPressed: _showComposerFullscreenEditor,
                      ),
                      suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
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
