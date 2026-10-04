import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_tool.dart';
import 'package:stroom/widgets/math_3d_toolbar.dart';
import 'package:stroom/widgets/math_canvas_3d.dart';

void main() {
  testWidgets(
      'group selection creates a regular polygon and changing sides resets partial input',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var tool = ConstructionTool.point;
    var sides = 6;
    var instruction = '';
    final key = GlobalKey<MathCanvas3DState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, update) {
      return Column(children: [
        Math3DToolbar(
          activeTool: tool,
          instruction: instruction,
          polygonSides: sides,
          onPolygonSidesChanged: (value) => update(() => sides = value),
          onToolSelected: (value) => update(() => tool = value),
        ),
        Expanded(
            child: MathCanvas3D(
          key: key,
          currentTool: tool,
          onToolInstruction: (value) => update(() => instruction = value),
          polygonSides: sides,
          onObjectCreated: (object) => key.currentState!
              .setObjects([...key.currentState!.objects, object]),
        )),
      ]);
    }))));
    await tester.pump();
    await tester.tap(find.text('直线与多边形'));
    await tester.pumpAndSettle();
    final regularPolygonTool = find.text('正多边形');
    await tester.ensureVisible(regularPolygonTool);
    await tester.tap(regularPolygonTool);
    await tester.pumpAndSettle();
    final canvasRect = tester.getRect(find.byType(MathCanvas3D));
    final start = canvasRect.center;
    await tester.tapAt(start);
    await tester.pump();
    expect(key.currentState!.constructionState!.points, hasLength(1));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.pumpAndSettle();
    expect(key.currentState!.constructionState!.points, isEmpty);
    await tester.tapAt(start);
    await tester.pump();
    await tester.tapAt(start + const Offset(65, 0));
    await tester.pump();
    expect(key.currentState!.objects.single.vertices, hasLength(5));
    await tester.tap(find.byTooltip('结束工具，返回移动'));
    await tester.pumpAndSettle();
    expect(key.currentState!.activeTool, ConstructionTool.move);
    expect(tester.takeException(), isNull);
  });
}
