part of 'chat_stream_manager.dart';

extension _ChatStreamManagerEventsExt on ChatStreamManager {
  /// Dispatches a single stream [event] into [state], updating the
  /// per-conversation accumulators and pushing throttled provider updates.
  void _handleStreamEvent(
      ChatEvent event, _ConversationStreamState state, String convId) {
    switch (event) {
      case TextEvent e:
        if (!state.hasReceivedFirstToken) {
          state.hasReceivedFirstToken = true;
          _pushToProvider(convId, streamingHasFirstTokenProvider, true);
        }
        state.fullReply += e.text;
        state.textChunks[state.textChunks.length - 1] += e.text;
        // 节流：最长200ms更新一次 provider
        final now = DateTime.now();
        if (now.difference(state.lastTextUpdate) >=
            ChatStreamManager._textThrottle) {
          state.lastTextUpdate = now;
          // Set textSections first (no listener) so that when
          // fullReply fires its listener and reads streamingTextSectionsProvider
          // inside _rebuildLiveSegments, it sees the already-updated value.
          _pushToProvider(convId, streamingTextSectionsProvider,
              List<String>.from(state.textChunks));
          _pushToProvider(convId, streamingFullReplyProvider, state.fullReply);
        }

      case ReasoningEvent e:
        state.reasoningBuffer += e.text;
        final sections = List<String>.from(state.reasoningSections);
        if (sections.isNotEmpty) {
          sections[sections.length - 1] = state.reasoningBuffer;
        } else {
          sections.add(state.reasoningBuffer);
        }
        state.reasoningSections = sections;
        // 节流
        final now = DateTime.now();
        if (now.difference(state.lastReasoningUpdate) >=
            ChatStreamManager._reasoningThrottle) {
          state.lastReasoningUpdate = now;
          _pushToProvider(
              convId, streamingReasoningProvider, state.reasoningBuffer);
          _pushToProvider(convId, streamingReasoningSectionsProvider, sections);
        }

      case ReasoningSectionEndEvent():
        final sections = List<String>.from(state.reasoningSections);
        sections.add('');
        state.reasoningSections = sections;
        state.reasoningBuffer = ''; // Reset for new reasoning section
        _pushToProvider(convId, streamingReasoningSectionsProvider, sections);

      case ToolCallStartEvent e:
        final toolCallData = ToolCallData(
          id: e.toolCall.id,
          name: e.toolCall.name,
          arguments: Map<String, dynamic>.from(e.toolCall.arguments),
          status: ToolCallStatus.running,
        );
        state.toolCalls.add(toolCallData);
        state.accumulatedToolCalls.add(toolCallData);
        // Start a new text chunk at tool call boundary so that
        // assistant speech is interleaved between tool call rounds
        // rather than all appearing at the end.
        if (state.textChunks.last.isNotEmpty || state.textChunks.length == 1) {
          state.textChunks.add('');
          // Record that this tool call starts a new round.
          // Consecutive tool calls that don't create new text chunks
          // are grouped together in the same round.
          state.toolCallRoundStarts.add(state.toolCalls.length - 1);
        }
        // Set textSections first (no listener) so that when
        // toolCalls fires its listener, it reads the updated value.
        _pushToProvider(convId, streamingTextSectionsProvider,
            List<String>.from(state.textChunks));
        _pushToProvider(convId, streamingToolCallsProvider,
            List<ToolCallData>.from(state.toolCalls));
        _pushToProvider(convId, streamingToolCallRoundStartsProvider,
            List<int>.from(state.toolCallRoundStarts));

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
        for (var i = 0; i < state.accumulatedToolCalls.length; i++) {
          if (state.accumulatedToolCalls[i].id == e.toolCallId) {
            state.accumulatedToolCalls[i] =
                state.accumulatedToolCalls[i].copyWith(
              status: ToolCallStatus.completed,
              result: e.result,
            );
            break;
          }
        }
        _pushToProvider(convId, streamingToolCallsProvider,
            List<ToolCallData>.from(state.toolCalls));
    }
  }
}
