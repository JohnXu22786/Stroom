import 'package:flutter/material.dart';

/// Types of 3D construction tools.
///
/// Each tool represents a construction mode in the 3D view.
/// The [ConstructionTool.move] is the default navigation mode;
/// all others create objects when the user clicks in the 3D view.
enum ConstructionTool {
  /// Default mode: orbit/pan/zoom the view, move existing objects.
  move,

  /// Place a free 3D point.
  point,
  midpoint,
  segment,
  ray,
  vector,
  circleThreePoints,
  regularPolygon,
  tetrahedron,

  /// Create a line through two points.
  line,

  /// Create a polygon by clicking vertices and closing.
  polygon,

  /// Create a plane through three non-collinear points.
  plane,

  /// Create a sphere from center + point on surface.
  sphere,

  /// Create a circle in 3D.
  circle,

  /// Create a cube from two base points.
  cube,

  /// Extrude a polygon to a prism.
  extrudePrism,

  /// Create a cone (base circle + apex).
  cone,

  /// Create a cylinder (base circle + top).
  cylinder,

  /// Create a pyramid (base polygon + apex).
  pyramid,
}

/// Named groups shared by the toolbar and tool metadata.
enum ToolGroup {
  points('点与选择'),
  lines('线与向量'),
  planes('平面与圆'),
  solids('立体图形');

  const ToolGroup(this.label);
  final String label;
}

class ToolInfo {
  final ConstructionTool tool;
  final String name;
  final IconData iconData;
  final String tooltip;
  final ToolGroup group;

  const ToolInfo({
    required this.tool,
    required this.name,
    required this.iconData,
    required this.tooltip,
    required this.group,
  });

  static const Map<ConstructionTool, ToolInfo> all = {
    ConstructionTool.move: ToolInfo(
      tool: ConstructionTool.move,
      name: '选择与移动',
      iconData: Icons.near_me_outlined,
      tooltip: '拖动点调整位置；再次点击选中的点切换平面 / 高度；空白处拖动旋转视角',
      group: ToolGroup.points,
    ),
    ConstructionTool.point: ToolInfo(
      tool: ConstructionTool.point,
      name: '自由点',
      iconData: Icons.add_location_alt_outlined,
      tooltip: '点击在 z=0 新建点，向上拖动调高；再次点击选中点切换移动方式',
      group: ToolGroup.points,
    ),
    ConstructionTool.midpoint: ToolInfo(
      tool: ConstructionTool.midpoint,
      name: '中点',
      iconData: Icons.linear_scale,
      tooltip: '选择两个不同的点，创建它们的中点',
      group: ToolGroup.points,
    ),
    ConstructionTool.segment: ToolInfo(
      tool: ConstructionTool.segment,
      name: '线段',
      iconData: Icons.horizontal_rule,
      tooltip: '选择两个端点，创建有限线段',
      group: ToolGroup.lines,
    ),
    ConstructionTool.line: ToolInfo(
      tool: ConstructionTool.line,
      name: '直线',
      iconData: Icons.timeline,
      tooltip: '选择两个点，创建向两端延伸的直线',
      group: ToolGroup.lines,
    ),
    ConstructionTool.ray: ToolInfo(
      tool: ConstructionTool.ray,
      name: '射线',
      iconData: Icons.trending_flat,
      tooltip: '选择起点，再选择方向点',
      group: ToolGroup.lines,
    ),
    ConstructionTool.vector: ToolInfo(
      tool: ConstructionTool.vector,
      name: '向量',
      iconData: Icons.north_east,
      tooltip: '选择起点和终点，创建有方向的向量',
      group: ToolGroup.lines,
    ),
    ConstructionTool.polygon: ToolInfo(
      tool: ConstructionTool.polygon,
      name: '多边形',
      iconData: Icons.polyline_outlined,
      tooltip: '依次选择顶点，再点击首个顶点闭合',
      group: ToolGroup.planes,
    ),
    ConstructionTool.regularPolygon: ToolInfo(
      tool: ConstructionTool.regularPolygon,
      name: '正多边形',
      iconData: Icons.hexagon_outlined,
      tooltip: '设置边数，再选择一条边的两个端点',
      group: ToolGroup.planes,
    ),
    ConstructionTool.plane: ToolInfo(
      tool: ConstructionTool.plane,
      name: '三点平面',
      iconData: Icons.layers_outlined,
      tooltip: '选择三个不共线的点',
      group: ToolGroup.planes,
    ),
    ConstructionTool.circle: ToolInfo(
      tool: ConstructionTool.circle,
      name: '圆（圆心与点）',
      iconData: Icons.circle_outlined,
      tooltip: '选择圆心，再选择圆周上的点',
      group: ToolGroup.planes,
    ),
    ConstructionTool.circleThreePoints: ToolInfo(
      tool: ConstructionTool.circleThreePoints,
      name: '三点圆',
      iconData: Icons.motion_photos_on_outlined,
      tooltip: '选择三个不共线的点，创建经过它们的圆',
      group: ToolGroup.planes,
    ),
    ConstructionTool.cube: ToolInfo(
      tool: ConstructionTool.cube,
      name: '正六面体',
      iconData: Icons.view_in_ar_outlined,
      tooltip: '选择一条棱的两个端点',
      group: ToolGroup.solids,
    ),
    ConstructionTool.tetrahedron: ToolInfo(
      tool: ConstructionTool.tetrahedron,
      name: '正四面体',
      iconData: Icons.change_history_outlined,
      tooltip: '选择一条棱的两个端点，创建六条等长棱',
      group: ToolGroup.solids,
    ),
    ConstructionTool.sphere: ToolInfo(
      tool: ConstructionTool.sphere,
      name: '球体',
      iconData: Icons.public,
      tooltip: '选择球心，再选择球面上的点',
      group: ToolGroup.solids,
    ),
    ConstructionTool.extrudePrism: ToolInfo(
      tool: ConstructionTool.extrudePrism,
      name: '三棱柱',
      iconData: Icons.account_tree_outlined,
      tooltip: '选择底面三个顶点，再设置垂直高度',
      group: ToolGroup.solids,
    ),
    ConstructionTool.pyramid: ToolInfo(
      tool: ConstructionTool.pyramid,
      name: '三棱锥',
      iconData: Icons.details_outlined,
      tooltip: '选择底面三个顶点，再选择顶点',
      group: ToolGroup.solids,
    ),
    ConstructionTool.cone: ToolInfo(
      tool: ConstructionTool.cone,
      name: '圆锥',
      iconData: Icons.signal_cellular_4_bar,
      tooltip: '选择底面圆心、半径点，再选择顶点',
      group: ToolGroup.solids,
    ),
    ConstructionTool.cylinder: ToolInfo(
      tool: ConstructionTool.cylinder,
      name: '圆柱',
      iconData: Icons.storage_outlined,
      tooltip: '选择底面圆心、半径点，再选择顶面圆心',
      group: ToolGroup.solids,
    ),
  };
}

/// Describes what the user should do next during construction.
class ConstructionStep {
  final String instruction;
  final String instructionEn;
  final int clickCount; // how many clicks this step needs

  const ConstructionStep({
    required this.instruction,
    required this.instructionEn,
    this.clickCount = 1,
  });
}

/// The construction workflow for each tool — the sequence of steps
/// the user must perform to create the object.
class ConstructionWorkflow {
  final ConstructionTool tool;
  final List<ConstructionStep> steps;

  const ConstructionWorkflow({required this.tool, required this.steps});

  static const Map<ConstructionTool, ConstructionWorkflow> workflows = {
    ConstructionTool.midpoint: ConstructionWorkflow(
      tool: ConstructionTool.midpoint,
      steps: [
        ConstructionStep(
            instruction: '选择或创建第一个点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择或创建第二个点', instructionEn: 'Select point 2'),
      ],
    ),
    ConstructionTool.segment: ConstructionWorkflow(
      tool: ConstructionTool.segment,
      steps: [
        ConstructionStep(
            instruction: '选择线段的第一个端点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择线段的第二个端点', instructionEn: 'Select point 2'),
      ],
    ),
    ConstructionTool.ray: ConstructionWorkflow(
      tool: ConstructionTool.ray,
      steps: [
        ConstructionStep(
            instruction: '选择射线起点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择射线方向点', instructionEn: 'Select point 2'),
      ],
    ),
    ConstructionTool.vector: ConstructionWorkflow(
      tool: ConstructionTool.vector,
      steps: [
        ConstructionStep(
            instruction: '选择向量起点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择向量终点', instructionEn: 'Select point 2'),
      ],
    ),
    ConstructionTool.circleThreePoints: ConstructionWorkflow(
      tool: ConstructionTool.circleThreePoints,
      steps: [
        ConstructionStep(
            instruction: '选择圆上的第一个点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择圆上的第二个点', instructionEn: 'Select point 2'),
        ConstructionStep(
            instruction: '选择圆上的第三个点（不能共线）', instructionEn: 'Select point 3'),
      ],
    ),
    ConstructionTool.regularPolygon: ConstructionWorkflow(
      tool: ConstructionTool.regularPolygon,
      steps: [
        ConstructionStep(
            instruction: '选择一条边的第一个端点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择一条边的第二个端点', instructionEn: 'Select point 2'),
      ],
    ),
    ConstructionTool.tetrahedron: ConstructionWorkflow(
      tool: ConstructionTool.tetrahedron,
      steps: [
        ConstructionStep(
            instruction: '选择一条棱的第一个端点', instructionEn: 'Select point 1'),
        ConstructionStep(
            instruction: '选择一条棱的第二个端点', instructionEn: 'Select point 2'),
      ],
    ),
    ConstructionTool.point: ConstructionWorkflow(
      tool: ConstructionTool.point,
      steps: [
        ConstructionStep(
          instruction: '点击在 z=0 放置点；向上拖动调高；点击选中点切换平面 / 高度',
          instructionEn:
              'Place on z=0; drag up for height; tap a selected point to switch mode',
          clickCount: 1,
        ),
      ],
    ),
    ConstructionTool.line: ConstructionWorkflow(
      tool: ConstructionTool.line,
      steps: [
        ConstructionStep(
          instruction: '选择或创建第一个点',
          instructionEn: 'Select or create the first point',
        ),
        ConstructionStep(
          instruction: '选择或创建第二个点',
          instructionEn: 'Select or create the second point',
        ),
      ],
    ),
    ConstructionTool.polygon: ConstructionWorkflow(
      tool: ConstructionTool.polygon,
      steps: [
        ConstructionStep(
          instruction: '点击第1个顶点',
          instructionEn: 'Click vertex 1',
        ),
        ConstructionStep(
          instruction: '点击第2个顶点',
          instructionEn: 'Click vertex 2',
        ),
        ConstructionStep(
          instruction: '点击更多顶点，然后点击第1个顶点闭合',
          instructionEn: 'Click more vertices, then click the first to close',
          clickCount: 0, // variable
        ),
      ],
    ),
    ConstructionTool.plane: ConstructionWorkflow(
      tool: ConstructionTool.plane,
      steps: [
        ConstructionStep(
          instruction: '选择或创建第一个点',
          instructionEn: 'Select or create point 1',
        ),
        ConstructionStep(
          instruction: '选择或创建第二个点',
          instructionEn: 'Select or create point 2',
        ),
        ConstructionStep(
          instruction: '选择或创建第三个点',
          instructionEn: 'Select or create point 3',
        ),
      ],
    ),
    ConstructionTool.sphere: ConstructionWorkflow(
      tool: ConstructionTool.sphere,
      steps: [
        ConstructionStep(
          instruction: '点击球心位置',
          instructionEn: 'Click the center point',
        ),
        ConstructionStep(
          instruction: '点击球面上一点确定半径',
          instructionEn: 'Click a point on the sphere surface',
        ),
      ],
    ),
    ConstructionTool.circle: ConstructionWorkflow(
      tool: ConstructionTool.circle,
      steps: [
        ConstructionStep(
          instruction: '点击圆心位置',
          instructionEn: 'Click the center point',
        ),
        ConstructionStep(
          instruction: '点击圆周上一点确定半径',
          instructionEn: 'Click a point on the circumference',
        ),
      ],
    ),
    ConstructionTool.cube: ConstructionWorkflow(
      tool: ConstructionTool.cube,
      steps: [
        ConstructionStep(
          instruction: '点击底面棱边的第一个端点',
          instructionEn: 'Click first endpoint of base edge',
        ),
        ConstructionStep(
          instruction: '点击底面棱边的第二个端点',
          instructionEn: 'Click second endpoint of base edge',
        ),
      ],
    ),
    ConstructionTool.extrudePrism: ConstructionWorkflow(
      tool: ConstructionTool.extrudePrism,
      steps: [
        ConstructionStep(
          instruction: '选择三角形底面的第一个顶点',
          instructionEn: 'Select the first base vertex',
        ),
        ConstructionStep(
          instruction: '选择三角形底面的第二个顶点',
          instructionEn: 'Select the second base vertex',
        ),
        ConstructionStep(
          instruction: '选择三角形底面的第三个顶点',
          instructionEn: 'Select the third base vertex',
        ),
        ConstructionStep(
          instruction: '点击或拖拽设置垂直高度',
          instructionEn: 'Click or drag to set perpendicular height',
        ),
      ],
    ),
    ConstructionTool.cone: ConstructionWorkflow(
      tool: ConstructionTool.cone,
      steps: [
        ConstructionStep(
          instruction: '点击底面圆心',
          instructionEn: 'Click base center point',
        ),
        ConstructionStep(
          instruction: '点击底面圆周上一点确定半径',
          instructionEn: 'Click a point on the base circle',
        ),
        ConstructionStep(
          instruction: '点击顶点确定方向和高度',
          instructionEn: 'Click the apex to set direction and height',
        ),
      ],
    ),
    ConstructionTool.cylinder: ConstructionWorkflow(
      tool: ConstructionTool.cylinder,
      steps: [
        ConstructionStep(
          instruction: '点击底面圆心',
          instructionEn: 'Click base center',
        ),
        ConstructionStep(
          instruction: '点击底面圆周上一点确定半径',
          instructionEn: 'Click a point on the base circle',
        ),
        ConstructionStep(
          instruction: '点击顶面圆心确定方向和高度',
          instructionEn: 'Click the top center to set direction and height',
        ),
      ],
    ),
    ConstructionTool.pyramid: ConstructionWorkflow(
      tool: ConstructionTool.pyramid,
      steps: [
        ConstructionStep(
          instruction: '选择三角形底面的第一个顶点',
          instructionEn: 'Select the first base vertex',
        ),
        ConstructionStep(
          instruction: '选择三角形底面的第二个顶点',
          instructionEn: 'Select the second base vertex',
        ),
        ConstructionStep(
          instruction: '选择三角形底面的第三个顶点',
          instructionEn: 'Select the third base vertex',
        ),
        ConstructionStep(
          instruction: '点击棱锥顶点',
          instructionEn: 'Click the pyramid apex',
        ),
      ],
    ),
  };
}
