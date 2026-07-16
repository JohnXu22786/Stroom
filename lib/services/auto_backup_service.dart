import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;

import 'app_log_service.dart';
import 'backup_location_manager.dart';
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
// 备份文件以 ZIP 格式保存到公共目录，格式为：
//   backup_YYYY-MM-DDTHH-MM-SS.zip
//
// 各平台存储位置由 [BackupLocationManager] 统一管理：
// - Android: 通过 SAF 选择 Documents 目录
// - iOS: 应用 Documents 目录（通过文件 App 可访问）
// - Desktop: ~/Documents/StroomData/AutoBackup
// - Web: 不支持
//
// 备份保留策略：
// - 1 小时规则：如果最近 1 小时内有备份，则跳过本次备份
// - 24 小时限制：24 小时内最多保留 3 个备份
// - 总数限制：最多保留 5 个备份
// - 使用天数：额外保留最近 2 次使用日的最后一个备份
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
  /// 创建包含所有应用数据的完整 ZIP 备份到公共目录。
  /// 备份完成后自动清理旧备份。
  ///
  /// 保留策略：
  /// - 1 小时规则：如果最近 1 小时内有备份，则跳过本次备份
  /// - 24 小时限制：24 小时内最多保留 3 个备份
  /// - 总数限制：最多保留 5 个备份
  /// - 使用天数：额外保留最近 2 次使用日的最后一个备份
  ///
  /// 在 Android SAF 模式下，备份写入系统临时目录后通过 SAF
  /// 写入用户选择的 Documents 目录，确保文件持久化到公共位置。
  ///
  /// [isPreMigration] 标记是否为迁移前备份（仅用于日志区分）。
  ///
  /// 返回 `true` 表示备份成功，`false` 表示备份失败或被取消。
  static Future<bool> performAutoBackup({
    bool isPreMigration = false,
  }) async {
    if (kIsWeb) return false;

    // 先设置运行标志，防止并发执行
    if (_isRunning) {
      debugPrint('[AutoBackupService] 备份已在运行中，跳过');
      await AppLogService.warning('AutoBackupService', '备份已在运行中，跳过');
      return false;
    }
    _isRunning = true;

    // ================================================================
    // 1 小时规则检查：如果最近 1 小时内有备份，则跳过本次备份
    // ================================================================
    try {
      final hasRecentBackup = await _hasBackupWithinLastHour();
      if (hasRecentBackup) {
        debugPrint('[AutoBackupService] 最近 1 小时内有备份，跳过本次自动备份');
        await AppLogService.info('AutoBackupService', '最近 1 小时内有备份，跳过本次自动备份');
        _isRunning = false;
        return true; // 返回 true 表示无需备份（非错误）
      }
    } catch (e) {
      debugPrint('[AutoBackupService] 检查最近备份失败: $e');
      // 检查失败不阻止备份
    }

    await AppLogService.info(
        'AutoBackupService', '开始执行自动备份 (isPreMigration=$isPreMigration)');
    if (_cancelRequested) {
      _isRunning = false;
      _cancelRequested = false;
      debugPrint('[AutoBackupService] 备份在开始前已被取消');
      await AppLogService.warning('AutoBackupService', '备份在开始前已被取消');
      return false;
    }
    _cancelRequested = false;

    String? safTempPath; // SAF 模式下写入的系统临时文件路径
    try {
      final isAndroidSaf = await BackupLocationManager.isUsingSafMode();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final tmpFileName = 'backup_$timestamp.tmp';
      final zipFileName = 'backup_$timestamp.zip';
      final backupType = isPreMigration ? 'pre-migration' : 'startup';

      if (isAndroidSaf) {
        // ============================================================
        // Android SAF 模式：通过 SAF 写入公共 Documents 目录
        // ============================================================
        final sysTempDir = Directory.systemTemp.path;
        safTempPath = p.join(sysTempDir, tmpFileName);

        debugPrint('[AutoBackupService] 开始 $backupType 备份(SAF)');
        await AppLogService.info(
            'AutoBackupService', '开始 $backupType 备份(SAF): $zipFileName');

        await BackupService.createBackup(
          outputPath: safTempPath,
          isCancelled: () => _cancelRequested,
        );

        if (_cancelRequested) {
          debugPrint('[AutoBackupService] 备份被取消');
          return false;
        }

        // 读取临时文件并通过 SAF 写入公共目录
        final bytes = await File(safTempPath).readAsBytes();
        await BackupLocationManager.writeBackupFile(zipFileName, bytes);

        // 清理旧备份
        await _cleanupOldBackupsSaf();

        debugPrint('[AutoBackupService] $backupType 备份完成(SAF): $zipFileName');
        await AppLogService.info(
            'AutoBackupService', '$backupType 备份完成(SAF): $zipFileName');
        return true;
      } else {
        // ============================================================
        // 非 SAF 模式（Desktop/iOS/Test）：直接使用 dart:io
        // ============================================================
        final backupRoot =
            await DataMigrationService.getExternalBackupRootPath();
        final backupDir = Directory(backupRoot);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }

        // 清理残留的 .tmp 文件
        await _cleanupTmpFiles(backupRoot);
        await _yieldToEventLoop();

        final tmpPath = p.join(backupRoot, tmpFileName);
        final zipPath = p.join(backupRoot, zipFileName);

        if (_cancelRequested) return false;

        debugPrint('[AutoBackupService] 开始 $backupType 备份到 $zipPath');

        await BackupService.createBackup(
          outputPath: tmpPath,
          isCancelled: () => _cancelRequested,
        );

        if (_cancelRequested) {
          await _deleteSystemTempFile(tmpPath);
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
        await AppLogService.info(
            'AutoBackupService', '$backupType 备份完成: $zipPath');
        return true;
      }
    } on BackupCancelledException {
      debugPrint('[AutoBackupService] 备份被取消');
      await AppLogService.warning('AutoBackupService', '备份被取消');
      return false;
    } catch (e) {
      debugPrint('[AutoBackupService] 备份失败: $e');
      await AppLogService.error('AutoBackupService', '备份失败', e);
      return false;
    } finally {
      // 清理 SAF 遗留的系统临时文件（无论成功失败）
      if (safTempPath != null) {
        await _deleteSystemTempFile(safTempPath);
      }
      _isRunning = false;
      _cancelRequested = false;
    }
  }

  /// 让出事件循环，确保 UI 可以处理帧渲染。
  static Future<void> _yieldToEventLoop() {
    return Future<void>.delayed(const Duration(milliseconds: 1));
  }

  /// 删除系统临时目录中的文件。
  static Future<void> _deleteSystemTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// 检查最近 1 小时内是否有备份。
  ///
  /// 如果存在最近 1 小时内的备份文件，返回 `true`，否则返回 `false`。
  /// 如果无法检查（如无备份目录或无备份文件），返回 `false`。
  static Future<bool> _hasBackupWithinLastHour() async {
    try {
      if (await BackupLocationManager.isUsingSafMode()) {
        // SAF 模式：通过 BackupLocationManager 列出文件
        final files = await BackupLocationManager.listBackupFiles();
        final zipFiles = files.where((f) => f.endsWith('.zip')).toList();
        if (zipFiles.isEmpty) return false;

        // SAF 模式下文件名包含时间戳，按文件名排序取最新的
        zipFiles.sort();
        final newest = zipFiles.last;
        final ts = _extractTimestampFromFilename(newest);
        if (ts == null) return false;

        return DateTime.now().difference(ts) < const Duration(hours: 1);
      } else {
        // 非 SAF 模式：通过文件系统直接检查
        final backupRoot =
            await DataMigrationService.getExternalBackupRootPath();
        final infos = await _listBackupInfos(backupRoot);
        if (infos.isEmpty) return false;

        // 取最新的备份
        final newest = infos.first;
        return DateTime.now().difference(newest.modified) <
            const Duration(hours: 1);
      }
    } catch (e) {
      debugPrint('[AutoBackupService] 检查 1 小时备份规则失败: $e');
      return false;
    }
  }

  /// 从备份文件名中提取时间戳。
  ///
  /// 文件名格式: backup_YYYY-MM-DDTHH-MM-SS.zip
  /// 返回解析后的 DateTime，如果解析失败返回 null。
  static DateTime? _extractTimestampFromFilename(String fileName) {
    try {
      // backup_2024-01-01T12-00-00.zip
      final match = RegExp(r'^backup_(\d{4}-\d{2}-\d{2})T(\d{2}-\d{2}-\d{2})')
          .firstMatch(fileName);
      if (match == null) return null;
      // 日期部分保留连字符，时间部分将连字符替换为冒号
      final datePart = match.group(1)!; // 2024-01-01
      final timePart = match.group(2)!.replaceAll('-', ':'); // 12:00:00
      final isoStr = '${datePart}T$timePart';
      return DateTime.parse(isoStr);
    } catch (_) {
      return null;
    }
  }

  /// 备份文件信息，用于保留策略排序和决策。
  ///
  /// 优先从文件名提取时间戳（更准确），
  /// 如果文件名无法解析则使用文件的修改时间。
  static Future<List<_BackupFileInfo>> _listBackupInfos(
      String backupRoot) async {
    final dir = Directory(backupRoot);
    if (!await dir.exists()) return [];

    final entries = await dir.list().toList();
    final infos = <_BackupFileInfo>[];

    for (final entry in entries) {
      DateTime? fileTime;
      final name = p.basename(entry.path);

      // 优先从文件名提取时间戳
      final ts = _extractTimestampFromFilename(name);
      if (ts != null) {
        fileTime = ts;
      }

      if (entry is File && entry.path.endsWith('.zip')) {
        try {
          DateTime modified;
          if (fileTime != null) {
            modified = fileTime;
          } else {
            final stat = await entry.stat();
            modified = stat.modified;
          }
          infos.add(_BackupFileInfo(
            path: entry.path,
            name: name,
            modified: modified,
            isDirectory: false,
          ));
        } catch (e) {
          debugPrint('[AutoBackupService] 无法获取文件信息 ${entry.path}: $e');
        }
      } else if (entry is Directory && name.startsWith('backup_')) {
        try {
          DateTime modified;
          if (fileTime != null) {
            modified = fileTime;
          } else {
            final stat = await entry.stat();
            modified = stat.modified;
          }
          infos.add(_BackupFileInfo(
            path: entry.path,
            name: name,
            modified: modified,
            isDirectory: true,
          ));
        } catch (e) {
          debugPrint('[AutoBackupService] 无法获取目录信息 ${entry.path}: $e');
        }
      }
    }

    // 按修改时间从新到旧排序
    infos.sort((a, b) => b.modified.compareTo(a.modified));
    return infos;
  }

  /// 获取 SAF 模式下的备份文件信息列表。
  static Future<List<_BackupFileInfo>> _listBackupInfosSaf() async {
    final files = await BackupLocationManager.listBackupFiles();
    final zipFiles = files.where((f) => f.endsWith('.zip')).toList();
    zipFiles.sort();

    final infos = <_BackupFileInfo>[];
    for (final name in zipFiles) {
      final ts = _extractTimestampFromFilename(name);
      if (ts != null) {
        infos.add(_BackupFileInfo(
          path: name,
          name: name,
          modified: ts,
          isDirectory: false,
        ));
      }
    }

    // 按时间从新到旧排序
    infos.sort((a, b) => b.modified.compareTo(a.modified));
    return infos;
  }

  /// 根据保留策略决定要删除的备份文件。
  ///
  /// 策略：
  /// 1. 最多保留 5 个备份（总数限制）
  /// 2. 24 小时内最多保留 3 个备份
  /// 3. 额外保留最近 2 次使用日的最后一个备份（超出 24h 的）
  ///
  /// 返回需要删除的文件路径列表。
  static List<_BackupFileInfo> _selectBackupsToDelete(
      List<_BackupFileInfo> infos) {
    // 如果备份总数不超过 3 个（24h 内的限制），则无需删除
    if (infos.length <= 3) return [];

    final now = DateTime.now();

    // 步骤 1: 从最新的开始，挑选需要保留的
    final keepList = <_BackupFileInfo>[];
    final deleteList = <_BackupFileInfo>[];

    // 获取 24h 内的备份（最新的 3 个）
    final within24h = <_BackupFileInfo>[];
    // 获取超出 24h 的备份
    final beyond24h = <_BackupFileInfo>[];

    for (final info in infos) {
      if (info.modified.isAfter(now.subtract(const Duration(hours: 24)))) {
        within24h.add(info);
      } else {
        beyond24h.add(info);
      }
    }

    // 24h 内最多保留 3 个
    if (within24h.length > 3) {
      // 只保留最新的 3 个
      for (var i = 3; i < within24h.length; i++) {
        deleteList.add(within24h[i]);
      }
      keepList.addAll(within24h.sublist(0, 3));
    } else {
      keepList.addAll(within24h);
    }

    // 对于超出 24h 的备份，保留最近 2 次使用日的最后一个备份
    // "使用日" = 备份文件所在的不同日期
    final keptUsageDays = <String>{};
    for (final info in keepList) {
      final dayKey =
          '${info.modified.year}-${info.modified.month}-${info.modified.day}';
      keptUsageDays.add(dayKey);
    }

    // 从超出 24h 的备份中，按日期分组，取每个日期最新的一个
    final dayToLatest = <String, _BackupFileInfo>{};
    for (final info in beyond24h) {
      final dayKey =
          '${info.modified.year}-${info.modified.month}-${info.modified.day}';
      // 如果该日期已有条目，取时间更新的
      final existing = dayToLatest[dayKey];
      if (existing == null || info.modified.isAfter(existing.modified)) {
        dayToLatest[dayKey] = info;
      }
    }

    // 按日期从新到旧排序
    final sortedDays = dayToLatest.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // 额外保留最多 2 个非 24h 内的不同使用日的最后一个备份
    // 总数不超过 5 个
    for (final entry in sortedDays) {
      if (keepList.length >= 5) break;
      if (keptUsageDays.contains(entry.key)) continue; // 已在保留列表中
      keepList.add(entry.value);
      keptUsageDays.add(entry.key);
    }

    // 如果仍有超出 5 个的，删除最旧的
    if (keepList.length > 5) {
      keepList.sort((a, b) => a.modified.compareTo(b.modified));
      while (keepList.length > 5) {
        final oldest = keepList.removeAt(0);
        deleteList.add(oldest);
      }
    }

    // 标记所有不在 keepList 中的为删除
    final keepPaths = keepList.map((e) => e.path).toSet();
    final deletePaths = deleteList.map((e) => e.path).toSet();
    for (final info in infos) {
      if (!keepPaths.contains(info.path) && !deletePaths.contains(info.path)) {
        deleteList.add(info);
      }
    }

    // 确保不超过 5 个（以防逻辑错误）
    final finalKeepCount = infos.length - deleteList.length;
    if (finalKeepCount > 5) {
      // 需要额外删除
      final toRemove = finalKeepCount - 5;
      // 从 keepList 中移除最旧的
      keepList.sort((a, b) => a.modified.compareTo(b.modified));
      for (var i = 0; i < toRemove && i < keepList.length; i++) {
        if (!deletePaths.contains(keepList[i].path)) {
          deleteList.add(keepList[i]);
          deletePaths.add(keepList[i].path);
        }
      }
    }

    return deleteList;
  }

  /// 清理旧备份（非 SAF 模式），按新保留策略执行。
  ///
  /// 新策略：
  /// - 最多保留 5 个备份（总数限制）
  /// - 24 小时内最多保留 3 个备份
  /// - 额外保留最近 2 次使用日的最后一个备份（超出 24h 的）
  static Future<void> _cleanupOldBackups(String backupRoot) async {
    try {
      final dir = Directory(backupRoot);
      if (!await dir.exists()) return;

      final infos = await _listBackupInfos(backupRoot);
      if (infos.isEmpty) return;

      final toDelete = _selectBackupsToDelete(infos);

      if (toDelete.isEmpty) {
        debugPrint('[AutoBackupService] 清理旧备份: 无需删除 (共 ${infos.length} 个)');
        return;
      }

      int deletedCount = 0;
      for (final info in toDelete) {
        try {
          if (info.isDirectory) {
            await Directory(info.path).delete(recursive: true);
          } else {
            await File(info.path).delete();
          }
          debugPrint('[AutoBackupService] 删除旧备份: ${info.name}');
          deletedCount++;
        } catch (e) {
          debugPrint('[AutoBackupService] 删除备份失败 ${info.name}: $e');
        }
      }

      await AppLogService.info('AutoBackupService',
          '清理旧备份完成: 删除了 $deletedCount 个, 剩余 ${infos.length - toDelete.length} 个');
    } catch (e) {
      debugPrint('[AutoBackupService] 清理旧备份失败: $e');
      await AppLogService.error('AutoBackupService', '清理旧备份失败', e);
    }
  }

  /// 清理旧备份（SAF 模式），按新保留策略执行。
  static Future<void> _cleanupOldBackupsSaf() async {
    try {
      final infos = await _listBackupInfosSaf();
      if (infos.isEmpty) return;

      final toDelete = _selectBackupsToDelete(infos);

      if (toDelete.isEmpty) {
        debugPrint(
            '[AutoBackupService] 清理旧备份(SAF): 无需删除 (共 ${infos.length} 个)');
        return;
      }

      int deletedCount = 0;
      for (final info in toDelete) {
        try {
          await BackupLocationManager.deleteBackupFile(info.name);
          debugPrint('[AutoBackupService] 删除旧备份(SAF): ${info.name}');
          deletedCount++;
        } catch (e) {
          debugPrint('[AutoBackupService] 删除备份失败(SAF) ${info.name}: $e');
        }
      }

      await AppLogService.info('AutoBackupService',
          '清理旧备份(SAF)完成: 删除了 $deletedCount 个, 剩余 ${infos.length - toDelete.length} 个');
    } catch (e) {
      debugPrint('[AutoBackupService] 清理旧备份失败(SAF): $e');
      await AppLogService.error('AutoBackupService', '清理旧备份失败(SAF)', e);
    }
  }

  /// 清理备份目录中的旧备份，按新保留策略执行。
  ///
  /// 供 [DataMigrationService] 等外部调用。
  static Future<void> cleanupOldBackups() async {
    if (await BackupLocationManager.isUsingSafMode()) {
      await _cleanupOldBackupsSaf();
    } else {
      final backupRoot = await DataMigrationService.getExternalBackupRootPath();
      await _cleanupOldBackups(backupRoot);
    }
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
}

/// 备份文件信息，用于保留策略排序。
class _BackupFileInfo {
  final String path;
  final String name;
  final DateTime modified;
  final bool isDirectory;

  const _BackupFileInfo({
    required this.path,
    required this.name,
    required this.modified,
    required this.isDirectory,
  });
}
