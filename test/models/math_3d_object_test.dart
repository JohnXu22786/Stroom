import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';

void main() {
  group('Point3D', () {
    test('creates a 3D point with x, y, z coordinates', () {
      final p = Point3D(1.0, 2.0, 3.0);
      expect(p.x, 1.0);
      expect(p.y, 2.0);
      expect(p.z, 3.0);
    });

    test('subtracts two points to get a vector', () {
      final a = Point3D(3, 4, 5);
      final b = Point3D(1, 2, 3);
      final v = a - b;
      expect(v.x, closeTo(2, 1e-10));
      expect(v.y, closeTo(2, 1e-10));
      expect(v.z, closeTo(2, 1e-10));
    });

    test('adds a vector to a point', () {
      final p = Point3D(1, 2, 3);
      final v = Vector3D(10, 20, 30);
      final result = p + v;
      expect(result.x, closeTo(11, 1e-10));
      expect(result.y, closeTo(22, 1e-10));
      expect(result.z, closeTo(33, 1e-10));
    });

    test('distanceTo calculates Euclidean distance', () {
      final a = Point3D(0, 0, 0);
      final b = Point3D(3, 4, 0);
      expect(a.distanceTo(b), closeTo(5, 1e-10));
    });

    test('distanceTo handles 3D distance', () {
      final a = Point3D(0, 0, 0);
      final b = Point3D(1, 2, 3);
      expect(a.distanceTo(b), closeTo(3.741657, 1e-5));
    });

    test('midpoint calculates correct center between two points', () {
      final a = Point3D(0, 0, 0);
      final b = Point3D(2, 4, 6);
      final m = a.midpoint(b);
      expect(m.x, closeTo(1, 1e-10));
      expect(m.y, closeTo(2, 1e-10));
      expect(m.z, closeTo(3, 1e-10));
    });

    test('toVector creates a vector from origin', () {
      final p = Point3D(1, 2, 3);
      final v = p.toVector();
      expect(v.x, closeTo(1, 1e-10));
      expect(v.y, closeTo(2, 1e-10));
      expect(v.z, closeTo(3, 1e-10));
    });

    test('equality works by value', () {
      expect(Point3D(1, 2, 3), equals(Point3D(1, 2, 3)));
      expect(Point3D(1, 2, 3), isNot(equals(Point3D(1, 2, 4))));
    });

    test('origin constant is (0,0,0)', () {
      expect(Point3D.origin.x, 0);
      expect(Point3D.origin.y, 0);
      expect(Point3D.origin.z, 0);
    });
  });

  group('Vector3D', () {
    test('creates a vector with x, y, z components', () {
      final v = Vector3D(1, 2, 3);
      expect(v.x, 1);
      expect(v.y, 2);
      expect(v.z, 3);
    });

    test('magnitude returns correct length', () {
      expect(Vector3D(3, 4, 0).magnitude, closeTo(5, 1e-10));
      expect(Vector3D(1, 2, 3).magnitude, closeTo(3.741657, 1e-5));
    });

    test('normalized returns unit vector', () {
      final v = Vector3D(3, 0, 0);
      final n = v.normalized();
      expect(n.x, closeTo(1, 1e-10));
      expect(n.y, closeTo(0, 1e-10));
      expect(n.z, closeTo(0, 1e-10));
      expect(n.magnitude, closeTo(1, 1e-10));
    });

    test('normalized handles zero vector gracefully', () {
      final v = Vector3D(0, 0, 0);
      final n = v.normalized();
      expect(n.x, 0);
      expect(n.y, 0);
      expect(n.z, 0);
    });

    test('dot product calculates correctly', () {
      final a = Vector3D(1, 0, 0);
      final b = Vector3D(0, 1, 0);
      expect(a.dot(b), closeTo(0, 1e-10));
      expect(a.dot(a), closeTo(1, 1e-10));
    });

    test('cross product calculates correctly', () {
      final x = Vector3D(1, 0, 0);
      final y = Vector3D(0, 1, 0);
      final z = x.cross(y);
      expect(z.x, closeTo(0, 1e-10));
      expect(z.y, closeTo(0, 1e-10));
      expect(z.z, closeTo(1, 1e-10));
    });

    test('addition and subtraction work', () {
      final a = Vector3D(1, 2, 3);
      final b = Vector3D(10, 20, 30);
      expect((a + b), equals(Vector3D(11, 22, 33)));
      expect((a - b), equals(Vector3D(-9, -18, -27)));
    });

    test('scalar multiplication works', () {
      final v = Vector3D(1, 2, 3);
      final scaled = v * 3;
      expect(scaled, equals(Vector3D(3, 6, 9)));
    });

    test('negation works', () {
      final v = Vector3D(1, -2, 3);
      expect(-v, equals(Vector3D(-1, 2, -3)));
    });
  });

  group('Object3D', () {
    test('point object stores Point3D correctly', () {
      final p = Object3D.point(Point3D(1, 2, 3), color: 0xFF0000FF);
      expect(p.type, Object3DType.point);
      expect(p.point, equals(Point3D(1, 2, 3)));
      expect(p.color, 0xFF0000FF);
    });

    test('line object stores endpoints correctly', () {
      final line = Object3D.line(
        Point3D(0, 0, 0),
        Point3D(1, 1, 1),
        color: 0xFF00FF00,
      );
      expect(line.type, Object3DType.line);
      expect(line.pointA, equals(Point3D(0, 0, 0)));
      expect(line.pointB, equals(Point3D(1, 1, 1)));
    });

    test('plane object stores plane equation', () {
      // Plane z = 0: a=0, b=0, c=1, d=0
      final plane = Object3D.plane(a: 0, b: 0, c: 1, d: 0);
      expect(plane.type, Object3DType.plane);
      expect(plane.planeA, 0);
      expect(plane.planeB, 0);
      expect(plane.planeC, 1);
      expect(plane.planeD, 0);
    });

    test('surface object stores mesh data', () {
      final vertices = [
        Point3D(0, 0, 0),
        Point3D(1, 0, 0),
        Point3D(0, 1, 0),
        Point3D(1, 1, 1),
      ];
      final indices = [0, 1, 2, 1, 3, 2];
      final surface = Object3D.surface(
        vertices: vertices,
        indices: indices,
        color: 0x80FF0000,
      );
      expect(surface.type, Object3DType.surface);
      expect(surface.vertices.length, 4);
      expect(surface.indices.length, 6);
    });

    test('sphere object stores center and radius', () {
      final sphere = Object3D.sphere(
        center: Point3D(0, 0, 0),
        radius: 2,
        color: 0x80808080,
      );
      expect(sphere.type, Object3DType.sphere);
      expect(sphere.sphereCenter, equals(Point3D(0, 0, 0)));
      expect(sphere.sphereRadius, 2);
    });

    test('default color is grey', () {
      final p = Object3D.point(Point3D(1, 2, 3));
      expect(p.color, 0xFFAAAAAA);
    });

    test('transformOrigin centers geometry at origin', () {
      final sphere = Object3D.sphere(
        center: Point3D(5, 10, 15),
        radius: 1,
      );
      expect(sphere.transformOrigin, false);
    });

    test('custom label can be set', () {
      final p = Object3D.point(Point3D(0, 0, 0), label: 'A');
      expect(p.label, 'A');
    });
  });

  group('Object3DType enum', () {
    test('has all expected types', () {
      expect(Object3DType.values.length, 8);
      expect(Object3DType.values, contains(Object3DType.point));
      expect(Object3DType.values, contains(Object3DType.line));
      expect(Object3DType.values, contains(Object3DType.plane));
      expect(Object3DType.values, contains(Object3DType.surface));
      expect(Object3DType.values, contains(Object3DType.sphere));
      expect(Object3DType.values, contains(Object3DType.polyhedron));
      expect(Object3DType.values, contains(Object3DType.vector));
      expect(Object3DType.values, contains(Object3DType.curve));
    });
  });

  group('SurfaceMesh utility', () {
    test('creates grid mesh for z = f(x,y) function', () {
      final mesh = SurfaceMesh.fromFunction(
        xMin: -1,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        gridX: 2,
        gridY: 2,
        f: (x, y) => x * x + y * y,
      );
      // 3x3 grid = 9 vertices
      // 2x2 cells × 2 triangles per cell = 8 triangles = 24 indices
      expect(mesh.vertices.length, 9);
      expect(mesh.indices.length, 24);
      // Center point (0,0) should have z = 0
      expect(mesh.vertices[4].z, closeTo(0, 1e-10));
    });

    test('computes vertex normals for lighting', () {
      final mesh = SurfaceMesh.fromFunction(
        xMin: -1,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        gridX: 2,
        gridY: 2,
        f: (x, y) => 0, // flat plane
      );
      expect(mesh.normals.length, 9);
      // All normals should point up
      for (final n in mesh.normals) {
        expect(n.z, greaterThan(0));
      }
    });

    test('computes bounding box', () {
      final mesh = SurfaceMesh.fromFunction(
        xMin: -2,
        xMax: 2,
        yMin: -3,
        yMax: 3,
        gridX: 4,
        gridY: 6,
        f: (x, y) => x + y,
      );
      expect(mesh.boundingBoxMin.x, closeTo(-2, 1e-10));
      expect(mesh.boundingBoxMax.x, closeTo(2, 1e-10));
      expect(mesh.boundingBoxMin.y, closeTo(-3, 1e-10));
      expect(mesh.boundingBoxMax.y, closeTo(3, 1e-10));
    });
  });
}
