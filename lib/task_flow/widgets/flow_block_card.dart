import 'package:flutter/material.dart';
import '../models/task_flow_definition.dart';
import 'io_type_indicator.dart';

/// A card representing a single block in the task flow builder.
///
/// Shows the block's icon, label, input/output types, and a brief
/// summary of its configured parameters. Supports drag-to-reorder,
/// tap to edit params, and delete.
class FlowBlockCard extends StatelessWidget {
  final TaskFlowBlock block;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onSettings;
  final VoidCallback? onDelete;

  const FlowBlockCard({
    super.key,
    required this.block,
    required this.index,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.onSettings,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = block.getDefinition();

    if (def == null) {
      return _buildUnknownBlock(cs);
    }

    // Compute non-default parameters for summary display
    final nonDefaultParams = block.params.entries.where((e) {
      final paramDef = def.params.where((p) => p.key == e.key).firstOrNull;
      if (paramDef == null) return false;
      if (e.value == null) return false;
      final dv = paramDef.defaultValue;
      // Compare against the definition's default value
      if (dv != null && dv == e.value) return false;
      if (dv == null &&
          (e.value.toString().isEmpty || e.value == 0 || e.value == false))
        return false;
      return true;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Connection arrow (before the block, except for the first)
        if (!isFirst) ...[
          Icon(Icons.arrow_downward, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(height: 4),
        ],

        // Block card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: def.color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + label + index
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: def.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(def.icon, size: 18, color: def.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$index. ${def.label}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              def.typeKey,
                              style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Settings button
                      IconButton(
                        icon: Icon(Icons.settings, size: 16, color: cs.primary),
                        onPressed: onSettings ?? onTap,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: '设置参数',
                      ),
                      // Delete button (only shown for last block)
                      if (onDelete != null)
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: cs.error),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: '删除',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // I/O type indicators
                  Row(
                    children: [
                      Flexible(
                        child: IOTypeIndicator(
                          type: def.inputType,
                          isInput: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Flexible(
                        child: IOTypeIndicator(
                          type: def.outputType,
                          isInput: false,
                        ),
                      ),
                    ],
                  ),

                  // Parameter summary (shows non-default values)
                  if (nonDefaultParams.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: nonDefaultParams.map((e) {
                          final paramDef = def.params
                              .where((p) => p.key == e.key)
                              .firstOrNull;
                          final label = paramDef?.label ?? e.key;
                          return Text(
                            '$label: ${e.value}',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Tap hint
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '点击设置参数',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnknownBlock(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isFirst) ...[
          Icon(Icons.arrow_downward, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(height: 4),
        ],
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.error.withValues(alpha: 0.4), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: cs.error),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未知功能块: ${block.typeKey}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.error,
                      ),
                    ),
                    Text(
                      '该功能块类型未注册',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
