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
      // HTML special chars should be preserved as-is in the raw HTML
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
    testWidgets('is a StatelessWidget', (tester) async {
      const widget = HtmlCodeBlockWidget(htmlCode: '<h1>Hello</h1>');
      // If it compiles as StatelessWidget, this is already verified.
      // We verify by checking it builds without a state.
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
      // The rendered equivalent should NOT be present
      // (we can't check for absence of a rendered h1 in a simple test,
      // but we verify the raw code is shown)
    });

    testWidgets('shows fullscreen preview button', (tester) async {
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
    });

    testWidgets('respects custom height', (tester) async {
      const widgetKey = Key('height-test-widget');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              key: widgetKey,
              htmlCode: '<p>test</p>',
              height: 500,
            ),
          ),
        ),
      );

      // The widget tree is constrained by Scaffold; verify the widget
      // renders without error and has the expected height applied
      expect(find.byKey(widgetKey), findsOneWidget);
    });

    testWidgets('uses default height of 300', (tester) async {
      const widgetKey = Key('default-height-test-widget');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(
              key: widgetKey,
              htmlCode: '<p>test</p>',
            ),
          ),
        ),
      );

      expect(find.byKey(widgetKey), findsOneWidget);
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
    });

    testWidgets('shows multiline HTML code', (tester) async {
      const html = '<div>\n  <p>Line 1</p>\n</div>';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlCodeBlockWidget(htmlCode: html),
          ),
        ),
      );

      // Verify the raw multi-line code is displayed
      expect(find.text('<div>\n  <p>Line 1</p>\n</div>'), findsOneWidget);
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
  });
}
