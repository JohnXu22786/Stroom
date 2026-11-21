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

    expect(result, value);
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

    expect(result, contains('\u200B'));
    expect(result.replaceAll('\u200B', ''), value);
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

    expect(breakCount, greaterThan(0));
    expect(breakCount, lessThan(value.characters.length ~/ 2));
    expect(result.replaceAll('\u200B', ''), value);
  });
}
