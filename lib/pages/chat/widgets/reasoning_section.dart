import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/widgets/markdown_extensions.dart';

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

/// Reasoning section that shows clickable orange button(s).
///
/// Each reasoning chain gets its own button. When tapped, opens a panel dialog
/// that renders the specific reasoning section's content using MarkdownWidget
/// (same rendering as assistant replies).
///
/// During streaming, the last section shows "推理中" (reasoning in progress).
/// Completed sections show "推理过程" (reasoning process).
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

/// A single clickable reasoning button (orange pill).
class _ReasoningButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = isStreaming ? '推理中' : '推理过程';
    final bgColor =
        isDark ? Colors.orange[900]!.withOpacity(0.2) : Colors.orange[50]!;
    final textColor = Colors.orange[700]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _openReasoningPanel(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_outlined, size: 16, color: textColor),
              const SizedBox(width: 4),
              if (isMulti)
                Text(
                  '推理 ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              if (isMulti) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReasoningPanel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _ReasoningPanelDialog(
        messageId: messageId,
        sectionIndex: index,
        initialReasoningText: reasoningText,
        isStreaming: isStreaming,
      ),
    );
  }
}

/// Dialog panel that displays reasoning content using MarkdownWidget.
///
/// Watches [streamingReasoningSectionsProvider] for live updates — during
/// streaming it shows incremental content for the active section.
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
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _displayText = widget.initialReasoningText;
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

    final showEmpty = _displayText.isEmpty && widget.isStreaming;

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
                  widget.isStreaming ? '推理中' : '推理过程',
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
                if (widget.isStreaming)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange[700],
                    ),
                  ),
                if (widget.isStreaming) const SizedBox(width: 8),
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
          // ── Content ──
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
                : SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }
}
