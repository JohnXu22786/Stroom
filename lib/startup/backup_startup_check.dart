import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../services/app_log_service.dart';
import '../services/backup_location_manager.dart';
import '../services/auto_backup_service.dart';

// ====================================================================
// BackupStartupCheck — 启动时备份存储位置检查
// ====================================================================
//
// 在应用启动时执行以下检查：
//
// 1. 检查备份存储位置是否可访问
//    - Android: 检查 SAF URI 是否存在且有效，无效则引导用户授权
//    - iOS: 检查应用 Documents 目录是否可写（路径固定，由系统管理）
//    - 桌面平台: 检查 ~/Documents/StroomData/AutoBackup 是否可写
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

  /// 标记启动时自动备份是否已在 startup 流程中执行。
  ///
  /// 用于防止 [HomePage] 等后续触发重复执行自动备份。
  static bool startupBackupPerformed = false;

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

      while (!storageAccessible && context.mounted) {
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
        }
      }

      if (!context.mounted) {
        return const BackupStartupResult(storageReady: false);
      }

      await AppLogService.info('BackupStartupCheck', '存储可访问，开始检查可用空间');

      // ---------------------------------------------------------------
      // 步骤 2：检查可用空间
      // ---------------------------------------------------------------
      bool hasSpace = await BackupLocationManager.hasSufficientSpace();

      while (!hasSpace && context.mounted) {
        final shouldRetry = await _showStorageSpaceDialog(context);
        if (!shouldRetry || !context.mounted) {
          return BackupStartupResult(
            storageReady: true,
            autoBackupPerformed: false,
          );
        }
        hasSpace = await BackupLocationManager.hasSufficientSpace();
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
      while (!backupSuccess && context.mounted) {
        try {
          backupSuccess = await AutoBackupService.performAutoBackup();
        } catch (e) {
          debugPrint('[BackupStartupCheck] 自动备份异常: $e');
          await AppLogService.error('BackupStartupCheck', '自动备份异常', e);
          backupSuccess = false;
        }

        if (!backupSuccess && context.mounted) {
          final shouldRetry = await _showBackupFailedDialog(context);
          if (!context.mounted) break;

          if (!shouldRetry) {
            // Android: 用户选择「重新授权」→ 清除 SAF URI，回到步骤 1
            // iOS / 桌面：用户选择「跳过」→ 退出循环（iOS 路径固定无需授权）
            if (!kIsWeb && Platform.isAndroid) {
              await BackupLocationManager.clearStorageAccess();
              needReAuth = true;
            }
            break;
          }
          // shouldRetry == true: 继续循环重试备份
        }
      }
    } while (needReAuth && context.mounted);

    if (backupSuccess) {
      startupBackupPerformed = true;
      await AppLogService.info('BackupStartupCheck', '启动后自动备份成功');
    } else {
      await AppLogService.warning('BackupStartupCheck', '启动后自动备份未执行（可能因 1 小时规则跳过或失败）');
    }

    return BackupStartupResult(
      storageReady: true,
      autoBackupPerformed: backupSuccess,
    );
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
  static Future<bool> _showStorageSpaceDialog(BuildContext context) async {
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
        content: const Text(
          '设备存储空间不足，无法正常完成自动备份。\n\n'
          '请清理一些不必要的文件后点击「重试」，'
          '或释放足够的空间后再继续使用应用。',
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
  /// 返回 `true` 表示用户想重试；`false` 表示用户想重新授权路径或跳过。
  /// - Android：不提供「跳过」按钮（有 SAF 可重新授权），必须重试或重新授权。
  /// - iOS / 桌面：保留「跳过」按钮（路径固定，不存在重新授权问题）。
  static Future<bool> _showBackupFailedDialog(BuildContext context) async {
    final isAndroid = !kIsWeb && Platform.isAndroid;

    final result = await showDialog<bool>(
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
        content: Text(
          isAndroid
              ? '自动备份未能成功完成。\n\n'
                  '请确认已授权正确的「Documents」文档目录路径，\n'
                  '点击「重新授权」返回重新选择正确的目录；\n'
                  '或点击「重试」再次尝试备份。'
              : '自动备份未能成功完成，可能是存储空间不足或设备状态异常。\n\n'
                  '请清理不必要的文件后点击「重试」，应用将再次尝试自动备份。'
                  '备份成功后即可正常使用。',
        ),
        actions: [
          if (isAndroid)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('重新授权'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('跳过'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
