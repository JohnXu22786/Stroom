import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;

import '../services/app_log_service.dart';
import '../services/auto_backup_service.dart';
import '../services/backup_location_manager.dart';
import '../utils/format_file_size.dart';

// ====================================================================
// BackupStartupCheck — 启动时备份存储位置检查
// ====================================================================
//
// 在应用启动时执行以下检查：
//
// 1. 检查备份存储位置是否可访问
//    - Android: 检查 SAF URI 是否存在且有效，无效则引导用户授权
//    - iOS: 检查应用 Documents 目录是否可写（路径固定，由系统管理）
//    - 桌面平台: 检查 ~/Documents/Stroom/AutoBackups 是否可写
//
// 2. 如果存储不可用（仅 Android 需用户授权），显示引导对话框
//    - 用户必须同意才能继续使用应用（循环直到同意）
//    - Android SAF 目录选择器自动定位到根目录下的 Documents 文件夹
//    - iOS/桌面路径固定，无需用户授权
//
// 3. 检查可用存储空间
//    - 如果空间不足，提示用户清理
//    - 清理后重试，直到有足够空间
//
// 4. 执行一次启动后自动备份
//    - 如果备份失败：
//      - Android：不提供「跳过」，必须重新授权路径或重试
//      - iOS / 桌面：保留「跳过」按钮（路径固定无可重新授权）
//    - 若用户选择重新授权（Android）：清除已保存的 SAF URI，
//      回到步骤 1 重新选择目录
// ====================================================================

/// 启动时备份检查结果。
class BackupStartupResult {
  /// 备份存储是否已就绪。
  final bool storageReady;

  /// 自动备份是否成功执行。
  final bool autoBackupPerformed;

  const BackupStartupResult({
    required this.storageReady,
    this.autoBackupPerformed = false,
  });
}

/// 启动时备份检查服务。
class BackupStartupCheck {
  BackupStartupCheck._();

  /// 静默自动重试之间的间隔。
  ///
  /// 测试中可覆盖为更短的值以加速用例（真实 IO 在 testWidgets 的
  /// FakeAsync 区域中不会完成，重试用例需在 runAsync 中跑真实延迟）。
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 2);

  /// 执行启动时的备份存储检查和自动备份。
  ///
  /// 此方法会阻塞直到：
  /// 1. 存储位置已就绪（Android SAF 授权完成）
  /// 2. 有足够存储空间
  /// 3. 自动备份执行成功
  ///
  /// 在 Web 平台上直接返回（不支持本地备份）。
  static Future<BackupStartupResult> runCheck(BuildContext context) async {
    if (kIsWeb) {
      return const BackupStartupResult(storageReady: false);
    }

    bool needReAuth = false;
    bool backupSuccess = false;

    do {
      needReAuth = false;
      backupSuccess = false;

      // ---------------------------------------------------------------
      // 步骤 1：确保备份存储可访问
      // ---------------------------------------------------------------
      bool storageAccessible =
          await BackupLocationManager.isStorageAccessible();

      // Android 必须授权成功才能继续（用户可以选择退出应用）；
      // 非 Android 平台路径固定，连续失败 2 次后降级继续，
      // 避免「确定 → 授权失败 → 重试」无限循环（路径不可修复时
      // 用户既无法退出也无法进入应用）。
      final bool isAndroid = !kIsWeb && Platform.isAndroid;
      int accessAttempts = 0;

      while (!storageAccessible && context.mounted) {
        accessAttempts++;
        // 显示引导对话框
        final shouldProceed = await _showStorageAccessDialog(context);
        if (!shouldProceed || !context.mounted) {
          // 用户选择退出应用
          return const BackupStartupResult(storageReady: false);
        }

        // 请求存储访问权限
        final granted = await BackupLocationManager.requestStorageAccess();
        if (granted) {
          storageAccessible = await BackupLocationManager.isStorageAccessible();
        }

        if (!storageAccessible && context.mounted) {
          // 授权失败，提示用户重试
          await _showAccessFailedDialog(context);
          if (!isAndroid && accessAttempts >= 2) {
            debugPrint('[BackupStartupCheck] 非 Android 平台存储仍不可访问，'
                '降级继续（备份失败将另行提示）');
            await AppLogService.warning(
                'BackupStartupCheck', '非 Android 平台备份存储不可访问，降级继续');
            return const BackupStartupResult(
              storageReady: true,
              autoBackupPerformed: false,
            );
          }
        }
      }

      if (!context.mounted) {
        return const BackupStartupResult(storageReady: false);
      }

      await AppLogService.info('BackupStartupCheck', '存储可访问，开始检查可用空间');

      // ---------------------------------------------------------------
      // 步骤 2：检查可用空间（按本次备份的估算大小，而非固定阈值）。
      // 若最近 1 小时已有备份（1 小时规则将跳过本次备份），
      // 无需检查空间 —— 避免对不会执行的备份要求用户清理空间。
      // ---------------------------------------------------------------
      final willSkipDueToOneHour =
          await AutoBackupService.hasRecentBackupWithinHour();
      final estimatedSize = await AutoBackupService.estimateBackupSize();

      bool hasSpace = true;
      if (!willSkipDueToOneHour) {
        hasSpace = await BackupLocationManager.hasSufficientSpace(
            requiredBytes: estimatedSize);

        while (!hasSpace && context.mounted) {
          final shouldRetry = await showStorageSpaceDialog(context,
              requiredBytes: estimatedSize);
          if (!shouldRetry || !context.mounted) {
            return BackupStartupResult(
              storageReady: true,
              autoBackupPerformed: false,
            );
          }
          hasSpace = await BackupLocationManager.hasSufficientSpace(
              requiredBytes: estimatedSize);
        }
      }

      if (!context.mounted) {
        return BackupStartupResult(
          storageReady: true,
          autoBackupPerformed: false,
        );
      }

      await AppLogService.info('BackupStartupCheck', '开始执行启动后自动备份');

      // ---------------------------------------------------------------
      // 步骤 3：执行启动后自动备份
      // ---------------------------------------------------------------
      //
      // 失败处理策略：不急着报错 —— 首次失败后先静默自动重试
      // [maxSilentRetries] 次（瞬时错误如文件占用、存储抖动常可自愈），
      // 静默重试全部失败后才弹窗让用户决定（重试/跳过/重新授权）。
      //
      // 被取消的备份（应用进入后台时系统主动 cancel）不自动重试 ——
      // 用户已离开应用，重试会违背其意图并浪费资源。
      // 取消的备份 lastFailure 为 null（见 AutoBackupService），
      // 用此区分「真实失败」与「系统取消」。
      //
      // 弹窗阶段最多出现 [maxFailureDialogs] 个失败对话框，避免不可恢复
      // 错误（如 OOM）导致无限弹窗循环（第 2 个对话框起只剩「跳过」）。
      int backupAttempts = 0;
      int dialogRetryCount = 0; // 弹窗阶段用户点击「重试」的次数
      const maxSilentRetries = 2;
      const maxFailureDialogs = 2;

      while (!backupSuccess && context.mounted) {
        backupAttempts++;
        try {
          backupSuccess = await AutoBackupService.performAutoBackup();
        } catch (e) {
          debugPrint('[BackupStartupCheck] 自动备份异常: $e');
          await AppLogService.error('BackupStartupCheck', '自动备份异常', e);
          backupSuccess = false;
        }

        if (!backupSuccess && context.mounted) {
          // 弹窗前的静默重试窗口：失败且非取消时自动重试，不打扰用户。
          final cancelled = AutoBackupService.lastFailure == null;
          if (dialogRetryCount == 0 &&
              !cancelled &&
              backupAttempts <= maxSilentRetries) {
            debugPrint('[BackupStartupCheck] 自动备份失败（第 $backupAttempts 次，'
                '共可静默重试 $maxSilentRetries 次），稍后自动重试…');
            await AppLogService.warning(
                'BackupStartupCheck', '自动备份失败（第 $backupAttempts 次），自动重试中');
            await Future<void>.delayed(retryDelay);
            continue;
          }

          final reachedMaxAttempts = dialogRetryCount + 1 >= maxFailureDialogs;
          final dialogResult = await showBackupFailedDialog(
            context,
            showSkip: reachedMaxAttempts,
            errorMessage: AutoBackupService.lastError,
          );
          if (!context.mounted) break;

          if (dialogResult == null) {
            // 用户选择「跳过」→ 退出循环
            break;
          }

          if (dialogResult == true) {
            // 用户选择「重试」→ 继续循环
            dialogRetryCount++;
            continue;
          }

          // dialogResult == false: 用户选择「重新授权」→ 清除 SAF URI，回到步骤 1
          if (!kIsWeb && Platform.isAndroid) {
            await BackupLocationManager.clearStorageAccess();
            needReAuth = true;
          }
          break;
        }
      }
    } while (needReAuth && context.mounted);

    if (backupSuccess) {
      await AppLogService.info('BackupStartupCheck', '启动后自动备份成功');
      // 空间清理提醒：剩余空间 < 5 × 本次备份大小 时提示清理
      if (context.mounted) {
        await maybeShowSpaceReminder(context);
      }
    } else {
      await AppLogService.warning(
          'BackupStartupCheck', '启动后自动备份未执行（可能因 1 小时规则跳过或失败）');
    }

    return BackupStartupResult(
      storageReady: true,
      autoBackupPerformed: backupSuccess,
    );
  }

  /// 备份成功后的空间清理提醒。
  ///
  /// 规则：当前设备/磁盘剩余空间 < 5 × 本次备份大小 时弹窗提醒清理，
  /// 为后续备份预留足够空间（否则下次自动备份可能因空间不足失败）。
  @visibleForTesting
  static Future<void> maybeShowSpaceReminder(BuildContext context) async {
    try {
      final reminder = await AutoBackupService.checkSpaceReminder();
      if (reminder == null || !context.mounted) return;

      final freeText = formatFileSize(reminder.freeBytes);
      final backupText = formatFileSize(reminder.backupSizeBytes);
      final recommendedText = formatFileSize(5 * reminder.backupSizeBytes);

      await AppLogService.info(
          'BackupStartupCheck',
          '空间提醒: 剩余 $freeText, 本次备份 $backupText, '
              '建议保留 ≥ $recommendedText');
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        // 必须点击「知道了」按钮才能关闭：防止用户误点空白处忽略提醒后，
        // 因剩余空间不足导致后续自动备份失败。
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cleaning_services_outlined,
                  color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 8),
              const Text('存储空间提醒'),
            ],
          ),
          content: Text(
            '当前设备剩余空间约 $freeText，而本次自动备份大小为 $backupText。\n\n'
            '建议保留至少 5 倍备份大小的空间（约 $recommendedText），'
            '以确保后续自动备份能够顺利进行。\n\n'
            '请清理一些不必要的文件（如旧的备份文件、大视频、应用缓存）。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (e) {
      // 提醒失败不阻塞启动流程
      debugPrint('[BackupStartupCheck] 空间提醒失败: $e');
    }
  }

  /// 显示存储访问授权引导对话框。
  ///
  /// 返回 true 表示用户同意授权，false 表示用户退出应用。
  static Future<bool> _showStorageAccessDialog(BuildContext context) async {
    // 确定平台信息
    final isAndroid = !kIsWeb && Platform.isAndroid;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder_open, color: Colors.orange.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('备份存储授权'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAndroid) ...[
              const Text(
                '为了确保您的数据安全，Stroom 需要您选择一个公开目录来存放自动备份文件。'
                '这样即使应用被卸载或清除数据，备份文件也不会丢失。',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '文件选择器已自动定位到存储根目录下的「Documents」文件夹，'
                      '点击下方「同意并选择目录」后直接点击「允许」即可。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '此授权仅需一次，之后备份将在后台自动进行，无需再次打扰您。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Stroom 将使用系统公共文档目录存放自动备份文件。'
                '这些文件在应用被卸载或清除数据后依然存在，'
                '您可以通过系统文件管理器直接访问。',
              ),
            ],
          ],
        ),
        actions: [
          if (isAndroid)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('退出应用'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isAndroid ? '同意并选择目录' : '确定'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// 显示授权失败对话框。
  ///
  /// 当用户未选择正确的 Documents 目录（如选择了根目录），或
  /// SAF 权限授予失败时显示。用户必须重新选择才能继续。
  static Future<void> _showAccessFailedDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
            const SizedBox(width: 8),
            const Text('授权失败'),
          ],
        ),
        content: const Text(
          '未获得正确的备份目录访问权限。\n\n'
          '请确保在文件选择器中选择了存储根目录下的「Documents」文件夹'
          '（而非存储根目录本身），然后点击「允许」。\n\n'
          '点击「重试」重新选择目录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 显示存储空间不足对话框。
  ///
  /// 返回 true 表示用户已清理空间并重试。
  /// [requiredBytes] 为本次备份的估算大小，用于提示具体需求。
  @visibleForTesting
  static Future<bool> showStorageSpaceDialog(
    BuildContext context, {
    int? requiredBytes,
  }) async {
    final requiredText = requiredBytes != null && requiredBytes > 0
        ? formatFileSize(requiredBytes)
        : '足够的';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storage, color: Colors.orange.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('存储空间不足'),
          ],
        ),
        content: Text(
          '设备存储空间不足，无法正常完成自动备份'
          '（本次备份约需 $requiredText 空间）。\n\n'
          '请清理一些不必要的文件（如旧的备份、大视频、缓存）'
          '后点击「重试」，或释放足够的空间后再继续使用应用。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('我已清理，重试'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('稍后处理'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示自动备份失败对话框。
  ///
  /// 返回值：
  /// - `true`  → 重试（继续循环备份）
  /// - `false` → 重新授权存储路径（Android 专用，清除 SAF URI）
  /// - `null`  → 跳过备份，退出循环
  ///
  /// [showSkip] 为 true 时在 Android 上也显示「跳过」按钮
  /// （达到最大重试次数后，避免无限循环）。
  /// [errorMessage] 可选的错误详情，用于判断是否为 OOM 并显示针对性提示。
  @visibleForTesting
  static Future<bool?> showBackupFailedDialog(
    BuildContext context, {
    bool showSkip = false,
    String? errorMessage,
  }) async {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final failure = AutoBackupService.lastFailure;

    // 根据失败分类构建提示文本；分类失败时回退到旧的关键字判断。
    final isOom = errorMessage != null &&
        (errorMessage.contains('Out of Memory') ||
            errorMessage.contains('OutOfMemory') ||
            errorMessage.contains('out of memory') ||
            errorMessage.contains('Cannot allocate memory') ||
            errorMessage.contains('failed to map file') ||
            errorMessage.contains('malloc failed'));

    // 分类信息优先；有具体原因时展示针对性提示（含所需/可用空间）。
    // 注意：提示文本不引用具体按钮 —— 重试/跳过/重新授权按钮的可见性
    // 随重试次数与平台变化（达到最大重试次数时只剩「跳过」），
    // 文本指引具体按钮会在按钮不存在时自相矛盾。
    String contentText;
    if (failure != null && failure.reason != BackupFailureReason.other) {
      switch (failure.reason) {
        case BackupFailureReason.noSpace:
          final requiredText = failure.requiredBytes != null
              ? formatFileSize(failure.requiredBytes!)
              : null;
          final freeText = failure.freeBytes != null
              ? formatFileSize(failure.freeBytes!)
              : null;
          final details = <String>[
            if (requiredText != null) '约需 $requiredText 空间',
            if (freeText != null) '当前可用 $freeText',
          ];
          final parenthetical =
              details.isNotEmpty ? '（${details.join('，')}）' : '';
          contentText = '自动备份因设备存储空间不足而失败$parenthetical。\n\n'
              '请清理一些不必要的文件（如旧的备份、大视频、应用缓存）'
              '后再试。\n'
              '也可以在设置中手动导出备份（可选择排除视频等大文件）。';
        case BackupFailureReason.outOfMemory:
          contentText = '自动备份因设备内存不足而失败。\n\n'
              '这通常是因为备份数据（尤其是视频文件）太大。'
              '您可以：\n'
              '• 在设置中手动导出备份（可选择排除视频等大文件）\n'
              '• 清理一些不需要的视频/图片后再试';
        case BackupFailureReason.permission:
          contentText = '自动备份因备份目录权限异常而失败。\n\n'
              '请确认已授权正确的「Documents」文档目录路径'
              '（Android 可在授权界面重新选择目录），'
              '然后再次尝试备份。';
        case BackupFailureReason.fileLocked:
          contentText = '自动备份因部分数据文件被其他程序占用而失败。\n\n'
              '请关闭正在占用这些文件的程序（如播放器、文件管理器），'
              '然后再试。';
        case BackupFailureReason.cancelled:
          contentText = '自动备份已取消。';
        case BackupFailureReason.other:
          contentText = '自动备份未能成功完成，请稍后重试。';
      }
      if (showSkip) {
        contentText += '\n\n自动备份多次尝试后仍未成功，'
            '点击「跳过」暂不备份，稍后可在应用中手动备份。';
      }
    } else if (isOom) {
      contentText = '自动备份因设备内存不足而失败。\n\n'
          '这通常是因为备份数据（尤其是视频文件）太大。'
          '您可以：\n'
          '• 点击「跳过」暂不备份，继续使用应用\n'
          '• 在设置中手动导出备份（可选择排除视频等大文件）\n'
          '• 清理一些不需要的视频/图片后重试';
    } else if (showSkip) {
      // 达到最大重试次数，只显示「跳过」按钮
      contentText = '自动备份多次尝试后仍未成功。\n\n'
          '点击「跳过」暂不备份，稍后可在应用中手动备份。';
    } else if (isAndroid) {
      contentText = '自动备份未能成功完成。\n\n'
          '请确认已授权正确的「Documents」文档目录路径，\n'
          '点击「重新授权」返回重新选择正确的目录；\n'
          '或点击「重试」再次尝试备份。';
    } else {
      contentText = '自动备份未能成功完成，可能是存储空间不足或设备状态异常。\n\n'
          '请清理不必要的文件后点击「重试」，应用将再次尝试自动备份。'
          '备份成功后即可正常使用。';
    }

    // 以下失败原因与存储路径授权无关，「重新授权」按钮无意义：
    // 空间不足 / 内存不足 / 文件占用 / 已取消 → 直接显示「跳过」
    final reauthIrrelevant = failure != null &&
        (failure.reason == BackupFailureReason.noSpace ||
            failure.reason == BackupFailureReason.outOfMemory ||
            failure.reason == BackupFailureReason.fileLocked ||
            failure.reason == BackupFailureReason.cancelled);

    // OOM 时「重新授权」无意义，直接显示「跳过」
    final showSkipInDialog =
        isOom || showSkip || !isAndroid || reauthIrrelevant;

    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
            const SizedBox(width: 8),
            const Text('自动备份失败'),
          ],
        ),
        content: Text(contentText),
        actions: [
          if (showSkipInDialog)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('跳过'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('重新授权'),
            ),
          if (!showSkip)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('重试'),
            ),
        ],
      ),
    );
    return result;
  }
}
