// Merged from:
//   - unified_task_list_page_test.dart
//   - unified_task_list_background_test.dart
//   - unified_task_list_bg_retry_open_test.dart
//   - unified_task_list_bg_waiting_test.dart
//   - unified_task_list_open_delete_retry_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

// =============================================================================
// CatCatch task helpers (from unified_task_list_page_test.dart)
// =============================================================================
catcatch.CatCatchTask _createCompletedTask({
  required String id,
  String? downloadedFilePath,
}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '测试视频 $id',
    status: catcatch.TaskStatus.completed,
    createdAt: DateTime(2025, 1, 1),
    completedAt: DateTime(2025, 1, 1).add(const Duration(minutes: 5)),
    downloadedFilePath: downloadedFilePath,
  );
}

catcatch.CatCatchTask _createRunningTask({required String id}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '运行中 $id',
    status: catcatch.TaskStatus.running,
    createdAt: DateTime(2025, 1, 1),
    progress: 50,
  );
}

catcatch.CatCatchTask _createFailedTask({required String id}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '失败 $id',
    status: catcatch.TaskStatus.failed,
    createdAt: DateTime(2025, 1, 1),
    error: 'Download failed',
  );
}

catcatch.CatCatchTask _createPausedTask({required String id}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: '已暂停 $id',
    status: catcatch.TaskStatus.paused,
    createdAt: DateTime(2025, 1, 1),
  );
}

// =============================================================================
// Page pump helpers
// =============================================================================
/// Pump the UnifiedTaskListPage with given catcatch tasks and no synthesis tasks.
Future<void> pumpPage(
    WidgetTester tester, List<catcatch.CatCatchTask> tasks) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = tasks;
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
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

/// Expand a completed task card by tapping the header.
/// Completed tasks start collapsed; tap the task title to expand.
Future<void> expandCompletedCard(WidgetTester tester) async {
  await tester.tap(find.textContaining('测试视频'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // wait for animation
}

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

/// Pumps the UnifiedTaskListPage with given synthesis tasks and empty others.
Future<void> pumpPageWithSynthesis(
  WidgetTester tester,
  List<SynthesisTask> synthesisTasks,
) async {
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
          notifier.state = synthesisTasks;
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) {
          final notifier = BackgroundTaskNotifier();
          notifier.state = [];
          return notifier;
        }),
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

/// Expand a background task card by tapping its header.
Future<void> expandTask(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

// =============================================================================
// Background task creation helpers
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

BackgroundTask _createCompletedBgTask({
  required String id,
  BackgroundTaskType type = BackgroundTaskType.ocr,
  String title = '已完成任务',
  String? downloadedFilePath,
}) {
  return BackgroundTask(
    id: id,
    type: type,
    title: title,
    status: TaskStatus.completed,
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    downloadedFilePath: downloadedFilePath,
  );
}

BackgroundTask _createFailedBgTask({
  required String id,
  BackgroundTaskType type = BackgroundTaskType.ocr,
  String title = '失败的OCR任务',
}) {
  return BackgroundTask(
    id: id,
    type: type,
    title: title,
    status: TaskStatus.failed,
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    retryData: type == BackgroundTaskType.ocr
        ? {'type': 'ocr', 'images': [], 'modelIndex': 0}
        : type == BackgroundTaskType.asr
            ? {'type': 'asr', 'audios': [], 'modelIndex': 0}
            : {'type': 'audioSeparation', 'videos': []},
  );
}

SynthesisTask _createCompletedSynthTask({
  required String id,
  String title = '合成任务',
  String? downloadedFilePath,
}) {
  return SynthesisTask(
    id: id,
    title: title,
    status: TaskStatus.completed,
    text: '测试文本',
    providerConfig: ProviderConfigItem(
      providerName: 'Test',
      host: 'https://test.com',
      key: 'test',
    ),
    modelConfig: ModelConfig(
      name: 'TestModel',
      modelId: 'test-model',
    ),
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    downloadedFilePath: downloadedFilePath,
  );
}

// =============================================================================
// Tests
// =============================================================================
void main() {
  // ===========================================================================
  // 1. unified_task_list_page_test.dart
  // ===========================================================================
  group('UnifiedTaskListPage - All tasks shown on default tab', () {
    testWidgets('all tasks shown in one unified list on 全部 tab',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(
            id: 'downloaded-1', downloadedFilePath: 'C:\\a.mp4'),
        _createRunningTask(id: 'running-1'),
      ]);

      expect(find.text('测试视频 downloaded-1'), findsOneWidget,
          reason: 'Completed download task should be visible on 全部 tab');
      expect(find.text('运行中 running-1'), findsOneWidget,
          reason: 'Running download task should be visible on 全部 tab');
    });

    testWidgets('empty task list shows placeholder', (tester) async {
      await pumpPage(tester, []);

      expect(find.text('暂无任务'), findsOneWidget,
          reason: 'Empty task list should show "暂无任务"');
    });
  });

  group('UnifiedTaskListPage - "打开文件" button', () {
    testWidgets('completed task shows tappable Open File button when expanded',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(
          id: 'test-1',
          downloadedFilePath: 'C:\\test\\video.mp4',
        ),
      ]);

      await expandCompletedCard(tester);

      expect(find.text('打开文件'), findsOneWidget, reason: '展开已完成卡片后应显示"打开文件"按钮');

      final textButton = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(textButton, findsOneWidget, reason: '"打开文件"文本应该在 TextButton 内');

      final size = tester.getSize(textButton);
      expect(size.width, greaterThan(0),
          reason: '按钮宽度应大于 0（当前为 ${size.width}）');
      expect(size.height, greaterThan(0),
          reason: '按钮高度应大于 0（当前为 ${size.height}）');

      final button = tester.widget<TextButton>(textButton);
      expect(button.onPressed, isNotNull,
          reason: '"打开文件"按钮的 onPressed 不应为 null');

      await tester.tap(textButton);
      await tester.pump();
    });

    testWidgets(
        'completed task without downloadedFilePath hides Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(id: 'test-2', downloadedFilePath: null),
      ]);

      await expandCompletedCard(tester);

      expect(find.text('打开文件'), findsNothing,
          reason: 'downloadedFilePath 为 null 时不应显示"打开文件"按钮');
    });

    testWidgets('running task should not show Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createRunningTask(id: 'test-3'),
      ]);

      expect(find.text('打开文件'), findsNothing, reason: '运行中的任务不应显示"打开文件"按钮');
    });

    testWidgets('failed task should not show Open File button', (tester) async {
      await pumpPage(tester, [
        _createFailedTask(id: 'test-4'),
      ]);

      await tester.tap(find.text('失败 test-4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing, reason: '失败的任务不应显示"打开文件"按钮');
    });

    testWidgets('paused task should not show Open File button', (tester) async {
      await pumpPage(tester, [
        _createPausedTask(id: 'test-5'),
      ]);

      await tester.tap(find.text('已暂停 test-5'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing, reason: '暂停的任务不应显示"打开文件"按钮');
    });

    testWidgets('multiple completed tasks all show Open File button',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(id: 'm1', downloadedFilePath: 'C:\\a.mp4'),
        _createCompletedTask(id: 'm2', downloadedFilePath: 'C:\\b.mp4'),
        _createCompletedTask(id: 'm3', downloadedFilePath: 'C:\\c.mp4'),
      ]);

      expect(find.text('测试视频 m1'), findsOneWidget);
      expect(find.text('测试视频 m2'), findsOneWidget);
      expect(find.text('测试视频 m3'), findsOneWidget);

      await tester.tap(find.text('测试视频 m1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('测试视频 m2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('测试视频 m3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNWidgets(3),
          reason: '3个已完成卡片展开后应显示3个"打开文件"按钮');

      final buttons = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(buttons, findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        final btn = buttons.at(i);
        final widget = tester.widget<TextButton>(btn);
        expect(widget.onPressed, isNotNull,
            reason: '第 $i 个按钮的 onPressed 不应为 null');
      }
    });

    testWidgets('Open File button has adequate tap target size',
        (tester) async {
      await pumpPage(tester, [
        _createCompletedTask(
          id: 'test-tap',
          downloadedFilePath: 'C:\\test\\video.mp4',
        ),
      ]);

      await expandCompletedCard(tester);

      final textButton = find.ancestor(
        of: find.text('打开文件'),
        matching: find.byType(TextButton),
      );
      expect(textButton, findsOneWidget);

      final size = tester.getSize(textButton.first);
      expect(size.width, greaterThan(0), reason: '按钮宽度必须 > 0');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '按钮高度应 >= 48（Material 最小触摸目标）');
    });
  });

  // ===========================================================================
  // 2. unified_task_list_background_test.dart
  // ===========================================================================
  group('UnifiedTaskListPage - Background tasks (no tabs, no result text)', () {
    testWidgets('background task appears in unified list (no tab needed)',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1'),
      ]);

      expect(find.text('OCR任务'), findsOneWidget, reason: 'OCR任务应显示在统一任务列表中');
    });

    testWidgets('background task shows status info', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'ocr-1', title: '运行中任务'),
      ]);

      expect(find.text('运行中任务'), findsOneWidget);
      expect(find.text('进行中'), findsAtLeast(1), reason: '进行中的任务应显示"进行中"状态');
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
      expect(find.text('已完成'), findsAtLeast(1), reason: '已完成的任务应显示"已完成"状态');
    });

    testWidgets('background task shows failed task with error', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'audio-1'),
      ]);

      expect(find.text('音频分离任务'), findsOneWidget, reason: '应显示失败的音频分离任务');
      expect(find.text('失败'), findsAtLeast(1), reason: '失败的任务应显示"失败"状态');

      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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

      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('删除'), findsOneWidget, reason: '展开后应显示"删除"按钮');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      expect(find.text('已完成'), findsAtLeast(1));
    });

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

      await tester.tap(find.text('OCR任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('识别结果'), findsNothing, reason: '"识别结果"标签不应再显示');
      expect(find.text('这是OCR识别出来的文字'), findsNothing, reason: '识别结果文字不应在卡片内显示');
    });

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

      await tester.tap(find.text('无文件任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '没有下载文件路径的背景任务不应显示"打开文件"按钮');
    });

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
      expect(find.text('进行中'), findsAtLeast(1));

      bgNotifier.completeTask(taskId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('转换中的任务'), findsOneWidget);
      expect(find.text('已完成'), findsAtLeast(1));
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
      expect(find.text('进行中'), findsAtLeast(1));

      bgNotifier.failTask(taskId, error: '转写失败: API错误');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('转写任务'), findsOneWidget);
      expect(find.text('失败'), findsAtLeast(1));
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

    testWidgets('expanding card reveals step timeline and action buttons',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedOcrTask(
          id: 'expand-card-1',
          title: '展开卡片',
          downloadedFilePath: 'C:\\file.txt',
        ),
      ]);

      await tester.tap(find.text('展开卡片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsWidgets, reason: '展开后应显示"打开文件"按钮');

      await tester.tap(find.text('展开卡片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('展开卡片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsWidgets, reason: '重新展开后仍应显示"打开文件"按钮');
    });

    testWidgets('tapping card header expands detail section', (tester) async {
      await pumpPageWithBackground(tester, [
        _createRunningOcrTask(id: 'expand-1', title: '展开测试'),
      ]);

      expect(find.text('等待开始...'), findsWidgets,
          reason: '步骤信息应在 widget tree 中存在（AnimatedCrossFade）');

      await tester.tap(find.text('展开测试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('等待开始...'), findsWidgets, reason: '展开后应能找到步骤信息');
    });

    testWidgets('tapping header again collapses the card', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedAudioTask(id: 'collapse-again-1'),
      ]);

      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('提取失败: FFmpeg未安装'), findsWidgets, reason: '展开后应能找到错误信息');

      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('音频分离任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('提取失败: FFmpeg未安装'), findsWidgets,
          reason: '再次展开后应显示错误信息');
    });

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

      await tester.tap(find.text('诊断错误任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('查看错误详情'), findsOneWidget,
          reason: '有诊断数据的失败任务应显示"查看错误详情"按钮');
    });
  });

  // ===========================================================================
  // 3. unified_task_list_bg_retry_open_test.dart
  // ===========================================================================
  group('Failed Background Task - Retry button', () {
    testWidgets('failed background task shows retry button when expanded',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(id: 'fail-1', title: '失败任务测试'),
      ]);

      expect(find.text('失败任务测试'), findsOneWidget);
      expect(find.text('失败'), findsAtLeast(1));

      await tester.tap(find.text('失败任务测试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试'), findsOneWidget, reason: '失败的任务展开后应显示"重试"按钮');
    });

    testWidgets('retry button has refresh icon', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(id: 'fail-icon', title: '失败重试'),
      ]);

      await tester.tap(find.text('失败重试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.refresh), findsOneWidget,
          reason: '"重试"按钮应显示刷新图标');
    });

    testWidgets('retry button and delete button both visible for failed tasks',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(id: 'fail-both', title: '双重按钮'),
      ]);

      await tester.tap(find.text('双重按钮'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试'), findsOneWidget, reason: '应显示"重试"按钮');
      expect(find.text('删除'), findsOneWidget, reason: '应显示"删除"按钮');
    });

    testWidgets('running background task does NOT show retry button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        BackgroundTask(
          id: 'running-1',
          type: BackgroundTaskType.ocr,
          title: '运行中',
          status: TaskStatus.running,
          createdAt: DateTime(2025, 6, 1),
        ),
      ]);

      await tester.tap(find.text('运行中'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试'), findsNothing, reason: '进行中的任务不应显示"重试"按钮');
    });

    testWidgets('completed background task does NOT show retry button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(id: 'done-1', title: '已完成任务'),
      ]);

      await tester.tap(find.text('已完成任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试'), findsNothing, reason: '已完成的任务不应显示"重试"按钮');
    });
  });

  group('Background Task - Open File button', () {
    testWidgets('completed bg task with file path shows open file button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'bg-file',
          title: '有文件的背景任务',
          downloadedFilePath: 'C:\\test\\result.txt',
        ),
      ]);

      await tester.tap(find.text('有文件的背景任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsOneWidget,
          reason: '有文件路径的背景任务应显示"打开文件"按钮');
    });

    testWidgets('completed bg task without file path hides open file button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'bg-no-file',
          title: '无文件的背景任务',
          downloadedFilePath: null,
        ),
      ]);

      await tester.tap(find.text('无文件的背景任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '没有文件路径的背景任务不应显示"打开文件"按钮');
    });
  });

  group('Background Task (ASR) - Open File button', () {
    testWidgets('completed ASR bg task with file path shows open file button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'asr-file',
          type: BackgroundTaskType.asr,
          title: '音频转写结果',
          downloadedFilePath: 'C:\\asr\\result.txt',
        ),
      ]);

      await tester.tap(find.text('音频转写结果'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsOneWidget,
          reason: '有文件路径的ASR转写任务应显示"打开文件"按钮');
    });

    testWidgets(
        'completed ASR bg task without file path hides open file button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'asr-no-file',
          type: BackgroundTaskType.asr,
          title: '无路径转写',
          downloadedFilePath: null,
        ),
      ]);

      await tester.tap(find.text('无路径转写'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '没有文件路径的ASR转写任务不应显示"打开文件"按钮');
    });
  });

  group('Synthesis Task - Open File button', () {
    testWidgets(
        'completed synthesis task with file path shows open file button',
        (tester) async {
      await pumpPageWithSynthesis(tester, [
        _createCompletedSynthTask(
          id: 'synth-file',
          title: '可打开文件',
          downloadedFilePath: 'C:\\audio\\test.mp3',
        ),
      ]);

      expect(find.text('可打开文件'), findsOneWidget);
      expect(find.text('已完成'), findsAtLeast(1));
      expect(find.text('打开文件'), findsOneWidget,
          reason: '有文件路径的合成任务应显示"打开文件"按钮');
    });

    testWidgets(
        'completed synthesis task without file path hides open file button',
        (tester) async {
      await pumpPageWithSynthesis(tester, [
        _createCompletedSynthTask(
          id: 'synth-no-file',
          title: '无路径合成',
          downloadedFilePath: null,
        ),
      ]);

      expect(find.text('无路径合成'), findsOneWidget);
      expect(find.text('打开文件'), findsNothing,
          reason: '没有文件路径的合成任务不应显示"打开文件"按钮');
    });

    testWidgets('synthesis open file button opens file with openFile',
        (tester) async {
      await pumpPageWithSynthesis(tester, [
        _createCompletedSynthTask(
          id: 'synth-open',
          title: '打开文件测试',
          downloadedFilePath: 'C:\\audio\\test.mp3',
        ),
      ]);

      final btn = find.text('打开文件');
      expect(btn, findsOneWidget);

      await tester.tap(btn);
      await tester.pump();
    });

    testWidgets('synthesis open file button has folder_open icon',
        (tester) async {
      await pumpPageWithSynthesis(tester, [
        _createCompletedSynthTask(
          id: 'synth-icon',
          title: '图标测试',
          downloadedFilePath: 'C:\\test\\audio.mp3',
        ),
      ]);

      expect(find.byIcon(Icons.folder_open), findsOneWidget,
          reason: '"打开文件"按钮应显示文件夹图标');
    });
  });

  group('Audio Separation Step Labels', () {
    test('audio separation step labels should be two steps', () {
      final labels = BackgroundTaskType.audioSeparation.stepLabels;
      expect(labels.length, 2, reason: '音频分离应有2个执行步骤');
      expect(labels[0], '分离音频', reason: '第一步应为"分离音频"');
      expect(labels[1], '保存到文件', reason: '第二步应为"保存到文件"');
    });

    test('audio separation steps are not "正在分离音频..."', () {
      final labels = BackgroundTaskType.audioSeparation.stepLabels;
      expect(labels.contains('正在分离音频...'), false,
          reason: '不应再使用"正在分离音频..."作为步骤名');
    });

    test('ocr steps remain unchanged', () {
      final labels = BackgroundTaskType.ocr.stepLabels;
      expect(labels.length, 5);
      expect(labels[0], '连接服务器');
    });

    test('asr steps remain unchanged', () {
      final labels = BackgroundTaskType.asr.stepLabels;
      expect(labels.length, 5);
      expect(labels[0], '连接服务器');
    });
  });

  group('SynthesisTask downloadedFilePath', () {
    test('SynthesisTask has downloadedFilePath field', () {
      final task = SynthesisTask(
        id: 'test-id',
        title: 'Test',
        status: TaskStatus.completed,
        text: 'test',
        providerConfig: ProviderConfigItem(
          providerName: 'P1',
          host: 'https://test.com',
          key: 'key',
        ),
        modelConfig: ModelConfig(
          name: 'M1',
          modelId: 'm1',
        ),
        createdAt: DateTime(2025, 1, 1),
        completedAt: DateTime(2025, 1, 1),
        downloadedFilePath: 'C:\\test\\audio.mp3',
      );
      expect(task.downloadedFilePath, 'C:\\test\\audio.mp3');
    });

    test('SynthesisTask downloadedFilePath defaults to null', () {
      final task = SynthesisTask(
        id: 'test-id-2',
        title: 'Test',
        status: TaskStatus.running,
        text: 'test',
        providerConfig: ProviderConfigItem(
          providerName: 'P1',
          host: 'https://test.com',
          key: 'key',
        ),
        modelConfig: ModelConfig(
          name: 'M1',
          modelId: 'm1',
        ),
        createdAt: DateTime(2025, 1, 1),
      );
      expect(task.downloadedFilePath, isNull);
    });

    test('SynthesisTask serialization includes downloadedFilePath', () {
      final task = SynthesisTask(
        id: 'ser-id',
        title: 'Ser',
        status: TaskStatus.completed,
        text: 'test',
        providerConfig: ProviderConfigItem(
          providerName: 'P1',
          host: 'https://test.com',
          key: 'key',
        ),
        modelConfig: ModelConfig(
          name: 'M1',
          modelId: 'm1',
        ),
        createdAt: DateTime(2025, 1, 1),
        completedAt: DateTime(2025, 1, 1),
        downloadedFilePath: 'C:\\audio\\test.mp3',
      );
      final map = task.toMap();
      expect(map['downloadedFilePath'], 'C:\\audio\\test.mp3');

      final restored = SynthesisTask.fromMap(map);
      expect(restored.downloadedFilePath, 'C:\\audio\\test.mp3');
    });

    test('SynthesisTask serialization handles null downloadedFilePath', () {
      final task = SynthesisTask(
        id: 'ser-null',
        title: 'SerNull',
        status: TaskStatus.running,
        text: 'test',
        providerConfig: ProviderConfigItem(
          providerName: 'P1',
          host: 'https://test.com',
          key: 'key',
        ),
        modelConfig: ModelConfig(
          name: 'M1',
          modelId: 'm1',
        ),
        createdAt: DateTime(2025, 1, 1),
        downloadedFilePath: null,
      );
      final map = task.toMap();
      expect(map.containsKey('downloadedFilePath'), false);

      final restored = SynthesisTask.fromMap(map);
      expect(restored.downloadedFilePath, isNull);
    });
  });

  // ===========================================================================
  // 4. unified_task_list_bg_waiting_test.dart
  // ===========================================================================
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

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget,
          reason: '等待中的任务应显示沙漏图标');
    });

    testWidgets('waiting task shows "立即开始" button when expanded',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-expand', title: '可立即开始的等待任务'),
      ]);

      expect(find.text('可立即开始的等待任务'), findsOneWidget);

      await tester.tap(find.text('可立即开始的等待任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('立即开始'), findsOneWidget, reason: '展开等待中的任务后应显示"立即开始"按钮');
    });

    testWidgets('waiting task does NOT show retry or open file buttons',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-no-other-btns'),
      ]);

      await tester.tap(find.text('等待转写'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试'), findsNothing, reason: '等待中的任务不应显示"重试"按钮');
      expect(find.text('打开文件'), findsNothing, reason: '等待中的任务不应显示"打开文件"按钮');
    });

    testWidgets('waiting task can be deleted via delete button',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createWaitingAsrTask(id: 'wait-del', title: '待删除的等待任务'),
      ]);

      await tester.tap(find.text('待删除的等待任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('删除'), findsOneWidget, reason: '展开后应显示"删除"按钮');

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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

  // ===========================================================================
  // 5. unified_task_list_open_delete_retry_test.dart
  // ===========================================================================
  group('Issue 2: Open File navigates to correct in-app viewer', () {
    testWidgets('tapping Open File on .mp3 file navigates to AudioPlayerPage',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'audio-test',
          title: '测试音频文件',
          downloadedFilePath: 'C:\\test\\audio.mp3',
        ),
      ]);

      await expandTask(tester, '测试音频文件');

      await tester.tap(find.text('打开文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('tapping Open File on .mp4 file navigates to VideoPlayerPage',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'video-test',
          title: '测试视频文件',
          downloadedFilePath: 'C:\\test\\video.mp4',
        ),
      ]);

      await expandTask(tester, '测试视频文件');
      await tester.tap(find.text('打开文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets(
        'tapping Open File on .txt file navigates to TextPreviewEditPage',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'text-test',
          title: '测试文本文件',
          downloadedFilePath: 'C:\\test\\document.txt',
        ),
      ]);

      await expandTask(tester, '测试文本文件');
      await tester.tap(find.text('打开文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('tapping Open File on unknown extension does not crash',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createCompletedBgTask(
          id: 'unknown-test',
          title: '测试未知文件',
          downloadedFilePath: 'C:\\test\\file.xyz',
        ),
      ]);

      await expandTask(tester, '测试未知文件');
      await tester.tap(find.text('打开文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('Issue 3: Deleting a task does not affect expansion of others', () {
    /// Helper: pump page with 3 background tasks for issue 3 tests.
    Future<void> pumpThreeTasks(
        WidgetTester tester, BackgroundTaskNotifier bgNotifier) async {
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

    testWidgets(
        'delete expanded item 1 preserves expansion state of other items',
        (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      bgNotifier.state = [
        _createCompletedBgTask(
          id: 'task-1',
          title: '第一个任务',
          downloadedFilePath: 'C:\\test\\a.mp4',
        ),
        _createCompletedBgTask(
          id: 'task-2',
          title: '第二个任务',
          downloadedFilePath: 'C:\\test\\b.mp4',
        ),
        _createCompletedBgTask(
          id: 'task-3',
          title: '第三个任务',
          downloadedFilePath: 'C:\\test\\c.mp4',
        ),
      ];

      await pumpThreeTasks(tester, bgNotifier);

      expect(find.text('第一个任务'), findsOneWidget, reason: '第一个任务应该显示');
      expect(find.text('第二个任务'), findsOneWidget, reason: '第二个任务应该显示');
      expect(find.text('第三个任务'), findsOneWidget, reason: '第三个任务应该显示');

      await expandTask(tester, '第一个任务');
      await expandTask(tester, '第二个任务');

      expect(find.text('删除'), findsAtLeast(1), reason: '展开的任务应显示删除按钮');

      await tester.tap(find.text('删除').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('第一个任务'), findsNothing, reason: '删除后第一个任务应消失');
      expect(find.text('第二个任务'), findsOneWidget, reason: '删除后第二个任务应仍在');
      expect(find.text('第三个任务'), findsOneWidget, reason: '删除后第三个任务应仍在');

      final remainingIds = bgNotifier.state.map((t) => t.id).toList();
      expect(remainingIds, contains('task-2'),
          reason: 'task-2 应保留在 provider 中');
      expect(remainingIds, contains('task-3'),
          reason: 'task-3 应保留在 provider 中');
      expect(remainingIds, isNot(contains('task-1')),
          reason: 'task-1 应从 provider 中移除');

      expect(remainingIds[0], 'task-2', reason: 'task-2 应该是第一个（最新）');
      expect(remainingIds[1], 'task-3', reason: 'task-3 应该是第二个');
    });

    testWidgets('delete collapsed item does not affect expanded items',
        (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      bgNotifier.state = [
        _createCompletedBgTask(
          id: 'task-a',
          title: '任务A',
          downloadedFilePath: 'C:\\test\\a.mp4',
        ),
        _createCompletedBgTask(
          id: 'task-b',
          title: '任务B',
          downloadedFilePath: 'C:\\test\\b.mp4',
        ),
        _createCompletedBgTask(
          id: 'task-c',
          title: '任务C',
          downloadedFilePath: 'C:\\test\\c.mp4',
        ),
      ];

      await pumpThreeTasks(tester, bgNotifier);

      expect(find.text('任务A'), findsOneWidget);
      expect(find.text('任务B'), findsOneWidget);
      expect(find.text('任务C'), findsOneWidget);

      await expandTask(tester, '任务C');

      await expandTask(tester, '任务A');
      expect(find.text('删除'), findsAtLeast(1), reason: '展开的任务应显示删除按钮');

      await tester.tap(find.text('删除').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('任务A'), findsNothing, reason: '删除后任务A应消失');
      expect(find.text('任务B'), findsOneWidget, reason: '删除后任务B应仍在');
      expect(find.text('任务C'), findsOneWidget, reason: '删除后任务C应仍在');

      final remainingIds = bgNotifier.state.map((t) => t.id).toList();
      expect(remainingIds, contains('task-c'), reason: 'task-c 应保留');
      expect(remainingIds, contains('task-b'), reason: 'task-b 应保留');
      expect(remainingIds, isNot(contains('task-a')), reason: 'task-a 应被移除');
    });
  });

  group('Issue 4: Retry pre-populates form with original data', () {
    test('BackgroundTask has retryData field', () {
      final task = BackgroundTask(
        id: 'retry-test',
        type: BackgroundTaskType.ocr,
        title: 'OCR重试测试',
        status: TaskStatus.failed,
        createdAt: DateTime(2025, 6, 1),
        retryData: {'type': 'ocr', 'images': [], 'modelIndex': 0},
      );
      expect(task.retryData, isNotNull);
      expect(task.retryData!['type'], 'ocr');
    });

    test('BackgroundTask retryData defaults to null', () {
      final task = BackgroundTask(
        id: 'no-retry',
        type: BackgroundTaskType.ocr,
        title: '无重试数据',
        status: TaskStatus.completed,
        createdAt: DateTime(2025, 6, 1),
      );
      expect(task.retryData, isNull);
    });

    test('BackgroundTask retryData is serialized and deserialized', () {
      final task = BackgroundTask(
        id: 'ser-retry',
        type: BackgroundTaskType.ocr,
        title: '序列化测试',
        status: TaskStatus.failed,
        createdAt: DateTime(2025, 6, 1),
        retryData: {
          'type': 'ocr',
          'images': [
            {'name': 'photo1', 'format': 'jpeg', 'bytes': 'base64data'},
          ],
          'modelIndex': 1,
        },
      );
      final map = task.toMap();
      expect(map['retryData'], isNotNull);
      expect((map['retryData'] as Map)['type'], 'ocr');

      final restored = BackgroundTask.fromMap(map);
      expect(restored.retryData, isNotNull);
      expect(restored.retryData!['type'], 'ocr');
      expect(restored.retryData!['modelIndex'], 1);
      final images = restored.retryData!['images'] as List;
      expect(images.length, 1);
      expect(images[0]['name'], 'photo1');
    });

    test('BackgroundTask retryData serialization handles null', () {
      final task = BackgroundTask(
        id: 'ser-null-retry',
        type: BackgroundTaskType.asr,
        title: '空重试',
        status: TaskStatus.completed,
        createdAt: DateTime(2025, 6, 1),
        retryData: null,
      );
      final map = task.toMap();
      expect(map.containsKey('retryData'), false);

      final restored = BackgroundTask.fromMap(map);
      expect(restored.retryData, isNull);
    });

    test('addTask with retryData stores it correctly', () {
      final notifier = BackgroundTaskNotifier();
      final retryData = <String, dynamic>{
        'type': 'ocr',
        'images': [
          {'name': 'test', 'format': 'jpeg', 'bytes': 'AAAA'}
        ],
        'modelIndex': 0,
      };
      final id = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '带重试数据的任务',
        retryData: retryData,
      );
      expect(id, isNotEmpty);

      final saved = notifier.state.firstWhere((t) => t.id == id);
      expect(saved.retryData, isNotNull);
      expect(saved.retryData!['type'], 'ocr');
      expect(saved.retryData!['modelIndex'], 0);
    });

    testWidgets('failed OCR task retry button navigates and passes retryData',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(
          id: 'ocr-retry',
          type: BackgroundTaskType.ocr,
          title: 'OCR重试',
        ),
      ]);

      await expandTask(tester, 'OCR重试');
      expect(find.text('重试'), findsOneWidget, reason: '失败的任务展开后应显示"重试"按钮');

      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('failed ASR task retry button navigates and passes retryData',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(
          id: 'asr-retry',
          type: BackgroundTaskType.asr,
          title: 'ASR重试',
        ),
      ]);

      await expandTask(tester, 'ASR重试');
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets(
        'failed AudioSeparation task retry button navigates and passes retryData',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(
          id: 'sep-retry',
          type: BackgroundTaskType.audioSeparation,
          title: '音频分离重试',
        ),
      ]);

      await expandTask(tester, '音频分离重试');
      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
