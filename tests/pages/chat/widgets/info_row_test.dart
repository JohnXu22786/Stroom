import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/widgets/info_row.dart';

void main() {
  testWidgets('shows long file information values without a line limit', (
    tester,
  ) async {
    final value = List.filled(140, 'é').join();

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
    expect((paragraph.text as TextSpan).text, contains('\u200B'));
  });

  testWidgets('wraps long runs of punctuation in file information values', (
    tester,
  ) async {
    for (final value in [
      List.filled(140, '_').join(),
      List.filled(140, '.').join(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: InfoRow(label: 'Path', value: value),
            ),
          ),
        ),
      );

      final textFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.semanticsLabel == value,
      );
      expect(textFinder, findsOneWidget);
      expect(tester.getSize(textFinder).height, greaterThan(2 * 13));
      expect(
        (tester
                .renderObject<RenderParagraph>(
                  find.descendant(
                    of: textFinder,
                    matching: find.byType(RichText),
                  ),
                )
                .text as TextSpan)
            .text,
        contains('\u200B'),
      );
    }
  });

  testWidgets('keeps fitting Arabic values unchanged for native shaping', (
    tester,
  ) async {
    const value = '/home/المستخدم/ملفات/تقرير.pdf';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: InfoRow(label: 'Path', value: value),
          ),
        ),
      ),
    );

    final textFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == value,
    );
    expect(textFinder, findsOneWidget);
    expect(tester.widget<Text>(textFinder).data, value);
  });

  testWidgets('constrains a long localized label at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: const Scaffold(
          body: SizedBox(
            width: 240,
            child: InfoRow(label: 'Chemin d’accès', value: '/local/sample.pdf'),
          ),
        ),
      ),
    );

    final label = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Chemin d’accès',
    );
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).maxLines, 1);
    expect(tester.takeException(), isNull);
  });
}
