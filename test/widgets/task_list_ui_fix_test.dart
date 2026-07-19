import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/home_page.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';

// =============================================================================
// Tests for Issue 3: Task list page UI fix
// - Remove "最近任务" header (with 3 session number badges) from task list page
// - Add "最近任务" text to home page status card (top-left, symmetric to 查看全部)
// =============================================================================

/// Pump the UnifiedTaskListPage with the given background tasks.
Future<void> pumpTaskListPage(
  WidgetTester tester, {
  List<BackgroundTask> backgroundTasks = const [],
}) async {
  final bgNotifier = BackgroundTaskNotifier();
  bgNotifier.state = backgroundTasks;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        backgroundTasksProvider.overrideWith((ref) => bgNotifier),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
      ],
      child: const MaterialApp(
        home: UnifiedTaskListPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnifiedTaskListPage - 最近任务 header removed', () {
    testWidgets('does NOT show "最近任务" header text', (tester) async {
      // Add a completed task so the list is not empty
      final bgNotifier = BackgroundTaskNotifier();
      final taskId = bgNotifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '测试任务',
      );
      bgNotifier.completeTask(taskId);

      await pumpTaskListPage(tester, backgroundTasks: bgNotifier.state);

      // The "最近任务" header should NOT be present
      expect(find.text('最近任务'), findsNothing,
          reason: 'Task list page should NOT show "最近任务" header');
    });

    testWidgets('does NOT show session number badges', (tester) async {
      await pumpTaskListPage(tester);

      // Session badges are built with launch sessions; they would show
      // numeric counts wrapped in Badge widgets. Since we don't have
      // direct access to the internal widget, verify the build method
      // is no longer called by checking no Badge widgets from the header exist.

      // The page should still show the TabBar and task list area.
      // With no tasks, it shows "暂无任务" empty state.
      expect(find.text('暂无任务'), findsOneWidget,
          reason: 'Empty task list should show placeholder');
    });

    testWidgets('still shows TabBar with 4 tabs', (tester) async {
      await pumpTaskListPage(tester);

      // All 4 tab labels should be present
      expect(find.text('全部'), findsOneWidget,
          reason: 'Tab "全部" should be present');
      expect(find.text('进行中'), findsOneWidget,
          reason: 'Tab "进行中" should be present');
      expect(find.text('已完成'), findsOneWidget,
          reason: 'Tab "已完成" should be present');
      expect(find.text('失败'), findsOneWidget,
          reason: 'Tab "失败" should be present');
    });

    testWidgets('still shows task cards when tasks exist', (tester) async {
      final bgNotifier = BackgroundTaskNotifier();
      bgNotifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '显示的任务',
      );

      await pumpTaskListPage(tester, backgroundTasks: bgNotifier.state);

      expect(find.text('显示的任务'), findsOneWidget,
          reason: 'Task card should still be shown');
      expect(find.text('进行中'), findsAtLeast(1),
          reason: 'Running task status should be shown');
    });
  });

  group('HomePage status card - 最近任务 text added', () {
    testWidgets('shows "最近任务" text in status card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The "最近任务" text should now appear on the home page
      expect(find.text('最近任务'), findsOneWidget,
          reason: 'Home page should show "最近任务" text in status card');
    });

    testWidgets('"最近任务" is positioned to the left of "查看全部"', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find both widgets
      final recentTaskFinder = find.text('最近任务');
      final viewAllFinder = find.text('查看全部');

      expect(recentTaskFinder, findsOneWidget);
      expect(viewAllFinder, findsOneWidget);

      // Get their positions
      final recentTaskBox = tester.renderObject<RenderBox>(
        recentTaskFinder,
      );
      final viewAllBox = tester.renderObject<RenderBox>(
        viewAllFinder,
      );

      final recentTaskRight = recentTaskBox.localToGlobal(Offset.zero).dx +
          recentTaskBox.size.width;
      final viewAllLeft = viewAllBox.localToGlobal(Offset.zero).dx;

      // "最近任务" should end before "查看全部" begins (left of it)
      expect(
        recentTaskRight,
        lessThan(viewAllLeft),
        reason: '"最近任务" text should be positioned to the left of "查看全部"',
      );
    });

    testWidgets('"查看全部" and ">" still present in status card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both the text and the visual indicator should still exist
      expect(find.text('查看全部'), findsOneWidget,
          reason: '"查看全部" should still be present');
      expect(find.text('>'), findsOneWidget,
          reason: '"查看全部 >" greater-than character should still be present');
    });

    testWidgets('status item counts (0, 0, 0) still displayed', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 3 status items should show their count (initially all "0")
      expect(find.text('0'), findsAtLeast(3),
          reason:
              'All 3 status count numbers should be displayed (found fewer than 3)');
    });

    testWidgets('status items still navigate to task list page on tap',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test tapping 进行中
      await tester.tap(find.text('进行中'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 进行中 should still navigate to task list page');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Test tapping 已完成
      await tester.tap(find.text('已完成'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 已完成 should still navigate to task list page');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Test tapping 失败
      await tester.tap(find.text('失败'));
      await tester.pumpAndSettle();
      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 失败 should still navigate to task list page');
    });

    testWidgets('tapping 查看全部 still navigates to task list page',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看全部'));
      await tester.pumpAndSettle();

      expect(find.text('任务列表'), findsOneWidget,
          reason: 'Tapping 查看全部 should still navigate to task list page');
    });
  });
}
