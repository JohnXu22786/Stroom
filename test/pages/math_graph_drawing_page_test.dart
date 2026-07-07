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
