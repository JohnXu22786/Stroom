import 'package:flutter/material.dart';

import '../models/math_3d_tool.dart';

/// A toolbar for 3D construction tools, organized by toolbox groups.
///
/// Mimics the GeoGebra toolbar pattern: tools are grouped into toolboxes,
/// the active tool is highlighted, and a tooltip shows the current instruction.
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
          // Tool buttons
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: _buildToolGroups(cs),
            ),
          ),
          // Instruction bar (when a tool is active)
          if (instruction != null && activeTool != ConstructionTool.move)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: cs.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      instruction!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Cancel button
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

  List<Widget> _buildToolGroups(ColorScheme cs) {
    // Define the tool groups and the order they appear
    const groups = [
      [ConstructionTool.move],
      [ConstructionTool.point],
      [ConstructionTool.line],
      [ConstructionTool.polygon],
      [ConstructionTool.plane],
      [ConstructionTool.circle, ConstructionTool.sphere],
      [
        ConstructionTool.cube,
        ConstructionTool.extrudePrism,
        ConstructionTool.pyramid,
        ConstructionTool.cone,
        ConstructionTool.cylinder,
      ],
    ];

    final widgets = <Widget>[];

    for (int g = 0; g < groups.length; g++) {
      if (g > 0) {
        // Separator between groups
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            width: 1,
            height: 24,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ));
      }

      for (final tool in groups[g]) {
        final info = ToolInfo.all[tool]!;
        final isActive = tool == activeTool;
        final iconColor = isActive ? cs.primary : cs.onSurface;

        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Tooltip(
              message: '${info.name}: ${info.tooltip}',
              child: Material(
                color: isActive
                    ? cs.primaryContainer.withValues(alpha: 0.4)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onToolSelected(tool),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: Icon(
                      info.iconData,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
