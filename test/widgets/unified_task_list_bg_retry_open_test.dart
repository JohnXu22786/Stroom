import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';

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

// =============================================================================
// Helpers to create test data
// =============================================================================

BackgroundTask _createFailedBgTask({
  required String id,
  BackgroundTaskType type = BackgroundTaskType.ocr,
  String title = '失败任务',
}) {
  return BackgroundTask(
    id: id,
    type: type,
    title: title,
    status: TaskStatus.failed,
    createdAt: DateTime(2025, 6, 1),
    completedAt: DateTime(2025, 6, 1, 0, 3),
    statusChangedAt: DateTime(2025, 6, 1, 0, 3),
    error: '处理失败',
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
  // Retry button for failed background tasks
  // ===========================================================================
  group('Failed Background Task - Retry button', () {
    testWidgets('failed background task shows retry button when expanded',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(id: 'fail-1', title: '失败任务测试'),
      ]);

      // Should show the failed task
      expect(find.text('失败任务测试'), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('失败任务测试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show retry button
      expect(find.text('重试'), findsOneWidget, reason: '失败的任务展开后应显示"重试"按钮');
    });

    testWidgets('retry button has refresh icon', (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(id: 'fail-icon', title: '失败重试'),
      ]);

      // Tap to expand
      await tester.tap(find.text('失败重试'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should have a refresh icon
      expect(find.byIcon(Icons.refresh), findsOneWidget,
          reason: '"重试"按钮应显示刷新图标');
    });

    testWidgets('retry button and delete button both visible for failed tasks',
        (tester) async {
      await pumpPageWithBackground(tester, [
        _createFailedBgTask(id: 'fail-both', title: '双重按钮'),
      ]);

      // Tap to expand
      await tester.tap(find.text('双重按钮'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both buttons should be present
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

      // Tap to expand
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

      // Tap to expand by tapping the title
      await tester.tap(find.text('已完成任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('重试'), findsNothing, reason: '已完成的任务不应显示"重试"按钮');
    });
  });

  // ===========================================================================
  // Open file button for completed background tasks
  // ===========================================================================
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

      // Tap to expand
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

      // Tap to expand
      await tester.tap(find.text('无文件的背景任务'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打开文件'), findsNothing,
          reason: '没有文件路径的背景任务不应显示"打开文件"按钮');
    });
  });

  // ===========================================================================
  // Open file button for completed synthesis tasks
  // ===========================================================================
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
      expect(find.text('已完成'), findsOneWidget);
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

      // The button should be tappable
      final btn = find.text('打开文件');
      expect(btn, findsOneWidget);

      // Tap and verify no crash
      await tester.tap(btn);
      await tester.pump();
      // No crash means success
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

  // ===========================================================================
  // Audio separation step labels
  // ===========================================================================
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

  // ===========================================================================
  // SynthesisTask model - downloadedFilePath field
  // ===========================================================================
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
}
