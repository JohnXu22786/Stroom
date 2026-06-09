import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/markdown_extensions.dart';

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
      // The markdown parser wraps in a paragraph element.
      // The latex inline syntax creates an Element with tag 'latex'
      // inside a parent Element (typically a paragraph containing 'text' elements).
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
      expect(matches[0].group(0),
          r'$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$');
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
      final nodes = _parseWithLatex(
          r'$a^2$ plus $b^2$ equals $c^2$');
      // Find all latex elements
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

    testWidgets('empty content falls back to text', (WidgetTester tester) async {
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
  });
}
