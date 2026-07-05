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
}
