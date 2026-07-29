import 'package:flutter/material.dart';

import '../models/block_type_definition.dart';
import '../models/io_type.dart';
import '../models/task_flow_definition.dart';
import 'flow_block_card.dart';
import 'io_type_indicator.dart';

class BlockChainEditor extends StatelessWidget {
  final List<TaskFlowBlock> blocks;
  final IOType inputType;
  final void Function(IOType type) onInputTypeChanged;
  final void Function(BlockType typeKey) onAddBlock;
  final void Function(int index) onEditBlock;
  final void Function(int index) onDeleteBlock;

  const BlockChainEditor({
    super.key,
    required this.blocks,
    required this.inputType,
    required this.onInputTypeChanged,
    required this.onAddBlock,
    required this.onEditBlock,
    required this.onDeleteBlock,
  });

  static const List<IOType> _inputTypeOptions = [
    IOType.text,
    IOType.audio,
    IOType.image,
    IOType.video,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              _buildInitialInputCard(context),
              ...List.generate(blocks.length, (index) {
                final block = blocks[index];
                final displayIndex = index + 1;
                final isLast = index == blocks.length - 1;
                return FlowBlockCard(
                  block: block,
                  index: displayIndex,
                  onTap: () => onEditBlock(index),
                  onSettings: () => onEditBlock(index),
                  onDelete: isLast ? () => onDeleteBlock(index) : null,
                );
              }),
            ],
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildInitialInputCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                          value: inputType,
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
                              onInputTypeChanged(type);
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
                        type: inputType,
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
        if (blocks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Icon(Icons.arrow_downward, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            onPressed: () => _showAddBlockSheet(context),
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

  void _showAddBlockSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    List<BlockTypeDefinition> availableTypes;
    if (blocks.isEmpty) {
      availableTypes = BlockTypeDefinition.getCompatibleNextBlocks(inputType);
    } else {
      final lastOutput = blocks.last.getDefinition()?.outputType ?? IOType.any;
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
                blocks.isEmpty
                    ? '当前初始输入类型: ${inputType.label}'
                    : '上一个功能块输出: ${blocks.last.getDefinition()?.outputType.label ?? inputType.label}',
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
          onAddBlock(type.typeKey);
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
}
