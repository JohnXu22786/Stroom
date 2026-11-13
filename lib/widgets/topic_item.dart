import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../providers/conversation_provider.dart';
import '../utils/conversation_utils.dart';
import 'temporary_countdown_capsule.dart';
import 'temporary_conversation_dialog.dart';

class TopicItem extends StatelessWidget {
  final Conversation topic;
  final bool selectionMode;
  final bool isSelected;
  final bool isActive;
  final bool isRunning;
  final bool isUnread;
  final bool isFailed;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPinToggle;
  final VoidCallback onRename;
  final VoidCallback onAutoRename;
  final VoidCallback onSelectionToggle;
  final VoidCallback? onTemporaryToggle;

  const TopicItem({
    super.key,
    required this.topic,
    required this.selectionMode,
    required this.isSelected,
    required this.isActive,
    this.isRunning = false,
    this.isUnread = false,
    this.isFailed = false,
    required this.onTap,
    required this.onDelete,
    required this.onPinToggle,
    required this.onRename,
    required this.onAutoRename,
    required this.onSelectionToggle,
    this.onTemporaryToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final statusBaseColor = isFailed
        ? cs.error
        : isUnread
            ? Color.lerp(cs.primary, Colors.green, 0.55)
            : null;
    final statusColor = statusBaseColor == null
        ? null
        : Color.lerp(statusBaseColor, cs.onSurfaceVariant, 0.4);

    final title = topic.title.isEmpty
        ? AppLocalizations.of(context)!.topicItemNew
        : topic.title;
    final subtitle = formatDate(topic.updatedAt);
    final msgCount = topic.messages.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive
          ? cs.primaryContainer.withValues(alpha: 0.2)
          : (isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: isActive ? 1.0 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onSelectionToggle(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor != null && !isRunning
                          ? statusColor.withValues(alpha: 0.12)
                          : cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isRunning
                          ? _PulsingConversationIcon(color: cs.onSurfaceVariant)
                          : Icon(
                              topic.isPinned
                                  ? Icons.push_pin
                                  : Icons.chat_bubble_outline_rounded,
                              size: 20,
                              color: statusColor ??
                                  (topic.isPinned
                                      ? cs.primary
                                      : cs.onSurfaceVariant),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (topic.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 12,
                              color: cs.primary,
                            ),
                          ),
                        if (topic.isTemporary &&
                            topic.temporaryExpiresAt != null)
                          TemporaryCountdownCapsule(
                            expiresAt: topic.temporaryExpiresAt!,
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (msgCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.message_outlined,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$msgCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        topic.isPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        size: 18,
                        color: topic.isPinned
                            ? cs.primary
                            : cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      tooltip: topic.isPinned
                          ? AppLocalizations.of(context)!.topicItemUnpin
                          : AppLocalizations.of(context)!.topicItemPin,
                      onPressed: onPinToggle,
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'rename':
                            onRename();
                            break;
                          case 'auto_rename':
                            onAutoRename();
                            break;
                          case 'pin':
                            onPinToggle();
                            break;
                          case 'toggle_temporary':
                            if (topic.isTemporary ||
                                await showTemporaryConversationEnableDialog(
                                  context,
                                )) {
                              if (context.mounted) {
                                onTemporaryToggle?.call();
                              }
                            }
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(
                            AppLocalizations.of(context)!.topicItemRename,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'auto_rename',
                          child: Text(
                            AppLocalizations.of(context)!.topicItemAutoName,
                            style: TextStyle(color: cs.onSurface),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(
                            topic.isPinned
                                ? AppLocalizations.of(context)!.topicItemUnpin
                                : AppLocalizations.of(context)!.topicItemPin,
                          ),
                        ),
                        if (onTemporaryToggle != null)
                          PopupMenuItem(
                            value: 'toggle_temporary',
                            child: Text(
                              topic.isTemporary
                                  ? AppLocalizations.of(context)!
                                      .conversationKeep
                                  : AppLocalizations.of(context)!
                                      .conversationSetTemporary,
                            ),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            AppLocalizations.of(context)!.topicItemDelete,
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingConversationIcon extends StatefulWidget {
  final Color color;

  const _PulsingConversationIcon({required this.color});

  @override
  State<_PulsingConversationIcon> createState() =>
      _PulsingConversationIconState();
}

class _PulsingConversationIconState extends State<_PulsingConversationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dimColor = widget.color.withValues(alpha: 0.45);
    final pulse = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: widget.color,
          end: dimColor,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: dimColor,
          end: widget.color,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) =>
          Icon(Icons.chat_bubble_outline_rounded, size: 20, color: pulse.value),
    );
  }
}
