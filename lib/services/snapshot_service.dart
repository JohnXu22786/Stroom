import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;

import 'app_log_service.dart';
import 'backup_service.dart';
import 'data_migration_service.dart';
import 'storage_service.dart';

/// 私有目录结构化快照清单条目。
class SnapshotEntry {
  final String file;
  final String sha256;
  final String createdAt;
  final Map<String, int> partVersions;

  const SnapshotEntry({
    required this.file,
    required this.sha256,
    required this.createdAt,
    required this.partVersions,
  });

  Map<String, dynamic> toJson() => {
        'file': file,
        'sha256': sha256,
        'createdAt': createdAt,
        'partVersions': partVersions,
      };

  static SnapshotEntry fromJson(Map<String, dynamic> json) => SnapshotEntry(
        file: json['file'] as String,
        sha256: json['sha256'] as String,
        createdAt: json['createdAt'] as String,
        partVersions: (json['partVersions'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

/// 私有目录结构化数据快照服务。
///
/// - 快照只含结构化数据（记录/配置/任务/Anki/Cookies），不含媒体与
///   附件文件（`BackupSelection.structuredOnly`），体积小，可在启动
///   动画完成后静默执行。
/// - 时间戳命名 + 原子 rename 落位，任何时刻目录内都是完整快照集合。
/// - 1 小时规则限频（迁移前快照 `force: true` 无视）。
/// - 保留策略与旧 AutoBackups 一致（24h 内 3 个 + 前两日各 1 个，
///   上限 5、下限 3）。
/// - 快照失败 ≠ 数据损坏：返回 null 并记日志，不进入修复流程。
class SnapshotService {
  SnapshotService._();

  static const String snapshotsDirName = 'snapshots';
  static const String manifestName = 'snapshot_index.json';

  /// 测试环境下的快照根目录，每个测试 isolate（测试文件）独立。
  ///
  /// 并行运行的测试文件共享 systemTemp，若都使用同一个固定子目录，
  /// 各文件 setUp 中的 `delete(recursive: true)` 会互相删除对方正在
  /// 使用的快照（与 BackupLocationManager.testBackupRoot 同理）。
  static String? _testSnapshotsRoot;

  static String get testSnapshotsRoot {
    final cached = _testSnapshotsRoot;
    if (cached != null) return cached;
    final dir = Directory.systemTemp.createTempSync('stroom_snapshots_test_');
    _testSnapshotsRoot = dir.path;
    return dir.path;
  }

  /// 1 小时规则：最近 1 小时内有快照则跳过（与旧自动备份一致）。
  static const Duration hourRule = Duration(hours: 1);

  /// 测试钩子：覆盖当前时间。
  @visibleForTesting
  static DateTime Function()? debugNow;

  static DateTime _now() => debugNow?.call() ?? DateTime.now();

  /// 快照目录（私有数据目录下；测试环境为 per-isolate 唯一目录）。
  static Future<Directory> get snapshotsDir async {
    String basePath;
    try {
      if (Platform.environment['FLUTTER_TEST'] == 'true') {
        basePath = testSnapshotsRoot;
      } else {
        basePath = await AppStorage.directory;
      }
    } catch (e) {
      basePath = await AppStorage.directory;
    }
    final dir = Directory(p.join(basePath, snapshotsDirName));
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (e) {
      debugPrint('[SnapshotService] 创建快照目录失败: $e');
    }
    return dir;
  }

  /// 快照索引文件（快照名 → 校验和/版本）。
  static Future<File> _indexFile() async {
    final dir = await snapshotsDir;
    return File(p.join(dir.path, manifestName));
  }

  /// 读取快照索引。缺失/损坏返回空列表（索引可重建，不阻塞）。
  static Future<List<SnapshotEntry>> readIndex() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return [];
      final list = decoded['snapshots'];
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SnapshotEntry.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[SnapshotService] 读取快照索引失败（重建）: $e');
      return [];
    }
  }

  /// 写入快照索引（原子）。
  static Future<void> _writeIndex(List<SnapshotEntry> entries) async {
    try {
      final file = await _indexFile();
      await file.writeAsString(
        jsonEncode({'snapshots': entries.map((e) => e.toJson()).toList()}),
      );
    } catch (e) {
      debugPrint('[SnapshotService] 写入快照索引失败: $e');
    }
  }

  /// 创建结构化快照。
  ///
  /// [force] 为 true 时无视 1 小时规则（迁移前快照）。
  /// 返回快照文件；1 小时规则命中时返回 null（不算失败）；
  /// 创建失败返回 null 并记日志。
  static Future<File?> createSnapshot({bool force = false}) async {
    if (kIsWeb) return null;
    try {
      if (!force && await hasSnapshotWithinHour()) {
        debugPrint('[SnapshotService] 最近 1 小时内有快照，跳过本次');
        return null;
      }

      final dir = await snapshotsDir;
      final timestamp = _now().toIso8601String().replaceAll(':', '-');
      final zipName = 'backup_$timestamp.zip';
      final tmpPath = p.join(dir.path, '$zipName.tmp');
      final zipPath = p.join(dir.path, zipName);

      // 复用备份构建链路（结构化 selection，后台 isolate 构建）
      await BackupService.createBackup(
        outputPath: tmpPath,
        selection: BackupSelection.structuredOnly,
      );

      final file = File(tmpPath);
      final bytes = await file.readAsBytes();
      final sha = sha256.convert(bytes).toString();
      await file.rename(zipPath);

      final partVersions = await DataMigrationService.getStoredPartVersions();
      final entry = SnapshotEntry(
        file: zipName,
        sha256: sha,
        createdAt: _now().toIso8601String(),
        partVersions: partVersions,
      );
      final index = await readIndex();
      index.removeWhere((e) => e.file == zipName);
      index.add(entry);
      await _writeIndex(index);

      await cleanupOldSnapshots();
      await AppLogService.info('SnapshotService', '结构化快照完成: $zipName');
      return File(zipPath);
    } catch (e) {
      debugPrint('[SnapshotService] 创建快照失败: $e');
      await AppLogService.error('SnapshotService', '创建快照失败', e);
      return null;
    }
  }

  /// 最近 1 小时（[hourRule]）内是否存在快照。
  static Future<bool> hasSnapshotWithinHour() async {
    try {
      final dir = await snapshotsDir;
      if (!await dir.exists()) return false;
      final entries = await dir.list().toList();
      final cutoff = _now().subtract(hourRule);
      for (final entry in entries) {
        if (entry is! File) continue;
        final name = entry.path.split(Platform.pathSeparator).last;
        final ts = _extractTimestamp(name);
        if (ts != null && ts.isAfter(cutoff)) return true;
      }
    } catch (e) {
      debugPrint('[SnapshotService] 检查最近快照失败: $e');
    }
    return false;
  }

  /// 按文件名提取快照时间（backup_YYYY-MM-DDTHH-MM-SS.zip）。
  static DateTime? _extractTimestamp(String name) {
    final match = RegExp(r'^backup_(\d{4}-\d{2}-\d{2})T(\d{2}-\d{2}-\d{2})')
        .firstMatch(name);
    if (match == null) return null;
    try {
      return DateTime.parse(
          '${match.group(1)}T${match.group(2)!.replaceAll('-', ':')}');
    } catch (_) {
      return null;
    }
  }

  /// 清理超出保留策略的旧快照（策略与旧 AutoBackups 一致）。
  static Future<void> cleanupOldSnapshots() async {
    try {
      final dir = await snapshotsDir;
      if (!await dir.exists()) return;
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.zip'))
          .toList();

      final infos = <_SnapshotInfo>[];
      for (final f in files) {
        final name = f.path.split(Platform.pathSeparator).last;
        final ts = _extractTimestamp(name);
        if (ts != null) {
          infos.add(_SnapshotInfo(path: f.path, modified: ts));
        }
      }
      if (infos.length <= 3) return;
      infos.sort((a, b) => b.modified.compareTo(a.modified));

      final now = _now();
      final within24h = infos
          .where((i) =>
              i.modified.isAfter(now.subtract(const Duration(hours: 24))))
          .toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      final beyond24h = infos
          .where((i) =>
              !i.modified.isAfter(now.subtract(const Duration(hours: 24))))
          .toList();

      final keep = <String>{
        ...within24h.take(3).map((i) => i.path),
      };
      final dayToLatest = <String, _SnapshotInfo>{};
      for (final info in beyond24h) {
        final dayKey = '${info.modified.year}-${_pad(info.modified.month)}-'
            '${_pad(info.modified.day)}';
        final existing = dayToLatest[dayKey];
        if (existing == null || info.modified.isAfter(existing.modified)) {
          dayToLatest[dayKey] = info;
        }
      }
      final sortedDays = dayToLatest.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      for (var i = 0;
          i < (sortedDays.length < 2 ? sortedDays.length : 2);
          i++) {
        keep.add(sortedDays[i].value.path);
      }
      // 下限 3：不足则从旧的补足
      if (keep.length < 3) {
        for (final info in beyond24h) {
          if (keep.length >= 3) break;
          keep.add(info.path);
        }
      }

      for (final info in infos) {
        if (!keep.contains(info.path)) {
          try {
            await File(info.path).delete();
            debugPrint('[SnapshotService] 清理旧快照: ${info.path}');
          } catch (e) {
            debugPrint('[SnapshotService] 清理旧快照失败: $e');
          }
        }
      }
      // 同步索引
      final index = await readIndex();
      final keptNames =
          keep.map((path) => path.split(Platform.pathSeparator).last).toSet();
      index.removeWhere((e) => !keptNames.contains(e.file));
      await _writeIndex(index);
    } catch (e) {
      debugPrint('[SnapshotService] 清理旧快照失败: $e');
    }
  }

  /// 列出所有快照（新 → 旧）。
  static Future<List<SnapshotEntry>> listSnapshots() async {
    final index = await readIndex();
    final sorted = List<SnapshotEntry>.from(index)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');
}

class _SnapshotInfo {
  final String path;
  final DateTime modified;
  const _SnapshotInfo({required this.path, required this.modified});
}
