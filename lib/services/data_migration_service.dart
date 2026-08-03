import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart' show legacyToBlocks;
import 'app_log_service.dart';
import 'auto_backup_service.dart';
import 'backup_location_manager.dart';
import 'manifest_database.dart';

part 'data_migration_backup.dart';
part 'data_migration_old_configs.dart';

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
  static const int currentFormatVersion = 3;

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
  /// - iOS:     `<app_group>`/Documents/Stroom/AutoBackups/（通过文件 App 可访问）
  /// - 测试环境: `Directory.systemTemp/stroom_backup_test_<随机后缀>/`（每个测试 isolate 独立）
  ///
  /// 获取外部备份根目录（委托 [DataMigrationBackup]，实现见
  /// data_migration_backup.dart）。
  static Future<String> getExternalBackupRootPath() =>
      DataMigrationBackup.getExternalBackupRootPath();

  /// 创建当前数据的完整 ZIP 备份（委托 [DataMigrationBackup]）。
  static Future<String?> createBackup() => DataMigrationBackup.createBackup();

  /// 清理旧备份，保留至少 3 个最新的（委托 [DataMigrationBackup]）。
  static Future<void> cleanOldBackups() =>
      DataMigrationBackup.cleanOldBackups();

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
      case 2:
        await _migrateV2ToV3();
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

  /// 迁移旧 chat_configs 到 provider_entries（委托 [DataMigrationOldConfigs]，
  /// 实现见 data_migration_old_configs.dart）。
  static Future<void> _migrateOldChatConfigs(SharedPreferences prefs) =>
      DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

  /// 修复 provider_entries 中 id 为 null 的条目（委托 [DataMigrationOldConfigs]）。
  static Future<void> _fixNullIdsInProviderEntries(SharedPreferences prefs) =>
      DataMigrationOldConfigs.fixNullIdsInProviderEntries(prefs);

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

  /// v2→v3: Convert old assistant messages to unified block format.
  static Future<void> _migrateV2ToV3() async {
    debugPrint('[DataMigrationService] v2→v3: Starting block migration');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('conversations');
    if (raw == null || raw.isEmpty) return;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      var migrated = 0;
      var skipped = 0;
      for (final c in list) {
        // 非 Map 对话条目属于损坏数据：跳过（结构性错误才会 rethrow）
        if (c is! Map) {
          skipped++;
          continue;
        }
        final messagesRaw = c['messages'];
        final messages = messagesRaw is List ? messagesRaw : <dynamic>[];
        for (final m in messages) {
          // 非 Map 消息属于损坏数据：跳过而不是当作结构性错误
          // （结构性错误会 rethrow 导致版本号永不提升、每次启动
          // 都重复迁移与备份）。
          if (m is! Map) {
            skipped++;
            continue;
          }
          if (m['role'] != 'assistant') continue;
          final blocksRaw = m['blocks'];
          if (blocksRaw is List && blocksRaw.isNotEmpty) continue;
          try {
            final blocks = legacyToBlocks(
              reasoningSections:
                  (m['reasoningSections'] as List<dynamic>?)?.cast<String>() ??
                      [],
              textChunks:
                  (m['textSections'] as List<dynamic>?)?.cast<String>() ?? [],
              toolCalls: ((m['toolCalls'] as List<dynamic>?) ?? [])
                  .map((tc) =>
                      ToolCallData.fromMap(Map<String, dynamic>.from(tc)))
                  .toList(),
              toolCallRoundStarts:
                  (m['toolCallRoundStarts'] as List<dynamic>?)?.cast<int>() ??
                      [],
            );
            if (blocks.isNotEmpty) {
              m['blocks'] = blocks.map((b) => b.toMap()).toList();
              migrated++;
            }
          } catch (e) {
            // 单条消息数据损坏（如 toolCalls 非 Map）：跳过该条，
            // 不中断整批迁移（fromMap 层同样防御，缺 blocks 可容忍）。
            // 仅当结构性错误（jsonDecode 失败等）才整体上抛。
            skipped++;
            debugPrint('[DataMigrationService] v2→v3: 跳过损坏消息: $e');
          }
        }
      }
      await prefs.setString('conversations', jsonEncode(list));
      debugPrint('[DataMigrationService] v2→v3: Migrated $migrated messages'
          '${skipped > 0 ? ', skipped $skipped corrupt entries' : ''}');
    } catch (e) {
      // 结构性迁移失败（jsonDecode 失败等）必须上抛：否则
      // checkAndMigrate 会把版本号升到 3，数据永久停留在"假成功"
      // 状态且永远不会重试。上抛后版本号不提升，下次启动自动重试
      // （startup 层会捕获并继续启动）。
      debugPrint('[DataMigrationService] v2→v3 migration failed: $e');
      rethrow;
    }
  }
}
