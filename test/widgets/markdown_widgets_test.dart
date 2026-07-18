// Merged from:
//   - markdown_extensions_test.dart
//   - markdown_table_scroll_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/code_block_source_widget.dart';
import 'package:stroom/widgets/html_code_block_widget.dart';
import 'package:stroom/widgets/markdown_extensions.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

/// Helper: creates a [m.Document] with the [LatexSyntax] registered and
/// parses [text], returning the root nodes so tests can inspect the AST.
List<m.Node> _parseWithLatex(String text) {
  final doc = m.Document(
    inlineSyntaxes: [LatexSyntax()],
  );
  return doc.parseLines(text.split('\n'));
}

/// Recursively searches the AST for an [m.Element] whose tag matches [tag].
/// Returns the first match or null.
m.Element? _findElement(List<m.Node> nodes, String tag) {
  for (final node in nodes) {
    if (node is m.Element && node.tag == tag) {
      return node;
    }
    if (node is m.Element) {
      final found = _findElement(node.children ?? [], tag);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  // ===========================================================================
  // 1. markdown_extensions_test.dart
  // ===========================================================================
  group('LatexSyntax - inline math \$...\$', () {
    test('parses simple inline math', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'The formula $E = mc^2$ is famous.';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 1);
      expect(matches[0].group(0), r'$E = mc^2$');
    });

    test('parses inline math with complex content', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'$\alpha + \beta = \gamma$';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 1);
      expect(matches[0].group(0), r'$\alpha + \beta = \gamma$');
    });

    test('parses multiple inline math expressions', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'$a^2$ and $b^2$ are squares.';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 2);
      expect(matches[0].group(0), r'$a^2$');
      expect(matches[1].group(0), r'$b^2$');
    });

    test('does not match standalone dollar sign', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'This is 5$ for the item.';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 0);
    });

    test('parses inline math with special characters', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'$x_{n+1} = \frac{1}{2}$';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 1);
      expect(matches[0].group(0), r'$x_{n+1} = \frac{1}{2}$');
    });

    test('AST contains inline math element after parsing', () {
      final nodes = _parseWithLatex(r'Inline $x^2$ math.');
      final latexEl = _findElement(nodes, 'latex');
      expect(latexEl, isNotNull);
      expect(latexEl!.attributes['content'], 'x^2');
      expect(latexEl.attributes['isInline'], 'true');
    });
  });

  group('LatexSyntax - block math \$\$...\$\$', () {
    test('parses simple block math', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'Here is a formula: $$\int_0^\infty e^{-x} dx$$';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 1);
      expect(matches[0].group(0), r'$$\int_0^\infty e^{-x} dx$$');
    });

    test('parses block math with complex content', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 1);
      expect(matches[0].group(0), r'$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$');
    });

    test('parses multiple block math expressions', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'$$\int f(x) dx$$ and $$\sum a_n$$';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 2);
    });

    test('distinguishes inline and block math', () {
      final regex = RegExp(LatexSyntax.latexPattern);
      final input = r'Inline $x^2$ and block $$\sum_{i=1}^n i$$';
      final matches = regex.allMatches(input).toList();
      expect(matches.length, 2);
      expect(matches[0].group(0), r'$x^2$');
      expect(matches[1].group(0), r'$$\sum_{i=1}^n i$$');
    });

    test('AST contains block math element with isInline=false', () {
      final nodes = _parseWithLatex(r'Block $$\int dx$$ here.');
      final latexEl = _findElement(nodes, 'latex');
      expect(latexEl, isNotNull);
      expect(latexEl!.attributes['content'], r'\int dx');
      expect(latexEl.attributes['isInline'], 'false');
    });
  });

  group('LatexSyntax - edge cases', () {
    test('empty block math (\$\$ alone) does not create math element', () {
      final nodes = _parseWithLatex(r'Empty block math $$.');
      final latexEl = _findElement(nodes, 'latex');
      expect(latexEl, isNull);
    });

    test('empty inline math (\$ alone) does not create math element', () {
      final nodes = _parseWithLatex(r'Empty inline math $.');
      final latexEl = _findElement(nodes, 'latex');
      expect(latexEl, isNull);
    });

    test('multiple math expressions in a single paragraph', () {
      final nodes = _parseWithLatex(r'$a^2$ plus $b^2$ equals $c^2$');
      final latexElements = <m.Element>[];
      void findLatex(List<m.Node> nodes) {
        for (final node in nodes) {
          if (node is m.Element && node.tag == 'latex') {
            latexElements.add(node);
          }
          if (node is m.Element) {
            findLatex(node.children ?? []);
          }
        }
      }

      findLatex(nodes);
      expect(latexElements.length, 3);
      expect(latexElements[0].attributes['content'], 'a^2');
      expect(latexElements[1].attributes['content'], 'b^2');
      expect(latexElements[2].attributes['content'], 'c^2');
    });
  });

  group('LatexNode', () {
    testWidgets('build returns WidgetSpan for inline math',
        (WidgetTester tester) async {
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': r'E = mc^2', 'isInline': 'true'},
        r'$E = mc^2$',
        config,
      );
      node.style = const TextStyle(fontSize: 16);

      final span = node.build();
      expect(span, isA<WidgetSpan>());
      final widgetSpan = span as WidgetSpan;
      expect(widgetSpan.alignment, PlaceholderAlignment.middle);
    });

    testWidgets('empty content falls back to text',
        (WidgetTester tester) async {
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': '', 'isInline': 'true'},
        r'$$',
        config,
      );

      final span = node.build();
      expect(span, isA<TextSpan>());
      final textSpan = span as TextSpan;
      expect(textSpan.text, r'$$');
    });

    testWidgets('block mode returns WidgetSpan', (WidgetTester tester) async {
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': r'\int dx', 'isInline': 'false'},
        r'$$\int dx$$',
        config,
      );
      node.style = const TextStyle(fontSize: 16);

      final span = node.build();
      expect(span, isA<WidgetSpan>());
    });
  });

  group('MarkdownConfig helpers', () {
    test('markdownGenerator is a MarkdownGenerator with LaTeX support', () {
      expect(markdownGenerator, isA<MarkdownGenerator>());
      expect(markdownGenerator.inlineSyntaxList.length, greaterThan(0));
      expect(markdownGenerator.generators.length, greaterThan(0));
    });

    test('codeBlockPreConfig returns config with draculaTheme', () {
      final lightPre = codeBlockPreConfig(isDark: false);
      expect(lightPre.theme, isNotNull);

      final darkPre = codeBlockPreConfig(isDark: true);
      expect(darkPre.theme, isNotNull);
    });

    test('buildMarkdownConfig works in light mode', () {
      final config = buildMarkdownConfig(isDark: false);
      expect(config, isA<MarkdownConfig>());
    });

    test('buildMarkdownConfig works in dark mode', () {
      final config = buildMarkdownConfig(isDark: true);
      expect(config, isA<MarkdownConfig>());
    });

    test('buildMarkdownConfig overrides h1 config with no divider', () {
      final config = buildMarkdownConfig(isDark: false);
      final h1 = config.h1;
      expect(h1, isA<HeadingConfig>());
      expect(h1.divider, isNull, reason: 'h1 should have no divider line');
    });

    test('buildMarkdownConfig overrides h2 config with no divider', () {
      final config = buildMarkdownConfig(isDark: false);
      final h2 = config.h2;
      expect(h2, isA<HeadingConfig>());
      expect(h2.divider, isNull, reason: 'h2 should have no divider line');
    });

    test('buildMarkdownConfig overrides h3 config with no divider', () {
      final config = buildMarkdownConfig(isDark: false);
      final h3 = config.h3;
      expect(h3, isA<HeadingConfig>());
      expect(h3.divider, isNull, reason: 'h3 should have no divider line');
    });

    test('buildMarkdownConfig keeps h4,h5,h6 without divider (same as before)',
        () {
      final config = buildMarkdownConfig(isDark: false);
      expect(config.h4.divider, isNull);
      expect(config.h5.divider, isNull);
      expect(config.h6.divider, isNull);
    });

    test('buildMarkdownConfig dark mode also removes h1/h2/h3 dividers', () {
      final config = buildMarkdownConfig(isDark: true);
      expect(config.h1.divider, isNull);
      expect(config.h2.divider, isNull);
      expect(config.h3.divider, isNull);
      expect(config.h4.divider, isNull);
      expect(config.h5.divider, isNull);
      expect(config.h6.divider, isNull);
    });
  });

  group('Mermaid code block builder', () {
    test('PreConfig.builder is set after adding mermaid support', () {
      final pre = codeBlockPreConfig(isDark: false);
      expect(pre.builder, isNotNull,
          reason:
              'codeBlockPreConfig should have a builder for mermaid detection');
    });

    test('returns MermaidRenderWidget for mermaid language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('graph TD\nA-->B', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>());
      final mermaidWidget = widget as MermaidRenderWidget;
      expect(mermaidWidget.mermaidCode, 'graph TD\nA-->B');
    });

    test('returns CodeBlockSourceView for non-mermaid/non-html language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('print("hello")', 'python');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('returns CodeBlockSourceView for empty language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('some code', '');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('returns CodeBlockSourceView for unknown language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('some code', 'unknown_language_xyz');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('mermaid builder works in dark mode too', () {
      final pre = codeBlockPreConfig(isDark: true);
      final builder = pre.builder!;
      final widget = builder('graph TD', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>());
    });
  });

  group('HTML code block builder', () {
    test('returns HtmlCodeBlockWidget for html language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('<h1>Hello</h1>', 'html');
      expect(widget, isA<HtmlCodeBlockWidget>());
      final htmlWidget = widget as HtmlCodeBlockWidget;
      expect(htmlWidget.htmlCode, '<h1>Hello</h1>');
    });

    test('returns CodeBlockSourceView for non-html languages (python)', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('print("hello")', 'python');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('returns CodeBlockSourceView for non-html languages (dart)', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('void main() {}', 'dart');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('returns CodeBlockSourceView for empty language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('<h1>test</h1>', '');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('returns CodeBlockSourceView for unknown language', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final widget = builder('<h1>test</h1>', 'unknown_language_xyz');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('html builder works in dark mode too', () {
      final pre = codeBlockPreConfig(isDark: true);
      final builder = pre.builder!;
      final widget = builder('<button>Click</button>', 'html');
      expect(widget, isA<HtmlCodeBlockWidget>());
      final htmlWidget = widget as HtmlCodeBlockWidget;
      expect(htmlWidget.htmlCode, '<button>Click</button>');
    });

    test('mermaid still works when HTML support is added', () {
      final pre = codeBlockPreConfig(isDark: false);
      final builder = pre.builder!;
      final mermaidWidget = builder('graph TD', 'mermaid');
      expect(mermaidWidget, isA<MermaidRenderWidget>());
    });

    test('buildMarkdownConfig accepts isStreaming parameter', () {
      final config = buildMarkdownConfig(isDark: false, isStreaming: false);
      expect(config, isA<MarkdownConfig>());
    });

    test('buildMarkdownConfig defaults isStreaming to false', () {
      final config = buildMarkdownConfig(isDark: false);
      expect(config, isA<MarkdownConfig>());
    });

    test('codeBlockPreConfig accepts isStreaming parameter', () {
      final pre = codeBlockPreConfig(isDark: false, isStreaming: false);
      expect(pre.builder, isNotNull);
    });

    test('preConfig builder returns MermaidRenderWidget when not streaming',
        () {
      final pre = codeBlockPreConfig(isDark: false, isStreaming: false);
      final builder = pre.builder!;
      final widget = builder('graph TD\nA-->B', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>());
    });

    test('preConfig builder returns CodeBlockSourceView when streaming mermaid',
        () {
      final pre = codeBlockPreConfig(isDark: false, isStreaming: true);
      final builder = pre.builder!;
      final widget = builder('graph TD\nA-->B', 'mermaid');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('preConfig builder still renders non-mermaid code during streaming',
        () {
      final pre = codeBlockPreConfig(isDark: false, isStreaming: true);
      final builder = pre.builder!;
      final widget = builder('print("hello")', 'python');
      expect(widget, isA<CodeBlockSourceView>());
    });

    test('preConfig builder still renders html code during streaming', () {
      final pre = codeBlockPreConfig(isDark: false, isStreaming: true);
      final builder = pre.builder!;
      final widget = builder('<h1>Hello</h1>', 'html');
      expect(widget, isA<HtmlCodeBlockWidget>());
    });
  });

  // ===========================================================================
  // 2. markdown_table_scroll_test.dart
  // ===========================================================================
  group('TableConfig - horizontal drag scroll wrapper', () {
    test('buildMarkdownConfig includes TableConfig with a wrapper', () {
      final config = buildMarkdownConfig(isDark: false);
      final tableConfig = config.table;
      expect(tableConfig, isA<TableConfig>());
      expect(tableConfig.wrapper, isNotNull,
          reason:
              'TableConfig.wrapper should be set to enable horizontal scrolling');
    });

    test('buildMarkdownConfig wrapper is a WidgetWrapper (function)', () {
      final config = buildMarkdownConfig(isDark: false);
      final wrapper = config.table.wrapper;
      expect(wrapper, isA<Widget Function(Widget child)>());
    });

    test('buildMarkdownConfig dark mode also includes table wrapper', () {
      final config = buildMarkdownConfig(isDark: true);
      expect(config.table.wrapper, isNotNull,
          reason:
              'Dark mode config should also have table wrapper for consistency');
    });

    test(
        'wrapper wraps child in a SingleChildScrollView with horizontal scroll',
        () {
      final config = buildMarkdownConfig(isDark: false);
      final wrapper = config.table.wrapper!;

      const testChild = SizedBox(width: 800, height: 100);
      final wrapped = wrapper(testChild);

      expect(wrapped, isA<SingleChildScrollView>(), reason: 'outermost widget');

      final scrollView = wrapped as SingleChildScrollView;
      expect(scrollView.scrollDirection, Axis.horizontal,
          reason: 'scroll direction should be horizontal');
    });

    test('wrapper clips child with Clip.hardEdge to prevent overflow', () {
      final config = buildMarkdownConfig(isDark: false);
      final wrapper = config.table.wrapper!;

      const testChild = SizedBox(width: 800, height: 100);
      final wrapped = wrapper(testChild);

      final scrollView = wrapped as SingleChildScrollView;
      expect(scrollView.clipBehavior, Clip.hardEdge,
          reason: 'should clip to prevent overflow beyond bubble');
    });
  });
}
