import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/math_canvas_webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MathCanvasWebView - buildMathHtml', () {
    test('replaces EXPRESSION_PLACEHOLDER with JS expression', () {
      final html = MathCanvasWebView.buildMathHtml('Math.pow(x,2)');
      expect(html, contains('Math.pow(x,2)'));
      expect(html, isNot(contains('EXPRESSION_PLACEHOLDER')));
    });

    test('creates unique board ID', () {
      final html1 = MathCanvasWebView.buildMathHtml('x^2');
      final html2 = MathCanvasWebView.buildMathHtml('x^2');
      expect(html1, isNot(equals(html2)));
    });

    test(
        'keeps long error details reachable and accessible in a short viewport',
        () {
      final html = MathCanvasWebView.buildMathHtml('x^2');

      expect(html, contains('max-height: 50%'));
      expect(html, contains('overflow-y: auto'));
      expect(html, contains('-webkit-overflow-scrolling: touch'));
      expect(html, contains('white-space: pre-wrap'));
      expect(html, contains('overflow-wrap: anywhere'));
      expect(html, contains('id="error-message" role="alert" tabindex="0"'));
    });
  });
}
