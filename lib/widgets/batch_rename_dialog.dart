import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/batch_rename_presets.dart';
import 'batch_rename_rule_editor.dart';

import '../utils/batch_rename.dart';
import '../utils/batch_rename_regex.dart';
import '../utils/file_record.dart';
import '../utils/manifest_bridge.dart';
import '../utils/sort_config.dart';

/// 弹出批量重命名面板（对标「拖把更名器 XTools」）。
/// 返回用户确认后的 [BatchRenamePlan]；取消或关闭返回 null。
Future<BatchRenamePlan?> showBatchRenameDialog<T extends FileRecord>({
  required BuildContext context,
  required List<T> selectedFiles,
  required List<String> selectedFolders,
  required List<T> allRecords,
  required Set<String> allFolders,
  required ManifestBridge bridge,
  required SortConfig initialSort,
}) {
  final items = <BatchRenameItem>[
    for (final f in selectedFolders)
      BatchRenameItem(
        id: f,
        isFolder: true,
        name: bridge.getFolderBaseName(f),
        folder: bridge.getParentFolderPath(f),
      ),
    for (final r in selectedFiles)
      BatchRenameItem(
        id: r.id,
        isFolder: false,
        name: r.name,
        format: r.format,
        folder: r.folder,
        createdAt: r.createdAt,
        modifiedAt: r.modifiedAt,
        size: r.size,
      ),
  ];
  final allFileItems = allRecords
      .map(
        (r) => BatchRenameItem(
          id: r.id,
          isFolder: false,
          name: r.name,
          format: r.format,
          folder: r.folder,
          createdAt: r.createdAt,
          modifiedAt: r.modifiedAt,
          size: r.size,
        ),
      )
      .toList();

  return showDialog<BatchRenamePlan>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => BatchRenameDialog(
      items: items,
      allFolders: allFolders,
      allFiles: allFileItems,
      bridge: bridge,
      initialConfig: BatchRenameConfig(
        sortField: initialSort.field,
        sortOrder: initialSort.order,
      ),
    ),
  );
}

/// Rules and preview share one plan; filtering never changes numbering.
class BatchRenameDialog extends StatefulWidget {
  final List<BatchRenameItem> items;
  final Set<String> allFolders;
  final List<BatchRenameItem> allFiles;
  final ManifestBridge bridge;
  final BatchRenameConfig initialConfig;
  const BatchRenameDialog(
      {super.key,
      required this.items,
      required this.allFolders,
      required this.allFiles,
      required this.bridge,
      required this.initialConfig});
  @override
  State<BatchRenameDialog> createState() => _BatchRenameDialogState();
}

class _RuleSlot {
  final int id;
  BatchRenameOp op;
  _RuleSlot(this.id, this.op);
}

enum _PreviewFilter { all, changed, errors, unchanged, excluded }

class _BatchRenameDialogState extends State<BatchRenameDialog> {
  late BatchRenameConfig _config = widget.initialConfig;
  late List<_RuleSlot> _rules;
  late BatchRenamePlan _plan;
  final _excluded = <String>{};
  final _overrides = <String, String>{};
  final _invalid = <int>{};
  final _store = BatchRenamePresets();
  Map<String, BatchRenameConfig> _presets = {};
  _PreviewFilter _filter = _PreviewFilter.all;
  String _search = '';
  final _searchController = TextEditingController();
  final _rulesPaneKey = GlobalKey();
  final _previewPaneKey = GlobalKey();
  String? _notice;
  bool _saving = false;
  bool _previewTab = false;
  int _nextId = 0;
  int _previewGeneration = 0;
  BatchRenameRegexWorker? _regexWorker;
  bool _previewing = false;
  String? _previewError;
  Map<String, int> _previewIndices = {};

  static const _builtins = <String, BatchRenameConfig>{
    '照片：日期与编号': BatchRenameConfig(rules: [
      BatchTemplateOp(enabled: true, pattern: '{created}_{n}'),
    ]),
    '课程：统一名称与编号': BatchRenameConfig(rules: [
      BatchTemplateOp(enabled: true, pattern: '课程_{n}', restartPerFolder: true),
    ]),
    '下载文件：清理空白': BatchRenameConfig(rules: [
      BatchCleanupOp(enabled: true, collapseWhitespace: true),
    ]),
  };

  @override
  void initState() {
    super.initState();
    _rules = [for (final op in _config.operations) _RuleSlot(_nextId++, op)];
    _recompute();
    unawaited(_loadPresets());
  }

  @override
  void dispose() {
    _previewGeneration++;
    _regexWorker?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await _store.load();
      if (mounted) setState(() => _presets = presets);
    } catch (_) {
      if (mounted) setState(() => _notice = '暂时无法读取方案，仍可编辑和执行规则');
    }
  }

  void _recompute() {
    _config = _config.copyWith(rules: [for (final slot in _rules) slot.op]);
    final generation = ++_previewGeneration;
    _regexWorker?.dispose();
    _regexWorker = null;
    _previewError = null;
    _previewing = validateBatchRenameConfig(_config) == null &&
        _config.operations
            .any((op) => op is BatchReplaceOp && op.effective && op.useRegex);
    _setPlan(computeBatchRenamePlan(
        items: widget.items,
        config: _previewing ? _config.copyWith(rules: []) : _config,
        bridge: widget.bridge,
        allFolders: widget.allFolders,
        allFiles: widget.allFiles,
        excludedKeys: _excluded,
        overrides: _overrides));
    if (_previewing) {
      final worker = _regexWorker = BatchRenameRegexWorker();
      unawaited(_computePreview(generation, worker));
    }
  }

  Future<void> _computePreview(
      int generation, BatchRenameRegexWorker worker) async {
    try {
      final plan = await computeBatchRenamePlanAsync(
          items: widget.items,
          config: _config,
          bridge: widget.bridge,
          allFolders: widget.allFolders,
          allFiles: widget.allFiles,
          excludedKeys: Set.of(_excluded),
          overrides: Map.of(_overrides),
          regexWorker: worker);
      if (mounted && generation == _previewGeneration) {
        setState(() {
          _setPlan(plan);
          _previewing = false;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _previewGeneration &&
          e is! BatchRenameRegexCancelled) {
        setState(() {
          _previewing = false;
          _previewError = e is TimeoutException
              ? e.message
              : e is StateError
                  ? '${e.message}'
                  : '预览计算失败，请调整规则后重试';
        });
      }
    } finally {
      worker.dispose();
    }
  }

  void _setPlan(BatchRenamePlan plan) {
    _plan = plan;
    _previewIndices = {
      for (var i = 0; i < _plan.results.length; i++)
        _plan.results[i].item.key: i
    };
  }

  void _change(VoidCallback update) => setState(() {
        update();
        _recompute();
      });

  void _useConfig(BatchRenameConfig config, {bool resetSelection = false}) =>
      _change(() {
        _config = config;
        _rules = [for (final op in config.operations) _RuleSlot(_nextId++, op)];
        _invalid.clear();
        _overrides.clear();
        if (resetSelection) _excluded.clear();
      });

  Future<void> _savePreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('保存重命名方案'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 60,
                  decoration: const InputDecoration(
                      labelText: '方案名称', helperText: '保存规则及顺序，不包含排除项或手动名称')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty)
                        Navigator.pop(ctx, controller.text.trim());
                    },
                    child: const Text('保存'))
              ],
            ));
    // Route animations may still hold the controller until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null || !mounted) return;
    if (_presets.containsKey(name)) {
      final replace = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('覆盖已有方案？'),
                  content: Text('将更新“$name”的规则。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('覆盖'))
                  ]));
      if (replace != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await _store.save(name, _config);
      await _loadPresets();
      if (mounted) setState(() => _notice = '已保存方案：$name');
    } catch (e) {
      if (mounted) setState(() => _notice = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _managePresets() async {
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                    title: const Text('管理方案'),
                    content: SizedBox(
                        width: 360,
                        child: ListView(shrinkWrap: true, children: [
                          if (_presets.isEmpty) const Text('尚未保存方案'),
                          for (final name in _presets.keys)
                            ListTile(
                                title: Text(name),
                                trailing: IconButton(
                                    tooltip: '删除方案',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      try {
                                        await _store.delete(name);
                                        if (!mounted || !ctx.mounted) return;
                                        setState(() => _presets.remove(name));
                                        update(() {});
                                      } catch (e) {
                                        if (mounted)
                                          setState(() => _notice = '删除失败：$e');
                                      }
                                    })),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('完成'))
                    ])));
  }

  Future<void> _editName(BatchRenameResult r) async {
    final controller = TextEditingController(text: r.baseName);
    final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('单独修改名称'),
                content: TextField(
                    key: const Key('batch_manual_name'),
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: '基础名称',
                        helperText: r.item.format.isEmpty
                            ? '此名称覆盖规则结果'
                            : '扩展名 .${r.item.format} 自动保留',
                        helperMaxLines: 2),
                    onSubmitted: (v) => Navigator.pop(ctx, v)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      key: const Key('batch_manual_save'),
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('确定'))
                ]));
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name != null && mounted) _change(() => _overrides[r.item.key] = name);
  }

  Widget _header() => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text('批量重命名（${widget.items.length} 项）',
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              tooltip: '使用说明',
              onPressed: _help,
              icon: const Icon(Icons.help_outline)),
          IconButton(
              key: const Key('batch_rename_close_btn'),
              tooltip: '关闭',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))
        ]),
        if (MediaQuery.viewInsetsOf(context).bottom == 0)
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PopupMenuButton<BatchRenameConfig>(
                    tooltip: '加载方案（替换规则并清除手动名称）',
                    onSelected: _useConfig,
                    itemBuilder: (_) => [
                          for (final e in _builtins.entries)
                            PopupMenuItem(value: e.value, child: Text(e.key)),
                          if (_presets.isNotEmpty) const PopupMenuDivider(),
                          for (final e in _presets.entries)
                            PopupMenuItem(value: e.value, child: Text(e.key)),
                        ],
                    child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('加载方案'),
                          Icon(Icons.arrow_drop_down, size: 18),
                        ]))),
                TextButton(
                    onPressed: _saving ||
                            _invalid.isNotEmpty ||
                            _plan.configError != null
                        ? null
                        : _savePreset,
                    child: Text(_saving ? '保存中…' : '保存方案')),
                IconButton(
                    onPressed: _managePresets,
                    tooltip: '管理方案',
                    icon: const Icon(Icons.tune)),
                IconButton(
                    key: const Key('batch_reset'),
                    tooltip: '重置全部规则与参与项目',
                    onPressed: () => _useConfig(
                        BatchRenameConfig(
                            sortField: widget.initialConfig.sortField,
                            sortOrder: widget.initialConfig.sortOrder),
                        resetSelection: true),
                    icon: const Icon(Icons.restart_alt)),
              ]),
        if (_notice != null)
          Text(_notice!, style: Theme.of(context).textTheme.bodySmall),
      ]));

  Widget _rulesPane() =>
      KeyedSubtree(key: _rulesPaneKey, child: _rulesContent());
  Widget _rulesContent() {
    final seen = <Type>{};
    return SingleChildScrollView(
        key: const Key('batch_rules_scroll'),
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('规则从上到下依次执行；可复制、移动或关闭。扩展名保持不变。',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final field in SortField.values)
              ChoiceChip(
                  label: Text(switch (field) {
                    SortField.name => '名称',
                    SortField.createdAt => '创建时间',
                    SortField.modifiedAt => '修改时间',
                    SortField.size => '大小'
                  }),
                  selected: _config.sortField == field,
                  onSelected: (_) => _change(
                      () => _config = _config.copyWith(sortField: field)))
          ]),
          Wrap(spacing: 6, children: [
            for (final order in SortOrder.values)
              ChoiceChip(
                  label: Text(order == SortOrder.ascending ? '升序' : '降序'),
                  selected: _config.sortOrder == order,
                  onSelected: (_) => _change(
                      () => _config = _config.copyWith(sortOrder: order)))
          ]),
          const Text('文件夹在前；同名按所在目录排序。', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          for (var i = 0; i < _rules.length; i++)
            _rule(_rules[i], i, seen.add(_rules[i].op.runtimeType)),
          PopupMenuButton<BatchRenameOp>(
              enabled: _rules.length < 50,
              onSelected: (op) => _change(
                  () => _rules.add(_RuleSlot(_nextId++, op.withEnabled(true)))),
              itemBuilder: (_) => [
                    for (final op in const BatchRenameConfig().operations)
                      PopupMenuItem(value: op, child: Text(op.label))
                  ],
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_rules.length < 50 ? '＋ 添加规则' : '最多 50 条规则'))),
        ]));
  }

  Widget _rule(_RuleSlot slot, int index, bool primary) =>
      BatchRenameRuleEditor(
        key: ValueKey(slot.id),
        slotId: slot.id,
        rule: slot.op,
        primary: primary,
        onChanged: (op) => _change(() => slot.op = op),
        onValidityChanged: (valid) {
          if (!mounted || !_rules.contains(slot)) return;
          setState(() {
            if (valid) {
              _invalid.remove(slot.id);
            } else {
              _invalid.add(slot.id);
            }
          });
        },
        onUp: index == 0
            ? null
            : () => _change(() {
                  _rules.removeAt(index);
                  _rules.insert(index - 1, slot);
                }),
        onDown: index == _rules.length - 1
            ? null
            : () => _change(() {
                  _rules.removeAt(index);
                  _rules.insert(index + 1, slot);
                }),
        onDuplicate: () {
          if (_rules.length < 50)
            _change(
                () => _rules.insert(index + 1, _RuleSlot(_nextId++, slot.op)));
        },
        onRemove: () => _change(() {
          _rules.remove(slot);
          _invalid.remove(slot.id);
        }),
      );

  List<BatchRenameResult> get _visible => _plan.results.where((r) {
        final matches = '${r.oldDisplay}\n${r.newDisplay}\n${r.item.folder}'
            .toLowerCase()
            .contains(_search.toLowerCase());
        return matches &&
            switch (_filter) {
              _PreviewFilter.all => true,
              _PreviewFilter.changed => r.isChanged,
              _PreviewFilter.errors => r.error != null,
              _PreviewFilter.unchanged =>
                r.included && !r.isChanged && r.error == null,
              _PreviewFilter.excluded => !r.included,
            };
      }).toList();

  Widget _previewPane() =>
      KeyedSubtree(key: _previewPaneKey, child: _previewContent());
  Widget _previewContent() {
    final visible = _visible;
    final colors = Theme.of(context).colorScheme;
    final controls = <Widget>[
      Text(
          '预览 · ${_plan.changeCount} 项更改 · ${_plan.conflictCount} 项问题 · ${_excluded.length} 项排除',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_previewing) ...[
        const LinearProgressIndicator(key: Key('batch_preview_busy')),
        const Text('正在计算预览，可继续修改规则或取消…'),
      ],
      if (_previewError != null)
        Text(_previewError!, style: TextStyle(color: colors.error)),
      TextField(
          key: const Key('batch_preview_search'),
          controller: _searchController,
          decoration: const InputDecoration(
              hintText: '搜索原名、新名或所在目录',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _search = v)),
      Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<_PreviewFilter>(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v!),
                items: [
                  for (final f in _PreviewFilter.values)
                    DropdownMenuItem(
                        value: f,
                        child: Text(switch (f) {
                          _PreviewFilter.all => '全部',
                          _PreviewFilter.changed => '有更改',
                          _PreviewFilter.errors => '有问题',
                          _PreviewFilter.unchanged => '未变化',
                          _PreviewFilter.excluded => '已排除'
                        }))
                ]),
            PopupMenuButton<String>(
                tooltip: '选择参与项目',
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'all', child: Text('全部参与')),
                      PopupMenuItem(value: 'files', child: Text('仅文件')),
                      PopupMenuItem(value: 'folders', child: Text('仅文件夹')),
                      PopupMenuItem(value: 'none', child: Text('全部排除')),
                    ],
                onSelected: (v) => _change(() {
                      _excluded.clear();
                      for (final item in widget.items) {
                        if (v == 'none' ||
                            (v == 'files' && item.isFolder) ||
                            (v == 'folders' && !item.isFolder))
                          _excluded.add(item.key);
                      }
                    }),
                child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('参与范围'),
                      Icon(Icons.arrow_drop_down, size: 18)
                    ]))),
            TextButton(
                onPressed:
                    _previewing || _previewError != null ? null : _copyPreview,
                child: const Text('复制清单')),
          ]),
      DropdownButton<BatchRenameConflictStrategy>(
          isExpanded: true,
          value: _config.conflictStrategy,
          items: const [
            DropdownMenuItem(
                value: BatchRenameConflictStrategy.block,
                child: Text('同名冲突：阻止执行')),
            DropdownMenuItem(
                value: BatchRenameConflictStrategy.numberSuffix,
                child: Text('同名冲突：追加 (2)、(3)…'))
          ],
          onChanged: (v) =>
              _change(() => _config = _config.copyWith(conflictStrategy: v))),
      if (_invalid.isNotEmpty || _plan.configError != null)
        Text(
            _invalid.isNotEmpty
                ? '请修正规则中的输入；当前预览尚未采用无效输入。'
                : _plan.configError!,
            style: TextStyle(color: colors.error)),
      if (_plan.conflictCount > 0)
        Text('存在冲突或非法名称，无法应用。请调整规则。', style: TextStyle(color: colors.error)),
    ];
    return Padding(
        padding: const EdgeInsets.all(12),
        child: CustomScrollView(
            key: const Key('batch_rename_preview_list'),
            slivers: [
              SliverToBoxAdapter(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: controls)),
              if (visible.isEmpty)
                const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('没有符合筛选条件的项目')))
              else
                SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, index) => _previewItem(visible[index])),
            ]));
  }

  Widget _previewItem(BatchRenameResult r) {
    final colors = Theme.of(context).colorScheme;
    return Card(
        key: Key('batch_rename_preview_${_previewIndices[r.item.key]}'),
        margin: const EdgeInsets.only(bottom: 6),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(
                  key: Key('batch_include_${r.item.key}'),
                  value: r.included,
                  onChanged: (v) => _change(() {
                        if (v == true) {
                          _excluded.remove(r.item.key);
                        } else {
                          _excluded.add(r.item.key);
                        }
                      })),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${r.item.isFolder ? '文件夹' : '文件'} · ${r.item.folder.isEmpty ? '根目录' : r.item.folder}',
                        style: Theme.of(context).textTheme.labelSmall),
                    Tooltip(
                        message: r.oldDisplay,
                        child: Text(r.oldDisplay,
                            maxLines: 2, overflow: TextOverflow.ellipsis)),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('→ '),
                          Expanded(
                              child: Tooltip(
                                  message: r.newDisplay,
                                  child: Text(r.newDisplay,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: r.error != null
                                              ? colors.error
                                              : r.isChanged
                                                  ? colors.primary
                                                  : colors.onSurfaceVariant))))
                        ]),
                    if (r.targetFolder != r.item.folder)
                      Text(
                          '目标目录：${r.targetFolder!.isEmpty ? '根目录' : r.targetFolder}',
                          style: Theme.of(context).textTheme.labelSmall),
                    Text(
                        r.error ??
                            (!r.included
                                ? '已排除'
                                : _overrides.containsKey(r.item.key)
                                    ? '手动名称'
                                    : r.isChanged
                                        ? '待重命名'
                                        : '未变化'),
                        style: TextStyle(
                            fontSize: 12,
                            color: r.error != null
                                ? colors.error
                                : colors.onSurfaceVariant)),
                  ])),
              Column(children: [
                IconButton(
                    key: Key('batch_edit_${r.item.key}'),
                    tooltip: '单独修改名称',
                    onPressed: r.included ? () => _editName(r) : null,
                    icon: const Icon(Icons.edit_outlined, size: 18)),
                if (_overrides.containsKey(r.item.key))
                  IconButton(
                      key: Key('batch_clear_override_${r.item.key}'),
                      tooltip: '恢复规则生成的名称',
                      onPressed: () =>
                          _change(() => _overrides.remove(r.item.key)),
                      icon: const Icon(Icons.undo, size: 18))
              ]),
            ])));
  }

  Future<void> _copyPreview() async {
    String cell(String text) => '"${text.replaceAll('"', '""')}"';
    final content = [
      '原路径,原名称,目标路径,状态',
      for (final r in _plan.results)
        [
          r.oldPath,
          r.oldDisplay,
          r.newPath,
          r.error ??
              (!r.included
                  ? '已排除'
                  : r.isChanged
                      ? '待重命名'
                      : '未变化')
        ].map(cell).join(',')
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) setState(() => _notice = '已复制完整预览清单（CSV）');
    } catch (_) {
      if (mounted) setState(() => _notice = '复制失败，请重试');
    }
  }

  void _help() => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
              title: const Text('批量重命名使用说明'),
              content: const SingleChildScrollView(
                  child: Text(
                      '1. 选择方案或启用规则，按需复制规则并调整上下顺序。\n\n2. 预览显示实际执行的名称。搜索与筛选只影响显示；取消勾选会排除该项并重新编号。可单独修改名称，或恢复为规则结果。\n\n3. 所有问题解决后才能执行。自动后缀只处理重名，不会覆盖其他文件。互换文件夹名称需要分批改名。\n\n4. 执行中可停止后续项目；当前项目会先完成。完成页显示结果，可撤销本次已完成的改名。列表发生后续变化时会阻止撤销。\n\n仅修改名称及目录路径，文件内容和扩展名保持不变。排除父目录自身的改名不会阻止已勾选子项改名；父目录改名时其内部路径仍会随之移动。')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('知道了'))
              ]));

  @override
  Widget build(BuildContext context) => Dialog(
      key: const Key('batch_rename_dialog'),
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160, maxHeight: 860),
          child: Column(children: [
            _header(),
            const Divider(height: 1),
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 720)
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _rulesPane()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _previewPane())
                    ]);
              return Column(children: [
                Row(children: [
                  Expanded(
                      child: TextButton(
                          key: const Key('batch_rules_tab'),
                          onPressed: () => setState(() => _previewTab = false),
                          child: Text(_previewTab ? '规则' : '● 规则'))),
                  Expanded(
                      child: TextButton(
                          key: const Key('batch_preview_tab'),
                          onPressed: () => setState(() => _previewTab = true),
                          child: Text(
                              '${_previewTab ? '● ' : ''}预览（${_plan.changeCount}）')))
                ]),
                Expanded(
                    child: IndexedStack(
                        index: _previewTab ? 1 : 0,
                        children: [_rulesPane(), _previewPane()])),
              ]);
            })),
            const Divider(height: 1),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  TextButton(
                      key: const Key('batch_rename_cancel_btn'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消')),
                  const Spacer(),
                  FilledButton(
                      key: const Key('batch_rename_apply_btn'),
                      onPressed: !_previewing &&
                              _previewError == null &&
                              _plan.canApply &&
                              _invalid.isEmpty
                          ? () => Navigator.pop(context, _plan)
                          : null,
                      child: Text('重命名 ${_plan.changeCount} 项')),
                ])),
          ])));
}
