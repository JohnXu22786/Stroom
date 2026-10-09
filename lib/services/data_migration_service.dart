import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;

import '../models/tool_call.dart';
import '../pages/chat/chat_types.dart' show legacyToBlocks;
import 'app_log_service.dart';
import 'backup_location_manager.dart';
import 'data_integrity_checker.dart';
import 'data_integrity_json_parser.dart' as json_parser;
import 'data_safety_manager.dart';
import 'manifest_database.dart';
import 'provider_model_migration.dart';
import 'flow_execution_migration.dart';
import 'snapshot_service.dart';
import 'startup_preferences.dart';
import 'startup_data_validation_unavailable.dart';
import 'data_migration_isolate_stub.dart'
    if (dart.library.io) 'data_migration_isolate_io.dart'
    as data_migration_isolate;

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
// Anki闪卡数据 / 内置浏览器数据。
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

  /// 内置浏览器数据（Cookies快照及平台支持的网站存储目录）。
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
  /// - settings v2: 供应商配置和模型的持久身份。
  /// - tasks v1: 旧任务流模型下标改为需要重新确认的引用。
  /// - tasks v2: 运行结果和未执行步骤状态。
  /// - anki/browserCookies: 无迁移历史，当前版本 0（机制就位，
  ///   未来各自格式变更时从 1 开始递增）
  static const Map<String, int> currentVersions = {
    chat: 1,
    settings: 2,
    pictures: 1,
    audio: 1,
    videos: 1,
    texts: 1,
    tasks: 2,
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

  /// 格式版本元数据由备份清单单独承载，不作为用户设置跨设备覆盖。
  static bool isFormatMetadataKey(String key) =>
      key == _kLegacyDataFormatVersionKey ||
      key == _kDataFormatVersionsKey ||
      key == 'data_format_version_migrated';

  /// Expands the legacy global format version carried by older backup files.
  static Map<String, int>? partVersionsFromLegacyGlobal(Object? value) {
    if (value is! int) return null;
    return _expandFromLegacyGlobal(value);
  }

  // ================================================================
  // 版本检查
  // ================================================================

  /// 获取旧版全局数据格式版本（`data_format_version`）。
  ///
  /// 如果从未存储过，返回 0。仅用于识别旧版应用留下的数据；
  /// 新机制下版本记录在 [getStoredPartVersions]。
  static Future<int> getStoredFormatVersion() async {
    final prefs = await StartupMigrationPreferences.load();
    return (await prefs.getInt(_kLegacyDataFormatVersionKey)) ?? 0;
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

  /// Reads stored versions without initializing the full preference cache.
  static Future<Map<String, int>> getStoredPartVersionsForStartup() async {
    final stored = await _readPartVersionsForStartup();
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
    final prefs = await StartupMigrationPreferences.load();
    return _parsePartVersions(await prefs.getString(_kDataFormatVersionsKey));
  }

  static Future<Map<String, int>?> _readPartVersionsForStartup() async {
    final raw = await StartupPreferences.getString(_kDataFormatVersionsKey);
    return _parsePartVersions(raw);
  }

  static Map<String, int>? _parsePartVersions(String? raw) {
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
  static Future<void> _savePartVersions(
    Map<String, int> versions, [
    StartupMigrationPreferences? prefs,
  ]) async {
    prefs ??= await StartupMigrationPreferences.load();
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
      StartupMigrationPreferences prefs) async {
    final raw = await prefs.getString(_kDataFormatVersionsKey);
    final stored = _parsePartVersions(raw);
    if (stored != null) {
      if (await prefs.containsKey(_kLegacyDataFormatVersionKey)) {
        await prefs.remove(_kLegacyDataFormatVersionKey);
      }
      return stored;
    }
    if (raw != null && raw.isNotEmpty) {
      await _quarantineCorruptData(prefs, 'data_format_versions', raw);
    }
    final legacy = (await prefs.getInt(_kLegacyDataFormatVersionKey)) ?? 0;
    final expanded = _expandFromLegacyGlobal(legacy);
    await _savePartVersions(expanded, prefs);
    // 展开完成即接管版本管理：旧全局 key 退役（即使后续某部分迁移
    // 失败也不回退，per-part 记录是唯一事实来源）。
    if (await prefs.containsKey(_kLegacyDataFormatVersionKey)) {
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
    final existingVersions = await _readPartVersionsForStartup();
    if (existingVersions != null) {
      final hasOutdatedPart = DataParts.all.any(
        (part) =>
            (existingVersions[part] ?? 0) < DataParts.currentVersions[part]!,
      );
      final hasLegacyVersion =
          await StartupPreferences.containsKey(_kLegacyDataFormatVersionKey);
      if (!hasOutdatedPart && !hasLegacyVersion) {
        await AppLogService.info('DataMigrationService', '数据格式版本为最新，无需迁移');
        return const MigrationResult(needsMigration: false);
      }
    }

    final StartupMigrationPreferences prefs;
    try {
      // Legacy migration is gated by targeted startup reads. Linux and Windows
      // load the required legacy map in a worker isolate when migration is due.
      prefs = await StartupMigrationPreferences.load();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StartupPreferencesUnavailable(
          const {_kDataFormatVersionsKey, _kLegacyDataFormatVersionKey},
          error,
        ),
        stackTrace,
      );
    }

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

    try {
      // 创建迁移前快照（私有目录结构化快照，无视 1 小时规则）。
      // 快照失败（或并发快照被取消）时绝不继续迁移：没有安全快照
      // 的迁移一旦中途失败可能造成数据损坏。返回 needsMigration=false
      // 保持版本号不变，下次启动自动重试（与旧版 v2→v3 结构性失败
      // 「版本号永不提升」的哲学一致）。
      // Web 平台不支持本地快照（createSnapshot 恒返回 null），直接迁移。
      if (!kIsWeb) {
        final snapshot = await SnapshotService.createSnapshot(force: true);
        if (snapshot == null) {
          debugPrint('[DataMigrationService] 迁移前快照失败，'
              '取消本次迁移（下次启动重试）');
          await AppLogService.error(
              'DataMigrationService', '迁移前快照失败，取消本次迁移（下次启动重试）');
          return const MigrationResult(needsMigration: false);
        }
      }

      // 执行迁移：只迁移版本落后的部分（顺序见 DataParts.all）
      await _performPartMigrations(stored, prefs: prefs);

      // 更新存储的版本号：只提升实际迁移过的部分。
      // 其他部分（包括高于当前版本的未来记录）保持原值 —— 绝不
      // 降级超前版本，否则「未来版本迁移后回滚再升级」会把已迁移
      // 的数据误判为需要重新迁移。
      await _recordMigratedParts(prefs, stored, outdatedParts);

      debugPrint('[DataMigrationService] Per-part data format migration '
          'completed: $detail');
      await AppLogService.info('DataMigrationService', '数据格式迁移成功: $detail');

      // 迁移完成后立即做完整性校验：迁移代码 bug 可能产出"能写入但
      // 校验不过"的数据（确定性失败，重试无效）。此时恢复迁移前
      // 快照（旧格式完整数据）并冻结 —— 当前构建不再尝试迁移，
      // 数据保持旧格式，用户回退旧版应用仍可正常使用。
      if (!kIsWeb) {
        final check = await DataIntegrityChecker.checkCurrentData();
        if (check.hasCorruption) {
          debugPrint('[DataMigrationService] 迁移后校验失败（数据损坏），'
              '恢复迁移前快照并冻结: ${check.corruptions.map((i) => i.message).join('; ')}');
          await AppLogService.error('DataMigrationService',
              '迁移后数据校验失败，恢复迁移前快照并冻结', check.corruptions.first.message);
          try {
            final restored = await DataSafetyManager.restoreLatestSnapshot();
            if (!restored) {
              await AppLogService.error(
                  'DataMigrationService', '恢复迁移前快照失败（无可用快照）');
            }
          } catch (e) {
            debugPrint('[DataMigrationService] 恢复迁移前快照失败: $e');
          }
          await DataSafetyManager.freezeForMigrationFailure(
            targetFormatVersion: DataParts.all.fold<int>(0, (max, p) {
              final v = DataParts.currentVersions[p] ?? 0;
              return v > max ? v : max;
            }),
            description: detail,
          );
          return const MigrationResult(needsMigration: false);
        }
      }
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
  /// pictures/audio/videos/texts 使用同一个 legacy `folders` 表，
  /// 但只把该表迁移到仍落后的媒体类别。共享表会保留到所有媒体类别
  /// 都达到当前版本，防止部分恢复时修改未选中的类别。
  static Future<void> _performPartMigrations(
    Map<String, int> stored, {
    required StartupMigrationPreferences prefs,
    Set<String>? onlyParts,
  }) async {
    final selectedParts = onlyParts ?? DataParts.all.toSet();
    final mediaPartsToMigrate = _mediaParts
        .where(
          (part) =>
              selectedParts.contains(part) &&
              (stored[part] ?? 0) < DataParts.currentVersions[part]!,
        )
        .toSet();
    if (mediaPartsToMigrate.isNotEmpty) {
      final allMediaCurrentAfterMigration = _mediaParts.every(
        (part) =>
            mediaPartsToMigrate.contains(part) ||
            (stored[part] ?? 0) >= DataParts.currentVersions[part]!,
      );
      await _migrateMediaV0ToV1(
        mediaParts: mediaPartsToMigrate,
        removeLegacyTable: allMediaCurrentAfterMigration,
      );
    }
    for (final part in DataParts.all) {
      if (!selectedParts.contains(part)) continue;
      if (_mediaParts.contains(part)) continue; // 已统一迁移
      final from = stored[part] ?? 0;
      final to = DataParts.currentVersions[part]!;
      if (from >= to) continue;
      for (int v = from; v < to; v++) {
        await _migratePartFrom(part, v, prefs);
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
  static Future<void> _migratePartFrom(
    String part,
    int version,
    StartupMigrationPreferences prefs,
  ) async {
    switch (part) {
      case DataParts.settings:
        if (version == 0) {
          await _migrateSettingsV0ToV1(prefs);
        } else if (version == 1) {
          await ProviderModelMigration.migrateSettings(prefs);
        }
        break;
      case DataParts.tasks:
        if (version == 0) await ProviderModelMigration.migrateFlows();
        if (version == 1) await FlowExecutionMigration.migrate();
        break;
      case DataParts.chat:
        if (version == 0) {
          await _migrateChatV0ToV1(prefs);
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
  static Future<MigrationResult> migrateDataFormatIfNeeded({
    Set<String>? onlyParts,
  }) async {
    final prefs = await StartupMigrationPreferences.load();

    final stored = await _resolvePartVersions(prefs);
    final selectedParts = onlyParts ?? DataParts.all.toSet();

    final outdatedParts = DataParts.all
        .where((p) =>
            selectedParts.contains(p) &&
            (stored[p] ?? 0) < DataParts.currentVersions[p]!)
        .toList();
    if (outdatedParts.isEmpty) {
      return const MigrationResult(needsMigration: false);
    }

    try {
      await _performPartMigrations(
        stored,
        prefs: prefs,
        onlyParts: selectedParts,
      );
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

  /// 将备份中的格式版本只应用到本次实际恢复的数据部分。
  ///
  /// 未恢复部分继续使用当前设备的版本标记。缺少版本信息的旧备份按
  /// 初始格式 v0 处理，由后续迁移升级恢复的数据部分。
  static Future<void> mergeRestoredPartVersions({
    required Map<String, int>? backupVersions,
    required Set<String> restoredParts,
  }) async {
    if (restoredParts.isEmpty) return;

    final prefs = await StartupMigrationPreferences.load();
    final stored = await _resolvePartVersions(prefs);

    for (final part in restoredParts) {
      if (DataParts.all.contains(part)) {
        final backupVersion = backupVersions?[part] ?? 0;
        final currentVersion = DataParts.currentVersions[part]!;
        // Backup restore writes media folders directly into the current
        // per-type tables, including when the backup used the legacy shared
        // `folders` list. Do not re-migrate selected media from the
        // destination's legacy table after replacing those categories.
        stored[part] =
            _mediaParts.contains(part) && backupVersion < currentVersion
                ? currentVersion
                : backupVersion;
      }
    }
    await _savePartVersions(stored, prefs);
  }

  /// 迁移成功后更新版本记录：只提升实际迁移过的部分。
  ///
  /// 其他部分（包括高于当前版本的未来记录）保持原值 —— 绝不降级
  /// 超前版本（见 [checkAndMigrate] 的说明）。同时移除旧全局 key，
  /// 避免双源版本记录。
  static Future<void> _recordMigratedParts(
    StartupMigrationPreferences prefs,
    Map<String, int> stored,
    List<String> outdatedParts,
  ) async {
    final updated = Map.of(stored);
    for (final part in outdatedParts) {
      updated[part] = DataParts.currentVersions[part]!;
    }
    await _savePartVersions(updated, prefs);
    if (await prefs.containsKey(_kLegacyDataFormatVersionKey)) {
      await prefs.remove(_kLegacyDataFormatVersionKey);
    }
  }

  /// settings v0 → v1: 实际的 SharedPreferences 数据格式迁移。
  ///
  /// 将旧版数据格式统一迁移到新版格式，确保所有 provider 在迁移完成
  /// 后的首次初始化时读取到的数据已是正确格式，避免因格式不兼容
  /// 导致的重复闪退（keeps stopping）问题。
  static Future<void> _migrateSettingsV0ToV1(
    StartupMigrationPreferences prefs,
  ) async {
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
  static Future<void> _migrateOldChatConfigs(
          StartupMigrationPreferences prefs) =>
      DataMigrationOldConfigs.migrateOldChatConfigs(prefs);

  /// 修复 provider_entries 中 id 为 null 的条目（委托 [DataMigrationOldConfigs]）。
  static Future<void> _fixNullIdsInProviderEntries(
          StartupMigrationPreferences prefs) =>
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
  static Future<void> _migrateMediaV0ToV1({
    required Set<String> mediaParts,
    required bool removeLegacyTable,
  }) async {
    try {
      debugPrint(
          '[DataMigrationService] media v0→v1: Migrating legacy shared folders '
          'to per-type folder tables');

      await ManifestDatabase.migrateLegacyFoldersToPerType(
        onlyFolderTables: mediaParts.map(_folderTableForMediaPart).toSet(),
        removeLegacyTable: removeLegacyTable,
      );

      debugPrint(
          '[DataMigrationService] media v0→v1: Migration completed successfully');
    } catch (e) {
      // 迁移失败不阻塞启动，记录日志后继续
      debugPrint('[DataMigrationService] media v0→v1 migration failed: $e');
    }
  }

  static String _folderTableForMediaPart(String part) {
    switch (part) {
      case DataParts.pictures:
        return ManifestTables.imageFolders;
      case DataParts.audio:
        return ManifestTables.audioFolders;
      case DataParts.videos:
        return ManifestTables.videoFolders;
      case DataParts.texts:
        return ManifestTables.textFolders;
      default:
        throw ArgumentError.value(part, 'part', 'Not a media data part');
    }
  }

  /// chat v0 → v1: Convert old assistant messages to unified block format.
  static Future<void> _migrateChatV0ToV1(
    StartupMigrationPreferences prefs,
  ) async {
    debugPrint('[DataMigrationService] chat v0→v1: Starting block migration');
    final raw = await prefs.getString('conversations');
    if (raw == null || raw.isEmpty) return;

    try {
      final Map<String, Object?> migratedData;
      if (kIsWeb) {
        migratedData = await json_parser.migrateLegacyConversationsWeb(raw);
      } else if (_isFlutterTest) {
        migratedData = _transformLegacyConversations(raw);
      } else {
        try {
          migratedData = await data_migration_isolate.runInIsolate(
            () => _transformLegacyConversations(raw),
          );
        } catch (error) {
          throw StartupDataValidationUnavailable.isolate(error);
        }
      }
      final parseError = migratedData['parseError'];
      if (parseError is String) throw FormatException(parseError);
      if (migratedData['isList'] != true) {
        debugPrint('[DataMigrationService] conversations 不是合法数组，'
            '已隔离并重置为空列表');
        await _quarantineCorruptData(prefs, 'conversations', raw);
        await prefs.setString('conversations', '[]');
        return;
      }
      await prefs.setString(
        'conversations',
        migratedData['encoded']! as String,
      );
      final migrated = migratedData['migrated']! as int;
      final skipped = migratedData['skipped']! as int;
      debugPrint(
          '[DataMigrationService] chat v0→v1: Migrated $migrated messages'
          '${skipped > 0 ? ', skipped $skipped corrupt entries' : ''}');
    } catch (e) {
      // 结构性迁移失败（jsonDecode 失败等）必须上抛：否则
      // checkAndMigrate 会把该部分版本升到当前值，数据永久停留在
      // "假成功"状态且永远不会重试。上抛后版本不提升，下次启动自动
      // 重试；本次启动会记录错误并继续到后续格式校验。
      debugPrint('[DataMigrationService] chat v0→v1 migration failed: $e');
      rethrow;
    }
  }
}

Map<String, Object?> _transformLegacyConversations(String raw) {
  // Parsing, migration, and encoding happen together off the UI isolate.
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (error) {
    return {'parseError': error.toString()};
  }
  if (decoded is! List) return {'isList': false};

  var migrated = 0;
  var skipped = 0;
  for (final conversation in decoded) {
    if (conversation is! Map) {
      skipped++;
      continue;
    }
    final rawMessages = conversation['messages'];
    final messages = rawMessages is List ? rawMessages : <dynamic>[];
    for (final message in messages) {
      if (message is! Map) {
        skipped++;
        continue;
      }
      if (message['role'] != 'assistant') continue;
      final existingBlocks = message['blocks'];
      if (existingBlocks is List && existingBlocks.isNotEmpty) continue;
      try {
        final blocks = legacyToBlocks(
          reasoningSections:
              (message['reasoningSections'] as List<dynamic>?)?.cast<String>() ??
                  [],
          textChunks:
              (message['textSections'] as List<dynamic>?)?.cast<String>() ??
                  [],
          toolCalls: ((message['toolCalls'] as List<dynamic>?) ?? [])
              .map((toolCall) => ToolCallData.fromMap(
                  Map<String, dynamic>.from(toolCall)))
              .toList(),
          toolCallRoundStarts:
              (message['toolCallRoundStarts'] as List<dynamic>?)?.cast<int>() ??
                  [],
        );
        if (blocks.isNotEmpty) {
          message['blocks'] = blocks.map((block) => block.toMap()).toList();
          migrated++;
        }
      } catch (_) {
        // A damaged message does not prevent migration of its siblings.
        skipped++;
      }
    }
  }

  return {
    'isList': true,
    'encoded': jsonEncode(decoded),
    'migrated': migrated,
    'skipped': skipped,
  };
}

bool get _isFlutterTest {
  try {
    return Platform.environment['FLUTTER_TEST'] == 'true';
  } catch (_) {
    return false;
  }
}
