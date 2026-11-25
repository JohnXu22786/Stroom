import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown_widget/widget/link_recognizer_lifecycle.dart';

void main() {
  test('preserves multiline highlighting and rendered code lines', () {
    const commentColor = Colors.red;
    const code =
        '/* comment starts\nstill a comment\nand ends */\n\nconst x = 1;';
    final widgets = MarkdownGenerator().buildWidgets(
      '```javascript\n$code\n```',
      config: MarkdownConfig(configs: [
        const PreConfig(theme: {
          'comment': TextStyle(color: commentColor),
        }),
      ]),
    );
    final codeBlock = _codeBlockFrom(widgets.single);
    final scrollView = codeBlock.child as SingleChildScrollView;
    final lines = (scrollView.child as Column).children.cast<ProxyRichText>();
    final textSpans = lines.map((line) => line.textSpan as TextSpan).toList();

    expect(
      textSpans.map((span) => span.toPlainText()).toList(),
      code.split('\n'),
      reason: 'code text and blank lines remain line-oriented',
    );
    expect(
      textSpans.any((span) => _containsStyledText(
            span,
            'still a comment',
            commentColor,
          )),
      isTrue,
      reason: 'the continuation line of a multiline comment remains styled',
    );
  });
}

Container _codeBlockFrom(Widget widget) {
  if (widget is Padding) return _codeBlockFrom(widget.child!);
  if (widget is LinkRecognizerLifecycle) return _codeBlockFrom(widget.child);
  if (widget is Text && widget.textSpan != null) {
    final codeBlocks = <Container>[];
    _collectCodeBlocks(widget.textSpan!, codeBlocks);
    return codeBlocks.single;
  }
  throw StateError('Markdown output did not contain a code block');
}

void _collectCodeBlocks(InlineSpan span, List<Container> codeBlocks) {
  if (span is WidgetSpan && span.child is Container) {
    codeBlocks.add(span.child as Container);
  } else if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      _collectCodeBlocks(child, codeBlocks);
    }
  }
}

bool _containsStyledText(TextSpan span, String text, Color color,
    [TextStyle? inheritedStyle]) {
  final style = inheritedStyle?.merge(span.style) ?? span.style;
  if (span.text?.contains(text) == true && style?.color == color) return true;
  return span.children?.any((child) {
        if (child is! TextSpan) return false;
        return _containsStyledText(child, text, color, style);
      }) ??
      false;
}
