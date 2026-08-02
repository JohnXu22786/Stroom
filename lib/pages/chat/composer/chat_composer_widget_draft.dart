part of 'chat_composer_widget.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatComposerDraftExt on ChatComposerWidgetState {
  /// Saves the current text as draft for the given widget's conversation,
  /// bypassing the debounce timer.
  void _saveDraftImmediately(ChatComposerWidget w) {
    final convId = w.conversationId;
    if (convId == null) return;
    // 编辑模式不写草稿（与 _onTextChanged 的跳过一致）：否则应用
    // 进入后台/被销毁时，正在编辑的消息文本会被当作新消息草稿
    // 持久化，重进对话后草稿区出现陈旧的编辑文本。
    if (w.editingMessageId != null) return;
    // If the text hasn't changed since last save, skip
    if (w == widget && _lastSavedDraft == _textController.text) return;
    final textToSave = _textController.text;
    ref.read(conversationsProvider.notifier).saveDraft(convId, textToSave);
    _lastSavedDraft = textToSave;
  }

  /// Pre-populates the pending attachments area with the original message's
  /// attachments when entering edit mode. For image attachments, loads the
  /// bytes from storage so the preview chip can display the thumbnail.
  void _loadEditingAttachments(List<Attachment>? attachments) {
    if (attachments == null || attachments.isEmpty) return;
    setState(() {
      _pendingAttachments.clear();
      _pendingImageBytes.clear();
      _pendingAttachments.addAll(attachments);
    });
    // Load image bytes asynchronously for preview
    for (final att in attachments) {
      if (att.fileType == 'image' && att.storagePath.isNotEmpty) {
        AttachmentStorage.readFile(att.storagePath).then((bytes) {
          if (bytes != null && mounted) {
            setState(() {
              _pendingImageBytes[att.id] = bytes;
            });
          }
        });
      }
    }
  }

  /// Debounced draft save triggered by text changes.
  /// Only calls setState when send-button enabled state transitions
  /// (empty ↔ non-empty) to avoid rebuilding the entire composer
  /// widget tree on every keystroke.
  void _onTextChanged(String text) {
    // Only rebuild when send-button enabled state changes
    final hasTextNow = text.trim().isNotEmpty;
    if (_lastHadText == null || _lastHadText != hasTextNow) {
      _lastHadText = hasTextNow;
      setState(() {});
    }
    // Skip draft saving in edit mode — the text is for editing a sent
    // message, not composing a new one.
    if (widget.editingMessageId != null) return;
    _draftTimer?.cancel();
    // Skip saving if the text hasn't actually changed since last save
    if (text == _lastSavedDraft) return;
    _draftTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final convId = widget.conversationId;
      if (convId == null) return;
      ref.read(conversationsProvider.notifier).saveDraft(convId, text);
      _lastSavedDraft = text;
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) return;

    // 流式守卫（与 Enter 键路径一致）：流式期间发送按钮被替换为停止
    // 按钮，但全屏编辑器的发送路径没有按钮级保护——chat_page 的
    // _onMessageSend 对流式中的对话静默 return，不清空这里会导致
    // 用户输入被静默丢弃。守卫：流式中不发送、保留输入。
    final streamingConvs = ref.read(streamingConversationsProvider);
    if (widget.conversationId != null &&
        streamingConvs.contains(widget.conversationId)) {
      return;
    }

    if (widget.editingMessageId != null) {
      // Edit mode: call onEditSend with the message id, edited text,
      // and all pending attachments (original + newly added, minus removed).
      final attachments = [..._pendingAttachments];
      widget.onEditSend?.call(
        widget.editingMessageId!,
        text.trim(),
        attachments,
      );
      _clearPendingAttachments();
      _textController.clear();
      // Cancel any pending draft timer in edit mode
      _draftTimer?.cancel();
      _lastSavedDraft = '';
      return;
    }

    widget.onSend(text.trim(), [..._pendingAttachments]);
    _clearPendingAttachments();
    _textController.clear();

    // Clear the draft for this conversation after sending
    final convId = widget.conversationId;
    if (convId != null) {
      _draftTimer?.cancel();
      ref.read(conversationsProvider.notifier).saveDraft(convId, '');
      _lastSavedDraft = '';
    }
  }

  /// Clear all pending attachments and clean up temp files.
  void _clearPendingAttachments() {
    for (final att in _pendingAttachments) {
      if (att.storagePath.startsWith('temp_edited/')) {
        _deleteTempFile(att.storagePath);
      }
    }
    _pendingAttachments.clear();
    _pendingImageBytes.clear();
  }

  void _showComposerFullscreenEditor() {
    final editingController = TextEditingController(text: _textController.text);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '编辑消息',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      // Preserve content back to the main input field
                      // instead of discarding it.
                      _textController.text = editingController.text;
                      // Trigger draft save since setting text programmatically
                      // does not fire onChanged.
                      _onTextChanged(_textController.text);
                      editingController.dispose();
                      Navigator.pop(ctx);
                    },
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: editingController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('发送'),
                  onPressed: () {
                    final text = editingController.text;
                    editingController.dispose();
                    Navigator.pop(ctx);
                    // 流式守卫（_handleSubmitted 内）可能提前 return：
                    // 先把对话框文本回写主输入框，守卫拦截时不丢输入
                    // （否则用户刚编辑的文本永久丢失，保留的是打开
                    // 对话框前的旧文本）。程序化赋值不触发 onChanged，
                    // 需显式调用 _onTextChanged（与关闭按钮路径一致）
                    // 以调度防抖草稿保存。
                    if (_textController.text != text) {
                      _textController.text = text;
                      _onTextChanged(text);
                    }
                    _handleSubmitted(text);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
