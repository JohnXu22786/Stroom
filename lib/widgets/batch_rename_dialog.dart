import 'package:flutter/material.dart';

import '../utils/batch_rename.dart';
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

/// 批量重命名面板
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

class _BatchRenameDialogState extends State<BatchRenameDialog> {
  late BatchRenameConfig _config = widget.initialConfig;
  late BatchRenamePlan _plan = _compute();

  // 文本输入控制器（数值字段在 onChanged 中解析为 int）
  final _numStartController = TextEditingController();
  final _numStepController = TextEditingController();
  final _numDigitsController = TextEditingController();
  final _numSeparatorController = TextEditingController();
  final _repFindController = TextEditingController();
  final _repToController = TextEditingController();
  final _insTextController = TextEditingController();
  final _insIndexController = TextEditingController();
  final _delCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = _config;
    _numStartController.text = '${c.numbering.start}';
    _numStepController.text = '${c.numbering.step}';
    _numDigitsController.text = '${c.numbering.digits}';
    _numSeparatorController.text = c.numbering.separator;
    _repFindController.text = c.replace.find;
    _repToController.text = c.replace.replace;
    _insTextController.text = c.insert.text;
    _insIndexController.text = '${c.insert.index}';
    _delCountController.text = '${c.delete.count}';
  }

  @override
  void dispose() {
    _numStartController.dispose();
    _numStepController.dispose();
    _numDigitsController.dispose();
    _numSeparatorController.dispose();
    _repFindController.dispose();
    _repToController.dispose();
    _insTextController.dispose();
    _insIndexController.dispose();
    _delCountController.dispose();
    super.dispose();
  }

  BatchRenamePlan _compute() => computeBatchRenamePlan(
        items: widget.items,
        config: _config,
        bridge: widget.bridge,
        allFolders: widget.allFolders,
        allFiles: widget.allFiles,
      );

  void _update(BatchRenameConfig config) {
    setState(() {
      _config = config;
      _plan = _compute();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('batch_rename_dialog'),
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSortSection(),
                    const SizedBox(height: 12),
                    _buildNumberingSection(),
                    const SizedBox(height: 12),
                    _buildReplaceSection(),
                    const SizedBox(height: 12),
                    _buildInsertSection(),
                    const SizedBox(height: 12),
                    _buildDeleteSection(),
                    const SizedBox(height: 12),
                    _buildCaseSection(),
                    const SizedBox(height: 12),
                    _buildPreviewSection(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // 头部
  // ====================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(Icons.drive_file_rename_outline,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '批量重命名（${widget.items.length} 项）',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const Key('batch_rename_close_btn'),
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // 排序（编号依据）
  // ====================================================================

  Widget _buildSortSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '排序（编号按此顺序分配）',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<SortField>(
              key: const Key('batch_sort_field_selector'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: SortField.name, label: Text('按名称')),
                ButtonSegment(value: SortField.createdAt, label: Text('按时间')),
                ButtonSegment(value: SortField.size, label: Text('按大小')),
              ],
              selected: {_config.sortField},
              onSelectionChanged: (s) =>
                  _update(_config.copyWith(sortField: s.first)),
            ),
            const SizedBox(height: 8),
            SegmentedButton<SortOrder>(
              key: const Key('batch_sort_order_selector'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: SortOrder.ascending, label: Text('升序')),
                ButtonSegment(value: SortOrder.descending, label: Text('降序')),
              ],
              selected: {_config.sortOrder},
              onSelectionChanged: (s) =>
                  _update(_config.copyWith(sortOrder: s.first)),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // 操作区块骨架：标题 + 启用开关 + 可折叠内容
  // ====================================================================

  Widget _opSection({
    required String title,
    required IconData icon,
    required Key switchKey,
    required bool enabled,
    required VoidCallback onEnabledChanged,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  key: switchKey,
                  value: enabled,
                  onChanged: (_) => onEnabledChanged(),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 区块内的小标签
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      );

  /// 紧凑数字输入框。
  /// [fallback] 为上一次有效的配置值：输入无法解析时回退显示该值，
  /// 避免预览/计划与实际输入脱节。
  Widget _numField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required double width,
    required int fallback,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 2),
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            onChanged: (s) {
              final parsed = int.tryParse(s.trim());
              if (parsed == null) {
                // 输入非法 → 回退到上次有效值，保持字段与配置一致
                controller.text = '$fallback';
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
                return;
              }
              onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }

  // ====================================================================
  // 编号
  // ====================================================================

  Widget _buildNumberingSection() {
    final n = _config.numbering;
    return _opSection(
      title: '编号',
      icon: Icons.tag,
      switchKey: const Key('batch_num_switch'),
      enabled: n.enabled,
      onEnabledChanged: () =>
          _update(_config.copyWith(numbering: n.copyWith(enabled: !n.enabled))),
      children: [
        SegmentedButton<BatchRenameNumberPos>(
          key: const Key('batch_num_pos_selector'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
                value: BatchRenameNumberPos.prefix, label: Text('前缀')),
            ButtonSegment(
                value: BatchRenameNumberPos.suffix, label: Text('后缀')),
          ],
          selected: {n.position},
          onSelectionChanged: (s) => _update(
              _config.copyWith(numbering: n.copyWith(position: s.first))),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _numField(
                label: '起始',
                hint: '1',
                controller: _numStartController,
                width: double.infinity,
                fallback: n.start,
                onChanged: (v) =>
                    _update(_config.copyWith(numbering: n.copyWith(start: v))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numField(
                label: '步长',
                hint: '1',
                controller: _numStepController,
                width: double.infinity,
                fallback: n.step,
                onChanged: (v) =>
                    _update(_config.copyWith(numbering: n.copyWith(step: v))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numField(
                label: '位数',
                hint: '1',
                controller: _numDigitsController,
                width: double.infinity,
                fallback: n.digits,
                onChanged: (v) =>
                    _update(_config.copyWith(numbering: n.copyWith(digits: v))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '分隔符',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    key: const Key('batch_num_separator_field'),
                    controller: _numSeparatorController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '_',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (s) => _update(
                      _config.copyWith(numbering: n.copyWith(separator: s)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // 替换
  // ====================================================================

  Widget _buildReplaceSection() {
    final r = _config.replace;
    return _opSection(
      title: '替换',
      icon: Icons.find_replace,
      switchKey: const Key('batch_replace_switch'),
      enabled: r.enabled,
      onEnabledChanged: () =>
          _update(_config.copyWith(replace: r.copyWith(enabled: !r.enabled))),
      children: [
        _label('查找内容'),
        TextField(
          key: const Key('batch_replace_find_field'),
          controller: _repFindController,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '要查找的文字',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (s) =>
              _update(_config.copyWith(replace: r.copyWith(find: s))),
        ),
        const SizedBox(height: 8),
        _label('替换为（留空表示删除查找内容）'),
        TextField(
          key: const Key('batch_replace_to_field'),
          controller: _repToController,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: '替换成的文字',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (s) =>
              _update(_config.copyWith(replace: r.copyWith(replace: s))),
        ),
        Row(
          children: [
            Checkbox(
              key: const Key('batch_replace_case_checkbox'),
              value: r.caseSensitive,
              onChanged: (v) => _update(
                _config.copyWith(
                    replace: r.copyWith(caseSensitive: v ?? false)),
              ),
            ),
            const Text('区分大小写', style: TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // 插入
  // ====================================================================

  Widget _buildInsertSection() {
    final ins = _config.insert;
    return _opSection(
      title: '插入',
      icon: Icons.input,
      switchKey: const Key('batch_insert_switch'),
      enabled: ins.enabled,
      onEnabledChanged: () => _update(
          _config.copyWith(insert: ins.copyWith(enabled: !ins.enabled))),
      children: [
        SegmentedButton<BatchRenameInsertPos>(
          key: const Key('batch_insert_pos_selector'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: BatchRenameInsertPos.start, label: Text('开头')),
            ButtonSegment(value: BatchRenameInsertPos.end, label: Text('结尾')),
            ButtonSegment(
              value: BatchRenameInsertPos.atIndex,
              label: Text('指定位置'),
            ),
          ],
          selected: {ins.position},
          onSelectionChanged: (s) => _update(
              _config.copyWith(insert: ins.copyWith(position: s.first))),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('插入文本'),
                  TextField(
                    key: const Key('batch_insert_text_field'),
                    controller: _insTextController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '要插入的文字',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (s) => _update(
                        _config.copyWith(insert: ins.copyWith(text: s))),
                  ),
                ],
              ),
            ),
            if (ins.position == BatchRenameInsertPos.atIndex) ...[
              const SizedBox(width: 8),
              _numField(
                label: '位置(第N个字符前)',
                hint: '1',
                controller: _insIndexController,
                width: 90,
                fallback: ins.index,
                onChanged: (v) =>
                    _update(_config.copyWith(insert: ins.copyWith(index: v))),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // 删除字符
  // ====================================================================

  Widget _buildDeleteSection() {
    final del = _config.delete;
    return _opSection(
      title: '删除字符',
      icon: Icons.backspace_outlined,
      switchKey: const Key('batch_delete_switch'),
      enabled: del.enabled,
      onEnabledChanged: () => _update(
          _config.copyWith(delete: del.copyWith(enabled: !del.enabled))),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<BatchRenameDeletePos>(
                key: const Key('batch_delete_pos_selector'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: BatchRenameDeletePos.start,
                    label: Text('从开头'),
                  ),
                  ButtonSegment(
                    value: BatchRenameDeletePos.end,
                    label: Text('从结尾'),
                  ),
                ],
                selected: {del.position},
                onSelectionChanged: (s) => _update(
                  _config.copyWith(delete: del.copyWith(position: s.first)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _numField(
              label: '数量',
              hint: '1',
              controller: _delCountController,
              width: 72,
              fallback: del.count,
              onChanged: (v) =>
                  _update(_config.copyWith(delete: del.copyWith(count: v))),
            ),
          ],
        ),
      ],
    );
  }

  // ====================================================================
  // 大小写
  // ====================================================================

  Widget _buildCaseSection() {
    final c = _config.caseOp;
    return _opSection(
      title: '大小写',
      icon: Icons.text_fields,
      switchKey: const Key('batch_case_switch'),
      enabled: c.enabled,
      onEnabledChanged: () =>
          _update(_config.copyWith(caseOp: c.copyWith(enabled: !c.enabled))),
      children: [
        SegmentedButton<BatchRenameCaseMode>(
          key: const Key('batch_case_mode_selector'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: BatchRenameCaseMode.upper, label: Text('全大写')),
            ButtonSegment(value: BatchRenameCaseMode.lower, label: Text('全小写')),
            ButtonSegment(
              value: BatchRenameCaseMode.firstUpper,
              label: Text('首字母大写'),
            ),
          ],
          selected: {c.mode},
          onSelectionChanged: (s) =>
              _update(_config.copyWith(caseOp: c.copyWith(mode: s.first))),
        ),
      ],
    );
  }

  // ====================================================================
  // 预览
  // ====================================================================

  Widget _buildPreviewSection() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '预览',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _plan.conflictCount > 0
                    ? '将重命名 ${_plan.changeCount} 项，${_plan.conflictCount} 项有冲突'
                    : '将重命名 ${_plan.changeCount} 项',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 220,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            key: const Key('batch_rename_preview_list'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _plan.results.length,
            itemBuilder: (context, index) =>
                _buildPreviewItem(index, _plan.results[index]),
          ),
        ),
        const SizedBox(height: 4),
        if (_plan.conflictCount > 0)
          Text(
            '存在冲突或非法名称，无法应用。请调整规则。',
            style: TextStyle(fontSize: 12, color: colors.error),
          ),
      ],
    );
  }

  Widget _buildPreviewItem(int index, BatchRenameResult r) {
    final colors = Theme.of(context).colorScheme;
    final Color newColor = r.error != null
        ? colors.error
        : (r.isChanged ? colors.primary : Colors.grey[500]!);
    final Widget statusIcon = r.error != null
        ? Icon(Icons.error_outline, size: 16, color: colors.error)
        : r.isChanged
            ? Icon(Icons.check_circle_outline,
                size: 16, color: Colors.green[600])
            : Icon(Icons.remove, size: 16, color: Colors.grey[400]);

    return Container(
      key: Key('batch_rename_preview_$index'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          Icon(
            r.item.isFolder ? Icons.folder_outlined : Icons.insert_drive_file,
            size: 16,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.oldDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        r.newDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: newColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (r.error != null)
                  Text(
                    r.error!,
                    style: TextStyle(fontSize: 11, color: colors.error),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          statusIcon,
        ],
      ),
    );
  }

  // ====================================================================
  // 底部操作栏
  // ====================================================================

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          TextButton(
            key: const Key('batch_rename_cancel_btn'),
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const Spacer(),
          FilledButton(
            key: const Key('batch_rename_apply_btn'),
            onPressed: _plan.canApply ? _apply : null,
            child: Text('重命名 ${_plan.changeCount} 项'),
          ),
        ],
      ),
    );
  }

  void _apply() {
    if (!_plan.canApply) return;
    Navigator.pop(context, _plan);
  }
}
