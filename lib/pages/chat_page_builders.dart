part of 'chat_page.dart';

extension _ChatPageBuildersExt on _ChatPageState {
  /// Builds the [Chat] widget with its message builders.
  Widget _buildChatWidget({
    required bool isDark,
    required bool isStreaming,
    required String streamingFullReply,
    required String? streamingMsgId,
    required String? activeId,
    required InMemoryChatController controller,
  }) {
    return NotificationListener<ScrollMetricsNotification>(
      // The metrics notification fires for every scroll frame AND when the
      // content grows (streaming message, mermaid auto-fit, sliver extent
      // estimate corrections) AND when the viewport resizes (keyboard,
      // composer, window). _followContentGrowth ignores the scrolling
      // cases and only re-pins when auto-scroll is engaged; the scroll-to-
      // bottom button state is recomputed from the CURRENT metrics on
      // every notification — a viewport-only change moves the at-bottom
      // relationship without firing a scroll event, and only this
      // notification carries it (an idle ScrollPosition does not notify
      // its controller listeners).
      onNotification: (_) {
        // Re-pin first: the follow's post-frame jump must run BEFORE the
        // button recompute, otherwise a content growth would read as "not
        // at the bottom" and flash the button on for a frame until the
        // follow's jump lands and _onChatScroll hides it again. Both
        // callbacks are registered in this order and run in that order
        // post-frame.
        _followContentGrowth();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateScrollToBottomState();
        });
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onChatScrollNotification,
        child: Chat(
          key: ValueKey(controller.hashCode),
          currentUserId: _currentUser.id,
          resolveUser: (id) async {
            if (id == _currentUser.id) return _currentUser;
            if (id == _aiUser.id) return _aiUser;
            return null;
          },
          chatController: controller,
          onMessageSend: (text) => _onMessageSend(text, []),
          theme: isDark ? ChatTheme.dark() : ChatTheme.light(),
          timeFormat: DateFormat('yyyy-MM-dd HH:mm'),
          builders: Builders(
            chatAnimatedListBuilder: (context, itemBuilder) =>
                _buildChatAnimatedList(context, itemBuilder),
            // Suppress the built-in scroll-to-bottom
            // button — we provide our own overlay below.
            scrollToBottomBuilder: (context, animation, onPressed) =>
                const SizedBox.shrink(),
            // Custom load-more indicator driven by the page's own load
            // state: the spinner is mounted ONLY while a pagination load
            // is actually running. The library's default indicator is kept
            // mounted while hidden and its visibility is driven by the
            // library's internal notifier rather than the real load state,
            // so a stuck notifier leaves a spinner spinning after the load
            // finished.
            loadMoreBuilder: (context) => _buildLoadMoreIndicator(),
            // Empty composer builder — the actual composer is
            // rendered below the Chat widget so it participates
            // in the Column layout flow instead of overlaying
            // the message list via the internal Stack. This
            // ensures the scroll area auto-adjusts as the
            // composer height changes (e.g. multi-line input).
            composerBuilder: (_) => const SizedBox.shrink(),
            textMessageBuilder: (context, message, index,
                    {required bool isSentByMe,
                    MessageGroupStatus? groupStatus}) =>
                _buildTextMessage(
              context,
              message,
              index,
              isSentByMe: isSentByMe,
              groupStatus: groupStatus,
              isDark: isDark,
              isStreaming: isStreaming,
              activeId: activeId,
            ),
            textStreamMessageBuilder: (context, message, index,
                    {required bool isSentByMe,
                    MessageGroupStatus? groupStatus}) =>
                _buildTextStreamMessage(
              context,
              message,
              index,
              isSentByMe: isSentByMe,
              groupStatus: groupStatus,
              isStreaming: isStreaming,
              streamingFullReply: streamingFullReply,
              streamingMsgId: streamingMsgId,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }

  /// Chat animated list with lazy pagination and auto-scroll control.
  ///
  /// On Android (Material 3) the default overscroll indicator is a
  /// shader-based stretch that does NOT affect platform views (the mermaid
  /// WebView stays rigid while the rest of the content stretches). The
  /// default indicator is replaced with a matrix-based stretch
  /// ([TransformStretchOverscroll]) so the mermaid area stretches together
  /// with the rest of the message content.
  Widget _buildChatAnimatedList(
    BuildContext context,
    ChatItem itemBuilder,
  ) {
    final list = ChatAnimatedList(
      itemBuilder: itemBuilder,
      onEndReached: _loadMoreMessages,
      scrollController: _chatScrollController,
      // 顶部"没有更多内容了"提示（用户滚到顶部且无更早历史消息时显示）。
      topSliver: _buildNoMoreMessagesSliver(),
      // Scrolling the list must NOT dismiss the soft keyboard — the
      // keyboard stays up while the user reads/scrolls; it is dismissed
      // via the keyboard's own close key or the page's dismiss button.
      // (The library defaults to onDrag, which hides the keyboard on any
      // drag — exactly what the user reported as unwanted.)
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      // The library's own debounced keyboard scroll (100ms debounce +
      // 250ms animation) runs alongside this page's keyboard-appear
      // scroll. Its animation is smooth (NOT Duration.zero — an instant
      // jump there cancelled this page's scroll mid-flight, which looked
      // like the animation disappearing); when it takes over mid-scroll
      // it continues toward the same bottom and the two read as one
      // continuous slide. The follow-up closes any small gap it leaves.
      // While the initial positioning pass runs (entry / conversation
      // switch), suppress the built-in jump-to-bottom — the page positions
      // the list at the last user message itself. Same-conversation reloads
      // keep the built-in jump so their behavior is unchanged.
      initialScrollToEndMode: _pendingInitialScrollAdjustment
          ? InitialScrollToEndMode.none
          : InitialScrollToEndMode.jump,
      // Initially disable auto-scroll. User must
      // tap the scroll-to-bottom button to enable.
      shouldScrollToEndWhenAtBottom: _autoScrollEnabled,
      shouldScrollToEndWhenSendingMessage: _autoScrollEnabled,
    );
    final useMatrixStretch = defaultTargetPlatform == TargetPlatform.android &&
        Theme.of(context).useMaterial3;
    if (!useMatrixStretch) return list;
    return ScrollConfiguration(
      // Disable the default (shader-based) stretch indicator so the
      // matrix-based one below is the only stretch applied.
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: TransformStretchOverscroll(
        axisDirection: AxisDirection.down,
        child: list,
      ),
    );
  }

  /// Load-more indicator shown above the message list while older messages
  /// are being loaded.
  ///
  /// Returns a zero-size box unless [_isLoadingMore] is true, so the
  /// [CircularProgressIndicator] is not in the widget tree at all when no
  /// pagination load is running — an indeterminate spinner cannot animate
  /// while it is not displayed, and a library notifier stuck in the loading
  /// state cannot keep a phantom spinner visible either.
  Widget _buildLoadMoreIndicator() {
    if (!_isLoadingMore) return const SizedBox.shrink();
    return const Padding(
      key: ValueKey('chat-load-more-indicator'),
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Top sliver with the "没有更多内容了" hint, shown once the user has
  /// reached the top of the list while no older messages remain.
  Widget _buildNoMoreMessagesSliver() {
    if (!_hasReachedTopWithoutMore || _hasMoreMessages) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            '没有更多内容了',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a text message with its bubble and action buttons.
  Widget _buildTextMessage(
    BuildContext context,
    TextMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
    required bool isDark,
    required bool isStreaming,
    required String? activeId,
  }) {
    final isAi = message.authorId == _aiUser.id;

    Widget messageBubble;
    if (isAi) {
      final chatMsg = _history.where((m) => m.id == message.id).firstOrNull;
      if ((chatMsg?.isError == true) || message.text.startsWith('错误:')) {
        messageBubble = _buildErrorMessageBubble(
          context: context,
          message: message,
          chatMsg: chatMsg,
          isDark: isDark,
        );
      } else {
        messageBubble = _buildAiMessageBubble(
          message: message,
          isDark: isDark,
          isStreaming: isStreaming,
          activeId: activeId,
        );
      }
    } else {
      messageBubble = _buildUserMessageBubble(
        message: message,
        index: index,
        isSentByMe: isSentByMe,
      );
    }

    return Column(
      crossAxisAlignment:
          isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: _messageKeys.putIfAbsent(
            message.id,
            () => GlobalKey(),
          ),
          child: messageBubble,
        ),
        // Timestamp below bubble (user messages only),
        // above action buttons, with theme-adaptive color.
        if (!isAi)
          Padding(
            padding: const EdgeInsets.only(
              left: 4,
              top: 2,
              bottom: 2,
            ),
            child: Text(
              DateFormat('yyyy-MM-dd HH:mm').format(
                (message.createdAt ?? message.resolvedTime ?? DateTime.now())
                    .toLocal(),
              ),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            top: 2,
            bottom: 4,
          ),
          child: _buildMessageActionButtons(
            context: context,
            message: message,
            isAi: isAi,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  /// Builder for streaming (textStream) messages.
  Widget _buildTextStreamMessage(
    BuildContext context,
    TextStreamMessage message,
    int index, {
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
    required bool isStreaming,
    required String streamingFullReply,
    required String? streamingMsgId,
    required bool isDark,
  }) {
    // If the message has accumulated content (e.g.,
    // after page restoration from background streaming),
    // render it as regular text instead of a spinner.
    // Uses captured [streamingFullReply] from build()
    // which is updated reactively via ref.watch.
    if (streamingFullReply.isNotEmpty && message.id == streamingMsgId) {
      // This is the message currently being generated, so the streaming
      // markdown config applies (mermaid blocks show "正在生成..." while
      // the reply is still being produced — only while their fence is
      // still open; closed blocks render immediately).
      final config = buildMessageMarkdownConfig(
        isDark: isDark,
        conversationIsStreaming: isStreaming,
        streamingMsgId: streamingMsgId,
        messageId: message.id,
        streamingText: streamingFullReply,
      );
      return Padding(
        padding: const EdgeInsets.all(12),
        child: MarkdownWidget(
          data: streamingFullReply,
          selectable: true,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          config: config,
          markdownGenerator: markdownGenerator,
        ),
      );
    }
    // While the message is still in the textStream phase (no text token
    // has arrived yet), render the live segments — tool call cards and
    // inline reasoning buttons — exactly like the text message bubble
    // does. Previously only the reasoning section buttons were rendered
    // here, so a model that thought and then called tools without any
    // text showed a pile of "思考完成" buttons and hid the tool calls
    // until the first text token converted the message to a text message.
    final segments = _chatSegments[message.id];
    if (segments != null && segments.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: _buildSegmentWidgets(
            messageId: message.id,
            segments: segments,
            isDark: isDark,
            isStreaming: isStreaming,
            hasSearchMatch: false,
          ),
        ),
      );
    }
    // Check if reasoning content exists for this
    // message. If so, render the reasoning button
    // immediately instead of a spinner, even before
    // the first TextEvent converts the message from
    // textStream to text type.
    final reasoningSections = _reasoningContents[message.id];
    if (reasoningSections != null && reasoningSections.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ReasoningSection(
              sections: ReasoningSectionData(
                texts: reasoningSections,
                // During textStream phase, reasoning
                // events are still being received (no
                // TextEvent yet), so streaming is
                // always true. Once TextEvent arrives,
                // updateMessage() converts the message
                // to text type and textMessageBuilder
                // takes over with the correct flag.
                streaming: isStreaming &&
                    message.id == _streamingMsgId &&
                    _isReasoningCompletedForMsg[message.id] != true,
              ),
              messageId: message.id,
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }
}
