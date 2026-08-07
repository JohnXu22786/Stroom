part of 'chat_composer_widget.dart';
// Extension methods on the State class cannot use @protected members
// (setState / state) without analyzer warnings, but the receiver IS the
// State/StateNotifier, so runtime behavior is identical to the original
// inline code.
// ignore_for_file: invalid_use_of_protected_member

extension _ChatComposerAttachmentsExt on ChatComposerWidgetState {
  // ═══════════════════════════════════════════════════════════════
  // Attachment / File pickers
  // ═══════════════════════════════════════════════════════════════

  void _showAttachmentPicker() {
    showChatAttachmentPanel(
      context: context,
      onPickFromCamera: _pickFromCamera,
      // 设备相册直接打开系统相册（不再弹出中间选择对话框）
      onPickFromGallery: _pickFromGallery,
      onPickFromFilePicker: _pickFromFilePicker,
      onPickFromAppFiles: _pickFromAppFiles,
    );
  }

  /// Pick from app internal files (images, documents, etc.).
  /// Uses the new unified file picker with folder hierarchy, multi-select,
  /// cross-folder selection, and preview bar.
  Future<void> _pickFromAppFiles() async {
    try {
      final result = await showAppFilePickerDialog(context);
      if (result == null || result.isEmpty) return;
      for (final entry in result) {
        await _addPendingAttachment(entry.key, entry.value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _addPendingAttachment(file.name, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍照失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 从设备相册选取图片（系统 API）
  ///
  /// 支持多选图片，自动适配不同平台：
  /// - Android/iOS: 原生系统相册
  /// - Web (桌面/移动): 浏览器文件选择器（image/*）
  /// - 桌面原生: 系统文件对话框
  /// 不支持时显示清晰的错误信息。
  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        await _addPendingAttachment(file.name, bytes);
      }
    } on UnsupportedError catch (e) {
      // 平台不支持 ImagePicker（极少数情况）
      if (mounted) {
        final platform = kIsWeb ? 'Web浏览器' : '当前设备';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$platform 不支持设备相册功能: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        // 提供更友好的平台相关错误提示
        String userHint;
        if (errorMsg.contains('permission') ||
            errorMsg.contains('denied') ||
            errorMsg.contains('权限')) {
          userHint = '请授予相册访问权限后重试';
        } else if (errorMsg.contains('cancelled') ||
            errorMsg.contains('cancel')) {
          return; // 用户取消操作，不显示错误
        } else if (kIsWeb &&
            (errorMsg.contains('NotAllowedError') ||
                errorMsg.contains('not allowed'))) {
          userHint = '请在浏览器设置中允许此网站访问文件';
        } else {
          userHint = '请检查设备是否支持相册选择功能';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入图片失败: $e\n$userHint'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 从设备文件系统选取文件（系统 API）
  ///
  /// 支持所有平台，自动适配不同操作系统：
  /// - Android/iOS: 系统文件选择器
  /// - Web (桌面/移动): 浏览器文件选择器
  /// - 桌面原生: 原生系统文件对话框
  Future<void> _pickFromFilePicker() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;
      await _addPendingAttachment(file.name, bytes);
    } on UnsupportedError catch (e) {
      if (mounted) {
        final platform = kIsWeb ? 'Web浏览器' : '当前设备';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$platform 不支持文件选择功能: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        String userHint;
        if (errorMsg.contains('permission') ||
            errorMsg.contains('denied') ||
            errorMsg.contains('权限')) {
          userHint = '请授予文件访问权限后重试';
        } else if (errorMsg.contains('cancelled') ||
            errorMsg.contains('cancel')) {
          return; // 用户取消操作，不显示错误
        } else if (kIsWeb &&
            (errorMsg.contains('NotAllowedError') ||
                errorMsg.contains('not allowed'))) {
          userHint = '请在浏览器设置中允许此网站访问文件';
        } else {
          userHint = '请确保设备支持文件选择功能';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入文件失败: $e\n$userHint'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addPendingAttachment(String fileName, Uint8List bytes) async {
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final fileType = mimeType.startsWith('image/')
        ? 'image'
        : mimeType.startsWith('video/')
            ? 'video'
            : mimeType.startsWith('audio/')
                ? 'audio'
                : 'document';
    final storagePath = await AttachmentStorage.saveFile(fileName, bytes);
    final hash = AttachmentStorage.computeHash(bytes);

    // Immediately compute base64 for the attachment so it's cached
    // and ready to send without waiting for conversion.
    // Cache for images, audio, video which need base64 for API calls
    // (image_url, input_audio, video_url formats respectively).
    // Also cache text files which may be sent inline.
    final String? base64Data;
    if (fileType == 'image' || fileType == 'audio' || fileType == 'video') {
      base64Data = base64Encode(bytes);
    } else {
      // For document files, base64 may not be needed for API calls
      base64Data = null;
    }

    final att = Attachment(
      fileName: fileName,
      mimeType: mimeType,
      fileType: fileType,
      hash: hash,
      storagePath: storagePath,
      fileSize: bytes.length,
      base64Data: base64Data,
    );
    if (fileType == 'image') {
      _pendingImageBytes[att.id] = bytes;
    }
    setState(() {
      _pendingAttachments.add(att);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导入 $fileName'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: 8,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.top + 48,
          ),
          duration: const Duration(seconds: 2),
          dismissDirection: DismissDirection.up,
        ),
      );
    }
  }

  void _removePendingAttachment(int index) {
    final att = _pendingAttachments[index];
    _pendingImageBytes.remove(att.id);
    // 清理编辑产物文件：仅限普通模式（pending 中未被任何消息引用）。
    // 编辑模式：附件仍被原消息引用（取消编辑后气泡仍需加载），
    // 删除会让原消息附件悬空。已提交编辑时被移除的文件成为孤儿，
    // 由删除整个对话时的附件清理兜底（见 conversations 删除逻辑）；
    // 若后续删除引用它的消息，_deleteMessage 的 isReferencedElsewhere
    // 检查会一并清理。
    if (widget.editingMessageId == null &&
        att.storagePath.startsWith('temp_edited/')) {
      _deleteTempFile(att.storagePath);
    }
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  /// Delete a temp-edited file from the attachment storage.
  Future<void> _deleteTempFile(String tempStoragePath) async {
    try {
      await AttachmentStorage.deleteFile(tempStoragePath);
    } catch (_) {
      // Non-critical cleanup
    }
  }

  /// Reorder handler for [ReorderableListView].
  /// onReorderItem 的 newIndex 已是移除 oldIndex 项之后调整过的索引，
  /// 不能再做 `if (newIndex > oldIndex) newIndex--;`（那是旧 onReorder
  /// 回调的写法，双重调整会导致向下拖动一格无效）。
  void _onReorderPendingAttachment(int oldIndex, int newIndex) {
    final item = _pendingAttachments.removeAt(oldIndex);
    setState(() {
      _pendingAttachments.insert(newIndex, item);
    });
  }

  /// Called when a pending attachment chip is tapped.
  /// For image attachments: shows [ImagePreviewDialog] with crop and edit
  ///   buttons. If user taps either, opens [ExtendedImageEditorPage]; on save,
  ///   updates the pending attachment with edited bytes.
  /// For non-image attachments: delegates to [widget.onPreviewAttachment].
  Future<void> _onTapPendingAttachment(int index) async {
    if (index < 0 || index >= _pendingAttachments.length) return;
    final att = _pendingAttachments[index];
    final isImage = att.fileType == 'image';

    if (!isImage) {
      widget.onPreviewAttachment?.call(att);
      return;
    }

    // For images: show preview dialog with edit button
    final imageBytes = _pendingImageBytes[att.id];
    if (imageBytes == null) return;
    if (!mounted) return;

    // Another edit is still processing — starting a second one could
    // silently discard the newer edit (both pipelines resolve against
    // the same original bytes). Ask the user to wait.
    if (_editsInFlight > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片处理中，请稍候再编辑'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (ctx) => ImagePreviewDialog(
        imageData: imageBytes,
        fileName: att.fileName,
      ),
    );

    if (shouldEdit != true || !mounted) return;

    // User tapped edit — open the ExtendedImage quick editor
    // (no save dialog needed for chat page attachments).
    // The editor pops immediately and processes in the background;
    // the pending attachment is updated from the callback once ready.
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExtendedImageEditorPage(
          imageBytes: imageBytes,
          fileName: att.fileName,
          onProcessed: (result) async {
            try {
              if (result is! QuickEditProcessingSuccess) return;
              if (!mounted) return;
              if (index >= _pendingAttachments.length) return;
              // Verify the attachment at this index is still the same
              // one we tapped
              if (_pendingAttachments[index].id != att.id) return;

              // Editor delivered edited bytes — update the pending
              // attachment
              await _updatePendingAttachmentAfterEdit(
                  index, result.editedBytes);
            } finally {
              // The pipeline always fires the callback (success or
              // failure) — release the send-blocking guard here.
              if (mounted) setState(() => _editsInFlight--);
            }
          },
        ),
      ),
    );
    if (confirmed == true && mounted) {
      // The pipeline is now running — hold the send button until the
      // callback releases it.
      setState(() => _editsInFlight++);
    }
  }

  /// Updates the pending attachment at [index] with [editedBytes].
  /// Saves the edited file into the attachment storage with a
  /// `temp_edited/` marker (does NOT overwrite the original).
  /// Updates both [_pendingAttachments] and [_pendingImageBytes].
  Future<void> _updatePendingAttachmentAfterEdit(
    int index,
    Uint8List editedBytes,
  ) async {
    // The composer is interactive while the editor processes in the
    // background — the attachment at [index] may have been removed or
    // reordered since the edit started. Bail out BEFORE any file I/O
    // so we never delete the file of an attachment that is still in use.
    if (index >= _pendingAttachments.length) return;
    final oldAtt = _pendingAttachments[index];

    try {
      // 编辑后的文件存入附件存储目录（与未编辑附件同一位置），
      // storagePath 保留 temp_edited/ 标记，供移除/清理逻辑识别。
      // 修复前：文件被写入系统临时目录但 storagePath 记为
      // temp_edited/xxx —— AttachmentStorage.readFile 解析到附件目录，
      // 文件不存在 → 发送后的消息气泡显示“无法加载文件”。
      final tempStoragePath = await AttachmentStorage.saveEditedFile(
        oldAtt.fileName,
        editedBytes,
      );
      final newHash = AttachmentStorage.computeHash(editedBytes);
      final newBase64 = base64Encode(editedBytes);

      // Update attachment with new temp-stored properties
      final updatedAtt = oldAtt.copyWith(
        hash: newHash,
        storagePath: tempStoragePath,
        fileSize: editedBytes.length,
        // 编辑输出格式可能与源不同（编辑器对 JPEG 源输出 JPEG，
        // 其余源输出 PNG）：mimeType 必须与真实内容一致，否则
        // data URI / media_type 声明与实际载荷不符。
        mimeType: _detectEditedImageMimeType(editedBytes, oldAtt.mimeType),
        base64Data: newBase64,
      );

      // The composer is interactive while the editor processes in the
      // background — the attachment at [index] may have been removed or
      // reordered during the awaits above. Re-validate BEFORE any
      // destructive file I/O so we never delete the file of an
      // attachment that is still in the list.
      if (!mounted ||
          index >= _pendingAttachments.length ||
          _pendingAttachments[index].id != oldAtt.id) {
        return;
      }

      // 清理旧文件：仅限普通模式（pending 中未被任何消息引用）。
      // 编辑模式：旧附件可能仍被原消息引用（取消编辑后气泡仍需加载），
      // 删除会让附件悬空；已提交编辑时被替换的文件成为孤儿，由删除
      // 整个对话时的附件清理兜底。
      if (widget.editingMessageId == null) {
        if (oldAtt.storagePath.startsWith('temp_edited/')) {
          await _deleteTempFile(oldAtt.storagePath);
        } else {
          try {
            await AttachmentStorage.deleteFile(oldAtt.storagePath);
          } catch (_) {
            // Non-fatal cleanup
          }
        }
      }

      // Re-validate after the delete await — the list may have changed
      // while the file work was running.
      if (!mounted ||
          index >= _pendingAttachments.length ||
          _pendingAttachments[index].id != oldAtt.id) {
        return;
      }

      setState(() {
        _pendingAttachments[index] = updatedAtt;
        _pendingImageBytes[updatedAtt.id] = editedBytes;
      });
    } catch (e) {
      debugPrint('[ChatComposer] _updatePendingAttachmentAfterEdit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存编辑后的图片失败'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 根据编辑后的实际字节推断 mimeType（PNG/JPEG 魔数），
  /// 无法识别时保留原 mimeType。
  String _detectEditedImageMimeType(Uint8List bytes, String fallback) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    return fallback;
  }
}
