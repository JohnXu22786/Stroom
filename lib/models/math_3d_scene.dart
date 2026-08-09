import 'dart:math' as dart_math;

import 'math_3d_object.dart';

// ======================================================================
// 3D 场景与相机
//
// Z-up 右手坐标系。相机为球形环绕相机：theta 为方位角（绕 Z 轴），
// phi 为仰角（0 = 水平，默认等距视角 ~35.26°）。
// ======================================================================

/// Type of 3D projection (GeoGebra: Parallel / Perspective / 3D Glasses / Oblique).
enum ProjectionType {
  /// Orthographic (parallel) projection — no foreshortening.
  parallel,

  /// Perspective projection with foreshortening.
  perspective,

  /// Oblique (cabinet) projection — xOy plane is face-on, Z sheared.
  oblique,

  /// Anaglyph "3D glasses" projection (rendered as perspective).
  anaglyph,
}

/// A 3D camera controlled via spherical coordinates around a target point.
class Camera3D {
  final Point3D target;
  final double distance;
  final double theta; // azimuth around Z axis (radians)
  final double phi; // elevation above xOy plane (radians)

  const Camera3D({
    this.target = Point3D.origin,
    this.distance = 12,
    this.theta = dart_math.pi / 4,
    this.phi = 0.6154797086703874, // ~35.26°, isometric-ish default view
  });

  /// Camera position in world space.
  Point3D get position {
    final cp = dart_math.cos(phi).clamp(-1.0, 1.0).toDouble();
    final sp = dart_math.sin(phi);
    final ct = dart_math.cos(theta);
    final st = dart_math.sin(theta);
    return Point3D(
      target.x + distance * cp * ct,
      target.y + distance * cp * st,
      target.z + distance * sp,
    );
  }

  /// Right vector of the view (screen +x in world space).
  Vector3D get rightVector {
    final f = forward;
    final up = Vector3D.unitZ;
    var r = f.cross(up);
    if (r.magnitudeSquared < 1e-12) {
      r = f.cross(Vector3D.unitY);
    }
    return r.normalized();
  }

  /// Camera up vector (screen -y in world space).
  Vector3D get upVector => rightVector.cross(forward).normalized();

  /// Forward direction (target - position).
  Vector3D get forward => (target - position).normalized();

  /// Orbit the camera around the target.
  Camera3D orbit({required double deltaTheta, required double deltaPhi}) {
    return Camera3D(
      target: target,
      distance: distance,
      theta: theta + deltaTheta,
      phi: (phi + deltaPhi)
          .clamp(-dart_math.pi / 2 + 0.01, dart_math.pi / 2 - 0.01),
    );
  }

  /// Zoom by a factor: factor > 1 moves the camera closer.
  Camera3D zoom({required double factor}) {
    final newDistance = (distance / factor).clamp(0.05, 5000).toDouble();
    return Camera3D(
      target: target,
      distance: newDistance,
      theta: theta,
      phi: phi,
    );
  }

  /// Pan: move target parallel to the view plane (screen-space deltas).
  Camera3D pan({required double deltaX, required double deltaY}) {
    final scale = distance * 0.004;
    final r = rightVector;
    final u = upVector;
    return Camera3D(
      target: target + r * (-deltaX * scale) + u * (deltaY * scale),
      distance: distance,
      theta: theta,
      phi: phi,
    );
  }

  /// One of the standard GeoGebra views.
  Camera3D withStandardView(StandardView view) {
    switch (view) {
      case StandardView.defaultView:
        return Camera3D(target: target, distance: distance);
      case StandardView.viewFromTop: // xOy
        return Camera3D(
            target: target,
            distance: distance,
            theta: 0,
            phi: dart_math.pi / 2 - 0.001);
      case StandardView.viewFromFront: // xOz
        return Camera3D(target: target, distance: distance, theta: 0, phi: 0);
      case StandardView.viewFromRight: // yOz
        return Camera3D(
            target: target,
            distance: distance,
            theta: dart_math.pi / 2,
            phi: 0);
    }
  }

  Camera3D copyWith({
    Point3D? target,
    double? distance,
    double? theta,
    double? phi,
  }) {
    return Camera3D(
      target: target ?? this.target,
      distance: distance ?? this.distance,
      theta: theta ?? this.theta,
      phi: phi ?? this.phi,
    );
  }
}

/// Standard view directions (GeoGebra style bar).
enum StandardView {
  defaultView,
  viewFromTop,
  viewFromFront,
  viewFromRight,
}

// ======================================================================
// Projection
// ======================================================================

/// A projected screen point: pixel (x, y) with depth for z-sorting.
class ScreenPoint {
  final double x;
  final double y;
  final double z; // view-space depth (larger = farther from camera)

  const ScreenPoint(this.x, this.y, this.z);

  @override
  String toString() => 'Screen($x, $y, z=$z)';
}

/// A world-space ray (used for picking and construction).
class Ray3D {
  final Point3D origin;
  final Vector3D direction;

  const Ray3D(this.origin, this.direction);

  Point3D at(double t) => origin + direction * t;

  /// Intersection with the plane n·p = d. Returns null if parallel.
  Point3D? intersectPlane(Vector3D n, double d) {
    final denom = direction.dot(n);
    if (denom.abs() < 1e-12) return null;
    final t = (d - n.dot(origin.toVector())) / denom;
    if (t < 0) return null;
    return at(t);
  }
}

/// A 3D projection mapping world coordinates to screen coordinates.
class Projection3D {
  final ProjectionType type;
  final double width;
  final double height;
  final Camera3D camera;

  const Projection3D({
    required this.type,
    required this.width,
    required this.height,
    required this.camera,
  });

  /// Scale: world units → pixels (parallel/oblique use a fixed scale;
  /// perspective is derived from distance so the target scales similarly).
  double get scale {
    // Keep the "visible height" roughly constant: 800 px shows `distance` units.
    return (800 / camera.distance).clamp(0.01, 10000.0);
  }

  double get _shear => 0.5; // cabinet projection shear

  /// Project a world point to screen. Returns null if behind the camera
  /// (perspective only; parallel always projects).
  ScreenPoint? project(Point3D p) {
    final ScreenPoint s;
    switch (type) {
      case ProjectionType.parallel:
        s = _projectParallel(p);
      case ProjectionType.perspective:
      case ProjectionType.anaglyph:
        s = _projectPerspective(p);
      case ProjectionType.oblique:
        s = _projectOblique(p);
    }
    if (s.x.isNaN || s.y.isNaN) return null;
    return s;
  }

  ScreenPoint _projectParallel(Point3D p) {
    final f = camera.forward;
    final r = camera.rightVector;
    final u = camera.upVector;
    final pos = camera.position;

    final rel = p - pos;
    final vx = rel.dot(r);
    final vy = rel.dot(u);
    final vz = rel.dot(f); // view depth, larger = farther

    final cx = width / 2 + vx * scale;
    final cy = height / 2 - vy * scale;
    return ScreenPoint(cx, cy, vz);
  }

  ScreenPoint _projectPerspective(Point3D p) {
    final f = camera.forward;
    final r = camera.rightVector;
    final u = camera.upVector;
    final pos = camera.position;

    final rel = p - pos;
    final vx = rel.dot(r);
    final vy = rel.dot(u);
    final vz = rel.dot(f);

    if (vz <= 0.05) {
      // Behind or too close to the camera — project to NaN so callers can
      // skip the point.
      return ScreenPoint(double.nan, double.nan, vz);
    }
    // Perspective: focal length in pixels such that the target plane
    // (distance) maps 1:1 with the parallel scale.
    final fovRad = 60 * dart_math.pi / 180;
    final focal = (height / 2) / dart_math.tan(fovRad / 2);
    final inv = focal / vz;
    return ScreenPoint(width / 2 + vx * inv, height / 2 - vy * inv, vz);
  }

  ScreenPoint _projectOblique(Point3D p) {
    // Cabinet projection: xOy face-on (x right, y up), Z sheared at 45°.
    final cx = width / 2 + (p.x + p.y * _shear * 0.7071) * scale;
    final cy = height / 2 - (p.y * _shear * 0.7071 + p.z) * scale;
    final depth = -p.y; // farther along -y
    return ScreenPoint(cx, cy, depth);
  }

  /// A world-space ray through a screen point (for picking / construction).
  Ray3D screenRay(double screenX, double screenY) {
    switch (type) {
      case ProjectionType.parallel:
        final f = camera.forward;
        final r = camera.rightVector;
        final u = camera.upVector;
        final pos = camera.position;
        final ndcX = (screenX - width / 2) / scale;
        final ndcY = -(screenY - height / 2) / scale;
        final origin = pos + r * ndcX + u * ndcY;
        return Ray3D(origin, f);
      case ProjectionType.perspective:
      case ProjectionType.anaglyph:
        final f = camera.forward;
        final r = camera.rightVector;
        final u = camera.upVector;
        final pos = camera.position;
        final fovRad = 60 * dart_math.pi / 180;
        final focal = (height / 2) / dart_math.tan(fovRad / 2);
        final ndcX = (screenX - width / 2) / focal;
        final ndcY = -(screenY - height / 2) / focal;
        final dir = (f + r * ndcX + u * ndcY).normalized();
        return Ray3D(pos, dir);
      case ProjectionType.oblique:
        // Invert the cabinet projection. Screen: u = x + y·s, v = -(z + y·s)
        // with s = shear·cos45°. A screen point maps to a ray parallel to
        // (-s, 1, -s). Parameterize with y = 0 as origin.
        final s = _shear * 0.7071;
        final u = (screenX - width / 2) / scale;
        final v = (screenY - height / 2) / scale;
        return Ray3D(Point3D(u, 0, -v), Vector3D(-s, 1, -s));
    }
  }

  /// Intersect the screen ray with the z = [z0] horizontal plane.
  Point3D? screenToGround(double screenX, double screenY, {double z0 = 0}) {
    final ray = screenRay(screenX, screenY);
    return ray.intersectPlane(Vector3D.unitZ, z0);
  }
}

// ======================================================================
// Geometry utilities (lines/planes/intersections)
// ======================================================================

/// Minimal distance from point [p] to the infinite line a + t·d.
double distancePointToLine(Point3D p, Point3D a, Vector3D d) {
  final len2 = d.magnitudeSquared;
  if (len2 < 1e-15) return p.distanceTo(a);
  return (p - a).cross(d).magnitude / dart_math.sqrt(len2);
}

/// Distance from point [p] to segment [a]-[b].
double distancePointToSegment(Point3D p, Point3D a, Point3D b) {
  return p.distanceTo(p.closestOnSegment(a, b));
}

/// Intersection of two infinite lines. Returns null if parallel/skew.
Point3D? intersectLineLine(Point3D a1, Vector3D d1, Point3D a2, Vector3D d2) {
  final n = d1.cross(d2);
  final nLen2 = n.magnitudeSquared;
  if (nLen2 < 1e-18) return null;
  final a2a1 = a2 - a1;
  final t = a2a1.cross(d2).dot(n) / nLen2;
  final s = a2a1.cross(d1).dot(n) / nLen2;
  // Coplanar and intersecting within tolerance
  final p1 = a1 + d1 * t;
  final p2 = a2 + d2 * s;
  if (p1.distanceTo(p2) > 1e-6) return null; // skew
  return p1;
}

/// Intersection of line with plane n·p = d. Returns null if parallel.
Point3D? intersectLinePlane(Point3D a, Vector3D d, Vector3D n, double planeD) {
  final denom = d.dot(n);
  if (denom.abs() < 1e-12) return null;
  final t = (planeD - n.dot(a.toVector())) / denom;
  return a + d * t;
}

/// Intersection of two planes. Returns (pointOnLine, direction) or null.
(Point3D, Vector3D)? intersectPlanePlane(
    Vector3D n1, double d1, Vector3D n2, double d2) {
  final dir = n1.cross(n2);
  if (dir.magnitudeSquared < 1e-18) return null;
  final n1n = n1.normalized();
  // A point on both planes: solve with a reference plane through origin.
  final n3 = dir.normalized();
  // Use linear solve on (n1, n2, n3)·p = (d1, d2, 0)
  final m = [
    [n1n.x, n1n.y, n1n.z],
    [n2.x, n2.y, n2.z],
    [n3.x, n3.y, n3.z],
  ];
  final rhs = [d1 / n1n.magnitude, d2, 0.0];
  final det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
      m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  if (det.abs() < 1e-12) return null;
  final invDet = 1 / det;
  final px = (m[1][1] * m[2][2] - m[1][2] * m[2][1]) * rhs[0] +
      (m[0][2] * m[2][1] - m[0][1] * m[2][2]) * rhs[1] +
      (m[0][1] * m[1][2] - m[0][2] * m[1][1]) * rhs[2];
  final py = (m[1][2] * m[2][0] - m[1][0] * m[2][2]) * rhs[0] +
      (m[0][0] * m[2][2] - m[0][2] * m[2][0]) * rhs[1] +
      (m[0][2] * m[1][0] - m[0][0] * m[1][2]) * rhs[2];
  final pz = (m[1][0] * m[2][1] - m[1][1] * m[2][0]) * rhs[0] +
      (m[0][1] * m[2][0] - m[0][0] * m[2][1]) * rhs[1] +
      (m[0][0] * m[1][1] - m[0][1] * m[1][0]) * rhs[2];
  return (Point3D(px * invDet, py * invDet, pz * invDet), dir);
}

/// Möller–Trumbore ray-triangle intersection. Returns t or null.
///
/// Barycentric bounds use a small epsilon so rays hitting exactly on a
/// vertex or edge are accepted (floating-point sign noise at u/v ≈ 0 must
/// not reject legitimate hits).
double? rayTriangle(
    Point3D origin, Vector3D dir, Point3D v0, Point3D v1, Point3D v2) {
  const eps = 1e-9;
  final e1 = v1 - v0;
  final e2 = v2 - v0;
  final p = dir.cross(e2);
  final det = e1.dot(p);
  if (det.abs() < 1e-12) return null;
  final inv = 1 / det;
  final tvec = origin - v0;
  final u = tvec.dot(p) * inv;
  if (u < -eps || u > 1 + eps) return null;
  final q = tvec.cross(e1);
  final v = dir.dot(q) * inv;
  if (v < -eps || u + v > 1 + eps) return null;
  final t = e2.dot(q) * inv;
  if (t < 0) return null;
  return t;
}

// ======================================================================
// Scene
// ======================================================================

/// A 3D scene: objects + camera + projection settings.
class Scene3D {
  final List<Object3D> _objects = [];
  Camera3D _camera = const Camera3D();
  ProjectionType _projectionType = ProjectionType.parallel;
  double _canvasWidth = 800;
  double _canvasHeight = 600;

  Camera3D get camera => _camera;
  ProjectionType get projectionType => _projectionType;

  /// Unmodifiable view of the objects.
  List<Object3D> get objects => List.unmodifiable(_objects);

  /// The projection object matching the current state.
  Projection3D get projection => Projection3D(
        type: _projectionType,
        width: _canvasWidth,
        height: _canvasHeight,
        camera: _camera,
      );

  void setViewport(double width, double height) {
    _canvasWidth = width;
    _canvasHeight = height;
  }

  void setCamera(Camera3D camera) {
    _camera = camera;
  }

  void setProjectionType(ProjectionType type) {
    _projectionType = type;
  }

  void add(Object3D object) {
    _objects.add(object);
  }

  void remove(Object3D object) {
    _objects.remove(object);
  }

  void removeWhere(bool Function(Object3D) test) {
    _objects.removeWhere(test);
  }

  /// Replace an object with a transformed copy (keeps position in list).
  void replace(Object3D oldObj, Object3D newObj) {
    final idx = _objects.indexOf(oldObj);
    if (idx >= 0) {
      _objects[idx] = newObj;
    }
  }

  void clear() {
    _objects.clear();
  }

  Object3D? byName(String name) {
    for (final o in _objects) {
      if (o.name == name) return o;
    }
    return null;
  }

  /// Next free GeoGebra-style label: A, B, C … Z, A1, B1, …
  String nextPointName() => _nextLabel('point');
  String nextLineName() => _nextLabel('line');
  String nextCurveName() => _nextLabel('curve');
  String nextSolidName() => _nextLabel('solid');

  String _nextLabel(String kind) {
    final used = _objects.map((o) => o.name).toSet();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int round = 0; round < 100; round++) {
      for (int i = 0; i < 26; i++) {
        final name = round == 0 ? letters[i] : '${letters[i]}${round + 1}';
        if (!used.contains(name)) return name;
      }
    }
    return 'X${used.length}';
  }

  /// Bounding box of all visible objects (null if empty).
  (Point3D, Point3D)? boundingBox({bool visibleOnly = true}) {
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity,
        maxY = -double.infinity,
        maxZ = -double.infinity;
    for (final o in _objects) {
      if (visibleOnly && !o.visible) continue;
      for (final p in o.samplePoints()) {
        if (!p.isFinite) continue;
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.z < minZ) minZ = p.z;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
        if (p.z > maxZ) maxZ = p.z;
      }
    }
    if (minX > maxX) return null;
    return (Point3D(minX, minY, minZ), Point3D(maxX, maxY, maxZ));
  }

  /// Center of the visible scene.
  Point3D get sceneCenter {
    final bb = boundingBox();
    if (bb == null) return _camera.target;
    final (min, max) = bb;
    return Point3D(
      (min.x + max.x) / 2,
      (min.y + max.y) / 2,
      (min.z + max.z) / 2,
    );
  }

  /// Adjust the camera so all visible objects fit the view.
  void fitToView() {
    final bb = boundingBox();
    if (bb == null) return;
    final (min, max) = bb;
    final size = Point3D(max.x - min.x, max.y - min.y, max.z - min.z);
    final newTarget = Point3D(
      (min.x + max.x) / 2,
      (min.y + max.y) / 2,
      (min.z + max.z) / 2,
    );
    // Distance such that the bounding sphere fits with margin.
    final radius =
        dart_math.sqrt(size.x * size.x + size.y * size.y + size.z * size.z) / 2;
    final newDistance = (radius * 2.2).clamp(1.0, 5000.0);
    _camera = Camera3D(
      target: newTarget,
      distance: newDistance,
      theta: _camera.theta,
      phi: _camera.phi,
    );
  }

  // ==================================================================
  // Picking
  // ==================================================================

  /// Pick the top-most object under the given screen point.
  ///
  /// Returns the object and the world-space point on it, or null.
  (Object3D, Point3D)? pick(double screenX, double screenY,
      {double pickRadius = 12}) {
    final proj = projection;
    final ray = proj.screenRay(screenX, screenY);

    (Object3D, Point3D, double)? best; // obj, point, screen distance
    for (final obj in _objects) {
      if (!obj.visible) continue;
      final hit = _pickObject(obj, ray, proj, screenX, screenY, pickRadius);
      if (hit != null) {
        if (best == null || hit.$3 < best.$3) best = hit;
      }
    }
    if (best == null) return null;
    return (best.$1, best.$2);
  }

  (Object3D, Point3D, double)? _pickObject(Object3D obj, Ray3D ray,
      Projection3D proj, double sx, double sy, double radius) {
    switch (obj.type) {
      case Object3DType.point:
        final s = proj.project(obj.pointValue);
        if (s == null || s.x.isNaN) return null;
        final d =
            dart_math.sqrt((s.x - sx) * (s.x - sx) + (s.y - sy) * (s.y - sy));
        if (d <= radius * 0.8) {
          return (obj, obj.pointValue, d);
        }
        return null;

      case Object3DType.segment:
      case Object3DType.vector:
        final a = proj.project(obj.pointAValue);
        final b = proj.project(obj.pointBValue);
        if (a == null || b == null) return null;
        final d = _screenDistanceToSegment(sx, sy, a, b);
        if (d <= radius) {
          final world =
              closestOnSegmentToRay(obj.pointAValue, obj.pointBValue, ray);
          return (obj, world, d);
        }
        return null;

      case Object3DType.line:
      case Object3DType.ray:
        final tMax = 40.0 / obj.vectorValue.magnitude;
        final end = obj.pointAValue + obj.vectorValue * tMax;
        final a = proj.project(obj.pointAValue);
        final b = proj.project(end);
        if (a == null || b == null) return null;
        final d = _screenDistanceToSegment(sx, sy, a, b);
        if (d <= radius) {
          final world = closestOnSegmentToRay(obj.pointAValue, end, ray);
          return (obj, world, d);
        }
        return null;

      case Object3DType.circle:
      case Object3DType.arc:
        final pts = obj.samplePoints();
        if (pts.length < 2) return null;
        var bestD = double.infinity;
        for (int i = 0; i < pts.length - 1; i++) {
          final a = proj.project(pts[i]);
          final b = proj.project(pts[i + 1]);
          if (a == null || b == null) continue;
          final d = _screenDistanceToSegment(sx, sy, a, b);
          if (d < bestD) bestD = d;
        }
        if (bestD <= radius) {
          final c = obj.circleCenter ?? Point3D.origin;
          final n = (obj.circleNormal ?? Vector3D.unitZ).normalized();
          final hit = ray.intersectPlane(n, n.dot(c.toVector()));
          final world = obj.inputPoint(hit ?? c);
          return (obj, world, bestD);
        }
        return null;

      case Object3DType.polygon:
        final hit =
            _pickMeshFace(ray, obj.polygonVertices, proj, sx, sy, radius);
        if (hit != null) {
          final snap = obj.inputPoint(hit.$1);
          return (obj, snap, hit.$2);
        }
        return null;

      case Object3DType.plane:
        final hit = ray.intersectPlane(obj.planeNormal, obj.planeDValue);
        if (hit != null) {
          final s = proj.project(hit);
          if (s == null || s.x.isNaN) return null;
          final d =
              dart_math.sqrt((s.x - sx) * (s.x - sx) + (s.y - sy) * (s.y - sy));
          if (d <= radius * 6) {
            return (obj, hit, d);
          }
        }
        return null;

      case Object3DType.sphere:
      case Object3DType.cone:
      case Object3DType.cylinder:
      case Object3DType.polyhedron:
      case Object3DType.surface:
        final mesh = _meshFor(obj);
        if (mesh == null || mesh.isEmpty) return null;
        var bestT = double.infinity;
        for (int i = 0; i < mesh.indices.length; i += 3) {
          final v0 = mesh.vertices[mesh.indices[i]];
          final v1 = mesh.vertices[mesh.indices[i + 1]];
          final v2 = mesh.vertices[mesh.indices[i + 2]];
          final t = rayTriangle(ray.origin, ray.direction, v0, v1, v2);
          if (t != null && t < bestT) bestT = t;
        }
        if (bestT.isFinite) {
          final world = ray.at(bestT);
          final s = proj.project(world);
          if (s == null || s.x.isNaN) return null;
          final d =
              dart_math.sqrt((s.x - sx) * (s.x - sx) + (s.y - sy) * (s.y - sy));
          return (obj, world, d);
        }
        return null;

      case Object3DType.curve:
        final pts = obj.curveSamplePoints;
        var bestD = double.infinity;
        Point3D? bestWorld;
        for (int i = 0; i < pts.length - 1; i++) {
          final a = proj.project(pts[i]);
          final b = proj.project(pts[i + 1]);
          if (a == null || b == null) continue;
          final d = _screenDistanceToSegment(sx, sy, a, b);
          if (d < bestD) {
            bestD = d;
            bestWorld = closestOnSegmentToRay(pts[i], pts[i + 1], ray);
          }
        }
        if (bestD <= radius && bestWorld != null) {
          return (obj, bestWorld, bestD);
        }
        return null;

      case Object3DType.measurement:
        return null;
    }
  }

  /// Closest point on segment [a]-[b] to the given ray.
  static Point3D closestOnSegmentToRay(Point3D a, Point3D b, Ray3D ray) {
    final e = b - a;
    final d = ray.direction;
    final w = a - ray.origin;
    final ee = e.magnitudeSquared;
    final dd = d.magnitudeSquared;
    final ed = e.dot(d);
    final we = w.dot(e);
    final wd = w.dot(d);
    final denom = ee * dd - ed * ed;

    double s, t;
    if (denom.abs() < 1e-12) {
      // Segment and ray are parallel: pick the closest endpoint.
      final tAtA = wd / dd;
      final tAtB = (wd + ed) / dd;
      s = tAtA.clamp(0.0, 1.0) <= tAtB.clamp(0.0, 1.0) ? 0.0 : 1.0;
      t = s == 0.0 ? tAtA : tAtB;
    } else {
      s = (ed * wd - we * dd) / denom;
      t = (ee * wd - we * ed) / denom;
    }
    if (s < 0) {
      s = 0;
      t = -wd / dd;
    } else if (s > 1) {
      s = 1;
      t = -(wd + ed) / dd;
    }
    if (t < 0) {
      t = 0;
      s = -we / ee;
      s = s.clamp(0.0, 1.0);
    }
    return a + e * s.clamp(0.0, 1.0);
  }

  /// Triangle hit test for polygons (single face).
  (Point3D, double)? _pickMeshFace(Ray3D ray, List<Point3D> verts,
      Projection3D proj, double sx, double sy, double radius) {
    if (verts.length < 3) return null;
    double? bestT;
    for (int i = 0; i < verts.length - 2; i++) {
      final t = rayTriangle(
          ray.origin, ray.direction, verts[0], verts[i + 1], verts[i + 2]);
      if (t != null && (bestT == null || t < bestT)) bestT = t;
    }
    if (bestT == null) return null;
    final world = ray.at(bestT);
    final s = proj.project(world);
    if (s == null || s.x.isNaN) return null;
    final d = dart_math.sqrt((s.x - sx) * (s.x - sx) + (s.y - sy) * (s.y - sy));
    if (d > radius * 2.5) return null;
    return (world, d);
  }

  static MeshData? _meshFor(Object3D obj) {
    switch (obj.type) {
      case Object3DType.sphere:
        return MeshBuilder.sphere(obj.sphereRadius, segments: 16);
      case Object3DType.cone:
        return MeshBuilder.cone(obj.solidRadius, obj.solidHeight);
      case Object3DType.cylinder:
        return MeshBuilder.cylinder(obj.solidRadius, obj.solidHeight);
      case Object3DType.polyhedron:
      case Object3DType.surface:
        return obj.mesh;
      default:
        return null;
    }
  }

  static double _screenDistanceToSegment(
      double px, double py, ScreenPoint a, ScreenPoint b) {
    final ax = a.x, ay = a.y, bx = b.x, by = b.y;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    double t;
    if (len2 < 1e-12) {
      t = 0;
    } else {
      t = ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
    }
    final cx = ax + t * dx, cy = ay + t * dy;
    return dart_math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}
