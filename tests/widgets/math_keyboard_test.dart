import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/math_keyboard.dart';

void main() {
  testWidgets('loading editor disables insertion and structural navigation',
      (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MathKeyboard(
      enabled: false,
      activeLabel: '公式 1',
      onDismiss: () {},
      onPlot: () {},
      onCommand: (kind, value) async {
        commands.add('$kind:$value');
      },
    ))));
    await tester.tap(find.byTooltip('7'));
    await tester.tap(find.text('上一项'));
    await tester.tap(find.text('下一项'));
    await tester.tap(find.byTooltip('撤销'));
    expect(commands, isEmpty);
  });
  testWidgets('changing categories keeps numeric keys and navigation usable',
      (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MathKeyboard(
      activeLabel: '公式 1',
      onDismiss: () {},
      onPlot: () {},
      onCommand: (kind, value) async {
        commands.add('$kind:$value');
      },
    ))));
    final seven = find.descendant(
        of: find.byTooltip('7'), matching: find.byType(FilledButton));
    final before = tester.getRect(seven);
    await tester.tap(seven);
    await tester.tap(find.text('函数'));
    await tester.pump();
    expect(tester.getRect(seven), before);
    await tester.tap(find.text('下一项'));
    await tester.tap(find.byTooltip('⌫'));
    expect(commands, ['insert:7', 'next:', 'command:deleteBackward']);
    expect(tester.takeException(), isNull);
  });
}
