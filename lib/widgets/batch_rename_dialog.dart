import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import 'package:stroom/widgets/stroom_menu_style.dart';
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
  const BatchRenameDialog({
    super.key,
    required this.items,
    required this.allFolders,
    required this.allFiles,
    required this.bridge,
    required this.initialConfig,
  });
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
  AppLocalizations get strings => AppLocalizations.of(context)!;
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
    '照片：日期与编号': BatchRenameConfig(
      rules: [BatchTemplateOp(enabled: true, pattern: '{created}_{n}')],
    ),
    '课程：统一名称与编号': BatchRenameConfig(
      rules: [
        BatchTemplateOp(
          enabled: true,
          pattern: '课程_{n}',
          restartPerFolder: true,
        ),
      ],
    ),
    '下载文件：清理空白': BatchRenameConfig(
      rules: [BatchCleanupOp(enabled: true, collapseWhitespace: true)],
    ),
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
      if (mounted) setState(() => _notice = strings.batchDlgPresetLoadFailed);
    }
  }

  String _builtinPresetLabel(String key) => switch (key) {
        '照片：日期与编号' => strings.batchBuiltinPhoto,
        '课程：统一名称与编号' => strings.batchBuiltinCourse,
        '下载文件：清理空白' => strings.batchBuiltinDownloads,
        _ => key,
      };

  void _recompute() {
    _config = _config.copyWith(rules: [for (final slot in _rules) slot.op]);
    final generation = ++_previewGeneration;
    _regexWorker?.dispose();
    _regexWorker = null;
    _previewError = null;
    _previewing = validateBatchRenameConfig(_config) == null &&
        _config.operations.any(
          (op) => op is BatchReplaceOp && op.effective && op.useRegex,
        );
    _setPlan(
      computeBatchRenamePlan(
        items: widget.items,
        config: _previewing ? _config.copyWith(rules: []) : _config,
        bridge: widget.bridge,
        allFolders: widget.allFolders,
        allFiles: widget.allFiles,
        excludedKeys: _excluded,
        overrides: _overrides,
      ),
    );
    if (_previewing) {
      final worker = _regexWorker = BatchRenameRegexWorker();
      unawaited(_computePreview(generation, worker));
    }
  }

  Future<void> _computePreview(
    int generation,
    BatchRenameRegexWorker worker,
  ) async {
    try {
      final plan = await computeBatchRenamePlanAsync(
        items: widget.items,
        config: _config,
        bridge: widget.bridge,
        allFolders: widget.allFolders,
        allFiles: widget.allFiles,
        excludedKeys: Set.of(_excluded),
        overrides: Map.of(_overrides),
        regexWorker: worker,
      );
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
                  : strings.batchDlgPreviewFailed;
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
        _plan.results[i].item.key: i,
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
        title: Text(strings.batchDlgSavePreset),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: strings.batchDlgPresetName,
            helperText: strings.batchDlgPresetHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.batchDlgCancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty)
                Navigator.pop(ctx, controller.text.trim());
            },
            child: Text(strings.batchDlgSave),
          ),
        ],
      ),
    );
    // Route animations may still hold the controller until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null || !mounted) return;
    if (_presets.containsKey(name)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.batchDlgOverwriteTitle),
          content: Text(strings.batchDlgOverwriteBody(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(strings.batchDlgCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(strings.batchDlgOverwrite),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await _store.save(name, _config);
      await _loadPresets();
      if (mounted) setState(() => _notice = strings.batchDlgSavedName(name));
    } catch (e) {
      if (mounted)
        setState(() => _notice = strings.batchDlgSaveFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _managePresets() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(strings.batchDlgManagePresets),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_presets.isEmpty) Text(strings.batchDlgNoPresets),
                for (final name in _presets.keys)
                  ListTile(
                    title: Text(name),
                    trailing: IconButton(
                      tooltip: strings.batchDlgDeletePreset,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        try {
                          await _store.delete(name);
                          if (!mounted || !ctx.mounted) return;
                          setState(() => _presets.remove(name));
                          update(() {});
                        } catch (e) {
                          if (mounted)
                            setState(
                              () => _notice = strings.batchDlgDeleteFailed(
                                e.toString(),
                              ),
                            );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.batchDlgDone),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BatchRenameResult r) async {
    final controller = TextEditingController(text: r.baseName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.batchDlgEditNameTooltip),
        content: TextField(
          key: const Key('batch_manual_name'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: strings.batchDlgBaseName,
            helperText: r.item.format.isEmpty
                ? strings.batchDlgOverrideHelp
                : strings.batchDlgExtensionRetained(r.item.format),
            helperMaxLines: 2,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.batchDlgCancel),
          ),
          FilledButton(
            key: const Key('batch_manual_save'),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(strings.batchDlgConfirm),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name != null && mounted) _change(() => _overrides[r.item.key] = name);
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.batchDlgRenameCount(widget.items.length.toString()),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: strings.batchDlgHelp,
                  onPressed: _help,
                  icon: const Icon(Icons.help_outline),
                ),
                IconButton(
                  key: const Key('batch_rename_close_btn'),
                  tooltip: strings.batchDlgClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PopupMenuButton<BatchRenameConfig>(
                    tooltip: strings.batchDlgLoadPreset,
                    onSelected: _useConfig,
                    itemBuilder: (_) => [
                      for (final e in _builtins.entries)
                        PopupMenuItem(
                          value: e.value,
                          child: Text(_builtinPresetLabel(e.key)),
                        ),
                      if (_presets.isNotEmpty) const PopupMenuDivider(),
                      for (final e in _presets.entries)
                        PopupMenuItem(value: e.value, child: Text(e.key)),
                    ],
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(strings.batchDlgLoad),
                          Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ||
                            _invalid.isNotEmpty ||
                            _plan.configError != null
                        ? null
                        : _savePreset,
                    child: Text(
                      _saving
                          ? strings.batchDlgSaving
                          : strings.batchDlgSavePresetFallback,
                    ),
                  ),
                  IconButton(
                    onPressed: _managePresets,
                    tooltip: strings.batchDlgManagePresets,
                    icon: const Icon(Icons.tune),
                  ),
                  IconButton(
                    key: const Key('batch_reset'),
                    tooltip: strings.batchDlgReset,
                    onPressed: () => _useConfig(
                      BatchRenameConfig(
                        sortField: widget.initialConfig.sortField,
                        sortOrder: widget.initialConfig.sortOrder,
                      ),
                      resetSelection: true,
                    ),
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),
            if (_notice != null)
              Text(_notice!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _rulesPane() =>
      KeyedSubtree(key: _rulesPaneKey, child: _rulesContent());
  Widget _rulesContent() {
    final seen = <Type>{};
    return SingleChildScrollView(
      key: const Key('batch_rules_scroll'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.batchDlgRuleInstructions,
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final field in SortField.values)
                ChoiceChip(
                  label: Text(switch (field) {
                    SortField.name => strings.batchDlgSortName,
                    SortField.createdAt => strings.batchDlgSortCreated,
                    SortField.modifiedAt => strings.batchDlgSortModified,
                    SortField.size => strings.batchDlgSortSize,
                  }),
                  selected: _config.sortField == field,
                  onSelected: (_) => _change(
                    () => _config = _config.copyWith(sortField: field),
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final order in SortOrder.values)
                ChoiceChip(
                  label: Text(
                    order == SortOrder.ascending
                        ? strings.batchDlgAscending
                        : strings.batchDlgDescending,
                  ),
                  selected: _config.sortOrder == order,
                  onSelected: (_) => _change(
                    () => _config = _config.copyWith(sortOrder: order),
                  ),
                ),
            ],
          ),
          Text(strings.batchDlgFolderSort, style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          for (var i = 0; i < _rules.length; i++)
            _rule(_rules[i], i, seen.add(_rules[i].op.runtimeType)),
          PopupMenuButton<BatchRenameOp>(
            enabled: _rules.length < 50,
            onSelected: (op) => _change(
              () => _rules.add(_RuleSlot(_nextId++, op.withEnabled(true))),
            ),
            itemBuilder: (_) => [
              for (final op in const BatchRenameConfig().operations)
                PopupMenuItem(
                  value: op,
                  child: Text(localizedBatchRenameOperationLabel(op, strings)),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _rules.length < 50
                    ? strings.batchDlgAddRule
                    : strings.batchDlgMaxRules,
              ),
            ),
          ),
        ],
      ),
    );
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
              () => _rules.insert(index + 1, _RuleSlot(_nextId++, slot.op)),
            );
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
        strings.batchDlgPreviewSummary(
          _plan.changeCount.toString(),
          _plan.conflictCount.toString(),
          _excluded.length.toString(),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      if (_previewing) ...[
        const LinearProgressIndicator(key: Key('batch_preview_busy')),
        Text(strings.batchDlgPreviewWorking),
      ],
      if (_previewError != null)
        Text(_previewError!, style: TextStyle(color: colors.error)),
      TextField(
        key: const Key('batch_preview_search'),
        controller: _searchController,
        decoration: InputDecoration(
          hintText: strings.batchDlgSearch,
          prefixIcon: Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<_PreviewFilter>(
            dropdownColor: StroomMenuStyle.surface(context),
            borderRadius: StroomMenuStyle.borderRadius,
            value: _filter,
            onChanged: (v) => setState(() => _filter = v!),
            items: [
              for (final f in _PreviewFilter.values)
                DropdownMenuItem(
                  value: f,
                  child: Text(switch (f) {
                    _PreviewFilter.all => strings.batchDlgFilterAll,
                    _PreviewFilter.changed => strings.batchDlgFilterChanged,
                    _PreviewFilter.errors => strings.batchDlgFilterErrors,
                    _PreviewFilter.unchanged => strings.batchDlgFilterUnchanged,
                    _PreviewFilter.excluded => strings.batchDlgFilterExcluded,
                  }),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: strings.batchDlgParticipants,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'all',
                child: Text(strings.batchDlgIncludeAll),
              ),
              PopupMenuItem(
                value: 'files',
                child: Text(strings.batchDlgOnlyFiles),
              ),
              PopupMenuItem(
                value: 'folders',
                child: Text(strings.batchDlgOnlyFolders),
              ),
              PopupMenuItem(
                value: 'none',
                child: Text(strings.batchDlgExcludeAll),
              ),
            ],
            onSelected: (v) => _change(() {
              _excluded.clear();
              for (final item in widget.items) {
                if (v == 'none' ||
                    (v == 'files' && item.isFolder) ||
                    (v == 'folders' && !item.isFolder)) _excluded.add(item.key);
              }
            }),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.batchDlgScope),
                  Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed:
                _previewing || _previewError != null ? null : _copyPreview,
            child: Text(strings.batchDlgCopyList),
          ),
        ],
      ),
      DropdownButton<BatchRenameConflictStrategy>(
        dropdownColor: StroomMenuStyle.surface(context),
        borderRadius: StroomMenuStyle.borderRadius,
        isExpanded: true,
        value: _config.conflictStrategy,
        items: [
          DropdownMenuItem(
            value: BatchRenameConflictStrategy.block,
            child: Text(strings.batchDlgConflictBlock),
          ),
          DropdownMenuItem(
            value: BatchRenameConflictStrategy.numberSuffix,
            child: Text(strings.batchDlgConflictSuffix),
          ),
        ],
        onChanged: (v) =>
            _change(() => _config = _config.copyWith(conflictStrategy: v)),
      ),
      if (_invalid.isNotEmpty || _plan.configError != null)
        Text(
          _invalid.isNotEmpty
              ? strings.batchDlgInvalidInput
              : _plan.configError!,
          style: TextStyle(color: colors.error),
        ),
      if (_plan.conflictCount > 0)
        Text(
          strings.batchDlgConflictError,
          style: TextStyle(color: colors.error),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomScrollView(
        key: const Key('batch_rename_preview_list'),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: controls,
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(strings.batchDlgNoMatches)),
            )
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (_, index) => _previewItem(visible[index]),
            ),
        ],
      ),
    );
  }

  Widget _previewItem(BatchRenameResult r) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: Key('batch_rename_preview_${_previewIndices[r.item.key]}'),
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: Key('batch_include_${r.item.key}'),
              value: r.included,
              onChanged: (v) => _change(() {
                if (v == true) {
                  _excluded.remove(r.item.key);
                } else {
                  _excluded.add(r.item.key);
                }
              }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.item.isFolder ? strings.batchDlgFolder : strings.batchDlgFile} · ${r.item.folder.isEmpty ? strings.batchDlgRoot : r.item.folder}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Tooltip(
                    message: r.oldDisplay,
                    child: Text(
                      r.oldDisplay,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('→ '),
                      Expanded(
                        child: Tooltip(
                          message: r.newDisplay,
                          child: Text(
                            r.newDisplay,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: r.error != null
                                  ? colors.error
                                  : r.isChanged
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (r.targetFolder != r.item.folder)
                    Text(
                      strings.batchDlgTargetFolder(
                        r.targetFolder!.isEmpty
                            ? strings.batchDlgRoot
                            : r.targetFolder!,
                      ),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  Text(
                    r.error ??
                        (!r.included
                            ? strings.batchDlgFilterExcluded
                            : _overrides.containsKey(r.item.key)
                                ? strings.batchDlgManualNameStatus
                                : r.isChanged
                                    ? strings.batchDlgPendingRename
                                    : strings.batchDlgFilterUnchanged),
                    style: TextStyle(
                      fontSize: 12,
                      color: r.error != null
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  key: Key('batch_edit_${r.item.key}'),
                  tooltip: strings.batchDlgEditNameTooltip,
                  onPressed: r.included ? () => _editName(r) : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                if (_overrides.containsKey(r.item.key))
                  IconButton(
                    key: Key('batch_clear_override_${r.item.key}'),
                    tooltip: strings.batchDlgRestoreNameTooltip,
                    onPressed: () =>
                        _change(() => _overrides.remove(r.item.key)),
                    icon: const Icon(Icons.undo, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPreview() async {
    String cell(String text) => '"${text.replaceAll('"', '""')}"';
    final content = [
      strings.batchDlgCsvHeader,
      for (final r in _plan.results)
        [
          r.oldPath,
          r.oldDisplay,
          r.newPath,
          r.error ??
              (!r.included
                  ? strings.batchDlgFilterExcluded
                  : r.isChanged
                      ? strings.batchDlgPendingRename
                      : strings.batchDlgFilterUnchanged),
        ].map(cell).join(','),
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) setState(() => _notice = strings.batchDlgCopied);
    } catch (_) {
      if (mounted) setState(() => _notice = strings.batchDlgCopyFailed);
    }
  }

  void _help() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.batchDlgHelpTitle),
          content: SingleChildScrollView(child: Text(strings.batchDlgHelpBody)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.batchDlgHelpDismiss),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        key: const Key('batch_rename_dialog'),
        insetPadding: const EdgeInsets.all(12),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160, maxHeight: 860),
          child: Column(
            children: [
              _header(),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720)
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _rulesPane()),
                          const VerticalDivider(width: 1),
                          Expanded(child: _previewPane()),
                        ],
                      );
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                key: const Key('batch_rules_tab'),
                                onPressed: () =>
                                    setState(() => _previewTab = false),
                                child: Text(
                                  _previewTab
                                      ? strings.batchDlgRulesTab
                                      : '● ${strings.batchDlgRulesTab}',
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                key: const Key('batch_preview_tab'),
                                onPressed: () =>
                                    setState(() => _previewTab = true),
                                child: Text(
                                  '${_previewTab ? '● ' : ''}${strings.batchDlgPreviewCount(_plan.changeCount.toString())}',
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _previewTab ? 1 : 0,
                            children: [_rulesPane(), _previewPane()],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TextButton(
                      key: const Key('batch_rename_cancel_btn'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(strings.batchDlgCancel),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('batch_rename_apply_btn'),
                      onPressed: !_previewing &&
                              _previewError == null &&
                              _plan.canApply &&
                              _invalid.isEmpty
                          ? () => Navigator.pop(context, _plan)
                          : null,
                      child: Text(
                        strings
                            .batchDlgRenameCount(_plan.changeCount.toString()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
