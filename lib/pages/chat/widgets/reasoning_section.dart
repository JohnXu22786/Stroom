import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:stroom/providers/chat_stream_provider.dart';
import 'package:stroom/widgets/markdown_extensions.dart';

/// Reasoning section that shows a clickable orange button.
///
/// When tapped, opens a panel dialog that renders the reasoning content
/// using the MarkdownWidget (same rendering as assistant replies).
///
/// During streaming, shows "推理中" (reasoning in progress) button.
/// After streaming completes and reasoning content is available, shows
/// "推理过程" (reasoning process) button.
class ReasoningSection extends ConsumerWidget {
  final String reasoningText;
  final bool isStreaming;
  final String messageId;

  ReasoningSection({
    super.key,
    required this.reasoningText,
    this.isStreaming = false,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = isStreaming ? '推理中' : '推理过程';
    final bgColor =
        isDark ? Colors.orange[900]!.withOpacity(0.2) : Colors.orange[50]!;
    final textColor = Colors.orange[700]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
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
      ),
    );
  }

  /// Track whether a dialog is already open to prevent stacking.
  bool _dialogOpen = false;

  void _openReasoningPanel(BuildContext context, WidgetRef ref) {
    if (_dialogOpen) return;
    _dialogOpen = true;
    showDialog(
      context: context,
      builder: (ctx) => _ReasoningPanelDialog(
        messageId: messageId,
        initialReasoningText: reasoningText,
        isStreaming: isStreaming,
      ),
    ).then((_) {
      _dialogOpen = false;
    });
  }
}

/// Dialog panel that displays reasoning content using MarkdownWidget.
///
/// Always watches [streamingReasoningProvider] for live updates — during
/// streaming it shows incremental content, after streaming it falls back
/// to the message's persisted [initialReasoningText]. The provider content
/// takes precedence when non-empty (covers both streaming and final state).
class _ReasoningPanelDialog extends ConsumerStatefulWidget {
  final String messageId;
  final String initialReasoningText;
  final bool isStreaming;

  const _ReasoningPanelDialog({
    required this.messageId,
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

    // Always watch streamingReasoningProvider for live updates.
    // During streaming: shows incremental content from the provider.
    // After streaming: if provider has content, shows final content;
    // otherwise falls back to initialReasoningText.
    final streamingText = ref.watch(streamingReasoningProvider);
    if (streamingText.isNotEmpty &&
        streamingText.length >= _displayText.length) {
      _displayText = streamingText;
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
