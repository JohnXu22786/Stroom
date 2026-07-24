import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_flow_definition.dart';
import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../providers/task_flow_provider.dart';
import '../widgets/flow_block_card.dart';
import '../widgets/block_editor_dialog.dart';
import '../widgets/io_type_indicator.dart';

/// Page for building/editing a task flow.
class TaskFlowBuilderPage extends ConsumerStatefulWidget {
  final String? flowId;

  const TaskFlowBuilderPage({super.key, this.flowId});

  @override
  ConsumerState<TaskFlowBuilderPage> createState() =>
      _TaskFlowBuilderPageState();
}

class _TaskFlowBuilderPageState extends ConsumerState<TaskFlowBuilderPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  List<TaskFlowBlock> _blocks = [];
  bool _isEditing = false;
  String? _editingFlowId;
  IOType _inputType = IOType.text;

  /// Available input types for initial input.
  /// Text and URL are merged into single "文本" option (URL treated as text).
  static const List<IOType> _inputTypeOptions = [
    IOType.text,
    IOType.audio,
    IOType.image,
    IOType.video,
  ];
  // URL omitted — treated as text via isCompatibleWith.

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();

    if (widget.flowId != null) {
      _editingFlowId = widget.flowId;
      final flow = ref.read(taskFlowListProvider).firstWhere(
            (f) => f.id == widget.flowId,
            orElse: () => TaskFlowDefinition(name: ''),
          );
      _nameController.text = flow.name;
      _descController.text = flow.description;
      _inputType = flow.inputType;
      _blocks = List<TaskFlowBlock>.from(flow.blocks);
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
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
            // Name & description
            _buildHeader(cs),

            // Flow content with initial input + blocks (scrollable)
            Expanded(
              child: _buildFlowContent(cs),
            ),

            // Bottom bar: add block button
            _buildBottomBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
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
                fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
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

  Widget _buildFlowContent(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // === Position 0: Initial Input Card (always visible) ===
        _buildInitialInputCard(cs),

        // === Blocks (positions 1..N) ===
        ...List.generate(_blocks.length, (index) {
          final block = _blocks[index];
          // Display index: first functional block = 1
          final displayIndex = index + 1;
          // Delete button only on the last block
          final isLast = index == _blocks.length - 1;

          return FlowBlockCard(
            block: block,
            index: displayIndex,
            onTap: () => _editBlock(index),
            onSettings: () => _editBlock(index),
            onDelete: isLast ? () => _removeBlock(index) : null,
          );
        }),
      ],
    );
  }

  /// Card for the initial input (position 0).
  Widget _buildInitialInputCard(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: cs.tertiary.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.input,
                          size: 18, color: Colors.blueGrey),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '0. 初始输入',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    // Input type selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IOType>(
                          value: _inputType,
                          isDense: true,
                          icon: Icon(Icons.arrow_drop_down,
                              size: 18, color: cs.primary),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.primary,
                          ),
                          onChanged: (type) {
                            if (type != null) {
                              setState(() => _inputType = type);
                            }
                          },
                          items: _inputTypeOptions.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: IOTypeIndicator(
                        type: _inputType,
                        isInput: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '用户运行任务流时输入',
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.tertiary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Arrow to first block
        if (_blocks.isNotEmpty) ...[
          SizedBox(
            height: 4,
          ),
          Icon(Icons.arrow_downward, size: 18, color: cs.onSurfaceVariant),
          SizedBox(
            height: 4,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _showAddBlockSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加功能块', style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // Actions
  // ========================================================================

  void _showAddBlockSheet() {
    final cs = Theme.of(context).colorScheme;

    // Determine compatible next block types
    List<BlockTypeDefinition> availableTypes;
    if (_blocks.isEmpty) {
      // No blocks yet — filter by compatibility with initial input
      availableTypes = BlockTypeDefinition.getCompatibleNextBlocks(_inputType);
    } else {
      // Filter by last block's output type
      final lastOutput = _blocks.last.getDefinition()?.outputType ?? IOType.any;
      availableTypes = BlockTypeDefinition.getCompatibleNextBlocks(lastOutput);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (scrollCtx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '选择功能块',
                style: Theme.of(scrollCtx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _blocks.isEmpty
                    ? '当前初始输入类型: ${_inputType.label}'
                    : '上一个功能块输出: ${_blocks.last.getDefinition()?.outputType.label ?? _inputType.label}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (availableTypes.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      '没有与当前类型兼容的功能块',
                      style:
                          TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: availableTypes
                        .map((type) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildBlockTypeOption(type, cs, ctx),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockTypeOption(
      BlockTypeDefinition type, ColorScheme cs, BuildContext ctx) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.pop(ctx);
          _addBlock(type.typeKey);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(type.icon, size: 20, color: type.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${type.inputType.label} → ${type.outputType.label}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline, size: 20, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _addBlock(String typeKey) {
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
      notifier.addFlow(
        name: name,
        description: _descController.text.trim(),
        inputType: _inputType,
        blocks: _blocks,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务流已创建')),
      );
    }

    Navigator.pop(context, true);
  }
}
