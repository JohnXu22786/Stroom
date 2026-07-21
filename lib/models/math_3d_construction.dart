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
    final workflow = ConstructionWorkflow.workflows[tool];
    if (workflow == null || _stepIndex >= workflow.steps.length) {
      return '完成构造';
    }
    return workflow.steps[_stepIndex].instruction;
  }

  /// Whether the construction is complete.
  bool get isComplete => _result != null;

  /// Add a point to the construction and return the action to take.
  ConstructionAction addPoint(Point3D point) {
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
        _result = Object3D.point(point,
            color: 0xFF2196F3, label: 'P${_points.length}');
        _updatePreview();
        return ConstructionAction.complete;

      case ConstructionTool.line:
        if (_points.length >= 2) {
          _result = Object3D.line(_points[0], _points[1],
              color: 0xFF4CAF50, label: 'Line${_points.length}');
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
          if (vertices.length >= 3) {
            _result = _createPolygon(vertices);
            _updatePreview();
            return ConstructionAction.complete;
          }
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.plane:
        if (_points.length >= 3) {
          _result = _createPlane(_points[0], _points[1], _points[2]);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.sphere:
        if (_points.length >= 2) {
          final radius = _points[0].distanceTo(_points[1]);
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
          _result = _createCircle(_points[0], _points[1]);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.cube:
        if (_points.length >= 2) {
          _result = _createCube(_points[0], _points[1]);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;

      case ConstructionTool.extrudePrism:
      case ConstructionTool.pyramid:
      case ConstructionTool.cone:
      case ConstructionTool.cylinder:
        // These need an existing polygon/base and a height point
        if (_points.length >= 2) {
          _result = Object3D.line(_points[0], _points[1],
              color: 0xFFFF9800, label: tool.name);
          _updatePreview();
          return ConstructionAction.complete;
        }
        _updatePreview();
        return ConstructionAction.advanceStep;
    }
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
  static Object3D _createCircle(Point3D center, Point3D onCircle) {
    final radius = center.distanceTo(onCircle);
    // Generate circle vertices as a polyline
    final segments = 32;
    final points = <Point3D>[];
    // Direction from center to onCircle
    final dir = (onCircle - center).normalized();
    final up = Vector3D(0, 1, 0);
    var axis = dir.cross(up).normalized();
    if (axis.magnitude < 0.1) {
      axis = dir.cross(Vector3D(0, 0, 1)).normalized();
    }
    final perp = dir.cross(axis);

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

    return Object3D.curve(
      points: points,
      color: 0xFF2196F3,
      label: 'Circle',
    );
  }

  /// Create a cube from two base edge points.
  static Object3D _createCube(Point3D a, Point3D b) {
    final edge = b - a;
    final height = edge.magnitude;

    // Build the 8 vertices of the cube
    // Assume base is on a plane perpendicular to Y
    final vx = edge.normalized();
    final up = Vector3D(0, 1, 0);
    var vz = vx.cross(up).normalized();
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

  /// Reset the construction state.
  void reset() {
    _points.clear();
    _result = null;
    _previewObject = null;
    _stepIndex = 0;
  }
}
