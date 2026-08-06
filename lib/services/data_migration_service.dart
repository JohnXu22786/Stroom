import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart' show legacyToBlocks;
import 'app_log_service.dart';
import 'auto_backup_service.dart';
import 'backup_location_manager.dart';
import 'manifest_database.dart';

part 'data_migration_backup.dart';
part 'data_migration_old_configs.dart';

/// 旧版（v3 及之前）使用的全局数据格式版本号 key。
///
/// 现在只作为「旧版本应用留下的数据」的识别输入：首次进入 per-part
/// 版本机制时，用它的值展开出每个部分的初始版本（见
/// [_expandFromLegacyGlobal]），随后该 key 被移除，不再写入。
/// 回滚到旧版应用后旧 key 会再次出现，此时 per-part 记录优先。
const String _kLegacyDataFormatVersionKey = 'data_format_version';

/// 各部分数据格式版本号的存储 key。
///
/// 值为 JSON 对象：`{"chat": 1, "settings": 1, "pictures": 1, ...}`，
/// 每个部分（与备份页的可选类别一一对应）各自记录自己的格式版本。
const String _kDataFormatVersionsKey = 'data_format_versions';

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
// DataParts — 数据部分标识符与各自的当前版本号
// ====================================================================
//
// 数据格式版本号从「全局单一版本号」改为「每部分各自独立版本号」。
// 分组与备份页（BackupSelection）的可选类别一一对应：
// 聊天记录和附件 / 设置 / 图片 / 音频 / 视频 / 文本 / 任务 /
// Anki闪卡数据 / 浏览器Cookies。
//
// 每个部分独立演进：某部分的格式变更只递增该部分的版本号，
// 其他部分不受影响。启动时只迁移版本落后的部分。
// ====================================================================

abstract final class DataParts {
  DataParts._();

  /// 聊天记录和附件（conversations / active_conversation_id + attachments/）。
  static const String chat = 'chat';

  /// 设置（所有设置相关 SharedPreferences 键）。
  static const String settings = 'settings';

  /// 图片（pictures/ 文件 + manifest image_records）。
  static const String pictures = 'pictures';

  /// 音频（tts_audio/ 文件 + manifest audio_records）。
  static const String audio = 'audio';

  /// 视频（videos/ 文件 + manifest video_records）。
  static const String videos = 'videos';

  /// 文本（texts/ 文件 + manifest text_records）。
  static const String texts = 'texts';

  /// 任务（synthesis/tasks.json + catcatch/tasks.json）。
  static const String tasks = 'tasks';

  /// Anki 闪卡数据库（collection.anki2）。
  static const String anki = 'anki';

  /// 浏览器Cookies持久化数据（browser_cookies.json）。
  static const String browserCookies = 'browserCookies';

  /// 所有部分（顺序即迁移执行顺序）。
  static const List<String> all = [
    chat,
    settings,
    pictures,
    audio,
    videos,
    texts,
    tasks,
    anki,
    browserCookies,
  ];

  /// 各部分当前支持的数据格式版本。
  ///
  /// 每次某部分的数据格式发生非兼容变更时，递增该部分的版本号。
  ///
  /// # 版本历史
  /// - chat v1: 引入统一 blocks 格式（旧全局 v2→v3 迁移：
  ///   assistant 消息的 reasoningSections/textSections/toolCalls
  ///   转为统一的 blocks 数组）
  /// - settings v1: 引入 provider_entries（旧全局 v0→v1 迁移：
  ///   old chat_configs → provider_entries + 修复 null id/type）
  /// - pictures/audio/videos/texts v1: 移除共享 folders 表，
  ///   全部改为每种类型独立的文件夹表（旧全局 v1→v2 迁移）
  /// - tasks/anki/browserCookies: 无迁移历史，当前版本 0（机制就位，
  ///   未来各自格式变更时从 1 开始递增）
  static const Map<String, int> currentVersions = {
    chat: 1,
    settings: 1,
    pictures: 1,
    audio: 1,
    videos: 1,
    texts: 1,
    tasks: 0,
    anki: 0,
    browserCookies: 0,
  };
}

// ====================================================================
// DataMigrationService — 数据格式版本检查与迁移
// ====================================================================
//
// 每次启动时检查每个数据部分的格式版本。版本落后的部分执行迁移。
// 每次迁移前会自动创建完整数据备份。备份目录至少保留 3 个
// 最新的备份文件，超出部分自动清理。
//
// 版本记录存储：
// - 新机制：`data_format_versions`（JSON，每部分各自的版本号）
// - 旧机制：`data_format_version`（单个全局整数，v3 及之前）
//   首次运行时从旧值展开出每部分的初始版本，随后移除旧 key。
// ====================================================================

class DataMigrationService {
  DataMigrationService._();

  /// 旧版全局格式版本号的最大值（v3 及之前使用的单一版本号机制）。
  ///
  /// 保留用于识别旧版应用留下的版本标记（展开为 per-part 版本时
  /// 使用，见 [_expandFromLegacyGlobal]）。新代码不再写入该 key。
  static const int currentFormatVersion = 3;

  // ================================================================
  // 部分标识符与版本常量（委托 DataParts）
  // ================================================================

  static const String partChat = DataParts.chat;
  static const String partSettings = DataParts.settings;
  static const String partPictures = DataParts.pictures;
  static const String partAudio = DataParts.audio;
  static const String partVideos = DataParts.videos;
  static const String partTexts = DataParts.texts;
  static const String partTasks = DataParts.tasks;
  static const String partAnki = DataParts.anki;
  static const String partBrowserCookies = DataParts.browserCookies;

  /// 所有数据部分的标识符（顺序即迁移执行顺序）。
  static const List<String> partIds = DataParts.all;

  /// 各部分当前支持的数据格式版本。
  static const Map<String, int> currentPartVersions = DataParts.currentVersions;

  // ================================================================
  // 版本检查
  // ================================================================

  /// 获取旧版全局数据格式版本（`data_format_version`）。
  ///
  /// 如果从未存储过，返回 0。仅用于识别旧版应用留下的数据；
  /// 新机制下版本记录在 [getStoredPartVersions]。
  static Future<int> getStoredFormatVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLegacyDataFormatVersionKey) ?? 0;
  }

  /// 获取各部分存储的数据格式版本。
  ///
  /// 返回 Map：部分标识符 → 版本号。从未存储过的部分按 0 处理
  ///（v0 = 初始版本，需要迁移到当前版本）。
  static Future<Map<String, int>> getStoredPartVersions() async {
    final stored = await _readPartVersions();
    if (stored == null) {
      return {for (final part in DataParts.all) part: 0};
    }
    return stored;
  }

  /// 读取存储的各部分版本（未存储或整体损坏时返回 null）。
  ///
  /// 逐键防御：某个部分的值类型错误（非数字）只将该部分按 0 处理，
  /// 不影响其他部分；整体解析失败才视为未存储（由调用方隔离现场）。
  static Future<Map<String, int>?> _readPartVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDataFormatVersionsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('[DataMigrationService] data_format_versions 不是合法对象，视为未存储');
        return null;
      }
      return {
        for (final part in DataParts.all)
          part: decoded[part] is num ? (decoded[part] as num).toInt() : 0,
      };
    } catch (e) {
      debugPrint('[DataMigrationService] data_format_versions 解析失败: $e');
      return null;
    }
  }

  /// 保存各部分版本到 SharedPreferences。
  ///
  /// 注意：记录按已知部分白名单（[DataParts.all]）重建 —— 未来版本
  /// 新增的第 10 个部分在回滚到本构建并发生写入时会丢失其记录
  ///（下次启动按 0 处理）。所有迁移步骤幂等，实际数据风险可忽略。
  static Future<void> _savePartVersions(Map<String, int> versions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDataFormatVersionsKey, jsonEncode(versions));
  }

  /// 确定各部分当前存储版本（非空）。
  ///
  /// 首次进入 per-part 机制（无 `data_format_versions`）时，从旧版
  /// 全局版本号展开出每部分的初始版本并立即落盘 —— 即使后续某部分
  /// 迁移失败，下次启动也只重试落后的部分。
  /// per-part 记录存在时旧全局 key 被清理（回滚再升级场景同样处理）。
  ///
  /// 版本记录本身损坏时（解析失败/非对象），按项目「先隔离再覆盖」
  /// 的约定保留损坏现场（带时间戳的隔离 key），再从旧全局版本或
  /// v0 展开重建 —— 迁移步骤全部幂等，重跑无害，但损坏证据不丢失。
  static Future<Map<String, int>> _resolvePartVersions(
      SharedPreferences prefs) async {
    final stored = await _readPartVersions();
    if (stored != null) {
      if (prefs.containsKey(_kLegacyDataFormatVersionKey)) {
        await prefs.remove(_kLegacyDataFormatVersionKey);
      }
      return stored;
    }
    final raw = prefs.getString(_kDataFormatVersionsKey);
    if (raw != null && raw.isNotEmpty) {
      await _quarantineCorruptData(prefs, 'data_format_versions', raw);
    }
    final legacy = prefs.getInt(_kLegacyDataFormatVersionKey) ?? 0;
    final expanded = _expandFromLegacyGlobal(legacy);
    await _savePartVersions(expanded);
    // 展开完成即接管版本管理：旧全局 key 退役（即使后续某部分迁移
    // 失败也不回退，per-part 记录是唯一事实来源）。
    if (prefs.containsKey(_kLegacyDataFormatVersionKey)) {
      await prefs.remove(_kLegacyDataFormatVersionKey);
    }
    debugPrint('[DataMigrationService] 已从旧全局版本 v$legacy '
        '展开 per-part 版本: $expanded');
    return expanded;
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
    final prefs = await SharedPreferences.getInstance();

    // 1. 确定各部分当前存储版本（首次进入 per-part 机制时从旧版
    // 全局版本号展开，见 _resolvePartVersions）。
    final stored = await _resolvePartVersions(prefs);

    final outdatedParts = DataParts.all
        .where((p) => (stored[p] ?? 0) < DataParts.currentVersions[p]!)
        .toList();

    if (outdatedParts.isEmpty) {
      await AppLogService.info('DataMigrationService', '数据格式版本为最新，无需迁移');
      return const MigrationResult(needsMigration: false);
    }

    final detail = outdatedParts
        .map((p) => '$p v${stored[p] ?? 0}→v${DataParts.currentVersions[p]}')
        .join(', ');
    await AppLogService.info('DataMigrationService', '需要数据格式迁移: $detail');

    // 需要迁移：清理旧备份
    await cleanOldBackups();

    try {
      // 创建备份到外部位置。
      // 备份失败（或并发备份被取消）时绝不继续迁移：没有安全快照
      // 的迁移一旦中途失败可能造成数据损坏。返回 needsMigration=false
      // 保持版本号不变，下次启动自动重试（与旧版 v2→v3 结构性失败
      // 「版本号永不提升」的哲学一致）。
      // Web 平台不支持本地备份（createBackup 恒返回 null），直接迁移。
      if (!kIsWeb) {
        final backupPath = await createBackup();
        if (backupPath == null) {
          debugPrint('[DataMigrationService] 迁移前备份失败，'
              '取消本次迁移（下次启动重试）');
          await AppLogService.error(
              'DataMigrationService', '迁移前备份失败，取消本次迁移（下次启动重试）');
          return const MigrationResult(needsMigration: false);
        }
      }

      // 执行迁移：只迁移版本落后的部分（顺序见 DataParts.all）
      await _performPartMigrations(stored);

      // 更新存储的版本号：只提升实际迁移过的部分。
      // 其他部分（包括高于当前版本的未来记录）保持原值 —— 绝不
      // 降级超前版本，否则「未来版本迁移后回滚再升级」会把已迁移
      // 的数据误判为需要重新迁移。
      await _recordMigratedParts(prefs, stored, outdatedParts);

      debugPrint('[DataMigrationService] Per-part data format migration '
          'completed: $detail');
      await AppLogService.info('DataMigrationService', '数据格式迁移成功: $detail');
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

  /// 从旧版全局版本号展开出每个部分的初始版本。
  ///
  /// 旧全局迁移链到各部分的映射：
  /// - v0→v1（chat_configs → provider_entries）：settings 部分
  /// - v1→v2（共享 folders → per-type 文件夹表）：pictures/audio/videos/texts
  /// - v2→v3（assistant 消息 → blocks）：chat 部分
  ///
  /// 展开语义：某部分引入迁移的全局版本号 <= 旧全局版本，说明该部分
  /// 已完成迁移（版本 = 当前版本）；否则该部分从未迁移（版本 0）。
  static Map<String, int> _expandFromLegacyGlobal(int legacy) {
    return {
      DataParts.chat: legacy >= 3 ? 1 : 0,
      DataParts.settings: legacy >= 1 ? 1 : 0,
      DataParts.pictures: legacy >= 2 ? 1 : 0,
      DataParts.audio: legacy >= 2 ? 1 : 0,
      DataParts.videos: legacy >= 2 ? 1 : 0,
      DataParts.texts: legacy >= 2 ? 1 : 0,
      DataParts.tasks: 0,
      DataParts.anki: 0,
      DataParts.browserCookies: 0,
    };
  }

  /// 执行所有落后部分的迁移，从各自存储版本迁移到当前版本。
  ///
  /// pictures/audio/videos/texts 四个媒体部分共享同一个物理迁移
  ///（共享 folders 表 → per-type 文件夹表），任一媒体部分落后时执行
  /// 一次即可完成全部四部分的物理迁移，避免重复执行 4 次。
  static Future<void> _performPartMigrations(Map<String, int> stored) async {
    final mediaNeedsMigration = _mediaParts
        .any((p) => (stored[p] ?? 0) < DataParts.currentVersions[p]!);
    if (mediaNeedsMigration) {
      await _migrateMediaV0ToV1();
    }
    for (final part in DataParts.all) {
      if (_mediaParts.contains(part)) continue; // 已统一迁移
      final from = stored[part] ?? 0;
      final to = DataParts.currentVersions[part]!;
      if (from >= to) continue;
      for (int v = from; v < to; v++) {
        await _migratePartFrom(part, v);
      }
    }
  }

  /// 四个媒体部分：共享 folders 物理迁移（见 [_performPartMigrations]）。
  static const List<String> _mediaParts = [
    DataParts.pictures,
    DataParts.audio,
    DataParts.videos,
    DataParts.texts,
  ];

  /// 执行指定部分从指定版本的迁移。
  ///
  /// 每个 case 对应一个部分的版本迁移逻辑。版本以递增方式添加：
  /// 例如 chat 部分从 v0 迁移到 v1 会执行 v0→v1 的步骤。
  /// 媒体四部分的迁移由 [_performPartMigrations] 统一执行。
  static Future<void> _migratePartFrom(String part, int version) async {
    switch (part) {
      case DataParts.settings:
        if (version == 0) {
          await _migrateSettingsV0ToV1();
        }
        break;
      case DataParts.chat:
        if (version == 0) {
          await _migrateChatV0ToV1();
        }
        break;
      default:
        debugPrint('[DataMigrationService] No migration steps defined '
            'for part $part v$version');
    }
  }

  /// Migrate the stored data to the current format if needed, WITHOUT
  /// the startup-side effects of [checkAndMigrate].
  ///
  /// Unlike [checkAndMigrate], this method:
  /// - Does NOT create external backups
  /// - Does NOT check crash recovery flags
  /// - Does NOT clean old backups
  /// - ONLY runs the migration steps and updates the versions
  ///
  /// This is suitable for situations where data has been freshly restored
  /// from a backup and needs to be brought up to date, or when running
  /// migration in contexts where file system backup is not needed.
  static Future<MigrationResult> migrateDataFormatIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    final stored = await _resolvePartVersions(prefs);

    final outdatedParts = DataParts.all
        .where((p) => (stored[p] ?? 0) < DataParts.currentVersions[p]!)
        .toList();
    if (outdatedParts.isEmpty) {
      return const MigrationResult(needsMigration: false);
    }

    try {
      await _performPartMigrations(stored);
      await _recordMigratedParts(prefs, stored, outdatedParts);
      debugPrint(
        '[DataMigrationService] Per-part data format migration from '
        '$outdatedParts to current versions completed',
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

  /// 迁移成功后更新版本记录：只提升实际迁移过的部分。
  ///
  /// 其他部分（包括高于当前版本的未来记录）保持原值 —— 绝不降级
  /// 超前版本（见 [checkAndMigrate] 的说明）。同时移除旧全局 key，
  /// 避免双源版本记录。
  static Future<void> _recordMigratedParts(
    SharedPreferences prefs,
    Map<String, int> stored,
    List<String> outdatedParts,
  ) async {
    final updated = Map.of(stored);
    for (final part in outdatedParts) {
      updated[part] = DataParts.currentVersions[part]!;
    }
    await _savePartVersions(updated);
    if (prefs.containsKey(_kLegacyDataFormatVersionKey)) {
      await prefs.remove(_kLegacyDataFormatVersionKey);
    }
  }

  /// settings v0 → v1: 实际的 SharedPreferences 数据格式迁移。
  ///
  /// 将旧版数据格式统一迁移到新版格式，确保所有 provider 在迁移完成
  /// 后的首次初始化时读取到的数据已是正确格式，避免因格式不兼容
  /// 导致的重复闪退（keeps stopping）问题。
  static Future<void> _migrateSettingsV0ToV1() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint(
        '[DataMigrationService] settings v0→v1: Starting data format migration');

    // --- 第1步：迁移旧版 chat_configs → provider_entries ---
    await _migrateOldChatConfigs(prefs);

    // --- 第2步：修复 provider_entries 中的空 ID 字段 ---
    await _fixNullIdsInProviderEntries(prefs);

    // --- 第3步：移除旧 key，防止重复迁移 ---
    await prefs.remove('migrated_old_conversations');
    await prefs.remove('data_format_version_migrated');

    debugPrint(
        '[DataMigrationService] settings v0→v1: Migration completed successfully');
  }

  /// 迁移旧 chat_configs 到 provider_entries（委托 [DataMigrationOldConfigs]，
  /// 实现见 data_migration_old_configs.dart）。
  static Future<void> _migrateOldChatConfigs(SharedPreferences prefs) =>
      DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

  /// 修复 provider_entries 中 id 为 null 的条目（委托 [DataMigrationOldConfigs]）。
  static Future<void> _fixNullIdsInProviderEntries(SharedPreferences prefs) =>
      DataMigrationOldConfigs.fixNullIdsInProviderEntries(prefs);

  /// pictures/audio/videos/texts v0 → v1: 移除共享 folders 表，
  /// 全部改为每个类型独立的文件夹表。
  ///
  /// 此迁移是幂等的：即使重复执行也不会有副作用。
  /// 四个媒体部分共用同一个物理迁移（共享 folders 表属于整体结构），
  /// 任意部分落后时执行一次即可（见 [_performPartMigrations]）。
  ///
  /// 注意：与 chat/settings 不同，此迁移是 best-effort —— 失败只记录
  /// 日志不中断迁移（[ManifestDatabase.migrateLegacyFoldersToPerType]
  /// 内部已吞掉全部错误；SQLite 路径由 DB 初始化时的 onUpgrade 兜底，
  /// JSON/web 路径无等价兜底）。失败不会重试。此行为延续旧版
  /// v1→v2 的设计，刻意不改为上抛：folders 结构迁移失败不应阻塞启动。
  static Future<void> _migrateMediaV0ToV1() async {
    try {
      debugPrint(
          '[DataMigrationService] media v0→v1: Migrating legacy shared folders '
          'to per-type folder tables');

      await ManifestDatabase.migrateLegacyFoldersToPerType();

      debugPrint(
          '[DataMigrationService] media v0→v1: Migration completed successfully');
    } catch (e) {
      // 迁移失败不阻塞启动，记录日志后继续
      debugPrint('[DataMigrationService] media v0→v1 migration failed: $e');
    }
  }

  /// chat v0 → v1: Convert old assistant messages to unified block format.
  static Future<void> _migrateChatV0ToV1() async {
    debugPrint('[DataMigrationService] chat v0→v1: Starting block migration');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('conversations');
    if (raw == null || raw.isEmpty) return;

    try {
      // 顶层也需防御：conversations 是可解析但不是数组（对象/标量）时，
      // `as List` 强转抛 TypeError 被误判为「结构性错误」上抛，导致
      // 版本号永不提升、每次启动都重复迁移与备份。这类数据属于损坏
      // 数据而非解码失败：隔离原始数据并重置为空列表。
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        debugPrint('[DataMigrationService] conversations 不是合法数组，'
            '已隔离并重置为空列表');
        await _quarantineCorruptData(prefs, 'conversations', raw);
        await prefs.setString('conversations', '[]');
        return;
      }
      final list = decoded;
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
            debugPrint('[DataMigrationService] chat v0→v1: 跳过损坏消息: $e');
          }
        }
      }
      await prefs.setString('conversations', jsonEncode(list));
      debugPrint(
          '[DataMigrationService] chat v0→v1: Migrated $migrated messages'
          '${skipped > 0 ? ', skipped $skipped corrupt entries' : ''}');
    } catch (e) {
      // 结构性迁移失败（jsonDecode 失败等）必须上抛：否则
      // checkAndMigrate 会把该部分版本升到当前值，数据永久停留在
      // "假成功"状态且永远不会重试。上抛后版本不提升，下次启动自动
      // 重试（startup 层会捕获并继续启动）。
      debugPrint('[DataMigrationService] chat v0→v1 migration failed: $e');
      rethrow;
    }
  }
}
