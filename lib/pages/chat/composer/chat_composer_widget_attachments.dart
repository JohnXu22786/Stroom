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
      // 选中即后台预压缩：发送时不再等待（isolate 中执行，不阻塞 UI）
      unawaited(_preCompressPendingImage(att, bytes));
    }
    setState(() {
      _pendingAttachments.add(att);
    });
    // 附件变化触发草稿保存（文字未变时原有 skip 逻辑靠签名识别）
    _scheduleDraftSave();
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

  /// 图片选中后立即后台预压缩（isolate 执行，不占用前台资源）。
  ///
  /// 结果写入 [Attachment.base64Data]（内存）与磁盘缓存
  /// （`temp_compressed/<conversationId>/<hash>`，按对话隔离），发送路径
  /// 直接复用、发送时零压缩等待；用户未发出即移除时由
  /// [_removePendingAttachment] 清理缓存文件。压缩结果只作用于"选中
  /// 时的那一份字节"：附件随后被编辑（hash 变化）时旧结果自然失效，
  /// 编辑产物会由 [_updatePendingAttachmentAfterEdit] 重新触发预压缩。
  /// 失败静默忽略（发送路径会按需重新压缩兜底）。
  ///
  /// 同名 hash 的多次调用（重复选中同一张图）会被串成链条：地图里的
  /// 条目永远代表"该 hash 最后一次写入"之前的全部任务，清理路径
  /// await 它即保证先于所有在途写入执行。
  Future<void> _preCompressPendingImage(Attachment att, Uint8List bytes) async {
    final convIdAtStart = widget.conversationId;
    final task = _preCompressImage(att, bytes, convIdAtStart);
    final prev = _preCompressFutures[att.hash];
    final chained = (prev ?? Future<void>.value()).then((_) => task);
    _preCompressFutures[att.hash] = chained;
    try {
      await chained;
    } finally {
      // 仅当仍指向本次链条时移除，避免清除后续同名 hash 的任务
      if (identical(_preCompressFutures[att.hash], chained)) {
        _preCompressFutures.remove(att.hash);
      }
    }
  }

  Future<void> _preCompressImage(
      Attachment att, Uint8List bytes, String? convIdAtStart) async {
    try {
      await preCompressImageForPendingAttachment(
        att,
        bytes,
        maxBytes: imageCompressThresholdBytes,
        conversationId: convIdAtStart,
        // 压缩耗时期间附件可能已被移除/编辑/对话已切换/对话已删除：
        // 写入磁盘缓存前再次确认，避免复活已被清理的缓存。
        isStillRelevant: () =>
            mounted &&
            _pendingAttachments.contains(att) &&
            widget.conversationId == convIdAtStart &&
            // 对话已不存在（删除对话时缓存目录整目录清理）→ 不再写盘
            (convIdAtStart == null ||
                ref
                    .read(conversationsProvider)
                    .any((c) => c.id == convIdAtStart)),
      );
    } catch (e) {
      debugPrint('[ChatComposer] 图片后台预压缩失败: $e');
    }
  }

  /// 等该 hash 的在途预压缩完成后删除其磁盘压缩缓存。
  ///
  /// 防止竞态：移除/编辑触发的清理若先于在途压缩执行，缓存文件会被
  /// 压缩任务重新创建（在对话已删除时成为永久孤儿）。
  Future<void> _deleteCompressedCacheAfterPreCompress(Attachment att) async {
    final inflight = _preCompressFutures[att.hash];
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {
        // 预压缩失败也会完成（内部已兜底），这里仅需等待时序
      }
    }
    await _deleteCompressedCache(att);
  }

  /// Best-effort 删除附件的磁盘压缩缓存（派生缓存，删除永远安全）。
  Future<void> _deleteCompressedCache(Attachment att) async {
    try {
      await AttachmentStorage.deleteCompressedImage(
        conversationId: att.conversationId ?? widget.conversationId,
        hash: att.hash,
      );
    } catch (_) {
      // 非关键清理
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
    // 磁盘压缩缓存清理时机：
    // - 普通模式（非编辑）：待发附件已被移除、无人引用，立即清理。
    // - 编辑模式 + 本次新加的附件：与普通发送一致，立即清理。
    // - 编辑模式 + 原消息附件：**不立即清理**——用户可能取消编辑，
    //   原消息仍引用该附件；确定重发时（_handleSubmitted 编辑分支）
    //   再统一清理。
    final isOriginalEditAttachment = widget.editingMessageId != null &&
        (widget.editingMessageAttachments?.any((a) => a.id == att.id) ?? false);
    if (isOriginalEditAttachment) {
      _removedEditAttachments.add(att);
    } else {
      unawaited(_deleteCompressedCacheAfterPreCompress(att));
    }
    setState(() {
      _pendingAttachments.removeAt(index);
    });
    // 附件变化触发草稿保存（文字未变时原有 skip 逻辑靠签名识别）
    _scheduleDraftSave();
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
    // 草稿快照保留列表顺序：重排后必须保存，否则恢复时顺序复原
    _scheduleDraftSave();
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
        // 旧字节的压缩缓存一并清理（hash 已变，旧缓存成为孤儿）。
        // 等旧 hash 在途的预压缩完成后删除，防止它复活旧缓存。
        await _deleteCompressedCacheAfterPreCompress(oldAtt);
      } else if (widget.editingMessageAttachments
              ?.any((a) => a.id == oldAtt.id) ??
          false) {
        // 编辑模式 + 原消息附件被编辑：旧字节缓存同样推迟到确定重发
        // 时清理（可能取消编辑，原消息仍引用旧字节）。
        _removedEditAttachments.add(oldAtt);
      } else {
        // 编辑模式 + 本次新加附件被编辑：与普通发送一致，立即清理。
        await _deleteCompressedCacheAfterPreCompress(oldAtt);
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
      // 编辑后的图片同样立即后台预压缩（发送时零等待）
      unawaited(_preCompressPendingImage(updatedAtt, editedBytes));
      // 附件变化触发草稿保存
      _scheduleDraftSave();
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
