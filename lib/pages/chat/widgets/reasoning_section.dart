import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/widgets/markdown_extensions.dart';
import '../chat_types.dart';

/// Data model for the reasoning sections to display.
/// [texts] is a list of reasoning chain texts, one per reasoning round.
/// [streaming] indicates whether the last section is still being streamed.
class ReasoningSectionData {
  final List<String> texts;
  final bool streaming;

  const ReasoningSectionData({
    required this.texts,
    this.streaming = false,
  });

  bool get isEmpty => texts.isEmpty;
  bool get hasMultiple => texts.length > 1;
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

  ReasoningSection({
    super.key,
    required this.sections,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sections.isEmpty) return const SizedBox.shrink();

    // If multiple sections, show them in a column
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < sections.texts.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < sections.texts.length - 1 ? 4 : 0,
            ),
            child: _ReasoningButton(
              reasoningText: sections.texts[i],
              isStreaming: sections.streaming && i == sections.texts.length - 1,
              isMulti: sections.hasMultiple,
              index: i,
              messageId: messageId,
            ),
          ),
      ],
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
      _chevronTimer = Timer.periodic(
        const Duration(milliseconds: 333),
        (_) {
          if (mounted) {
            setState(() {
              _chevronCount = _chevronCount >= 3 ? 1 : _chevronCount + 1;
            });
          }
        },
      );
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
    final chevrons = '›' * _chevronCount;
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
            const SizedBox(width: 2),
            Text(
              chevrons,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
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

class _ReasoningPanelDialogState extends ConsumerState<_ReasoningPanelDialog> {
  late ScrollController _scrollController;
  bool _userScrolledUp = false;
  String _displayText = '';
  int _previousTextLength = 0;

  @override
  void initState() {
    super.initState();
    _displayText = widget.initialReasoningText;
    _previousTextLength = _displayText.length;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    final allSections = ref.watch(streamingReasoningSectionsProvider);
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
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }

    // Determine reasoning completion state reactively.
    // Reasoning is "complete" when either:
    // 1. A TextEvent has arrived (first token received) while reasoning
    //    content exists, or
    // 2. The stream has ended.
    final hasFirstToken = ref.watch(streamingHasFirstTokenProvider);
    final isStreamActive = ref.watch(isStreamingProvider);
    final hasReasoningContent = _displayText.isNotEmpty;
    final isReasoningComplete =
        hasReasoningContent && (hasFirstToken || !isStreamActive);

    final showEmpty = _displayText.isEmpty && !isReasoningComplete;

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
                if (!isReasoningComplete)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange[700],
                    ),
                  ),
                if (!isReasoningComplete) const SizedBox(width: 8),
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
