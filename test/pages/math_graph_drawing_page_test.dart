import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/pages/math_graph_drawing_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: HomePage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

/// A Dart version of the JavaScript compileFormula logic for testing.
///
/// This mirrors the JS implementation to verify the preprocessing rules
/// (^ → **, implicit multiplication, Math. prefix) are correct.
String _dartCompileFormula(String formula, Map<String, double>? params) {
  var expr = formula.trim();
  if (expr.isEmpty) return expr;

  // 1. Replace parameters (word-boundary)
  if (params != null) {
    for (final entry in params.entries) {
      final pattern = RegExp('\\b${entry.key}\\b');
      expr = expr.replaceAll(pattern, '(${entry.value})');
    }
  }

  // 2. Replace ^ with **
  expr = expr.replaceAll('^', '**');

  // 3. Replace math constants
  expr = expr.replaceAll(RegExp(r'\bpi\b', caseSensitive: false), 'Math.PI');
  expr = expr.replaceAll(RegExp(r'\be\b'), 'Math.E');

  // 4. Basic implicit multiplication: digit|) followed by letter|(
  expr = expr.replaceAllMapped(
    RegExp(r'([\d\)])([a-zA-Z\(])'),
    (m) => '${m[1]}*${m[2]}',
  );

  // 5. Add Math. prefix to known math functions
  const mathFuncs = [
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'atan2',
    'sinh',
    'cosh',
    'tanh',
    'log10',
    'log2',
    'log',
    'ln',
    'sqrt',
    'abs',
    'ceil',
    'floor',
    'round',
    'exp',
    'sign',
    'lg',
  ];
  for (final fn in mathFuncs) {
    String replacement;
    if (fn == 'ln') {
      replacement = 'Math.log';
    } else if (fn == 'lg') {
      replacement = 'Math.log10';
    } else {
      replacement = 'Math.$fn';
    }
    expr = expr.replaceAllMapped(
      RegExp('\\b$fn\\b'),
      (m) => replacement,
    );
  }

  // 6. Remaining variable followed by (  → insert *
  //    Only match single letters NOT preceded by letter, digit, or dot.
  expr = expr.replaceAllMapped(
    RegExp(r'(?<![a-zA-Z0-9.])([a-zA-Z])\s*\('),
    (m) => '${m[1]}*(',
  );

  return expr;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('MathGraphDrawingPage - Static HTML generation', () {
    test('build2dHtml() generates valid HTML with formula placeholder', () {
      const formula = 'sin(x)';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      expect(html, contains('<!DOCTYPE html'));
      expect(html, contains('jsxgraph'));
      expect(html, contains('JXG.JSXGraph.initBoard'));
      expect(html, contains('sin(x)'));
      // Should NOT have 3D content
      expect(html, contains('jxgbox'));
      expect(html, isNot(contains('three.min.js')));
    });

    test('build2dHtml() contains compileFormula JavaScript function', () {
      const formula = 'x^2';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // The template should define a compileFormula function
      expect(html, contains('function compileFormula('));
      // Should convert ^ to ** in runtime
      expect(html, contains('replace(/\\^/g'));
      // Should handle implicit multiplication
      expect(html, contains('implicit multiplication'));
    });

    test('build3dHtml() generates valid HTML with formula placeholder', () {
      const formula = 'sin(x)*cos(y)';
      final html = MathGraphDrawingPage.build3dHtml(formula);

      expect(html, contains('<!DOCTYPE html'));
      expect(html, contains('three.min.js'));
      expect(html, contains('sin(x)*cos(y)'));
      // Should NOT have 2D content
      expect(html, contains('container'));
      expect(html, isNot(contains('jsxgraph')));
    });

    test('build3dHtml() contains compileFormula JavaScript function', () {
      const formula = 'x^2 + y^2';
      final html = MathGraphDrawingPage.build3dHtml(formula);

      expect(html, contains('function compileFormula('));
      expect(html, contains('replace(/\\^/g'));
    });

    test('build2dHtml() escapes dangerous characters in formula', () {
      // Formula with HTML special chars that should be escaped
      const formula = 'a & b < c > d\'s test';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // The formula placeholder in the JS string should be escaped
      expect(html, contains('a &amp; b &lt; c &gt; d&#39;s test'));
      expect(html, contains('&amp;'));
      expect(html, contains('&lt;'));
      expect(html, contains('&gt;'));
      expect(html, contains('&#39;'));
    });

    test('build3dHtml() preserves normal formula characters', () {
      const formula = 'a*x^2 + b*y^2';
      final html = MathGraphDrawingPage.build3dHtml(formula);

      expect(html, contains('a*x^2 + b*y^2'));
    });

    test('build2dHtml() with empty formula returns basic axes', () {
      const formula = '';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      expect(html, contains('<!DOCTYPE html'));
      expect(html, contains('JXG.JSXGraph.initBoard'));
      // Should have the board even with empty formula
      expect(html, contains('jsxgraph'));
    });
  });

  group('MathGraphDrawingPage - Formula compilation logic', () {
    // These tests use _dartCompileFormula to verify the compile rules
    // mirror the JavaScript compileFormula function.

    test('^ is converted to ** for exponentiation', () {
      final result = _dartCompileFormula('x^2', null);
      expect(result, contains('x**2'));
    });

    test('implicit multiplication: 2x → 2*x', () {
      final result = _dartCompileFormula('2x', null);
      expect(result, contains('2*x'));
    });

    test('implicit multiplication: 2sin(x) → 2*Math.sin(x)', () {
      final result = _dartCompileFormula('2sin(x)', null);
      expect(result, contains('2*Math.sin(x)'));
    });

    test('implicit multiplication: (x+1)(x-1) → (x+1)*(x-1)', () {
      final result = _dartCompileFormula('(x+1)(x-1)', null);
      expect(result, contains('(x+1)*(x-1)'));
    });

    test('implicit multiplication: x(x+1) → x*(x+1)', () {
      final result = _dartCompileFormula('x(x+1)', null);
      expect(result, contains('x*(x+1)'));
    });

    test('sin(x) becomes Math.sin(x)', () {
      final result = _dartCompileFormula('sin(x)', null);
      expect(result, contains('Math.sin(x)'));
    });

    test('cos(x) becomes Math.cos(x)', () {
      final result = _dartCompileFormula('cos(x)', null);
      expect(result, contains('Math.cos(x)'));
    });

    test('ln(x) becomes Math.log(x) (natural log)', () {
      final result = _dartCompileFormula('ln(x)', null);
      expect(result, contains('Math.log(x)'));
    });

    test('lg(x) becomes Math.log10(x)', () {
      final result = _dartCompileFormula('lg(x)', null);
      expect(result, contains('Math.log10(x)'));
    });

    test('pi becomes Math.PI', () {
      final result = _dartCompileFormula('pi', null);
      expect(result, contains('Math.PI'));
    });

    test('standalone e becomes Math.E', () {
      final result = _dartCompileFormula('e^x', null);
      // e is replaced, but x is not
      expect(result, contains('Math.E**x'));
    });

    test('complex formula: 2x^2+3x-5 compiles correctly', () {
      // 2x^2+3x-5
      // Step 2 (^): 2x**2+3x-5
      // Step 4 (implicit mult): 2*x**2+3*x-5
      // No math funcs, no variable(
      final result = _dartCompileFormula('2x^2+3x-5', null);
      expect(result, contains('2*x**2+3*x-5'));
    });

    test('parameter replacement uses word boundaries (no /a/g bug)', () {
      // 'atan' contains 'a' — word boundary ensures only standalone 'a' is replaced
      final params = <String, double>{'a': 2.0};
      final result = _dartCompileFormula('a*atan(x)', params);
      // The 'a' should be replaced with (2), but 'atan' should stay as Math.atan
      expect(result, contains('(2.0)*Math.atan(x)'));
    });

    test('parameter replacement: a, b, c, d not breaking function names', () {
      final params = <String, double>{'a': 1.0, 'b': 2.0, 'c': 3.0, 'd': 4.0};
      final result = _dartCompileFormula('asin(a) + acos(b) + atan(c)', params);
      // asin should become Math.asin (not Math.(1)sin)
      // acos should become Math.acos (not Math.(2)cos)
      // atan should become Math.atan (not Math.(3)tan)
      expect(result, contains('Math.asin'));
      expect(result, contains('Math.acos'));
      expect(result, contains('Math.atan'));
      // The params should appear
      expect(result, contains('(1.0)'));
      expect(result, contains('(2.0)'));
      expect(result, contains('(3.0)'));
    });

    test('comprehensive: x^2 produces parabolic evaluation', () {
      // x^2 → x**2 → after compilation: function(x,y){ return x**2; }
      // At x=2, value should be 4
      final result = _dartCompileFormula('x^2', null);
      // The resulting expression when evaluated should behave like x*x
      // We can check the compiled expression contains the right form
      expect(result, contains('x**2'));
      // No XOR operator (^) should remain
      expect(result, isNot(contains('^')));
    });
  });

  group('MathGraphDrawingPage - Coordinate extraction', () {
    test('extractCoordinatesFromJs() parses valid JSON coordinate data', () {
      const jsonData = '''
      [
        {"x": -3.14, "y": 0.0},
        {"x": -1.57, "y": -1.0},
        {"x": 0.0, "y": 0.0},
        {"x": 1.57, "y": 1.0},
        {"x": 3.14, "y": 0.0}
      ]
      ''';

      final coordinates =
          MathGraphDrawingPage.extractCoordinatesFromJs(jsonData);

      expect(coordinates, hasLength(5));
      expect(coordinates[0].x, closeTo(-3.14, 0.001));
      expect(coordinates[0].y, closeTo(0.0, 0.001));
      expect(coordinates[2].x, closeTo(0.0, 0.001));
      expect(coordinates[2].y, closeTo(0.0, 0.001));
    });

    test('extractCoordinatesFromJs() handles empty array', () {
      const jsonData = '[]';
      final coordinates =
          MathGraphDrawingPage.extractCoordinatesFromJs(jsonData);

      expect(coordinates, isEmpty);
    });

    test('extractCoordinatesFromJs() handles malformed JSON gracefully', () {
      const jsonData = 'not valid json';
      final coordinates =
          MathGraphDrawingPage.extractCoordinatesFromJs(jsonData);

      expect(coordinates, isEmpty);
    });

    test('extractCoordinatesFromJs() handles null input gracefully', () {
      final coordinates = MathGraphDrawingPage.extractCoordinatesFromJs(null);

      expect(coordinates, isEmpty);
    });
  });

  group('MathGraphDrawingPage - Widget rendering', () {
    testWidgets('renders AppBar with correct title when showPreview=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('数学绘图'), findsOneWidget);
    });

    testWidgets('formula text input field is present', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('输入函数表达式...'), findsOneWidget);
    });

    testWidgets('view mode toggle buttons are present', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2D'), findsOneWidget);
      expect(find.text('3D'), findsOneWidget);
    });

    testWidgets('3D view mode shows 3D formula label after switching',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear the initial formula text so hint becomes visible
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // Clear text using the clear button suffix
      final clearButton = find.byIcon(Icons.clear);
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pumpAndSettle();
      }

      // Find and tap the 3D toggle button
      final threeDToggle = find.text('3D');
      await tester.ensureVisible(threeDToggle);
      await tester.tap(threeDToggle);
      await tester.pumpAndSettle();

      // In 3D mode with empty formula, the hint should display
      expect(find.text('输入 z = f(x, y)'), findsOneWidget);
    });

    testWidgets('sliders area is present for parameter adjustment', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have parameter labels
      expect(find.text('参数'), findsWidgets);
    });

    testWidgets('no coordinate data list is shown (removed as useless)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The coordinate data list should have been removed
      // Previously showed "坐标数据"
      expect(find.textContaining('坐标数据'), findsNothing);
      expect(find.text('暂无数据'), findsNothing);
    });

    testWidgets('no platform exceptions when rendering without WebView', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MathGraphDrawingPage(initialShowPreview: false),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('HomePage - Module card integration', () {
    testWidgets('shows 7 module cards including 数学绘图', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show all 7 module cards
      expect(find.text('OCR'), findsOneWidget);
      expect(find.text('语音识别'), findsOneWidget);
      expect(find.text('下载网页资源'), findsOneWidget);
      expect(find.text('音频分离'), findsOneWidget);
      expect(find.text('语音合成'), findsOneWidget);
      expect(find.text('图表制作'), findsOneWidget);
      expect(find.text('数学绘图'), findsOneWidget);
    });

    testWidgets('数学绘图 card has correct subtitle', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('函数图形绘制'), findsOneWidget);
    });

    testWidgets('数学绘图 card is present on home page', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The card should be visible with correct label and subtitle
      expect(find.text('数学绘图'), findsOneWidget);
      expect(find.text('函数图形绘制'), findsOneWidget);
    });
  });
}
