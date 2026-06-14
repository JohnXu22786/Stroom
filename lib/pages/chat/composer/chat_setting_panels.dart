import 'package:flutter/material.dart';
import 'package:stroom/models/tool_call.dart';

// ═══════════════════════════════════════════════════════════════
// Model Panel
// ═══════════════════════════════════════════════════════════════

/// Shows a modal bottom sheet for selecting the AI model.
/// Supports drag-and-drop reordering via [onModelsReordered].
void showModelPanel({
  required BuildContext context,
  required List<String> models,
  required int selectedModelIndex,
  required ValueChanged<int> onModelSelected,
  ValueChanged<List<String>>? onModelsReordered,
}) {
  var localSelectedIndex = selectedModelIndex;
  var localModels = List<String>.from(models);

  void handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = localModels.removeAt(oldIndex);
    localModels.insert(newIndex, item);

    // Update selected index to follow the dragged model
    if (localSelectedIndex == oldIndex) {
      localSelectedIndex = newIndex;
    } else if (oldIndex < localSelectedIndex && newIndex >= localSelectedIndex) {
      localSelectedIndex--;
    } else if (oldIndex > localSelectedIndex && newIndex <= localSelectedIndex) {
      localSelectedIndex++;
    }

    onModelsReordered?.call(List<String>.from(localModels));
  }

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[350],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.smart_toy_outlined,
                            size: 18, color: Colors.teal),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '选择模型',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (localModels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          '暂无可用模型',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        itemCount: localModels.length,
                        onReorder: (oldIndex, newIndex) {
                          handleReorder(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              final elevation =
                                  Tween<double>(begin: 0, end: 4)
                                      .animate(animation)
                                      .value;
                              return Material(
                                elevation: elevation,
                                color: Colors.transparent,
                                shadowColor: Colors.black26,
                                borderRadius: BorderRadius.circular(10),
                                child: child,
                              );
                            },
                            child: child,
                          );
                        },
                        itemBuilder: (context, i) {
                          final isSelected = localSelectedIndex == i;
                          return Padding(
                            key: ValueKey('model_${localModels[i]}_$i'),
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Card(
                              elevation: 0,
                              color: isSelected
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest
                                      .withOpacity(0.3),
                              child: ListTile(
                                dense: true,
                                leading: ReorderableDragStartListener(
                                  index: i,
                                  child: Icon(
                                    Icons.drag_indicator,
                                    size: 20,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                title: Text(
                                  localModels[i],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: cs.onSurface,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check,
                                        size: 18, color: cs.primary)
                                    : null,
                                onTap: () {
                                  setState(
                                      () => localSelectedIndex = i);
                                  onModelSelected(i);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// Tools Panel
// ═══════════════════════════════════════════════════════════════

/// Shows a modal bottom sheet for toggling MCP tools.
void showToolsPanel({
  required BuildContext context,
  required List<ToolDefinition> tools,
  required Set<String> enabledTools,
  required void Function(String toolName, bool enabled) onToolToggle,
}) {
  var localEnabledTools = Set<String>.from(enabledTools);
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[350],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: cs.tertiary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.build_outlined,
                            size: 18, color: cs.tertiary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '可用工具',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (tools.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          '暂无可用工具',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ...tools.map((tool) {
                      final isEnabled =
                          localEnabledTools.contains(tool.name);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SwitchListTile(
                            dense: true,
                            value: isEnabled,
                            onChanged: (enabled) {
                              setState(() {
                                if (enabled) {
                                  localEnabledTools.add(tool.name);
                                } else {
                                  localEnabledTools.remove(tool.name);
                                }
                              });
                              onToolToggle(tool.name, enabled);
                            },
                            activeColor: cs.primary,
                            title: Text(
                              tool.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                            subtitle: tool.description.isNotEmpty
                                ? Text(
                                    tool.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════
// Reasoning Panel
// ═══════════════════════════════════════════════════════════════

/// Shows a modal bottom sheet for reasoning settings.
void showReasoningPanel({
  required BuildContext context,
  required bool reasoningEnabled,
  required String reasoningEffort,
  required ValueChanged<bool> onReasoningToggle,
  required ValueChanged<String> onReasoningEffortChange,
}) {
  var localEnabled = reasoningEnabled;
  var localEffort = reasoningEffort;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[350],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.psychology_outlined,
                            size: 18, color: Colors.purple),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '推理设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Reasoning toggle
                  Container(
                    decoration: BoxDecoration(
                      color:
                          cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '推理',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        Switch(
                          value: localEnabled,
                          activeColor: cs.primary,
                          onChanged: (value) {
                            setState(() => localEnabled = value);
                            onReasoningToggle(value);
                          },
                        ),
                      ],
                    ),
                  ),
                  // Reasoning effort chips
                  if (localEnabled) ...[
                    const SizedBox(height: 12),
                    Text(
                      '推理强度',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _EffortChip(
                          label: '低',
                          value: 'low',
                          selected: localEffort == 'low',
                          onSelected: () {
                            setState(() => localEffort = 'low');
                            onReasoningEffortChange('low');
                          },
                        ),
                        const SizedBox(width: 8),
                        _EffortChip(
                          label: '中',
                          value: 'medium',
                          selected: localEffort == 'medium',
                          onSelected: () {
                            setState(() => localEffort = 'medium');
                            onReasoningEffortChange('medium');
                          },
                        ),
                        const SizedBox(width: 8),
                        _EffortChip(
                          label: '高',
                          value: 'high',
                          selected: localEffort == 'high',
                          onSelected: () {
                            setState(() => localEffort = 'high');
                            onReasoningEffortChange('high');
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// A chip/button for selecting reasoning effort level.
class _EffortChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  const _EffortChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? cs.onPrimaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _effortDescription(value),
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? cs.onPrimaryContainer.withOpacity(0.7)
                      : cs.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _effortDescription(String level) {
    switch (level) {
      case 'low':
        return '快速响应';
      case 'medium':
        return '平衡';
      case 'high':
        return '深度思考';
      default:
        return '';
    }
  }
}
