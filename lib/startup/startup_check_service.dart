import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

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
        // 兜底：跳过非 Map 条目，避免 `as Map` 类型转换闪退
        if (list[i] is! Map<String, dynamic>) {
          issues.add(StartupIssue(
            message: 'provider_entries[$i]: 条目为 null 或类型无效',
            severity: StartupIssueSeverity.error,
            dataKey: 'provider_entries',
          ));
          continue;
        }
        final entry = list[i] as Map<String, dynamic>;

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

        // ================================================================
        // 验证嵌套列表内容 — 检查 configs/models/customParams/voices/
        // reasoningParams 中是否包含非 Map 条目（这些会导致 ProviderEntry
        // 解析时 `as Map` 闪退）。
        // ================================================================
        _validateNestedList(entry, 'configs', i, issues);
        final configs = entry['configs'] as List?;
        if (configs != null) {
          for (int ci = 0; ci < configs.length; ci++) {
            if (configs[ci] is! Map<String, dynamic>) continue;
            final config = configs[ci] as Map<String, dynamic>;
            _validateNestedList(config, 'models', i, issues);
            final models = config['models'] as List?;
            if (models != null) {
              for (int mi = 0; mi < models.length; mi++) {
                if (models[mi] is! Map<String, dynamic>) continue;
                final model = models[mi] as Map<String, dynamic>;
                _validateNestedList(model, 'customParams', i, issues);
                _validateNestedList(model, 'voices', i, issues);
                _validateNestedList(model, 'reasoningParams', i, issues);
              }
            }
          }
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

  /// 验证嵌套列表中是否包含非 Map 条目。
  ///
  /// 如果 [fieldName] 对应的值是列表但包含非 Map 条目，则报告错误。
  /// 这些非 Map 条目会在 ProviderEntry/ModelConfig 解析时导致 `as Map` 闪退。
  static void _validateNestedList(
    Map<String, dynamic> parent,
    String fieldName,
    int entryIndex,
    List<StartupIssue> issues,
  ) {
    final list = parent[fieldName];
    if (list is! List) return;
    for (int j = 0; j < list.length; j++) {
      if (list[j] is! Map<String, dynamic>) {
        issues.add(StartupIssue(
          message: 'provider_entries[$entryIndex].$fieldName[$j]: '
              '条目不是合法对象，可能会导致解析闪退',
          severity: StartupIssueSeverity.error,
          dataKey: 'provider_entries',
        ));
      }
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
        // 兜底：跳过非 Map 条目，避免 `as Map` 类型转换闪退
        if (list[i] is! Map<String, dynamic>) {
          issues.add(StartupIssue(
            message: 'conversations[$i]: 会话为 null 或类型无效',
            severity: StartupIssueSeverity.error,
            dataKey: 'conversations',
          ));
          continue;
        }
        final conv = list[i] as Map<String, dynamic>;

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
        // 兜底：跳过非 Map 条目，避免 `as Map<String, dynamic>` 闪退
        if (list[i] is! Map<String, dynamic>) {
          debugPrint(
              '[StartupCheckService] Skipping non-Map entry at index $i in type registration check');
          continue;
        }
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
}
