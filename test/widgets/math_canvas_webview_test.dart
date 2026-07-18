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

    test('includes JSXGraph core script', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('jsxgraphcore.js'));
    });

    test('includes JSXGraph CSS', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('jsxgraph.css'));
    });

    test('includes board initialization with axes and grid', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('axis'));
      expect(html, contains('grid'));
    });

    test('includes Flutter JavaScript channel bridge', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('flutter_inappwebview'));
    });

    test('includes setExpression handler', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('setExpression'));
    });

    test('includes updateParameters handler', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('updateParameters'));
    });

    test('includes resetView handler', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('resetView'));
    });

    test('includes coordinate data sending mechanism', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('coordinateUpdate'));
    });

    test('includes viewport change reporting', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('viewportChange'));
    });

    test('has error handling for invalid expressions', () {
      final html = MathCanvasWebView.buildMathHtml('invalid');
      expect(html, contains('error'));
    });

    test('transparent background is configured', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('transparent'));
    });

    test('no navigation or copyright in the board settings', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('showNavigation: false'));
      expect(html, contains('showCopyright: false'));
    });

    test('board has reasonable default bounding box', () {
      final html = MathCanvasWebView.buildMathHtml('x^2');
      expect(html, contains('-10'));
      expect(html, contains('10'));
    });

    test('handles empty expression gracefully', () {
      final html = MathCanvasWebView.buildMathHtml('');
      expect(html, contains('jsxgraphcore.js'));
    });

    test('creates unique board ID', () {
      final html1 = MathCanvasWebView.buildMathHtml('x^2');
      final html2 = MathCanvasWebView.buildMathHtml('x^2');
      expect(html1, isNot(equals(html2)));
    });
  });
}
