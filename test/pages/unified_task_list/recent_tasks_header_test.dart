import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/pages/unified_task_list/task_utils.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  group('UnifiedTaskListPage - recent tasks header removed', () {
    final baseTime = DateTime(2025, 7, 18, 10, 0, 0);

    catcatch.CatCatchTask _catCatch({
      required String id,
      required DateTime createdAt,
    }) {
      return catcatch.CatCatchTask(
        id: id,
        url: 'https://example.com/video.mp4',
        expectedDurationSec: 120,
        title: 'Task $id',
        status: catcatch.TaskStatus.completed,
        createdAt: createdAt,
      );
    }

    testWidgets('does NOT show 最近任务 header even when launches exist', (
      tester,
    ) async {
      // Set up launches: 3 timestamps → 2 sessions
      final launchTimestamps = [
        baseTime.subtract(const Duration(hours: 2)),
        baseTime.subtract(const Duration(hours: 1)),
        baseTime,
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catcatchTasksProvider.overrideWith((ref) {
              final notifier = CatCatchNotifier(ref);
              notifier.state = [
                _catCatch(
                    id: 'c1',
                    createdAt: baseTime.subtract(const Duration(minutes: 30))),
              ];
              return notifier;
            }),
            taskListProvider.overrideWith((ref) {
              final notifier = TaskListNotifier(ref);
              notifier.state = [];
              return notifier;
            }),
            backgroundTasksProvider.overrideWith((ref) {
              final notifier = BackgroundTaskNotifier();
              notifier.state = [];
              return notifier;
            }),
            taskListLastReadProvider.overrideWith((ref) => DateTime(2000)),
            appLaunchTimestampsProvider.overrideWith((ref) => launchTimestamps),
          ],
          child: const MaterialApp(
            home: UnifiedTaskListPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should NOT show "最近任务" label on task list page (moved to home page)
      expect(find.text('最近任务'), findsNothing,
          reason: 'Task list page should NOT show 最近任务 label (moved to home page)');
    });

    testWidgets('still does NOT show 最近任务 when no launches recorded', (tester) async {
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
            backgroundTasksProvider.overrideWith((ref) {
              final notifier = BackgroundTaskNotifier();
              notifier.state = [];
              return notifier;
            }),
            taskListLastReadProvider.overrideWith((ref) => DateTime.now()),
            appLaunchTimestampsProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: UnifiedTaskListPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should NOT show "最近任务" label on task list page
      expect(find.text('最近任务'), findsNothing,
          reason: 'Task list page should NOT show 最近任务 label');
    });
  });

  group('HomePage - recent tasks header present', () {
    testWidgets('shows 最近任务 header on home page status card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "最近任务" label on home page status card
      expect(find.text('最近任务'), findsOneWidget,
          reason: 'Home page should show 最近任务 in status card');
    });
  });
}
