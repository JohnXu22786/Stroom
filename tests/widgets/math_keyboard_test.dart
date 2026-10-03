import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/math_keyboard.dart';

void main() {
  testWidgets(
      'category directory reaches logs and hidden Greek keys without losing numeric positions',
      (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                    width: 320,
                    height: 220,
                    child: MathKeyboard(
                      activeLabel: '公式 1',
                      onDismiss: () {},
                      onPlot: () {},
                      onCommand: (kind, value) async =>
                          commands.add('$kind:$value'),
                    ))))));
    final seven = find.byTooltip('7');
    final before = tester.getRect(seven);
    await tester.tap(find.byTooltip('全部符号分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('指数/对数').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('自然对数 ln'));
    await tester.tap(seven);
    expect(tester.getRect(seven), before);
    expect(commands, [r'insert:\ln\left(#0\right)', 'insert:7']);
    await tester.tap(find.byTooltip('全部符号分类'));
    await tester.pumpAndSettle();
    final uppercase = find.text('希腊大写').last;
    await tester.ensureVisible(uppercase);
    await tester.tap(uppercase);
    await tester.pumpAndSettle();
    final selectedTab = tester.getRect(find.ancestor(
        of: find.text('希腊大写'), matching: find.byType(ChoiceChip)));
    final keyboard = tester.getRect(find.byType(MathKeyboard));
    expect(selectedTab.left, greaterThanOrEqualTo(keyboard.left));
    expect(selectedTab.right, lessThanOrEqualTo(keyboard.right - 44));
    await tester.tap(find.byTooltip('Alpha'));
    expect(commands.last, r'insert:\Alpha');
    expect(tester.getRect(seven), before);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'very short keyboard scrolls controls and keys without hiding arrows',
      (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                    width: 320,
                    height: 90,
                    child: MathKeyboard(
                      activeLabel: '公式 1',
                      onDismiss: () {},
                      onPlot: () {},
                      onCommand: (kind, value) async =>
                          commands.add('$kind:$value'),
                    ))))));
    expect(tester.takeException(), isNull);
    final right = find.byTooltip('光标右移');
    final before = tester.getRect(right);
    await tester.scrollUntilVisible(find.byTooltip('7'), 60,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down));
    await tester.tap(find.byTooltip('7'));
    await tester.tap(right);
    expect(tester.getRect(right), before);
    expect(commands, ['insert:7', 'navigate:right']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('navigation stays visible while keys scroll in a short viewport',
      (tester) async {
    final commands = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                    width: 320,
                    height: 180,
                    child: MathKeyboard(
                      activeLabel: '公式 1',
                      onDismiss: () {},
                      onPlot: () {},
                      onCommand: (kind, value) async {
                        commands.add('$kind:$value');
                      },
                    ))))));
    final right = find.byTooltip('光标右移');
    final before = tester.getRect(right);
    await tester.drag(find.byTooltip('7'), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.getRect(right), before);
    await tester.tap(right);
    await tester.tap(find.byTooltip('光标上移 / 切换上层'));
    await tester.tap(find.byTooltip('退出当前结构'));
    expect(commands, ['navigate:right', 'navigate:up', 'navigate:out']);
    expect(tester.takeException(), isNull);
  });

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
