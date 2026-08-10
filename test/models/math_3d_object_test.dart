import 'dart:math' as dart_math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';

void main() {
  group('Point3D', () {
    test('distance and midpoint', () {
      const a = Point3D(0, 0, 0);
      const b = Point3D(3, 4, 12);
      expect(a.distanceTo(b), 13);
      expect(a.midpoint(b), const Point3D(1.5, 2, 6));
    });

    test('lerp interpolates', () {
      const a = Point3D(0, 0, 0);
      const b = Point3D(2, 4, 6);
      expect(a.lerp(b, 0.5), const Point3D(1, 2, 3));
      expect(a.lerp(b, 1), b);
    });

    test('closestOnSegment clamps to segment', () {
      const a = Point3D(0, 0, 0);
      const b = Point3D(10, 0, 0);
      const p = Point3D(5, 3, 0);
      expect(p.closestOnSegment(a, b), const Point3D(5, 0, 0));
      const far = Point3D(50, 3, 0);
      expect(far.closestOnSegment(a, b), b);
    });

    test('projectedOnPlane projects onto plane', () {
      const p = Point3D(1, 2, 3);
      final n = const Vector3D(0, 0, 1);
      expect(p.projectedOnPlane(n, 0), const Point3D(1, 2, 0));
    });

    test('operator semantics', () {
      const a = Point3D(1, 2, 3);
      const b = Point3D(4, 5, 6);
      final v = b - a;
      expect(v, const Vector3D(3, 3, 3));
      expect(a + v, b);
    });
  });

  group('Vector3D', () {
    test('magnitude and normalization', () {
      const v = Vector3D(3, 4, 0);
      expect(v.magnitude, 5);
      final n = v.normalized();
      expect(n.magnitude, closeTo(1, 1e-12));
      expect(n.x, closeTo(0.6, 1e-12));
    });

    test('dot and cross products', () {
      const a = Vector3D(1, 0, 0);
      const b = Vector3D(0, 1, 0);
      expect(a.dot(b), 0);
      expect(a.cross(b), Vector3D.unitZ);
      expect(b.cross(a), -Vector3D.unitZ);
    });

    test('zero vector cannot be normalized', () {
      expect(Vector3D.zero.normalized(), Vector3D.zero);
    });
  });

  group('Object3D types', () {
    test('point and segment objects expose geometry', () {
      final p = Object3D.point(const Point3D(1, 2, 3),
          name: 'A', style: const ObjectStyle(color: 0xFF112233));
      expect(p.type, Object3DType.point);
      expect(p.pointValue, const Point3D(1, 2, 3));
      expect(p.name, 'A');
      expect(p.style.color, 0xFF112233);

      final s =
          Object3D.segment(const Point3D(0, 0, 0), const Point3D(1, 1, 1));
      expect(s.type, Object3DType.segment);
      expect(s.pointAValue, const Point3D(0, 0, 0));
      expect(s.pointBValue, const Point3D(1, 1, 1));
    });

    test('circle stores center, normal and radius', () {
      final c = Object3D.circle(const Point3D(1, 1, 1), Vector3D.unitZ, 5);
      expect(c.circleCenter, const Point3D(1, 1, 1));
      expect(c.circleNormal, Vector3D.unitZ);
      expect(c.circleRadius, 5);
    });

    test('arc samples only its angular range', () {
      // Quarter arc from 0 to π/2 on the unit circle in the xOy plane.
      // The circle basis is (u, v) = ((0,1,0), (-1,0,0)) for n = unitZ, so
      // angle 0 lies at (0,1,0) and π/2 at (-1,0,0).
      final arc =
          Object3D.arc(Point3D.origin, Vector3D.unitZ, 1, 0, dart_math.pi / 2);
      final pts = arc.samplePoints();
      expect(pts.length, 49);
      expect(pts.first.distanceTo(const Point3D(0, 1, 0)), lessThan(1e-9));
      expect(pts.last.distanceTo(const Point3D(-1, 0, 0)), lessThan(1e-9));
      for (final p in pts) {
        expect(p.z, closeTo(0, 1e-9));
        expect(p.x, lessThanOrEqualTo(1e-9));
        expect(p.y, greaterThanOrEqualTo(-1e-9));
      }
      // A full circle still samples the whole turn (first == last point).
      final circle = Object3D.circle(Point3D.origin, Vector3D.unitZ, 1);
      final cpts = circle.samplePoints();
      expect(cpts.first.distanceTo(const Point3D(0, 1, 0)), lessThan(1e-9));
      expect(cpts.last.distanceTo(const Point3D(0, 1, 0)), lessThan(1e-9));
    });

    test('solid objects store mesh builders data', () {
      final sph = Object3D.sphere(const Point3D(0, 0, 1), 2);
      expect(sph.sphereCenter, const Point3D(0, 0, 1));
      expect(sph.sphereRadius, 2);

      final cone = Object3D.cone(Point3D.origin, 1, 3);
      expect(cone.solidRadius, 1);
      expect(cone.solidHeight, 3);

      final cyl = Object3D.cylinder(Point3D.origin, 2, 4);
      expect(cyl.solidRadius, 2);
      expect(cyl.solidHeight, 4);
    });

    test('plane object exposes coefficients', () {
      final pl = Object3D.plane(a: 1, b: 2, c: 3, d: 4);
      expect(pl.planeNormalA, 1);
      expect(pl.planeNormalB, 2);
      expect(pl.planeNormalC, 3);
      expect(pl.planeDValue, 4);
      expect(pl.planeNormal, const Vector3D(1, 2, 3));
    });

    test('polygon keeps vertices', () {
      final poly = Object3D.polygon(const [
        Point3D(0, 0, 0),
        Point3D(1, 0, 0),
        Point3D(1, 1, 0),
      ]);
      expect(poly.polygonVertices.length, 3);
    });

    test('surface mesh gets computed normals', () {
      final mesh = MeshBuilder.fromFunction(
        xMin: -1,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        gridX: 2,
        gridY: 2,
        f: (x, y) => 0,
      );
      expect(mesh.vertices.length, 9);
      expect(mesh.indices.length, 8 * 3);
      final withNormals = mesh.withComputedNormals();
      expect(withNormals.normals.length, 9);
      expect(withNormals.normals.first.magnitude, closeTo(1, 1e-9));
    });

    test('anchorPoint for plane is the closest point to origin', () {
      final pl = Object3D.plane(a: 0, b: 0, c: 1, d: 2);
      expect(pl.anchorPoint, const Point3D(0, 0, 2));
    });
  });

  group('Object3D transforms', () {
    test('translated moves all geometry', () {
      final seg =
          Object3D.segment(const Point3D(0, 0, 0), const Point3D(1, 0, 0));
      final moved = seg.translated(const Vector3D(0, 0, 5));
      expect(moved.pointAValue, const Point3D(0, 0, 5));
      expect(moved.pointBValue, const Point3D(1, 0, 5));
      expect(moved.name, seg.name);
    });

    test('reflected across xOy plane mirrors z', () {
      final p = Object3D.point(const Point3D(1, 2, 3));
      final r = p.reflected(Vector3D.unitZ, 0);
      expect(r.pointValue, const Point3D(1, 2, -3));
    });

    test('reflectedAboutPoint mirrors through a point', () {
      final p = Object3D.point(const Point3D(1, 2, 3));
      final r = p.reflectedAboutPoint(const Point3D(0, 0, 0));
      expect(r.pointValue, const Point3D(-1, -2, -3));
    });

    test('rotated rotates around axis', () {
      final p = Object3D.point(const Point3D(1, 0, 0));
      final r = p.rotated(Point3D.origin, Vector3D.unitZ, dart_math.pi / 2);
      expect(r.pointValue.x, closeTo(0, 1e-9));
      expect(r.pointValue.y, closeTo(1, 1e-9));
      expect(r.pointValue.z, closeTo(0, 1e-9));
    });

    test('scaled scales from center', () {
      final p = Object3D.point(const Point3D(2, 0, 0));
      final s = p.scaled(Point3D.origin, 0.5);
      expect(s.pointValue, const Point3D(1, 0, 0));
    });

    test('withVisible and withStyle preserve geometry', () {
      final p = Object3D.point(const Point3D(1, 1, 1), name: 'P');
      final hidden = p.withVisible(false);
      expect(hidden.visible, false);
      expect(hidden.pointValue, p.pointValue);
      final styled = p.withStyle(const ObjectStyle(color: 0xFF000000));
      expect(styled.style.color, 0xFF000000);
      expect(styled.pointValue, p.pointValue);
    });

    test('plane transform rebuilds a valid plane', () {
      final pl = Object3D.plane(a: 0, b: 0, c: 1, d: 0);
      final moved = pl.translated(const Vector3D(0, 0, 3));
      // Plane z=0 shifted up by 3 → d = 3.
      expect(moved.planeNormalC, closeTo(1, 1e-9));
      expect(moved.planeDValue, closeTo(3, 1e-9));
    });
  });

  group('MeshBuilder', () {
    test('sphere mesh is closed and non-degenerate', () {
      final m = MeshBuilder.sphere(2, segments: 8);
      expect(m.vertices.length, 81);
      expect(m.indices.length, 8 * 8 * 6);
    });

    test('cone mesh has apex, rim and base center', () {
      final m = MeshBuilder.cone(1, 2, segments: 12);
      expect(m.vertices.length, 14);
      expect(m.indices.length, 12 * 6);
    });

    test('cylinder mesh has two caps', () {
      final m = MeshBuilder.cylinder(1, 2, segments: 12);
      expect(m.vertices.length, 26);
      expect(m.indices.length, 12 * 12);
    });

    test('prism extrudes base along normal', () {
      final base = [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ];
      final m = MeshBuilder.prism(base, 3);
      // 8 vertices: 4 bottom + 4 top.
      expect(m.vertices.length, 8);
      // 4 side quads (8 tris) + 2 base fans (2 tris each) = 12 triangles.
      expect(m.indices.length, 12 * 3);
      final topZ = m.vertices.sublist(4).map((v) => v.z).toList();
      expect(topZ.every((z) => (z - 3).abs() < 1e-9), true);
    });

    test('pyramid has base + apex', () {
      final base = [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ];
      final m = MeshBuilder.pyramid(base, const Point3D(1, 1, 4));
      expect(m.vertices.length, 5);
      expect(m.vertices.last.z, 4);
    });

    test('tetrahedron uses 4 vertices', () {
      final m = MeshBuilder.tetrahedron(const [
        Point3D(0, 0, 0),
        Point3D(1, 0, 0),
        Point3D(0, 1, 0),
        Point3D(0, 0, 1),
      ]);
      expect(m.vertices.length, 4);
      expect(m.indices.length, 12);
    });

    test('cube mesh has 8 vertices and 12 faces', () {
      final m = MeshBuilder.cube(Point3D.origin, const Point3D(1, 1, 1));
      expect(m.vertices.length, 8);
      expect(m.indices.length, 36);
    });

    test('revolve creates a lathe surface', () {
      final profile = [
        Point3D(1, 0, 0), // radius 1 at z=0
        Point3D(1, 1, 0), // radius 1 at z=1
      ];
      final m = MeshBuilder.revolve(profile, 2 * dart_math.pi, segments: 12);
      expect(m.vertices.length, 13 * 2);
      expect(m.indices.length, 12 * 2 * 3);
    });

    test('parametric grid respects ranges', () {
      final m = MeshBuilder.parametric(
        x: (u, v) => u,
        y: (u, v) => v,
        z: (u, v) => 0,
        uMin: 0,
        uMax: 1,
        vMin: 0,
        vMax: 2,
        gridU: 3,
        gridV: 4,
      );
      expect(m.vertices.length, 4 * 5);
      final zs = m.vertices.map((v) => v.z).toSet();
      expect(zs, {0.0});
    });
  });

  group('Object3D inputPoint (snapping)', () {
    test('point input returns the point', () {
      final p = Object3D.point(const Point3D(1, 2, 3));
      expect(p.inputPoint(const Point3D(9, 9, 9)), const Point3D(1, 2, 3));
    });

    test('segment input snaps to segment', () {
      final s =
          Object3D.segment(const Point3D(0, 0, 0), const Point3D(4, 0, 0));
      final snapped = s.inputPoint(const Point3D(2, 5, 1));
      expect(snapped.x, closeTo(2, 1e-9));
      expect(snapped.y, closeTo(0, 1e-9));
    });

    test('circle input snaps onto the circle', () {
      final c = Object3D.circle(Point3D.origin, Vector3D.unitZ, 2);
      final snapped = c.inputPoint(const Point3D(5, 0, 0));
      expect(snapped.distanceTo(Point3D.origin), closeTo(2, 1e-9));
      expect(snapped.z, closeTo(0, 1e-9));
    });

    test('plane input projects onto plane', () {
      final pl = Object3D.plane(a: 0, b: 0, c: 1, d: 3);
      final snapped = pl.inputPoint(const Point3D(1, 1, 1));
      expect(snapped.z, closeTo(3, 1e-9));
    });
  });

  group('Solid axis support', () {
    test('anchorPoint of a tilted cone is the axis midpoint', () {
      final cone =
          Object3D.cone(Point3D.origin, 1, 3, axis: const Vector3D(1, 0, 0));
      final a = cone.anchorPoint;
      expect(a.x, closeTo(1.5, 1e-9));
      expect(a.y, closeTo(0, 1e-9));
      expect(a.z, closeTo(0, 1e-9));
    });

    test('samplePoints of a tilted cylinder bound its true extent', () {
      final cyl = Object3D.cylinder(Point3D.origin, 1, 3,
          axis: const Vector3D(1, 0, 0));
      final pts = cyl.samplePoints();
      var maxX = -double.infinity, minX = double.infinity;
      var maxY = -double.infinity, minY = double.infinity;
      var maxZ = -double.infinity, minZ = double.infinity;
      for (final p in pts) {
        maxX = maxX < p.x ? p.x : maxX;
        minX = minX > p.x ? p.x : minX;
        maxY = maxY < p.y ? p.y : maxY;
        minY = minY > p.y ? p.y : minY;
        maxZ = maxZ < p.z ? p.z : maxZ;
        minZ = minZ > p.z ? p.z : minZ;
      }
      // Extent along the axis: 0..3 (radius 1).
      expect(maxX, closeTo(3, 1e-9));
      expect(minX, closeTo(0, 1e-9));
      // Radial extent: ±1 in y/z.
      expect(maxY, closeTo(1, 1e-9));
      expect(minY, closeTo(-1, 1e-9));
      expect(maxZ, closeTo(1, 1e-9));
      expect(minZ, closeTo(-1, 1e-9));
    });
  });
}
