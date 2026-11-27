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
import 'package:markdown_widget/widget/link_recognizer_lifecycle.dart';
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
  } else if (span is WidgetSpan && span.child is Container) {
    final child = (span.child as Container).child;
    if (child is ProxyRichText) {
      result.addAll(_collectSpans(child.textSpan));
    }
  }
  return result;
}

Widget _unwrapLinkRecognizerLifecycle(Widget widget) =>
    widget is LinkRecognizerLifecycle
    ? _unwrapLinkRecognizerLifecycle(widget.child)
    : widget;

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
    final child = _unwrapLinkRecognizerLifecycle(padded.child!);
    if (child is Text) spans.addAll(_collectSpans(child.textSpan as TextSpan));
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
      expect(
        countOccurrences(stripped, 'term'),
        1,
        reason: 'the match inside the code fence must not be counted',
      );
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
      expect(
        countOccurrences(stripped, 'sudo'),
        0,
        reason: 'double-backtick span content must not be counted',
      );
      expect(countOccurrences(stripped, 'term'), 1);
    });

    test('removes fences inside blockquotes', () {
      final stripped = stripSearchIrrelevantMarkdown(
        '> ~~~\n> term\n> ~~~\nterm in prose',
      );
      expect(
        countOccurrences(stripped, 'term'),
        1,
        reason:
            'the match inside the blockquote code fence must not be '
            'counted',
      );
    });

    test('keeps prose around ragged backtick runs', () {
      // The renderer treats these backtick runs as literal text (a code
      // span cannot start right after a backtick), so the prose between
      // them must survive stripping.
      final stripped = stripSearchIrrelevantMarkdown('a ````` x ```` b');
      expect(
        countOccurrences(stripped, 'x'),
        1,
        reason: 'ragged backtick runs are literal text, not code spans',
      );
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

    test('removes link and image destinations from search text', () {
      const markdown =
          '[label](https://hidden.example/term) '
          '![image](https://term.example) literal ](term) visible term '
          '[spaced] (term) [invalid](visible term)';
      final stripped = stripSearchIrrelevantMarkdown(markdown);
      expect(countOccurrences(stripped, 'term'), 4);
      expect(stripped, contains('[label]'));
      final spans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        markdown,
      );
      final current = spans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(current.map((span) => span.text), ['term']);
      final highlights = spans.where(
        (span) =>
            span.style?.backgroundColor == Colors.yellow ||
            span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(highlights.map((span) => span.text), [
        'term',
        'term',
        'term',
        'term',
      ]);

      const backtickDestination = '[label](https://x/`term)` visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(backtickDestination),
          'term',
        ),
        1,
        reason: 'link destination parsing must see its closing parenthesis',
      );
      final backtickSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        backtickDestination,
      );
      final currentBacktickMatch = backtickSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentBacktickMatch.map((span) => span.text), ['term']);

      const escapedAngleDestination = r'[label](url\<term) visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(escapedAngleDestination),
          'term',
        ),
        1,
        reason: 'an escaped angle bracket in a bare URL remains valid',
      );

      const angleInTitle = '[label](url "title <term>") visible term';
      expect(
        countOccurrences(stripSearchIrrelevantMarkdown(angleInTitle), 'term'),
        1,
        reason: 'angle brackets in a link title do not invalidate its URL',
      );

      final separatedSyntax = stripSearchIrrelevantMarkdown(
        '[label]`x`(term) visible term',
      );
      expect(
        countOccurrences(separatedSyntax, 'term'),
        2,
        reason: 'stripping inline code must not create a link destination',
      );

      final titledLink = stripSearchIrrelevantMarkdown(
        '[title](url "term )") visible term',
      );
      expect(countOccurrences(titledLink, 'term'), 1);

      const paddedNoTitleLink = '[label](hiddenTerm ) visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(paddedNoTitleLink),
          'term',
        ),
        1,
        reason: 'whitespace before a closing paren does not require a title',
      );
      final paddedNoTitleSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        paddedNoTitleLink,
      );
      final currentPaddedNoTitleMatch = paddedNoTitleSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentPaddedNoTitleMatch.map((span) => span.text), ['term']);

      const angleLinkWithSpace = '[label](<hidden term>) visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(angleLinkWithSpace),
          'term',
        ),
        1,
        reason: 'spaces inside angle-bracket destinations remain valid',
      );
      final angleLinkWithSpaceSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        angleLinkWithSpace,
      );
      final currentAngleLinkWithSpace = angleLinkWithSpaceSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentAngleLinkWithSpace.map((span) => span.text), ['term']);

      const parenthesizedTitle = '[title](url "term (") visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(parenthesizedTitle),
          'term',
        ),
        1,
        reason: 'parentheses in a quoted title do not close the link',
      );
      final parenthesizedTitleSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        parenthesizedTitle,
      );
      final currentTitleMatch = parenthesizedTitleSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentTitleMatch.map((span) => span.text), ['term']);

      const quoteBeforeLink = 'intro ("unfinished [label](term) visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(quoteBeforeLink),
          'term',
        ),
        1,
        reason: 'unrelated quote state must not hide a later link closer',
      );
      final quoteBeforeLinkSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        quoteBeforeLink,
      );
      final currentQuoteMatch = quoteBeforeLinkSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentQuoteMatch.map((span) => span.text), ['term']);

      const parenthesizedDelimiterTitle = '[title](url (term ()) visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(parenthesizedDelimiterTitle),
          'term',
        ),
        1,
        reason: 'parenthesized title delimiters are not destination parens',
      );
      final parenthesizedDelimiterTitleSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        parenthesizedDelimiterTitle,
      );
      final currentParenthesizedMatch = parenthesizedDelimiterTitleSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentParenthesizedMatch.map((span) => span.text), ['term']);

      const nestedTitledLink =
          '[outer](bad (oops [inner](url "term (") blah visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(nestedTitledLink),
          'term',
        ),
        1,
        reason: 'a failed outer scan must still validate a nested titled link',
      );
      final nestedTitledLinkSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        nestedTitledLink,
      );
      final currentNestedTitleMatch = nestedTitledLinkSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentNestedTitleMatch.map((span) => span.text), ['term']);

      const nestedSimpleLink = '[broken](bad[good](term) prose visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(nestedSimpleLink),
          'term',
        ),
        1,
        reason: 'a failed outer scan must not hide a nested valid link',
      );
      final nestedSimpleLinkSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        nestedSimpleLink,
      );
      final currentNestedSimpleMatch = nestedSimpleLinkSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentNestedSimpleMatch.map((span) => span.text), ['term']);

      const nestedAngleDestination =
          '[outer](bad (oops [inner](<urlterm(>) blah visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(nestedAngleDestination),
          'term',
        ),
        1,
        reason: 'angle destination parentheses do not consume the link closer',
      );
      final nestedAngleDestinationSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        nestedAngleDestination,
      );
      final currentNestedAngleMatch = nestedAngleDestinationSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentNestedAngleMatch.map((span) => span.text), ['term']);

      const angleInMalformedTitle =
          '[outer](bad (oops < [inner](term) blah > visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(angleInMalformedTitle),
          'term',
        ),
        1,
        reason: 'an unrelated angle bracket must not hide an inner link close',
      );
      final angleInMalformedTitleSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        angleInMalformedTitle,
      );
      final currentAngleTitleMatch = angleInMalformedTitleSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentAngleTitleMatch.map((span) => span.text), ['term']);

      const invalidAngleOuter = '[broken](<bad [good](term)> visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(invalidAngleOuter),
          'term',
        ),
        1,
        reason: 'an invalid angle destination must not hide a nested link',
      );
      final invalidAngleOuterSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        invalidAngleOuter,
      );
      final currentInvalidAngleMatch = invalidAngleOuterSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentInvalidAngleMatch.map((span) => span.text), ['term']);

      const escapedCloserBeforeNestedLink =
          r'[outer](bad (oops \](< [inner](term) blah > visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(escapedCloserBeforeNestedLink),
          'term',
        ),
        1,
        reason: 'escaped bracket text must not start angle destination state',
      );
      final escapedCloserSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        escapedCloserBeforeNestedLink,
      );
      final currentEscapedCloserMatch = escapedCloserSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentEscapedCloserMatch.map((span) => span.text), ['term']);

      const escapedLabelCloserBeforeNestedLink =
          r'[outer](bad (oops [x \](< [inner](term) blah > visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(escapedLabelCloserBeforeNestedLink),
          'term',
        ),
        1,
        reason: 'an escaped label closer must not open an angle destination',
      );
      final escapedLabelCloserSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        escapedLabelCloserBeforeNestedLink,
      );
      final currentEscapedLabelMatch = escapedLabelCloserSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentEscapedLabelMatch.map((span) => span.text), ['term']);

      const evenEscapedLabelCloser = r'[label\\](<urlterm(>) visible term';
      expect(
        countOccurrences(
          stripSearchIrrelevantMarkdown(evenEscapedLabelCloser),
          'term',
        ),
        1,
        reason: 'an even backslash run leaves the closing bracket active',
      );
      final evenEscapedLabelSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        evenEscapedLabelCloser,
      );
      final currentEvenEscapedMatch = evenEscapedLabelSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(currentEvenEscapedMatch.map((span) => span.text), ['term']);

      final manyClosers = List.filled(1024, ')').join();
      final malformedLink = stripSearchIrrelevantMarkdown(
        '[label](visible term $manyClosers',
      );
      expect(countOccurrences(malformedLink, 'term'), 1);

      final repeatedOpeners = List.filled(512, '[a](').join();
      final malformedCandidates = stripSearchIrrelevantMarkdown(
        '$repeatedOpeners visible term',
      );
      expect(countOccurrences(malformedCandidates, 'term'), 1);

      final repeatedAngleCandidates = List.filled(512, '[a](x(').join();
      final repeatedAngleClosers = List.filled(1024, ')').join();
      final malformedAngleCandidates = stripSearchIrrelevantMarkdown(
        '$repeatedAngleCandidates<hiddenTerm$repeatedAngleClosers visible term',
      );
      expect(countOccurrences(malformedAngleCandidates, 'hiddenterm'), 1);
      expect(countOccurrences(malformedAngleCandidates, 'term'), 2);

      final repeatedInvalidTailCandidates = List.filled(512, '[a](x(').join();
      final malformedTailCandidates = stripSearchIrrelevantMarkdown(
        '$repeatedInvalidTailCandidates invalid$repeatedAngleClosers visible term',
      );
      expect(countOccurrences(malformedTailCandidates, 'term'), 1);

      final nestedLink = stripSearchIrrelevantMarkdown(
        '[broken](bad[good](term) prose',
      );
      expect(
        countOccurrences(nestedLink, 'term'),
        0,
        reason: 'a failed outer link must not hide a valid nested link',
      );
    });

    test('removes inline math content from search text', () {
      const markdown = r'formula $term + 1$ then visible term';
      final stripped = stripSearchIrrelevantMarkdown(markdown);
      expect(countOccurrences(stripped, 'term'), 1);
      final spans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        markdown,
      );
      final current = spans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(current.map((span) => span.text), ['term']);
    });

    test('removes indented code content but keeps later prose', () {
      const markdown =
          '    hidden term\n\n   \tsecond hidden term'
          '\n\n> >\n> >     nested hidden term\n> >\n\nvisible term';
      final stripped = stripSearchIrrelevantMarkdown(markdown);
      expect(countOccurrences(stripped, 'term'), 1);
      expect(stripped, contains('visible term'));
      final spans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        markdown,
      );
      final current = spans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(current.map((span) => span.text), ['term']);

      const tabQuotedCode = '>\t    hidden term\n>\nvisible term';
      final tabQuotedStripped = stripSearchIrrelevantMarkdown(tabQuotedCode);
      expect(countOccurrences(tabQuotedStripped, 'term'), 1);
      final tabQuotedSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        tabQuotedCode,
      );
      final tabQuotedCurrent = tabQuotedSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(tabQuotedCurrent.map((span) => span.text), ['term']);

      const tabQuotedParagraph = '>\tvisible term';
      final tabParagraphStripped = stripSearchIrrelevantMarkdown(
        tabQuotedParagraph,
      );
      expect(countOccurrences(tabParagraphStripped, 'term'), 1);
      final tabParagraphSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        tabQuotedParagraph,
      );
      final tabParagraphCurrent = tabParagraphSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(tabParagraphCurrent.map((span) => span.text), ['term']);

      const blockquoteAfterParagraph =
          'intro\n>     hidden term\n> visible term';
      final blockquoteSearchText = stripSearchIrrelevantMarkdown(
        blockquoteAfterParagraph,
      );
      expect(countOccurrences(blockquoteSearchText, 'term'), 1);
      final blockquoteSpans = _spansOf(
        buildSearchMarkdownGenerator(
          query: 'term',
          messageFirstMatchIndex: 0,
          occurrenceOffset: 0,
          currentMatchIndex: 0,
        ),
        blockquoteAfterParagraph,
      );
      final blockquoteCurrent = blockquoteSpans.where(
        (span) => span.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(blockquoteCurrent.map((span) => span.text), ['term']);
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
      expect(
        highlights[1].style?.backgroundColor,
        Colors.orangeAccent,
        reason: 'the second occurrence is the current match',
      );
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
      expect(
        highlights[0].style?.backgroundColor,
        Colors.yellow,
        reason: 'occurrence 0 has global index 5, not the cursor 6',
      );
      expect(
        highlights[1].style?.backgroundColor,
        Colors.orangeAccent,
        reason: 'occurrence 1 has global index 6 = the cursor',
      );
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
      expect(
        highlights[0].style?.backgroundColor,
        Colors.orangeAccent,
        reason: 'this occurrence has global index 12 = the cursor',
      );
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
      final firstBlock = _unwrapLinkRecognizerLifecycle(
        (widgets.first as Padding).child!,
      ) as Text;
      final root = firstBlock.textSpan as TextSpan;
      final hasMathWidget = _containsWidgetSpan(root);
      expect(
        hasMathWidget,
        isTrue,
        reason: 'the \$...\$ math must still render as a widget',
      );
      final highlights = _collectSpans(root).where(
        (s) =>
            s.style?.backgroundColor == Colors.yellow ||
            s.style?.backgroundColor == Colors.orangeAccent,
      );
      expect(highlights.length, 1);
    });

    test(
      'code-fence content is not highlighted and does not shift ordinals',
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
        expect(
          highlights.length,
          1,
          reason: 'the code-fence occurrence must not be highlighted',
        );
        expect(
          highlights.single.style?.backgroundColor,
          Colors.orangeAccent,
          reason: 'the prose occurrence must stay the current match',
        );
      },
    );
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
      final plain = span.children!
          .whereType<TextSpan>()
          .map((s) => s.text ?? '')
          .join();
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
