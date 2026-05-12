import 'package:flutter/material.dart';
import 'package:stroom/models/chat_message.dart';
import 'avatar_widget.dart';
import 'markdown_renderer.dart';

/// Message bubble that handles both user and AI messages.
///
/// **User message** (right-aligned):
/// Container with bg surfaceContainerHighest, rounded-xl, max-width 85%.
///
/// **AI message** (left-aligned):
/// Row: [AvatarWidget('S')] + [header "Stroom" + Markdown body + action buttons]
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onCopy,
  });

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child:
          _isUser ? _buildUserBubble(context, cs) : _buildAiBubble(context, cs),
    );
  }

  // ── User message bubble ──────────────────────────────────────────────
  Widget _buildUserBubble(BuildContext context, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
              if (message.isStreaming)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AI message bubble ────────────────────────────────────────────────
  Widget _buildAiBubble(BuildContext context, ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: AvatarWidget(name: 'S', size: 32),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Stroom" label header
              Text(
                'Stroom',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              // Markdown body
              MarkdownRenderer(
                data: message.content,
                selectable: true,
              ),
              // Action buttons (copy, retry) and streaming indicator
              const SizedBox(height: 4),
              _buildActionsRow(context, cs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsRow(BuildContext context, ColorScheme cs) {
    if (message.isStreaming) {
      return Row(
        children: [
          _TypingIndicator(color: cs.primary),
        ],
      );
    }

    return Row(
      children: [
        if (onCopy != null)
          _ActionButton(
            icon: Icons.content_copy,
            tooltip: '复制',
            onTap: onCopy,
          ),
        const SizedBox(width: 4),
        if (onRetry != null)
          _ActionButton(
            icon: Icons.refresh,
            tooltip: '重试',
            onTap: onRetry,
          ),
      ],
    );
  }
}

/// Small icon button used in message action bar.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurfaceVariant,
          disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Animated typing indicator (three bouncing dots).
class _TypingIndicator extends StatefulWidget {
  final Color color;

  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.15;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final size = 6.0 + 4.0 * (t < 0.5 ? t * 2 : (1.0 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
