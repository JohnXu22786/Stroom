import 'package:flutter/material.dart';

import '../providers/conversation_provider.dart';
import '../utils/conversation_utils.dart';

class TopicItem extends StatelessWidget {
  final Conversation topic;
  final bool selectionMode;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPinToggle;
  final VoidCallback onRename;
  final VoidCallback onAutoRename;
  final VoidCallback onSelectionToggle;

  const TopicItem({
    super.key,
    required this.topic,
    required this.selectionMode,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onPinToggle,
    required this.onRename,
    required this.onAutoRename,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = topic.title.isEmpty ? '新话题' : topic.title;
    final subtitle = formatDate(topic.updatedAt);
    final msgCount = topic.messages.length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isActive
          ? cs.primaryContainer.withValues(alpha: 0.2)
          : (isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: isActive ? 1.0 : 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (selectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onSelectionToggle(),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    topic.isPinned
                        ? Icons.push_pin
                        : Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: topic.isPinned ? cs.primary : cs.onSurfaceVariant,
                  ),
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
                            child: Icon(Icons.push_pin,
                                size: 12, color: cs.primary),
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
                          Icon(Icons.message_outlined,
                              size: 12, color: cs.onSurfaceVariant),
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
                      tooltip: topic.isPinned ? '取消置顶' : '置顶',
                      onPressed: onPinToggle,
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: cs.onSurfaceVariant),
                      onSelected: (value) {
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
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('重命名'),
                        ),
                        PopupMenuItem(
                          value: 'auto_rename',
                          child: Text('自动命名',
                              style: TextStyle(color: cs.onSurface)),
                        ),
                        PopupMenuItem(
                          value: 'pin',
                          child: Text(topic.isPinned ? '取消置顶' : '置顶'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除', style: TextStyle(color: cs.error)),
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
