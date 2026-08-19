import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/widgets/quit_confirmation_dialog.dart';

void main() {
  Future<Future<bool?> Function()> showDialogHelper(
    WidgetTester tester, {
    required int runningTaskCount,
  }) async {
    late Future<bool?> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              result = showQuitConfirmationDialog(
                context,
                runningTaskCount: runningTaskCount,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    return () => result;
  }

  testWidgets('cancel returns false and keeps the app running', (tester) async {
    final result = await showDialogHelper(tester, runningTaskCount: 1);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(await result(), isFalse);
  });

  testWidgets('confirm returns true', (tester) async {
    final result = await showDialogHelper(tester, runningTaskCount: 2);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    expect(await result(), isTrue);
  });

  testWidgets('no running tasks shows the generic quit prompt', (tester) async {
    await showDialogHelper(tester, runningTaskCount: 0);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 0 个任务时显示通用确认文案（不包含任务数）。
    expect(find.textContaining('确定要退出 Stroom 吗'), findsOneWidget);
    // 对话框仍打开（未点击任何按钮）。
  });

  testWidgets('tapping outside the dialog (barrier dismiss) counts as cancel',
      (tester) async {
    final result = await showDialogHelper(tester, runningTaskCount: 2);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the barrier outside the AlertDialog.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await result(), isFalse, reason: 'showDialog 返回 null 时必须按取消处理');
  });
}
