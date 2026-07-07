import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;

import 'backup_service.dart';
import 'data_migration_service.dart';

// ====================================================================
// AutoBackupService — 自动后台备份服务
// ====================================================================
//
// 提供两种自动备份场景：
//
// 1. 启动后台备份
//    每次启动进入主页后，在后台以最小占用创建一次完整数据备份。
//    如果备份过程中用户退出应用，自动放弃本次备份。
//
// 2. 迁移前备份
//    在数据格式升级/版本迁移前，自动创建备份再执行迁移。
//
// 备份文件以 ZIP 格式保存到 StroomBackups 目录，格式为：
//   backup_YYYY-MM-DDTHH-MM-SS.zip
//
// 备份目录至少保留 3 个最新的备份文件，超出部分自动清理。
// ====================================================================

/// 自动后台备份服务。
class AutoBackupService {
  AutoBackupService._();

  static bool _isRunning = false;
  static bool _cancelRequested = false;

  /// 当前是否正在执行自动备份。
  static bool get isRunning => _isRunning;

  /// 请求取消正在运行的自动备份。
  ///
  /// 在备份方法的各让出点会检查此标志，
  /// 如果为 `true` 则抛出 [BackupCancelledException] 终止备份。
  static void cancel() {
    _cancelRequested = true;
  }

  /// 执行一次自动后台备份。
  ///
  /// 创建包含所有应用数据的完整 ZIP 备份到 StroomBackups 目录。
  /// 备份完成后自动清理旧备份（保留至少 3 个）。
  ///
  /// [isPreMigration] 标记是否为迁移前备份（仅用于日志区分）。
  ///
  /// 返回 `true` 表示备份成功，`false` 表示备份失败或被取消。
  static Future<bool> performAutoBackup({
    bool isPreMigration = false,
  }) async {
    if (kIsWeb) return false;
    if (_isRunning) {
      debugPrint('[AutoBackupService] 备份已在运行中，跳过');
      return false;
    }

    _isRunning = true;
    // 如果 cancel() 在 performAutoBackup() 开始前已被调用（例如应用进入后台），
    // 直接放弃本次备份并重置取消标记，避免影响后续备份。
    if (_cancelRequested) {
      _isRunning = false;
      _cancelRequested = false;
      debugPrint('[AutoBackupService] 备份在开始前已被取消');
      return false;
    }
    _cancelRequested = false;

    try {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      final backupDir = Directory(backupRoot);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-');
      final zipPath = p.join(backupRoot, 'backup_$timestamp.zip');

      if (_cancelRequested) return false;

      final backupType = isPreMigration ? 'pre-migration' : 'startup';
      debugPrint('[AutoBackupService] 开始 $backupType 备份到 $zipPath');

      await BackupService.createBackup(
        outputPath: zipPath,
        isCancelled: () => _cancelRequested,
      );

      if (_cancelRequested) {
        // 如果文件已部分写入，删除不完整的备份文件
        final zipFile = File(zipPath);
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
        debugPrint('[AutoBackupService] 备份被取消');
        return false;
      }

      // 清理旧备份
      await _cleanupOldBackups(backupRoot);

      debugPrint('[AutoBackupService] $backupType 备份完成: $zipPath');
      return true;
    } on BackupCancelledException {
      debugPrint('[AutoBackupService] 备份被取消');
      return false;
    } catch (e) {
      debugPrint('[AutoBackupService] 备份失败: $e');
      return false;
    } finally {
      _isRunning = false;
      _cancelRequested = false;
    }
  }

  /// 清理旧备份，保留至少 3 个最新的备份文件。
  ///
  /// 同时处理旧格式（目录格式）和新格式（ZIP 格式）的备份。
  /// 排序规则按修改时间，保留最新的 3 个，删除其余。
  static Future<void> _cleanupOldBackups(String backupRoot) async {
    try {
      final dir = Directory(backupRoot);
      if (!await dir.exists()) return;

      final entries = await dir.list().toList();
      final backupItems = <FileSystemEntity>[];

      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.zip')) {
          // 新格式：ZIP 文件
          backupItems.add(entry);
        } else if (entry is Directory &&
            p.basename(entry.path).startsWith('backup_')) {
          // 旧格式：backup_ 开头的目录（兼容旧版本）
          backupItems.add(entry);
        }
      }

      // 按修改时间排序（最早的在前）
      backupItems.sort((a, b) {
        try {
          return a.statSync().modified.compareTo(b.statSync().modified);
        } catch (_) {
          return 0;
        }
      });

      // 保留至少 3 个
      while (backupItems.length > 3) {
        final oldest = backupItems.removeAt(0);
        try {
          if (oldest is Directory) {
            await oldest.delete(recursive: true);
          } else {
            await oldest.delete();
          }
          debugPrint('[AutoBackupService] 删除旧备份: ${oldest.path}');
        } catch (e) {
          debugPrint('[AutoBackupService] 删除备份失败 ${oldest.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('[AutoBackupService] 清理旧备份失败: $e');
    }
  }

  /// 清理备份目录中的旧备份，保留至少 3 个最新的。
  ///
  /// 供 [DataMigrationService] 等外部调用。
  static Future<void> cleanupOldBackups() async {
    final backupRoot = await DataMigrationService.getExternalBackupRootPath();
    await _cleanupOldBackups(backupRoot);
  }
}
