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
import 'package:stroom/services/chat_protocol.dart';
import 'chat_setting_panels.dart';
import 'chat_file_picker_dialog.dart';
import 'composer_shared.dart';

part 'chat_composer_widget_draft.dart';
part 'chat_composer_widget_attachments.dart';
part 'chat_composer_widget_panels.dart';
part 'chat_composer_widget_build_sections.dart';

/// Tap-region group shared by the composer input and the chat message
/// list. With the app-wide tap-outside blur ([TapOutsideUnfocus]), a tap on
/// the message list while composing would otherwise count as "outside" and
/// unfocus the composer, closing the keyboard the moment the user touches
/// the list to scroll. Grouping the list with the composer keeps the
/// deliberate chat behavior: the keyboard stays up while the user
/// reads/scrolls the list, and is dismissed via the keyboard's own close
/// key or the page's keyboard-dismiss button.
const chatComposerTapRegionGroupId = ValueKey('chat-composer-tap-region');

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

  /// 该对话未发送的附件草稿（按对话隔离，与 [initialDraftText] 一起
  /// 恢复）。图片附件带预压缩 base64（发送零等待），文件附件只带
  /// 引用（恢复时重新读取编码）。
  final List<Attachment> initialDraftAttachments;
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

  /// Whether the data-loss warning should be shown when entering edit mode.
  /// The chat page sets this when the edited message has newer messages
  /// below it (re-sending the edit would delete them). When set, the
  /// warning pill replaces the edit capsule immediately on entry (fading
  /// in), then fades out on auto-hide (2s) or close so the edit capsule
  /// fades back in.
  final bool showEditWarningOnEntry;

  /// Bumped by the chat page on every explicit edit entry
  /// ([ChatPage._startEditMessage]). The composer re-arms the warning when
  /// the count changes even for the same message id, so re-tapping edit on
  /// the message being edited re-shows the warning after a dismissal.
  final int editWarningArmCount;

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
    this.initialDraftAttachments = const [],
    this.onModelsReordered,
    this.reasoningParams = const [],
    this.editingMessageId,
    this.editingMessageText,
    this.editingMessageAttachments,
    this.onEditSend,
    this.onEditCancel,
    this.showEditWarningOnEntry = false,
    this.editWarningArmCount = 0,
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

  // ── Edit data-loss warning state ──
  /// Whether the warning pill is currently shown in the edit capsule's
  /// row. While visible it replaces the edit capsule.
  bool _editWarningVisible = false;

  /// Whether the warning pill is in its fade-out phase: dismissed (auto-
  /// hide or close) but still in the tree until the fade completes, so the
  /// edit capsule fades back in only after the pill is gone.
  bool _editWarningFadingOut = false;

  /// Timer that auto-hides the warning pill after 2 seconds.
  Timer? _editWarningTimer;

  /// Timer that removes the pill from the tree once its fade-out finished.
  Timer? _editWarningFadeOutTimer;

  /// How long the warning stays visible before auto-hiding.
  static const Duration _editWarningAutoHideDelay = Duration(seconds: 2);

  /// How long the pill's fade-out (and the capsule's fade-in) lasts.
  static const Duration _editWarningFadeOutDuration =
      Duration(milliseconds: 200);

  /// How long after dismissal the pill stays in the tree before being
  /// removed: slightly longer than the fade-out, so the removal never
  /// preempts the fade animation (frame jank) and the pill→capsule swap
  /// stays strictly sequential.
  static final Duration _editWarningFadeOutRemovalDelay =
      _editWarningFadeOutDuration + const Duration(milliseconds: 50);

  /// 在途的图片后台预压缩任务（按附件 hash 追踪）。
  ///
  /// 移除/编辑清理磁盘缓存时必须先等对应的预压缩完成，否则会出现
  /// "清理先执行、压缩后写盘"的竞态——缓存文件被删除后又被重新
  /// 创建（对话已删除时还会留下永久孤儿目录）。
  final Map<String, Future<void>> _preCompressFutures = {};

  /// 编辑模式下被移除的原消息附件（缓存推迟到确定重发时清理）。
  ///
  /// 编辑期间用户可能取消编辑：此时移除原附件不能立即删缓存（取消
  /// 后原消息仍引用该附件）；只有点发送（确定重发）时才由
  /// _handleSubmitted 的编辑分支统一清理。编辑时**新加**的附件不在此
  /// 列——它们与普通发送一致，移除即清（见 _removePendingAttachment）。
  final List<Attachment> _removedEditAttachments = [];

  Timer? _draftTimer;

  /// Tracks the last draft text that was saved, so we can avoid redundant
  /// saves when the text hasn't actually changed.
  String _lastSavedDraft = '';

  /// Tracks the last saved attachment-draft signature (per-attachment
  /// id/hash/type), so attachment changes also trigger a draft save even
  /// when the text is unchanged.
  List<String> _lastSavedDraftAttSignature = const [];

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

    // Restore the conversation's unsent attachment draft (if any).
    // Edit mode populates its own attachments below.
    if (widget.editingMessageId == null) {
      _restoreDraftAttachments(widget.initialDraftAttachments);
      _lastSavedDraftAttSignature = _draftAttSignature();
    }

    // If entering edit mode, pre-fill with the message text
    // and pre-populate pending attachments with the original attachments.
    if (widget.editingMessageId != null && widget.editingMessageText != null) {
      _textController.text = widget.editingMessageText!;
      _lastSavedDraft = widget.editingMessageText!;
      _lastHadText = widget.editingMessageText!.trim().isNotEmpty;
      _loadEditingAttachments(widget.editingMessageAttachments);
      // Arm the data-loss warning: the pill replaces the edit capsule on
      // the first build. Safe during initState — no setState, no view
      // access (unlike the removed keyboard-based reveal). No-op unless
      // showEditWarningOnEntry is set.
      _armEditWarning();
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
        // Arm the data-loss warning: it is revealed immediately, replacing
        // the capsule until dismissed (auto-hide or close).
        _armEditWarning();
      } else if (widget.editingMessageId == null &&
          oldWidget.editingMessageId != null) {
        // Edit mode cancelled - clear everything, then restore the current
        // conversation's draft (text + attachments). Covers both plain
        // cancel and the "switched conversation while editing" case (the
        // page clears edit state asynchronously after the history load —
        // the switch branch skipped the restore, this branch does it).
        _draftTimer?.cancel();
        _textController.clear();
        _lastSavedDraft = '';
        _lastSavedDraftAttSignature = const [];
        _lastHadText = false;
        _clearPendingAttachments();
        _disarmEditWarning();
        if (widget.initialDraftText.isNotEmpty) {
          _textController.text = widget.initialDraftText;
          _lastSavedDraft = widget.initialDraftText;
        }
        _lastHadText = _textController.text.trim().isNotEmpty;
        _restoreDraftAttachments(widget.initialDraftAttachments);
        _lastSavedDraftAttSignature = _draftAttSignature();
      }
      return;
    }

    // Re-entry on the SAME message (the edit button tapped again while it
    // is already being edited): the id didn't transition, so re-arm on the
    // page's explicit entry bump — re-shows the warning after a dismissal.
    // Also cancels an in-progress fade-out (re-tap during the fade
    // restarts the countdown instead of letting the pill vanish). When the
    // pill is already fully showing, keep it (avoid a hide/re-show blip);
    // the current auto-hide countdown continues.
    if (widget.editingMessageId != null &&
        widget.editWarningArmCount != oldWidget.editWarningArmCount) {
      if (!_editWarningVisible || _editWarningFadingOut) {
        _armEditWarning();
      }
      return;
    }

    // Detect conversation change: save draft for old conversation,
    // then restore draft for the new one
    if (oldWidget.conversationId != widget.conversationId) {
      // The warning refers to the previous conversation's messages — a
      // stale pill would be misleading after switching conversations.
      _disarmEditWarning();
      // Cancel any pending debounced save to avoid it firing with a stale
      // text value for the wrong conversation after the switch.
      _draftTimer?.cancel();
      // 编辑中切换对话：不保存、不恢复草稿——页面清除编辑态是异步的
      // （历史加载完成后），此帧 editingMessageId 仍非空，保存会把
      // "正在编辑的消息内容"当成旧对话草稿写进去；恢复会把编辑文本
      // 冲掉。页面清除编辑态后由下面的取消分支统一恢复当前对话草稿。
      if (oldWidget.editingMessageId == null) {
        // 保存旧对话草稿（文字 + 附件快照）。必须在恢复新对话**之前**
        // 快照旧内容；且不能在 didUpdateWidget（构建阶段）同步修改
        // provider（Riverpod 调试断言），推迟到帧后执行。
        final oldConvId = oldWidget.conversationId;
        final oldTextSnapshot = _textController.text;
        final oldAttsSnapshot = _draftAttachmentSnapshot();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (oldConvId == null) return;
          try {
            ref.read(conversationsProvider.notifier).saveDraft(
                  oldConvId,
                  oldTextSnapshot,
                  draftAttachments: oldAttsSnapshot,
                );
          } catch (e) {
            // 帧后组件可能已销毁：草稿保存 best-effort
            debugPrint(
                '[ChatComposer] failed to save old-conversation draft: $e');
          }
        });

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
        // 附件草稿同样按对话隔离：切走时已保存旧对话快照，切回时
        // 加载新对话的草稿附件（替换当前 pending）。
        _restoreDraftAttachments(widget.initialDraftAttachments);
        _lastSavedDraftAttSignature = _draftAttSignature();
      }
    }
  }

  /// Arms the edit data-loss warning for the current edit session: the
  /// warning pill replaces the edit capsule immediately on the next build
  /// (the fade-in is handled by the pill's own TweenAnimationBuilder) and
  /// auto-hides after [_editWarningAutoHideDelay].
  ///
  /// No-op unless the page says re-sending the edit can delete messages
  /// below ([ChatComposerWidget.showEditWarningOnEntry]) — but the pill
  /// state is reset in either case, so switching the edit target from a
  /// warned to an unwarned message hides the pill. Called during the build
  /// phase ([initState]/[didUpdateWidget]) only, so it mutates state
  /// directly — the build that follows renders the pill or the capsule.
  void _armEditWarning() {
    _editWarningTimer?.cancel();
    _editWarningFadeOutTimer?.cancel();
    _editWarningVisible = false;
    _editWarningFadingOut = false;
    if (!widget.showEditWarningOnEntry) return;
    _editWarningVisible = true;
    _editWarningTimer = Timer(_editWarningAutoHideDelay, _dismissEditWarning);
  }

  /// Dismisses the warning pill (close button or auto-hide). Dismissing
  /// also disarms: the warning is shown at most once per edit entry
  /// (re-armed only by a new entry bump).
  ///
  /// The pill fades out over [_editWarningFadeOutDuration] before being
  /// removed from the tree (after [_editWarningFadeOutRemovalDelay]), so
  /// the edit capsule only fades back in once the fade-out finished
  /// (sequential, not a cross-fade).
  void _dismissEditWarning() {
    _editWarningTimer?.cancel();
    if (!mounted || !_editWarningVisible || _editWarningFadingOut) return;
    setState(() => _editWarningFadingOut = true);
    _editWarningFadeOutTimer = Timer(_editWarningFadeOutRemovalDelay, () {
      if (!mounted) return;
      setState(() {
        _editWarningVisible = false;
        _editWarningFadingOut = false;
      });
    });
  }

  /// Disarms the warning without a rebuild (called during the build phase
  /// from [didUpdateWidget] when edit mode ends or the conversation
  /// changes; the build that follows renders the capsule again).
  void _disarmEditWarning() {
    _editWarningTimer?.cancel();
    _editWarningFadeOutTimer?.cancel();
    _editWarningVisible = false;
    _editWarningFadingOut = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _editWarningTimer?.cancel();
    _editWarningFadeOutTimer?.cancel();
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
      // The whole composer is part of the composer's tap region group
      // ([chatComposerTapRegionGroupId], shared with the message list): with
      // the app-wide tap-outside blur, tapping the composer's OWN controls
      // (attach / model chip / send / edit capsule) must not unfocus the
      // input — the keyboard stays up while the user adjusts the composer,
      // exactly like it stays up while reading/scrolls the list.
      child: TextFieldTapRegion(
        groupId: chatComposerTapRegionGroupId,
        child: Container(
          key: _composerKey,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border:
                Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
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
              // ── Edit mode capsule / data-loss warning pill ──
              // The warning replaces the capsule in its row while visible;
              // dismissal fades the pill out before the capsule fades back
              // in.
              if (widget.editingMessageId != null)
                _editWarningVisible
                    ? _buildEditWarningPill(
                        cs: cs,
                        fadingOut: _editWarningFadingOut,
                      )
                    : _buildEditModeCapsule(cs: cs),
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
      ),
    );
  }
}

/// A small chip button for the settings row above the composer input.
typedef _SettingsChip = SettingsChip;
