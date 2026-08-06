part of 'chat_page.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatPageEditingExt on _ChatPageState {
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
    });
    // Sending the edit deletes this message and every message below it —
    // remind the user when there is actually anything to lose.
    if (index < _history.length - 1) {
      _showEditWarning();
    }
  }

  /// Shows the centered data-loss warning for 2 seconds. Re-entry (e.g.
  /// switching to edit another message) restarts the timer.
  void _showEditWarning() {
    _editWarningTimer?.cancel();
    setState(() => _editWarningVisible = true);
    _editWarningTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _editWarningVisible = false);
    });
  }

  /// Hides the warning immediately (close button, edit cancel/send, or
  /// conversation switch). No-op when the warning is not visible.
  void _hideEditWarning() {
    _editWarningTimer?.cancel();
    if (!_editWarningVisible || !mounted) return;
    setState(() => _editWarningVisible = false);
  }

  void _handleEditSend(
    String messageId,
    String newText,
    List<Attachment> attachments,
  ) {
    if (!mounted) return;
    // The edit operation itself performs the deletion — warning no longer
    // relevant once the user commits to it.
    _hideEditWarning();
    // Clear edit state
    setState(() {
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
    });
    // Perform the edit with the combined attachments
    _editUserMessageWithText(messageId, newText, attachments);
  }

  void _handleEditCancel() {
    if (!mounted) return;
    // Edit aborted — no deletion will happen, hide the warning.
    _hideEditWarning();
    setState(() {
      _editingMessageId = null;
      _editingMessageText = null;
      _editingMessageAttachments = null;
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

      // Remove this message and all after from history and controller.
      try {
        if (index < _history.length) {
          final removed = _history.sublist(index);
          _history.removeRange(index, _history.length);
          for (final r in removed) {
            final ctrlMsg =
                _controller?.messages.where((m) => m.id == r.id).firstOrNull;
            if (ctrlMsg != null) {
              await _controller?.removeMessage(ctrlMsg);
            }
            // Clean up cached maps for removed messages to prevent memory leaks.
            _chatSegments.remove(r.id);
            _reasoningContents.remove(r.id);
            _finalizedMessages.remove(r.id);
            _isReasoningCompletedForMsg.remove(r.id);
            _messageKeys.remove(r.id);
            // NOTE: 这里**不删除**附件文件——编辑态下 composer 直接
            // 复用原消息的同一批 Attachment 对象（storagePath 相同），
            // 删除文件会让新消息的附件读取失败（_onMessageSend 随后
            // 把同一 storagePath 挂到新消息）。与 _deleteMessage 不同，
            // 编辑路径没有 isReferencedElsewhere 保护。真正的孤儿文件
            // 清理在 _deleteMessage（带引用检查）中完成。
          }
          // Safety: keep pagination index within bounds
          _loadedUpToIndex = _loadedUpToIndex.clamp(0, _history.length);
        }
      } catch (e) {
        debugPrint('[ChatPage] _editUserMessageWithText remove failed: $e');
      }

      // Force the UI to reflect the truncated history BEFORE any provider
      // listener fires _loadConversationMessages (which would reload old
      // messages from the provider before _saveMessages below runs).
      if (mounted) setState(() {});

      // Now persist the truncated history. This must happen before
      // _onMessageSend calls _saveEnabledToolsToConversation which
      // triggers the conversationsProvider listener.
      await _saveMessages();

      // Send with edited text and the combined attachments (original + new)
      await _onMessageSend(newText, newAttachments);
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

      // Remove this assistant message and all after from history
      try {
        if (index < _history.length) {
          final removed = _history.sublist(index);
          _history.removeRange(index, _history.length);
          for (final r in removed) {
            final ctrlMsg =
                _controller?.messages.where((m) => m.id == r.id).firstOrNull;
            if (ctrlMsg != null) {
              await _controller?.removeMessage(ctrlMsg);
            }
            // Clean up cached maps for removed messages to prevent memory leaks.
            _chatSegments.remove(r.id);
            _reasoningContents.remove(r.id);
            _finalizedMessages.remove(r.id);
            _isReasoningCompletedForMsg.remove(r.id);
            _messageKeys.remove(r.id);
          }
          // Safety: keep pagination index within bounds
          _loadedUpToIndex = _loadedUpToIndex.clamp(0, _history.length);
        }
      } catch (e) {
        debugPrint('[ChatPage] _retryAssistantMessage remove failed: $e');
      }

      // Force UI rebuild and sync provider before re-streaming
      if (mounted) setState(() {});
      await _saveMessages();

      // Re-generate using the preceding user message
      final userMsg = _history[index - 1];
      await _startStreaming(userMsg.content);
      await _syncHistoryFromProvider();
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
    if (index == -1) return;
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
