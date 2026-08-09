import 'package:flutter/material.dart';

import '../models/math_3d_scene.dart' show ProjectionType, StandardView;
import 'math_canvas_3d.dart' show PointCapturing;

/// The 3D Graphics View style bar (GeoGebra style): standard views,
/// projection type, axes / grid / xOy-plane visibility, point capturing,
/// auto-rotation and view reset.
class Math3DViewToolbar extends StatelessWidget {
  final bool showAxes;
  final bool showGrid;
  final bool showPlane;
  final bool autoRotating;
  final PointCapturing capturing;
  final ProjectionType projectionType;
  final VoidCallback onToggleAxes;
  final VoidCallback onToggleGrid;
  final VoidCallback onTogglePlane;
  final VoidCallback onToggleAutoRotate;
  final VoidCallback onResetView;
  final ValueChanged<PointCapturing> onCapturingChanged;
  final ValueChanged<StandardView> onStandardView;
  final ValueChanged<ProjectionType> onProjectionChanged;

  const Math3DViewToolbar({
    super.key,
    required this.showAxes,
    required this.showGrid,
    required this.showPlane,
    required this.autoRotating,
    required this.capturing,
    required this.projectionType,
    required this.onToggleAxes,
    required this.onToggleGrid,
    required this.onTogglePlane,
    required this.onToggleAutoRotate,
    required this.onResetView,
    required this.onCapturingChanged,
    required this.onStandardView,
    required this.onProjectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ---- Standard views ----
            _PopupButton(
              icon: Icons.center_focus_strong,
              tooltip: '标准视图',
              items: const [
                ('默认视图', Icons.center_focus_strong),
                ('俯视图 (xOy)', Icons.view_quilt_outlined),
                ('正视图 (xOz)', Icons.view_column_outlined),
                ('右视图 (yOz)', Icons.view_sidebar_outlined),
              ],
              onSelect: (i) => onStandardView(StandardView.values[i]),
            ),
            _spacer(cs),
            // ---- Projection type ----
            _PopupButton(
              icon: _projectionIcon,
              tooltip: '投影类型',
              items: const [
                ('平行投影', Icons.grid_3x3),
                ('透视投影', Icons.view_in_ar),
                ('斜投影', Icons.crop_free),
                ('3D 眼镜', Icons.visibility),
              ],
              onSelect: (i) => onProjectionChanged(ProjectionType.values[i]),
            ),
            _spacer(cs),
            // ---- Axes / grid / plane toggles ----
            _toggleButton(cs,
                icon: Icons.crop_square,
                tooltip: '坐标轴',
                active: showAxes,
                onPressed: onToggleAxes),
            _toggleButton(cs,
                icon: Icons.grid_on,
                tooltip: '网格',
                active: showGrid,
                onPressed: onToggleGrid),
            _toggleButton(cs,
                icon: Icons.crop_landscape,
                tooltip: 'xOy 平面',
                active: showPlane,
                onPressed: onTogglePlane),
            _spacer(cs),
            // ---- Point capturing ----
            _PopupButton(
              icon: Icons.gps_fixed,
              tooltip: '点捕捉：$_capturingLabel',
              items: const [
                ('关闭', Icons.gps_off),
                ('自动', Icons.gps_fixed),
                ('吸附到网格', Icons.gps_not_fixed),
                ('固定到网格', Icons.push_pin_outlined),
              ],
              onSelect: (i) => onCapturingChanged(PointCapturing.values[i]),
            ),
            _spacer(cs),
            // ---- Auto-rotate ----
            _toggleButton(cs,
                icon: autoRotating ? Icons.stop : Icons.play_arrow,
                tooltip: autoRotating ? '停止自动旋转' : '自动旋转视图',
                active: autoRotating,
                onPressed: onToggleAutoRotate),
            _spacer(cs),
            // ---- Reset view ----
            _toggleButton(cs,
                icon: Icons.restart_alt,
                tooltip: '重置视图',
                active: false,
                onPressed: onResetView),
          ],
        ),
      ),
    );
  }

  IconData get _projectionIcon {
    switch (projectionType) {
      case ProjectionType.parallel:
        return Icons.grid_3x3;
      case ProjectionType.perspective:
        return Icons.view_in_ar;
      case ProjectionType.oblique:
        return Icons.crop_free;
      case ProjectionType.anaglyph:
        return Icons.visibility;
    }
  }

  String get _capturingLabel {
    switch (capturing) {
      case PointCapturing.off:
        return '关闭';
      case PointCapturing.automatic:
        return '自动';
      case PointCapturing.snapToGrid:
        return '吸附网格';
      case PointCapturing.fixedToGrid:
        return '固定网格';
    }
  }

  Widget _spacer(ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(width: 1, height: 24, color: cs.outlineVariant),
      );

  Widget _toggleButton(ColorScheme cs,
      {required IconData icon,
      required String tooltip,
      required bool active,
      required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: active ? cs.primary : cs.onSurfaceVariant,
        backgroundColor:
            active ? cs.primaryContainer.withValues(alpha: 0.35) : null,
      ),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

/// A compact popup-menu button with an icon label.
class _PopupButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final List<(String, IconData)> items;
  final ValueChanged<int> onSelect;

  const _PopupButton({
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<int>(
      tooltip: tooltip,
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (int i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(items[i].$2, size: 18),
                const SizedBox(width: 10),
                Text(items[i].$1, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: cs.onSurface),
            Icon(Icons.arrow_drop_down, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
