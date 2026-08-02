part of 'chat_stream_manager.dart';

extension _ChatStreamManagerFinalizeExt on ChatStreamManager {
  /// Post-stream processing: captures raw request/response data, updates
  /// usage metrics, marks interrupted tools, builds and persists the
  /// assistant message, completes the result, and cleans up stream state.
  ///
  /// Called once at the end of [ChatStreamManager.startStreaming] after the
  /// stream loop has finished (including the finally-block flush).
  Future<StreamResult> _completeStream({
    required _ConversationStreamState state,
    required String convId,
    required Object? streamError,
    required ChatService? snappedChatService,
  }) async {
    // Capture request/response raw data from the ChatService instance
    // that was active when this stream started (snapped above). Using
    // the snapped reference is critical: adapter.currentChatService may
    // have been replaced mid-stream by a page re-entry calling configure()
    // or selectModel(). Reading through the replaced service returns null.
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;
    try {
      final reqBody = snappedChatService?.lastRequestBody;
      final headers = snappedChatService?.lastRequestHeaders;
      final url = snappedChatService?.lastRequestUrl;
      if (reqBody != null || headers != null || url != null) {
        rawRequestCapture = {};
        if (url != null) rawRequestCapture['url'] = url;
        if (headers != null) rawRequestCapture['headers'] = headers;
        if (reqBody != null) rawRequestCapture['body'] = reqBody;
      }
      final respData = snappedChatService?.lastResponseData;
      final statusCode = snappedChatService?.lastResponseStatusCode;
      final respHeaders = snappedChatService?.lastResponseHeaders;
      if (respData != null || statusCode != null || respHeaders != null) {
        rawResponseCapture = {};
        if (statusCode != null) {
          rawResponseCapture['statusCode'] = statusCode;
        }
        if (respHeaders != null) {
          rawResponseCapture['headers'] = respHeaders;
        }
        if (respData != null) rawResponseCapture['data'] = respData;
      } else if (streamError is Object) {
        rawResponseCapture = {'error': streamError.toString()};
      }
    } catch (_) {}
    // ── 实际 token 计量与花费（来自 API usage，非估算） ──
    // 更新对话的 lastInputTokens/lastOutputTokens 与累计花费。
    // 花费纯粹采用 API 返回的 cost（如 OpenRouter usage.total_cost），
    // 不自统计（缓存/推理 token 计价要素太多，自统计不准）。
    final wasCancelled = state.cancelledByUser;
    try {
      final usage = snappedChatService?.lastUsage;
      if (usage != null) {
        final inputTokens = usage['inputTokens'] as int?;
        final outputTokens = usage['outputTokens'] as int?;
        final cost = usage['cost'] as double? ?? 0;
        if (inputTokens != null || outputTokens != null || cost > 0) {
          await _ref?.read(conversationsProvider.notifier).updateUsage(
                conversationId: convId,
                // 用户取消的流：usage 可能不完整（流被截断），写
                // input/output 会让 lastInputTokens 虚低（压缩触发
                // 判断失真）；cost 是已发生的事实，保留累计。
                inputTokens: wasCancelled ? null : inputTokens,
                outputTokens: wasCancelled ? null : outputTokens,
                costIncrement: cost,
              );
        }
      }
    } catch (e) {
      debugPrint('[ChatStreamManager] usage 计量更新失败: $e');
    }

    // Do NOT overwrite state.reasoningSections or state.reasoningBuffer
    // from _adapter.reasoningContent. The manager already correctly
    // accumulates reasoning sections event-by-event (ReasoningEvent +
    // ReasoningSectionEndEvent), and _adapter.reasoningContent is a
    // cumulative buffer from the ChatService that is never reset per-round.
    // Overwriting would merge all reasoning into the last section.

    // ── Post-stream processing ──
    ChatMessage? assistantMessage;
    // Align with the catch clause in startStreaming, which folds the error
    // text into fullReply for ANY thrown object (not just Exception/Error).
    final hadStreamError = streamError != null;

    // 中断工具标记：取消或流错误时，把仍未完成的工具结果标记为中断占位，
    // 避免 UI 与持久化中工具永远停留在 running 状态。
    // 必须保证不抛异常：此段在 try 外，一旦抛出 completer 永不完成
    // （页面 await 永久挂起、service 残留、下一条消息被去重丢弃）。
    try {
      if (wasCancelled || hadStreamError) {
        for (var i = 0; i < state.toolCalls.length; i++) {
          final tc = state.toolCalls[i];
          if (tc.status == ToolCallStatus.running ||
              tc.status == ToolCallStatus.pending) {
            state.toolCalls[i] = tc.copyWith(
              status: ToolCallStatus.completed,
              result: ChatService.kToolInterruptedPlaceholder,
            );
          }
        }
        for (var i = 0; i < state.accumulatedToolCalls.length; i++) {
          final tc = state.accumulatedToolCalls[i];
          if (tc.status == ToolCallStatus.running ||
              tc.status == ToolCallStatus.pending) {
            state.accumulatedToolCalls[i] = tc.copyWith(
              status: ToolCallStatus.completed,
              result: ChatService.kToolInterruptedPlaceholder,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatStreamManager] 中断工具标记失败: $e');
    }

    try {
      // 纯工具轮取消时 fullReply 为空但 accumulatedToolCalls 非空：
      // 仍要持久化 assistant 消息，否则中断标记（[工具执行被中断]）
      // 从 UI 与存储中丢失。同理，纯推理轮取消（fullReply 与工具
      // 均空但 reasoningSections 非空）：已流出的推理内容也要落库，
      // 否则用户看到的思考过程在崩溃/重进后消失。
      final hasContent = state.fullReply.isNotEmpty ||
          state.accumulatedToolCalls.isNotEmpty ||
          state.reasoningSections.any((s) => s.isNotEmpty);
      if (hasContent) {
        // 用显式错误标志而非文本前缀判断：模型正常回复以"错误:"开头
        // 时不应被误标为错误消息。
        final isError = hadStreamError;
        // reasoningContent 用全量累计（sections 拼接）：ReasoningSectionEndEvent
        // 会重置 reasoningBuffer，后者只含最后一轮——OpenAI 协议历史重建
        // 回放 reasoning_content 时，中间轮推理会丢失（深度推理模型
        // 上下文质量下降）。sections 是权威存储，二者不同源。
        final fullReasoning = state.reasoningSections.join('\n');
        final msg = ChatMessage(
          role: 'assistant',
          content: state.fullReply,
          id: state.streamingMsgId ?? '',
          isError: isError,
          reasoningContent: fullReasoning.isNotEmpty ? fullReasoning : null,
          rawRequest: rawRequestCapture,
          rawResponse: rawResponseCapture,
          toolCalls: state.accumulatedToolCalls.isNotEmpty
              ? List<ToolCallData>.from(state.accumulatedToolCalls)
              : null,
          reasoningSections: state.reasoningSections.isNotEmpty
              ? List<String>.from(state.reasoningSections)
              : null,
          textSections: state.textChunks.any((c) => c.isNotEmpty)
              ? List<String>.from(state.textChunks)
              : null,
          toolCallRoundStarts: state.toolCallRoundStarts.isNotEmpty
              ? List<int>.from(state.toolCallRoundStarts)
              : null,
          blocks: legacyToBlocks(
            reasoningSections: state.reasoningSections,
            textChunks: state.textChunks,
            toolCalls: state.accumulatedToolCalls,
            toolCallRoundStarts: state.toolCallRoundStarts,
          ),
        );
        state.history.add(msg);
        assistantMessage = msg;
      }
    } catch (e, s) {
      debugPrint('[ChatStreamManager] 后处理错误: $e\n$s');
    }

    // ── Persist BEFORE cleaning up stream state ──
    // This guard ensures save always runs, even if the code below throws.
    // It's the single persistence path for all streaming results.
    // Identity guard：Stop→re-Send 时旧流的 finalize 可能晚于新流的
    // 保存执行——若 _streams[convId] 已指向新 state，旧历史（不含
    // 新用户消息）不得覆盖新流已持久化的数据。
    try {
      if (state.history.isNotEmpty && _streams[convId] == state) {
        await AppLogService.info('ChatStreamManager',
            '[STREAM-MGR] startStreaming: persisting historyLen=${state.history.length}');
        await _saveMessages(convId: convId, history: state.history);
        // 保存 await 期间新流可能已注册（Stop→re-Send）：此时本次
        // 保存已把旧历史写入（updateMessages 全量替换），若新流已
        // 持久化过数据，重新保存最新 _streams[convId] 的历史覆盖回来。
        // （防御 TOCTOU：保存前检查 + 保存后检查双保险）
        if (_streams[convId] != state &&
            _streams[convId]?.history.isNotEmpty == true) {
          await _saveMessages(
              convId: convId,
              history: List<ChatMessage>.from(_streams[convId]!.history));
        }
      }
    } catch (e) {
      await AppLogService.error(
          'ChatStreamManager', '[STREAM-MGR] save failed', e);
    }

    // Build the result and complete the resultCompleter AFTER save.
    // 注意：标题生成等 LLM 回环任务绝不能阻塞这里 —— 否则页面
    // _startStreaming 的 await 被拖住（秒级），且此窗口内用户的再次
    // 发送会命中 _streams 去重而丢失新消息。
    // 结果构造必须保证不抛异常：completer 一旦不 complete，页面
    // await 永久挂起、service 残留（下一条消息复用旧 service 会
    // 导致 usage 双计）。
    StreamResult result;
    try {
      result = StreamResult(
        history: List.from(state.history),
        assistantMessage: assistantMessage,
        fullReply: state.fullReply,
        reasoningBuffer: state.reasoningBuffer,
        reasoningSections: List.from(state.reasoningSections),
        textSections: List.from(state.textChunks),
        toolCalls: List.from(state.accumulatedToolCalls),
        toolCallRoundStarts: List.from(state.toolCallRoundStarts),
        blocks: legacyToBlocks(
          reasoningSections: state.reasoningSections,
          textChunks: state.textChunks,
          toolCalls: state.accumulatedToolCalls,
          toolCallRoundStarts: state.toolCallRoundStarts,
        ),
        cancelled: wasCancelled,
      );
    } catch (e, s) {
      debugPrint('[ChatStreamManager] 结果构造失败: $e\n$s');
      result = StreamResult(
        history: List.from(state.history),
        fullReply: state.fullReply,
        cancelled: wasCancelled,
      );
    }

    // Complete the result completer so duplicate startStreaming calls
    // await the same future and get the final result.
    if (!state.resultCompleter!.isCompleted) {
      state.resultCompleter!.complete(result);
    }

    // Clean up this conversation's stream.
    // Identity guard: if _streams[convId] no longer references THIS state
    // object, a new stream was already started for the same convId (via the
    // Stop→re-Send path). In that case, skip removal and provider cleanup
    // to avoid destroying the new stream's state.
    if (_streams[convId] == state) {
      _streams.remove(convId);
    }
    state.resultCompleter = null;

    // Only clear per-conversation providers if no new stream replaced
    // this one. If a new stream is active for the same convId, its own
    // provider state should be left untouched.
    final replaced = _streams.containsKey(convId) && _streams[convId] != state;
    if (!replaced) {
      _setProvider(isStreamingProvider(convId), false);
      _setProvider(streamingMsgIdProvider(convId), null);
      _setProvider(streamingHasFirstTokenProvider(convId), false);
      _setProvider(streamingReasoningProvider(convId), '');
    }

    // Remove this conversation from the streaming set ONLY if no new
    // stream replaced this one. If _streams still contains convId (pointing
    // to a different state object), keep it in the streaming set.
    if (!_streams.containsKey(convId)) {
      final activeSet = <String>{
        ..._ref?.read(streamingConversationsProvider) ?? const {}
      };
      activeSet.remove(convId);
      _setProvider(streamingConversationsProvider, activeSet);
      // Dispose the per-conversation ChatService so a subsequent
      // startStreaming for the same convId creates a fresh service
      // with the latest config (from forceService / selectModel).
      _adapter.cancelService(convId);

      // ── 自动标题（fire-and-forget，不阻塞结果返回） ──
      // 放在 cancelService 之后：_maybeGenerateTitle 内部用
      // createTransientService 创建一次性 service，不会与已 dispose
      // 的旧 service 冲突。失败静默（保留截断标题）。
      if (!wasCancelled && !hadStreamError && state.history.isNotEmpty) {
        // ignore: discarded_futures
        unawaited(_maybeGenerateTitle(
          convId: convId,
          history: List<ChatMessage>.from(state.history),
        ));
      }
    }

    // Do NOT clear segment-related providers here (streamingFullReplyProvider,
    // streamingTextSectionsProvider, streamingReasoningSectionsProvider,
    // streamingToolCallsProvider, streamingToolCallRoundStartsProvider).
    // The chat_page's post-stream code in _startStreaming handles provider
    // cleanup AFTER updating _history and calling _buildFinalSegments.
    // Clearing segment providers prematurely triggers _rebuildLiveSegments
    // with empty data, overwriting the correct segments (including reasoning
    // with isStreaming=true that should have been replaced by
    // _buildFinalSegments with isStreaming=false).

    return result;
  }
}
