import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/provider_config.dart' show ReasoningParam;
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/pages/camera_page.dart';
import 'package:stroom/widgets/camera_choice_dialog.dart';
import 'package:stroom/widgets/gallery_choice_dialog.dart';
import 'package:stroom/widgets/file_preview.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/widgets/chat_attachment_panel.dart';
import 'package:stroom/models/tool_call.dart';
import 'chat_setting_panels.dart';
import 'app_album_picker_dialog.dart';
import 'app_file_picker_dialog.dart';

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
  final ValueChanged<List<String>>? onModelsReordered;
  final List<ReasoningParam> reasoningParams;
  final bool hasReasoningParams;

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
    this.onModelsReordered,
    this.reasoningParams = const [],
    this.hasReasoningParams = false,
  });

  @override
  ConsumerState<ChatComposerWidget> createState() => ChatComposerWidgetState();
}

class ChatComposerWidgetState extends ConsumerState<ChatComposerWidget> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final List<Attachment> _pendingAttachments = [];
  final Map<String, Uint8List> _pendingImageBytes = {};
  final GlobalKey _composerKey = GlobalKey();

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
  void dispose() {
    _focusNode.onKeyEvent = null;
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) return;
    widget.onSend(text.trim(), [..._pendingAttachments]);
    _pendingAttachments.clear();
    _pendingImageBytes.clear();
    _textController.clear();
  }

  void _showComposerFullscreenEditor() {
    final editingController =
        TextEditingController(text: _textController.text);
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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      // Preserve content back to the main input field
                      // instead of discarding it.
                      _textController.text = editingController.text;
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
    final reasoningParamValues = ref.read(reasoningParamValuesProvider);
    showReasoningPanel(
      context: context,
      reasoningEnabled: reasoningEnabled,
      reasoningParamSelections: reasoningParamValues,
      reasoningParams: widget.reasoningParams,
      onReasoningToggle: (value) {
        ref.read(reasoningEnabledProvider.notifier).state = value;
        SharedPreferences.getInstance()
            .then((prefs) => prefs.setBool('reasoning_enabled', value));
      },
      onReasoningParamChanged: (paramName, value) {
        final current = Map<String, String>.from(
            ref.read(reasoningParamValuesProvider));
        current[paramName] = value;
        ref.read(reasoningParamValuesProvider.notifier).state = current;
        SharedPreferences.getInstance().then((prefs) =>
            prefs.setString('reasoning_params', current.toString()));
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
      onPickFromGallery: _showGalleryPicker,
      onPickFromFilePicker: _pickFromFilePicker,
      onPickFromAppFiles: _pickFromAppFiles,
    );
  }

  void _showGalleryPicker() {
    showGalleryChoiceDialog(context).then((result) {
      if (result == null) return;
      if (result.choice == GalleryChoice.system) {
        _pickFromGallery();
      } else {
        _pickFromAppAlbum();
      }
    });
  }

  /// Pick from app's internal album (ImageManifest) — legacy single-type picker.
  Future<void> _pickFromAppAlbum() async {
    try {
      final result = await showAppAlbumPickerDialog(context);
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
    final choice = await showCameraChoiceDialog(
      context,
      showFolderSection: false,
    );
    if (choice == null) return;
    try {
      if (choice.choice == CameraChoice.app) {
        final result =
            await Navigator.of(context, rootNavigator: true).push<String>(
          MaterialPageRoute(builder: (_) => const CameraPage()),
        );
        if (result != null && result.isNotEmpty) {
          final file = File(result);
          final bytes = await file.readAsBytes();
          final fileName = result.split(RegExp(r'[/\\]')).last;
          await _addPendingAttachment(fileName, bytes);
        }
      } else {
        final picker = ImagePicker();
        final file = await picker.pickImage(source: ImageSource.camera);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        await _addPendingAttachment(file.name, bytes);
      }
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

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        await _addPendingAttachment(file.name, bytes);
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

  Future<void> _addPendingAttachment(
      String fileName, Uint8List bytes) async {
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
    // Only cache for images (which need base64 for API calls) and
    // text files (which may be sent inline).
    final String? base64Data;
    if (fileType == 'image') {
      base64Data = base64Encode(bytes);
    } else {
      // For non-image files, base64 is not needed for API calls
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
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = ref.watch(isStreamingProvider);
    final hasText = _textController.text.trim().isNotEmpty;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: _composerKey,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pending attachments row ──
            if (hasAttachments)
              Container(
                height: 80,
                padding: const EdgeInsets.only(left: 12, top: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingAttachments.length,
                  itemBuilder: (ctx, i) {
                    final att = _pendingAttachments[i];
                    return FilePreviewChip(
                      attachment: att,
                      imageBytes: _pendingImageBytes[att.id],
                      onRemove: () => _removePendingAttachment(i),
                      onTap: widget.onPreviewAttachment != null
                          ? () => widget.onPreviewAttachment!(att)
                          : null,
                    );
                  },
                ),
              ),

            // ── Settings row (model, tools, reasoning) ──
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: hasAttachments ? 0 : 6,
                bottom: 0,
              ),
              child: Row(
                children: [
                  _SettingsChip(
                    icon: Icons.smart_toy_outlined,
                    label: '模型',
                    color: Colors.teal,
                    onTap: _showModelPanel,
                  ),
                  const SizedBox(width: 8),
                  _SettingsChip(
                    icon: Icons.build_outlined,
                    label: '工具',
                    color: cs.tertiary,
                    onTap: _showToolsPanel,
                  ),
                  const SizedBox(width: 8),
                  _SettingsChip(
                    icon: Icons.psychology_outlined,
                    label: '推理',
                    color: Colors.purple,
                    onTap: widget.hasReasoningParams
                        ? _showReasoningPanel
                        : null,
                    enabled: widget.hasReasoningParams,
                  ),
                ],
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
                    icon:
                        Icon(Icons.attach_file_outlined, color: cs.onSurfaceVariant),
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
                      onChanged: (_) => setState(() {}),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHigh.withOpacity(0.8),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.fullscreen,
                              size: 20, color: cs.onSurfaceVariant),
                          tooltip: '全屏编辑',
                          onPressed: _showComposerFullscreenEditor,
                        ),
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 36, minHeight: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (isStreaming)
                    IconButton(
                      icon: Icon(Icons.stop_circle_outlined,
                          color: Colors.red[400]),
                      tooltip: '停止生成',
                      onPressed: widget.onStop,
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.send_rounded, color: cs.primary),
                      tooltip: '发送',
                      onPressed: (hasText || hasAttachments)
                          ? () =>
                              _handleSubmitted(_textController.text)
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
class _SettingsChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingsChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = !enabled;
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withOpacity(0.08)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withOpacity(0.1)
                : color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isDisabled
                    ? Colors.grey.withOpacity(0.4)
                    : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDisabled
                    ? Colors.grey.withOpacity(0.4)
                    : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
