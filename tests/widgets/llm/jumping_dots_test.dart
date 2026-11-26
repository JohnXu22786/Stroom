import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/llm/jumping_dots.dart';

Widget _indicator({
  required Key key,
  int numberOfDots = 3,
  double fontSize = 10,
  double dotSpacing = 0,
  double textScale = 1,
  Color color = Colors.black,
  int milliseconds = 250,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: JumpingDotsProgressIndicator(
              key: key,
              numberOfDots: numberOfDots,
              fontSize: fontSize,
              dotSpacing: dotSpacing,
              color: color,
              milliseconds: milliseconds,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('reconciles controller count when the widget updates', (
    tester,
  ) async {
    const key = ValueKey('jumping-dots');
    await tester.pumpWidget(_indicator(key: key, numberOfDots: 3));

    await tester.pumpWidget(_indicator(key: key, numberOfDots: 1));
    expect(find.byType(JumpingDot), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(_indicator(key: key, numberOfDots: 4));
    expect(find.byType(JumpingDot), findsNWidgets(4));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebuilds dots with updated style and spacing', (tester) async {
    const key = ValueKey('jumping-dots');
    await tester.pumpWidget(
      _indicator(
        key: key,
        numberOfDots: 2,
        fontSize: 10,
        dotSpacing: 1,
        color: Colors.black,
      ),
    );

    await tester.pumpWidget(
      _indicator(
        key: key,
        numberOfDots: 3,
        fontSize: 20,
        dotSpacing: 7,
        color: Colors.red,
      ),
    );

    final dots = tester.widgetList<JumpingDot>(find.byType(JumpingDot));
    expect(dots, hasLength(3));
    expect(dots.every((dot) => dot.fontSize == 20), isTrue);
    expect(dots.every((dot) => dot.color == Colors.red), isTrue);

    final paddings = tester.widgetList<Padding>(find.byType(Padding));
    expect(paddings, hasLength(3));
    expect(
      paddings.every(
        (padding) => padding.padding == const EdgeInsets.only(right: 7),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates duration for an already running animation', (
    tester,
  ) async {
    const key = ValueKey('jumping-dots');
    await tester.pumpWidget(
      _indicator(key: key, numberOfDots: 1, milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 30));
    final heightBeforeUpdate = tester.getSize(find.byType(JumpingDot)).height;

    await tester.pumpWidget(
      _indicator(key: key, numberOfDots: 1, milliseconds: 1000),
    );
    await tester.pump(const Duration(milliseconds: 30));
    final heightAfterUpdate = tester.getSize(find.byType(JumpingDot)).height;

    expect(heightAfterUpdate - heightBeforeUpdate, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the existing indicator geometry at normal text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _indicator(key: const ValueKey('dots'), fontSize: 14),
    );

    expect(
      tester.getSize(find.byType(JumpingDotsProgressIndicator)).height,
      21,
    );
    expect(tester.getSize(find.byType(JumpingDot).first).height, 14);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits scaled paragraph metrics at enlarged text scales', (
    tester,
  ) async {
    for (final scale in [2.0, 3.0]) {
      await tester.pumpWidget(
        _indicator(
          key: const ValueKey('dots'),
          fontSize: 14,
          textScale: scale,
        ),
      );

      final paragraph =
          tester.renderObject<RenderParagraph>(find.text('.').first);
      final dotSize = tester.getSize(find.byType(JumpingDot).first);
      final naturalParagraph = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout();
      expect(
        dotSize.height,
        greaterThanOrEqualTo(naturalParagraph.height),
        reason: 'the dot slot must fit the natural line height at ${scale}x',
      );
      naturalParagraph.dispose();
      expect(
        tester.getSize(find.byType(JumpingDotsProgressIndicator)).height,
        21 * scale,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
