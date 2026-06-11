import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../widgets/markdown_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/message_attachment_preview.dart';
import '../services/attachment_storage.dart';

import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../services/chat_adapter.dart';
import '../services/chat_service.dart';
import '../providers/conversation_provider.dart';
import '../providers/provider_config.dart';
import '../widgets/llm/jumping_dots.dart';
import '../widgets/llm/tool_call_card.dart';
import 'message_search_page.dart';
import 'provider_config_page.dart';

import 'chat/chat_types.dart';
import 'chat/utils/format_chat_error.dart';

export 'chat/utils/format_chat_error.dart' show formatChatErrorMessage;
import 'chat/widgets/action_button.dart';
import 'chat/widgets/reasoning_section.dart';
import 'chat/dialogs/error_detail_dialog.dart';
import 'chat/dialogs/confirm_dialog.dart';
import 'chat/dialogs/edit_message_dialog.dart';
import 'chat/dialogs/image_preview_dialog.dart';
import 'chat/dialogs/file_info_dialog.dart';
import 'chat/dialogs/json_inspection_dialog.dart';
import 'chat/composer/chat_composer_widget.dart';

class ChatPage extends ConsumerStatefulWidget {
  /// Optional search query to auto-activate search mode with.
  /// When provided, the page will open in search mode with the query
  /// pre-filled and matching text highlighted. Used by [MessageSearchPage].
  final String? initialSearchQuery;

  const ChatPage({super.key, this.initialSearchQuery});

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
  final Map<String, String> _reasoningContents = {};
  final Map<String, List<MessageSegment>> _chatSegments = {};
  /// Tracks how many characters of [_history] text have been rendered as
  /// [TextSegment] entries in [_chatSegments] for each streaming message.
  /// Used for incremental markdown rendering: only new text chunks are
  /// added as new [TextSegment]s, avoiding full re-render of the entire
  /// accumulated content on each throttle cycle.
  final Map<String, int> _streamingRenderedLengths = {};
  String? _streamingMsgId;

  bool _isSearching = false;
  SearchMode _searchMode = SearchMode.current;
  String _searchQuery = '';
  final List<SearchMatch> _searchMatches = [];
  int _currentMatchIndex = 0;
  final TextEditingController _searchTextController = TextEditingController();
  final Map<String, GlobalKey> _messageKeys = {};

  bool _developerMode = false;
  final Map<String, bool> _expandedErrors = {};

  // ── Infinite Scroll / Lazy Load pagination state ──
  /// Number of messages to load per page.
  static const int _pageSize = 20;

  /// Index in [_history] pointing to the first message that is loaded into
  /// the chat controller. All messages from [_loadedUpToIndex] to the end of
  /// [_history] are visible. When [_loadedUpToIndex] is 0, all messages are
  /// already loaded.
  int _loadedUpToIndex = 0;

  /// Whether a pagination load is currently in progress.
  bool _isLoadingMore = false;

  /// Whether there are more older messages to load.
  bool get _hasMoreMessages => _loadedUpToIndex > 0;

  static bool _toolsRegistered = false;

  /// Returns true if [text] ends with an unclosed LaTeX math delimiter.
  ///
  /// Checks for:
  /// - Unclosed inline math (`$...$` with an odd number of `$`).
  /// - Unclosed block math (`$$...$$` where `$$` count is odd).
  ///
  /// Used during streaming to avoid splitting math formulas across
  /// segment boundaries. If the last segment ends with unclosed math,
  /// new text is merged into it instead of creating a new segment.
  static bool _hasUnclosedMath(String text) {
    if (text.isEmpty) return false;
    int i = 0;
    int inlineCount = 0;
    int blockCount = 0;
    while (i < text.length) {
      if (text[i] == r'\' && i + 1 < text.length) {
        i += 2; // skip escaped character (e.g. \$)
        continue;
      }
      if (text[i] == r'$') {
        if (i + 1 < text.length && text[i + 1] == r'$') {
          blockCount++;
          i += 2;
        } else {
          inlineCount++;
          i++;
        }
      } else {
        i++;
      }
    }
    return (inlineCount % 2 == 1) || (blockCount % 2 == 1);
  }

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
    // If initialSearchQuery is provided, activate search mode after init
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchTextController.text = widget.initialSearchQuery!;
        _isSearching = true;
        _performSearch(widget.initialSearchQuery!);
      });
    }
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

  Future<void> _initialize() async {
    _configureAdapter();
    // Initialize MCP servers and discover tools
    final entriesState = ref.read(providerEntriesProvider);
    await _adapter.initializeMcpServers(entriesState);
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
      }
      // Restore saved reasoning toggle
      final savedReasoning = prefs.getBool('reasoning_enabled');
      if (savedReasoning != null) {
        ref.read(reasoningEnabledProvider.notifier).state = savedReasoning;
      }
      // Restore saved reasoning effort
      final savedEffort = prefs.getString('reasoning_effort');
      if (savedEffort != null &&
          ['low', 'medium', 'high'].contains(savedEffort)) {
        ref.read(reasoningEffortProvider.notifier).state = savedEffort;
      }
    });
    _loadConversationMessages();
  }

  /// Loads the previous page of older messages and prepends them to the
  /// chat controller. Called by [ChatAnimatedList.onEndReached] when the user
  /// scrolls near the top of the message list.
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    _isLoadingMore = true;
    if (mounted) setState(() {});

    try {
      final newStart = max(0, _loadedUpToIndex - _pageSize);
      final batchMessages = _history.sublist(newStart, _loadedUpToIndex);

      // Convert ChatMessage list to flutter_chat_ui Message list
      final msgs = batchMessages.map((m) => Message.text(
        id: m.id,
        authorId: m.role == 'user' ? _currentUser.id : _aiUser.id,
        text: m.content,
        createdAt: m.createdAt,
      )).toList();

      // Guard: controller might have been disposed during the async gap
      // (e.g., conversation switched). Only update state if still valid
      // and the load hasn't been invalidated by a conversation switch.
      if (_controller != null && _isLoadingMore) {
        // Prepend all messages at the beginning (index 0) of the controller
        await _controller!.insertAllMessages(msgs, index: 0);
        // Re-check after await: conversation might have switched during the
        // insertion, which would have reset _isLoadingMore to false.
        if (_isLoadingMore) {
          _loadedUpToIndex = newStart;
        }
      }
    } catch (e, s) {
      debugPrint('[ChatPage] _loadMoreMessages error: $e\n$s');
    } finally {
      _isLoadingMore = false;
      if (mounted) setState(() {});
    }
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
      _streamingRenderedLengths.clear();
      _streamingMsgId = null;
      _controller?.dispose();
      _messageKeys.clear();
      _expandedErrors.clear();
      _searchTextController.clear();
      _isSearching = false;
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = 0;

      // Initialize pagination state: reset any in-flight load and
      // let the loop below set the correct loaded index.
      _isLoadingMore = false;

      final newCtrl = InMemoryChatController();
      _controller = newCtrl;
      // Load all messages into _history (needed for full context in API calls
      // and search), but only insert the last _pageSize messages into the
      // controller for display (lazy loading).
      for (final msg in conv.messages) {
        _history.add(msg);
      }
      _loadedUpToIndex = max(0, _history.length - _pageSize);
      for (var i = _loadedUpToIndex; i < _history.length; i++) {
        final msg = _history[i];
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
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => ProviderConfigPage(entryId: llmEntry.id),
        ),
      ).then((_) {
        if (mounted) _configureAdapter();
      });
    }
  }

  Future<void> _onMessageSend(String text, List<Attachment> attachments) async {
    if (ref.read(isStreamingProvider)) return;

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
    if (ref.read(isStreamingProvider)) return;
    ref.read(isStreamingProvider.notifier).state = true;
    if (mounted) setState(() {});
    _cancelledByUser = false;

    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';
    _streamingMsgId = aiMsgId;
    _chatSegments[aiMsgId] = [];
    _streamingRenderedLengths[aiMsgId] = 0;

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
      // Merge built-in tools with MCP tools
      final mcpTools = _adapter.getAllToolDefinitions();
      final enabledTools = ref.read(enabledToolNamesProvider);
      final allTools = <ToolDefinition>[
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
        // Only include enabled MCP tools
        ...mcpTools.where((t) => enabledTools.contains(t.name)),
      ];

      final stream = _adapter.sendStreamWithTools(
        text,
        history: _history,
        reasoning: ref.read(reasoningEnabledProvider),
        reasoningEffort: ref.read(reasoningEffortProvider),
        tools: allTools,
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
            final now = DateTime.now();
            if (now.difference(lastUpdate) >= minInterval) {
              lastUpdate = now;
              // Keep the controller updated so the Chat widget re-renders
              // the streaming message. The textMessageBuilder will read
              // from _chatSegments (incremental segments) for the actual
              // markdown rendering, not from message.text directly.
              updateMessage(fullReply);
              // Incremental rendering: add only the new text chunk as a
              // TextSegment, so MarkdownWidget only parses new content
              // instead of re-rendering the entire accumulated text.
              final renderedLen = _streamingRenderedLengths[aiMsgId]!;
              if (fullReply.length > renderedLen) {
                final newChunk = fullReply.substring(renderedLen);
                final segments = _chatSegments[aiMsgId]!;
                final lastSeg =
                    segments.isNotEmpty ? segments.last : null;
                if (lastSeg is TextSegment &&
                    _hasUnclosedMath(lastSeg.text)) {
                  // Merge into the last segment to avoid splitting math
                  // formulas ($...$ or $$...$$) across segment boundaries.
                  // The merged segment's MarkdownWidget will re-parse the
                  // combined text and can render the now-complete formula.
                  segments[segments.length - 1] =
                      TextSegment(lastSeg.text + newChunk);
                } else {
                  segments.add(TextSegment(newChunk));
                }
                _streamingRenderedLengths[aiMsgId] = fullReply.length;
              }
            }

          case ToolCallStartEvent e:
            // Flush any text not yet rendered as segments before tool call
            final renderedLen = _streamingRenderedLengths[aiMsgId]!;
            if (fullReply.length > renderedLen) {
              _chatSegments[aiMsgId]!.add(
                TextSegment(fullReply.substring(renderedLen)),
              );
              _streamingRenderedLengths[aiMsgId] = fullReply.length;
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
        // Clear segments since error overrides the accumulated content.
        // The error path in textMessageBuilder reads message.text directly,
        // not _chatSegments, so segments are not used for error display.
        _chatSegments[aiMsgId]?.clear();
        _streamingRenderedLengths[aiMsgId] = 0;
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
        final respHeaders = _adapter.lastResponseHeaders;
        if (respData != null || statusCode != null || respHeaders != null) {
          rawResponseCapture = {};
          if (statusCode != null) rawResponseCapture!['statusCode'] = statusCode;
          if (respHeaders != null) rawResponseCapture!['headers'] = respHeaders;
          if (respData != null) rawResponseCapture!['data'] = respData;
        } else {
          // For network errors (DNS failure, timeout, server not found, etc.)
          // there is no HTTP response, so capture the error message string.
          rawResponseCapture = {
            'error': e.toString(),
          };
        }
      }
    } finally {
      // Flush any remaining text not yet rendered as segments
      final renderedLen = _streamingRenderedLengths[aiMsgId]!;
      if (fullReply.length > renderedLen) {
        _chatSegments[aiMsgId]!.add(
          TextSegment(fullReply.substring(renderedLen)),
        );
        _streamingRenderedLengths[aiMsgId] = fullReply.length;
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
      // After streaming completes, clear segments for messages without
      // tool calls. This allows the normal MarkdownWidget path to render
      // the full text correctly, avoiding visual artifacts from markdown
      // constructs (paragraphs, inline code, etc.) that were split across
      // arbitrary throttle-boundary segments. Segments containing tool
      // calls are retained since they are naturally delimited at tool
      // call boundaries and the ToolCallCards must still be displayed.
      if (_chatSegments[aiMsgId] != null &&
          _chatSegments[aiMsgId]!.every((s) => s is TextSegment)) {
        _chatSegments[aiMsgId]!.clear();
      }
      if (ref.read(reasoningEnabledProvider)) {
        reasoningBuffer = _adapter.reasoningContent;
      }
    }

    // Wrap post-stream processing in try-catch so that isStreamingProvider
    // is ALWAYS reset to false, even if an unexpected error occurs here.
    // Without this, a stuck streaming flag would permanently block new messages.
    try {
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
    } catch (e, s) {
      debugPrint('[ChatPage] post-stream error: $e\n$s');
    } finally {
      _streamingMsgId = null;
      ref.read(isStreamingProvider.notifier).state = false;
      _cancelledByUser = false;
      if (mounted) setState(() {});
    }

    await _saveMessages();
  }

  void _confirmRetryOrEdit(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    if (ref.read(isStreamingProvider)) return;

    final msg = _history[index];
    final isUser = msg.role == 'user';
    final newerMessagesExist = index < _history.length - 1;

    showRetryEditConfirmDialog(
      context: context,
      isUser: isUser,
      newerMessagesExist: newerMessagesExist,
      onEdit: () => _editUserMessage(messageId),
      onRetry: () => _retryAssistantMessage(messageId),
    );
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
        // Safety: keep pagination index within bounds
        _loadedUpToIndex = _loadedUpToIndex.clamp(0, _history.length);
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

    showEditMessageDialog(
      context: context,
      currentText: msg.content,
    ).then((newText) {
      if (newText != null && newText.isNotEmpty && mounted) {
        _editUserMessageWithText(messageId, newText);
      }
    });
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
        // Safety: keep pagination index within bounds
        _loadedUpToIndex = _loadedUpToIndex.clamp(0, _history.length);
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
        // Safety: keep pagination index within bounds
        _loadedUpToIndex = _loadedUpToIndex.clamp(0, _history.length);
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
      // Adjust pagination state: if the deleted message was before the loaded
      // region, shift _loadedUpToIndex to keep it pointing at the same messages.
      if (index < _loadedUpToIndex && _loadedUpToIndex > 0) {
        _loadedUpToIndex = max(0, _loadedUpToIndex - 1);
      }
    });

    final msgToRemove = _controller?.messages.where((m) => m.id == messageId).firstOrNull;
    if (msgToRemove != null) {
      await _controller?.removeMessage(msgToRemove);
    }

    _saveMessages();
  }

  void _confirmDeleteMessage(String messageId) {
    showDeleteConfirmDialog(
      context: context,
      onDelete: () => _deleteMessage(messageId),
    );
  }

  Widget _buildMessageAttachmentPreview(Attachment att) {
    return MessageAttachmentPreview(
      attachment: att,
      onTap: () => _showAttachmentPreview(att),
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
      _showImagePreview(att, data);
    } else {
      _showFileInfoPreview(att);
    }
  }

  /// Full-screen dark dialog with pinch-to-zoom image preview.
  void _showImagePreview(Attachment att, Uint8List data) {
    showImagePreviewDialog(
      context: context,
      fileName: att.fileName,
      data: data,
    );
  }

  /// Full-screen dark preview for non-image files (documents, audio, video).
  /// Shows file icon, name, type, size, and action buttons.
  void _showFileInfoPreview(Attachment att) {
    showFileInfoPreviewDialog(
      context: context,
      attachment: att,
    );
  }

  void _stopStreaming() {
    _cancelledByUser = true;
    try {
      _adapter.cancel();
    } catch (e) {
      debugPrint('[ChatPage] cancel error: $e');
    }
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
      _searchMode = SearchMode.current;
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = 0;
      _searchTextController.clear();
    });
  }

  Widget _buildModeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _openGlobalSearch() {
    Navigator.of(context, rootNavigator: true).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const MessageSearchPage()),
    ).then((result) async {
      if (!mounted || result == null) return;
      final conversationId = result['conversationId'] as String?;
      final query = result['query'] as String?;
      if (conversationId == null || query == null || query.isEmpty) return;

      // Step 1: Save current conversation's messages first (before switching)
      await _saveMessages();
      if (!mounted) return;

      // Step 2: If switching to a different conversation, select it.
      // The activeConversationIdProvider listener schedules
      // _loadConversationMessages in a post-frame callback, which clears
      // search state. Schedule search activation in a subsequent
      // post-frame callback so it runs AFTER that load completes.
      final activeId = ref.read(activeConversationIdProvider);
      if (conversationId != activeId) {
        ref.read(conversationsProvider.notifier).selectConversation(conversationId);
      }

      // Step 3: Schedule search activation for the next frame, after
      // _loadConversationMessages has completed its synchronous part.
      // Note: Setting _searchTextController.text triggers onChanged →
      // _performSearch internally via the controller listener, so the
      // explicit _performSearch call below is redundant but kept for
      // safety in case the listener doesn't fire as expected.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _searchTextController.text = query;
          _isSearching = true;
        });
        _performSearch(query);
      });
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

    showJsonInspectionDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markdownConfig = buildMarkdownConfig(isDark: isDark);
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
                  // Back button when inside nested navigator and not first route
                  if (Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
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
                    onPressed: () => setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _searchMode = SearchMode.current;
                    }),
                  ),
                  // ── Model selector ──
                  if (adapterConfigured) _buildModelSelector(),
                  // ── Reasoning toggle ──
                  if (adapterConfigured)
                    Consumer(
                      builder: (context, ref, child) {
                        final reasoningEnabled = ref.watch(reasoningEnabledProvider);
                        return IconButton(
                          icon: Icon(
                            Icons.psychology,
                            color: reasoningEnabled
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          tooltip: reasoningEnabled ? '推理已开启' : '推理',
                          onPressed: () {
                            final newValue = !reasoningEnabled;
                            ref.read(reasoningEnabledProvider.notifier).state = newValue;
                            SharedPreferences.getInstance().then((prefs) =>
                                prefs.setBool('reasoning_enabled', newValue));
                          },
                        );
                      },
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Search field + nav controls
                    Row(
                      children: [
                        Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _searchTextController,
                              autofocus: true,
                              onChanged: (query) {
                                if (_searchMode == SearchMode.current) {
                                  _performSearch(query);
                                } else if (query.isNotEmpty) {
                                  // Global mode: defer to full search page
                                  _openGlobalSearch();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: _searchMode == SearchMode.current
                                    ? '搜索当前对话...'
                                    : '搜索所有对话...',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        if (_searchMode == SearchMode.current && _searchMatches.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${_currentMatchIndex + 1}/${_searchMatches.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (_searchMode == SearchMode.current) ...[
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
                        ],
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
                    // Row 2: Mode toggle chips
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildModeChip(
                          label: '当前对话',
                          selected: _searchMode == SearchMode.current,
                          onTap: () {
                            if (_searchMode != SearchMode.current) {
                              setState(() {
                                _searchMode = SearchMode.current;
                                _searchTextController.clear();
                                _performSearch('');
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildModeChip(
                          label: '所有对话',
                          selected: _searchMode == SearchMode.global,
                          onTap: () {
                            if (_searchMode != SearchMode.global) {
                              setState(() => _searchMode = SearchMode.global);
                              _openGlobalSearch();
                            }
                          },
                        ),
                      ],
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
                        chatAnimatedListBuilder: (context, itemBuilder) =>
                            ChatAnimatedList(
                          itemBuilder: itemBuilder,
                          onEndReached: _loadMoreMessages,
                        ),
                        composerBuilder: (context) => ChatComposerWidget(
                          onSend: _onMessageSend,
                          onStop: _stopStreaming,
                          mcpTools: _adapter.getAllToolDefinitions(),
                          enabledTools: ref.watch(enabledToolNamesProvider),
                          onEnabledToolsChanged: (tools) {
                            ref.read(enabledToolNamesProvider.notifier).state = tools;
                          },
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
                                      ReasoningSection(reasoningText: reasoningText),
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
                                      // Merge consecutive TextSegments to avoid visual breaks
                                      // between arbitrary streaming chunk boundaries (e.g.
                                      // throttle intervals). Each text block renders in a
                                      // single MarkdownWidget for continuity.
                                      ...mergeConsecutiveTextSegments(segments).map((seg) => switch (seg) {
                                            TextSegment s => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: hasSearchMatch
                                                ? _buildHighlightedText(s.text, message.id)
                                                : MarkdownWidget(
                                                    data: s.text,
                                                    selectable: true,
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    config: markdownConfig,
                                                    markdownGenerator: markdownGenerator,
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
                                        config: markdownConfig,
                                        markdownGenerator: markdownGenerator,
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
                                      height: 120,
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
                                    ActionButton(
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
                                      ActionButton(
                                        icon: Icons.refresh,
                                        tooltip: '重试',
                                        onPressed: () =>
                                            _confirmRetryOrEdit(message.id),
                                      )
                                    else
                                      ActionButton(
                                        icon: Icons.edit_outlined,
                                        tooltip: '编辑',
                                        onPressed: () =>
                                            _showEditMessageDialog(message.id),
                                      ),
                                    const SizedBox(width: 2),
                                    if (_developerMode && isAi && _history.any((m) => m.id == message.id && (m.rawRequest != null || m.rawResponse != null)))
                                      ActionButton(
                                        icon: Icons.code,
                                        tooltip: 'JSON 审查',
                                        onPressed: () => _showJsonInspection(message.id),
                                      ),
                                    const SizedBox(width: 2),
                                    ActionButton(
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

  void _showErrorDetailDialog(BuildContext context, String messageId) {
    final chatMsg = _history.where((m) => m.id == messageId).firstOrNull;
    if (chatMsg == null) return;

    showErrorDetailDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
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
