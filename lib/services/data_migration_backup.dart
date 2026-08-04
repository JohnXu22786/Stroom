part of 'data_migration_service.dart';

// ====================================================================
// 备份相关静态方法（从 DataMigrationService 拆出，控制主文件行数）
// ====================================================================

/// 备份辅助：外部仍通过 DataMigrationService.xxx 委托调用，
/// 公开 API 与日志前缀保持不变。
class DataMigrationBackup {
  /// 获取外部备份根目录。
  ///
  /// 注意：此方法委托给 [BackupLocationManager.getBackupRootPath]。
  /// 在 Android 上如果 SAF URI 尚未配置，会返回 null。
  static Future<String> getExternalBackupRootPath() async {
    if (kIsWeb) {
      return '/stroom_backups';
    }

    // 测试环境：每个测试 isolate 独立的临时目录（见 BackupLocationManager.testBackupRoot）
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        return BackupLocationManager.testBackupRoot;
      }
    } catch (e) {
      debugPrint('[DataMigrationService] Error checking test env: $e');
    }

    // 委托给 BackupLocationManager
    final path = await BackupLocationManager.getBackupRootPath();
    if (path != null) {
      return path;
    }

    // 兜底：系统临时目录
    try {
      return '${Directory.systemTemp.path}/Stroom/AutoBackups';
    } catch (_) {
      return '/tmp/Stroom/AutoBackups';
    }
  }

  /// 创建当前数据的完整 ZIP 备份。
  ///
  /// 使用 [AutoBackupService] 创建包含所有应用数据的完整备份
  /// 到 Stroom/AutoBackups 目录。备份文件格式为：
  ///   backup_YYYY-MM-DDTHH-MM-SS.zip
  ///
  /// 返回备份文件路径，如果备份失败返回 `null`。
  static Future<String?> createBackup() async {
    if (kIsWeb) {
      debugPrint(
          '[DataMigrationService] File system backup not supported on web');
      return null;
    }

    try {
      final success = await AutoBackupService.performAutoBackup(
        isPreMigration: true,
      );
      if (!success) return null;

      // Android SAF 模式下备份通过 SAF 写入用户选择的公共目录，
      // 备份根路径是虚拟的 'saf://content://...'，本地文件系统上
      // 不存在，不能用 Directory.exists() 校验 —— 改用 SAF 文件列表
      // 验证并返回文件名作为非 null 标记。
      if (await BackupLocationManager.isUsingSafMode()) {
        final files = await BackupLocationManager.listBackupFiles();
        final newest = latestZipName(files);
        if (newest == null) return null;
        debugPrint('[DataMigrationService] SAF backup verified: $newest');
        return newest;
      }

      // 获取最新的备份文件路径
      final backupRoot = await getExternalBackupRootPath();
      final backupDir = Directory(backupRoot);
      if (!await backupDir.exists()) return null;

      final entries = await backupDir.list().toList();
      final zipFiles = entries
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();
      if (zipFiles.isEmpty) return null;

      // 按修改时间排序，取最新的
      zipFiles.sort((a, b) {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          return 0;
        }
      });

      debugPrint(
          '[DataMigrationService] Backup created at ${zipFiles.first.path}');
      return zipFiles.first.path;
    } catch (e) {
      debugPrint('[DataMigrationService] Failed to create backup: $e');
      return null;
    }
  }

  /// 清理旧备份，保留至少 3 个最新的。
  ///
  /// 委托给 [AutoBackupService.cleanupOldBackups] 执行。
  /// 在每次启动时自动调用，确保旧备份不会无限累积。
  static Future<void> cleanOldBackups() async {
    if (kIsWeb) return;
    await AppLogService.info('DataMigrationService', '开始清理旧备份');
    await AutoBackupService.cleanupOldBackups();
    await AppLogService.info('DataMigrationService', '旧备份清理完成');
  }

  /// 从 SAF 文件列表中找出最新的 zip 备份文件名。
  ///
  /// SAF 返回的列表未排序且可能包含非 zip 文件（如访问测试临时文件），
  /// 必须过滤 .zip 并按文件名排序（`backup_2026-01-01T00-00-00.zip`
  /// 这类 ISO 时间戳文件名的字典序即时间序）。无匹配时返回 `null`。
  @visibleForTesting
  static String? latestZipName(List<String> files) {
    final zips = files.where((f) => f.endsWith('.zip')).toList()..sort();
    return zips.isEmpty ? null : zips.last;
  }
}
