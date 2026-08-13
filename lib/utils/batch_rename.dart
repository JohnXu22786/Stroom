import 'manifest_bridge.dart';
import 'natural_sort.dart';
import 'sort_config.dart';

// ====================================================================
// 批量重命名 — 纯逻辑（无 UI 依赖，可单测）
//
// 设计对标「拖把更名器 XTools」：先对选中项排序，再按固定操作链
// （编号 → 替换 → 插入 → 删除字符 → 大小写）逐项计算新名称，
// 并做冲突检测与名称校验，最后给出可直接应用的 [BatchRenamePlan]。
// ====================================================================

/// 编号位置
enum BatchRenameNumberPos { prefix, suffix }

/// 插入位置
enum BatchRenameInsertPos { start, end, atIndex }

/// 删除字符位置
enum BatchRenameDeletePos { start, end }

/// 大小写模式
enum BatchRenameCaseMode { upper, lower, firstUpper }

// --------------------------------------------------------------------
// 操作配置
// --------------------------------------------------------------------

/// 编号操作：为排序后的每一项追加/前置序号
class BatchNumberOp {
  final bool enabled;
  final BatchRenameNumberPos position;
  final int start;
  final int step;
  final int digits;
  final String separator;

  const BatchNumberOp({
    this.enabled = false,
    this.position = BatchRenameNumberPos.prefix,
    this.start = 1,
    this.step = 1,
    this.digits = 1,
    this.separator = '_',
  });

  bool get effective => enabled;

  BatchNumberOp copyWith({
    bool? enabled,
    BatchRenameNumberPos? position,
    int? start,
    int? step,
    int? digits,
    String? separator,
  }) =>
      BatchNumberOp(
        enabled: enabled ?? this.enabled,
        position: position ?? this.position,
        start: start ?? this.start,
        step: step ?? this.step,
        digits: digits ?? this.digits,
        separator: separator ?? this.separator,
      );
}

/// 替换操作：查找并替换文本
class BatchReplaceOp {
  final bool enabled;
  final String find;
  final String replace;
  final bool caseSensitive;

  const BatchReplaceOp({
    this.enabled = false,
    this.find = '',
    this.replace = '',
    this.caseSensitive = false,
  });

  /// 查找内容为空时替换无意义
  bool get effective => enabled && find.isNotEmpty;

  BatchReplaceOp copyWith({
    bool? enabled,
    String? find,
    String? replace,
    bool? caseSensitive,
  }) =>
      BatchReplaceOp(
        enabled: enabled ?? this.enabled,
        find: find ?? this.find,
        replace: replace ?? this.replace,
        caseSensitive: caseSensitive ?? this.caseSensitive,
      );
}

/// 插入操作：在开头/结尾/指定位置插入文本
class BatchInsertOp {
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
class BatchDeleteOp {
  final bool enabled;
  final BatchRenameDeletePos position;
  final int count;

  const BatchDeleteOp({
    this.enabled = false,
    this.position = BatchRenameDeletePos.start,
    this.count = 1,
  });

  /// 数量为 0 时删除无意义
  bool get effective => enabled && count > 0;

  BatchDeleteOp copyWith({
    bool? enabled,
    BatchRenameDeletePos? position,
    int? count,
  }) =>
      BatchDeleteOp(
        enabled: enabled ?? this.enabled,
        position: position ?? this.position,
        count: count ?? this.count,
      );
}

/// 大小写转换操作
class BatchCaseOp {
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

/// 批量重命名完整配置（含编号排序方式）
class BatchRenameConfig {
  final SortField sortField;
  final SortOrder sortOrder;
  final BatchNumberOp numbering;
  final BatchReplaceOp replace;
  final BatchInsertOp insert;
  final BatchDeleteOp delete;
  final BatchCaseOp caseOp;

  const BatchRenameConfig({
    this.sortField = SortField.name,
    this.sortOrder = SortOrder.ascending,
    this.numbering = const BatchNumberOp(),
    this.replace = const BatchReplaceOp(),
    this.insert = const BatchInsertOp(),
    this.delete = const BatchDeleteOp(),
    this.caseOp = const BatchCaseOp(),
  });

  /// 是否存在能真正生效的操作（空查找/空插入等视为无效）
  bool get hasActiveOps =>
      numbering.effective ||
      replace.effective ||
      insert.effective ||
      delete.effective ||
      caseOp.effective;

  BatchRenameConfig copyWith({
    SortField? sortField,
    SortOrder? sortOrder,
    BatchNumberOp? numbering,
    BatchReplaceOp? replace,
    BatchInsertOp? insert,
    BatchDeleteOp? delete,
    BatchCaseOp? caseOp,
  }) =>
      BatchRenameConfig(
        sortField: sortField ?? this.sortField,
        sortOrder: sortOrder ?? this.sortOrder,
        numbering: numbering ?? this.numbering,
        replace: replace ?? this.replace,
        insert: insert ?? this.insert,
        delete: delete ?? this.delete,
        caseOp: caseOp ?? this.caseOp,
      );
}

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

  /// 显示名：文件带扩展名，文件夹仅末级名
  String get displayName => isFolder || format.isEmpty ? name : '$name.$format';
}

/// 单条预览结果
class BatchRenameResult {
  final BatchRenameItem item;

  /// 应用操作链后的基础名（与 [BatchRenameItem.name] 相同表示未变化）
  final String baseName;
  final String oldDisplay;
  final String newDisplay;

  /// 冲突/非法名称原因；null 表示该项可应用
  String? error;

  BatchRenameResult({
    required this.item,
    required this.baseName,
    required this.oldDisplay,
    required this.newDisplay,
    this.error,
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

  /// 文件夹改名指令，已按安全顺序排列（子文件夹先于父文件夹；
  /// 名称让位/互换时按腾位顺序执行）
  final List<BatchRenameEntry> folderEntries;

  /// 文件改名指令（按预览排序顺序）
  final List<BatchRenameEntry> fileEntries;

  BatchRenamePlan({
    required this.results,
    required this.folderEntries,
    required this.fileEntries,
  });

  int get changeCount => results.where((r) => r.isChanged).length;
  int get conflictCount => results.where((r) => r.error != null).length;

  /// 无冲突且确实存在改名项时才可应用
  bool get canApply => changeCount > 0 && results.every((r) => r.error == null);
}

// --------------------------------------------------------------------
// 计划计算
// --------------------------------------------------------------------

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
}) {
  final selectedFileIds =
      items.where((i) => !i.isFolder).map((i) => i.id).toSet();

  // 1. 排序（文件夹组在前，文件组在后；编号按此顺序分配）
  final sorted = _sortItems(items, config);

  // 2. 逐项应用操作链
  final results = <BatchRenameResult>[];
  for (var i = 0; i < sorted.length; i++) {
    final item = sorted[i];
    final newBase = _applyOps(item, i, config);
    final changed = newBase != item.name;
    String? error;
    if (changed) {
      error = item.isFolder
          ? bridge.validateFolderName(newBase)
          : bridge.validateFileName(newBase);
    }
    results.add(
      BatchRenameResult(
        item: item,
        baseName: newBase,
        oldDisplay: item.displayName,
        newDisplay: item.isFolder || item.format.isEmpty
            ? newBase
            : '$newBase.${item.format}',
        error: error,
      ),
    );
  }

  // 3. 全量文件夹最终路径解析（父级改名会级联到子级，未改名文件夹同样级联）
  final folderFinalPaths =
      _computeFinalFolderPaths(results, allFolders, bridge);

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
  int nameCmp(BatchRenameItem a, BatchRenameItem b) =>
      compareNatural(a.name, b.name);

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
        if (at == null || bt == null) return nameCmp(a, b);
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

/// 固定顺序：编号 → 替换 → 插入 → 删除字符 → 大小写
String _applyOps(BatchRenameItem item, int index, BatchRenameConfig config) {
  var name = item.name;

  final n = config.numbering;
  if (n.effective) {
    final numStr = _formatNumber(n.start + index * n.step, n.digits);
    name = n.position == BatchRenameNumberPos.prefix
        ? '$numStr${n.separator}$name'
        : '$name${n.separator}$numStr';
  }

  final r = config.replace;
  if (r.effective) {
    name = r.caseSensitive
        ? name.replaceAll(r.find, r.replace)
        : _replaceAllIgnoreCase(name, r.find, r.replace);
  }

  final ins = config.insert;
  if (ins.effective) {
    name = switch (ins.position) {
      BatchRenameInsertPos.start => '${ins.text}$name',
      BatchRenameInsertPos.end => '$name${ins.text}',
      BatchRenameInsertPos.atIndex => _insertAtIndex(name, ins.text, ins.index),
    };
  }

  final del = config.delete;
  if (del.effective) {
    final runes = name.runes.toList();
    name = del.position == BatchRenameDeletePos.start
        ? (runes.length <= del.count
            ? ''
            : String.fromCharCodes(runes.skip(del.count)))
        : (runes.length <= del.count
            ? ''
            : String.fromCharCodes(runes.take(runes.length - del.count)));
  }

  final c = config.caseOp;
  if (c.effective) {
    name = switch (c.mode) {
      BatchRenameCaseMode.upper => name.toUpperCase(),
      BatchRenameCaseMode.lower => name.toLowerCase(),
      BatchRenameCaseMode.firstUpper =>
        name.isEmpty ? name : name[0].toUpperCase() + name.substring(1),
    };
  }
  return name;
}

/// 序号格式化：起始值 10 + 步长 5 + 位数 3 → 010 / 015 / 020
String _formatNumber(int value, int digits) {
  final negative = value < 0;
  final abs = value.abs().toString();
  final width = negative ? digits - 1 : digits;
  final padded = width > abs.length ? abs.padLeft(width, '0') : abs;
  return negative ? '-$padded' : padded;
}

/// 忽略大小写替换所有出现。
/// Dart 的 [String.toLowerCase] 使用 Unicode 简单小写映射（1:1），
/// 不会改变字符串长度，因此小写化后的索引与原文一一对应。
String _replaceAllIgnoreCase(String input, String find, String replace) {
  if (find.isEmpty || input.isEmpty) return input;
  final lowerInput = input.toLowerCase();
  final lowerFind = find.toLowerCase();
  final sb = StringBuffer();
  var i = 0;
  while (i <= input.length) {
    final idx = lowerInput.indexOf(lowerFind, i);
    if (idx < 0) {
      sb.write(input.substring(i));
      break;
    }
    sb.write(input.substring(i, idx));
    sb.write(replace);
    i = idx + find.length;
  }
  return sb.toString();
}

/// 在 1 基位置插入文本（按字符计数，越界收拢到边界）
String _insertAtIndex(String name, String text, int index) {
  final runes = name.runes.toList();
  final raw = index - 1;
  final pos = raw < 0 ? 0 : (raw > runes.length ? runes.length : raw);
  return String.fromCharCodes(runes.take(pos)) +
      text +
      String.fromCharCodes(runes.skip(pos));
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
      if (!unprocessed.contains(folderFinalPaths[pending[i].item.id])) {
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
