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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('MathGraphDrawingPage - Static HTML generation', () {
    test('build2dHtml() includes math.js CDN and JSXGraph', () {
      const formula = 'sin(x)';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      expect(html, contains('<!DOCTYPE html'));
      expect(html, contains('jsxgraph'));
      expect(html, contains('JXG.JSXGraph.initBoard'));
      expect(html, contains('mathjs'));
      // Should NOT have 3D content
      expect(html, contains('jxgbox'));
      expect(html, isNot(contains('three.min.js')));
    });

    test('build2dHtml() uses math.evaluate instead of eval', () {
      const formula = '2x + 3';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // Should use math.evaluate for safe evaluation
      expect(html, contains('math.evaluate'));
      // Should NOT use direct eval
      expect(html, isNot(contains('return eval(compiled)')));
      expect(html, isNot(contains('return function(x) { return eval(')));
    });

    test('build2dHtml() includes x and a,b,c,d in math.evaluate scope', () {
      const formula = 'a*x^2 + b*x + c';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // Scope should include x and parameters
      expect(html, contains('x: x'));
      expect(html, contains('a: p.a'));
      expect(html, contains('b: p.b'));
      expect(html, contains('c: p.c'));
      expect(html, contains('d: p.d'));
    });

    test('build3dHtml() generates valid HTML with math.js', () {
      const formula = 'sin(x)*cos(y)';
      final html = MathGraphDrawingPage.build3dHtml(formula);

      expect(html, contains('<!DOCTYPE html'));
      expect(html, contains('three.min.js'));
      expect(html, contains('mathjs'));
      expect(html, contains('sin(x)*cos(y)'));
      // Should NOT have 2D content
      expect(html, contains('container'));
      expect(html, isNot(contains('jsxgraph')));
    });

    test('build3dHtml() uses math.evaluate with x,y and a,b,c,d in scope', () {
      const formula = 'a*x^2 + b*y^2';
      final html = MathGraphDrawingPage.build3dHtml(formula);

      expect(html, contains('math.evaluate'));
      expect(html, contains('x: x'));
      expect(html, contains('y: y'));
      expect(html, contains('a: p.a'));
      expect(html, contains('b: p.b'));
      expect(html, contains('c: p.c'));
      expect(html, contains('d: p.d'));
      // Should NOT use direct eval
      expect(html, isNot(contains('return function(x, y) { return eval(')));
    });

    test('build2dHtml() escapes dangerous characters in formula', () {
      // Formula with HTML special chars that should be escaped
      const formula = 'a & b < c > d\'s test';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // The formula placeholder in the JS string should be escaped
      expect(html, contains('a &amp; b &lt; c &gt; d&#39;s test'));
      // No raw dangerous chars should appear in the formula position
      // (the template JS code uses single quotes, but our formula text is escaped)
      expect(html, contains('&amp;'));
      expect(html, contains('&lt;'));
      expect(html, contains('&gt;'));
      expect(html, contains('&#39;'));
    });

    test('build3dHtml() preserves formula characters', () {
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

    test('build2dHtml() has smooth curve plotting resolution', () {
      const formula = 'x^2';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // Step should be 0.05 or smaller for smooth curves (was 0.5)
      expect(html, contains('x += 0.05'));
    });

    test('build2dHtml() uses getParams() for parameter substitution', () {
      const formula = '2x + 1';
      final html = MathGraphDrawingPage.build2dHtml(formula);

      // Parameters should be passed via scope, not string replacement
      // The old approach had .replace(/a/g, ...) which is gone now
      expect(html, isNot(contains('.replace(/a/g, ')));
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

    testWidgets('no coordinate data list is displayed by default', (
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

      // The old coordinate data table/chart icon should NOT be present
      expect(find.byIcon(Icons.table_chart), findsNothing);
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
