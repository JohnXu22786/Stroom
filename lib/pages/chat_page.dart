import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
import '../widgets/transform_stretch_overscroll.dart';
import '../services/attachment_storage.dart';

import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart' show ToolCallData;
import '../services/app_log_service.dart';
import '../services/chat_adapter.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_stream_provider.dart';
import '../providers/chat_manager_provider.dart';
import '../services/chat_stream_manager.dart' show StreamResult;
import '../providers/provider_config.dart';
import '../providers/assistant_provider.dart' show selectedAssistantProvider;
import '../widgets/llm/jumping_dots.dart';
import '../widgets/llm/tool_call_card.dart';
import 'message_search_page.dart';
import 'provider_config_page.dart';

import 'chat/chat_types.dart';
import 'chat/chat_initial_scroll.dart';

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

part 'chat_page_streaming.dart';
part 'chat_page_editing.dart';
part 'chat_page_messages.dart';
part 'chat_page_persistence.dart';
part 'chat_page_attachments.dart';
part 'chat_page_search.dart';
part 'chat_page_models.dart';
part 'chat_page_ui.dart';
part 'chat_page_listeners.dart';
part 'chat_page_builders.dart';
part 'chat_page_bubbles.dart';

class ChatPage extends ConsumerStatefulWidget {
  /// Optional search query to auto-activate search mode with.
  /// When provided, the page will open in search mode with the query
  /// pre-filled and matching text highlighted. Used by [MessageSearchPage].
  final String? initialSearchQuery;

  const ChatPage({super.key, this.initialSearchQuery});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

/// Combines the last persisted history with the in-memory history owned by an
/// active background stream. The live snapshot wins for an existing message,
/// while newly sent messages that have not reached persistence are appended.
List<ChatMessage> mergeStreamingHistory(
  List<ChatMessage> persisted,
  List<ChatMessage> live,
) {
  final merged = List<ChatMessage>.from(persisted);
  final indexById = <String, int>{};
  for (var i = 0; i < merged.length; i++) {
    indexById[merged[i].id] = i;
  }
  for (final message in live) {
    final index = indexById[message.id];
    if (index == null) {
      indexById[message.id] = merged.length;
      merged.add(message);
    } else {
      merged[index] = message;
    }
  }
  return merged;
}

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  InMemoryChatController? _controller;
  late final User _currentUser;
  late final User _aiUser;
  final List<ChatMessage> _history = [];

  /// Shortcut to the app-level [ChatAdapter] managed by [ChatStreamManager].
  /// The manager owns the adapter lifecycle, not the page.
  ChatAdapter get _adapter => ref.read(chatStreamManagerProvider).adapter;
  int _selectedModelIndex = 0;

  /// Saved model display name order for drag-sort persistence.
  List<String>? _savedModelOrder;

  /// Tracks streaming state locally so dispose() can check it without
  /// calling ref.read() (which throws after the widget is marked disposed).
  bool _isStreamingActive = false;

  /// Synchronous guard: set of conversation IDs that are currently in the
  /// async gap between passing the streaming guard in _onMessageSend and
  /// the synchronous _streams insertion in ChatStreamManager.startStreaming.
  /// Prevents double-send when the user rapidly presses Enter twice.
  final Set<String> _pendingSendConvIds = {};

  /// True while _editUserMessageWithText or _retryAssistantMessage is
  /// mutating history and controller messages, preventing
  /// _loadConversationMessages from interfering with the edit.
  bool _isModifyingHistory = false;

  final Map<String, List<String>> _reasoningContents = {};

  /// Tracks whether reasoning has completed for a given message.
  /// Set to true when the first [TextEvent] arrives after at least one
  /// [ReasoningEvent] has been received for the same message.
  /// Used to determine the reasoning button label during streaming:
  /// - false + streaming = "推理中" (reasoning still in progress)
  /// - true + streaming = "推理过程" (reasoning done, text being streamed)
  final Map<String, bool> _isReasoningCompletedForMsg = {};

  /// 是否展开"上下文已压缩"banner 的摘要预览。
  bool _showCompactionSummary = false;

  /// Tracks message IDs for which _buildFinalSegments has already run.
  /// Prevents _rebuildLiveSegments from overwriting finalized non-streaming
  /// segments with live streaming=true data, even if a late-arriving
  /// listener fires.
  final Set<String> _finalizedMessages = {};

  final Map<String, List<MessageSegment>> _chatSegments = {};

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

  /// Whether the chat list is currently being positioned so the top of the
  /// last user message is at the top of the viewport after a conversation
  /// load. While true, the message list is hidden (offstage) so the
  /// positioning pass is never visible to the user.
  bool _pendingInitialScrollAdjustment = false;

  /// ID of the conversation whose messages are currently shown in
  /// [_history]. Used to distinguish entry/conversation switches (which
  /// reposition to the last user message) from same-conversation reloads
  /// (which keep the built-in jump-to-bottom behavior).
  String? _loadedConversationId;

  /// Frame counter for the initial positioning pass — guards against
  /// pathological layouts looping forever.
  int _initialAdjustStepsTaken = 0;

  /// Whether the next frame of the initial positioning pass is already
  /// scheduled, so the pass advances at most one step per frame.
  bool _initialAdjustStepScheduled = false;

  /// Consecutive frames the pass has been chasing a growing bottom
  /// (maxScrollExtent still moving); capped by the pass so a fast
  /// background stream cannot keep the list hidden indefinitely.
  int _initialAdjustChaseFrames = 0;

  /// Captured scroll position before the keyboard opened, so it can be
  /// restored when the keyboard is dismissed.
  double? _lastScrollPositionBeforeKeyboard;

  /// Insets above which the soft keyboard is considered visible.
  /// Below this the keyboard is treated as (almost) gone.
  static const double _keyboardVisibleThreshold = 100;

  /// Approximate duration of the soft-keyboard dismiss animation remaining
  /// once the scroll restore kicks in (the keyboard is already mostly
  /// closed when the transition fires). The restore animates over roughly
  /// this so the list visibly follows the keyboard back down.
  static const Duration _keyboardAnimationDuration =
      Duration(milliseconds: 150);

  /// While true, the chat list keeps its bottom edge pinned to the viewport
  /// bottom: every viewport-height change (keyboard sliding up or down) is
  /// compensated with an equal scroll adjustment. This makes the list shift
  /// in lockstep with the keyboard animation instead of jumping late.
  bool _anchorToBottomWhileKeyboard = false;

  /// True while the user is touching/dragging the chat list. Used to keep
  /// the bottom pinning (and its pin release) from fighting user scrolls.
  bool _userIsDragging = false;

  /// True while the keyboard-dismiss scroll restore animation is running.
  /// The composer focus hook must not overwrite the saved pre-keyboard
  /// position while the restore is in flight (a mid-restore re-tap would
  /// otherwise capture a mid-animation offset as the new "saved" position).
  bool _isRestoringKeyboardScroll = false;

  /// True when the last keyboard-dismiss restore ran to completion (the
  /// position reached its target). Once that happened, the saved position
  /// is stale for the NEXT keyboard session: the open transition must
  /// re-save the current offset even though the field still holds a
  /// (non-null) saved value — e.g. after Android's back button hides the
  /// IME without unfocusing the composer, a re-tap on the still-focused
  /// field never fires the focus hook.
  bool _restoreCompletedSinceLastSave = false;

  /// Scroll offset reported by the previous [_onChatScroll] notification.
  /// A decrease (moving away from the bottom) can only come from a user
  /// drag/fling — the chat library's keyboard scrolls and the restore
  /// animation only ever move toward the bottom — so it releases the pin.
  double _lastReportedScrollPixels = 0;

  /// Chat area height (logical px) from the previous build, used to compute
  /// per-frame viewport-height deltas while the keyboard animation runs.
  double? _lastChatAreaHeight;

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

  /// Timer that auto-hides the edit data-loss warning overlay.
  Timer? _editWarningTimer;

  /// Whether the "editing will delete all messages below" warning overlay
  /// is currently visible in the message display area.
  bool _editWarningVisible = false;

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

  /// Guards against concurrent calls to [_loadConversationMessages].
  /// Prevents race conditions where message loading is triggered from
  /// multiple sources (init, provider listeners) simultaneously, which
  /// could dispose the chat controller mid-use and cause null errors.
  bool _isLoadingMessages = false;
  Completer<void>? _messageLoadCompleter;

  /// Requests one fresh load after the current load finishes. This prevents a
  /// completion or conversation switch during an async load from being lost
  /// to the in-flight guard.
  bool _reloadAfterLoading = false;

  /// Invalidates a load when the active conversation changes while it is
  /// awaiting persistence/logging/controller work.
  int _conversationLoadGeneration = 0;

  /// Whether there are more older messages to load.
  bool get _hasMoreMessages => _loadedUpToIndex > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = User(id: 'user1', name: 'You');
    _aiUser = User(id: 'ai1', name: 'Stroom');
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
    _editWarningTimer?.cancel();
    // The ChatStreamManager owns the adapter lifecycle. We do NOT cancel
    // or dispose it here — if streaming is active, it continues in the
    // background and saves results when complete. The adapter is cleaned
    // up when the manager is disposed (app lifecycle).
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
    final isNowVisible = bottomInset > _keyboardVisibleThreshold;
    // While the initial positioning pass runs the list is hidden; keyboard /
    // viewport changes must not fight the pass. Still track the keyboard
    // visibility flag so the post-pass close transition is not missed.
    if (_pendingInitialScrollAdjustment) {
      _wasKeyboardVisible = isNowVisible;
      return;
    }

    if (isNowVisible && !_wasKeyboardVisible) {
      // Keyboard just appeared — capture the pre-keyboard scroll position
      // (unless the composer focus hook already captured it for this
      // session, or a previous restore is still the source of truth),
      // then jump to the bottom immediately so the input area and latest
      // message are visible without waiting for the keyboard animation to
      // finish. The per-frame pinning in _onChatAreaResized then keeps the
      // list glued to the bottom while the keyboard keeps sliding up.
      if ((_lastScrollPositionBeforeKeyboard == null ||
              _restoreCompletedSinceLastSave) &&
          _chatScrollController.hasClients) {
        _lastScrollPositionBeforeKeyboard =
            _chatScrollController.position.pixels;
        _restoreCompletedSinceLastSave = false;
      }
      _scrollToBottom();
      _anchorToBottomWhileKeyboard = true;
    } else if (!isNowVisible && _wasKeyboardVisible) {
      // Keyboard just disappeared — stop pinning and smoothly scroll back
      // to the position captured before the keyboard opened.
      _anchorToBottomWhileKeyboard = false;
      _restoreScrollPositionAfterKeyboard();
    }
    _wasKeyboardVisible = isNowVisible;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeId = ref.watch(activeConversationIdProvider);
    final streamingConvs = ref.watch(streamingConversationsProvider);
    final isStreaming = activeId != null && streamingConvs.contains(activeId);
    final streamingFullReply =
        activeId != null ? ref.watch(streamingFullReplyProvider(activeId)) : '';
    final streamingMsgId =
        activeId != null ? ref.watch(streamingMsgIdProvider(activeId)) : null;

    // ── Streaming listeners (per-conversation via family providers) ──
    // Each listener watches its conversation's family instance. When the
    // user switches conversations, build() re-executes and the listeners
    // automatically re-register on the new conversation's families.
    // No _isStreamingForCurrentConv guard needed — families prevent cross-contamination.
    if (activeId != null) {
      _registerStreamingListeners(activeId);
    }
    // Detect background stream completion: when the current conversation
    // leaves the streaming set, the stream is done — run cleanup + reload
    // the finalized message from DB. This covers the re-entry case where
    // the original _startStreaming future belongs to a disposed page
    // instance and never runs its post-stream code here.
    _registerStreamingCompletionListener();
    // Reactively load messages when the active conversation changes.
    _registerActiveConversationListener();
    // Reactively load messages when conversations data finishes loading.
    _registerConversationsListener();
    // Re-configure adapter when provider entries change.
    _registerProviderEntriesListener();
    // Auto-save reasoning settings when they change (per-model persistence).
    _registerReasoningListeners();

    final adapterConfigured = _adapter.isConfigured;
    final controller = _controller;

    // Get conversation title
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
              _buildTopBar(title: title),
              // ── 上下文统计行（标题栏下方悬挂，opencode sidebar 风格）──
              if (activeId != null) _buildContextStatusLine(activeId),
              // ── Search bar ──
              if (_isSearching) _buildSearchBar(),
              // ── Unconfigured banner ──
              if (!adapterConfigured) _buildUnconfiguredBanner(),
              // ── 上下文已压缩 banner（可展开查看摘要） ──
              if (activeId != null) _buildCompactionBanner(activeId),
              // ── Chat widget ──
              Expanded(
                child: controller == null
                    ? const SizedBox.shrink()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          // Feed the chat area height into the
                          // keyboard-follow pinning logic.
                          _onChatAreaResized(constraints.maxHeight);
                          // While the initial positioning pass runs the list
                          // is kept mounted and laid out (message positions
                          // are measured from render boxes) but hidden, so
                          // the pass itself is never visible to the user.
                          return Visibility(
                            visible: !_pendingInitialScrollAdjustment,
                            maintainState: true,
                            child: Stack(
                              children: [
                                _buildChatWidget(
                                  isDark: isDark,
                                  isStreaming: isStreaming,
                                  streamingFullReply: streamingFullReply,
                                  streamingMsgId: streamingMsgId,
                                  activeId: activeId,
                                  controller: controller,
                                ),
                                // ── Scroll-to-bottom overlay button ──
                                if (_showScrollToBottomButton)
                                  _buildScrollToBottomButton(isDark: isDark),
                                // ── Edit data-loss warning overlay ──
                                // Centered in the message display area; auto-hides
                                // after 2 seconds or on close-button tap.
                                if (_editWarningVisible)
                                  _buildEditWarningOverlay(context: context),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // ── Chat composer (below chat, in Column flow) ──
              _buildComposer(
                activeId: activeId,
                currentDraftText: currentDraftText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
