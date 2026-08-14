import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;

import 'app_log_service.dart';
import 'backup_location_manager.dart';
import 'backup_service.dart';
import 'backup_service_shared.dart' show collectAttachmentPaths;
import 'data_migration_service.dart';
import 'manifest_database.dart';
import 'storage_service.dart';
import '../utils/image_thumbnail_loader.dart';

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
// - Desktop: ~/Documents/Stroom/AutoBackups
// - Web: 不支持
//
// 备份保留策略：
// - 1 小时规则：如果最近 1 小时内有备份，则跳过本次备份
// - 24 小时限制：24 小时内最多保留 3 个备份
// - 前日保留规则：超出 24h 的备份按日分组，保留最近 2 个有使用日的最后 1 个备份
// - 总数限制：最多保留 5 个（当天 3 个 + 前日 2 个），最少保留 3 个
// ====================================================================

/// 备份执行结果（区分「创建了快照」与「1 小时规则跳过」，
/// 供迁移前备份判断是否需要自己再执行一次）。
enum _BackupOutcome {
  /// 实际创建了新备份文件。
  created,

  /// 最近 1 小时内有备份，按规则跳过（非错误）。
  skippedOneHour,

  /// 备份失败或被取消。
  failed,
}

// ====================================================================
// 备份失败分类 — 为 UI 提供具体、可操作的失败原因
// ====================================================================

/// 备份失败原因分类。
enum BackupFailureReason {
  /// 存储空间不足（可预检或在写入时触发）。
  noSpace,

  /// 设备内存不足（OOM）。
  outOfMemory,

  /// 备份目录权限异常（Android SAF 未授权/授权失效）。
  permission,

  /// 文件被其他程序占用（如 Windows 上被占用无法写入）。
  fileLocked,

  /// 备份被取消。
  cancelled,

  /// 其他未知错误。
  other,
}

/// 一次备份失败的详细信息（供 UI 展示针对性提示）。
class BackupFailure {
  /// 失败原因分类。
  final BackupFailureReason reason;

  /// 用户可读的失败原因描述。
  final String message;

  /// 技术细节（原始异常信息）。
  final String? detail;

  /// 预计所需空间（noSpace 时）。
  final int? requiredBytes;

  /// 当前剩余空间（noSpace 时）。
  final int? freeBytes;

  const BackupFailure({
    required this.reason,
    required this.message,
    this.detail,
    this.requiredBytes,
    this.freeBytes,
  });
}

/// 将异常分类为具体的备份失败原因。
///
/// 通过错误文本匹配常见系统错误（ENOSPC / OOM / 权限 / 文件占用），
/// 无法识别时归为 [BackupFailureReason.other]。
BackupFailure classifyBackupFailure(
  Object error, {
  int? requiredBytes,
  int? freeBytes,
}) {
  final text = error.toString();
  final lower = text.toLowerCase();

  BackupFailureReason reason;
  String message;

  if (error is BackupCancelledException) {
    reason = BackupFailureReason.cancelled;
    message = '备份已取消。';
  } else if (text.contains('No space left on device') ||
      text.contains('ENOSPC') ||
      text.contains('insufficient storage') ||
      text.contains('not enough space') ||
      lower.contains('no space') ||
      text.contains('存储空间不足') ||
      text.contains('空间不足')) {
    reason = BackupFailureReason.noSpace;
    message = '存储空间不足，无法完成自动备份。'
        '请清理设备中的文件（如旧的备份、大视频、缓存）后重试。';
  } else if (text.contains('Out of Memory') ||
      text.contains('OutOfMemory') ||
      lower.contains('out of memory') ||
      text.contains('Cannot allocate memory') ||
      text.contains('failed to map file') ||
      text.contains('malloc failed')) {
    reason = BackupFailureReason.outOfMemory;
    message = '设备内存不足，无法完成自动备份（备份数据可能过大）。'
        '建议清理一些不需要的大文件后重试。';
  } else if (text.contains('Permission denied') ||
      lower.contains('permission') ||
      text.contains('SAF URI') ||
      text.contains('未授权') ||
      text.contains('权限') ||
      text.contains('ACCESS_DENIED') ||
      text.contains('SECURITY_EXCEPTION')) {
    reason = BackupFailureReason.permission;
    message = '备份目录访问权限异常，无法写入备份文件。'
        '请重新授权备份目录后重试。';
  } else if (text.contains('被占用') ||
      lower.contains('in use') ||
      text.contains('sharing violation') ||
      text.contains('used by another process') ||
      lower.contains('locked')) {
    reason = BackupFailureReason.fileLocked;
    message = '部分数据文件被其他程序占用，无法完成自动备份。'
        '请关闭正在占用这些文件的程序后重试。';
  } else {
    reason = BackupFailureReason.other;
    message = '自动备份失败，请稍后重试。';
  }

  return BackupFailure(
    reason: reason,
    message: message,
    detail: text,
    requiredBytes: requiredBytes,
    freeBytes: freeBytes,
  );
}

/// 是否需要提醒用户清理空间。
///
/// 规则：当前设备/磁盘剩余空间 < 5 × 本次备份大小 时需要提醒
/// （为后续备份预留足够的空间）。
bool shouldRemindSpaceCleanup({
  required int backupSizeBytes,
  required int freeBytes,
}) {
  if (backupSizeBytes <= 0 || freeBytes < 0) return false;
  return freeBytes < 5 * backupSizeBytes;
}

/// 空间清理提醒信息。
class SpaceReminderInfo {
  /// 本次备份的实际大小（字节）。
  final int backupSizeBytes;

  /// 当前设备/磁盘剩余空间（字节）。
  final int freeBytes;

  const SpaceReminderInfo({
    required this.backupSizeBytes,
    required this.freeBytes,
  });
}

/// 自动后台备份服务。
class AutoBackupService {
  AutoBackupService._();

  static bool _isRunning = false;
  static bool _cancelRequested = false;

  /// 正在执行的备份 Future（防并发重入）。
  ///
  /// 与 [_isRunning] 的区别：并发调用方不是直接返回失败，而是等待
  /// 同一个在途备份完成并共享其结果。这避免了「启动时自动备份」与
  /// 「迁移前备份」并发时，一方被静默跳过 —— 例如迁移前备份被跳过
  /// 会导致 checkAndMigrate 在没有安全快照的情况下迁移数据。
  static Future<_BackupOutcome>? _inFlight;

  /// 最近一次备份失败的错误信息（用于调用方判断错误类型）。
  static String? lastError;

  /// 最近一次备份失败的分类信息（供 UI 展示针对性提示）。
  static BackupFailure? lastFailure;

  /// 最近一次成功备份的文件大小（字节），供空间提醒使用。
  static int? lastBackupSizeBytes;

  /// 测试专用：覆盖剩余空间查询（null 表示不覆盖，使用真实查询）。
  @visibleForTesting
  static Future<int?> Function()? debugFreeSpaceOverride;

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
  /// - 24 小时内最多保留 3 个备份（当天）
  /// - 超出 24h 的备份只保留最近 2 个有使用日的最后 1 个备份
  /// - 总数上限 5 个（当天 3 + 前日 2），下限 3 个
  ///
  /// 在 Android SAF 模式下，备份写入系统临时目录后通过 SAF
  /// 写入用户选择的 Documents 目录，确保文件持久化到公共位置。
  ///
  /// [isPreMigration] 标记是否为迁移前备份：迁移会原地改写数据，
  /// 因此迁移前备份会无视 1 小时规则，强制创建一份新快照。
  ///
  /// 返回 `true` 表示备份成功（或 1 小时规则跳过，非错误），
  /// `false` 表示备份失败或被取消。
  static Future<bool> performAutoBackup({
    bool isPreMigration = false,
  }) async {
    if (kIsWeb) return false;

    // 并发保护：已有备份在途时，等待同一个备份完成并返回相同结果，
    // 而不是直接返回失败（避免「迁移前备份」被并发跳过导致迁移时
    // 没有安全快照，或启动备份被误报为失败）。
    //
    // 迁移前备份的例外：仅当共享的备份是普通备份且因「1 小时规则」
    // 跳过（未创建快照）时，才需要自己再跑一次强制新快照。
    // 共享结果为失败/取消时直接共享该结果 —— 例如应用进入后台触发
    // cancel() 后，绝不能无视取消再启动一次完整备份并继续迁移。
    while (true) {
      final inFlight = _inFlight;
      if (inFlight == null) break;
      debugPrint('[AutoBackupService] 备份已在运行中，等待其完成');
      await AppLogService.warning('AutoBackupService', '备份已在运行中，等待其完成');
      final shared = await inFlight;
      if (!isPreMigration || shared != _BackupOutcome.skippedOneHour) {
        return _outcomeToBool(shared);
      }
      // 迁移前备份 + 共享结果「1 小时规则跳过」：循环重试，
      // 下一轮 _inFlight 已为 null，会真正执行备份（迁移前备份
      // 自身无视 1 小时规则）。
    }

    final future = _performAutoBackupInternal(isPreMigration: isPreMigration);
    _inFlight = future;
    try {
      final outcome = await future;
      return _outcomeToBool(outcome);
    } finally {
      // 只清理自己启动的备份：若期间已有新的备份启动，不能误清。
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  static bool _outcomeToBool(_BackupOutcome outcome) {
    // created / skippedOneHour 对调用方都是「成功」（跳过非错误）。
    return outcome != _BackupOutcome.failed;
  }

  /// 备份的实际实现（由 [performAutoBackup] 保证单实例执行）。
  static Future<_BackupOutcome> _performAutoBackupInternal({
    required bool isPreMigration,
  }) async {
    _isRunning = true;
    // 清空上次备份的状态（必须放在 1 小时规则检查之前 —— 若跳过本次
    // 备份，不应残留上一次备份的大小/失败信息，否则空间提醒会用
    // 过期的「本次备份大小」弹窗）。
    lastError = null;
    lastFailure = null;
    lastBackupSizeBytes = null;

    // ================================================================
    // 1 小时规则检查：如果最近 1 小时内有备份，则跳过本次备份
    // ================================================================
    // 注意：迁移前备份（isPreMigration=true）跳过该规则 —— 迁移会
    // 原地改写数据（如 v2→v3 重写 conversations），必须使用刚刚创建
    // 的新快照，1 小时前的旧备份可能缺少迁移前的最新会话数据。
    if (!isPreMigration) {
      try {
        final hasRecentBackup = await _hasBackupWithinLastHour();
        if (hasRecentBackup) {
          debugPrint('[AutoBackupService] 最近 1 小时内有备份，跳过本次自动备份');
          await AppLogService.info('AutoBackupService', '最近 1 小时内有备份，跳过本次自动备份');
          _isRunning = false;
          return _BackupOutcome.skippedOneHour; // 无需备份（非错误）
        }
      } catch (e) {
        debugPrint('[AutoBackupService] 检查最近备份失败: $e');
        // 检查失败不阻止备份
      }
    }

    await AppLogService.info(
        'AutoBackupService', '开始执行自动备份 (isPreMigration=$isPreMigration)');
    if (_cancelRequested) {
      _isRunning = false;
      _cancelRequested = false;
      debugPrint('[AutoBackupService] 备份在开始前已被取消');
      await AppLogService.warning('AutoBackupService', '备份在开始前已被取消');
      return _BackupOutcome.failed;
    }
    _cancelRequested = false;

    String? safTempPath; // SAF 模式下写入的系统临时文件路径
    try {
      // ============================================================
      // 空间预检：估算本次备份所需空间，与剩余空间对比。
      // 不足时快速失败并给出明确的「存储空间不足」原因，
      // 而不是写入到一半才触发 ENOSPC（后者信息不明确且浪费时间）。
      // 注意：预检必须放在 try/finally 内，保证失败时 _isRunning
      // 被正确复位（否则后续 cancel() 会让备份永久无法启动）。
      // ============================================================
      try {
        final requiredBytes = await estimateBackupSize();
        final freeBytes = debugFreeSpaceOverride != null
            ? await debugFreeSpaceOverride!()
            : await BackupLocationManager.getFreeDiskSpaceBytes();
        if (freeBytes != null && freeBytes < requiredBytes) {
          debugPrint('[AutoBackupService] 空间不足预检失败: '
              '需要约 $requiredBytes 字节, 可用 $freeBytes 字节');
          final failure = classifyBackupFailure(
            '存储空间不足: 需要约 $requiredBytes 字节, 当前可用 $freeBytes 字节',
            requiredBytes: requiredBytes,
            freeBytes: freeBytes,
          );
          lastError = failure.detail;
          lastFailure = failure;
          await AppLogService.error(
              'AutoBackupService', '自动备份失败：存储空间不足', Exception(failure.detail));
          return _BackupOutcome.failed;
        }
      } catch (e) {
        // 预检失败不阻止备份（无法获取剩余空间时跳过预检）
        debugPrint('[AutoBackupService] 空间预检失败，跳过: $e');
      }

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
          return _BackupOutcome.failed;
        }

        // 记录备份大小（供空间提醒使用）
        lastBackupSizeBytes = File(safTempPath).lengthSync();

        // 流式上传：本地临时文件 → SAF 公共目录。
        // 不能 readAsBytes 后经 MethodChannel 传整包 —— 大备份
        // （数百 MB）会耗尽内存，且超过 Android Binder 事务上限
        // （约 1MB）会抛 TransactionTooLargeException 导致崩溃。
        await BackupLocationManager.writeBackupFileFromPath(
            zipFileName, safTempPath);

        // 清理旧备份
        await _cleanupOldBackupsSaf();

        debugPrint('[AutoBackupService] $backupType 备份完成(SAF): $zipFileName');
        await AppLogService.info(
            'AutoBackupService', '$backupType 备份完成(SAF): $zipFileName');
        return _BackupOutcome.created;
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

        if (_cancelRequested) return _BackupOutcome.failed;

        debugPrint('[AutoBackupService] 开始 $backupType 备份到 $zipPath');

        await BackupService.createBackup(
          outputPath: tmpPath,
          isCancelled: () => _cancelRequested,
        );

        if (_cancelRequested) {
          await _deleteSystemTempFile(tmpPath);
          debugPrint('[AutoBackupService] 备份被取消');
          return _BackupOutcome.failed;
        }

        // 原子重命名：.tmp → .zip
        final tmpFile = File(tmpPath);
        if (await tmpFile.exists()) {
          await tmpFile.rename(zipPath);
        }
        lastBackupSizeBytes = File(zipPath).lengthSync();

        // 清理旧备份
        await _cleanupOldBackups(backupRoot);

        debugPrint('[AutoBackupService] $backupType 备份完成: $zipPath');
        await AppLogService.info(
            'AutoBackupService', '$backupType 备份完成: $zipPath');
        return _BackupOutcome.created;
      }
    } on BackupCancelledException {
      debugPrint('[AutoBackupService] 备份被取消');
      await AppLogService.warning('AutoBackupService', '备份被取消');
      lastError = null;
      lastFailure = null;
      return _BackupOutcome.failed;
    } catch (e) {
      debugPrint('[AutoBackupService] 备份失败: $e');
      await AppLogService.error('AutoBackupService', '备份失败', e);
      lastError = e.toString();
      lastFailure = classifyBackupFailure(e);
      return _BackupOutcome.failed;
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

  /// 最近 1 小时内是否已有备份（1 小时规则是否会跳过本次备份）。
  ///
  /// 供启动流程在「空间检查」前判断：若备份将被 1 小时规则跳过，
  /// 则不需要检查/要求空间，避免对根本不会执行的备份弹出空间不足
  /// 提示（例如迁移刚创建了备份，或用户 1 小时内刚启动过应用）。
  static Future<bool> hasRecentBackupWithinHour() async {
    try {
      return await _hasBackupWithinLastHour();
    } catch (e) {
      debugPrint('[AutoBackupService] 检查最近备份失败: $e');
      return false; // 检查失败按「无最近备份」处理（保守执行备份流程）
    }
  }

  /// 估算一次全量备份所需的空间（字节）。
  ///
  /// 统计：媒体数据库记录的大小字段 + 附件文件实际大小 +
  /// 任务/Anki/Cookies 文件大小，再加 10% 余量与 1MB 固定开销
  /// （manifest 等 JSON 清单）。
  ///
  /// 用于备份前的空间预检（快速失败并给出明确原因）与
  /// 启动时的空间检查。统计失败的部分静默跳过（估算仅供预判）。
  static Future<int> estimateBackupSize() async {
    if (kIsWeb) return 0;
    var total = 0;

    void addFileLength(String path) {
      try {
        final f = File(path);
        if (f.existsSync()) total += f.lengthSync();
      } catch (_) {}
    }

    // 媒体记录大小（记录中的 size 字段）+ 缩略图实际大小
    try {
      final appDir = await AppStorage.directory;
      final imageRecords = await ManifestDatabase.getAllImageRecords();
      final audioRecords = await ManifestDatabase.getAllAudioRecords();
      final videoRecords = await ManifestDatabase.getAllVideoRecords();
      final textRecords = await ManifestDatabase.getAllTextRecords();
      for (final r in imageRecords) {
        total += (r['size'] as num?)?.toInt() ?? 0;
        // 缩略图按实际文件大小统计（避免固定估算过度放大）
        final hash = r['hash'] as String?;
        if (hash != null) {
          addFileLength(
              p.join(appDir, 'pictures', imageThumbFileName(hash)));
        }
      }
      for (final r in audioRecords) {
        total += (r['size'] as num?)?.toInt() ?? 0;
      }
      for (final r in videoRecords) {
        total += (r['size'] as num?)?.toInt() ?? 0;
      }
      for (final r in textRecords) {
        total += (r['size'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    // 附件文件（按实际文件大小统计）
    try {
      final paths = await collectAttachmentPaths();
      final appDir = await AppStorage.directory;
      for (final storagePath in paths) {
        final parts = storagePath.split('/');
        if (parts.length < 2) continue;
        addFileLength(p.join(appDir, parts[0], parts.sublist(1).join('/')));
      }
    } catch (_) {}

    // 任务 / Anki / Cookies 文件
    try {
      final appDir = await AppStorage.directory;
      addFileLength(p.join(appDir, 'synthesis', 'tasks.json'));
      addFileLength(p.join(appDir, 'catcatch', 'tasks.json'));
      addFileLength(p.join(appDir, 'collection.anki2'));
      addFileLength(p.join(appDir, 'browser_cookies.json'));
    } catch (_) {}

    // 10% 余量 + 1MB 固定开销
    return total + total ~/ 10 + 1024 * 1024;
  }

  /// 自动备份完成后的空间清理提醒检查。
  ///
  /// 规则：当前设备/磁盘剩余空间 < 5 × 本次备份大小 时，返回提醒信息；
  /// 否则（或无法获取剩余空间 / 无备份大小）返回 null。
  ///
  /// 由启动检查在备份成功后调用并弹出清理提醒。
  static Future<SpaceReminderInfo?> checkSpaceReminder() async {
    final backupSize = lastBackupSizeBytes;
    if (backupSize == null || backupSize <= 0) return null;
    final freeBytes = debugFreeSpaceOverride != null
        ? await debugFreeSpaceOverride!()
        : await BackupLocationManager.getFreeDiskSpaceBytes();
    if (freeBytes == null) return null;
    if (!shouldRemindSpaceCleanup(
        backupSizeBytes: backupSize, freeBytes: freeBytes)) {
      return null;
    }
    return SpaceReminderInfo(backupSizeBytes: backupSize, freeBytes: freeBytes);
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
  /// 1. 当天（24h 内）最多保留 3 个备份（遵循 1 小时不重复规则）
  /// 2. 超出 24h 的备份：按使用日分组，保留最近 2 个有使用日的最后 1 个备份
  ///    （即「前两天的最后备份各一个」）
  /// 3. 总数上限为 5 个（3 个当天 + 2 个前日），下限为 3 个
  /// 4. 低于 3 个时不清理
  ///
  /// 返回需要删除的文件路径列表。
  static List<_BackupFileInfo> _selectBackupsToDelete(
      List<_BackupFileInfo> infos) {
    // 最少保留 3 个，低于此数不清理
    if (infos.length <= 3) return [];

    final now = DateTime.now();

    // 分为 24h 内和超出 24h
    final within24h = <_BackupFileInfo>[];
    final beyond24h = <_BackupFileInfo>[];
    for (final info in infos) {
      if (info.modified.isAfter(now.subtract(const Duration(hours: 24)))) {
        within24h.add(info);
      } else {
        beyond24h.add(info);
      }
    }

    // 当天（24h 内）：最多保留最新 3 个
    within24h.sort((a, b) => b.modified.compareTo(a.modified));
    final keepList = <_BackupFileInfo>[
      ...within24h.take(3),
    ];
    // 前日（超出 24h）：按日历日分组，每日期保留最新一个
    // dayKey 必须补零，使字典序与时间序一致
    final dayToLatest = <String, _BackupFileInfo>{};
    for (final info in beyond24h) {
      final dayKey =
          '${info.modified.year}-${_padDay(info.modified.month)}-${_padDay(info.modified.day)}';
      final existing = dayToLatest[dayKey];
      if (existing == null || info.modified.isAfter(existing.modified)) {
        dayToLatest[dayKey] = info;
      }
    }

    // 按日期从新到旧排序
    final sortedDays = dayToLatest.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    // 取最近 2 个有使用日的最后备份（"前两天的最后备份各一个"）
    final beyondDaysToKeep = sortedDays.length < 2 ? sortedDays.length : 2;
    for (var i = 0; i < beyondDaysToKeep; i++) {
      keepList.add(sortedDays[i].value);
    }

    // 最小值保证：如果不足 3 个，从 beyond24h 补足（确保 >= 3）
    if (keepList.length < 3) {
      beyond24h.sort((a, b) => b.modified.compareTo(a.modified));
      final keepPaths = keepList.map((e) => e.path).toSet();
      for (final info in beyond24h) {
        if (keepList.length >= 3) break;
        if (keepPaths.add(info.path)) {
          keepList.add(info);
        }
      }
    }

    // 标记删除：不在 keepList 中的全部删除
    final keepPaths = keepList.map((e) => e.path).toSet();
    final deleteList = <_BackupFileInfo>[];
    for (final info in infos) {
      if (!keepPaths.contains(info.path)) {
        deleteList.add(info);
      }
    }

    return deleteList;
  }

  /// 清理旧备份（非 SAF 模式），按保留策略执行。
  ///
  /// 保留策略：
  /// - 24 小时内最多保留 3 个备份
  /// - 超出 24h 保留最近 2 个有使用日的最后 1 个备份
  /// - 总数上限 5 个，下限 3 个
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

  /// 清理备份目录中的旧备份，按保留策略执行。
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

/// 将 1..12 → "01".."12"，1..31 → "01".."31"，确保字典序与时间序一致。
String _padDay(int n) => n.toString().padLeft(2, '0');

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
