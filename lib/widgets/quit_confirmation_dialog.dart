import 'package:flutter/material.dart';

/// 任务运行中退出确认对话框。
///
/// 桌面端（Windows/macOS/Linux）退出应用会立即中断所有运行中的
/// 后台任务，因此在「完全退出应用」按钮和「关闭窗口即退出」场景
/// 下，若有任务正在运行，必须先让用户确认。
///
/// 返回 `true` 表示用户确认退出，`false` 表示取消。
Future<bool> showQuitConfirmationDialog(
  BuildContext context, {
  required int runningTaskCount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('退出应用？'),
      content: Text(
        runningTaskCount > 0
            ? '有 $runningTaskCount 个任务正在运行，'
                '退出将中断这些任务。确定要退出吗？'
            : '确定要退出 Stroom 吗？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('退出'),
        ),
      ],
    ),
  ).then((confirmed) => confirmed ?? false);
}
