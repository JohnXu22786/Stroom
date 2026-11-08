import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_3d_scene.dart';
import 'package:stroom/widgets/math_canvas_3d.dart';

void main() {
  Future<MathCanvas3DState> setup(WidgetTester tester) async {
    final key = GlobalKey<MathCanvas3DState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MathCanvas3D(
          key: key,
          currentTool: ConstructionTool.point,
          onObjectCreated: (object) {
            key.currentState!
                .setObjects([...key.currentState!.objects, object]);
          },
        ),
      ),
    ));
    await tester.pump();
    return key.currentState!;
  }

  Offset screen(MathCanvas3DState state, Point3D point) {
    final projected = worldToScreen(
      point,
      state.camera,
      state.projectionType == ProjectionType.parallel
          ? Projection3D.parallel(
              width: 800, height: 600, scale: state.camera.distance * 0.6)
          : Projection3D.perspective(width: 800, height: 600, fov: 60),
    );
    return Offset(projected.x, projected.y);
  }

  testWidgets('free point starts on z=0 even over an elevated surface',
      (tester) async {
    final state = await setup(tester);
    state.setObjects([const Object3D.plane(c: 1, d: 2)]);
    await tester.pump();
    await tester.tapAt(const Offset(340, 330));
    await tester.pump();
    expect(state.objects.last.point.z, 0);
    expect(state.selectedPoint, same(state.objects.last));
    expect(state.pointDragMode, PointDragMode.height);
  });

  testWidgets('visible points beyond the parallel camera remain editable',
      (tester) async {
    final state = await setup(tester);
    state.setObjects([const Object3D.point(Point3D(0, 0, 12))]);
    await tester.pump();
    await tester.tap(find.byTooltip('3D 视图设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('俯视 xOy'));
    await tester.pumpAndSettle();
    final initial = state.objects.single.point;
    await tester.tapAt(screen(state, initial));
    await tester.pump();
    expect(state.objects, hasLength(1));
    expect(state.selectedPoint, isNotNull);
    await tester.dragFrom(screen(state, initial), const Offset(0, -40));
    await tester.pump();
    final moved = state.objects.single.point;
    expect(moved.z, initial.z);
    expect(moved.distanceTo(initial), greaterThan(0.1));
    await tester.tapAt(screen(state, moved));
    await tester.pump();
    await tester.dragFrom(screen(state, moved), const Offset(0, -40));
    await tester.pump();
    expect(state.objects.single.point.z, greaterThan(initial.z));
  });

  testWidgets('height dragging works at close and shallow perspective depths',
      (tester) async {
    final state = await setup(tester);
    state.setProjectionType(ProjectionType.perspective);
    while (state.camera.distance > 0.25) {
      state.zoomIn();
    }
    final forward = (state.camera.target - state.camera.position).normalized();
    for (final depth in [0.25, 0.02]) {
      final initial = state.camera.position + forward * depth;
      state.setObjects([Object3D.point(initial)]);
      await tester.pump();
      await tester.tapAt(screen(state, initial));
      await tester.pump();
      await tester.tapAt(screen(state, initial));
      await tester.pump();
      expect(state.pointDragMode, PointDragMode.height);
      await tester.dragFrom(screen(state, initial), const Offset(0, -40));
      await tester.pump();
      final raised = state.objects.single.point;
      expect(raised.z, greaterThan(initial.z), reason: 'depth=$depth');
      expect(raised.x, initial.x);
      expect(raised.y, initial.y);
      await tester.dragFrom(screen(state, raised), const Offset(0, 80));
      await tester.pump();
      expect(state.objects.single.point.z, lessThan(raised.z));
    }
  });

  for (final projection in ProjectionType.values) {
    testWidgets('point toggles height and current plane in $projection',
        (tester) async {
      final state = await setup(tester);
      state.setProjectionType(projection);
      await tester.pump();
      await tester.tapAt(const Offset(340, 330));
      await tester.pump();
      final initial = state.objects.single.point;
      final camera = state.camera;
      await tester.dragFrom(screen(state, initial), const Offset(18, -60));
      await tester.pump();
      final raised = state.objects.single.point;
      expect(raised.x, closeTo(initial.x, 1e-8));
      expect(raised.y, closeTo(initial.y, 1e-8));
      expect(raised.z, greaterThan(0));
      expect(state.camera.theta, camera.theta);
      expect(state.pointDragMode, PointDragMode.height);

      await tester.tapAt(screen(state, raised));
      await tester.pump();
      expect(state.pointDragMode, PointDragMode.plane);
      await tester.dragFrom(screen(state, raised), const Offset(70, 20));
      await tester.pump();
      final moved = state.objects.single.point;
      expect(moved.z, closeTo(raised.z, 1e-8));
      expect(moved.distanceTo(raised), greaterThan(0.1));
      expect(state.objects, hasLength(1));
    });
  }

  testWidgets('deselected point can be selected and dragged with a mouse',
      (tester) async {
    final state = await setup(tester);
    state.setTool(ConstructionTool.move);
    state.setObjects([const Object3D.point(Point3D(1, 1, 2), label: 'A')]);
    await tester.pump();
    await tester.tapAt(screen(state, state.objects.single.point));
    await tester.pump();
    expect(state.selectedPoint?.label, 'A');
    await tester.tapAt(screen(state, state.objects.single.point));
    await tester.pump();
    final start = state.objects.single.point;
    final pointer = await tester.startGesture(screen(state, start),
        kind: PointerDeviceKind.mouse);
    await pointer.moveBy(const Offset(0, -70));
    await pointer.up();
    await tester.pump();
    expect(state.objects.single.point.z, greaterThan(start.z));
    expect(state.objects.single.point.x, start.x);
    expect(state.objects.single.point.y, start.y);
    await tester.tapAt(const Offset(100, 500));
    await tester.pump();
    expect(state.selectedPoint, isNull);
    await tester.tapAt(screen(state, state.objects.single.point));
    await tester.pump();
    expect(state.selectedPoint, isNotNull);
  });

  testWidgets(
      'floating controls do not create points and created labels are unique',
      (tester) async {
    final state = await setup(tester);
    await tester.tapAt(const Offset(340, 330));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('point-drag-mode')));
    await tester.pump();
    expect(state.pointDragMode, PointDragMode.plane);
    expect(state.objects, hasLength(1));
    await tester.tap(find.byTooltip('放大'));
    await tester.pump();
    expect(state.objects, hasLength(1));
    await tester.tapAt(const Offset(230, 410));
    await tester.pump();
    expect(state.objects, hasLength(2));
    expect(state.objects.map((object) => object.label).toSet(), hasLength(2));
  });

  testWidgets('cancelling a point drag restores it without creating objects',
      (tester) async {
    final state = await setup(tester);
    await tester.tapAt(const Offset(340, 330));
    await tester.pump();
    final initial = state.objects.single;
    final pointer = await tester.startGesture(screen(state, initial.point));
    await pointer.moveBy(const Offset(0, -80));
    await tester.pump();
    await pointer.cancel();
    await tester.pump();
    expect(state.objects, [initial]);
  });

  testWidgets('two fingers navigate without moving or creating a point',
      (tester) async {
    final state = await setup(tester);
    await tester.tapAt(const Offset(340, 330));
    await tester.pump();
    final initial = state.objects.single;
    final position = screen(state, initial.point);
    final first = await tester.startGesture(position, pointer: 1);
    final second =
        await tester.startGesture(position + const Offset(80, 0), pointer: 2);
    await first.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(30, 0));
    await first.up();
    await second.up();
    await tester.pump();
    expect(state.objects, [initial]);
    expect(state.camera.distance, lessThan(10));
  });
}
