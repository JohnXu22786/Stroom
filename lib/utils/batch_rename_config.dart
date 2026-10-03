import 'sort_config.dart';

/// 编号位置
enum BatchRenameNumberPos { prefix, suffix }

/// 插入位置
enum BatchRenameInsertPos { start, end, atIndex }

/// 删除字符位置
enum BatchRenameDeletePos { start, end, atIndex }

/// 大小写模式
enum BatchRenameCaseMode { upper, lower, firstUpper, title }

enum BatchRenameConflictStrategy { block, numberSuffix }

sealed class BatchRenameOp {
  const BatchRenameOp();
  bool get enabled;
}

// --------------------------------------------------------------------
// 操作配置
// --------------------------------------------------------------------

/// 编号操作：为排序后的每一项追加/前置序号
class BatchNumberOp extends BatchRenameOp {
  final bool restartPerFolder;
  final bool enabled;
  final BatchRenameNumberPos position;
  final int start;
  final int step;
  final int digits;
  final String separator;

  const BatchNumberOp({
    this.restartPerFolder = false,
    this.enabled = false,
    this.position = BatchRenameNumberPos.prefix,
    this.start = 1,
    this.step = 1,
    this.digits = 1,
    this.separator = '_',
  });

  bool get effective => enabled;

  BatchNumberOp copyWith({
    bool? restartPerFolder,
    bool? enabled,
    BatchRenameNumberPos? position,
    int? start,
    int? step,
    int? digits,
    String? separator,
  }) =>
      BatchNumberOp(
        restartPerFolder: restartPerFolder ?? this.restartPerFolder,
        enabled: enabled ?? this.enabled,
        position: position ?? this.position,
        start: start ?? this.start,
        step: step ?? this.step,
        digits: digits ?? this.digits,
        separator: separator ?? this.separator,
      );
}

/// 替换操作：查找并替换文本
class BatchReplaceOp extends BatchRenameOp {
  final bool useRegex;
  final bool firstOnly;
  final bool enabled;
  final String find;
  final String replace;
  final bool caseSensitive;

  const BatchReplaceOp({
    this.useRegex = false,
    this.firstOnly = false,
    this.enabled = false,
    this.find = '',
    this.replace = '',
    this.caseSensitive = false,
  });

  /// 查找内容为空时替换无意义
  bool get effective => enabled && find.isNotEmpty;

  BatchReplaceOp copyWith({
    bool? useRegex,
    bool? firstOnly,
    bool? enabled,
    String? find,
    String? replace,
    bool? caseSensitive,
  }) =>
      BatchReplaceOp(
        useRegex: useRegex ?? this.useRegex,
        firstOnly: firstOnly ?? this.firstOnly,
        enabled: enabled ?? this.enabled,
        find: find ?? this.find,
        replace: replace ?? this.replace,
        caseSensitive: caseSensitive ?? this.caseSensitive,
      );
}

/// 插入操作：在开头/结尾/指定位置插入文本
class BatchInsertOp extends BatchRenameOp {
  final bool enabled;
  final BatchRenameInsertPos position;
  final int index;
  final String text;

  const BatchInsertOp({
    this.enabled = false,
    this.position = BatchRenameInsertPos.start,
    this.index = 1,
    this.text = '',
  });

  /// 文本为空时插入无意义
  bool get effective => enabled && text.isNotEmpty;

  BatchInsertOp copyWith({
    bool? enabled,
    BatchRenameInsertPos? position,
    int? index,
    String? text,
  }) =>
      BatchInsertOp(
        enabled: enabled ?? this.enabled,
        position: position ?? this.position,
        index: index ?? this.index,
        text: text ?? this.text,
      );
}

/// 删除字符操作：从开头/结尾删除指定数量字符
class BatchDeleteOp extends BatchRenameOp {
  final int index;
  final bool enabled;
  final BatchRenameDeletePos position;
  final int count;

  const BatchDeleteOp({
    this.index = 1,
    this.enabled = false,
    this.position = BatchRenameDeletePos.start,
    this.count = 1,
  });

  /// 数量为 0 时删除无意义
  bool get effective => enabled && count > 0;

  BatchDeleteOp copyWith({
    int? index,
    bool? enabled,
    BatchRenameDeletePos? position,
    int? count,
  }) =>
      BatchDeleteOp(
        index: index ?? this.index,
        enabled: enabled ?? this.enabled,
        position: position ?? this.position,
        count: count ?? this.count,
      );
}

/// 大小写转换操作
class BatchCaseOp extends BatchRenameOp {
  final bool enabled;
  final BatchRenameCaseMode mode;

  const BatchCaseOp({
    this.enabled = false,
    this.mode = BatchRenameCaseMode.lower,
  });

  bool get effective => enabled;

  BatchCaseOp copyWith({bool? enabled, BatchRenameCaseMode? mode}) =>
      BatchCaseOp(enabled: enabled ?? this.enabled, mode: mode ?? this.mode);
}

/// 模板使用原始记录的名称和日期，拥有独立编号设置。
class BatchTemplateOp extends BatchRenameOp {
  @override
  final bool enabled;
  final String pattern;
  final int start;
  final int step;
  final int digits;
  final bool restartPerFolder;
  const BatchTemplateOp(
      {this.enabled = false,
      this.pattern = '{name}_{n}',
      this.start = 1,
      this.step = 1,
      this.digits = 3,
      this.restartPerFolder = false});
  BatchTemplateOp copyWith(
          {bool? enabled,
          String? pattern,
          int? start,
          int? step,
          int? digits,
          bool? restartPerFolder}) =>
      BatchTemplateOp(
          enabled: enabled ?? this.enabled,
          pattern: pattern ?? this.pattern,
          start: start ?? this.start,
          step: step ?? this.step,
          digits: digits ?? this.digits,
          restartPerFolder: restartPerFolder ?? this.restartPerFolder);
}

class BatchCleanupOp extends BatchRenameOp {
  @override
  final bool enabled;
  final bool trim;
  final bool collapseWhitespace;
  const BatchCleanupOp(
      {this.enabled = false,
      this.trim = true,
      this.collapseWhitespace = false});
  BatchCleanupOp copyWith(
          {bool? enabled, bool? trim, bool? collapseWhitespace}) =>
      BatchCleanupOp(
          enabled: enabled ?? this.enabled,
          trim: trim ?? this.trim,
          collapseWhitespace: collapseWhitespace ?? this.collapseWhitespace);
}

/// 批量重命名完整配置（含编号排序方式）
class BatchRenameConfig {
  final List<BatchRenameOp>? rules;
  final BatchTemplateOp template;
  final BatchCleanupOp cleanup;
  final BatchRenameConflictStrategy conflictStrategy;

  // 保留默认链的构造参数；工作台用 rules 表示可重复、可排序的规则。
  List<BatchRenameOp> get operations =>
      rules ??
      [
        template,
        numbering,
        replace,
        delete,
        insert,
        caseOp,
        cleanup,
      ];
  final SortField sortField;
  final SortOrder sortOrder;
  final BatchNumberOp numbering;
  final BatchReplaceOp replace;
  final BatchInsertOp insert;
  final BatchDeleteOp delete;
  final BatchCaseOp caseOp;

  const BatchRenameConfig({
    this.rules,
    this.template = const BatchTemplateOp(),
    this.cleanup = const BatchCleanupOp(),
    this.conflictStrategy = BatchRenameConflictStrategy.block,
    this.sortField = SortField.name,
    this.sortOrder = SortOrder.ascending,
    this.numbering = const BatchNumberOp(),
    this.replace = const BatchReplaceOp(),
    this.insert = const BatchInsertOp(),
    this.delete = const BatchDeleteOp(),
    this.caseOp = const BatchCaseOp(),
  });

  BatchRenameConfig copyWith({
    List<BatchRenameOp>? rules,
    BatchTemplateOp? template,
    BatchCleanupOp? cleanup,
    BatchRenameConflictStrategy? conflictStrategy,
    SortField? sortField,
    SortOrder? sortOrder,
    BatchNumberOp? numbering,
    BatchReplaceOp? replace,
    BatchInsertOp? insert,
    BatchDeleteOp? delete,
    BatchCaseOp? caseOp,
  }) =>
      BatchRenameConfig(
        rules: rules ?? this.rules,
        template: template ?? this.template,
        cleanup: cleanup ?? this.cleanup,
        conflictStrategy: conflictStrategy ?? this.conflictStrategy,
        sortField: sortField ?? this.sortField,
        sortOrder: sortOrder ?? this.sortOrder,
        numbering: numbering ?? this.numbering,
        replace: replace ?? this.replace,
        insert: insert ?? this.insert,
        delete: delete ?? this.delete,
        caseOp: caseOp ?? this.caseOp,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'sortField': sortField.name,
        'sortOrder': sortOrder.name,
        'conflicts': conflictStrategy.name,
        'rules': operations.map((r) => r.toJson()).toList(),
      };

  factory BatchRenameConfig.fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != 1) throw const FormatException('不支持的方案版本');
      final rules = json['rules'] as List;
      if (rules.length > 50) throw const FormatException('规则数量超过 50 条');
      return BatchRenameConfig(
        sortField: SortField.values.byName(json['sortField'] as String),
        sortOrder: SortOrder.values.byName(json['sortOrder'] as String),
        conflictStrategy: BatchRenameConflictStrategy.values
            .byName(json['conflicts'] as String),
        rules: rules
            .map((r) =>
                batchRenameOpFromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('方案数据无效');
    }
  }
}

extension BatchRenameOpData on BatchRenameOp {
  String get label => switch (this) {
        BatchNumberOp() => '编号',
        BatchReplaceOp() => '替换',
        BatchInsertOp() => '插入',
        BatchDeleteOp() => '删除字符',
        BatchCaseOp() => '大小写',
        BatchTemplateOp() => '命名模板',
        BatchCleanupOp() => '空白清理',
      };

  BatchRenameOp withEnabled(bool value) => switch (this) {
        BatchNumberOp r => r.copyWith(enabled: value),
        BatchReplaceOp r => r.copyWith(enabled: value),
        BatchInsertOp r => r.copyWith(enabled: value),
        BatchDeleteOp r => r.copyWith(enabled: value),
        BatchCaseOp r => r.copyWith(enabled: value),
        BatchTemplateOp r => r.copyWith(enabled: value),
        BatchCleanupOp r => r.copyWith(enabled: value),
      };

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        ...switch (this) {
          BatchNumberOp r => {
              'type': 'number',
              'position': r.position.name,
              'start': r.start,
              'step': r.step,
              'digits': r.digits,
              'separator': r.separator,
              'restartPerFolder': r.restartPerFolder
            },
          BatchReplaceOp r => {
              'type': 'replace',
              'find': r.find,
              'replace': r.replace,
              'caseSensitive': r.caseSensitive,
              'useRegex': r.useRegex,
              'firstOnly': r.firstOnly
            },
          BatchInsertOp r => {
              'type': 'insert',
              'position': r.position.name,
              'index': r.index,
              'text': r.text
            },
          BatchDeleteOp r => {
              'type': 'delete',
              'position': r.position.name,
              'index': r.index,
              'count': r.count
            },
          BatchCaseOp r => {'type': 'case', 'mode': r.mode.name},
          BatchTemplateOp r => {
              'type': 'template',
              'pattern': r.pattern,
              'start': r.start,
              'step': r.step,
              'digits': r.digits,
              'restartPerFolder': r.restartPerFolder
            },
          BatchCleanupOp r => {
              'type': 'cleanup',
              'trim': r.trim,
              'collapseWhitespace': r.collapseWhitespace
            },
        },
      };
}

BatchRenameOp batchRenameOpFromJson(Map<String, dynamic> j) {
  final enabled = j['enabled'] as bool;
  return switch (j['type']) {
    'number' => BatchNumberOp(
        enabled: enabled,
        position: BatchRenameNumberPos.values.byName(j['position'] as String),
        start: j['start'] as int,
        step: j['step'] as int,
        digits: j['digits'] as int,
        separator: j['separator'] as String,
        restartPerFolder: j['restartPerFolder'] as bool),
    'replace' => BatchReplaceOp(
        enabled: enabled,
        find: j['find'] as String,
        replace: j['replace'] as String,
        caseSensitive: j['caseSensitive'] as bool,
        useRegex: j['useRegex'] as bool,
        firstOnly: j['firstOnly'] as bool),
    'insert' => BatchInsertOp(
        enabled: enabled,
        position: BatchRenameInsertPos.values.byName(j['position'] as String),
        index: j['index'] as int,
        text: j['text'] as String),
    'delete' => BatchDeleteOp(
        enabled: enabled,
        position: BatchRenameDeletePos.values.byName(j['position'] as String),
        index: j['index'] as int,
        count: j['count'] as int),
    'case' => BatchCaseOp(
        enabled: enabled,
        mode: BatchRenameCaseMode.values.byName(j['mode'] as String)),
    'template' => BatchTemplateOp(
        enabled: enabled,
        pattern: j['pattern'] as String,
        start: j['start'] as int,
        step: j['step'] as int,
        digits: j['digits'] as int,
        restartPerFolder: j['restartPerFolder'] as bool),
    'cleanup' => BatchCleanupOp(
        enabled: enabled,
        trim: j['trim'] as bool,
        collapseWhitespace: j['collapseWhitespace'] as bool),
    _ => throw const FormatException('未知规则类型'),
  };
}
