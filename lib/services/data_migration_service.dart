import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'storage_service.dart';

/// The key used in SharedPreferences to store the data format version.
const String _kDataFormatVersionKey = 'data_format_version';

// ====================================================================
// MigrationResult — result of checkAndMigrate()
// ====================================================================

/// The result of a data format version check or migration.
class MigrationResult {
  /// Whether a data migration is needed.
  final bool needsMigration;

  /// Whether the app must be restarted after migration.
  ///
  /// This is set to `true` when the migration requires the app to restart
  /// to load the new data format (e.g., when database schema changes).
  /// When `false`, the migration is seamless and the app can continue
  /// without restart.
  final bool restartRequired;

  const MigrationResult({
    required this.needsMigration,
    this.restartRequired = false,
  });
}

// ====================================================================
// DataMigrationService — 数据格式版本检查与迁移
// ====================================================================
//
// 启动时检查数据格式版本。如果版本过低，则执行迁移。
// 每次迁移前会自动创建旧数据备份（保留 2 天后自动清理）。
// ====================================================================

class DataMigrationService {
  DataMigrationService._();

  /// 当前应用支持的数据格式版本。
  ///
  /// 每次数据格式变更（非兼容变更）时，递增此值。
  /// 低版本的数据会在启动时自动迁移到当前版本。
  static const int currentFormatVersion = 1;

  // ================================================================
  // 版本检查
  // ================================================================

  /// 获取存储的数据格式版本。如果从未存储过，返回 0。
  static Future<int> getStoredFormatVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kDataFormatVersionKey) ?? 0;
  }

  /// 检查并执行数据迁移。
  ///
  /// 返回 [MigrationResult]，指示是否需要迁移以及是否需要重启。
  ///
  /// 调用此方法后：
  /// - 如果 [MigrationResult.needsMigration] 为 `true`，调用者应展示迁移对话框。
  /// - 如果 [MigrationResult.restartRequired] 为 `true`，迁移完成后需要重启应用。
  static Future<MigrationResult> checkAndMigrate() async {
    final storedVersion = await getStoredFormatVersion();

    // 版本相同时不需要迁移
    if (storedVersion >= currentFormatVersion) {
      return const MigrationResult(needsMigration: false);
    }

    // 需要迁移：先从旧版清理
    await cleanOldBackups();

    // 创建备份
    await createBackup();

    // 执行迁移
    await _performMigration(storedVersion, currentFormatVersion);

    // 更新存储的版本号
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDataFormatVersionKey, currentFormatVersion);

    debugPrint(
      '[DataMigrationService] Migrated data format from v$storedVersion to v$currentFormatVersion',
    );

    // 当前版本 (1) 的迁移不需要重启
    return const MigrationResult(
      needsMigration: true,
      restartRequired: false,
    );
  }

  // ================================================================
  // 备份管理
  // ================================================================

  /// 备份目录名称
  static const String _backupRootName = 'data_backup';

  /// 获取备份根目录路径。
  static Future<String> _getBackupRootPath() async {
    final appDir = await AppStorage.directory;
    return p.join(appDir, _backupRootName);
  }

  /// 创建当前数据的时间戳备份。
  ///
  /// 备份内容：
  /// - `manifest.json` — 备份元数据（时间、旧版本号）
  /// - `preferences.json` — SharedPreferences 快照
  ///
  /// 返回备份目录路径，如果备份创建失败返回 `null`。
  static Future<String?> createBackup() async {
    if (kIsWeb) {
      debugPrint('[DataMigrationService] Backup not supported on web');
      return null;
    }

    try {
      final backupRoot = await _getBackupRootPath();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupDir = Directory(p.join(backupRoot, 'backup_$timestamp'));
      await backupDir.create(recursive: true);

      // 1. Create manifest.json
      final manifest = {
        'formatVersion': await getStoredFormatVersion(),
        'createdAt': DateTime.now().toIso8601String(),
        'backupType': 'pre_migration',
      };
      await File(p.join(backupDir.path, 'manifest.json'))
          .writeAsString(jsonEncode(manifest));

      // 2. Backup SharedPreferences (excluding flutter internal keys)
      final prefs = await SharedPreferences.getInstance();
      final prefData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('flutter.')) continue;
        prefData[key] = prefs.get(key);
      }
      await File(p.join(backupDir.path, 'preferences.json'))
          .writeAsString(jsonEncode(prefData));

      debugPrint('[DataMigrationService] Backup created at ${backupDir.path}');
      return backupDir.path;
    } catch (e) {
      debugPrint('[DataMigrationService] Failed to create backup: $e');
      return null;
    }
  }

  /// 清理超过 2 天的旧备份。
  ///
  /// 在每次迁移前自动调用，确保旧备份不会无限累积。
  static Future<void> cleanOldBackups() async {
    if (kIsWeb) return;

    try {
      final backupRootPath = await _getBackupRootPath();
      final backupRoot = Directory(backupRootPath);

      if (!await backupRoot.exists()) return;

      final cutoff = DateTime.now().subtract(const Duration(days: 2));
      final entries = backupRoot.listSync();

      for (final entry in entries) {
        if (entry is! Directory) continue;
        try {
          final stat = entry.statSync();
          if (stat.modified.isBefore(cutoff) ||
              stat.modified.isAtSameMomentAs(cutoff)) {
            await entry.delete(recursive: true);
            debugPrint(
              '[DataMigrationService] Cleaned old backup: ${entry.path}',
            );
          }
        } catch (e) {
          debugPrint(
            '[DataMigrationService] Failed to clean backup ${entry.path}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[DataMigrationService] Failed to clean old backups: $e');
    }
  }

  // ================================================================
  // 迁移步骤
  // ================================================================

  /// 执行从 [fromVersion] 到 [toVersion] 的数据迁移。
  ///
  /// 每个版本的迁移步骤以递增方式添加。
  /// 例如，从 v0 迁移到 v3 会依次执行 v0→v1、v1→v2、v2→v3 的步骤。
  static Future<void> _performMigration(int fromVersion, int toVersion) async {
    for (int v = fromVersion; v < toVersion; v++) {
      await _migrateFrom(v);
    }
  }

  /// 执行从指定版本的迁移。
  ///
  /// 每个 case 对应一个版本的迁移逻辑。
  /// v0 → v1: 首次引入数据格式版本跟踪，无需实际数据变更。
  static Future<void> _migrateFrom(int version) async {
    switch (version) {
      case 0:
        // v0 → v1: 首次引入数据格式版本，无需数据变更。
        // 这是一个标记性迁移，所有现有数据在旧版本中已兼容。
        debugPrint('[DataMigrationService] Migrating from v0 to v1: '
            'initial format versioning (no data changes needed)');
        break;
      // 未来版本：
      // case 1:
      //   // v1 → v2: 示例迁移步骤
      //   await _migrateV1ToV2();
      //   break;
      default:
        debugPrint('[DataMigrationService] No migration steps defined '
            'for version v$version');
    }
  }

  // 未来版本迁移示例：
  // static Future<void> _migrateV1ToV2() async {
  //   debugPrint('[DataMigrationService] Executing v1 → v2 migration...');
  //   // ... 实际的迁移逻辑
  // }
}
