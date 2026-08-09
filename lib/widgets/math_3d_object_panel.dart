import 'package:flutter/material.dart';

import '../models/math_3d_object.dart';

/// Object list panel (GeoGebra Algebra View style): shows every scene object
/// with its name, color, visibility toggle and delete button. Tapping a row
/// selects the object in the canvas.
class Math3DObjectPanel extends StatelessWidget {
  final List<Object3D> objects;
  final Object3D? selected;
  final ValueChanged<Object3D> onSelect;
  final ValueChanged<Object3D> onToggleVisible;
  final ValueChanged<Object3D> onDelete;

  const Math3DObjectPanel({
    super.key,
    required this.objects,
    required this.selected,
    required this.onSelect,
    required this.onToggleVisible,
    required this.onDelete,
  });

  static const Map<Object3DType, IconData> _typeIcons = {
    Object3DType.point: Icons.fiber_manual_record,
    Object3DType.segment: Icons.remove,
    Object3DType.line: Icons.horizontal_rule,
    Object3DType.ray: Icons.trending_flat,
    Object3DType.vector: Icons.north_east,
    Object3DType.circle: Icons.radio_button_unchecked,
    Object3DType.arc: Icons.circle,
    Object3DType.polygon: Icons.star,
    Object3DType.polyhedron: Icons.view_in_ar,
    Object3DType.sphere: Icons.language,
    Object3DType.cone: Icons.expand_less,
    Object3DType.cylinder: Icons.wifi_tethering,
    Object3DType.plane: Icons.crop_square,
    Object3DType.surface: Icons.waves,
    Object3DType.curve: Icons.timeline,
    Object3DType.measurement: Icons.straighten,
  };

  static String _typeName(Object3DType t) {
    switch (t) {
      case Object3DType.point:
        return '点';
      case Object3DType.segment:
        return '线段';
      case Object3DType.line:
        return '直线';
      case Object3DType.ray:
        return '射线';
      case Object3DType.vector:
        return '向量';
      case Object3DType.circle:
        return '圆';
      case Object3DType.arc:
        return '圆弧';
      case Object3DType.polygon:
        return '多边形';
      case Object3DType.polyhedron:
        return '多面体';
      case Object3DType.sphere:
        return '球';
      case Object3DType.cone:
        return '圆锥';
      case Object3DType.cylinder:
        return '圆柱';
      case Object3DType.plane:
        return '平面';
      case Object3DType.surface:
        return '曲面';
      case Object3DType.curve:
        return '曲线';
      case Object3DType.measurement:
        return '测量';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('对象列表 (${objects.length})',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: objects.isEmpty
                ? Center(
                    child: Text('暂无对象\n使用工具或输入表达式创建',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  )
                : ListView.builder(
                    itemCount: objects.length,
                    itemBuilder: (context, index) {
                      final obj = objects[index];
                      final isSelected = identical(obj, selected);
                      return InkWell(
                        onTap: () => onSelect(obj),
                        child: Container(
                          color: isSelected
                              ? cs.primaryContainer.withValues(alpha: 0.4)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              // Color dot (opacity applied once).
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Color(obj.style.color)
                                      .withValues(alpha: obj.style.opacity),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(_typeIcons[obj.type],
                                  size: 15, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(obj.name,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                    Text(_typeName(obj.type),
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onSurfaceVariant),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  obj.visible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 16,
                                  color:
                                      obj.visible ? cs.onSurface : cs.outline,
                                ),
                                tooltip: obj.visible ? '隐藏' : '显示',
                                onPressed: () => onToggleVisible(obj),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                    maxWidth: 28,
                                    maxHeight: 28),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 16,
                                    color: cs.error.withValues(alpha: 0.8)),
                                tooltip: '删除',
                                onPressed: () => onDelete(obj),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                    maxWidth: 28,
                                    maxHeight: 28),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
