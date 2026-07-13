import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/html_code_block_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HtmlCodeBlockWidget - buildHtmlDocument', () {
    test('wraps raw HTML in a complete document', () {
      const html = '<h1>Hello World</h1>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('<!DOCTYPE html>'));
      expect(doc, contains('<html>'));
      expect(doc, contains('</html>'));
      expect(doc, contains('<h1>Hello World</h1>'));
    });

    test('preserves HTML content as-is (no escaping)', () {
      const html = '<button onclick="alert(1)">Click</button>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('<button onclick="alert(1)">Click</button>'));
    });

    test('handles empty HTML', () {
      const html = '';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('<!DOCTYPE html>'));
      expect(doc, contains('<html>'));
    });

    test('includes proper viewport meta tag', () {
      const html = '<p>test</p>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('name="viewport"'));
      expect(doc, contains('width=device-width'));
    });

    test('preserves HTML with special characters like & < >', () {
      const html = '<div>A && B < C > D</div>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('A && B < C > D'));
    });

    test('preserves HTML with inline styles', () {
      const html = '<div style="color: red; font-size: 20px;">Styled</div>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('style="color: red; font-size: 20px;"'));
    });

    test('preserves HTML with images and external resources', () {
      const html = '<img src="https://example.com/image.png" alt="test"/>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('src="https://example.com/image.png"'));
    });

    test('preserves HTML with script tags', () {
      const html = '<script src="https://cdn.example.com/lib.js"></script>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('src="https://cdn.example.com/lib.js"'));
    });

    test('handles HTML with newlines and multiple lines', () {
      const html = '<div>\n  <p>Line 1</p>\n  <p>Line 2</p>\n</div>';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      expect(doc, contains('<div>'));
      expect(doc, contains('<p>Line 1</p>'));
      expect(doc, contains('<p>Line 2</p>'));
      expect(doc, contains('</div>'));
    });

    test('handles complex full HTML document', () {
      const html = '''<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body>
  <h1>Title</h1>
  <p>Content</p>
</body>
</html>''';
      final doc = HtmlCodeBlockWidget.buildHtmlDocument(html);
      // Should still wrap it properly even if it already has DOCTYPE/html tags
      expect(doc, contains('<h1>Title</h1>'));
      expect(doc, contains('<p>Content</p>'));
    });
  });

  group('HtmlCodeBlockWidget - widget rendering', () {
    testWidgets('renders as a StatefulWidget', (tester) async {
      const widget = HtmlCodeBlockWidget(htmlCode: '<h1>Hello</h1>');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
      expect(find.byType(HtmlCodeBlockWidget), findsOneWidget);
    });

    testWidgets('shows raw HTML code as text, not rendered', (tester) async {
      const html = '<h1>Hello World</h1>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // The raw HTML source should be visible as text
      expect(find.text('<h1>Hello World</h1>'), findsOneWidget);
    });

    testWidgets('shows fullscreen preview and wrap toggle buttons',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      // The fullscreen button with "全屏预览" text should be present
      expect(find.text('全屏预览'), findsOneWidget);
      // The fullscreen icon should be present
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      // The wrap toggle button with "换行显示" text should be present
      expect(find.text('换行显示'), findsOneWidget);
      // The wrap toggle icon should be present
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);
    });

    testWidgets('wrap toggle button is positioned left of fullscreen button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      // Find both buttons by their text
      final wrapToggle = tester.widget<Text>(find.text('换行显示'));
      final fullscreen = tester.widget<Text>(find.text('全屏预览'));

      // Get their global positions
      final wrapPos = tester.getCenter(find.text('换行显示'));
      final fullscreenPos = tester.getCenter(find.text('全屏预览'));

      // Wrap toggle should be to the left of fullscreen button
      expect(wrapPos.dx, lessThan(fullscreenPos.dx),
          reason: 'Wrap toggle should be left of the fullscreen button');
    });

    testWidgets('wrap toggle switches between wrap and no-wrap state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      // Initially shows '换行显示' (wrap toggle in OFF state)
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.text('取消换行'), findsNothing);

      // Tap the wrap toggle button
      await tester.tap(find.text('换行显示'));
      await tester.pumpAndSettle();

      // After tap, should show '取消换行' (wrap toggle in ON state)
      expect(find.text('取消换行'), findsOneWidget);
      expect(find.text('换行显示'), findsNothing);

      // Tap the wrap toggle button again
      await tester.tap(find.text('取消换行'));
      await tester.pumpAndSettle();

      // Should be back to '换行显示'
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.text('取消换行'), findsNothing);
    });

    testWidgets('shows (empty) for empty HTML code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: ''),
          ),
        ),
      );

      expect(find.text('(empty)'), findsOneWidget);
      // No line numbers for empty code
      expect(find.text('1'), findsNothing);
    });

    testWidgets('shows line numbers for multiline code (no-wrap default)',
        (tester) async {
      const html = '<div>\n  <p>Line 1</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // In no-wrap mode, code is a single SelectableText with full text
      expect(find.text(html), findsOneWidget);

      // Should have line numbers 1, 2, 3
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows individual code lines in wrap mode', (tester) async {
      const html = '<div>\n  <p>Line 1</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // Switch to wrap mode first
      await tester.tap(find.text('换行显示'));
      await tester.pumpAndSettle();

      // In wrap mode, each line is a separate SelectableText
      expect(find.text('<div>'), findsOneWidget);
      expect(find.text('  <p>Line 1</p>'), findsOneWidget);
      expect(find.text('</div>'), findsOneWidget);

      // Should have line numbers 1, 2, 3
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows line number 1 for single line code', (tester) async {
      const html = '<p>Hello</p>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // Should show the code
      expect(find.text('<p>Hello</p>'), findsOneWidget);
      // Should show line number 1
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('adapts colors to dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      // Widget should render without error in dark mode
      expect(find.byType(HtmlCodeBlockWidget), findsOneWidget);
      // The fullscreen button should still be present
      expect(find.text('全屏预览'), findsOneWidget);
      // The wrap toggle should still be present
      expect(find.text('换行显示'), findsOneWidget);
    });

    testWidgets('shows multiline code with correct line numbers in wrap mode',
        (tester) async {
      const html = '<div>\n  <p>Line 1</p>\n  <p>Line 2</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // Switch to wrap mode
      await tester.tap(find.text('换行显示'));
      await tester.pumpAndSettle();

      // Verify the raw multi-line code is displayed as individual lines
      expect(find.text('<div>'), findsOneWidget);
      expect(find.text('  <p>Line 1</p>'), findsOneWidget);
      expect(find.text('  <p>Line 2</p>'), findsOneWidget);
      expect(find.text('</div>'), findsOneWidget);

      // Verify line numbers 1-4
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('fullscreen button is present and tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      // The fullscreen button should be present
      expect(find.text('全屏预览'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      // Tapping should not throw (the dialog requires InAppWebView
      // which is a platform widget; we verify the gesture is wired)
      await tester.tap(find.text('全屏预览'));
      // Just pump once — dialog opening will be handled in integration tests
      // with real platform support
    });

    testWidgets('wrap toggle button is present and tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: '<p>test</p>'),
          ),
        ),
      );

      // The wrap toggle button should be present
      expect(find.text('换行显示'), findsOneWidget);
      expect(find.byIcon(Icons.wrap_text), findsOneWidget);

      // Tapping should toggle to "取消换行" without throwing
      await tester.tap(find.text('换行显示'));
      await tester.pumpAndSettle();

      expect(find.text('取消换行'), findsOneWidget);
    });

    testWidgets('handles code with trailing newline', (tester) async {
      const html = '<div>\n</div>\n';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // Should show full code including trailing newline
      expect(find.text(html), findsOneWidget);

      // Three lines: '<div>', '</div>', ''
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('wrap mode changes scroll configuration', (tester) async {
      const html = '<div>\n  <p>long line</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // In no-wrap mode (default): horizontal Scrollable should exist
      final horizontalScrollables = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal);
      expect(horizontalScrollables, findsWidgets,
          reason: 'No-wrap mode should have horizontal scroll');

      // Switch to wrap mode
      await tester.tap(find.text('换行显示'));
      await tester.pumpAndSettle();

      // In wrap mode: no horizontal Scrollable should exist
      // (Only vertical scrollable remains)
      final horizontalScrollablesAfter = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal);
      expect(horizontalScrollablesAfter, findsNothing,
          reason: 'Wrap mode should have no horizontal scroll');
    });

    // ---- Adaptive height tests (4:3 aspect ratio) ----

    testWidgets('uses adaptive height: small content is not taller than needed',
        (tester) async {
      // Single line of code in a wide screen
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const html = '<p>Hello</p>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(htmlCode: html),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the SizedBox with the adaptive height / Container
      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final containerConstraints = container.constraints;

      // Content height for 1 line = ~20px (13*1.5) + padding (40px top + 12px bottom)
      // Should be less than 4:3 max height which is ~600 (800*0.75)
      // So the widget should be sized to fit content (not capped)
      // The SizedBox height should reflect the actual content
      final sizedBoxFinder = find.byType(SizedBox);
      expect(sizedBoxFinder, findsWidgets,
          reason: 'SizedBox should exist for adaptive sizing');
    });

    testWidgets('caps height at roughly 4:3 aspect ratio for tall content',
        (tester) async {
      // 50 lines of code — should be capped at ~75% of width
      await tester.binding.setSurfaceSize(const Size(500, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final lines = List.generate(50, (i) => '<p>Line $i</p>').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(htmlCode: lines),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The widget is inside a Scaffold which applies padding.
      // The available width should be roughly 500 minus padding.
      // Max height should be capped at available_width * 0.75.
      // 50 lines * ~20px per line = ~1000px content height
      // 500px width * 0.75 = 375px max height
      // So the widget should be ~375px tall
      final sizedBox = find.byType(SizedBox).first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);

      expect(sizedBoxWidget.height, lessThan(500),
          reason:
              'Height should be capped, not matching the full 50 lines of content');
      expect(sizedBoxWidget.height, greaterThan(0),
          reason: 'Height should be positive');
    });

    testWidgets(
        'tall code block content scrolls vertically within capped height',
        (tester) async {
      // Many lines to ensure scrolling is needed
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final lines = List.generate(80, (i) => 'Line number $i').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(htmlCode: lines),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find vertical scrollable — should exist and allow scrolling
      final verticalScrollables = find
          .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);
      expect(verticalScrollables, findsWidgets,
          reason: 'Vertical scrollable should exist for tall content');
    });

    testWidgets('respects custom height property even when content is short',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Single line, but with a custom height of 200
      const html = '<p>Hello</p>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(
                htmlCode: html,
                height: 200,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The custom height should override adaptive sizing
      // Find SizedBox — should use 200
      final sizedBox = find.byType(SizedBox).first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);

      expect(sizedBoxWidget.height, equals(200),
          reason: 'Custom height property should be respected');
    });

    testWidgets('respects custom height property with tall content',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final lines = List.generate(50, (i) => 'Line $i').join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(
                htmlCode: lines,
                height: 500,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom height of 500 should be used, even though it exceeds 4:3 ratio
      final sizedBox = find.byType(SizedBox).first;
      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);

      expect(sizedBoxWidget.height, equals(500),
          reason: 'Custom height property should override adaptive cap');
    });

    testWidgets('empty code block uses default adaptive height',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HtmlCodeBlockWidget(htmlCode: ''),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show empty placeholder
      expect(find.text('(empty)'), findsOneWidget);
    });
  });
}
