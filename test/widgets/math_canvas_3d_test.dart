import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_expression_3d.dart';
import 'package:stroom/widgets/math_canvas_3d.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
      home: Scaffold(
          body:
              Center(child: SizedBox(width: 800, height: 600, child: child))));
}

void main() {
  group('MathCanvas3D basics', () {
    testWidgets('creates 3D canvas without error', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('surface with a singularity (z=1/x) renders without crash',
        (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      // The sample grid hits x=0 exactly, producing infinite vertices; the
      // renderer must skip those triangles instead of crashing on NaN
      // shading (regression: UnsupportedError in _shaded's .round()).
      final expr = Expression3D.surface('z = 1/x');
      expect(expr.isValid, isTrue);
      final mesh = expr.sampleSurfaceGrid(
        xMin: -5,
        xMax: 5,
        yMin: -5,
        yMax: 5,
        gridX: 36,
        gridY: 36,
      );
      // Transparent style is REQUIRED to exercise the crash path: opaque
      // faces are back-face culled (NaN normal fails the facing test) and
      // the parallel projection filters NaN — only translucent surfaces
      // reach _shaded with a NaN normal.
      state.addObject(Object3D.surface(mesh,
          name: 'f1', style: const ObjectStyle(opacity: 0.5)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('canvas is ready callback fires', (tester) async {
      var ready = false;
      await tester.pumpWidget(_wrap(MathCanvas3D(onReady: () => ready = true)));
      await tester.pump();
      expect(ready, true);
    });

    testWidgets('default view settings', (tester) async {
      late MathCanvas3DState state;
      await tester.pumpWidget(_wrap(MathCanvas3D(
        onReady: () {},
      )));
      await tester.pump();
      state = tester.state(find.byType(MathCanvas3D));
      expect(state.showAxes, true);
      expect(state.showGrid, true);
      expect(state.showPlane, true);
      expect(state.projectionType, ProjectionType.parallel);
      expect(state.activeTool, ConstructionTool.move);
    });

    testWidgets('toggleAxes / toggleGrid / togglePlane', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.toggleAxes();
      await tester.pump();
      expect(state.showAxes, false);
      state.toggleGrid();
      await tester.pump();
      expect(state.showGrid, false);
      state.togglePlane();
      await tester.pump();
      expect(state.showPlane, false);
    });

    testWidgets('setProjectionType changes projection', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.setProjectionType(ProjectionType.perspective);
      await tester.pump();
      expect(state.projectionType, ProjectionType.perspective);
      state.setProjectionType(ProjectionType.oblique);
      await tester.pump();
      expect(state.projectionType, ProjectionType.oblique);
    });

    testWidgets('resetView restores default camera', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));

      // Orbit away from the default.
      state.scene.setCamera(state.camera.orbit(deltaTheta: 2, deltaPhi: 0.3));
      await tester.pump();
      expect(state.camera.theta, isNot(closeTo(0, 0.01)));

      state.resetView();
      await tester.pump();
      expect(state.camera.theta, closeTo(piOver4, 0.01));
      expect(state.camera.distance, closeTo(12, 0.01));
    });

    testWidgets('setObjects adds objects and reports scene changes',
        (tester) async {
      var changes = 0;
      await tester.pumpWidget(_wrap(MathCanvas3D(
        onSceneChanged: () => changes++,
      )));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));

      state.setObjects([
        Object3D.point(const Point3D(1, 2, 3), name: 'A'),
      ]);
      await tester.pump();
      expect(state.objects.length, 1);
      expect(changes, greaterThan(0));
    });

    testWidgets('addObject / removeObject / setExpressionObjects',
        (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));

      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();
      expect(state.objects.length, 1);

      // Expression objects are replaced without touching construction ones.
      state.setExpressionObjects([
        Object3D.surface(
            MeshBuilder.fromFunction(
                xMin: -1,
                xMax: 1,
                yMin: -1,
                yMax: 1,
                gridX: 2,
                gridY: 2,
                f: (x, y) => 0),
            name: 'f'),
      ]);
      await tester.pump();
      expect(state.objects.length, 2);

      state.setExpressionObjects([]);
      await tester.pump();
      expect(state.objects.length, 1);

      state.removeObject(state.objects.first);
      await tester.pump();
      expect(state.objects.isEmpty, true);
    });

    testWidgets('setObjectVisible and setObjectStyle', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();

      state.setObjectVisible('A', false);
      await tester.pump();
      expect(state.objects.first.visible, false);

      state.setObjectStyle('A', const ObjectStyle(color: 0xFF123456));
      await tester.pump();
      expect(state.objects.first.style.color, 0xFF123456);
    });

    testWidgets('fitView adjusts the camera', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(5, 5, 5)));
      state.addObject(Object3D.point(const Point3D(-5, -5, -5)));
      await tester.pump();
      state.fitView();
      await tester.pump();
      expect(state.camera.target, const Point3D(0, 0, 0));
      expect(state.camera.distance, greaterThan(5));
    });

    testWidgets('auto-rotate toggles the animation controller', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.setAutoRotate(true);
      await tester.pump(const Duration(milliseconds: 100));
      final thetaAfter = state.camera.theta;
      state.setAutoRotate(false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(thetaAfter, isNot(closeTo(piOver4, 0.001)));
    });

    testWidgets('selectObject and keyboard movement', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();

      state.selectObject(state.objects.first);
      await tester.pump();
      expect(state.selected, isNotNull);

      // Simulate a right-arrow key down while the canvas has focus.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(state.objects.first.pointValue.x, greaterThan(0));
    });
  });

  group('Construction via gestures', () {
    testWidgets('point tool tap creates a point object', (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.point,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      // Tap the canvas center â†’ ground point at the origin.
      await tester.tap(find.byType(MathCanvas3D));
      await tester.pump();
      await tester.pump();

      expect(state.objects.length, 1);
      expect(state.objects.first.type, Object3DType.point);
      final p = state.objects.first.pointValue;
      expect(p.distanceTo(const Point3D(0, 0, 0)), lessThan(0.01));
    });

    testWidgets('line tool two taps creates a segment', (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.line,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      await tester.tapAt(const Offset(400, 300)); // origin
      await tester.pump();
      await tester.tapAt(const Offset(500, 300)); // +x
      await tester.pump();
      await tester.pump();

      expect(state.objects.length, 1);
      expect(state.objects.first.type, Object3DType.line);
      final line = state.objects.first;
      // First point near the origin; the vector points along the screen
      // +x direction, which in the default isometric view is (-1, 1, 0).
      expect(line.pointAValue.distanceTo(const Point3D(0, 0, 0)), lessThan(1));
      expect(line.vectorValue.magnitude, greaterThan(0.5));
      expect(line.vectorValue.x, lessThan(0));
      expect(line.vectorValue.y, greaterThan(0));
    });

    testWidgets('sphere tool creates a sphere', (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.sphereCenterPoint,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.tapAt(const Offset(500, 300));
      await tester.pump();
      await tester.pump();

      expect(state.objects.length, 1);
      expect(state.objects.first.type, Object3DType.sphere);
      expect(state.objects.first.sphereRadius, greaterThan(0));
    });

    testWidgets('construction continues for multiple objects', (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.point,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.tapAt(const Offset(440, 300));
      await tester.pump();
      await tester.pump();

      // The point tool stays active and creates two points.
      expect(state.objects.length, 2);
      expect(state.objects.every((o) => o.type == Object3DType.point), true);
    });

    testWidgets('switching to move tool clears construction', (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.point,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      expect(state.construction, isNotNull);
      state.setTool(ConstructionTool.move);
      await tester.pump();
      expect(state.construction, isNull);
      expect(state.activeTool, ConstructionTool.move);
    });

    testWidgets('tap on a point selects it in move mode', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();

      // Tap at the screen position of the origin.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump();

      expect(state.selected, isNotNull);
      expect(state.selected!.name, 'A');
    });

    testWidgets('dragging rotates the camera', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      final theta0 = state.camera.theta;
      final phi0 = state.camera.phi;

      await tester.drag(find.byType(MathCanvas3D), const Offset(80, 0));
      await tester.pump();

      expect(state.camera.theta, isNot(closeTo(theta0, 0.001)));
      expect(
          state.camera.phi, closeTo(phi0, 0.001)); // horizontal drag keeps phi
    });

    testWidgets('dragging vertically changes phi', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      final phi0 = state.camera.phi;

      await tester.drag(find.byType(MathCanvas3D), const Offset(0, 60));
      await tester.pump();

      expect(state.camera.phi, isNot(closeTo(phi0, 0.001)));
    });

    testWidgets('painter handles empty scene without crash', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('midpoint tool: clicking a segment creates the midpoint',
        (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.midpoint,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      // A segment along the screen-horizontal direction through the origin.
      state.addObject(Object3D.segment(
          const Point3D(-2, 0, 0), const Point3D(2, 0, 0),
          name: 's'));
      await tester.pump();

      // Click the projected midpoint of the segment (its midpoint is at the
      // origin, which projects to the canvas center).
      final proj = state.scene.projection;
      final s = proj.project(const Point3D(0, 0, 0))!;
      await tester.tapAt(Offset(s.x, s.y));
      await tester.pump();
      await tester.pump();

      expect(state.objects.length, 2);
      final created = state.objects.last;
      expect(created.type, Object3DType.point);
      expect(
          created.pointValue.distanceTo(const Point3D(0, 0, 0)), lessThan(1));
    });

    testWidgets('area tool: clicking a polygon measures its area',
        (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.area,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.polygon(const [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ], name: 'poly'));
      await tester.pump();

      // Click the projected anchor of the polygon (inside the face).
      final proj = state.scene.projection;
      final s = proj.project(const Point3D(1, 1, 0))!;
      await tester.tapAt(Offset(s.x, s.y));
      await tester.pump();
      await tester.pump();

      expect(state.objects.length, 2);
      final created = state.objects.last;
      expect(created.type, Object3DType.measurement);
      expect(created.measureText, contains('4'));
    });

    testWidgets('area tool: clicking exactly on a polygon vertex also works',
        (tester) async {
      await tester.pumpWidget(_wrap(MathCanvas3D(
        initialTool: ConstructionTool.area,
      )));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.polygon(const [
        Point3D(0, 0, 0),
        Point3D(2, 0, 0),
        Point3D(2, 2, 0),
        Point3D(0, 2, 0),
      ], name: 'poly'));
      await tester.pump();

      // Click exactly on vertex (0,0,0) â€” floating-point sign noise at the
      // barycentric boundary must not reject the hit (regression for the
      // CI-only failure where libm produced u = -1e-16).
      final proj = state.scene.projection;
      final s = proj.project(const Point3D(0, 0, 0))!;
      await tester.tapAt(Offset(s.x, s.y));
      await tester.pump();
      await tester.pump();

      expect(state.objects.length, 2);
      expect(state.objects.last.type, Object3DType.measurement);
    });

    testWidgets('dragging a selected point does not drift', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();

      // Drag the point to the right (screen +x = world (-1,1,0) direction).
      await tester.dragFrom(const Offset(400, 300), const Offset(50, 0));
      await tester.pump();

      final moved = state.objects.first;
      // Screen +50px at default camera â‰ˆ 0.75 world units along (-1,1,0).
      expect(moved.pointValue.x, lessThan(-0.3));
      expect(moved.pointValue.y, greaterThan(0.3));
      expect(moved.pointValue.z, closeTo(0, 1e-9));

      // Drag back toward the start: the point should return near the origin
      // (no cumulative drift).
      await tester.dragFrom(const Offset(450, 300), const Offset(-50, 0));
      await tester.pump();
      final back = state.objects.first;
      expect(back.pointValue.distanceTo(const Point3D(0, 0, 0)), lessThan(0.3));
    });

    testWidgets('dragging keeps the object selected', (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();

      // First tap selects the point.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump();
      expect(state.selected, isNotNull);

      // Dragging the selected point moves it AND keeps it selected.
      await tester.dragFrom(const Offset(400, 300), const Offset(60, 0));
      await tester.pump();
      expect(state.selected, isNotNull);
      expect(state.objects.first.pointValue.x, isNot(closeTo(0, 0.01)));
    });

    testWidgets('first tap does not toggle z-mode; second tap does',
        (tester) async {
      await tester.pumpWidget(_wrap(const MathCanvas3D()));
      await tester.pump();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      state.addObject(Object3D.point(const Point3D(0, 0, 0), name: 'A'));
      await tester.pump();

      // First tap selects the point.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      await tester.pump();
      expect(state.selected, isNotNull);

      // Drag horizontally in xOy mode: x/y move, z stays 0.
      await tester.dragFrom(const Offset(400, 300), const Offset(40, 0));
      await tester.pump();
      final afterFirst = state.objects.first.pointValue;
      expect(afterFirst.z, closeTo(0, 1e-9));
      expect(afterFirst.x.abs() + afterFirst.y.abs(), greaterThan(0.1));

      // Second tap on the (moved) point toggles the z-drag mode.
      final pos = state.objects.first.pointValue;
      final s = state.scene.projection.project(pos)!;
      await tester.tapAt(Offset(s.x, s.y));
      await tester.pump();
      await tester.pump();

      // Vertical drag now changes z.
      await tester.dragFrom(Offset(s.x, s.y), const Offset(0, -60));
      await tester.pump();
      final afterSecond = state.objects.first.pointValue;
      expect(afterSecond.z, greaterThan(0.05));
    });
  });
}

const piOver4 = 0.7853981633974483;
