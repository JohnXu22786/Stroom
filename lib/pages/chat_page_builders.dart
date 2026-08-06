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
    return Chat(
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
                {required bool isSentByMe, MessageGroupStatus? groupStatus}) =>
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
                {required bool isSentByMe, MessageGroupStatus? groupStatus}) =>
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
    );
  }

  /// Chat animated list with lazy pagination and auto-scroll control.
  Widget _buildChatAnimatedList(
    BuildContext context,
    ChatItem itemBuilder,
  ) {
    return ChatAnimatedList(
      itemBuilder: itemBuilder,
      onEndReached: _loadMoreMessages,
      scrollController: _chatScrollController,
      // Initially disable auto-scroll. User must
      // tap the scroll-to-bottom button to enable.
      shouldScrollToEndWhenAtBottom: _autoScrollEnabled,
      shouldScrollToEndWhenSendingMessage: _autoScrollEnabled,
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
      // the reply is still being produced).
      final config = buildMessageMarkdownConfig(
        isDark: isDark,
        conversationIsStreaming: isStreaming,
        streamingMsgId: streamingMsgId,
        messageId: message.id,
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
