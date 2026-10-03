import 'package:flutter/material.dart';

import '../models/math_3d_tool.dart';

/// A compact, named toolbox: groups stay visible while tools scroll on phones.
class Math3DToolbar extends StatefulWidget {
  final ConstructionTool activeTool;
  final String? instruction;
  final ValueChanged<ConstructionTool> onToolSelected;
  final int polygonSides;
  final ValueChanged<int>? onPolygonSidesChanged;

  const Math3DToolbar({
    super.key,
    required this.activeTool,
    this.instruction,
    required this.onToolSelected,
    this.polygonSides = 6,
    this.onPolygonSidesChanged,
  });

  @override
  State<Math3DToolbar> createState() => _Math3DToolbarState();
}

class _Math3DToolbarState extends State<Math3DToolbar> {
  late ToolGroup _group = ToolInfo.all[widget.activeTool]!.group;

  @override
  void didUpdateWidget(Math3DToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTool != widget.activeTool) {
      _group = ToolInfo.all[widget.activeTool]!.group;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = ToolInfo.all[widget.activeTool]!;
    return Material(
      color: cs.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final group in ToolGroup.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(group.label),
                      selected: _group == group,
                      onSelected: (_) => setState(() => _group = group),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                for (final info in ToolInfo.all.values
                    .where((info) => info.group == _group))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tooltip(
                      message: info.tooltip,
                      child: Semantics(
                        selected: info.tool == widget.activeTool,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(80, 64),
                            foregroundColor: info.tool == widget.activeTool
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                            backgroundColor: info.tool == widget.activeTool
                                ? cs.primaryContainer
                                : cs.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => widget.onToolSelected(info.tool),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(info.iconData, size: 24),
                              const SizedBox(height: 4),
                              Text(info.name),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.activeTool == ConstructionTool.regularPolygon)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('边数：'),
                DropdownButton<int>(
                  value: widget.polygonSides,
                  items: [
                    for (var n = 3; n <= 12; n++)
                      DropdownMenuItem(value: n, child: Text('$n'))
                  ],
                  onChanged: (value) {
                    if (value != null)
                      widget.onPolygonSidesChanged?.call(value);
                  },
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${active.name} · ${widget.instruction?.isNotEmpty == true ? widget.instruction : active.tooltip}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
                if (widget.activeTool != ConstructionTool.move)
                  IconButton(
                    tooltip: '结束构造，返回选择',
                    onPressed: () =>
                        widget.onToolSelected(ConstructionTool.move),
                    icon: const Icon(Icons.close, size: 20),
                  )
                else
                  const SizedBox(width: 12, height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
