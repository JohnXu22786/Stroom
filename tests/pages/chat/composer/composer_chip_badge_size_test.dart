import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';

void main() {
  testWidgets('badge keeps its text size and grows for the full 99+ label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChipBadge(count: 1, color: Colors.blue),
              ChipBadge(count: 12, color: Colors.blue),
              ChipBadge(count: 100, color: Colors.blue),
            ],
          ),
        ),
      ),
    );

    final badges = find.byType(ChipBadge);
    final widths = <double>[];
    for (var index = 0; index < badges.evaluate().length; index++) {
      final badge = badges.at(index);
      widths.add(tester.getSize(badge).width);
      final container = tester.widget<Container>(
        find.descendant(of: badge, matching: find.byType(Container)),
      );
      expect(
        (container.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(7),
      );
      final text = tester.widget<Text>(
        find.descendant(of: badge, matching: find.byType(Text)),
      );
      expect(text.style?.fontSize, 11);
    }

    expect(widths[0], 14);
    expect(widths[1], greaterThan(widths[0]));
    expect(widths[2], greaterThan(widths[1]));
    expect(find.text('99+'), findsOneWidget);
    expect(tester.getSemantics(find.text('99+')).label, '99+');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const ChipBadge(count: 100, color: Colors.blue),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ChipBadge)).height, greaterThan(14));
    expect(tester.takeException(), isNull);
  });
}
