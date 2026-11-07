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
    ref.listen(streamingTextAppendProvider(convId), (prev, next) {
      if (!mounted || next == null || next.text.isEmpty) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      if (next.hasMarkdownSyntax) {
        _updateLiveMarkdownSegment(msgId, next, convId);
        return;
      }
      final existingSegments = _chatSegments[msgId] ?? const [];
      final existingText = existingSegments
          .whereType<TextSegment>()
          .where((segment) => segment.chunkIndex == next.chunkIndex)
          .lastOrNull;
      final fragments = _livePlainTextFragments.putIfAbsent(
        '$msgId:${next.chunkIndex}',
        () => existingText != null && existingText.liveTextFragments == null
            ? <String>[existingText.text]
            : <String>[],
      );
      if (next.text.isNotEmpty) {
        fragments.add(next.text);
        if (fragments.length > 32) {
          var mergeIndex = 0;
          var shortestPairLength = fragments[0].length + fragments[1].length;
          for (var i = 1; i < fragments.length - 1; i++) {
            final pairLength = fragments[i].length + fragments[i + 1].length;
            if (pairLength < shortestPairLength) {
              mergeIndex = i;
              shortestPairLength = pairLength;
            }
          }
          fragments[mergeIndex] += fragments.removeAt(mergeIndex + 1);
        }
      }
      final segments = existingSegments;
      final existingIndex = segments.lastIndexWhere(
        (segment) =>
            segment is TextSegment && segment.chunkIndex == next.chunkIndex,
      );
      final updated = List<MessageSegment>.of(segments);
      final segment = TextSegment(
        '',
        chunkIndex: next.chunkIndex,
        liveTextFragments: fragments,
      );
      if (existingIndex >= 0) {
        updated[existingIndex] = segment;
      } else {
        updated.add(segment);
      }
      _chatSegments[msgId] = updated;
      if (!(_isReasoningCompletedForMsg[msgId] ?? false)) {
        _isReasoningCompletedForMsg[msgId] = true;
        _convertStreamingPlaceholderToTextMessage(msgId);
        _rebuildLiveSegments(msgId);
        final rebuilt =
            List<MessageSegment>.of(_chatSegments[msgId] ?? const []);
        rebuilt.removeWhere((item) =>
            item is TextSegment && item.chunkIndex == next.chunkIndex);
        rebuilt.add(segment);
        _chatSegments[msgId] = rebuilt;
      }
      _refreshStreamingBubble(msgId);
    });

    // Keep legacy direct provider writes working for older callers. Normal
    // manager updates arrive through textSections below, the single live text
    // representation.
    ref.listen(streamingFullReplyProvider(convId), (String? prev, String next) {
      if (!mounted || next.isEmpty || next == prev) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _updateStreamingMessage(msgId, next);
      _rebuildLiveSegments(msgId);
    });

    ref.listen(streamingReasoningAppendProvider(convId), (prev, next) {
      if (!mounted || next == null || next.text.isEmpty) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      final sections = _reasoningContents[msgId] ?? const <String>[];
      var shouldRebuild = false;
      final updated = List<String>.of(sections);
      while (updated.length <= next.sectionIndex) {
        updated.add('');
      }
      if (updated[next.sectionIndex].isEmpty) {
        // A marker is enough for the inline reasoning button. Keep active text
        // in the stream manager and fetch one full snapshot only when the user
        // opens the reasoning panel.
        updated[next.sectionIndex] = ' ';
        _reasoningContents[msgId] = updated;
        shouldRebuild = true;
      }
      if (_isReasoningCompletedForMsg[msgId] ?? false) {
        _isReasoningCompletedForMsg[msgId] = false;
        shouldRebuild = true;
      }
      if (!shouldRebuild) return;
      _rebuildLiveSegments(msgId);
      _refreshStreamingBubble(msgId);
    });

    ref.listen(streamingReasoningSectionsProvider(convId),
        (List<String>? prev, List<String> next) {
      if (!mounted || next.isEmpty || identical(prev, next)) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _reasoningContents[msgId] = List<String>.from(next);
      // Reset the reasoning-completed flag BEFORE rebuilding the live
      // segments: the rebuild reads this flag to decide whether the last
      // reasoning section is streaming. Resetting it after the rebuild left
      // a stale `true` (set by the textSections listener, e.g. its fresh
      // [''] push at stream start) in effect for the whole first render —
      // the button flashed "思考完成" until the next throttled reasoning
      // push rebuilt with the corrected flag.
      //
      // The reset is scoped to content updates: only when the last section
      // has content is reasoning still being streamed. A trailing '' (the
      // placeholder appended by ReasoningSectionEndEvent when a round ends)
      // must NOT reset the flag — the last sealed section has already
      // completed and keeps showing "思考完成" (resetting would flip it to
      // "思考中" until the next round's first push).
      if (next.last.isNotEmpty) {
        _isReasoningCompletedForMsg[msgId] = false;
      }
      _rebuildLiveSegments(msgId);
      _refreshStreamingBubble(msgId);
    });

    ref.listen(streamingHasFirstTokenProvider(convId), (bool? prev, bool next) {
      if (!mounted || !next) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      if ((_reasoningContents[msgId]?.length ?? 0) > 0) {
        _isReasoningCompletedForMsg[msgId] = true;
        _refreshStreamingBubble(msgId);
      }
    });

    ref.listen(streamingToolCallsProvider(convId),
        (List<ToolCallData>? prev, List<ToolCallData> next) {
      if (!mounted || next.isEmpty || identical(prev, next)) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _rebuildLiveSegments(msgId);
      _refreshStreamingBubble(msgId);
    });

    ref.listen(streamingTextSectionsProvider(convId),
        (List<String>? prev, List<String> next) {
      if (!mounted || next.isEmpty || identical(prev, next)) return;
      final msgId = _streamingMsgId ?? ref.read(streamingMsgIdProvider(convId));
      if (msgId == null) return;
      _livePlainTextFragments
          .removeWhere((key, _) => key.startsWith('$msgId:'));
      if (!next.any((section) => section.isNotEmpty)) {
        // Empty text chunks are published at tool-round boundaries. Keep the
        // TextStream placeholder so tool-only rounds render through their
        // live segments without prematurely switching bubble builders.
        _isReasoningCompletedForMsg[msgId] = true;
        _rebuildLiveSegments(msgId);
        return;
      }
      final reasoningWasCompleted = _isReasoningCompletedForMsg[msgId] ?? false;
      _isReasoningCompletedForMsg[msgId] = true;
      // Switch the placeholder to the normal assistant bubble without
      // copying the growing reply into the chat controller. Text is rendered
      // from the live segments below.
      _convertStreamingPlaceholderToTextMessage(msgId);
      if (!reasoningWasCompleted || !_updateLiveTextSegment(msgId, next)) {
        _rebuildLiveSegments(msgId);
      }
      // Other segment changes are refreshed by their reasoning/tool listener.
    });
  }

  void _updateLiveMarkdownSegment(
    String msgId,
    StreamingTextAppend next,
    String convId,
  ) {
    final prior = _chatSegments[msgId] ?? const <MessageSegment>[];
    final existingText = prior
        .whereType<TextSegment>()
        .where((segment) => segment.chunkIndex == next.chunkIndex)
        .lastOrNull;
    final existingFragments = existingText?.liveTextFragments;
    final canSeedFragments = existingFragments != null &&
        existingFragments.fold<int>(
              0,
              (length, fragment) => length + fragment.length,
            ) <=
            _LiveMarkdownSearchPreview._maxLength;
    final seed = existingText == null ||
            existingText.liveMarkdownAppend != null ||
            (existingFragments != null && !canSeedFragments) ||
            (existingFragments == null &&
                existingText.text.length >
                    _LiveMarkdownSearchPreview._maxLength)
        ? ''
        : existingFragments?.join() ?? existingText.text;
    final previewKey = '$msgId:${next.chunkIndex}';
    final priorAppendCount = _liveMarkdownAppendCounts[previewKey] ?? 0;
    final managerAppendCount =
        ref.read(chatStreamManagerProvider).textChunkAppendCountFor(convId);
    final nextAppendCount = priorAppendCount + 1;
    final appendCount = managerAppendCount > nextAppendCount
        ? managerAppendCount
        : nextAppendCount;
    _liveMarkdownAppendCounts[previewKey] = appendCount;
    if (_isSearching) {
      var preview = _liveMarkdownSearchPreviews[previewKey];
      if (preview == null) {
        final manager = ref.read(chatStreamManagerProvider);
        final publishedLength =
            manager.publishedTextChunkLengthFor(convId, next.chunkIndex);
        if (publishedLength > _LiveMarkdownSearchPreview._maxLength) {
          final excerpt = manager.publishedTextChunkExcerptFor(
            convId,
            next.chunkIndex,
            _LiveMarkdownSearchPreview._maxLength,
          );
          if (excerpt != null && excerpt.length == 2) {
            preview = _LiveMarkdownSearchPreview.fromExcerpt(
              excerpt[0],
              excerpt[1],
              sourceLength: publishedLength,
              initialUpdates: appendCount,
              lastSequence: next.sequence,
            );
          }
        }
        if (preview == null) {
          final chunks = manager.publishedTextChunksFor(convId);
          final initialText = next.chunkIndex < chunks.length
              ? chunks[next.chunkIndex]
              : '$seed${next.text}';
          preview = _LiveMarkdownSearchPreview(
            initialText,
            initialUpdates: appendCount,
            lastSequence: next.sequence,
          );
        }
        _liveMarkdownSearchPreviews[previewKey] = preview;
      } else if (preview.lastSequence != null &&
          next.sequence > preview.lastSequence! + 1) {
        final manager = ref.read(chatStreamManagerProvider);
        final publishedLength =
            manager.publishedTextChunkLengthFor(convId, next.chunkIndex);
        if (publishedLength > _LiveMarkdownSearchPreview._maxLength) {
          // Recover oversized previews from a bounded source excerpt rather
          // than copying the full published chunk during gap recovery.
          final excerpt = manager.publishedTextChunkExcerptFor(
            convId,
            next.chunkIndex,
            _LiveMarkdownSearchPreview._maxLength,
          );
          if (excerpt != null && excerpt.length == 2) {
            preview.recoverWithExcerpt(
              excerpt[0],
              excerpt[1],
              sourceLength: publishedLength,
              updateCount: appendCount,
              sequence: next.sequence,
            );
          } else {
            preview.append(next.text, sequence: next.sequence);
          }
        } else {
          final chunks = manager.publishedTextChunksFor(convId);
          final publishedText = next.chunkIndex < chunks.length
              ? chunks[next.chunkIndex]
              : '${seed}${next.text}';
          preview = _LiveMarkdownSearchPreview(
            publishedText,
            initialUpdates: appendCount,
            lastSequence: next.sequence,
          );
          _liveMarkdownSearchPreviews[previewKey] = preview;
        }
      } else {
        preview.append(next.text, sequence: next.sequence);
      }
    } else {
      _liveMarkdownSearchPreviews.remove(previewKey);
    }
    _livePlainTextFragments.remove('$msgId:${next.chunkIndex}');

    if (!(_isReasoningCompletedForMsg[msgId] ?? false)) {
      _isReasoningCompletedForMsg[msgId] = true;
      _convertStreamingPlaceholderToTextMessage(msgId);
      _rebuildLiveSegments(msgId);
    }

    final segments = List<MessageSegment>.of(_chatSegments[msgId] ?? prior);
    final existingIndex = segments.lastIndexWhere(
      (segment) =>
          segment is TextSegment && segment.chunkIndex == next.chunkIndex,
    );
    final segment = TextSegment(
      '',
      chunkIndex: next.chunkIndex,
      liveMarkdownAppend: next.text,
      liveMarkdownSequence: next.sequence,
      liveMarkdownSeed: seed,
    );
    if (existingIndex >= 0) {
      segments[existingIndex] = segment;
    } else {
      segments.add(segment);
    }
    _chatSegments[msgId] = segments;
    _refreshStreamingBubble(msgId);
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
        if (_isInitialChatLoadPending) {
          setState(() => _isInitialChatLoadPending = false);
        }
        _detachStreamPage(clearIfCompleted: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(activeConversationIdProvider) == null) {
            _clearConversationView();
          }
        });
        return;
      }
      if (next != null && next != prev) {
        // Stop retaining the previous conversation's stream buffers while
        // this page displays another conversation. Reattach below if the
        // destination conversation is still streaming.
        _detachStreamPage(clearIfCompleted: true);
        // Check streaming state FIRST, then set flags, THEN activate
        // (so listeners fired by activateConversation see correct flags).
        final manager = ref.read(chatStreamManagerProvider);
        final targetIsStreaming = manager.isStreamingFor(next);
        _isStreamingActive = targetIsStreaming;
        _streamingMsgId =
            targetIsStreaming ? manager.streamingMsgIdFor(next) : null;
        if (targetIsStreaming && _streamingMsgId != null) {
          _attachStreamPage(manager, next, _streamingMsgId!);
        }
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
        _streamingSearchOccurrenceCache.clear();
        _reasoningContents.clear();
        _finalizedMessages.clear();
        _isReasoningCompletedForMsg.clear();
        _convertedStreamingPlaceholderIds.clear();
        manager.activateConversation(next);
        // Schedule loads for conversation switches and for an initial
        // null→ID restoration that the first _initialize load could not see.
        // Keep an already pending spinner tied to the new active ID as well.
        final isInitialConversationRestore =
            prev == null && _loadedConversationId != next;
        if (isInitialConversationRestore && !_isInitialChatLoadPending) {
          setState(() => _isInitialChatLoadPending = true);
        }
        // Capture the target conversation ID so rapid C1→C2→C3 switches
        // don't load the wrong conversation (the post-frame reads
        // activeConversationIdProvider which may have changed).
        if (prev != null || isInitialConversationRestore) {
          final capturedConvId = next;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted ||
                ref.read(activeConversationIdProvider) != capturedConvId) {
              return;
            }
            await _loadConversationMessages();
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
          final isWaitingForInitialHistory = _isInitialChatLoadPending;
          if (activeConv == null) {
            // The provider has finished hydrating without the saved ID; show
            // the normal empty/error state instead of leaving a spinner up.
            if (isWaitingForInitialHistory) {
              setState(() => _isInitialChatLoadPending = false);
            }
          } else {
            // Retry when initial setup was waiting for provider hydration, or
            // when the active history is newer than the currently loaded list.
            final shouldReload = isWaitingForInitialHistory ||
                (_history.isEmpty && activeConv.messages.isNotEmpty) ||
                (_history.length < activeConv.messages.length &&
                    !_isStreamingActive &&
                    !_isLoadingMessages &&
                    !_isModifyingHistory);
            if (shouldReload) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted ||
                    ref.read(activeConversationIdProvider) != activeId) {
                  return;
                }
                await _loadConversationMessages();
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
          // 供应商配置可能连带改了拖动排序（model_order，与供应商页
          // 共享）：先重载顺序再重配，避免"列表第一个"兜底用旧顺序。
          try {
            final prefs = await SharedPreferences.getInstance();
            if (!mounted) return;
            final savedOrder = prefs.getStringList('model_order');
            if (savedOrder != null && savedOrder.isNotEmpty) {
              setState(() => _savedModelOrder = savedOrder);
            }
          } catch (e) {
            debugPrint('entries listener reload model_order failed: $e');
          }
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
          // _configureAdapter resets the adapter to model 0 and already
          // re-applies the active conversation's model (per-conversation
          // record → assistant default → first model). 再跑一次无副作用的
          // 恢复链，兜底 _configureAdapter 早期调用时对话尚未加载的情况。
          _restoreActiveConversationModel();
        });
      }
    });
  }

  /// 助手列表异步加载完成后重跑模型恢复链。
  ///
  /// 竞态防护：conversations 与 assistants 是两条独立的异步加载路径，
  /// 对话先加载完时恢复链可能看不到助手默认模型（规则2落空）。此处
  /// 监听 assistantProvider，仅在 空 → 非空 的首次加载完成转换时补跑
  /// 一次（prev == null 覆盖监听注册时的首帧；prev.isEmpty 覆盖加载
  /// 完成）。注意不监听增删改（非空 → 非空 不触发）：编辑助手默认值
  /// 不应在会话中途改写当前对话的模型——无记录对话会在下次进入时
  /// 自然跟随新默认。
  void _registerAssistantListener() {
    ref.listen(assistantProvider,
        (List<Assistant>? prev, List<Assistant> next) {
      if (prev == null || (prev.isEmpty && next.isNotEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _restoreActiveConversationModel();
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
    ref.listen(
      customParamValuesProvider,
      (_, __) => _persistCurrentReasoningSettings(),
    );
  }

  /// Updates the streaming message placeholder in the controller with the
  /// latest accumulated text. Called by the canonical text-section listener,
  /// or by the legacy full-reply listener for older direct provider writers.
  void _updateStreamingMessage(String msgId, String content) {
    if (!mounted) return;
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
    _refreshStreamingBubble(msgId);
  }

  /// Converts a stream placeholder once, avoiding controller scans on later
  /// text-section updates. A missing controller message is retried on the
  /// next provider update; an already-normal message is remembered for this
  /// page session, which also covers streaming re-entry.
  void _convertStreamingPlaceholderToTextMessage(String msgId) {
    if (!mounted || _convertedStreamingPlaceholderIds.contains(msgId)) return;
    final placeholder = _controller?.messages
        .where(
          (message) => message.id == msgId,
        )
        .firstOrNull;
    if (placeholder == null) return;
    _convertedStreamingPlaceholderIds.add(msgId);
    if (placeholder is! TextStreamMessage) return;
    _controller?.updateMessage(
      placeholder,
      Message.text(
        id: msgId,
        authorId: _aiUser.id,
        text: '',
        createdAt: DateTime.now(),
      ),
    );
    _refreshStreamingBubble(msgId);
  }

  /// Rebuilds only the active message item after its live segments change.
  void _refreshStreamingBubble(String msgId) {
    if (!mounted) return;
    if (_streamingMsgId != msgId) return;
    _streamingBubbleRevision.value++;
  }
}
