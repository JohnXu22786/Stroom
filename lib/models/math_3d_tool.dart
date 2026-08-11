import 'package:flutter/material.dart';

import 'math_3d_object.dart';

/// Types of 3D construction tools.
///
/// Each tool represents a construction mode in the 3D view, grouped into
/// toolboxes mirroring the GeoGebra 3D toolbar structure.
enum ConstructionTool {
  // --- Movement -------------------------------------------------------
  /// Default mode: rotate the view, select and move objects.
  move,

  // --- Point ----------------------------------------------------------
  point,
  midpoint,
  intersect,

  // --- Line -----------------------------------------------------------
  line,
  segment,
  ray,
  vector,
  perpendicularLine,
  parallelLine,

  // --- Polygon --------------------------------------------------------
  polygon,
  regularPolygon,

  // --- Circle / Arc ---------------------------------------------------
  circleCenterPoint,
  circleCenterRadius,
  circle3Points,
  arc,

  // --- Plane ----------------------------------------------------------
  plane3Points,

  // --- Geometric solids ----------------------------------------------
  pyramid,
  prism,
  extrudePrism,
  extrudePyramid,
  cone,
  cylinder,
  tetrahedron,
  cube,

  // --- Sphere ---------------------------------------------------------
  sphereCenterPoint,
  sphereCenterRadius,

  // --- Measurement ----------------------------------------------------
  distance,
  angle,
  area,
  volume,

  // --- Transformation -------------------------------------------------
  translate,
  reflectPoint,
  reflectPlane,
  rotateLine,
  dilate,

  // --- General --------------------------------------------------------
  delete,
  showHide,
}

/// What kind of input a construction step expects.
enum InputKind {
  /// A point: clicking empty space creates a new free point, clicking an
  /// existing object snaps onto it.
  point,

  /// An existing object of one of [allowedTypes] (or any, if null).
  object,

  /// A numeric value entered in a dialog.
  number,
}

/// One step of a tool's construction workflow.
class ToolStep {
  final String instruction;
  final InputKind kind;
  final Set<Object3DType>? allowedTypes;

  const ToolStep(
    this.instruction, {
    this.kind = InputKind.point,
    this.allowedTypes,
  });
}

/// Tool metadata (Chinese UI).
class ToolInfo {
  final ConstructionTool tool;
  final String name;
  final IconData iconData;
  final String tooltip;
  final int group; // toolbox group id
  final List<ToolStep> steps;
  final bool isObjectTool; // accepts objects as primary input

  const ToolInfo({
    required this.tool,
    required this.name,
    required this.iconData,
    required this.tooltip,
    required this.group,
    required this.steps,
    this.isObjectTool = false,
  });

  static const Map<ConstructionTool, ToolInfo> all = {
    // ---- Movement ----
    ConstructionTool.move: ToolInfo(
      tool: ConstructionTool.move,
      name: '移动',
      iconData: Icons.pan_tool_alt,
      tooltip: '拖拽旋转视图，选中并拖动对象',
      group: 0,
      steps: [],
    ),

    // ---- Point ----
    ConstructionTool.point: ToolInfo(
      tool: ConstructionTool.point,
      name: '点',
      iconData: Icons.fiber_manual_record,
      tooltip: '点击放置点（按住拖拽调整高度）',
      group: 1,
      steps: [ToolStep('点击放置点（按住拖拽可调整 z 坐标）')],
    ),
    ConstructionTool.midpoint: ToolInfo(
      tool: ConstructionTool.midpoint,
      name: '中点',
      iconData: Icons.brightness_1_outlined,
      tooltip: '取两点或线段的中点',
      group: 1,
      steps: [
        ToolStep('选择线段或两个点', kind: InputKind.object, allowedTypes: {
          Object3DType.segment,
          Object3DType.line,
          Object3DType.curve,
        }),
      ],
    ),
    ConstructionTool.intersect: ToolInfo(
      tool: ConstructionTool.intersect,
      name: '交点',
      iconData: Icons.circle_outlined,
      tooltip: '求两个对象的交点',
      group: 1,
      steps: [
        ToolStep('选择第一个对象（线/平面/球/圆）', kind: InputKind.object, allowedTypes: {
          Object3DType.line,
          Object3DType.ray,
          Object3DType.segment,
          Object3DType.plane,
          Object3DType.sphere,
          Object3DType.circle,
        }),
        ToolStep('选择第二个对象', kind: InputKind.object, allowedTypes: {
          Object3DType.line,
          Object3DType.ray,
          Object3DType.segment,
          Object3DType.plane,
          Object3DType.sphere,
          Object3DType.circle,
        }),
      ],
      isObjectTool: true,
    ),

    // ---- Line ----
    ConstructionTool.line: ToolInfo(
      tool: ConstructionTool.line,
      name: '直线',
      iconData: Icons.horizontal_rule,
      tooltip: '过两个点创建直线',
      group: 2,
      steps: [
        ToolStep('选择或创建第一个点'),
        ToolStep('选择或创建第二个点'),
      ],
    ),
    ConstructionTool.segment: ToolInfo(
      tool: ConstructionTool.segment,
      name: '线段',
      iconData: Icons.remove,
      tooltip: '连接两个点创建线段',
      group: 2,
      steps: [
        ToolStep('选择或创建第一个点'),
        ToolStep('选择或创建第二个点'),
      ],
    ),
    ConstructionTool.ray: ToolInfo(
      tool: ConstructionTool.ray,
      name: '射线',
      iconData: Icons.trending_flat,
      tooltip: '从第一个点出发过第二个点创建射线',
      group: 2,
      steps: [
        ToolStep('选择或创建起点'),
        ToolStep('选择或创建射线经过的点'),
      ],
    ),
    ConstructionTool.vector: ToolInfo(
      tool: ConstructionTool.vector,
      name: '向量',
      iconData: Icons.north_east,
      tooltip: '从第一个点指向第二个点的向量',
      group: 2,
      steps: [
        ToolStep('选择或创建起点'),
        ToolStep('选择或创建终点'),
      ],
    ),
    ConstructionTool.perpendicularLine: ToolInfo(
      tool: ConstructionTool.perpendicularLine,
      name: '垂线',
      iconData: Icons.tune,
      tooltip: '过点作已知直线的垂线',
      group: 2,
      steps: [
        ToolStep('选择直线或线段', kind: InputKind.object, allowedTypes: {
          Object3DType.line,
          Object3DType.segment,
          Object3DType.ray
        }),
        ToolStep('选择垂线经过的点'),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.parallelLine: ToolInfo(
      tool: ConstructionTool.parallelLine,
      name: '平行线',
      iconData: Icons.drag_indicator,
      tooltip: '过点作已知直线的平行线',
      group: 2,
      steps: [
        ToolStep('选择直线或线段', kind: InputKind.object, allowedTypes: {
          Object3DType.line,
          Object3DType.segment,
          Object3DType.ray
        }),
        ToolStep('选择平行线经过的点'),
      ],
      isObjectTool: true,
    ),

    // ---- Polygon ----
    ConstructionTool.polygon: ToolInfo(
      tool: ConstructionTool.polygon,
      name: '多边形',
      iconData: Icons.star,
      tooltip: '依次点击顶点，再点击第一个顶点闭合',
      group: 3,
      steps: [
        ToolStep('点击第 1 个顶点'),
        ToolStep('点击第 2 个顶点'),
        ToolStep('点击更多顶点，然后点击第 1 个顶点闭合'),
      ],
    ),
    ConstructionTool.regularPolygon: ToolInfo(
      tool: ConstructionTool.regularPolygon,
      name: '正多边形',
      iconData: Icons.star_border,
      tooltip: '选择两个点作为一条边，输入边数',
      group: 3,
      steps: [
        ToolStep('选择或创建第一个点'),
        ToolStep('选择或创建第二个点'),
        ToolStep('输入边数（3-20）', kind: InputKind.number),
      ],
    ),

    // ---- Circle / Arc ----
    ConstructionTool.circleCenterPoint: ToolInfo(
      tool: ConstructionTool.circleCenterPoint,
      name: '圆（圆心+点）',
      iconData: Icons.radio_button_unchecked,
      tooltip: '以圆心和圆周上一点创建圆',
      group: 4,
      steps: [
        ToolStep('点击圆心位置'),
        ToolStep('点击圆周上一点确定半径'),
      ],
    ),
    ConstructionTool.circleCenterRadius: ToolInfo(
      tool: ConstructionTool.circleCenterRadius,
      name: '圆（圆心+半径）',
      iconData: Icons.adjust,
      tooltip: '以圆心和半径数值创建圆',
      group: 4,
      steps: [
        ToolStep('点击圆心位置'),
        ToolStep('输入半径', kind: InputKind.number),
      ],
    ),
    ConstructionTool.circle3Points: ToolInfo(
      tool: ConstructionTool.circle3Points,
      name: '三点画圆',
      iconData: Icons.change_history,
      tooltip: '过三个不共线点创建圆',
      group: 4,
      steps: [
        ToolStep('点击第一个点'),
        ToolStep('点击第二个点'),
        ToolStep('点击第三个点'),
      ],
    ),
    ConstructionTool.arc: ToolInfo(
      tool: ConstructionTool.arc,
      name: '圆弧',
      iconData: Icons.circle,
      tooltip: '经过三个点创建圆弧',
      group: 4,
      steps: [
        ToolStep('点击弧的起点'),
        ToolStep('点击弧经过的点'),
        ToolStep('点击弧的终点'),
      ],
    ),

    // ---- Plane ----
    ConstructionTool.plane3Points: ToolInfo(
      tool: ConstructionTool.plane3Points,
      name: '平面（三点）',
      iconData: Icons.crop_square,
      tooltip: '过三个不共线点创建平面',
      group: 5,
      steps: [
        ToolStep('点击第一个点'),
        ToolStep('点击第二个点'),
        ToolStep('点击第三个点'),
      ],
    ),

    // ---- Solids ----
    ConstructionTool.pyramid: ToolInfo(
      tool: ConstructionTool.pyramid,
      name: '棱锥',
      iconData: Icons.change_history,
      tooltip: '先点击底面多边形顶点，再点击顶点',
      group: 6,
      steps: [
        ToolStep('点击底面第 1 个顶点'),
        ToolStep('点击底面第 2 个顶点'),
        ToolStep('点击底面更多顶点，然后点击第 1 个顶点闭合'),
        ToolStep('点击棱锥顶点'),
      ],
    ),
    ConstructionTool.prism: ToolInfo(
      tool: ConstructionTool.prism,
      name: '棱柱',
      iconData: Icons.view_in_ar,
      tooltip: '先点击底面多边形顶点，再点击顶部对应点',
      group: 6,
      steps: [
        ToolStep('点击底面第 1 个顶点'),
        ToolStep('点击底面第 2 个顶点'),
        ToolStep('点击底面更多顶点，然后点击第 1 个顶点闭合'),
        ToolStep('点击顶部对应点确定高度'),
      ],
    ),
    ConstructionTool.extrudePrism: ToolInfo(
      tool: ConstructionTool.extrudePrism,
      name: '拉伸为棱柱',
      iconData: Icons.layers,
      tooltip: '选择多边形并点击高度方向',
      group: 6,
      steps: [
        ToolStep('选择要拉伸的多边形',
            kind: InputKind.object, allowedTypes: {Object3DType.polygon}),
        ToolStep('点击确定拉伸高度'),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.extrudePyramid: ToolInfo(
      tool: ConstructionTool.extrudePyramid,
      name: '拉伸为棱锥',
      iconData: Icons.layers_outlined,
      tooltip: '选择多边形并点击顶点',
      group: 6,
      steps: [
        ToolStep('选择底面多边形',
            kind: InputKind.object, allowedTypes: {Object3DType.polygon}),
        ToolStep('点击棱锥顶点'),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.cone: ToolInfo(
      tool: ConstructionTool.cone,
      name: '圆锥',
      iconData: Icons.expand_less,
      tooltip: '点击底面圆心、圆周上一点和顶点创建圆锥',
      group: 6,
      steps: [
        ToolStep('点击底面圆心'),
        ToolStep('点击底面圆周上一点确定半径'),
        ToolStep('点击圆锥顶点'),
      ],
    ),
    ConstructionTool.cylinder: ToolInfo(
      tool: ConstructionTool.cylinder,
      name: '圆柱',
      iconData: Icons.wifi_tethering,
      tooltip: '点击底面圆心、圆周上一点和顶面圆心创建圆柱',
      group: 6,
      steps: [
        ToolStep('点击底面圆心'),
        ToolStep('点击底面圆周上一点确定半径'),
        ToolStep('点击顶面圆心确定高度'),
      ],
    ),
    ConstructionTool.tetrahedron: ToolInfo(
      tool: ConstructionTool.tetrahedron,
      name: '正四面体',
      iconData: Icons.workspaces_outline,
      tooltip: '选择两个点作为一条棱创建正四面体',
      group: 6,
      steps: [
        ToolStep('点击棱的第一个端点'),
        ToolStep('点击棱的第二个端点'),
      ],
    ),
    ConstructionTool.cube: ToolInfo(
      tool: ConstructionTool.cube,
      name: '立方体',
      iconData: Icons.crop_3_2,
      tooltip: '选择两个点作为一条棱创建立方体',
      group: 6,
      steps: [
        ToolStep('点击棱的第一个端点'),
        ToolStep('点击棱的第二个端点'),
      ],
    ),

    // ---- Sphere ----
    ConstructionTool.sphereCenterPoint: ToolInfo(
      tool: ConstructionTool.sphereCenterPoint,
      name: '球（球心+点）',
      iconData: Icons.language,
      tooltip: '以球心和球面上一点创建球',
      group: 7,
      steps: [
        ToolStep('点击球心位置'),
        ToolStep('点击球面上一点确定半径'),
      ],
    ),
    ConstructionTool.sphereCenterRadius: ToolInfo(
      tool: ConstructionTool.sphereCenterRadius,
      name: '球（球心+半径）',
      iconData: Icons.public,
      tooltip: '以球心和半径数值创建球',
      group: 7,
      steps: [
        ToolStep('点击球心位置'),
        ToolStep('输入半径', kind: InputKind.number),
      ],
    ),

    // ---- Measurement ----
    ConstructionTool.distance: ToolInfo(
      tool: ConstructionTool.distance,
      name: '距离',
      iconData: Icons.straighten,
      tooltip: '测量两点/点与线/点与平面的距离',
      group: 8,
      steps: [
        ToolStep('选择或创建第一个点'),
        ToolStep('选择或创建第二个点'),
      ],
    ),
    ConstructionTool.angle: ToolInfo(
      tool: ConstructionTool.angle,
      name: '角度',
      iconData: Icons.architecture,
      tooltip: '测量三点构成的角度',
      group: 8,
      steps: [
        ToolStep('选择或创建角的顶点'),
        ToolStep('选择或创建角一边上的点'),
        ToolStep('选择或创建角另一边上的点'),
      ],
    ),
    ConstructionTool.area: ToolInfo(
      tool: ConstructionTool.area,
      name: '面积',
      iconData: Icons.aspect_ratio,
      tooltip: '测量多边形或圆的面积',
      group: 8,
      steps: [
        ToolStep('选择多边形或圆',
            kind: InputKind.object,
            allowedTypes: {Object3DType.polygon, Object3DType.circle}),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.volume: ToolInfo(
      tool: ConstructionTool.volume,
      name: '体积',
      iconData: Icons.filter_center_focus,
      tooltip: '测量多面体/球/锥/柱的体积',
      group: 8,
      steps: [
        ToolStep('选择立体对象', kind: InputKind.object, allowedTypes: {
          Object3DType.polyhedron,
          Object3DType.sphere,
          Object3DType.cone,
          Object3DType.cylinder,
        }),
      ],
      isObjectTool: true,
    ),

    // ---- Transformation ----
    ConstructionTool.translate: ToolInfo(
      tool: ConstructionTool.translate,
      name: '平移',
      iconData: Icons.open_with,
      tooltip: '按向量平移对象',
      group: 9,
      steps: [
        ToolStep('选择要平移的对象', kind: InputKind.object),
        ToolStep('选择或创建起点'),
        ToolStep('选择或创建终点（构成平移向量）'),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.reflectPoint: ToolInfo(
      tool: ConstructionTool.reflectPoint,
      name: '关于点镜像',
      iconData: Icons.flip,
      tooltip: '以点为中心镜像对象',
      group: 9,
      steps: [
        ToolStep('选择要镜像的对象', kind: InputKind.object),
        ToolStep('选择镜像中心点'),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.reflectPlane: ToolInfo(
      tool: ConstructionTool.reflectPlane,
      name: '关于平面镜像',
      iconData: Icons.flip_to_back,
      tooltip: '以平面为镜面镜像对象',
      group: 9,
      steps: [
        ToolStep('选择要镜像的对象', kind: InputKind.object),
        ToolStep('选择镜像平面',
            kind: InputKind.object, allowedTypes: {Object3DType.plane}),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.rotateLine: ToolInfo(
      tool: ConstructionTool.rotateLine,
      name: '绕轴旋转',
      iconData: Icons.rotate_right,
      tooltip: '绕直线旋转对象指定角度',
      group: 9,
      steps: [
        ToolStep('选择要旋转的对象', kind: InputKind.object),
        ToolStep('选择旋转轴（直线）', kind: InputKind.object, allowedTypes: {
          Object3DType.line,
          Object3DType.segment,
          Object3DType.ray
        }),
        ToolStep('输入旋转角度（度）', kind: InputKind.number),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.dilate: ToolInfo(
      tool: ConstructionTool.dilate,
      name: '缩放',
      iconData: Icons.zoom_in,
      tooltip: '以点为缩放中心按比例缩放对象',
      group: 9,
      steps: [
        ToolStep('选择要缩放的对象', kind: InputKind.object),
        ToolStep('选择缩放中心点'),
        ToolStep('输入缩放比例', kind: InputKind.number),
      ],
      isObjectTool: true,
    ),

    // ---- General ----
    ConstructionTool.delete: ToolInfo(
      tool: ConstructionTool.delete,
      name: '删除',
      iconData: Icons.delete_outline,
      tooltip: '点击对象将其删除',
      group: 10,
      steps: [
        ToolStep('点击要删除的对象', kind: InputKind.object),
      ],
      isObjectTool: true,
    ),
    ConstructionTool.showHide: ToolInfo(
      tool: ConstructionTool.showHide,
      name: '显示/隐藏',
      iconData: Icons.visibility_outlined,
      tooltip: '点击对象切换显隐',
      group: 10,
      steps: [
        ToolStep('点击要切换显隐的对象', kind: InputKind.object),
      ],
      isObjectTool: true,
    ),
  };

  static const List<List<ConstructionTool>> groups = [
    [ConstructionTool.move],
    [
      ConstructionTool.point,
      ConstructionTool.midpoint,
      ConstructionTool.intersect,
    ],
    [
      ConstructionTool.line,
      ConstructionTool.segment,
      ConstructionTool.ray,
      ConstructionTool.vector,
      ConstructionTool.perpendicularLine,
      ConstructionTool.parallelLine,
    ],
    [ConstructionTool.polygon, ConstructionTool.regularPolygon],
    [
      ConstructionTool.circleCenterPoint,
      ConstructionTool.circleCenterRadius,
      ConstructionTool.circle3Points,
      ConstructionTool.arc,
    ],
    [ConstructionTool.plane3Points],
    [
      ConstructionTool.pyramid,
      ConstructionTool.prism,
      ConstructionTool.extrudePrism,
      ConstructionTool.extrudePyramid,
      ConstructionTool.cone,
      ConstructionTool.cylinder,
      ConstructionTool.tetrahedron,
      ConstructionTool.cube,
    ],
    [ConstructionTool.sphereCenterPoint, ConstructionTool.sphereCenterRadius],
    [
      ConstructionTool.distance,
      ConstructionTool.angle,
      ConstructionTool.area,
      ConstructionTool.volume,
    ],
    [
      ConstructionTool.translate,
      ConstructionTool.reflectPoint,
      ConstructionTool.reflectPlane,
      ConstructionTool.rotateLine,
      ConstructionTool.dilate,
    ],
    [ConstructionTool.delete, ConstructionTool.showHide],
  ];
}
