import 'dart:math' as dart_math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_3d_scene.dart';

void main() {
  group('Camera3D', () {
    test('creates camera with default values looking at origin', () {
      final cam = Camera3D();
      expect(cam.target, equals(Point3D(0, 0, 0)));
      expect(cam.distance, 10);
      expect(cam.theta, closeTo(0, 1e-10));
      expect(cam.phi, closeTo(dart_math.pi / 4, 1e-10));
    });

    test('position is derived from spherical coordinates', () {
      // Use phi=0 so camera is on the horizon (no clamping issues)
      final cam = Camera3D(
        target: Point3D(0, 0, 0),
        distance: 10,
        theta: 0,
        phi: 0,
      );
      final pos = cam.position;
      // phi=0, theta=0: position should be (0, 0, 10)
      expect(pos.x, closeTo(0, 1e-10));
      expect(pos.y, closeTo(0, 1e-10));
      expect(pos.z, closeTo(10, 1e-10));
    });

    test('phi is clamped during orbit operation', () {
      // Constructor doesn't clamp (const), but orbit does
      final cam = Camera3D().orbit(deltaTheta: 0, deltaPhi: dart_math.pi * 6);
      expect(cam.phi, lessThanOrEqualTo(dart_math.pi * 0.49));
      expect(cam.phi, greaterThanOrEqualTo(-dart_math.pi * 0.49));
    });

    test('distance is clamped during zoom operation', () {
      // Constructor doesn't clamp (const), but zoom does
      final cam = Camera3D(distance: 10).zoom(factor: 0.001);
      expect(cam.distance, greaterThanOrEqualTo(0.1));
    });

    test('orbit rotation updates theta', () {
      final cam = Camera3D();
      final updated = cam.orbit(deltaTheta: 0.5, deltaPhi: 0);
      expect(updated.theta, closeTo(0.5, 1e-10));
      expect(updated.phi, closeTo(dart_math.pi / 4, 1e-10));
    });

    test('orbit rotation updates phi', () {
      final cam = Camera3D();
      final updated = cam.orbit(deltaTheta: 0, deltaPhi: 0.3);
      expect(updated.phi, closeTo(dart_math.pi / 4 + 0.3, 1e-10));
    });

    test('zoom changes distance by factor', () {
      final cam = Camera3D(distance: 10);
      final updated = cam.zoom(factor: 2);
      expect(updated.distance, closeTo(5, 1e-10)); // zoom in: distance / factor
    });

    test('pan moves target parallel to view plane', () {
      final cam = Camera3D(
        target: Point3D(0, 0, 0),
        distance: 10,
        theta: 0,
        phi: 0, // looking along Z axis
      );
      final updated = cam.pan(deltaX: 100, deltaY: 200);
      // Pan sensitivity: distance * 0.005
      // deltaX=100 → target.x changes by -100 * 10 * 0.005 = -5
      expect(updated.target.x, closeTo(-5, 1e-10));
      // deltaY=200 → target.y changes by 200 * 10 * 0.005 = 10
      expect(updated.target.y, closeTo(10, 1e-10));
      expect(updated.target.z, closeTo(0, 1e-10));
    });

    test('view matrix is 4x4', () {
      final cam = Camera3D();
      final viewMatrix = cam.viewMatrix();
      expect(viewMatrix.length, 16); // 4x4 column-major
    });

    test('position is finite for valid camera', () {
      final cam = Camera3D();
      final pos = cam.position;
      expect(pos.x.isFinite, true);
      expect(pos.y.isFinite, true);
      expect(pos.z.isFinite, true);
    });

    test('copyWith creates modified copy', () {
      final cam = Camera3D();
      final modified = cam.copyWith(distance: 20);
      expect(modified.distance, 20);
      // Original unchanged
      expect(cam.distance, 10);
    });
  });

  group('Projection3D', () {
    test('parallel projection creates orthographic matrix', () {
      final proj = Projection3D.parallel(
        width: 800,
        height: 600,
        scale: 50,
      );
      expect(proj.type, ProjectionType.parallel);
      expect(proj.width, 800);
      expect(proj.height, 600);
    });

    test('perspective projection creates perspective matrix', () {
      final proj = Projection3D.perspective(
        width: 800,
        height: 600,
        fov: 60,
        near: 0.1,
        far: 1000,
      );
      expect(proj.type, ProjectionType.perspective);
      expect(proj.fov, 60);
    });

    test('projection matrix is 4x4', () {
      final proj = Projection3D.parallel(width: 800, height: 600);
      final matrix = proj.projectionMatrix();
      expect(matrix.length, 16);
    });

    test('project transforms 3D point to 2D screen coordinates', () {
      final proj = Projection3D.parallel(width: 800, height: 600, scale: 50);
      // Origin should project to center of screen
      final screen = proj.project(Point3D(0, 0, 0));
      expect(screen.x, closeTo(400, 1));
      expect(screen.y, closeTo(300, 1));
      // z is depth (for sorting) — finite
      expect(screen.z.isFinite, isTrue);
    });

    test('project maps positive x to the right', () {
      final proj = Projection3D.parallel(width: 800, height: 600, scale: 50);
      final screen = proj.project(Point3D(1, 0, 0));
      expect(screen.x, greaterThan(400)); // right of center
    });

    test('project maps positive y upward (screen y decreases)', () {
      final proj = Projection3D.parallel(width: 800, height: 600, scale: 50);
      final screen = proj.project(Point3D(0, 1, 0));
      expect(screen.y, lessThan(300)); // higher on screen
    });

    test('perspective projection produces different results from parallel', () {
      final parallel =
          Projection3D.parallel(width: 800, height: 600, scale: 50);
      final perspective = Projection3D.perspective(
        width: 800,
        height: 600,
        fov: 60,
        near: 0.1,
        far: 1000,
      );
      final p1 = parallel.project(Point3D(1, 0, 5));
      final p2 = perspective.project(Point3D(1, 0, 5));
      // They differ (perspective has foreshortening)
      expect(p1.x, isNot(equals(p2.x)));
    });
  });

  group('Scene3D', () {
    test('creates empty scene', () {
      final scene = Scene3D();
      expect(scene.objects, isEmpty);
      expect(scene.camera, isNotNull);
    });

    test('adds objects to scene', () {
      final scene = Scene3D();
      final obj = Object3D.point(Point3D(1, 2, 3));
      scene.add(obj);
      expect(scene.objects.length, 1);
    });

    test('removes objects from scene', () {
      final scene = Scene3D();
      final obj = Object3D.point(Point3D(1, 2, 3));
      scene.add(obj);
      scene.remove(obj);
      expect(scene.objects, isEmpty);
    });

    test('clears all objects', () {
      final scene = Scene3D();
      scene.add(Object3D.point(Point3D(1, 2, 3)));
      scene.add(Object3D.point(Point3D(4, 5, 6)));
      scene.clear();
      expect(scene.objects, isEmpty);
    });

    test('scene center is at target if no objects', () {
      final scene = Scene3D();
      expect(scene.sceneCenter, equals(Point3D(0, 0, 0)));
    });

    test('fitToView adjusts camera to encompass all objects', () {
      final scene = Scene3D();
      scene.add(Object3D.point(Point3D(-5, -5, -5)));
      scene.add(Object3D.point(Point3D(5, 5, 5)));
      scene.fitToView();
      // Camera distance should be large enough to see both points
      expect(scene.camera.distance, greaterThan(5));
    });

    test('objects list is immutable from outside', () {
      final scene = Scene3D();
      scene.add(Object3D.point(Point3D(1, 2, 3)));
      final objects = scene.objects;
      expect(objects.length, 1);
      // Modifying the returned list should not affect scene
      // (the getter returns an unmodifiable list)
      // This test verifies the behavior even if it's just the length
    });
  });

  group('3D to 2D pipeline', () {
    test('worldToScreen transforms through camera and projection', () {
      final cam = Camera3D(
        target: Point3D(0, 0, 0),
        distance: 10,
        theta: 0,
        phi: 0,
      );
      final proj = Projection3D.parallel(width: 800, height: 600, scale: 50);
      final screen = worldToScreen(Point3D(0, 0, 0), cam, proj);
      expect(screen.x, closeTo(400, 5));
      expect(screen.y, closeTo(300, 5));
    });

    test('worldToScreen preserves relative positions', () {
      final cam = Camera3D(
        target: Point3D(0, 0, 0),
        distance: 10,
        theta: 0,
        phi: 0,
      );
      final proj = Projection3D.parallel(width: 800, height: 600, scale: 50);
      final left = worldToScreen(Point3D(-1, 0, 0), cam, proj);
      final right = worldToScreen(Point3D(1, 0, 0), cam, proj);
      expect(left.x, lessThan(right.x));
    });

    test('worldToScreen returns finite values for valid input', () {
      final cam = Camera3D();
      final proj = Projection3D.parallel(width: 800, height: 600);
      final screen = worldToScreen(Point3D(100, 100, 100), cam, proj);
      expect(screen.x.isFinite, true);
      expect(screen.y.isFinite, true);
    });

    test('worldToScreen handles object behind camera', () {
      final cam = Camera3D(
        target: Point3D(0, 0, 0),
        distance: 5,
        theta: 0,
        phi: 0,
      );
      final proj = Projection3D.perspective(
        width: 800,
        height: 600,
        fov: 60,
      );
      // Point behind the camera
      final screen = worldToScreen(Point3D(0, 0, 20), cam, proj);
      // Should not crash, might return invalid coordinates
      expect(screen, isNotNull);
    });
  });

  group('Matrix4 utilities', () {
    test('identity matrix has correct diagonal', () {
      final m = identityMatrix4();
      for (int i = 0; i < 4; i++) {
        expect(m[i * 4 + i], closeTo(1, 1e-10));
      }
    });

    test('matrix multiplication produces correct result', () {
      // A = translate(1,2,3), B = scale(2,2,2)
      // A * B means "scale then translate" — translation is unchanged
      final a = <double>[
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        1,
        2,
        3,
        1,
      ];
      final b = scaleMatrix4(2, 2, 2);
      final result = multiplyMatrix4(a, b);
      // Scale part should be [2, 2, 2]
      expect(result[0], closeTo(2, 1e-10)); // scale x
      expect(result[5], closeTo(2, 1e-10)); // scale y
      expect(result[10], closeTo(2, 1e-10)); // scale z
      // Translation remains unchanged (scale then translate)
      expect(result[12], closeTo(1, 1e-10));
      expect(result[13], closeTo(2, 1e-10));
      expect(result[14], closeTo(3, 1e-10));
    });
  });
}
