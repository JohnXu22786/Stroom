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
    // Deliver any sub-throttle reasoning tail before the stream state is
    // cleared. Normal section-end events flush this same delta earlier.
    final reasoningTail = state.takeReasoningAppend();
    if (reasoningTail != null) {
      _pushToProvider(convId, streamingReasoningAppendProvider, reasoningTail);
    }

    // Timer cancellation prevents future callbacks but does not wait for a
    // partial write already in progress. Let it finish before building the
    // full-history snapshot so the two large saves do not overlap.
    try {
      await state._periodicPersistFuture;
    } catch (e) {
      debugPrint('[ChatStreamManager] 等待定期持久化失败: $e');
    }

    // Capture request/response raw data from the ChatService instance
    // that was active when this stream started (snapped above). Using
    // the snapped reference is critical: adapter.currentChatService may
    // have been replaced mid-stream by a page re-entry calling configure()
    // or selectModel(). Reading through the replaced service returns null.
    Map<String, dynamic>? rawRequestCapture;
    Map<String, dynamic>? rawResponseCapture;
    try {
      final reqBody = state.requestBodySnapshot;
      final headers = snappedChatService?.lastRequestHeaders;
      final url = snappedChatService?.lastRequestUrl;
      if (reqBody != null || headers != null || url != null) {
        rawRequestCapture = {};
        if (url != null) rawRequestCapture['url'] = url;
        if (headers != null) rawRequestCapture['headers'] = headers;
        if (reqBody != null) rawRequestCapture['body'] = reqBody;
      }
      if (rawRequestCapture != null) {
        rawRequestCapture = ChatMessage.compactRawRequest(rawRequestCapture);
      }
      snappedChatService?.releaseLastRequestBody(reqBody);
      state.requestBodySnapshot = null;
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
    // 对话级计费累计已由 per-request 事件驱动完成（_commitUsage：
    // 每次请求的完整 usage 数据返回时立即增量累加，含压缩/标题内部
    // 任务请求）。这里不再整次发送一次性提交——避免 service 复用/
    // 异常清理路径把旧请求 usage 重复提交（双计）。
    final wasCancelled = state.cancelledByUser;

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
    if (!wasCancelled && !hadStreamError && state.historyOnSuccess != null) {
      final storedMessagesById = <String, ChatMessage>{};
      for (final storedMessage in state.history) {
        storedMessagesById.putIfAbsent(
          storedMessage.id,
          () => storedMessage,
        );
      }
      state.history = state.historyOnSuccess!
          .map((message) => storedMessagesById[message.id] ?? message)
          .toList();
    }

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

    // Keep ordinary stream text section-backed. The persisted message and UI
    // can materialize content when needed, while TaskFlow's fullReply getter
    // joins only when that consumer explicitly asks for a String. Synthetic
    // error replies are not represented by text sections and stay explicit.
    final fullReply = state.hasSyntheticErrorReply ? state.fullReply : null;
    final textChunks =
        state.hasSyntheticErrorReply ? <String>[] : state.textChunks;
    final hasTextContent = textChunks.any((chunk) => chunk.isNotEmpty);
    try {
      // 纯工具轮取消时 fullReply 为空但 accumulatedToolCalls 非空：
      // 仍要持久化 assistant 消息，否则中断标记（[工具执行被中断]）
      // 从 UI 与存储中丢失。同理，纯推理轮取消（fullReply 与工具
      // 均空但 reasoningSections 非空）：已流出的推理内容也要落库，
      // 否则用户看到的思考过程在崩溃/重进后消失。
      final hasContent = wasCancelled ||
          (fullReply?.isNotEmpty ?? hasTextContent) ||
          state.accumulatedToolCalls.isNotEmpty ||
          state.reasoningSections.any((s) => s.isNotEmpty);
      if (hasContent) {
        // 用显式错误标志而非文本前缀判断：模型正常回复以"错误:"开头
        // 时不应被误标为错误消息。
        final isError = hadStreamError || wasCancelled;
        final blocks = legacyToBlocks(
          reasoningSections: state.reasoningSections,
          textChunks: textChunks,
          toolCalls: state.accumulatedToolCalls,
          toolCallRoundStarts: state.toolCallRoundStarts,
        );
        if (wasCancelled) {
          blocks.add(const ErrorBlock(message: '用户中断了输出'));
        } else if (hadStreamError &&
            (textChunks.any((chunk) => chunk.isNotEmpty) ||
                state.reasoningSections.any((section) => section.isNotEmpty))) {
          final errorMessage = _ref == null
              ? formatChatErrorMessage(streamError)
              : formatChatErrorMessage(
                  streamError,
                  locale: _ref?.read(localeProvider),
                );
          blocks.add(ErrorBlock(message: errorMessage));
        }
        final msg = ChatMessage(
          role: 'assistant',
          content: fullReply ?? '',
          contentFromTextSections:
              !state.hasSyntheticErrorReply && hasTextContent,
          id: state.streamingMsgId ?? '',
          isError: isError,
          rawRequest: rawRequestCapture,
          rawResponse: rawResponseCapture,
          toolCalls: state.accumulatedToolCalls.isNotEmpty
              ? List<ToolCallData>.from(state.accumulatedToolCalls)
              : null,
          reasoningSections: state.reasoningSections.isNotEmpty
              ? List<String>.from(state.reasoningSections)
              : null,
          textSections: textChunks.any((c) => c.isNotEmpty)
              ? List<String>.from(textChunks)
              : null,
          toolCallRoundStarts: state.toolCallRoundStarts.isNotEmpty
              ? List<int>.from(state.toolCallRoundStarts)
              : (state.accumulatedToolCalls.isNotEmpty ? [0] : null),
          blocks: blocks,
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
    // 保存执行——若 _streams[convId] 已指向新 state，旧历史（不�