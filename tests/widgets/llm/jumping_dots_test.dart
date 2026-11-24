import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/llm/jumping_dots.dart';

Widget _indicator({
  required Key key,
  int numberOfDots = 3,
  double fontSize = 10,
  double dotSpacing = 0,
  Color color = Colors.black,
  int milliseconds = 250,
}) =>
    MaterialApp(
      home: Scaffold(
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
}
