import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../services/attachment_storage.dart';
import '../services/chat_adapter.dart';
import '../services/chat_service.dart';
import '../providers/conversation_provider.dart';
import '../providers/provider_config.dart';
import '../providers/assistant_provider.dart';
import '../widgets/llm/jumping_dots.dart';
import '../widgets/llm/tool_call_card.dart';
import '../utils/data_sanitizer.dart';
import 'assistant_selection_page.dart';
import 'topic_selection_page.dart';
import 'provider_config_page.dart';
import 'chat/chat_action_button.dart';
import 'chat/chat_composer_widget.dart';
import 'chat/chat_error_utils.dart';
import 'chat/chat_providers.dart';
import 'chat/chat_reasoning_section.dart';
import 'chat/message_segment.dart';

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
  final Map<String, List<MessageSegment>> _chatSegments = {};
  String? _streamingMsgId;

  bool _isSearching = false;
  String _searchQuery = '';
  final List<SearchMatch> _searchMatches = [];
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

    // Check if we have a selected assistant and active conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final assistantId = ref.read(selectedAssistantIdProvider);
      final activeConvId = ref.read(activeConversationIdProvider);

      if (assistantId == null || activeConvId == null) {
        // If no assistant or topic selected, go back to assistant selection
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AssistantSelectionPage()),
        );
        return;
      }

      _initialize();
    });
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
    SharedPreferences.getInstance().then((prefs) {
      // Restore saved model selection — clear stale index if out of range
      final savedIdx = prefs.getInt('selected_model_index');
      if (savedIdx != null) {
        final entriesState = ref.read(providerEntriesProvider);
        final models = _adapter.availableModels(entriesState);
        if (savedIdx >= 0 && savedIdx < models.length) {
          final model = models[savedIdx];
          _adapter.selectModel(
              entriesState, model.configIndex, model.modelIndex);
          setState(() => _selectedModelIndex = savedIdx);
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
      if (conv == null) return;

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

      if (conv.messages.isEmpty) {
        if (mounted) setState(() {});
        return;
      }
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
    if (ref.read(isStreamingProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请等待当前消息生成完成')),
        );
      }
      return;
    }
    _saveMessages().then((_) {
      final assistantId = ref.read(selectedAssistantIdProvider);
      ref.read(conversationsProvider.notifier).createConversation(
            assistantId: assistantId,
          );

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
        MaterialPageRoute(builder: (_) => TopicSelectionPage()),
      ).then((_) {
        if (!mounted) return;
        _loadConversationMessages();
      });
    });
  }

  Future<void> _onMessageSend(String text, List<Attachment> attachments) async {
    if (ref.read(isStreamingProvider)) return;

    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) {
      final assistantId = ref.read(selectedAssistantIdProvider);
      ref.read(conversationsProvider.notifier).createConversation(
            assistantId: assistantId,
          );
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
    if (ref.read(isStreamingProvider)) return;
    ref.read(isStreamingProvider.notifier).state = true;
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
      // Get the assistant's system prompt
      final assistant = ref.read(selectedAssistantProvider);
      final systemPrompt = assistant?.prompt;

      final stream = _adapter.sendStreamWithTools(
        text,
        history: _history,
        reasoning: _reasoningEnabled,
        systemPrompt: systemPrompt,
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
                TextSegment(textBeforeToolCall),
              );
              textBeforeToolCall = '';
            }
            _chatSegments[aiMsgId]!.add(
              ToolCallSegment(
                e.toolCall.copyWith(status: ToolCallStatus.running),
              ),
            );
            if (mounted) setState(() {});

          case ToolCallCompleteEvent e:
            final segs = _chatSegments[aiMsgId] ?? [];
            for (var i = segs.length - 1; i >= 0; i--) {
              final seg = segs[i];
              if (seg is ToolCallSegment && seg.data.id == e.toolCallId) {
                segs[i] = ToolCallSegment(
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
        _chatSegments[aiMsgId]!.add(TextSegment(textBeforeToolCall));
      }
      // Mark any still-running tool calls as cancelled
      for (var i = 0; i < (_chatSegments[aiMsgId]?.length ?? 0); i++) {
        final seg = _chatSegments[aiMsgId]![i];
        if (seg is ToolCallSegment && seg.data.status == ToolCallStatus.running) {
          _chatSegments[aiMsgId]![i] = ToolCallSegment(
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
    ref.read(isStreamingProvider.notifier).state = false;
    _cancelledByUser = false;
    if (mounted) setState(() {});

    await _saveMessages();
  }

  void _confirmRetryOrEdit(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    if (ref.read(isStreamingProvider)) return;

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
    ref.read(isStreamingProvider.notifier).state = false;
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
          _searchMatches.add(SearchMatch(msg.id, idx, idx + query.length));
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
    final isStreaming = ref.watch(isStreamingProvider);

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
    final selectedAssistant = ref.watch(selectedAssistantProvider);
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
                          // Assistant emoji + name
                          if (selectedAssistant != null) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              child: Text(
                                selectedAssistant.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                selectedAssistant.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
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
                                      ChatReasoningSection(reasoningText: reasoningText),
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
                                            TextSegment s => Padding(
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
                                            ToolCallSegment s => ToolCallCard(data: s.data),
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
                                    ChatActionButton(
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
                                      ChatActionButton(
                                        icon: Icons.refresh,
                                        tooltip: '重试',
                                        onPressed: () =>
                                            _confirmRetryOrEdit(message.id),
                                      )
                                    else
                                      ChatActionButton(
                                        icon: Icons.edit_outlined,
                                        tooltip: '编辑',
                                        onPressed: () =>
                                            _showEditMessageDialog(message.id),
                                      ),
                                    const SizedBox(width: 2),
                                    if (_developerMode && isAi && _history.any((m) => m.id == message.id && (m.rawRequest != null || m.rawResponse != null)))
                                      ChatActionButton(
                                        icon: Icons.code,
                                        tooltip: 'JSON 审查',
                                        onPressed: () => _showJsonInspection(message.id),
                                      ),
                                    const SizedBox(width: 2),
                                    ChatActionButton(
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
