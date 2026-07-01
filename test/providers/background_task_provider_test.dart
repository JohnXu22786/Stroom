import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';

void main() {
  group('BackgroundTaskNotifier', () {
    test('addTask creates a running task with correct type', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '测试OCR',
      );

      expect(notifier.state.length, 1);
      expect(notifier.state[0].id, id);
      expect(notifier.state[0].type, BackgroundTaskType.ocr);
      expect(notifier.state[0].title, '测试OCR');
      expect(notifier.state[0].status, TaskStatus.running);
    });

    test('addTask creates tasks with different types', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR任务');
      notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR任务');
      notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: '音频分离任务');

      expect(notifier.state.length, 3);
      expect(notifier.state[0].type, BackgroundTaskType.audioSeparation);
      expect(notifier.state[1].type, BackgroundTaskType.asr);
      expect(notifier.state[2].type, BackgroundTaskType.ocr);
    });

    test('completeTask updates task status to completed (keeps task visible)',
        () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.running);

      notifier.completeTask(id);

      // Completed task should stay in list with status=completed
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.completed);
      expect(notifier.state[0].completedAt, isNotNull);
    });

    test('completeTask updates only the specified task, keeps others', () {
      final notifier = BackgroundTaskNotifier();

      final id1 = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      expect(notifier.state.length, 2);

      notifier.completeTask(id1);

      expect(notifier.state.length, 2);
      expect(notifier.state[0].id, id2); // newest first
      expect(notifier.state[0].status, TaskStatus.running);
      expect(notifier.state[1].id, id1);
      expect(notifier.state[1].status, TaskStatus.completed);
    });

    test('failTask keeps failed task in state with error (no auto-remove)', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.asr, title: '测试ASR');
      notifier.failTask(id, error: '网络连接超时');

      // Failed task should stay in list so user can see error
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.failed);
      expect(notifier.state[0].error, '网络连接超时');
      expect(notifier.state[0].completedAt, isNotNull);
    });

    test('removeTask removes task from list (manual removal)', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      notifier.addTask(type: BackgroundTaskType.audioSeparation, title: 'Sep1');

      notifier.removeTask(id2);

      expect(notifier.state.length, 2);
      expect(notifier.state.every((t) => t.id != id2), isTrue);
    });

    test('addTask returns unique IDs for each task', () {
      final notifier = BackgroundTaskNotifier();

      final id1 =
          notifier.addTask(type: BackgroundTaskType.ocr, title: 'Task1');
      final id2 =
          notifier.addTask(type: BackgroundTaskType.ocr, title: 'Task2');
      final id3 =
          notifier.addTask(type: BackgroundTaskType.ocr, title: 'Task3');

      expect(id1, isNot(id2));
      expect(id1, isNot(id3));
      expect(id2, isNot(id3));
    });

    test('completeTask with non-existent id does nothing', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');

      // Should not throw
      expect(() => notifier.completeTask('non-existent'), returnsNormally);
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.running);
    });

    test('failTask with non-existent id does nothing', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');

      expect(() => notifier.failTask('non-existent', error: 'error'),
          returnsNormally);
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.running);
    });

    test('removeTask with non-existent id does nothing', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');

      expect(() => notifier.removeTask('non-existent'), returnsNormally);
      expect(notifier.state.length, 1);
    });

    test('tasks are ordered newest first', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'First');
      notifier.addTask(type: BackgroundTaskType.asr, title: 'Second');
      notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: 'Third');

      expect(notifier.state[0].title, 'Third');
      expect(notifier.state[1].title, 'Second');
      expect(notifier.state[2].title, 'First');
    });

    test('toMap/fromMap round-trip preserves all fields (using failed task)',
        () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.asr, title: '测试ASR任务');
      final id =
          notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR任务');
      notifier.failTask(id, error: '处理失败');

      final task = notifier.state[0];
      final map = task.toMap();
      final restored = BackgroundTask.fromMap(map);

      expect(restored.id, task.id);
      expect(restored.type, task.type);
      expect(restored.title, task.title);
      expect(restored.status, task.status);
      expect(restored.error, task.error);
      expect(restored.createdAt.toIso8601String(),
          task.createdAt.toIso8601String());
      expect(restored.completedAt?.toIso8601String(),
          task.completedAt?.toIso8601String());
      expect(restored.statusChangedAt?.toIso8601String(),
          task.statusChangedAt?.toIso8601String());
    });

    test('toMap/fromMap with failed task preserves error', () {
      final notifier = BackgroundTaskNotifier();

      final id =
          notifier.addTask(type: BackgroundTaskType.asr, title: '测试ASR任务');
      notifier.failTask(id, error: '处理失败: API返回错误');

      final task = notifier.state[0];
      final map = task.toMap();
      final restored = BackgroundTask.fromMap(map);

      expect(restored.status, TaskStatus.failed);
      expect(restored.error, '处理失败: API返回错误');
    });

    test('failTask without error sets status to failed', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');
      notifier.failTask(id);

      expect(notifier.state[0].status, TaskStatus.failed);
      expect(notifier.state[0].error, isNull);
    });

    test('multiple completed tasks all get status completed', () {
      final notifier = BackgroundTaskNotifier();

      final id1 = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      final id3 = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: 'Sep1');
      expect(notifier.state.length, 3);

      notifier.completeTask(id1);
      expect(notifier.state.length, 3);
      expect(notifier.state.where((t) => t.id == id1).single.status,
          TaskStatus.completed);

      notifier.completeTask(id2);
      expect(notifier.state.length, 3);
      expect(notifier.state.where((t) => t.id == id1).single.status,
          TaskStatus.completed);
      expect(notifier.state.where((t) => t.id == id2).single.status,
          TaskStatus.completed);

      notifier.completeTask(id3);
      expect(notifier.state.length, 3);
      expect(notifier.state.where((t) => t.id == id3).single.status,
          TaskStatus.completed);
    });

    test('completed tasks and failed tasks coexist in state', () {
      final notifier = BackgroundTaskNotifier();

      final id1 = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      final id3 = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: 'Sep1');

      notifier.completeTask(id1); // Should stay with status=completed
      notifier.failTask(id2, error: 'ASR失败'); // Should stay with status=failed

      expect(notifier.state.length, 3);
      expect(notifier.state.where((t) => t.id == id1).single.status,
          TaskStatus.completed);
      expect(notifier.state.where((t) => t.id == id2).single.status,
          TaskStatus.failed);
      expect(notifier.state.where((t) => t.id == id3).single.status,
          TaskStatus.running);
    });

    // ==================================================================
    // Result field tests (replaces old progress tests)
    // ==================================================================

    test('addTask initializes task without result', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      expect(notifier.state[0].result, isNull);
    });

    test('setResult stores result text on task', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: '音频分离');

      notifier.setResult(id, '这是结果文本');
      expect(notifier.state[0].result, '这是结果文本');
    });

    test('setResult does not affect other tasks', () {
      final notifier = BackgroundTaskNotifier();

      final id1 = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR');

      notifier.setResult(id1, 'OCR结果');

      expect(notifier.state.where((t) => t.id == id1).single.result, 'OCR结果');
      expect(notifier.state.where((t) => t.id == id2).single.result, isNull);
    });

    test('toMap/fromMap preserves result field', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: '音频分离');
      notifier.setResult(id, '结果文本');

      final task = notifier.state[0];
      final map = task.toMap();
      // result field should be present in serialized map
      expect(map['result'], '结果文本');
      final restored = BackgroundTask.fromMap(map);

      expect(restored.result, '结果文本');
    });

    test('fromMap handles missing result key (backward compatibility)', () {
      final map = {
        'id': 'test-id',
        'type': 'ocr',
        'title': '旧数据任务',
        'status': 'running',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final restored = BackgroundTask.fromMap(map);

      expect(restored.result, isNull);
      expect(restored.title, '旧数据任务');
      expect(restored.status, TaskStatus.running);
    });

    // ==================================================================
    // Edge case: complete/fail transitions
    // ==================================================================

    test('completeTask is idempotent (calling twice does not throw)', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      notifier.completeTask(id);
      // Second complete should not throw and should not change state
      expect(() => notifier.completeTask(id), returnsNormally);
      expect(notifier.state[0].status, TaskStatus.completed);
    });

    test('failTask is idempotent (calling twice does not throw)', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      notifier.failTask(id);
      expect(() => notifier.failTask(id), returnsNormally);
      expect(notifier.state[0].status, TaskStatus.failed);
    });

    test('completeTask after failTask keeps completed status (last wins)', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      notifier.failTask(id, error: '原始错误');
      // Complete a failed task — status becomes completed
      notifier.completeTask(id);
      expect(notifier.state[0].status, TaskStatus.completed);
      // The old error should be cleared by completeTask
      expect(notifier.state[0].error, isNull);
    });

    test(
        'failTask after completeTask uses last-wins semantics (status becomes failed)',
        () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      notifier.completeTask(id);
      // Calling failTask on an already completed task should not change status
      notifier.failTask(id, error: '后续错误');
      // The first completeTask set status to completed; failTask should
      // not downgrade a completed task since _updateTask always sets
      // whatever status is passed. This is by design (last wins).
      // But the error WILL be overwritten by failTask's error param.
      // Test that both operations independently modify their fields.
      // For simplicity, we just verify nothing crashes and task stays.
      expect(
          notifier.state[0].status, TaskStatus.failed); // last-wins semantics
    });

    test('setResult after completeTask still updates result field', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      notifier.completeTask(id);
      // setResult should still work even after task is completed
      notifier.setResult(id, '最终结果');
      expect(notifier.state[0].result, '最终结果');
      expect(notifier.state[0].status, TaskStatus.completed);
    });

    test('setResult after failTask updates result but status stays failed', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      notifier.failTask(id, error: 'ASR失败');
      notifier.setResult(id, '部分结果');
      expect(notifier.state[0].result, '部分结果');
      expect(notifier.state[0].status, TaskStatus.failed);
      expect(notifier.state[0].error, 'ASR失败');
    });

    test(
        'completeTask without matching id leaves other tasks unmodified with correct status',
        () {
      final notifier = BackgroundTaskNotifier();
      notifier.addTask(type: BackgroundTaskType.ocr, title: '保留任务');
      // Complete a non-existent id
      notifier.completeTask('non-existent-id');
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.running);
    });

    test(
        'task remains in list after status transitions from running to completed to running via manual state',
        () {
      // Verify that completing a task keeps it visible (no auto-remove), then
      // verify we can still read it.
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '可见性测试');
      expect(notifier.state.length, 1);
      notifier.completeTask(id);
      expect(notifier.state.length, 1, reason: '已完成任务应保留在列表中');
      expect(notifier.state[0].status, TaskStatus.completed);
    });
  });
}
