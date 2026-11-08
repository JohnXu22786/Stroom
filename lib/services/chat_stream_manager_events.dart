part of 'chat_stream_manager.dart';

extension _ChatStreamManagerEventsExt on ChatStreamManager {
  /// Dispatches a single stream [event] into [state], updating the
  /// per-conversation accumulators and pushing throttled provider updates.
  void _handleStreamEvent(
      ChatEvent event, _ConversationStreamState state, String convId) {
    switch (event) {
      case InputTranscriptEvent _:
        // Provider-side transcription belongs to the user turn; it is not
        // assistant output and is already retained by the audio request.
        break;
      case MediaAttachmentsEvent e:
        final eventOrder = e.contentOrder;
        for (var index = 0; index < e.attachments.length; index++) {
          final attachment = e.attachments[index];
          final storedOrder = attachment.extraFields['stroom.contentOrder'];
          final attachmentOrder = storedOrder is int
              ? storedOrder + state.contentOrderOffset
              : eventOrder == null
                  ? state.nextContentOrder
                  : eventOrder + state.contentOrderOffset + index;
          final owned = attachment.copyWith(conversationId: convId);
          state.mediaAttachments.add(owned);
          state.orderedContentParts.add({
            'type': 'attachment',
            'attachmentId': owned.id,
            'contentOrder': attachmentOrder,
          });
          if (state.nextContentOrder <= attachmentOrder) {
            state.nextContentOrder = attachmentOrder + 1;
          }
        }
        break;
      case TextEvent e:
        if (e.text.isNotEmpty) {
          final order = e.contentOrder == null
              ? state.nextContentOrder
              : e.contentOrder! + state.contentOrderOffset;
          state.orderedContentParts.add({
            'type': 'text',
            'text': e.text,
            'contentOrder': order,
          });
          if (state.nextContentOrder <= order) {
            state.nextContentOrder = order + 1;
          }
        }
        if (!state.hasReceivedFirstToken) {
          state.hasReceivedFirstToken = true;
          _pushToProvider(convId, streamingHasFirstTokenProvider, true);
        }
        if (!e.alreadyAccumulated) state.appendText(e.text);
        // 节流：最长200ms更新一次 provider
        final now = DateTime.now();
        if (now.difference(state.lastTextUpdate) >=
            ChatStreamManager._textThrottle) {
          state.lastTextUpdate = now;
          final hasMarkdownSyntax = state.currentChunkHasMarkdownSyntax;
          final textDelta = state.takeTextDelta();
          if (textDelta.isNotEmpty) {
            _pushToProvider(
              convId,
              streamingTextAppendProvider,
              StreamingTextAppend(
                sequence: state.nextTextUpdateSequence,
                chunkIndex: state.currentTextChunkIndex,
                text: textDelta,
                hasMarkdownSyntax: hasMarkdownSyntax,
              ),
            );
          }
        }

      case ReasoningEvent e:
        state.appendReasoning(e.text);
        // 节流
        final now = DateTime.now();
        if (now.difference(state.lastReasoningUpdate) >=
            ChatStreamManager._reasoningThrottle) {
          state.lastReasoningUpdate = now;
          final append = state.takeReasoningAppend();
          if (append != null) {
            _pushToProvider(convId, streamingReasoningAppendProvider, append);
          }
        }

      case ReasoningSectionEndEvent e:
        // Each provider request restarts contentOrder at zero. A follow-up
        // tool request belongs to the same assistant reply, so offset its
        // visible content after the completed rounds.
        state.contentOrderOffset = state.nextContentOrder;
        // Drain the last visible text delta before sealing this round. The
        // service waits for this event before building the tool-chain message
        // or requesting the next round.
        final pendingText = state.takeTextDelta();
        if (pendingText.isNotEmpty) {
          final hasMarkdownSyntax = state.currentChunkHasMarkdownSyntax;
          _pushToProvider(
            convId,
            streamingTextAppendProvider,
            StreamingTextAppend(
              sequence: state.nextTextUpdateSequence,
              chunkIndex: state.currentTextChunkIndex,
              text: pendingText,
              hasMarkdownSyntax: hasMarkdownSyntax,
            ),
          );
          if (hasMarkdownSyntax) {
            // The text-section snapshot includes this drained tail. Publish
            // the delta first so the live segment cannot append it twice.
            _pushToProvider(
                convId, streamingTextSectionsProvider, state.textChunks);
          }
        }
        state.startTextChunkFromService();
        // Preserve the sub-throttle tail before publishing the boundary.
        final append = state.takeReasoningAppend();
        if (append != null) {
          _pushToProvider(convId, streamingReasoningAppendProvider, append);
        }
        final completedReasoning = state.reasoningBuffer;
        state.setCompletedToolCallReasoning(completedReasoning);
        state.endReasoningSection();
        final sections = state.reasoningSections;
        _pushToProvider(convId, streamingReasoningProvider, completedReasoning);
        // The service emits one ReasoningSectionEndEvent per tool round,
        // right before that round's ToolCallStartEvents. Mark that the
        // next tool call begins a new round: the reasoning-section
        // boundary is authoritative even when the round starts with
        // reasoning and no visible text (the standard reasoning-model
        // agent pattern). Without this, such rounds were merged into the
        // previous round and their reasoning section was rendered at the
        // bottom of the message by _buildWithRounds' trailing loop.
        state.pendingRoundStart = true;
        _pushToProvider(convId, streamingReasoningSectionsProvider, sections);
        e.onDelivered?.call();

      case ToolCallStartEvent e:
        final toolCallData = ToolCallData(
          id: e.toolCall.id,
          name: e.toolCall.name,
          arguments: Map<String, dynamic>.from(e.toolCall.arguments),
          status: ToolCallStatus.running,
        );
        state.toolCalls.add(toolCallData);
        state.addAccumulatedToolCall(toolCallData);
        // Start a new text chunk at tool call boundary so that
        // assistant speech is interleaved between tool call rounds
        // rather than all appearing at the end.
        // A new round starts when:
        // 1. the reasoning-section boundary says so (pendingRoundStart —
        //    the previous round sealed its reasoning section), or
        // 2. the last text chunk is non-empty (speech preceded this
        //    tool call), or
        // 3. this is the very first tool call.
        // Consecutive tool calls within the same assistant step (parallel
        // tools emitted in one response) don't satisfy any condition and
        // stay grouped in the same round.
        final serviceStartedTextChunk = state.takeServiceStartedTextChunk();
        if (serviceStartedTextChunk ||
            state.pendingRoundStart ||
            state.currentTextChunkIsNotEmpty ||
            state.textChunks.length == 1) {
          if (!serviceStartedTextChunk) state.startTextChunk();
          // Record that this tool call starts a new round.
          state.toolCallRoundStarts.add(state.toolCalls.length - 1);
        }
        state.pendingRoundStart = false;
        // Push order matters: the textSections and toolCalls listeners call
        // _rebuildLiveSegments synchronously (Riverpod fires listeners on
        // state change), which reads ALL segment providers. roundStarts must
        // therefore be pushed BEFORE toolCalls — otherwise the rebuild
        // triggered by the toolCalls push reads the stale round boundary and
        // renders the new round's reasoning at the bottom until the first
        // complete event of the round.
        _pushToProvider(
            convId, streamingTextSectionsProvider, state.textChunks);
        _pushToProvider(convId, streamingToolCallRoundStartsProvider,
            List<int>.from(state.toolCallRoundStarts));
        _pushToProvider(convId, streamingToolCallsProvider,
            List<ToolCallData>.from(state.toolCalls));

      case ToolCallCompleteEvent e:
        for (var i = 0; i < state.toolCalls.length; i++) {
          if (state.toolCalls[i].id == e.toolCallId) {
            state.toolCalls[i] = state.toolCalls[i].copyWith(
              status: ToolCallStatus.completed,
              result: e.result,
            );
            break;
          }
        }
        state.updateAccumulatedToolCall(
          e.toolCallId,
          (call) => call.copyWith(
            status: ToolCallStatus.completed,
            result: e.result,
          ),
        );
        _pushToProvider(convId, streamingToolCallsProvider,
            List<ToolCallData>.from(state.toolCalls));
    }
  }
}
