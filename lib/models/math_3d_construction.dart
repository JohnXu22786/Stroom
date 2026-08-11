import 'dart:math' as dart_math;

import 'math_3d_object.dart';
import 'math_3d_scene.dart';
import 'math_3d_tool.dart';

// ======================================================================
// Construction input
// ======================================================================

/// A single input collected during construction.
sealed class ConstructionInput {
  const ConstructionInput();
}

/// A point: either newly placed in empty space, or snapped onto an object.
class NewPointInput extends ConstructionInput {
  final Point3D point;
  const NewPointInput(this.point);
}

/// An existing scene object selected by the user.
class ObjectInput extends ConstructionInput {
  final Object3D object;

  /// The world-space position where the object was clicked (used to snap
  /// points onto lines/planes/circles accurately).
  final Point3D? snapPoint;

  const ObjectInput(this.object, {this.snapPoint});
}

/// A numeric value entered via dialog.
class NumberInput extends ConstructionInput {
  final double value;
  const NumberInput(this.value);
}

/// Objects produced or affected by a completed construction.
class ConstructionResult {
  /// Objects to add to the scene (main object + auxiliary points).
  final List<Object3D> created;

  /// Objects to remove from the scene (Delete tool).
  final List<Object3D> removed;

  /// Objects to replace in the scene (Show/Hide toggles).
  final List<Object3D> modified;

  const ConstructionResult({
    this.created = const [],
    this.removed = const [],
    this.modified = const [],
  });
}

// ======================================================================
// Construction state machine
// ======================================================================

/// Tracks the state of an ongoing construction.
class ConstructionState {
  final ConstructionTool tool;
  final List<ConstructionInput> inputs = [];

  ConstructionState({required this.tool});

  /// Whether the current step expects a numeric input.
  bool get awaitingNumber {
    final step = currentStep;
    return step != null && step.kind == InputKind.number;
  }

  ToolStep? get currentStep {
    final info = ToolInfo.all[tool]!;
    final idx = _workflowIndex;
    if (idx < 0 || idx >= info.steps.length) return null;
    return info.steps[idx];
  }

  /// Index into the workflow steps. For polygon-style tools the step
  /// count grows with the number of inputs.
  int get _workflowIndex {
    final info = ToolInfo.all[tool]!;
    switch (tool) {
      case ConstructionTool.polygon:
        // steps: 1, 2, then "more + close"
        if (inputs.isEmpty) return 0;
        if (inputs.length == 1) return 1;
        return 2;
      case ConstructionTool.pyramid:
      case ConstructionTool.prism:
        if (inputs.isEmpty) return 0;
        if (inputs.length == 1) return 1;
        if (_baseClosed) return 3; // final step (apex / top point)
        return 2; // more base vertices
      default:
        final idx = inputs.length;
        return idx >= info.steps.length ? info.steps.length - 1 : idx;
    }
  }

  /// The instruction to show the user right now.
  String get currentInstruction {
    if (isComplete) return '完成构造';
    final step = currentStep;
    if (step == null) return '';
    return step.instruction;
  }

  /// Whether the construction has completed.
  bool get isComplete => _result != null;
  ConstructionResult? _result;
  ConstructionResult? get result => _result;

  /// Whether the base polygon has been closed (polygon-style tools).
  bool _baseClosed = false;
  bool get baseClosed => _baseClosed;

  /// Number of base vertices captured before the closing click. The closing
  /// click duplicates the first vertex, so the base is `previewPoints` minus
  /// the duplicate; for pyramid/prism an apex/top input follows the close.
  int _baseCount = 0;

  /// The base polygon vertices for pyramid/prism (closed base).
  List<Point3D> get baseVertices {
    if (inputs.isEmpty) return const [];
    // All inputs until the closing point, minus the duplicated close point.
    final pts = inputs.whereType<NewPointInput>().map((e) => e.point).toList();
    if (pts.isNotEmpty && _baseClosed && _baseCount > 0) {
      return pts.take(_baseCount).toList();
    }
    return pts;
  }

  /// Preview points placed so far (for the canvas to draw).
  List<Point3D> get previewPoints {
    final pts = inputs.whereType<NewPointInput>().map((e) => e.point).toList();
    return pts;
  }

  /// Preview segments connecting consecutive inputs (for the canvas).
  List<(Point3D, Point3D)> get previewSegments {
    final pts = previewPoints;
    final segs = <(Point3D, Point3D)>[];
    for (int i = 0; i < pts.length - 1; i++) {
      segs.add((pts[i], pts[i + 1]));
    }
    return segs;
  }

  /// Add an input; returns true when the construction completed
  /// ([result] is then available).
  bool addInput(ConstructionInput input, {double closeDistance = 0.35}) {
    if (isComplete) return true;

    // Object-steps only accept existing objects; free-space clicks are
    // ignored (the canvas filters these too, this is the safety net).
    final step = currentStep;
    if (step != null && step.kind == InputKind.object) {
      if (input is! ObjectInput) return false;
      if (step.allowedTypes != null &&
          !step.allowedTypes!.contains(input.object.type)) {
        return false;
      }
      // Dynamic narrowing: the intersect tool only implements a subset of
      // the type pairs, so the second step must reject combinations that
      // would silently produce nothing.
      if (tool == ConstructionTool.intersect &&
          inputs.length == 1 &&
          !intersectionSupported(
              (inputs[0] as ObjectInput).object.type, input.object.type)) {
        return false;
      }
    }

    // Polygon-style close detection: clicking near the first base vertex.
    if (input is NewPointInput && _isPolygonStyle) {
      final pts = previewPoints;
      if (pts.isNotEmpty && !_baseClosed) {
        final first = pts.first;
        if (input.point.distanceTo(first) < closeDistance &&
            inputs.length >= 2) {
          // Keep the duplicated point so previews close properly.
          _baseCount = pts.length;
          inputs.add(input);
          _baseClosed = true;
          _tryComplete();
          return isComplete;
        }
      }
    }

    inputs.add(input);
    _tryComplete();
    return isComplete;
  }

  bool get _isPolygonStyle =>
      tool == ConstructionTool.polygon ||
      tool == ConstructionTool.pyramid ||
      tool == ConstructionTool.prism;

  void _tryComplete() {
    final info = ToolInfo.all[tool]!;
    final done = _inputsComplete(info);
    if (!done) return;
    _result = ToolFactory.create(this, info);
  }

  bool _inputsComplete(ToolInfo info) {
    // Polygon tools are complete when the base is closed (pyramid/prism
    // additionally need the final apex/top input).
    switch (tool) {
      case ConstructionTool.polygon:
        return _baseClosed;
      case ConstructionTool.pyramid:
      case ConstructionTool.prism:
        // Base vertices + closing point + apex/top point.
        return _baseClosed && inputs.length >= _baseCount + 2;
      default:
        final needed = info.steps.length;
        if (inputs.length < needed) return false;
        // All steps consumed; a trailing number step must have received
        // a numeric value.
        if (info.steps.last.kind == InputKind.number) {
          return inputs.last is NumberInput;
        }
        return true;
    }
  }

  void reset() {
    inputs.clear();
    _baseClosed = false;
    _result = null;
  }
}

// ======================================================================
// Tool factory — builds objects for every construction tool
// ======================================================================

/// Creates the scene objects for a completed construction.
class ToolFactory {
  /// Style defaults per object kind (GeoGebra-ish palette).
  static const _pointStyle =
      ObjectStyle(color: 0xFFD32F2F, labelMode: LabelMode.name);
  static const _lineStyle =
      ObjectStyle(color: 0xFF2962FF, labelMode: LabelMode.name);
  static const _curveStyle =
      ObjectStyle(color: 0xFF2962FF, labelMode: LabelMode.name);
  static const _solidStyle =
      ObjectStyle(color: 0xFF00897B, opacity: 0.75, labelMode: LabelMode.name);
  static const _planeStyle =
      ObjectStyle(color: 0xFF8E24AA, opacity: 0.3, labelMode: LabelMode.name);

  static ConstructionResult create(ConstructionState state, ToolInfo info) {
    final inputs = state.inputs;
    switch (state.tool) {
      case ConstructionTool.move:
        return const ConstructionResult();

      // ---- Point ----
      case ConstructionTool.point:
        final p = _pointOf(inputs.last);
        return ConstructionResult(created: [
          Object3D.point(p, name: _uniqueName('P'), style: _pointStyle),
        ]);

      case ConstructionTool.midpoint:
        final obj = _objectOf(inputs.last);
        final mid = _midpointOf(obj);
        return ConstructionResult(created: [
          Object3D.point(mid, name: _uniqueName('M'), style: _pointStyle),
        ]);

      case ConstructionTool.intersect:
        return _buildIntersection(inputs);

      // ---- Line ----
      case ConstructionTool.line:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        return ConstructionResult(created: [
          Object3D.line(a, b - a, name: _uniqueName('l'), style: _lineStyle),
        ]);

      case ConstructionTool.segment:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        return ConstructionResult(created: [
          Object3D.segment(a, b, name: _uniqueName('s'), style: _lineStyle),
        ]);

      case ConstructionTool.ray:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        return ConstructionResult(created: [
          Object3D.ray(a, b - a, name: _uniqueName('r'), style: _lineStyle),
        ]);

      case ConstructionTool.vector:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        return ConstructionResult(created: [
          Object3D.vectorObj(a, b - a,
              name: _uniqueName('u'), style: _lineStyle),
        ]);

      case ConstructionTool.perpendicularLine:
        final obj = _objectOf(inputs[0]);
        final p = _pointOf(inputs[1]);
        final dir = _perpendicularDir(obj, p);
        return ConstructionResult(created: [
          Object3D.line(p, dir, name: _uniqueName('l'), style: _lineStyle),
        ]);

      case ConstructionTool.parallelLine:
        final obj = _objectOf(inputs[0]);
        final p = _pointOf(inputs[1]);
        return ConstructionResult(created: [
          Object3D.line(p, _dirOf(obj).normalized(),
              name: _uniqueName('l'), style: _lineStyle),
        ]);

      // ---- Polygon ----
      case ConstructionTool.polygon:
        final verts = state.baseVertices;
        if (verts.length < 3) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.polygon(verts,
              name: _uniqueName('poly'), style: _curveStyle),
        ]);

      case ConstructionTool.regularPolygon:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        final n = (_numberOf(inputs[2])).round().clamp(3, 20);
        final verts = _regularPolygon(a, b, n);
        return ConstructionResult(created: [
          Object3D.polygon(verts,
              name: _uniqueName('poly'), style: _curveStyle),
        ]);

      // ---- Circle / Arc ----
      case ConstructionTool.circleCenterPoint:
        final c = _pointOf(inputs[0]);
        final p = _pointOf(inputs[1]);
        final r = c.distanceTo(p);
        return ConstructionResult(created: [
          Object3D.circle(c, Vector3D.unitZ, r,
              name: _uniqueName('c'), style: _curveStyle),
        ]);

      case ConstructionTool.circleCenterRadius:
        final c = _pointOf(inputs[0]);
        final r = _numberOf(inputs[1]).abs();
        return ConstructionResult(created: [
          Object3D.circle(c, Vector3D.unitZ, r,
              name: _uniqueName('c'), style: _curveStyle),
        ]);

      case ConstructionTool.circle3Points:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        final c = _pointOf(inputs[2]);
        final circle = _circleThrough3(a, b, c);
        if (circle == null) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.circle(circle.$1, circle.$2, circle.$3,
              name: _uniqueName('c'), style: _curveStyle),
        ]);

      case ConstructionTool.arc:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        final c = _pointOf(inputs[2]);
        final arc = _arcThrough3(a, b, c);
        if (arc == null) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.arc(arc.$1, arc.$2, arc.$3, arc.$4, arc.$5,
              name: _uniqueName('a'), style: _curveStyle),
        ]);

      // ---- Plane ----
      case ConstructionTool.plane3Points:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        final c = _pointOf(inputs[2]);
        final n = (b - a).cross(c - a);
        if (n.isZero) return const ConstructionResult();
        final nn = n.normalized();
        return ConstructionResult(created: [
          Object3D.plane(
            a: nn.x,
            b: nn.y,
            c: nn.z,
            d: nn.dot(a.toVector()),
            name: _uniqueName('pl'),
            style: _planeStyle,
          ),
        ]);

      // ---- Solids ----
      case ConstructionTool.pyramid:
        final base = state.baseVertices;
        final apex = _pointOf(inputs.last);
        if (base.length < 3) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.polyhedron(MeshBuilder.pyramid(base, apex),
              name: _uniqueName('P'), style: _solidStyle),
        ]);

      case ConstructionTool.prism:
        final base = state.baseVertices;
        final top = _pointOf(inputs.last);
        if (base.length < 3) return const ConstructionResult();
        final n = (base[1] - base[0]).cross(base[2] - base[0]).normalized();
        final height = (top - base.first).dot(n);
        if (height.abs() < 1e-9) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.polyhedron(
              MeshBuilder.prism(base, height.abs(), direction: n * height.sign),
              name: _uniqueName('P'),
              style: _solidStyle),
        ]);

      case ConstructionTool.extrudePrism:
        final poly = _objectOf(inputs[0]);
        final base = poly.polygonVertices;
        final top = _pointOf(inputs[1]);
        if (base.length < 3) return const ConstructionResult();
        final n = (base[1] - base[0]).cross(base[2] - base[0]).normalized();
        final height = (top - base.first).dot(n);
        if (height.abs() < 1e-9) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.polyhedron(
              MeshBuilder.prism(base, height.abs(), direction: n * height.sign),
              name: _uniqueName('P'),
              style: _solidStyle),
        ]);

      case ConstructionTool.extrudePyramid:
        final poly = _objectOf(inputs[0]);
        final base = poly.polygonVertices;
        final apex = _pointOf(inputs[1]);
        if (base.length < 3) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.polyhedron(MeshBuilder.pyramid(base, apex),
              name: _uniqueName('P'), style: _solidStyle),
        ]);

      case ConstructionTool.cone:
        final c = _pointOf(inputs[0]);
        final rim = _pointOf(inputs[1]);
        final apex = _pointOf(inputs[2]);
        final r = (c.distanceTo(rim)).clamp(1e-6, double.infinity);
        final axisVec = apex - c;
        final h = axisVec.magnitude;
        if (h < 1e-9) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.cone(c, r, h,
              axis: axisVec * (1 / h),
              name: _uniqueName('cone'),
              style: _solidStyle),
        ]);

      case ConstructionTool.cylinder:
        final c = _pointOf(inputs[0]);
        final rim = _pointOf(inputs[1]);
        final top = _pointOf(inputs[2]);
        final r = (c.distanceTo(rim)).clamp(1e-6, double.infinity);
        final axisVec = top - c;
        final h = axisVec.magnitude;
        if (h < 1e-9) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.cylinder(c, r, h,
              axis: axisVec * (1 / h),
              name: _uniqueName('cyl'),
              style: _solidStyle),
        ]);

      case ConstructionTool.tetrahedron:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        final verts = _tetrahedron(a, b);
        return ConstructionResult(created: [
          Object3D.polyhedron(MeshBuilder.tetrahedron(verts),
              name: _uniqueName('T'), style: _solidStyle),
        ]);

      case ConstructionTool.cube:
        final a = _pointOf(inputs[0]);
        final b = _pointOf(inputs[1]);
        final verts = _cube(a, b);
        return ConstructionResult(created: [
          Object3D.polyhedron(MeshData(vertices: verts, indices: _cubeIndices),
              name: _uniqueName('C'), style: _solidStyle),
        ]);

      // ---- Sphere ----
      case ConstructionTool.sphereCenterPoint:
        final c = _pointOf(inputs[0]);
        final p = _pointOf(inputs[1]);
        final r = c.distanceTo(p);
        return ConstructionResult(created: [
          Object3D.sphere(c, r, name: _uniqueName('sph'), style: _solidStyle),
        ]);

      case ConstructionTool.sphereCenterRadius:
        final c = _pointOf(inputs[0]);
        final r = _numberOf(inputs[1]).abs();
        return ConstructionResult(created: [
          Object3D.sphere(c, r, name: _uniqueName('sph'), style: _solidStyle),
        ]);

      // ---- Measurement ----
      case ConstructionTool.distance:
        return _buildDistance(inputs);

      case ConstructionTool.angle:
        return _buildAngle(inputs);

      case ConstructionTool.area:
        final obj = _objectOf(inputs[0]);
        final area = _areaOf(obj);
        if (area == null) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.measurement('面积 = ${_fmt(area)}', obj.anchorPoint,
              name: _uniqueName('m'),
              style: const ObjectStyle(color: 0xFF00695C)),
        ]);

      case ConstructionTool.volume:
        final obj = _objectOf(inputs[0]);
        final vol = _volumeOf(obj);
        if (vol == null) return const ConstructionResult();
        return ConstructionResult(created: [
          Object3D.measurement('体积 = ${_fmt(vol)}', obj.anchorPoint,
              name: _uniqueName('m'),
              style: const ObjectStyle(color: 0xFF00695C)),
        ]);

      // ---- Transformation ----
      case ConstructionTool.translate:
        final obj = _objectOf(inputs[0]);
        final from = _pointOf(inputs[1]);
        final to = _pointOf(inputs[2]);
        return ConstructionResult(created: [
          obj.translated(to - from),
        ]);

      case ConstructionTool.reflectPoint:
        final obj = _objectOf(inputs[0]);
        final c = _pointOf(inputs[1]);
        return ConstructionResult(created: [
          obj.reflectedAboutPoint(c),
        ]);

      case ConstructionTool.reflectPlane:
        final obj = _objectOf(inputs[0]);
        final plane = _objectOf(inputs[1]);
        return ConstructionResult(created: [
          obj.reflected(plane.planeNormal, plane.planeDValue),
        ]);

      case ConstructionTool.rotateLine:
        final obj = _objectOf(inputs[0]);
        final axis = _objectOf(inputs[1]);
        final angleDeg = _numberOf(inputs[2]);
        return ConstructionResult(created: [
          obj.rotated(
              axis.pointAValue, _dirOf(axis), angleDeg * dart_math.pi / 180),
        ]);

      case ConstructionTool.dilate:
        final obj = _objectOf(inputs[0]);
        final c = _pointOf(inputs[1]);
        final factor = _numberOf(inputs[2]);
        // A zero factor collapses the object to a point; refuse it like
        // GeoGebra does instead of producing a degenerate solid.
        if (factor.abs() < 1e-12) return const ConstructionResult();
        return ConstructionResult(created: [
          obj.scaled(c, factor),
        ]);

      // ---- General ----
      case ConstructionTool.delete:
        final obj = _objectOf(inputs[0]);
        return ConstructionResult(removed: [obj]);

      case ConstructionTool.showHide:
        final obj = _objectOf(inputs[0]);
        return ConstructionResult(modified: [obj.withVisible(!obj.visible)]);
    }
  }

  // ==================================================================
  // Helpers
  // ==================================================================

  static Point3D _pointOf(ConstructionInput input) {
    if (input is NewPointInput) return input.point;
    if (input is ObjectInput) {
      final snap = input.snapPoint ?? input.object.anchorPoint;
      return input.object.inputPoint(snap);
    }
    return Point3D.origin;
  }

  static Object3D _objectOf(ConstructionInput input) =>
      (input as ObjectInput).object;

  /// The direction of a line-like object; segments/rays contribute their
  /// actual direction (segment has no stored vector).
  static Vector3D _dirOf(Object3D obj) {
    if (obj.type == Object3DType.segment) {
      return obj.pointBValue - obj.pointAValue;
    }
    return obj.vectorValue;
  }

  /// The line parameter t of [p] along a line-like object (p = a + t·d).
  static double _tOf(Object3D obj, Point3D p) {
    final d = _dirOf(obj);
    final len2 = d.magnitudeSquared;
    if (len2 < 1e-15) return 0;
    return (p - obj.pointAValue).dot(d) / len2;
  }

  static double _numberOf(ConstructionInput input) =>
      (input as NumberInput).value;

  static String _fmt(double v) {
    if (v.abs() >= 10000 || (v.abs() < 0.001 && v != 0)) {
      return v.toStringAsExponential(3);
    }
    return v.toStringAsFixed(2);
  }

  static int _nameCounter = 0;
  static String _uniqueName(String prefix) {
    _nameCounter++;
    return '$prefix$_nameCounter';
  }

  static Point3D _midpointOf(Object3D obj) {
    switch (obj.type) {
      case Object3DType.segment:
        return obj.pointAValue.midpoint(obj.pointBValue);
      case Object3DType.line:
      case Object3DType.ray:
        return obj.pointAValue;
      case Object3DType.curve:
        final pts = obj.curveSamplePoints;
        if (pts.length >= 2) {
          return pts.first.midpoint(pts.last);
        }
        return obj.anchorPoint;
      default:
        return obj.anchorPoint;
    }
  }

  static Vector3D _perpendicularDir(Object3D obj, Point3D p) {
    final base = obj.pointAValue;
    final dir = _dirOf(obj).normalized();
    final rel = p - base;
    final along = dir * rel.dot(dir);
    final perp = rel - along;
    if (perp.magnitudeSquared > 1e-12) return perp.normalized();
    // Point is on the line: pick any perpendicular direction.
    final ref = dir.cross(Vector3D.unitZ);
    if (!ref.isZero) return ref.normalized();
    return dir.cross(Vector3D.unitX).normalized();
  }

  /// Regular n-gon with AB as one of its edges. The polygon lies in the
  /// plane spanned by AB and a direction perpendicular to it (preferred
  /// near-horizontal so xOy polygons look flat).
  static List<Point3D> _regularPolygon(Point3D a, Point3D b, int n) {
    final d = b - a;
    final len = d.magnitude;
    if (len < 1e-12) return [a];
    if (n < 3) return [a, b];
    final dir = d.normalized();
    var u = dir.cross(Vector3D.unitZ);
    if (u.isZero) u = dir.cross(Vector3D.unitX);
    u = u.normalized();
    final theta = 2 * dart_math.pi / n;
    final radius = len / (2 * dart_math.sin(dart_math.pi / n));
    // The center sits on the perpendicular bisector of AB at distance
    // h = R·cos(π/n) from the AB midpoint.
    final h = radius * dart_math.cos(dart_math.pi / n);
    final center = a.lerp(b, 0.5) + u * h;
    // Angle of A around the center (in the dir/u basis).
    final cosA = -(len / 2) / radius; // = -sin(π/n)
    final sinA = -h / radius; // = -cos(π/n)
    final verts = <Point3D>[];
    for (int i = 0; i < n; i++) {
      final c =
          cosA * dart_math.cos(i * theta) - sinA * dart_math.sin(i * theta);
      final s =
          sinA * dart_math.cos(i * theta) + cosA * dart_math.sin(i * theta);
      verts.add(center + dir * (radius * c) + u * (radius * s));
    }
    // Sanity: vertex 0 must be A and vertex 1 must be B.
    assert(verts[0].distanceTo(a) < 1e-6);
    assert(verts[1].distanceTo(b) < 1e-6);
    return verts;
  }

  /// Circle through 3 points: (center, normal, radius).
  ///
  /// center = a + s·a1 + t·a2 with equal distances to a, b, c:
  ///   s·(a1·a1) + t·(a1·a2) = |a1|²/2
  ///   s·(a1·a2) + t·(a2·a2) = |a2|²/2
  static (Point3D, Vector3D, double)? _circleThrough3(
      Point3D a, Point3D b, Point3D c) {
    final a1 = b - a;
    final a2 = c - a;
    if (a1.cross(a2).magnitudeSquared < 1e-18) return null; // collinear

    final m11 = a1.dot(a1);
    final m12 = a1.dot(a2);
    final m22 = a2.dot(a2);
    final mdet = m11 * m22 - m12 * m12;
    if (mdet.abs() < 1e-18) return null;
    final s = (m11 / 2 * m22 - m12 * m22 / 2) / mdet;
    final t = (m11 * m22 / 2 - m12 * m11 / 2) / mdet;
    final center = a + a1 * s + a2 * t;
    final radius = center.distanceTo(a);
    return (center, a1.cross(a2).normalized(), radius);
  }

  /// Arc through 3 points: (center, normal, radius, startAngle, endAngle)
  /// going from [a] to [c] through [b].
  static (Point3D, Vector3D, double, double, double)? _arcThrough3(
      Point3D a, Point3D b, Point3D c) {
    final circle = _circleThrough3(a, b, c);
    if (circle == null) return null;
    final (center, n, r) = circle;
    final u0 = n.cross(Vector3D.unitZ);
    final u =
        u0.isZero ? n.cross(Vector3D.unitX).normalized() : u0.normalized();
    final v = n.cross(u).normalized();
    double angleOf(Point3D p) {
      final rel = p - center;
      final x = rel.dot(u);
      final y = rel.dot(v);
      var th = dart_math.atan2(y, x);
      if (th < 0) th += 2 * dart_math.pi;
      return th;
    }

    final thA = angleOf(a);
    final thB = angleOf(b);
    final thC = angleOf(c);
    // Choose the arc from A to C that passes through B.
    double start, end;
    final ccw = _isBetween(thA, thB, thC, true);
    if (ccw) {
      start = thA;
      end = thC <= thA ? thC + 2 * dart_math.pi : thC;
    } else {
      start = thA;
      end = thC >= thA ? thC - 2 * dart_math.pi : thC;
    }
    return (center, n, r, start, end);
  }

  /// Whether [x] lies between [from] and [to] going counter-clockwise.
  static bool _isBetween(double from, double x, double to, bool ccw) {
    if (ccw) {
      if (from <= to) return x >= from && x <= to;
      return x >= from || x <= to;
    }
    if (from >= to) return x <= from && x >= to;
    return x <= from || x >= to;
  }

  static List<Point3D> _tetrahedron(Point3D a, Point3D b) {
    final d = b - a;
    final l = d.magnitude;
    if (l < 1e-12) return [a, b, a, a];
    final dir = d.normalized();
    var u = dir.cross(Vector3D.unitZ);
    if (u.isZero) u = dir.cross(Vector3D.unitX);
    u = u.normalized();
    final v = dir.cross(u).normalized();
    final c = a + dir * (l / 2) + v * (dart_math.sqrt(3) / 2 * l);
    // centroid of ABC, then D along u:
    final g = a + dir * (l / 2) + v * (dart_math.sqrt(3) / 6 * l);
    final dpt = g + u * (dart_math.sqrt(2.0 / 3.0) * l);
    return [a, b, c, dpt];
  }

  static const _cubeIndices = [
    0, 1, 2, 0, 2, 3, // bottom
    4, 6, 5, 4, 7, 6, // top
    0, 4, 5, 0, 5, 1, // front
    3, 2, 6, 3, 6, 7, // back
    0, 3, 7, 0, 7, 4, // left
    1, 5, 6, 1, 6, 2, // right
  ];

  static List<Point3D> _cube(Point3D a, Point3D b) {
    final d = b - a;
    final l = d.magnitude;
    if (l < 1e-12) return List.filled(8, a);
    final dir = d.normalized();
    var u = dir.cross(Vector3D.unitZ);
    if (u.isZero) u = dir.cross(Vector3D.unitX);
    u = u.normalized() * l;
    final v = d.cross(u).normalized() * l;
    return [
      a,
      a + d,
      a + d + v,
      a + v,
      a + u,
      a + u + d,
      a + u + d + v,
      a + u + v,
    ];
  }

  // ==================================================================
  // Measurement math
  // ==================================================================

  static ConstructionResult _buildDistance(List<ConstructionInput> inputs) {
    final i0 = inputs[0];
    final i1 = inputs[1];

    double value = 0;
    String text = '';
    Point3D anchor = Point3D.origin;
    Point3D segA = Point3D.origin;
    Point3D segB = Point3D.origin;

    // Point-to-line/plane distance when one input is an object.
    final obj0 = i0 is ObjectInput ? i0.object : null;
    final obj1 = i1 is ObjectInput ? i1.object : null;
    if (obj0 != null &&
        (obj0.type == Object3DType.line || obj0.type == Object3DType.ray)) {
      final p = _pointOf(i1);
      value = distancePointToLine(p, obj0.pointAValue, obj0.vectorValue);
      text = '距离 = ${_fmt(value)}';
      anchor = p;
      segA = p;
      segB = p.closestOnLine(obj0.pointAValue, obj0.vectorValue);
    } else if (obj1 != null &&
        (obj1.type == Object3DType.line || obj1.type == Object3DType.ray)) {
      final p = _pointOf(i0);
      value = distancePointToLine(p, obj1.pointAValue, obj1.vectorValue);
      text = '距离 = ${_fmt(value)}';
      anchor = p;
      segA = p;
      segB = p.closestOnLine(obj1.pointAValue, obj1.vectorValue);
    } else if (obj0 != null && obj0.type == Object3DType.plane) {
      final p = _pointOf(i1);
      final n = obj0.planeNormal;
      value = (n.dot(p.toVector()) - obj0.planeDValue).abs() / n.magnitude;
      text = '距离 = ${_fmt(value)}';
      anchor = p;
      segA = p;
      segB = p.projectedOnPlane(n, obj0.planeDValue);
    } else if (obj1 != null && obj1.type == Object3DType.plane) {
      final p = _pointOf(i0);
      final n = obj1.planeNormal;
      value = (n.dot(p.toVector()) - obj1.planeDValue).abs() / n.magnitude;
      text = '距离 = ${_fmt(value)}';
      anchor = p;
      segA = p;
      segB = p.projectedOnPlane(n, obj1.planeDValue);
    } else {
      final a = _pointOf(i0);
      final b = _pointOf(i1);
      value = a.distanceTo(b);
      text = '距离 = ${_fmt(value)}';
      anchor = a.midpoint(b);
      segA = a;
      segB = b;
    }

    final created = <Object3D>[
      Object3D.measurement(text, anchor,
          name: _uniqueName('m'), style: const ObjectStyle(color: 0xFF00695C)),
    ];
    if (segA.distanceTo(segB) > 1e-9) {
      created.add(Object3D.segment(segA, segB,
          name: _uniqueName('d'),
          style: const ObjectStyle(
              color: 0xFF00695C,
              lineStyle: LineStyle.shortDash,
              opacity: 0.8)));
    }
    return ConstructionResult(created: created);
  }

  static ConstructionResult _buildAngle(List<ConstructionInput> inputs) {
    final apex = _pointOf(inputs[0]);
    final p1 = _pointOf(inputs[1]);
    final p2 = _pointOf(inputs[2]);
    final v1 = p1 - apex;
    final v2 = p2 - apex;
    if (v1.isZero || v2.isZero) return const ConstructionResult();
    final cosA = (v1.dot(v2) / (v1.magnitude * v2.magnitude)).clamp(-1.0, 1.0);
    final deg = dart_math.acos(cosA) * 180 / dart_math.pi;
    return ConstructionResult(created: [
      Object3D.measurement('角度 = ${_fmt(deg)}°', apex,
          name: _uniqueName('a'), style: const ObjectStyle(color: 0xFF00695C)),
      Object3D.segment(apex, p1,
          name: _uniqueName('s'),
          style: const ObjectStyle(
              color: 0xFF00695C, lineStyle: LineStyle.shortDash, opacity: 0.8)),
      Object3D.segment(apex, p2,
          name: _uniqueName('s'),
          style: const ObjectStyle(
              color: 0xFF00695C, lineStyle: LineStyle.shortDash, opacity: 0.8)),
    ]);
  }

  static double? _areaOf(Object3D obj) {
    switch (obj.type) {
      case Object3DType.polygon:
        final v = obj.polygonVertices;
        if (v.length < 3) return null;
        // Sum of triangle areas via cross products.
        final n = (v[1] - v[0]).cross(v[2] - v[0]).normalized();
        var area = 0.0;
        for (int i = 1; i < v.length - 1; i++) {
          final tri = (v[i] - v[0]).cross(v[i + 1] - v[0]);
          area += tri.dot(n).abs() / 2;
        }
        return area;
      case Object3DType.circle:
        return dart_math.pi * obj.circleRadius! * obj.circleRadius!;
      default:
        return null;
    }
  }

  static double? _volumeOf(Object3D obj) {
    switch (obj.type) {
      case Object3DType.sphere:
        return 4 /
            3 *
            dart_math.pi *
            dart_math.pow(obj.sphereRadius, 3).toDouble();
      case Object3DType.cone:
        return dart_math.pi *
            obj.solidRadius *
            obj.solidRadius *
            obj.solidHeight /
            3;
      case Object3DType.cylinder:
        return dart_math.pi *
            obj.solidRadius *
            obj.solidRadius *
            obj.solidHeight;
      case Object3DType.polyhedron:
        final m = obj.mesh;
        if (m == null || m.isEmpty) return null;
        // Tetrahedralize from the centroid of the vertices.
        var sx = 0.0, sy = 0.0, sz = 0.0;
        for (final v in m.vertices) {
          sx += v.x;
          sy += v.y;
          sz += v.z;
        }
        final p = Point3D(sx / m.vertices.length, sy / m.vertices.length,
            sz / m.vertices.length);
        var vol = 0.0;
        for (int i = 0; i < m.indices.length; i += 3) {
          final a = m.vertices[m.indices[i]];
          final b = m.vertices[m.indices[i + 1]];
          final c = m.vertices[m.indices[i + 2]];
          vol += (a - p).dot((b - p).cross(c - p)).abs() / 6;
        }
        return vol;
      default:
        return null;
    }
  }

  static ConstructionResult _buildIntersection(List<ConstructionInput> inputs) {
    final obj0 = _objectOf(inputs[0]);
    final obj1 = _objectOf(inputs[1]);
    final created = <Object3D>[];
    final type0 = obj0.type;
    final type1 = obj1.type;

    bool isLineLike(Object3DType t) =>
        t == Object3DType.line ||
        t == Object3DType.ray ||
        t == Object3DType.segment;
    bool isPlaneLike(Object3DType t) => t == Object3DType.plane;

    // line × line — reject intersections that lie outside a segment/ray.
    if (isLineLike(type0) && isLineLike(type1)) {
      final res = intersectLineLine(
          obj0.pointAValue, _dirOf(obj0), obj1.pointAValue, _dirOf(obj1));
      if (res != null &&
          paramInLineRange(type0, res.$2) &&
          paramInLineRange(type1, res.$3)) {
        created.add(
            Object3D.point(res.$1, name: _uniqueName('I'), style: _pointStyle));
      }
      return ConstructionResult(created: created);
    }

    bool onLineLike(Object3D obj, double t) => paramInLineRange(obj.type, t);

    // line × plane — same range check on the line parameter.
    if (isLineLike(type0) && isPlaneLike(type1)) {
      final p = intersectLinePlane(
          obj0.pointAValue, _dirOf(obj0), obj1.planeNormal, obj1.planeDValue);
      if (p != null && onLineLike(obj0, _tOf(obj0, p))) {
        created
            .add(Object3D.point(p, name: _uniqueName('I'), style: _pointStyle));
      }
      return ConstructionResult(created: created);
    }
    if (isPlaneLike(type0) && isLineLike(type1)) {
      final p = intersectLinePlane(
          obj1.pointAValue, _dirOf(obj1), obj0.planeNormal, obj0.planeDValue);
      if (p != null && onLineLike(obj1, _tOf(obj1, p))) {
        created
            .add(Object3D.point(p, name: _uniqueName('I'), style: _pointStyle));
      }
      return ConstructionResult(created: created);
    }

    // plane × plane → intersection line
    if (isPlaneLike(type0) && isPlaneLike(type1)) {
      final res = intersectPlanePlane(obj0.planeNormal, obj0.planeDValue,
          obj1.planeNormal, obj1.planeDValue);
      if (res != null) {
        created.add(Object3D.line(res.$1, res.$2,
            name: _uniqueName('l'), style: _lineStyle));
      }
      return ConstructionResult(created: created);
    }

    // line × circle / line × polygon (plane + circle check)
    if (isLineLike(type0) && type1 == Object3DType.circle ||
        type0 == Object3DType.circle && isLineLike(type1)) {
      final line = isLineLike(type0) ? obj0 : obj1;
      final circle = type0 == Object3DType.circle ? obj0 : obj1;
      final c = circle.circleCenter ?? Point3D.origin;
      final n = (circle.circleNormal ?? Vector3D.unitZ).normalized();
      final r = circle.circleRadius ?? 1;
      final hit = intersectLinePlane(
          line.pointAValue, _dirOf(line), n, n.dot(c.toVector()));
      if (hit != null &&
          onLineLike(line, _tOf(line, hit)) &&
          hit.distanceTo(c) <= r * 1.0001) {
        created.add(
            Object3D.point(hit, name: _uniqueName('I'), style: _pointStyle));
      }
      return ConstructionResult(created: created);
    }

    // line × sphere
    if (isLineLike(type0) && type1 == Object3DType.sphere ||
        type0 == Object3DType.sphere && isLineLike(type1)) {
      final line = isLineLike(type0) ? obj0 : obj1;
      final sphere = type0 == Object3DType.sphere ? obj0 : obj1;
      final pts = _lineSphereIntersection(line.pointAValue, _dirOf(line),
          sphere.sphereCenter, sphere.sphereRadius);
      for (final p in pts) {
        if (onLineLike(line, _tOf(line, p))) {
          created.add(
              Object3D.point(p, name: _uniqueName('I'), style: _pointStyle));
        }
      }
      return ConstructionResult(created: created);
    }

    // plane × sphere → circle
    if (isPlaneLike(type0) && type1 == Object3DType.sphere ||
        type0 == Object3DType.sphere && isPlaneLike(type1)) {
      final plane = isPlaneLike(type0) ? obj0 : obj1;
      final sphere = type0 == Object3DType.sphere ? obj0 : obj1;
      final n = plane.planeNormal.normalized();
      // Plane equation N·p = d with a possibly unnormalized normal N:
      // signed distance = N̂·center - d/|N| (NOT (N̂·center - d)/|N|).
      final dist = n.dot(sphere.sphereCenter.toVector()) -
          plane.planeDValue / plane.planeNormal.magnitude;
      if (dist.abs() < sphere.sphereRadius) {
        final r = dart_math
            .sqrt(sphere.sphereRadius * sphere.sphereRadius - dist * dist);
        final center = sphere.sphereCenter + n * (-dist);
        created.add(Object3D.circle(center, n, r,
            name: _uniqueName('c'), style: _curveStyle));
      }
      return ConstructionResult(created: created);
    }

    return ConstructionResult(created: created);
  }

  /// Intersection points of a line with a sphere (0, 1 or 2 points).
  static List<Point3D> _lineSphereIntersection(
      Point3D a, Vector3D dir, Point3D center, double r) {
    final d = dir.normalized();
    final oc = a - center;
    final b = oc.dot(d);
    final cc = oc.dot(oc) - r * r;
    final disc = b * b - cc;
    if (disc < 0) return const [];
    final sq = dart_math.sqrt(disc);
    return [a + d * (-b - sq), a + d * (-b + sq)];
  }
}

/// Whether the intersect tool implements the type pair (a, b).
bool intersectionSupported(Object3DType a, Object3DType b) {
  bool lineLike(Object3DType t) =>
      t == Object3DType.line ||
      t == Object3DType.ray ||
      t == Object3DType.segment;
  if (lineLike(a) && lineLike(b)) return true;
  if (lineLike(a) && b == Object3DType.plane ||
      a == Object3DType.plane && lineLike(b)) {
    return true;
  }
  if (a == Object3DType.plane && b == Object3DType.plane) return true;
  if (lineLike(a) && b == Object3DType.circle ||
      a == Object3DType.circle && lineLike(b)) {
    return true;
  }
  if (lineLike(a) && b == Object3DType.sphere ||
      a == Object3DType.sphere && lineLike(b)) {
    return true;
  }
  if (a == Object3DType.plane && b == Object3DType.sphere ||
      a == Object3DType.sphere && b == Object3DType.plane) {
    return true;
  }
  return false;
}
