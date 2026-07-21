import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/provider_config.dart' show ReasoningParam;
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/widgets/file_preview.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/widgets/chat_attachment_panel.dart';
import 'package:stroom/widgets/image_preview_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'chat_setting_panels.dart';
import 'chat_file_picker_dialog.dart';
import 'composer_shared.dart';

class ChatComposerWidget extends ConsumerStatefulWidget {
  final void Function(String text, List<Attachment> attachments) onSend;
  final VoidCallback onStop;
  final ValueChanged<Attachment>? onPreviewAttachment;
  final List<ToolDefinition> mcpTools;
  final Set<String> enabledTools;
  final ValueChanged<Set<String>> onEnabledToolsChanged;
  final List<String> modelNames;
  final int selectedModelIndex;
  final ValueChanged<int> onModelSelected;
  final String? conversationId;
  final String initialDraftText;
  final ValueChanged<List<String>>? onModelsReordered;
  final List<ReasoningParam> reasoningParams;

  // ── Edit mode support ──
  /// When non-null, the composer enters edit mode for the given message.
  final String? editingMessageId;

  /// The text to pre-fill when entering edit mode.
  final String? editingMessageText;

  /// The original attachments of the message being edited, pre-populated
  /// in the pending area so the user can see, add, or remove them.
  final List<Attachment>? editingMessageAttachments;

  /// Called when user taps send in edit mode.
  /// Passes the message id, edited text, and all pending attachments
  /// (original + newly added, minus any removed).
  final void Function(
      String messageId, String text, List<Attachment> attachments)? onEditSend;

  /// Called when user taps X on the edit capsule to cancel editing.
  final VoidCallback? onEditCancel;

  const ChatComposerWidget({
    super.key,
    required this.onSend,
    required this.onStop,
    this.onPreviewAttachment,
    this.mcpTools = const [],
    this.enabledTools = const {},
    required this.onEnabledToolsChanged,
    this.modelNames = const [],
    this.selectedModelIndex = 0,
    required this.onModelSelected,
    this.conversationId,
    this.initialDraftText = '',
    this.onModelsReordered,
    this.reasoningParams = const [],
    this.editingMessageId,
    this.editingMessageText,
    this.editingMessageAttachments,
    this.onEditSend,
    this.onEditCancel,
  });

  @override
  ConsumerState<ChatComposerWidget> createState() => ChatComposerWidgetState();
}

class ChatComposerWidgetState extends ConsumerState<ChatComposerWidget>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final List<Attachment> _pendingAttachments = [];
  final Map<String, Uint8List> _pendingImageBytes = {};
  final GlobalKey _composerKey = GlobalKey();

  Timer? _draftTimer;

  /// Tracks the last draft text that was saved, so we can avoid redundant
  /// saves when the text hasn't actually changed.
  String _lastSavedDraft = '';

  /// Tracks the previous send-button enabled state to avoid calling
  /// setState on every keystroke. Only triggers a rebuild when the
  /// send-button state actually transitions (empty ↔ non-empty).
  /// `null` means uninitialized (first call), which always triggers a rebuild.
  bool? _lastHadText;

  /// Whether the current platform is mobile (Android/iOS) where the soft
  /// keyboard should show a "newline" button. On desktop/web, the keyboard
  /// shows a "send" action and Enter is intercepted via [onKeyEvent].
  bool _isMobile(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();

    // Listen to app lifecycle events so drafts are saved even when the
    // app goes to background or is terminated unexpectedly.
    WidgetsBinding.instance.addObserver(this);

    // Restore draft text for the current conversation, if any
    if (widget.initialDraftText.isNotEmpty) {
      _textController.text = widget.initialDraftText;
      _lastSavedDraft = widget.initialDraftText;
    }
    _lastHadText = _textController.text.trim().isNotEmpty;

    // If entering edit mode, pre-fill with the message text
    // and pre-populate pending attachments with the original attachments.
    if (widget.editingMessageId != null && widget.editingMessageText != null) {
      _textController.text = widget.editingMessageText!;
      _lastSavedDraft = widget.editingMessageText!;
      _lastHadText = widget.editingMessageText!.trim().isNotEmpty;
      _loadEditingAttachments(widget.editingMessageAttachments);
    }

    _focusNode.onKeyEvent = (node, event) {
      // Only intercept Enter key for desktop platforms.
      // On mobile, soft keyboard events don't trigger
      // onKeyEvent, so TextInputAction.newline applies.
      if (!_isMobile(context) &&
          event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (isShift) {
          // Shift+Enter: let default behavior insert newline
          return KeyEventResult.ignored;
        } else {
          // Enter without Shift: send the message
          _handleSubmitted(_textController.text);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(ChatComposerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect edit mode change: if editingMessageId changed, update the
    // text field with the new message text and pre-populate attachments.
    // If edit was cancelled (editingMessageId became null), clear everything.
    if (oldWidget.editingMessageId != widget.editingMessageId) {
      _draftTimer?.cancel();
      if (widget.editingMessageId != null &&
          widget.editingMessageText != null) {
        // Entering edit mode (or switching to a different message)
        _textController.text = widget.editingMessageText!;
        _lastSavedDraft = widget.editingMessageText!;
        _lastHadText = widget.editingMessageText!.trim().isNotEmpty;
        // Auto-focus the text field so keyboard appears on mobile
        _focusNode.requestFocus();
        // Pre-populate pending attachments with the original message's
        // attachments, and load image bytes for preview.
        _loadEditingAttachments(widget.editingMessageAttachments);
      } else if (widget.editingMessageId == null &&
          oldWidget.editingMessageId != null) {
        // Edit mode cancelled - clear everything
        _textController.clear();
        _lastSavedDraft = '';
        _lastHadText = false;
        _clearPendingAttachments();
      }
      return;
    }

    // Detect conversation change: save draft for old conversation,
    // then restore draft for the new one
    if (oldWidget.conversationId != widget.conversationId) {
      // Cancel any pending debounced save to avoid it firing with a stale
      // text value for the wrong conversation after the switch.
      _draftTimer?.cancel();
      // Save draft for the old conversation (if any)
      _saveDraftImmediately(oldWidget);

      // Restore draft for the new conversation
      if (widget.initialDraftText.isNotEmpty) {
        _textController.text = widget.initialDraftText;
        _lastSavedDraft = widget.initialDraftText;
        _lastHadText = widget.initialDraftText.trim().isNotEmpty;
      } else {
        _textController.clear();
        _lastSavedDraft = '';
        _lastHadText = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    // Save draft before disposing. Use try-catch because ref may
    // already be disposed during teardown, especially in tests.
    try {
      _saveDraftImmediately(widget);
    } catch (e) {
      // Non-critical: draft is best-effort during disposal.
      // Log unexpected errors so they are visible during development
      // without crashing the app.
      debugPrint('[ChatComposer] failed to save draft on dispose: $e');
    }
    _focusNode.onKeyEvent = null;
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save draft immediately when the app goes to background, is hidden,
    // or is about to be terminated. This ensures unsent text is preserved
    // even if dispose() never runs (e.g. app was killed by OS).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _draftTimer?.cancel();
      _saveDraftImmediately(widget);
    }
  }

  /// Saves the current text as draft for the given widget's conversation,
  /// bypassing the debounce timer.
  void _saveDraftImmediately(ChatComposerWidget w) {
    final convId = w.conversationId;
    if (convId == null) return;
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

  // ═══════════════════════════════════════════════════════════════
  // Settings panels
  // ═══════════════════════════════════════════════════════════════

  void _showModelPanel() {
    showModelPanel(
      context: context,
      models: widget.modelNames,
      selectedModelIndex: widget.selectedModelIndex,
      onModelSelected: widget.onModelSelected,
      onModelsReordered: widget.onModelsReordered,
    );
  }

  void _showToolsPanel() {
    showToolsPanel(
      context: context,
      tools: widget.mcpTools,
      enabledTools: widget.enabledTools,
      onToolToggle: (toolName, enabled) {
        final current = Set<String>.from(widget.enabledTools);
        if (enabled) {
          current.add(toolName);
        } else {
          current.remove(toolName);
        }
        widget.onEnabledToolsChanged(current);
      },
    );
  }

  void _showReasoningPanel() {
    final reasoningEnabled = ref.read(reasoningEnabledProvider);
    final reasoningEffortEnabled = ref.read(reasoningEffortEnabledProvider);
    final reasoningParamValues = ref.read(reasoningParamValuesProvider);
    showReasoningPanel(
      context: context,
      reasoningEnabled: reasoningEnabled,
      reasoningEffortEnabled: reasoningEffortEnabled,
      reasoningParamSelections: reasoningParamValues,
      reasoningParams: widget.reasoningParams,
      onReasoningToggle: (value) {
        ref.read(reasoningEnabledProvider.notifier).state = value;
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setBool('reasoning_enabled', value),
        );
      },
      onReasoningEffortToggle: (value) {
        ref.read(reasoningEffortEnabledProvider.notifier).state = value;
        // Effort toggle state is auto-persisted via the ref.listen in
        // chat_page.dart's _persistCurrentReasoningSettings mechanism.
      },
      onReasoningParamChanged: (paramName, value) {
        final current = Map<String, String>.from(
          ref.read(reasoningParamValuesProvider),
        );
        current[paramName] = value;
        ref.read(reasoningParamValuesProvider.notifier).state = current;
        // Sync reasoningEffortProvider when an effort param changes
        // so the effort value is available for API calls (chat_page sends
        // it via ChatAdapter.sendStreamWithTools).
        final effortParam =
            widget.reasoningParams.cast<ReasoningParam?>().firstWhere(
                  (p) => p?.isEffortParam ?? false,
                  orElse: () => null,
                );
        if (effortParam != null && paramName == effortParam.paramName) {
          ref.read(reasoningEffortProvider.notifier).state = value;
        }
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString('reasoning_params', current.toString()),
        );
      },
    );
  }

  void _showCustomParamsPanel() {
    final reasoningParamValues = ref.read(reasoningParamValuesProvider);
    final reasoningEnabled = ref.read(reasoningEnabledProvider);
    showCustomReasoningParamsPanel(
      context: context,
      reasoningEnabled: reasoningEnabled,
      reasoningParamSelections: reasoningParamValues,
      reasoningParams: widget.reasoningParams,
      onReasoningParamChanged: (paramName, value) {
        final current = Map<String, String>.from(
          ref.read(reasoningParamValuesProvider),
        );
        current[paramName] = value;
        ref.read(reasoningParamValuesProvider.notifier).state = current;
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString('reasoning_params', current.toString()),
        );
      },
    );
  }

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
    // (no save dialog needed for chat page attachments)
    final editedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => ExtendedImageEditorPage(
          imageBytes: imageBytes,
          fileName: att.fileName,
        ),
      ),
    );

    if (editedBytes == null || !mounted) return;
    if (index >= _pendingAttachments.length) return;
    // Verify the attachment at this index is still the same one we tapped
    if (_pendingAttachments[index].id != att.id) return;

    // Editor returned edited bytes — update the pending attachment
    await _updatePendingAttachmentAfterEdit(index, editedBytes);
  }

  /// Updates the pending attachment at [index] with [editedBytes].
  /// Saves the edited file to temp cache (does NOT overwrite the original).
  /// Updates both [_pendingAttachments] and [_pendingImageBytes].
  Future<void> _updatePendingAttachmentAfterEdit(
    int index,
    Uint8List editedBytes,
  ) async {
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

      // Clean up old temp file if it was also a temp edit
      if (oldAtt.storagePath.startsWith('temp_edited/')) {
        _deleteTempFile(oldAtt.storagePath);
      } else {
        // Delete the old non-temp storage file (original attachment copy)
        try {
          await AttachmentStorage.deleteFile(oldAtt.storagePath);
        } catch (_) {
          // Non-fatal cleanup
        }
      }

      // Update attachment with new temp-stored properties
      final updatedAtt = oldAtt.copyWith(
        hash: newHash,
        storagePath: tempStoragePath,
        fileSize: editedBytes.length,
        base64Data: newBase64,
      );

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

  @override
  Widget build(BuildContext context) {
    final isStreaming = ref.watch(isStreamingProvider);
    final hasText = _textController.text.trim().isNotEmpty;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final reasoningEnabled = ref.watch(reasoningEnabledProvider);
    final reasoningEffortEnabled = ref.watch(reasoningEffortEnabledProvider);
    final reasoningParamValues = ref.watch(reasoningParamValuesProvider);

    // Find the effort param (isEffortParam=true) from widget.reasoningParams
    final effortParam =
        widget.reasoningParams.cast<ReasoningParam?>().firstWhere(
              (p) => p?.isEffortParam ?? false,
              orElse: () => null,
            );

    // Determine reasoning chip label and color based on reasoning state.
    // When reasoning is enabled AND effort toggle is on AND a value has been
    // selected for the effort param: show that value (e.g. "high", "low").
    // Otherwise: show "推理" (purple when enabled, grey when disabled).
    final String reasoningLabel;
    if (reasoningEnabled &&
        reasoningEffortEnabled &&
        effortParam != null &&
        reasoningParamValues.containsKey(effortParam.paramName)) {
      reasoningLabel = reasoningParamValues[effortParam.paramName]!;
    } else {
      reasoningLabel = '推理';
    }
    final reasoningColor = reasoningEnabled ? Colors.purple : Colors.grey;

    // ═══════════════════════════════════════════════════════════
    // Tool chip & custom params chip: unified accent color
    // ═══════════════════════════════════════════════════════════
    // When the "灵歌" tool is enabled, both chips turn grey and
    // hide their badge (matching the reasoning disabled state).
    const Color toolAccentColor = Color(0xFF6366F1);
    const String lingeToolName = '灵歌';
    final bool isLingeEnabled = widget.enabledTools.contains(lingeToolName);

    // Tool chip
    final Color toolColor = isLingeEnabled ? Colors.grey : toolAccentColor;
    final int? toolBadgeCount =
        isLingeEnabled ? null : widget.enabledTools.length;

    // Custom params chip — count non-toggle, non-effort params with values
    final int customParamsBadgeCount = widget.reasoningParams
        .where((p) => !p.isReasoningToggle && !p.isEffortParam)
        .where((p) => reasoningParamValues.containsKey(p.paramName))
        .length;
    final Color customParamsColor =
        isLingeEnabled ? Colors.grey : toolAccentColor;
    final int? customParamsBadgeCountOrNull = isLingeEnabled
        ? null
        : (customParamsBadgeCount > 0 ? customParamsBadgeCount : null);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: _composerKey,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pending attachments row (reorderable) ──
            if (hasAttachments)
              Container(
                height: 80,
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  itemCount: _pendingAttachments.length,
                  onReorderItem: _onReorderPendingAttachment,
                  itemBuilder: (ctx, i) {
                    final att = _pendingAttachments[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('pending_att_${att.id}'),
                      index: i,
                      child: FilePreviewChip(
                        attachment: att,
                        imageBytes: _pendingImageBytes[att.id],
                        onRemove: () => _removePendingAttachment(i),
                        onTap: () => _onTapPendingAttachment(i),
                      ),
                    );
                  },
                ),
              ),

            // ── Settings row (model, tools, reasoning) ──
            // Uses Wrap so tags use their natural width and flow to the next
            // line when they don't fit side-by-side. ModelNameChip is constrained
            // to at most the full row width so its internal Flexible can
            // truncate text properly. Tools and reasoning chips use natural
            // width since their labels are short and fixed.
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: hasAttachments ? 0 : 6,
                bottom: 0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Leave 4px horizontal margin for "留边" within the settings area.
                  final maxTagWidth = constraints.maxWidth - 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxTagWidth),
                        child: ModelNameChip(
                          displayName: (widget.modelNames.isNotEmpty &&
                                  widget.selectedModelIndex >= 0 &&
                                  widget.selectedModelIndex <
                                      widget.modelNames.length)
                              ? widget.modelNames[widget.selectedModelIndex]
                              : '',
                          color: Colors.teal,
                          onTap: _showModelPanel,
                        ),
                      ),
                      _SettingsChip(
                        icon: Icons.build_outlined,
                        label: '工具',
                        color: toolColor,
                        onTap: _showToolsPanel,
                        badgeCount: toolBadgeCount,
                      ),
                      _SettingsChip(
                        icon: Icons.psychology_outlined,
                        label: reasoningLabel,
                        color: reasoningColor,
                        onTap: _showReasoningPanel,
                        enabled: true,
                      ),
                      // Custom reasoning params button — always visible regardless
                      // of whether custom params are configured. When no
                      // non-toggle/non-effort params exist, the button opens
                      // a panel that explains "当前模型未配置自定义推理参数".
                      _SettingsChip(
                        icon: Icons.tune,
                        label: '自定义参数',
                        color: customParamsColor,
                        onTap: _showCustomParamsPanel,
                        enabled: true,
                        badgeCount: customParamsBadgeCountOrNull,
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Edit mode capsule ──
            if (widget.editingMessageId != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 6,
                  bottom: 0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: 14,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '编辑消息',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: widget.onEditCancel,
                        // Add padding around the close icon for a larger
                        // touch target on mobile.
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Input row ──
            Padding(
              padding: EdgeInsets.only(
                left: 4,
                right: 4,
                top: 4,
                bottom: 8 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    tooltip: '附件',
                    onPressed: _showAttachmentPicker,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      textInputAction: _isMobile(context)
                          ? TextInputAction.newline
                          : TextInputAction.send,
                      onSubmitted: null,
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            cs.surfaceContainerHigh.withValues(alpha: 0.8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.fullscreen,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                          tooltip: '全屏编辑',
                          onPressed: _showComposerFullscreenEditor,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isStreaming)
                    IconButton(
                      icon: Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.red[400],
                      ),
                      tooltip: '停止生成',
                      onPressed: widget.onStop,
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.send_rounded, color: cs.primary),
                      tooltip: '发送',
                      onPressed: (hasText || hasAttachments)
                          ? () => _handleSubmitted(_textController.text)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small chip button for the settings row above the composer input.
typedef _SettingsChip = SettingsChip;
