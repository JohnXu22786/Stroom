import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/widgets/markdown_extensions.dart';
import '../chat_types.dart';

/// Data model for the reasoning sections to display.
/// [texts] is a list of reasoning chain texts, one per reasoning round.
/// [streaming] indicates whether the last section is still being streamed.
/// [sectionIndices] maps each text to its section index for the panel
/// dialog. Must have same length as [texts]. Defaults to [0,1,2,...].
class ReasoningSectionData {
  final List<String> texts;
  final bool streaming;
  final List<int> sectionIndices;

  const ReasoningSectionData({
    required this.texts,
    this.streaming = false,
    this.sectionIndices = const [],
  });
}

/// Reasoning section that shows clickable text line(s).
///
/// Each reasoning chain gets its own line like "思考中 ›" or "思考完成 ›".
/// When tapped, opens a panel dialog that renders the specific reasoning
/// section's content using MarkdownWidget (same rendering as assistant replies).
///
/// During streaming, the last section shows "思考中" (thinking in progress).
/// Completed sections show "思考完成" (thinking complete).
class ReasoningSection extends ConsumerWidget {
  final ReasoningSectionData sections;
  final String messageId;

  const ReasoningSection({
    super.key,
    required this.sections,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Skip empty placeholder texts: ReasoningSectionEndEvent appends an
    // empty '' section for the next round. Rendering it produced phantom
    // "思考完成" buttons whenever a round ended without any visible text
    // (the standard think → tool call pattern), piling them up until the
    // first text token triggered a full re-render.
    final texts = <String>[];
    final indices = <int>[];
    for (var i = 0; i < sections.texts.length; i++) {
      if (sections.texts[i].isEmpty) continue;
      texts.add(sections.texts[i]);
      indices.add(sections.sectionIndices.length == sections.texts.length
          ? sections.sectionIndices[i]
          : i);
    }
    if (texts.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (int i = 0; i < texts.length; i++) {
      children.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i < texts.length - 1 ? 4 : 0,
          ),
          child: _ReasoningButton(
            reasoningText: texts[i],
            // Only mark the last section as streaming when the section
            // actually being streamed is visible: if the trailing raw text
            // is the empty '' placeholder (a round ended, the next one has
            // no content yet), no visible button is streaming — the last
            // sealed section must keep showing "思考完成".
            isStreaming: sections.streaming &&
                i == texts.length - 1 &&
                sections.texts.last.isNotEmpty,
            isMulti: texts.length > 1,
            index: indices[i],
            messageId: messageId,
          ),
        ),
      );
    }

    // If multiple sections, show them in a column
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// A single clickable reasoning text line like "思考中 ›" or "思考完成 ›".
///
/// When streaming, the chevron animates through › ›› ››› at ~333ms intervals.
class _ReasoningButton extends ConsumerStatefulWidget {
  final String reasoningText;
  final bool isStreaming;
  final bool isMulti;
  final int index;
  final String messageId;

  const _ReasoningButton({
    required this.reasoningText,
    required this.isStreaming,
    required this.isMulti,
    required this.index,
    required this.messageId,
  });

  @override
  ConsumerState<_ReasoningButton> createState() => _ReasoningButtonState();
}

class _ReasoningButtonState extends ConsumerState<_ReasoningButton> {
  Timer? _chevronTimer;
  int _chevronCount = 1;

  @override
  void initState() {
    super.initState();
    if (widget.isStreaming) {
      _chevronTimer = Timer.periodic(const Duration(milliseconds: 333), (_) {
        if (mounted) {
          setState(() {
            _chevronCount = _chevronCount >= 3 ? 1 : _chevronCount + 1;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(_ReasoningButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When streaming completes (isStreaming transitions from true to false),
    // cancel the chevron animation timer so the ">>>" animation stops.
    if (oldWidget.isStreaming && !widget.isStreaming) {
      _chevronTimer?.cancel();
      _chevronTimer = null;
      _chevronCount = 0;
    }
  }

  @override
  void dispose() {
    _chevronTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isStreaming ? '思考中' : '思考完成';
    final prefix = widget.isMulti ? '思考 ${widget.index + 1} ' : '';
    final accentColor = Colors.orange[700]!;

    return GestureDetector(
      onTap: () => _openReasoningPanel(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$prefix$label',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
            // Only show animated chevrons (› ›› ›››) when the reasoning
            // section is still being streamed. Completed sections show
            // "思考完成" without any trailing chevrons.
            if (widget.isStreaming) ...[
              const SizedBox(width: 2),
              Text(
                '›' * _chevronCount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: accentColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openReasoningPanel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _ReasoningPanelDialog(
        messageId: widget.messageId,
        sectionIndex: widget.index,
        initialReasoningText: widget.reasoningText,
        isStreaming: widget.isStreaming,
      ),
    );
  }
}

/// Dialog panel that displays reasoning content using MarkdownWidget.
///
/// Watches [streamingReasoningSectionsProvider] for live updates — during
/// streaming it shows incremental content for the active section.
/// Also watches [streamingHasFirstTokenProvider] and [isStreamingProvider]
/// to reactively update the header from "思考中" to "思考完成" when
/// reasoning completes (text content starts arriving or stream ends).
class _ReasoningPanelDialog extends ConsumerStatefulWidget {
  final String messageId;
  final int sectionIndex;
  final String initialReasoningText;
  final bool isStreaming;

  const _ReasoningPanelDialog({
    required this.messageId,
    required this.sectionIndex,
    required this.initialReasoningText,
    required this.isStreaming,
  });

  @override
  ConsumerState<_ReasoningPanelDialog> createState() =>
      _ReasoningPanelDialogState();
}

class _ReasoningPanelDialogState extends ConsumerState<_ReasoningPanelDialog>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _userScrolledUp = false;
  String _displayText = '';
  int _previousTextLength = 0;

  /// Drives the completion sequence for the corner status icon: spinner
  /// fades out (0.5s) → checkmark pops in with a jelly bounce (0.5s) →
  /// holds (1s) → pops out with a jelly shrink (1s, as long as the
  /// fade-out + pop-in process) → corner empty.
  /// Total duration 3s. Both [TweenSequence]s below sum to 120 weight
  /// points (25ms per point) so their phases stay aligned.
  late final AnimationController _completionController;
  late final Animation<double> _spinnerOpacity;
  late final Animation<double> _checkmarkScale;

  /// Whether the first build has been tracked, and the completion state
  /// seen on the previous build. Used to detect completion transitions.
  bool _completionTracked = false;
  bool _prevComplete = false;

  /// Whether the pop animation has been started for the current completion.
  /// A panel opened after completion keeps [false] and shows an empty
  /// corner (the checkmark only plays as the spinner→complete transition);
  /// once a false→true transition is observed this becomes true and the
  /// corner rendering is driven by [_completionController].
  bool _completionAnimated = false;

  static const _spinnerKey = ValueKey('reasoning-corner-spinner');
  static const _checkKey = ValueKey('reasoning-corner-check');

  @override
  void initState() {
    super.initState();
    _displayText = widget.initialReasoningText;
    _previousTextLength = _displayText.length;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _completionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _spinnerOpacity = TweenSequence<double>([
      // Spinner fade-out over the first 0.5s ([0, 500ms]).
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      // Weights sum to 120 so the fade lands exactly on the same
      // 25ms-per-point grid as [_checkmarkScale] (fade ends at 500ms,
      // exactly when the checkmark starts popping in).
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 100),
    ]).animate(_completionController);
    _checkmarkScale = TweenSequence<double>([
      // Not visible during the fade-out.
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
      // Jelly pop-in over 0.5s ([500ms, 1000ms]): elasticOut overshoots
      // past 1.0 (scale > 1) then settles, giving the 果冻弹跳 bounce.
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
      // Hold at full scale for 1s ([1000ms, 2000ms]).
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      // Jelly pop-out over 1s ([2000ms, 3000ms]): as long as the fade-out
      // + pop-in process. elasticOut.flipped shrinks with a wobble and
      // never goes negative (no mirrored blip).
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.elasticOut.flipped)),
        weight: 40,
      ),
    ]).animate(_completionController);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final isAtBottom = (maxScroll - currentScroll) <= 50;
    if (isAtBottom == _userScrolledUp) {
      setState(() => _userScrolledUp = !isAtBottom);
    }
  }

  void _scrollToBottom() {
    _userScrolledUp = false;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final markdownConfig = buildMarkdownConfig(isDark: isDark);

    // Watch all sections from provider and extract the one for this dialog.
    // If the section index is within range, use the provider's version
    // (which may have been updated since the dialog opened).
    final convId = ref.watch(activeConversationIdProvider);
    final allSections = convId != null
        ? ref.watch(streamingReasoningSectionsProvider(convId))
        : const <String>[];
    if (widget.sectionIndex < allSections.length) {
      final providerText = allSections[widget.sectionIndex];
      if (providerText.length >= _displayText.length) {
        _displayText = providerText;
      }
    }

    // Auto-scroll to bottom when new content arrives, unless the user
    // has manually scrolled up (interrupted auto-scroll).
    if (_displayText.length > _previousTextLength) {
      _previousTextLength = _displayText.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_userScrolledUp && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    // Determine reasoning completion state reactively.
    // Reasoning is "complete" when either:
    // 1. A TextEvent has arrived (first token received) while reasoning
    //    content exists, or
    // 2. The stream has ended.
    final hasFirstToken = convId != null
        ? ref.watch(streamingHasFirstTokenProvider(convId))
        : false;
    final isStreamActive =
        convId != null ? ref.watch(isStreamingProvider(convId)) : false;
    final hasReasoningContent = _displayText.isNotEmpty;
    final isReasoningComplete =
        hasReasoningContent && (hasFirstToken || !isStreamActive);

    final showEmpty = _displayText.isEmpty && !isReasoningComplete;

    // Detect completion transitions to drive the corner checkmark sequence.
    // The first build only records the initial state (a panel opened after
    // completion shows an empty corner, no animation). On a false→true
    // transition the sequence plays once; on true→false (a new stream —
    // e.g. the next message — resets hasFirstToken and restarts streaming)
    // the animation resets so the next completion can replay it. Note that
    // additional reasoning rounds within one stream keep the completion
    // state sticky (like the pre-existing "思考完成" header) and do not
    // replay the animation.
    if (!_completionTracked) {
      _completionTracked = true;
      _prevComplete = isReasoningComplete;
    } else if (isReasoningComplete != _prevComplete) {
      _prevComplete = isReasoningComplete;
      if (isReasoningComplete) {
        _completionAnimated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _completionController.forward(from: 0);
        });
      } else {
        _completionAnimated = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _completionController.reset();
        });
      }
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
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
                Icon(
                  Icons.psychology_outlined,
                  size: 20,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Text(
                  isReasoningComplete ? '思考完成' : '思考中',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
                if (widget.sectionIndex > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    ' (${widget.sectionIndex + 1})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.orange[500],
                    ),
                  ),
                ],
                const Spacer(),
                // Corner status icon: the spinner while streaming, then on
                // completion it fades out (0.5s) and a checkmark pops in
                // with a jelly bounce (0.5s), holds 1s, then pops out with
                // a jelly shrink (1s — as long as the fade-out + pop-in
                // process) leaving the corner empty. The checkmark only
                // plays as the spinner→complete transition; a panel opened
                // after completion shows an empty corner. The slot keeps a
                // constant size so the close button never jumps during the
                // sequence.
                SizedBox(
                  width: 21,
                  height: 21,
                  child: AnimatedBuilder(
                    animation: _completionController,
                    builder: (context, _) {
                      final bool showSpinner;
                      final double spinnerOpacity;
                      final double checkScale;
                      if (!isReasoningComplete) {
                        showSpinner = true;
                        spinnerOpacity = 1;
                        checkScale = 0;
                      } else if (_completionAnimated) {
                        showSpinner = _spinnerOpacity.value > 0.001;
                        spinnerOpacity = _spinnerOpacity.value;
                        checkScale = _checkmarkScale.value;
                      } else {
                        // Panel opened after completion: no static
                        // checkmark — the corner stays empty.
                        showSpinner = false;
                        spinnerOpacity = 0;
                        checkScale = 0;
                      }
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (showSpinner)
                            Opacity(
                              key: _spinnerKey,
                              opacity: spinnerOpacity,
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          if (checkScale > 0.001)
                            Transform.scale(
                              key: _checkKey,
                              scale: checkScale,
                              // Scale about the slot center so the jelly
                              // bounce pops in place (原地弹出) instead of
                              // drifting down-right and clipping.
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.check,
                                size: 21,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
          // ── Content (with auto-scroll) ──
          Flexible(
            child: showEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        child: MarkdownWidget(
                          data: _displayText,
                          selectable: true,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          config: markdownConfig,
                          markdownGenerator: markdownGenerator,
                        ),
                      ),
                      // "Jump to bottom" button — only visible when user
                      // has manually scrolled up (interrupted auto-scroll).
                      if (_userScrolledUp)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Material(
                            elevation: 4,
                            shape: const CircleBorder(),
                            color: Colors.orange[700],
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _scrollToBottom,
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.arrow_downward,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
