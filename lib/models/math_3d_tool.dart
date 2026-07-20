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

/// 构造工具的元数据（中文）
class ToolInfo {
  final ConstructionTool tool;
  final String name;
  final IconData iconData;
  final String tooltip;
  final int group; // 所属工具组 (0-9)

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
      name: '移动',
      iconData: Icons.pan_tool,
      tooltip: '拖拽旋转视图',
      group: 0,
    ),
    ConstructionTool.point: ToolInfo(
      tool: ConstructionTool.point,
      name: '点',
      iconData: Icons.fiber_manual_record,
      tooltip: '点击放置点（按住拖拽调整高度）',
      group: 1,
    ),
    ConstructionTool.line: ToolInfo(
      tool: ConstructionTool.line,
      name: '直线',
      iconData: Icons.timeline,
      tooltip: '点击两个点创建直线',
      group: 2,
    ),
    ConstructionTool.polygon: ToolInfo(
      tool: ConstructionTool.polygon,
      name: '多边形',
      iconData: Icons.star,
      tooltip: '依次点击顶点，再点第一个顶点闭合',
      group: 3,
    ),
    ConstructionTool.plane: ToolInfo(
      tool: ConstructionTool.plane,
      name: '平面',
      iconData: Icons.crop_square,
      tooltip: '点击三个不共线点创建平面',
      group: 4,
    ),
    ConstructionTool.sphere: ToolInfo(
      tool: ConstructionTool.sphere,
      name: '球体',
      iconData: Icons.language,
      tooltip: '点击球心，再点击球面点',
      group: 5,
    ),
    ConstructionTool.circle: ToolInfo(
      tool: ConstructionTool.circle,
      name: '圆',
      iconData: Icons.radio_button_unchecked,
      tooltip: '点击圆心，再点击圆周上一点',
      group: 5,
    ),
    ConstructionTool.cube: ToolInfo(
      tool: ConstructionTool.cube,
      name: '立方体',
      iconData: Icons.view_in_ar,
      tooltip: '点击两个点作为底面棱边',
      group: 6,
    ),
    ConstructionTool.extrudePrism: ToolInfo(
      tool: ConstructionTool.extrudePrism,
      name: '拉伸棱柱',
      iconData: Icons.layers,
      tooltip: '点击多边形底面，拖拽或输入高度',
      group: 6,
    ),
    ConstructionTool.cone: ToolInfo(
      tool: ConstructionTool.cone,
      name: '圆锥',
      iconData: Icons.expand_less,
      tooltip: '点击底面圆心，再点击顶点',
      group: 6,
    ),
    ConstructionTool.cylinder: ToolInfo(
      tool: ConstructionTool.cylinder,
      name: '圆柱',
      iconData: Icons.wifi_tethering,
      tooltip: '点击底面圆心，再点击顶面圆心',
      group: 6,
    ),
    ConstructionTool.pyramid: ToolInfo(
      tool: ConstructionTool.pyramid,
      name: '棱锥',
      iconData: Icons.change_history,
      tooltip: '点击多边形底面，再点击顶点',
      group: 6,
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

  const ConstructionWorkflow({
    required this.tool,
    required this.steps,
  });

  static const Map<ConstructionTool, ConstructionWorkflow> workflows = {
    ConstructionTool.point: ConstructionWorkflow(
      tool: ConstructionTool.point,
      steps: [
        ConstructionStep(
          instruction: '点击放置点（按住拖拽调整z坐标）',
          instructionEn: 'Click to place point (drag to adjust z)',
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
          instruction: '选择要拉伸的多边形',
          instructionEn: 'Select a polygon to extrude',
        ),
        ConstructionStep(
          instruction: '点击或拖拽设置高度',
          instructionEn: 'Click/drag to set height',
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
          instruction: '点击顶点确定高度',
          instructionEn: 'Click apex to set height',
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
          instruction: '点击顶面圆心确定高度',
          instructionEn: 'Click top center to set height',
        ),
      ],
    ),
    ConstructionTool.pyramid: ConstructionWorkflow(
      tool: ConstructionTool.pyramid,
      steps: [
        ConstructionStep(
          instruction: '选择多边形底面',
          instructionEn: 'Select a polygon base',
        ),
        ConstructionStep(
          instruction: '点击顶点确定高度',
          instructionEn: 'Click apex to set height',
        ),
      ],
    ),
  };
}
