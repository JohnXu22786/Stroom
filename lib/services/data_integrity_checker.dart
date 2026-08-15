import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../startup/startup_check_service.dart';
import '../utils/web_file_store.dart';
import 'manifest_database.dart';
import 'storage_service.dart';

/// 单条完整性校验问题。
class DataIntegrityIssue {
  /// 数据部分标识（与 [DataParts] 对齐；`file` 表示非版本化文件）。
  final String part;

  /// 人类可读的问题描述。
  final String message;

  /// true = 数据已损坏（应进入修复/回滚流程）；
  /// false = 仅警告（不影响使用，不触发回滚）。
  final bool isCorruption;

  const DataIntegrityIssue({
    required this.part,
    required this.message,
    required this.isCorruption,
  });
}

/// 完整性校验报告。
class DataIntegrityReport {
  final List<DataIntegrityIssue> issues;

  const DataIntegrityReport(this.issues);

  bool get hasCorruption => issues.any((i) => i.isCorruption);

  List<DataIntegrityIssue> get corruptions =>
      issues.where((i) => i.isCorruption).toList();
}

/// 启动数据完整性校验器。
///
/// 四层检查：
/// 1. 物理层：SQLite `PRAGMA integrity_check`（原生平台）、JSON 可解析性
/// 2. 格式层：版本记录 `data_format_versions` 合法性（超前版本由
///    版本哨兵另行处理，这里只判"记录本身是否可解析"）
/// 3. 语义层：复用 [StartupCheckService.validateDataFormats] 的
///    provider_entries / conversations 结构校验（防闪退检查）
///
/// 语义层只查"必然正确"的硬性不变量，绝不查"记录数"等软指标，
/// 防止正常操作触发误报回滚。
///
/// 注意：快照文件本身的 SHA-256 校验在 SnapshotService 中执行，
/// 本检查器只校验"当前正在使用的数据"。
class DataIntegrityChecker {
  DataIntegrityChecker._();

  static const _taskFiles = [
    'synthesis/tasks.json',
    'catcatch/tasks.json',
    'background/tasks.json',
  ];

  static const _taskFlowFiles = [
    'task_flows/flows.json',
    'task_flows/executions.json',
  ];

  /// 检查当前数据完整性。
  static Future<DataIntegrityReport> checkCurrentData() async {
    final issues = <DataIntegrityIssue>[];

    await _checkPrefsJsonKeys(issues);
    await _checkTaskFiles(issues);
    await _checkCookies(issues);
    await _checkSqliteDatabases(issues);
    await _checkSemantics(issues);

    return DataIntegrityReport(issues);
  }

  // ================================================================
  // 1. prefs JSON 键解析
  // ================================================================

  static Future<void> _checkPrefsJsonKeys(
      List<DataIntegrityIssue> issues) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        'conversations',
        'provider_entries',
        'data_format_versions',
      ]) {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) continue;
        try {
          jsonDecode(raw);
        } catch (e) {
          issues.add(DataIntegrityIssue(
            part: key == 'data_format_versions' ? 'settings' : 'chat',
            message: 'SharedPreferences 键 $key 无法解析: $e',
            isCorruption: true,
          ));
        }
      }
    } catch (e) {
      debugPrint('[DataIntegrityChecker] prefs 检查失败: $e');
    }
  }

  // ================================================================
  // 2. 任务/任务流 JSON 文件
  // ================================================================

  static Future<void> _checkTaskFiles(List<DataIntegrityIssue> issues) async {
    if (kIsWeb) return;
    try {
      final appDir = await AppStorage.directory;
      for (final rel in [..._taskFiles, ..._taskFlowFiles]) {
        final file = File(p.join(appDir, rel));
        if (!await file.exists()) continue;
        try {
          final content = await file.readAsString();
          if (content.trim().isEmpty) continue;
          jsonDecode(content);
        } catch (e) {
          issues.add(DataIntegrityIssue(
            part: 'tasks',
            message: '任务文件 $rel 无法解析: $e',
            isCorruption: true,
          ));
        }
      }
    } catch (e) {
      debugPrint('[DataIntegrityChecker] 任务文件检查失败: $e');
    }
  }

  // ================================================================
  // 3. Cookies JSON 文件
  // ================================================================

  static Future<void> _checkCookies(List<DataIntegrityIssue> issues) async {
    if (kIsWeb) return;
    try {
      final appDir = await AppStorage.directory;
      final file = File(p.join(appDir, 'browser_cookies.json'));
      if (!await file.exists()) return;
      try {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return;
        jsonDecode(content);
      } catch (e) {
        issues.add(DataIntegrityIssue(
          part: 'browserCookies',
          message: 'browser_cookies.json 无法解析: $e',
          isCorruption: true,
        ));
      }
    } catch (e) {
      debugPrint('[DataIntegrityChecker] cookies 检查失败: $e');
    }
  }

  // ================================================================
  // 4. SQLite 数据库（仅原生平台）
  // ================================================================

  static Future<void> _checkSqliteDatabases(
      List<DataIntegrityIssue> issues) async {
    if (kIsWeb || WebFileStore.isTestMode) return;

    // ManifestDatabase（原生 SQLite）
    try {
      final db = await ManifestDatabase.database;
      final rows = await db.rawQuery('PRAGMA integrity_check');
      final result = rows.isEmpty ? '' : (rows.first.values.first as String?);
      if (result != 'ok') {
        issues.add(DataIntegrityIssue(
          part: 'media',
          message: 'ManifestDatabase integrity_check: $result',
          isCorruption: true,
        ));
      }
    } catch (e) {
      issues.add(DataIntegrityIssue(
        part: 'media',
        message: 'ManifestDatabase 无法打开/校验: $e',
        isCorruption: true,
      ));
    }

    // Anki 数据库：只读打开 + integrity_check（不经过 provider，
    // 避免初始化副作用；被占用时（Windows 独占锁）降级为警告）。
    try {
      final appDir = await AppStorage.directory;
      final ankiFile = File(p.join(appDir, 'collection.anki2'));
      if (!await ankiFile.exists()) return;
      final db = await _openAnkiReadOnly(ankiFile.path);
      if (db != null) {
        try {
          final rows = await db.rawQuery('PRAGMA integrity_check');
          final result =
              rows.isEmpty ? '' : (rows.first.values.first as String?);
          if (result != 'ok') {
            issues.add(DataIntegrityIssue(
              part: 'anki',
              message: 'Anki integrity_check: $result',
              isCorruption: true,
            ));
          }
        } finally {
          await db.close();
        }
      }
    } catch (e) {
      issues.add(DataIntegrityIssue(
        part: 'anki',
        message: 'Anki 数据库校验跳过（无法打开）: $e',
        isCorruption: false,
      ));
    }
  }

  /// 只读打开 SQLite 数据库执行完整性检查。
  ///
  /// 使用 sqflite 的 openReadOnly；失败（如文件被其他连接独占）返回 null。
  static Future<dynamic> _openAnkiReadOnly(String path) async {
    try {
      return await sqflite.openDatabase(path, readOnly: true);
    } catch (e) {
      debugPrint('[DataIntegrityChecker] 只读打开 Anki 失败: $e');
      return null;
    }
  }

  // ================================================================
  // 5. 语义层（复用现有防闪退结构校验）
  // ================================================================

  static Future<void> _checkSemantics(List<DataIntegrityIssue> issues) async {
    try {
      final startupIssues = await StartupCheckService.validateDataFormats();
      for (final issue in startupIssues) {
        if (issue.severity == StartupIssueSeverity.error) {
          issues.add(DataIntegrityIssue(
            part: 'chat',
            message: issue.message,
            isCorruption: true,
          ));
        }
      }
    } catch (e) {
      debugPrint('[DataIntegrityChecker] 语义校验失败: $e');
    }
  }
}
