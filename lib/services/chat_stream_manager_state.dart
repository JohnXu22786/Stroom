part of 'chat_stream_manager.dart';

// ============================================================================
// StreamResult — 流式请求完成后返回的结果
// ============================================================================

/// The result of a streaming request, returned by [ChatStreamManager.startStreaming].
///
/// Contains the final message history (including the assistant's response),
/// the accumulated reply text, and any tool calls or reasoning content.
class StreamResult {
  /// The conversation message history after the assistant message was appended.
  final List<ChatMessage> history;

  /// The newly created assistant message, or null if no text was received.
  final ChatMessage? assistantMessage;

  /// The full accumulated reply text from the stream.
  final String fullReply;

  /// The accumulated reasoning buffer, or empty if no reasoning events.
  final String reasoningBuffer;

  /// All reasoning sections (for multi-step tool call rounds).
  final List<String> reasoningSections;

  /// Per-round text chunks that mirror the Agent chain structure,
  /// allowing assistant speech to be interleaved between reasoning
  /// and tool call blocks instead of all appearing at the end.
  final List<String> textSections;

  /// Tool calls accumulated during the stream.
  final List<ToolCallData> toolCalls;

  /// Indices into [toolCalls] where each new tool-call round begins.
  /// Used by [buildAgentChainSegments] to group consecutive tool calls
  /// that belong to the same assistant step. Each round is sealed by a
  /// ReasoningSectionEndEvent (recorded via pendingRoundStart) or by
  /// non-empty text before the round's first tool call.
  final List<int> toolCallRoundStarts;
  final List<MessageBlock> blocks;

  /// Whether the stream was cancelled by the user.
  final bool cancelled;

  const StreamResult({
    required this.history,
    this.assistantMessage,
    this.fullReply = '',
    this.reasoningBuffer = '',
    this.reasoningSections = const [],
    this.textSections = const [],
    this.toolCalls = const [],
    this.toolCallRoundStarts = const [],
    this.blocks = const [],
    this.cancelled = false,
  });

  /// Whether the stream produced any content.
  bool get hasContent => fullReply.isNotEmpty;
}

// ============================================================================
// _ConversationStreamState — per-conversation mutable streaming state
// ============================================================================

class _ConversationStreamState {
  final String convId;
  bool cancelledByUser = false;

  /// Guards against overlapping periodic persist calls from the timer.
  bool _isPersisting = false;
  String? streamingMsgId;
  Future<void> Function(ChatMessage continuation)? onContinuation;
  final StringBuffer _fullReply = StringBuffer();
  String get fullReply => _fullReply.toString();
  set fullReply(String value) {
    _fullReply
      ..clear()
      ..write(value);
  }

  final StringBuffer _reasoningBuffer = StringBuffer();
  String get reasoningBuffer => _reasoningBuffer.toString();
  List<String> _reasoningSections = [];
  bool _reasoningSectionActive = false;
  List<String> get reasoningSections => [
        ..._reasoningSections,
        if (_reasoningSectionActive) _reasoningBuffer.toString(),
      ];

  void appendReasoning(String text) {
    if (!_reasoningSectionActive &&
        _reasoningSections.isNotEmpty &&
        _reasoningSections.last.isEmpty) {
      _reasoningSections.removeLast();
    }
    _reasoningBuffer.write(text);
    _reasoningSectionActive = true;
  }

  void endReasoningSection() {
    _reasoningSections = reasoningSections..add('');
    _reasoningBuffer.clear();
    _reasoningSectionActive = false;
  }

  final List<StringBuffer> _textChunks = [StringBuffer()];
  List<String> get textChunks =>
      _textChunks.map((chunk) => chunk.toString()).toList();

  void appendText(String text) {
    _fullReply.write(text);
    _textChunks.last.write(text);
  }

  void startTextChunk() => _textChunks.add(StringBuffer());

  bool get currentTextChunkIsNotEmpty => _textChunks.last.isNotEmpty;

  /// Per-round text chunks that mirror reasoning sections: each time a new
  /// tool call round begins, a new chunk is started so that post-stream
  /// segment building can interleave assistant speech between reasoning and
  /// tool call blocks in the correct Agent chain order.
  List<ToolCallData> toolCalls = [];
  List<ChatMessage> history = [];
  List<ChatMessage>? historyOnSuccess;
  bool hasReceivedFirstToken = false;
  bool isComplete = false;

  /// Accumulator for tool calls across streaming rounds (used for history).
  final List<ToolCallData> accumulatedToolCalls = [];

  /// Indices into [toolCalls] where each new tool-call round begins.
  /// Used by buildAgentChainSegments to correctly group consecutive
  /// tool calls that belong to the same assistant "step".
  ///
  /// Initialized empty (NOT [0]) — the first ToolCallStartEvent adds
  /// index 0 when it creates the first new text chunk. Pre-seeding [0]
  /// would cause a duplicate [0, 0], splitting round 0's tools across
  /// phantom rounds.
  List<int> toolCallRoundStarts = [];

  /// Set by [ReasoningSectionEndEvent] and consumed by the next
  /// [ToolCallStartEvent]. Marks that the next tool call begins a NEW
  /// round — the reasoning-section boundary is the authoritative round
  /// boundary (the service emits one end event per tool round), while
  /// text chunks alone miss rounds that start with reasoning and no
  /// visible text (the standard reasoning-model agent pattern).
  /// Without this, such rounds were merged into the previous round and
  /// their reasoning section was rendered at the bottom of the message.
  bool pendingRoundStart = false;
  List<MessageBlock> blocks = [];

  /// Throttle timers
  DateTime lastTextUpdate = DateTime.now();
  DateTime lastReasoningUpdate = DateTime.now();

  /// Periodic persistence timer
  Timer? persistTimer;

  /// Completer used to return the same future for duplicate startStreaming
  /// calls on the same conversation.
  Completer<StreamResult>? resultCompleter;

  _ConversationStreamState({required this.convId});
}
