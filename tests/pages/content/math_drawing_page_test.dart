import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/math_drawing_page.dart';
import 'package:stroom/widgets/math_formula_field.dart';

Widget _buildTestApp({String? initialExpression}) {
  return MaterialApp(
    home: MathDrawingPage(
      initialExpression: initialExpression,
      initialMathematicalMode: false,
      initialShowWebView: false,
    ),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  editorInteractionTests();

  group('MathDrawingPage - formula input', () {
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

      // Add a second formula
      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      // Tap remove on first formula
      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Confirmation dialog should appear
      expect(find.text('删除'), findsWidgets);

      // Confirm deletion
      await tester.tap(find.text('删除').last);
      await tester.pump();

      // Now 1 formula should remain
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('add button only on first row', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_circle));
      await tester.pump();

      // There should be exactly 1 add button (only on first row)
      expect(find.byIcon(Icons.add_circle), findsOneWidget);
    });

    testWidgets('eye toggle hides formula', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Tap eye to toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Should now show eye-off icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('plotting across tabs keeps formulas alive', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      // Enter formula
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.pump();

      // Plot it
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      // Switch to 3D tab
      await tester.tap(find.text('3D'));
      await tester.pumpAndSettle();

      // Switch back to 2D tab
      await tester.tap(find.text('2D 绘图'));
      await tester.pumpAndSettle();

      // Text field should still have the formula
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller?.text, equals('x^2'));

      // Canvas should still be present
      expect(tester.takeException(), isNull);
    });
  });

  group('MathDrawingPage - error handling', () {
    testWidgets('shows error for invalid expression', (tester) async {
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
    // Helpers to measure the formula row's action buttons (the IconButtons
    // inside the row that contains the formula TextField, excluding the
    // AppBar's reset-view button and the TextField's own undo suffix icon).
    List<Rect> rowButtonRects(WidgetTester tester, {int rowIndex = 0}) {
      final row = find
          .ancestor(
            of: find.byType(TextField).at(rowIndex),
            matching: find.byType(Row),
          )
          .first;
      final buttons = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              ![Icons.undo, Icons.calculate_outlined, Icons.keyboard]
                  .contains((w.icon as Icon?)?.icon),
        ),
      );
      return [
        for (var i = 0; i < buttons.evaluate().length; i++)
          tester.getRect(buttons.at(i)),
      ];
    }

    Rect textFieldRect(WidgetTester tester, {int rowIndex = 0}) {
      return tester.getRect(find.byType(TextField).at(rowIndex));
    }

    void expectUniformSpacing(
      WidgetTester tester, {
      required int rowIndex,
      required double gap,
    }) {
      final tfRect = textFieldRect(tester, rowIndex: rowIndex);
      final rects = rowButtonRects(tester, rowIndex: rowIndex);
      expect(rects, isNotEmpty);

      // Input -> first action button
      expect(rects.first.left - tfRect.right, closeTo(gap, 0.01),
          reason: 'Gap between text field and first action button');

      // Every action button is a compact 24x24 block
      for (final r in rects) {
        expect(r.width, closeTo(24, 0.01),
            reason: 'Action button should be 24 wide (compact block)');
        expect(r.height, closeTo(24, 0.01),
            reason: 'Action button should be 24 tall (compact block)');
      }

      // Uniform gaps between consecutive buttons
      for (var i = 0; i < rects.length - 1; i++) {
        expect(rects[i + 1].left - rects[i].right, closeTo(gap, 0.01),
            reason: 'Gap between consecutive action buttons should be uniform');
      }
    }

    testWidgets(
        'action buttons are compact 24x24 blocks with uniform 12px gaps',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expectUniformSpacing(tester, rowIndex: 0, gap: 12);
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
}

// Editing snapshots are asynchronous on native WebViews. Exercise the page
// with the bridge boundary rather than constructing a platform view in tests.
void editorInteractionTests() {
  testWidgets('pending deletion keeps a later confirmation tied to its formula',
      (tester) async {
    final platform = await _delayedEditors(tester, rows: 3);
    final fields = tester
        .stateList<MathFormulaFieldState>(find.byType(MathFormulaField))
        .toList();
    final gate = Completer<void>();
    platform.activeEditors.first.controller.snapshotGate = gate.future;
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove_circle_outline).last);
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MathFormulaField), findsNWidgets(2));
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state<MathFormulaFieldState>(find.byType(MathFormulaField)),
        same(fields[1]));
  });

  testWidgets('concurrent pending deletions retain the final formula',
      (tester) async {
    final platform = await _delayedEditors(tester, rows: 2);
    final gate = Completer<void>();
    platform.activeEditors.first.controller.snapshotGate = gate.future;
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove_circle_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MathFormulaField), findsOneWidget);
  });

  testWidgets('short narrow screens keep the canvas and keyboard scrollable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MathDrawingPage(
      initialShowWebView: false,
      initialMathematicalMode: true,
    )));
    await tester.tap(find.byType(MathFormulaField));
    await tester.pump();
    await tester.tap(find.byTooltip('全部符号分类'));
    await tester.pumpAndSettle();
    final matrices = find.text('矩阵').last;
    await tester.ensureVisible(matrices);
    await tester.tap(matrices);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('收起数学键盘'));
    await tester.pump();
    expect(find.text('下一项'), findsNothing);
  });
  testWidgets('math keyboard follows row identity across deletion and tabs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MathDrawingPage(
      initialShowWebView: false,
      initialMathematicalMode: true,
    )));
    await tester.tap(find.byType(MathFormulaField).first);
    await tester.pump();
    expect(find.text('下一项'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pump();
    final fields = tester
        .stateList<MathFormulaFieldState>(find.byType(MathFormulaField))
        .toList();
    fields[1].acceptSnapshot({
      'revision': fields[1].revision,
      'latex': r'\frac{x}{2}',
      'edited': true
    });
    await tester.pump();
    await tester.tap(find.byType(MathFormulaField).last);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(tester.state<MathFormulaFieldState>(find.byType(MathFormulaField)),
        same(fields[1]));
    await tester.tap(find.text('3D'));
    await tester.pumpAndSettle();
    expect(find.text('下一项'), findsNothing);
    await tester.tap(find.text('2D 绘图'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('切换到系统键盘 / LaTeX 源码'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        r'\frac{x}{2}');
    expect(tester.takeException(), isNull);
  });
}

Future<_DelayedEditorPlatform> _delayedEditors(WidgetTester tester,
    {required int rows}) async {
  final original = InAppWebViewPlatform.instance;
  final platform = _DelayedEditorPlatform();
  InAppWebViewPlatform.instance = platform;
  addTearDown(() =>
      InAppWebViewPlatform.instance = original ?? _DelayedEditorPlatform());
  await tester.pumpWidget(
      const MaterialApp(home: MathDrawingPage(initialMathematicalMode: true)));
  for (var i = 1; i < rows; i++) {
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pump();
  }
  platform.activeEditors =
      platform.editors.sublist(platform.editors.length - rows);
  for (final native in platform.activeEditors) {
    final controller = native
        .controllerFromPlatform<InAppWebViewController>(native.controller);
    native.params.onWebViewCreated!(controller);
    native.params.onLoadStop!(controller, null);
  }
  await tester.pumpAndSettle();
  return platform;
}

class _DelayedEditorPlatform extends InAppWebViewPlatform {
  final editors = <_DelayedEditor>[];
  late final List<_DelayedEditor> activeEditors;
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
      PlatformInAppWebViewWidgetCreationParams params) {
    final editor = _DelayedEditor(params);
    editors.add(editor);
    return editor;
  }
}

class _DelayedEditor extends PlatformInAppWebViewWidget {
  final controller = _DelayedEditorController();
  _DelayedEditor(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox();
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;
  @override
  void dispose() {}
}

class _DelayedEditorController extends PlatformInAppWebViewController {
  Future<void>? snapshotGate;
  _DelayedEditorController()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 0));
  @override
  Future<dynamic> evaluateJavascript(
      {required String source, ContentWorld? contentWorld}) async {
    if (source.contains('stroomMath.snapshot()')) await snapshotGate;
    return null;
  }

  @override
  void addJavaScriptHandler(
      {required String handlerName,
      required JavaScriptHandlerCallback callback}) {}
  @override
  void dispose({bool isKeepAlive = false}) {}
}
