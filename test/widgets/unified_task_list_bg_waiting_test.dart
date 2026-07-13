import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/providers/background_task_provider.dart';

// =============================================================================
// Pump Helpers (matches unified_task_list_background_test.dart pattern)
// =============================================================================

/// Pumps the UnifiedTaskListPage with given background tasks and empty others.
Future<void> pumpPageWithBackground(
  WidgetTester tester,
  List<BackgroundTask> backgroundTasks,
) async {
  final bgNotifier = BackgroundTaskNotifier();
  bgNotifier.state = backgroundTasks;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) => bgNotifier),
        taskListLastReadProvider.overrideWith((ref) => DateTime.now()),
      ],
      child: const MaterialApp(
        home: UnifiedTaskListPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// =============================================================================
// Test helpers
// =============================================================================

BackgroundTask _createWaitingAsrTask({
  required String id,
  String title = '等待转写',
}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.asr,
    title: title,
    status: TaskStatus.waiting,
    createdAt: DateTime(2025, 6, 1),
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('UnifiedTaskListPage - Background task waiting status', () {
    testWidgets('waiting task appears in task list with correct title',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-1', title: '等待转写的音频'),
      ]);

      expect(find.text('等待转写的音频'), findsOneWidget, reason: '等待中的任务应显示在任务列表中');
    });

    testWidgets('waiting task shows "等待中" status chip', (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-2'),
      ]);

      expect(find.text('等待中'), findsOneWidget, reason: '等待中的任务应显示"等待中"状态标签');
    });

    testWidgets('waiting task shows hourglass_empty icon', (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-3'),
      ]);

      // The waiting status icon should be Icons.hourglass_empty
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget,
          reason: '等待中的任务应显示沙漏图标');
    });

    testWidgets('waiting task shows "立即开始" button when expanded',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-expand', title: '可立即开始的等待任务'),
      ]);

      // Find the waiting task card header
      expect(find.text('可立即开始的等待任务'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('可立即开始的等待任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After expand, should see the "立即开始" button
      expect(find.text('立即开始'), findsOneWidget, reason: '展开等待中的任务后应显示"立即开始"按钮');
    });

    testWidgets('waiting task does NOT show retry or open file buttons',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-no-other-btns'),
      ]);

      // Tap to expand
      await tester.tap(find.text('等待转写'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // "重试" and "打开文件" buttons should not appear for waiting tasks
      expect(find.text('重试'), findsNothing, reason: '等待中的任务不应显示"重试"按钮');
      expect(find.text('打开文件'), findsNothing, reason: '等待中的任务不应显示"打开文件"按钮');
    });

    testWidgets('waiting task can be deleted via delete button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-del', title: '待删除的等待任务'),
      ]);

      // Tap to expand
      await tester.tap(find.text('待删除的等待任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the delete button
      expect(find.text('删除'), findsOneWidget, reason: '展开后应显示"删除"按钮');

      // Tap the delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Task should be removed
      expect(find.text('暂无任务'), findsOneWidget, reason: '删除等待任务后应显示空状态');
    });

    testWidgets('multiple waiting tasks all appear in list', (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-a', title: '等待任务A'),
        _createWaitingAsrTask(id: 'wait-b', title: '等待任务B'),
        _createWaitingAsrTask(id: 'wait-c', title: '等待任务C'),
      ]);

      expect(find.text('等待任务A'), findsOneWidget);
      expect(find.text('等待任务B'), findsOneWidget);
      expect(find.text('等待任务C'), findsOneWidget);
      expect(find.text('等待中'), findsNWidgets(3), reason: '三个等待任务应都显示"等待中"状态');
    });
  });
}
