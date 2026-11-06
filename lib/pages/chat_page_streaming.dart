part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageStreamingExt on _ChatPageState {
  void _attachStreamPage(
      ChatStreamManager manager, String convId, String msgId) {
    _detachStreamPage();
    manager.attachStreamPage(convId, msgId, _streamPageOwner);
    _attachedStreamManager = manager;
    _attachedStreamConvId = convId;
    _attachedStreamMsgId = msgId;
  }

  void _registerContinuationHandler(
      ChatStreamManager manager, String convId, String msgId) {
    manager.setContinuationHandler(convId, (continuation) async {
      if (!mounted || ref.read(activeConversationIdProvider) != convId) {
        return false;
      }
      final pendingLoad = _messageLoadCompleter;
      if (pendingLoad != null) await pendingLoad.future;
      if (!mounted || ref.read(activeConversationIdProvider) != convId) {
        return false;
      }

      final streamController = _controller;
      if (streamController == null) return false;
      final continuationAlreadyVisible = streamController.messages
          .any((message) => message.id == continuation.id);
      final assistantPlaceholder = streamController?.messages
          .where((message) => message.id == msgId)
          .firstOrNull;
      if (assistantPlaceholder != null) {
        await streamController?.removeMessage(assistantPlaceholder);
      }
      if (!continuationAlreadyVisible) {
        await streamController?.insertMessage(
          Message.text(
            id: continuation.id,
            authorId: _currentUser.id,
            text: continuation.content,
            createdAt: continuation.createdAt,
          ),
        );
      }
      await streamController?.insertMessage(
        assistantPlaceholder ??
            Message.text(
              id: msgId,
              authorId: _aiUser.id,
              text: manager.fullReplyFor(convId),
              createdAt: DateTime.now(),
            ),
      );
      return true;
    });
  }

  void _detachStreamPageFor(String convId, String msgId) {
    if (_attachedStreamConvId == convId && _attachedStreamMsgId == msgId) {
      _detachStreamPage();
    }
  }

  void _detachStreamPage({bool clearIfCompleted = false}) {
    final manager = _attachedStreamManager;
    final convId = _attachedStreamConvId;
    final msgId = _attachedStreamMsgId;
    if (manager != null && convId != null && msgId != null) {
      _streamingMarkdownCache
          .removeWhere((key, _) => key.startsWith('$msgId:'));
      _streamingFenceInfoCaches
          .removeWhere((key, _) => key.startsWith('$msgId:'));
      _livePlainTextFragments
          .removeWhere((key, _) => key.startsWith('$msgId:'));
      manager.detachStreamPage(
        convId,
        msgId,
        _streamPageOwner,
        clearIfCompleted: clearIfCompleted,
      );
    }
    _attachedStreamManager = null;
    _attachedStreamConvId = null;
    _attachedStreamMsgId = null;
  }

  /// Restores the streaming message UI when the page is re-initialized after
  /// having been disposed during active streaming (user navigated away during
  /// generation and came back). Uses per-conversation state from the manager
  /// to restore the correct conversation's streaming content.
  void _restoreStreamingState() {
    final activeConvId = ref.read(activeConversationIdProvider);
    if (activeConvId == null) return;

    final manager = ref.read(chatStreamManagerProvider);
    if (!manager.isStreamingFor(activeConvId)) return;

    final msgId = manager.streamingMsgIdFor(activeConvId);
    if (msgId == null) return;
    _attachStreamPage(manager, activeConvId, msgId);
    _registerContinuationHandler(manager, activeConvId, msgId);

    final fullReply = manager.fullReplyFor(activeConvId);
    final reasoningSections = manager.reasoningSectionsFor(activeConvId);

    AppLogService.info(
        'ChatPage',
        '[STREAM-RESTORE] _restoreStreamingState: conv=$activeConvId msgId=$msgId '
            'fullReplyLen=${fullReply.length} reasoningSectionsLen=${reasoningSections.length}');

    // ── SYNCHRONOUS: immediately set streaming state so that any
    // provider listeners firing during pending async work (e.g. MCP
    // init) do NOT bail out via _rebuildLiveSegments' guard.
    // This prevents the "one-frame render then freeze" re-entry bug.
    _isStreamingActive = true;
    _streamingMsgId = msgId;
    try {
      ref.read(isStreamingProvider(activeConvId).notifier).state = true;
      ref.read(streamingMsgIdProvider(activeConvId).notifier).state = msgId;
      ref
          .read(streamingReasoningSectionsProvider(activeConvId).notifier)
          .state = List<String>.from(reasoningSections);
      // Also restore the remaining segment providers to prevent
      // cross-contamination with stale data from another conversation.
      // roundStarts is set BEFORE toolCalls so that the toolCalls listener's
      // synchronous _rebuildLiveSegments reads the fresh round boundary.
      ref.read(streamingTextSectionsProvider(activeConvId).notifier).state =
          List<String>.from(
              ref.read(chatStreamManagerProvider).textChunksFor(activeConvId));
      ref
              .read(streamingToolCallRoundStartsProvider(activeConvId).notifier)
              .state =
          List<int>.from(ref
              .read(chatStreamManagerProvider)
              .toolCallRoundStartsFor(activeConvId));
      ref.read(streamingToolCallsProvider(activeConvId).notifier).state =
          List<ToolCallData>.from(
              ref.read(chatStreamManagerProvider).toolCallsFor(activeConvId));
      ref.read(streamingHasFirstTokenProvider(activeConvId).notifier).state =
          ref.read(chatStreamManagerProvider).hasFirstTokenFor(activeConvId);
      ref.read(streamingReasoningProvider(activeConvId).notifier).state =
          ref.read(chatStreamManagerProvider).reasoningBufferFor(activeConvId);
    } catch (e) {
      debugPrint('[ChatPage] _restoreStreamingState provider set failed: $e');
    }

    // Restore reasoning sections map for backward compatibility
    if (reasoningSections.isNotEmpty) {
      _reasoningContents[msgId] = List.of(reasoningSections);
    }
    // Restore reasoning completion state. During normal streaming, the
    // streamingTextSectionsProvider listener in build() sets this flag.
    // But during re-entry (_restoreStreamingState runs before build()),
    // the listener hasn't fired yet, so we set it here synchronously.
    // Without this, the reasoning button shows "思考中" (animated chevrons)
    // instead of "思考完成" when returning to a conversation where
    // reasoning is done and text is already flowing.
    if (reasoningSections.isNotEmpty &&
        ref.read(chatStreamManagerProvider).hasFirstTokenFor(activeConvId)) {
      _isReasoningCompletedForMsg[msgId] = true;
    }

    // ── POST-FRAME: deferred controller + UI work
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for the initial history load to finish before touching the
      // controller. Otherwise the streaming message could be inserted
      // into the pre-load controller, which _loadConversationMessages is
      // about to replace and dispose — losing the message entirely if the
      // background stream completes in the meantime.
      final pendingLoad = _messageLoadCompleter;
      if (pendingLoad != null) await pendingLoad.future;

      if (!mounted ||
          ref.read(activeConversationIdProvider) != activeConvId ||
          _streamingMsgId != msgId ||
          !manager.isStreamingFor(activeConvId) ||
          manager.streamingMsgIdFor(activeConvId) != msgId) {
        return;
      }
      // Also activate the conversation in the manager so provider updates
      // from the manager's throttle loop reach this page's listeners.
      manager.activateConversation(activeConvId);

      // Check if _loadConversationMessages' primary restore path already
      // inserted this message into the new controller. If so, keep the
      // already-built segments and skip inserting a duplicate — which
      // would create two Message widgets with the same id, doubling the
      // streaming bubble. (While the stream is live, the load loop always
      // skips the streaming message's DB copy, so any existing instance
      // in the controller is the live Message.text from the restore path.)
      final restoreController = _controller;
      final alreadyInController =
          restoreController?.messages.any((m) => m.id == msgId) ?? false;

      if (!alreadyInController) {
        // Ensure a segments entry exists for the bubble, but keep any
        // segments a build() listener already rebuilt while the message
        // was absent from the controller.
        _chatSegments.putIfAbsent(msgId, () => []);
        // Insert directly as Message.text so it renders through the
        // normal textMessageBuilder (gray bubble + segments) instead of
        // textStreamMessageBuilder (raw white-background Markdown).
        // This fallback insertion happens only when async restore left the
        // message out of the replacement controller. Seed the restored text
        // so the re-entry bubble is immediately complete.
        final latestFullReply = manager.fullReplyFor(activeConvId);
        restoreController
            ?.insertMessage(
          Message.text(
            id: msgId,
            authorId: _aiUser.id,
            text: latestFullReply,
            createdAt: DateTime.now(),
          ),
        )
            .then((_) {
          if (!mounted ||
              _controller != restoreController ||
              ref.read(activeConversationIdProvider) != activeConvId ||
              !manager.isStreamingFor(activeConvId) ||
              manager.streamingMsgIdFor(activeConvId) != msgId) {
            return;
          }
          _rebuildLiveSegments(msgId);
          setState(() {});
        });
      } else {
        AppLogService.info('ChatPage',
            '[STREAM-RESTORE] msgId=$msgId already in controller (loaded from DB by _loadConversationMessages), skipping duplicate insert');
        _rebuildLiveSegments(msgId);
        setState(() {});
      }
    });
  }

  /// Handles the case where a background stream completes while this page
  /// instance is showing it (e.g. the user navigated away during streaming
  /// and came back — the original [_startStreaming] future belongs to the
  /// disposed page instance and never runs its post-stream cleanup here).
  ///
  /// Detected via [streamingConversationsProvider]: when the current
  /// conversation leaves the streaming set, the stream is done. This method
  /// clears local streaming state + providers and reloads the finalized
  /// message from the DB (which now carries [toolCallRoundStarts] for
  /// correct multi-tool grouping).
  void _handleStreamCompletion() {
    if (!mounted) return;
    // Guard: in the NORMAL (non-re-entry) case, _startStreaming's post-stream
    // code runs synchronously after the manager returns and sets
    // _isStreamingActive = false BEFORE this post-frame callback fires. So if
    // it's already false, the normal path handled cleanup — skip to avoid a
    // wasteful DB reload + visual flicker. In the RE-ENTRY case, no
    // _startStreaming ran for this page instance, so _isStreamingActive stays
    // true and we run the cleanup here.
    if (!_isStreamingActive) return;
    final msgId = _streamingMsgId;
    AppLogService.info('ChatPage',
        '[STREAM-COMPLETION] _handleStreamCompletion: detected background stream completion for msgId=$msgId');

    _isStreamingActive = false;
    _streamingMsgId = null;
    _detachStreamPage();
    final convId = ref.read(activeConversationIdProvider);
    try {
      if (convId != null) {
        ref.read(isStreamingProvider(convId).notifier).state = false;
        ref.read(streamingMsgIdProvider(convId).notifier).state = null;
        ref.read(streamingFullReplyProvider(convId).notifier).state = '';
        ref.read(streamingHasFirstTokenProvider(convId).notifier).state = false;
        ref.read(streamingReasoningProvider(convId).notifier).state = '';
        ref.read(streamingReasoningAppendProvider(convId).notifier).state =
            null;
        ref.read(streamingReasoningSectionsProvider(convId).notifier).state =
            [];
        ref.read(streamingToolCallsProvider(convId).notifier).state = [];
        ref.read(streamingTextSectionsProvider(convId).notifier).state = [''];
        ref.read(streamingTextAppendProvider(convId).notifier).state = null;
        ref.read(streamingToolCallRoundStartsProvider(convId).notifier).state =
            [];
      }
    } catch (e) {
      debugPrint('[ChatPage] _handleStreamCompletion provider cleanup: $e');
    }
    // Keep the finalized message visible while the reload happens; the
    // reload will replace _chatSegments from the persisted message (which
    // carries toolCallRoundStarts, so multi-tool grouping is correct).
    if (msgId != null) _finalizedMessages.add(msgId);
    // Reload from DB. _loadConversationMessages is now unguarded because
    // _isStreamingActive is false. It clears _chatSegments / _finalizedMessages
    // and rebuilds from the persisted message (including toolCallRoundStarts).
    _loadConversationMessages();
    if (mounted) setState(() {});
  }

  Future<void> _startStreaming(
    String text, {
    String? capturedConvId,
    List<ChatMessage>? historyOverride,
    List<ChatMessage>? requestHistoryOverride,
    List<ChatMessage>? historyOnSuccess,
  }) async {
    final effectiveConvId =
        capturedConvId ?? ref.read(activeConversationIdProvider) ?? '';
    final manager = ref.read(chatStreamManagerProvider);
    // 解析本次发送实际使用的助手：对话绑定的助手优先（创建时按
    // assistantId 绑定并持久化；全局搜索等入口可能绕过"选择助手"页面
    // 直接打开其它助手的对话，此时对话的绑定才是权威），其次回退到
    // 会话当前选择的助手（旧数据中未绑定助手的对话语义），最后兜底
    // 默认助手——绝不静默退化为"无系统提示词"的请求。
    final assistants = ref.read(assistantProvider);
    final conv = ref
        .read(conversationsProvider)
        .where((c) => c.id == effectiveConvId)
        .firstOrNull;
    final selectedAssistant = resolveAssistantForSend(
      conversationAssistantId: conv?.assistantId,
      sessionAssistant: ref.read(selectedAssistantProvider),
      assistants: assistants,
    );
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
    final allTools = _adapter.getAllToolDefinitions();
    final enabledTools = ref.read(enabledToolNamesProvider);
    final filteredTools =
        allTools.where((tool) => enabledTools.contains(tool.name)).toList();
    final reasoning = ref.read(reasoningEnabledProvider);
    final reasoningEffort = ref.read(reasoningEffortProvider);
    final reasoningParamValues = ref.read(reasoningParamValuesProvider);
    final storedCustomParamValues = ref.read(customParamValuesProvider);
    final customParamValues = storedCustomParamValues == null
        ? null
        : Map<String, String>.from(storedCustomParamValues);
    if (customParamValues != null) {
      for (final param
          in _adapter.customParams.where((p) => p.type == 'json')) {
        if (!customParamValues.containsKey(param.paramName)) continue;
        if (param.defaultValue.trim().isEmpty) {
          customParamValues.remove(param.paramName);
        } else {
          customParamValues[param.paramName] = param.defaultValue;
        }
      }
    }
    final histBefore = historyOverride ?? List<ChatMessage>.from(_history);
    // Guard: only block if THIS conversation is streaming, not another.
    if (ref.read(streamingConversationsProvider).contains(effectiveConvId)) {
      return;
    }

    await AppLogService.info(
        'ChatPage', '开始流式请求, capturedConvId=$capturedConvId');
    if (mounted && ref.read(activeConversationIdProvider) != effectiveConvId) {
      return;
    }
    final aiMsgId = 'a${DateTime.now().microsecondsSinceEpoch}';
    _streamingMsgId = aiMsgId;
    _chatSegments[aiMsgId] = [];
    _reasoningContents[aiMsgId] = [];

    // 1. Insert streaming placeholder message into the controller
    final streamController = _controller;
    final placeholder = Message.textStream(
      id: aiMsgId,
      authorId: _aiUser.id,
      createdAt: DateTime.now(),
      streamId: aiMsgId,
    );
    if (mounted) {
      await streamController?.insertMessage(placeholder);
    }
    if (mounted && ref.read(activeConversationIdProvider) != effectiveConvId) {
      await streamController?.removeMessage(placeholder);
      if (_streamingMsgId == aiMsgId) {
        _isStreamingActive = false;
        _streamingMsgId = null;
      }
      ref.read(isStreamingProvider(effectiveConvId).notifier).state = false;
      return;
    }

    // Delegate streaming to ChatStreamManager (runs background loop).
    // Uses effectiveConvId (declared above) for the guard + manager call.
    await AppLogService.info('ChatPage',
        '[STREAM-SEND] _startStreaming: sending to manager, historyLen=${histBefore.length}, convId=$effectiveConvId');
    if (mounted && ref.read(activeConversationIdProvider) != effectiveConvId) {
      await streamController?.removeMessage(placeholder);
      if (_streamingMsgId == aiMsgId) {
        _isStreamingActive = false;
        _streamingMsgId = null;
      }
      ref.read(isStreamingProvider(effectiveConvId).notifier).state = false;
      return;
    }
    // Advertise a stoppable stream immediately before manager registration.
    // startStreaming registers its state synchronously before its first await,
    // so Stop can never race ahead of the state that cancel() needs to mark.
    ref.read(isStreamingProvider(effectiveConvId).notifier).state = true;
    _isStreamingActive = true;
    if (mounted) setState(() {});
    _registerContinuationHandler(manager, effectiveConvId, aiMsgId);

    final streamFuture = manager.startStreaming(
      text: text,
      convId: effectiveConvId,
      history: histBefore,
      requestHistoryOverride: requestHistoryOverride,
      historyOnSuccess: historyOnSuccess,
      tools: filteredTools,
      reasoning: reasoning,
      reasoningEffort: reasoningEffort,
      reasoningParamValues: reasoningParamValues,
      customParamValues: customParamValues,
      streamingMsgId: aiMsgId,
    );
    _attachStreamPage(manager, effectiveConvId, aiMsgId);
    final StreamResult result = await streamFuture;
    _detachStreamPageFor(effectiveConvId, aiMsgId);

    if (!mounted) return;

    // ── Post-stream completion ──
    // CRITICAL: Update _history FIRST, before any debug/log calls that
    // could throw and prevent the update. Without this, the next message
    // sees stale _history missing previous assistant messages.
    // Guard: only update if the user is still viewing this conversation.
    // If they switched away mid-stream, _history now holds the OTHER
    // conversation's data and overwriting it would corrupt the display.
    final pageOwnedStream = _streamingMsgId == aiMsgId &&
        ref.read(activeConversationIdProvider) == effectiveConvId;
    // Stop clears the page-owned id immediately so an aborted manager result
    // cannot overwrite the live partial response with an incomplete result.
    // Once the real manager returns its persisted cancellation message, apply
    // that result too; otherwise edit/regenerate leaves _history stale after
    // the stop and subsequent actions cannot find the newly saved message.
    final finalizedStoppedStream = _streamingMsgId == null &&
        result.assistantMessage?.isError == true &&
        ref.read(activeConversationIdProvider) == effectiveConvId;
    final shouldApplyStreamResult = pageOwnedStream || finalizedStoppedStream;
    if (shouldApplyStreamResult) {
      _history.clear();
      _history.addAll(result.history);
      await _removeOrphanMessagesFromController();
    }

    // Clear the local streaming flag IMMEDIATELY (before any await below)
    // so the streamingConversationsProvider listener's post-frame callback
    // (_handleStreamCompletion, guard: `if (!_isStreamingActive) return;`)
    // sees false and skips — avoiding a wasteful DB reload + visual flicker
    // in the normal (non-re-entry) completion path.
    if (shouldApplyStreamResult) {
      _streamingMsgId = null;
      _isStreamingActive = false;
    }

    // Clean up local streaming state and providers. Do not clear providers
    // belonging to a replacement stream for the same conversation.
    final currentStreamMsgId = manager.streamingMsgIdFor(effectiveConvId);
    final canClearProviders =
        currentStreamMsgId == null || currentStreamMsgId == aiMsgId;
    if (canClearProviders) {
      try {
        ref.read(isStreamingProvider(effectiveConvId).notifier).state = false;
        ref.read(streamingMsgIdProvider(effectiveConvId).notifier).state = null;
        ref.read(streamingFullReplyProvider(effectiveConvId).notifier).state =
            '';
        ref
            .read(streamingHasFirstTokenProvider(effectiveConvId).notifier)
            .state = false;
        ref.read(streamingReasoningProvider(effectiveConvId).notifier).state =
            '';
        ref
            .read(streamingReasoningAppendProvider(effectiveConvId).notifier)
            .state = null;
        ref
            .read(streamingReasoningSectionsProvider(effectiveConvId).notifier)
            .state = [];
        ref.read(streamingToolCallsProvider(effectiveConvId).notifier).state =
            [];
        ref
            .read(streamingTextSectionsProvider(effectiveConvId).notifier)
            .state = [''];
        ref
            .read(
                streamingToolCallRoundStartsProvider(effectiveConvId).notifier)
            .state = [];
      } catch (e) {
        debugPrint('[ChatPage] post-stream provider cleanup failed: $e');
      }
    }

    // Log stream completion for diagnostics
    try {
      await AppLogService.info(
          'ChatPage',
          '[STREAM-END] _startStreaming completed: result.history.length=${result.history.length}, '
              'toolCalls=${result.toolCalls.length}, roundStarts=${result.toolCallRoundStarts}');
    } catch (_) {}

    // Update the controller: replace streaming placeholder with final message
    if (shouldApplyStreamResult &&
        mounted &&
        ref.read(activeConversationIdProvider) == effectiveConvId) {
      final finalMsg = result.assistantMessage;
      if (finalMsg != null) {
        // Round boundaries are persisted on finalMsg.toolCallRoundStarts
        // (set by the manager during streaming). _buildFinalSegments reads
        // them from the message directly — no local map needed.

        // Update the streaming placeholder to show the final text
        _controller?.updateMessage(
          placeholder,
          Message.text(
            id: finalMsg.id,
            authorId: _aiUser.id,
            text: finalMsg.content,
            createdAt: finalMsg.createdAt,
          ),
        );

        // Build a unified segments list representing the full Agent chain:
        // Reasoning → ToolCall → Reasoning → ... → Text (answer)
        // This preserves reasoning visibility alongside tool calls and text.
        _buildFinalSegments(finalMsg);

        // Also store in _reasoningContents for backward compatibility
        // with any code paths that read that map directly.
        if (finalMsg.reasoningSections != null &&
            finalMsg.reasoningSections!.isNotEmpty) {
          _reasoningContents[finalMsg.id] = finalMsg.reasoningSections!;
        }
      } else {
        // 无任何内容产出（如纯思考期取消、空回复）：移除流式占位符，
        // 否则 spinner 气泡会残留到下次重新加载；同时清理本次会话
        // 内的分段/推理缓存条目（切换对话时会统一清除）。
        await _controller?.removeMessage(placeholder);
        _chatSegments.remove(aiMsgId);
        _streamingMarkdownCache
            .removeWhere((key, _) => key.startsWith('$aiMsgId:'));
        _streamingFenceInfoCaches
            .removeWhere((key, _) => key.startsWith('$aiMsgId:'));
        _livePlainTextFragments
            .removeWhere((key, _) => key.startsWith('$aiMsgId:'));
        _reasoningContents.remove(aiMsgId);
        _isReasoningCompletedForMsg.remove(aiMsgId);
      }
      setState(() {});
    }
  }

  /// Builds the final [_chatSegments] entry for a completed assistant message.
  void _buildFinalSegments(ChatMessage msg) {
    _streamingMarkdownCache
        .removeWhere((key, _) => key.startsWith('${msg.id}:'));
    _streamingFenceInfoCaches
        .removeWhere((key, _) => key.startsWith('${msg.id}:'));
    _livePlainTextFragments
        .removeWhere((key, _) => key.startsWith('${msg.id}:'));
    final rebuiltBlocks = legacyToBlocks(
      reasoningSections: msg.reasoningSections ?? [],
      textChunks: msg.textSections ?? [],
      toolCalls: msg.toolCalls ?? [],
      toolCallRoundStarts: msg.toolCallRoundStarts ?? [],
    );
    rebuiltBlocks.addAll(msg.blocks?.whereType<ErrorBlock>() ?? const []);
    final hasCanonicalFields = msg.toolCallRoundStarts != null ||
        ((msg.toolCalls == null || msg.toolCalls!.isEmpty) &&
            !(msg.blocks?.any((block) => block is ToolCallBlock) ?? false) &&
            (msg.reasoningSections != null || msg.textSections != null));
    final blocks =
        hasCanonicalFields ? rebuiltBlocks : (msg.blocks ?? rebuiltBlocks);
    final segments = blocksToSegments(blocks);

    // Fallback: no blocks produced anything, use content as single block
    if (segments.isEmpty && msg.content.isNotEmpty) {
      segments.add(TextSegment(msg.content));
    }

    _chatSegments[msg.id] = segments;
    _finalizedMessages.add(msg.id);
    _isReasoningCompletedForMsg[msg.id] = true;
  }

  /// Rebuilds the live [_chatSegments] for [msgId] by reading current
  /// provider state and using the same interleaving logic as post-stream.
  void _rebuildLiveSegments(String msgId) {
    if (!_isStreamingActive) return;
    if (_finalizedMessages.contains(msgId)) return;

    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;

    final segments = buildAgentChainSegments(
      reasoningSections: _reasoningContents[msgId] ??
          ref.read(streamingReasoningSectionsProvider(convId)),
      textChunks: ref.read(streamingTextSectionsProvider(convId)),
      toolCalls: ref.read(streamingToolCallsProvider(convId)),
      isLastReasoningStreaming: !(_isReasoningCompletedForMsg[msgId] ?? false),
      toolCallRoundStarts:
          ref.read(streamingToolCallRoundStartsProvider(convId)),
    );

    _chatSegments[msgId] = segments;
  }

  /// Replaces only the final growing text section after a throttled text
  /// update. The sealed reasoning, text, and tool segments keep their object
  /// identity so their Markdown widgets can reuse the existing parse tree.
  bool _updateLiveTextSegment(String msgId, List<String> textChunks) {
    if (textChunks.isEmpty) return false;
    final segments = _chatSegments[msgId];
    if (segments == null) return false;
    final chunkIndex = textChunks.length - 1;
    final segmentIndex = segments.lastIndexWhere(
      (segment) => segment is TextSegment && segment.chunkIndex == chunkIndex,
    );
    if (segmentIndex == -1) return false;

    final updated = List<MessageSegment>.of(segments);
    updated[segmentIndex] = TextSegment(
      textChunks[chunkIndex],
      chunkIndex: chunkIndex,
    );
    _chatSegments[msgId] = updated;
    return true;
  }

  void _stopStreaming() {
    final stoppedMsgId = _streamingMsgId;
    final convId = ref.read(activeConversationIdProvider);
    _isStreamingActive = false;
    _streamingMsgId = null;
    try {
      ref.read(chatStreamManagerProvider).cancel(convId);
      // Render the partial response and interruption error immediately. The
      // manager finalizes persistence independently; clearing the page-owned
      // id leaves the normal history reload to read that saved result instead
      // of replacing this live message with an incomplete result object.
      if (stoppedMsgId != null && convId != null && _controller != null) {
        final partial =
            ref.read(chatStreamManagerProvider).fullReplyFor(convId);
        final segments =
            List<MessageSegment>.from(_chatSegments[stoppedMsgId] ?? const []);
        if (!segments.any((segment) => segment is ErrorSegment)) {
          segments.add(ErrorSegment('用户中断了输出'));
        }
        _chatSegments[stoppedMsgId] = segments;
        _controller?.updateMessage(
          Message.textStream(
              id: stoppedMsgId, authorId: _aiUser.id, streamId: stoppedMsgId),
          Message.text(
            id: stoppedMsgId,
            authorId: _aiUser.id,
            text: partial,
          ),
        );
        if (mounted) setState(() {});
      }
      // Keep the manager's streaming set entry until its cancelled result is
      // persisted. The send guard uses this set and prevents a fast resend
      // from replacing the cancelled state before its partial/error is saved.
    } catch (e) {
      debugPrint('[ChatPage] _stopStreaming cancel error: $e');
    }
    try {
      final convId = ref.read(activeConversationIdProvider);
      if (convId != null) {
        ref.read(isStreamingProvider(convId).notifier).state = false;
        ref.read(streamingMsgIdProvider(convId).notifier).state = null;
        ref.read(streamingFullReplyProvider(convId).notifier).state = '';
        ref.read(streamingHasFirstTokenProvider(convId).notifier).state = false;
        ref.read(streamingReasoningProvider(convId).notifier).state = '';
        ref.read(streamingReasoningAppendProvider(convId).notifier).state =
            null;
        ref.read(streamingReasoningSectionsProvider(convId).notifier).state =
            [];
        ref.read(streamingToolCallsProvider(convId).notifier).state = [];
        ref.read(streamingTextSectionsProvider(convId).notifier).state = [''];
        ref.read(streamingTextAppendProvider(convId).notifier).state = null;
        ref.read(streamingToolCallRoundStartsProvider(convId).notifier).state =
            [];
      }
    } catch (e) {
      debugPrint('[ChatPage] _stopStreaming provider cleanup error: $e');
    }
  }
}
