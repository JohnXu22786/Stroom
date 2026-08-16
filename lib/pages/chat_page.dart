import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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
import '../utils/model_order.dart';

import '../models/chat_event.dart';
import '../models/chat_message.dart';
import '../models/tool_call.dart' show ToolCallData;
import '../models/assistant.dart' show Assistant;
import '../services/app_log_service.dart';
import '../services/chat_adapter.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_stream_provider.dart';
import '../providers/chat_manager_provider.dart';
import '../services/chat_stream_manager.dart' show StreamResult;
import '../providers/provider_config.dart';
import '../providers/assistant_provider.dart'
    show
        assistantProvider,
        resolveAssistantForSend,
        selectedAssistantIdProvider,
        selectedAssistantProvider;
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
import 'chat/chat_overlay_buttons.dart';

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

/// Scroll controller for the chat list that can swallow library-initiated
/// scrolls while a keyboard session is open.
///
/// flutter_chat_ui drives the same controller from its own debounced
/// keyboard handler (onKeyboardHeightChanged → controller.animateTo/jumpTo,
/// 100ms after the insets settle). That second scroll visibly fought the
/// page's own keyboard scroll — the user saw two scrolls per keyboard
/// open, the second one overshooting. While [swallowScrolls] is set the
/// library's calls become no-ops; the page's own scrolls go through
/// [ScrollPosition] directly (position.animateTo / position.jumpTo) and
/// are unaffected.
class _KeyboardAwareScrollController extends ScrollController {
  bool swallowScrolls = false;

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    if (swallowScrolls) return Future.value();
    return super.animateTo(to, duration: duration, curve: curve);
  }

  @override
  void jumpTo(double value) {
    if (swallowScrolls) return;
    super.jumpTo(value);
  }
}

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

  /// Scroll controller for the chat message list.
  late _KeyboardAwareScrollController _chatScrollController;

  /// Tracks whether the soft keyboard was visible in the previous metrics
  /// change, so [didChangeMetrics] can detect show/hide transitions for
  /// the keyboard scroll session. The keyboard-dismiss overlay BUTTON's
  /// own visibility is tracked by [ChatOverlayButtons] — this flag only
  /// drives the session, never the UI (a setState here would rebuild the
  /// whole message list on every keyboard transition).
  bool _wasKeyboardVisible = false;

  /// Bumped by the [ScrollMetricsNotification] handler (every frame any
  /// scroll metric moves, viewport-only changes included). [ChatOverlayButtons]
  /// listens to it to recompute its button visibility from the CURRENT
  /// metrics; without it, viewport-only changes (keyboard, composer
  /// growth) would leave the button stale, and recomputing here would
  /// mean a page-level setState (a full message-list rebuild) per flip.
  final ValueNotifier<int> _overlayMetricsTick = ValueNotifier(0);

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

  /// Distance from the bottom within which the list counts as "at the
  /// bottom": auto-scroll stays engaged. Shared with the overlay buttons'
  /// visibility via [ChatOverlayButtons.atBottomWindowPx] (single source).
  static const double _atBottomWindowPx = ChatOverlayButtons.atBottomWindowPx;

  /// True between the keyboard appearing and its dismissal. Used to keep
  /// the content-growth follow ([_followContentGrowth]) inert during the
  /// session — its instant jump would otherwise move the list while the
  /// keyboard is up.
  bool _keyboardFollowUpPending = false;

  /// True while the user is touching/dragging the chat list. Used by the
  /// content-growth follow ([_followContentGrowth]) to keep it from
  /// fighting a finger scroll (the keyboard bottom-pinning that originally
  /// introduced this flag was reverted).
  bool _userIsDragging = false;

  /// Last OBSERVED content extent (maxScrollExtent + viewportDimension —
  /// the list's total content height) from [_followContentGrowth] metrics
  /// notifications. The metrics notification fires for every metric change
  /// (pixels during ordinary scrolls, and maxScrollExtent when the viewport
  /// shrinks too), so the follow only acts when the observed content extent
  /// strictly grows — i.e. the content grew or the sliver corrected its
  /// extent estimate. A pure pixel change (a user scroll, even one stopping
  /// within the at-bottom window) or a viewport-only change (composer
  /// growing, window resize) never re-pins; a content shrink re-arms the
  /// gate for the next growth. Reset when the list is replaced (conversation
  /// switch, view clear) — the extent belongs to the previous list.
  double? _lastFollowContentExtent;
  bool _isSearching = false;
  SearchMode _searchMode = SearchMode.current;
  String _searchQuery = '';
  final List<SearchMatch> _searchMatches = [];
  int _currentMatchIndex = 0;
  final TextEditingController _searchTextController = TextEditingController();
  final Map<String, GlobalKey> _messageKeys = {};

  /// In-flight search navigation (may be loading older paginated messages).
  /// Serializes rapid up/down taps so a newer tap waits for the previous
  /// one's loads instead of racing them (load-more refuses concurrent runs).
  Future<void>? _pendingSearchScroll;

  bool _developerMode = false;
  final Map<String, bool> _expandedErrors = {};

  // ── Edit mode state ──
  /// When set, the composer enters edit mode for this message.
  String? _editingMessageId;

  /// The text of the message being edited.
  String? _editingMessageText;

  /// The original attachments of the message being edited.
  List<Attachment>? _editingMessageAttachments;

  /// Whether the composer should arm the "editing will delete all messages
  /// below" warning when entering edit mode. True when the edited message
  /// has newer messages below it; the warning itself (its reveal timing
  /// and auto-hide) is owned by the composer, which shows it in the edit
  /// capsule's row.
  bool _showEditWarningOnEntry = false;

  /// Bumped on every explicit edit entry so the composer can re-arm the
  /// warning even when the same message is edited again (the editingMessageId
  /// alone wouldn't change on a same-message re-entry).
  int _editWarningArmCount = 0;

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

  /// True once the user has reached the top of the list while no older
  /// messages remain — shows the "没有更多内容了" hint above the first
  /// message. Reset when the conversation view is cleared or reloaded.
  bool _hasReachedTopWithoutMore = false;

  /// Bumped when a pagination load starts. The load's `finally` only clears
  /// [_isLoadingMore] if its captured generation is still current — a stale
  /// load that outlived a conversation switch (its 500ms minimum-display
  /// delay is still pending) must not clear the flag of a load that started
  /// in the new conversation.
  int _loadMoreGeneration = 0;

  /// Minimum display duration of the top load-more indicator. The spinner
  /// must stay up for at least this long even when the page loads
  /// instantly, otherwise it flashes for a single frame.
  static const Duration _loadMoreMinDisplayDuration =
      Duration(milliseconds: 500);

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
    _chatScrollController = _KeyboardAwareScrollController();
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
    // 使进行中的加载失效：卡在 0.5 秒最少显示延迟里的加载在延迟结束后
    // 不得再向已 dispose 的控制器插入消息。
    _loadMoreGeneration++;
    // The ChatStreamManager owns the adapter lifecycle. We do NOT cancel
    // or dispose it here — if streaming is active, it continues in the
    // background and saves results when complete. The adapter is cleaned
    // up when the manager is disposed (app lifecycle).
    _controller?.dispose();
    _searchTextController.dispose();
    _chatScrollController.removeListener(_onChatScroll);
    _chatScrollController.dispose();
    _overlayMetricsTick.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    // Read the inset from the VIEW, not the inherited MediaQuery: the
    // page sits inside HomePage's Scaffold, which strips
    // viewInsets.bottom from the body's MediaQuery (resizeToAvoidBottom-
    // Inset consumes it), so MediaQuery would always report 0 here and
    // the whole keyboard session would never run on device. The view is
    // fresh even inside this callback.
    final bottomInset = _currentKeyboardInset();
    final isNowVisible =
        bottomInset > ChatOverlayButtons.keyboardVisibleThreshold;
    // While the initial positioning pass runs the list is hidden; keyboard /
    // viewport changes must not fight the pass. Still track the keyboard
    // visibility flag so the post-pass close transition is not missed.
    if (_pendingInitialScrollAdjustment) {
      _wasKeyboardVisible = isNowVisible;
      return;
    }
    // The page stays mounted (IndexedStack keep-alive) while other main
    // pages are shown. Keyboard insets are app-global, so a keyboard that
    // opens on another tab must not hijack the chat scroll session (it would
    // scroll the hidden list to the bottom and corrupt the saved reading
    // position). Only the closing transition is still honored while hidden,
    // so switching away mid-keyboard still restores the reading spot.
    if (!Visibility.of(context) && isNowVisible && !_wasKeyboardVisible) {
      return;
    }

    if (isNowVisible && !_wasKeyboardVisible) {
      // Keyboard just appeared — start the keyboard session. The list is
      // NOT scrolled (the user asked for no keyboard scroll at all): it
      // stays where it is; the Scaffold shrinks the viewport around it.
      // The library's own debounced keyboard scroll is swallowed for the
      // session so it cannot move the list either.
      _keyboardFollowUpPending = true;
      _chatScrollController.swallowScrolls = true;
    } else if (!isNowVisible && _wasKeyboardVisible) {
      // Keyboard just disappeared — end the keyboard session. The list is
      // not moved on dismiss.
      _restoreScrollPositionAfterKeyboard();
    }
    // NO setState here — and no post-frame button recompute. The
    // keyboard-dismiss overlay button tracks the keyboard itself
    // ([ChatOverlayButtons] is a WidgetsBindingObserver), and the scroll-
    // to-bottom button recomputes itself from the current metrics on the
    // same triggers. A page-level setState on the keyboard transition
    // rebuilt the whole chat page — and with it every visible markdown
    // message (MarkdownWidget re-parses the markdown on any rebuild) —
    // which dropped frames during the keyboard open/close animation.
    // The session flags above drive the scroll behavior only.
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
    // Re-run the model restore chain when the assistant list finishes
    // loading (rules: assistant default / first model fallback).
    _registerAssistantListener();
    // Auto-save reasoning settings when they change (per-model persistence).
    _registerReasoningListeners();

    final adapterConfigured = _adapter.isConfigured;
    final controller = _controller;

    // Get conversation title
    final conversations = ref.watch(conversationsProvider);
    String title = '新对话';
    String currentDraftText = '';
    List<Attachment> currentDraftAttachments = const [];
    if (activeId != null) {
      final conv = conversations.where((c) => c.id == activeId).firstOrNull;
      if (conv != null) {
        if (conv.title.isNotEmpty) title = conv.title;
        currentDraftText = conv.draftText;
        currentDraftAttachments = conv.draftAttachments;
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
                    : Visibility(
                        // While the initial positioning pass runs the list is
                        // kept mounted and laid out (message positions are
                        // measured from render boxes) but hidden, so the
                        // pass itself is never visible to the user.
                        visible: !_pendingInitialScrollAdjustment,
                        maintainState: true,
                        // The message list is part of the composer's tap
                        // region group ([chatComposerTapRegionGroupId]): with
                        // the app-wide tap-outside blur, touching the list to
                        // scroll while composing must NOT unfocus the
                        // composer — the keyboard stays up while the user
                        // reads/scrolls (dismissed via the keyboard's own
                        // close key or the page's keyboard-dismiss button).
                        child: TextFieldTapRegion(
                          groupId: chatComposerTapRegionGroupId,
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
                              // ── Overlay buttons (scroll-to-bottom +
                              // keyboard-dismiss) ──
                              // A self-contained widget: it owns BOTH
                              // buttons' visibility state (keyboard state
                              // via its own WidgetsBindingObserver reading
                              // the view insets; scroll-button state
                              // recomputed from the current list metrics).
                              // Keyboard transitions and at-bottom flips
                              // therefore rebuild ONLY this small overlay
                              // — never the message list (whose markdown
                              // messages re-parse on every rebuild, which
                              // dropped frames during the keyboard
                              // animation).
                              Positioned.fill(
                                child: ChatOverlayButtons(
                                  scrollController: _chatScrollController,
                                  metricsTick: _overlayMetricsTick,
                                  isDark: isDark,
                                  onScrollToBottomTap: _onScrollToBottomTap,
                                  onKeyboardDismissTap: () =>
                                      FocusScope.of(context).unfocus(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              // ── Chat composer (below chat, in Column flow) ──
              _buildComposer(
                activeId: activeId,
                currentDraftText: currentDraftText,
                currentDraftAttachments: currentDraftAttachments,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
