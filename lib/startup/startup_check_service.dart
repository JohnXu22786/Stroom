import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:isolate';

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
  // 是否在测试环境中运行
  // ================================================================

  /// 检测是否在 Flutter 测试环境中运行。
  /// 测试环境不支持 Isolate.run，需要回退到同步执行。
  static bool _inTestMode() {
    try {
      return Platform.environment['FLUTTER_TEST'] == 'true';
    } catch (_) {
      return false;
    }
  }

  // ================================================================
  // 可序列化的中间结果（用于 Isolate 通信）
  // ================================================================

  /// Isolate 间传递的可序列化检查结果。
  @pragma('vm:entry-point')
  static Map<String, String?> _makeIssueMap(
      String message, String severity, String? dataKey) {
    return {
      'message': message,
      'severity': severity,
      'dataKey': dataKey,
    };
  }

  /// 从可序列化 Map 转换为 [StartupIssue]。
  static StartupIssue _issueFromMap(Map<String, String?> map) {
    final sev = map['severity'] ?? 'info';
    return StartupIssue(
      message: map['message'] ?? '',
      severity: sev == 'error'
          ? StartupIssueSeverity.error
          : sev == 'warning'
              ? StartupIssueSeverity.warning
              : StartupIssueSeverity.info,
      dataKey: map['dataKey'],
    );
  }

  // ================================================================
  // 2. 数据格式验证（后台 Isolate 执行）
  // ================================================================

  /// 验证所有关键数据的 JSON 结构和字段完整性。
  ///
  /// 检查范围包括：
  /// - provider_entries: 确保是合法列表，每个条目有非空 id/type/name
  /// - conversations: 确保是合法列表，每个会话有 id/messages 字段
  ///
  /// CPU 密集的 JSON 解析工作会在后台 Isolate 中执行，
  /// 避免阻塞主 UI 线程导致页面顿住。测试环境下回退到同步执行。
  static Future<List<StartupIssue>> validateDataFormats() async {
    final prefs = await SharedPreferences.getInstance();
    final providerEntriesJson = prefs.getString('provider_entries');
    final conversationsJson = prefs.getString('conversations');

    // 在测试环境下回退到同步执行（Isolate 在 FakeAsync 中不可用）
    if (_inTestMode()) {
      return _validateDataFormatsSync(providerEntriesJson, conversationsJson);
    }

    // 生产环境：在后台 Isolate 中执行 CPU 密集的 JSON 解析和验证
    try {
      final resultMaps = await Isolate.run(() {
        return _validateDataFormatsSync(providerEntriesJson, conversationsJson);
      });
      return resultMaps;
    } catch (e) {
      debugPrint('[StartupCheckService] Isolate validation failed: $e');
      // Isolate 不可用时（如部分受限环境），回退到同步执行
      return _validateDataFormatsSync(providerEntriesJson, conversationsJson);
    }
  }

  /// 数据格式验证的同步实现（可在 Isolate 中执行或测试环境使用）。
  @pragma('vm:entry-point')
  static List<StartupIssue> _validateDataFormatsSync(
      String? providerEntriesJson, String? conversationsJson) {
    final issues = <StartupIssue>[];

    _validateProviderEntriesSync(providerEntriesJson, issues);
    _validateConversationsSync(conversationsJson, issues);

    return issues;
  }

  /// 验证 provider_entries 的 JSON 格式和字段完整性。
  static void _validateProviderEntriesSync(
    String? json,
    List<StartupIssue> issues,
  ) {
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
      _validateNestedListSync(entry, 'configs', i, issues);
      final configs = entry['configs'] as List?;
      if (configs != null) {
        for (int ci = 0; ci < configs.length; ci++) {
          if (configs[ci] is! Map<String, dynamic>) continue;
          final config = configs[ci] as Map<String, dynamic>;
          _validateNestedListSync(config, 'models', i, issues);
          final models = config['models'] as List?;
          if (models != null) {
            for (int mi = 0; mi < models.length; mi++) {
              if (models[mi] is! Map<String, dynamic>) continue;
              final model = models[mi] as Map<String, dynamic>;
              _validateNestedListSync(model, 'customParams', i, issues);
              _validateNestedListSync(model, 'voices', i, issues);
              _validateNestedListSync(model, 'reasoningParams', i, issues);
            }
          }
        }
      }
    }
  }

  /// 验证嵌套列表中是否包含非 Map 条目。
  static void _validateNestedListSync(
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
  static void _validateConversationsSync(
    String? json,
    List<StartupIssue> issues,
  ) {
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
  }

  // ================================================================
  // 3. 数据完整性检查（后台 Isolate 执行）
  // ================================================================

  /// 检查数据一致性和完整性。
  ///
  /// 当前检查项：
  /// - provider_entries 中引用的类型是否在已知类型列表中
  ///
  /// CPU 密集的 JSON 解析工作在后台 Isolate 中执行，
  /// 避免阻塞主 UI 线程。
  static Future<List<StartupIssue>> checkDataIntegrity() async {
    final prefs = await SharedPreferences.getInstance();
    final providerEntriesJson = prefs.getString('provider_entries');

    // 在测试环境下回退到同步执行
    if (_inTestMode()) {
      return _checkDataIntegritySync(providerEntriesJson);
    }

    // 生产环境：在后台 Isolate 中执行
    try {
      final resultMaps = await Isolate.run(() {
        return _checkDataIntegritySync(providerEntriesJson);
      });
      return resultMaps;
    } catch (e) {
      debugPrint('[StartupCheckService] Isolate check failed: $e');
      return _checkDataIntegritySync(providerEntriesJson);
    }
  }

  /// 数据完整性检查的同步实现（可在 Isolate 中或测试环境使用）。
  @pragma('vm:entry-point')
  static List<StartupIssue> _checkDataIntegritySync(
      String? providerEntriesJson) {
    final issues = <StartupIssue>[];
    if (providerEntriesJson == null || providerEntriesJson.isEmpty) {
      return issues;
    }

    try {
      final list = jsonDecode(providerEntriesJson) as List<dynamic>;
      for (int i = 0; i < list.length; i++) {
        // 兜底：跳过非 Map 条目
        if (list[i] is! Map<String, dynamic>) {
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
    return issues;
  }

  /// 检查类型是否在已知的供应商类型列表中。
  static bool _isKnownProviderType(String type) {
    return ['llm', 'tts', 'ocr', 'asr', 'mcp', 'builtin'].contains(type);
  }
}
