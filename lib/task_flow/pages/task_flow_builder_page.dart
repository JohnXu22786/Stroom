import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import '../providers/task_flow_provider.dart';
import '../services/task_flow_execution_service.dart';
import '../widgets/block_chain_editor.dart';
import '../widgets/block_editor_dialog.dart';

/// Unified page for editing AND launching a task flow.
///
/// When [startInRunMode] is true, the page opens in "run" mode showing the
/// execution UI (overview, input, step list, start button) with an edit
/// button in the top-right corner. Tapping edit switches to edit mode.
///
/// When [startInRunMode] is false (default), the page opens in edit mode
/// for building / modifying the block chain. If [flowId] is null the page
/// acts as "create new flow".
class TaskFlowBuilderPage extends ConsumerStatefulWidget {
  final String? flowId;
  final bool startInRunMode;

  const TaskFlowBuilderPage({
    super.key,
    this.flowId,
    this.startInRunMode = false,
  });

  @override
  ConsumerState<TaskFlowBuilderPage> createState() =>
      _TaskFlowBuilderPageState();
}

class _TaskFlowBuilderPageState extends ConsumerState<TaskFlowBuilderPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _inputController;

  List<TaskFlowBlock> _blocks = [];
  bool _isEditing = false;
  String? _editingFlowId;
  IOType _inputType = IOType.text;
  bool _isRunMode = false;

  String _initialName = '';
  String _initialDesc = '';
  IOType _initialInputType = IOType.text;
  List<TaskFlowBlock> _initialBlocks = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _inputController = TextEditingController();

    _inputController.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.flowId != null) {
      _editingFlowId = widget.flowId;
      _isEditing = true;
      _isRunMode = widget.startInRunMode;

      final flow = ref.read(taskFlowListProvider).firstWhere(
            (f) => f.id == widget.flowId,
            orElse: () => TaskFlowDefinition(name: ''),
          );
      _nameController.text = flow.name;
      _descController.text = flow.description;
      _inputType = flow.inputType;
      _blocks = List<TaskFlowBlock>.from(flow.blocks);
    }

    _initialName = _nameController.text.trim();
    _initialDesc = _descController.text.trim();
    _initialInputType = _inputType;
    _initialBlocks = List<TaskFlowBlock>.from(_blocks);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // =========================================================================
  // Dirty check helpers
  // =========================================================================

  bool get _isDirty {
    if (!_isEditing) {
      return _nameController.text.trim().isNotEmpty ||
          _descController.text.trim().isNotEmpty ||
          _blocks.isNotEmpty ||
          _inputType != IOType.text;
    }
    return _nameController.text.trim() != _initialName ||
        _descController.text.trim() != _initialDesc ||
        _inputType != _initialInputType ||
        _blocksDiffer(_blocks, _initialBlocks);
  }

  bool _blocksDiffer(List<TaskFlowBlock> a, List<TaskFlowBlock> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      final blockA = a[i];
      final blockB = b[i];
      if (blockA.id != blockB.id || blockA.typeKey != blockB.typeKey)
        return true;
      if (!mapEquals(blockA.params, blockB.params)) return true;
    }
    return false;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未保存的更改？'),
        content: const Text('返回后，所有未保存的更改将会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // =========================================================================
  // Build entry – mode dispatch
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isRunMode) return _buildRunMode();
    return _buildEditMode();
  }

  // ============================================================
  // EDIT MODE (existing builder UI)
  // ============================================================

  Widget _buildEditMode() {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!mounted) return;
        if (!_isDirty) {
          Navigator.of(context).pop();
          return;
        }
        final shouldDiscard = await _showUnsavedChangesDialog();
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑任务流' : '新建任务流'),
          centerTitle: true,
          actions: [
            TextButton.icon(
              onPressed: _saveFlow,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存'),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _buildEditHeader(cs),
              Expanded(
                child: BlockChainEditor(
                  blocks: _blocks,
                  inputType: _inputType,
                  onInputTypeChanged: (type) =>
                      setState(() => _inputType = type),
                  onAddBlock: _addBlock,
                  onEditBlock: _editBlock,
                  onDeleteBlock: _removeBlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '输入任务流名称',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              hintText: '添加描述（可选）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            maxLines: 2,
            minLines: 1,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _addBlock(BlockType typeKey) {
    setState(() {
      _blocks = [..._blocks, TaskFlowBlock(typeKey: typeKey)];
    });
  }

  void _removeBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    setState(() {
      _blocks = [..._blocks]..removeAt(index);
    });
  }

  Future<void> _editBlock(int index) async {
    if (index < 0 || index >= _blocks.length) return;
    final updated = await showBlockEditorDialog(
      context,
      block: _blocks[index],
    );
    if (updated != null && mounted) {
      setState(() {
        final newBlocks = [..._blocks];
        newBlocks[index] = updated;
        _blocks = newBlocks;
      });
    }
  }

  void _saveFlow() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务流名称')),
      );
      return;
    }

    final notifier = ref.read(taskFlowListProvider.notifier);

    if (_editingFlowId != null) {
      notifier.updateFlow(
        _editingFlowId!,
        name: name,
        description: _descController.text.trim(),
        inputType: _inputType,
        blocks: _blocks,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务流已更新')),
      );
    } else {
      _editingFlowId = notifier.addFlow(
        name: name,
        description: _descController.text.trim(),
        inputType: _inputType,
        blocks: _blocks,
      );
      _isEditing = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务流已创建')),
      );
    }

    _initialName = _nameController.text.trim();
    _initialDesc = _descController.text.trim();
    _initialInputType = _inputType;
    _initialBlocks = _blocks
        .map((b) => TaskFlowBlock(
              id: b.id,
              typeKey: b.typeKey,
              params: Map<String, dynamic>.from(b.params),
            ))
        .toList();

    Navigator.of(context).pop();
  }

  // ============================================================
  // RUN MODE (merged from execution page)
  // ============================================================

  Widget _buildRunMode() {
    final cs = Theme.of(context).colorScheme;
    final flowName = _nameController.text.trim();

    if (flowName.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务流'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('任务未找到', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(flowName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => setState(() => _isRunMode = false),
            tooltip: '编辑',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRunOverviewCard(flowName, cs),
            const SizedBox(height: 20),
            _buildRunInputSection(cs),
            const SizedBox(height: 16),
            ..._blocks.asMap().entries.map((entry) => _buildRunStepCard(
                block: entry.value, index: entry.key, cs: cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildRunOverviewCard(String flowName, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_tree, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(flowName,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
          ]),
          if (_descController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_descController.text.trim(),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _blocks.asMap().entries.map((entry) {
                final def = entry.value.getDefinition();
                return Row(children: [
                  if (entry.key > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward,
                          size: 14, color: cs.onSurfaceVariant),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: def?.color.withValues(alpha: 0.12) ??
                          Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(def?.label ?? entry.value.typeKey.name,
                        style: TextStyle(
                            fontSize: 11,
                            color: def?.color ?? Colors.grey,
                            fontWeight: FontWeight.w500)),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunInputSection(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.input, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('输入（${_inputType.label}）',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ]),
            const SizedBox(height: 8),
            if (_inputType == IOType.url)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入网页链接',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.link, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.url,
              )
            else if (_inputType == IOType.text)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入文本',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.text_fields, size: 18),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
              )
            else
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: '输入 ${_inputType.label} 路径或标识',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: cs.surface,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: _inputController.text.trim().isNotEmpty
                      ? _startFlow
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始任务流'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunStepCard({
    required TaskFlowBlock block,
    required int index,
    required ColorScheme cs,
  }) {
    final def = block.getDefinition();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.arrow_downward,
                  size: 18, color: cs.onSurfaceVariant),
            ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(def?.icon ?? Icons.extension,
                      size: 16, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      '${index + 1}. ${def?.label ?? block.typeKey.name}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Run mode – start execution
  // =========================================================================

  Future<void> _startFlow() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty) return;

    final flow = ref
        .read(taskFlowListProvider)
        .where((f) => f.id == _editingFlowId)
        .firstOrNull;

    if (flow == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务流不存在')),
        );
      }
      return;
    }

    if (flow.blocks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务流未包含任何功能块')),
        );
      }
      return;
    }

    final service = ref.read(taskFlowExecutionServiceProvider);

    if (service.isRunning) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已有任务流正在执行')),
        );
      }
      return;
    }

    // Fire-and-forget: startFlow can take minutes (polling loops).
    // The unified task list will show real-time progress.
    service.startFlow(_editingFlowId!, inputText);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('任务流已启动'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}
