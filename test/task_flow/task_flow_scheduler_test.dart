import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/services/task_flow_scheduler.dart';

void main() {
  group('TaskFlowScheduler weights', () {
    test('CPU-heavy blocks cost 2, network-only blocks cost 1', () {
      expect(TaskFlowScheduler.weightFor(BlockType.catcatch), 2);
      expect(TaskFlowScheduler.weightFor(BlockType.audioSeparation), 2);
      expect(TaskFlowScheduler.weightFor(BlockType.asr), 1);
      expect(TaskFlowScheduler.weightFor(BlockType.ocr), 1);
      expect(TaskFlowScheduler.weightFor(BlockType.tts), 1);
      expect(TaskFlowScheduler.weightFor(BlockType.chat), 1);
    });

    test('base budget derives from core count, clamped 2..4', () {
      expect(TaskFlowScheduler(coreCount: 2).baseBudget, 2);
      expect(TaskFlowScheduler(coreCount: 4).baseBudget, 2);
      expect(TaskFlowScheduler(coreCount: 6).baseBudget, 3);
      expect(TaskFlowScheduler(coreCount: 8).baseBudget, 4);
      expect(TaskFlowScheduler(coreCount: 32).baseBudget, 4);
      expect(TaskFlowScheduler(coreCount: 1).baseBudget, 2);
    });
  });

  group('TaskFlowScheduler acquisition', () {
    late TaskFlowScheduler scheduler;

    setUp(() {
      // 4 cores → base budget 2. Stable RSS (no contraction).
      scheduler = TaskFlowScheduler(
        coreCount: 4,
        rssBytes: () => 100 * 1024 * 1024,
      );
    });

    test('acquires immediately while budget allows', () async {
      await scheduler.acquire('f1', 1);
      await scheduler.acquire('f2', 1);
      expect(scheduler.activeWeight, 2);
      expect(scheduler.queuedCount, 0);
      scheduler.release('f1');
      scheduler.release('f2');
      expect(scheduler.activeWeight, 0);
    });

    test('queues FIFO when over budget and resumes on release', () async {
      await scheduler.acquire('f1', 2); // budget 2/2 used
      final f2 = scheduler.acquire('f2', 1); // must wait
      final f3 = scheduler.acquire('f3', 1); // must wait (behind f2)

      // Nothing released yet — both still queued.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(scheduler.queuedCount, 2);
      expect(scheduler.activeWeight, 2);

      // Release f1 → f2 (queue head) acquires.
      scheduler.release('f1');
      await f2;
      expect(scheduler.activeWeight, 1);
      expect(scheduler.queuedCount, 1);

      // Release f2 → f3 acquires.
      scheduler.release('f2');
      await f3;
      expect(scheduler.activeWeight, 1);
      expect(scheduler.queuedCount, 0);
      scheduler.release('f3');
    });

    test('a heavy block cannot jump the queue even if it fits alone', () async {
      await scheduler.acquire('f1', 1); // 1/2
      final f2 = scheduler.acquire('f2', 2); // queued (2 > 1 remaining)
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(scheduler.queuedCount, 1);

      // f1 releases → f2 fits (0 + 2 <= 2).
      scheduler.release('f1');
      await f2;
      expect(scheduler.activeWeight, 2);
      scheduler.release('f2');
    });

    test('cancel removes a queued flow and its acquire throws', () async {
      await scheduler.acquire('f1', 2);
      final f2 = scheduler.acquire('f2', 1); // queued
      await Future<void>.delayed(const Duration(milliseconds: 600));

      scheduler.cancel('f2');
      await expectLater(f2, throwsA(isA<FlowSchedulerCancelledException>()));
      expect(scheduler.queuedCount, 0);
      expect(scheduler.activeWeight, 2);
      scheduler.release('f1');
    });

    test('cancel of a non-queued flow is a no-op', () {
      scheduler.cancel('nope');
      expect(scheduler.queuedCount, 0);
    });

    test('release is idempotent', () async {
      await scheduler.acquire('f1', 1);
      scheduler.release('f1');
      scheduler.release('f1');
      expect(scheduler.activeWeight, 0);
    });

    test(
        'a weight-2 head under a contracted budget still runs when idle '
        '(no queue starvation)', () async {
      var rss = 100 * 1024 * 1024;
      final contracted = TaskFlowScheduler(
        coreCount: 4, // base budget 2
        rssBytes: () => rss,
        rssWindow: const Duration(seconds: 30),
        rssGrowthThresholdBytes: 300 * 1024 * 1024,
      );
      await contracted.acquire('f1', 1); // baseline sample
      rss = 500 * 1024 * 1024; // contract budget to 1
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final heavy = contracted.acquire('h1', 2); // queued (2 > budget 1)
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(contracted.queuedCount, 1);
      expect(contracted.currentBudget, 1);

      // f1 releases → queue head (weight 2) proceeds despite 2 > budget 1.
      contracted.release('f1');
      await heavy;
      expect(contracted.activeWeight, 2);
      expect(contracted.queuedCount, 0);
      contracted.release('h1');
    });
  });

  group('TaskFlowScheduler dynamic budget (RSS)', () {
    test('fast RSS growth contracts the budget; stability recovers it',
        () async {
      var rss = 100 * 1024 * 1024;
      final scheduler = TaskFlowScheduler(
        coreCount: 4, // base budget 2
        rssBytes: () => rss,
        rssWindow: const Duration(seconds: 30),
        rssGrowthThresholdBytes: 300 * 1024 * 1024,
      );

      // Baseline sample.
      await scheduler.acquire('f1', 1);
      // RSS grows fast (e.g. a conversion loading data).
      rss = 500 * 1024 * 1024; // +400MB > threshold
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Next acquire samples the growth → budget contracts to 1.
      // active=1 (f1), budget now 1 → f2 must queue (not awaited yet).
      final f2 = scheduler.acquire('f2', 1);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(scheduler.queuedCount, 1);
      expect(scheduler.currentBudget, 1);

      // Memory stabilizes → budget recovers to 2, f2 acquires.
      rss = 510 * 1024 * 1024; // growth now 410MB... still above half
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(scheduler.currentBudget, 1); // still contracted (410 > 150)

      rss = 300 * 1024 * 1024; // growth 200MB > 150 → still contracted
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(scheduler.currentBudget, 1);

      rss = 200 * 1024 * 1024; // growth 100MB < 150 → recover
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(scheduler.currentBudget, 2);
      // f2 auto-acquired the moment the budget recovered — queued no more.
      expect(scheduler.queuedCount, 0);
      await f2;
      expect(scheduler.activeWeight, 2); // f1 + f2 both running
      scheduler.release('f1');
      scheduler.release('f2');
    });

    test(
        'RSS growth during a long block is attributed at the next '
        'acquire (cross-block baseline)', () async {
      var rss = 100 * 1024 * 1024;
      final s = TaskFlowScheduler(
        coreCount: 4,
        rssBytes: () => rss,
        rssWindow: const Duration(seconds: 30),
        rssGrowthThresholdBytes: 300 * 1024 * 1024,
      );

      // Block A runs for "minutes" (no sampling happens meanwhile).
      await s.acquire('a', 1);
      rss = 500 * 1024 * 1024; // A ballooned memory while running
      await Future<void>.delayed(const Duration(milliseconds: 100));
      s.release('a'); // samples on release → growth attributed

      // Budget is now contracted even though the samples are sparse.
      expect(s.currentBudget, 1);
      expect(s.baseBudget, 2);
    });

    test('long idle gap re-anchors the RSS baseline (no false contraction)',
        () async {
      var rss = 500 * 1024 * 1024; // high from an unrelated previous run
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final s = TaskFlowScheduler(
        coreCount: 4,
        rssBytes: () => rss,
        now: () => fakeNow,
        rssWindow: const Duration(seconds: 30),
        rssGrowthThresholdBytes: 300 * 1024 * 1024,
      );
      await s.acquire('a', 1); // baseline 500MB @ 12:00
      rss = 510 * 1024 * 1024;
      s.release('a'); // small growth (10MB), no contraction
      expect(s.currentBudget, 2);

      // Idle for longer than 2x the window, then a new flow starts with
      // stable RSS — the stale baseline must not trigger contraction.
      fakeNow = fakeNow.add(const Duration(minutes: 61));
      await s.acquire('b', 1);
      expect(s.currentBudget, 2);
      s.release('b');
    });
  });
}
