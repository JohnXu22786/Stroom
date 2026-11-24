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
