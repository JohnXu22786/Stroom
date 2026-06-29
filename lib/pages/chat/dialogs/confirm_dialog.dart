import 'package:flutter/material.dart';

/// Shows a confirmation dialog for editing a user message or retrying an AI message.
Future<void> showRetryEditConfirmDialog({
  required BuildContext context,
  required bool isUser,
  required bool newerMessagesExist,
  required VoidCallback onEdit,
  required VoidCallback onRetry,
}) async {
  if (isUser) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑消息'),
        content: Text(
          newerMessagesExist
              ? '确定要编辑这条消息吗？此操作将删除此消息及之后的所有消息。'
              : '确定要重新发送这条消息吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEdit();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  } else {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重试'),
        content: Text(
          newerMessagesExist ? '确定要重试这条回复吗？此操作将删除此消息及之后的所有消息。' : '确定要重新生成回复吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// Shows a confirmation dialog for deleting a message.
Future<void> showDeleteConfirmDialog({
  required BuildContext context,
  required VoidCallback onDelete,
}) async {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除消息'),
      content: const Text('确定要删除这条消息吗？此操作无法撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onDelete();
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('删除'),
        ),
      ],
    ),
  );
}
