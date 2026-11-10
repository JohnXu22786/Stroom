part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageEditingExt on _ChatPageState {
  /// Removes [messageId]'s controller item and all per-message caches.
  ///
  /// Shared by the edit / retry truncation loops. The controller removal is
  /// id-based (the message must be looked up at removal time — the loop
  /// mutates the controller list, so positions shift).
  Future<void> _removeMessageFromController(String messageId) async {
    final ctrlMsg =
        _controller?.messages.where((m) => m.id == messageId).firstOrNull;
    if (ctrlMsg != null) {
      await _controller?.removeMessage(ctrlMsg);
    }
    // Clean up cached maps for removed messages to prevent memory leaks.
    _chatSegments.remove(messageId);
    _reasoningContents.remove(messageId);
    _finalizedMessages.remove(messageId);
    _isReasoningCompletedForMsg.remove(messageId);
    _messageKeys.remove(messageId);
  }

  /// Removes every controller message that is NOT part of [_history].
  ///
  /// Edit/retry truncation only iterates messages found in [_history], but
  /// a STOPPED partial reply (or any other aborted stream) lives ONLY in the
  /// controller + segment cache — it never entered [_history]. Without this
  /// sweep such a message survives the truncation and its tool call cards /
  /// reasoning buttons linger on screen as ghosts after the edit/regenerate.
  Future<void> _removeOrphanMessagesFromController() async {
    final keptIds = _history.map((m) => m.id).toSet();
    final orphanIds = (_controller?.messages ?? [])
        .where((m) => !keptIds.contains(m.id))
        .map((m) => m.id)
        .toList();
    for (final orphanId in orphanIds) {
      await _removeMessageFromController(orphanId);
    }
  }

  void _confirmRetryOrEdit(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId != null &&
        ref.read(streamingConversationsProvider).contains(activeId)) {
      return;
    }

    final msg = _history[index];
    final isUser = msg.role == 'user';
    final newerMessagesExist = index < _history.length - 1;

    showRetryEditConfirmDialog(
      context: context,
      isUser: isUser,
      newerMessagesExist: newerMessagesExist,
      onEdit: () => _startEditMessage(messageId),
      onRetry: () => _retryAssistantMessage(messageId),
    );
  }

  void _startEditMessage(String messageId) {
    final index = _history.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final activeId = ref.read(activeConversationIdProvider);
    // Check both the provider set AND the local flag — there's a
    // microsecond window between _isStreamingActive=true (set
    // synchronously in _startStreaming) and the
    // streamingConversationsProvider update (pushed by the manager).
    if ((activeId != null &&
            ref.read(streamingConversationsProvider).contains(activeId)) ||
        _isStreamingActive) {
      return;
    }
    final msg = _history[index];

    // Instead of showing a separate dialog, enter edit mode in the composer.
    // The composer will pre-fill with the message text, show the original
    // attachments in the pending area, and show an edit capsule.
    // On send, _handleEditSend is called. On cancel, _handleEditCancel.
    setState(() {
      _editingMessageId = messageId;
      _editingMessageText = msg.content;
      _editingMessageAttachments = msg.attachments;
      // Sending the edit deletes this message and every message below it —
      // arm the composer's data-loss warning when there is anything to lose.
      // The composer shows it immediately on entry in the capsule's row
      // (fade-in), then fades it out after 2s or on close.
      _showEditWarningOnEntry = index < _history.length - 1;
      // Bump so the composer re-arms even for the same message id
      // (re-tap on the message being edited re-shows the warning).
      _editWarningArmCount++;
    });
  }

  void _handleEditSend(
    String messageId,
    String newText,
    List<Attachment> attachments,
  ) {
    if (!mounted) return;
    // Clear edit state
    setState(() {
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
      _showEditWarningOnEntry = false;
    });
    // Perform the edit with the combined attachments
    _editUserMessageWithText(messageId, newText, attachments);
  }

  void _handleEditCancel() {
    if (!mounted) return;
    setState(() {
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
      _showEditWarningOnEntry = false;
    });
  }

  Future<void> _editUserMessageWithText(
    String messageId,
    String newText,
    List<Attachment> newAttachments,
  ) async {
    // Re-entrancy guard: prevent concurrent edit operations (e.g.
    // rapid double-tap on "Send" in edit mode).
    if (_isModifyingHistory) return;
    _isModifyingHistory = true;
    try {
      final index = _history.indexWhere((m) => m.id == messageId);
      if (index == -1 || index >= _history.length) return;
      // Keep the complete old transcript durable while the replacement is
      // in flight. The request sees only the prefix before the edited turn;
      // on success the manager replaces the old tail, while an error or stop
      // appends the failed attempt after the untouched transcript.
      await _onMessageSend(
        newText,
        newAttachments,
        historyForRequestPrefix: List<ChatMessage>.from(_history.take(index)),
      );
    } finally {
      _isModifyingHistory = false;
      _scheduleReloadAfterBlockingOperation();
    }
  }

  Future<void> _retryAssistantMessage(String messageId) async {
    _isModifyingHistory = true;
    try {
      final index = _history.indexWhere((m) => m.id == messageId);
      if (index == -1 || index == 0 || index >= _history.length) return;
      final historyBeforeAttempt = List<ChatMessage>.from(_history);
      final historyForSuccess = historyBeforeAttempt.sublist(0, index);
      final userMsg = _history[index - 1];
      await _startStreaming(
        userMsg.content,
        historyOverride: historyBeforeAttempt,
        requestHistoryOverride: historyForSuccess,
        historyOnSuccess: historyForSuccess,
        replaceHistoryOnError: true,
      );
    } finally {
      _isModifyingHistory = false;
      _scheduleReloadAfterBlockingOperation();
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    // Prevent deleting the currently streaming message — the streaming loop
    // relies on _chatSegments entries for this
    // message, and removing them mid-stream would cause null-assert crashes.
    if (messageId == _streamingMsgId) return;
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId != null &&
        ref.read(streamingConversationsProvider).contains(activeId)) {
      return;
    }
    final index = _history.indexWhere((m) => m.id == messageId);
    // 孤儿消息：只存在于 controller/缓存、不在 _history 中（如 Stop 掉
    // 的部分回复）。直接移除 controller 项与缓存——否则其工具卡片会
    // 一直残留（幽灵卡片）。孤儿本就不在 _history 里，无需 _saveMessages
    // （若其 finalize 延迟落库，下次重载会从 provider 恢复，属正常语义）。
    if (index == -1) {
      await _removeMessageFromController(messageId);
      if (mounted) setState(() {});
      return;
    }
    final msg = _history[index];

    for (final att in msg.attachments) {
      final isReferencedElsewhere = _history.asMap().entries.any(
            (entry) =>
                entry.key != index &&
                entry.value.attachments.any(
                  (a) => a.storagePath == att.storagePath,
                ),
          );
      if (!isReferencedElsewhere) {
        await AttachmentStorage.deleteFile(att.storagePath);
        // 磁盘压缩缓存一并清理（派生缓存，best-effort：失败不影响
        // 消息删除）。缓存按（对话, hash）定位，isReferencedElsewhere
        // 按 storagePath 判定——字节完全相同（同 hash 不同文件）的
        // 兄弟消息共享同一缓存条目，可能被本删除连带清掉，其下次
        // 发送重新压缩即可（缓存删除永远安全）。
        try {
          await AttachmentStorage.deleteCompressedImage(
            conversationId: att.conversationId,
            hash: att.hash,
          );
        } catch (_) {
          // 非关键清理
        }
      }
    }

    setState(() {
      _history.removeAt(index);
      // Clean up cached maps for the deleted message to prevent memory leaks.
      _chatSegments.remove(messageId);
      _reasoningContents.remove(messageId);
      _finalizedMessages.remove(messageId);
      _isReasoningCompletedForMsg.remove(messageId);
      _messageKeys.remove(messageId);
      // Adjust pagination state: if the deleted message was before the loaded
      // region, shift _loadedUpToIndex to keep it pointing at the same messages.
      if (index < _loadedUpToIndex && _loadedUpToIndex > 0) {
        _loadedUpToIndex = _loadedUpToIndex > 0 ? _loadedUpToIndex - 1 : 0;
      }
      // 历史被截断：使进行中的加载失效，并同步清除其加载标志。
      _isLoadingMore = false;
      _loadMoreGeneration++;
    });

    final msgToRemove =
        _controller?.messages.where((m) => m.id == messageId).firstOrNull;
    if (msgToRemove != null) {
      await _controller?.removeMessage(msgToRemove);
    }

    _saveMessages();
  }

  void _confirmDeleteMessage(String messageId) {
    showDeleteConfirmDialog(
      context: context,
      onDelete: () => _deleteMessage(messageId),
    );
  }
}
