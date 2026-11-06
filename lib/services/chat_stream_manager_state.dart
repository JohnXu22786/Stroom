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
  Map<String, dynamic>? requestBodySnapshot;
  bool cancelledByUser = false;
  bool toolCallStarted = false;
  final Completer<void> cancellationSignal = Completer<void>();

  void cancelByUser() {
    cancelledByUser = true;
    if (!cancellationSignal.isCompleted) cancellationSignal.complete();
  }

  /// Guards against overlapping periodic persist calls from the timer.
  bool _isPersisting = false;
  Future<void>? _periodicPersistFuture;
  String? streamingMsgId;
  Future<bool> Function(ChatMessage continuation)? onContinuation;
  final List<ChatMessage> pendingContinuations = [];
  final Set<ChatMessage> deliveringContinuations = {};
  // The text sections are the canonical live representation. Completed
  // sections are immutable strings, and only the current section remains a
  // mutable buffer. This lets throttled snapshots reuse sealed sections
  // instead of copying the full reply for every update.
  final List<String> _completedTextChunks = [];
  StringBuffer _currentTextChunk = StringBuffer();

  String get fullReply => textChunks.join();
  set fullReply(String value) {
    _completedTextChunks.clear();
    _currentTextChunk = StringBuffer(value);
    _pendingTextDelta.clear();
    _currentChunkHasMarkdownSyntax = _containsMarkdownSyntax(value);
    _markdownSyntaxCarry = '';
    _markdownCarryStartsAtLineStart = true;
    _pendingInlineDelimiter = null;
    _pendingInlineDelimiterLength = 0;
    _inlineDelimiterLeftCodeUnit = null;
    _lastScannedCodeUnit = null;
    _consecutiveBackslashes = 0;
    _openInlineDelimiters.clear();
    _openLinkLabel = false;
    _closedLinkLabel = false;
    _openLinkLabelAtLineStart = false;
    _closedLinkLabelAtLineStart = false;
    _linkScannerAtLineStart = true;
    _linkScannerLineSpaces = 0;
    _lineStartHasDigits = false;
    _atLineStart = true;
    _pendingOrderedListMarker = false;
    _scanOrderedListMarkers(value);
    _currentChunkHasMarkdownSyntax |= _scanInlineMarkdown(value);
  }

  final StringBuffer _reasoningBuffer = StringBuffer();
  String? _reasoningBufferSnapshot;
  String get _reasoningSnapshot =>
      _reasoningBufferSnapshot ??= _reasoningBuffer.toString();
  String get reasoningBuffer => _reasoningSnapshot;
  final StringBuffer _pendingReasoningDelta = StringBuffer();
  int _reasoningUpdateSequence = 0;
  int get currentReasoningSectionIndex => _reasoningSections.length;

  StreamingReasoningAppend? takeReasoningAppend() {
    if (_pendingReasoningDelta.isEmpty) return null;
    final append = StreamingReasoningAppend(
      sequence: _reasoningUpdateSequence++,
      sectionIndex: currentReasoningSectionIndex,
      text: _pendingReasoningDelta.toString(),
    );
    _pendingReasoningDelta.clear();
    return append;
  }

  final List<String> _reasoningSections = [];
  bool _reasoningSectionActive = false;
  List<String> get reasoningSections => [
        ..._reasoningSections,
        if (_reasoningSectionActive) _reasoningSnapshot,
      ];

  void appendReasoning(String text) {
    if (!_reasoningSectionActive &&
        _reasoningSections.isNotEmpty &&
        _reasoningSections.last.isEmpty) {
      _reasoningSections.removeLast();
    }
    _reasoningBuffer.write(text);
    _pendingReasoningDelta.write(text);
    _reasoningBufferSnapshot = null;
    _reasoningSectionActive = true;
  }

  void endReasoningSection() {
    if (_reasoningSectionActive) _reasoningSections.add(_reasoningSnapshot);
    _reasoningSections.add('');
    _reasoningBuffer.clear();
    _reasoningBufferSnapshot = null;
    _reasoningSectionActive = false;
  }

  // Only the growing section needs to be materialized at each throttle tick.
  // Previously each read converted the full reply to a String, then sliced
  // every section from that new full copy.
  List<String> get textChunks {
    return List<String>.unmodifiable([
      ..._completedTextChunks,
      _currentTextChunk.toString(),
    ]);
  }

  final StringBuffer _pendingTextDelta = StringBuffer();
  bool _currentChunkHasMarkdownSyntax = false;
  int _textUpdateSequence = 0;
  bool _lineStartHasDigits = false;
  bool _atLineStart = true;
  bool _pendingOrderedListMarker = false;
  String _markdownSyntaxCarry = '';
  bool _markdownCarryStartsAtLineStart = true;
  int? _pendingInlineDelimiter;
  int _pendingInlineDelimiterLength = 0;
  int? _inlineDelimiterLeftCodeUnit;
  int? _lastScannedCodeUnit;
  int _consecutiveBackslashes = 0;
  final Map<int, int> _openInlineDelimiters = {};
  bool _openLinkLabel = false;
  bool _closedLinkLabel = false;
  bool _openLinkLabelAtLineStart = false;
  bool _closedLinkLabelAtLineStart = false;
  bool _linkScannerAtLineStart = true;
  int _linkScannerLineSpaces = 0;

  bool get currentChunkHasMarkdownSyntax => _currentChunkHasMarkdownSyntax;
  int get currentTextChunkIndex => _completedTextChunks.length;

  int get nextTextUpdateSequence => _textUpdateSequence++;

  String takeTextDelta() {
    final delta = _pendingTextDelta.toString();
    _pendingTextDelta.clear();
    return delta;
  }

  bool _serviceStartedTextChunk = false;
  String? _completedServiceTextChunk;
  String? _completedToolCallReasoning;

  String startTextChunkFromService() {
    _serviceStartedTextChunk = true;
    return _completedServiceTextChunk = startTextChunk();
  }

  String? takeCompletedToolCallRound() {
    final completed = _completedServiceTextChunk;
    _completedServiceTextChunk = null;
    return completed;
  }

  String? takeCompletedToolCallReasoning() {
    final completed = _completedToolCallReasoning;
    _completedToolCallReasoning = null;
    return completed;
  }

  void setCompletedToolCallReasoning(String reasoning) {
    _completedToolCallReasoning = reasoning;
  }

  bool takeServiceStartedTextChunk() {
    final started = _serviceStartedTextChunk;
    _serviceStartedTextChunk = false;
    return started;
  }

  void appendText(String text) {
    _currentTextChunk.write(text);
    _pendingTextDelta.write(text);
    final syntaxProbe = '$_markdownSyntaxCarry$text';
    final markdownProbe =
        _markdownCarryStartsAtLineStart ? syntaxProbe : '\u0000$syntaxProbe';
    if (!_currentChunkHasMarkdownSyntax &&
        (_containsMarkdownSyntax(markdownProbe) || _scanInlineMarkdown(text))) {
      _currentChunkHasMarkdownSyntax = true;
    }
    if (syntaxProbe.length <= 32) {
      _markdownSyntaxCarry = syntaxProbe;
    } else {
      final firstRetainedIndex = syntaxProbe.length - 32;
      _markdownCarryStartsAtLineStart =
          syntaxProbe.codeUnitAt(firstRetainedIndex - 1) == 10;
      _markdownSyntaxCarry = syntaxProbe.substring(firstRetainedIndex);
    }
    if (!_currentChunkHasMarkdownSyntax) _scanOrderedListMarkers(text);
  }

  // Shared because this detector runs on each incoming text event.
  static final RegExp _markdownBlockStart = RegExp(
    r'^\s{0,3}(?:`{3,}|~{3,}|#{1,6}\s|>|[-+*]\s)',
    multiLine: true,
  );
  static final RegExp _markdownIndentedLine = RegExp(
    r'^(?: {4,}|\t)\S',
    multiLine: true,
  );
  static final RegExp _markdownThematicBreak = RegExp(
    r'^\s{0,3}(?:\*(?:\s*\*){2,}|-(?:\s*-){2,}|_(?:\s*_){2,})\s*$',
    multiLine: true,
  );
  static final RegExp _markdownSetextHeading = RegExp(
    r'^\s{0,3}=+\s*$',
    multiLine: true,
  );
  static final RegExp _markdownTableDivider = RegExp(
    r'^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$',
    multiLine: true,
  );
  static final RegExp _markdownTableCellDivider = RegExp(
    r'\|\s*:?-{3,}:?\s*\|',
  );
  static final RegExp _markdownMath = RegExp(
    r'\\(?:\(|\[|begin\{(?:equation|align|gather)\})',
  );
  static final RegExp _markdownUrl = RegExp(
    r'(?<!\w)(https?://|www\.)\S+',
  );
  static final RegExp _markdownHtmlEntity = RegExp(
    r'&(?:[A-Za-z][A-Za-z0-9]+|#\d+);',
  );
  static final RegExp _markdownHtmlTag = RegExp(r'<[/?!]?[A-Za-z][^>]*>');
  static final RegExp _markdownGenericUrl = RegExp(r'\b\w+://\S+');

  bool _containsMarkdownSyntax(String text) =>
      _markdownBlockStart.hasMatch(text) ||
      _markdownIndentedLine.hasMatch(text) ||
      _markdownThematicBreak.hasMatch(text) ||
      _markdownSetextHeading.hasMatch(text) ||
      _markdownTableDivider.hasMatch(text) ||
      _markdownTableCellDivider.hasMatch(text) ||
      _markdownMath.hasMatch(text) ||
      _markdownUrl.hasMatch(text) ||
      _markdownHtmlEntity.hasMatch(text) ||
      _markdownHtmlTag.hasMatch(text) ||
      _markdownGenericUrl.hasMatch(text);

  bool _scanInlineMarkdown(String text) {
    for (final codeUnit in text.codeUnits) {
      final isDelimiter = codeUnit == 42 || // *
          codeUnit == 95 || // _
          codeUnit == 96 || // `
          codeUnit == 126 || // ~
          codeUnit == 36; // $
      if (isDelimiter && !_consecutiveBackslashes.isOdd) {
        if (_pendingInlineDelimiter == codeUnit) {
          _pendingInlineDelimiterLength++;
        } else {
          if (_finishInlineDelimiterRun(codeUnit)) return true;
          _pendingInlineDelimiter = codeUnit;
          _pendingInlineDelimiterLength = 1;
          _inlineDelimiterLeftCodeUnit = _lastScannedCodeUnit;
        }
      } else {
        if (_finishInlineDelimiterRun(codeUnit)) return true;
        if (_closedLinkLabel) {
          if (codeUnit == 40 || codeUnit == 91) return true; // ( or [
          if (codeUnit == 58 && _closedLinkLabelAtLineStart) return true; // :
          _closedLinkLabel = false;
          _closedLinkLabelAtLineStart = false;
        }
        if (codeUnit == 91) {
          _openLinkLabel = true;
          _openLinkLabelAtLineStart =
              _linkScannerAtLineStart && _linkScannerLineSpaces <= 3;
        } else if (codeUnit == 93 && _openLinkLabel) {
          _openLinkLabel = false;
          _closedLinkLabel = true;
          _closedLinkLabelAtLineStart = _openLinkLabelAtLineStart;
          _openLinkLabelAtLineStart = false;
        } else if (codeUnit == 10) {
          _openLinkLabel = false;
          _closedLinkLabel = false;
          _openLinkLabelAtLineStart = false;
          _closedLinkLabelAtLineStart = false;
        }
        if (codeUnit == 10) {
          _linkScannerAtLineStart = true;
          _linkScannerLineSpaces = 0;
        } else if (_linkScannerAtLineStart && codeUnit == 32) {
          _linkScannerLineSpaces++;
        } else {
          _linkScannerAtLineStart = false;
        }
      }
      _consecutiveBackslashes =
          codeUnit == 92 ? _consecutiveBackslashes + 1 : 0;
      _lastScannedCodeUnit = codeUnit;
    }
    return _hasClosingInlineDelimiter();
  }

  bool _finishInlineDelimiterRun(int nextCodeUnit) {
    if (_pendingInlineDelimiter == null) return false;
    if (_consumeClosingInlineDelimiter()) {
      return _consumedInlineDelimiterWasMarkdown;
    }

    final delimiter = _pendingInlineDelimiter!;
    final length = _pendingInlineDelimiterLength;
    final opensDelimiter = delimiter == 96 || delimiter == 36
        ? length >= 1
        : delimiter == 126
            ? length >= 2
            : length >= 1;
    final nextIsWhitespace = nextCodeUnit == 9 ||
        nextCodeUnit == 10 ||
        nextCodeUnit == 13 ||
        nextCodeUnit == 32;
    final leftIsWord = _isWordCodeUnit(_inlineDelimiterLeftCodeUnit);
    final underscoreInsideWord = delimiter == 95 && leftIsWord;
    if (opensDelimiter && !nextIsWhitespace && !underscoreInsideWord) {
      // Only the latest opener for each delimiter can be closed next. Once
      // a match is found, the section is routed through Markdown.
      _openInlineDelimiters[delimiter] = length;
    }
    _pendingInlineDelimiter = null;
    _pendingInlineDelimiterLength = 0;
    _inlineDelimiterLeftCodeUnit = null;
    return false;
  }

  bool _hasClosingInlineDelimiter() {
    return _consumeClosingInlineDelimiter() &&
        _consumedInlineDelimiterWasMarkdown;
  }

  bool _consumedInlineDelimiterWasMarkdown = false;

  bool _consumeClosingInlineDelimiter() {
    _consumedInlineDelimiterWasMarkdown = false;
    final delimiter = _pendingInlineDelimiter;
    if (delimiter == null) return false;
    final left = _inlineDelimiterLeftCodeUnit;
    final leftIsWhitespace =
        left == 9 || left == 10 || left == 13 || left == 32;
    if (leftIsWhitespace ||
        _openInlineDelimiters[delimiter] != _pendingInlineDelimiterLength) {
      return false;
    }
    _openInlineDelimiters.remove(delimiter);
    _consumedInlineDelimiterWasMarkdown = true;
    _pendingInlineDelimiter = null;
    _pendingInlineDelimiterLength = 0;
    _inlineDelimiterLeftCodeUnit = null;
    return true;
  }

  bool _isWordCodeUnit(int? codeUnit) =>
      codeUnit != null &&
      ((codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122));

  void _scanOrderedListMarkers(String text) {
    for (final codeUnit in text.codeUnits) {
      if (codeUnit == 10) {
        _atLineStart = true;
        _lineStartHasDigits = false;
        _pendingOrderedListMarker = false;
        continue;
      }
      if (_pendingOrderedListMarker) {
        if (codeUnit == 32 || codeUnit == 9) {
          _currentChunkHasMarkdownSyntax = true;
        }
        _pendingOrderedListMarker = false;
        _atLineStart = false;
        continue;
      }
      if (!_atLineStart) continue;
      if (codeUnit == 32 && !_lineStartHasDigits) continue;
      if (codeUnit >= 48 && codeUnit <= 57) {
        _lineStartHasDigits = true;
        continue;
      }
      if ((codeUnit == 46 || codeUnit == 41) && _lineStartHasDigits) {
        _pendingOrderedListMarker = true;
        continue;
      }
      _atLineStart = false;
    }
  }

  String startTextChunk() {
    final completed = _currentTextChunk.toString();
    _completedTextChunks.add(completed);
    _currentTextChunk = StringBuffer();
    _pendingTextDelta.clear();
    _currentChunkHasMarkdownSyntax = false;
    _lineStartHasDigits = false;
    _atLineStart = true;
    _pendingOrderedListMarker = false;
    _markdownSyntaxCarry = '';
    _markdownCarryStartsAtLineStart = true;
    _pendingInlineDelimiter = null;
    _pendingInlineDelimiterLength = 0;
    _inlineDelimiterLeftCodeUnit = null;
    _lastScannedCodeUnit = null;
    _consecutiveBackslashes = 0;
    _openInlineDelimiters.clear();
    _openLinkLabel = false;
    _closedLinkLabel = false;
    _openLinkLabelAtLineStart = false;
    _closedLinkLabelAtLineStart = false;
    _linkScannerAtLineStart = true;
    _linkScannerLineSpaces = 0;
    return completed;
  }

  bool get currentTextChunkIsNotEmpty => _currentTextChunk.length > 0;

  /// Per-round text chunks that mirror reasoning sections: each time a new
  /// tool call round begins, a new chunk is started so that post-stream
  /// segment building can interleave assistant speech between reasoning and
  /// tool call blocks in the correct Agent chain order.
  List<ToolCallData> toolCalls = [];
  List<ChatMessage> history = [];
  List<ChatMessage>? historyOnSuccess;
  bool hasReceivedFirstToken = false;
  bool hasSyntheticErrorReply = false;
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
