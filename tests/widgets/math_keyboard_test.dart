import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/math_keyboard.dart';

Future<void> _selectCategory(WidgetTester tester, String category) async {
  await tester.ensureVisible(find.byTooltip('全部符号分类'));
  await tester.tap(find.byTooltip('全部符号分类'));
  await tester.pumpAndSettle();
  final item = find.text(category).last;
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _pumpKeyboard(WidgetTester tester, List<String> commands,
    {double width = 320, double height = 400, bool enabled = true}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                  width: width,
                  height: height,
                  child: MathKeyboard(
                    activeLabel: '公式 1',
                    enabled: enabled,
                    onDismiss: () {},
                    onPlot: () {},
                    onCommand: (kind, value) async =>
                        commands.add('$kind:$value'),
                  ))))));
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
        'Latin QWERTY shows all letters at $width with persistent Shift and pinned navigation',
        (tester) async {
      final commands = <String>[];
      await _pumpKeyboard(tester, commands, width: width);
      await _selectCategory(tester, '字母');
      final keyboard = tester.getRect(find.byType(MathKeyboard));
      final navigation = tester.getRect(find.byTooltip('光标右移'));
      final rowTops = <double>[];
      for (final row in ['qwertyuiop', 'asdfghjkl', 'zxcvbnm']) {
        final rects = [
          for (final letter in row.split(''))
            tester.getRect(find.byTooltip(letter))
        ];
        rowTops.add(rects.first.top);
        for (var index = 0; index < rects.length; index++) {
          final rect = rects[index];
          expect(rect.top, rects.first.top);
          expect(rect.height, 44);
          expect(rect.left, greaterThanOrEqualTo(keyboard.left));
          expect(rect.right, lessThanOrEqualTo(keyboard.right));
          expect(rect.bottom, lessThanOrEqualTo(navigation.top));
          if (index > 0) expect(rect.left, greaterThan(rects[index - 1].right));
          await tester.tap(find.byTooltip(row[index]));
        }
      }
      expect(rowTops[0], lessThan(rowTops[1]));
      expect(rowTops[1], lessThan(rowTops[2]));
      expect(commands, [
        for (final letter in 'qwertyuiopasdfghjklzxcvbnm'.split(''))
          'insert:$letter'
      ]);
      commands.clear();
      final shift = find.byKey(const ValueKey('math-keyboard-shift'));
      final backspace = find.byTooltip('⌫');
      expect(tester.getRect(shift).top, rowTops.last);
      expect(tester.getRect(backspace).top, rowTops.last);
      final semantics = tester.ensureSemantics();
      expect(
          tester.getSemantics(shift),
          matchesSemantics(
              label: 'Shift',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasToggledState: true,
              isToggled: false,
              hasTapAction: true));
      await tester.tap(shift);
      await tester.pump();
      expect(
          tester.getSemantics(shift),
          matchesSemantics(
              label: 'Shift',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasToggledState: true,
              isToggled: true,
              hasTapAction: true));
      expect(find.byTooltip('Shift：大写已开启，切换小写'), findsOneWidget);
      await tester.tap(find.byTooltip('Q'));
      await tester.tap(find.byTooltip('M'));
      await tester.tap(backspace);
      await tester.tap(find.byTooltip('3'));
      await tester.tap(find.text('上一项'));
      await tester.tap(find.text('下一项'));
      await _selectCategory(tester, '函数');
      await tester.tap(find.byTooltip('7'));
      await _selectCategory(tester, '字母');
      await tester.tap(find.byTooltip('Q'));
      await _selectCategory(tester, '希腊字母');
      await tester.tap(find.byTooltip('Alpha'));
      await _selectCategory(tester, '字母');
      await tester.tap(shift);
      await tester.pump();
      await tester.tap(find.byTooltip('q'));
      expect(commands, [
        'insert:Q',
        'insert:M',
        'command:deleteBackward',
        'insert:3',
        'previous:',
        'next:',
        'insert:7',
        'insert:Q',
        r'insert:\Alpha',
        'insert:q'
      ]);
      expect(tester.getRect(find.byTooltip('光标右移')), navigation);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets(
      'Greek page swipes preserve Shift slots and reset on category changes',
      (tester) async {
    final commands = <String>[];
    await _pumpKeyboard(tester, commands);
    await _selectCategory(tester, '希腊字母');
    expect(find.text('希腊大写'), findsNothing);
    expect(find.text('1/2'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('1/2'),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    await tester.drag(find.byTooltip('Alpha'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    final firstSlot = tester.getRect(find.byTooltip('nu'));
    const secondPage = [
      'nu',
      'xi',
      'omicron',
      'pi',
      'rho',
      'sigma',
      'tau',
      'upsilon',
      'phi',
      'chi',
      'psi',
      'omega'
    ];
    for (final name in secondPage) {
      await tester.tap(find.byTooltip(name));
    }
    final shift = find.byKey(const ValueKey('math-keyboard-shift'));
    await tester.tap(shift);
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('Nu')), firstSlot);
    for (final name in secondPage) {
      await tester
          .tap(find.byTooltip('${name[0].toUpperCase()}${name.substring(1)}'));
    }
    await tester.tap(shift);
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.getRect(find.byTooltip('nu')), firstSlot);
    await tester.tap(find.byTooltip('nu'));
    expect(commands, [
      for (final name in secondPage) 'insert:\\$name',
      for (final name in secondPage)
        'insert:\\${name[0].toUpperCase()}${name.substring(1)}',
      r'insert:\nu'
    ]);
    await tester.tap(shift);
    await tester.pump();
    await _selectCategory(tester, '希腊变体');
    await tester.tap(find.byTooltip('varkappa'));
    await _selectCategory(tester, '希腊字母');
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byTooltip('Alpha'));
    expect(commands.sublist(commands.length - 2),
        [r'insert:\varkappa', r'insert:\Alpha']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'short Latin keyboard scrolls letters while navigation stays pinned',
      (tester) async {
    final commands = <String>[];
    await _pumpKeyboard(tester, commands, height: 90);
    await _selectCategory(tester, '字母');
    final right = find.byTooltip('光标右移');
    final before = tester.getRect(right);
    final scrollable = find.byWidgetPredicate((widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(find.byTooltip('q'), 40,
        scrollable: scrollable);
    await tester.tap(find.byTooltip('q'));
    await tester.scrollUntilVisible(find.byTooltip('⌫'), 40,
        scrollable: scrollable);
    await tester.tap(find.byTooltip('⌫'));
    await tester.tap(right);
    expect(commands, ['insert:q', 'command:deleteBackward', 'navigate:right']);
    expect(tester.getRect(right), before);
    expect(tester.takeException(), isNull);
  });

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
    final greek = find.text('希腊字母').last;
    await tester.ensureVisible(greek);
    await tester.tap(greek);
    await tester.pumpAndSettle();
    final selectedTab = tester.getRect(find.ancestor(
        of: find.text('希腊字母'), matching: find.byType(ChoiceChip)));
    final keyboard = tester.getRect(find.byType(MathKeyboard));
    expect(selectedTab.left, greaterThanOrEqualTo(keyboard.left));
    expect(selectedTab.right, lessThanOrEqualTo(keyboard.right - 44));
    expect(tester.getRect(seven), before);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('math-keyboard-shift')), 40,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down));
    await tester.tap(find.byKey(const ValueKey('math-keyboard-shift')));
    await tester.pump();
    await tester.scrollUntilVisible(find.byTooltip('Alpha'), -40,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down));
    await tester.tap(find.byTooltip('Alpha'));
    expect(commands.last, r'insert:\Alpha');
    await tester.drag(find.byTooltip('Alpha'), const Offset(0, 200));
    await tester.pumpAndSettle();
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
    await _selectCategory(tester, '字母');
    await tester.tap(find.byTooltip('q'));
    await tester.tap(find.byKey(const ValueKey('math-keyboard-shift')));
    await tester.tap(find.byTooltip('光标右移'));
    expect(find.byTooltip('q'), findsOneWidget);
    expect(find.byTooltip('Q'), findsNothing);
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
