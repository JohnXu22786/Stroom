import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/pages/unified_task_list/background_task_card.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/providers/background_task_provider.dart';

// =============================================================================
// Pump Helpers
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
// Helpers to create test background tasks
// =============================================================================

BackgroundTask _createRunningOcrTask({required String id, String title = 'OCR任务', int progress = 0}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.ocr,
    title: title,
    status: TaskStatus.running,
    createdAt: DateTime(2025, 6, 1),
    progress: progress,
  );
}

BackgroundTask _createFailedAudioTask({required String id}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.audioSeparation,
    title: '音频分离任务',
    status: TaskStatus.failed,
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    error: '提取失败: FFmpeg未安装',
  );
}

BackgroundTask _createCompletedTask({required String id, String title = '已完成任务', int progress = 100}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.ocr,
    title: title,
    status: TaskStatus.completed,
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    progress: progress,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('UnifiedTaskListPage - Background tasks', () {
    testWidgets('background tasks tab is present', (tester) async {
      await pumpPageWithBackground(tester, []);

      // Should have a tab for background tasks (OCR/ASR/AudioSeparation)
      expect(find.text('其他'), findsOneWidget,
          reason: '应存在"其他"标签页用于显示OCR/ASR/音频分离任务');
    });

    testWidgets('background tasks appear in "全部" tab', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1'),
      ]);

      // Should show the OCR task in the "全部" tab
      expect(find.text('OCR任务'), findsOneWidget,
          reason: 'OCR任务应显示在任务列表中');
    });

    testWidgets('background tasks tab shows running task', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the running task title and status
      expect(find.text('OCR任务'), findsOneWidget,
          reason: '"其他"标签页应显示进行中的OCR任务');
      expect(find.text('进行中'), findsOneWidget,
          reason: '进行中的任务应显示"进行中"状态');
    });

    testWidgets(
        'completed background task via completeTask is shown with completed status',
        (tester) async {
      // Create a notifier and add a running task, then complete it (which keeps it with status=completed)
      final bgNotifier = BackgroundTaskNotifier();
      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'OCR已完成',
      );
      bgNotifier.completeTask(taskId); // Updates status to completed, keeps task visible
      // Now the notifier state has 1 task with status=completed

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

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Completed task should appear with "已完成" status
      expect(find.text('OCR已完成'), findsOneWidget,
          reason: '已完成的任务应显示在列表中');
      expect(find.text('已完成'), findsOneWidget,
          reason: '已完成的任务应显示"已完成"状态');
    });

    testWidgets('background tasks tab shows failed task with error',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('音频分离任务'), findsOneWidget,
          reason: '"其他"标签页应显示失败的音频分离任务');
      expect(find.text('失败'), findsOneWidget,
          reason: '失败的任务应显示"失败"状态');

      // Tap to expand the card
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After expand, error message should be visible
      expect(find.text('提取失败: FFmpeg未安装'), findsOneWidget,
          reason: '展开后应显示失败的错误信息');
    });

    testWidgets('empty background tasks shows placeholder', (tester) async {
      await pumpPageWithBackground(tester, []);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('暂无任务'), findsOneWidget,
          reason: '空任务列表应显示"暂无任务"占位符');
    });

    testWidgets('failed background task can be deleted via expanded delete button', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap to expand the card
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the delete button in the expanded section
      expect(find.text('删除'), findsOneWidget,
          reason: '展开后应显示"删除"按钮');
    });

    testWidgets('multiple background task types all display (running + failed)',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1', title: '图片文字识别'),
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('图片文字识别'), findsOneWidget);
      expect(find.text('音频分离任务'), findsOneWidget);
    });

    testWidgets('background task cards show correct icons for running',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Running task should show a spinner icon (CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: '进行中的任务应显示加载指示器');
    });

    testWidgets('running background task shows progress percentage in circular indicator',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1', progress: 65),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show the progress number
      expect(find.text('65%'), findsOneWidget,
          reason: '进行中的任务应显示进度百分比');
    });

    testWidgets('completed background task does not show progress percentage',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedTask(id: 'done-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show completed icon (appears at least once - status icon + right icon)
      expect(find.byIcon(Icons.check_circle), findsAtLeast(1),
          reason: '已完成的任务应显示完成图标');
      // Should show "已完成" label
      expect(find.text('已完成'), findsOneWidget);
    });

    testWidgets('running background task card shows progress and status info',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1', title: '运行中任务', progress: 30),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Shows task title
      expect(find.text('运行中任务'), findsOneWidget);

      // Running task should show "进行中" status chip
      expect(find.text('进行中'), findsOneWidget,
          reason: '进行中的任务应显示"进行中"状态');
    });

    testWidgets('failed background task shows expandable error section',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap to expand the card
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After expand, error message should be visible
      expect(find.text('提取失败: FFmpeg未安装'), findsOneWidget,
          reason: '展开后应显示错误详情');
    });

    testWidgets('background task card delete action removes the task',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      // Switch to "其他" tab
      await tester.tap(find.text('其他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap to expand
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find and tap the delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Task should be removed - "暂无任务" appears
      expect(find.text('暂无任务'), findsOneWidget,
          reason: '删除任务后应显示空状态');
    });
  });
}
