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

      notifier.completeTask(id, downloadedFilePath: 'C:\\file.txt');

      // Completed task should stay in list with status=completed
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.completed);
      expect(notifier.state[0].completedAt, isNotNull);
      expect(notifier.state[0].downloadedFilePath, 'C:\\file.txt');
    });

    test('completeTask without downloadedFilePath keeps it null', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');
      notifier.completeTask(id);

      expect(notifier.state[0].downloadedFilePath, isNull);
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

    test('toMap/fromMap round-trip preserves all fields (including steps and downloadedFilePath)',
        () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR任务');

      // Set initial steps
      notifier.setSteps(id, [
        BgTaskStep(label: '连接服务器', status: BgStepStatus.completed),
        BgTaskStep(label: '上传图片', status: BgStepStatus.running),
        BgTaskStep(label: '识别中', status: BgStepStatus.pending),
        BgTaskStep(label: '保存结果', status: BgStepStatus.pending),
      ]);

      // Set a step as completed
      notifier.updateStep(id, 0, completed: true);

      // Complete the task with a file path
      notifier.completeTask(id, downloadedFilePath: 'C:\\ocr\\result.txt');

      final task = notifier.state[0];
      expect(task.downloadedFilePath, 'C:\\ocr\\result.txt');

      final map = task.toMap();
      final restored = BackgroundTask.fromMap(map);

      expect(restored.id, task.id);
      expect(restored.type, task.type);
      expect(restored.title, task.title);
      expect(restored.status, task.status);
      expect(restored.error, task.error);
      expect(restored.downloadedFilePath, task.downloadedFilePath);
      expect(restored.createdAt.toIso8601String(),
          task.createdAt.toIso8601String());
      expect(restored.completedAt?.toIso8601String(),
          task.completedAt?.toIso8601String());
      expect(restored.statusChangedAt?.toIso8601String(),
          task.statusChangedAt?.toIso8601String());
      expect(restored.steps.length, task.steps.length);
      expect(restored.steps[0].label, task.steps[0].label);
      expect(restored.steps[0].completed, task.steps[0].completed);
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

      notifier.completeTask(id1);
      notifier.completeTask(id2);
      notifier.completeTask(id3);

      expect(notifier.state.where((t) => t.id == id1).single.status,
          TaskStatus.completed);
      expect(notifier.state.where((t) => t.id == id2).single.status,
          TaskStatus.completed);
      expect(notifier.state.where((t) => t.id == id3).single.status,
          TaskStatus.completed);
    });

    // ==================================================================
    // Step tracking tests
    // ==================================================================

    test('addTask initializes task with default steps for the type', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      // Steps are auto-initialized based on task type
      expect(notifier.state[0].steps.length, 5,
          reason: 'OCR tasks should have 5 default steps');
      expect(notifier.state[0].steps[0].label, '连接服务器');
      expect(notifier.state[0].steps[0].status, BgStepStatus.pending);
    });

    test('setSteps stores steps on task', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      final steps = [
        BgTaskStep(label: '连接服务器', status: BgStepStatus.pending),
        BgTaskStep(label: '上传图片', status: BgStepStatus.pending),
      ];

      notifier.setSteps(id, steps);

      expect(notifier.state[0].steps.length, 2);
      expect(notifier.state[0].steps[0].label, '连接服务器');
      expect(notifier.state[0].steps[0].status, BgStepStatus.pending);
    });

    test('updateStep updates a specific step by index', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      notifier.setSteps(id, [
        BgTaskStep(label: '连接服务器', status: BgStepStatus.pending),
        BgTaskStep(label: '上传图片', status: BgStepStatus.pending),
        BgTaskStep(label: '识别中', status: BgStepStatus.pending),
      ]);

      // Mark first step as completed
      notifier.updateStep(id, 0, completed: true);
      expect(notifier.state[0].steps[0].completed, isTrue);
      expect(notifier.state[0].steps[0].running, isFalse);
      expect(notifier.state[0].steps[1].completed, isFalse);

      // Mark second step as running
      notifier.updateStep(id, 1, running: true);
      expect(notifier.state[0].steps[1].running, isTrue);
    });

    test('updateStep with failed marks step as failed and stores error', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      notifier.setSteps(id, [
        BgTaskStep(label: '连接服务器', status: BgStepStatus.pending),
        BgTaskStep(label: '上传图片', status: BgStepStatus.pending),
      ]);

      notifier.updateStep(id, 1, failed: true, error: '上传超时');
      expect(notifier.state[0].steps[1].failed, isTrue);
      expect(notifier.state[0].steps[1].error, '上传超时');
    });

    test('setSteps does not affect other tasks', () {
      final notifier = BackgroundTaskNotifier();

      final id1 = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR');

      notifier.setSteps(id1, [
        BgTaskStep(label: '连接服务器', status: BgStepStatus.completed),
      ]);

      // The task we called setSteps on (id1, index 1 since newest first) has 1 custom step
      expect(notifier.state[1].steps.length, 1, reason: 'OCR task should have 1 custom step');
      // The other task (id2, index 0) still has its default 5 steps
      expect(notifier.state[0].steps.length, 5, reason: 'ASR task should still have default steps');
    });

    // ==================================================================
    // Result field tests (kept internally for file saving)
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

    test('toMap/fromMap with downloadedFilePath persists correctly', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');
      notifier.completeTask(id, downloadedFilePath: 'D:\\files\\result.txt');

      final task = notifier.state[0];
      final map = task.toMap();
      expect(map['downloadedFilePath'], 'D:\\files\\result.txt');

      final restored = BackgroundTask.fromMap(map);
      expect(restored.downloadedFilePath, 'D:\\files\\result.txt');
    });

    test('toMap/fromMap preserves result field', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: '音频分离');
      notifier.setResult(id, '结果文本');

      final task = notifier.state[0];
      final map = task.toMap();
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
    // Edge cases
    // ==================================================================

    test('completeTask is idempotent (calling twice does not throw)', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      notifier.completeTask(id);
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

    test('task remains in list after status transitions', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '可见性测试');
      expect(notifier.state.length, 1);
      notifier.completeTask(id);
      expect(notifier.state.length, 1, reason: '已完成任务应保留在列表中');
    });
  });
}
