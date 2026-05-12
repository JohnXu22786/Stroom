import 'package:flutter/material.dart';

/// Top header bar inspired by Claude's `page-header`.
///
/// Claude style:
/// - flex w-full bg-bg-100 sticky top-0 z-header h-12
/// - Title: truncate font-base-bold
/// - Right side: action buttons
/// - Bottom border: border-b-0.5 border-border-300
class ChatHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final Widget? actions;

  const ChatHeader({
    super.key,
    required this.title,
    this.onMenuTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (onMenuTap != null)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuTap,
              tooltip: '菜单',
            ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          if (actions != null) actions!,
        ],
      ),
    );
  }
}
