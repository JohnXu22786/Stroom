part of 'chat_page.dart';

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
          ? _formatErrorValue(responseBodyData)
          : _formatErrorValue(responseError);
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
                '发送失败',
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
                  '查看详细错误',
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
    for (final seg in mergeConsecutiveTextSegments(segments)) {
      switch (seg) {
        case TextSegment s:
          widgets.add(Padding(
            padding: const EdgeInsets.only(
              bottom: 4,
            ),
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
                    ),
                    markdownGenerator: markdownGenerator,
                  ),
          ));
          // Count occurrences the highlight generator can actually paint
          // (matches inside code/math render as dedicated widgets and never
          // become highlightable text), so the offset stays aligned with the
          // per-segment ordinal of the next text segment.
          occurrenceOffset += countOccurrences(
            stripSearchIrrelevantMarkdown(s.text),
            lowerQuery,
          );
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
    final markdownConfig = buildMessageMarkdownConfig(
      isDark: isDark,
      conversationIsStreaming: isStreaming,
      streamingMsgId: _streamingMsgId,
      messageId: message.id,
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
            padding: const EdgeInsets.only(
              left: 4,
              right: 4,
              bottom: 4,
            ),
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                reverse: isSentByMe,
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
