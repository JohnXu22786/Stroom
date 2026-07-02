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

BackgroundTask _createRunningOcrTask({
  required String id,
  String title = 'OCR任务',
}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.ocr,
    title: title,
    status: TaskStatus.running,
    createdAt: DateTime(2025, 6, 1),
  );
}

BackgroundTask _createCompletedOcrTask({
  required String id,
  String title = '已完成任务',
  String? downloadedFilePath,
}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.ocr,
    title: title,
    status: TaskStatus.completed,
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    downloadedFilePath: downloadedFilePath,
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

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('UnifiedTaskListPage - Background tasks (no tabs, no result text)', () {
    testWidgets('background task appears in unified list (no tab needed)',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1'),
      ]);

      // Should show the OCR task in the main (only) list
      expect(find.text('OCR任务'), findsOneWidget, reason: 'OCR任务应显示在统一任务列表中');
    });

    testWidgets('background task shows status info', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1', title: '运行中任务'),
      ]);

      expect(find.text('运行中任务'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget, reason: '进行中的任务应显示"进行中"状态');
    });

    testWidgets('completed background task shows completed status',
        (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'OCR已完成',
      );
      bgNotifier.completeTask(taskId);

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

      expect(find.text('OCR已完成'), findsOneWidget, reason: '已完成的任务应显示在列表中');
      expect(find.text('已完成'), findsOneWidget, reason: '已完成的任务应显示"已完成"状态');
    });

    testWidgets('background task shows failed task with error', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      expect(find.text('音频分离任务'), findsOneWidget, reason: '应显示失败的音频分离任务');
      expect(find.text('失败'), findsOneWidget, reason: '失败的任务应显示"失败"状态');

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

      expect(find.text('暂无任务'), findsOneWidget, reason: '空任务列表应显示"暂无任务"占位符');
    });

    testWidgets('failed background task can be deleted via delete button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      // Tap to expand the card
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the delete button in the expanded section
      expect(find.text('删除'), findsOneWidget, reason: '展开后应显示"删除"按钮');

      // Tap the delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Task should be removed
      expect(find.text('暂无任务'), findsOneWidget, reason: '删除任务后应显示空状态');
    });

    testWidgets('multiple background task types all display', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1', title: '图片文字识别'),
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      expect(find.text('图片文字识别'), findsOneWidget);
      expect(find.text('音频分离任务'), findsOneWidget);
    });

    testWidgets('background task does NOT show progress indicator',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1'),
      ]);

      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '进行中的OCR/ASR任务不应显示进度指示器');
      expect(find.textContaining('%'), findsNothing,
          reason: '进行中的任务不应显示进度百分比');
    });

    testWidgets('completed background task shows check icon', (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedOcrTask(id: 'done-1'),
      ]);

      expect(find.byIcon(Icons.check_circle), findsAtLeast(1),
          reason: '已完成的任务应显示完成图标');
      expect(find.text('已完成'), findsOneWidget);
    });

    // =========================================================================
    // No result text tests (requirement: remove result display)
    // =========================================================================
    testWidgets('background task does NOT show "识别结果" label', (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'OCR任务',
      );
      bgNotifier.setResult(taskId, '这是OCR识别出来的文字');
      bgNotifier.completeTask(taskId);

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

      // Tap to expand
      await tester.tap(find.text('OCR任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // "识别结果" label should NOT be visible (removed by requirements)
      expect(find.text('识别结果'), findsNothing,
          reason: '"识别结果"标签不应再显示');
      // The result text itself should NOT be visible
      expect(find.text('这是OCR识别出来的文字'), findsNothing,
          reason: '识别结果文字不应在卡片内显示');
    });

    // =========================================================================
    // Open file button for background tasks (requirement: like download tasks)
    // =========================================================================
    testWidgets('completed background task with file path shows Open File button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedOcrTask(
          id: 'done-file',
          title: '有文件的任务',
          downloadedFilePath: 'C:\\ocr\\result.txt',
        ),
      ]);

      // Tap to expand
      await tester.tap(find.text('有文件的任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsOneWidget,
          reason: '有下载文件路径的背景任务应显示"打开文件"按钮');
    });

    testWidgets('completed background task without file path hides Open File button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedOcrTask(
          id: 'done-no-file',
          title: '无文件任务',
          downloadedFilePath: null,
        ),
      ]);

      // Tap to expand
      await tester.tap(find.text('无文件任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '没有下载文件路径的背景任务不应显示"打开文件"按钮');
    });

    // =========================================================================
    // Status transition tests
    // =========================================================================
    testWidgets('task shows "已完成" when running task transitions to completed',
        (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '转换中的任务',
      );

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

      expect(find.text('转换中的任务'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);

      bgNotifier.completeTask(taskId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('转换中的任务'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsAtLeast(1));
    });

    testWidgets('task shows "失败" when running task transitions to failed',
        (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.asr,
        title: '转写任务',
      );

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

      expect(find.text('转写任务'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);

      bgNotifier.failTask(taskId, error: '转写失败: API错误');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('转写任务'), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsAtLeast(1));
    });

    testWidgets('background task open file button has adequate tap target',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedOcrTask(
          id: 'done-tap',
          title: '可点任务',
          downloadedFilePath: 'C:\\file.txt',
        ),
      ]);

      // Tap to expand
      await tester.tap(find.text('可点任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final textButton = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(textButton, findsOneWidget);

      final size = tester.getSize(textButton.first);
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '按钮高度应 >= 48（Material 最小触摸目标）');
    });
  });
}
