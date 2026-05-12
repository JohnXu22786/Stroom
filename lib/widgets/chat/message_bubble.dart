import 'package:flutter/material.dart';
import 'package:stroom/models/chat_message.dart';
import 'avatar_widget.dart';
import 'markdown_renderer.dart';

/// Message bubble that handles both user and AI messages.
///
/// **User message** (right-aligned):
/// Rounded container with subtle background, max-width 85%.
///
/// **AI message** (left-aligned):
/// Row: [AvatarWidget('S')] + [header "Stroom" + Markdown body (serif) + action buttons]
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child:
          _isUser ? _buildUserBubble(context, cs) : _buildAiBubble(context, cs),
    );
  }

  // ── User message bubble ──────────────────────────────────────────────
  // Claude.ai style: no bubble/background, plain right-aligned text
  Widget _buildUserBubble(BuildContext context, ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 48, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface,
                height: 1.6,
              ),
              textAlign: TextAlign.right,
            ),
            if (message.isStreaming)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
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
          padding: const EdgeInsets.only(top: 2),
          child: AvatarWidget(name: 'S', size: 28),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Stroom" label header — smaller and lighter
              Text(
                'Stroom',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              // Markdown body — serif font for AI responses
              DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 14,
                  color: cs.onSurface,
                  height: 1.6,
                ),
                child: MarkdownRenderer(
                  data: message.content,
                  selectable: true,
                ),
              ),
              const SizedBox(height: 6),
              // Action buttons (copy, retry) and streaming indicator
              _buildActionsRow(context, cs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsRow(BuildContext context, ColorScheme cs) {
    if (message.isStreaming) {
      return _TypingIndicator(color: cs.primary);
    }

    return _HoverActions(
      child: Row(
        children: [
          if (onCopy != null)
            _ActionButton(
              icon: Icons.content_copy,
              tooltip: '复制',
              onTap: onCopy,
            ),
          const SizedBox(width: 2),
          if (onRetry != null)
            _ActionButton(
              icon: Icons.refresh,
              tooltip: '重试',
              onTap: onRetry,
            ),
        ],
      ),
    );
  }
}

/// Wraps a child to only show on hover (Claude.ai style).
class _HoverActions extends StatefulWidget {
  final Widget child;
  const _HoverActions({required this.child});

  @override
  State<_HoverActions> createState() => _HoverActionsState();
}

class _HoverActionsState extends State<_HoverActions> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        opacity: _hovered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: widget.child,
      ),
    );
  }
}

/// Subtle small icon button used in message action bar.
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
      width: 24,
      height: 24,
      child: IconButton(
        icon: Icon(icon, size: 14),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurfaceVariant.withValues(alpha: 0.45),
          disabledForegroundColor: cs.onSurfaceVariant.withValues(alpha: 0.15),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// Three-dot bouncing typing indicator.
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
            // Stagger each dot by 1/3 of the animation cycle
            final t = (_controller.value + i / 3) % 1.0;
            // Triangle wave: bounce scale from 0.4 → 1.0 → 0.4
            final scale = 0.4 + 0.6 * (t < 0.5 ? t * 2 : (1.0 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
