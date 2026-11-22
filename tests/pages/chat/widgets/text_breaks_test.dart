import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/text_breaks.dart';

void main() {
  testWidgets('leaves a fitting Arabic file name unchanged', (tester) async {
    const value = 'تقرير.pdf';
    final result = breakOverlongWords(
      value,
      maxWidth: 200,
      style: const TextStyle(fontSize: 13),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('en', 'US'),
    );

    await tester.pumpWidget(MaterialApp(home: Text(result)));
    expect(result, value);
    expect(find.text(value), findsOneWidget);
  });

  testWidgets('breaks overwide punctuation-only values', (tester) async {
    final value = List.filled(140, '.').join();
    final result = breakOverlongWords(
      value,
      maxWidth: 40,
      style: const TextStyle(fontSize: 13),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('en', 'US'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 40,
          child: Text(result, semanticsLabel: value),
        ),
      ),
    );

    expect(result, contains('\u200B'));
    expect(result.replaceAll('\u200B', ''), value);
    expect(tester.getSize(find.byType(Text)).height, greaterThan(13));
  });

  testWidgets('uses line-sized breaks for overlong Arabic text', (
    tester,
  ) async {
    final value = List.filled(40, 'م').join();
    final result = breakOverlongWords(
      value,
      maxWidth: 40,
      style: const TextStyle(fontSize: 13),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: const Locale('en', 'US'),
    );
    final breakCount = '\u200B'.allMatches(result).length;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 40,
          child: Text(result, semanticsLabel: value),
        ),
      ),
    );

    expect(breakCount, greaterThan(0));
    expect(breakCount, lessThan(value.characters.length ~/ 2));
    expect(result.replaceAll('\u200B', ''), value);
    expect(tester.getSize(find.byType(Text)).height, greaterThan(13));
  });
}
