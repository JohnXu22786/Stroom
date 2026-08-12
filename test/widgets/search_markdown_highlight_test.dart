// Tests for the search-highlighting markdown generator used by chat search.
//
// Regression coverage:
// - Searching must NOT flatten the markdown into plain text — it must keep
//   the markdown rendering and only highlight the matching occurrences.
// - The "current" (orange) highlight must follow the global navigation
//   cursor across messages and across text segments of one message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:stroom/widgets/markdown_extensions.dart';

/// Recursively collects every [TextSpan] (including nested children) from
/// [span].
List<TextSpan> _collectSpans(InlineSpan span) {
  final result = <TextSpan>[];
  if (span is TextSpan) {
    result.add(span);
    for (final child in span.children ?? const <InlineSpan>[]) {
      result.addAll(_collectSpans(child));
    }
  }
  return result;
}

/// Builds [markdown] with [gen] and returns every text span of the resulting
/// widgets, so tests can inspect both the rendered plain text and the
/// highlight styles.
List<TextSpan> _spansOf(MarkdownGenerator gen, String markdown) {
  final widgets = gen.buildWidgets(
    markdown,
    config: MarkdownConfig.defaultConfig,
  );
  final spans = <TextSpan>[];
  for (final widget in widgets) {
    final padded = widget as Padding;
    final textWidget = padded.child as Text;
    spans.addAll(_collectSpans(textWidget.textSpan as TextSpan));
  }
  return spans;
}

String _plainText(List<TextSpan> spans) =>
    spans.map((s) => s.text ?? '').join();

/// Recursively reports whether [span] contains a [WidgetSpan] (math,
/// code blocks, images, ...).
bool _containsWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) return true;
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (_containsWidgetSpan(child)) return true;
    }
  }
  return false;
}

void main() {
  group('countOccurrences', () {
    test('counts case-insensitive, non-overlapping occurrences', () {
      expect(countOccurrences('Foo foo FOo', 'foo'), 3);
      expect(countOccurrences('aaaa', 'aa'), 2);
      expect(countOccurrences('hello world', 'world'), 1);
    });

    test('returns zero for empty query or no match', () {
      expect(countOccurrences('hello', ''), 0);
      expect(countOccurrences('hello', 'x'), 0);
      expect(countOccurrences('', 'x'), 0);
    });
  });

  group('stripSearchIrrelevantMarkdown', () {
    test('removes fenced code block content but keeps the line structure', () {
      final stripped = stripSearchIrrelevantMarkdown(
        '```\nterm\n```\nprose term',
      );
      expect(countOccurrences(stripped, 'term'), 1,
          reason: 'the match inside the code fence must not be counted');
      expect(stripped, isNot(contains('term\n```')));
    });

    test('removes tilde fences, inline code and display math', () {
      final stripped = stripSearchIrrelevantMarkdown(
        'a `code term` b\n~~~\nterm\n~~~\nc \$\$term\$\$ d',
      );
      expect(countOccurrences(stripped, 'term'), 0);
      expect(stripped, contains('a  b'));
      expect(stripped, contains('c  d'));
    });

    test('removes double-backtick spans containing inner backticks', () {
      // ``sudo`` is a single code span to the renderer (content "sudo");
      // the whole span must be stripped, not just the two backtick pairs.
      final stripped = stripSearchIrrelevantMarkdown('Use ``sudo rm`` term');
      expect(countOccurrences(stripped, 'sudo'), 0,
          reason: 'double-backtick span content must not be counted');
      expect(countOccurrences(stripped, 'term'), 1);
    });

    test('removes fences inside blockquotes', () {
      final stripped = stripSearchIrrelevantMarkdown(
        '> ~~~\n> term\n> ~~~\nterm in prose',
      );
      expect(countOccurrences(stripped, 'term'), 1,
          reason: 'the match inside the blockquote code fence must not be '
              'counted');
    });

    test('keeps prose around ragged backtick runs', () {
      // The renderer treats these backtick runs as literal text (a code
      // span cannot start right after a backtick), so the prose between
      // them must survive stripping.
      final stripped = stripSearchIrrelevantMarkdown('a ````` x ```` b');
      expect(countOccurrences(stripped, 'x'), 1,
          reason: 'ragged backtick runs are literal text, not code spans');
    });

    test('does not strip code spans across a paragraph boundary', () {
      // Inline parsing happens per paragraph; an unmatched backtick in one
      // paragraph must not pair with one in another paragraph.
      final stripped = stripSearchIrrelevantMarkdown(
        'para with `open backtick\n\npara two with closing` backtick',
      );
      expect(countOccurrences(stripped, 'open backtick'), 1);
      expect(countOccurrences(stripped, 'closing'), 1);
    });

    test('keeps unmatched backticks (rendered as literal text)', () {
      final stripped = stripSearchIrrelevantMarkdown('she said `term');
      expect(countOccurrences(stripped, 'term'), 1);
    });

    test('drops the tail of an unclosed trailing fence', () {
      final stripped = stripSearchIrrelevantMarkdown('```\nterm');
      expect(countOccurrences(stripped, 'term'), 0);
    });
  });

  group('buildSearchMarkdownGenerator', () {
    test('keeps the markdown structure and highlights every occurrence', () {
      final gen = buildSearchMarkdownGenerator(
        query: 'term',
        messageFirstMatchIndex: 0,
        occurrenceOffset: 0,
        currentMatchIndex: 0,
      );
      final spans = _spansOf(gen, '**bold** term and *em* term');
      // Markdown must still be parsed: no raw asterisks in the output.
      expect(_plainText(spans), 'bold term and em term');
      expect(_plainText(spans), isNot(contains('*')));

      final highlights = spans.where(
        (s) =>
            s.style?.backgroundColor == Colors.yellow ||
            s.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(highlights.length, 2);
    });

    test('marks the occurrence matching the cursor as the current one', () {
      final gen = buildSearchMarkdownGenerator(
        query: 'term',
        messageFirstMatchIndex: 0,
        occurrenceOffset: 0,
        currentMatchIndex: 1,
      );
      final spans = _spansOf(gen, 'term one term two term three');
      final highlights = spans
          .where(
            (s) =>
                s.style?.backgroundColor == Colors.yellow ||
                s.style?.backgroundColor == Colors.orangeAccent,
          )
          .toList();
      expect(highlights.length, 3);
      expect(highlights[0].text, 'term');
      expect(highlights[0].style?.backgroundColor, Colors.yellow);
      expect(highlights[1].style?.backgroundColor, Colors.orangeAccent,
          reason: 'the second occurrence is the current match');
      expect(highlights[1].style?.fontWeight, FontWeight.bold);
      expect(highlights[2].style?.backgroundColor, Colors.yellow);
    });

    test('messageFirstMatchIndex shifts the current match selection', () {
      final gen = buildSearchMarkdownGenerator(
        query: 'term',
        messageFirstMatchIndex: 5,
        occurrenceOffset: 0,
        currentMatchIndex: 6,
      );
      final spans = _spansOf(gen, 'term term');
      final highlights = spans
          .where(
            (s) =>
                s.style?.backgroundColor == Colors.yellow ||
                s.style?.backgroundColor == Colors.orangeAccent,
          )
          .toList();
      expect(highlights.length, 2);
      expect(highlights[0].style?.backgroundColor, Colors.yellow,
          reason: 'occurrence 0 has global index 5, not the cursor 6');
      expect(highlights[1].style?.backgroundColor, Colors.orangeAccent,
          reason: 'occurrence 1 has global index 6 = the cursor');
    });

    test('occurrenceOffset aligns segments of a multi-segment message', () {
      // Simulates the SECOND text segment of a message whose first segment
      // already contained two occurrences.
      final gen = buildSearchMarkdownGenerator(
        query: 'term',
        messageFirstMatchIndex: 10,
        occurrenceOffset: 2,
        currentMatchIndex: 12,
      );
      final spans = _spansOf(gen, 'term here');
      final highlights = spans
          .where(
            (s) =>
                s.style?.backgroundColor == Colors.yellow ||
                s.style?.backgroundColor == Colors.orangeAccent,
          )
          .toList();
      expect(highlights.length, 1);
      expect(highlights[0].style?.backgroundColor, Colors.orangeAccent,
          reason: 'this occurrence has global index 12 = the cursor');
    });

    test('unmatched markdown (links, emphasis) still renders', () {
      final gen = buildSearchMarkdownGenerator(
        query: 'findme',
        messageFirstMatchIndex: 0,
        occurrenceOffset: 0,
        currentMatchIndex: 0,
      );
      final spans = _spansOf(gen, '[link](https://x.dev) and **findme** stay.');
      // The link's text and the surrounding paragraph still render (the
      // link node appends a trailing space, so compare loosely).
      expect(_plainText(spans), contains('link'));
      expect(_plainText(spans), contains(' and findme stay.'));
      // The link structure survives: its text span keeps the underline.
      final linkSpan = spans.firstWhere((s) => s.text == 'link');
      expect(linkSpan.style?.decoration, TextDecoration.underline);
      final highlights = spans.where(
        (s) =>
            s.style?.backgroundColor == Colors.yellow ||
            s.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(highlights.length, 1);
    });

    test('inline math is preserved as a widget span', () {
      final gen = buildSearchMarkdownGenerator(
        query: 'findme',
        messageFirstMatchIndex: 0,
        occurrenceOffset: 0,
        currentMatchIndex: 0,
      );
      final widgets = gen.buildWidgets(
        r'Inline $x^2$ and **findme** stay.',
        config: MarkdownConfig.defaultConfig,
      );
      // Math renders as a WidgetSpan inside the first block's text span.
      final firstBlock = (widgets.first as Padding).child as Text;
      final root = firstBlock.textSpan as TextSpan;
      final hasMathWidget = _containsWidgetSpan(root);
      expect(hasMathWidget, isTrue,
          reason: 'the \$...\$ math must still render as a widget');
      final highlights = _collectSpans(root).where(
        (s) =>
            s.style?.backgroundColor == Colors.yellow ||
            s.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(highlights.length, 1);
    });

    test('code-fence content is not highlighted and does not shift ordinals',
        () {
      // The search layer strips code fences, so the prose occurrence is
      // match 0 and must be the current (orange) one even though the raw
      // text also contains "term" inside the fence.
      final gen = buildSearchMarkdownGenerator(
        query: 'term',
        messageFirstMatchIndex: 0,
        occurrenceOffset: 0,
        currentMatchIndex: 0,
      );
      final spans = _spansOf(gen, '```\nterm\n```\nprose term');
      final highlights = spans
          .where(
            (s) =>
                s.style?.backgroundColor == Colors.yellow ||
                s.style?.backgroundColor == Colors.orangeAccent,
          )
          .toList();
      expect(highlights.length, 1,
          reason: 'the code-fence occurrence must not be highlighted');
      expect(highlights.single.style?.backgroundColor, Colors.orangeAccent,
          reason: 'the prose occurrence must stay the current match');
    });
  });

  group('SearchHighlightTextNode', () {
    test('splits text around occurrences and keeps plain segments', () {
      final node = SearchHighlightTextNode(
        text: 'aaa term bbb term ccc',
        lowerQuery: 'term',
        startGlobalIndex: 0,
        currentGlobalIndex: -1,
        baseStyle: const TextStyle(fontSize: 16),
      );
      final span = node.build() as TextSpan;
      final highlights = span.children!.whereType<TextSpan>().where(
        (s) => s.style?.backgroundColor == Colors.yellow,
      );
      expect(highlights.length, 2);
      final plain = span.children!.whereType<TextSpan>().map((s) => s.text ?? '').join();
      expect(plain, 'aaa term bbb term ccc');
    });

    test('empty query returns the plain text without looping forever', () {
      final node = SearchHighlightTextNode(
        text: 'any text',
        lowerQuery: '',
        startGlobalIndex: 0,
        currentGlobalIndex: -1,
        baseStyle: const TextStyle(fontSize: 16),
      );
      final span = node.build() as TextSpan;
      expect(span.text, 'any text');
      expect(span.children, isNull);
    });
  });
}
