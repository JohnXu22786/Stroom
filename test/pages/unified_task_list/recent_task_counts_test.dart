import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/pages/unified_task_list/task_utils.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/providers/background_task_provider.dart';

void main() {
  group('computeRecentTaskCounts', () {
    final baseTime = DateTime(2025, 7, 18, 10, 0, 0); // 10:00

    // Create a CatCatchTask helper
    catcatch.CatCatchTask _catCatch({
      required String id,
      required DateTime createdAt,
      DateTime? statusChangedAt,
    }) {
      return catcatch.CatCatchTask(
        id: id,
        url: 'https://example.com/video.mp4',
        expectedDurationSec: 120,
        title: 'Task $id',
        status: catcatch.TaskStatus.completed,
        createdAt: createdAt,
        statusChangedAt: statusChangedAt,
      );
    }

    // Create a SynthesisTask helper
    SynthesisTask _synth({
      required String id,
      required DateTime createdAt,
      DateTime? statusChangedAt,
    }) {
      return SynthesisTask(
        id: id,
        title: 'Synth $id',
        status: TaskStatus.completed,
        text: 'text',
        providerConfig: ProviderConfigItem(
          providerName: 'Test',
          host: 'https://test.com',
          key: 'key',
        ),
        modelConfig: ModelConfig(name: 'M', modelId: 'm'),
        createdAt: createdAt,
        statusChangedAt: statusChangedAt,
      );
    }

    // Create a BackgroundTask helper
    BackgroundTask _bg({
      required String id,
      required DateTime createdAt,
      DateTime? statusChangedAt,
    }) {
      return BackgroundTask(
        id: id,
        type: BackgroundTaskType.ocr,
        title: 'Bg $id',
        status: TaskStatus.completed,
        createdAt: createdAt,
        statusChangedAt: statusChangedAt,
      );
    }

    test('returns correct counts for tasks in 3 launch sessions', () {
      // Launch timestamps: 10:00, 11:00, 12:00
      final launches = [
        baseTime, // 10:00
        baseTime.add(const Duration(hours: 1)), // 11:00
        baseTime.add(const Duration(hours: 2)), // 12:00
        baseTime.add(const Duration(hours: 3)), // 13:00
      ];

      // Tasks:
      // Session 1 (10:00-11:00): 2 tasks at 10:30
      // Session 2 (11:00-12:00): 1 task at 11:30
      // Session 3 (12:00-13:00): 3 tasks at 12:30
      final catTasks = [
        _catCatch(
            id: 'c1', createdAt: baseTime.add(const Duration(minutes: 30))),
        _catCatch(
            id: 'c2', createdAt: baseTime.add(const Duration(minutes: 30))),
        _catCatch(
            id: 'c3', createdAt: baseTime.add(const Duration(minutes: 90))),
        _catCatch(
            id: 'c4', createdAt: baseTime.add(const Duration(minutes: 150))),
        _catCatch(
            id: 'c5', createdAt: baseTime.add(const Duration(minutes: 150))),
        _catCatch(
            id: 'c6', createdAt: baseTime.add(const Duration(minutes: 150))),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );

      // Should return 3 sessions (most recent first)
      expect(result.length, 3, reason: 'Should return 3 sessions');
      // Session 3 (12:00-13:00): 3 tasks
      expect(result[0]['total'], 3,
          reason: 'Most recent session should have 3 tasks');
      // Session 2 (11:00-12:00): 1 task
      expect(result[1]['total'], 1,
          reason: 'Middle session should have 1 task');
      // Session 1 (10:00-11:00): 2 tasks
      expect(result[2]['total'], 2,
          reason: 'Oldest session should have 2 tasks');
    });

    test('returns empty list when fewer than 2 launches', () {
      final launches = [DateTime.now()];
      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: [],
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );
      expect(result, isEmpty,
          reason: 'With only 1 launch, should return empty');
    });

    test('returns counts of 0 for sessions with no tasks', () {
      final launches = [
        baseTime,
        baseTime.add(const Duration(hours: 1)),
        baseTime.add(const Duration(hours: 2)),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: [],
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );

      // 3 timestamps → 2 complete intervals, both shown
      expect(result.length, 2, reason: '3 timestamps give 2 intervals');
      expect(result[0]['total'], 0, reason: 'Most recent session has no tasks');
      expect(result[1]['total'], 0, reason: 'Older session also has no tasks');
    });

    test('correctly marks unread tasks based on threshold', () {
      final launches = [
        baseTime,
        baseTime.add(const Duration(hours: 1)),
        baseTime.add(const Duration(hours: 2)),
      ];

      // Session 2 (11:00-12:00): tasks at 10:30 → belongs to Session 1 (10:00-11:00)
      final catTasks = [
        _catCatch(
            id: 'c1', createdAt: baseTime.add(const Duration(minutes: 30))),
        _catCatch(
          id: 'c2',
          createdAt: baseTime.add(const Duration(minutes: 30)),
          statusChangedAt:
              baseTime.add(const Duration(hours: 4)), // after threshold
        ),
      ];

      final threshold = baseTime.add(const Duration(hours: 2)); // 12:00

      // Both tasks are in session 1 (10:00-11:00)
      // c1: createdAt=10:30, statusChangedAt=null → uses createdAt 10:30 which is before threshold 12:00 → not unread
      // c2: createdAt=10:30, statusChangedAt=14:00 → 14:00 is after threshold 12:00 → unread
      // Session 2 (11:00-12:00): no tasks → total=0, unread=0

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: threshold,
      );

      expect(result.length, 2, reason: '3 timestamps = 2 intervals');
      // Most recent session (11:00-12:00)
      expect(result[0]['total'], 0, reason: 'No tasks in most recent session');
      expect(result[0]['unread'], 0, reason: 'No tasks in most recent session');
      // Older session (10:00-11:00)
      expect(result[1]['total'], 2, reason: '2 tasks in older session');
      expect(result[1]['unread'], 1, reason: '1 of 2 tasks is unread');
    });

    test('handles all three task types together', () {
      final launches = [
        baseTime,
        baseTime.add(const Duration(hours: 1)),
      ];

      final catTasks = [
        _catCatch(
            id: 'c1', createdAt: baseTime.add(const Duration(minutes: 30))),
      ];
      final synthTasks = [
        _synth(id: 's1', createdAt: baseTime.add(const Duration(minutes: 30))),
      ];
      final bgTasks = [
        _bg(id: 'b1', createdAt: baseTime.add(const Duration(minutes: 30))),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: synthTasks,
        backgroundTasks: bgTasks,
        unreadThreshold: DateTime(2000),
      );

      expect(result.length, 1, reason: '2 timestamps give 1 interval');
      expect(result[0]['total'], 3, reason: '3 tasks total across all types');
    });

    test(
        'task at exact launch boundary is counted in the NEXT interval (exclusive start)',
        () {
      final launches = [
        baseTime,
        baseTime.add(const Duration(hours: 1)),
        baseTime.add(const Duration(hours: 2)),
      ];

      // Task created exactly at the second launch timestamp (11:00)
      final catTasks = [
        _catCatch(
            id: 'boundary', createdAt: baseTime.add(const Duration(hours: 1))),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );

      // With exclusive start inclusive end, a task at exactly t1=11:00 IS in
      // interval (t0=10:00, t1=11:00] and NOT in interval (t1=11:00, t2=12:00]
      expect(result.length, 2, reason: '3 timestamps = 2 intervals');
      // Older session (10:00-11:00) should have the task (11:00 is <= 11:00)
      expect(result[1]['total'], 1,
          reason: 'Task at exactly 11:00 should be in the older interval');
      // Most recent session (11:00-12:00) should not (11:00 is NOT after 11:00)
      expect(result[0]['total'], 0,
          reason: 'No task should be in the newer interval');
    });

    test(
        'task created after the most recent launch is counted in current session',
        () {
      final launches = [
        baseTime,
        baseTime.add(const Duration(hours: 1)),
      ];

      // Task created after the second launch (during current running session)
      final catTasks = [
        _catCatch(
            id: 'current',
            createdAt: baseTime
                .add(const Duration(hours: 1))
                .add(const Duration(minutes: 5))),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );

      // With 2 timestamps, only 1 interval: (t0, now]
      expect(result.length, 1, reason: '2 timestamps = 1 interval');
      // The current session (open-ended) should include tasks created after the last launch
      expect(result[0]['total'], 1,
          reason: 'Current session should include post-launch task');
    });

    test('only shows last 3 sessions when there are 5+ launches', () {
      final launches = [
        baseTime.subtract(const Duration(days: 5)),
        baseTime.subtract(const Duration(days: 4)),
        baseTime.subtract(const Duration(days: 3)),
        baseTime.subtract(const Duration(days: 2)),
        baseTime.subtract(const Duration(days: 1)),
      ];

      // Tasks only in the 2nd interval (which should not be shown, it's too old)
      final catTasks = [
        _catCatch(
            id: 'old',
            createdAt: baseTime
                .subtract(const Duration(days: 4))
                .add(const Duration(minutes: 30))),
        // And one in the most recent interval
        _catCatch(
            id: 'new',
            createdAt: baseTime
                .subtract(const Duration(days: 1))
                .add(const Duration(minutes: 30))),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );

      // 5 launches × 4 intervals → show last 3
      // Launch timestamps: t0=-5d, t1=-4d, t2=-3d, t3=-2d, t4=-1d
      // startIndex = 5 - 3 = 2
      // i=2: (t1=-4d, t2=-3d] → result[2]
      // i=3: (t2=-3d, t3=-2d] → result[1]
      // i=4: (t3=-2d, now]   → result[0] (open-ended)
      // Old task at -4d+30min: in interval i=2 → result[2] → total=1
      // New task at -1d+30min: in interval i=4 → result[0] → total=1
      expect(result.length, 3,
          reason: '5 timestamps × 4 intervals → show last 3');
      expect(result[0]['total'], 1,
          reason: 'Most recent session (-2d to now) has the new task');
      expect(result[1]['total'], 0,
          reason: 'Middle session (-3d to -2d) has no tasks');
      expect(result[2]['total'], 1,
          reason: 'Oldest shown session (-4d to -3d) has the old task');
    });

    test('only shows last 3 sessions when there are 4+ launches', () {
      final launches = [
        baseTime.subtract(const Duration(days: 3)),
        baseTime.subtract(const Duration(days: 2)),
        baseTime.subtract(const Duration(days: 1)),
        baseTime,
      ];

      // Task created right after the second launch
      final catTasks = [
        _catCatch(
            id: 'mid',
            createdAt: baseTime
                .subtract(const Duration(days: 2))
                .add(const Duration(minutes: 30))),
      ];

      final result = computeRecentTaskCounts(
        launches: launches,
        catcatchTasks: catTasks,
        synthesisTasks: [],
        backgroundTasks: [],
        unreadThreshold: DateTime(2000),
      );

      expect(result.length, 3, reason: '4 timestamps → show 3 sessions');
      // Sessions in reverse order: (t2, now], (t1, t2], (t0, t1]
      // t0 = -3d, t1 = -2d, t2 = -1d, t3 = baseTime
      // Task at -2d+30min is in interval (t1, t2] = (-2d, -1d] — that's the middle entry
      expect(result[0]['total'], 0,
          reason: 'Most recent session (-1d to now) has no tasks');
      expect(result[1]['total'], 1,
          reason: 'Middle session (-2d to -1d) has the task');
      expect(result[2]['total'], 0,
          reason: 'Oldest shown session (-3d to -2d) has no tasks');
    });
  });
}
