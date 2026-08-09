import 'dart:math' as dart_math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_3d_scene.dart';

void main() {
  group('Camera3D', () {
    test('default camera looks at origin from above', () {
      const cam = Camera3D();
      final pos = cam.position;
      expect(pos.z, greaterThan(0));
      expect(pos.x, greaterThan(0));
      expect(pos.y, greaterThan(0));
      // Distance from origin equals the camera distance.
      expect(pos.distanceTo(Point3D.origin), closeTo(cam.distance, 1e-9));
    });

    test('position follows spherical coordinates (z-up)', () {
      const cam =
          Camera3D(target: Point3D.origin, distance: 10, theta: 0, phi: 0);
      final pos = cam.position;
      // phi=0 → horizontal, theta=0 → along +X.
      expect(pos.z, closeTo(0, 1e-9));
      expect(pos.x, closeTo(10, 1e-9));
      expect(pos.y, closeTo(0, 1e-9));
    });

    test('view from top looks straight down', () {
      const cam = Camera3D(
          target: Point3D.origin,
          distance: 10,
          theta: 0,
          phi: dart_math.pi / 2 - 0.01);
      final pos = cam.position;
      expect(pos.x.abs(), lessThan(0.2));
      expect(pos.y.abs(), lessThan(0.2));
      expect(pos.z, greaterThan(9));
    });

    test('orbit updates theta and phi', () {
      const cam = Camera3D();
      final orbited = cam.orbit(deltaTheta: 0.5, deltaPhi: 0.25);
      expect(orbited.theta, closeTo(cam.theta + 0.5, 1e-12));
      expect(orbited.phi, closeTo(cam.phi + 0.25, 1e-12));
    });

    test('phi is clamped near poles', () {
      const cam = Camera3D();
      final orbited = cam.orbit(deltaTheta: 0, deltaPhi: dart_math.pi);
      expect(orbited.phi, lessThan(dart_math.pi / 2));
      expect(orbited.phi, greaterThan(-dart_math.pi / 2));
    });

    test('zoom changes distance', () {
      const cam = Camera3D(distance: 10);
      final closer = cam.zoom(factor: 2);
      expect(closer.distance, closeTo(5, 1e-12));
      final farther = cam.zoom(factor: 0.5);
      expect(farther.distance, closeTo(20, 1e-12));
    });

    test('pan moves target parallel to view plane', () {
      const cam = Camera3D(
          target: Point3D.origin,
          distance: 10,
          theta: 0,
          phi: dart_math.pi / 4);
      final panned = cam.pan(deltaX: 100, deltaY: 0);
      // The target must move (along the screen-right vector).
      expect(panned.target.distanceTo(Point3D.origin), greaterThan(0.01));
      expect(panned.target.z, closeTo(0, 1e-9)); // horizontal pan keeps z
    });

    test('standard views point along axes', () {
      const cam = Camera3D();
      final top = cam.withStandardView(StandardView.viewFromTop);
      final pos = top.position;
      expect(pos.x.abs(), lessThan(0.5));
      expect(pos.y.abs(), lessThan(0.5));
      expect(pos.z, greaterThan(9));

      final front = cam.withStandardView(StandardView.viewFromFront);
      final fpos = front.position;
      expect(fpos.z.abs(), lessThan(0.5));
      expect(fpos.x, greaterThan(9));
    });
  });

  group('Projection3D', () {
    const cam = Camera3D(
        target: Point3D.origin,
        distance: 10,
        theta: dart_math.pi / 4,
        phi: 0.615);

    test('parallel projection centers the target', () {
      final proj = Projection3D(
          type: ProjectionType.parallel, width: 800, height: 600, camera: cam);
      final s = proj.project(Point3D.origin);
      expect(s, isNotNull);
      expect(s!.x, closeTo(400, 0.1));
      expect(s.y, closeTo(300, 0.1));
    });

    test('perspective differs from parallel', () {
      final par = Projection3D(
          type: ProjectionType.parallel, width: 800, height: 600, camera: cam);
      final per = Projection3D(
          type: ProjectionType.perspective,
          width: 800,
          height: 600,
          camera: cam);
      final p1 = par.project(const Point3D(2, 0, 2))!;
      final p2 = per.project(const Point3D(2, 0, 2))!;
      expect(p1.x, isNot(closeTo(p2.x, 0.01)));
    });

    test('points behind camera project to NaN (perspective)', () {
      final per = Projection3D(
          type: ProjectionType.perspective,
          width: 800,
          height: 600,
          camera: cam);
      // A point far behind the camera (opposite the view direction).
      final behind = per.project(Point3D.origin + cam.forward * (-1000));
      expect(behind, isNull);
    });

    test('oblique projection keeps xOy face-on', () {
      final proj = Projection3D(
          type: ProjectionType.oblique,
          width: 800,
          height: 600,
          camera: const Camera3D());
      final a = proj.project(const Point3D(1, 0, 0))!;
      final b = proj.project(const Point3D(0, 1, 0))!;
      final c = proj.project(const Point3D(0, 0, 1))!;
      // X increases screen x, Z decreases screen y (screen y is down).
      expect(a.x, greaterThan(400));
      expect(a.y, closeTo(300, 1));
      expect(c.y, lessThan(300));
      expect(c.x, closeTo(400, 1));
      // Y is sheared: not purely vertical.
      expect(b.x, isNot(closeTo(400, 1)));
    });

    test('screenRay and screenToGround are inverse of project for parallel',
        () {
      final proj = Projection3D(
          type: ProjectionType.parallel, width: 800, height: 600, camera: cam);
      const world = Point3D(1.5, -2, 0.5);
      final s = proj.project(world)!;
      final ground = proj.screenToGround(s.x, s.y, z0: world.z);
      expect(ground, isNotNull);
      expect(ground!.x, closeTo(world.x, 1e-6));
      expect(ground.y, closeTo(world.y, 1e-6));
    });

    test('perspective screenRay passes through the world point', () {
      final proj = Projection3D(
          type: ProjectionType.perspective,
          width: 800,
          height: 600,
          camera: cam);
      const world = Point3D(1, 1, 1);
      final s = proj.project(world)!;
      final ray = proj.screenRay(s.x, s.y);
      // The ray origin + t·dir should hit the plane z=1 at world.
      final hit = ray.intersectPlane(Vector3D.unitZ, world.z);
      expect(hit, isNotNull);
      expect(hit!.x, closeTo(world.x, 0.5));
      expect(hit.y, closeTo(world.y, 0.5));
    });
  });

  group('Geometry utilities', () {
    test('distancePointToLine', () {
      final d = distancePointToLine(
          const Point3D(0, 2, 0), Point3D.origin, Vector3D.unitX);
      expect(d, closeTo(2, 1e-9));
    });

    test('distancePointToSegment', () {
      final d = distancePointToSegment(
          const Point3D(5, 5, 0), Point3D.origin, const Point3D(2, 0, 0));
      // Clamps to the endpoint (2, 0, 0): sqrt(3² + 5²).
      expect(d, closeTo(dart_math.sqrt(34), 1e-9));
    });

    test('intersectLineLine finds the intersection', () {
      final p = intersectLineLine(Point3D.origin, Vector3D.unitX,
          const Point3D(1, -2, 0), Vector3D.unitY);
      expect(p, isNotNull);
      expect(p!.x, closeTo(1, 1e-9));
      expect(p.y, closeTo(0, 1e-9));
      expect(p.z, closeTo(0, 1e-9));
    });

    test('intersectLineLine returns null for skew lines', () {
      final p = intersectLineLine(Point3D.origin, Vector3D.unitX,
          const Point3D(0, 0, 1), Vector3D.unitY);
      expect(p, isNull);
    });

    test('intersectLinePlane', () {
      final p =
          intersectLinePlane(Point3D.origin, Vector3D.unitZ, Vector3D.unitZ, 4);
      expect(p, isNotNull);
      expect(p!.z, closeTo(4, 1e-9));
    });

    test('intersectPlanePlane returns the crease line', () {
      final res = intersectPlanePlane(
          Vector3D.unitZ,
          0, // z = 0
          const Vector3D(1, 0, 0),
          1 // x = 1
          );
      expect(res, isNotNull);
      final (point, dir) = res!;
      expect(point.x, closeTo(1, 1e-9));
      expect(point.z, closeTo(0, 1e-9));
      expect(dir.dot(Vector3D.unitZ), closeTo(0, 1e-9));
      expect(dir.dot(const Vector3D(1, 0, 0)), closeTo(0, 1e-9));
    });

    test('rayTriangle intersection', () {
      const v0 = Point3D(0, 0, 0);
      const v1 = Point3D(1, 0, 0);
      const v2 = Point3D(0, 1, 0);
      final t = rayTriangle(
          const Point3D(0.2, 0.2, 5), Vector3D.unitZ * -1, v0, v1, v2);
      expect(t, isNotNull);
      expect(t!, closeTo(5, 1e-9));
      // Ray missing the triangle returns null.
      final miss =
          rayTriangle(const Point3D(5, 5, 5), Vector3D.unitZ * -1, v0, v1, v2);
      expect(miss, isNull);
    });
  });

  group('Scene3D', () {
    test('add / remove / clear / replace', () {
      final scene = Scene3D();
      final a = Object3D.point(const Point3D(1, 2, 3), name: 'A');
      final b = Object3D.point(const Point3D(4, 5, 6), name: 'B');
      scene.add(a);
      scene.add(b);
      expect(scene.objects.length, 2);

      scene.replace(a, a.translated(const Vector3D(0, 0, 10)));
      expect(scene.objects.first.pointValue.z, closeTo(13, 1e-9));

      scene.remove(b);
      expect(scene.objects.length, 1);
      scene.clear();
      expect(scene.objects.isEmpty, true);
    });

    test('objects list is unmodifiable', () {
      final scene = Scene3D()..add(Object3D.point(const Point3D(1, 1, 1)));
      expect(() => scene.objects.add(Object3D.point(const Point3D(0, 0, 0))),
          throwsUnsupportedError);
    });

    test('byName finds objects', () {
      final scene = Scene3D()
        ..add(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      expect(scene.byName('A'), isNotNull);
      expect(scene.byName('B'), isNull);
    });

    test('nextPointName generates unique labels', () {
      final scene = Scene3D()
        ..add(Object3D.point(const Point3D(0, 0, 0), name: 'A'))
        ..add(Object3D.point(const Point3D(0, 0, 0), name: 'B'));
      expect(scene.nextPointName(), 'C');
    });

    test('boundingBox covers all objects', () {
      final scene = Scene3D()
        ..add(Object3D.point(const Point3D(-1, -2, -3)))
        ..add(Object3D.point(const Point3D(4, 5, 6)));
      final bb = scene.boundingBox();
      expect(bb, isNotNull);
      final (min, max) = bb!;
      expect(min, const Point3D(-1, -2, -3));
      expect(max, const Point3D(4, 5, 6));
    });

    test('fitToView centers on the scene', () {
      final scene = Scene3D()
        ..add(Object3D.point(const Point3D(10, 10, 10)))
        ..add(Object3D.point(const Point3D(-10, -10, -10)));
      scene.fitToView();
      final cam = scene.camera;
      expect(cam.target, const Point3D(0, 0, 0));
      expect(cam.distance, greaterThan(10));
    });

    test('pick finds a point object under the cursor', () {
      final scene = Scene3D()
        ..setViewport(800, 600)
        ..add(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      final cam = Camera3D(
          target: Point3D.origin,
          distance: 10,
          theta: dart_math.pi / 4,
          phi: 0.615);
      scene.setCamera(cam);
      final proj = scene.projection;
      final s = proj.project(Point3D.origin)!;
      final hit = scene.pick(s.x, s.y);
      expect(hit, isNotNull);
      expect(hit!.$1.name, 'A');
      expect(hit.$2, const Point3D(0, 0, 0));
    });

    test('pick returns null on empty space', () {
      final scene = Scene3D()
        ..setViewport(800, 600)
        ..add(Object3D.point(const Point3D(3, 3, 3), name: 'A'));
      final cam = Camera3D(
          target: Point3D.origin,
          distance: 10,
          theta: dart_math.pi / 4,
          phi: 0.615);
      scene.setCamera(cam);
      final hit = scene.pick(100, 100);
      expect(hit, isNull);
    });

    test('pick hits a sphere via ray-triangle', () {
      final scene = Scene3D()
        ..setViewport(800, 600)
        ..add(Object3D.sphere(Point3D.origin, 1, name: 'S'));
      final cam = Camera3D(
          target: Point3D.origin,
          distance: 10,
          theta: dart_math.pi / 4,
          phi: 0.615);
      scene.setCamera(cam);
      final s = scene.projection.project(Point3D.origin)!;
      final hit = scene.pick(s.x, s.y);
      expect(hit, isNotNull);
      expect(hit!.$1.name, 'S');
    });

    test('pick hits a segment', () {
      final scene = Scene3D()
        ..setViewport(800, 600)
        ..add(Object3D.segment(const Point3D(-2, 0, 0), const Point3D(2, 0, 0),
            name: 's'));
      final cam = Camera3D(
          target: Point3D.origin,
          distance: 10,
          theta: dart_math.pi / 4,
          phi: 0.615);
      scene.setCamera(cam);
      final s = scene.projection.project(const Point3D(0, 0, 0))!;
      final hit = scene.pick(s.x, s.y);
      expect(hit, isNotNull);
      expect(hit!.$1.name, 's');
      expect(hit.$2.distanceTo(Point3D.origin), lessThan(1));
    });
  });

  group('Scene3D projection round trip', () {
    test('worldToScreen is consistent for the default camera', () {
      final scene = Scene3D()..setViewport(800, 600);
      final proj = scene.projection;
      const world = Point3D(1, 2, 3);
      final s = proj.project(world);
      expect(s, isNotNull);
      expect(s!.x.isFinite, true);
      expect(s.y.isFinite, true);
    });
  });
}
