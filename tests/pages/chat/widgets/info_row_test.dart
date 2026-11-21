import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/info_row.dart';

void main() {
  testWidgets('shows long file information values without a line limit', (
    tester,
  ) async {
    final value = List.filled(140, 'a').join();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: InfoRow(label: 'Name', value: value),
          ),
        ),
      ),
    );

    final textFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == value,
    );
    expect(textFinder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: textFinder, matching: find.byType(RichText)),
    );
    expect(paragraph.maxLines, isNull);
    expect(paragraph.overflow, TextOverflow.clip);
    expect(tester.getSize(textFinder).height, greaterThan(2 * 13));
    expect((paragraph.text as TextSpan).text, value.characters.join('\u200B'));
  });
}
