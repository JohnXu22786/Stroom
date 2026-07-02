import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../services/data_migration_service.dart';

// ====================================================================
// Startup Issue Severity
// ====================================================================

/// Severity level of a startup check issue.
enum StartupIssueSeverity {
  /// Informational — no action needed.
  info,

  /// Warning — data is suboptimal but the app can still function.
  warning,

  /// Error — data is corrupted and should be repaired or reset.
  error,
}

// ====================================================================
// Startup Issue
// ====================================================================

/// Describes a single issue found during startup checks.
class StartupIssue {
  final String message;
  final StartupIssueSeverity severity;
  final String? dataKey;

  const StartupIssue({
    required this.message,
    this.severity = StartupIssueSeverity.info,
    this.dataKey,
  });
}

// ====================================================================
// Startup Check Report
// ====================================================================

/// The full report returned by [StartupCheckService.runAllChecks].
class StartupCheckReport {
  final bool formatVersionChecked;
  final bool dataFormatsValidated;
  final bool dataIntegrityChecked;
  final bool migrationPerformed;
  final List<StartupIssue> issues;

  const StartupCheckReport({
    required this.formatVersionChecked,
    required this.dataFormatsValidated,
    required this.dataIntegrityChecked,
    required this.migrationPerformed,
    this.issues = const [],
  });

  /// Returns only error-level issues.
  List<StartupIssue> get errors =>
      issues.where((i) => i.severity == StartupIssueSeverity.error).toList();

  /// Returns only warning-level issues.
  List<StartupIssue> get warnings =>
      issues.where((i) => i.severity == StartupIssueSeverity.warning).toList();
}

// ====================================================================
// StartupCheckService — 启动检查服务
// ====================================================================
//
// 在应用启动时执行以下检查（按顺序）：
// 1. 数据格式版本检查 — 检查存储数据版本，必要时迁移备份
// 2. 数据格式验证 — 验证关键数据的 JSON 结构是否完整
// 3. 数据完整性检查 — 检查数据一致性（例如引用完整性）
//
// 迁移完成后只有新版本的数据存在，不保留旧版本兼容层。
// ====================================================================

class StartupCheckService {
  StartupCheckService._();

  // ================================================================
  // 1. 数据格式版本检查与迁移
  // ================================================================

  /// 检查数据格式版本，必要时执行迁移。
  ///
  /// 如果版本过低，将自动先执行备份（到应用数据目录外的位置），
  /// 再执行迁移到当前版本。迁移后只有新格式数据存在。
  ///
  /// 每次启动都执行此检查（包括版本已是最新时的恢复性检查）。
  static Future<MigrationResult> checkFormatVersion() async {
    return DataMigrationService.checkAndMigrate();
  }

  // ================================================================
  // 2. 数据格式验证
  // ================================================================

  /// 验证所有关键数据的 JSON 结构和字段完整性。
  ///
  /// 检查范围包括：
  /// - provider_entries: 确保是合法列表，每个条目有非空 id/type/name
  /// - conversations: 确保是合法列表，每个会话有 id/messages 字段
  static Future<List<StartupIssue>> validateDataFormats() async {
    final issues = <StartupIssue>[];
    final prefs = await SharedPreferences.getInstance();

    await _validateProviderEntries(prefs, issues);
    await _validateConversations(prefs, issues);

    return issues;
  }

  /// 验证 provider_entries 的 JSON 格式和字段完整性。
  static Future<void> _validateProviderEntries(
    SharedPreferences prefs,
    List<StartupIssue> issues,
  ) async {
    try {
      final json = prefs.getString('provider_entries');
      if (json == null || json.isEmpty) return;

      List<dynamic> list;
      try {
        list = jsonDecode(json) as List<dynamic>;
      } catch (_) {
        issues.add(const StartupIssue(
          message: 'provider_entries 数据格式错误：不是合法的 JSON 数组',
          severity: StartupIssueSeverity.error,
          dataKey: 'provider_entries',
        ));
        return;
      }

      for (int i = 0; i < list.length; i++) {
        final entry = list[i] as Map<String, dynamic>?;
        if (entry == null) {
          issues.add(StartupIssue(
            message: 'provider_entries[$i]: 条目为 null',
            severity: StartupIssueSeverity.error,
            dataKey: 'provider_entries',
          ));
          continue;
        }

        if (entry['id'] == null || (entry['id'] as String?)?.isEmpty == true) {
          issues.add(StartupIssue(
            message: 'provider_entries[$i]: id 字段缺失或为空',
            severity: StartupIssueSeverity.error,
            dataKey: 'provider_entries',
          ));
        }

        if (entry['type'] == null ||
            (entry['type'] as String?)?.isEmpty == true) {
          issues.add(StartupIssue(
            message: 'provider_entries[$i]: type 字段缺失或为空',
            severity: StartupIssueSeverity.warning,
            dataKey: 'provider_entries',
          ));
        }

        if (entry['name'] == null ||
            (entry['name'] as String?)?.isEmpty == true) {
          issues.add(StartupIssue(
            message: 'provider_entries[$i]: name 字段缺失或为空',
            severity: StartupIssueSeverity.warning,
            dataKey: 'provider_entries',
          ));
        }
      }
    } catch (e) {
      issues.add(StartupIssue(
        message: '验证 provider_entries 时出错: $e',
        severity: StartupIssueSeverity.error,
        dataKey: 'provider_entries',
      ));
    }
  }

  /// 验证 conversations 的 JSON 格式和字段完整性。
  static Future<void> _validateConversations(
    SharedPreferences prefs,
    List<StartupIssue> issues,
  ) async {
    try {
      final json = prefs.getString('conversations');
      if (json == null || json.isEmpty) return;

      List<dynamic> list;
      try {
        list = jsonDecode(json) as List<dynamic>;
      } catch (_) {
        issues.add(const StartupIssue(
          message: 'conversations 数据格式错误：不是合法的 JSON 数组',
          severity: StartupIssueSeverity.error,
          dataKey: 'conversations',
        ));
        return;
      }

      for (int i = 0; i < list.length; i++) {
        final conv = list[i] as Map<String, dynamic>?;
        if (conv == null) {
          issues.add(StartupIssue(
            message: 'conversations[$i]: 会话为 null',
            severity: StartupIssueSeverity.error,
            dataKey: 'conversations',
          ));
          continue;
        }

        if (conv['id'] == null || (conv['id'] as String?)?.isEmpty == true) {
          issues.add(StartupIssue(
            message: 'conversations[$i]: id 字段缺失',
            severity: StartupIssueSeverity.error,
            dataKey: 'conversations',
          ));
        }

        if (conv['messages'] == null) {
          issues.add(StartupIssue(
            message: 'conversations[$i]: messages 字段缺失',
            severity: StartupIssueSeverity.warning,
            dataKey: 'conversations',
          ));
        }
      }
    } catch (e) {
      issues.add(StartupIssue(
        message: '验证 conversations 时出错: $e',
        severity: StartupIssueSeverity.error,
        dataKey: 'conversations',
      ));
    }
  }

  // ================================================================
  // 3. 数据完整性检查
  // ================================================================

  /// 检查数据一致性和完整性。
  ///
  /// 当前检查项：
  /// - provider_entries 中引用的类型是否在已知类型列表中
  static Future<List<StartupIssue>> checkDataIntegrity() async {
    final issues = <StartupIssue>[];
    final prefs = await SharedPreferences.getInstance();

    await _checkProviderTypeRegistration(prefs, issues);

    return issues;
  }

  /// 检查 provider_entries 中所有条目的 type 是否已知。
  static Future<void> _checkProviderTypeRegistration(
    SharedPreferences prefs,
    List<StartupIssue> issues,
  ) async {
    try {
      final json = prefs.getString('provider_entries');
      if (json == null || json.isEmpty) return;

      final list = jsonDecode(json) as List<dynamic>;
      for (int i = 0; i < list.length; i++) {
        final entry = list[i] as Map<String, dynamic>;
        final type = entry['type'] as String?;
        if (type != null && type.isNotEmpty && !_isKnownProviderType(type)) {
          issues.add(StartupIssue(
            message: 'provider_entries[$i]: 未知的供应商类型 "$type"，'
                '应用可能无法正常使用该供应商',
            severity: StartupIssueSeverity.warning,
            dataKey: 'provider_entries',
          ));
        }
      }
    } catch (e) {
      debugPrint('[StartupCheckService] Failed to check provider types: $e');
    }
  }

  /// 检查类型是否在已知的供应商类型列表中。
  static bool _isKnownProviderType(String type) {
    return ['llm', 'tts', 'ocr', 'asr', 'mcp', 'builtin'].contains(type);
  }

  // ================================================================
  // 4. 数据格式修复
  // ================================================================

  /// 修复常见的数据格式问题，确保数据在当前版本下可被安全读取。
  ///
  /// 在启动检查的最后阶段调用，修复后直接持久化。
  /// 当前修复项：
  /// - provider_entries 中 null/空字符串 的 id 字段（会生成 UUID）
  /// - provider_entries 中 null 的 type 字段
  /// - provider_entries 中 null 的条目
  ///
  /// 返回修复过程中发现的错误日志数量（非修复数量）。
  static Future<int> repairDataFormats() async {
    final prefs = await SharedPreferences.getInstance();
    int errorCount = 0;

    errorCount += await _repairProviderEntries(prefs);

    if (errorCount > 0) {
      debugPrint(
          '[StartupCheckService] Data repair completed with $errorCount error(s)');
    } else {
      debugPrint('[StartupCheckService] Data repair completed, no errors');
    }

    return errorCount;
  }

  /// 修复 provider_entries 中的常见格式问题。
  ///
  /// 返回遇到的解析错误数（非修复数）。
  static Future<int> _repairProviderEntries(SharedPreferences prefs) async {
    final json = prefs.getString('provider_entries');
    if (json == null || json.isEmpty) return 0;

    List<dynamic> list;
    try {
      list = jsonDecode(json) as List<dynamic>;
    } catch (e) {
      debugPrint('[StartupCheckService] provider_entries is malformed JSON, '
          'cannot repair: $e');
      return 1;
    }

    bool changed = false;
    int parseErrors = 0;

    for (int i = 0; i < list.length; i++) {
      final entry = list[i];
      if (entry is! Map<String, dynamic>) {
        debugPrint(
            '[StartupCheckService] provider_entries[$i] is null/non-map, '
            'removing');
        list[i] = <String, dynamic>{
          'id': 'provider_${const Uuid().v4()}',
          'type': 'tts',
          'name': '已修复条目',
          'configs': <Map<String, dynamic>>[],
        };
        changed = true;
        continue;
      }

      // Fix null/empty id — also handles non-String types (e.g. int from corrupted data)
      final rawId = entry['id'];
      if (rawId == null || rawId is! String || rawId.isEmpty) {
        final rawType = entry['type'];
        final type = rawType is String ? rawType : 'unknown';
        entry['id'] = 'repaired_${type}_${const Uuid().v4()}';
        changed = true;
        debugPrint(
            '[StartupCheckService] Fixed null/empty id at index $i (type: $type)');
      }

      // Fix null/empty type — also handles non-String types
      if (entry['type'] == null ||
          entry['type'] is! String ||
          (entry['type'] as String).isEmpty) {
        entry['type'] = 'tts';
        changed = true;
        debugPrint('[StartupCheckService] Fixed null/empty type at index $i');
      }

      // Fix null/empty name — also handles non-String types
      if (entry['name'] == null ||
          entry['name'] is! String ||
          (entry['name'] as String).isEmpty) {
        entry['name'] = '供应商 ${i + 1}';
        changed = true;
        debugPrint('[StartupCheckService] Fixed null/empty name at index $i');
      }

      // Fix null configs
      if (entry['configs'] == null || (entry['configs'] is! List)) {
        entry['configs'] = <Map<String, dynamic>>[];
        changed = true;
      }
    }

    if (changed) {
      try {
        await prefs.setString('provider_entries', jsonEncode(list));
        debugPrint('[StartupCheckService] provider_entries repaired and saved');
      } catch (e) {
        debugPrint('[StartupCheckService] Failed to save repaired data: $e');
        parseErrors++;
      }
    }

    return parseErrors;
  }
}
