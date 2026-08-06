import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/providers/provider_config.dart'
    show ReasoningParam, findEffortParam;
import 'package:stroom/providers/chat_stream_provider.dart';
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

part 'chat_composer_widget_draft.dart';
part 'chat_composer_widget_attachments.dart';
part 'chat_composer_widget_panels.dart';
part 'chat_composer_widget_build_sections.dart';

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

  /// Called when the input field gains/loses focus. The chat page uses the
  /// gain event to react to the tap immediately — before the soft-keyboard
  /// animation starts — so the message list shifts up without the usual
  /// delay.
  final ValueChanged<bool>? onFocusChanged;

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
    this.onFocusChanged,
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

  /// Number of quick image edits still processing in the background.
  /// While non-zero, sending is blocked — the pending attachments still
  /// hold the unedited bytes until the edit callback applies them.
  int _editsInFlight = 0;

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

    // Notify the chat page the moment the input gains/loses focus so it can
    // react to the tap before the soft-keyboard animation starts.
    _focusNode.addListener(_onFocusChanged);

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
          // Enter without Shift: send the message.
          // Guard against streaming — the send IconButton is hidden
          // during streaming, but the keyboard Enter path has no
          // such guard and could double-append user messages if the
          // user presses Enter rapidly in the brief window between
          // _onMessageSend's guard and isStreamingProvider == true.
          final streamingConvs = ref.read(streamingConversationsProvider);
          if (widget.conversationId == null ||
              !streamingConvs.contains(widget.conversationId)) {
            _handleSubmitted(_textController.text);
          }
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

  /// Forwards focus changes (with the current focus state) to the page.
  void _onFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
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

  @override
  Widget build(BuildContext context) {
    final streamingConvs = ref.watch(streamingConversationsProvider);
    final isStreaming = widget.conversationId != null &&
        streamingConvs.contains(widget.conversationId);
    final hasText = _textController.text.trim().isNotEmpty;
    final hasAttachments = _pendingAttachments.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

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
            if (hasAttachments) _buildPendingAttachmentsRow(),
            // ── Settings row (model, tools, reasoning) ──
            _buildChipsSettingsRow(
              cs: cs,
              hasAttachments: hasAttachments,
            ),
            // ── Edit mode capsule ──
            if (widget.editingMessageId != null) _buildEditModeCapsule(cs: cs),
            // ── Quick-edit processing banner ──
            if (_editsInFlight > 0) _buildProcessingBanner(cs: cs),
            // ── Input row ──
            _buildInputRow(
              cs: cs,
              isStreaming: isStreaming,
              hasText: hasText,
              hasAttachments: hasAttachments,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small chip button for the settings row above the composer input.
typedef _SettingsChip = SettingsChip;
