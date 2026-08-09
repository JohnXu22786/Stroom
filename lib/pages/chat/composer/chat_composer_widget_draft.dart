part of 'chat_composer_widget.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatComposerDraftExt on ChatComposerWidgetState {
  /// 草稿 JSON 携带 base64 的总预算（按原始字节计）。
  ///
  /// 超过预算的图片放弃携带压缩 base64（恢复时从磁盘压缩缓存/重新
  /// 压缩取回，见 [_restoreDraftAttachmentPayload]）——保护 Web 端
  /// localStorage（约 5MB）不被草稿撑爆：一旦爆掉，**整个对话持久化
  /// 都会静默失败**（不止草稿）。桌面端无硬限，但预算也能避免每次
  /// 防抖持久化编码数 MB 字符串。
  static const int _kDraftB64BudgetBytes = 1500 * 1024;

  /// 当前 pending 附件的草稿快照签名：文字未变但附件变了时也要保存。
  /// 含 base64Data 长度——预压缩完成（base64 从原始大字节变为压缩
  /// 产物）也会触发一次保存，把可零等待的载荷落进草稿。
  List<String> _draftAttSignature() => _pendingAttachments
      .map(
          (a) => '${a.id}:${a.hash}:${a.fileType}:${a.base64Data?.length ?? 0}')
      .toList();

  /// 生成待保存的附件草稿快照（深拷贝，与 pending 列表无引用共享）。
  ///
  /// 仅图片附件携带 base64Data，且必须是"已压缩完成/小图"的可直接
  /// 发送载荷（≤ 阈值）——未压缩完的原始大 base64 不携带（体积无谓
  /// 膨胀），恢复时重新读文件并触发预压缩。文件附件只存引用，
  /// 恢复时重新读取编码。总携带量受 [_kDraftB64BudgetBytes] 预算约束。
  List<Attachment> _draftAttachmentSnapshot() {
    var budget = _kDraftB64BudgetBytes;
    return _pendingAttachments.map((a) {
      var includeB64 = false;
      if (a.fileType == 'image' &&
          attachmentHasReadyPayload(a, maxBytes: imageCompressThresholdBytes)) {
        // base64 体积 ≈ 4/3 × 原始字节；预算内才携带
        final payloadLen = a.base64Data!.length * 3 ~/ 4;
        if (payloadLen <= budget) {
          includeB64 = true;
          budget -= payloadLen;
        }
      }
      final copy = Attachment.fromMap(a.toMap(includeBase64Data: includeB64));
      // 草稿归属当前对话：恢复后的清理/缓存定位使用
      copy.conversationId ??= widget.conversationId;
      return copy;
    }).toList();
  }

  /// Saves the current text + attachment snapshot as draft for the given
  /// widget's conversation, bypassing the debounce timer.
  void _saveDraftImmediately(ChatComposerWidget w) {
    final convId = w.conversationId;
    if (convId == null) return;
    // 编辑模式不写草稿（与 _onTextChanged 的跳过一致）：否则应用
    // 进入后台/被销毁时，正在编辑的消息文本会被当作新消息草稿
    // 持久化，重进对话后草稿区出现陈旧的编辑文本。
    if (w.editingMessageId != null) return;
    // If neither the text nor the attachments changed since last save, skip
    if (w == widget &&
        _lastSavedDraft == _textController.text &&
        _lastSavedDraftAttSignature.toString() ==
            _draftAttSignature().toString()) {
      return;
    }
    final textToSave = _textController.text;
    ref.read(conversationsProvider.notifier).saveDraft(
          convId,
          textToSave,
          draftAttachments: _draftAttachmentSnapshot(),
        );
    _lastSavedDraft = textToSave;
    _lastSavedDraftAttSignature = _draftAttSignature();
  }

  /// 附件变化（添加/移除/编辑）后调度一次草稿保存（防抖，与文字
  /// 共用同一计时器）。文字未变时原有 skip 逻辑会拦下冗余保存，
  /// 因此这里不能只依赖文字——见 [_draftAttSignature]。
  void _scheduleDraftSave() {
    if (widget.editingMessageId != null) return;
    if (widget.conversationId == null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _saveDraftImmediately(widget);
    });
  }

  /// 恢复该对话的附件草稿（替换当前 pending）。
  ///
  /// - 图片附件：base64Data 为预压缩产物时直接可用（发送零等待，
  ///   无需读文件）；否则先查磁盘压缩缓存，再读原文件重新预压缩。
  /// - 文件附件：异步读原文件并重新 base64 编码。
  /// - 预览字节（原始图）异步从 storagePath 读取。
  ///
  /// **深拷贝**：草稿附件是对话持有的对象，恢复进 pending 后会被
  /// 预压缩/文件编码就地修改——直接引用会把大体积 base64 写回
  /// 对话状态，撑爆持久化。
  void _restoreDraftAttachments(List<Attachment> attachments) {
    final copies = attachments
        .map((a) => Attachment.fromMap(a.toMap(includeBase64Data: true)))
        .toList();
    _removedEditAttachments.clear();
    setState(() {
      _pendingAttachments.clear();
      _pendingImageBytes.clear();
      if (copies.isNotEmpty) {
        _pendingAttachments.addAll(copies);
      }
    });
    for (final att in copies) {
      unawaited(_restoreDraftAttachmentPayload(att));
    }
  }

  /// 恢复单个草稿附件的载荷（base64Data/预览字节），并重新触发
  /// 未完成的后台预压缩。
  Future<void> _restoreDraftAttachmentPayload(Attachment att) async {
    // 图片且已有可直接发送的压缩载荷：零 IO 恢复
    if (att.fileType == 'image' &&
        attachmentHasReadyPayload(att, maxBytes: imageCompressThresholdBytes)) {
      await _loadDraftPreviewFromDisk(att);
      return;
    }
    if (att.fileType == 'image') {
      // 磁盘压缩缓存优先（选中时预压缩/发送时压缩的产物）：
      // 避免每次重进对话都重新压缩；缓存命中即零等待。
      final cached = await AttachmentStorage.readCompressedImage(
        conversationId: att.conversationId ?? widget.conversationId,
        hash: att.hash,
      );
      if (cached != null &&
          cached.bytes.length <= imageCompressThresholdBytes &&
          mounted) {
        att.base64Data = base64Encode(cached.bytes);
        att.compressedCachePersisted = true;
        await _loadDraftPreviewFromDisk(att);
        return;
      }
    }
    if (att.storagePath.isEmpty) {
      // 无法读取（理论上草稿总是带 storagePath）：发送路径兜底
      if (att.fileType == 'image' && att.base64Data != null) {
        await _loadDraftPreviewFromDisk(att);
      }
      return;
    }
    final bytes = await AttachmentStorage.readFile(att.storagePath);
    if (bytes == null || !mounted) return;
    if (att.fileType == 'image') {
      // 重新触发后台预压缩（结果写回 base64Data + 磁盘缓存）
      await _preCompressPendingImage(att, bytes);
      if (!mounted) return;
      setState(() {
        _pendingImageBytes[att.id] = bytes;
      });
    } else {
      // 文件：重新 base64 编码（发送载荷）
      att.base64Data = base64Encode(bytes);
      if (!mounted) return;
      setState(() {
        _pendingImageBytes[att.id] = bytes;
      });
    }
  }

  /// 从磁盘读取原始字节作为预览（不覆盖已就绪的发送载荷）。
  Future<void> _loadDraftPreviewFromDisk(Attachment att) async {
    if (att.storagePath.isEmpty) return;
    final bytes = await AttachmentStorage.readFile(att.storagePath);
    if (bytes == null || !mounted) return;
    setState(() {
      _pendingImageBytes[att.id] = bytes;
    });
  }

  /// Pre-populates the pending attachments area with the original message's
  /// attachments when entering edit mode. For image attachments, loads the
  /// bytes from storage so the preview chip can display the thumbnail.
  void _loadEditingAttachments(List<Attachment>? attachments) {
    // 新的编辑会话：无论目标消息有没有附件，都先重置本会话状态——
    // 1) 清空上一会话遗留的 pending 附件：切换编辑目标到无附件消息
    //    时若不清理，陈旧附件芯片仍显示且可移除，其移除会误删仍被
    //    原消息引用图片的压缩缓存（编辑会话外移除 = 立即清理）；
    // 2) 清空"待重发时清理"记录：避免在无附件消息上提交时，误删
    //    上一会话推迟清理的缓存。
    _removedEditAttachments.clear();
    setState(() {
      _pendingAttachments.clear();
      _pendingImageBytes.clear();
      if (attachments != null && attachments.isNotEmpty) {
        _pendingAttachments.addAll(attachments);
      }
    });
    if (attachments == null || attachments.isEmpty) return;
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
    _scheduleDraftSave();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) return;

    // A quick image edit is still processing — sending now would use
    // the unedited attachment bytes.
    if (_editsInFlight > 0) return;

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
      // 确定重发：清理编辑期间被移除图片的压缩缓存。移除时推迟
      // （用户可能取消编辑，见 _removePendingAttachment），此刻才
      // 确认删除；同一张图（同 hash）在发送前又被加回时不删——
      // 新消息仍需要它的缓存。等待在途预压缩完成后删除。
      final removed = [..._removedEditAttachments];
      widget.onEditSend?.call(
        widget.editingMessageId!,
        text.trim(),
        attachments,
      );
      for (final a in removed) {
        if (attachments.any((n) => n.hash == a.hash)) continue;
        unawaited(_deleteCompressedCacheAfterPreCompress(a));
      }
      _clearPendingAttachments();
      _textController.clear();
      // Cancel any pending draft timer in edit mode
      _draftTimer?.cancel();
      _lastSavedDraft = '';
      _lastSavedDraftAttSignature = const [];
      return;
    }

    widget.onSend(text.trim(), [..._pendingAttachments]);
    _clearPendingAttachments();
    _textController.clear();

    // Clear the draft (text + attachments) for this conversation after
    // sending
    final convId = widget.conversationId;
    if (convId != null) {
      _draftTimer?.cancel();
      ref.read(conversationsProvider.notifier).saveDraft(
        convId,
        '',
        draftAttachments: const [],
      );
      _lastSavedDraft = '';
      _lastSavedDraftAttSignature = const [];
    }
  }

  /// Clear all pending attachments.
  ///
  /// 注意：发送后**不删除** temp_edited 文件——消息已持久化引用该文件，
  /// 删除会让发送后的气泡预览/加载失败（“无法加载文件”）。
  /// 未被发送的编辑产物由 _removePendingAttachment 在用户移除时清理；
  /// 消息删除时由 _deleteMessage 的 isReferencedElsewhere 检查清理；
  /// 编辑提交后未被引用的孤儿文件由删除整个对话时的附件清理兜底。
  void _clearPendingAttachments() {
    _pendingAttachments.clear();
    _pendingImageBytes.clear();
    // 编辑会话结束（提交或取消）：不再有"待重发时清理"的附件。
    // 提交路径已在 _handleSubmitted 中完成清理；取消路径原消息仍
    // 引用这些附件，缓存本来就不该删。
    _removedEditAttachments.clear();
  }

  void _showComposerFullscreenEditor() {
    showDialog(
      context: context,
      builder: (ctx) => _FullscreenComposerEditorDialog(
        initialText: _textController.text,
        onClose: (text) {
          if (!mounted) return;
          // Preserve content back to the main input field
          // instead of discarding it.
          _textController.text = text;
          // Trigger draft save since setting text programmatically
          // does not fire onChanged.
          _onTextChanged(text);
        },
        onSend: (text) {
          if (!mounted) return;
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
    );
  }
}

/// 全屏编辑消息对话框。
///
/// 点击右上角叉叉与按系统返回键/导航键（[PopScope]）走同一条
/// [_closePreservingContent] 路径：都把编辑内容回写到主输入框，而不是
/// 直接丢弃。点击遮罩（barrier）/桌面 Esc 也会被 [PopScope] 拦截并走
/// 同一条保留路径。输入控制器由本组件持有并在组件销毁（对话框退出动画
/// 结束、路由被移除）时才 dispose，避免在退出动画期间仍被 TextField
/// 引用时触发 "A TextEditingController was used after being disposed"。
class _FullscreenComposerEditorDialog extends StatefulWidget {
  const _FullscreenComposerEditorDialog({
    required this.initialText,
    required this.onClose,
    required this.onSend,
  });

  final String initialText;

  /// Called when the user closes the dialog (X button or back key).
  /// Receives the final edited text so the caller can preserve it.
  final ValueChanged<String> onClose;

  /// Called when the user sends. Receives the final edited text.
  final ValueChanged<String> onSend;

  @override
  State<_FullscreenComposerEditorDialog> createState() =>
      _FullscreenComposerEditorDialogState();
}

class _FullscreenComposerEditorDialogState
    extends State<_FullscreenComposerEditorDialog> {
  late final TextEditingController _editingController =
      TextEditingController(text: widget.initialText);

  /// Guards against double-invocation (e.g. X tapped while back key is
  /// pressed during the exit animation, or a rapid double-tap).
  bool _closed = false;

  @override
  void dispose() {
    _editingController.dispose();
    super.dispose();
  }

  /// Close the dialog while preserving the edited content back to the main
  /// input field. Shared by the top-right X button, the system back key,
  /// barrier taps and desktop Esc (all flow through [PopScope]).
  /// Pop first: the dialog closes even if the callback throws, and the
  /// State stays mounted through the exit animation so the callback still
  /// runs safely.
  void _closePreservingContent() {
    if (_closed) return;
    _closed = true;
    Navigator.pop(context);
    widget.onClose(_editingController.text);
  }

  void _send() {
    if (_closed) return;
    _closed = true;
    Navigator.pop(context);
    widget.onSend(_editingController.text);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closePreservingContent();
      },
      child: Dialog(
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
                    onPressed: _closePreservingContent,
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _editingController,
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
                  onPressed: _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
