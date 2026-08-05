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
    // Clean up temp file if it exists
    if (att.storagePath.startsWith('temp_edited/')) {
      _deleteTempFile(att.storagePath);
    }
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  /// Delete a temp file from the cache directory.
  Future<void> _deleteTempFile(String tempStoragePath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final name = tempStoragePath.replaceFirst('temp_edited/', '');
      final file = File('${tempDir.path}/$name');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Non-critical cleanup
    }
  }

  /// Reorder handler for [ReorderableListView].
  /// Adjusts indices per ReorderableListView convention:
  /// when [newIndex] > [oldIndex], subtract 1 because the item is already
  /// removed from its old position before being inserted at newIndex.
  void _onReorderPendingAttachment(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExtendedImageEditorPage(
          imageBytes: imageBytes,
          fileName: att.fileName,
          onProcessed: (result) async {
            if (result is! QuickEditProcessingSuccess) return;
            if (!mounted) return;
            if (index >= _pendingAttachments.length) return;
            // Verify the attachment at this index is still the same one
            // we tapped
            if (_pendingAttachments[index].id != att.id) return;

            // Editor delivered edited bytes — update the pending attachment
            await _updatePendingAttachmentAfterEdit(index, result.editedBytes);
          },
        ),
      ),
    );
  }

  /// Updates the pending attachment at [index] with [editedBytes].
  /// Saves the edited file to temp cache (does NOT overwrite the original).
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
      // Save edited file to temp cache directory instead of permanent storage
      final tempDir = await getTemporaryDirectory();
      final tempFileName =
          'edited_${DateTime.now().millisecondsSinceEpoch}_${oldAtt.fileName}';
      final tempFile = File('${tempDir.path}/$tempFileName');
      await tempFile.writeAsBytes(editedBytes);

      // Track as a temp-edited file
      final tempStoragePath = 'temp_edited/$tempFileName';
      final newHash = AttachmentStorage.computeHash(editedBytes);
      final newBase64 = base64Encode(editedBytes);

      // Update attachment with new temp-stored properties
      final updatedAtt = oldAtt.copyWith(
        hash: newHash,
        storagePath: tempStoragePath,
        fileSize: editedBytes.length,
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

      // Clean up old temp file if it was also a temp edit
      if (oldAtt.storagePath.startsWith('temp_edited/')) {
        _deleteTempFile(oldAtt.storagePath);
      } else if (widget.editingMessageId == null) {
        // 普通模式：新选附件编辑后，旧永久文件不再被任何消息引用
        // （仅存在于 _pendingAttachments），清理孤儿文件。
        try {
          await AttachmentStorage.deleteFile(oldAtt.storagePath);
        } catch (_) {
          // Non-fatal cleanup
        }
      } else {
        // 编辑模式：附件可能引用原消息的永久文件，**不删除**——
        // 删除会让原消息附件悬空（取消编辑后气泡加载失败）。
        // 孤儿文件由 _deleteMessage 的 isReferencedElsewhere 检查
        // 在真正删除消息时清理。
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
}
