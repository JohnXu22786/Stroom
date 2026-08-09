import 'dart:math' as dart_math;

// ======================================================================
// 3D 数学模块核心对象模型
//
// 坐标约定（与 GeoGebra 3D 一致）：右手系，Z 轴向上，
// xOy 平面为地面（网格、2D 联动均在此平面）。
// ======================================================================

/// A 3D point with x, y, z coordinates.
class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);

  /// Origin at (0, 0, 0).
  static const origin = Point3D(0, 0, 0);

  /// Subtract another point to get a vector.
  Vector3D operator -(Point3D other) =>
      Vector3D(x - other.x, y - other.y, z - other.z);

  /// Add a vector to get a new point.
  Point3D operator +(Vector3D v) => Point3D(x + v.x, y + v.y, z + v.z);

  /// Euclidean distance to another point.
  double distanceTo(Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return dart_math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Squared distance to another point (cheaper).
  double distanceToSquared(Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return dx * dx + dy * dy + dz * dz;
  }

  /// Midpoint between this and another point.
  Point3D midpoint(Point3D other) => Point3D(
        (x + other.x) / 2,
        (y + other.y) / 2,
        (z + other.z) / 2,
      );

  /// Convert to a position vector (from origin).
  Vector3D toVector() => Vector3D(x, y, z);

  /// Linear interpolation: this + t * (other - this).
  Point3D lerp(Point3D other, double t) => Point3D(
        x + (other.x - x) * t,
        y + (other.y - y) * t,
        z + (other.z - z) * t,
      );

  /// Closest point on segment [a]-[b] to this point.
  Point3D closestOnSegment(Point3D a, Point3D b) {
    final ab = b - a;
    final len2 = ab.magnitudeSquared;
    if (len2 < 1e-15) return a;
    final t = ((this - a).dot(ab) / len2).clamp(0.0, 1.0);
    return a.lerp(b, t);
  }

  /// Closest point on the infinite line through [a] with direction [dir].
  Point3D closestOnLine(Point3D a, Vector3D dir) {
    final len2 = dir.magnitudeSquared;
    if (len2 < 1e-15) return a;
    final t = (this - a).dot(dir) / len2;
    return a + dir * t;
  }

  /// Project this point onto the plane given by normal [n] and distance [d]
  /// (plane equation: n · p = d).
  Point3D projectedOnPlane(Vector3D n, double d) {
    final nn = n.normalized();
    return this + nn * (d - nn.dot(toVector()));
  }

  /// Whether this point is finite (no NaN / infinity components).
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  @override
  bool operator ==(Object other) =>
      other is Point3D && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '($x, $y, $z)';
}

/// A 3D vector with x, y, z components.
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  /// Zero vector.
  static const zero = Vector3D(0, 0, 0);

  /// Unit vector along X axis.
  static const unitX = Vector3D(1, 0, 0);

  /// Unit vector along Y axis.
  static const unitY = Vector3D(0, 1, 0);

  /// Unit vector along Z axis (up, GeoGebra convention).
  static const unitZ = Vector3D(0, 0, 1);

  /// Magnitude (length) of this vector.
  double get magnitude => dart_math.sqrt(x * x + y * y + z * z);

  /// Squared magnitude.
  double get magnitudeSquared => x * x + y * y + z * z;

  /// Returns a unit vector in the same direction.
  /// Returns zero vector if magnitude is zero.
  Vector3D normalized() {
    final mag = magnitude;
    if (mag < 1e-15) return Vector3D.zero;
    return Vector3D(x / mag, y / mag, z / mag);
  }

  /// Dot product with another vector.
  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;

  /// Cross product with another vector.
  Vector3D cross(Vector3D other) => Vector3D(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  /// Component-wise multiply.
  Vector3D componentMul(Vector3D other) =>
      Vector3D(x * other.x, y * other.y, z * other.z);

  Vector3D operator +(Vector3D other) =>
      Vector3D(x + other.x, y + other.y, z + other.z);

  Vector3D operator -(Vector3D other) =>
      Vector3D(x - other.x, y - other.y, z - other.z);

  Vector3D operator *(double scalar) =>
      Vector3D(x * scalar, y * scalar, z * scalar);

  Vector3D operator -() => Vector3D(-x, -y, -z);

  /// Whether this vector is finite.
  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  /// Whether the magnitude is (near) zero.
  bool get isZero => magnitudeSquared < 1e-15;

  @override
  bool operator ==(Object other) =>
      other is Vector3D && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '[$x, $y, $z]';
}

// ======================================================================
// Style types
// ======================================================================

/// How object labels are displayed (GeoGebra Labelling modes).
enum LabelMode {
  /// No label.
  hidden,

  /// Just the object name, e.g. "A", "f".
  name,

  /// Name and value, e.g. "A = (1, 2, 3)".
  nameValue,

  /// Just the value, e.g. "(1, 2, 3)".
  value,
}

/// Line dash style (GeoGebra line styles).
enum LineStyle {
  solid,
  longDash,
  shortDash,
  dotted,
}

/// Point marker style (GeoGebra point styles).
enum PointStyle {
  dot,
  cross,
  square,
  diamond,
}

/// Visual style shared by all 3D objects.
class ObjectStyle {
  final int color; // 0xAARRGGBB
  final double opacity; // 0..1
  final LineStyle lineStyle;
  final double lineWidth;
  final PointStyle pointStyle;
  final double pointSize;
  final LabelMode labelMode;

  const ObjectStyle({
    this.color = 0xFF4A90D9,
    this.opacity = 1.0,
    this.lineStyle = LineStyle.solid,
    this.lineWidth = 2,
    this.pointStyle = PointStyle.dot,
    this.pointSize = 5,
    this.labelMode = LabelMode.hidden,
  });

  const ObjectStyle.solid({
    this.color = 0xFF4A90D9,
    this.opacity = 1.0,
    this.lineStyle = LineStyle.solid,
    this.lineWidth = 2,
    this.pointStyle = PointStyle.dot,
    this.pointSize = 5,
    this.labelMode = LabelMode.hidden,
  });

  ObjectStyle copyWith({
    int? color,
    double? opacity,
    LineStyle? lineStyle,
    double? lineWidth,
    PointStyle? pointStyle,
    double? pointSize,
    LabelMode? labelMode,
  }) {
    return ObjectStyle(
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      lineStyle: lineStyle ?? this.lineStyle,
      lineWidth: lineWidth ?? this.lineWidth,
      pointStyle: pointStyle ?? this.pointStyle,
      pointSize: pointSize ?? this.pointSize,
      labelMode: labelMode ?? this.labelMode,
    );
  }
}

// ======================================================================
// Object types
// ======================================================================

/// Types of 3D objects.
enum Object3DType {
  point,
  segment,
  line,
  ray,
  vector,
  circle,
  arc,
  polygon,
  polyhedron,
  sphere,
  cone,
  cylinder,
  plane,
  surface,
  curve,
  measurement,
}

/// A triangle mesh: vertices, triangle indices, optional per-vertex normals.
class MeshData {
  final List<Point3D> vertices;
  final List<int> indices; // triplets
  final List<Vector3D> normals; // parallel to vertices

  const MeshData({
    required this.vertices,
    required this.indices,
    this.normals = const [],
  });

  bool get isEmpty => vertices.isEmpty || indices.length < 3;

  /// Compute flat normals per vertex by averaging face normals.
  MeshData withComputedNormals() {
    if (normals.length == vertices.length) return this;
    final faceNormals = <Vector3D>[];
    for (int i = 0; i < indices.length; i += 3) {
      final p0 = vertices[indices[i]];
      final p1 = vertices[indices[i + 1]];
      final p2 = vertices[indices[i + 2]];
      faceNormals.add((p1 - p0).cross(p2 - p0).normalized());
    }
    final vn = List<Vector3D>.filled(vertices.length, Vector3D.zero);
    for (int i = 0; i < indices.length; i += 3) {
      final fn = faceNormals[i ~/ 3];
      vn[indices[i]] = vn[indices[i]] + fn;
      vn[indices[i + 1]] = vn[indices[i + 1]] + fn;
      vn[indices[i + 2]] = vn[indices[i + 2]] + fn;
    }
    for (int i = 0; i < vn.length; i++) {
      vn[i] = vn[i].normalized();
    }
    return MeshData(vertices: vertices, indices: indices, normals: vn);
  }

  /// Transform all vertices by [transform].
  MeshData transformed(Point3D Function(Point3D) transform) => MeshData(
        vertices: [for (final v in vertices) transform(v)],
        indices: indices,
        normals: normals,
      );
}

/// An immutable 3D object in the scene.
///
/// Geometry is stored per type; [MeshData]-bearing types (polyhedron, cone,
/// cylinder, sphere, surface) are rendered from their meshes.
class Object3D {
  final Object3DType type;
  final String name; // e.g. "A", "f", "c" — GeoGebra style label
  final bool visible;
  final ObjectStyle style;

  // Point / vector geometry
  final Point3D? point;
  final Vector3D? vector;

  // Line-like geometry: through pointA with direction, or segment A-B
  final Point3D? pointA;
  final Point3D? pointB;

  // Plane: a·x + b·y + c·z = d  (normal = (a, b, c))
  final double? planeA;
  final double? planeB;
  final double? planeC;
  final double? planeD;

  // Circle / arc: center, normal, radius, angles
  final Point3D? circleCenter;
  final Vector3D? circleNormal;
  final double? circleRadius;
  final double? arcStart;
  final double? arcEnd;

  // Mesh geometry
  final MeshData? mesh;

  // Curve: polyline sample points
  final List<Point3D>? curvePoints;

  // Measurement: display text + anchor
  final String? measureText;
  final Point3D? measureAnchor;

  const Object3D._({
    required this.type,
    required this.name,
    required this.visible,
    required this.style,
    this.point,
    this.vector,
    this.pointA,
    this.pointB,
    this.planeA,
    this.planeB,
    this.planeC,
    this.planeD,
    this.circleCenter,
    this.circleNormal,
    this.circleRadius,
    this.arcStart,
    this.arcEnd,
    this.mesh,
    this.curvePoints,
    this.measureText,
    this.measureAnchor,
  });

  // ==================================================================
  // Factory constructors
  // ==================================================================

  factory Object3D.point(
    Point3D p, {
    String name = 'P',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.point,
          name: name,
          visible: visible,
          style: style,
          point: p);

  factory Object3D.segment(
    Point3D a,
    Point3D b, {
    String name = 's',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.segment,
          name: name,
          visible: visible,
          style: style,
          pointA: a,
          pointB: b);

  factory Object3D.line(
    Point3D through,
    Vector3D direction, {
    String name = 'l',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.line,
          name: name,
          visible: visible,
          style: style,
          pointA: through,
          vector: direction);

  factory Object3D.ray(
    Point3D from,
    Vector3D direction, {
    String name = 'r',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.ray,
          name: name,
          visible: visible,
          style: style,
          pointA: from,
          vector: direction);

  factory Object3D.vectorObj(
    Point3D from,
    Vector3D v, {
    String name = 'u',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.vector,
          name: name,
          visible: visible,
          style: style,
          point: from,
          vector: v);

  factory Object3D.circle(
    Point3D center,
    Vector3D normal,
    double radius, {
    String name = 'c',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.circle,
          name: name,
          visible: visible,
          style: style,
          circleCenter: center,
          circleNormal: normal,
          circleRadius: radius);

  factory Object3D.arc(
    Point3D center,
    Vector3D normal,
    double radius,
    double startAngle,
    double endAngle, {
    String name = 'a',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.arc,
          name: name,
          visible: visible,
          style: style,
          circleCenter: center,
          circleNormal: normal,
          circleRadius: radius,
          arcStart: startAngle,
          arcEnd: endAngle);

  factory Object3D.polygon(
    List<Point3D> vertices, {
    String name = 'poly',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.polygon,
          name: name,
          visible: visible,
          style: style,
          curvePoints: vertices);

  factory Object3D.polyhedron(
    MeshData mesh, {
    String name = 'P',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.polyhedron,
          name: name,
          visible: visible,
          style: style,
          mesh: mesh.withComputedNormals());

  factory Object3D.sphere(
    Point3D center,
    double radius, {
    String name = 'sph',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.sphere,
          name: name,
          visible: visible,
          style: style,
          circleCenter: center,
          circleRadius: radius);

  factory Object3D.cone(
    Point3D center,
    double radius,
    double height, {
    String name = 'cone',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.cone,
          name: name,
          visible: visible,
          style: style,
          circleCenter: center,
          circleRadius: radius,
          planeA: height);

  factory Object3D.cylinder(
    Point3D center,
    double radius,
    double height, {
    String name = 'cyl',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.cylinder,
          name: name,
          visible: visible,
          style: style,
          circleCenter: center,
          circleRadius: radius,
          planeA: height);

  factory Object3D.plane({
    double a = 0,
    double b = 0,
    double c = 1,
    double d = 0,
    String name = 'plane',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.plane,
          name: name,
          visible: visible,
          style: style,
          planeA: a,
          planeB: b,
          planeC: c,
          planeD: d);

  factory Object3D.surface(
    MeshData mesh, {
    String name = 'f',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.surface,
          name: name,
          visible: visible,
          style: style,
          mesh: mesh.withComputedNormals());

  factory Object3D.curve(
    List<Point3D> points, {
    String name = 'curve',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.curve,
          name: name,
          visible: visible,
          style: style,
          curvePoints: points);

  factory Object3D.measurement(
    String text,
    Point3D anchor, {
    String name = 'm',
    bool visible = true,
    ObjectStyle style = const ObjectStyle(),
  }) =>
      Object3D._(
          type: Object3DType.measurement,
          name: name,
          visible: visible,
          style: style,
          measureText: text,
          measureAnchor: anchor);

  // ==================================================================
  // Geometric convenience getters
  // ==================================================================

  Point3D get pointValue => point ?? Point3D.origin;
  Vector3D get vectorValue => vector ?? Vector3D.zero;
  Point3D get pointAValue => pointA ?? Point3D.origin;
  Point3D get pointBValue => pointB ?? Point3D.origin;
  Point3D get sphereCenter => circleCenter ?? Point3D.origin;
  double get sphereRadius => circleRadius ?? 1;
  Point3D get solidCenter => circleCenter ?? Point3D.origin;
  double get solidRadius => circleRadius ?? 1;
  double get solidHeight => planeA ?? 1;
  double get planeNormalA => planeA ?? 0;
  double get planeNormalB => planeB ?? 0;
  double get planeNormalC => planeC ?? 1;
  double get planeDValue => planeD ?? 0;
  Vector3D get planeNormal =>
      Vector3D(planeNormalA, planeNormalB, planeNormalC);
  List<Point3D> get polygonVertices => curvePoints ?? const [];
  List<Point3D> get curveSamplePoints => curvePoints ?? const [];

  /// A representative point used for bounding boxes and scene centering.
  Point3D get anchorPoint {
    switch (type) {
      case Object3DType.point:
        return pointValue;
      case Object3DType.segment:
        return pointAValue.midpoint(pointBValue);
      case Object3DType.line:
      case Object3DType.ray:
        return pointAValue;
      case Object3DType.vector:
        return pointValue;
      case Object3DType.circle:
      case Object3DType.arc:
        return circleCenter ?? Point3D.origin;
      case Object3DType.polygon:
        return _averageOf(polygonVertices);
      case Object3DType.polyhedron:
      case Object3DType.surface:
        return _meshCenter();
      case Object3DType.sphere:
        return sphereCenter;
      case Object3DType.cone:
      case Object3DType.cylinder:
        return solidCenter + Vector3D(0, 0, solidHeight / 2);
      case Object3DType.plane:
        // Closest point of the plane to the origin.
        final n = planeNormal;
        final len2 = n.magnitudeSquared;
        if (len2 < 1e-15) return Point3D.origin;
        final k = planeDValue / len2;
        return Point3D(n.x * k, n.y * k, n.z * k);
      case Object3DType.curve:
        return _averageOf(curveSamplePoints);
      case Object3DType.measurement:
        return measureAnchor ?? Point3D.origin;
    }
  }

  Point3D _averageOf(List<Point3D> pts) {
    if (pts.isEmpty) return Point3D.origin;
    var sx = 0.0, sy = 0.0, sz = 0.0;
    for (final p in pts) {
      sx += p.x;
      sy += p.y;
      sz += p.z;
    }
    return Point3D(sx / pts.length, sy / pts.length, sz / pts.length);
  }

  Point3D _meshCenter() {
    final v = mesh?.vertices;
    if (v == null || v.isEmpty) return Point3D.origin;
    return _averageOf(v);
  }

  // ==================================================================
  // Geometric helpers for construction / measurement
  // ==================================================================

  /// A sensible "grab point" when this object is used as construction input:
  /// returns the point itself for points, the representative position for
  /// other objects. When [snap] is given, [snap] is the world position
  /// projected onto this object.
  Point3D inputPoint(Point3D snap) {
    switch (type) {
      case Object3DType.point:
        return pointValue;
      case Object3DType.segment:
        return snap.closestOnSegment(pointAValue, pointBValue);
      case Object3DType.line:
        return snap.closestOnLine(pointAValue, vectorValue);
      case Object3DType.ray:
        final onLine = snap.closestOnLine(pointAValue, vectorValue);
        final t = (onLine - pointAValue).dot(vectorValue.normalized());
        return t < 0 ? pointAValue : onLine;
      case Object3DType.circle:
      case Object3DType.arc:
        final c = circleCenter ?? Point3D.origin;
        final n = (circleNormal ?? Vector3D.unitZ).normalized();
        final rel = snap - c;
        final onPlane = rel - n * rel.dot(n);
        final r = circleRadius ?? 1;
        if (onPlane.magnitudeSquared < 1e-15) {
          // Snap point projects to center — pick a fixed point on the circle.
          return c + _circleBasis(n).$1 * r;
        }
        return c + onPlane.normalized() * r;
      case Object3DType.polygon:
        final v = polygonVertices;
        if (v.isEmpty) return snap;
        final n = _polygonNormal(v);
        return snap.projectedOnPlane(n, n.dot(v.first.toVector()));
      case Object3DType.plane:
        return snap.projectedOnPlane(planeNormal, planeDValue);
      case Object3DType.sphere:
        final c = sphereCenter;
        final r = sphereRadius;
        final d = snap.distanceTo(c);
        if (d < 1e-12) return c + Vector3D.unitX * r;
        return c + (snap - c) * (r / d);
      case Object3DType.measurement:
        return measureAnchor ?? snap;
      default:
        return anchorPoint;
    }
  }

  /// The normal of the plane this object lies in (polygon/circle/arc).
  Vector3D? get naturalNormal {
    switch (type) {
      case Object3DType.polygon:
        final v = polygonVertices;
        if (v.length < 3) return null;
        return _polygonNormal(v);
      case Object3DType.circle:
      case Object3DType.arc:
        return (circleNormal ?? Vector3D.unitZ).normalized();
      case Object3DType.plane:
        return planeNormal.normalized();
      default:
        return null;
    }
  }

  static Vector3D _polygonNormal(List<Point3D> v) {
    final n = (v[1] - v[0]).cross(v[2] - v[0]);
    if (n.isZero) return Vector3D.unitZ;
    return n.normalized();
  }

  static (Vector3D, Vector3D) _circleBasis(Vector3D normal) {
    final n = normal.normalized();
    final ref =
        n.dot(Vector3D.unitZ).abs() > 0.9 ? Vector3D.unitX : Vector3D.unitZ;
    final u = n.cross(ref).normalized();
    final v = n.cross(u).normalized();
    return (u, v);
  }

  /// Sample points of this object (for rendering bounding etc.).
  List<Point3D> samplePoints() {
    switch (type) {
      case Object3DType.point:
        return [pointValue];
      case Object3DType.segment:
        return [pointAValue, pointBValue];
      case Object3DType.line:
        return [
          pointAValue + vectorValue * (-10),
          pointAValue + vectorValue * 10,
        ];
      case Object3DType.ray:
        return [pointAValue, pointAValue + vectorValue * 10];
      case Object3DType.vector:
        return [pointValue, pointValue + vectorValue];
      case Object3DType.circle:
      case Object3DType.arc:
        return _sampleCircle(this);
      case Object3DType.polygon:
        return polygonVertices;
      case Object3DType.polyhedron:
      case Object3DType.surface:
        return mesh?.vertices ?? const [];
      case Object3DType.sphere:
        return [
          sphereCenter + Vector3D.unitX * (-sphereRadius),
          sphereCenter + Vector3D.unitX * sphereRadius,
          sphereCenter + Vector3D.unitY * (-sphereRadius),
          sphereCenter + Vector3D.unitY * sphereRadius,
          sphereCenter + Vector3D.unitZ * (-sphereRadius),
          sphereCenter + Vector3D.unitZ * sphereRadius,
        ];
      case Object3DType.cone:
      case Object3DType.cylinder:
        final c = solidCenter;
        final r = solidRadius;
        final h = solidHeight;
        return [
          c + Vector3D(-r, -r, 0),
          c + Vector3D(r, r, 0),
          c + Vector3D(0, 0, h),
          c + Vector3D(r, -r, h),
        ];
      case Object3DType.plane:
        return const [];
      case Object3DType.curve:
        return curveSamplePoints;
      case Object3DType.measurement:
        return [measureAnchor ?? Point3D.origin];
    }
  }

  static List<Point3D> _sampleCircle(Object3D obj) {
    final c = obj.circleCenter ?? Point3D.origin;
    final n = (obj.circleNormal ?? Vector3D.unitZ).normalized();
    final r = obj.circleRadius ?? 1;
    final (u, v) = _circleBasis(n);
    // Arcs sample only [arcStart, arcEnd]; circles sample the full turn.
    final isArc = obj.type == Object3DType.arc;
    final start = isArc ? (obj.arcStart ?? 0) : 0.0;
    final end = isArc ? (obj.arcEnd ?? 2 * dart_math.pi) : 2 * dart_math.pi;
    const segments = 48;
    final pts = <Point3D>[];
    for (int i = 0; i <= segments; i++) {
      final t = start + (end - start) * i / segments;
      pts.add(c + u * (r * dart_math.cos(t)) + v * (r * dart_math.sin(t)));
    }
    return pts;
  }

  // ==================================================================
  // Transformations (immutable — produce new objects)
  // ==================================================================

  /// Translate by [t]. Keeps name/style/visibility.
  Object3D translated(Vector3D t) => transform((p) => p + t);

  /// Reflect across the plane n·p = d.
  Object3D reflected(Vector3D n, double d) => transform(
        (p) =>
            p + n.normalized() * (-2 * (n.normalized().dot(p.toVector()) - d)),
      );

  /// Rotate around the axis through [axisPoint] with direction [axisDir]
  /// by [angle] radians.
  Object3D rotated(Point3D axisPoint, Vector3D axisDir, double angle) =>
      transform((p) => _rotatePoint(p, axisPoint, axisDir, angle));

  /// Scale by [factor] from [center].
  Object3D scaled(Point3D center, double factor) => transform(
        (p) => center + (p - center) * factor,
      );

  /// Reflect across a point [center].
  Object3D reflectedAboutPoint(Point3D center) =>
      transform((p) => center + (center - p));

  /// A copy with the visibility flag changed.
  Object3D withVisible(bool visible) => _copyWith(visible: visible);

  /// A copy with a different style.
  Object3D withStyle(ObjectStyle style) => _copyWith(style: style);

  /// A copy with a different name.
  Object3D withRenamed(String name) {
    final copy = withReplaced(visible, style);
    return _rename(copy, name);
  }

  Object3D _rename(Object3D obj, String name) {
    // Rebuild through the geometry-preserving factory with the new name.
    switch (obj.type) {
      case Object3DType.point:
        return Object3D.point(obj.pointValue,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.segment:
        return Object3D.segment(obj.pointAValue, obj.pointBValue,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.line:
        return Object3D.line(obj.pointAValue, obj.vectorValue,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.ray:
        return Object3D.ray(obj.pointAValue, obj.vectorValue,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.vector:
        return Object3D.vectorObj(obj.pointValue, obj.vectorValue,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.circle:
        return Object3D.circle(obj.circleCenter ?? Point3D.origin,
            obj.circleNormal ?? Vector3D.unitZ, obj.circleRadius ?? 1,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.arc:
        return Object3D.arc(
            obj.circleCenter ?? Point3D.origin,
            obj.circleNormal ?? Vector3D.unitZ,
            obj.circleRadius ?? 1,
            obj.arcStart ?? 0,
            obj.arcEnd ?? 0,
            name: name,
            visible: obj.visible,
            style: obj.style);
      case Object3DType.polygon:
        return Object3D.polygon(obj.polygonVertices,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.polyhedron:
        return Object3D.polyhedron(obj.mesh!,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.sphere:
        return Object3D.sphere(obj.sphereCenter, obj.sphereRadius,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.cone:
        return Object3D.cone(obj.solidCenter, obj.solidRadius, obj.solidHeight,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.cylinder:
        return Object3D.cylinder(
            obj.solidCenter, obj.solidRadius, obj.solidHeight,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.plane:
        return Object3D.plane(
            a: obj.planeNormalA,
            b: obj.planeNormalB,
            c: obj.planeNormalC,
            d: obj.planeDValue,
            name: name,
            visible: obj.visible,
            style: obj.style);
      case Object3DType.surface:
        return Object3D.surface(obj.mesh!,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.curve:
        return Object3D.curve(obj.curveSamplePoints,
            name: name, visible: obj.visible, style: obj.style);
      case Object3DType.measurement:
        return Object3D.measurement(
            obj.measureText ?? '', obj.measureAnchor ?? Point3D.origin,
            name: name, visible: obj.visible, style: obj.style);
    }
  }

  Object3D _copyWith({bool? visible, ObjectStyle? style}) {
    return withReplaced(visible ?? this.visible, style ?? this.style);
  }

  // Internal: rebuild with given visibility/style without touching geometry.
  Object3D withReplaced(bool visible, ObjectStyle style) {
    switch (type) {
      case Object3DType.point:
        return Object3D.point(pointValue,
            name: name, visible: visible, style: style);
      case Object3DType.segment:
        return Object3D.segment(pointAValue, pointBValue,
            name: name, visible: visible, style: style);
      case Object3DType.line:
        return Object3D.line(pointAValue, vectorValue,
            name: name, visible: visible, style: style);
      case Object3DType.ray:
        return Object3D.ray(pointAValue, vectorValue,
            name: name, visible: visible, style: style);
      case Object3DType.vector:
        return Object3D.vectorObj(pointValue, vectorValue,
            name: name, visible: visible, style: style);
      case Object3DType.circle:
        return Object3D.circle(circleCenter ?? Point3D.origin,
            circleNormal ?? Vector3D.unitZ, circleRadius ?? 1,
            name: name, visible: visible, style: style);
      case Object3DType.arc:
        return Object3D.arc(
            circleCenter ?? Point3D.origin,
            circleNormal ?? Vector3D.unitZ,
            circleRadius ?? 1,
            arcStart ?? 0,
            arcEnd ?? 0,
            name: name,
            visible: visible,
            style: style);
      case Object3DType.polygon:
        return Object3D.polygon(polygonVertices,
            name: name, visible: visible, style: style);
      case Object3DType.polyhedron:
        return Object3D.polyhedron(mesh!,
            name: name, visible: visible, style: style);
      case Object3DType.sphere:
        return Object3D.sphere(sphereCenter, sphereRadius,
            name: name, visible: visible, style: style);
      case Object3DType.cone:
        return Object3D.cone(solidCenter, solidRadius, solidHeight,
            name: name, visible: visible, style: style);
      case Object3DType.cylinder:
        return Object3D.cylinder(solidCenter, solidRadius, solidHeight,
            name: name, visible: visible, style: style);
      case Object3DType.plane:
        return Object3D.plane(
            a: planeNormalA,
            b: planeNormalB,
            c: planeNormalC,
            d: planeDValue,
            name: name,
            visible: visible,
            style: style);
      case Object3DType.surface:
        return Object3D.surface(mesh!,
            name: name, visible: visible, style: style);
      case Object3DType.curve:
        return Object3D.curve(curveSamplePoints,
            name: name, visible: visible, style: style);
      case Object3DType.measurement:
        return Object3D.measurement(
            measureText ?? '', measureAnchor ?? Point3D.origin,
            name: name, visible: visible, style: style);
    }
  }

  Object3D transform(Point3D Function(Point3D) f) {
    switch (type) {
      case Object3DType.point:
        return Object3D.point(f(pointValue),
            name: name, visible: visible, style: style);
      case Object3DType.segment:
        return Object3D.segment(f(pointAValue), f(pointBValue),
            name: name, visible: visible, style: style);
      case Object3DType.line:
      case Object3DType.ray:
        final a = f(pointAValue);
        final b = f(pointAValue + vectorValue);
        return type == Object3DType.line
            ? Object3D.line(a, b - a,
                name: name, visible: visible, style: style)
            : Object3D.ray(a, b - a,
                name: name, visible: visible, style: style);
      case Object3DType.vector:
        return Object3D.vectorObj(
            f(pointValue), f(pointValue + vectorValue) - f(pointValue),
            name: name, visible: visible, style: style);
      case Object3DType.circle:
        final n0 = circleNormal ?? Vector3D.unitZ;
        final c0 = circleCenter ?? Point3D.origin;
        final c1 = f(c0);
        final c2 = f(c0 + n0);
        return Object3D.circle(c1, c2 - c1, circleRadius ?? 1,
            name: name, visible: visible, style: style);
      case Object3DType.arc:
        // Rebuild center, normal, and recompute the start/end angles from
        // the transformed endpoints so rotations/mirrors stay correct.
        final n0 = (circleNormal ?? Vector3D.unitZ).normalized();
        final c0 = circleCenter ?? Point3D.origin;
        final r0 = circleRadius ?? 1;
        final s0 = arcStart ?? 0;
        final e0 = arcEnd ?? 2 * dart_math.pi;
        final (u0, v0) = _circleBasis(n0);
        final pStart =
            c0 + u0 * (r0 * dart_math.cos(s0)) + v0 * (r0 * dart_math.sin(s0));
        final pEnd =
            c0 + u0 * (r0 * dart_math.cos(e0)) + v0 * (r0 * dart_math.sin(e0));
        final c1 = f(c0);
        final n1 = f(c0 + n0) - c1;
        final (u1, v1) = _circleBasis(n1);
        double angleOf(Point3D p) {
          final rel = p - c1;
          return dart_math.atan2(rel.dot(v1), rel.dot(u1));
        }

        var a1 = angleOf(f(pStart));
        var a2 = angleOf(f(pEnd));
        // Keep the sweep direction of the original arc.
        if (e0 >= s0) {
          while (a2 - a1 < 0) {
            a2 += 2 * dart_math.pi;
          }
        } else {
          while (a2 - a1 > 0) {
            a2 -= 2 * dart_math.pi;
          }
        }
        return Object3D.arc(c1, n1, r0, a1, a2,
            name: name, visible: visible, style: style);
      case Object3DType.polygon:
        return Object3D.polygon([for (final p in polygonVertices) f(p)],
            name: name, visible: visible, style: style);
      case Object3DType.polyhedron:
        return Object3D.polyhedron(mesh!.transformed(f),
            name: name, visible: visible, style: style);
      case Object3DType.sphere:
        return Object3D.sphere(f(sphereCenter), sphereRadius,
            name: name, visible: visible, style: style);
      case Object3DType.cone:
        return Object3D.cone(f(solidCenter), solidRadius, solidHeight,
            name: name, visible: visible, style: style);
      case Object3DType.cylinder:
        return Object3D.cylinder(f(solidCenter), solidRadius, solidHeight,
            name: name, visible: visible, style: style);
      case Object3DType.plane:
        // Rebuild plane from three points.
        final n = planeNormal;
        final k = planeDValue / n.magnitudeSquared;
        final p0 = Point3D(n.x * k, n.y * k, n.z * k);
        final basis = _circleBasis(n);
        final p1 = f(p0 + basis.$1);
        final p2 = f(p0 + basis.$2);
        final p3 = f(p0);
        final nn = (p1 - p3).cross(p2 - p3);
        return Object3D.plane(
          a: nn.x,
          b: nn.y,
          c: nn.z,
          d: nn.dot(p3.toVector()),
          name: name,
          visible: visible,
          style: style,
        );
      case Object3DType.surface:
        return Object3D.surface(mesh!.transformed(f),
            name: name, visible: visible, style: style);
      case Object3DType.curve:
        return Object3D.curve([for (final p in curveSamplePoints) f(p)],
            name: name, visible: visible, style: style);
      case Object3DType.measurement:
        return Object3D.measurement(
            measureText ?? '', f(measureAnchor ?? Point3D.origin),
            name: name, visible: visible, style: style);
    }
  }

  static Point3D _rotatePoint(
      Point3D p, Point3D axisPoint, Vector3D axisDir, double angle) {
    final dir = axisDir.normalized();
    final rel = p - axisPoint;
    final k = dir;
    final cosA = dart_math.cos(angle);
    final sinA = dart_math.sin(angle);
    final rotated =
        rel * cosA + k.cross(rel) * sinA + k * (k.dot(rel) * (1 - cosA));
    return axisPoint + rotated;
  }

  /// The 2D-like center for solid scaling (used by Dilate).
  Point3D get transformCenter => anchorPoint;
}

// ======================================================================
// Mesh builders for solids and surfaces
// ======================================================================

/// Builders for common solid meshes. All meshes are "closed" — faces are
/// oriented so that outward normals point away from the interior.
class MeshBuilder {
  /// A UV sphere centered at origin with the given [radius] and [segments].
  static MeshData sphere(double radius, {int segments = 20}) {
    final vertices = <Point3D>[];
    final indices = <int>[];
    for (int i = 0; i <= segments; i++) {
      final phi = dart_math.pi * i / segments;
      for (int j = 0; j <= segments; j++) {
        final theta = 2 * dart_math.pi * j / segments;
        final x = radius * dart_math.sin(phi) * dart_math.cos(theta);
        final y = radius * dart_math.sin(phi) * dart_math.sin(theta);
        final z = radius * dart_math.cos(phi);
        vertices.add(Point3D(x, y, z));
      }
    }
    for (int i = 0; i < segments; i++) {
      for (int j = 0; j < segments; j++) {
        final a = i * (segments + 1) + j;
        final b = a + 1;
        final c = (i + 1) * (segments + 1) + j;
        final d = c + 1;
        indices.addAll([a, c, b]);
        indices.addAll([b, c, d]);
      }
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// A cone with base center at origin, radius [r], height [h] along +Z.
  static MeshData cone(double r, double h, {int segments = 24}) {
    final vertices = <Point3D>[Point3D(0, 0, h)];
    for (int j = 0; j < segments; j++) {
      final t = 2 * dart_math.pi * j / segments;
      vertices.add(Point3D(r * dart_math.cos(t), r * dart_math.sin(t), 0));
    }
    final indices = <int>[];
    for (int j = 0; j < segments; j++) {
      final b = j + 1;
      final c = (j + 1) % segments + 1;
      indices.addAll([0, c, b]); // side (apex 0, base rim)
    }
    // Base disk: add center as a separate vertex.
    final centerIdx = vertices.length;
    vertices.add(Point3D.origin);
    for (int j = 0; j < segments; j++) {
      final a = j + 1;
      final b = (j + 1) % segments + 1;
      indices.addAll([centerIdx, b, a]);
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// A cylinder with base center at origin, radius [r], height [h] along +Z.
  static MeshData cylinder(double r, double h, {int segments = 24}) {
    final vertices = <Point3D>[];
    for (int j = 0; j < segments; j++) {
      final t = 2 * dart_math.pi * j / segments;
      vertices.add(Point3D(r * dart_math.cos(t), r * dart_math.sin(t), 0));
    }
    final topStart = vertices.length;
    for (int j = 0; j < segments; j++) {
      final t = 2 * dart_math.pi * j / segments;
      vertices.add(Point3D(r * dart_math.cos(t), r * dart_math.sin(t), h));
    }
    final bottomCenter = vertices.length;
    vertices.add(Point3D.origin);
    final topCenter = vertices.length;
    vertices.add(Point3D(0, 0, h));

    final indices = <int>[];
    for (int j = 0; j < segments; j++) {
      final a = j;
      final b = (j + 1) % segments;
      final c = topStart + j;
      final d = topStart + (j + 1) % segments;
      indices.addAll([a, b, c]);
      indices.addAll([b, d, c]);
      indices.addAll([bottomCenter, b, a]);
      indices.addAll([topStart + a, topStart + b, topCenter]);
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// A closed triangular prism from a base polygon [base] and [height] along
  /// the polygon normal (if [direction] is null).
  static MeshData prism(List<Point3D> base, double height,
      {Vector3D? direction}) {
    if (base.length < 3) {
      return const MeshData(vertices: [], indices: []);
    }
    final n = (base[1] - base[0]).cross(base[2] - base[0]).normalized();
    final dir = (direction ?? n).normalized() * height;
    final top = [for (final p in base) p + dir];
    return _extrude(base, top, 0, base.length, base.length, base.length * 2);
  }

  /// A pyramid from a base polygon [base] and apex [apex].
  static MeshData pyramid(List<Point3D> base, Point3D apex) {
    if (base.length < 3) {
      return const MeshData(vertices: [], indices: []);
    }
    final vertices = <Point3D>[...base, apex];
    final indices = <int>[];
    for (int i = 0; i < base.length - 2; i++) {
      indices.addAll([0, i + 1, i + 2]);
    }
    for (int i = 0; i < base.length; i++) {
      final a = i;
      final b = (i + 1) % base.length;
      indices.addAll([b, a, base.length]);
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// Generic extrusion between two parallel polygons.
  static MeshData _extrude(List<Point3D> bottom, List<Point3D> top, int vbStart,
      int vbEnd, int vtStart, int vtEnd) {
    final vertices = <Point3D>[...bottom, ...top];
    final indices = <int>[];
    final n = bottom.length;
    for (int i = 0; i < n; i++) {
      final a = i;
      final b = (i + 1) % n;
      final c = n + i;
      final d = n + (i + 1) % n;
      indices.addAll([a, b, c]);
      indices.addAll([b, d, c]);
    }
    for (int i = 0; i < n - 2; i++) {
      indices.addAll([0, i + 1, i + 2]);
    }
    for (int i = 0; i < n - 2; i++) {
      indices.addAll([n, n + i + 2, n + i + 1]);
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// A tetrahedron from 4 vertices.
  static MeshData tetrahedron(List<Point3D> v) {
    assert(v.length == 4);
    const indices = [0, 2, 1, 0, 1, 3, 0, 3, 2, 1, 2, 3];
    return MeshData(vertices: v, indices: indices);
  }

  /// A cube (axis-aligned) with one corner at [min] and the opposite at [max].
  static MeshData cube(Point3D min, Point3D max) {
    final x0 = min.x, y0 = min.y, z0 = min.z;
    final x1 = max.x, y1 = max.y, z1 = max.z;
    final v = [
      Point3D(x0, y0, z0),
      Point3D(x1, y0, z0),
      Point3D(x1, y1, z0),
      Point3D(x0, y1, z0),
      Point3D(x0, y0, z1),
      Point3D(x1, y0, z1),
      Point3D(x1, y1, z1),
      Point3D(x0, y1, z1),
    ];
    const indices = [
      0, 1, 2, 0, 2, 3, // bottom (z0)
      4, 6, 5, 4, 7, 6, // top (z1)
      0, 4, 5, 0, 5, 1, // front (y0)
      3, 2, 6, 3, 6, 7, // back (y1)
      0, 3, 7, 0, 7, 4, // left (x0)
      1, 5, 6, 1, 6, 2, // right (x1)
    ];
    return MeshData(vertices: v, indices: indices);
  }

  /// A grid mesh for z = f(x, y) sampling.
  static MeshData fromFunction({
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
    required int gridX,
    required int gridY,
    required double Function(double x, double y) f,
  }) {
    final cols = gridX + 1;
    final rows = gridY + 1;
    final vertices = <Point3D>[];
    final indices = <int>[];
    final stepX = (xMax - xMin) / gridX;
    final stepY = (yMax - yMin) / gridY;
    for (int iy = 0; iy < rows; iy++) {
      for (int ix = 0; ix < cols; ix++) {
        final x = xMin + ix * stepX;
        final y = yMin + iy * stepY;
        final z = f(x, y);
        vertices.add(Point3D(x, y, z));
      }
    }
    for (int iy = 0; iy < gridY; iy++) {
      for (int ix = 0; ix < gridX; ix++) {
        final i0 = iy * cols + ix;
        final i1 = i0 + 1;
        final i2 = (iy + 1) * cols + ix;
        final i3 = i2 + 1;
        indices.addAll([i0, i1, i2]);
        indices.addAll([i1, i3, i2]);
      }
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// A parametric grid mesh.
  static MeshData parametric({
    required double Function(double u, double v) x,
    required double Function(double u, double v) y,
    required double Function(double u, double v) z,
    required double uMin,
    required double uMax,
    required double vMin,
    required double vMax,
    required int gridU,
    required int gridV,
  }) {
    final cols = gridU + 1;
    final rows = gridV + 1;
    final vertices = <Point3D>[];
    final indices = <int>[];
    final stepU = (uMax - uMin) / gridU;
    final stepV = (vMax - vMin) / gridV;
    for (int iv = 0; iv < rows; iv++) {
      for (int iu = 0; iu < cols; iu++) {
        final u = uMin + iu * stepU;
        final v = vMin + iv * stepV;
        vertices.add(Point3D(x(u, v), y(u, v), z(u, v)));
      }
    }
    for (int iv = 0; iv < gridV; iv++) {
      for (int iu = 0; iu < gridU; iu++) {
        final i0 = iv * cols + iu;
        final i1 = i0 + 1;
        final i2 = (iv + 1) * cols + iu;
        final i3 = i2 + 1;
        indices.addAll([i0, i1, i2]);
        indices.addAll([i1, i3, i2]);
      }
    }
    return MeshData(vertices: vertices, indices: indices);
  }

  /// Surface of revolution: rotate the profile points [profile] (2D polyline
  /// with x = radius, y = height) around the Z axis by [angle] radians.
  static MeshData revolve(List<Point3D> profile, double angle,
      {int segments = 32}) {
    if (profile.length < 2 || segments < 3) {
      return const MeshData(vertices: [], indices: []);
    }
    final vertices = <Point3D>[];
    final indices = <int>[];
    for (int i = 0; i <= segments; i++) {
      final t = angle * i / segments;
      final cosT = dart_math.cos(t);
      final sinT = dart_math.sin(t);
      for (final p in profile) {
        vertices.add(Point3D(p.x * cosT, p.x * sinT, p.y));
      }
    }
    final n = profile.length;
    for (int i = 0; i < segments; i++) {
      for (int j = 0; j < n - 1; j++) {
        final a = i * n + j;
        final b = i * n + j + 1;
        final c = (i + 1) * n + j;
        final d = (i + 1) * n + j + 1;
        indices.addAll([a, c, b]);
        indices.addAll([b, c, d]);
      }
    }
    return MeshData(vertices: vertices, indices: indices);
  }
}
