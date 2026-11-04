import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
      title: Text(AppLocalizations.of(context)!.quitDialogTitle),
      content: Text(
        runningTaskCount > 0
            ? AppLocalizations.of(context)!
                .quitDialogRunningTasks(runningTaskCount)
            : AppLocalizations.of(context)!.quitDialogNoTasks,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(AppLocalizations.of(context)!.quitDialogCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(AppLocalizations.of(context)!.quitDialogExit),
        ),
      ],
    ),
  ).then((confirmed) => confirmed ?? false);
}
