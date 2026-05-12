import 'package:flutter/material.dart';

/// Bottom input bar inspired by Claude's chat input.
///
/// Claude style:
/// - Container with rounded-[20px], multi-layer shadow system
/// - bg-bg-000 (surfaceContainerLow)
/// - Inner: TextField with no border, maxLines: null, minLines: 1
/// - Right side: send button (filled circle)
/// - Placeholder: "输入消息..."
///
/// Behavior:
/// - Enter key sends
/// - Shift+Enter inserts newline
/// - Send button disabled when text is empty or [isLoading]
/// - Auto-focus on appear
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isLoading;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
  }

  /// Build multi-layer shadows matching Claude's approach.
  ///
  /// Base state:
  ///   - 0 0.25rem 1.25rem hsl(black/3.5%)
  ///   - 0 0 0 0.5px outline
  /// Hover: intensified shadow + outline
  /// Focus-within (via isFocused): even stronger shadow
  List<BoxShadow> _buildShadows(ColorScheme cs, bool isFocused) {
    if (isFocused) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 0,
          spreadRadius: 1,
        ),
      ];
    }

    if (_isHovered) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 0,
          spreadRadius: 0.75,
        ),
      ];
    }

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 0,
        spreadRadius: 0.5,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFocused = _focusNode.hasFocus;
    final canSend = _hasText && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered || isFocused ? cs.outline : cs.outlineVariant,
            width: 0.5,
          ),
          boxShadow: _buildShadows(cs, isFocused),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    size: 20,
                  ),
                  tooltip: '发送',
                  onPressed: canSend ? _send : null,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        canSend ? cs.primary : cs.surfaceContainerHighest,
                    foregroundColor:
                        canSend ? cs.onPrimary : cs.onSurfaceVariant,
                    disabledBackgroundColor: cs.surfaceContainerHighest,
                    disabledForegroundColor: cs.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
