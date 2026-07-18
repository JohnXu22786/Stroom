import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/markdown_extensions.dart';
import '../widgets/message_attachment_preview.dart';
import '../services/attachment_storage.dart';

import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart';
import '../services/app_log_service.dart';
import '../services/chat_adapter.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_stream_provider.dart';
import '../providers/provider_config.dart';
import '../providers/assistant_provider.dart' show selectedAssistantProvider;
import '../widgets/llm/jumping_dots.dart';
import '../widgets/llm/tool_call_card.dart';
import 'message_search_page.dart';
import 'provider_config_page.dart';

import 'chat/chat_types.dart';
import 'chat/utils/format_chat_error.dart';

export 'chat/utils/format_chat_error.dart' show formatChatErrorMessage;
import 'chat/widgets/action_button.dart';
import 'chat/widgets/reasoning_section.dart';
import 'chat/dialogs/error_detail_dialog.dart' show showDataDetailDialog;
import 'chat/dialogs/confirm_dialog.dart';
import 'chat/dialogs/image_preview_dialog.dart';
import 'chat/dialogs/file_info_dialog.dart';
import 'chat/dialogs/json_inspection_dialog.dart';
import 'chat/dialogs/audio_preview_dialog.dart';
import 'chat/dialogs/video_preview_dialog.dart';
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

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  InMemoryChatController? _controller;
  late final User _currentUser;
  late final User _aiUser;
  late final ChatAdapter _adapter;
  final List<ChatMessage> _history = [];
  int _selectedModelIndex = 0;

  /// Saved model display name order for drag-sort persistence.
  List<String>? _savedModelOrder;
  bool _cancelledByUser = false;

  /// Tracks streaming state locally so dispose() can check it without
  /// calling ref.read() (which throws after the widget is marked disposed).
  bool _isStreamingActive = false;
  final Map<String, List<String>> _reasoningContents = {};

  /// Tracks whether reasoning has completed for a given message.
  /// Set to true when the first [TextEvent] arrives after at least one
  /// [ReasoningEvent] has been received for the same message.
  /// Used to determine the reasoning button label during streaming:
  /// - false + streaming = "推理中" (reasoning still in progress)
  /// - true + streaming = "推理过程" (reasoning done, text being streamed)
  final Map<String, bool> _isReasoningCompletedForMsg = {};
  final Map<String, List<MessageSegment>> _chatSegments = {};

  /// Tracks how many characters of [_history] text have been rendered as
  /// [TextSegment] entries in [_chatSegments] for each streaming message.
  /// Used for incremental markdown rendering: only new text chunks are
  /// added as new [TextSegment]s, avoiding full re-render of the entire
  /// accumulated content on each throttle cycle.
  final Map<String, int> _streamingRenderedLengths = {};
  String? _streamingMsgId;

  // ── Auto-scroll / scroll-to-bottom state ──
  /// Whether auto-scrolling is enabled. Initially false — user must click
  /// the scroll-to-bottom button to enable it. Disabled when user scrolls up.
  bool _autoScrollEnabled = false;

  /// Whether the scroll-to-bottom button should be visible.
  bool _showScrollToBottomButton = false;

  /// Scroll controller for the chat message list.
  late ScrollController _chatScrollController;

  /// Tracks whether the soft keyboard was visible in the previous metrics
  /// change, so [didChangeMetrics] can detect show/hide transitions.
  bool _wasKeyboardVisible = false;

  /// Captured scroll position before the keyboard opened, so it can be
  /// restored when the keyboard is dismissed.
  double? _lastScrollPositionBeforeKeyboard;

  bool _isSearching = false;
  SearchMode _searchMode = SearchMode.current;
  String _searchQuery = '';
  final List<SearchMatch> _searchMatches = [];
  int _currentMatchIndex = 0;
  final TextEditingController _searchTextController = TextEditingController();
  final Map<String, GlobalKey> _messageKeys = {};

  bool _developerMode = false;
  final Map<String, bool> _expandedErrors = {};

  // ── Edit mode state ──
  /// When set, the composer enters edit mode for this message.
  String? _editingMessageId;

  /// The text of the message being edited.
  String? _editingMessageText;

  /// The original attachments of the message being edited.
  List<Attachment>? _editingMessageAttachments;

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
    WidgetsBinding.instance.addObserver(this);
    _currentUser = User(id: 'user1', name: 'You');
    _aiUser = User(id: 'ai1', name: 'Stroom');
    _adapter = ChatAdapter();
    _controller = InMemoryChatController();
    _chatScrollController = ScrollController();
    _chatScrollController.addListener(_onChatScroll);

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_isStreamingActive) {
      // Only cancel the adapter when NOT streaming. If streaming is active,
      // the adapter must stay alive so the stream can continue in the
      // background and save results when it completes.
      _adapter.cancel();
      _adapter.dispose();
    }
    _controller?.dispose();
    _searchTextController.dispose();
    _chatScrollController.removeListener(_onChatScroll);
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isNowVisible = bottomInset > 100;

    if (isNowVisible && !_wasKeyboardVisible) {
      // Keyboard just appeared — save scroll position and jump to bottom
      // immediately so the input area and latest message are visible.
      if (_chatScrollController.hasClients) {
        _lastScrollPositionBeforeKeyboard =
            _chatScrollController.position.pixels;
      }
      _scrollToBottom();
    } else if (!isNowVisible && _wasKeyboardVisible) {
      // Keyboard just disappeared — restore the scroll position that was
      // captured before the keyboard opened.
      _restoreScrollPositionAfterKeyboard();
    }
    _wasKeyboardVisible = isNowVisible;
  }

  /// Scrolls the chat list to the bottom-most message immediately when the
  /// keyboard opens, keeping the input area and latest message visible.
  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_chatScrollController.hasClients) {
          _scrollToBottom();
        }
      });
    }
  }

  /// Restores the scroll position that was captured before the keyboard
  /// opened, so the user returns to where they were reading.
  void _restoreScrollPositionAfterKeyboard() {
    final savedPos = _lastScrollPositionBeforeKeyboard;
    _lastScrollPositionBeforeKeyboard = null;
    if (savedPos == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chatScrollController.hasClients) {
        final maxScroll = _chatScrollController.position.maxScrollExtent;
        _chatScrollController.jumpTo(savedPos.clamp(0.0, maxScroll));
      }
    });
  }

  /// Handles chat list scroll events to track auto-scroll state.
  void _onChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final maxScroll = _chatScrollController.position.maxScrollExtent;
    final currentScroll = _chatScrollController.position.pixels;
    final isAtBottom = (maxScroll - currentScroll) <= 80;

    if (isAtBottom) {
      // At bottom — user sees latest messages
      if (_showScrollToBottomButton || (!_autoScrollEnabled)) {
        setState(() {
          _showScrollToBottomButton = false;
          // Enable auto-scroll when user is at bottom (so new messages
          // automatically keep them at the bottom).
          if (_chatScrollController.hasClients &&
              _chatScrollController.position.maxScrollExtent > 0) {
            _autoScrollEnabled = true;
          }
        });
      }
    } else {
      // Scrolled up — disable auto-scroll and show button
      if (!_showScrollToBottomButton || _autoScrollEnabled) {
        setState(() {
          _autoScrollEnabled = false;
          _showScrollToBottomButton = true;
        });
      }
    }
  }

  /// Called when the user taps the scroll-to-bottom button.
  /// Enables auto-scroll and scrolls to the bottom.
  void _onScrollToBottomTap() {
    _scrollToBottom();
    setState(() {
      _autoScrollEnabled = true;
      _showScrollToBottomButton = false;
    });
  }

  /// Restores the streaming message UI when the page is re-initialized after
  /// having been disposed during active streaming (user navigated away during
  /// generation and came back). Re-inserts the streaming message placeholder
  /// into the controller and restores accumulated content providers so the UI
  /// shows the loading indicator and any partial text already received.
  void _restoreStreamingState() {
    if (!ref.read(isStreamingProvider)) return;
    final msgId = ref.read(streamingMsgIdProvider);
    if (msgId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fullReply = ref.read(streamingFullReplyProvider);
      final reasoningSections = ref.read(streamingReasoningSectionsProvider);
      _streamingMsgId = msgId;
      _chatSegments[msgId] = [];
      _streamingRenderedLengths[msgId] = 0;
      // Restore reasoning sections from provider so the buttons show up
      if (reasoningSections.isNotEmpty) {
        _reasoningContents[msgId] = List.of(reasoningSections);
      }

      final placeholder = Message.textStream(
        id: msgId,
        authorId: _aiUser.id,
        createdAt: DateTime.now(),
        streamId: msgId,
      );
      _controller?.insertMessage(placeholder).then((_) {
        if (!mounted) return;
        // If we already have content, update the message to show it
        if (fullReply.isNotEmpty) {
          _controller?.updateMessage(
            placeholder,
            Message.text(
              id: msgId,
              authorId: _aiUser.id,
              text: fullReply,
              createdAt: DateTime.now(),
            ),
          );
          // If first token already received, the streaming message
          // content will be displayed via textMessageBuilder reading
          // message.text. The JumpingDots indicator is hidden because
          // isWaitingForFirstToken checks streamingHasFirstTokenProvider.
        }
        setState(() {});
      });
    });
  }

  Future<void> _initialize() async {
    await AppLogService.info('ChatPage', '开始初始化聊天页面');
    _configureAdapter();
    // Initialize built-in tools (HTTP tools) first — independent of MCP
    // server connectivity. This ensures HTTP tools (brave_web_search,
    // bocha_web_search, querit_search, searxng_search) are always
    // available in the tool list even if MCP servers are unreachable.
    final entriesState = ref.read(providerEntriesProvider);
    _adapter.initializeBuiltinTools(entriesState);
    // Then discover MCP server tools (SSE / stdio) dynamically.
    // MCP discovery failures don't affect already-registered built-in tools.
    try {
      await AppLogService.info('ChatPage',
          '开始初始化 MCP 服务器，当前有 ${entriesState.entries.length} 个供应商配置');
      await _adapter.initializeMcpServers(entriesState);
      await AppLogService.info('ChatPage', 'MCP 服务器初始化完成');
    } finally {
      // Rebuild UI so the tool panel reflects the newly discovered MCP tools.
      // Must check mounted because the async gap may outlive the widget.
      if (mounted) setState(() {});
      // Do NOT auto-enable all tools. All tools default to OFF.
      // Per-conversation enabled tools are restored in _loadConversationMessages.
      // Using finally ensures MCP discovery errors don't prevent the rest.
    }
    // Restore saved model selection and restore per-model settings
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      _restoreSavedModelSelection(prefs);
    });
    await _loadConversationMessages();
    // Restore streaming state if a stream was active when the page was
    // previously disposed (user navigated away during generation and then
    // came back). This re-inserts the streaming message placeholder with
    // accumulated content so the UI shows the loading indicator and any
    // partial text that has already been received.
    _restoreStreamingState();
    await AppLogService.info('ChatPage', '聊天页面初始化完成');
  }

  /// Loads the previous page of older messages and prepends them to the
  /// chat controller. Called by [ChatAnimatedList.onEndReached] when the user
  /// scrolls near the top of the message list.
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    _isLoadingMore = true;
    if (mounted) setState(() {});

    try {
      final newStart =
          _loadedUpToIndex >= _pageSize ? _loadedUpToIndex - _pageSize : 0;
      final batchMessages = _history.sublist(newStart, _loadedUpToIndex);

      // Convert ChatMessage list to flutter_chat_ui Message list
      final msgs = batchMessages
          .map(
            (m) => Message.text(
              id: m.id,
              authorId: m.role == 'user' ? _currentUser.id : _aiUser.id,
              text: m.content,
              createdAt: m.createdAt,
            ),
          )
          .toList();

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
    _recalculateSelectedModelIndex();
    if (mounted) setState(() {});
  }

  /// Recalculates [_selectedModelIndex] based on the adapter's currently
  /// selected model, mapped through the display order (saved drag-sort).
  void _recalculateSelectedModelIndex() {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final idx = models.indexWhere(
      (m) =>
          m.configIndex == _adapter.currentConfigIndex &&
          m.modelIndex == _adapter.currentModelIndex,
    );
    if (idx >= 0) {
      final selectedName = models[idx].displayName;
      // Map to display order index so the panel highlights the right model
      final displayNames = _getModelNames();
      final displayIdx = displayNames.indexOf(selectedName);
      _selectedModelIndex = displayIdx >= 0 ? displayIdx : 0;
    } else {
      _selectedModelIndex = 0;
    }
  }

  Future<void> _loadConversationMessages() async {
    try {
      final activeId = ref.read(activeConversationIdProvider);
      await AppLogService.info(
          'ChatPage', '开始加载对话消息, activeConversationId=$activeId');
      if (activeId == null) {
        await AppLogService.warning(
            'ChatPage', 'activeConversationId 为 null，跳过加载对话消息');
        return;
      }

      final convs = ref.read(conversationsProvider);
      await AppLogService.info('ChatPage', '当前共有 ${convs.length} 个对话');
      final conv = convs.where((c) => c.id == activeId).firstOrNull;
      if (conv == null) {
        await AppLogService.warning(
            'ChatPage', '未找到 activeConversationId=$activeId 对应的对话');
      }

      // Restore per-conversation enabled MCP/built-in tool names.
      // If the conversation has saved tool preferences, use them.
      // Otherwise, default to ALL available tools enabled so that built-in
      // remote SSE MCP providers (and user-added MCPs) are immediately
      // visible in the chat page's tool list without requiring the user to
      // manually toggle each one on. Users can still opt-out specific tools
      // via the "可用工具" panel — the toggled-off state is then persisted
      // into conv.enabledMcpToolNames + conv.hasExplicitEnabledMcpTools on
      // the next save.
      final convEnabled = (conv != null)
          ? Set<String>.from(conv.enabledMcpToolNames)
          : <String>{};
      final hasExplicitPrefs =
          conv?.hasExplicitEnabledMcpTools ?? false;
      ref.read(enabledToolNamesProvider.notifier).state =
          resolveEnabledToolNames(
        allTools: _adapter.getAllToolDefinitions(),
        savedEnabledNames: convEnabled,
        hasExplicitSavedPrefs: hasExplicitPrefs,
      );
      if (conv == null || conv.messages.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      _history.clear();
      _chatSegments.clear();
      _reasoningContents.clear();
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

      // Clear edit mode state when switching conversations — the message
      // being edited no longer exists in the new conversation.
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;

      // Initialize pagination state: reset any in-flight load and
      // let the loop below set the correct loaded index.
      _isLoadingMore = false;

      final newCtrl = InMemoryChatController();
      _controller = newCtrl;
      // Load all messages into _history (needed for full context in API calls
      // and search), but only insert the last _pageSize messages into the
      // controller for display (lazy loading).
      final msgCount = conv.messages.length;
      await AppLogService.info('ChatPage', '开始加载 $msgCount 条消息到 _history');
      for (final msg in conv.messages) {
        _history.add(msg);
        // Restore reasoning content from persisted ChatMessage
        if (msg.reasoningContent != null && msg.reasoningContent!.isNotEmpty) {
          _reasoningContents[msg.id] = [msg.reasoningContent!];
        }
      }
      _loadedUpToIndex =
          _history.length >= _pageSize ? _history.length - _pageSize : 0;
      await AppLogService.info(
          'ChatPage',
          '消息加载完成: _history 共 ${_history.length} 条, '
              'loadedUpToIndex=$_loadedUpToIndex');
      for (var i = _loadedUpToIndex; i < _history.length; i++) {
        final msg = _history[i];
        await _controller?.insertMessage(
          Message.text(
            id: msg.id,
            authorId: msg.role == 'user' ? _currentUser.id : _aiUser.id,
            text: msg.content,
            createdAt: msg.createdAt,
          ),
        );
      }
      await AppLogService.info(
          'ChatPage', '控制器消息插入完成，共 ${_controller?.messages.length ?? 0} 条');
      if (mounted) setState(() {});
    } catch (e, s) {
      debugPrint('[ChatPage] _loadConversationMessages error: $e\n$s');
      await AppLogService.error('ChatPage', '加载对话消息失败', e, s);
    }
  }

  /// Saves the currently enabled tool names to the active conversation.
  /// This ensures per-conversation tool preferences persist across sessions.
  void _saveEnabledToolsToConversation() {
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;
    final enabledTools = ref.read(enabledToolNamesProvider);
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == convId).firstOrNull;
    if (conv == null) return;
    // Only persist if the set actually changed to avoid unnecessary writes
    if (conv.enabledMcpToolNames.length != enabledTools.length ||
        !conv.enabledMcpToolNames.containsAll(enabledTools)) {
      // We need to update the conversation's enabledMcpToolNames.
      // Since Conversation is mutable, we update it in-place and let
      // the existing _persist mechanism handle the save.
      // Access the notifier to trigger persistence.
      ref.read(conversationsProvider.notifier).updateEnabledTools(
            convId,
            enabledTools,
          );
    }
  }

  Future<void> _saveMessages({String? capturedConvId}) async {
    try {
      final convId = capturedConvId ?? ref.read(activeConversationIdProvider);
      if (convId == null) return;
      await ref.read(conversationsProvider.notifier).updateMessages(convId, [
        ..._history,
      ]);
    } catch (e, s) {
      // Fallback: save directly to SharedPreferences if the notifier is
      // unavailable (e.g. during background streaming after page disposal).
      debugPrint('_saveMessages via notifier failed: $e\n$s');
      try {
        final prefs = await SharedPreferences.getInstance();
        final allJson = prefs.getString('conversations');
        if (allJson == null) return;
        final convId = capturedConvId ?? ref.read(activeConversationIdProvider);
        if (convId == null) return;
        final decoded = jsonDecode(allJson);
        if (decoded is! List) return;
        final list = decoded.cast<Map<String, dynamic>>();
        final conv = list.where((c) => c['id'] == convId).firstOrNull;
        if (conv == null) return;
        conv['messages'] = _history.map((m) => m.toMap()).toList();
        conv['updatedAt'] = DateTime.now().toIso8601String();
        await prefs.setString('conversations', jsonEncode(list));
      } catch (e2, s2) {
        debugPrint('_saveMessages fallback also failed: $e2\n$s2');
      }
    }
  }

  void _navigateToProviderConfig() {
    final entriesState = ref.read(providerEntriesProvider);
    final llmEntry =
        entriesState.entries.where((e) => e.type == 'llm').firstOrNull;
    if (llmEntry != null) {
      Navigator.of(context, rootNavigator: true)
          .push(
        MaterialPageRoute(
          builder: (_) => ProviderConfigPage(entryId: llmEntry.id),
        ),
      )
          .then((_) {
        if (mounted) _configureAdapter();
      });
    }
  }

  Future<void> _onMessageSend(String text, List<Attachment> attachments) async {
    if (ref.read(isStreamingProvider)) return;

    String? convId = ref.read(activeConversationIdProvider);
    await AppLogService.info(
        'ChatPage',
        '用户发送消息, convId=$convId, text长度=${text.length}, '
            'attachments=${attachments.length}');
    if (convId == null) {
      await AppLogService.info('ChatPage', '无活跃对话，创建新对话');
      ref.read(conversationsProvider.notifier).createConversation();
      convId = ref.read(activeConversationIdProvider);
      await AppLogService.info('ChatPage', '新对话已创建: $convId');
    }

    // Save the current enabled tools to the conversation before sending.
    // This ensures the tool preferences are persisted even if the user
    // switches conversations or navigates away during streaming.
    _saveEnabledToolsToConversation();

    final userMsgId = 'u${DateTime.now().millisecondsSinceEpoch}';

    _history.add(
      ChatMessage(
        role: 'user',
        content: text,
        id: userMsgId,
        attachments: attachments,
      ),
    );
    await _controller?.insertMessage(
      Message.text(
        id: userMsgId,
        authorId: _currentUser.id,
        text: text,
        createdAt: DateTime.now(),
      ),
    );

    await _startStreaming(text, capturedConvId: convId);
  }

  Future<void> _startStreaming(String text, {String? capturedConvId}) async {
    if (ref.read(isStreamingProvider)) return;

    await AppLogService.info(
        'ChatPage', '开始流式请求, capturedConvId=$capturedConvId');
    ref.read(isStreamingProvider.notifier).state = true;
    _isStreamingActive = true;
    if (mounted) setState(() {});
    _cancelledByUser = false;

    final aiMsgId = 'a${DateTime.now().millisecondsSinceEpoch}';
    _streamingMsgId = aiMsgId;
    _chatSegments[aiMsgId] = [];
    _streamingRenderedLengths[aiMsgId] = 0;
    // Initialize reasoning sections as empty list, only populated when
    // actual reasoning events arrive. This prevents showing an empty
    // "推理过程" button when no reasoning content exists.
    _reasoningContents[aiMsgId] = [];
    // Persist streaming message ID in provider so it survives page disposal
    ref.read(streamingMsgIdProvider.notifier).state = aiMsgId;

    final placeholder = Message.textStream(
      id: aiMsgId,
      authorId: _aiUser.id,
      createdAt: DateTime.now(),
      streamId: aiMsgId,
    );
    if (mounted) {
      await _controller?.insertMessage(placeholder);
    }

    String fullReply = '';
    String reasoningBuffer = '';
    DateTime lastUpdate = DateTime.now();
    DateTime lastReasoningUpdate = DateTime.now();
    const minInterval = Duration(milliseconds: 50);
    const reasoningMinInterval = Duration(milliseconds: 100);

    /// Whether the first reasoning update has been applied to the UI.
    /// Used to ensure the reasoning button appears on the very first
    /// ReasoningEvent even when throttled by [reasoningMinInterval].
    bool hasShownFirstReasoning = false;
    // Reset reasoning providers at start of new streaming session.
    // Initialize sections as empty list — they are populated on first
    // ReasoningEvent (not with a placeholder empty string).
    ref.read(streamingReasoningProvider.notifier).state = '';
    ref.read(streamingReasoningSectionsProvider.notifier).state = [];
    bool hasReceivedFirstToken = false;
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;

    void updateMessage(String content) {
      // Skip UI update if the page was disposed (user navigated away during
      // streaming). The streaming continues in the background and will save
      // the completed result via _saveMessages() when it finishes.
      if (!mounted) return;
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

    Object? streamError;
    try {
      // Merge built-in tools with MCP tools
      final allTools = _adapter.getAllToolDefinitions();
      final enabledTools = ref.read(enabledToolNamesProvider);
      // All tools uniformly respect the user's toggle state from the settings panel.
      final filteredTools =
          allTools.where((t) => enabledTools.contains(t.name)).toList();

      // Pass assistant prompt and settings to adapter
      final selectedAssistant = ref.read(selectedAssistantProvider);
      if (selectedAssistant != null) {
        _adapter.setAssistantPrompt(selectedAssistant.prompt);
        _adapter.setAssistantSettings(selectedAssistant.settings);
        _adapter.setAssistantCustomParams(
          selectedAssistant.settings.customParameters,
        );
      } else {
        _adapter.setAssistantPrompt(null);
        _adapter.setAssistantSettings(null);
        _adapter.setAssistantCustomParams(null);
      }

      final stream = _adapter.sendStreamWithTools(
        text,
        history: _history,
        reasoning: ref.read(reasoningEnabledProvider),
        reasoningEffort: ref.read(reasoningEffortProvider),
        reasoningParamValues: ref.read(reasoningParamValuesProvider),
        tools: filteredTools,
      );

      await for (final event in stream) {
        if (_cancelledByUser) break;

        switch (event) {
          case TextEvent e:
            if (!hasReceivedFirstToken) {
              hasReceivedFirstToken = true;
              ref.read(streamingHasFirstTokenProvider.notifier).state = true;
              if (mounted) setState(() {});
            }
            // Mark reasoning as completed when text content starts arriving
            // after reasoning content has been received. This changes the
            // reasoning button label from "推理中" to "推理过程" during
            // streaming (Issue 1 fix).
            if (reasoningBuffer.isNotEmpty &&
                _isReasoningCompletedForMsg[aiMsgId] != true) {
              _isReasoningCompletedForMsg[aiMsgId] = true;
            }
            fullReply += e.text;
            final now = DateTime.now();
            if (now.difference(lastUpdate) >= minInterval) {
              lastUpdate = now;
              // Update provider so streaming state survives page disposal
              ref.read(streamingFullReplyProvider.notifier).state = fullReply;
              // Keep the controller updated so the Chat widget re-renders
              // the streaming message. The textMessageBuilder will read
              // from _chatSegments (incremental segments) for the actual
              // markdown rendering, not from message.text directly.
              if (mounted) {
                updateMessage(fullReply);
              }
              // Incremental rendering: add only the new text chunk as a
              // TextSegment, so MarkdownWidget only parses new content
              // instead of re-rendering the entire accumulated text.
              final renderedLen = _streamingRenderedLengths[aiMsgId]!;
              if (fullReply.length > renderedLen) {
                final newChunk = fullReply.substring(renderedLen);
                final segments = _chatSegments[aiMsgId]!;
                final lastSeg = segments.isNotEmpty ? segments.last : null;
                if (lastSeg is TextSegment && _hasUnclosedMath(lastSeg.text)) {
                  // Merge into the last segment to avoid splitting math
                  // formulas ($...$ or $$...$$) across segment boundaries.
                  // The merged segment's MarkdownWidget will re-parse the
                  // combined text and can render the now-complete formula.
                  segments[segments.length - 1] = TextSegment(
                    lastSeg.text + newChunk,
                  );
                } else {
                  segments.add(TextSegment(newChunk));
                }
                _streamingRenderedLengths[aiMsgId] = fullReply.length;
              }
            }

          case ReasoningEvent e:
            // Accumulate reasoning text incrementally and update providers
            // so the reasoning panel can display streaming content in real time.
            reasoningBuffer += e.text;
            // Always update _reasoningContents immediately so the button
            // appears on the very first reasoning event, regardless of
            // the throttle interval. Previously the throttle could block
            // the first event, causing the reasoning button to not appear
            // during streaming (Issue 2 fix).
            final sections = [...ref.read(streamingReasoningSectionsProvider)];
            if (sections.isNotEmpty) {
              sections[sections.length - 1] = reasoningBuffer;
            } else {
              sections.add(reasoningBuffer);
            }
            _reasoningContents[aiMsgId] = sections;
            final now = DateTime.now();
            if (now.difference(lastReasoningUpdate) >= reasoningMinInterval) {
              lastReasoningUpdate = now;
              hasShownFirstReasoning = true;
              ref.read(streamingReasoningProvider.notifier).state =
                  reasoningBuffer;
              ref.read(streamingReasoningSectionsProvider.notifier).state =
                  sections;
              if (mounted) setState(() {});
            } else if (!hasShownFirstReasoning && mounted) {
              // First reasoning event(s): ensure the button appears
              // even if throttled, so the reasoning button is visible
              // immediately when streaming reasoning content.
              hasShownFirstReasoning = true;
              ref.read(streamingReasoningSectionsProvider.notifier).state =
                  sections;
              ref.read(streamingReasoningProvider.notifier).state =
                  reasoningBuffer;
              if (mounted) setState(() {});
            }

          case ReasoningSectionEndEvent():
            // Finalize current reasoning section and start a new empty one
            // for the next tool call round.
            // Read from _reasoningContents (not the provider) to get the
            // latest accumulated content, since the provider is throttled
            // and may hold stale data between throttle intervals.
            final sections = List<String>.from(
              _reasoningContents[aiMsgId] ?? [],
            );
            sections.add('');
            ref.read(streamingReasoningSectionsProvider.notifier).state =
                sections;
            _reasoningContents[aiMsgId] = sections;
            if (mounted) setState(() {});

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
      streamError = e;
      if (!_cancelledByUser) {
        debugPrint('[ChatPage] streaming error: $e\n$s');
        await AppLogService.error('ChatPage', '流式请求异常', e, s);
        final errorMsg = _formatErrorMessage(e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg.replaceAll('错误: ', '').split('\n')[0]),
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
      }
    } finally {
      // Always capture request/response raw data for ALL messages
      // (not just errors), so the "view raw data" button works.
      // This runs regardless of _cancelledByUser or error vs. success.
      try {
        final reqBody = _adapter.lastRequestBody;
        final headers = _adapter.lastRequestHeaders;
        final url = _adapter.lastRequestUrl;
        if (reqBody != null || headers != null || url != null) {
          rawRequestCapture = {};
          if (url != null) rawRequestCapture['url'] = url;
          if (headers != null) rawRequestCapture['headers'] = headers;
          if (reqBody != null) rawRequestCapture['body'] = reqBody;
        }
        final respData = _adapter.lastResponseData;
        final statusCode = _adapter.lastResponseStatusCode;
        final respHeaders = _adapter.lastResponseHeaders;
        if (respData != null || statusCode != null || respHeaders != null) {
          rawResponseCapture = {};
          if (statusCode != null) rawResponseCapture['statusCode'] = statusCode;
          if (respHeaders != null) rawResponseCapture['headers'] = respHeaders;
          if (respData != null) rawResponseCapture['data'] = respData;
        } else if (streamError is Exception) {
          // For network errors with no HTTP response, capture error string
          rawResponseCapture = {'error': streamError.toString()};
        }
      } catch (_) {}
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
        if (seg is ToolCallSegment &&
            seg.data.status == ToolCallStatus.running) {
          _chatSegments[aiMsgId]![i] = ToolCallSegment(
            seg.data.copyWith(
              status: ToolCallStatus.error,
              result: 'Cancelled',
            ),
          );
        }
      }
      // Final update — ensure last chunk is shown.
      // Also update when user cancelled (stopped) with no content, to
      // replace the streaming placeholder with a regular message so the
      // CircularProgressIndicator in textStreamMessageBuilder is removed.
      if (fullReply.isNotEmpty ||
          (_cancelledByUser && _streamingMsgId != null)) {
        updateMessage(fullReply);
      }
      // NOTE: We intentionally do NOT clear _chatSegments here.
      // mergeConsecutiveTextSegments (used in textMessageBuilder) already
      // merges consecutive TextSegments during rendering, so there are no
      // visual artifacts from split-throttle-boundary segments. Clearing
      // would cause MarkdownWidget to re-parse the ENTIRE long message at
      // once, risking OOM/flash-crash with long responses.
      // _chatSegments is eventually cleaned up when the message is deleted,
      // edited, or retried (see _deleteMessage, _editUserMessageWithText,
      // _retryAssistantMessage).
      // Always capture reasoning content from the response.
      // The SSE parser now yields reasoning_content unconditionally;
      // the reasoning toggle only controls whether the params are SENT.
      reasoningBuffer = _adapter.reasoningContent;
      ref.read(streamingReasoningProvider.notifier).state = reasoningBuffer;
      // Update the last reasoning section with final content.
      // Only add a new section if reasoning content exists, to avoid
      // creating an empty [''] placeholder that shows a blank button.
      final finalSections = [...ref.read(streamingReasoningSectionsProvider)];
      if (finalSections.isNotEmpty) {
        finalSections[finalSections.length - 1] = reasoningBuffer;
      } else if (reasoningBuffer.isNotEmpty) {
        finalSections.add(reasoningBuffer);
      }
      ref.read(streamingReasoningSectionsProvider.notifier).state =
          finalSections;
      _reasoningContents[aiMsgId] = finalSections;
      // Mark reasoning as completed at stream end in case it wasn't
      // already marked (e.g., if only reasoning was received with no
      // text content, or the stream was cancelled mid-reasoning).
      if (reasoningBuffer.isNotEmpty) {
        _isReasoningCompletedForMsg[aiMsgId] = true;
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
          reasoningContent: reasoningBuffer.isNotEmpty ? reasoningBuffer : null,
          rawRequest: rawRequestCapture,
          rawResponse: rawResponseCapture,
        );
        _history.add(msg);
      }
      if (reasoningBuffer.isNotEmpty) {
        // Reasoning sections already updated above via provider.
        // Ensure _reasoningContents has the latest sections.
        final sections = List<String>.from(
          ref.read(streamingReasoningSectionsProvider),
        );
        _reasoningContents[aiMsgId] = sections;
      }
    } catch (e, s) {
      debugPrint('[ChatPage] post-stream error: $e\n$s');
    } finally {
      _streamingMsgId = null;
      _isStreamingActive = false;
      ref.read(isStreamingProvider.notifier).state = false;
      ref.read(streamingMsgIdProvider.notifier).state = null;
      ref.read(streamingFullReplyProvider.notifier).state = '';
      ref.read(streamingHasFirstTokenProvider.notifier).state = false;
      // NOTE: streamingReasoningProvider and streamingReasoningSectionsProvider
      // are deliberately NOT reset here. The dialog panels watch these
      // providers, and clearing them would cause open dialogs to lose their
      // content. These providers are reset at the START of a new streaming
      // session instead (see _startStreaming), preserving the final reasoning
      // content from the completed stream.
      _cancelledByUser = false;
      // NOTE: _streamingRenderedLengths.remove(aiMsgId) is intentionally
      // deferred to after _saveMessages() (below). Removing it here would
      // trigger a null-assert crash on the `!` operator at lines 727/865
      // if any code path accesses it during the save/rebuild window.
      // Eventual cleanup happens after _saveMessages() returns.
      if (mounted) setState(() {});
    }

    // Save messages even if page was disposed — this persists the completed
    // streaming result to SharedPreferences so it shows up when the user
    // navigates back to the chat page. Uses ref.read which works at the
    // ProviderScope level and does not require mounted to be true.
    // Use capturedConvId (set at stream start) to avoid saving to the wrong
    // conversation if the user switched conversations during background
    // streaming (e.g. navigated back and selected a different topic).
    await AppLogService.info(
        'ChatPage',
        '保存流式结果: convId=$capturedConvId, '
            'fullReply长度=${fullReply.length}, '
            '历史消息数=${_history.length}');
    await _saveMessages(capturedConvId: capturedConvId);

    // Eventual cleanup: remove streaming-only map entries now that the
    // save is complete. Deferred from the inner finally block to prevent
    // null-assert crashes (lines 727/865 use `!` on map lookups) and to
    // ensure segments are still available for any mid-save UI rebuilds.
    _streamingRenderedLengths.remove(aiMsgId);

    // Clean up the adapter after background streaming completes. If the page
    // was disposed while streaming, dispose() skipped adapter cleanup, so we
    // must do it here to prevent resource leaks.
    if (!mounted) {
      try {
        _adapter.dispose();
      } catch (_) {}
    }
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
      onEdit: () => _startEditMessage(messageId),
      onRetry: () => _retryAssistantMessage(messageId),
    );
  }

  void _startEditMessage(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    if (ref.read(isStreamingProvider)) return;
    final msg = _history[index];

    // Instead of showing a separate dialog, enter edit mode in the composer.
    // The composer will pre-fill with the message text, show the original
    // attachments in the pending area, and show an edit capsule.
    // On send, _handleEditSend is called. On cancel, _handleEditCancel.
    setState(() {
      _editingMessageId = messageId;
      _editingMessageText = msg.content;
      _editingMessageAttachments = msg.attachments;
    });
  }

  void _handleEditSend(
    String messageId,
    String newText,
    List<Attachment> attachments,
  ) {
    if (!mounted) return;
    // Clear edit state
    setState(() {
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
    });
    // Perform the edit with the combined attachments
    _editUserMessageWithText(messageId, newText, attachments);
  }

  void _handleEditCancel() {
    if (!mounted) return;
    setState(() {
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
    });
  }

  Future<void> _editUserMessageWithText(
    String messageId,
    String newText,
    List<Attachment> newAttachments,
  ) async {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1 || index >= _history.length) return;

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
          // Clean up cached maps for removed messages to prevent memory leaks.
          _chatSegments.remove(r.id);
          _reasoningContents.remove(r.id);
          _isReasoningCompletedForMsg.remove(r.id);
          _streamingRenderedLengths.remove(r.id);
          _messageKeys.remove(r.id);
        }
        // Safety: keep pagination index within bounds
        _loadedUpToIndex = _loadedUpToIndex.clamp(0, _history.length);
      }
    } catch (e) {
      debugPrint('[ChatPage] _editUserMessageWithText remove failed: $e');
    }

    // Send with edited text and the combined attachments (original + new)
    await _onMessageSend(newText, newAttachments);
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
          // Clean up cached maps for removed messages to prevent memory leaks.
          _chatSegments.remove(r.id);
          _reasoningContents.remove(r.id);
          _isReasoningCompletedForMsg.remove(r.id);
          _streamingRenderedLengths.remove(r.id);
          _messageKeys.remove(r.id);
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
    // Prevent deleting the currently streaming message — the streaming loop
    // relies on _chatSegments and _streamingRenderedLengths entries for this
    // message, and removing them mid-stream would cause null-assert crashes.
    if (messageId == _streamingMsgId) return;
    if (ref.read(isStreamingProvider)) return;
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final msg = _history[index];

    for (final att in msg.attachments) {
      final isReferencedElsewhere = _history.asMap().entries.any(
            (entry) =>
                entry.key != index &&
                entry.value.attachments.any(
                  (a) => a.storagePath == att.storagePath,
                ),
          );
      if (!isReferencedElsewhere) {
        await AttachmentStorage.deleteFile(att.storagePath);
      }
    }

    setState(() {
      _history.removeAt(index);
      // Clean up cached maps for the deleted message to prevent memory leaks.
      _chatSegments.remove(messageId);
      _reasoningContents.remove(messageId);
      _isReasoningCompletedForMsg.remove(messageId);
      _streamingRenderedLengths.remove(messageId);
      _messageKeys.remove(messageId);
      // Adjust pagination state: if the deleted message was before the loaded
      // region, shift _loadedUpToIndex to keep it pointing at the same messages.
      if (index < _loadedUpToIndex && _loadedUpToIndex > 0) {
        _loadedUpToIndex = _loadedUpToIndex > 0 ? _loadedUpToIndex - 1 : 0;
      }
    });

    final msgToRemove =
        _controller?.messages.where((m) => m.id == messageId).firstOrNull;
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

  /// Returns true if the attachment is a text-based file that can be
  /// previewed by reading its content as UTF-8 text.
  bool _isTextAttachment(Attachment att) {
    // Check mime type for text
    if (att.mimeType.startsWith('text/')) return true;
    // Check common text file extensions
    final ext = p.extension(att.fileName).toLowerCase();
    const textExtensions = {
      '.txt',
      '.md',
      '.json',
      '.xml',
      '.csv',
      '.html',
      '.htm',
      '.css',
      '.js',
      '.ts',
      '.dart',
      '.py',
      '.yaml',
      '.yml',
      '.toml',
      '.ini',
      '.cfg',
      '.conf',
      '.log',
      '.sh',
      '.bat',
      '.ps1',
      '.sql',
      '.rb',
      '.php',
      '.java',
      '.cpp',
      '.c',
      '.h',
      '.hpp',
      '.rs',
      '.go',
      '.swift',
      '.kt',
      '.gradle',
      '.properties',
      '.env',
      '.gitignore',
      '.dockerfile',
      '.makefile',
    };
    if (textExtensions.contains(ext)) return true;
    return false;
  }

  /// Returns true if the attachment is a PDF file.
  bool _isPdfAttachment(Attachment att) {
    if (att.mimeType == 'application/pdf') return true;
    return p.extension(att.fileName).toLowerCase() == '.pdf';
  }

  void _showAttachmentPreview(Attachment att) async {
    final data = await AttachmentStorage.readFile(att.storagePath);
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法加载文件')));
      }
      return;
    }
    if (!mounted) return;
    final isImage = att.fileType == 'image';
    final isText = _isTextAttachment(att);
    final isPdf = _isPdfAttachment(att);
    final isAudio = att.fileType == 'audio';
    final isVideo = att.fileType == 'video';

    if (isImage) {
      _showImagePreview(att, data);
    } else if (isText) {
      _showTextPreview(att, data);
    } else if (isPdf) {
      _showPdfPreview(att, data);
    } else if (isAudio) {
      _showAudioPreview(att, data);
    } else if (isVideo) {
      _showVideoPreview(att, data);
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
    showFileInfoPreviewDialog(context: context, attachment: att);
  }

  /// Text content preview — shows the full file content in a scrollable
  /// dialog with selectable text. Supports all common text-based formats
  /// (txt, md, json, code files, etc.).
  void _showTextPreview(Attachment att, Uint8List data) {
    String content;
    try {
      content = utf8.decode(data);
    } catch (e) {
      debugPrint('[ChatPage] Text preview decode failed: $e');
      _showFileInfoPreview(att);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with file name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      att.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // Scrollable text content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PDF preview — attempts to open the PDF using the system's default
  /// PDF viewer via [url_launcher]. Falls back to file info dialog if
  /// the launcher is unavailable.
  Future<void> _showPdfPreview(Attachment att, Uint8List data) async {
    try {
      // Try to save to a temp file and open with system handler
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, att.fileName));
      await tempFile.writeAsBytes(data);
      final uri = Uri.file(tempFile.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[ChatPage] PDF preview failed: $e');
    }
    // Fallback: show file info
    if (mounted) _showFileInfoPreview(att);
  }

  /// Audio preview — opens a dialog with an audio player powered by
  /// [just_audio]. The user can play/pause the audio file.
  Future<void> _showAudioPreview(Attachment att, Uint8List data) async {
    // Save bytes to a temp file for the audio player
    String? filePath;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, att.fileName));
      await tempFile.writeAsBytes(data);
      filePath = tempFile.path;
    } catch (e) {
      debugPrint('[ChatPage] Audio preview temp file failed: $e');
      if (mounted) _showFileInfoPreview(att);
      return;
    }

    if (!mounted) return;
    // Show audio player dialog
    showDialog(
      context: context,
      builder: (ctx) =>
          AudioPreviewDialog(filePath: filePath!, fileName: att.fileName),
    );
  }

  /// Video preview — opens a dialog with a Chewie + fvp video player.
  Future<void> _showVideoPreview(Attachment att, Uint8List data) async {
    // Save bytes to a temp file for the video player
    String? filePath;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, att.fileName));
      await tempFile.writeAsBytes(data);
      filePath = tempFile.path;
    } catch (e) {
      debugPrint('[ChatPage] Video preview temp file failed: $e');
      if (mounted) _showFileInfoPreview(att);
      return;
    }

    if (!mounted) return;
    // Show video player dialog
    showDialog(
      context: context,
      builder: (ctx) =>
          VideoPreviewDialog(filePath: filePath!, fileName: att.fileName),
    );
  }

  void _stopStreaming() {
    _cancelledByUser = true;
    _isStreamingActive = false;
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
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) {
      return;
    }
    final match = _searchMatches[_currentMatchIndex];
    final key = _messageKeys[match.messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, alignment: 0.3);
    }
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length;
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
    Navigator.of(context, rootNavigator: true)
        .push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const MessageSearchPage()),
    )
        .then((result) async {
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
        ref
            .read(conversationsProvider.notifier)
            .selectConversation(conversationId);
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

  Widget _buildHighlightedText(
    String text,
    String messageId, {
    Color? textColor,
  }) {
    if (_searchQuery.isEmpty) {
      return SelectableText(
        text,
        style: textColor != null ? TextStyle(color: textColor) : null,
      );
    }
    final matches =
        _searchMatches.where((m) => m.messageId == messageId).toList();
    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: textColor != null ? TextStyle(color: textColor) : null,
      );
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
      spans.add(
        TextSpan(
          text: matchText,
          style: TextStyle(
            backgroundColor: isCurrent ? Colors.orangeAccent : Colors.yellow,
            color: Colors.black87,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
      lastEnd = match.matchEnd;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return SelectableText.rich(
      TextSpan(style: DefaultTextStyle.of(context).style, children: spans),
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
    final isStreaming = ref.watch(isStreamingProvider);
    final markdownConfig = buildMarkdownConfig(
      isDark: isDark,
      isStreaming: isStreaming,
    );
    final adapterConfigured = _adapter.isConfigured;
    final controller = _controller;

    // Reactively load messages when the active conversation changes
    ref.listen(activeConversationIdProvider, (prev, next) {
      if (next != null && next != prev) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadConversationMessages();
        });
      }
    });

    // Reactively load messages when conversations data finishes loading
    // (e.g., after async _load() in ConversationsNotifier completes).
    //
    // Fixes the race condition where _loadConversationMessages() runs before
    // conversation data is available, leaving the chat page blank with
    // "no message yet" even though all data exists in SharedPreferences.
    //
    // Uses _history.isEmpty to only trigger on data arrival (not on every
    // subsequent save/update), avoiding redundant reloads.
    ref.listen(conversationsProvider, (prev, next) {
      if (prev != next && _history.isEmpty) {
        final activeId = ref.read(activeConversationIdProvider);
        if (activeId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadConversationMessages();
          });
        }
      }
    });

    // Re-configure adapter when provider entries change (e.g. after load completes).
    // Also re-initialize built-in and MCP tools: if ProviderEntriesNotifier.load()
    // hasn't completed when _initialize() first runs, the MCP entry is empty and
    // no MCP servers are initialized. This listener ensures that once the data
    // finishes loading, MCP servers are discovered and their tools appear in the
    // chat page's tool list.
    ref.listen(providerEntriesProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          _configureAdapter();
          // Re-initialize built-in and MCP tools with the updated provider data.
          // This is safe to call multiple times — initializeMcpServers disposes
          // old clients before creating new ones.
          final entriesState = ref.read(providerEntriesProvider);
          _adapter.initializeBuiltinTools(entriesState);
          await _adapter.initializeMcpServers(entriesState);
          if (mounted) setState(() {});
          // _configureAdapter resets the adapter to model 0. Restore the
          // saved model selection so the adapter and reasoning params
          // stay in sync with the persisted choice.
          SharedPreferences.getInstance().then((prefs) {
            if (mounted) _restoreSavedModelSelection(prefs);
          });
        });
      }
    });

    // Auto-save reasoning settings when they change (per-model persistence)
    ref.listen(
      reasoningEnabledProvider,
      (_, __) => _persistCurrentReasoningSettings(),
    );
    ref.listen(
      reasoningEffortEnabledProvider,
      (_, __) => _persistCurrentReasoningSettings(),
    );
    ref.listen(
      reasoningEffortProvider,
      (_, __) => _persistCurrentReasoningSettings(),
    );
    ref.listen(
      reasoningParamValuesProvider,
      (_, __) => _persistCurrentReasoningSettings(),
    );

    // Get conversation title
    final activeId = ref.watch(activeConversationIdProvider);
    final conversations = ref.watch(conversationsProvider);
    String title = '新对话';
    String currentDraftText = '';
    if (activeId != null) {
      final conv = conversations.where((c) => c.id == activeId).firstOrNull;
      if (conv != null) {
        if (conv.title.isNotEmpty) title = conv.title;
        currentDraftText = conv.draftText;
      }
    }

    return PopScope(
      canPop: true,
      child: SafeArea(
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
                        onPressed: () {
                          // Allow navigation back at any time, even during
                          // streaming. The stream continues in the background,
                          // messages are saved when streaming completes.
                          Navigator.of(context).pop();
                        },
                      ),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () =>
                            setState(() => _developerMode = !_developerMode),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (_developerMode)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
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
                  ],
                ),
              ),

              // ── Search bar ──
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
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
                          Icon(
                            Icons.search,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          if (_searchMode == SearchMode.current &&
                              _searchMatches.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${_currentMatchIndex + 1}/${_searchMatches.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_searchMode == SearchMode.current) ...[
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_up,
                                size: 20,
                              ),
                              tooltip: '上一个',
                              onPressed: _previousMatch,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                              ),
                              tooltip: '下一个',
                              onPressed: _nextMatch,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: '关闭搜索',
                            onPressed: _closeSearch,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ 未配置聊天API — 前往设置',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
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
                    : Stack(
                        children: [
                          Chat(
                            key: ValueKey(controller.hashCode),
                            currentUserId: _currentUser.id,
                            resolveUser: (id) async {
                              if (id == _currentUser.id) return _currentUser;
                              if (id == _aiUser.id) return _aiUser;
                              return null;
                            },
                            chatController: controller,
                            onMessageSend: (text) => _onMessageSend(text, []),
                            theme:
                                isDark ? ChatTheme.dark() : ChatTheme.light(),
                            timeFormat: DateFormat('yyyy-MM-dd HH:mm'),
                            builders: Builders(
                              chatAnimatedListBuilder: (context, itemBuilder) =>
                                  ChatAnimatedList(
                                itemBuilder: itemBuilder,
                                onEndReached: _loadMoreMessages,
                                scrollController: _chatScrollController,
                                // Initially disable auto-scroll. User must
                                // tap the scroll-to-bottom button to enable.
                                shouldScrollToEndWhenAtBottom:
                                    _autoScrollEnabled,
                                shouldScrollToEndWhenSendingMessage:
                                    _autoScrollEnabled,
                              ),
                              // Suppress the built-in scroll-to-bottom
                              // button — we provide our own overlay below.
                              scrollToBottomBuilder:
                                  (context, animation, onPressed) =>
                                      const SizedBox.shrink(),
                              // Empty composer builder — the actual composer is
                              // rendered below the Chat widget so it participates
                              // in the Column layout flow instead of overlaying
                              // the message list via the internal Stack. This
                              // ensures the scroll area auto-adjusts as the
                              // composer height changes (e.g. multi-line input).
                              composerBuilder: (_) => const SizedBox.shrink(),
                              textMessageBuilder: (
                                context,
                                message,
                                index, {
                                required bool isSentByMe,
                                MessageGroupStatus? groupStatus,
                              }) {
                                final isAi = message.authorId == _aiUser.id;

                                Widget messageBubble;
                                if (isAi) {
                                  final chatMsg = _history
                                      .where((m) => m.id == message.id)
                                      .firstOrNull;
                                  if ((chatMsg?.isError == true) ||
                                      message.text.startsWith('错误:')) {
                                    // Extract error details from rawResponse
                                    final resp = chatMsg?.rawResponse ?? {};
                                    final statusCode = resp['statusCode'];
                                    final responseBodyData = resp['data'];
                                    final responseError = resp['error'];
                                    final originalErrorText =
                                        message.text.replaceAll('错误: ', '');

                                    // Build the list of error info widgets
                                    final errorWidgets = <Widget>[];

                                    // Status Code (new — shown first)
                                    if (statusCode != null) {
                                      errorWidgets.add(
                                        SelectableText(
                                          'Status Code: $statusCode',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.red[200]
                                                : Colors.red[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }

                                    // Response Body error (new — shown second)
                                    if (responseBodyData != null ||
                                        responseError != null) {
                                      final bodyText = responseBodyData != null
                                          ? _formatErrorValue(responseBodyData)
                                          : _formatErrorValue(responseError);
                                      errorWidgets.add(
                                        SelectableText(
                                          bodyText,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.red[200]
                                                : Colors.red[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }

                                    // Blank line before original error
                                    if (errorWidgets.isNotEmpty &&
                                        originalErrorText.isNotEmpty) {
                                      errorWidgets.add(
                                        const SizedBox(height: 8),
                                      );
                                    }

                                    // Original error (DIO Exception etc.)
                                    if (originalErrorText.isNotEmpty) {
                                      errorWidgets.add(
                                        SelectableText(
                                          originalErrorText,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.red[200]
                                                : Colors.red[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                      );
                                    }

                                    messageBubble = Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: (isDark
                                                ? Colors.red[900]
                                                : Colors.red[50])!
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 14,
                                                color: isDark
                                                    ? Colors.red[300]
                                                    : Colors.red[700],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '发送失败',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.red[300]
                                                      : Colors.red[700],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ...errorWidgets,
                                          if (chatMsg != null &&
                                              (chatMsg.rawRequest != null ||
                                                  chatMsg.rawResponse != null))
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: TextButton.icon(
                                                icon: Icon(
                                                  Icons.preview,
                                                  size: 14,
                                                  color: isDark
                                                      ? Colors.red[300]
                                                      : Colors.red[700],
                                                ),
                                                label: Text(
                                                  '查看详细错误',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.red[300]
                                                        : Colors.red[700],
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _showErrorDetailDialog(
                                                  context,
                                                  message.id,
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    final reasoningSections =
                                        _reasoningContents[message.id];
                                    final segments = _chatSegments[message.id];
                                    final isWaitingForFirstToken =
                                        message.id == _streamingMsgId &&
                                            message.text.isEmpty &&
                                            isStreaming &&
                                            !ref.read(
                                              streamingHasFirstTokenProvider,
                                            );
                                    final hasSearchMatch = _isSearching &&
                                        _searchQuery.isNotEmpty &&
                                        _searchMatches.any(
                                          (m) => m.messageId == message.id,
                                        );

                                    messageBubble = Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[850]
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (reasoningSections != null &&
                                              reasoningSections.isNotEmpty)
                                            ReasoningSection(
                                              sections: ReasoningSectionData(
                                                texts: reasoningSections,
                                                // Streaming is true only while
                                                // reasoning events are still
                                                // being received. Once text
                                                // content starts (reasoning
                                                // complete), streaming becomes
                                                // false so the button shows
                                                // "推理过程" instead of "推理中".
                                                streaming: isStreaming &&
                                                    message.id ==
                                                        _streamingMsgId &&
                                                    _isReasoningCompletedForMsg[
                                                            message.id] !=
                                                        true,
                                              ),
                                              messageId: message.id,
                                            ),
                                          // During streaming, when first token hasn't arrived
                                          // and we don't have reasoning content, show JumpingDots.
                                          // Reasoning content already shows "推理中" button.
                                          if (isWaitingForFirstToken &&
                                              (reasoningSections == null ||
                                                  reasoningSections.isEmpty))
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              child:
                                                  JumpingDotsProgressIndicator(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            )
                                          else if (segments != null &&
                                              segments.isNotEmpty)
                                            // Merge consecutive TextSegments to avoid visual breaks
                                            // between arbitrary streaming chunk boundaries (e.g.
                                            // throttle intervals). Each text block renders in a
                                            // single MarkdownWidget for continuity.
                                            ...mergeConsecutiveTextSegments(
                                              segments,
                                            ).map(
                                              (seg) => switch (seg) {
                                                TextSegment s => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 4,
                                                    ),
                                                    child: hasSearchMatch
                                                        ? _buildHighlightedText(
                                                            s.text,
                                                            message.id,
                                                          )
                                                        : MarkdownWidget(
                                                            data: s.text,
                                                            selectable: true,
                                                            shrinkWrap: true,
                                                            physics:
                                                                const NeverScrollableScrollPhysics(),
                                                            config:
                                                                markdownConfig,
                                                            markdownGenerator:
                                                                markdownGenerator,
                                                          ),
                                                  ),
                                                ToolCallSegment s =>
                                                  ToolCallCard(data: s.data),
                                              },
                                            )
                                          else if (hasSearchMatch)
                                            _buildHighlightedText(
                                              message.text,
                                              message.id,
                                            )
                                          else
                                            MarkdownWidget(
                                              data: message.text,
                                              selectable: true,
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              config: markdownConfig,
                                              markdownGenerator:
                                                  markdownGenerator,
                                            ),
                                        ],
                                      ),
                                    );
                                  }
                                } else {
                                  final chatMsg = _history
                                      .where((m) => m.id == message.id)
                                      .firstOrNull;
                                  final hasAttachments =
                                      chatMsg?.attachments.isNotEmpty == true;
                                  final hasSearchMatch = _isSearching &&
                                      _searchQuery.isNotEmpty &&
                                      _searchMatches.any(
                                        (m) => m.messageId == message.id,
                                      );
                                  messageBubble = Column(
                                    crossAxisAlignment:
                                        hasAttachments && isSentByMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasSearchMatch)
                                        _buildHighlightedText(
                                          message.text,
                                          message.id,
                                        )
                                      else
                                        SimpleTextMessage(
                                          message: message,
                                          index: index,
                                          showTime: false,
                                        ),
                                      if (hasAttachments)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            right: 4,
                                            bottom: 4,
                                          ),
                                          child: SizedBox(
                                            height: 120,
                                            child: ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              reverse: isSentByMe,
                                              itemCount:
                                                  chatMsg!.attachments.length,
                                              itemBuilder: (ctx, i) {
                                                final att =
                                                    chatMsg.attachments[i];
                                                return _buildMessageAttachmentPreview(
                                                  att,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: isSentByMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      key: _messageKeys.putIfAbsent(
                                        message.id,
                                        () => GlobalKey(),
                                      ),
                                      child: messageBubble,
                                    ),
                                    // Timestamp below bubble (user messages only),
                                    // above action buttons, with theme-adaptive color.
                                    if (!isAi)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          top: 2,
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          DateFormat('yyyy-MM-dd HH:mm').format(
                                            (message.createdAt ??
                                                    message.resolvedTime ??
                                                    DateTime.now())
                                                .toLocal(),
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        top: 2,
                                        bottom: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ActionButton(
                                            icon: Icons.copy,
                                            tooltip: '复制',
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: message.text,
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('已复制'),
                                                  duration: Duration(
                                                    seconds: 1,
                                                  ),
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
                                                  _confirmRetryOrEdit(
                                                message.id,
                                              ),
                                            )
                                          else
                                            ActionButton(
                                              icon: Icons.edit_outlined,
                                              tooltip: '编辑',
                                              onPressed: () =>
                                                  _startEditMessage(
                                                message.id,
                                              ),
                                            ),
                                          // Raw data view button: only shown for AI messages when data exists.
                                          if (isAi &&
                                              _history.any(
                                                (m) =>
                                                    m.id == message.id &&
                                                    (m.rawRequest != null ||
                                                        m.rawResponse != null),
                                              )) ...[
                                            const SizedBox(width: 2),
                                            ActionButton(
                                              icon: Icons.data_exploration,
                                              tooltip: '查看数据详情',
                                              onPressed: () =>
                                                  _showRawDataDialog(
                                                context,
                                                message.id,
                                              ),
                                            ),
                                          ],
                                          if (_developerMode &&
                                              isAi &&
                                              _history.any(
                                                (m) =>
                                                    m.id == message.id &&
                                                    (m.rawRequest != null ||
                                                        m.rawResponse != null),
                                              )) ...[
                                            const SizedBox(width: 2),
                                            ActionButton(
                                              icon: Icons.code,
                                              tooltip: 'JSON 审查',
                                              onPressed: () =>
                                                  _showJsonInspection(
                                                message.id,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 2),
                                          ActionButton(
                                            icon: Icons.delete_outline,
                                            tooltip: '删除',
                                            onPressed: () =>
                                                _confirmDeleteMessage(
                                              message.id,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                              textStreamMessageBuilder: (
                                context,
                                message,
                                index, {
                                required bool isSentByMe,
                                MessageGroupStatus? groupStatus,
                              }) {
                                // If the message has accumulated content (e.g.,
                                // after page restoration from background streaming),
                                // render it as regular text instead of a spinner.
                                final accumulated = ref.read(
                                  streamingFullReplyProvider,
                                );
                                if (accumulated.isNotEmpty &&
                                    message.id ==
                                        ref.read(streamingMsgIdProvider)) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: MarkdownWidget(
                                      data: accumulated,
                                      selectable: true,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      config: markdownConfig,
                                      markdownGenerator: markdownGenerator,
                                    ),
                                  );
                                }
                                // Check if reasoning content exists for this
                                // message. If so, render the reasoning button
                                // immediately instead of a spinner, even before
                                // the first TextEvent converts the message from
                                // textStream to text type.
                                final reasoningSections =
                                    _reasoningContents[message.id];
                                if (reasoningSections != null &&
                                    reasoningSections.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ReasoningSection(
                                          sections: ReasoningSectionData(
                                            texts: reasoningSections,
                                            // During textStream phase, reasoning
                                            // events are still being received (no
                                            // TextEvent yet), so streaming is
                                            // always true. Once TextEvent arrives,
                                            // updateMessage() converts the message
                                            // to text type and textMessageBuilder
                                            // takes over with the correct flag.
                                            streaming: isStreaming &&
                                                message.id == _streamingMsgId &&
                                                _isReasoningCompletedForMsg[
                                                        message.id] !=
                                                    true,
                                          ),
                                          messageId: message.id,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // ── Scroll-to-bottom overlay button ──
                          if (_showScrollToBottomButton)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Material(
                                elevation: 4,
                                shape: const CircleBorder(),
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _onScrollToBottomTap,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.arrow_downward,
                                      size: 20,
                                      color: isDark
                                          ? Colors.grey[200]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              // ── Chat composer (below chat, in Column flow) ──
              // Rendered as a direct Column child so it participates in the
              // layout flow instead of overlaying the message list via a
              // Stack. This lets the scroll area auto-adjust as the
              // composer height changes (e.g. multi-line input).
              ChatComposerWidget(
                conversationId: activeId,
                initialDraftText: currentDraftText,
                onSend: _onMessageSend,
                onStop: _stopStreaming,
                onPreviewAttachment: _showAttachmentPreview,
                mcpTools: _adapter.getAllToolDefinitions(),
                enabledTools: ref.watch(enabledToolNamesProvider),
                onEnabledToolsChanged: (tools) {
                  ref.read(enabledToolNamesProvider.notifier).state = tools;
                  _saveEnabledToolsToConversation();
                },
                modelNames: _getModelNames(),
                selectedModelIndex: _selectedModelIndex,
                onModelSelected: _onModelSelected,
                onModelsReordered: _onModelsReordered,
                reasoningParams: _adapter.reasoningParams,
                hasReasoningParams: _adapter.hasReasoningParams,
                editingMessageId: _editingMessageId,
                editingMessageText: _editingMessageText,
                editingMessageAttachments: _editingMessageAttachments,
                onEditSend: _handleEditSend,
                onEditCancel: _handleEditCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetailDialog(BuildContext context, String messageId) {
    final chatMsg = _history.where((m) => m.id == messageId).firstOrNull;
    if (chatMsg == null) return;

    showDataDetailDialog(
      context: context,
      rawRequest: chatMsg.rawRequest,
      rawResponse: chatMsg.rawResponse,
    );
  }

  /// Shows a dialog with raw HTTP request/response data for the given message.
  void _showRawDataDialog(BuildContext context, String messageId) {
    _showErrorDetailDialog(context, messageId);
  }

  /// Formats an error value for display in the error bubble.
  /// If the value is a Map/List, converts to JSON string.
  /// If the value is already a String, returns it as-is (up to 200 chars).
  String _formatErrorValue(dynamic value) {
    if (value is String) {
      return value.length > 200 ? '${value.substring(0, 200)}...' : value;
    }
    if (value is Map || value is List) {
      try {
        final json = const JsonEncoder.withIndent('  ').convert(value);
        return json.length > 200 ? '${json.substring(0, 200)}...' : json;
      } catch (_) {
        return value.toString();
      }
    }
    return value?.toString() ?? '';
  }

  /// Returns the list of model display names for the attachment panel,
  /// ordered according to the user's saved drag-sort order if available.
  List<String> _getModelNames() {
    final entriesState = ref.read(providerEntriesProvider);
    final names = _adapter
        .availableModels(entriesState)
        .map((m) => m.displayName)
        .toList();

    // Apply saved order: bring known names to the front in saved order,
    // then append any new names not yet in the saved order.
    if (_savedModelOrder != null && _savedModelOrder!.isNotEmpty) {
      final ordered = <String>[];
      final remaining = Set<String>.from(names);
      for (final savedName in _savedModelOrder!) {
        if (remaining.remove(savedName)) {
          ordered.add(savedName);
        }
      }
      // Append any models not yet in the saved order
      ordered.addAll(remaining);
      return ordered;
    }
    return names;
  }

  /// Called when model is selected from the attachment panel.
  /// Uses the model name from the display list to find the correct
  /// adapter model, so that drag-reordered indices still select the
  /// right model. Saves current model's settings and restores the
  /// new model's per-model settings.
  void _onModelSelected(int idx) {
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final displayNames = _getModelNames();
    if (idx < 0 || idx >= displayNames.length) return;

    final selectedName = displayNames[idx];
    final modelIdx = models.indexWhere((m) => m.displayName == selectedName);
    if (modelIdx < 0) return;

    // Capture old model name BEFORE setState changes _selectedModelIndex
    final oldModelName = _getCurrentModelName();

    // Save current model's settings before switching, using captured name
    SharedPreferences.getInstance().then((prefs) {
      try {
        if (oldModelName.isNotEmpty) {
          final allSettings = _loadPerModelSettingsMap(prefs);
          allSettings[oldModelName] = {
            'reasoningEnabled': ref.read(reasoningEnabledProvider),
            'reasoningEffortEnabled': ref.read(reasoningEffortEnabledProvider),
            'reasoningEffort': ref.read(reasoningEffortProvider),
            'reasoningParamValues': ref.read(reasoningParamValuesProvider),
          };
          prefs.setString('per_model_chat_settings', jsonEncode(allSettings));
        }
      } catch (e) {
        debugPrint('_onModelSelectionChanged save settings failed: $e');
      }
    });

    final model = models[modelIdx];
    _adapter.selectModel(entriesState, model.configIndex, model.modelIndex);
    setState(() => _selectedModelIndex = idx);
    SharedPreferences.getInstance().then((prefs) {
      try {
        prefs.setInt('selected_model_index', idx);
        // Restore the new model's per-model settings
        _restorePerModelSettings(prefs, idx);
      } catch (e) {
        debugPrint('_onModelSelectionChanged save index failed: $e');
      }
    });
  }

  /// Called when models are reordered by drag-and-drop in the model panel.
  void _onModelsReordered(List<String> reordered) {
    setState(() => _savedModelOrder = reordered);
    SharedPreferences.getInstance().then((prefs) {
      try {
        prefs.setStringList('model_order', reordered);
      } catch (e) {
        debugPrint('_onModelsReordered failed: $e');
      }
    });
  }

  // ── Per-model settings persistence ──────────────────────────────────

  /// Returns the display name of the currently selected model.
  String _getCurrentModelName() {
    final names = _getModelNames();
    if (_selectedModelIndex >= 0 && _selectedModelIndex < names.length) {
      return names[_selectedModelIndex];
    }
    return '';
  }

  /// Saves the current reasoning/reasoning-effort/reasoning-param settings
  /// to SharedPreferences, keyed by the current model's display name.
  void _saveCurrentModelSettings(SharedPreferences prefs) {
    try {
      final modelName = _getCurrentModelName();
      if (modelName.isEmpty) return;

      // Load existing per-model settings map
      final allSettings = _loadPerModelSettingsMap(prefs);
      allSettings[modelName] = {
        'reasoningEnabled': ref.read(reasoningEnabledProvider),
        'reasoningEffortEnabled': ref.read(reasoningEffortEnabledProvider),
        'reasoningEffort': ref.read(reasoningEffortProvider),
        'reasoningParamValues': ref.read(reasoningParamValuesProvider),
      };
      prefs.setString('per_model_chat_settings', jsonEncode(allSettings));
    } catch (e) {
      debugPrint('_saveCurrentModelSettings failed: $e');
    }
  }

  /// Restores the saved model selection (index + adapter state + per-model
  /// settings) from SharedPreferences. Also restores drag-sort order.
  ///
  /// This is used both on initial page load and after [_configureAdapter]
  /// resets the adapter state (e.g. when [providerEntriesProvider] changes),
  /// ensuring the adapter and UI stay in sync with the persisted selection.
  ///
  /// IMPORTANT: The saved [selected_model_index] is a DISPLAY index (from the
  /// possibly-reordered model list shown to the user). We must map it through
  /// the model's display name to find the correct flat index in the adapter's
  /// [availableModels] list. Using the saved index directly on the flat list
  /// would select the wrong model when the display order differs from the flat
  /// order (e.g. after drag-and-drop reordering in the model panel).
  void _restoreSavedModelSelection(SharedPreferences prefs) {
    // Restore saved model order (drag-sort persistence) first,
    // so model names resolve correctly.
    final savedOrder = prefs.getStringList('model_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      setState(() {
        _savedModelOrder = savedOrder;
      });
    }

    // Restore saved model selection — clear stale index if out of range
    final entriesState = ref.read(providerEntriesProvider);
    final models = _adapter.availableModels(entriesState);
    final saved = prefs.getInt('selected_model_index');
    int selectedIdx = 0;
    if (saved != null && saved >= 0) {
      // Map display index to flat index via display name:
      // The saved index is a DISPLAY index (from the user-facing reorderable
      // list). We need to find the corresponding model in the flat list by
      // resolving through the display name, not by using the index directly.
      final displayNames = _getModelNames();
      if (saved < displayNames.length) {
        selectedIdx = saved;
        final selectedName = displayNames[saved];
        final flatIdx = models.indexWhere(
          (m) => m.displayName == selectedName,
        );
        if (flatIdx >= 0) {
          final model = models[flatIdx];
          _adapter.selectModel(
            entriesState,
            model.configIndex,
            model.modelIndex,
          );
        } else {
          // Saved model not found in current list (e.g. deleted from
          // provider config). Fall back to the default (first model).
          selectedIdx = 0;
          prefs.remove('selected_model_index');
        }
      } else {
        // Saved index out of range for current display names — discard
        selectedIdx = 0;
        prefs.remove('selected_model_index');
      }
    } else {
      prefs.remove('selected_model_index');
    }
    setState(() => _selectedModelIndex = selectedIdx);

    // Restore per-model settings for the currently selected model
    _restorePerModelSettings(prefs, selectedIdx);
  }

  /// Restores the reasoning/reasoning-effort/reasoning-param settings
  /// for the model at the given display [index].
  void _restorePerModelSettings(SharedPreferences prefs, int index) {
    final names = _getModelNames();
    if (index < 0 || index >= names.length) return;
    final modelName = names[index];

    final allSettings = _loadPerModelSettingsMap(prefs);
    final modelSettings = allSettings[modelName];
    if (modelSettings
        case {
          'reasoningEnabled': bool re,
          'reasoningEffort': String refEff,
          'reasoningParamValues': Map<String, dynamic> rpv,
        }) {
      ref.read(reasoningEnabledProvider.notifier).state = re;
      // Restore reasoning effort enabled state (with default false)
      final bool ree =
          modelSettings['reasoningEffortEnabled'] as bool? ?? false;
      ref.read(reasoningEffortEnabledProvider.notifier).state = ree;
      // Validate reasoningEffort against known values
      const validEfforts = {'low', 'medium', 'high'};
      ref.read(reasoningEffortProvider.notifier).state =
          validEfforts.contains(refEff) ? refEff : 'medium';
      // Cast from Map<String, dynamic> (jsonDecode result) to Map<String, String>
      ref.read(reasoningParamValuesProvider.notifier).state = rpv.map(
        (k, v) => MapEntry(k, v.toString()),
      );
    } else {
      // No saved settings for this model — use defaults
      ref.read(reasoningEnabledProvider.notifier).state = false;
      ref.read(reasoningEffortEnabledProvider.notifier).state = false;
      ref.read(reasoningEffortProvider.notifier).state = 'medium';
      ref.read(reasoningParamValuesProvider.notifier).state = {};
    }
  }

  /// Loads the per-model settings map from SharedPreferences.
  Map<String, dynamic> _loadPerModelSettingsMap(SharedPreferences prefs) {
    final json = prefs.getString('per_model_chat_settings');
    if (json != null && json.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(json) as Map);
      } catch (_) {}
    }
    return {};
  }

  /// Persists the current reasoning settings to the current model's slot.
  /// Called when reasoning toggle, effort, or param values change.
  void _persistCurrentReasoningSettings() {
    SharedPreferences.getInstance().then((prefs) {
      _saveCurrentModelSettings(prefs);
    });
  }
}
