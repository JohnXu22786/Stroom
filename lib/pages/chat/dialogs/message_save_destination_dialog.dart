import 'package:flutter/material.dart';

enum MessageSaveDestination { appFiles, device }

Future<MessageSaveDestination?> showMessageSaveDestinationDialog(
  BuildContext context,
) {
  return showDialog<MessageSaveDestination>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('保存消息'),
      icon: const Icon(Icons.save_outlined),
      semanticLabel: '选择消息保存位置',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('选择保存位置：'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.folder_outlined, size: 18),
            label: const Text('保存到应用文件'),
            onPressed: () =>
                Navigator.of(ctx).pop(MessageSaveDestination.appFiles),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('保存到设备'),
            onPressed: () =>
                Navigator.of(ctx).pop(MessageSaveDestination.device),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}
