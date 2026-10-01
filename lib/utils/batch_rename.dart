import 'package:characters/characters.dart';

import 'batch_rename_config.dart';
import 'batch_rename_regex.dart';
import 'manifest_bridge.dart';
export 'batch_rename_config.dart';
import 'natural_sort.dart';
import 'sort_config.dart';

// Batch rename planning is pure: ordered rules, per-item overrides and complete
// final-state conflict detection produce the same names shown in the preview.

// --------------------------------------------------------------------
// 输入项 / 结果 / 计划
// --------------------------------------------------------------------

/// 一个待重命名项（文件或文件夹）
class BatchRenameItem {
  final String id;

  /// 文件为记录 id；文件夹为完整路径
  final bool isFolder;

  /// 基础名（不含扩展名；文件夹为末级名）
  final String name;

  /// 文件扩展名（文件夹为 ''）
  final String format;

  /// 文件所在文件夹路径 / 文件夹的父路径
  final String folder;
  final DateTime? createdAt;

  /// 内容最后修改时间（与文件记录一致；文件夹为 null）
  final DateTime? modifiedAt;
  final int size;

  const BatchRenameItem({
    required this.id,
    required this.isFolder,
    required this.name,
    this.format = '',
    this.folder = '',
    this.createdAt,
    this.modifiedAt,
    this.size = 0,
  });

  String get key => '${isFolder ? 'folder' : 'file'}:$id';

  /// 显示名：文件带扩展名，文件夹仅末级名
  String get displayName => isFolder || format.isEmpty ? name : '$name.$format';
}

/// 单条预览结果
class BatchRenameResult {
  final BatchRenameItem item;

  /// 应用操作链后的基础名（与 [BatchRenameItem.name] 相同表示未变化）
  String baseName;
  final String oldDisplay;
  String newDisplay;
  final bool included;
  String? targetFolder;
  String get oldPath =>
      item.folder.isEmpty ? oldDisplay : '${item.folder}/$oldDisplay';
  String get newPath => (targetFolder ?? item.folder).isEmpty
      ? newDisplay
      : '${targetFolder ?? item.folder}/$newDisplay';

  /// 冲突/非法名称原因；null 表示该项可应用
  String? error;

  BatchRenameResult({
    required this.item,
    required this.baseName,
    required this.oldDisplay,
    required this.newDisplay,
    this.error,
    this.included = true,
  });

  bool get isChanged => baseName != item.name;
}

/// 一条待执行的改名指令（由计划生成，保证应用顺序安全）
class BatchRenameEntry {
  final String id;

  /// 文件为记录 id；文件夹为原完整路径
  final bool isFolder;
  final String newBaseName;

  const BatchRenameEntry({
    required this.id,
    required this.isFolder,
    required this.newBaseName,
  });
}

/// 批量重命名计划：预览结果 + 应用顺序
class BatchRenamePlan {
  final List<BatchRenameResult> results;
  final String? configError;

  /// 文件夹改名指令，已按安全顺序排列（子文件夹先于父文件夹；
  /// 名称让位/互换时按腾位顺序执行）
  final List<BatchRenameEntry> folderEntries;

  /// 文件改名指令（按预览排序顺序）
  final List<BatchRenameEntry> fileEntries;

  BatchRenamePlan({
    required this.results,
    this.configError,
    required this.folderEntries,
    required this.fileEntries,
  });

  int get changeCount => results.where((r) => r.isChanged).length;
  int get conflictCount => results.where((r) => r.error != null).length;

  /// 无冲突且确实存在改名项时才可应用
  bool get canApply =>
      configError == null &&
      changeCount > 0 &&
      results.every((r) => r.error == null);
}

// --------------------------------------------------------------------
// 计划计算
// --------------------------------------------------------------------

/// Interactive previews use a cancellable worker for user regexes. Other
/// operations and the final conflict/scheduling pass share the sync engine.
Future<BatchRenamePlan> computeBatchRenamePlanAsync({
  required List<BatchRenameItem> items,
  required BatchRenameConfig config,
  required ManifestBridge bridge,
  required Set<String> allFolders,
  required List<BatchRenameItem> allFiles,
  required BatchRenameRegexWorker regexWorker,
  Set<String> excludedKeys = const {},
  Map<String, String> overrides = const {},
}) async {
  if (validateBatchRenameConfig(config) != null) {
    return computeBatchRenamePlan(
        items: items,
        config: config,
        bridge: bridge,
        allFolders: allFolders,
        allFiles: allFiles,
        excludedKeys: excludedKeys,
        overrides: overrides);
  }
  final sorted = _sortItems(items, config)
      .where((item) => !excludedKeys.contains(item.key))
      .toList();
  final indices = <String, (int, int)>{};
  final folderIndices = <String, int>{};
  for (var i = 0; i < sorted.length; i++) {
    final item = sorted[i];
    final folderIndex = folderIndices[item.folder] ?? 0;
    indices[item.key] = (i, folderIndex);
    folderIndices[item.folder] = folderIndex + 1;
  }
  final names = {for (final item in sorted) item.key: item.name};
  final errors = <String, String>{};
  for (final op in config.operations.where((op) => op.enabled)) {
    final active = sorted
        .where((item) =>
            !overrides.containsKey(item.key) && !errors.containsKey(item.key))
        .toList();
    if (op is BatchReplaceOp &&
        op.effective &&
        op.useRegex &&
        active.isNotEmpty) {
      final replacements = await regexWorker
          .replace([for (final item in active) names[item.key]!], op);
      for (var i = 0; i < active.length; i++) {
        final key = active[i].key;
        final value = replacements[i];
        if (value.error != null) {
          errors[key] = value.error!;
        } else {
          names[key] = value.name!;
        }
      }
    } else {
      for (final item in active) {
        final index = indices[item.key]!;
        try {
          names[item.key] = _applyOps(
              item, index.$1, index.$2, config.copyWith(rules: [op]),
              initialName: names[item.key]);
        } on FormatException catch (e) {
          errors[item.key] = e.message;
        }
      }
    }
  }
  final plan = computeBatchRenamePlan(
      items: items,
      config: config.copyWith(rules: []),
      bridge: bridge,
      allFolders: allFolders,
      allFiles: allFiles,
      excludedKeys: excludedKeys,
      overrides: {
        ...names,
        ...overrides,
        for (final item in sorted)
          if (errors.containsKey(item.key)) item.key: item.name
      });
  for (final result in plan.results) {
    if (errors.containsKey(result.item.key))
      result.error = errors[result.item.key];
  }
  return plan;
}

/// 计算批量重命名计划。
/// [items] 为选中的文件与文件夹；[allFiles] 为全部文件记录（用于冲突
/// 检测，选中项按 id 排除）；[allFolders] 为全部文件夹路径（选中项按
/// 自身路径排除）。
BatchRenamePlan computeBatchRenamePlan({
  required List<BatchRenameItem> items,
  required BatchRenameConfig config,
  required ManifestBridge bridge,
  required Set<String> allFolders,
  required List<BatchRenameItem> allFiles,
  Set<String> excludedKeys = const {},
  Map<String, String> overrides = const {},
}) {
  final selectedFileIds =
      items.where((i) => !i.isFolder).map((i) => i.id).toSet();

  // 1. 排序（文件夹组在前，文件组在后；编号按此顺序分配）
  final sorted = _sortItems(items, config);

  // 排除项不消耗编号；手动名称在操作链之后覆盖，仍接受同等校验。
  final configError = validateBatchRenameConfig(config);
  final results = <BatchRenameResult>[];
  var sequence = 0;
  final folderSequences = <String, int>{};
  for (final item in sorted) {
    final included = !excludedKeys.contains(item.key);
    var newBase = item.name;
    String? error;
    if (included) {
      final folderIndex = folderSequences[item.folder] ?? 0;
      try {
        if (configError != null) throw FormatException(configError);
        newBase = overrides[item.key] ??
            _applyOps(item, sequence, folderIndex, config);
        if (newBase != item.name)
          error = _validateName(newBase, item.isFolder, bridge);
      } on FormatException catch (e) {
        error = e.message;
      }
      sequence++;
      folderSequences[item.folder] = folderIndex + 1;
    }
    results.add(BatchRenameResult(
        item: item,
        baseName: newBase,
        oldDisplay: item.displayName,
        newDisplay: _displayName(item, newBase),
        included: included,
        error: error));
  }

  if (config.conflictStrategy == BatchRenameConflictStrategy.numberSuffix) {
    _resolveNameConflicts(results, allFiles, allFolders, bridge);
  }

  // 3. 全量文件夹最终路径解析（父级改名会级联到子级，未改名文件夹同样级联）
  final folderFinalPaths =
      _computeFinalFolderPaths(results, allFolders, bridge);

  for (final r in results) {
    r.targetFolder = folderFinalPaths[r.item.folder] ?? r.item.folder;
  }

  // 4. 冲突检测
  _detectFileConflicts(results, allFiles, selectedFileIds, folderFinalPaths);
  _detectFolderConflicts(results, folderFinalPaths);

  // 5. 生成应用指令（跳过冲突/非法项）
  final folderEntries = _buildFolderEntries(results, folderFinalPaths);
  final fileEntries = results
      .where((r) => !r.item.isFolder && r.isChanged && r.error == null)
      .map(
        (r) => BatchRenameEntry(
          id: r.item.id,
          isFolder: false,
          newBaseName: r.baseName,
        ),
      )
      .toList();

  return BatchRenamePlan(
    results: results,
    configError: configError,
    folderEntries: folderEntries,
    fileEntries: fileEntries,
  );
}

// --------------------------------------------------------------------
// 排序
// --------------------------------------------------------------------

List<BatchRenameItem> _sortItems(
  List<BatchRenameItem> items,
  BatchRenameConfig config,
) {
  int nameCmp(BatchRenameItem a, BatchRenameItem b) {
    var c = compareNatural(a.name, b.name);
    if (c == 0) c = compareNatural(a.folder, b.folder);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  int fieldCmp(BatchRenameItem a, BatchRenameItem b) {
    int c;
    switch (config.sortField) {
      case SortField.name:
        return nameCmp(a, b);
      case SortField.createdAt || SortField.modifiedAt:
        // 文件夹无时间，始终按名称排序（组内单独排序，不会混入）
        final at = config.sortField == SortField.createdAt
            ? a.createdAt
            : a.modifiedAt;
        final bt = config.sortField == SortField.createdAt
            ? b.createdAt
            : b.modifiedAt;
        if (at == null && bt == null) return nameCmp(a, b);
        if (at == null) return 1;
        if (bt == null) return -1;
        c = at.compareTo(bt);
        break;
      case SortField.size:
        c = a.size.compareTo(b.size);
        break;
    }
    // 并列时用名称兜底，保证排序与编号结果稳定
    return c != 0 ? c : nameCmp(a, b);
  }

  final folders = items.where((i) => i.isFolder).toList();
  final files = items.where((i) => !i.isFolder).toList();

  if (config.sortOrder == SortOrder.ascending) {
    folders.sort(nameCmp);
    files.sort(fieldCmp);
  } else {
    folders.sort((a, b) => nameCmp(b, a));
    files.sort((a, b) => fieldCmp(b, a));
  }
  return [...folders, ...files];
}

// --------------------------------------------------------------------
// 操作链
// --------------------------------------------------------------------

String _displayName(BatchRenameItem item, String name) =>
    item.isFolder || item.format.isEmpty ? name : '$name.${item.format}';

String? _validateName(String name, bool folder, ManifestBridge bridge) {
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) return '名称不能包含控制字符';
  if (name != name.trim()) return '名称不能以空白开头或结尾，可添加空白清理规则';
  return folder
      ? bridge.validateFolderName(name)
      : bridge.validateFileName(name);
}

/// 在分配补零字符串和编译正则之前验证上限，避免非法方案拖垮预览。
String? validateBatchRenameConfig(BatchRenameConfig config) {
  if (config.operations.length > 50) return '最多支持 50 条规则';
  for (final op in config.operations) {
    if (!op.enabled) continue;
    switch (op) {
      case BatchNumberOp():
        if (op.digits < 1 || op.digits > 12) return '编号位数应为 1–12';
        if (op.start.abs() > 999999999 || op.step.abs() > 999999999)
          return '编号起始值和步长须在 ±999999999 以内';
      case BatchReplaceOp():
        if (op.find.length > 1000 || op.replace.length > 1000) return '替换规则过长';
        if (op.useRegex && op.find.isNotEmpty) {
          try {
            RegExp(op.find, caseSensitive: op.caseSensitive, unicode: true);
          } on FormatException {
            return '正则表达式无效';
          }
        }
      case BatchDeleteOp():
        if (op.position == BatchRenameDeletePos.atIndex && op.index < 1)
          return '删除位置必须从 1 开始';
      case BatchInsertOp():
        if (op.text.length > 1000) return '插入文本过长';
      case BatchTemplateOp():
        if (op.pattern.contains('{n}') &&
            (op.digits < 1 ||
                op.digits > 12 ||
                op.start.abs() > 999999999 ||
                op.step.abs() > 999999999))
          return '模板编号设置无效：位数 1–12，起始和步长在 ±999999999 以内';
        if (op.pattern.length > 1000) return '模板过长';
        final rest = op.pattern.replaceAll(
            RegExp(r'\{(name|n|folder|ext|created|modified)\}'), '');
        if (rest.contains('{') || rest.contains('}')) return '未知模板变量或未闭合的大括号';
      case BatchCaseOp() || BatchCleanupOp():
        break;
    }
  }
  return null;
}

String _applyOps(
    BatchRenameItem item, int index, int folderIndex, BatchRenameConfig config,
    {String? initialName}) {
  var name = initialName ?? item.name;
  for (final op in config.operations) {
    if (!op.enabled) continue;
    switch (op) {
      case BatchTemplateOp():
        name = op.pattern.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (m) {
          return switch (m[1]) {
            'name' => item.name,
            'folder' => item.folder.split('/').last,
            'ext' => item.format,
            'n' => _formatNumber(
                op.start +
                    (op.restartPerFolder ? folderIndex : index) * op.step,
                op.digits),
            'created' => _date(item.createdAt, '创建时间'),
            'modified' => _date(item.modifiedAt, '修改时间'),
            _ => throw const FormatException('未知模板变量'),
          };
        });
      case BatchNumberOp():
        final number = _formatNumber(
            op.start + (op.restartPerFolder ? folderIndex : index) * op.step,
            op.digits);
        name = op.position == BatchRenameNumberPos.prefix
            ? '$number${op.separator}$name'
            : '$name${op.separator}$number';
      case BatchReplaceOp():
        if (!op.effective) continue;
        name = replaceBatchRenameText(name, op);
      case BatchDeleteOp():
        if (!op.effective) continue;
        final chars = name.characters.toList();
        final start = switch (op.position) {
          BatchRenameDeletePos.start => 0,
          BatchRenameDeletePos.end =>
            (chars.length - op.count).clamp(0, chars.length),
          BatchRenameDeletePos.atIndex => (op.index - 1).clamp(0, chars.length),
        };
        chars.removeRange(start, (start + op.count).clamp(start, chars.length));
        name = chars.join();
      case BatchInsertOp():
        if (!op.effective) continue;
        final chars = name.characters.toList();
        final pos = switch (op.position) {
          BatchRenameInsertPos.start => 0,
          BatchRenameInsertPos.end => chars.length,
          BatchRenameInsertPos.atIndex => (op.index - 1).clamp(0, chars.length),
        };
        chars.insert(pos, op.text);
        name = chars.join();
      case BatchCaseOp():
        name = switch (op.mode) {
          BatchRenameCaseMode.upper => name.toUpperCase(),
          BatchRenameCaseMode.lower => name.toLowerCase(),
          BatchRenameCaseMode.firstUpper => name.isEmpty
              ? name
              : name.characters.first.toUpperCase() +
                  name.characters.skip(1).toString(),
          BatchRenameCaseMode.title => name.toLowerCase().replaceAllMapped(
              RegExp(r'(^|[\s_\-])([^\s_\-])', unicode: true),
              (m) => '${m[1]}${m[2]!.toUpperCase()}'),
        };
      case BatchCleanupOp():
        if (op.collapseWhitespace) name = name.replaceAll(RegExp(r'\s+'), ' ');
        if (op.trim) name = name.trim();
    }
    if (name.length > 4096) throw const FormatException('中间名称过长，请调整规则');
  }
  return name;
}

String _date(DateTime? value, String label) {
  if (value == null) throw FormatException('该项目没有$label，请调整模板');
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _formatNumber(int value, int digits) {
  final negative = value < 0;
  final abs = value.abs().toString();
  final width = negative ? digits - 1 : digits;
  final padded = width > abs.length ? abs.padLeft(width, '0') : abs;
  return negative ? '-$padded' : padded;
}

/// 为撞名的项目加后缀。目录按原父级分组：父级只移动，不会合并。
void _resolveNameConflicts(
    List<BatchRenameResult> results,
    List<BatchRenameItem> allFiles,
    Set<String> allFolders,
    ManifestBridge bridge) {
  final changing =
      results.where((r) => r.isChanged && r.error == null).toList();
  final keys = changing.map((r) => r.item.key).toSet();
  final occupied = <String>{};
  String key(bool folder, String parent, String name) =>
      '${folder ? 'd' : 'f'}\u0001$parent\u0001$name';
  for (final f in allFiles) {
    if (!keys.contains(f.key)) occupied.add(key(false, f.folder, f.name));
  }
  for (final f in allFolders) {
    if (!keys.contains('folder:$f'))
      occupied.add(key(
          true, bridge.getParentFolderPath(f), bridge.getFolderBaseName(f)));
  }
  for (final r in results.where((r) => !keys.contains(r.item.key))) {
    occupied.add(key(r.item.isFolder, r.item.folder, r.item.name));
  }
  // 优先保留本来无冲突的目标，避免新增后缀挤占另一个项目的目标。
  final reserved = changing
      .map((r) => key(r.item.isFolder, r.item.folder, r.baseName))
      .toSet();
  for (final r in changing) {
    final base = r.baseName;
    var n = 2;
    if (occupied.contains(key(r.item.isFolder, r.item.folder, r.baseName))) {
      do {
        r.baseName = '$base (${n++})';
      } while (occupied
              .contains(key(r.item.isFolder, r.item.folder, r.baseName)) ||
          reserved.contains(key(r.item.isFolder, r.item.folder, r.baseName)));
      r.newDisplay = _displayName(r.item, r.baseName);
      r.error = _validateName(r.baseName, r.item.isFolder, bridge);
    }
    occupied.add(key(r.item.isFolder, r.item.folder, r.baseName));
  }
}

// --------------------------------------------------------------------
// 冲突检测
// --------------------------------------------------------------------

String _fileKey(String folder, String baseName) => '$folder\u0001$baseName';

/// 计算全部文件夹的最终路径（键为原路径）。
/// 改名的文件夹用新基础名；未改名的文件夹若祖先被改名则随级联移动。
/// 浅 → 深，保证祖先先解析。选中的改名文件夹可能不在 [allFolders]
/// 中（调用方未传全量集合），因此以「allFolders ∪ 改名文件夹」为准。
Map<String, String> _computeFinalFolderPaths(
  List<BatchRenameResult> results,
  Set<String> allFolders,
  ManifestBridge bridge,
) {
  final newBaseByOriginal = <String, String>{
    for (final r in results)
      if (r.item.isFolder && r.isChanged) r.item.id: r.baseName,
  };
  final all = <String>{...allFolders, ...newBaseByOriginal.keys};
  final sorted = all.toList()
    ..sort((a, b) => a.split('/').length.compareTo(b.split('/').length));

  final finalPath = <String, String>{};
  for (final f in sorted) {
    final parent = bridge.getParentFolderPath(f);
    final base = bridge.getFolderBaseName(f);
    final newParent = parent.isEmpty ? '' : (finalPath[parent] ?? parent);
    final base2 = newBaseByOriginal[f] ?? base;
    finalPath[f] = newParent.isEmpty ? base2 : '$newParent/$base2';
  }
  return finalPath;
}

/// 文件冲突：同一文件夹内基础名唯一（沿用单文件重命名的约定）。
/// 采用「最终状态」语义：被改名项让出的原名可被其他选中项占用；
/// 文件所在文件夹若被级联改名，则按最终文件夹参与检测。
void _detectFileConflicts(
  List<BatchRenameResult> results,
  List<BatchRenameItem> allFiles,
  Set<String> selectedFileIds,
  Map<String, String> folderFinalPaths,
) {
  final counts = <String, int>{};
  void countKey(String key) => counts[key] = (counts[key] ?? 0) + 1;
  String resolvedFolder(String folder) => folderFinalPaths[folder] ?? folder;

  // 未选中文件按最终文件夹保留原有键
  for (final f in allFiles) {
    if (!selectedFileIds.contains(f.id)) {
      countKey(_fileKey(resolvedFolder(f.folder), f.name));
    }
  }
  // 选中项的新键（未变化项即原键）
  for (final r in results) {
    if (!r.item.isFolder) {
      countKey(_fileKey(resolvedFolder(r.item.folder), r.baseName));
    }
  }
  // 只标记发生改名的项：未变化项不承担冲突提示（其名称保持有效）
  for (final r in results) {
    if (r.item.isFolder || !r.isChanged || r.error != null) continue;
    if ((counts[_fileKey(resolvedFolder(r.item.folder), r.baseName)] ?? 0) >
        1) {
      r.error = '同一文件夹内存在同名文件';
    }
  }
}

/// 文件夹冲突：改名项的最终路径不得与「不参与改名的文件夹」最终位置
/// 重复/包含；批内改名项之间不得撞名。改名项自身子树内的级联移动
/// 不算冲突（如 a→x 时 a/b 随迁到 x/b）。
void _detectFolderConflicts(
  List<BatchRenameResult> results,
  Map<String, String> folderFinalPaths,
) {
  final changed = results.where((r) => r.item.isFolder && r.isChanged).toList();
  final changedOriginals = changed.map((r) => r.item.id).toSet();

  // 不参与改名的文件夹（未选中 + 选中但未改名），按最终位置参与检测
  final unchanged = <(String, String)>[
    for (final e in folderFinalPaths.entries)
      if (!changedOriginals.contains(e.key)) (e.key, e.value),
  ];

  bool insideSubtree(String child, String parent) =>
      child == parent || child.startsWith('$parent/');

  for (final r in changed) {
    if (r.error != null) continue;
    final o = r.item.id;
    final fp = folderFinalPaths[o]!;
    // 与不参与改名的文件夹冲突（排除自身子树内的级联目标）
    final collidesExisting = unchanged.any((u) {
      if (insideSubtree(u.$1, o)) return false;
      return u.$2 == fp || u.$2.startsWith('$fp/');
    });
    // 与批内其他改名项冲突（排除自身子树内的级联目标）
    final collidesBatch = changed.any((q) {
      if (identical(q, r)) return false;
      if (insideSubtree(q.item.id, o)) return false;
      final fpq = folderFinalPaths[q.item.id]!;
      return fpq == fp || fpq.startsWith('$fp/');
    });
    if (collidesExisting || collidesBatch) {
      r.error = '目标位置已存在同名文件夹';
    }
  }
}

/// 生成文件夹改名指令，顺序保证：
/// - 子文件夹先于父文件夹（父级改名后子级路径会移位）；
/// - 名称让位（A 的新名 == B 的原名）时先执行让位方。
/// 出现死循环互换时剩余项标记为冲突。
List<BatchRenameEntry> _buildFolderEntries(
  List<BatchRenameResult> results,
  Map<String, String> folderFinalPaths,
) {
  final pending = results
      .where((r) => r.item.isFolder && r.isChanged && r.error == null)
      .toList();
  // 深者优先（稳定排序保证同级保持预览顺序）
  int depth(BatchRenameResult r) => r.item.id.split('/').length;
  pending.sort((a, b) => depth(b).compareTo(depth(a)));

  final unprocessed = pending.map((r) => r.item.id).toSet();
  final entries = <BatchRenameEntry>[];
  while (pending.isNotEmpty) {
    var picked = -1;
    for (var i = 0; i < pending.length; i++) {
      final r = pending[i];
      final localTarget =
          r.item.folder.isEmpty ? r.baseName : '${r.item.folder}/${r.baseName}';
      final hasPendingChild =
          unprocessed.any((path) => path.startsWith('${r.item.id}/'));
      if (!hasPendingChild && !unprocessed.contains(localTarget)) {
        picked = i;
        break;
      }
    }
    if (picked == -1) {
      // 死循环互换：剩余项全部标记为冲突
      for (final r in pending) {
        r.error ??= '文件夹之间存在名称互换，无法应用';
      }
      break;
    }
    final r = pending.removeAt(picked);
    unprocessed.remove(r.item.id);
    entries.add(
      BatchRenameEntry(id: r.item.id, isFolder: true, newBaseName: r.baseName),
    );
  }
  return entries;
}
