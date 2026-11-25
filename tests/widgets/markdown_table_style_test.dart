import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:markdown_widget/markdown_widget.dart';

TextStyle? _styleForText(InlineSpan span, String text) {
  if (span is! TextSpan) return null;
  if (span.text == text) return span.style;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final style = _styleForText(child, text);
    if (style != null) return style;
  }
  return null;
}

void main() {
  for (final alignment in <({String separator, Alignment expected})>[
    (separator: ':---', expected: Alignment.centerLeft),
    (separator: ':---:', expected: Alignment.center),
    (separator: '---:', expected: Alignment.centerRight),
  ]) {
    testWidgets(
      'table header and body honor ${alignment.expected} column alignment',
      (WidgetTester tester) async {
        final widgets = MarkdownGenerator().buildWidgets(
          '| Header |\n| ${alignment.separator} |\n| Body |',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Column(children: widgets)),
          ),
        );

        for (final text in ['Header', 'Body']) {
          final alignments = tester
              .widgetList<Align>(
                find.ancestor(
                  of: find.text(text),
                  matching: find.byType(Align),
                ),
              )
              .map((align) => align.alignment);
          expect(
            alignments,
            contains(alignment.expected),
            reason: '$text should use ${alignment.expected}',
          );
        }
      },
    );
  }

  testWidgets('ignores body cells beyond the table header column count', (
    WidgetTester tester,
  ) async {
    final table = markdown.Element('table', [
      markdown.Element('thead', [
        markdown.Element('tr', [
          markdown.Element('th', [markdown.Text('Header')]),
        ]),
      ]),
      markdown.Element('tbody', [
        markdown.Element('tr', [
          markdown.Element('td', [markdown.Text('Visible')]),
          markdown.Element('td', [markdown.Text('Overflow')]),
        ]),
      ]),
    ]);
    final widgets = MarkdownGenerator().buildWidgetsFromNodes([table]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Column(children: widgets)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Visible'), findsOneWidget);
    expect(find.text('Overflow'), findsNothing);
  });

  testWidgets('table header and body use their configured text styles', (
    WidgetTester tester,
  ) async {
    const headerColor = Colors.red;
    const bodyColor = Colors.green;
    final config = MarkdownConfig(
      configs: const [
        TableConfig(
          headerStyle: TextStyle(color: headerColor, fontSize: 24),
          bodyStyle: TextStyle(color: bodyColor, fontSize: 12),
        ),
      ],
    );
    final widgets = MarkdownGenerator().buildWidgets(
      '| Head |\n| --- |\n| Body |',
      config: config,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Column(children: widgets)),
      ),
    );

    final table = find.byType(Table);
    final cellTexts = tester.widgetList<Text>(
      find.descendant(of: table, matching: find.byType(Text)),
    );
    final spansByText = {
      for (final text in cellTexts)
        text.textSpan!.toPlainText(): text.textSpan!,
    };

    expect(_styleForText(spansByText['Head']!, 'Head')?.color, headerColor);
    expect(_styleForText(spansByText['Head']!, 'Head')?.fontSize, 24);
    expect(_styleForText(spansByText['Body']!, 'Body')?.color, bodyColor);
    expect(_styleForText(spansByText['Body']!, 'Body')?.fontSize, 12);
  });
}
