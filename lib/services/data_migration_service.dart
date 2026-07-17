import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log_service.dart';
import 'auto_backup_service.dart';
import 'backup_location_manager.dart';
import 'manifest_database.dart';

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
// 每次启动时检查数据格式版本。如果版本过低，则执行迁移。
// 每次迁移前会自动创建完整数据备份。备份目录至少保留 3 个
// 最新的备份文件，超出部分自动清理。
// ====================================================================

class DataMigrationService {
  DataMigrationService._();

  /// 当前应用支持的数据格式版本。
  ///
  /// 每次数据格式变更（非兼容变更）时，递增此值。
  /// 低版本的数据会在启动时自动迁移到当前版本。
  ///
  /// # 版本历史
  /// - v0: 初始版本（无版本号记录）
  /// - v1: 引入 data_format_version; 迁移 old chat_configs → provider_entries
  /// - v2: 移除共享 folders 表, 全部改为每个类型独立的文件夹表
  static const int currentFormatVersion = 2;

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
  /// 每次启动都会执行此检查，确保数据格式是最新的。
  ///
  /// 调用此方法后：
  /// - 如果 [MigrationResult.needsMigration] 为 `true`，调用者应展示迁移对话框。
  /// - 如果 [MigrationResult.restartRequired] 为 `true`，迁移完成后需要重启应用。
  static Future<MigrationResult> checkAndMigrate() async {
    final storedVersion = await getStoredFormatVersion();
    await AppLogService.info('DataMigrationService',
        '检查数据格式版本: 当前=$storedVersion, 最新=$currentFormatVersion');

    // 版本相同时不需要迁移
    if (storedVersion >= currentFormatVersion) {
      await AppLogService.info('DataMigrationService', '数据格式版本为最新，无需迁移');
      return const MigrationResult(needsMigration: false);
    }

    await AppLogService.info('DataMigrationService',
        '需要数据格式迁移: v$storedVersion → v$currentFormatVersion');

    // 需要迁移：清理旧备份
    await cleanOldBackups();

    try {
      // 创建备份到外部位置
      await createBackup();

      // 执行迁移
      await _performMigration(storedVersion, currentFormatVersion);

      // 更新存储的版本号
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDataFormatVersionKey, currentFormatVersion);

      debugPrint(
        '[DataMigrationService] Migrated data format from v$storedVersion to v$currentFormatVersion',
      );
      await AppLogService.info('DataMigrationService',
          '数据格式迁移成功: v$storedVersion → v$currentFormatVersion');
    } catch (e) {
      debugPrint('[DataMigrationService] Migration failed: $e');
      await AppLogService.error('DataMigrationService', '数据格式迁移失败', e);
      rethrow;
    }

    // 迁移完成后总是需要重启应用，确保所有 provider 和服务
    // 以新的数据格式重新初始化，避免因旧状态导致闪退。
    return const MigrationResult(
      needsMigration: true,
      restartRequired: true,
    );
  }

  // ================================================================
  // 备份管理
  // ================================================================

  /// 获取外部备份根目录路径。
  ///
  /// 备份位置不在应用数据目录内，以防止应用数据被删除时备份也丢失。
  ///
  /// 位置策略（所有位置均对用户可见/可访问）：
  /// - Windows: %USERPROFILE%\Documents\Stroom\AutoBackups\
  /// - macOS:   ~/Documents/Stroom/AutoBackups/
  /// - Linux:   ~/Documents/Stroom/AutoBackups/
  /// - Android: 通过 SAF 选择 Documents 目录（优先），
  ///   用户选择后调用 takePersistableUriPermission 固化权限。
  /// - iOS:     <app_group>/Documents/Stroom/AutoBackups/（通过文件 App 可访问）
  /// - 测试环境: Directory.systemTemp/stroom_backup_test/
  ///
  /// 注意：此方法委托给 [BackupLocationManager.getBackupRootPath]。
  /// 在 Android 上如果 SAF URI 尚未配置，会返回 null。
  static Future<String> getExternalBackupRootPath() async {
    if (kIsWeb) {
      return '/stroom_backups';
    }

    // 测试环境：使用临时目录
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        return '${Directory.systemTemp.path}/stroom_backup_test';
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
  /// - v0 → v1: 首次引入数据格式版本，执行实际的 SharedPreferences 数据迁移。
  /// - v1 → v2: 移除共享 folders 表，数据迁移到每个类型独立的文件夹表。
  static Future<void> _migrateFrom(int version) async {
    switch (version) {
      case 0:
        await _migrateV0ToV1();
        break;
      case 1:
        await _migrateV1ToV2();
        break;
      default:
        debugPrint('[DataMigrationService] No migration steps defined '
            'for version v$version');
    }
  }

  /// Migrate the stored data to the current format if needed, WITHOUT
  /// the startup-side effects of [checkAndMigrate].
  ///
  /// Unlike [checkAndMigrate], this method:
  /// - Does NOT create external backups
  /// - Does NOT check crash recovery flags
  /// - Does NOT clean old backups
  /// - ONLY runs the migration steps and updates the version
  ///
  /// This is suitable for situations where data has been freshly restored
  /// from a backup and needs to be brought up to date, or when running
  /// migration in contexts where file system backup is not needed.
  static Future<MigrationResult> migrateDataFormatIfNeeded() async {
    final storedVersion = await getStoredFormatVersion();

    if (storedVersion >= currentFormatVersion) {
      return const MigrationResult(needsMigration: false);
    }

    try {
      await _performMigration(storedVersion, currentFormatVersion);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kDataFormatVersionKey, currentFormatVersion);
      debugPrint(
        '[DataMigrationService] Migrated data format from v$storedVersion '
        'to v$currentFormatVersion',
      );
    } catch (e) {
      debugPrint('[DataMigrationService] Data format migration failed: $e');
      rethrow;
    }

    return const MigrationResult(
      needsMigration: true,
      restartRequired: true,
    );
  }

  /// v0 → v1: 实际的 SharedPreferences 数据格式迁移。
  ///
  /// 将旧版数据格式统一迁移到新版格式，确保所有 provider 在迁移完成
  /// 后的首次初始化时读取到的数据已是正确格式，避免因格式不兼容
  /// 导致的重复闪退（keeps stopping）问题。
  static Future<void> _migrateV0ToV1() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('[DataMigrationService] v0→v1: Starting data format migration');

    // --- 第1步：迁移旧版 chat_configs → provider_entries ---
    await _migrateOldChatConfigs(prefs);

    // --- 第2步：修复 provider_entries 中的空 ID 字段 ---
    await _fixNullIdsInProviderEntries(prefs);

    // --- 第3步：移除旧 key，防止重复迁移 ---
    await prefs.remove('migrated_old_conversations');
    await prefs.remove('data_format_version_migrated');

    debugPrint(
        '[DataMigrationService] v0→v1: Migration completed successfully');
  }

  /// 迁移旧版 chat_configs（被重构删除的格式）到 provider_entries。
  static Future<void> _migrateOldChatConfigs(SharedPreferences prefs) async {
    final oldJson = prefs.getString('chat_configs');
    if (oldJson == null || oldJson.isEmpty) return;

    try {
      // 兜底：使用 whereType 安全过滤非 Map 条目
      final oldList = (jsonDecode(oldJson) as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      if (oldList.isEmpty) return;

      final migratedConfigs = <Map<String, dynamic>>[];
      for (final oldItem in oldList) {
        // 兜底：安全过滤 models 中的非 Map 条目
        final oldModels = (oldItem['models'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];

        final models = oldModels.map((m) {
          final typeConfig = <String, dynamic>{};
          final maxTokens = m['maxTokens'] ?? m['context'];
          if (maxTokens != null) typeConfig['context'] = maxTokens;
          final temperature = m['temperature'];
          if (temperature != null) typeConfig['temperature'] = temperature;

          return <String, dynamic>{
            'name': m['modelId'] as String? ?? '',
            'modelId': m['modelId'] as String? ?? '',
            'supportStream': m['supportStream'] as bool? ?? true,
            'typeConfig': typeConfig,
          };
        }).toList();

        migratedConfigs.add(<String, dynamic>{
          'providerName': oldItem['providerName'] as String? ?? '',
          'host': oldItem['host'] as String? ?? '',
          'key': oldItem['key'] as String? ?? '',
          'models': models,
        });
      }

      if (migratedConfigs.isEmpty) return;

      // 读取或初始化当前 provider_entries
      String? existingJson;
      try {
        existingJson = prefs.getString('provider_entries');
      } catch (_) {}

      List<Map<String, dynamic>> existingEntries = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          // 兜底：使用 whereType 安全过滤非 Map 条目
          existingEntries = (jsonDecode(existingJson) as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        } catch (_) {
          // 现有数据损坏，忽略并用空列表重新开始
        }
      }

      // 如果已有 llm 类型条目则不覆盖
      final hasLlmEntry = existingEntries
          .any((e) => e['type'] == 'llm' && e['id'] != 'builtin_llm');
      if (!hasLlmEntry) {
        existingEntries.add({
          'id': 'migrated_llm',
          'type': 'llm',
          'name': 'LLM供应商',
          'configs': migratedConfigs,
        });

        await prefs.setString('provider_entries', jsonEncode(existingEntries));
        debugPrint(
            '[DataMigrationService] Migrated ${oldList.length} old chat config(s) to provider_entries');
      }

      // 删除旧数据，防止 provider 级别重复迁移
      await prefs.remove('chat_configs');
      await prefs.remove('chat_selected_config_id');
    } catch (e) {
      debugPrint(
          '[DataMigrationService] Failed to migrate old chat configs: $e');
    }
  }

  /// 修复 provider_entries 中所有条目的 id 字段不为空。
  ///
  /// 旧版数据中某些条目的 id 可能为 null，导致 ProviderEntry.fromMap()
  /// 在 `map['id'] as String` 处抛出 TypeError，进而引发闪退。
  static Future<void> _fixNullIdsInProviderEntries(
      SharedPreferences prefs) async {
    final json = prefs.getString('provider_entries');
    if (json == null || json.isEmpty) return;

    try {
      // 兜底：使用 whereType 安全过滤非 Map 条目
      final list =
          (jsonDecode(json) as List).whereType<Map<String, dynamic>>().toList();
      bool changed = false;

      for (int i = 0; i < list.length; i++) {
        final entry = list[i];
        if (entry['id'] == null || (entry['id'] as String?)?.isEmpty == true) {
          // 为 null id 的条目生成一个唯一 ID
          final type = entry['type'] as String? ?? 'unknown';
          entry['id'] = 'migrated_${type}_$i';
          changed = true;
          debugPrint(
              '[DataMigrationService] Fixed null id for provider entry at index $i (type: $type)');
        }

        // 修复自定义参数中缺少 type 字段的旧格式
        final configs = entry['configs'] as List?;
        if (configs != null) {
          for (final config in configs) {
            // 兜底：跳过非 Map 的 config 条目
            if (config is! Map<String, dynamic>) continue;
            final configMap = config;
            final models = configMap['models'] as List?;
            if (models == null) continue;
            for (final model in models) {
              // 兜底：跳过非 Map 的 model 条目
              if (model is! Map<String, dynamic>) continue;
              final modelMap = model;
              final customParams = modelMap['customParams'] as List?;
              if (customParams == null) continue;
              for (final param in customParams) {
                // 兜底：跳过非 Map 的 param 条目
                if (param is! Map<String, dynamic>) continue;
                final paramMap = param;
                if (paramMap['type'] == null) {
                  paramMap['type'] = 'string';
                  changed = true;
                }
              }
            }
          }
        }

        // 确保每条记录都有 type 字段（旧版可能缺失）
        if (entry['type'] == null ||
            (entry['type'] as String?)?.isEmpty == true) {
          entry['type'] = 'tts';
          changed = true;
          debugPrint(
              '[DataMigrationService] Fixed null type for provider entry at index $i');
        }
      }

      if (changed) {
        await prefs.setString('provider_entries', jsonEncode(list));
        debugPrint(
            '[DataMigrationService] Fixed null IDs/types in provider_entries');
      }
    } catch (e) {
      debugPrint('[DataMigrationService] Failed to fix provider entries: $e');
    }
  }

  /// v1 → v2: 移除共享 folders 表，完全迁移到每个类型独立的文件夹表。
  ///
  /// 迁移步骤：
  /// 1. 检测并迁移旧版共享 folders 表中的数据到 text/audio/image/video_folders
  /// 2. 删除旧版共享 folders 表（SQLite）或 key（JSON/web）
  /// 3. 迁移完成后，只保留每种类型独立的文件夹表
  ///
  /// 此迁移是幂等的：即使重复执行也不会有副作用。
  static Future<void> _migrateV1ToV2() async {
    try {
      debugPrint(
          '[DataMigrationService] v1→v2: Migrating legacy shared folders '
          'to per-type folder tables');

      await ManifestDatabase.migrateLegacyFoldersToPerType();

      debugPrint(
          '[DataMigrationService] v1→v2: Migration completed successfully');
    } catch (e) {
      // 迁移失败不阻塞启动，记录日志后继续
      debugPrint('[DataMigrationService] v1→v2 migration failed: $e');
    }
  }
}
