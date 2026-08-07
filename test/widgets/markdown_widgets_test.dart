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

  group('LatexNode - mhchem \\ce support', () {
    // Regression: $\ce{...}$ used to hit "Undefined control sequence: \ce"
    // in flutter_math_fork and fall back to the raw red text. The
    // preprocessor must make it render real math instead.

    testWidgets('renders \\ce{H2O} without the error fallback',
        (WidgetTester tester) async {
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': r'\ce{H2O}', 'isInline': 'true'},
        r'$\ce{H2O}$',
        config,
      );
      node.style = const TextStyle(fontSize: 16, color: Colors.black);

      final span = node.build() as WidgetSpan;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text.rich(TextSpan(children: [span])),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text(r'$\ce{H2O}$'), findsNothing,
          reason: 'the raw-text error fallback must not appear');
    });

    testWidgets('renders a reaction equation without the error fallback',
        (WidgetTester tester) async {
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': r'\ce{2H2 + O2 -> 2H2O}', 'isInline': 'false'},
        r'$$\ce{2H2 + O2 -> 2H2O}$$',
        config,
      );
      node.style = const TextStyle(fontSize: 16, color: Colors.black);

      final span = node.build() as WidgetSpan;
      final child = (span.child as Container).child!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text.rich(TextSpan(children: [WidgetSpan(child: child)])),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text(r'$$\ce{2H2 + O2 -> 2H2O}$$'), findsNothing,
          reason: 'the raw-text error fallback must not appear');
    });

    testWidgets('renders \\pu units without the error fallback',
        (WidgetTester tester) async {
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': r'\pu{123 kJ/mol}', 'isInline': 'true'},
        r'$\pu{123 kJ/mol}$',
        config,
      );
      node.style = const TextStyle(fontSize: 16, color: Colors.black);

      final span = node.build() as WidgetSpan;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text.rich(TextSpan(children: [span])),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text(r'$\pu{123 kJ/mol}$'), findsNothing);
    });

    testWidgets('malformed \\ce falls back to the raw error text, no crash',
        (WidgetTester tester) async {
      // The preprocessor promises malformed input cannot crash rendering:
      // it is passed through unchanged and the existing error fallback
      // (raw red text) takes over.
      final config = MarkdownConfig.defaultConfig;
      final node = LatexNode(
        {'content': r'\ce{H2O', 'isInline': 'true'},
        r'$\ce{H2O$',
        config,
      );
      node.style = const TextStyle(fontSize: 16, color: Colors.black);

      final span = node.build() as WidgetSpan;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text.rich(TextSpan(children: [span])),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text(r'$\ce{H2O$'), findsOneWidget,
          reason: 'malformed input must keep the legacy error fallback');
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

  group('buildMessageMarkdownConfig - per-message streaming', () {
    // Regression: when a new message starts streaming, previously rendered
    // mermaid diagrams in OLD messages must NOT show the "正在生成..."
    // loading placeholder and must NOT re-render. Only the message that is
    // currently being generated may use the streaming config.
    test('old messages use non-streaming config while conversation streams',
        () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'new-message-id',
        messageId: 'old-message-id',
      );
      final widget = config.pre.builder!('graph TD\nA-->B', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>(),
          reason: 'an old message must render mermaid normally, not show the '
              'streaming loading placeholder');
    });

    test('the message currently being generated uses the streaming config', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
      );
      final widget = config.pre.builder!('graph TD\nA-->B', 'mermaid');
      expect(widget, isNot(isA<MermaidRenderWidget>()));
      expect(widget, isNot(isA<CodeBlockSourceView>()));
    });

    test('conversation not streaming: mermaid renders normally', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: false,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
      );
      final widget = config.pre.builder!('graph TD\nA-->B', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>());
    });

    test('streamingMsgId is null: mermaid renders normally', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: null,
        messageId: 'any-message-id',
      );
      final widget = config.pre.builder!('graph TD\nA-->B', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>());
    });

    test('non-mermaid code renders normally with either config', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
      );
      final widget = config.pre.builder!('print("hi")', 'python');
      expect(widget, isA<CodeBlockSourceView>());
    });
  });

  group('unclosedFenceTail - fence completion detection', () {
    // Regression: while a message streams, the "正在生成..." placeholder
    // must only show while the mermaid code fence is STILL OPEN. A closed
    // fence (even when the stream continues after it) must render
    // immediately. The markdown parser swallows everything after an
    // unclosed fence into one code block; unclosedFenceTail returns that
    // swallowed tail so the builder can tell it apart from closed blocks.

    test('markdown parser swallows an unclosed fence into one code block', () {
      // Sanity check of the core assumption behind unclosedFenceTail:
      // the parser hands the builder the whole tail as ONE code block.
      // (encodeHtml: false matches markdown_widget's MarkdownGenerator.)
      final doc =
          m.Document(encodeHtml: false).parse('```mermaid\ngraph TD\nA-->B');
      final pre =
          doc.firstWhere((n) => n is m.Element && n.tag == 'pre') as m.Element;
      final code = (pre.children!.first as m.Element).textContent;
      expect(code.trim(), 'graph TD\nA-->B');
    });

    test('markdown parser keeps a closed fence separate from later text', () {
      final doc =
          m.Document(encodeHtml: false).parse('```mermaid\nA\n```\nmore text');
      final pre =
          doc.firstWhere((n) => n is m.Element && n.tag == 'pre') as m.Element;
      final code = pre.children!.first as m.Element;
      expect(code.tag, 'code');
      expect(code.textContent.trim(), 'A');
      // The text after the closed fence is NOT swallowed into the block.
      expect(doc.whereType<m.Element>().where((n) => n.tag == 'code').length,
          lessThan(2));
    });

    test('returns null when the last fence is closed', () {
      expect(unclosedFenceTail('```mermaid\ngraph TD\nA-->B\n```\nmore text'),
          isNull);
      expect(unclosedFenceTail('text without fences'), isNull);
      expect(unclosedFenceTail(''), isNull);
    });

    test('returns the tail when the last fence is still open', () {
      expect(
          unclosedFenceTail('```mermaid\ngraph TD\nA-->B'), 'graph TD\nA-->B');
      // No trailing newline yet (mid-stream).
      expect(unclosedFenceTail('```mermaid\ngraph TD\nA--'), 'graph TD\nA--');
      // Opening fence with nothing after it yet.
      expect(unclosedFenceTail('```mermaid'), '');
    });

    test('returns null when an open fence is closed by a later fence', () {
      expect(
          unclosedFenceTail('```mermaid\ngraph TD\n```\n```python\nx = 1\n```'),
          isNull);
    });

    test('multiple blocks: only a still-open LAST fence yields a tail', () {
      // First mermaid block closed, second still open → tail is the
      // second block's partial content only.
      expect(
          unclosedFenceTail('```mermaid\nA\n```\n\n```mermaid\nB\nC'), 'B\nC');
    });

    test('tilde fences are detected too', () {
      expect(unclosedFenceTail('~~~mermaid\ngraph TD'), 'graph TD');
      expect(unclosedFenceTail('~~~mermaid\nA\n~~~\ntext'), isNull);
    });

    test('a fence line with an info string does not close an open fence', () {
      // CommonMark: closing fences cannot carry an info string.
      expect(unclosedFenceTail('```mermaid\n```python'), isNotNull);
    });

    test('trailing blank lines are part of the tail (trim-insensitive)', () {
      expect(unclosedFenceTail('```mermaid\nA\n\n'), isNotNull);
      // The parser drops a trailing blank line (spec 127/128) and appends
      // a newline; the trim-insensitive equality must still match.
      expect(isStreamingMermaidTail('A', '```mermaid\nA\n\n'), isTrue);
    });

    test('CRLF line endings are normalized like the parser does', () {
      // markdown_widget splits on RegExp(r'(\r?\n)|(\r)'), so the parser's
      // code never contains \r; the tail must match it.
      expect(unclosedFenceTail('```mermaid\r\ngraph TD\r\nA-->B'),
          'graph TD\nA-->B');
      expect(
          isStreamingMermaidTail(
              'graph TD\nA-->B', '```mermaid\r\ngraph TD\r\nA-->B'),
          isTrue);
    });

    test('CommonMark allows 1-3 leading spaces on fences', () {
      expect(unclosedFenceTail(' ```mermaid\nA'), 'A');
      expect(unclosedFenceTail('   ```mermaid\nA'), 'A');
      // Indented closing fence closes too.
      expect(unclosedFenceTail('```mermaid\nA\n ```'), isNull);
      // 4 spaces is not a fence (indented code instead).
      expect(unclosedFenceTail('    ```mermaid\nA'), isNull);
    });

    test('a longer closing run closes the fence', () {
      expect(unclosedFenceTail('```mermaid\nA\n````'), isNull);
    });

    test('backticks inside a backtick fence info string do not open it', () {
      // CommonMark: backtick fences cannot contain backticks in info.
      expect(unclosedFenceTail('```foo`bar\nA'), isNull);
    });
  });

  group('buildMessageMarkdownConfig - fence-aware streaming placeholder', () {
    // Regression: during streaming only the mermaid block whose fence is
    // still OPEN shows "正在生成..."; blocks whose fence has closed render
    // immediately (and only once), even while the stream continues after
    // them — including messages with MULTIPLE mermaid blocks.
    test('open trailing mermaid block shows the streaming placeholder', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
        streamingText: '```mermaid\ngraph TD\nA-->B',
      );
      final widget = config.pre.builder!('graph TD\nA-->B', 'mermaid');
      expect(widget, isNot(isA<MermaidRenderWidget>()),
          reason: 'an open fence must keep showing the generating state');
    });

    test('closed mermaid block renders while the stream continues', () {
      // First block closed, second still open → first renders.
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
        streamingText: '```mermaid\nA\n```\n\n```mermaid\nB',
      );
      final widget = config.pre.builder!('A', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>(),
          reason: 'a closed fence must render immediately, even mid-stream');
    });

    test('all mermaid blocks render once every fence is closed', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
        streamingText: '```mermaid\nA\n```\n\n```mermaid\nB\n```',
      );
      expect(config.pre.builder!('A', 'mermaid'), isA<MermaidRenderWidget>());
      expect(config.pre.builder!('B', 'mermaid'), isA<MermaidRenderWidget>());
    });

    test('mermaid code identical to the tail of a CLOSED fence renders', () {
      // The tail comparison must only match the open fence's tail, not a
      // closed block whose content happens to appear at the end.
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
        streamingText: '```mermaid\nA\n```',
      );
      final widget = config.pre.builder!('A', 'mermaid');
      expect(widget, isA<MermaidRenderWidget>());
    });

    test('streamingText null keeps the legacy loading behavior', () {
      final config = buildMessageMarkdownConfig(
        isDark: false,
        conversationIsStreaming: true,
        streamingMsgId: 'current-message-id',
        messageId: 'current-message-id',
      );
      final widget = config.pre.builder!('A', 'mermaid');
      expect(widget, isNot(isA<MermaidRenderWidget>()));
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

    test(
        'preConfig builder returns loading widget (not CodeBlockSourceView) when streaming mermaid',
        () {
      final pre = codeBlockPreConfig(isDark: false, isStreaming: true);
      final builder = pre.builder!;
      final widget = builder('graph TD\nA-->B', 'mermaid');
      // During streaming, mermaid code blocks now show a loading widget
      // instead of CodeBlockSourceView or the full MermaidRenderWidget.
      expect(widget, isNot(isA<CodeBlockSourceView>()));
      expect(widget, isNot(isA<MermaidRenderWidget>()));
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
