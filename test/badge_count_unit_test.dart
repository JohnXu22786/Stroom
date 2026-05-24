import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as ct;

/// 模拟生产代码中的 activeTaskCount 计算逻辑（catcatch部分）
int _countActiveCatCatch(
    List<ct.CatCatchTask> tasks, DateTime lastRead) {
  return tasks
      .where((t) =>
          t.status.name != 'completed' &&
          ((t.statusChangedAt ?? t.createdAt).isAfter(lastRead) ||
              (t.status.name == 'running' &&
                  t.steps.any((s) =>
                      s.type.name == 'userSelecting' && s.running))))
      .length;
}

ct.CatCatchTask _makeTask({
  required String id,
  required String statusName,
  required DateTime createdAt,
  bool hasUserSelecting = false,
  DateTime? statusChangedAt,
}) {
  return ct.CatCatchTask(
    id: id,
    url: 'https://example.com/v.mp4',
    expectedDurationSec: 60,
    createdAt: createdAt,
    status: ct.TaskStatus.values.firstWhere((s) => s.name == statusName),
    statusChangedAt: statusChangedAt,
    title: 'Task $id',
    steps: [
      ct.StepStatus.done(ct.StepType.fetching),
      ct.StepStatus.done(ct.StepType.analyzing),
      ct.StepStatus(
        type: ct.StepType.userSelecting,
        running: hasUserSelecting,
      ),
      ct.StepStatus.pending(ct.StepType.downloading),
    ],
    progress: statusName == 'running' ? 50 : 100,
  );
}

void main() {
  group('activeCatCatch badge count logic', () {
    final now = DateTime.now();
    final twoHoursAgo = now.subtract(const Duration(hours: 2));
    final oneHourAgo = now.subtract(const Duration(hours: 1));

    test('userSelecting task counts even when lastRead is after creation',
        () {
      final task = _makeTask(
        id: 'us1',
        statusName: 'running',
        createdAt: twoHoursAgo,
        statusChangedAt: twoHoursAgo,
        hasUserSelecting: true,
      );
      final count = _countActiveCatCatch([task], now);
      expect(count, 1);
    });

    test('userSelecting task counts when statusChangedAt is null', () {
      final task = _makeTask(
        id: 'us2',
        statusName: 'running',
        createdAt: twoHoursAgo,
        statusChangedAt: null,
        hasUserSelecting: true,
      );
      final count = _countActiveCatCatch([task], now);
      expect(count, 1);
    });

    test('completed task does not count', () {
      final task = _makeTask(
        id: 'c1',
        statusName: 'completed',
        createdAt: twoHoursAgo,
        statusChangedAt: now,
        hasUserSelecting: false,
      );
      final count = _countActiveCatCatch([task], now);
      expect(count, 0);
    });

    test('unread running task (no userSelecting) counts when after lastRead',
        () {
      final task = _makeTask(
        id: 'r1',
        statusName: 'running',
        createdAt: twoHoursAgo,
        statusChangedAt: now,
        hasUserSelecting: false,
      );
      final count = _countActiveCatCatch([task], oneHourAgo);
      expect(count, 1);
    });

    test('running task before lastRead without userSelecting does not count',
        () {
      final task = _makeTask(
        id: 'r2',
        statusName: 'running',
        createdAt: twoHoursAgo,
        statusChangedAt: twoHoursAgo,
        hasUserSelecting: false,
      );
      final count = _countActiveCatCatch([task], now);
      expect(count, 0);
    });

    test('paused task before lastRead does not count', () {
      final task = _makeTask(
        id: 'p1',
        statusName: 'paused',
        createdAt: twoHoursAgo,
        statusChangedAt: twoHoursAgo,
        hasUserSelecting: false,
      );
      final count = _countActiveCatCatch([task], now);
      expect(count, 0);
    });

    test('multiple tasks: mixture of counted and not counted', () {
      final tasks = [
        _makeTask(
          id: 'us1',
          statusName: 'running',
          createdAt: twoHoursAgo,
          statusChangedAt: twoHoursAgo,
          hasUserSelecting: true,
        ),
        _makeTask(
          id: 'c1',
          statusName: 'completed',
          createdAt: twoHoursAgo,
          statusChangedAt: twoHoursAgo,
          hasUserSelecting: false,
        ),
        _makeTask(
          id: 'r1',
          statusName: 'running',
          createdAt: twoHoursAgo,
          statusChangedAt: now,
          hasUserSelecting: false,
        ),
      ];
      final count = _countActiveCatCatch(tasks, oneHourAgo);
      // us1 (userSelecting ignores lastRead) + r1 (after lastRead) = 2
      expect(count, 2);
    });

    test('empty list returns 0', () {
      expect(_countActiveCatCatch([], now), 0);
    });
  });
}
