import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MermaidRenderWidget - buildMermaidHtml', () {
    test('replaces MERMAID_CODE_PLACEHOLDER with escaped code', () {
      final code = 'graph TD\nA-->B';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('graph TD'));
      // '-->' gets HTML-escaped to '--&gt;'
      expect(html, contains('A--&gt;B'));
      expect(html, isNot(contains('MERMAID_CODE_PLACEHOLDER')));
    });

    test('escapes HTML special characters in code', () {
      final code = '<test> & "quote"';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      // The escaped code should be in the HTML
      expect(html, contains('&lt;test&gt;'));
      expect(html, contains('&amp;'));
    });

    test('includes mermaid.js script reference', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid@11'));
      expect(html, contains('mermaid.min.js'));
    });

    test('includes mermaid.initialize call', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.initialize'));
    });

    test('uses mermaid.run() for v11 API compatibility', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.run'));
    });

    test('includes CSS to prevent SVG overflow', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      // Should have CSS rules to constrain mermaid SVG output
      expect(html, contains('.mermaid svg'));
      expect(html, contains('max-width'));
    });

    test('handles empty code', () {
      final html = MermaidRenderWidget.buildMermaidHtml('');
      expect(html, isNot(contains('MERMAID_CODE_PLACEHOLDER')));
    });

    test('handles code with newlines and special chars', () {
      final code = 'sequenceDiagram\nAlice->>Bob: Hello\nBob-->>Alice: Hi';
      final html = MermaidRenderWidget.buildMermaidHtml(code);
      expect(html, contains('sequenceDiagram'));
      expect(html, contains('Alice-&gt;&gt;Bob'));
      expect(html, contains('Bob--&gt;&gt;Alice'));
    });

    test('HTML uses loose securityLevel for mermaid', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains("securityLevel: 'loose'"));
    });

    test('HTML includes error container for rendering failures', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('error-message'));
    });
  });
}
