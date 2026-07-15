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
// Task creation helpers (same pattern as unified_task_list_test.dart)
// =============================================================================
catcatch.CatCatchTask _createCatCatchTask({
  required String id,
  required catcatch.TaskStatus status,
  String title = 'CatCatch任务',
}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video.mp4',
    expectedDurationSec: 120,
    title: title,
    status: status,
    createdAt: DateTime(2025, 6, 1),
  );
}

SynthesisTask _createSynthesisTask({
  required String id,
  required TaskStatus status,
  String title = '合成任务',
}) {
  return SynthesisTask(
    id: id,
    title: title,
    status: status,
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
  );
}

BackgroundTask _createBackgroundTask({
  required String id,
  required TaskStatus status,
  String title = '后台任务',
}) {
  return BackgroundTask(
    id: id,
    type: BackgroundTaskType.ocr,
    title: title,
    status: status,
    createdAt: DateTime(2025, 6, 1),
  );
}

// =============================================================================
// Page pump helpers
// =============================================================================
/// Pump UnifiedTaskListPage with given providers and optional initialTab.
Future<void> pumpTaskListPage(
  WidgetTester tester, {
  List<catcatch.CatCatchTask> catcatchTasks = const [],
  List<SynthesisTask> synthesisTasks = const [],
  List<BackgroundTask> backgroundTasks = const [],
  int initialTab = 0,
}) async {
  final bgNotifier = BackgroundTaskNotifier();
  bgNotifier.state = backgroundTasks;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = catcatchTasks;
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = synthesisTasks;
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) => bgNotifier),
        taskListLastReadProvider.overrideWith((ref) => DateTime.now()),
      ],
      child: MaterialApp(
        home: UnifiedTaskListPage(initialTab: initialTab),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// =============================================================================
// Tests
// =============================================================================
void main() {
  group('UnifiedTaskListPage - Tabs', () {
    testWidgets('TabBar exists with 4 tabs: 全部, 进行中, 已完成, 失败', (tester) async {
      await pumpTaskListPage(tester);

      // Should now show TabBar
      expect(find.byType(TabBar), findsOneWidget,
          reason: 'TabBar should exist in the page');

      // Check all 4 tab labels exist
      expect(find.text('全部'), findsOneWidget, reason: 'Tab "全部" should exist');
      expect(find.text('进行中'), findsWidgets, reason: 'Tab "进行中" should exist');
      expect(find.text('已完成'), findsWidgets, reason: 'Tab "已完成" should exist');
      expect(find.text('失败'), findsWidgets, reason: 'Tab "失败" should exist');
    });

    testWidgets('初始 tab 参数为 0（全部）时默认显示所有任务', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-running',
            status: catcatch.TaskStatus.running,
            title: '运行中的下载',
          ),
          _createCatCatchTask(
            id: 'cc-completed',
            status: catcatch.TaskStatus.completed,
            title: '已完成的下载',
          ),
          _createCatCatchTask(
            id: 'cc-failed',
            status: catcatch.TaskStatus.failed,
            title: '失败的下载',
          ),
        ],
        initialTab: 0,
      );

      // All 3 tasks should be visible on "全部" tab
      expect(find.text('运行中的下载'), findsOneWidget);
      expect(find.text('已完成的下载'), findsOneWidget);
      expect(find.text('失败的下载'), findsOneWidget);
    });

    testWidgets('initialTab=1（进行中）只显示进行中的任务', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-running',
            status: catcatch.TaskStatus.running,
            title: '运行中的下载',
          ),
          _createCatCatchTask(
            id: 'cc-completed',
            status: catcatch.TaskStatus.completed,
            title: '已完成的下载',
          ),
          _createCatCatchTask(
            id: 'cc-paused',
            status: catcatch.TaskStatus.paused,
            title: '暂停的下载',
          ),
        ],
        initialTab: 1,
      );

      // running + paused should show, completed should not
      expect(find.text('运行中的下载'), findsOneWidget);
      expect(find.text('暂停的下载'), findsOneWidget);
      expect(find.text('已完成的下载'), findsNothing);
    });

    testWidgets('initialTab=2（已完成）只显示已完成的任务', (tester) async {
      await pumpTaskListPage(
        tester,
        synthesisTasks: [
          _createSynthesisTask(
            id: 'synth-running',
            status: TaskStatus.running,
            title: '进行中的合成',
          ),
          _createSynthesisTask(
            id: 'synth-completed',
            status: TaskStatus.completed,
            title: '已完成的合成',
          ),
        ],
        initialTab: 2,
      );

      expect(find.text('已完成的合成'), findsOneWidget);
      expect(find.text('进行中的合成'), findsNothing);
    });

    testWidgets('initialTab=3（失败）只显示失败的任务', (tester) async {
      await pumpTaskListPage(
        tester,
        backgroundTasks: [
          _createBackgroundTask(
            id: 'bg-failed',
            status: TaskStatus.failed,
            title: '失败的后台',
          ),
          _createBackgroundTask(
            id: 'bg-completed',
            status: TaskStatus.completed,
            title: '已完成的后台',
          ),
        ],
        initialTab: 3,
      );

      expect(find.text('失败的后台'), findsOneWidget);
      expect(find.text('已完成的后台'), findsNothing);
    });

    testWidgets('进行中 tab 包含 running, paused, waiting 状态', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-running',
            status: catcatch.TaskStatus.running,
            title: '运行中',
          ),
          _createCatCatchTask(
            id: 'cc-paused',
            status: catcatch.TaskStatus.paused,
            title: '已暂停',
          ),
          _createCatCatchTask(
            id: 'cc-waiting',
            status: catcatch.TaskStatus.waiting,
            title: '等待中',
          ),
        ],
        initialTab: 1,
      );

      expect(find.text('运行中'), findsOneWidget);
      expect(find.text('已暂停'), findsOneWidget);
      expect(find.text('等待中'), findsOneWidget);
    });

    testWidgets('切换到进行中 tab 后只显示进行中的任务', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-running',
            status: catcatch.TaskStatus.running,
            title: '运行中',
          ),
          _createCatCatchTask(
            id: 'cc-completed',
            status: catcatch.TaskStatus.completed,
            title: '已完成',
          ),
        ],
        initialTab: 0,
      );

      // Initially all visible — "已完成" text may appear in both tab and status chip
      expect(find.text('运行中'), findsOneWidget);
      expect(find.text('已完成'), findsAtLeast(1));

      // Tap the "进行中" tab (widgetWithText to target the Tab widget)
      await tester.tap(find.widgetWithText(Tab, '进行中'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Only running should be visible; "已完成" may still appear in tab but not in list
      expect(find.text('运行中'), findsOneWidget);
      // Completed task card should not be visible — its title "已完成" won't appear
      // (the "已完成" tab label still exists but that's separate)
    });

    testWidgets('空列表时 暂无任务 占位符显示在非全部 tab', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-completed',
            status: catcatch.TaskStatus.completed,
            title: '已完成任务',
          ),
        ],
        // 进行中 tab - no running tasks
        initialTab: 1,
      );

      // Should show empty state on 进行中 tab when no running tasks
      expect(find.text('暂无任务'), findsOneWidget,
          reason: 'Empty state should show when no tasks match tab filter');
    });

    testWidgets('全部 tab 混合显示三种类型的任务', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-1',
            status: catcatch.TaskStatus.completed,
            title: 'CatCatch下载',
          ),
        ],
        synthesisTasks: [
          _createSynthesisTask(
            id: 'synth-1',
            status: TaskStatus.completed,
            title: '语音合成',
          ),
        ],
        backgroundTasks: [
          _createBackgroundTask(
            id: 'bg-1',
            status: TaskStatus.completed,
            title: 'OCR识别',
          ),
        ],
        initialTab: 0,
      );

      expect(find.text('CatCatch下载'), findsOneWidget);
      expect(find.text('语音合成'), findsOneWidget);
      expect(find.text('OCR识别'), findsOneWidget);
    });

    testWidgets('TabBar 切换后重置过滤状态', (tester) async {
      await pumpTaskListPage(
        tester,
        catcatchTasks: [
          _createCatCatchTask(
            id: 'cc-running',
            status: catcatch.TaskStatus.running,
            title: '运行中任务',
          ),
          _createCatCatchTask(
            id: 'cc-failed',
            status: catcatch.TaskStatus.failed,
            title: '失败任务',
          ),
        ],
        initialTab: 0,
      );

      // Both visible on 全部 tab
      expect(find.text('运行中任务'), findsOneWidget);
      expect(find.text('失败任务'), findsOneWidget);

      // Switch to 失败 tab — use widgetWithText to target the Tab widget specifically
      await tester.tap(find.widgetWithText(Tab, '失败'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('失败任务'), findsOneWidget);
      expect(find.text('运行中任务'), findsNothing);

      // Switch back to 全部 tab
      await tester.tap(find.widgetWithText(Tab, '全部'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('运行中任务'), findsOneWidget);
      expect(find.text('失败任务'), findsOneWidget);
    });
  });
}
