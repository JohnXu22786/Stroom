part of 'chat_page.dart';

class _CachedStreamingMarkdown {
  final String text;
  final bool isDark;
  final bool isStreaming;
  final Widget widget;

  const _CachedStreamingMarkdown({
    required this.text,
    required this.isDark,
    required this.isStreaming,
    required this.widget,
  });
}

class _StreamingSearchOccurrenceCount {
  String _query = '';
  int _textLength = 0;
  String _tail = '';
  int _count = 0;
  int _nextSearchIndex = 0;
  int _lowerTextLength = 0;
  int _liveRawTextLength = 0;
  bool _canAppendIncrementally = false;
  bool _hasContextualLowercase = false;
  String? _unfinishedFenceChar;
  int _unfinishedFenceLength = 0;
  int _fenceLineStage = 0;
  int _fenceLineLeadingSpaces = 0;
  int _fenceLinePostQuoteSpaces = 0;
  int _fenceLineRunLength = 0;
  bool _fenceLineQuoteSpaceConsumed = false;
  bool _fencePreviousRawWasCr = false;
  bool _textEndsWithCr = false;

  int countFor(String text, String lowerQuery) {
    if (_query != lowerQuery) _reset(lowerQuery);
    // Live text sections only append. Comparing lengths avoids rescanning the
    // growing prefix just to confirm that the new snapshot extends it.
    if (text.length == _textLength) return _count;

    if (_unfinishedFenceChar != null &&
        text.length > _textLength &&
        lowerQuery.isNotEmpty &&
        !_hasContextualLowercase) {
      if (_scanUnfinishedFence(text.substring(_textLength))) {
        _textLength = text.length;
        return _count;
      }
      // A closing fence changes the searchable text. Recount once at that
      // boundary; subsequent appends use the normal path.
      return _recount(text, lowerQuery);
    }

    if (_canAppendIncrementally &&
        text.length > _textLength &&
        lowerQuery.isNotEmpty) {
      var appended = text.substring(_textLength);
      if (_textEndsWithCr && appended.startsWith('\n')) {
        appended = appended.substring(1);
      }
      if (appended.contains('`') ||
          appended.contains('~') ||
          appended.contains(r'$') ||
          appended.contains('\u03A3')) {
        return _recount(text, lowerQuery);
      }
      final normalizedAppended =
          appended.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      _appendLowerText(normalizedAppended.toLowerCase(), lowerQuery);
      _textLength = text.length;
      _textEndsWithCr = text.endsWith('\r');
      return _count;
    }

    return _recount(text, lowerQuery);
  }

  int countLiveFragmentsFor(List<String> fragments, String lowerQuery) {
    if (_query != lowerQuery) _reset(lowerQuery);
    var liveTextLength = 0;
    for (final fragment in fragments) {
      liveTextLength += fragment.length;
    }
    if (liveTextLength < _liveRawTextLength) _reset(lowerQuery);
    if (_hasContextualLowercase) {
      final text = fragments.join();
      final count = _recount(text, lowerQuery);
      _hasContextualLowercase = true;
      _liveRawTextLength = liveTextLength;
      return count;
    }

    final appendedLength = liveTextLength - _liveRawTextLength;
    if (appendedLength > 0 && lowerQuery.isNotEmpty) {
      final appendedParts = <String>[];
      var remaining = appendedLength;
      for (var i = fragments.length - 1; i >= 0 && remaining > 0; i--) {
        final fragment = fragments[i];
        final take = fragment.length < remaining ? fragment.length : remaining;
        appendedParts.add(fragment.substring(fragment.length - take));
        remaining -= take;
      }
      final appended = appendedParts.reversed.join();
      if (appended.contains('\u03A3')) {
        final text = fragments.join();
        final count = _recount(text, lowerQuery);
        _hasContextualLowercase = true;
        _liveRawTextLength = liveTextLength;
        return count;
      }
      _appendLowerText(appended.toLowerCase(), lowerQuery);
    }
    _liveRawTextLength = liveTextLength;
    return _count;
  }

  int _recount(String text, String lowerQuery) {
    _hasContextualLowercase = text.contains('\u03A3');
    final searchableText = stripSearchIrrelevantMarkdown(text);
    final lowerSearchableText = searchableText.toLowerCase();
    _count = countOccurrences(searchableText, lowerQuery);
    _nextSearchIndex = 0;
    _lowerTextLength = lowerSearchableText.length;
    _tail = '';
    if (lowerQuery.isNotEmpty) {
      var start = 0;
      while (true) {
        final index = lowerSearchableText.indexOf(lowerQuery, start);
        if (index == -1) break;
        _nextSearchIndex = index + lowerQuery.length;
        start = _nextSearchIndex;
      }
    }
    _textLength = text.length;
    _textEndsWithCr = text.endsWith('\r');
    _setUnfinishedFenceState(text);
    _canAppendIncrementally = lowerQuery.isNotEmpty &&
        !_hasContextualLowercase &&
        _unfinishedFenceChar == null;
    if (_canAppendIncrementally && lowerQuery.length > 1) {
      final tailLength = lowerQuery.length - 1;
      _tail = lowerSearchableText.length <= tailLength
          ? lowerSearchableText
          : lowerSearchableText.substring(
              lowerSearchableText.length - tailLength,
            );
    }
    return _count;
  }

  void _appendLowerText(String appended, String lowerQuery) {
    final searchText = _tail + appended;
    final tailStart = _lowerTextLength - _tail.length;
    var start = _nextSearchIndex > tailStart ? _nextSearchIndex - tailStart : 0;
    while (true) {
      final index = searchText.indexOf(lowerQuery, start);
      if (index == -1) break;
      if (index + lowerQuery.length > _tail.length) {
        _count++;
        _nextSearchIndex = tailStart + index + lowerQuery.length;
      }
      start = index + lowerQuery.length;
    }
    _lowerTextLength += appended.length;
    final tailLength = lowerQuery.length - 1;
    _tail = tailLength == 0 || searchText.length <= tailLength
        ? (tailLength == 0 ? '' : searchText)
        : searchText.substring(searchText.length - tailLength);
  }

  void _reset(String lowerQuery) {
    _query = lowerQuery;
    _textLength = 0;
    _tail = '';
    _count = 0;
    _nextSearchIndex = 0;
    _lowerTextLength = 0;
    _liveRawTextLength = 0;
    _canAppendIncrementally = false;
    _hasContextualLowercase = false;
    _unfinishedFenceChar = null;
    _unfinishedFenceLength = 0;
    _resetFenceLineState();
    _fencePreviousRawWasCr = false;
    _textEndsWithCr = false;
  }

  void _setUnfinishedFenceState(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var inFence = false;
    String? fenceChar;
    var fenceLength = 0;
    final lines = normalized.split('\n');
    var trailingLineIsFenceContent = false;
    for (final line in lines) {
      trailingLineIsFenceContent = inFence;
      final withoutQuote = _stripFenceBlockquote(line.trimRight());
      if (inFence) {
        if (_isFenceClosingLine(withoutQuote, fenceChar!, fenceLength)) {
          inFence = false;
          fenceChar = null;
          fenceLength = 0;
        }
      } else {
        final opening = _findFenceOpening(withoutQuote);
        if (opening != null) {
          inFence = true;
          fenceChar = opening.$1;
          fenceLength = opening.$2;
        }
      }
    }
    _unfinishedFenceChar = inFence ? fenceChar : null;
    _unfinishedFenceLength = inFence ? fenceLength : 0;
    _resetFenceLineState();
    if (inFence && trailingLineIsFenceContent) {
      final trailingLine = normalized.substring(
        normalized.lastIndexOf('\n') + 1,
      );
      for (final char in trailingLine.split('')) {
        _trackFenceLineChar(char);
      }
    }
    _fencePreviousRawWasCr = text.endsWith('\r');
  }

  /// Scans only newly received characters while an unterminated fence is
  /// active. The markdown stripper emits the same single trailing blank line
  /// regardless of how much more fence content arrives, so its searchable
  /// output and count remain unchanged until a closing fence appears.
  bool _scanUnfinishedFence(String appended) {
    final fenceLength = _unfinishedFenceLength;
    for (final char in appended.split('')) {
      if (_fencePreviousRawWasCr && char == '\n') {
        _fencePreviousRawWasCr = false;
        continue;
      }
      _fencePreviousRawWasCr = false;
      if (char == '\r') {
        if (_isFenceLineClosingCandidate(fenceLength)) {
          _unfinishedFenceChar = null;
          _unfinishedFenceLength = 0;
          _resetFenceLineState();
          return false;
        }
        _resetFenceLineState();
        _fencePreviousRawWasCr = true;
      } else if (char == '\n') {
        if (_isFenceLineClosingCandidate(fenceLength)) {
          _unfinishedFenceChar = null;
          _unfinishedFenceLength = 0;
          _resetFenceLineState();
          return false;
        }
        _resetFenceLineState();
      } else {
        _trackFenceLineChar(char);
      }
    }
    if (_isFenceLineClosingCandidate(fenceLength)) {
      _unfinishedFenceChar = null;
      _unfinishedFenceLength = 0;
      _resetFenceLineState();
      return false;
    }
    return true;
  }

  void _resetFenceLineState() {
    _fenceLineStage = 0;
    _fenceLineLeadingSpaces = 0;
    _fenceLinePostQuoteSpaces = 0;
    _fenceLineRunLength = 0;
    _fenceLineQuoteSpaceConsumed = false;
  }

  void _trackFenceLineChar(String char) {
    final fenceChar = _unfinishedFenceChar!;
    if (_fenceLineStage == 4) return;
    if (_fenceLineStage == 0) {
      if (char == ' ' && _fenceLineLeadingSpaces < 3) {
        _fenceLineLeadingSpaces++;
      } else if (char == '>') {
        _fenceLineStage = 1;
      } else if (char == fenceChar) {
        _fenceLineStage = 2;
        _fenceLineRunLength = 1;
      } else {
        _fenceLineStage = 4;
      }
      return;
    }
    if (_fenceLineStage == 1) {
      if (char == ' ' && !_fenceLineQuoteSpaceConsumed) {
        _fenceLineQuoteSpaceConsumed = true;
      } else if (char == ' ' && _fenceLinePostQuoteSpaces < 3) {
        _fenceLinePostQuoteSpaces++;
      } else if (char == fenceChar) {
        _fenceLineStage = 2;
        _fenceLineRunLength = 1;
      } else {
        _fenceLineStage = 4;
      }
      return;
    }
    if (_fenceLineStage == 2) {
      if (char == fenceChar) {
        _fenceLineRunLength++;
      } else if (_fenceLineRunLength >= _unfinishedFenceLength &&
          char.trim().isEmpty) {
        _fenceLineStage = 3;
      } else {
        _fenceLineStage = 4;
      }
      return;
    }
    if (char.trim().isNotEmpty) _fenceLineStage = 4;
  }

  bool _isFenceLineClosingCandidate(int fenceLength) =>
      (_fenceLineStage == 2 || _fenceLineStage == 3) &&
      _fenceLineRunLength >= fenceLength;

  static String _stripFenceBlockquote(String line) {
    var i = 0;
    while (i < line.length && i < 3 && line[i] == ' ') {
      i++;
    }
    if (i >= line.length || line[i] != '>') return line;
    i++;
    if (i < line.length && line[i] == ' ') i++;
    return line.substring(i);
  }

  static (String, int)? _findFenceOpening(String line) {
    var i = 0;
    while (i < line.length && i < 3 && line[i] == ' ') {
      i++;
    }
    if (i >= line.length || (line[i] != '`' && line[i] != '~')) return null;
    final char = line[i];
    var end = i;
    while (end < line.length && line[end] == char) {
      end++;
    }
    if (end - i < 3 || (char == '`' && line.substring(end).contains('`'))) {
      return null;
    }
    return (char, end - i);
  }

  static bool _isFenceClosingLine(String line, String char, int length) {
    var i = 0;
    while (i < line.length && i < 3 && line[i] == ' ') {
      i++;
    }
    final trimmed = line.substring(i).trimRight();
    if (trimmed.isEmpty || trimmed[0] != char) return false;
    var run = 0;
    while (run < trimmed.length && trimmed[run] == char) {
      run++;
    }
    return run >= length && trimmed.substring(run).trim().isEmpty;
  }
}

extension _ChatPageBubblesExt on _ChatPageState {
  /// Error bubble for failed AI messages with status code, response body
  /// and original error text.
  Widget _buildErrorMessageBubble({
    required BuildContext context,
    required TextMessage message,
    required ChatMessage? chatMsg,
    required bool isDark,
  }) {
    // Extract error details from rawResponse
    final resp = chatMsg?.rawResponse ?? {};
    final statusCode = resp['statusCode'];
    final responseBodyData = resp['data'];
    final responseError = resp['error'];
    final originalErrorText = message.text.replaceAll('错误: ', '');

    // Build the list of error info widgets
    final errorWidgets = <Widget>[];

    // Status Code (new — shown first)
    if (statusCode != null) {
      errorWidgets.add(
        SelectableText(
          'Status Code: $statusCode',
          style: TextStyle(
            color: isDark ? Colors.red[200] : Colors.red[800],
            fontSize: 13,
          ),
        ),
      );
    }

    // Response Body error (new — shown second)
    if (responseBodyData != null || responseError != null) {
      final bodyText = responseBodyData != null
          ? formatErrorValueForDisplay(responseBodyData)
          : formatErrorValueForDisplay(responseError);
      errorWidgets.add(
        SelectableText(
          bodyText,
          style: TextStyle(
            color: isDark ? Colors.red[200] : Colors.red[800],
            fontSize: 13,
          ),
        ),
      );
    }

    // Blank line before original error
    if (errorWidgets.isNotEmpty && originalErrorText.isNotEmpty) {
      errorWidgets.add(
        const SizedBox(height: 8),
      );
    }

    // Original error (DIO Exception etc.)
    if (originalErrorText.isNotEmpty) {
      errorWidgets.add(
        SelectableText(
          originalErrorText,
          style: TextStyle(
            color: isDark ? Colors.red[200] : Colors.red[800],
            fontSize: 13,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (isDark ? Colors.red[900] : Colors.red[50])!.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: isDark ? Colors.red[300] : Colors.red[700],
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.chatSendFailed,
                style: TextStyle(
                  color: isDark ? Colors.red[300] : Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...errorWidgets,
          if (chatMsg != null &&
              (chatMsg.rawRequest != null || chatMsg.rawResponse != null))
            Padding(
              padding: const EdgeInsets.only(
                top: 8,
              ),
              child: TextButton.icon(
                icon: Icon(
                  Icons.preview,
                  size: 14,
                  color: isDark ? Colors.red[300] : Colors.red[700],
                ),
                label: Text(
                  AppLocalizations.of(context)!.chatViewErrorDetails,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.red[300] : Colors.red[700],
                  ),
                ),
                onPressed: () => _showErrorDetailDialog(
                  context,
                  message.id,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Renders a list of [MessageSegment]s into widgets: text segments as
  /// Markdown, tool calls as [ToolCallCard]s, and reasoning sections as
  /// inline [ReasoningSection] buttons.
  ///
  /// Shared by the normal assistant bubble (text messages) and the
  /// textStream bubble so both render tool calls and reasoning identically
  /// during streaming.
  List<Widget> _buildSegmentWidgets({
    required String messageId,
    required List<MessageSegment> segments,
    required bool isDark,
    required bool isStreaming,
    required bool hasSearchMatch,
  }) {
    // Merge consecutive TextSegments to avoid visual breaks
    // between arbitrary streaming chunk boundaries (e.g.
    // throttle intervals). Each text block renders in a
    // single MarkdownWidget for continuity.
    final widgets = <Widget>[];
    // When searching, each text segment renders through a highlight-aware
    // markdown generator. Matches are re-found inside every text node, and
    // [occurrenceOffset] (how many occurrences appeared in earlier text
    // segments of this message) keeps the "current" highlight aligned with
    // the global navigation cursor across segments.
    final lowerQuery = hasSearchMatch ? _searchQuery.toLowerCase() : '';
    final messageFirstMatchIndex = hasSearchMatch
        ? _searchMatches.indexWhere((m) => m.messageId == messageId)
        : 0;
    var occurrenceOffset = 0;
    final streamingConvId = isStreaming && messageId == _streamingMsgId
        ? ref.read(activeConversationIdProvider)
        : null;
    final liveTextChunkCount = streamingConvId == null
        ? 0
        : ref.read(streamingTextSectionsProvider(streamingConvId)).length;
    final mergedSegments = mergeConsecutiveTextSegments(segments);
    final lastTextSegmentIndex =
        mergedSegments.lastIndexWhere((segment) => segment is TextSegment);
    for (var segmentIndex = 0;
        segmentIndex < mergedSegments.length;
        segmentIndex++) {
      final seg = mergedSegments[segmentIndex];
      switch (seg) {
        case TextSegment s:
          if (s.liveTextFragments != null) {
            if (hasSearchMatch &&
                !(isStreaming &&
                    messageId == _streamingMsgId &&
                    segmentIndex == lastTextSegmentIndex)) {
              final cacheKey = s.chunkIndex == null
                  ? '$messageId:live-segment:$segmentIndex'
                  : '$messageId:live-chunk:${s.chunkIndex}';
              occurrenceOffset += _streamingSearchOccurrenceCache
                  .putIfAbsent(cacheKey, _StreamingSearchOccurrenceCount.new)
                  .countLiveFragmentsFor(s.liveTextFragments!, lowerQuery);
            }
            widgets.add(Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText.rich(
                TextSpan(
                  children: s.liveTextFragments!
                      .map((fragment) => TextSpan(text: fragment))
                      .toList(growable: false),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ));
            continue;
          }
          final canReuseSealedText = !hasSearchMatch &&
              streamingConvId != null &&
              s.chunkIndex != null &&
              s.chunkIndex! < liveTextChunkCount - 1;
          final cacheKey =
              canReuseSealedText ? '$messageId:${s.chunkIndex}' : null;
          final cached =
              cacheKey == null ? null : _streamingMarkdownCache[cacheKey];
          final streamingFenceInfoCache = isStreaming &&
                  messageId == _streamingMsgId &&
                  s.chunkIndex != null
              ? _streamingFenceInfoCaches.putIfAbsent(
                  '$messageId:${s.chunkIndex}',
                  StreamingFenceInfoCache.new,
                )
              : null;
          if (cached != null &&
              identical(cached.text, s.text) &&
              cached.isDark == isDark &&
              cached.isStreaming == isStreaming) {
            widgets.add(cached.widget);
          } else {
            final textWidget = Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: hasSearchMatch
                  ? MarkdownWidget(
                      data: s.text,
                      selectable: true,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      config: buildMessageMarkdownConfig(
                        isDark: isDark,
                        conversationIsStreaming: isStreaming,
                        streamingMsgId: _streamingMsgId,
                        messageId: messageId,
                        streamingText: s.text,
                        streamingFenceInfoCache: streamingFenceInfoCache,
                      ),
                      markdownGenerator: buildSearchMarkdownGenerator(
                        query: _searchQuery,
                        messageFirstMatchIndex: messageFirstMatchIndex,
                        occurrenceOffset: occurrenceOffset,
                        currentMatchIndex: _currentMatchIndex,
                      ),
                    )
                  : MarkdownWidget(
                      data: s.text,
                      selectable: true,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Per-segment streaming config: each segment
                      // is parsed by its OWN MarkdownWidget, so the
                      // fence-completion check must run against that
                      // segment's text.
                      config: buildMessageMarkdownConfig(
                        isDark: isDark,
                        conversationIsStreaming: isStreaming,
                        streamingMsgId: _streamingMsgId,
                        messageId: messageId,
                        streamingText: s.text,
                        streamingFenceInfoCache: streamingFenceInfoCache,
                      ),
                      markdownGenerator: markdownGenerator,
                    ),
            );
            widgets.add(textWidget);
            if (cacheKey != null) {
              _streamingMarkdownCache[cacheKey] = _CachedStreamingMarkdown(
                text: s.text,
                isDark: isDark,
                isStreaming: isStreaming,
                widget: textWidget,
              );
            }
          }
          // Count occurrences the highlight generator can actually paint
          // (matches inside code/math render as dedicated widgets and never
          // become highlightable text), so the offset stays aligned with the
          // per-segment ordinal of the next text segment.
          if (hasSearchMatch) {
            final isActiveStreamingSearch =
                isStreaming && messageId == _streamingMsgId;
            if (isActiveStreamingSearch &&
                segmentIndex == lastTextSegmentIndex) {
              // The trailing text block cannot shift a later segment's
              // highlight ordinal. Count it once after another text block
              // arrives and seals it instead of recounting it while growing.
            } else if (isActiveStreamingSearch) {
              final cacheKey = s.chunkIndex == null
                  ? '$messageId:segment:$segmentIndex'
                  : '$messageId:chunk:${s.chunkIndex}';
              occurrenceOffset += _streamingSearchOccurrenceCache
                  .putIfAbsent(cacheKey, _StreamingSearchOccurrenceCount.new)
                  .countFor(s.text, lowerQuery);
            } else {
              occurrenceOffset += countOccurrences(
                stripSearchIrrelevantMarkdown(s.text),
                lowerQuery,
              );
            }
          }
        case ErrorSegment s:
          widgets.add(Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.red[900] : Colors.red[50])!
                  .withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              s.message,
              style: TextStyle(
                color: isDark ? Colors.red[200] : Colors.red[800],
                fontSize: 13,
              ),
            ),
          ));
        case ToolCallSegment s:
          widgets.add(ToolCallCard(data: s.data));
        case ReasoningSegment s:
          // Resolve the section text by RAW index and skip empty
          // placeholder sections entirely (no widget, no padding) —
          // otherwise finalized messages with interior '' sections
          // would show phantom 4px gaps the live view doesn't have.
          final text =
              (s.sectionIndex < (_reasoningContents[messageId]?.length ?? 0))
                  ? _reasoningContents[messageId]![s.sectionIndex]
                  : '';
          if (text.isEmpty) continue;
          widgets.add(Padding(
            padding: const EdgeInsets.only(
              bottom: 4,
            ),
            child: ReasoningSection(
              sections: ReasoningSectionData(
                texts: [text],
                streaming: s.isStreaming,
                sectionIndices: [s.sectionIndex],
              ),
              messageId: messageId,
            ),
          ));
      }
    }
    return widgets;
  }

  /// Bubble for a normal AI message with reasoning sections and segments.
  Widget _buildAiMessageBubble({
    required TextMessage message,
    required bool isDark,
    required bool isStreaming,
    required String? activeId,
  }) {
    final reasoningSections = _reasoningContents[message.id];
    final segments = _chatSegments[message.id];
    final isWaitingForFirstToken = message.id == _streamingMsgId &&
        message.text.isEmpty &&
        isStreaming &&
        activeId != null &&
        !ref.read(
          streamingHasFirstTokenProvider(activeId),
        );
    final hasSearchMatch = _isSearching &&
        _searchQuery.isNotEmpty &&
        _searchMatches.any(
          (m) => m.messageId == message.id,
        );

    // Per-message markdown config: only the message that is currently
    // being generated uses the streaming config (mermaid blocks show the
    // "正在生成..." placeholder). All other messages — including old
    // messages while a NEW message streams — keep their regular config,
    // so already-rendered mermaid diagrams are neither hidden behind the
    // loading placeholder nor re-rendered.
    //
    // While streaming, each text segment gets its OWN config carrying the
    // segment's raw text as streamingText, so mermaid blocks whose fence
    // has already closed render immediately; only the still-open trailing
    // block keeps the loading placeholder (see isStreamingMermaidTail).
    // The fallback MarkdownWidgets below (messages without segments) pass
    // the message text as streamingText for the same fence-completion
    // check, so a closed block in a streaming message is never treated as
    // still being generated.
    final streamingFenceInfoCache = isStreaming && _streamingMsgId == message.id
        ? _streamingFenceInfoCaches.putIfAbsent(
            '${message.id}:fallback',
            StreamingFenceInfoCache.new,
          )
        : null;
    final markdownConfig = buildMessageMarkdownConfig(
      isDark: isDark,
      conversationIsStreaming: isStreaming,
      streamingMsgId: _streamingMsgId,
      messageId: message.id,
      streamingText: message.text,
      streamingFenceInfoCache: streamingFenceInfoCache,
    );

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // During streaming, when first token hasn't arrived
          // and we don't have reasoning content, show JumpingDots.
          // Reasoning content already shows "推理中" button.
          if (isWaitingForFirstToken &&
              (reasoningSections == null || reasoningSections.isEmpty))
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 8,
              ),
              child: JumpingDotsProgressIndicator(
                color: Colors.grey,
                fontSize: 14,
              ),
            )
          else if (segments != null && segments.isNotEmpty)
            ..._buildSegmentWidgets(
              messageId: message.id,
              segments: segments,
              isDark: isDark,
              isStreaming: isStreaming,
              hasSearchMatch: hasSearchMatch,
            )
          // Historical messages: segments may be null (loaded from
          // persistence), but reasoning sections can still exist
          // via _reasoningContents (restored from ChatMessage.
          // reasoningContent). Show the reasoning buttons as a
          // group at the top, same as the pre-inline layout.
          else if (reasoningSections != null && reasoningSections.isNotEmpty)
            ReasoningSection(
              sections: ReasoningSectionData(
                texts: reasoningSections,
                streaming: false,
              ),
              messageId: message.id,
            )
          else if (hasSearchMatch)
            MarkdownWidget(
              data: message.text,
              selectable: true,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              config: markdownConfig,
              markdownGenerator: buildSearchMarkdownGenerator(
                query: _searchQuery,
                messageFirstMatchIndex: _searchMatches.indexWhere(
                  (m) => m.messageId == message.id,
                ),
                occurrenceOffset: 0,
                currentMatchIndex: _currentMatchIndex,
              ),
            )
          else
            MarkdownWidget(
              data: message.text,
              selectable: true,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              config: markdownConfig,
              markdownGenerator: markdownGenerator,
            ),
        ],
      ),
    );
  }

  /// Bubble for a user message with optional attachment previews.
  Widget _buildUserMessageBubble({
    required TextMessage message,
    required int index,
    required bool isSentByMe,
  }) {
    final chatMsg = _history.where((m) => m.id == message.id).firstOrNull;
    final hasAttachments = chatMsg?.attachments.isNotEmpty == true;
    // Only render the text bubble when the message actually has text:
    // attachment-only messages (files/images without any text) would
    // otherwise show an empty blue bubble. Whitespace-only content is
    // treated as no text (the composer already trims before sending).
    final hasText = message.text.trim().isNotEmpty;
    final hasSearchMatch = _isSearching &&
        _searchQuery.isNotEmpty &&
        _searchMatches.any(
          (m) => m.messageId == message.id,
        );
    return Column(
      crossAxisAlignment: hasAttachments && isSentByMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSearchMatch && hasText)
          _buildHighlightedText(
            message.text,
            message.id,
          )
        else if (hasText)
          SimpleTextMessage(
            message: message,
            index: index,
            showTime: false,
          ),
        if (hasAttachments)
          Padding(
            key: const ValueKey('user-message-attachment-area'),
            padding: EdgeInsets.only(
              left: 4,
              right: 4,
              top: hasText ? 8 : 0,
              bottom: 4,
            ),
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                // 不用 reverse（原实现为让横条贴住气泡右缘而 reverse，
                // 但会把可见顺序镜像成待发/API 发送顺序的反向——模型按
                // 请求顺序读文件，记录里却倒着显示）。shrinkWrap 让横条
                // 收缩到内容宽度，靠外层 Column 的 end 对齐贴住右缘；
                // 顺序即附件列表顺序（第一个文件最左，与待发条一致）。
                // 溢出时视口默认停靠 offset 0 → 第一个文件可见，且懒
                // 列表回收重建后同样回到首项（无状态可丢）。
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: chatMsg!.attachments.length,
                itemBuilder: (ctx, i) {
                  final att = chatMsg.attachments[i];
                  return _buildMessageAttachmentPreview(
                    att,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
