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
  /// 使用原子写入模式：
  /// 1. 先写入到 .tmp 临时文件
  /// 2. 成功后重命名为 .zip
  /// 3. 如果过程中被取消或进程终止，.tmp 文件会在下次备份时被清理
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

      // 清理上次中断备份残留的 .tmp 文件
      await _cleanupTmpFiles(backupRoot);
      // 让出事件循环，避免清理操作影响主页面首次帧渲染
      await _yieldToEventLoop();

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      // 先使用 .tmp 扩展名写入，原子重命名防止进程终止导致损坏的 .zip 留存
      final tmpPath = p.join(backupRoot, 'backup_$timestamp.tmp');
      final zipPath = p.join(backupRoot, 'backup_$timestamp.zip');

      if (_cancelRequested) return false;

      final backupType = isPreMigration ? 'pre-migration' : 'startup';
      debugPrint('[AutoBackupService] 开始 $backupType 备份到 $zipPath');

      await BackupService.createBackup(
        outputPath: tmpPath,
        isCancelled: () => _cancelRequested,
      );

      if (_cancelRequested) {
        // 删除不完整的临时文件
        final tmpFile = File(tmpPath);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
        debugPrint('[AutoBackupService] 备份被取消');
        return false;
      }

      // 原子重命名：.tmp → .zip
      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        await tmpFile.rename(zipPath);
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

  /// 让出事件循环，确保 UI 可以处理帧渲染。
  static Future<void> _yieldToEventLoop() {
    return Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// 清理备份目录中的 .tmp 临时文件（上次中断备份留下的残留）。
  static Future<void> _cleanupTmpFiles(String backupRoot) async {
    try {
      final dir = Directory(backupRoot);
      if (!await dir.exists()) return;

      final entries = await dir.list().toList();
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.tmp')) {
          try {
            await entry.delete();
            debugPrint('[AutoBackupService] 清理残留临时文件: ${entry.path}');
          } catch (e) {
            debugPrint('[AutoBackupService] 清理临时文件失败 ${entry.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[AutoBackupService] 清理临时文件失败: $e');
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
