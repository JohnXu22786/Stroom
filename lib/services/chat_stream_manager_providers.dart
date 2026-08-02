part of 'chat_stream_manager.dart';

extension _ChatStreamManagerProvidersExt on ChatStreamManager {
  // ── Provider 更新辅助 ──

  void _setProvider<T>(StateProvider<T> provider, T value) {
    if (_ref == null) return;
    _ref!.read(provider.notifier).state = value;
  }

  /// Pushes the state of the given conversation to its per-conversation
  /// family provider instances.
  void _pushStateToProviders(_ConversationStreamState s) {
    _setProvider(isStreamingProvider(s.convId), true);
    _setProvider(streamingMsgIdProvider(s.convId), s.streamingMsgId);
    _setProvider(streamingFullReplyProvider(s.convId), s.fullReply);
    _setProvider(
        streamingHasFirstTokenProvider(s.convId), s.hasReceivedFirstToken);
    _setProvider(streamingReasoningProvider(s.convId), s.reasoningBuffer);
    _setProvider(streamingReasoningSectionsProvider(s.convId),
        List<String>.from(s.reasoningSections));
    _setProvider(streamingToolCallsProvider(s.convId),
        List<ToolCallData>.from(s.toolCalls));
    _setProvider(streamingTextSectionsProvider(s.convId),
        List<String>.from(s.textChunks));
    _setProvider(streamingToolCallRoundStartsProvider(s.convId),
        List<int>.from(s.toolCallRoundStarts));
  }

  /// Clears streaming providers for a specific conversation.
  ///
  /// Only clears if [convId] does NOT currently have an active stream.
  /// If another conversation IS streaming (different convId), this
  /// conversation's unrelated provider entries are still cleared.
  void _clearProvidersFor(String convId) {
    if (_streams.containsKey(convId)) return; // Don't clear if still streaming
    _setProvider(isStreamingProvider(convId), false);
    _setProvider(streamingMsgIdProvider(convId), null);
    _setProvider(streamingFullReplyProvider(convId), '');
    _setProvider(streamingHasFirstTokenProvider(convId), false);
    _setProvider(streamingReasoningProvider(convId), '');
    _setProvider(streamingReasoningSectionsProvider(convId), []);
    _setProvider(streamingToolCallsProvider(convId), []);
    _setProvider(streamingTextSectionsProvider(convId), ['']);
    _setProvider(streamingToolCallRoundStartsProvider(convId), []);
  }

  /// Pushes a provider update for [convId]'s family instance.
  /// With family providers, there is no _activeConvId guard — each
  /// conversation writes to its own independent provider space.
  void _pushToProvider<T>(
      String convId, StateProviderFamily<T, String> family, T value) {
    if (_ref == null) return;
    _setProvider(family(convId), value);
  }
}
