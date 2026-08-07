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
      // estimate corrections); _followContentGrowth ignores the scrolling
      // cases and only re-pins when auto-scroll is engaged.
      onNotification: (_) {
        _followContentGrowth();
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

  /// Tracks user drags on the chat list via scroll notifications, so the
  /// keyboard bottom-pinning never fights a finger scroll. Programmatic
  /// scrolls (jumpTo / animateTo — e.g. the chat library's own keyboard
  /// handling) have null [ScrollNotification.dragDetails] and are ignored.
  bool _onChatScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _userIsDragging = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _userIsDragging = false;
    }
    return false;
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
