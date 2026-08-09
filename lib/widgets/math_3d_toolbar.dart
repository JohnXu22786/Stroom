import 'package:flutter/material.dart';

import '../models/math_3d_tool.dart';

/// A toolbox-style toolbar for 3D construction tools, mirroring GeoGebra:
/// tools are grouped into toolboxes; tapping a toolbox icon shows its
/// member tools; the active tool is highlighted and the toolbox collapses
/// back to the selected tool.
class Math3DToolbar extends StatelessWidget {
  final ConstructionTool activeTool;
  final String? instruction;
  final ValueChanged<ConstructionTool> onToolSelected;

  const Math3DToolbar({
    super.key,
    required this.activeTool,
    this.instruction,
    required this.onToolSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                for (int g = 0; g < ToolInfo.groups.length; g++) ...[
                  if (g > 0) _separator(cs),
                  _ToolboxButton(
                    tools: ToolInfo.groups[g],
                    activeTool: activeTool,
                    onSelected: onToolSelected,
                  ),
                ],
              ],
            ),
          ),
          // Instruction bar (when a construction tool is active).
          if (instruction != null && instruction!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: cs.primaryContainer.withValues(alpha: 0.35),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      instruction!,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                  // Cancel button.
                  GestureDetector(
                    onTap: () => onToolSelected(ConstructionTool.move),
                    child: Icon(Icons.close, size: 16, color: cs.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _separator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(width: 1, height: 26, color: cs.outlineVariant),
    );
  }
}

/// One toolbox button: shows the active tool of the group; tapping opens a
/// popup with all tools of the group.
class _ToolboxButton extends StatelessWidget {
  final List<ConstructionTool> tools;
  final ConstructionTool activeTool;
  final ValueChanged<ConstructionTool> onSelected;

  const _ToolboxButton({
    required this.tools,
    required this.activeTool,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isInGroup = tools.contains(activeTool);
    final activeInfo = ToolInfo.all[isInGroup ? activeTool : tools.first]!;

    return PopupMenuButton<ConstructionTool>(
      tooltip: activeInfo.name,
      initialValue: isInGroup ? activeTool : null,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final t in tools)
          PopupMenuItem(
            value: t,
            child: Row(
              children: [
                Icon(ToolInfo.all[t]!.iconData, size: 18),
                const SizedBox(width: 10),
                Text(ToolInfo.all[t]!.name,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 1),
        decoration: BoxDecoration(
          color: isInGroup
              ? cs.primaryContainer.withValues(alpha: 0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(activeInfo.iconData,
                size: 20, color: isInGroup ? cs.primary : cs.onSurface),
            Icon(Icons.arrow_drop_down, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
