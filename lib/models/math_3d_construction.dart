import 'dart:math' as dart_math;

import 'math_3d_object.dart';
import 'math_3d_tool.dart';

/// Result of a construction action — what the system should do next.
enum ConstructionAction {
  /// Continue waiting for more user input on the current step.
  awaitInput,

  /// Advance to the next step.
  advanceStep,

  /// Construction is complete — create the object.
  complete,

  /// Reset the construction (user cancelled or error).
  reset,
}

/// Tracks the state of an ongoing construction.
///
/// When the user selects a tool, a new [ConstructionState] is created.
/// As the user clicks in the 3D view, points are accumulated.
/// When enough points are collected, the object is created.
class ConstructionState {
  final ConstructionTool tool;
  final List<Point3D> _points = [];
  int _stepIndex = 0;
  Object3D? _previewObject;
  Object3D? _result;
  String? _validationMessage;
  Vector3D _workingPlaneNormal = Vector3D.unitZ;

  ConstructionState({required this.tool});

  /// The current step the user is on.
  int get stepIndex => _stepIndex;

  /// Points accumulated so far in this construction.
  List<Point3D> get points => List.unmodifiable(_points);

  /// A preview object showing what's being constructed so far.
  Object3D? get previewObject => _previewObject;

  /// The completed object (non-null only after [complete] returns true).
  Object3D? get result => _result;

  /// Total number of steps in this construction workflow.
  int get totalSteps {
    final workflow = ConstructionWorkflow.workflows[tool];
    if (workflow == null) return 1;
    return workflow.steps.length;
  }

  /// The instruction for the current step.
  String get currentInstruction {
    if (_validationMessage != null) return _validationMessage!;
    final workflow = ConstructionWorkflow.workflows[tool];
    if (workflow == null || _stepIndex >= workflow.steps.length) {
      return '完成构造';
    }
    return workflow.steps[_stepIndex].instruction;
  }

  /// Whether the construction is complete.
  bool get isComplete => _result != null;

  /// Add a point to the construction and return the action to take.
  ConstructionAction addPoint(
    Point3D point, {
    Vector3D? workingPlaneNormal,
  }) {
    if (!_isFinitePoint(point)) {
      return _reject('无法放置无效坐标，请重新选择位置');
    }

    // Reject degenerate inputs before they become part of the construction.
    // A zero-length edge or a collinear plane is not a useful object and would
    // otherwise produce invalid normals or invisible geometry.
    if (tool == ConstructionTool.line &&
        _points.isNotEmpty &&
        _points.last.distanceTo(point) < 1e-9) {
      return _reject('两点不能重合，请重新选择第二个点');
    }
    if ((tool == ConstructionTool.sphere || tool == ConstructionTool.circle) &&
        _points.isNotEmpty &&
        _points.last.distanceTo(point) < 1e-9) {
      return _reject('半径必须大于 0，请重新选择半径点');
    }
    if (tool == ConstructionTool.plane &&
        _points.length == 2 &&
        (_points[1] - _points[0]).cross(point - _points[0]).magnitude < 1e-9) {
      return _reject('三个点不能共线，请重新选择第三个点');
    }
    if ((tool == ConstructionTool.cube ||
            tool == ConstructionTool.extrudePrism ||
            tool == ConstructionTool.pyramid) &&
        _points.length == 1 &&
        _points.last.distanceTo(point) < 1e-9) {
      return _reject('底面顶点不能重合，请重新选择');
    }
    if ((tool == ConstructionTool.extrudePrism ||
            tool == ConstructionTool.pyramid) &&
        _points.length == 2 &&
        (_points[1] - _points[0]).cross(point - _points[0]).magnitude < 1e-9) {
      return _reject('底面三个点不能共线，请重新选择第三个点');
    }
    if ((tool == ConstructionTool.extrudePrism ||
            tool == ConstructionTool.pyramid) &&
        _points.length == 3) {
      final baseNormal =
          (_points[1] - _points[0]).cross(_points[2] - _points[0]).normalized();
      if ((point - _points[0]).dot(baseNormal).abs() < 1e-9) {
        return _reject('高度必须离开底面，请重新选择顶点');
      }
    }
    if ((tool == ConstructionTool.cone || tool == ConstructionTool.cylinder) &&
        _points.length == 1 &&
        _points[0].distanceTo(point) < 1e-9) {
      return _reject('底面半径必须大于 0，请重新选择半径点');
    }
    if ((tool == ConstructionTool.cone || tool == ConstructionTool.cylinder) &&
        _points.length == 2) {
      final axis = point - _points[0];
      if (axis.magnitude < 1e-9) {
        return _reject('高度必须大于 0，请重新选择顶部位置');
      }
      final axisUnit = axis.normalized();
      final radiusVector = _points[1] - _points[0];
      final projectedRadius =
          radiusVector - axisUnit * radiusVector.dot(axisUnit);
      if (projectedRadius.magnitude < 1e-9) {
        return _reject('半径方向不能与高度方向平行，请重新选择顶部位置');
      }
    }

    _validationMessage = null;
    if (workingPlaneNormal != null && workingPlaneNormal.magnitude > 1e-9) {
      _workingPlaneNormal = workingPlaneNormal.normalized();
    }
    _points.add(point);
    // Advance to next step, capped at the last workflow step
    final maxStep = totalSteps - 1;
    _stepIndex = _points.length < totalSteps ? _points.length : maxStep;

    // Determine if we have enough points based on tool type
    switch (tool) {
      case ConstructionTool.move:
        return ConstructionAction.reset;

      case ConstructionTool.point:
        // Single click = point is placed
        _result = Object3D.point(
          point,
          color: 0xFF2196F3,
          label: 'P${_points.length}',
        );
        _updatePreview();
        return ConstructionAction.complete;

      case ConstructionTool.line:
        if (_points.length >= 2) {
          _result = Object3D.line(
            _points[0],
            _points[1],
            color: 0xFF4CAF50,
            label: 'Line${_points.length}',
          );
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.polygon:
        // Check if we closed the polygon (clicked near first point)
        if (_points.length >= 3 &&
            _points.first.distanceTo(_points.last) < 0.5) {
          // Remove the duplicate closing point
          final vertices = List<Point3D>.from(_points)..removeLast();
          if (vertices.length >= 3 && _hasArea(vertices)) {
            _result = _createPolygon(vertices);
            _updatePreview();
            return ConstructionAction.complete;
          }
          _points.removeLast();
          _stepIndex =
              _points.length < totalSteps ? _points.length : totalSteps - 1;
          _updatePreview();
          return ConstructionAction.awaitInput;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.plane:
        if (_points.length >= 3) {
          final normal =
              (_points[1] - _points[0]).cross(_points[2] - _points[0]);
          if (normal.magnitude < 1e-10) {
            _points.removeLast();
            _stepIndex = _points.length;
            _updatePreview();
            return ConstructionAction.awaitInput;
          }
          _result = _createPlane(_points[0], _points[1], _points[2]);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.sphere:
        if (_points.length >= 2) {
          final radius = _points[0].distanceTo(_points[1]);
          if (radius < 1e-10) {
            _points.removeLast();
            _stepIndex = _points.length;
            _updatePreview();
            return ConstructionAction.awaitInput;
          }
          _result = Object3D.sphere(
            center: _points[0],
            radius: radius,
            color: 0x804CAF50,
            label: 'Sphere',
          );
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.circle:
        if (_points.length >= 2) {
          _result = _createCircle(
            _points[0],
            _points[1],
            planeNormal: _workingPlaneNormal,
          );
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.cube:
        if (_points.length >= 2) {
          _result = _createCube(
            _points[0],
            _points[1],
            planeNormal: _workingPlaneNormal,
          );
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.extrudePrism:
        if (_points.length >= 4) {
          _result = _createTriangularPrism(
            _points[0],
            _points[1],
            _points[2],
            _points[3],
          );
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;
      case ConstructionTool.pyramid:
        if (_points.length >= 4) {
          _result = _createPyramid(
            _points[0],
            _points[1],
            _points[2],
            _points[3],
          );
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;
      case ConstructionTool.cone:
        if (_points.length >= 3) {
          _result = _createCone(_points[0], _points[1], _points[2]);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;
      case ConstructionTool.cylinder:
        if (_points.length >= 3) {
          _result = _createCylinder(_points[0], _points[1], _points[2]);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;
    }
  }

  /// Update the transient preview without committing a construction point.
  ///
  /// This is deliberately separate from [addPoint]: a drag should show the
  /// object being built, while only pointer-up advances the workflow.
  void updatePreviewPoint(
    Point3D point, {
    Vector3D? workingPlaneNormal,
  }) {
    if (!_isFinitePoint(point)) return;
    if (workingPlaneNormal != null && workingPlaneNormal.magnitude > 1e-9) {
      _workingPlaneNormal = workingPlaneNormal.normalized();
    }
    if (_points.isEmpty) {
      _previewObject = Object3D.point(point, color: 0x60808080);
      return;
    }

    final start = _points.last;
    switch (tool) {
      case ConstructionTool.sphere:
        {
          final radius = start.distanceTo(point);
          _previewObject = radius < 1e-9
              ? Object3D.point(start, color: 0x60808080)
              : Object3D.sphere(
                  center: start,
                  radius: radius,
                  color: 0x404CAF50,
                );
          return;
        }
      case ConstructionTool.circle:
        {
          final radius = start.distanceTo(point);
          _previewObject = radius < 1e-9
              ? Object3D.point(start, color: 0x60808080)
              : _createCircle(
                  start,
                  point,
                  planeNormal: _workingPlaneNormal,
                  color: 0x804CAF50,
                );
          return;
        }
      case ConstructionTool.line:
      case ConstructionTool.cube:
        _previewObject = Object3D.line(start, point, color: 0x60808080);
        return;
      case ConstructionTool.cone:
        if (_points.length >= 2 &&
            _hasRoundSolidGeometry(
              _points[0],
              _points[1],
              point,
            )) {
          _previewObject = _createCone(_points[0], _points[1], point);
        } else {
          _previewObject = Object3D.line(start, point, color: 0x60808080);
        }
        return;
      case ConstructionTool.cylinder:
        if (_points.length >= 2 &&
            _hasRoundSolidGeometry(
              _points[0],
              _points[1],
              point,
            )) {
          _previewObject = _createCylinder(_points[0], _points[1], point);
        } else {
          _previewObject = Object3D.line(start, point, color: 0x60808080);
        }
        return;
      case ConstructionTool.extrudePrism:
        if (_points.length >= 3) {
          _previewObject = _createTriangularPrism(
            _points[0],
            _points[1],
            _points[2],
            point,
          );
        } else {
          _previewObject = Object3D.line(start, point, color: 0x60808080);
        }
        return;
      case ConstructionTool.pyramid:
        if (_points.length >= 3) {
          _previewObject = _createPyramid(
            _points[0],
            _points[1],
            _points[2],
            point,
          );
        } else {
          _previewObject = Object3D.line(start, point, color: 0x60808080);
        }
        return;
      default:
        _previewObject = Object3D.line(start, point, color: 0x60808080);
    }
  }

  /// Remove a transient preview after a gesture ends or a tool is cancelled.
  void clearPreview() {
    _previewObject = null;
  }

  /// Return a non-mutating preview for the point currently under the cursor.
  Object3D? previewForPoint(Point3D point) {
    if (!point.x.isFinite || !point.y.isFinite || !point.z.isFinite) {
      return null;
    }

    final previewPoints = [..._points, point];
    if (previewPoints.length == 1) {
      return Object3D.point(previewPoints.first, color: 0x60808080);
    }
    if (tool == ConstructionTool.polygon) {
      return Object3D.curve(points: previewPoints, color: 0x60808080);
    }
    return Object3D.line(
      previewPoints[previewPoints.length - 2],
      previewPoints.last,
      color: 0x60808080,
    );
  }

  static bool _hasArea(List<Point3D> vertices) {
    final origin = vertices.first;
    var area = Vector3D.zero;
    for (var i = 1; i < vertices.length - 1; i++) {
      area = area + (vertices[i] - origin).cross(vertices[i + 1] - origin);
    }
    return area.magnitude > 1e-10;
  }

  /// Create a preview line or marker showing the current state.
  void _updatePreview() {
    if (_points.length == 1) {
      _previewObject = Object3D.point(_points[0], color: 0x60808080);
    } else if (_points.length >= 2 && _result == null) {
      _previewObject = Object3D.line(
        _points[_points.length - 2],
        _points[_points.length - 1],
        color: 0x60808080,
      );
    } else {
      _previewObject = null;
    }
  }

  /// Create a polygon from a list of vertices.
  static Object3D _createPolygon(List<Point3D> vertices) {
    // Triangulate the polygon (fan triangulation from first vertex)
    final indices = <int>[];
    for (int i = 1; i < vertices.length - 1; i++) {
      indices.add(0);
      indices.add(i);
      indices.add(i + 1);
    }

    return Object3D.polyhedron(
      vertices: vertices,
      indices: indices,
      color: 0x804CAF50,
      label: 'Polygon',
    );
  }

  /// Create a plane through three points.
  static Object3D _createPlane(Point3D a, Point3D b, Point3D c) {
    // Compute plane normal from cross product of edges
    final ab = b - a;
    final ac = c - a;
    final normal = ab.cross(ac).normalized();

    // Plane equation: normal · (x, y, z) = normal · a
    final d = normal.x * a.x + normal.y * a.y + normal.z * a.z;

    return Object3D.plane(
      a: normal.x,
      b: normal.y,
      c: normal.z,
      d: d,
      color: 0x402196F3,
      label: 'Plane',
    );
  }

  /// Create a circle from center and a point on the circle.
  static Object3D _createCircle(
    Point3D center,
    Point3D onCircle, {
    Vector3D? planeNormal,
    int color = 0xFF2196F3,
  }) {
    final radius = center.distanceTo(onCircle);
    // Generate circle vertices as a polyline
    final segments = 32;
    final points = <Point3D>[];
    // Direction from center to onCircle
    final dir = (onCircle - center).normalized();
    var perp = (planeNormal ?? Vector3D.unitZ).cross(dir).normalized();
    if (perp.magnitude < 0.1) {
      perp = dir.cross(Vector3D.unitY).normalized();
    }

    for (int i = 0; i <= segments; i++) {
      final theta = 2 * dart_math.pi * i / segments;
      final x = center.x +
          radius *
              (dart_math.cos(theta) * dir.x + dart_math.sin(theta) * perp.x);
      final y = center.y +
          radius *
              (dart_math.cos(theta) * dir.y + dart_math.sin(theta) * perp.y);
      final z = center.z +
          radius *
              (dart_math.cos(theta) * dir.z + dart_math.sin(theta) * perp.z);
      points.add(Point3D(x, y, z));
    }

    return Object3D.curve(points: points, color: color, label: 'Circle');
  }

  /// Create a cube from two base edge points.
  static Object3D _createCube(
    Point3D a,
    Point3D b, {
    Vector3D planeNormal = Vector3D.unitZ,
  }) {
    final edge = b - a;
    final height = edge.magnitude;

    // Build the 8 vertices of the cube
    final vx = edge.normalized();
    final up = planeNormal.normalized();
    var vz = up.cross(vx).normalized();
    if (vz.magnitude < 0.1) {
      vz = vx.cross(Vector3D(0, 0, 1)).normalized();
    }
    final vy = vz.cross(vx).normalized();

    final verts = <Point3D>[
      a,
      b,
      b + vz * height,
      a + vz * height,
      a + vy * height,
      b + vy * height,
      b + vy * height + vz * height,
      a + vy * height + vz * height,
    ];

    final indices = [
      // Bottom
      0, 1, 2, 0, 2, 3,
      // Top
      4, 6, 5, 4, 7, 6,
      // Front
      0, 4, 5, 0, 5, 1,
      // Back
      3, 2, 6, 3, 6, 7,
      // Left
      0, 3, 7, 0, 7, 4,
      // Right
      1, 5, 6, 1, 6, 2,
    ];

    return Object3D.polyhedron(
      vertices: verts,
      indices: indices,
      color: 0x80FF9800,
      label: 'Cube',
    );
  }

  static Object3D _createTriangularPrism(
    Point3D a,
    Point3D b,
    Point3D c,
    Point3D heightPoint,
  ) {
    final normal = (b - a).cross(c - a).normalized();
    final height = (heightPoint - a).dot(normal);
    final offset = normal * height;
    final vertices = <Point3D>[a, b, c, a + offset, b + offset, c + offset];
    final indices = <int>[
      0,
      2,
      1,
      3,
      4,
      5,
      0,
      1,
      4,
      0,
      4,
      3,
      1,
      2,
      5,
      1,
      5,
      4,
      2,
      0,
      3,
      2,
      3,
      5,
    ];
    return Object3D.polyhedron(
      vertices: vertices,
      indices: indices,
      color: 0x80FF9800,
      label: 'Prism',
    );
  }

  static Object3D _createPyramid(
    Point3D a,
    Point3D b,
    Point3D c,
    Point3D apex,
  ) {
    return Object3D.polyhedron(
      vertices: [a, b, c, apex],
      indices: [
        0,
        2,
        1,
        0,
        1,
        3,
        1,
        2,
        3,
        2,
        0,
        3,
      ],
      color: 0x80FF9800,
      label: 'Pyramid',
    );
  }

  static Object3D _createCone(
    Point3D center,
    Point3D radiusPoint,
    Point3D apex,
  ) {
    final axis = (apex - center).normalized();
    final rawRadius = radiusPoint - center;
    final radial = rawRadius - axis * rawRadius.dot(axis);
    final radius = radial.magnitude;
    final u = radial.normalized();
    final v = axis.cross(u).normalized();
    const segments = 24;
    final vertices = <Point3D>[center];
    for (var i = 0; i < segments; i++) {
      final angle = 2 * dart_math.pi * i / segments;
      final direction = u * dart_math.cos(angle) + v * dart_math.sin(angle);
      vertices.add(center + direction * radius);
    }
    final apexIndex = vertices.length;
    vertices.add(apex);
    final indices = <int>[];
    for (var i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      indices.addAll([0, next + 1, i + 1]);
      indices.addAll([i + 1, next + 1, apexIndex]);
    }
    return Object3D.polyhedron(
      vertices: vertices,
      indices: indices,
      color: 0x80FF9800,
      label: 'Cone',
    );
  }

  static Object3D _createCylinder(
    Point3D center,
    Point3D radiusPoint,
    Point3D topCenter,
  ) {
    final axis = (topCenter - center).normalized();
    final rawRadius = radiusPoint - center;
    final radial = rawRadius - axis * rawRadius.dot(axis);
    final radius = radial.magnitude;
    final u = radial.normalized();
    final v = axis.cross(u).normalized();
    const segments = 24;
    final vertices = <Point3D>[center, topCenter];
    for (var i = 0; i < segments; i++) {
      final angle = 2 * dart_math.pi * i / segments;
      final direction = u * dart_math.cos(angle) + v * dart_math.sin(angle);
      vertices.add(center + direction * radius);
    }
    final topRingStart = vertices.length;
    for (var i = 0; i < segments; i++) {
      final angle = 2 * dart_math.pi * i / segments;
      final direction = u * dart_math.cos(angle) + v * dart_math.sin(angle);
      vertices.add(topCenter + direction * radius);
    }
    final indices = <int>[];
    for (var i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      final bottom = i + 2;
      final nextBottom = next + 2;
      final top = topRingStart + i;
      final nextTop = topRingStart + next;
      indices.addAll([0, nextBottom, bottom]);
      indices.addAll([1, top, nextTop]);
      indices.addAll([bottom, nextBottom, nextTop, bottom, nextTop, top]);
    }
    return Object3D.polyhedron(
      vertices: vertices,
      indices: indices,
      color: 0x80FF9800,
      label: 'Cylinder',
    );
  }

  static bool _hasRoundSolidGeometry(
    Point3D center,
    Point3D radiusPoint,
    Point3D topPoint,
  ) {
    final axis = topPoint - center;
    if (axis.magnitude < 1e-9) return false;
    final axisUnit = axis.normalized();
    final radial = radiusPoint - center;
    return (radial - axisUnit * radial.dot(axisUnit)).magnitude > 1e-9;
  }

  /// Reset the construction state.
  void reset() {
    _points.clear();
    _result = null;
    _previewObject = null;
    _validationMessage = null;
    _workingPlaneNormal = Vector3D.unitZ;
    _stepIndex = 0;
  }

  ConstructionAction _reject(String message) {
    _validationMessage = message;
    return ConstructionAction.awaitInput;
  }

  static bool _isFinitePoint(Point3D point) =>
      point.x.isFinite && point.y.isFinite && point.z.isFinite;
}
