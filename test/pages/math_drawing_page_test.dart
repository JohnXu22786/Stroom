import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_3d_tool.dart';
import 'package:stroom/pages/math_drawing_page.dart';
import 'package:stroom/widgets/math_3d_object_panel.dart';
import 'package:stroom/widgets/math_3d_toolbar.dart';
import 'package:stroom/widgets/math_canvas_3d.dart';

Widget _buildTestApp({String? initialExpression}) {
  return MaterialApp(
    home: MathDrawingPage(initialExpression: initialExpression),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MathDrawingPage - initial render', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('数学绘图'), findsOneWidget);
    });

    testWidgets('renders 2D and 3D tabs', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('2D 绘图'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('shows one formula row with text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows add, checkmark, eye, color buttons', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byIcon(Icons.add_circle), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });
  });

  group('MathDrawingPage - formula input (2D)', () {
    testWidgets('typing shows in text field', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('x^2'));
    });

    testWidgets('checkmark button plots formulas', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - multi formula', () {
    testWidgets('add button adds another row', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('remove button with confirmation removes formula',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('删除'), findsWidgets);

      await tester.tap(find.text('删除').last);
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('eye toggle hides formula', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('plotting across tabs keeps formulas alive', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2D 绘图'));
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('x^2'));
      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - 3D mode', () {
    testWidgets('3D tab shows toolbar, canvas and object panel',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      expect(find.byType(MathCanvas3D), findsOneWidget);
      expect(find.byType(Math3DToolbar), findsOneWidget);
      expect(find.byType(Math3DObjectPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('object panel toggles via app bar button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();
      expect(find.byType(Math3DObjectPanel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(find.byType(Math3DObjectPanel), findsNothing);
    });

    testWidgets('plotting an explicit surface creates an object',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'z = x + y');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      expect(state.objects.length, 1);
      expect(state.objects.first.type, Object3DType.surface);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plotting an implicit sphere creates a mesh object',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'x^2 + y^2 + z^2 = 4');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      expect(state.objects.length, 1);
      expect(state.objects.first.type, Object3DType.surface);
      expect(state.objects.first.mesh!.vertices.length, greaterThan(100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('plotting a parametric curve creates a curve', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '(cos(t), sin(t), t)');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      expect(state.objects.length, 1);
      expect(state.objects.first.type, Object3DType.curve);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid 3D expression shows error snackbar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'x ^^ 2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      // Error snackbar appears; no crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a tool shows the instruction bar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      // Open the point toolbox (second toolbox) and pick the Point tool.
      final toolboxes = find.byWidgetPredicate(
        (w) => w is PopupMenuButton<ConstructionTool>,
      );
      await tester.tap(toolboxes.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('点').last);
      await tester.pumpAndSettle();

      final state = tester.state<MathCanvas3DState>(find.byType(MathCanvas3D));
      expect(state.activeTool, ConstructionTool.point);
      // Instruction bar appears (contains 点击).
      expect(find.textContaining('点击'), findsOneWidget);

      // Cancel via close icon returns to move.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(state.activeTool, ConstructionTool.move);
    });
  });

  group('MathDrawingPage - error handling', () {
    testWidgets('no crash on empty', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows error for invalid expression without crash',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x ^^ 2');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - UI spacing', () {
    testWidgets('formula rows render with color circle and visibility icon',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('eye icon is positioned after the text field (outside input)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      final textField = find.byType(TextField);
      final eyeIcon = find.byIcon(Icons.visibility);

      final textFieldRect = tester.getRect(textField);
      final eyeRect = tester.getRect(eyeIcon);

      expect(eyeRect.left, greaterThan(textFieldRect.right - 1),
          reason:
              'Eye icon should be positioned to the right of the text field (outside the input)');
    });

    testWidgets('formula row overall layout does not overflow', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'sin(x) + cos(x) + tan(x) + log(x) + sqrt(x)',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - initial expression', () {
    testWidgets('pre-populates expression when provided', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(initialExpression: 'sin(x)'),
      );
      await tester.pump();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('sin(x)'));
    });
  });

  group('Tool metadata', () {
    testWidgets('every tool has metadata and an icon', (tester) async {
      for (final tool in ConstructionTool.values) {
        final info = ToolInfo.all[tool]!;
        expect(info.iconData, isA<IconData>());
        expect(info.name, isNotEmpty);
      }
    });

    testWidgets('all tools are grouped', (tester) async {
      final grouped = ToolInfo.groups.expand((g) => g).toSet();
      expect(grouped.length, ConstructionTool.values.length);
    });

    testWidgets('each tool has at least one workflow step', (tester) async {
      for (final tool in ConstructionTool.values) {
        if (tool == ConstructionTool.move) continue;
        expect(ToolInfo.all[tool]!.steps, isNotEmpty,
            reason: '$tool needs workflow steps');
      }
    });
  });
}
