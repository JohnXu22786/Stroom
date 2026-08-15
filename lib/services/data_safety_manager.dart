import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;

import '../utils/app_version.dart';
import '../utils/atomic_file.dart';
import '../utils/web_file_store.dart';
import 'app_log_service.dart';
import 'backup_service.dart';
import 'backup_service_shared.dart' show collectAttachmentPaths;
import 'data_integrity_checker.dart';
import 'manifest_database.dart';
import 'snapshot_service.dart';
import 'storage_service.dart';

/// 数据安全状态。
enum DataSafetyState {
  /// 正常：按 1 小时规则执行快照。
  normal,

  /// 修复中：检测到损坏，正在从快照链回滚（暂停自动快照）。
  repairing,

  /// 冻结：自动修复全部失败，或迁移失败 —— 拒绝进入应用，
  /// 防止写入进一步破坏数据（版本感知，见 [DataSafetyStatus.frozenByVersion]）。
  frozen,
}

/// 持久化的数据安全状态（<AppStorage>/.data_safety.json）。
class DataSafetyStatus {
  final DataSafetyState state;

  /// 冻结时的应用版本（编译期常量 [appVersion]）。
  ///
  /// 解除条件：当前构建版本 != 冻结时版本。这样：
  /// - 原版（相同构建）→ 保持冻结（避免同一坏迁移无限重试）；
  /// - 修复版（版本号不同）→ 解除冻结并重试迁移；
  /// - 回退旧版（版本号不同）→ 解除冻结，旧版可正常使用旧格式数据。
  final String? frozenByVersion;

  /// 失败迁移的描述（如 "v4→v5"），供冻结页展示。
  final String? failedMigration;

  /// 失败迁移的目标格式版本（冻结记录，仅展示用）。
  final int? targetFormatVersion;

  final DateTime? updatedAt;

  const DataSafetyStatus({
    required this.state,
    this.frozenByVersion,
    this.failedMigration,
    this.targetFormatVersion,
    this.updatedAt,
  });

  static const normal =
      DataSafetyStatus(state: DataSafetyState.normal);

  bool get isFrozen => state == DataSafetyState.frozen;
  bool get isRepairing => state == DataSafetyState.repairing;

  Map<String, dynamic> toJson() => {
        'state': state.name,
        if (frozenByVersion != null) 'frozenByVersion': frozenByVersion,
        if (failedMigration != null) 'failedMigration': failedMigration,
        if (targetFormatVersion != null)
          'targetFormatVersion': targetFormatVersion,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  static DataSafetyStatus fromJson(Map<String, dynamic> json) =>
      DataSafetyStatus(
        state: DataSafetyState.values.firstWhere(
          (s) => s.name == json['state'],
          orElse: () => DataSafetyState.normal,
        ),
        frozenByVersion: json['frozenByVersion'] as String?,
        failedMigration: json['failedMigration'] as String?,
        targetFormatVersion: (json['targetFormatVersion'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
}

/// 启动自愈检查结果。
class RepairResult {
  /// 本次检测到数据损坏。
  final bool corruptionFound;

  /// 已从快照回滚修复成功。
  final bool repaired;

  /// 无法自动修复，已冻结（或本次因冻结未运行）。
  final bool frozen;

  /// 因冻结状态未运行检查（冻结由相同构建触发，需用户回退/升级）。
  final bool skippedDueToFreeze;

  const RepairResult({
    this.corruptionFound = false,
    this.repaired = false,
    this.frozen = false,
    this.skippedDueToFreeze = false,
  });
}

/// 数据自愈管理器：启动校验 → 损坏则从快照链回滚 → 全失败则冻结。
///
/// 规则：
/// - 冻结是**版本感知**的：仅冻结时的构建保持冻结，旧版/修复版解除。
/// - 修复期间暂停自动快照（防止坏数据覆盖好快照）；修复成功后
///   立即打一版"干净快照"再恢复正常节奏。
/// - 回滚后附件缺失（旧记录引用的文件已删）静默处理：不阻止回滚、
///   不触发再次回滚（附件缺失 ≠ 数据损坏）。
class DataSafetyManager {
  DataSafetyManager._();

  static const String stateFileName = '.data_safety.json';

  /// 孤儿文件清理阈值：回滚/恢复后产生的无引用文件超过此时间才删除
  ///（防误删正在写入或用户可能恢复的文件）。
  static const Duration orphanGracePeriod = Duration(days: 3);

  // ================================================================
  // 状态读写
  // ================================================================

  static Future<File> _stateFile() async {
    final appDir = await AppStorage.directory;
    return File(p.join(appDir, stateFileName));
  }

  static Future<DataSafetyStatus> loadStatus() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return DataSafetyStatus.normal;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return DataSafetyStatus.normal;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return DataSafetyStatus.normal;
      return DataSafetyStatus.fromJson(decoded);
    } catch (e) {
      debugPrint('[DataSafetyManager] 读取状态失败（按正常处理）: $e');
      return DataSafetyStatus.normal;
    }
  }

  static Future<void> saveStatus(DataSafetyStatus status) async {
    try {
      final file = await _stateFile();
      await AtomicFile.writeString(file, jsonEncode(status.toJson()));
    } catch (e) {
      debugPrint('[DataSafetyManager] 保存状态失败: $e');
    }
  }

  /// 迁移失败时冻结（记录失败迁移信息）。
  static Future<void> freezeForMigrationFailure({
    required int targetFormatVersion,
    required String description,
  }) async {
    final current = await loadStatus();
    await saveStatus(DataSafetyStatus(
      state: DataSafetyState.frozen,
      frozenByVersion: appVersion,
      failedMigration: description,
      targetFormatVersion: targetFormatVersion,
      updatedAt: DateTime.now(),
    ));
    await AppLogService.error(
        'DataSafetyManager', '数据格式迁移失败，已冻结（$description）');
    if (current.isFrozen) {
      debugPrint('[DataSafetyManager] 保持冻结状态');
    }
  }

  /// 迁移成功（或数据恢复）后清除冻结。
  static Future<void> clearFrozen() async {
    await saveStatus(DataSafetyStatus.normal);
  }

  // ================================================================
  // 启动自愈主入口
  // ================================================================

  /// 启动时调用：处理冻结 → 校验 → 损坏则回滚修复。
  static Future<RepairResult> checkAndRepair() async {
    final status = await loadStatus();

    // ---- 冻结处理（版本感知）----
    if (status.isFrozen) {
      if (status.frozenByVersion == appVersion) {
        // 同一构建：保持冻结，等待用户回退/升级（或手动处理）。
        debugPrint('[DataSafetyManager] 检测到冻结（版本 $appVersion），'
            '拒绝进入应用');
        return const RepairResult(skippedDueToFreeze: true, frozen: true);
      }
      // 旧版或修复版：解除冻结。
      // - 回退旧版：数据是旧格式（迁移失败时恢复的迁移前快照），
      //   旧版可正常读写；
      // - 修复版：下面正常校验，数据格式旧则触发重试迁移。
      debugPrint('[DataSafetyManager] 解除冻结（冻结于 '
          '${status.frozenByVersion}，当前 $appVersion）');
      await saveStatus(DataSafetyStatus.normal);
    }

    // ---- 完整性校验 ----
    final report = await DataIntegrityChecker.checkCurrentData();
    if (!report.hasCorruption) {
      if (status.isRepairing) {
        // 上次修复实际已完成（回滚已生效），恢复 normal。
        await saveStatus(DataSafetyStatus.normal);
      }
      return const RepairResult();
    }

    debugPrint('[DataSafetyManager] 检测到数据损坏（${report.corruptions.length} 处），'
        '开始从快照链修复');
    await AppLogService.error(
        'DataSafetyManager',
        '检测到数据损坏，开始自动修复: '
            '${report.corruptions.map((i) => '${i.part}: ${i.message}').join('; ')}');
    await saveStatus(DataSafetyStatus(state: DataSafetyState.repairing));

    final repaired = await _repairFromSnapshots();
    if (repaired) {
      // 修复成功：立即打一版干净快照（force 无视 1 小时规则），
      // 再恢复正常状态与自动快照节奏。
      await SnapshotService.createSnapshot(force: true);
      await saveStatus(DataSafetyStatus.normal);
      return const RepairResult(corruptionFound: true, repaired: true);
    }

    // 全部快照都失败：冻结（无法自动修复，等待用户手动导入）。
    await saveStatus(DataSafetyStatus(
      state: DataSafetyState.frozen,
      frozenByVersion: appVersion,
      updatedAt: DateTime.now(),
    ));
    await AppLogService.error(
        'DataSafetyManager', '自动修复失败，数据已冻结（等待手动导入）');
    return const RepairResult(corruptionFound: true, frozen: true);
  }

  /// 从快照链（新 → 旧）尝试恢复。
  ///
  /// 每个快照：SHA-256 校验（快照本身损坏则跳过）→ 结构化恢复 →
  /// 恢复后完整性校验。返回是否修复成功。
  static Future<bool> _repairFromSnapshots() async {
    final snapshots = await SnapshotService.listSnapshots();
    final dir = await SnapshotService.snapshotsDir;
    for (final entry in snapshots) {
      try {
        final file = File(p.join(dir.path, entry.file));
        if (!await file.exists()) {
          debugPrint('[DataSafetyManager] 快照缺失，跳过: ${entry.file}');
          continue;
        }
        final bytes = await file.readAsBytes();
        if (sha256.convert(bytes).toString() != entry.sha256) {
          debugPrint('[DataSafetyManager] 快照校验失败（SHA 不符），'
              '跳过: ${entry.file}');
          continue;
        }
        await BackupService.restoreBackup(
          file.path,
          selection: BackupSelection.structuredOnly,
        );
        final check = await DataIntegrityChecker.checkCurrentData();
        if (!check.hasCorruption) {
          debugPrint('[DataSafetyManager] 已从快照 ${entry.file} 恢复数据');
          await AppLogService.info(
              'DataSafetyManager', '已从快照 ${entry.file} 恢复数据');
          return true;
        }
        debugPrint('[DataSafetyManager] 快照 ${entry.file} 恢复后仍校验失败');
      } catch (e) {
        debugPrint('[DataSafetyManager] 快照 ${entry.file} 恢复失败: $e');
      }
    }
    return false;
  }

  // ================================================================
  // 孤儿文件清理
  // ================================================================

  /// 清理无引用的孤儿文件（回滚/恢复/删除记录后产生）。
  ///
  /// 只清理私有目录中"磁盘上有、但当前数据引用清单里没有"的文件，
  /// 且修改时间超过 [orphanGracePeriod]（3 天缓冲，防误删正在写入或
  /// 用户可能恢复的文件）。绝不触碰手动备份目录（用户主动导出的数据）。
  static Future<void> cleanupOrphans() async {
    if (kIsWeb) return;
    try {
      final appDir = await AppStorage.directory;

      // 收集当前引用集合（附件 basename + 媒体 hash basename）
      final referenced = <String>{};
      try {
        final attachments = await collectAttachmentPaths();
        for (final storagePath in attachments) {
          referenced.add(p.basename(storagePath));
        }
      } catch (e) {
        debugPrint('[DataSafetyManager] 收集附件引用失败: $e');
      }
      try {
        final records = <Map<String, dynamic>>[
          ...await ManifestDatabase.getAllImageRecords(),
          ...await ManifestDatabase.getAllAudioRecords(),
          ...await ManifestDatabase.getAllVideoRecords(),
          ...await ManifestDatabase.getAllTextRecords(),
        ];
        for (final record in records) {
          final hash = record['hash'] as String?;
          if (hash != null) {
            final format = record['format'] as String? ?? 'jpg';
            referenced.add('$hash.$format');
            referenced.add('${hash}_thumb_v2.png');
          }
        }
      } catch (e) {
        debugPrint('[DataSafetyManager] 收集媒体引用失败: $e');
      }

      // 扫描附件与媒体目录
      final dirsToScan = [
        p.join(appDir, 'attachments'),
        p.join(appDir, 'pictures'),
        p.join(appDir, 'tts_audio'),
        p.join(appDir, 'videos'),
        p.join(appDir, 'texts'),
      ];
      final cutoff = DateTime.now().subtract(orphanGracePeriod);
      var deleted = 0;
      for (final dirPath in dirsToScan) {
        final dir = Directory(dirPath);
        if (!await dir.exists()) continue;
        final entries = await dir.list().toList();
        for (final entry in entries) {
          if (entry is! File) continue;
          final name = p.basename(entry.path);
          if (referenced.contains(name)) continue;
          try {
            final stat = await entry.stat();
            if (stat.modified.isAfter(cutoff)) continue;
            await entry.delete();
            deleted++;
            debugPrint('[DataSafetyManager] 清理孤儿文件: $name');
          } catch (e) {
            debugPrint('[DataSafetyManager] 清理孤儿文件失败 $name: $e');
          }
        }
      }
      if (deleted > 0) {
        await AppLogService.info(
            'DataSafetyManager', '孤儿文件清理完成（删除 $deleted 个）');
      }
    } catch (e) {
      debugPrint('[DataSafetyManager] 孤儿清理失败: $e');
    }
  }
}
