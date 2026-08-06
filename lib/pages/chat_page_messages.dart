part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageMessagesExt on _ChatPageState {
  Future<void> _initialize() async {
    await AppLogService.info('ChatPage', '开始初始化聊天页面');
    _configureAdapter();
    // Initialize built-in tools (HTTP tools) first — independent of MCP
    // server connectivity. This ensures HTTP tools (brave_web_search,
    // bocha_web_search, querit_search, searxng_search) are always
    // available in the tool list even if MCP servers are unreachable.
    final entriesState = ref.read(providerEntriesProvider);
    _adapter.initializeBuiltinTools(entriesState);

    // ── Restore streaming state BEFORE MCP server init ──
    // The synchronous part of _restoreStreamingState sets
    // _isStreamingActive=true and streaming providers immediately so
    // that throttled provider updates from the manager (every 200ms)
    // continue to render live segments during the 1–2 s MCP discovery
    // await below. Without this, _rebuildLiveSegments bails out via
    // `if (!_isStreamingActive) return;` and the UI freezes.
    _restoreStreamingState();
    await AppLogService.info('ChatPage',
        '[STREAM-INIT] _initialize: _restoreStreamingState called, _isStreamingActive=$_isStreamingActive _streamingMsgId=$_streamingMsgId');

    // Load conversation messages after restoring a background stream. This
    // lets the loader merge the manager's live history with the persisted
    // snapshot instead of briefly replacing it with stale data.
    await _loadConversationMessages();

    // Then discover MCP server tools (SSE / stdio) dynamically.
    // MCP discovery failures don't affect already-registered built-in tools.
    // Re-read the entries state here: the snapshot taken at the top of
    // _initialize may predate ProviderEntriesNotifier.load() completing
    // (async SharedPreferences + migrations). Passing the stale (possibly
    // empty) snapshot would skip MCP discovery entirely and leave the tool
    // list at built-in-only.
    try {
      final freshEntriesState =
          mounted ? ref.read(providerEntriesProvider) : null;
      await AppLogService.info('ChatPage',
          '开始初始化 MCP 服务器，当前有 ${freshEntriesState?.entries.length ?? 0} 个供应商配置');
      if (freshEntriesState != null) {
        await _adapter.initializeMcpServers(freshEntriesState);
        // MCP tools may have been discovered AFTER _loadConversationMessages
        // resolved the enabled set. Re-resolve so newly discovered MCP tools
        // are auto-enabled for conversations without explicit prefs — this
        // matches resolveEnabledToolNames' contract ("no saved preferences →
        // enable all available tools") and keeps the badge/list at the full
        // count (12) instead of 7 on first entry.
        if (mounted) _resolveEnabledToolsForActiveConversation();
      }
      await AppLogService.info('ChatPage', 'MCP 服务器初始化完成');
    } finally {
      // Rebuild UI so the tool panel reflects the newly discovered MCP tools.
      // Must check mounted because the async gap may outlive the widget.
      if (mounted) setState(() {});
      // 工具启用集已在 MCP 发现完成后重新解析：无显式偏好的新对话默认
      // 启用全部可用工具；有显式偏好（用户手动开关过）的对话保留其
      // 保存的选择。使用 finally 确保 MCP 发现错误不会阻断其余初始化。
    }
    // Restore saved model selection and restore per-model settings
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      _restoreSavedModelSelection(prefs);
    });
    await AppLogService.info('ChatPage', '[STREAM-INIT] _initialize complete');
  }

  /// Loads the previous page of older messages and prepends them to the
  /// chat controller. Called by [ChatAnimatedList.onEndReached] when the user
  /// scrolls near the top of the message list.
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    _isLoadingMore = true;
    if (mounted) setState(() {});

    try {
      final newStart = _loadedUpToIndex >= _ChatPageState._pageSize
          ? _loadedUpToIndex - _ChatPageState._pageSize
          : 0;
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

  void _clearConversationView() {
    // The warning refers to the previous conversation's messages — a stale
    // overlay would be misleading after switching conversations.
    _hideEditWarning();
    final oldCtrl = _controller;
    _controller = InMemoryChatController();
    _history.clear();
    _chatSegments.clear();
    _reasoningContents.clear();
    _finalizedMessages.clear();
    _streamingMsgId = null;
    _isStreamingActive = false;
    _messageKeys.clear();
    _expandedErrors.clear();
    _loadedUpToIndex = 0;
    _isLoadingMore = false;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldCtrl?.dispose();
    });
  }

  void _scheduleReloadAfterBlockingOperation() {
    if (!_reloadAfterLoading || !mounted || _isLoadingMessages) return;
    if (_isModifyingHistory) return;
    _reloadAfterLoading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversationMessages();
    });
  }

  Future<void> _loadConversationMessages() async {
    // Guard: prevent concurrent calls to _loadConversationMessages.
    // Multiple sources can trigger message loading (init, provider
    // listeners for conversationsProvider, activeConversationIdProvider)
    // and without this guard they race — one call might dispose the
    // controller while another is using it, causing null errors.
    if (_isLoadingMessages) {
      _reloadAfterLoading = true;
      await AppLogService.info('ChatPage',
          '[STREAM-LOAD] _loadConversationMessages: already loading, skip');
      final pendingLoad = _messageLoadCompleter;
      if (pendingLoad != null) await pendingLoad.future;
      return;
    }
    // Guard: do NOT reload while editing or retrying — the edit flow
    // truncates _history and would be corrupted by a concurrent reload.
    if (_isModifyingHistory) {
      _reloadAfterLoading = true;
      return;
    }

    // Guard: do NOT reload messages while streaming is active AND history
    // is already populated. The streaming loop relies on _chatSegments and
    // other per-message state that would be cleared by a reload.
    //
    // HOWEVER: if history is empty, the initial load never completed
    // (e.g. conversation data wasn't ready when _initialize ran). In that
    // case we MUST load history now, preserving the streaming state so
    // live segments continue to render while historical messages fill in.
    if (_isStreamingActive && _history.isNotEmpty) {
      await AppLogService.info('ChatPage',
          '[STREAM-LOAD] _loadConversationMessages: streaming active + history has ${_history.length} msgs, skip');
      return;
    }

    _isLoadingMessages = true;
    final loadCompleter = Completer<void>();
    _messageLoadCompleter = loadCompleter;
    final loadGeneration = ++_conversationLoadGeneration;
    try {
      final activeId = ref.read(activeConversationIdProvider);
      bool isCurrentLoad() =>
          mounted &&
          loadGeneration == _conversationLoadGeneration &&
          ref.read(activeConversationIdProvider) == activeId;
      final convs = ref.read(conversationsProvider);
      await AppLogService.info('ChatPage',
          '[STREAM-LOAD] _loadConversationMessages: activeId=$activeId convCount=${convs.length}');
      if (activeId == null) {
        await AppLogService.warning(
            'ChatPage', '[STREAM-LOAD] activeConversationId is null, skip');
        if (isCurrentLoad()) _clearConversationView();
        return;
      }
      final conv = convs.where((c) => c.id == activeId).firstOrNull;
      if (conv == null) {
        await AppLogService.warning(
            'ChatPage', '未找到 activeConversationId=$activeId 对应的对话');
      }

      final liveHistory = _isStreamingActive
          ? ref.read(chatStreamManagerProvider).historyFor(activeId)
          : const <ChatMessage>[];
      final messages = mergeStreamingHistory(
        conv?.messages ?? const <ChatMessage>[],
        liveHistory,
      );

      if (!isCurrentLoad()) return;

      // Restore per-conversation model selection if this conversation was
      // previously used with a specific model. The conversation's last used
      // model takes priority over the globally saved model index.
      if (conv != null &&
          conv.lastUsedModelName != null &&
          conv.lastUsedModelName!.isNotEmpty) {
        _selectModelByName(conv.lastUsedModelName!);
      }

      // Restore per-conversation enabled MCP/built-in tool names.
      // If the conversation has saved tool preferences, use them.
      // Otherwise, default to ALL tools enabled at load time so that
      // built-in remote SSE MCP providers (and user-added MCPs) are
      // immediately visible in the chat page's tool list without
      // requiring the user to manually toggle each one on. Users can
      // still opt-out specific tools via the "工具" panel — the
      // toggled-off state is then persisted into
      // conv.enabledMcpToolNames + conv.hasExplicitEnabledMcpTools on
      // the next save.
      _resolveEnabledToolsForActiveConversation();
      if (messages.isEmpty) {
        _clearConversationView();
        return;
      }

      // Save streaming state before clearing, in case we're loading
      // history while a stream is active (_isStreamingActive && _history.isEmpty).
      final savedStreamingMsgId = _isStreamingActive ? _streamingMsgId : null;
      final savedChatSegments = _isStreamingActive
          ? Map<String, List<MessageSegment>>.from(_chatSegments)
          : null;
      final savedFinalizedMessages =
          _isStreamingActive ? Set<String>.from(_finalizedMessages) : null;
      final savedReasoningContents = _isStreamingActive
          ? Map<String, List<String>>.from(_reasoningContents)
          : null;
      bool keepLiveStream() =>
          savedStreamingMsgId != null &&
          _isStreamingActive &&
          ref.read(chatStreamManagerProvider).isStreamingFor(activeId);

      // ── Build new controller before swapping to avoid visual flash ──
      // Populate a local controller FIRST with all messages, then atomically
      // swap _controller. The old controller stays alive (and visible) during
      // the entire populate step; the widget only sees the new controller
      // after the final setState() call.
      final newCtrl = InMemoryChatController();
      // Keep oldCtrl for deferred disposal below.
      final loadedHistory = <ChatMessage>[];
      final loadedChatSegments = <String, List<MessageSegment>>{};
      final loadedReasoningContents = <String, List<String>>{};
      // Load all messages into _history (needed for full context in API calls
      // and search), but only insert the last _pageSize messages into the
      // controller for display (lazy loading).
      final msgCount = messages.length;
      await AppLogService.info('ChatPage', '开始加载 $msgCount 条消息到 _history');
      for (final msg in messages) {
        loadedHistory.add(msg);
        // Restore reasoning sections from persisted ChatMessage.
        // Prefer the new multi-section [reasoningSections] field over the
        // legacy single-string [reasoningContent] for backward compatibility.
        if (msg.reasoningSections != null &&
            msg.reasoningSections!.isNotEmpty) {
          loadedReasoningContents[msg.id] =
              List<String>.from(msg.reasoningSections!);
        } else if (msg.reasoningContent != null &&
            msg.reasoningContent!.isNotEmpty) {
          loadedReasoningContents[msg.id] = [msg.reasoningContent!];
        }

        // Build unified segments for the full Agent chain.
        // Build segments from blocks (unified path since v0.4.50).
        // If blocks are absent (periodic persist or old data), build
        // them from legacy fields on the fly.
        final blocks = msg.blocks ??
            legacyToBlocks(
              reasoningSections: msg.reasoningSections ?? [],
              textChunks: msg.textSections ?? [],
              toolCalls: msg.toolCalls ?? [],
              toolCallRoundStarts: msg.toolCallRoundStarts ?? [],
            );
        final segments = blocksToSegments(blocks);
        // Fallback: no textSections, use content as single trailing block
        if (segments.isEmpty && msg.content.isNotEmpty) {
          segments.add(TextSegment(msg.content));
        } else if (msg.textSections == null && msg.content.isNotEmpty) {
          segments.add(TextSegment(msg.content));
        }
        if (segments.isNotEmpty) {
          loadedChatSegments[msg.id] = segments;
        }
      }
      final loadedUpToIndex = loadedHistory.length >= _ChatPageState._pageSize
          ? loadedHistory.length - _ChatPageState._pageSize
          : 0;
      await AppLogService.info(
          'ChatPage',
          '消息加载完成: _history 共 ${loadedHistory.length} 条, '
              'loadedUpToIndex=$loadedUpToIndex');
      for (var i = loadedUpToIndex; i < loadedHistory.length; i++) {
        final msg = loadedHistory[i];
        // When loading during an active stream, skip the streaming
        // message — it is restored separately below as a
        // live Message.text with the current fullReply from the manager.
        if (msg.id == savedStreamingMsgId && keepLiveStream()) continue;
        await newCtrl.insertMessage(
          Message.text(
            id: msg.id,
            authorId: msg.role == 'user' ? _currentUser.id : _aiUser.id,
            text: msg.content,
            createdAt: msg.createdAt,
          ),
        );
      }
      if (!isCurrentLoad()) {
        newCtrl.dispose();
        return;
      }
      await AppLogService.info(
          'ChatPage', '控制器消息插入完成，共 ${newCtrl.messages.length} 条');
      if (!isCurrentLoad()) {
        newCtrl.dispose();
        return;
      }
      // ── Atomically swap controllers ──
      final liveStreamStillActive = keepLiveStream();
      if (savedStreamingMsgId != null && !liveStreamStillActive) {
        if (_isStreamingActive) _reloadAfterLoading = true;
        _isStreamingActive = false;
      }
      _history
        ..clear()
        ..addAll(loadedHistory);
      _chatSegments
        ..clear()
        ..addAll(loadedChatSegments);
      _reasoningContents
        ..clear()
        ..addAll(loadedReasoningContents);
      _finalizedMessages.clear();
      _streamingMsgId = null;
      _messageKeys.clear();
      _expandedErrors.clear();
      // 压缩摘要 banner 的展开态是页面级标志：切对话时重置
      // （否则旧对话的展开状态跨对话残留）
      _showCompactionSummary = false;
      // 保留搜索状态（用户正在搜索时后台流完成触发的重载不应
      // 静默关闭搜索）：保留 query 并按新历史重跑匹配；仅当
      // 未在搜索时才清空。
      if (_isSearching) {
        final searchQuery = _searchQuery;
        _searchMatches.clear();
        _currentMatchIndex = 0;
        if (searchQuery.isNotEmpty) {
          _performSearch(searchQuery);
        }
      } else {
        _searchTextController.clear();
        _isSearching = false;
        _searchQuery = '';
        _searchMatches.clear();
        _currentMatchIndex = 0;
      }
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
      // The data-loss warning refers to the previous conversation's
      // messages — a stale overlay would be misleading after a reload or
      // conversation switch (same lifecycle as the edit-mode state above).
      _hideEditWarning();
      _isLoadingMore = false;
      _loadedUpToIndex = loadedUpToIndex;
      final oldCtrl = _controller;
      _controller = newCtrl;
      // Defer disposing the old controller until after the widget tree
      // has rebuilt (next frame). Between the swap above and setState()
      // below, callbacks may still reference the old controller.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldCtrl?.dispose();
      });
      // Restore streaming state that we saved before the clear,
      // so the live streaming UI continues to work while we
      // display the now-loaded historical messages.
      if (savedStreamingMsgId != null && liveStreamStillActive) {
        _streamingMsgId = savedStreamingMsgId;
        _chatSegments.addAll(savedChatSegments!);
        _finalizedMessages.addAll(savedFinalizedMessages!);
        _reasoningContents.addAll(savedReasoningContents!);
        // 从 manager 恢复**最新**推理内容：切换前保存的快照可能过时
        // （切走期间流继续推进），而 provider 推送发生在监听重注册
        // 之前、监听器不会触发——否则推理按钮内容为空/状态错误
        // （按钮显示"思考中"、面板为空），直到流结束重载才恢复。
        final liveReasoning =
            ref.read(streamingReasoningSectionsProvider(activeId));
        if (liveReasoning.isNotEmpty) {
          _reasoningContents[savedStreamingMsgId] =
              List<String>.from(liveReasoning);
          _isReasoningCompletedForMsg[savedStreamingMsgId] = true;
        }

        // Re-insert the streaming placeholder into the new controller.
        // We skipped it during the load loop above (it may not be in DB
        // yet if periodic persist hasn't run), so restore it now as a
        // live Message.text so it renders through the normal textMessageBuilder
        // (gray bubble + segments) instead of textStreamMessageBuilder (raw
        // white-background Markdown). Streaming listeners will continue to
        // update it via _updateStreamingMessage.
        final inCtrl =
            _controller?.messages.any((m) => m.id == savedStreamingMsgId) ??
                false;
        if (!inCtrl) {
          final restoredFullReply =
              ref.read(chatStreamManagerProvider).fullReplyFor(activeId);
          _controller?.insertMessage(
            Message.text(
              id: savedStreamingMsgId,
              authorId: _aiUser.id,
              text: restoredFullReply,
              createdAt: DateTime.now(),
            ),
          );
        }
        // The persisted copy may contain only an older partial response. Use
        // the restored provider state immediately so the live bubble keeps
        // its complete reasoning/tool/text segments after the controller swap.
        _rebuildLiveSegments(savedStreamingMsgId);
      }
      if (mounted) setState(() {});
    } catch (e, s) {
      debugPrint('[ChatPage] _loadConversationMessages error: $e\n$s');
      await AppLogService.error('ChatPage', '加载对话消息失败', e, s);
    } finally {
      _isLoadingMessages = false;
      if (identical(_messageLoadCompleter, loadCompleter)) {
        _messageLoadCompleter = null;
      }
      if (!loadCompleter.isCompleted) loadCompleter.complete();
      _scheduleReloadAfterBlockingOperation();
    }
  }

  Future<void> _ensureHistoryLoaded(String convId) async {
    final pendingLoad = _messageLoadCompleter;
    if (_isLoadingMessages && pendingLoad != null) {
      await pendingLoad.future;
    }
    if (!mounted || ref.read(activeConversationIdProvider) != convId) return;

    final conversation = ref
        .read(conversationsProvider)
        .where((conversation) => conversation.id == convId)
        .firstOrNull;
    if (conversation != null &&
        conversation.messages.length > _history.length &&
        !_isStreamingActive) {
      await _loadConversationMessages();
    }
  }

  Future<void> _syncHistoryFromProvider({String? capturedConvId}) async {
    if (!mounted) return;
    final convId = capturedConvId ?? ref.read(activeConversationIdProvider);
    if (convId == null || convId.isEmpty) return;
    if (ref.read(activeConversationIdProvider) != convId) return;
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == convId).firstOrNull;
    if (conv != null && ref.read(activeConversationIdProvider) == convId) {
      _history.clear();
      _history.addAll(conv.messages);
    }
  }

  /// Resolves the enabled tool names for the active conversation using the
  /// adapter's CURRENT tool definitions (built-in + discovered MCP tools).
  ///
  /// - Conversations with explicit saved prefs keep their saved selection.
  /// - New conversations (no explicit prefs) auto-enable EVERY available
  ///   tool — including MCP tools discovered after the initial message load.
  ///
  /// Called both from [_loadConversationMessages] and after MCP discovery
  /// completes in [_initialize], so that MCP tools discovered asynchronously
  /// are immediately visible and enabled (badge/list show the full count)
  /// instead of staying OFF until the next conversation switch.
  void _resolveEnabledToolsForActiveConversation() {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;
    final convs = ref.read(conversationsProvider);
    final conv = convs.where((c) => c.id == activeId).firstOrNull;
    final convEnabled = (conv != null)
        ? Set<String>.from(conv.enabledMcpToolNames)
        : <String>{};
    final hasExplicitPrefs = conv?.hasExplicitEnabledMcpTools ?? false;
    ref.read(enabledToolNamesProvider.notifier).state = resolveEnabledToolNames(
      allTools: _adapter.getAllToolDefinitions(),
      savedEnabledNames: convEnabled,
      hasExplicitSavedPrefs: hasExplicitPrefs,
    );
  }
}
