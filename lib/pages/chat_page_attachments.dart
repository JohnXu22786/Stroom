part of 'chat_page.dart';

extension _ChatPageAttachmentsExt on _ChatPageState {
  Widget _buildMessageAttachmentPreview(Attachment att) {
    return MessageAttachmentPreview(
      attachment: att,
      onTap: () => _showAttachmentPreview(att),
    );
  }

  /// Returns true if the attachment is a text-based file that can be
  /// previewed by reading its content as UTF-8 text.
  bool _isTextAttachment(Attachment att) {
    // Check mime type for text
    if (att.mimeType.startsWith('text/')) return true;
    // Check common text file extensions
    final ext = p.extension(att.fileName).toLowerCase();
    const textExtensions = {
      '.txt',
      '.md',
      '.json',
      '.xml',
      '.csv',
      '.html',
      '.htm',
      '.css',
      '.js',
      '.ts',
      '.dart',
      '.py',
      '.yaml',
      '.yml',
      '.toml',
      '.ini',
      '.cfg',
      '.conf',
      '.log',
      '.sh',
      '.bat',
      '.ps1',
      '.sql',
      '.rb',
      '.php',
      '.java',
      '.cpp',
      '.c',
      '.h',
      '.hpp',
      '.rs',
      '.go',
      '.swift',
      '.kt',
      '.gradle',
      '.properties',
      '.env',
      '.gitignore',
      '.dockerfile',
      '.makefile',
    };
    if (textExtensions.contains(ext)) return true;
    return false;
  }

  /// Returns true if the attachment is a PDF file.
  bool _isPdfAttachment(Attachment att) {
    if (att.mimeType == 'application/pdf') return true;
    return p.extension(att.fileName).toLowerCase() == '.pdf';
  }

  void _showAttachmentPreview(Attachment att) async {
    // 图片附件：立即弹出预览对话框，字节由 dataLoader 在对话框内异步
    // 加载 —— 大图（数 MB）不再阻塞弹窗前读盘，这是预览卡顿的来源
    if (att.fileType == 'image') {
      showImagePreviewDialog(
        context: context,
        fileName: att.fileName,
        dataLoader: () => AttachmentStorage.readFile(att.storagePath),
      );
      return;
    }

    final data = await AttachmentStorage.readFile(att.storagePath);
    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法加载文件')));
      }
      return;
    }
    if (!mounted) return;
    final isText = _isTextAttachment(att);
    final isPdf = _isPdfAttachment(att);
    final isAudio = att.fileType == 'audio';
    final isVideo = att.fileType == 'video';

    if (isText) {
      _showTextPreview(att, data);
    } else if (isPdf) {
      _showPdfPreview(att, data);
    } else if (isAudio) {
      _showAudioPreview(att, data);
    } else if (isVideo) {
      _showVideoPreview(att, data);
    } else {
      _showFileInfoPreview(att);
    }
  }

  /// Full-screen dark preview for non-image files (documents, audio, video).
  /// Shows file icon, name, type, size, and action buttons.
  void _showFileInfoPreview(Attachment att) {
    showFileInfoPreviewDialog(context: context, attachment: att);
  }

  /// Text content preview — shows the full file content in a scrollable
  /// dialog with selectable text. Supports all common text-based formats
  /// (txt, md, json, code files, etc.).
  void _showTextPreview(Attachment att, Uint8List data) {
    String content;
    try {
      content = utf8.decode(data);
    } catch (e) {
      debugPrint('[ChatPage] Text preview decode failed: $e');
      _showFileInfoPreview(att);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with file name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      att.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            // Scrollable text content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PDF preview — attempts to open the PDF using the system's default
  /// PDF viewer via [url_launcher]. Falls back to file info dialog if
  /// the launcher is unavailable.
  Future<void> _showPdfPreview(Attachment att, Uint8List data) async {
    try {
      // Try to save to a temp file and open with system handler
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, att.fileName));
      await tempFile.writeAsBytes(data);
      final uri = Uri.file(tempFile.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[ChatPage] PDF preview failed: $e');
    }
    // Fallback: show file info
    if (mounted) _showFileInfoPreview(att);
  }

  /// Audio preview — opens a dialog with an audio player powered by
  /// [just_audio]. The user can play/pause the audio file.
  Future<void> _showAudioPreview(Attachment att, Uint8List data) async {
    // Save bytes to a temp file for the audio player
    String? filePath;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, att.fileName));
      await tempFile.writeAsBytes(data);
      filePath = tempFile.path;
    } catch (e) {
      debugPrint('[ChatPage] Audio preview temp file failed: $e');
      if (mounted) _showFileInfoPreview(att);
      return;
    }

    if (!mounted) return;
    // Show audio player dialog
    showDialog(
      context: context,
      builder: (ctx) =>
          AudioPreviewDialog(filePath: filePath!, fileName: att.fileName),
    );
  }

  /// Video preview — opens a dialog with a Chewie + fvp video player.
  Future<void> _showVideoPreview(Attachment att, Uint8List data) async {
    // Save bytes to a temp file for the video player
    String? filePath;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, att.fileName));
      await tempFile.writeAsBytes(data);
      filePath = tempFile.path;
    } catch (e) {
      debugPrint('[ChatPage] Video preview temp file failed: $e');
      if (mounted) _showFileInfoPreview(att);
      return;
    }

    if (!mounted) return;
    // Show video player dialog
    showDialog(
      context: context,
      builder: (ctx) =>
          VideoPreviewDialog(filePath: filePath!, fileName: att.fileName),
    );
  }
}
