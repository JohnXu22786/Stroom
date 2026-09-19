import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/models/math_3d_construction.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_3d_scene.dart';
import 'package:stroom/models/math_3d_tool.dart';

void main() {
  group('3D construction geometry', () {
    test('intersects a ray with a working plane in front of the camera', () {
      const ray = Ray3D(Point3D(1, 2, 5), Vector3D(0, 0, -1));

      final hit = intersectRayPlane(
        ray,
        point: const Point3D(0, 0, 2),
        normal: Vector3D.unitZ,
      );

      expect(hit, const Point3D(1, 2, 2));
    });

    test('does not create a false hit for a parallel ray', () {
      const ray = Ray3D(Point3D(0, 0, 1), Vector3D.unitX);

      final hit = intersectRayPlane(
        ray,
        point: Point3D.origin,
        normal: Vector3D.unitZ,
      );

      expect(hit, isNull);
    });

    test('sphere keeps a spatial radius point instead of flattening it', () {
      final construction = ConstructionState(tool: ConstructionTool.sphere);
      expect(
        construction.addPoint(const Point3D(1, 2, 3)),
        ConstructionAction.advanceStep,
      );
      expect(
        construction.addPoint(const Point3D(1, 2, 6)),
        ConstructionAction.complete,
      );

      expect(construction.result?.type, Object3DType.sphere);
      expect(construction.result?.sphereCenter, const Point3D(1, 2, 3));
      expect(construction.result?.sphereRadius, 3);
    });
  });
}
