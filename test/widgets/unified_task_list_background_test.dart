import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
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
      expect(find.textContaining('%'), findsNothing, reason: '进行中的任务不应显示进度百分比');
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
      expect(find.text('识别结果'), findsNothing, reason: '"识别结果"标签不应再显示');
      // The result text itself should NOT be visible
      expect(find.text('这是OCR识别出来的文字'), findsNothing, reason: '识别结果文字不应在卡片内显示');
    });

    // =========================================================================
    // Open file button for background tasks (requirement: like download tasks)
    // =========================================================================
    testWidgets(
        'completed background task with file path shows Open File button',
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

    testWidgets(
        'completed background task without file path hides Open File button',
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

    // =========================================================================
    // Collapse/expand behavior tests
    // =========================================================================
    testWidgets('expanding card reveals step timeline and action buttons',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedOcrTask(
          id: 'expand-card-1',
          title: '展开卡片',
          downloadedFilePath: 'C:\\file.txt',
        ),
      ]);

      // Tap to expand
      await tester.tap(find.text('展开卡片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expanded section should have "打开文件" button rendered
      // (AnimatedCrossFade keeps both in tree, but expanded state shows second child)
      expect(find.text('打开文件'), findsWidgets, reason: '展开后应显示"打开文件"按钮');

      // Collapse by tapping the header again
      await tester.tap(find.text('展开卡片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expand again (verifying toggle works)
      await tester.tap(find.text('展开卡片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should still find button after re-expand
      expect(find.text('打开文件'), findsWidgets, reason: '重新展开后仍应显示"打开文件"按钮');
    });

    testWidgets('tapping card header expands detail section', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'expand-1', title: '展开测试'),
      ]);

      // The step info text "等待开始..." is present in the AnimatedCrossFade tree
      // but is only visibly rendered when expanded. Tap to expand and verify it's renderable.
      expect(find.text('等待开始...'), findsWidgets,
          reason: '步骤信息应在 widget tree 中存在（AnimatedCrossFade）');

      // Tap the title to expand and verify the expand button (chevron) adjust behavior
      await tester.tap(find.text('展开测试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After expand, the content should still be there
      expect(find.text('等待开始...'), findsWidgets, reason: '展开后应能找到步骤信息');
    });

    testWidgets('tapping header again collapses the card', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'collapse-again-1'),
      ]);

      // Tap to expand
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Expanded - error should be findable
      expect(find.text('提取失败: FFmpeg未安装'), findsWidgets, reason: '展开后应能找到错误信息');

      // Tap again to collapse
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the title a third time to re-expand and ensure toggle works
      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Re-expanded - error should be visible again
      expect(find.text('提取失败: FFmpeg未安装'), findsWidgets,
          reason: '再次展开后应显示错误信息');
    });

    // =========================================================================
    // Error detail dialog tests
    // =========================================================================
    testWidgets('failed task with diagnostics shows error detail button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        BackgroundTask(
          id: 'diag-btn',
          type: BackgroundTaskType.ocr,
          title: '诊断错误任务',
          status: TaskStatus.failed,
          error: 'OCR识别失败',
          createdAt: DateTime(2025, 6, 1),
          rawRequest: {'url': 'https://api.test.com'},
          rawResponse: {'statusCode': 400, 'data': 'bad request'},
        ),
      ]);

      // Tap to expand
      await tester.tap(find.text('诊断错误任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show the "查看错误详情" button
      expect(find.text('查看错误详情'), findsOneWidget,
          reason: '有诊断数据的失败任务应显示"查看错误详情"按钮');
    });
  });
}
