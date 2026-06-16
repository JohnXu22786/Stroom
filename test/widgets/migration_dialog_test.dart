import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/data_migration_service.dart';
import 'package:stroom/widgets/migration_dialog.dart';

/// A mutable holder for the pop result, allowing the helper to return
/// a reference that gets populated asynchronously.
class _PopResult {
  bool? value;
}

/// Pumps a MaterialApp that shows the [MigrationDialog] via [showDialog].
///
/// Returns a [Completer] to control the migration future, and optionally
/// a [_PopResult] that is populated when the dialog closes.
Future<({Completer<MigrationResult> completer, _PopResult? popResult})>
    _pumpDialog(WidgetTester tester, {bool capturePopResult = false}) async {
  final completer = Completer<MigrationResult>();
  final popResult = capturePopResult ? _PopResult() : null;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          Future.microtask(() {
            showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => MigrationDialog(future: completer.future),
            ).then((value) {
              popResult?.value = value;
            });
          });
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  return (completer: completer, popResult: popResult);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MigrationDialog', () {
    testWidgets('shows migration in progress UI while waiting for future',
        (tester) async {
      await _pumpDialog(tester);

      expect(find.text('正在数据迁移到新版本'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('确定'), findsNothing);
    });

    testWidgets('dialog is non-dismissable (cannot pop)', (tester) async {
      await _pumpDialog(tester);

      expect(find.text('正在数据迁移到新版本'), findsOneWidget);

      // Try to pop using Navigator
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('正在数据迁移到新版本'), findsOneWidget);
    });

    testWidgets('shows completion and restart message when migration completes',
        (tester) async {
      final result = await _pumpDialog(tester);

      result.completer.complete(const MigrationResult(
        needsMigration: true,
        restartRequired: true,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 迁移完成后显示重启提示
      expect(find.textContaining('重启应用'), findsOneWidget);

      // 消耗 1.5s 自动关闭定时器，避免 Timer pending 错误
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
    });

    testWidgets(
        'auto-closes with true (exit signal) after migration completes',
        (tester) async {
      final result = await _pumpDialog(tester, capturePopResult: true);

      result.completer.complete(const MigrationResult(
        needsMigration: true,
        restartRequired: true,
      ));
      await tester.pump();
      // Wait for the 1.5s auto-close delay (1600ms = 1500ms delay + 100ms buffer)
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();

      // 迁移完成后自动关闭并返回 true（退出应用）
      expect(result.popResult!.value, isTrue);
    });

    testWidgets('shows error state when migration fails', (tester) async {
      final result = await _pumpDialog(tester);

      result.completer.completeError(Exception('模拟迁移失败'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('数据迁移失败'), findsOneWidget);
      expect(find.textContaining('模拟迁移失败'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });
  });
}
