part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageListenersExt on _ChatPageState {
  /// Registers per-conversation streaming listeners (family providers).
  /// Each listener watches its conversation's family instance. When the
  /// user switches conversations, build() re-executes and the listeners
  /// automatically re-register on the new conversation's families.
  /// No _isStreamingForCurrentConv guard needed — families prevent cross-contamination.
  void _registerStreamingListeners(String convId) {
    ref.listen(streamingFullReplyProvider(convId), (String? prev, String next) {
      if (!mounted || next.isEmpty || next == prev) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _updateStreamingMessage(msgId, next);
      _rebuildLiveSegments(msgId);
      if (mounted) setState(() {});
    });

    ref.listen(streamingReasoningSectionsProvider(convId),
        (List<String>? prev, List<String> next) {
      if (!mounted || next.isEmpty || identical(prev, next)) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _reasoningContents[msgId] = List<String>.from(next);
      _rebuildLiveSegments(msgId);
      // Reset reasoning-completed flag whenever reasoning sections change.
      // Previously only reset when section count grew, but content updates
      // (e.g. ReasoningEvent filling an empty placeholder) don't change
      // the count. Without this, the button shows "思考完成" while new
      // reasoning is still arriving.
      _isReasoningCompletedForMsg[msgId] = false;
      if (mounted) setState(() {});
    });

    ref.listen(streamingHasFirstTokenProvider(convId), (bool? prev, bool next) {
      if (!mounted || !next) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      if ((_reasoningContents[msgId]?.length ?? 0) > 0) {
        _isReasoningCompletedForMsg[msgId] = true;
        if (mounted) setState(() {});
      }
    });

    ref.listen(streamingToolCallsProvider(convId),
        (List<ToolCallData>? prev, List<ToolCallData> next) {
      if (!mounted || next.isEmpty || identical(prev, next)) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _rebuildLiveSegments(msgId);
      if (mounted) setState(() {});
    });

    ref.listen(streamingTextSectionsProvider(convId),
        (List<String>? prev, List<String> next) {
      if (!mounted || next.isEmpty || identical(prev, next)) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _isReasoningCompletedForMsg[msgId] = true;
      _rebuildLiveSegments(msgId);
      if (mounted) setState(() {});
    });
  }

  /// Detects background stream completion: when the current conversation
  /// leaves the streaming set, the stream is done — run cleanup + reload
  /// the finalized message from DB. This covers the re-entry case where
  /// the original _startStreaming future belongs to a disposed page
  /// instance and never runs its post-stream code here.
  void _registerStreamingCompletionListener() {
    ref.listen(streamingConversationsProvider,
        (Set<String>? prev, Set<String> next) {
      if (!mounted) return;
      final activeConvId = ref.read(activeConversationIdProvider);
      if (activeConvId == null) return;
      final wasStreaming = prev?.contains(activeConvId) ?? false;
      final isStreaming = next.contains(activeConvId);
      if (wasStreaming && !isStreaming && _isStreamingActive) {
        final capturedMsgId = _streamingMsgId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _streamingMsgId == capturedMsgId) {
            _handleStreamCompletion();
          }
        });
      }
    });
  }

  /// Reactively loads messages when the active conversation changes.
  /// Also activates the conversation in the streaming manager so the
  /// global providers reflect this conversation's streaming state.
  /// Resets the per-page streaming flags so stale state from the
  /// previous conversation doesn't affect the new one.
  void _registerActiveConversationListener() {
    ref.listen(activeConversationIdProvider, (prev, next) {
      if (next != prev) _conversationLoadGeneration++;
      if (next == null && next != prev) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(activeConversationIdProvider) == null) {
            _clearConversationView();
          }
        });
        return;
      }
      if (next != null && next != prev) {
        // Check streaming state FIRST, then set flags, THEN activate
        // (so listeners fired by activateConversation see correct flags).
        final manager = ref.read(chatStreamManagerProvider);
        final targetIsStreaming = manager.isStreamingFor(next);
        _isStreamingActive = targetIsStreaming;
        _streamingMsgId =
            targetIsStreaming ? manager.streamingMsgIdFor(next) : null;
        // Clear _history so _loadConversationMessages passes the guard
        // (`if (_isStreamingActive && _history.isNotEmpty) return;`).
        // Without this, switching from a streaming conversation to another
        // and back leaves _history populated with stale data from the other
        // conversation, causing the guard to short-circuit the reload and
        // losing _chatSegments for completed messages (plain text only, no
        // tool call cards or reasoning buttons).
        _history.clear();
        // Also clear per-message maps so stale entries from the previous
        // conversation don't leak into _loadConversationMessages'
        // save/restore block, which would cross-contaminate segment data.
        _chatSegments.clear();
        _reasoningContents.clear();
        _finalizedMessages.clear();
        _isReasoningCompletedForMsg.clear();
        // Abandon any keyboard scroll session from the previous
        // conversation — its saved position and pinning belong to a list
        // that is about to be replaced.
        _lastScrollPositionBeforeKeyboard = null;
        _anchorToBottomWhileKeyboard = false;
        _isRestoringKeyboardScroll = false;
        _restoreCompletedSinceLastSave = false;
        manager.activateConversation(next);
        // Only schedule _loadConversationMessages for actual conversation
        // SWITCHES (prev != null), not for the initial registration of this
        // listener (prev == null). During init, _initialize() already calls
        // _loadConversationMessages + _restoreStreamingState, so a second
        // load would clear the in-progress UI and cause user messages to
        // appear incomplete for 1-2 seconds before re-rendering.
        // Capture the target conversation ID so rapid C1→C2→C3 switches
        // don't load the wrong conversation (the post-frame reads
        // activeConversationIdProvider which may have changed).
        if (prev != null) {
          final capturedConvId = next;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                ref.read(activeConversationIdProvider) == capturedConvId) {
              _loadConversationMessages();
            }
          });
        }
      }
    });
  }

  /// Reactively loads messages when conversations data finishes loading
  /// (e.g., after async _load() in ConversationsNotifier completes).
  void _registerConversationsListener() {
    ref.listen(conversationsProvider, (prev, next) {
      if (prev != next) {
        // Detect deleted conversations: if a conversation that was
        // streaming was removed from the list, cancel its orphaned
        // stream. Otherwise the persist timer runs indefinitely and
        // the stream never cleans up.
        if (prev != null) {
          final deletedIds = prev
              .map((c) => c.id)
              .toSet()
              .difference(next.map((c) => c.id).toSet());
          final streamingConvs = ref.read(streamingConversationsProvider);
          for (final deletedId in deletedIds) {
            if (streamingConvs.contains(deletedId)) {
              ref.read(chatStreamManagerProvider).cancel(deletedId);
              final updated = <String>{...streamingConvs}..remove(deletedId);
              ref.read(streamingConversationsProvider.notifier).state = updated;
            }
          }
        }
        final activeId = ref.read(activeConversationIdProvider);
        if (activeId != null) {
          final activeConv = next.where((c) => c.id == activeId).firstOrNull;
          if (activeConv != null && activeConv.messages.isNotEmpty) {
            // Only reload if there's a mismatch: either history is empty
            // (initial load hadn't completed) OR the loaded conversation
            // has more messages than we currently have (e.g. data arrived
            // after user sent a message, so _history only has the new
            // message but not the history).
            if (_history.isEmpty ||
                (_history.length < activeConv.messages.length &&
                    !_isStreamingActive &&
                    !_isLoadingMessages &&
                    !_isModifyingHistory)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadConversationMessages();
              });
            }
          }
        }
      }
    });
  }

  /// Re-configures the adapter when provider entries change (e.g. after
  /// load completes), re-initializing built-in and MCP tools.
  void _registerProviderEntriesListener() {
    ref.listen(providerEntriesProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          _configureAdapter();
          // Re-initialize built-in and MCP tools with the updated provider
          // data. initializeMcpServers is lazy (publishes placeholders only,
          // no network; connections happen on tool calls) and skips when the
          // MCP entry instance is unchanged, so this is safe to call
          // repeatedly.
          final entriesState = ref.read(providerEntriesProvider);
          _adapter.initializeBuiltinTools(entriesState);
          // initializeMcpServers 只同步发布占位工具定义（不做任何网络
          // 连接，连接在工具被调用时按需建立）。
          await _adapter.initializeMcpServers(entriesState);
          // MCP tools discovered on this late path (load() completed after the
          // initial _initialize snapshot) must be auto-enabled for
          // conversations without explicit prefs — same as the _initialize
          // path — so the tool badge/list shows the full count.
          if (mounted) _resolveEnabledToolsForActiveConversation();
          if (mounted) setState(() {});
          // _configureAdapter resets the adapter to model 0. Restore the
          // saved model selection so the adapter and reasoning params
          // stay in sync with the persisted choice. The conversation's
          // last used model takes priority over the global index.
          final convId = ref.read(activeConversationIdProvider);
          final convs = ref.read(conversationsProvider);
          final conv = convs.where((c) => c.id == convId).firstOrNull;
          if (conv != null &&
              conv.lastUsedModelName != null &&
              conv.lastUsedModelName!.isNotEmpty) {
            _selectModelByName(conv.lastUsedModelName!);
          } else {
            SharedPreferences.getInstance().then((prefs) {
              if (mounted) _restoreSavedModelSelection(prefs);
            });
          }
        });
      }
    });
  }

  /// Auto-saves reasoning settings when they change (per-model persistence).
  void _registerReasoningListeners() {
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
  }

  /// Updates the streaming message placeholder in the controller with the
  /// latest accumulated text from [streamingFullReplyProvider].
  /// Called by [build]'s listener on provider changes.
  void _updateStreamingMessage(String msgId, String content) {
    if (!mounted || content.isEmpty) return;
    final placeholder = _controller?.messages
        .where(
          (m) => m.id == msgId,
        )
        .firstOrNull;
    if (placeholder == null) return;
    _controller?.updateMessage(
      placeholder,
      Message.text(
        id: msgId,
        authorId: _aiUser.id,
        text: content,
        createdAt: DateTime.now(),
      ),
    );
  }
}
