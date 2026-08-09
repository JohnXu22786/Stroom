import 'dart:math' as dart_math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_construction.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_3d_tool.dart';

void main() {
  group('ConstructionState workflow', () {
    test('point tool completes with one point', () {
      final state = ConstructionState(tool: ConstructionTool.point);
      expect(state.currentInstruction, contains('点击'));
      final done = state.addInput(const NewPointInput(Point3D(1, 2, 3)));
      expect(done, true);
      final result = state.result!;
      expect(result.created.length, 1);
      expect(result.created.first.type, Object3DType.point);
      expect(result.created.first.pointValue, const Point3D(1, 2, 3));
    });

    test('line tool completes with two points', () {
      final state = ConstructionState(tool: ConstructionTool.line);
      expect(state.addInput(const NewPointInput(Point3D(0, 0, 0))), false);
      expect(state.currentInstruction, contains('第二个'));
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 1)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.line);
      expect(obj.pointAValue, const Point3D(0, 0, 0));
      expect(obj.vectorValue, const Vector3D(1, 1, 1));
    });

    test('segment tool creates a segment', () {
      final state = ConstructionState(tool: ConstructionTool.segment);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      expect(done, true);
      expect(state.result!.created.first.type, Object3DType.segment);
    });

    test('polygon closes on the first vertex', () {
      final state = ConstructionState(tool: ConstructionTool.polygon);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 2, 0)));
      final done = state.addInput(const NewPointInput(Point3D(0.05, 0.02, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.polygon);
      expect(obj.polygonVertices.length, 3);
    });

    test('plane tool creates a plane through three points', () {
      final state = ConstructionState(tool: ConstructionTool.plane3Points);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(0, 1, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.plane);
      // Plane z=0 → normal (0,0,1), d=0.
      expect(obj.planeNormalC, closeTo(1, 1e-9));
      expect(obj.planeDValue, closeTo(0, 1e-9));
    });

    test('sphere center+point tool creates a sphere', () {
      final state = ConstructionState(tool: ConstructionTool.sphereCenterPoint);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(3, 4, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.sphere);
      expect(obj.sphereCenter, const Point3D(0, 0, 0));
      expect(obj.sphereRadius, closeTo(5, 1e-9));
    });

    test('sphere center+radius uses the numeric input', () {
      final state =
          ConstructionState(tool: ConstructionTool.sphereCenterRadius);
      state.addInput(const NewPointInput(Point3D(1, 1, 1)));
      expect(state.awaitingNumber, true);
      final done = state.addInput(const NumberInput(2.5));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.sphereRadius, closeTo(2.5, 1e-9));
      expect(obj.sphereCenter, const Point3D(1, 1, 1));
    });

    test('circle center+point creates a horizontal circle', () {
      final state = ConstructionState(tool: ConstructionTool.circleCenterPoint);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.circle);
      expect(obj.circleNormal, Vector3D.unitZ);
      expect(obj.circleRadius, closeTo(1, 1e-9));
    });

    test('circle through 3 points is arbitrary orientation', () {
      final state = ConstructionState(tool: ConstructionTool.circle3Points);
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      state.addInput(const NewPointInput(Point3D(0, 1, 0)));
      final done = state.addInput(const NewPointInput(Point3D(0, 0, 1)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.circle);
      // Circumcircle of the three unit points: center (1/3,1/3,1/3),
      // radius sqrt(2/3).
      expect(obj.circleRadius, closeTo(dart_math.sqrt(2 / 3), 1e-9));
      expect(obj.circleCenter!.x, closeTo(1 / 3, 1e-9));
    });

    test('arc tool creates an arc', () {
      final state = ConstructionState(tool: ConstructionTool.arc);
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      state.addInput(const NewPointInput(Point3D(0, 1, 0)));
      final done = state.addInput(const NewPointInput(Point3D(-1, 0, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.arc);
      expect(obj.arcStart, isNotNull);
      expect(obj.arcEnd, isNotNull);
    });

    test('cube tool creates a polyhedron from two points', () {
      final state = ConstructionState(tool: ConstructionTool.cube);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.polyhedron);
      expect(obj.mesh!.vertices.length, 8);
    });

    test('tetrahedron tool creates a regular tetrahedron', () {
      final state = ConstructionState(tool: ConstructionTool.tetrahedron);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      final verts = obj.mesh!.vertices;
      expect(verts.length, 4);
      // All edges have length 2.
      for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 4; j++) {
          expect(verts[i].distanceTo(verts[j]), closeTo(2, 1e-9));
        }
      }
    });

    test('cone tool needs center, rim and apex', () {
      final state = ConstructionState(tool: ConstructionTool.cone);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(0, 0, 3)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.cone);
      expect(obj.solidRadius, closeTo(1, 1e-9));
      expect(obj.solidHeight, closeTo(3, 1e-9));
    });

    test('cylinder tool needs center, rim and top', () {
      final state = ConstructionState(tool: ConstructionTool.cylinder);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(0, 0, 5)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.cylinder);
      expect(obj.solidRadius, closeTo(2, 1e-9));
      expect(obj.solidHeight, closeTo(5, 1e-9));
    });

    test('pyramid closes base then takes apex', () {
      final state = ConstructionState(tool: ConstructionTool.pyramid);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 2, 0)));
      expect(
          state.addInput(const NewPointInput(Point3D(0.05, 0.02, 0))), false);
      expect(state.baseClosed, true);
      expect(state.currentInstruction, contains('顶点'));
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 4)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.polyhedron);
      expect(obj.mesh!.vertices.length, 5);
    });

    test('prism extrudes from closed base', () {
      final state = ConstructionState(tool: ConstructionTool.prism);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 2, 0)));
      state.addInput(const NewPointInput(Point3D(0.05, 0.02, 0)));
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 4)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.mesh!.vertices.length, 8);
    });

    test('regularPolygon uses number of sides', () {
      final state = ConstructionState(tool: ConstructionTool.regularPolygon);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      expect(state.awaitingNumber, true);
      final done = state.addInput(const NumberInput(6));
      expect(done, true);
      final obj = state.result!.created.first;
      final verts = obj.polygonVertices;
      expect(verts.length, 6);
      // Vertex 0 is the first clicked point, vertex 1 the second (AB is an
      // edge), and all edges have length 2.
      expect(verts[0].distanceTo(const Point3D(0, 0, 0)), lessThan(1e-6));
      expect(verts[1].distanceTo(const Point3D(2, 0, 0)), lessThan(1e-6));
      for (int i = 0; i < 6; i++) {
        expect(verts[i].distanceTo(verts[(i + 1) % 6]), closeTo(2, 1e-9));
      }
    });
  });

  group('Object-input tools', () {
    test('midpoint of a segment', () {
      final seg =
          Object3D.segment(const Point3D(0, 0, 0), const Point3D(4, 6, 8));
      final state = ConstructionState(tool: ConstructionTool.midpoint);
      final done = state.addInput(ObjectInput(seg));
      expect(done, true);
      final p = state.result!.created.first;
      expect(p.type, Object3DType.point);
      expect(p.pointValue, const Point3D(2, 3, 4));
    });

    test('intersect line-line creates a point', () {
      final l1 = Object3D.line(Point3D.origin, Vector3D.unitX);
      final l2 = Object3D.line(const Point3D(1, -2, 0), Vector3D.unitY);
      final state = ConstructionState(tool: ConstructionTool.intersect);
      state.addInput(ObjectInput(l1));
      final done = state.addInput(ObjectInput(l2));
      expect(done, true);
      final created = state.result!.created;
      expect(created.length, 1);
      expect(created.first.type, Object3DType.point);
      expect(created.first.pointValue.x, closeTo(1, 1e-9));
    });

    test('intersect plane-plane creates a line', () {
      final p1 = Object3D.plane(a: 0, b: 0, c: 1, d: 0);
      final p2 = Object3D.plane(a: 1, b: 0, c: 0, d: 1);
      final state = ConstructionState(tool: ConstructionTool.intersect);
      state.addInput(ObjectInput(p1));
      final done = state.addInput(ObjectInput(p2));
      expect(done, true);
      final created = state.result!.created;
      expect(created.length, 1);
      expect(created.first.type, Object3DType.line);
    });

    test('intersect line-sphere creates two points', () {
      final line = Object3D.line(Point3D.origin, Vector3D.unitZ);
      final sphere = Object3D.sphere(Point3D.origin, 1);
      final state = ConstructionState(tool: ConstructionTool.intersect);
      state.addInput(ObjectInput(line));
      final done = state.addInput(ObjectInput(sphere));
      expect(done, true);
      final created = state.result!.created;
      expect(created.length, 2);
      expect(created[0].pointValue.z, closeTo(-1, 1e-9));
      expect(created[1].pointValue.z, closeTo(1, 1e-9));
    });

    test('perpendicular line through a point', () {
      final line = Object3D.line(Point3D.origin, Vector3D.unitX);
      final state = ConstructionState(tool: ConstructionTool.perpendicularLine);
      state.addInput(ObjectInput(line));
      final done = state.addInput(const NewPointInput(Point3D(1, 2, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.line);
      // Direction must be perpendicular to X.
      expect(obj.vectorValue.dot(Vector3D.unitX), closeTo(0, 1e-9));
    });

    test('parallel line through a point', () {
      final line = Object3D.line(Point3D.origin, Vector3D.unitX);
      final state = ConstructionState(tool: ConstructionTool.parallelLine);
      state.addInput(ObjectInput(line));
      final done = state.addInput(const NewPointInput(Point3D(0, 5, 0)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.pointAValue, const Point3D(0, 5, 0));
      expect(obj.vectorValue.dot(Vector3D.unitX), closeTo(1, 1e-9));
    });

    test('extrude prism from a polygon', () {
      final poly = Object3D.polygon(const [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ]);
      final state = ConstructionState(tool: ConstructionTool.extrudePrism);
      state.addInput(ObjectInput(poly));
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 3)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.type, Object3DType.polyhedron);
      expect(obj.mesh!.vertices.length, 8);
    });

    test('extrude pyramid from a polygon', () {
      final poly = Object3D.polygon(const [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ]);
      final state = ConstructionState(tool: ConstructionTool.extrudePyramid);
      state.addInput(ObjectInput(poly));
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 3)));
      expect(done, true);
      final obj = state.result!.created.first;
      expect(obj.mesh!.vertices.length, 5);
    });
  });

  group('Measurement and transformation tools', () {
    test('distance between two points', () {
      final state = ConstructionState(tool: ConstructionTool.distance);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(3, 4, 0)));
      expect(done, true);
      final created = state.result!.created;
      final m = created.firstWhere((o) => o.type == Object3DType.measurement);
      expect(m.measureText, contains('5'));
    });

    test('distance point to line', () {
      final line = Object3D.line(Point3D.origin, Vector3D.unitX);
      final state = ConstructionState(tool: ConstructionTool.distance);
      state.addInput(ObjectInput(line));
      final done = state.addInput(const NewPointInput(Point3D(0, 3, 4)));
      expect(done, true);
      final m = state.result!.created
          .firstWhere((o) => o.type == Object3DType.measurement);
      expect(m.measureText, contains('5'));
    });

    test('angle between three points', () {
      final state = ConstructionState(tool: ConstructionTool.angle);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      final done = state.addInput(const NewPointInput(Point3D(0, 1, 0)));
      expect(done, true);
      final m = state.result!.created
          .firstWhere((o) => o.type == Object3DType.measurement);
      expect(m.measureText, contains('90'));
    });

    test('area of a polygon', () {
      final poly = Object3D.polygon(const [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ]);
      final state = ConstructionState(tool: ConstructionTool.area);
      final done = state.addInput(ObjectInput(poly));
      expect(done, true);
      final m = state.result!.created.first;
      expect(m.measureText, contains('4'));
    });

    test('area of a circle', () {
      final circle = Object3D.circle(Point3D.origin, Vector3D.unitZ, 2);
      final state = ConstructionState(tool: ConstructionTool.area);
      final done = state.addInput(ObjectInput(circle));
      expect(done, true);
      final m = state.result!.created.first;
      expect(m.measureText, contains('12.57'));
    });

    test('volume of a sphere', () {
      final sphere = Object3D.sphere(Point3D.origin, 1);
      final state = ConstructionState(tool: ConstructionTool.volume);
      final done = state.addInput(ObjectInput(sphere));
      expect(done, true);
      final m = state.result!.created.first;
      expect(m.measureText, contains('4.19'));
    });

    test('volume of a cube polyhedron', () {
      final cube = Object3D.polyhedron(
          MeshBuilder.cube(Point3D.origin, const Point3D(1, 1, 1)));
      final state = ConstructionState(tool: ConstructionTool.volume);
      final done = state.addInput(ObjectInput(cube));
      expect(done, true);
      final m = state.result!.created.first;
      expect(m.measureText, contains('1'));
    });

    test('translate by vector', () {
      final point = Object3D.point(const Point3D(1, 1, 1), name: 'P');
      final state = ConstructionState(tool: ConstructionTool.translate);
      state.addInput(ObjectInput(point));
      state.addInput(const NewPointInput(Point3D.origin));
      final done = state.addInput(const NewPointInput(Point3D(2, 0, 0)));
      expect(done, true);
      final moved = state.result!.created.first;
      expect(moved.pointValue, const Point3D(3, 1, 1));
      expect(moved.name, 'P');
    });

    test('reflect about point', () {
      final point = Object3D.point(const Point3D(2, 2, 2));
      final state = ConstructionState(tool: ConstructionTool.reflectPoint);
      state.addInput(ObjectInput(point));
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 1)));
      expect(done, true);
      final r = state.result!.created.first;
      expect(r.pointValue, const Point3D(0, 0, 0));
    });

    test('reflect about plane', () {
      final point = Object3D.point(const Point3D(1, 2, 3));
      final plane = Object3D.plane(a: 0, b: 0, c: 1, d: 0);
      final state = ConstructionState(tool: ConstructionTool.reflectPlane);
      state.addInput(ObjectInput(point));
      final done = state.addInput(ObjectInput(plane));
      expect(done, true);
      final r = state.result!.created.first;
      expect(r.pointValue, const Point3D(1, 2, -3));
    });

    test('rotate around line', () {
      final point = Object3D.point(const Point3D(1, 0, 0));
      final axis = Object3D.line(Point3D.origin, Vector3D.unitZ);
      final state = ConstructionState(tool: ConstructionTool.rotateLine);
      state.addInput(ObjectInput(point));
      state.addInput(ObjectInput(axis));
      final done = state.addInput(const NumberInput(90));
      expect(done, true);
      final r = state.result!.created.first;
      expect(r.pointValue.x, closeTo(0, 1e-9));
      expect(r.pointValue.y, closeTo(1, 1e-9));
    });

    test('dilate scales from a point', () {
      final point = Object3D.point(const Point3D(2, 0, 0));
      final state = ConstructionState(tool: ConstructionTool.dilate);
      state.addInput(ObjectInput(point));
      state.addInput(const NewPointInput(Point3D.origin));
      final done = state.addInput(const NumberInput(0.5));
      expect(done, true);
      final r = state.result!.created.first;
      expect(r.pointValue, const Point3D(1, 0, 0));
    });

    test('delete removes the object', () {
      final point = Object3D.point(const Point3D(1, 1, 1));
      final state = ConstructionState(tool: ConstructionTool.delete);
      final done = state.addInput(ObjectInput(point));
      expect(done, true);
      expect(state.result!.removed, [point]);
    });

    test('showHide toggles visibility', () {
      final point = Object3D.point(const Point3D(1, 1, 1));
      final state = ConstructionState(tool: ConstructionTool.showHide);
      final done = state.addInput(ObjectInput(point));
      expect(done, true);
      expect(state.result!.modified.first.visible, false);
    });
  });

  group('Construction preview', () {
    test('preview points and segments follow inputs', () {
      final state = ConstructionState(tool: ConstructionTool.polygon);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      expect(state.previewPoints.length, 2);
      expect(state.previewSegments.length, 1);
    });

    test('free click on object-step is ignored', () {
      final state = ConstructionState(tool: ConstructionTool.midpoint);
      final done = state.addInput(const NewPointInput(Point3D(1, 1, 1)));
      expect(done, false);
      expect(state.inputs.isEmpty, true);
    });

    test('number step prompts via awaitingNumber', () {
      final state = ConstructionState(tool: ConstructionTool.regularPolygon);
      state.addInput(const NewPointInput(Point3D.origin));
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      expect(state.awaitingNumber, true);
      expect(state.currentStep!.kind, InputKind.number);
    });

    test('reset clears the construction', () {
      final state = ConstructionState(tool: ConstructionTool.line);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.reset();
      expect(state.inputs.isEmpty, true);
      expect(state.isComplete, false);
    });
  });

  group('Geometry math (ToolFactory helpers)', () {
    test('regular polygon from the tool forms an equilateral hexagon', () {
      final state = ConstructionState(tool: ConstructionTool.regularPolygon);
      state.addInput(const NewPointInput(Point3D(0, 0, 0)));
      state.addInput(const NewPointInput(Point3D(1, 0, 0)));
      state.addInput(const NumberInput(6));
      final verts = state.result!.created.first.polygonVertices;
      expect(verts.length, 6);
      for (int i = 0; i < 6; i++) {
        final d = verts[i].distanceTo(verts[(i + 1) % 6]);
        expect(d, closeTo(1, 1e-9));
      }
    });
  });
}
