import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/asr_retry_storage.dart';
import 'package:stroom/services/ios_continued_task_service.dart';
import 'package:stroom/services/ocr_retry_storage.dart';
import 'package:stroom/utils/web_file_store.dart';

/// Returns the on-disk tasks.json inside [dirPath] (per-test isolated dir).
File _tasksFileIn(String dirPath) =>
    File(p.join(dirPath, 'background', 'tasks.json'));

enum _StartupAddTiming {
  afterRestoreReadStarts,
  queuedBeforeRestore,
  writePreparedBeforeRestoreRead,
}

Future<void> _verifyStartupAddPreservesPersistedTask({
  required String storageDir,
  required String addedTaskId,
  required _StartupAddTiming timing,
}) async {
  const persistedTaskId = 'persisted-before-restore';
  final seed = BackgroundTaskNotifier();
  seed.addTask(
    type: BackgroundTaskType.asr,
    title: 'Persisted before restore',
    startImmediately: false,
    taskId: persistedTaskId,
  );
  await seed.pendingPersistence;
  seed.dispose();
  await seed.pendingPersistence;

  final readStarted = Completer<void>();
  final resumeRead = Completer<void>();
  BackgroundTaskNotifier.debugBeforeTaskSnapshotRead = () async {
    if (!readStarted.isCompleted) readStarted.complete();
    await resumeRead.future;
  };

  final writeStarted = Completer<void>();
  final resumeWrite = Completer<void>();
  var writeCount = 0;
  if (timing == _StartupAddTiming.writePreparedBeforeRestoreRead) {
    BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
      writeCount++;
      if (writeCount == 1) {
        writeStarted.complete();
        await resumeWrite.future;
      }
    };
  }

  final notifier = BackgroundTaskNotifier();
  Future<void>? restore;
  BackgroundTaskNotifier? reloaded;

  void addTask() {
    notifier.addTask(
      type: BackgroundTaskType.ocr,
      title: 'Added around startup restore',
      startImmediately: false,
      taskId: addedTaskId,
    );
  }

  try {
    if (timing == _StartupAddTiming.afterRestoreReadStarts) {
      restore = notifier.restoreFromPersistence();
      await readStarted.future;
      addTask();
    } else {
      addTask();
      if (timing == _StartupAddTiming.writePreparedBeforeRestoreRead) {
        await writeStarted.future;
      }
      restore = notifier.restoreFromPersistence();
      await readStarted.future;
    }

    if (timing == _StartupAddTiming.writePreparedBeforeRestoreRead) {
      resumeWrite.complete();
      await notifier.pendingPersistence;
      final persistedBeforeRestoreRead =
          jsonDecode(await _tasksFileIn(storageDir).readAsString()) as List;
      expect(
        persistedBeforeRestoreRead.whereType<Map>().any(
              (task) => task['id'] == persistedTaskId,
            ),
        isTrue,
        reason:
            'a prepared add snapshot must preserve prior tasks when it commits before restore reads the file',
      );
      resumeRead.complete();
    } else {
      var writeFinishedBeforeRestoreRead = false;
      await Future.any<void>([
        notifier.pendingPersistence.then((_) {
          writeFinishedBeforeRestoreRead = true;
        }),
        Future<void>.delayed(const Duration(seconds: 1)),
      ]);
      expect(
        writeFinishedBeforeRestoreRead,
        isFalse,
        reason:
            'an add must not persist a partial snapshot before the old file is read',
      );
      resumeRead.complete();
    }

    await restore!;
    await notifier.pendingPersistence;
    expect(
      notifier.state.map((task) => task.id),
      containsAll([persistedTaskId, addedTaskId]),
    );
    expect(
      notifier.taskById(addedTaskId)?.status,
      TaskStatus.waiting,
      reason: 'the ordinary addTask waiting-task behavior remains intact',
    );

    BackgroundTaskNotifier.debugBeforeTaskSnapshotRead = null;
    BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
    reloaded = BackgroundTaskNotifier();
    await reloaded.restoreFromPersistence();
    await reloaded.pendingPersistence;
    expect(
      reloaded.state.map((task) => task.id),
      containsAll([persistedTaskId, addedTaskId]),
    );
  } finally {
    if (!resumeWrite.isCompleted) resumeWrite.complete();
    if (!resumeRead.isCompleted) resumeRead.complete();
    if (restore != null) await restore;
    notifier.dispose();
    await notifier.pendingPersistence;
    reloaded?.dispose();
    if (reloaded != null) await reloaded.pendingPersistence;
  }
}

/// Waits (up to ~3s) until [check] returns true.
Future<void> _waitFor(Future<bool> Function() check) async {
  for (var i = 0; i < 150; i++) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for condition');
}

/// Reads the file content, or null when the file does not exist yet
/// or is momentarily locked by a concurrent write/delete.
Future<String?> _readFileIfExists(File file) async {
  try {
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    return null; // 读与写/删竞争时视为"尚未就绪"
  }
}

void main() {
  // 初始化绑定，使 path_provider 在测试环境中走 MissingPluginException
  // 回退路径，持久化测试才能真正落盘。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundTaskNotifier', () {
    // 每个测试使用独立的持久化目录：真实测试环境的所有测试共享
    // 同一个 AppStorage 临时目录，异步写入链可能跨测试交错
    // （上一个测试的写入在本测试写入之后才落盘），
    // 独立目录彻底消除跨测试污染。
    late Directory testDir;

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp('bg_task_test_');
      BackgroundTaskNotifier.debugStorageDirectoryOverride = testDir.path;
      OcrRetryStorage.debugBeforeCacheWrite = null;
      BackgroundTaskNotifier.debugBeforeOcrCacheDelete = null;
      BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
      BackgroundTaskNotifier.debugBeforeTaskSnapshotRead = null;
      BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
      // ignore: invalid_use_of_visible_for_testing_member
      BackgroundTaskNotifier.debugBeforeLegacyAsrRetryMigration = null;
      // iOS 常驻任务桥接默认关闭（测试机非 iOS）。
      IosContinuedTaskService.debugForceSupported = false;
    });

    tearDown(() async {
      BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
      BackgroundTaskNotifier.debugBeforeOcrCacheCleanup = null;
      BackgroundTaskNotifier.debugBeforeOcrCacheDelete = null;
      BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
      BackgroundTaskNotifier.debugBeforeTaskSnapshotRead = null;
      BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
      // ignore: invalid_use_of_visible_for_testing_member
      BackgroundTaskNotifier.debugBeforeLegacyAsrRetryMigration = null;
      OcrRetryStorage.debugBeforeCacheWrite = null;
      IosContinuedTaskService.debugForceSupported = false;
      try {
        await testDir.delete(recursive: true);
      } catch (_) {
        // Windows 上文件句柄可能尚未释放，忽略清理失败。
      }
    });
    test('addTask creates a running task with correct type', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

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
        type: BackgroundTaskType.audioSeparation,
        title: '音频分离任务',
      );

      expect(notifier.state.length, 3);
      expect(notifier.state[0].type, BackgroundTaskType.audioSeparation);
      expect(notifier.state[1].type, BackgroundTaskType.asr);
      expect(notifier.state[2].type, BackgroundTaskType.ocr);
    });

    test(
      'completeTask updates task status to completed (keeps task visible)',
      () {
        final notifier = BackgroundTaskNotifier();

        final id = notifier.addTask(
          type: BackgroundTaskType.ocr,
          title: '测试OCR',
        );
        expect(notifier.state.length, 1);
        expect(notifier.state[0].status, TaskStatus.running);

        notifier.completeTask(id, downloadedFilePath: 'C:\\file.txt');

        // Completed task should stay in list with status=completed
        expect(notifier.state.length, 1);
        expect(notifier.state[0].status, TaskStatus.completed);
        expect(notifier.state[0].completedAt, isNotNull);
        expect(notifier.state[0].downloadedFilePath, 'C:\\file.txt');
      },
    );

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

    test(
      'cancelTask does not fail a same-ID replacement created during step notification',
      () async {
        final notifier = BackgroundTaskNotifier();
        final id = notifier.addTask(type: BackgroundTaskType.ocr, title: '旧任务');
        notifier.updateStep(id, 0, running: true);
        notifier.registerCancellationForGeneration(
          id,
          notifier.taskById(id)!,
          () {},
        );

        var replaced = false;
        notifier.addListener((_) {
          final task = notifier.taskById(id);
          if (replaced ||
              task?.title != '旧任务' ||
              task!.steps.first.status != BgStepStatus.failed) {
            return;
          }

          replaced = true;
          notifier.removeTask(id);
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: '替换任务',
            taskId: id,
          );
        });

        notifier.cancelTask(id);

        expect(replaced, isTrue);
        expect(notifier.state.single.title, '替换任务');
        expect(notifier.state.single.status, TaskStatus.running);
        expect(notifier.state.single.error, isNull);

        notifier.dispose();
        await notifier.pendingPersistence;
      },
    );

    test('removeTask removes task from list (manual removal)', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      final id2 = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR1');
      notifier.addTask(type: BackgroundTaskType.audioSeparation, title: 'Sep1');

      notifier.removeTask(id2);

      expect(notifier.state.length, 2);
      expect(notifier.state.every((t) => t.id != id2), isTrue);
    });

    test(
      'removeTask keeps retry data when task removal cannot be persisted',
      () async {
        final notifier = BackgroundTaskNotifier();
        final id = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR');
        await notifier.pendingPersistence;
        final persistedFile = _tasksFileIn(testDir.path);
        expect(await _readFileIfExists(persistedFile), contains(id));

        final blockedRoot = File(p.join(testDir.path, 'blocked-root'));
        await blockedRoot.writeAsString('not a directory');
        BackgroundTaskNotifier.debugStorageDirectoryOverride = blockedRoot.path;
        var cleanupCalls = 0;
        notifier.registerTaskCleanup(id, () async {
          cleanupCalls++;
        });

        notifier.removeTask(id);
        await notifier.pendingPersistence;
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(notifier.state.where((task) => task.id == id), isEmpty);
        expect(cleanupCalls, 0);
        expect(await _readFileIfExists(persistedFile), contains(id));
        notifier.dispose();
      },
    );

    test(
      'later successful task write runs cleanup for a persisted removal',
      () async {
        final notifier = BackgroundTaskNotifier();
        final id = notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR');
        await notifier.pendingPersistence;
        final persistedFile = _tasksFileIn(testDir.path);
        final blockedRoot = File(p.join(testDir.path, 'blocked-root'));
        await blockedRoot.writeAsString('not a directory');
        var cleanupCalls = 0;
        final cleanupCalled = Completer<void>();
        notifier.registerTaskCleanup(id, () async {
          cleanupCalls++;
          if (!cleanupCalled.isCompleted) cleanupCalled.complete();
        });

        BackgroundTaskNotifier.debugStorageDirectoryOverride = blockedRoot.path;
        notifier.removeTask(id);
        await notifier.pendingPersistence;
        expect(cleanupCalls, 0);
        expect(await _readFileIfExists(persistedFile), contains(id));

        BackgroundTaskNotifier.debugStorageDirectoryOverride = testDir.path;
        notifier.addTask(
          type: BackgroundTaskType.asr,
          title: 'next task write',
          taskId: 'task-after-failed-removal',
        );
        await notifier.pendingPersistence;
        await cleanupCalled.future.timeout(const Duration(seconds: 1));

        expect(cleanupCalls, 1);
        final saved = await _readFileIfExists(persistedFile);
        expect(saved, isNot(contains(id)));
        expect(saved, contains('task-after-failed-removal'));
        notifier.dispose();
        await notifier.pendingPersistence;
      },
    );

    test('task cleanup stays bound to the removed task generation', () async {
      final notifier = BackgroundTaskNotifier();
      const taskId = 'same-id-retry-cleanup';
      notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'original',
        taskId: taskId,
      );
      await notifier.pendingPersistence;
      final original = notifier.taskById(taskId)!;
      var originalCleanupCalls = 0;
      var replacementCleanupCalls = 0;
      notifier.registerTaskCleanup(
        taskId,
        () async => originalCleanupCalls++,
        taskGeneration: original,
      );

      final removal = notifier.removeTasksPersisted([taskId]);
      notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'replacement',
        taskId: taskId,
      );
      final replacement = notifier.taskById(taskId)!;
      notifier.registerTaskCleanup(
        taskId,
        () async => replacementCleanupCalls++,
        taskGeneration: replacement,
      );

      expect(await removal, isTrue);
      await notifier.pendingPersistence;

      expect(
          notifier.taskById(taskId)!.hasSameGenerationAs(replacement), isTrue);
      expect(originalCleanupCalls, 1);
      expect(replacementCleanupCalls, 0);
      notifier.dispose();
      await notifier.pendingPersistence;
    });

    test('addTask returns unique IDs for each task', () {
      final notifier = BackgroundTaskNotifier();

      final id1 = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'Task1',
      );
      final id2 = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'Task2',
      );
      final id3 = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'Task3',
      );

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

      expect(
        () => notifier.failTask('non-existent', error: 'error'),
        returnsNormally,
      );
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
        type: BackgroundTaskType.audioSeparation,
        title: 'Third',
      );

      expect(notifier.state[0].title, 'Third');
      expect(notifier.state[1].title, 'Second');
      expect(notifier.state[2].title, 'First');
    });

    test(
      'toMap/fromMap round-trip preserves all fields (including steps and downloadedFilePath)',
      () {
        final notifier = BackgroundTaskNotifier();

        final id = notifier.addTask(
          type: BackgroundTaskType.ocr,
          title: '测试OCR任务',
        );

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
        expect(
          restored.createdAt.toIso8601String(),
          task.createdAt.toIso8601String(),
        );
        expect(
          restored.completedAt?.toIso8601String(),
          task.completedAt?.toIso8601String(),
        );
        expect(
          restored.statusChangedAt?.toIso8601String(),
          task.statusChangedAt?.toIso8601String(),
        );
        expect(restored.steps.length, task.steps.length);
        expect(restored.steps[0].label, task.steps[0].label);
        expect(restored.steps[0].completed, task.steps[0].completed);
      },
    );

    test('toMap/fromMap with failed task preserves error', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: '测试ASR任务',
      );
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
        type: BackgroundTaskType.audioSeparation,
        title: 'Sep1',
      );

      notifier.completeTask(id1);
      notifier.completeTask(id2);
      notifier.completeTask(id3);

      expect(
        notifier.state.where((t) => t.id == id1).single.status,
        TaskStatus.completed,
      );
      expect(
        notifier.state.where((t) => t.id == id2).single.status,
        TaskStatus.completed,
      );
      expect(
        notifier.state.where((t) => t.id == id3).single.status,
        TaskStatus.completed,
      );
    });

    // ==================================================================
    // Step tracking tests
    // ==================================================================

    test('addTask initializes task with default steps for the type', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      // Steps are auto-initialized based on task type
      expect(
        notifier.state[0].steps.length,
        5,
        reason: 'OCR tasks should have 5 default steps',
      );
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
      notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR');

      notifier.setSteps(id1, [
        BgTaskStep(label: '连接服务器', status: BgStepStatus.completed),
      ]);

      // The task we called setSteps on (id1, index 1 since newest first) has 1 custom step
      expect(
        notifier.state[1].steps.length,
        1,
        reason: 'OCR task should have 1 custom step',
      );
      // The other task (id2, index 0) still has its default 5 steps
      expect(
        notifier.state[0].steps.length,
        5,
        reason: 'ASR task should still have default steps',
      );
    });

    // ==================================================================
    // Result field tests (kept internally for file saving)
    // ==================================================================

    test('addTask initializes task without result', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: '测试OCR');

      expect(notifier.state[0].result, isNull);
    });

    test('setResult stores result text on task', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: '音频分离',
      );

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

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR结果');
      notifier.setResult(
        id,
        '结果文本',
        isComplete: false,
        folder: 'captured folder',
      );
      notifier.markPartialResultSaveRequested(id);
      notifier.completeTask(id, resultSavedAsPartial: true);

      final task = notifier.state[0];
      final map = task.toMap();
      expect(map['result'], '结果文本');
      expect(map['resultIsComplete'], isFalse);
      expect(map['resultFolder'], 'captured folder');
      expect(map['partialSaveRequested'], isTrue);
      expect(map['resultSavedAsPartial'], isTrue);
      final restored = BackgroundTask.fromMap(map);

      expect(restored.result, '结果文本');
      expect(restored.resultIsComplete, isFalse);
      expect(restored.resultFolder, 'captured folder');
      expect(restored.partialSaveRequested, isTrue);
      expect(restored.resultSavedAsPartial, isTrue);
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

    test('legacy truncated OCR result stays marked incomplete', () {
      final map = {
        'id': 'legacy-truncated-ocr',
        'type': 'ocr',
        'title': '旧的不完整 OCR',
        'status': 'failed',
        'result': 'partial text',
        'error': 'OCR识别失败: Exception: OCR 返回了不完整结果（finish_reason=length）',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final restored = BackgroundTask.fromMap(map);

      expect(restored.result, 'partial text');
      expect(restored.resultIsComplete, isFalse);
      expect(
        restored.error,
        'OCR识别失败: Exception: OCR 返回了不完整结果（finish_reason=length）',
      );
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

    // ==================================================================
    // Step count tests (after step label changes)
    // ==================================================================

    test(
      'ASR task has 5 default steps (connection, upload, transcribe, receive, save)',
      () {
        final notifier = BackgroundTaskNotifier();
        notifier.addTask(type: BackgroundTaskType.asr, title: 'ASR');
        expect(
          notifier.state[0].steps.length,
          5,
          reason: 'ASR should have 5 default steps',
        );
        expect(notifier.state[0].steps[0].label, '连接服务器');
        expect(notifier.state[0].steps[2].label, '转写中');
        expect(notifier.state[0].steps[4].label, '保存文件');
      },
    );

    test('AudioSeparation task has 2 default steps (分离音频, 保存到文件)', () {
      final notifier = BackgroundTaskNotifier();
      notifier.addTask(type: BackgroundTaskType.audioSeparation, title: '音频分离');
      expect(
        notifier.state[0].steps.length,
        2,
        reason: 'AudioSeparation should have 2 steps (分离音频, 保存到文件)',
      );
      expect(notifier.state[0].steps[0].label, '分离音频');
      expect(notifier.state[0].steps[1].label, '保存到文件');
    });

    // ==================================================================
    // Raw diagnostics (rawRequest/rawResponse) tests
    // ==================================================================

    test(
      'legacy OCR request bodies retain only the unavailable image count',
      () {
        final encodedImage = base64Encode(List<int>.filled(128 * 1024, 0x5a));
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-without-retry-snapshot',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/png;base64,$encodedImage',
                      },
                    },
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/png;base64,$encodedImage',
                      },
                    },
                  ],
                },
              ],
            },
          },
        });

        final retryData = task.retryData!;
        expect(retryData['version'], OcrRetrySnapshot.currentVersion);
        expect(retryData['modelRef'], {'modelId': 'vision-model'});
        expect(
          retryData['instructionContent'],
          'Read the receipt total carefully',
        );
        expect(retryData['images'], hasLength(2));
        expect(
          (retryData['images'] as List).every(
            (image) =>
                image is Map &&
                image['storageRef'] is String &&
                !image.containsKey('bytes'),
          ),
          isTrue,
        );
        final persisted = jsonEncode(task.toMap());
        expect(persisted, isNot(contains(encodedImage)));
        expect(persisted, isNot(contains('data:image/png;base64')));
        expect(persisted, contains('Read the receipt total carefully'));
      },
    );

    test(
      'legacy OCR migration omits model IDs matching an auth credential',
      () {
        const apiKey = 'opaque-provider-secret-value-92';
        BackgroundTask taskFor(String id, String authorization) =>
            BackgroundTask.fromMap({
              'id': id,
              'type': 'ocr',
              'title': 'legacy OCR request',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'rawRequest': {
                'url': 'https://api.example.com/v1/chat/completions',
                'headers': {'Authorization': authorization},
                'body': {
                  'model': apiKey,
                  'messages': [
                    {
                      'role': 'user',
                      'content': [
                        {'type': 'text', 'text': 'Read the document carefully'},
                      ],
                    },
                  ],
                },
              },
            });

        for (final entry in [
          ('full', 'Bearer $apiKey'),
          ('masked', 'Bearer opaque-p...e-92'),
          ('unicode ellipsis', 'Bearer opaque-p…e-92'),
        ]) {
          final task = taskFor('legacy-ocr-secret-model-${entry.$1}', entry.$2);
          final retryData = task.retryData!;
          final persisted = jsonEncode(task.toMap());
          expect(retryData['modelRef'], isEmpty);
          expect(
            OcrRetrySnapshot.fromMap(retryData).instructionContent,
            'Read the document carefully',
          );
          expect(persisted, isNot(contains(apiKey)));
        }
      },
    );

    test('legacy OCR request context survives when image count is unknown', () {
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-unknown-image-count',
        'type': 'ocr',
        'title': 'legacy OCR request',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'url': 'https://api.example.com/v1/chat/completions',
          'body': {
            'model': 'vision-model',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': 'Read the document carefully'},
                ],
              },
            ],
          },
        },
      });

      final snapshot = OcrRetrySnapshot.fromMap(task.retryData!);
      expect(snapshot.imageEntryCount, 0);
      expect(snapshot.modelId, 'vision-model');
      expect(snapshot.instructionContent, 'Read the document carefully');
      expect(jsonEncode(task.toMap()), contains('Read the document carefully'));
    });

    test(
      'current OCR retry snapshots drop unknown fields before later writes',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'current-v2-with-unknown-inline-data';
        const apiKey = 'unsupported-v2-credential-155';
        final imageBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          1,
          2,
          3,
        ]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
            instructionContent: 'Read the document carefully',
          ),
        );
        final imageEntries = retryData['images'] as List<dynamic>;
        final imageEntry = Map<String, dynamic>.from(imageEntries.single as Map)
          ..['imageData'] = 'data:image/png;base64,${base64Encode(imageBytes)}';
        imageEntries[0] = imageEntry;
        retryData['apiKey'] = apiKey;
        final cacheReference = imageEntry['storageRef'] as String;
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'ocr',
              'title': 'Current OCR retry with ignored extensions',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [
                {'label': 'OCR', 'status': 'pending'},
              ],
              'retryData': retryData,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          notifier.updateStep(taskId, 0, completed: true);
          await notifier.pendingPersistence;

          final persisted = jsonDecode(await file.readAsString()) as List;
          final persistedTask = persisted.single as Map<String, dynamic>;
          final persistedRetry =
              persistedTask['retryData'] as Map<String, dynamic>;
          final encodedRetry = jsonEncode(persistedRetry);
          expect(encodedRetry, isNot(contains(apiKey)));
          expect(encodedRetry, isNot(contains('imageData')));
          expect(encodedRetry, isNot(contains('data:image/png;base64')));
          expect(persistedRetry['version'], OcrRetrySnapshot.currentVersion);
          final persistedImage =
              (persistedRetry['images'] as List).single as Map;
          expect(persistedImage['storageRef'], cacheReference);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'restore defers legacy retry persistence until cache migration succeeds',
      () async {
        WebFileStore.enableTestMode();
        final bytes = Uint8List.fromList(List<int>.filled(64 * 1024, 0x5a));
        final encodedBytes = base64Encode(bytes);
        final taskFile = _tasksFileIn(testDir.path);
        var rejectCacheWrites = true;
        var cacheWriteAttempts = 0;
        OcrRetryStorage.debugBeforeCacheWrite = (_, _) async {
          cacheWriteAttempts++;
          if (rejectCacheWrites) throw StateError('temporary cache failure');
        };
        final originalData = {
          'id': 'legacy-retry',
          'type': 'ocr',
          'title': 'legacy OCR retry',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': 'step', 'status': 'pending'},
          ],
          'retryData': {
            'type': 'ocr',
            'version': 1,
            'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
            'instructionContent': 'Read the receipt total',
            'images': [
              {'bytes': encodedBytes, 'format': 'png', 'name': 'receipt.png'},
            ],
          },
        };
        final originalContent = jsonEncode([originalData]);
        await taskFile.parent.create(recursive: true);
        await taskFile.writeAsString(originalContent);
        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final task = notifier.state.single;
          final snapshot = OcrRetrySnapshot.fromMap(task.retryData!);

          expect(task.retryData!['version'], 1);
          expect(snapshot.imageEntryCount, 1);
          expect(snapshot.instructionContent, 'Read the receipt total');
          expect(
            await OcrRetryStorage.restoreImages(snapshot),
            isA<OcrRetryRestoreResult>().having(
              (result) => result.isComplete,
              'complete image set',
              isTrue,
            ),
          );
          expect(snapshot.images.single.bytes, bytes);
          expect(await taskFile.readAsString(), originalContent);

          notifier.updateStep('legacy-retry', 0, completed: true);
          await notifier.pendingPersistence;
          notifier.updateStep('legacy-retry', 0, running: true);
          await notifier.pendingPersistence;
          expect(cacheWriteAttempts, 3);
          expect(await taskFile.readAsString(), originalContent);
          expect(
            OcrRetrySnapshot.fromMap(
              notifier.state.single.retryData!,
            ).images.single.bytes,
            bytes,
          );

          rejectCacheWrites = false;
          notifier.updateStep('legacy-retry', 0, completed: true);
          await notifier.pendingPersistence;

          final migrated = OcrRetrySnapshot.fromMap(
            notifier.state.single.retryData!,
          );
          expect(migrated.version, OcrRetrySnapshot.currentVersion);
          expect(migrated.images.single.bytes, isNull);
          expect(
            (await OcrRetryStorage.restoreImages(migrated)).isComplete,
            isTrue,
          );
          final persisted = await taskFile.readAsString();
          expect(persisted, isNot(contains(encodedBytes)));
          expect(persisted, contains('ocr_retry_cache/'));

          final restoredNotifier = BackgroundTaskNotifier();
          try {
            await restoredNotifier.restoreFromPersistence();
            final persistedRetry = OcrRetrySnapshot.fromMap(
              restoredNotifier.state.single.retryData!,
            );
            expect(
              (await OcrRetryStorage.restoreImages(persistedRetry)).isComplete,
              isTrue,
            );
          } finally {
            restoredNotifier.dispose();
            await restoredNotifier.pendingPersistence;
          }
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'restore defers mixed legacy retry persistence when a valid image write fails',
      () async {
        WebFileStore.enableTestMode();
        final bytes = Uint8List.fromList(List<int>.filled(96, 0x37));
        final encodedBytes = base64Encode(bytes);
        final taskFile = _tasksFileIn(testDir.path);
        var rejectCacheWrites = true;
        var cacheWriteAttempts = 0;
        OcrRetryStorage.debugBeforeCacheWrite = (_, _) async {
          cacheWriteAttempts++;
          if (rejectCacheWrites) throw StateError('temporary cache failure');
        };
        final originalContent = jsonEncode([
          {
            'id': 'mixed-legacy-retry',
            'type': 'ocr',
            'title': 'mixed legacy OCR retry',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': 'step', 'status': 'pending'},
            ],
            'retryData': {
              'type': 'ocr',
              'version': 1,
              'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
              'instructionContent': 'Read the receipt total',
              'images': [
                {'bytes': encodedBytes, 'format': 'png'},
                {'bytes': 'not-base64!', 'format': 'jpeg'},
              ],
            },
          },
        ]);
        await taskFile.parent.create(recursive: true);
        await taskFile.writeAsString(originalContent);

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          var snapshot = OcrRetrySnapshot.fromMap(
            notifier.state.single.retryData!,
          );
          expect(snapshot.version, 1);
          expect(snapshot.hasInvalidImages, isTrue);
          expect(snapshot.images.single.bytes, bytes);
          expect(await taskFile.readAsString(), originalContent);

          notifier.updateStep('mixed-legacy-retry', 0, completed: true);
          await notifier.pendingPersistence;
          expect(cacheWriteAttempts, 2);
          expect(await taskFile.readAsString(), originalContent);

          rejectCacheWrites = false;
          notifier.updateStep('mixed-legacy-retry', 0, running: true);
          await notifier.pendingPersistence;

          snapshot = OcrRetrySnapshot.fromMap(notifier.state.single.retryData!);
          expect(snapshot.version, OcrRetrySnapshot.currentVersion);
          expect(snapshot.imageEntryCount, 2);
          expect(snapshot.images, hasLength(2));
          final restored = await OcrRetryStorage.restoreImages(snapshot);
          expect(restored.isComplete, isFalse);
          expect(restored.missingImageCount, 1);
          expect(restored.images.single.bytes, bytes);
          expect(
            await OcrRetryStorage.read(snapshot.images.first.storageRef!),
            bytes,
          );
          final persisted = await taskFile.readAsString();
          expect(persisted, isNot(contains(encodedBytes)));
          expect(persisted, isNot(contains('not-base64!')));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'restore preserves inline bytes when a stale cache reference is present',
      () async {
        WebFileStore.enableTestMode();
        final bytes = Uint8List.fromList(List<int>.filled(96, 0x4b));
        final encodedBytes = base64Encode(bytes);
        final taskFile = _tasksFileIn(testDir.path);
        var rejectCacheWrites = true;
        var cacheWriteAttempts = 0;
        OcrRetryStorage.debugBeforeCacheWrite = (_, _) async {
          cacheWriteAttempts++;
          if (rejectCacheWrites) throw StateError('temporary cache failure');
        };
        final originalContent = jsonEncode([
          {
            'id': 'stale-reference-legacy-retry',
            'type': 'ocr',
            'title': 'legacy OCR retry',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': 'step', 'status': 'pending'},
            ],
            'retryData': {
              'type': 'ocr',
              'version': 1,
              'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
              'instructionContent': 'Read the receipt total',
              'images': [
                {
                  'bytes': encodedBytes,
                  'storageRef': '../stale-reference.bin',
                  'format': 'png',
                },
              ],
            },
          },
        ]);
        await taskFile.parent.create(recursive: true);
        await taskFile.writeAsString(originalContent);

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          var snapshot = OcrRetrySnapshot.fromMap(
            notifier.state.single.retryData!,
          );
          expect(snapshot.version, 1);
          expect(snapshot.images.single.bytes, bytes);
          expect(snapshot.images.single.storageRef, isNull);
          expect(cacheWriteAttempts, 1);
          expect(await taskFile.readAsString(), originalContent);

          notifier.updateStep(
            'stale-reference-legacy-retry',
            0,
            completed: true,
          );
          await notifier.pendingPersistence;
          expect(cacheWriteAttempts, 2);
          expect(await taskFile.readAsString(), originalContent);

          rejectCacheWrites = false;
          notifier.updateStep('stale-reference-legacy-retry', 0, running: true);
          await notifier.pendingPersistence;

          snapshot = OcrRetrySnapshot.fromMap(notifier.state.single.retryData!);
          expect(snapshot.version, OcrRetrySnapshot.currentVersion);
          expect(snapshot.images.single.bytes, isNull);
          final restored = await OcrRetryStorage.restoreImages(snapshot);
          expect(restored.isComplete, isTrue);
          expect(restored.images.single.bytes, bytes);
          final persisted = await taskFile.readAsString();
          expect(persisted, isNot(contains(encodedBytes)));
          expect(persisted, isNot(contains('../stale-reference.bin')));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'empty legacy image bodies are sanitized without deferring task updates',
      () async {
        WebFileStore.enableTestMode();
        final taskFile = _tasksFileIn(testDir.path);
        await taskFile.parent.create(recursive: true);
        await taskFile.writeAsString(
          jsonEncode([
            {
              'id': 'empty-legacy-retry',
              'type': 'ocr',
              'title': 'empty legacy OCR retry',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [
                {'label': 'step', 'status': 'pending'},
              ],
              'retryData': {
                'type': 'ocr',
                'version': 1,
                'modelRef': {'configId': 'config-1', 'modelId': 'model-1'},
                'images': [
                  {'bytes': '', 'format': 'png'},
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          var snapshot = OcrRetrySnapshot.fromMap(
            notifier.state.single.retryData!,
          );
          expect(snapshot.version, OcrRetrySnapshot.currentVersion);
          expect(snapshot.imageEntryCount, 1);
          expect(snapshot.images.single.bytes, isNull);
          expect(
            (await OcrRetryStorage.restoreImages(snapshot)).missingImageCount,
            1,
          );

          notifier.updateStep('empty-legacy-retry', 0, completed: true);
          await notifier.pendingPersistence;
          snapshot = OcrRetrySnapshot.fromMap(notifier.state.single.retryData!);
          expect(snapshot.version, OcrRetrySnapshot.currentVersion);
          expect(snapshot.imageEntryCount, 1);
          expect(snapshot.images.single.bytes, isNull);

          final persisted = await taskFile.readAsString();
          expect(persisted, isNot(contains('"bytes"')));
          final persistedTasks = jsonDecode(persisted) as List;
          final persistedSteps =
              (persistedTasks.single as Map)['steps'] as List;
          expect((persistedSteps.single as Map)['status'], 'completed');
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'legacy OCR instruction migration drops credentials from request text',
      () {
        const apiKey = 'opaque-user-secret-87';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-instruction-with-secret',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer $apiKey'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {
                      'type': 'text',
                      'text': 'The value to recognize is $apiKey',
                    },
                    {'type': 'text', 'text': 'Authorization: Bearer $apiKey'},
                  ],
                },
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt total carefully',
        );
        expect(persisted, contains('Read the receipt total carefully'));
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains('Authorization:')));
      },
    );

    test(
      'legacy OCR instruction migration redacts a short masked prefix embedded in an echoed key',
      () {
        const apiKey = 'xsecretQwrtyPSDF89';
        const instruction = 'Read the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-masked-prefix-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Read the receipt using [redacted]');
        expect(persisted, contains('Read the receipt using [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short numeric tails after an embedded mask prefix',
      () {
        const apiKey = 'xsecret12345';
        const instruction = 'Read $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-numeric-tail-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read [redacted]',
        );
        expect(serializedRetryData['instructionContent'], 'Read [redacted]');
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts a short-prefix credential split by a newline',
      () {
        const apiKey = 'abcQwrty123';
        const instruction =
            'Please review the receipt using abc\nQwrty123 to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-newline-split-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          persisted,
          contains(
            'Please review the receipt using [redacted] to process this image',
          ),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted.replaceAll(r'\n', ''), isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase recognize command under a prefix-only mask',
      () {
        const instruction = 'recognize the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-recognize-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer recogniz…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded short-prefix credential split by a newline',
      () {
        const apiKey = 'xsecretQwrtyPSDF89';
        const instruction =
            'Please review the receipt using xsecret\nQwrtyPSDF89 to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-prefix-newline-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          persisted,
          contains(
            'Please review the receipt using [redacted] to process this image',
          ),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted.replaceAll(r'\n', ''), isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts a Unicode tail from an embedded short-prefix credential',
      () {
        const apiKey = 'xsecretQwrty123åø';
        const instruction =
            'Please review the receipt using $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-prefix-unicode-tail-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Please review the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains('åø')));
      },
    );

    test(
      'legacy OCR instruction migration detects Unicode short-prefix credentials without digits',
      () {
        const apiKey = 'xsecretQwrtyåø';
        const instruction =
            'Please review the receipt using $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-prefix-unicode-alpha-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Please review the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains('åø')));
      },
    );

    test(
      'legacy OCR instruction migration detects Unicode numeric short-prefix credentials',
      () {
        const apiKey = 'xsecretQwrty١٢';
        const instruction =
            'Please review the receipt using $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-prefix-unicode-number-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Please review the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains('١٢')));
      },
    );

    test(
      'legacy OCR instruction migration detects numeric echoes of Unicode natural words',
      () {
        const apiKey = 'xsecretária123';
        const instruction =
            'Read the receipt using $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-unicode-natural-word-numeric-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Read the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural credential words embedded in keys',
      () {
        const apiKey = 'xauthentication';
        const instruction =
            'Read the receipt using $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-natural-credential-word-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer auth…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Read the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short natural word echoes in credential use context',
      () {
        const apiKey = 'xsecretariat';
        const instruction = 'Please use $apiKey for the request';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-natural-word-request-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Please use [redacted] for the request',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Please use [redacted] for the request',
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short prefixes in explicit credential use context',
      () {
        const apiKey = 'xabcQwrtyPSDF';
        const instruction =
            'Please use $apiKey for the request; read the receipt total carefully.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-explicit-credential-use-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please use [redacted] for the request; read the receipt total carefully.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('read the receipt total carefully'));
      },
    );

    test(
      'legacy OCR instruction migration redacts embedded natural words in use-to-process context',
      () {
        const apiKey = 'xsecretariat';
        const instruction =
            'Please use $apiKey to process this image; read the receipt total carefully.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-natural-word-use-to-process-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please use [redacted] to process this image; read the receipt total carefully.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('read the receipt total carefully'));
      },
    );

    test(
      'legacy OCR instruction migration preserves a natural use-to-process prompt',
      () {
        const instruction = 'Please use secretariat to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-use-to-process-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(serializedRetryData['instructionContent'], instruction);
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration redacts keys in using-to-process context',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction =
            'Please review the receipt using $apiKey to process this image.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-key-using-to-process-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please review the receipt using [redacted] to process this image.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded printed identifier echo',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction =
            'Read the receipt and transcribe the printed identifier $apiKey.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-printed-identifier-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Read the receipt and transcribe the printed identifier [redacted].';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('Read the receipt'));
      },
    );

    test(
      'legacy OCR instruction migration redacts identified credential labels',
      () {
        const apiKey = 'xsecretQmXvP';
        for (final identifier in [
          'the printed identifier',
          'the code',
          'the account number',
          'the serial number',
          'the invoice number',
          'the tracking number',
          'the order number',
          'the ID',
          'the value',
        ]) {
          final instruction =
              'Please identify $identifier $apiKey from the receipt and count the columns.';
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-identified-printed-key-value-echo',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer secret…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': instruction},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());
          final serializedRetryData = (jsonDecode(persisted)
              as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
          final sanitizedInstruction =
              'Please identify $identifier [redacted] from the receipt and count the columns.';

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            sanitizedInstruction,
          );
          expect(
            serializedRetryData['instructionContent'],
            sanitizedInstruction,
          );
          expect(persisted, isNot(contains(apiKey)));
          expect(persisted, contains('count the columns'));
        }
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded transcribed key value',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction = 'Please transcribe $apiKey from the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-transcribed-key-value-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please transcribe [redacted] from the receipt.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded key read from a receipt',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction =
            'Please read $apiKey from the receipt and count the columns.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-read-key-value-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please read [redacted] from the receipt and count the columns.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('count the columns'));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded key extracted from a receipt',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction =
            'Please extract $apiKey from the receipt and count the columns.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-extract-key-value-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please extract [redacted] from the receipt and count the columns.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('count the columns'));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded key identified from a receipt',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction =
            'Please identify $apiKey from the receipt and count the columns.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-identify-key-value-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please identify [redacted] from the receipt and count the columns.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('count the columns'));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded key recognized from a receipt',
      () {
        const apiKey = 'xsecretQmXvP';
        const instruction =
            'Please recognize $apiKey from the receipt and count the columns.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-recognize-key-value-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        const sanitizedInstruction =
            'Please recognize [redacted] from the receipt and count the columns.';

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(serializedRetryData['instructionContent'], sanitizedInstruction);
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, contains('count the columns'));
      },
    );

    test(
      'legacy OCR instruction migration preserves authentication documentation prompts',
      () {
        for (final instruction in [
          'Read the authentication guide',
          'Read the authentication manual',
          'Please read the authentication instructions',
          'Could you read the authentication message?',
          'Read the authentication flow diagram',
          'Read the authentication table',
          'Read the authentication label',
          'Please read authentication instructions',
          'Please read authentication documentation',
          'Please read authorization documentation',
          'Explain the authentication process',
          'Explain authentication methods',
          'Explain the authentication screen',
          'Explain the authentication settings',
          'Summarize the authentication message',
          'Read my authentication message',
        ]) {
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-authentication-guide-prompt',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer auth…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': instruction},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());
          final serializedRetryData = (jsonDecode(persisted)
              as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            instruction,
          );
          expect(serializedRetryData['instructionContent'], instruction);
          expect(persisted, contains(instruction));
        }
      },
    );

    test(
      'legacy OCR instruction migration preserves natural words after using',
      () {
        const instruction =
            'Please inspect the receipt. The memo describes using authorities for the request.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-authorities-after-using',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer auth…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(serializedRetryData['instructionContent'], instruction);
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration redacts combining marks in embedded short-prefix credentials',
      () {
        const apiKey = 'xsecretQwrty\u0301';
        const instruction =
            'Please review the receipt using $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-short-prefix-combining-mark-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Please review the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains('\u0301')));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase transcribe command under a prefix-only mask',
      () {
        const instruction = 'transcribe the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-transcribe-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer transcrib…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration redacts a three-character embedded prefix split by a newline',
      () {
        const apiKey = 'xabcQwrt123';
        const instruction =
            'Please review the receipt using xabc\nQwrt123 to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-three-character-embedded-newline-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Please review the receipt using [redacted] to process this image',
        );
        expect(
          persisted,
          contains(
            'Please review the receipt using [redacted] to process this image',
          ),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted.replaceAll(r'\n', ''), isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase summarize command under a prefix-only mask',
      () {
        const instruction = 'summarize the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-summarize-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer summariz…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase interpret command under a prefix-only mask',
      () {
        const instruction = 'interpret the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-interpret-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer interpre…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase translate command under a prefix-only mask',
      () {
        const instruction = 'translate the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-translate-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer translat…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase calculate command under a prefix-only mask',
      () {
        const instruction = 'calculate the total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-calculate-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer calculat…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase categorize command under a prefix-only mask',
      () {
        const instruction = 'categorize this receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-categorize-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer categoriz…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase enumerate command under a prefix-only mask',
      () {
        const instruction = 'enumerate the receipt items';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-enumerate-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer enumerat…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase determine command under a prefix-only mask',
      () {
        const instruction = 'determine the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-determine-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer determin…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a lowercase highlight command under a prefix-only mask',
      () {
        const instruction = 'highlight the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-highlight-command-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer highligh…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwriting read prompt under a prefix-only mask',
      () {
        const instruction = 'read the handwriting on this receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwriting-read-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwrit…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwritten text prompt under a prefix-only mask',
      () {
        const instruction = 'read the handwritten text';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwritten-text-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a sentence-ending handwriting prompt under a prefix-only mask',
      () {
        const instruction = 'read the handwriting.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwriting-sentence-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwrit…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a transcribe handwriting prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe the handwriting';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-transcribe-handwriting-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwrit…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a polite transcribe handwriting prompt under a prefix-only mask',
      () {
        const instruction = 'Could you please transcribe the handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-polite-transcribe-handwriting-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwriting in-image prompt under a prefix-only mask',
      () {
        const instruction = 'Read the handwriting in the image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwriting-in-image-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwrit…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an all-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe all handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-all-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an any-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe any handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-any-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a some-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe some handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-some-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an all-of-the handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe all of the handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-all-of-the-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an all-of-this handwritten-note prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe all of this handwritten note';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-all-of-this-handwritten-note-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an all-of-my handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe all of my handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-all-of-my-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a some-of-the handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe some of the handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-some-of-the-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an each-of-the handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe each of the handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-each-of-the-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an every-handwritten-note prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe every handwritten note';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-every-handwritten-note-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a both-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe both handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-both-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a both-of-the handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe both of the handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-both-of-the-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a one-of-the handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe one of the handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-one-of-the-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a several-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe several handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-several-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a multiple-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe multiple handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-multiple-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a many-handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe many handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-many-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an a-few handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe a few handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-a-few-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an a-couple-of handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe a couple of handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-a-couple-of-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves an a-pair-of handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe a pair of handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-a-pair-of-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a possessive handwritten-note prompt under a prefix-only mask',
      () {
        const instruction = 'Please transcribe my handwritten note';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-possessive-handwritten-note-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwritten receipt prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe the handwritten receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwritten-receipt-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwritten invoice prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe the handwritten invoice';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwritten-invoice-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwritten form prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe the handwritten form';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwritten-form-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a handwritten document prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe the handwritten document';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-handwritten-document-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a longer handwritten-document prompt under a prefix-only mask',
      () {
        const instruction =
            'Please transcribe all of the text in the handwritten note';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-longer-handwritten-document-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves a numeric handwritten-notes prompt under a prefix-only mask',
      () {
        const instruction = 'Transcribe two handwritten notes';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-numeric-handwritten-notes-prompt-natural-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer handwritt…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration redacts masked credential echoes split by a newline',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instructions = [
          'Read the receipt using opaque-user-\nsecret-87',
          'Read the receipt using opaque-user\n-secret-87',
        ];
        for (var index = 0; index < instructions.length; index++) {
          final instruction = instructions[index];
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-newline-split-masked-key-echo-$index',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer opaque-user-…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': instruction},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());
          final migratedInstruction = OcrRetrySnapshot.fromMap(
            task.retryData!,
          ).instructionContent;

          expect(migratedInstruction, 'Read the receipt using [redacted]');
          expect(persisted, contains('Read the receipt using [redacted]'));
          expect(migratedInstruction, isNot(contains(apiKey)));
          expect(persisted, isNot(contains(instruction)));
        }
      },
    );

    test(
      'legacy OCR instruction migration redacts a high-entropy echo split after an internal mask separator',
      () {
        const apiKey = 'opaque-userQwrtyPSDF89';
        const instruction =
            'Read the receipt using opaque-user\nQwrtyPSDF89 to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-internal-separator-newline-split-masked-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt using [redacted] to process this image',
        );
        expect(
          serializedRetryData['instructionContent'],
          'Read the receipt using [redacted] to process this image',
        );
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains('QwrtyPSDF89')));
      },
    );

    test(
      'legacy OCR instruction migration does not persist a credential split across bare text parts',
      () {
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-bare-part-boundary-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': 'opaque-user'},
                    {'type': 'text', 'text': 'for'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, isNull);
        expect(persisted, isNot(contains('opaque-user\nfor')));
      },
    );

    test(
      'legacy OCR instruction migration recognizes a masked request credential',
      () {
        const apiKey = 'opaque-user-secret-87';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-masked-instruction-secret',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-u...t-87'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {
                      'type': 'text',
                      'text': 'The value to recognize is $apiKey',
                    },
                  ],
                },
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt total carefully',
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration drops keys echoed under prefix-only Unicode auth masks',
      () {
        const apiKey = 'opaque-user-secret-value-179';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-prefix-only-unicode-auth-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                  ],
                },
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt total carefully\n'
          'Use [redacted] to process this image',
        );
        expect(persisted, contains('Read the receipt total carefully'));
        expect(persisted, contains('Use [redacted] to process this image'));
        expect(persisted, isNot(contains(apiKey)));

        final spacedMaskTask = BackgroundTask.fromMap({
          'id': 'legacy-ocr-prefix-only-unicode-auth-mask-with-space',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user- …'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                  ],
                },
              ],
            },
          },
        });
        final spacedMaskPersisted = jsonEncode(spacedMaskTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            spacedMaskTask.retryData!,
          ).instructionContent,
          'Read the receipt total carefully\n'
          'Use [redacted] to process this image',
        );
        expect(
          spacedMaskPersisted,
          contains('Read the receipt total carefully'),
        );
        expect(
          spacedMaskPersisted,
          contains('Use [redacted] to process this image'),
        );
        expect(spacedMaskPersisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves can-you prompts while redacting keys',
      () {
        const apiKey = 'opaque-user-secret-value-179';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-can-you-prefix-only-auth-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Can you read the receipt using $apiKey',
                    },
                  ],
                },
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Can you read the receipt using [redacted]',
        );
        expect(
          persisted,
          contains('Can you read the receipt using [redacted]'),
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration drops keys echoed under token-scheme auth masks',
      () {
        const apiKey = 'opaque-user-secret-token-191';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-token-scheme-prefix-only-auth-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Token opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                  ],
                },
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt total carefully\n'
          'Use [redacted] to process this image',
        );
        expect(persisted, contains('Read the receipt total carefully'));
        expect(persisted, contains('Use [redacted] to process this image'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration handles short open-ended masks without dropping ordinary prompts',
      () {
        const apiKey = 'abc1234567890abcdef';
        const shorterApiKey = 'abc12345';
        const shortestApiKey = 'abc1234';
        const safePrompt = 'Read the receipt total carefully';
        const redactedShortUsePrompt = 'Use [redacted] to process this image';
        BackgroundTask taskFor(
          String id,
          List<String> textParts, {
          String credentialPrefix = 'abc',
        }) =>
            BackgroundTask.fromMap({
              'id': id,
              'type': 'ocr',
              'title': 'legacy OCR request',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'rawRequest': {
                'url': 'https://api.example.com/v1/chat/completions',
                'headers': {'Authorization': 'Bearer $credentialPrefix…'},
                'body': {
                  'model': 'vision-model',
                  'messages': [
                    {
                      'role': 'user',
                      'content': [
                        for (final text in textParts)
                          {'type': 'text', 'text': text},
                      ],
                    },
                  ],
                },
              },
            });

        final echoedKeyTask = taskFor('legacy-ocr-short-prefix-echoed-key', [
          safePrompt,
          'Use $apiKey to process this image',
        ]);
        final echoedKeyPersisted = jsonEncode(echoedKeyTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(echoedKeyTask.retryData!).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(echoedKeyPersisted, contains(safePrompt));
        expect(echoedKeyPersisted, isNot(contains(apiKey)));

        const shortUsePrompt = 'Use $apiKey to process this image';
        final shortUseTask = taskFor(
          'legacy-ocr-short-prefix-safe-use-with-key',
          [shortUsePrompt],
        );
        final shortUsePersisted = jsonEncode(shortUseTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(shortUseTask.retryData!).instructionContent,
          redactedShortUsePrompt,
        );
        expect(shortUsePersisted, contains(redactedShortUsePrompt));
        expect(shortUsePersisted, isNot(contains(apiKey)));

        const shortUnclassifiedKey = 'abcwhatever';
        final shortUnclassifiedKeyTask = taskFor(
          'legacy-ocr-short-prefix-unclassified-alpha-echo',
          [safePrompt, 'Use $shortUnclassifiedKey to process this image'],
        );
        final shortUnclassifiedKeyPersisted = jsonEncode(
          shortUnclassifiedKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortUnclassifiedKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(shortUnclassifiedKeyPersisted, contains(safePrompt));
        expect(
          shortUnclassifiedKeyPersisted,
          isNot(contains(shortUnclassifiedKey)),
        );

        const shortRandomAlphaKey = 'abcwhjkl';
        final shortRandomAlphaTask = taskFor(
          'legacy-ocr-short-prefix-random-alpha-echo',
          [safePrompt, 'Use $shortRandomAlphaKey to process this image'],
        );
        final shortRandomAlphaPersisted = jsonEncode(
          shortRandomAlphaTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortRandomAlphaTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(shortRandomAlphaPersisted, contains(safePrompt));
        expect(shortRandomAlphaPersisted, isNot(contains(shortRandomAlphaKey)));

        const secretPrefixedKey = 'secretmango';
        final secretPrefixedTask = taskFor(
          'legacy-ocr-short-credential-word-prefix-echo',
          [safePrompt, 'Use $secretPrefixedKey to process this image'],
          credentialPrefix: 'secret',
        );
        final secretPrefixedPersisted = jsonEncode(secretPrefixedTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            secretPrefixedTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(secretPrefixedPersisted, contains(safePrompt));
        expect(secretPrefixedPersisted, isNot(contains(secretPrefixedKey)));

        const secretaryPrompt = 'Please ask the secretary carefully';
        final secretaryTask = taskFor(
          'legacy-ocr-short-credential-word-natural-completion',
          [secretaryPrompt],
          credentialPrefix: 'secret',
        );
        expect(
          OcrRetrySnapshot.fromMap(secretaryTask.retryData!).instructionContent,
          secretaryPrompt,
        );

        const secretMenuPrompt = 'Read the secret-menu label';
        final secretMenuTask = taskFor(
          'legacy-ocr-short-credential-word-hyphenated-term',
          [secretMenuPrompt],
          credentialPrefix: 'secret-',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            secretMenuTask.retryData!,
          ).instructionContent,
          secretMenuPrompt,
        );

        final unhyphenatedSecretMenuTask = taskFor(
          'legacy-ocr-short-credential-word-unhyphenated-natural-term',
          [secretMenuPrompt],
          credentialPrefix: 'secret',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            unhyphenatedSecretMenuTask.retryData!,
          ).instructionContent,
          secretMenuPrompt,
        );
        expect(
          jsonEncode(unhyphenatedSecretMenuTask.toMap()),
          contains(secretMenuPrompt),
        );

        const secretHyphenatedKey = 'secret-qwertyuiop';
        final secretHyphenatedKeyTask = taskFor(
          'legacy-ocr-short-credential-word-hyphenated-key',
          [safePrompt, 'The note says $secretHyphenatedKey.'],
          credentialPrefix: 'secret-',
        );
        final secretHyphenatedKeyPersisted = jsonEncode(
          secretHyphenatedKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            secretHyphenatedKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(secretHyphenatedKeyPersisted, contains(safePrompt));
        expect(
          secretHyphenatedKeyPersisted,
          isNot(contains(secretHyphenatedKey)),
        );

        const shortSecretHyphenatedKey = 'secret-abacdf';
        final shortSecretHyphenatedKeyTask = taskFor(
          'legacy-ocr-short-credential-word-open-ended-hyphenated-key',
          [safePrompt, 'The note says $shortSecretHyphenatedKey.'],
          credentialPrefix: 'secret',
        );
        final shortSecretHyphenatedKeyPersisted = jsonEncode(
          shortSecretHyphenatedKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortSecretHyphenatedKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(shortSecretHyphenatedKeyPersisted, contains(safePrompt));
        expect(
          shortSecretHyphenatedKeyPersisted,
          isNot(contains(shortSecretHyphenatedKey)),
        );

        const secretPluralPrompt = 'Please keep secrets private';
        final secretPluralTask = taskFor(
          'legacy-ocr-short-credential-word-natural-plural',
          [safePrompt, secretPluralPrompt],
          credentialPrefix: 'secret',
        );
        final secretPluralPersisted = jsonEncode(secretPluralTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            secretPluralTask.retryData!,
          ).instructionContent,
          '$safePrompt\nPlease keep [redacted] private',
        );
        expect(secretPluralPersisted, contains(safePrompt));
        expect(
          secretPluralPersisted,
          contains('Please keep [redacted] private'),
        );
        expect(secretPluralPersisted, isNot(contains('secrets')));

        const tokenizationKey = 'tokenization';
        const tokenizationPrompt =
            'Review the $tokenizationKey rules carefully';
        final tokenizationTask = taskFor(
          'legacy-ocr-short-token-word-natural-completion',
          [safePrompt, tokenizationPrompt],
          credentialPrefix: 'token',
        );
        final tokenizationPersisted = jsonEncode(tokenizationTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            tokenizationTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$tokenizationPrompt',
        );
        expect(tokenizationPersisted, contains(safePrompt));
        expect(tokenizationPersisted, contains(tokenizationPrompt));

        const tokenizingKey = 'tokenizing';
        const tokenizingPrompt = 'Please read $tokenizingKey instructions';
        const redactedTokenizingPrompt = 'Please read [redacted] instructions';
        final tokenizingTask = taskFor(
          'legacy-ocr-short-token-word-verb-completion',
          [safePrompt, tokenizingPrompt],
          credentialPrefix: 'token',
        );
        final tokenizingPersisted = jsonEncode(tokenizingTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            tokenizingTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedTokenizingPrompt',
        );
        expect(tokenizingPersisted, contains(safePrompt));
        expect(tokenizingPersisted, contains(redactedTokenizingPrompt));
        expect(
          OcrRetrySnapshot.fromMap(
            tokenizingTask.retryData!,
          ).instructionContent,
          isNot(contains(tokenizingKey)),
        );
        expect(tokenizingPersisted, isNot(contains(tokenizingKey)));

        const tokenizePrompt = 'Please tokenize the receipt';
        final tokenizeTask = taskFor(
          'legacy-ocr-short-token-word-verb-completion',
          [safePrompt, tokenizePrompt],
          credentialPrefix: 'token',
        );
        final tokenizePersisted = jsonEncode(tokenizeTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(tokenizeTask.retryData!).instructionContent,
          '$safePrompt\n$tokenizePrompt',
        );
        expect(tokenizePersisted, contains(safePrompt));
        expect(tokenizePersisted, contains(tokenizePrompt));

        const unicodeCredentialEcho = 'qwrtypsdfåø';
        const unicodeCredentialInstruction =
            'Please use $unicodeCredentialEcho as API key';
        final unicodeCredentialTask = taskFor(
          'legacy-ocr-explicit-unicode-credential-use',
          [safePrompt, unicodeCredentialInstruction],
          credentialPrefix: 'qwrtypsdf',
        );
        final unicodeCredentialPersisted = jsonEncode(
          unicodeCredentialTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            unicodeCredentialTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(unicodeCredentialPersisted, contains(safePrompt));
        expect(
          OcrRetrySnapshot.fromMap(
            unicodeCredentialTask.retryData!,
          ).instructionContent,
          isNot(contains(unicodeCredentialEcho)),
        );
        expect(
          unicodeCredentialPersisted,
          isNot(contains(unicodeCredentialEcho)),
        );

        const contextFreeUnicodeCredentialEcho = 'qwrtypsdfåø';
        const contextFreeUnicodeInstruction =
            'The receipt includes $contextFreeUnicodeCredentialEcho.';
        final contextFreeUnicodeTask = taskFor(
          'legacy-ocr-context-free-unicode-credential-echo',
          [safePrompt, contextFreeUnicodeInstruction],
          credentialPrefix: 'qwrtypsdf',
        );
        final contextFreeUnicodePersisted = jsonEncode(
          contextFreeUnicodeTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            contextFreeUnicodeTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(contextFreeUnicodePersisted, contains(safePrompt));
        expect(
          OcrRetrySnapshot.fromMap(
            contextFreeUnicodeTask.retryData!,
          ).instructionContent,
          isNot(contains(contextFreeUnicodeCredentialEcho)),
        );
        expect(
          contextFreeUnicodePersisted,
          isNot(contains(contextFreeUnicodeCredentialEcho)),
        );

        const plainTextKey = 'projectcereal';
        final plainTextKeyTask = taskFor(
          'legacy-ocr-short-prefix-unmarked-alpha-echo',
          [safePrompt, 'The note says $plainTextKey.'],
          credentialPrefix: 'project',
        );
        final plainTextKeyPersisted = jsonEncode(plainTextKeyTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            plainTextKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(plainTextKeyPersisted, contains(safePrompt));
        expect(plainTextKeyPersisted, isNot(contains(plainTextKey)));

        final emDashEchoTask = taskFor(
          'legacy-ocr-short-prefix-unmarked-alpha-echo-em-dash',
          [safePrompt, 'The note says $plainTextKey—'],
          credentialPrefix: 'project',
        );
        final emDashEchoPersisted = jsonEncode(emDashEchoTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            emDashEchoTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(emDashEchoPersisted, contains(safePrompt));
        expect(emDashEchoPersisted, isNot(contains(plainTextKey)));

        const spacedPrefixPrompt =
            'Review the project cereal receipt carefully';
        final spacedPrefixTask = taskFor(
          'legacy-ocr-short-prefix-natural-whitespace',
          [spacedPrefixPrompt],
          credentialPrefix: 'project',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            spacedPrefixTask.retryData!,
          ).instructionContent,
          spacedPrefixPrompt,
        );

        final shorterEchoedKeyTask = taskFor(
          'legacy-ocr-short-prefix-short-echoed-key',
          [safePrompt, 'Use $shorterApiKey to process this image'],
        );
        final shorterEchoedKeyPersisted = jsonEncode(
          shorterEchoedKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shorterEchoedKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(shorterEchoedKeyPersisted, contains(safePrompt));
        expect(shorterEchoedKeyPersisted, isNot(contains(shorterApiKey)));

        final shortestEchoedKeyTask = taskFor(
          'legacy-ocr-short-prefix-shortest-echoed-key',
          [safePrompt, 'Use $shortestApiKey to process this image'],
        );
        final shortestEchoedKeyPersisted = jsonEncode(
          shortestEchoedKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortestEchoedKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(shortestEchoedKeyPersisted, contains(safePrompt));
        expect(shortestEchoedKeyPersisted, isNot(contains(shortestApiKey)));

        final splitEchoedKeyTask = taskFor(
          'legacy-ocr-short-prefix-split-echoed-key',
          [safePrompt, 'Use abc', '12345 to process this image'],
        );
        final splitEchoedKeyPersisted = jsonEncode(splitEchoedKeyTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            splitEchoedKeyTask.retryData!,
          ).instructionContent,
          isNull,
        );
        expect(splitEchoedKeyPersisted, isNot(contains('Use abc')));
        expect(
          splitEchoedKeyPersisted,
          isNot(contains('12345 to process this image')),
        );

        const singleCharacterPrefixKey = 'abc123';
        final singleCharacterPrefixTask = taskFor(
          'legacy-ocr-single-character-prefix-echoed-key',
          [safePrompt, 'Use $singleCharacterPrefixKey to process this image'],
          credentialPrefix: 'a',
        );
        final singleCharacterPrefixPersisted = jsonEncode(
          singleCharacterPrefixTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            singleCharacterPrefixTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(singleCharacterPrefixPersisted, contains(safePrompt));
        expect(
          singleCharacterPrefixPersisted,
          isNot(contains(singleCharacterPrefixKey)),
        );

        const alphabeticShortKey = 'abcdefghijk';
        final alphabeticShortKeyTask = taskFor(
          'legacy-ocr-single-character-prefix-alphabetic-echo',
          [safePrompt, 'Use $alphabeticShortKey for this receipt'],
          credentialPrefix: 'a',
        );
        final alphabeticShortKeyPersisted = jsonEncode(
          alphabeticShortKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            alphabeticShortKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(alphabeticShortKeyPersisted, contains(safePrompt));
        expect(
          alphabeticShortKeyPersisted,
          isNot(contains(alphabeticShortKey)),
        );

        const shortestAlphabeticKey = 'abcdefgh';
        final shortestAlphabeticKeyTask = taskFor(
          'legacy-ocr-single-character-prefix-short-alphabetic-echo',
          [safePrompt, 'Use $shortestAlphabeticKey for this receipt'],
          credentialPrefix: 'a',
        );
        final shortestAlphabeticKeyPersisted = jsonEncode(
          shortestAlphabeticKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortestAlphabeticKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(shortestAlphabeticKeyPersisted, contains(safePrompt));
        expect(
          shortestAlphabeticKeyPersisted,
          isNot(contains(shortestAlphabeticKey)),
        );

        const longAlphabeticPrefixKey = 'abcdefghijklmno';
        final longAlphabeticPrefixTask = taskFor(
          'legacy-ocr-long-alphabetic-prefix-echo',
          [safePrompt, 'Use $longAlphabeticPrefixKey for this receipt'],
          credentialPrefix: 'abcdefgh',
        );
        final longAlphabeticPrefixPersisted = jsonEncode(
          longAlphabeticPrefixTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            longAlphabeticPrefixTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(longAlphabeticPrefixPersisted, contains(safePrompt));
        expect(
          longAlphabeticPrefixPersisted,
          isNot(contains(longAlphabeticPrefixKey)),
        );

        final shortAlphabeticPrefixTask = taskFor(
          'legacy-ocr-short-alphabetic-prefix-echo',
          [safePrompt, 'Use $longAlphabeticPrefixKey for this receipt'],
          credentialPrefix: 'abc',
        );
        final shortAlphabeticPrefixPersisted = jsonEncode(
          shortAlphabeticPrefixTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortAlphabeticPrefixTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(shortAlphabeticPrefixPersisted, contains(safePrompt));
        expect(
          shortAlphabeticPrefixPersisted,
          isNot(contains(longAlphabeticPrefixKey)),
        );

        const shortAlphabeticKey = 'abcabcdefghijk';
        final shortAlphabeticKeyTask = taskFor(
          'legacy-ocr-short-alphabetic-prefix-key',
          [safePrompt, 'Use $shortAlphabeticKey to process this image'],
          credentialPrefix: 'abc',
        );
        final shortAlphabeticKeyPersisted = jsonEncode(
          shortAlphabeticKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortAlphabeticKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(shortAlphabeticKeyPersisted, contains(safePrompt));
        expect(
          shortAlphabeticKeyPersisted,
          isNot(contains(shortAlphabeticKey)),
        );

        const nonAscendingShortKey = 'abcqwertyword';
        final nonAscendingShortKeyTask = taskFor(
          'legacy-ocr-short-nonascending-alphabetic-prefix-key',
          [safePrompt, 'Use $nonAscendingShortKey to process this image'],
          credentialPrefix: 'abc',
        );
        final nonAscendingShortKeyPersisted = jsonEncode(
          nonAscendingShortKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            nonAscendingShortKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(nonAscendingShortKeyPersisted, contains(safePrompt));
        expect(
          nonAscendingShortKeyPersisted,
          isNot(contains(nonAscendingShortKey)),
        );

        const keyboardSequenceKey = 'abcqwertyzxy';
        final keyboardSequenceTask = taskFor(
          'legacy-ocr-short-keyboard-sequence-key',
          [safePrompt, 'Use $keyboardSequenceKey to process this image'],
          credentialPrefix: 'abc',
        );
        final keyboardSequencePersisted = jsonEncode(
          keyboardSequenceTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            keyboardSequenceTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(keyboardSequencePersisted, contains(safePrompt));
        expect(keyboardSequencePersisted, isNot(contains(keyboardSequenceKey)));

        const highEntropyShortKey = 'abcxyzkqwe';
        final highEntropyShortKeyTask = taskFor(
          'legacy-ocr-short-high-entropy-key',
          [safePrompt, 'Use $highEntropyShortKey to process this image'],
          credentialPrefix: 'abc',
        );
        final highEntropyShortKeyPersisted = jsonEncode(
          highEntropyShortKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            highEntropyShortKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(highEntropyShortKeyPersisted, contains(safePrompt));
        expect(
          highEntropyShortKeyPersisted,
          isNot(contains(highEntropyShortKey)),
        );

        const repeatedLetterShortKey = 'abcxyzkqwx';
        final repeatedLetterShortKeyTask = taskFor(
          'legacy-ocr-short-repeated-letter-key',
          [safePrompt, 'Use $repeatedLetterShortKey to process this image'],
          credentialPrefix: 'abc',
        );
        final repeatedLetterShortKeyPersisted = jsonEncode(
          repeatedLetterShortKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            repeatedLetterShortKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\n$redactedShortUsePrompt',
        );
        expect(repeatedLetterShortKeyPersisted, contains(safePrompt));
        expect(
          repeatedLetterShortKeyPersisted,
          isNot(contains(repeatedLetterShortKey)),
        );

        const internalHyphenKey = 'opaque-userx';
        final internalHyphenKeyTask = taskFor(
          'legacy-ocr-internal-hyphen-prefix-key',
          [safePrompt, 'Use $internalHyphenKey to process this image'],
          credentialPrefix: 'opaque-user',
        );
        final internalHyphenKeyPersisted = jsonEncode(
          internalHyphenKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            internalHyphenKeyTask.retryData!,
          ).instructionContent,
          '$safePrompt\nUse [redacted] to process this image',
        );
        expect(internalHyphenKeyPersisted, contains(safePrompt));
        expect(
          internalHyphenKeyPersisted,
          contains('Use [redacted] to process this image'),
        );
        expect(internalHyphenKeyPersisted, isNot(contains(internalHyphenKey)));

        const shortPrefixHyphenatedKey = 'abc-qwertyuiop';
        final shortPrefixHyphenatedKeyTask = taskFor(
          'legacy-ocr-short-prefix-hyphenated-echo',
          [safePrompt, 'The note says $shortPrefixHyphenatedKey.'],
          credentialPrefix: 'abc',
        );
        final shortPrefixHyphenatedKeyPersisted = jsonEncode(
          shortPrefixHyphenatedKeyTask.toMap(),
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortPrefixHyphenatedKeyTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(shortPrefixHyphenatedKeyPersisted, contains(safePrompt));
        expect(
          shortPrefixHyphenatedKeyPersisted,
          isNot(contains(shortPrefixHyphenatedKey)),
        );

        const shortPrefixHyphenatedPrompt =
            'Please summarize the project-based template';
        final shortPrefixHyphenatedPromptTask = taskFor(
          'legacy-ocr-short-prefix-hyphenated-word-prompt',
          [shortPrefixHyphenatedPrompt],
          credentialPrefix: 'pro',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            shortPrefixHyphenatedPromptTask.retryData!,
          ).instructionContent,
          shortPrefixHyphenatedPrompt,
        );

        const singleCharacterSafePrompt = 'Read the receipt and summarize it';
        final singleCharacterSafeTask = taskFor(
          'legacy-ocr-single-character-prefix-safe-prompt',
          [singleCharacterSafePrompt],
          credentialPrefix: 'a',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            singleCharacterSafeTask.retryData!,
          ).instructionContent,
          singleCharacterSafePrompt,
        );

        const ordinaryPrompt = 'Read about abc in the manual';
        final ordinaryTask = taskFor(
          'legacy-ocr-short-prefix-ordinary-prompt',
          [ordinaryPrompt],
        );
        expect(
          OcrRetrySnapshot.fromMap(ordinaryTask.retryData!).instructionContent,
          ordinaryPrompt,
        );

        const prefixExtendedWordPrompt = 'Read the abstract carefully';
        final prefixExtendedWordTask = taskFor(
          'legacy-ocr-short-prefix-ordinary-word-extension',
          [prefixExtendedWordPrompt],
          credentialPrefix: 'abs',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            prefixExtendedWordTask.retryData!,
          ).instructionContent,
          prefixExtendedWordPrompt,
        );

        const lowerEntropyWordPrompt = 'Read the abstraction carefully';
        final lowerEntropyWordTask = taskFor(
          'legacy-ocr-short-prefix-lower-entropy-word-extension',
          [lowerEntropyWordPrompt],
          credentialPrefix: 'abs',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            lowerEntropyWordTask.retryData!,
          ).instructionContent,
          lowerEntropyWordPrompt,
        );

        const highEntropyNaturalWordPrompt = 'Read about abstractionism';
        final highEntropyNaturalWordTask = taskFor(
          'legacy-ocr-short-prefix-high-entropy-natural-word',
          [highEntropyNaturalWordPrompt],
          credentialPrefix: 'abs',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            highEntropyNaturalWordTask.retryData!,
          ).instructionContent,
          highEntropyNaturalWordPrompt,
        );

        const vowelRichNaturalWordPrompt = 'Read about education';
        final vowelRichNaturalWordTask = taskFor(
          'legacy-ocr-short-prefix-vowel-rich-natural-word',
          [vowelRichNaturalWordPrompt],
          credentialPrefix: 'edu',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            vowelRichNaturalWordTask.retryData!,
          ).instructionContent,
          vowelRichNaturalWordPrompt,
        );
      },
    );

    test(
      'legacy OCR instruction migration removes Unicode continuation after marked masks',
      () {
        const echoedCredential = 'sk_live_7åø';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-marked-prefix-unicode-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer sk_live_7…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The receipt includes $echoedCredential.',
                    },
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(retryInstruction, safePrompt);
        expect(persisted, contains(safePrompt));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration removes Unicode echoes after short masks',
      () {
        const echoedCredential = 'skåø';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-unicode-prefix-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer sk…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The note says $echoedCredential.',
                    },
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(retryInstruction, safePrompt);
        expect(persisted, contains(safePrompt));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration preserves credentialing prompt after credential mask',
      () {
        const echoedCredential = 'credentialing';
        const safePrompt = 'Read the receipt total carefully';
        const instruction = 'credentialing is required for this application';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer credential…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());
        const redactedInstruction =
            '[redacted] is required for this application';

        expect(retryInstruction, '$safePrompt\n$redactedInstruction');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(redactedInstruction));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration redacts Unicode echo after seven character opaque mask',
      () {
        const echoedCredential = 'qwrtypsåø';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-seven-character-opaque-unicode-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer qwrtyps…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The note says $echoedCredential.',
                    },
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(retryInstruction, safePrompt);
        expect(persisted, contains(safePrompt));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration redacts credentialed secretary key completion',
      () {
        const echoedCredential = 'secretary';
        const safePrompt = 'Read the receipt total carefully';
        const prose =
            'Please set the token to secretary, then continue carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-secret-word-completion-prose',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(retryInstruction, safePrompt);
        expect(persisted, contains(safePrompt));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration redacts Unicode echo after six character opaque mask',
      () {
        const echoedCredential = 'qwrtypåø';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-six-character-opaque-unicode-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer qwrtyp…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The note says $echoedCredential.',
                    },
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(retryInstruction, safePrompt);
        expect(persisted, contains(safePrompt));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration preserves natural credential words in ordinary prompts',
      () {
        const safePrompt = 'Read the receipt total carefully';
        const instruction = 'Please review the secret carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-natural-credential-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secre…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          '$safePrompt\n$instruction',
        );
        expect(
          serializedRetryData['instructionContent'],
          '$safePrompt\n$instruction',
        );
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration removes short credential-word echoes',
      () {
        const apiKey = 'abcsecret';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-credential-word-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes short-prefix keys with internal separators',
      () {
        const apiKey = 'opaqueNqv-Kzmt';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-internal-separator-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'The client included $apiKey.'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes vowel-rich short alpha echoes',
      () {
        const apiKey = 'abcfmoiutg';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-vowel-rich-short-alpha-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes nine-letter alpha echoes',
      () {
        const apiKey = 'abcxyzqwe';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-nine-letter-alpha-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration treats whitespace after masks as open ended',
      () {
        const apiKey = 'abc1234567890abcdef';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-mask-with-trailing-whitespace',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc… '},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes repeated short alpha echoes',
      () {
        const apiKey = 'abcxyzxyzxyzxyz';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-repeated-short-alpha-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural words after long alpha masks',
      () {
        const promptsAndExpectedInstructions = {
          'Read the characterization': 'Read the [redacted]',
          'Read the characteristic carefully': 'Read the [redacted] carefully',
        };
        for (final entry in promptsAndExpectedInstructions.entries) {
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-natural-long-prefix-prompt',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer character…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': entry.key},
                    ],
                  },
                ],
              },
            },
          });

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            entry.value,
          );
        }
      },
    );

    test(
      'legacy OCR instruction migration removes keys after hyphenated masks',
      () {
        const apiKey = 'opaque-user-kqzvjpnamr';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-hyphenated-prefix-alpha-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes credential words after hyphenated masks',
      () {
        const apiKey = 'opaque-user-secret';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-hyphenated-prefix-secret-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes hyphenated credential suffixes',
      () {
        const apiKey = 'myproject-secret';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-hyphenated-credential-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes one-letter alpha key echoes',
      () {
        const apiKey = 'myprojectq';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-one-letter-alpha-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves ordinary plural prompts',
      () {
        const safePrompt = 'Read the characters carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-plural-word-after-long-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer character…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                  ],
                },
              ],
            },
          },
        });

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(jsonEncode(task.toMap()), contains(safePrompt));
      },
    );

    test(
      'legacy OCR instruction migration preserves natural word possessives',
      () {
        const prompts = {
          'character': "Review the character's label",
          'document': 'Review the document’s header',
        };
        for (final entry in prompts.entries) {
          final prompt = entry.value;
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-natural-word-possessive-${entry.key}',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer ${entry.key}…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': prompt},
                    ],
                  },
                ],
              },
            },
          });
          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            prompt,
          );
          expect(jsonEncode(task.toMap()), contains(prompt));
        }
      },
    );

    test(
      'legacy OCR instruction migration removes short alpha key echoes after long masks',
      () {
        const apiKey = 'myprojectabcef';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-alpha-key-after-long-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes short natural-looking alpha echoes',
      () {
        const apiKey = 'documentaa';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-natural-looking-alpha-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The client sent $apiKey with the request',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes short uncommon alpha continuations',
      () {
        const safePrompt = 'Read the receipt total carefully';
        for (final apiKey in ['myprojectkqzv', 'myprojectkqz']) {
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-uncommon-alpha-extension-${apiKey.length}',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer myproject…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': safePrompt},
                      {'type': 'text', 'text': 'Use $apiKey for the request'},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            safePrompt,
          );
          expect(persisted, contains(safePrompt));
          expect(persisted, isNot(contains(apiKey)));
        }
      },
    );

    test(
      'legacy OCR instruction migration removes repeated alpha characters after long masks',
      () {
        const apiKey = 'myprojectaaaaa';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-repeated-alpha-character-run',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes low-entropy alpha echoes after long masks',
      () {
        const apiKey = 'myprojectaabc';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-low-entropy-alpha-key-after-long-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes alpha echoes after hyphenated masks',
      () {
        const apiKey = 'myproject-abcd';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-alpha-key-after-hyphenated-mask',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes high-entropy hyphenated credential echoes',
      () {
        const apiKey = 'myproject-fjmrxpwknlvb';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-high-entropy-hyphenated-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes low-entropy hyphenated credential echoes',
      () {
        const apiKey = 'myproject-randomstuff';
        const shortApiKey = 'myproject-abcd';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-low-entropy-hyphenated-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                    {'type': 'text', 'text': 'Read $shortApiKey'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(shortApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes short hyphenated credential echoes',
      () {
        const apiKey = 'myproject-zxjprvma';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-hyphenated-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes alpha echoes surrounded by punctuation',
      () {
        const apiKeys = [
          'myprojectcontent',
          'myprojectpoppy',
          'myprojectpoppy',
          'myprojectcontent',
        ];
        const echoTexts = [
          'Please use myprojectcontent.',
          'The label is "myprojectpoppy"',
          'The note says `myprojectpoppy`.',
          'The note says **myprojectcontent**.',
        ];
        const safePrompt = 'Read the receipt total carefully';
        for (var index = 0; index < apiKeys.length; index++) {
          final apiKey = apiKeys[index];
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-punctuated-alpha-key-$index',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer myproject…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': safePrompt},
                      {'type': 'text', 'text': echoTexts[index]},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            safePrompt,
          );
          expect(persisted, contains(safePrompt));
          expect(persisted, isNot(contains(apiKey)));
        }
      },
    );

    test(
      'legacy OCR instruction migration removes grammatical suffix credential echoes',
      () {
        const apiKey = 'myprojecting';
        const pastTenseApiKey = 'myprojected';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-grammatical-suffix-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey for the request'},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                    {
                      'type': 'text',
                      'text': 'Use $pastTenseApiKey for the request',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          '$safePrompt\nUse [redacted] to process this image',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('Use [redacted] to process this image'));
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(pastTenseApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes natural-suffix credential echoes in prose',
      () {
        const apiKey = 'myprojected';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-suffix-key-in-prose',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'The note says $apiKey.'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration also removes documentation echoes in prose',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-suffix-prose',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'The note says $apiKey.'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes one-letter credential echoes in prose and use context',
      () {
        const apiKey = 'mysecretm';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-one-letter-alpha-key-in-use-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer mysecret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                    {'type': 'text', 'text': 'The note says $apiKey.'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          '$safePrompt\nUse [redacted] to process this image',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('Use [redacted] to process this image'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural suffixes in credential assignments',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-suffix-credential-assignment',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The Authorization value is $apiKey.',
                    },
                    {
                      'type': 'text',
                      'text': 'The Authorization header is $apiKey.',
                    },
                    {'type': 'text', 'text': 'Authorization header: $apiKey'},
                    {
                      'type': 'text',
                      'text': 'Authorization header value is $apiKey.',
                    },
                    {
                      'type': 'text',
                      'text': 'Authorization header equals $apiKey',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));

        const shortPrefixApiKey = 'secretary';
        final shortPrefixTask = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-natural-suffix-credential-assignment',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The Authorization value is $shortPrefixApiKey.',
                    },
                  ],
                },
              ],
            },
          },
        });
        final shortPrefixPersisted = jsonEncode(shortPrefixTask.toMap());
        expect(
          OcrRetrySnapshot.fromMap(
            shortPrefixTask.retryData!,
          ).instructionContent,
          safePrompt,
        );
        expect(shortPrefixPersisted, contains(safePrompt));
        expect(shortPrefixPersisted, isNot(contains(shortPrefixApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural suffixes after a key label',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-suffix-key-assignment',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'The key is $apiKey.'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural word API key use values',
      () {
        const apiKey = 'interactions';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-api-key-use-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer interaction…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey as the API key'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural word key assignments',
      () {
        const apiKey = 'interactions';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-api-key-set-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer interaction…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Set API key to $apiKey'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural word Authorization assignments',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-authorization-set-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Set Authorization header value to $apiKey',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural word credential use values',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-credential-use-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey as the credential'},
                    {
                      'type': 'text',
                      'text': 'Enter $apiKey into the Authorization header',
                    },
                    {
                      'type': 'text',
                      'text': 'Copy $apiKey into the Authorization header',
                    },
                    {
                      'type': 'text',
                      'text': 'Copy $apiKey to the Authorization header',
                    },
                    {
                      'type': 'text',
                      'text': 'Put $apiKey in the Authorization header',
                    },
                    {
                      'type': 'text',
                      'text': 'Use $apiKey for the Authorization header',
                    },
                    {'type': 'text', 'text': 'Use $apiKey as a bearer token'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short credential values used to process images',
      () {
        const apiKey = 'skghjklm';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-key-use-to-process-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer sk…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts compound credential words',
      () {
        const apiKey = 'secret-key';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-compound-credential-word',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Please send $apiKey'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short opaque alpha key echoes',
      () {
        const apiKey = 'skghjklm';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-short-opaque-alpha-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer skghjkl…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts low-vowel short alpha key echoes',
      () {
        const apiKey = 'aartvbncm';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-low-vowel-short-alpha-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer aartvbn…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves natural text split after a masked prefix',
      () {
        const safeInstruction = 'Check opaque-user\nfor the receipt total';
        const apiKey = 'opaque-user-secret-value-179';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-part-boundary-after-masked-prefix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': 'Check opaque-user'},
                    {'type': 'text', 'text': 'for the receipt total'},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safeInstruction,
        );
        expect(serializedRetryData['instructionContent'], safeInstruction);
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves prose after a separator-ended mask prefix newline',
      () {
        const instruction = 'Check opaque-user-\nfor the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-newline-after-masked-prefix-separator',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          instruction,
        );
        expect(serializedRetryData['instructionContent'], instruction);
      },
    );

    test(
      'legacy OCR instruction migration removes a natural connector key in credential context',
      () {
        const apiKey = 'opaque-user-as';
        const credentialInstruction =
            'Provide opaque-user-\nas the authorization value';
        const safeInstruction = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-credential-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': credentialInstruction},
                    {'type': 'text', 'text': safeInstruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final compactedInstruction = migratedInstruction?.replaceAll(
          RegExp(r'\s+'),
          '',
        );
        final serializedInstruction =
            serializedRetryData['instructionContent'] as String?;
        final compactedSerializedInstruction =
            serializedInstruction?.replaceAll(RegExp(r'\s+'), '');

        expect(migratedInstruction, contains(safeInstruction));
        expect(persisted, contains(safeInstruction));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
        expect(compactedInstruction, isNot(contains(apiKey)));
        expect(compactedSerializedInstruction, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes a natural connector key after pass action',
      () {
        const apiKey = 'opaque-user-as';
        const credentialInstruction =
            'Pass opaque-user-\nas the authorization value to process the receipt.';
        const safeInstruction = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-pass-credential-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': credentialInstruction},
                    {'type': 'text', 'text': safeInstruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final compactedInstruction = migratedInstruction?.replaceAll(
          RegExp(r'\s+'),
          '',
        );
        final serializedInstruction =
            serializedRetryData['instructionContent'] as String?;
        final compactedSerializedInstruction =
            serializedInstruction?.replaceAll(RegExp(r'\s+'), '');

        expect(migratedInstruction, contains(safeInstruction));
        expect(persisted, contains(safeInstruction));
        expect(compactedInstruction, isNot(contains(apiKey)));
        expect(compactedSerializedInstruction, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes a natural connector key after set action',
      () {
        const apiKey = 'opaque-user-as';
        const credentialInstruction =
            'Set opaque-user-\nas the authorization value to process the receipt.';
        const safeInstruction = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-set-credential-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': credentialInstruction},
                    {'type': 'text', 'text': safeInstruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final compactedInstruction = migratedInstruction?.replaceAll(
          RegExp(r'\s+'),
          '',
        );
        final serializedInstruction =
            serializedRetryData['instructionContent'] as String?;
        final compactedSerializedInstruction =
            serializedInstruction?.replaceAll(RegExp(r'\s+'), '');

        expect(migratedInstruction, contains(safeInstruction));
        expect(persisted, contains(safeInstruction));
        expect(compactedInstruction, isNot(contains(apiKey)));
        expect(compactedSerializedInstruction, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves OCR action after a natural connector key',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Pass opaque-user-\nas the authorization value to process the receipt.';
        const sanitizedInstruction =
            'Pass [redacted] as the authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-safe-trailing-action',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final serializedInstruction =
            serializedRetryData['instructionContent'] as String?;

        expect(migratedInstruction, sanitizedInstruction);
        expect(serializedInstruction, sanitizedInstruction);
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves send action after a natural connector key',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Send opaque-user-\nas the authorization value to process the receipt.';
        const sanitizedInstruction =
            'Send [redacted] as the authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-send-safe-action',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(
          serializedRetryData['instructionContent'],
          sanitizedInstruction,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves send action when the key ends in a natural connector',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Send opaque-user-as as the authorization value to process the receipt.';
        const sanitizedInstruction =
            'Send [redacted] as the authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-send-key-ending-as',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(
          serializedRetryData['instructionContent'],
          sanitizedInstruction,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves use action after a natural connector key',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Use opaque-user-\nas the authorization value to process the receipt.';
        const sanitizedInstruction =
            'Use [redacted] as the authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-use-safe-action',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(
          serializedRetryData['instructionContent'],
          sanitizedInstruction,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves use action for qualified authorization targets',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Use opaque-user-as as the OAuth authorization value to process the receipt.';
        const sanitizedInstruction =
            'Use [redacted] as the OAuth authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-use-oauth-authorization',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(
          serializedRetryData['instructionContent'],
          sanitizedInstruction,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves use action for OAuth2 authorization targets',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Use opaque-user-\nas the OAuth2 authorization value to process the receipt.';
        const sanitizedInstruction =
            'Use [redacted] as the OAuth2 authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-use-oauth2-authorization',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(
          serializedRetryData['instructionContent'],
          sanitizedInstruction,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves use action for spaced OAuth version targets',
      () {
        const apiKey = 'opaque-user-as';
        const instruction =
            'Use opaque-user-as as the OAuth 2.0 authorization value to process the receipt.';
        const sanitizedInstruction =
            'Use [redacted] as the OAuth 2.0 authorization value to process the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-connector-use-oauth-spaced-version',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          sanitizedInstruction,
        );
        expect(
          serializedRetryData['instructionContent'],
          sanitizedInstruction,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short opaque alpha key echoes with trailing punctuation',
      () {
        const apiKey = 'skghjklm';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-short-opaque-alpha-key-trailing-slash',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer skghjklm…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey/ for this image'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains('$apiKey/')));
      },
    );

    test(
      'legacy OCR instruction migration preserves natural words in read prompts',
      () {
        const safePrompt = 'Read the construction label';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-completion-1',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer construct…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
      },
    );

    test(
      'legacy OCR instruction migration preserves thoughtful word completion',
      () {
        const safePrompt = 'Please provide a thoughtful summary';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-completion-2',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer thoughtfu…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
      },
    );

    test(
      'legacy OCR instruction migration redacts short keys followed by a slash',
      () {
        const apiKey = 'skpmrvwthj/';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-key-trailing-slash',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer sk…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Open /tmp/$apiKey to inspect the image',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts open ended keys ending in slash',
      () {
        const apiKey = 'opaque-user/';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-key-slash-only-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts repeated open ended keys ending in slash',
      () {
        const apiKey = 'abcabcabc/';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-repeated-key-slash-only-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer abcabcabc…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short hyphenated key continuations',
      () {
        const apiKey = 'opaque-user-abc';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-short-hyphenated-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Observed value: $apiKey.'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short punctuation delimited key continuations',
      () {
        const apiKey = 'opaque-user.abcd';
        const shortApiKey = 'opaque-user.x';
        const equalsApiKey = 'opaque-user=xy';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-punctuation-separated-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                    {'type': 'text', 'text': shortApiKey},
                    {'type': 'text', 'text': equalsApiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(shortApiKey)));
        expect(persisted, isNot(contains(equalsApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts internal bearer punctuation after a long mask prefix',
      () {
        const plusApiKey = 'longpref+banana';
        const tildeApiKey = 'longpref~banana';
        const shortPlusApiKey = 'longpref+abc';
        const shortTildeApiKey = 'longpref~abc';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-long-prefix-internal-bearer-punctuation',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer longpref…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': plusApiKey},
                    {'type': 'text', 'text': tildeApiKey},
                    {'type': 'text', 'text': shortPlusApiKey},
                    {'type': 'text', 'text': shortTildeApiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(plusApiKey)));
        expect(persisted, isNot(contains(tildeApiKey)));
        expect(persisted, isNot(contains(shortPlusApiKey)));
        expect(persisted, isNot(contains(shortTildeApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts dotted keys after natural prefixes',
      () {
        const apiKey = 'customer.xyz';
        const safePrompt = 'Check the customer record';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-natural-prefix-dotted-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer customer…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short dotted keys after natural prefixes',
      () {
        const apiKey = 'character.xy';
        const safePrompt = 'Check the character record';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-natural-prefix-short-dotted-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer character…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short dotted keys with an eight-letter prefix',
      () {
        const apiKey = 'document.ab';
        const safePrompt = 'Review the document record';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-eight-letter-prefix-short-dotted-key',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts two letter hyphenated key continuations',
      () {
        const apiKey = 'opaque-user-xy';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-two-letter-hyphenated-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves ordinary alpha text split after a masked prefix',
      () {
        const safeInstruction =
            'Review the interaction\nsummary of the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-ordinary-alpha-part-boundary-after-masked-prefix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer interaction…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': 'Review the interaction'},
                    {'type': 'text', 'text': 'summary of the receipt'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final serializedRetryData = (jsonDecode(persisted)
            as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safeInstruction,
        );
        expect(serializedRetryData['instructionContent'], safeInstruction);
      },
    );

    test(
      'legacy OCR instruction migration redacts one letter hyphenated key continuations',
      () {
        const apiKey = 'opaque-user-x';
        const safePrompt = 'Check opaque-user for the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-one-letter-hyphenated-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves apiculture word completion',
      () {
        const safePrompt = 'Please review apiculture trends';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-apiculture-word-completion',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer api…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
      },
    );

    test(
      'legacy OCR instruction migration redacts short hyphenated prefix echoes',
      () {
        const apiKey = 'opaque-user/';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-hyphenated-prefix-slash-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short dotted key continuations',
      () {
        const apiKey = 'opaque.user.x';
        const safePrompt = 'Check opaque.user for the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-dotted-prefix-key-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque.user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts open ended keys ending in equals',
      () {
        const apiKey = 'opaque-user=';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-key-equals-only-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts open ended keys ending in credential punctuation',
      () {
        const hyphenApiKey = 'opaque-user-';
        const underscoreApiKey = 'opaque-user_';
        const plusApiKey = 'opaque-user+';
        const tildeApiKey = 'opaque-user~';
        const safePrompt = 'Check opaque-user for the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-key-hyphen-or-underscore-only-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': hyphenApiKey},
                    {'type': 'text', 'text': underscoreApiKey},
                    {'type': 'text', 'text': plusApiKey},
                    {'type': 'text', 'text': tildeApiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(hyphenApiKey)));
        expect(persisted, isNot(contains(underscoreApiKey)));
        expect(persisted, isNot(contains(plusApiKey)));
        expect(persisted, isNot(contains(tildeApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts terminal punctuation after a short open ended mask prefix',
      () {
        const plusApiKey = 'opaque-user+';
        const tildeApiKey = 'opaque-user~';
        const prefixPlusApiKey = 'opaque+';
        const prefixTildeApiKey = 'opaque~';
        const prefixHyphenApiKey = 'opaque-';
        const prefixUnderscoreApiKey = 'opaque_';
        const prefixSlashApiKey = 'opaque/';
        const prefixEqualsApiKey = 'opaque=';
        const safePrompt = 'Read about opaque. in the manual';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-hyphenated-punctuation-tail',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': plusApiKey},
                    {'type': 'text', 'text': tildeApiKey},
                    {'type': 'text', 'text': prefixPlusApiKey},
                    {'type': 'text', 'text': prefixTildeApiKey},
                    {'type': 'text', 'text': prefixHyphenApiKey},
                    {'type': 'text', 'text': prefixUnderscoreApiKey},
                    {'type': 'text', 'text': prefixSlashApiKey},
                    {'type': 'text', 'text': prefixEqualsApiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(plusApiKey)));
        expect(persisted, isNot(contains(tildeApiKey)));
        expect(persisted, isNot(contains(prefixPlusApiKey)));
        expect(persisted, isNot(contains(prefixTildeApiKey)));
        expect(persisted, isNot(contains(prefixHyphenApiKey)));
        expect(persisted, isNot(contains(prefixUnderscoreApiKey)));
        expect(persisted, isNot(contains(prefixSlashApiKey)));
        expect(persisted, isNot(contains(prefixEqualsApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration checks credential context after punctuation-only masked key echoes',
      () {
        const credentialInstruction = 'Use document. as my API key';
        const safePrompt = 'Check the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-punctuation-only-explicit-key-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': credentialInstruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(credentialInstruction)));
      },
    );

    test(
      'legacy OCR instruction migration redacts internal bearer punctuation after a short open ended mask prefix',
      () {
        const plusApiKey = 'opaque+abcd';
        const tildeApiKey = 'opaque~abcd';
        const safePrompt = 'Check the receipt total';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-prefix-internal-bearer-punctuation',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': plusApiKey},
                    {'type': 'text', 'text': tildeApiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(plusApiKey)));
        expect(persisted, isNot(contains(tildeApiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts punctuation-only tails after natural prefixes',
      () {
        const apiKeys = [
          'interaction-',
          'interaction_',
          'interaction=',
          'interaction/',
        ];
        const safePrompt = 'Check the interaction label';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-natural-prefix-punctuation-only-keys',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer interaction…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    for (final apiKey in apiKeys)
                      {'type': 'text', 'text': apiKey},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        for (final apiKey in apiKeys) {
          expect(persisted, isNot(contains(apiKey)));
        }
      },
    );

    test(
      'legacy OCR instruction migration preserves natural-word instruction prompts',
      () {
        const safePrompts = [
          'Read about the interaction carefully',
          'Please include the interaction summary',
        ];
        for (var index = 0; index < safePrompts.length; index++) {
          final safePrompt = safePrompts[index];
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-one-letter-word-extension-$index',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer interactio…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': safePrompt},
                    ],
                  },
                ],
              },
            },
          });
          final expectedPrompt = safePrompt;
          final persisted = jsonEncode(task.toMap());

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            expectedPrompt,
          );
          expect(persisted, contains(expectedPrompt));
        }
      },
    );

    test(
      'legacy OCR instruction migration preserves natural words used to process images',
      () {
        const apiKey = 'interactions';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-use-to-process-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer interaction…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to process this image',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          '$safePrompt\nUse $apiKey to process this image',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('Use $apiKey to process this image'));
      },
    );

    test('legacy OCR instruction migration preserves short-prefix words', () {
      const safePrompt = 'Read the characterization on this page';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-short-prefix-characterization-prompt',
        'type': 'ocr',
        'title': 'legacy OCR request',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'url': 'https://api.example.com/v1/chat/completions',
          'headers': {'Authorization': 'Bearer cha…'},
          'body': {
            'model': 'vision-model',
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': safePrompt},
                ],
              },
            ],
          },
        },
      });

      expect(
        OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
        safePrompt,
      );
    });

    test(
      'legacy OCR instruction migration preserves secrecy after secre mask prefix',
      () {
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt = 'Please preserve secrecy';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-secre-mask-secrecy-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secre…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$ordinaryPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(ordinaryPrompt));
      },
    );

    test(
      'legacy OCR instruction migration redacts authentication key and preserves its prompt',
      () {
        const apiKey = 'authentication';
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt = 'Please check authentication settings';
        const sanitizedPrompt = 'Please check [redacted] settings';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-auth-mask-natural-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer auth…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$sanitizedPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(sanitizedPrompt));
        expect(instructionContent, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts authenticate key and preserves its prompt',
      () {
        const apiKey = 'authenticate';
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt = 'Please authenticate the receipt';
        const sanitizedPrompt = 'Please [redacted] the receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-auth-key-natural-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer auth…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$sanitizedPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(sanitizedPrompt));
        expect(instructionContent, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes opaque auth-prefix echoes and preserves author prompts',
      () {
        const echoedCredential = 'authabc';
        const shortEchoedCredential = 'authab';
        const singleCharacterEchoedCredential = 'authx';
        const unicodeEchoedCredential = 'authåø';
        const opaqueAlphaEchoedCredential = 'authqzxpt';
        const longerAlphaEchoedCredential = 'authflint';
        const hyphenatedEchoedCredential = 'auth-abc';
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt =
            'Please ask the author to review this authentic receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-auth-prefix-opaque-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer auth…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The receipt includes $echoedCredential.',
                    },
                    {
                      'type': 'text',
                      'text': 'The footer includes $shortEchoedCredential.',
                    },
                    {
                      'type': 'text',
                      'text':
                          'The label includes $singleCharacterEchoedCredential.',
                    },
                    {
                      'type': 'text',
                      'text': 'The footer includes $unicodeEchoedCredential.',
                    },
                    {
                      'type': 'text',
                      'text':
                          'The label includes $opaqueAlphaEchoedCredential.',
                    },
                    {
                      'type': 'text',
                      'text': 'The note includes $longerAlphaEchoedCredential.',
                    },
                    {
                      'type': 'text',
                      'text': 'The label includes $hyphenatedEchoedCredential.',
                    },
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final retryInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(retryInstruction, '$safePrompt\n$ordinaryPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(ordinaryPrompt));
        expect(retryInstruction, isNot(contains(echoedCredential)));
        expect(retryInstruction, isNot(contains(shortEchoedCredential)));
        expect(
          retryInstruction,
          isNot(contains(singleCharacterEchoedCredential)),
        );
        expect(retryInstruction, isNot(contains(unicodeEchoedCredential)));
        expect(retryInstruction, isNot(contains(opaqueAlphaEchoedCredential)));
        expect(retryInstruction, isNot(contains(longerAlphaEchoedCredential)));
        expect(retryInstruction, isNot(contains(hyphenatedEchoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(shortEchoedCredential)));
        expect(persisted, isNot(contains(singleCharacterEchoedCredential)));
        expect(persisted, isNot(contains(unicodeEchoedCredential)));
        expect(persisted, isNot(contains(opaqueAlphaEchoedCredential)));
        expect(persisted, isNot(contains(longerAlphaEchoedCredential)));
        expect(persisted, isNot(contains(hyphenatedEchoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration removes Unicode echoes after credential-word masks',
      () {
        const echoedCredential = 'tokenåø';
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt =
            'Please ask the author to review this authentic receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-token-prefix-unicode-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer token…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The receipt includes $echoedCredential.',
                    },
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$ordinaryPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(ordinaryPrompt));
        expect(instructionContent, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration removes Unicode echoes after vowel-rich key prefixes',
      () {
        const echoedCredential = 'qwertyuiåø';
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt =
            'Please ask the author to review this authentic receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-vowel-rich-prefix-unicode-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer qwertyui…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The receipt includes $echoedCredential.',
                    },
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$ordinaryPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(ordinaryPrompt));
        expect(instructionContent, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration removes Unicode echoes after high-vowel key prefixes',
      () {
        const echoedCredential = 'aebicodufåø';
        const safePrompt = 'Read the receipt total carefully';
        const ordinaryPrompt =
            'Please ask the author to review this authentic receipt';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-high-vowel-prefix-unicode-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer aebicoduf…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'The receipt includes $echoedCredential.',
                    },
                    {'type': 'text', 'text': ordinaryPrompt},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$ordinaryPrompt');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(ordinaryPrompt));
        expect(instructionContent, isNot(contains(echoedCredential)));
        expect(persisted, isNot(contains(echoedCredential)));
      },
    );

    test(
      'legacy OCR instruction migration redacts documentation used for request after short mask',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'Use documentation for the request';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-docu-short-mask-use-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer docu…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(
          instructionContent,
          '$safePrompt\nUse [redacted] for the request',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('Use [redacted] for the request'));
        expect(instructionContent, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts documentation after short mask in prose',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'The note says documentation.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-docu-natural-word-prose',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer docu…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\nThe note says [redacted].');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('The note says [redacted].'));
        expect(instructionContent, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts short natural word key echoes in prose',
      () {
        const apiKey = 'obfuscated';
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'The receipt is obfuscated.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-obfusca-mask-natural-word-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer obfusca…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\nThe receipt is [redacted].');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('The receipt is [redacted].'));
        expect(instructionContent, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves OAuth version mentions after a masked prefix',
      () {
        const safePrompt = 'Read the OAuth2 section';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-oauth-version-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer OAuth…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                  ],
                },
              ],
            },
          },
        });

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
      },
    );

    test(
      'legacy OCR instruction migration preserves OAuth versions after an auth mask',
      () {
        for (final safePrompt in [
          'Read the OAuth2 section',
          'Read the OAuth2.0 section',
        ]) {
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-auth-mask-oauth-version-prompt',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer auth…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': safePrompt},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());
          final serializedRetryData = (jsonDecode(persisted)
              as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            safePrompt,
          );
          expect(serializedRetryData['instructionContent'], safePrompt);
          expect(persisted, contains(safePrompt));
        }
      },
    );

    test(
      'legacy OCR instruction migration preserves prose around long mask echoes',
      () {
        BackgroundTask taskFor(
          String id,
          String safePrompt, {
          String credentialPrefix = 'document',
        }) =>
            BackgroundTask.fromMap({
              'id': id,
              'type': 'ocr',
              'title': 'legacy OCR request',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'rawRequest': {
                'url': 'https://api.example.com/v1/chat/completions',
                'headers': {'Authorization': 'Bearer $credentialPrefix…'},
                'body': {
                  'model': 'vision-model',
                  'messages': [
                    {
                      'role': 'user',
                      'content': [
                        {'type': 'text', 'text': safePrompt},
                      ],
                    },
                  ],
                },
              },
            });

        const promptsAndExpectedInstructions = {
          'Please document the receipt carefully':
              'Please document the receipt carefully',
          'Please document: the receipt carefully':
              'Please document: the receipt carefully',
          'Please review the documentary record carefully':
              'Please review the documentary record carefully',
          'Please review the documentation carefully':
              'Please review the documentation carefully',
          'Please review the documentaries': 'Please review the documentaries',
          'Please include documentation with the receipt':
              'Please include documentation with the receipt',
          'The note says documented.': 'The note says [redacted].',
          'The note says documents.': 'The note says documents.',
          'Send documentation for the request':
              'Send [redacted] for the request',
          'Use documentation for the request': 'Use [redacted] for the request',
          'Please include a document-based summary':
              'Please include a document-based summary',
        };
        for (final entry in promptsAndExpectedInstructions.entries) {
          final task = taskFor('legacy-ocr-long-prefix-safe-prompt', entry.key);
          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            entry.value,
          );
        }

        const safeContinuationPrompts = {
          'purchase': (
            'Please review all purchases',
            'Please review all purchases',
          ),
          'document': (
            'The documentary explains the scene',
            'The documentary explains the scene',
          ),
          'message': (
            'Please review the messages',
            'Please review the messages',
          ),
          'service': (
            'Please review the services',
            'Please review the services',
          ),
          'transac': (
            'Please compare the transaction-based rate',
            'Please compare the transaction-based rate',
          ),
          'transaction': (
            'Please review all transactions carefully',
            'Please review all transactions carefully',
          ),
          'authorizatio': (
            'Review the authorization on this page',
            'Review the authorization on this page',
          ),
          'authorization': (
            'Review the authorizations on this page',
            'Review the authorizations on this page',
          ),
          'authenticat': (
            'Please authenticate the receipt',
            'Please [redacted] the receipt',
          ),
          'cooperat': ('Please cooperate.', 'Please [redacted].'),
          'translat': (
            'Please translate this receipt',
            'Please [redacted] this receipt',
          ),
          'bookkeeper': (
            'Review the bookkeepers on this page',
            'Review the bookkeepers on this page',
          ),
          'character': (
            'Please characterize the receipt',
            'Please characterize the receipt',
          ),
          'descriptio': (
            'Please provide a description of this image',
            'Please provide a description of this image',
          ),
          'archite': (
            'Please review the architecture',
            'Please review the architecture',
          ),
          'accommod': (
            'Please accommodate the requested crop',
            'Please [redacted] the requested crop',
          ),
          'secretar': (
            'Please ask the secretary carefully',
            'Please ask the [redacted] carefully',
          ),
          'certifica': (
            'Please review the certificate',
            'Please review the certificate',
          ),
          'project': (
            'Review the project-based template',
            'Review the project-based template',
          ),
        };
        for (final entry in safeContinuationPrompts.entries) {
          final prompt = entry.value.$1;
          final expectedInstruction = entry.value.$2;
          final task = taskFor(
            'legacy-ocr-safe-plural-${entry.key}',
            prompt,
            credentialPrefix: entry.key,
          );
          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            expectedInstruction,
          );
          expect(jsonEncode(task.toMap()), contains(expectedInstruction));
        }

        const oneLetterNaturalPrompts = {
          'password': 'The passwords are saved securely.',
          'credential': 'The credentials are valid.',
        };
        for (final entry in oneLetterNaturalPrompts.entries) {
          final task = taskFor(
            'legacy-ocr-one-letter-natural-word-${entry.key}',
            entry.value,
            credentialPrefix: entry.key,
          );
          final expectedInstruction = entry.value.replaceFirst(
            '${entry.key}s',
            '[redacted]',
          );
          final persisted = jsonEncode(task.toMap());
          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            expectedInstruction,
          );
          expect(persisted, contains(expectedInstruction));
          expect(persisted, isNot(contains('${entry.key}s')));
        }

        const hyphenatedSafePrompt = 'Please include a document-based summary';
        final hyphenatedTask = taskFor(
          'legacy-ocr-long-prefix-hyphenated-safe-prompt',
          hyphenatedSafePrompt,
          credentialPrefix: 'document-',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            hyphenatedTask.retryData!,
          ).instructionContent,
          hyphenatedSafePrompt,
        );

        const repeatedLetterSafePrompt = 'Review the bookkeeper carefully';
        final repeatedLetterTask = taskFor(
          'legacy-ocr-long-prefix-repeated-letter-word',
          repeatedLetterSafePrompt,
          credentialPrefix: 'bookkeep',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            repeatedLetterTask.retryData!,
          ).instructionContent,
          'Review the bookkeeper carefully',
        );

        const hyphenatedProjectPrompt = 'Use a project-based template';
        final hyphenatedProjectTask = taskFor(
          'legacy-ocr-hyphenated-project-prompt',
          hyphenatedProjectPrompt,
          credentialPrefix: 'my-project',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            hyphenatedProjectTask.retryData!,
          ).instructionContent,
          hyphenatedProjectPrompt,
        );

        const openEndedHyphenatedProjectPrompt =
            'Please review a project-based template';
        final openEndedHyphenatedProjectTask = taskFor(
          'legacy-ocr-open-ended-hyphenated-project-prompt',
          openEndedHyphenatedProjectPrompt,
          credentialPrefix: 'myproject',
        );
        expect(
          OcrRetrySnapshot.fromMap(
            openEndedHyphenatedProjectTask.retryData!,
          ).instructionContent,
          openEndedHyphenatedProjectPrompt,
        );
      },
    );

    test(
      'legacy OCR instruction migration preserves natural-word review prompts',
      () {
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'Please review the documentation carefully.';
        const splitProseStart = 'Also examine the docu';
        const splitProseEnd = 'mentation carefully.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-key-echo-in-prose',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                    {'type': 'text', 'text': splitProseStart},
                    {'type': 'text', 'text': splitProseEnd},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(
          instructionContent,
          '$safePrompt\n'
          'Please review the documentation carefully.\n'
          'Also examine the docu\n'
          'mentation carefully.',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(prose));
        expect(persisted, contains('Also examine the docu'));
        expect(persisted, contains('mentation carefully.'));
      },
    );

    test(
      'legacy OCR instruction migration preserves a natural credential word in an ordinary prompt',
      () {
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'Review the authorization on this page';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-one-letter-natural-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer authorizatio…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(instructionContent, '$safePrompt\n$prose');
        expect(persisted, contains(safePrompt));
        expect(persisted, contains(prose));
      },
    );

    test(
      'legacy OCR instruction migration redacts authorization word after author mask',
      () {
        const apiKey = 'authorization';
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'Use authorization for the request';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-author-natural-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer author…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(
          instructionContent,
          '$safePrompt\nUse [redacted] for the request',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('Use [redacted] for the request'));
        expect(instructionContent, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts secrets in credential-use context',
      () {
        const credentialEcho = 'secrets';
        const safePrompt = 'Read the receipt total carefully';
        const prose = 'Use secrets for the request';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-secret-natural-word-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer secret…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': prose},
                  ],
                },
              ],
            },
          },
        });
        final instructionContent = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;
        final persisted = jsonEncode(task.toMap());

        expect(
          instructionContent,
          '$safePrompt\nUse [redacted] for the request',
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, contains('Use [redacted] for the request'));
        expect(instructionContent, isNot(contains(credentialEcho)));
        expect(persisted, isNot(contains(credentialEcho)));
      },
    );

    test(
      'legacy OCR instruction migration redacts possessive credential use values',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-possessive-key-use-context',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Use $apiKey as my API key'},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey as my private API key',
                    },
                    {'type': 'text', 'text': 'Use $apiKey as an OAuth token'},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey as a temporary API key',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts possessive key assignments',
      () {
        const apiKey = 'documentation';
        const safePrompt = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-word-possessive-key-assignment',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {'type': 'text', 'text': 'Set your API key to $apiKey'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes natural compound credential echoes',
      () {
        const apiKey = 'myproject-based';
        const safePrompt = 'Please review a project-based template';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-compound-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Use $apiKey to access the project',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          safePrompt,
        );
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves an ordinary plural after an open-ended prefix',
      () {
        const prompt = 'Please review applications carefully.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-application-plural-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer application…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          prompt,
        );
        expect(persisted, contains(prompt));
      },
    );

    test(
      'legacy OCR instruction migration preserves ordinary suffix prompts',
      () {
        const prompts = [
          ('education', 'Read about education—especially its history.'),
          ('a', 'Please identify the agriculture label.'),
          ('secret', 'Please identify what glands secrete'),
          ('secret', 'Please read the secretion label'),
          ('secret', 'Read the secretariat report'),
          ('secret', 'Read the secretive label'),
          ('secret', 'Please review the secretarial document'),
          ('secret', 'La secretaría'),
          ('secret', 'Leia a palavra secretária'),
          ('photo', 'Please read the photograph label'),
          ('authorizatio', 'What does authorization mean in this document?'),
          ('auth', 'Please explain the authority limit.'),
          ('auth', 'Please explain authenticity'),
          ('auth', 'Please authorize the receipt.'),
          ('auth', 'Please review the authorized value'),
          ('auth', 'Read the authoritarian poster'),
          ('token', 'Review the tokenized receipt'),
          ('token', 'Please explain tokenizers in the diagram'),
          ('token', 'Explain the tokenization process'),
          ('token', 'Use token-based authentication'),
          ('token', 'Read the tokenization guide'),
          ('auth', 'Please provide an authoritative source for the receipt'),
          ('auth', 'Describe the authentication process'),
          ('cred', 'Please identify the word accreditation on the form.'),
          ('auth', 'Describe authenticating users'),
          ('token', 'The tokenization rules should be followed'),
          ('auth', 'Review the authorship line.'),
          ('auth', 'Review the authoring notes.'),
          ('auth', 'Check authorizing text'),
          ('auth', 'Read authenticator instructions'),
          ('auth', 'Please identify authoritarianism in the poster'),
          ('understa', 'understand the invoice.'),
          ('auth', 'The auth-based flow is documented.'),
          ('configurat', 'Please review configuration settings.'),
          ('configurat', 'Review configuration settings.'),
          ('configurat', 'Review the configuration settings.'),
          ('configurat', 'Use configuration settings to identify the receipt'),
          ('application', 'Please review the application-based template'),
          ('instruction', 'Please follow the instructions carefully.'),
          ('instruction', 'Read the instructional label'),
          ('document', 'Use documentation to process this image'),
          ('document', 'Extract the documentation'),
          ('document', 'Please read the documentation carefully'),
          ('document-', 'Read the document-based label'),
          ('character', 'Please characterize the receipt.'),
          ('prelim', 'Please review the preliminary invoice'),
          ('password', 'Please read the password-protected document.'),
          ('password', 'Read the passwordless login guide'),
          ('user-', 'Read the user-interface label'),
        ];
        final tasks = prompts.map((entry) {
          final (credentialPrefix, prompt) = entry;
          return BackgroundTask.fromMap({
            'id': 'legacy-ocr-unicode-suffix-safe-prompt-$credentialPrefix',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer $credentialPrefix…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': prompt},
                    ],
                  },
                ],
              },
            },
          });
        }).toList();
        final instructionContents = tasks
            .map(
              (task) =>
                  OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            )
            .toList();

        expect(instructionContents, prompts.map((entry) => entry.$2).toList());
        for (var index = 0; index < prompts.length; index++) {
          expect(jsonEncode(tasks[index].toMap()), contains(prompts[index].$2));
        }
      },
    );

    test(
      'legacy OCR instruction migration removes separator-normalized natural word key echoes',
      () {
        const keyCases = [
          ('auth', 'auth-orize'),
          ('auth', 'auth-orized'),
          ('token', 'token-ized'),
        ];
        const safePrompt = 'Read the receipt total carefully';
        for (final (credentialPrefix, apiKey) in keyCases) {
          final task = BackgroundTask.fromMap({
            'id':
                'legacy-ocr-hyphenated-natural-word-key-echo-$credentialPrefix',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer $credentialPrefix…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': safePrompt},
                      {
                        'type': 'text',
                        'text': 'Use $apiKey to process this image',
                      },
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());

          expect(
            OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
            '$safePrompt\nUse [redacted] to process this image',
          );
          expect(persisted, contains(safePrompt));
          expect(persisted, contains('Use [redacted] to process this image'));
          expect(persisted, isNot(contains(apiKey)));
        }
      },
    );

    test(
      'legacy OCR instruction migration preserves ordinary prompts under open-ended ASCII masks',
      () {
        const prompt = 'Please review the documentation carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-ascii-mask-natural-prompt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document...'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          prompt,
        );
        expect(persisted, contains(prompt));
      },
    );

    test(
      'legacy OCR instruction migration preserves prompts with short masked keys',
      () {
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-masked-instruction',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer k***'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {'type': 'text', 'text': 'apiKey: private-value'},
                  ],
                },
              ],
            },
          },
        });

        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          'Read the receipt total carefully',
        );
        expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
      },
    );

    test(
      'legacy OCR instruction migration redacts credentials split across text parts',
      () {
        const apiKey = 'opaque-user-secret-87';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-split-instruction-secret',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer $apiKey'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text': 'Read the receipt total carefully',
                    },
                    {'type': 'text', 'text': 'Bearer'},
                    {'type': 'text', 'text': 'opaque-user-'},
                    {'type': 'text', 'text': 'secret-87'},
                  ],
                },
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(
          OcrRetrySnapshot.fromMap(task.retryData!).instructionContent,
          isNull,
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts credential nouns used for a request',
      () {
        const echoedKey = 'passwords';
        const safePrompt = 'Read the receipt total carefully.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-open-ended-password-request-value',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer password…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': safePrompt},
                    {
                      'type': 'text',
                      'text': 'Provide $echoedKey for the request',
                    },
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final instruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(instruction, contains(safePrompt));
        expect(instruction, isNot(contains(echoedKey)));
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(echoedKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves safe text beside an echoed key',
      () {
        const apiKey = 'opaque-user-secret-87';
        const safePrompt = 'Read the receipt total carefully.';
        const originalInstruction =
            '$safePrompt Use $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-mixed-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': originalInstruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final instruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(instruction, contains(safePrompt));
        expect(instruction, contains('Use [redacted] to process this image'));
        expect(instruction, isNot(contains(apiKey)));
        expect(persisted, contains(safePrompt));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    for (final trailingInstruction in [
      'and read the total',
      'then read the total',
      'before reading the total',
      'before checking the total',
      'to verify the total',
      'to confirm the total',
    ]) {
      test(
        'legacy OCR instruction migration preserves trailing instructions after an embedded key with $trailingInstruction',
        () {
          const apiKey = 'xopaque-user-secret-87';
          final instruction =
              'Please locate $apiKey in the receipt $trailingInstruction.';
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-embedded-key-with-trailing-instruction',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer xopaque-user-…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': instruction},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());
          final retryData = OcrRetrySnapshot.fromMap(task.retryData!).toMap();

          expect(
            retryData['instructionContent'],
            'Please locate [redacted] in the receipt $trailingInstruction.',
          );
          expect(persisted, contains(trailingInstruction));
          expect(persisted, isNot(contains(apiKey)));
        },
      );
    }

    for (final (kind, instruction) in [
      ('OCR-specific', 'OCR the receipt total: opaque-user-secret-87'),
      ('search', 'Search the receipt for opaque-user-secret-87.'),
    ]) {
      test(
        'legacy OCR instruction migration preserves $kind instructions around echoed keys',
        () {
          const apiKey = 'opaque-user-secret-87';
          final expectedInstruction =
              instruction.replaceFirst(apiKey, '[redacted]');
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-$kind-instruction-key-echo',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'url': 'https://api.example.com/v1/chat/completions',
              'headers': {'Authorization': 'Bearer opaque-user-…'},
              'body': {
                'model': 'vision-model',
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': instruction},
                    ],
                  },
                ],
              },
            },
          });
          final persisted = jsonEncode(task.toMap());
          final migratedInstruction = OcrRetrySnapshot.fromMap(
            task.retryData!,
          ).instructionContent;

          expect(migratedInstruction, expectedInstruction);
          expect(persisted, contains(expectedInstruction));
          expect(migratedInstruction, isNot(contains(apiKey)));
          expect(persisted, isNot(contains(apiKey)));
        },
      );
    }

    test(
      'legacy OCR instruction migration redacts short plus-suffixed key echoes',
      () {
        const apiKey = 'opaque-user-+a';
        const instruction = 'Read the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-short-plus-suffixed-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Read the receipt using [redacted]');
        expect(persisted, contains('Read the receipt using [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves decode prompts around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-value-179';
        const instruction = 'Decode this receipt using $apiKey.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-decode-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Decode this receipt using [redacted].');
        expect(persisted, contains('Decode this receipt using [redacted].'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts repeated hyphenated echoes after structured masks',
      () {
        const apiKey = 'opaque-user-abc-abc-abc';
        const instruction = 'The scan mentions $apiKey.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-repeated-hyphenated-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'The scan mentions [redacted].');
        expect(persisted, contains('The scan mentions [redacted].'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts repeated components after a partially visible mask segment',
      () {
        const apiKey = 'opaque-user-user-user';
        const instruction = 'Read the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-repeated-partial-hyphenated-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-u…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Read the receipt using [redacted]');
        expect(persisted, contains('Read the receipt using [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes echoed keys inside larger tokens',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Read the receipt using x$apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Read the receipt using [redacted]');
        expect(persisted, contains('Read the receipt using [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves image prompts around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Look at this image: $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-image-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Look at this image: [redacted]');
        expect(persisted, contains('Look at this image: [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves check instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Check the receipt total using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-check-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Check the receipt total using [redacted]');
        expect(persisted, contains('Check the receipt total using [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves scan instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Scan the receipt for the total using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-scan-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Scan the receipt for the total using [redacted]',
        );
        expect(
          persisted,
          contains('Scan the receipt for the total using [redacted]'),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves direct transcribe requests around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Please transcribe $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-direct-transcribe-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Please transcribe [redacted]');
        expect(persisted, contains('Please transcribe [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts embedded long open-mask prefixes',
      () {
        const apiKey = 'xqwrtypsdf123';
        const instruction = 'Please transcribe $apiKey from the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-long-open-mask-prefix-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer qwrtypsdf…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Please transcribe [redacted] from the receipt.',
        );
        expect(persisted, contains('Please transcribe [redacted]'));
        expect(persisted, contains('from the receipt'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts an embedded exact long mask prefix',
      () {
        const apiKey = 'xqwrtypsdf';
        const instruction = 'Please transcribe $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-embedded-exact-long-open-mask-prefix-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer qwrtypsdf…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Please transcribe [redacted]');
        expect(persisted, contains('Please transcribe [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts natural embedded prefixes with credential tails',
      () {
        const apiKey = 'xmyprojectsecret87';
        const instruction = 'Please transcribe $apiKey from the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-embedded-prefix-credential-tail-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Please transcribe [redacted] from the receipt.',
        );
        expect(persisted, contains('Please transcribe [redacted]'));
        expect(persisted, contains('from the receipt'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes opaque alpha tails after natural embedded prefixes',
      () {
        const apiKey = 'xmyprojectfjmrxpwknlvb';
        const instruction = 'The note says $apiKey.';
        const safeInstruction = 'Read the receipt total carefully';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-embedded-prefix-opaque-alpha-tail',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                    {'type': 'text', 'text': safeInstruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, contains(safeInstruction));
        expect(persisted, contains(safeInstruction));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes short opaque alpha tails after natural embedded prefixes',
      () {
        const apiKey = 'xmyprojectfjmrxpwkk';
        const instruction =
            'Read the receipt total carefully. The note says $apiKey.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-embedded-prefix-short-opaque-alpha-tail',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
            migratedInstruction, contains('Read the receipt total carefully.'));
        expect(persisted, contains('Read the receipt total carefully.'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration removes uncommon alpha tails after natural embedded prefixes',
      () {
        const apiKey = 'xmyprojectqwrtyps';
        const instruction =
            'Read the receipt total carefully. The note says $apiKey.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-embedded-prefix-uncommon-alpha-tail',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
            migratedInstruction, contains('Read the receipt total carefully.'));
        expect(persisted, contains('Read the receipt total carefully.'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts a natural-looking key in a receipt prompt',
      () {
        const apiKey = 'xmyprojectplaything';
        const instruction = 'Read $apiKey from the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-natural-embedded-prefix-natural-suffix',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer myproject…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Read [redacted] from the receipt.');
        expect(persisted, contains('Read [redacted] from the receipt.'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves documentation read from a receipt',
      () {
        const instruction = 'Please read documentation from the receipt.';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-documentation-read-from-receipt',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer document…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, instruction);
        expect(persisted, contains(instruction));
      },
    );

    test(
      'legacy OCR instruction migration preserves colon prompts around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Please identify: $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-colon-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Please identify: [redacted]');
        expect(persisted, contains('Please identify: [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves a single instruction around an echoed key',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Read the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-single-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(migratedInstruction, 'Read the receipt using [redacted]');
        expect(persisted, contains('Read the receipt using [redacted]'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves context-setting instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction =
            'For accurate OCR, extract all totals using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-context-setting-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'For accurate OCR, extract all totals using [redacted]',
        );
        expect(
          persisted,
          contains('For accurate OCR, extract all totals using [redacted]'),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts a single Unicode continuation in an echoed key',
      () {
        const apiKey = 'opaque-user-documenté';
        const instruction = 'Read the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-single-unicode-continuation-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Read the receipt using [redacted]');
        expect(persisted, contains('Read the receipt using [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves polite review instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Could you please review the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-polite-review-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'Could you please review the receipt using [redacted]',
        );
        expect(
          persisted,
          contains('Could you please review the receipt using [redacted]'),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves use instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Use $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-use-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(migratedInstruction, 'Use [redacted] to process this image');
        expect(persisted, contains('Use [redacted] to process this image'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves page-specific use instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'For page 2, use $apiKey to process this image';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-page-use-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(
          migratedInstruction,
          'For page 2, use [redacted] to process this image',
        );
        expect(
          persisted,
          contains('For page 2, use [redacted] to process this image'),
        );
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration redacts a full long echoed credential',
      () {
        const secretTail = 'TAIL-KEY-179';
        final repeatedPrefix = List.filled(140, 'a').join();
        final apiKey = 'opaque-user-$repeatedPrefix$secretTail';
        const instructionLead = 'Read the receipt using ';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-long-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': '$instructionLead$apiKey'},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(migratedInstruction, '${instructionLead}[redacted]');
        expect(persisted, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(secretTail)));
      },
    );

    test(
      'legacy OCR instruction migration preserves process instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Please process this image using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-process-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(
          migratedInstruction,
          'Please process this image using [redacted]',
        );
        expect(
          persisted,
          contains('Please process this image using [redacted]'),
        );
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves recognize instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Recognize the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-recognize-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(migratedInstruction, 'Recognize the receipt using [redacted]');
        expect(persisted, contains('Recognize the receipt using [redacted]'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves direct recognize requests around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Recognize $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-direct-recognize-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent;

        expect(migratedInstruction, 'Recognize [redacted]');
        expect(persisted, contains('Recognize [redacted]'));
        expect(migratedInstruction, isNot(contains(apiKey)));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test(
      'legacy OCR instruction migration preserves inspect instructions around echoed keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const instruction = 'Inspect the receipt using $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-inspect-instruction-key-echo',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {'Authorization': 'Bearer opaque-user-…'},
            'body': {
              'model': 'vision-model',
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': instruction},
                  ],
                },
              ],
            },
          },
        });
        final persisted = jsonEncode(task.toMap());
        final migratedInstruction = OcrRetrySnapshot.fromMap(
          task.retryData!,
        ).instructionContent!;

        expect(migratedInstruction, 'Inspect the receipt using [redacted]');
        expect(persisted, contains('Inspect the receipt using [redacted]'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test('toMap/fromMap sanitizes OCR rawRequest and rawResponse', () {
      const rawRequest = {'url': 'https://api.example.com/ocr', 'body': 'test'};
      const rawResponse = {
        'statusCode': 400,
        'data': {'error': 'bad request'},
      };
      final task = BackgroundTask(
        id: 'diag-id',
        type: BackgroundTaskType.ocr,
        title: '诊断测试',
        status: TaskStatus.failed,
        error: '识别失败',
        rawRequest: rawRequest,
        rawResponse: rawResponse,
      );

      final map = task.toMap();
      final restored = BackgroundTask.fromMap(map);

      expect(restored.rawRequest, {'host': 'api.example.com'});
      expect(restored.rawResponse, {'statusCode': 400});
      expect(restored.error, '识别失败');
    });

    test('OCR task and step persistence exclude keys matching error types', () {
      const apiKey = 'connectionTimeout';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-error-type-key',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'error': 'OCR 请求失败（$apiKey）',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': 'OCR 请求失败（$apiKey）'},
        ],
        'rawRequest': {
          'headers': {'Authorization': 'Bearer $apiKey'},
        },
        'rawResponse': {'statusCode': 503, 'errorType': apiKey},
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.rawResponse, {'statusCode': 503});
      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(persisted, isNot(contains(apiKey)));
    });

    test('legacy OCR diagnostics omit unverified request IDs', () {
      const apiKey = 'opaque-user-secret-87';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-opaque-request-id',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'url': 'https://api.example.com/v1',
          'headers': {
            'Authorization': 'Bearer opaque-u...t-87',
            'x-request-id': [apiKey],
          },
          'body': {'messages': 'legacy image request'},
        },
        'rawResponse': {
          'statusCode': 401,
          'headers': {
            'x-request-id': [apiKey],
          },
          'data': {'id': apiKey},
        },
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.rawResponse, {'statusCode': 401});
      expect(persisted, isNot(contains(apiKey)));
    });

    test('legacy OCR diagnostics exclude credentials from request URLs', () {
      const credentials = [
        (
          'https://ocr.test/v1?key=opaque-query-secret-87',
          'opaque-query-secret-87',
        ),
        (
          'https://user:oauth-userinfo-secret@ocr.test/v1',
          'oauth-userinfo-secret',
        ),
        (
          'https://ocr.test/v1?access_token=opaque-token-secret-87',
          'opaque-token-secret-87',
        ),
        (
          'https://ocr.test/v1?secretKey=opaque-secret-key-191',
          'opaque-secret-key-191',
        ),
        (
          'https://ocr.test/v1?privateKey=opaque-private-key-191',
          'opaque-private-key-191',
        ),
      ];

      for (final (url, credential) in credentials) {
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-url-credential',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {'url': url},
          'rawResponse': {'statusCode': 401, 'requestId': credential},
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.rawResponse, {'statusCode': 401});
        expect(persisted, isNot(contains(credential)), reason: url);
      }
    });

    test('OCR task persistence omits image-shaped request IDs', () {
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-image-request-id',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'url': 'https://api.example.com/v1',
          'headers': {'x-request-id': png},
        },
        'rawResponse': {
          'statusCode': 503,
          'headers': {'x-request-id': png},
          'data': {'id': png},
        },
      });

      final persisted = jsonEncode(task.toMap());
      expect(task.rawRequest, {'host': 'api.example.com'});
      expect(task.rawResponse, {'statusCode': 503});
      expect(persisted, isNot(contains(png)));
    });

    test('legacy OCR task persistence omits short image metadata', () {
      const pngSignature = 'iVBORw0KGgo';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-short-image-metadata',
        'type': 'ocr',
        'title': 'legacy OCR request',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawResponse': {
          'statusCode': 503,
          'data': {
            'id': 'req-$pngSignature',
            'choices': [
              {'finish_reason': pngSignature},
            ],
          },
        },
      });

      final persisted = jsonEncode(task.toMap());
      expect(task.rawResponse, {'statusCode': 503});
      expect(persisted, isNot(contains(pngSignature)));
    });

    test(
      'legacy OCR diagnostics retain safe request IDs and finish reasons',
      () {
        const apiKey = 'opaque-provider-secret-value-93';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-safe-diagnostics',
          'type': 'ocr',
          'title': 'legacy OCR request',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'url': 'https://api.example.com/v1/chat/completions',
            'headers': {
              'Authorization': 'Bearer $apiKey',
              'x-request-id': ['req-request-123'],
            },
            'body': {'messages': 'legacy image request'},
          },
          'rawResponse': {
            'statusCode': 503,
            'headers': {
              'x-request-id': ['req-response-456'],
            },
            'data': {
              'choices': [
                {'finish_reason': 'stop'},
              ],
            },
          },
        });

        final persisted = jsonEncode(task.toMap());
        expect(task.rawRequest, {
          'host': 'api.example.com',
          'requestId': 'req-request-123',
        });
        expect(task.rawResponse, {
          'statusCode': 503,
          'finishReason': 'stop',
          'requestId': 'req-response-456',
        });
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test('legacy OCR auth-token header excludes echoed request IDs', () {
      const apiToken = 'req-private-value-123';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-auth-token-echo',
        'type': 'ocr',
        'title': 'legacy OCR request',
        'status': 'failed',
        'error': 'OCR request failed: $apiToken',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {
            'label': 'OCR request',
            'status': 'failed',
            'error': 'OCR request failed: $apiToken',
          },
        ],
        'rawRequest': {
          'url': 'https://api.example.com/v1/chat/completions',
          'method': 'POST',
          'headers': {'X-Auth-Token': apiToken},
          'body': {
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/png;base64,aGVsbG8='},
                  },
                ],
              },
            ],
          },
        },
        'rawResponse': {
          'statusCode': 503,
          'data': {
            'request_id': apiToken,
            'requestId': 'req-safe-auth-fallback-123',
          },
        },
      });
      final serializedTask = task.toMap();
      final persistedSnapshot = jsonEncode(serializedTask);

      expect(persistedSnapshot, isNot(contains(apiToken)));
      expect(task.retryData, isNotNull);
      expect(task.rawResponse, {
        'statusCode': 503,
        'requestId': 'req-safe-auth-fallback-123',
      });
      expect(serializedTask['error'], 'OCR 错误详情已隐藏');
      expect(serializedTask['steps'], [
        {'label': 'OCR request', 'status': 'failed', 'error': 'OCR 错误详情已隐藏'},
      ]);
      expect(persistedSnapshot, contains('req-safe-auth-fallback-123'));
    });

    test('legacy diagnostics fall back after an unsafe request ID field', () {
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-request-id-fallback',
        'type': 'ocr',
        'title': 'legacy OCR response',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawResponse': {
          'statusCode': 503,
          'data': {
            'request_id': 'Read the private receipt amount carefully',
            'requestId': 'req-safe-123',
            'id': 'chatcmpl-later-safe-id',
          },
        },
      });

      expect(task.rawResponse, {
        'statusCode': 503,
        'requestId': 'req-safe-123',
      });
      expect(jsonEncode(task.toMap()), contains('req-safe-123'));
    });

    test(
      'legacy diagnostics skip excluded ID before a later safe candidate',
      () {
        const apiKey = 'opaque-user-secret-87';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-excluded-request-id-fallback',
          'type': 'ocr',
          'title': 'legacy OCR response',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'headers': {'Authorization': 'Bearer $apiKey'},
          },
          'rawResponse': {
            'statusCode': 503,
            'data': {
              'request_id': apiKey,
              'requestId': 'req-safe-after-key',
              'id': 'chatcmpl-later-safe-id',
            },
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.rawResponse, {
          'statusCode': 503,
          'requestId': 'req-safe-after-key',
        });
        expect(persisted, contains('req-safe-after-key'));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test('legacy OCR diagnostics exclude masked credentials from host', () {
      const apiKey = 'opaque-user-secret-87';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-credential-host',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'url': 'https://$apiKey.vision.example.com/v1',
          'headers': {'Authorization': 'Bearer opaque-u...t-87'},
        },
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.rawRequest, isNot(contains('host')));
      expect(persisted, isNot(contains(apiKey)));
    });

    test('legacy OCR diagnostics omit masked secrets but retain safe IDs', () {
      const apiKey = 'opaque-user-secret-87';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-opaque-finish-reason',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'headers': {'Authorization': 'Bearer opaque-u...t-87'},
          'body': {'messages': 'legacy image request'},
        },
        'rawResponse': {
          'statusCode': 401,
          'headers': {
            'x-request-id': ['request-123'],
          },
          'data': {
            'choices': [
              {'finish_reason': apiKey},
            ],
          },
        },
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.rawResponse, {'statusCode': 401, 'requestId': 'request-123'});
      expect(persisted, isNot(contains(apiKey)));
    });

    test(
      'legacy OCR diagnostics exclude secret and private key header echoes',
      () {
        for (final entry in [
          ('X-Secret-Key', 'opaque-user-secret-192'),
          ('X-Private-Key', 'opaque-private-value-192'),
        ]) {
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-${entry.$1}',
            'type': 'ocr',
            'title': 'legacy OCR request',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'rawRequest': {
              'headers': {entry.$1: entry.$2},
              'body': {'messages': 'legacy image request'},
            },
            'rawResponse': {
              'statusCode': 401,
              'data': {'id': entry.$2},
            },
          });
          final persisted = jsonEncode(task.toMap());

          expect(task.rawResponse, {'statusCode': 401}, reason: entry.$1);
          expect(persisted, isNot(contains(entry.$2)), reason: entry.$1);
        }
      },
    );

    test(
      'legacy OCR diagnostics exclude echoed keys from prefix-only auth masks',
      () {
        const apiKey = 'opaque-prefix-private-value-179';
        const safeRequestId = 'req-safe-after-prefix-mask';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-prefix-only-auth-mask',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'rawRequest': {
            'headers': {'Authorization': 'Bearer opaque-prefix...'},
          },
          'rawResponse': {
            'statusCode': 503,
            'data': {'request_id': apiKey, 'requestId': safeRequestId},
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.rawResponse, {
          'statusCode': 503,
          'requestId': safeRequestId,
        });
        expect(persisted, contains(safeRequestId));
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test('legacy OCR task persistence excludes short masked auth echoes', () {
      const apiKey = 'abcd';
      const safeRequestId = 'req-safe-after-tiny-mask';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-tiny-auth-mask',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'rawRequest': {
          'headers': {'Authorization': 'Bearer a***'},
        },
        'rawResponse': {
          'statusCode': 401,
          'requestId': apiKey,
          'data': {'requestId': safeRequestId},
        },
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.rawResponse, {'statusCode': 401, 'requestId': safeRequestId});
      expect(persisted, contains(safeRequestId));
      expect(persisted, isNot(contains(apiKey)));
    });

    test('OCR task error sanitizer preserves safe Dio failure types', () {
      const safeError = 'OCR 请求失败（connectionTimeout）';
      const wrappedLegacyError = 'OCR识别失败: $safeError';
      final task = BackgroundTask.fromMap({
        'id': 'ocr-safe-transport-error',
        'type': 'ocr',
        'title': 'OCR 任务',
        'status': 'failed',
        'error': safeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': safeError},
        ],
      });

      expect(task.error, safeError);
      expect(task.steps.single.error, safeError);
      expect(jsonEncode(task.toMap()), contains(safeError));

      final wrappedTask = BackgroundTask.fromMap({
        'id': 'legacy-ocr-safe-wrapped-dio-error',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'error': wrappedLegacyError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      expect(wrappedTask.error, wrappedLegacyError);
    });

    test(
      'legacy OCR task and step errors hide unclassified provider echoes',
      () {
        const providerEcho = 'HTTP 400: invoice for Jane Doe';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-unclassified-provider-error',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'error': providerEcho,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': '请求 OCR', 'status': 'failed', 'error': providerEcho},
          ],
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.error, 'OCR 错误详情已隐藏（HTTP 400）');
        expect(task.steps.single.error, 'OCR 错误详情已隐藏（HTTP 400）');
        expect(persisted, contains('HTTP 400'));
        expect(persisted, isNot(contains('invoice for Jane Doe')));

        final statusOnly = BackgroundTask.fromMap({
          'id': 'legacy-ocr-status-only-error',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'error': 'HTTP 400',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        });
        expect(statusOnly.error, 'HTTP 400');

        final nonOcr = BackgroundTask.fromMap({
          'id': 'legacy-asr-provider-error',
          'type': 'asr',
          'title': '旧版 ASR 任务',
          'status': 'failed',
          'error': providerEcho,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        });
        expect(nonOcr.error, providerEcho);
      },
    );

    test('legacy OCR task and step errors redact response bodies on load', () {
      final apiKey = 'AIza${List.filled(35, 'a').join()}';
      final imageData = base64Encode(List<int>.filled(256, 65));
      final legacyError = 'OCR识别失败: Exception: 请求失败 (HTTP 401): '
          'OCR 返回了不完整结果（finish_reason=length） '
          '{"api_key":"$apiKey","image":"data:image/png;base64,$imageData"}';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-with-error-body',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'result': 'partial result',
        'error': legacyError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': legacyError},
        ],
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.resultIsComplete, isFalse);
      expect(task.error, isNot(contains(apiKey)));
      expect(task.error, isNot(contains(imageData)));
      expect(task.steps.single.error, isNot(contains(apiKey)));
      expect(task.steps.single.error, isNot(contains(imageData)));
      expect(persisted, isNot(contains(apiKey)));
      expect(persisted, isNot(contains(imageData)));
      expect(task.error, contains('HTTP 401'));
    });

    test('legacy OCR task and step errors redact bare base64 images', () {
      const imageBodies = [
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/1s8AAAAASUVORK5CYII=',
        'UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEAAUAmJaQAA3AA/v89WAAAAA==',
      ];

      for (var index = 0; index < imageBodies.length; index++) {
        final imageBody = imageBodies[index];
        expect(imageBody.length, lessThan(160));
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-image-error-$index',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'error': imageBody,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': '请求 OCR', 'status': 'failed', 'error': imageBody},
          ],
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.error, 'OCR 错误详情已隐藏');
        expect(task.steps.single.error, 'OCR 错误详情已隐藏');
        expect(persisted, isNot(contains(imageBody)));
      }

      final ordinaryError = BackgroundTask.fromMap({
        'id': 'legacy-ocr-ordinary-error',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'error': 'OCR 任务因格式问题未完成',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });
      expect(ordinaryError.error, 'OCR 任务因格式问题未完成');
    });

    test('legacy OCR refusal text redacts short bare base64 image bodies', () {
      const imageBodies = [
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/1s8AAAAASUVORK5CYII=',
        'UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEAAUAmJaQAA3AA/v89WAAAAA==',
      ];

      for (var index = 0; index < imageBodies.length; index++) {
        final imageBody = imageBodies[index];
        final wrappedBody = imageBody.replaceAllMapped(
          RegExp(r'.{1,4}'),
          (match) => '${match.group(0)} ',
        );
        final error = 'Exception: OCR 请求被模型拒绝: $wrappedBody';
        expect(error.length, lessThan(160));
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-refusal-image-error-$index',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'error': error,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': '请求 OCR', 'status': 'failed', 'error': error},
          ],
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.error, 'OCR 错误详情已隐藏');
        expect(task.steps.single.error, 'OCR 错误详情已隐藏');
        expect(persisted, isNot(contains(wrappedBody)));
      }
    });

    test(
      'legacy OCR task and step errors redact credentials from auth headers',
      () {
        const apiKey = 'opaque-user-secret-87';
        for (final authorization in [
          'Bearer $apiKey',
          'Bearer opaque-u...t-87',
        ]) {
          final error = 'Provider rejected credential $apiKey';
          final task = BackgroundTask.fromMap({
            'id': 'legacy-ocr-auth-error',
            'type': 'ocr',
            'title': '旧版 OCR 任务',
            'status': 'failed',
            'error': error,
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [
              {'label': '请求 OCR', 'status': 'failed', 'error': error},
            ],
            'rawRequest': {
              'url': 'https://api.example.com/v1',
              'headers': {'Authorization': authorization},
            },
          });
          final persisted = jsonEncode(task.toMap());

          expect(task.error, 'OCR 错误详情已隐藏');
          expect(task.steps.single.error, 'OCR 错误详情已隐藏');
          expect(persisted, isNot(contains(apiKey)));
        }
      },
    );

    test(
      'legacy OCR task and step errors redact opaque X-Token header values',
      () {
        const apiToken = 'private-opaque-header-166';
        final error = 'Provider rejected credential $apiToken';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-x-token-error',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'error': error,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': '请求 OCR', 'status': 'failed', 'error': error},
          ],
          'rawRequest': {
            'url': 'https://api.example.com/v1',
            'headers': {'X-Token': apiToken},
          },
        });

        final persisted = jsonEncode(task.toMap());

        expect(task.error, 'OCR 错误详情已隐藏');
        expect(task.steps.single.error, 'OCR 错误详情已隐藏');
        expect(persisted, isNot(contains(apiToken)));
      },
    );

    test(
      'later OCR task and step errors retain X-Token exclusions in memory',
      () {
        const apiToken = 'private-opaque-header-later-172';
        final notifier = BackgroundTaskNotifier();
        final id = notifier.addTask(
          type: BackgroundTaskType.ocr,
          title: 'OCR后续错误',
        );

        notifier.setRawDiagnostics(
          id,
          rawRequest: {
            'url': 'https://api.example.com/v1',
            'headers': {'X-Token': apiToken},
          },
        );
        expect(notifier.state.single.rawRequest, {'host': 'api.example.com'});

        notifier.updateStep(
          id,
          0,
          failed: true,
          error: 'Provider rejected credential $apiToken',
        );
        notifier.failTask(
          id,
          error: 'OCR failed with credential $apiToken',
          rawResponse: {'requestId': apiToken},
        );

        final task = notifier.state.single;
        expect(task.error, 'OCR 错误详情已隐藏');
        expect(task.steps.first.error, 'OCR 错误详情已隐藏');
        expect(task.rawResponse, isNot(contains('requestId')));
        expect(jsonEncode(task.toMap()), isNot(contains(apiToken)));
      },
    );

    test(
      'legacy OCR task errors filter extracted details against auth keys',
      () {
        const apiKey = 'opaque-user-secret-87';
        const error = 'OCR request failed HTTP 503 finish_reason=$apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-auth-error-details',
          'type': 'ocr',
          'title': '旧版 OCR 任务',
          'status': 'failed',
          'error': error,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': '请求 OCR', 'status': 'failed', 'error': error},
          ],
          'rawRequest': {
            'url': 'https://api.example.com/v1',
            'headers': {'Authorization': 'Bearer $apiKey'},
          },
        });
        final persisted = jsonEncode(task.toMap());

        expect(task.error, 'OCR 错误详情已隐藏（HTTP 503）');
        expect(task.steps.single.error, 'OCR 错误详情已隐藏（HTTP 503）');
        expect(persisted, isNot(contains(apiKey)));
      },
    );

    test('legacy short OCR refusal errors redact token assignments', () {
      const unsafeError = 'OCR 请求被模型拒绝: token=private-value';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-refusal-token',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy exception OCR refusal text is not persisted', () {
      const providerText = '发票姓名张三，订单金额 1280 元';
      const unsafeError = 'Exception: OCR 请求被模型拒绝: $providerText';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-exception-refusal',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(persisted, isNot(contains(providerText)));
      expect(persisted, isNot(contains('Exception:')));
    });

    test('legacy bare OCR refusal text is not persisted', () {
      const providerText = '发票姓名张三，订单金额 1280 元';
      const unsafeError = 'OCR 请求被模型拒绝: $providerText';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-bare-refusal',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });
      final persisted = jsonEncode(task.toMap());

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(persisted, isNot(contains(providerText)));
    });

    test('legacy OCR task and step errors redact bare key fields', () {
      const unsafeError = 'OCR rejected: key=private-value';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-bare-key',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy OCR task and step errors redact spaced API key fields', () {
      const unsafeError = 'OCR rejected: API key=private-value';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-api-key-space',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy short OCR refusal errors redact bearer assignments', () {
      const unsafeError = 'OCR 请求被模型拒绝: bearer=private-value';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-refusal-bearer',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy short OCR refusal errors redact prefixed camel-case keys', () {
      const unsafeError = 'OCR 请求被模型拒绝: xApiKey=private-value';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-refusal-prefixed-key',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy OCR task and step errors redact OpenAI project keys', () {
      const unsafeError = 'Incorrect API key provided: '
          'sk-proj-abcdefghijklmnopqrstuvwxyz1234567890';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-openai-project-key',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(
        jsonEncode(task.toMap()),
        isNot(contains('abcdefghijklmnopqrstuvwxyz1234567890')),
      );
    });

    test('legacy OCR task and step errors redact Anthropic API keys', () {
      const unsafeError = 'Incorrect API key provided: '
          'sk-ant-api03-abcdefghijklmnopqrstuvwxyz1234567890';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-anthropic-api-key',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(
        jsonEncode(task.toMap()),
        isNot(contains('abcdefghijklmnopqrstuvwxyz1234567890')),
      );
    });

    test('legacy OCR task and step errors redact Groq and OpenRouter keys', () {
      const apiKeys = [
        'gsk_abcdefghijklmnopqrstuvwxyz1234567890',
        'sk-or-v1-abcdefghijklmnopqrstuvwxyz1234567890',
      ];

      for (var index = 0; index < apiKeys.length; index++) {
        final apiKey = apiKeys[index];
        final unsafeError = 'Incorrect API key provided: $apiKey';
        final task = BackgroundTask.fromMap({
          'id': 'legacy-ocr-provider-key-$index',
          'type': 'ocr',
          'title': '旧版 OCR 拒绝响应',
          'status': 'failed',
          'error': unsafeError,
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [
            {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
          ],
        });

        expect(task.error, 'OCR 错误详情已隐藏');
        expect(task.steps.single.error, 'OCR 错误详情已隐藏');
        expect(jsonEncode(task.toMap()), isNot(contains(apiKey)));
      }
    });

    test('legacy OCR task and step errors redact client secret fields', () {
      const unsafeError = 'OCR rejected: client_secret=private-value';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-client-secret',
        'type': 'ocr',
        'title': '旧版 OCR 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy OCR task errors redact quoted JSON credential fields', () {
      const unsafeError = 'OCR rejected: {"client_secret":"private-value"}';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-json-client-secret',
        'type': 'ocr',
        'title': '旧版 OCR JSON 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('legacy OCR task and step errors redact secret key fields', () {
      const unsafeError = 'OCR rejected: {"secret_key":"private-value"}';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-json-secret-key',
        'type': 'ocr',
        'title': '旧版 OCR JSON 拒绝响应',
        'status': 'failed',
        'error': unsafeError,
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'steps': [
          {'label': '请求 OCR', 'status': 'failed', 'error': unsafeError},
        ],
      });

      expect(task.error, 'OCR 错误详情已隐藏');
      expect(task.steps.single.error, 'OCR 错误详情已隐藏');
      expect(jsonEncode(task.toMap()), isNot(contains('private-value')));
    });

    test('failTask with rawRequest/rawResponse stores diagnostics', () {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR诊断');

      const rawRequest = {'url': 'https://api.example.com/ocr', 'body': 'test'};
      const rawResponse = {
        'statusCode': 500,
        'data': {'error': 'server error'},
      };

      notifier.failTask(
        id,
        error: 'OCR失败',
        rawRequest: rawRequest,
        rawResponse: rawResponse,
      );

      expect(notifier.state[0].status, TaskStatus.failed);
      expect(notifier.state[0].error, 'OCR失败');
      expect(notifier.state[0].rawRequest, {'host': 'api.example.com'});
      expect(notifier.state[0].rawResponse, {'statusCode': 500});
    });

    // ==================================================================
    // Waiting status tests
    // ==================================================================

    test('addTask with startImmediately=false creates waiting task', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: '等待中ASR',
        startImmediately: false,
      );

      expect(notifier.state.length, 1);
      expect(notifier.state[0].id, id);
      expect(notifier.state[0].status, TaskStatus.waiting);
      expect(
        notifier.state[0].steps.every((s) => s.status == BgStepStatus.pending),
        isTrue,
        reason: '等待中的任务所有步骤应为 pending',
      );
    });

    test('startTask transitions waiting task to running', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: '将要启动的任务',
        startImmediately: false,
      );
      expect(notifier.state[0].status, TaskStatus.waiting);

      notifier.startTask(id);

      expect(notifier.state[0].status, TaskStatus.running);
      expect(notifier.state[0].statusChangedAt, isNotNull);
    });

    test('startTask on non-existent id does nothing', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');

      expect(() => notifier.startTask('non-existent'), returnsNormally);
      expect(notifier.state.length, 1);
      expect(notifier.state[0].status, TaskStatus.running);
    });

    test('startTask on already running task does nothing', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      expect(notifier.state[0].status, TaskStatus.running);

      notifier.startTask(id);

      expect(notifier.state[0].status, TaskStatus.running);
    });

    test('toMap/fromMap round-trip preserves waiting status', () {
      final task = BackgroundTask(
        id: 'waiting-id',
        type: BackgroundTaskType.asr,
        title: '等待转写',
        status: TaskStatus.waiting,
        createdAt: DateTime(2025, 6, 1),
      );

      final map = task.toMap();
      final restored = BackgroundTask.fromMap(map);

      expect(restored.status, TaskStatus.waiting);
      expect(restored.title, '等待转写');
    });

    test('startTask on paused task does nothing', () {
      final notifier = BackgroundTaskNotifier();
      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      // Add a paused task directly
      notifier.state = [
        notifier.state[0],
        BackgroundTask(
          id: 'paused-id',
          type: BackgroundTaskType.asr,
          title: '已暂停任务',
          status: TaskStatus.paused,
          createdAt: DateTime(2025, 6, 1),
        ),
      ];

      notifier.startTask('paused-id');

      expect(
        notifier.state[1].status,
        TaskStatus.paused,
        reason: '已暂停的任务调用 startTask 不应改变状态',
      );
    });

    test('startTask on completed task does nothing', () {
      final notifier = BackgroundTaskNotifier();
      notifier.state = [
        BackgroundTask(
          id: 'completed-id',
          type: BackgroundTaskType.ocr,
          title: '已完成任务',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 6, 1),
        ),
      ];

      notifier.startTask('completed-id');

      expect(
        notifier.state[0].status,
        TaskStatus.completed,
        reason: '已完成的任务调用 startTask 不应改变状态',
      );
    });

    test('startTask on failed task does nothing', () {
      final notifier = BackgroundTaskNotifier();
      notifier.state = [
        BackgroundTask(
          id: 'failed-id',
          type: BackgroundTaskType.asr,
          title: '失败任务',
          status: TaskStatus.failed,
          createdAt: DateTime(2025, 6, 1),
          error: '之前失败的错误',
        ),
      ];

      notifier.startTask('failed-id');

      expect(
        notifier.state[0].status,
        TaskStatus.failed,
        reason: '失败的任务调用 startTask 不应改变状态',
      );
      expect(
        notifier.state[0].error,
        '之前失败的错误',
        reason: 'startTask 不应清除失败任务的错误信息',
      );
    });

    test('consecutive startTask calls are idempotent', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: '幂等测试',
        startImmediately: false,
      );
      expect(notifier.state[0].status, TaskStatus.waiting);

      // First startTask transitions waiting -> running
      notifier.startTask(id);
      expect(notifier.state[0].status, TaskStatus.running);

      // Second startTask should be a no-op
      final firstChangedAt = notifier.state[0].statusChangedAt;
      notifier.startTask(id);
      expect(notifier.state[0].status, TaskStatus.running);
      expect(
        notifier.state[0].statusChangedAt,
        firstChangedAt,
        reason: '第二次 startTask 不应更新 statusChangedAt',
      );
    });

    test('startTask preserves steps and other fields of waiting task', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: '待启动任务',
        startImmediately: false,
      );

      // Verify initial steps
      final initialSteps = notifier.state[0].steps;
      expect(initialSteps.length, 5);
      expect(
        initialSteps.every((s) => s.status == BgStepStatus.pending),
        isTrue,
      );

      notifier.startTask(id);

      // Steps should remain unchanged after startTask
      expect(notifier.state[0].steps.length, initialSteps.length);
      expect(
        notifier.state[0].steps.every((s) => s.status == BgStepStatus.pending),
        isTrue,
        reason: 'startTask 不应修改步骤状态',
      );
      expect(notifier.state[0].title, '待启动任务');
      expect(notifier.state[0].type, BackgroundTaskType.asr);
    });

    // ==================================================================
    // RetryData tests (background computation resilience)
    // ==================================================================

    test('setRetryData updates retryData on existing task', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'OCR任务',
        retryData: null, // initially no retryData
      );
      expect(notifier.state[0].retryData, isNull);

      const retryData = <String, dynamic>{
        'type': 'ocr',
        'modelIndex': 0,
        'images': [],
      };
      notifier.setRetryData(id, retryData);

      expect(notifier.state[0].retryData, retryData);
    });

    test(
      'setRetryData with null preserves existing retryData (use clearRetryData to clear)',
      () {
        final notifier = BackgroundTaskNotifier();

        final id = notifier.addTask(
          type: BackgroundTaskType.asr,
          title: 'ASR任务',
          retryData: <String, dynamic>{'key': 'value'},
        );
        expect(notifier.state[0].retryData, isNotNull);

        // setRetryData with null should NOT clear existing data
        // (the copyWith pattern distinguishes between "not provided" and "clear")
        notifier.setRetryData(id, null);

        expect(
          notifier.state[0].retryData,
          isNotNull,
          reason: 'setRetryData(null) should not clear existing retryData',
        );
      },
    );

    test('clearRetryData explicitly removes stored retry data', () async {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: 'ASR任务',
        retryData: <String, dynamic>{'version': 2},
      );

      expect(await notifier.clearRetryData(id), isTrue);

      expect(notifier.state.single.retryData, isNull);
    });

    test('setRetryData on non-existent task does nothing', () {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR1');
      expect(
        () => notifier.setRetryData('non-existent', <String, dynamic>{}),
        returnsNormally,
      );
      expect(notifier.state.length, 1);
      expect(notifier.state[0].retryData, isNull);
    });

    test('waiting task with no retryData can still be started and failed', () {
      final notifier = BackgroundTaskNotifier();

      // Create task with startImmediately=false AND no retryData
      // (simulating the flow where retryData computation failed)
      final id = notifier.addTask(
        type: BackgroundTaskType.asr,
        title: '无retryData的任务',
        retryData: null,
        startImmediately: false,
      );
      expect(notifier.state[0].status, TaskStatus.waiting);
      expect(notifier.state[0].retryData, isNull);

      // Start the task as _executeTaskChain would
      notifier.startTask(id);
      expect(notifier.state[0].status, TaskStatus.running);

      // Fail the task as processing would on error
      notifier.failTask(id, error: '处理失败');
      expect(notifier.state[0].status, TaskStatus.failed);
      expect(notifier.state[0].error, '处理失败');
    });

    test('retryData can be set lazily after task creation', () {
      final notifier = BackgroundTaskNotifier();

      // Simulate: task created without retryData, then retryData
      // computed in background isolate and set later
      final id = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: '音频分离',
        retryData: null,
      );
      expect(notifier.state[0].retryData, isNull);

      // Background computation completes, set the retryData
      const retryData = <String, dynamic>{
        'type': 'audioSeparation',
        'videos': [
          {'name': 'test.mp4', 'format': 'mp4'},
        ],
      };
      notifier.setRetryData(id, retryData);

      expect(notifier.state[0].retryData, retryData);

      // Task execution should still work after retryData is set
      notifier.completeTask(id);
      expect(notifier.state[0].status, TaskStatus.completed);
    });

    // ==================================================================
    // Persistence tests (real file under the per-test isolated directory)
    // ==================================================================

    test(
      'tasks persist to disk and restore across notifier instances',
      () async {
        final file = _tasksFileIn(testDir.path);

        final n1 = BackgroundTaskNotifier();
        final id = n1.addTask(type: BackgroundTaskType.ocr, title: '持久化任务');
        n1.completeTask(id, downloadedFilePath: 'C:\\result.txt');

        // 等待本测试的数据真正落盘（按内容判断：写入是异步的）。
        await _waitFor(() async {
          final content = await _readFileIfExists(file);
          return (content?.contains(id) ?? false) &&
              (content?.contains('"status":"completed"') ?? false);
        });

        final n2 = BackgroundTaskNotifier();
        await n2.restoreFromPersistence();

        expect(n2.state.length, 1);
        expect(n2.state[0].id, id);
        expect(n2.state[0].status, TaskStatus.completed);
        expect(n2.state[0].downloadedFilePath, 'C:\\result.txt');
      },
    );

    test(
      'corrupt persisted entries are skipped, valid entries survive',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'good-id',
              'type': 'ocr',
              'title': '有效任务',
              'status': 'completed',
              'createdAt': DateTime.now().toIso8601String(),
            },
            'garbage entry', // non-map entry
            {
              'id': 'bad-id',
              'type': 'unknown-type', // unknown enum value
              'title': '坏任务',
              'status': 'running',
              'createdAt': 'not-a-date',
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        await notifier.restoreFromPersistence();

        // Only the valid entry survives; corrupt entries must not crash
        // the whole restore.
        expect(notifier.state.length, 1);
        expect(notifier.state[0].id, 'good-id');
        expect(notifier.state[0].status, TaskStatus.completed);
      },
    );

    test(
      'malformed OCR retry data preserves the task and blocks incomplete retry',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'malformed-ocr-retry-data',
              'type': 'ocr',
              'title': 'Recoverable OCR task',
              'status': 'failed',
              'error': 'OCR request failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': ['not', 'a', 'map'],
              'rawRequest': {'imageCount': 2},
            },
            {
              'id': 'malformed-ocr-retry-data-unknown-count',
              'type': 'ocr',
              'title': 'OCR task with unknown image count',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': 'not a map',
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();

          final restoredTask = notifier.taskById('malformed-ocr-retry-data');
          expect(restoredTask, isNotNull);
          final task = restoredTask!;
          expect(task.id, 'malformed-ocr-retry-data');
          expect(task.title, 'Recoverable OCR task');
          expect(task.error, 'OCR request failed');

          final retryData = task.retryData;
          expect(retryData, isNotNull);
          final snapshot = OcrRetrySnapshot.fromMap(retryData!);
          expect(snapshot.imageEntryCount, 2);
          final restoredImages = await OcrRetryStorage.restoreImages(snapshot);
          expect(restoredImages.isComplete, isFalse);
          expect(restoredImages.images, isEmpty);
          expect(restoredImages.missingImageCount, 2);

          final unknownCountTask = notifier.taskById(
            'malformed-ocr-retry-data-unknown-count',
          );
          expect(unknownCountTask, isNotNull);
          final unknownCountData = unknownCountTask!.retryData;
          expect(unknownCountData, isNotNull);
          expect(
            OcrRetrySnapshot.fromMap(unknownCountData!).imageEntryCount,
            0,
          );

          final persistedTasks =
              jsonDecode(await file.readAsString()) as List<dynamic>;
          expect(
            persistedTasks.every(
              (task) => (task as Map<String, dynamic>)['retryData']
                  is Map<String, dynamic>,
            ),
            isTrue,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'startup cleanup preserves OCR cache when tasks JSON is unreadable',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'unreadable-task-store-cache';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString('{unreadable json');

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();

          expect(notifier.state, isEmpty);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unknown OCR retry extensions block preserving a skipped task row',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'skipped-ocr-with-unknown-retry-fields';
        const apiKey = 'skipped-v2-credential-155';
        final imageBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          4,
          5,
          6,
        ]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final imageEntries = retryData['images'] as List<dynamic>;
        final imageEntry = Map<String, dynamic>.from(imageEntries.single as Map)
          ..['imageData'] = 'data:image/png;base64,${base64Encode(imageBytes)}';
        imageEntries[0] = imageEntry;
        retryData['apiKey'] = apiKey;
        final cacheReference = imageEntry['storageRef'] as String;
        final skippedRow = {
          // Missing id keeps the task row skipped, so any retry snapshot must
          // be safe to preserve byte-for-byte before unrelated task writes.
          'type': 'ocr',
          'title': 'Skipped OCR task with unknown retry fields',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': retryData,
        };
        final validSibling = BackgroundTask(
          id: 'valid-sibling-with-unknown-retry-row',
          type: BackgroundTaskType.asr,
          title: 'Valid sibling',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([skippedRow, validSibling]));
        final originalBytes = await file.readAsBytes();
        var writeAttempts = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          writeAttempts++;
        };

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          expect(
            notifier.state.map((task) => task.id),
            contains('valid-sibling-with-unknown-retry-row'),
          );

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Do not rewrite the unsafe skipped row',
            taskId: 'new-task-with-unsafe-skipped-neighbor',
          );
          await notifier.pendingPersistence;

          expect(
            notifier.taskById('new-task-with-unsafe-skipped-neighbor'),
            isNotNull,
          );
          expect(writeAttempts, 0);
          expect(await file.readAsBytes(), originalBytes);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'startup cleanup preserves skipped task refs while later writes persist',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'malformed-task-entry-cache';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'ocr',
              'title': 'corrupt OCR task',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': retryData,
            },
            {
              'id': 'valid-task-after-corrupt-entry',
              'type': 'asr',
              'title': 'valid task',
              'status': 'completed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
            },
          ]),
        );

        final originalSnapshot = await file.readAsBytes();
        final writtenTaskIds = <String>[];
        try {
          for (var startup = 0; startup < 2; startup++) {
            final notifier = BackgroundTaskNotifier();
            try {
              await notifier.restoreFromPersistence();

              expect(
                notifier.state.map((task) => task.id),
                containsAll([
                  'valid-task-after-corrupt-entry',
                  ...writtenTaskIds,
                ]),
              );
              expect(await OcrRetryStorage.read(cacheReference), imageBytes);
              if (startup == 0) {
                expect(await file.readAsBytes(), originalSnapshot);
              }

              final newTaskId = 'new-task-after-partial-restore-$startup';
              writtenTaskIds.add(newTaskId);
              notifier.addTask(
                type: BackgroundTaskType.asr,
                title: 'task after partial restore',
                taskId: newTaskId,
              );
              await notifier.pendingPersistence;

              expect(
                notifier.state.any((task) => task.id == newTaskId),
                isTrue,
              );
              final persisted = jsonDecode(await file.readAsString()) as List;
              expect(
                persisted.whereType<Map>().singleWhere(
                      (task) => task['title'] == 'corrupt OCR task',
                    ),
                {
                  'type': 'ocr',
                  'title': 'corrupt OCR task',
                  'status': 'failed',
                  'createdAt': DateTime(2025, 1, 1).toIso8601String(),
                  'steps': [],
                  'retryData': retryData,
                },
              );
              expect(
                persisted.whereType<Map>().map((task) => task['id']),
                containsAll([
                  'valid-task-after-corrupt-entry',
                  ...writtenTaskIds,
                ]),
              );
              expect(await OcrRetryStorage.read(cacheReference), imageBytes);
            } finally {
              notifier.dispose();
              await notifier.pendingPersistence;
            }
          }
        } finally {
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'new OCR task persists after safe partial restore and survives restart',
      () async {
        WebFileStore.enableTestMode();
        const skippedTaskId = 'skipped-ocr-task-cache-owner';
        const newTaskId = 'new-ocr-task-after-safe-partial-restore';
        final skippedImageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final newImageBytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);
        final skippedRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: skippedTaskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: skippedImageBytes, format: 'png')],
          ),
        );
        final skippedCacheReference =
            ((skippedRetryData['images'] as List).single as Map)['storageRef']
                as String;
        final newRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: newTaskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: newImageBytes, format: 'jpeg')],
          ),
        );
        final newCacheReference = ((newRetryData['images'] as List).single
            as Map)['storageRef'] as String;
        final skippedRow = <String, dynamic>{
          // A missing ID makes this row unparseable, but the provider can
          // preserve it losslessly alongside ordinary task updates.
          'type': 'ocr',
          'title': 'Skipped OCR task with a live cache reference',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [],
          'retryData': skippedRetryData,
          'extensionData': {
            'preserve': [1, 'two', true],
          },
        };
        final validSibling = BackgroundTask(
          id: 'valid-sibling-after-partial-restore',
          type: BackgroundTaskType.asr,
          title: 'Valid sibling',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([skippedRow, validSibling]));
        final originalBytes = await file.readAsBytes();

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          expect(
            notifier.taskById('valid-sibling-after-partial-restore'),
            isNotNull,
          );
          expect(notifier.state.map((task) => task.id), [
            'valid-sibling-after-partial-restore',
          ]);
          expect(
            await OcrRetryStorage.read(skippedCacheReference),
            skippedImageBytes,
          );
          expect(await file.readAsBytes(), originalBytes);

          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'New task after partial restore',
            taskId: newTaskId,
            retryData: newRetryData,
            startImmediately: false,
          );
          await notifier.pendingPersistence;
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }

        final restarted = BackgroundTaskNotifier();
        try {
          await restarted.restoreFromPersistence();
          expect(restarted.taskById(newTaskId), isNotNull);
          expect(
            restarted.taskById('valid-sibling-after-partial-restore'),
            isNotNull,
          );
          final persisted = jsonDecode(await file.readAsString()) as List;
          expect(
            persisted.whereType<Map>().singleWhere(
                  (row) => row['title'] == skippedRow['title'],
                ),
            skippedRow,
          );
          expect(
            persisted.whereType<Map>().any((row) => row['id'] == newTaskId),
            isTrue,
          );
          expect(
            persisted.whereType<Map>().any(
                  (row) => row['id'] == 'valid-sibling-after-partial-restore',
                ),
            isTrue,
          );
          expect(
            await OcrRetryStorage.read(skippedCacheReference),
            skippedImageBytes,
          );
          expect(await OcrRetryStorage.read(newCacheReference), newImageBytes);
        } finally {
          restarted.dispose();
          await restarted.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'partial restore preserves skipped non-OCR retry data on later writes',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final skippedAsrRow = <String, dynamic>{
          // Missing id makes this a skipped row while retaining a normal ASR
          // retry payload that the OCR snapshot parser must not interpret.
          'type': 'asr',
          'title': 'Skipped ASR task',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {
            'inputPath': '/recordings/interview.wav',
            'language': 'zh-CN',
          },
        };
        final validSibling = BackgroundTask(
          id: 'valid-asr-sibling',
          type: BackgroundTaskType.asr,
          title: 'Valid ASR task',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        await file.writeAsString(jsonEncode([skippedAsrRow, validSibling]));

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          expect(notifier.taskById('valid-asr-sibling'), isNotNull);

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'New ASR task after partial restore',
            taskId: 'new-asr-after-partial-restore',
          );
          await notifier.pendingPersistence;

          final persisted = jsonDecode(await file.readAsString()) as List;
          final preservedAsr = persisted.whereType<Map>().singleWhere(
                (row) => row['title'] == 'Skipped ASR task',
              );
          expect(preservedAsr, skippedAsrRow);
          expect(
            persisted.whereType<Map>().any(
                  (row) => row['id'] == 'new-asr-after-partial-restore',
                ),
            isTrue,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }

        final restarted = BackgroundTaskNotifier();
        try {
          await restarted.restoreFromPersistence();
          expect(
            restarted.taskById('new-asr-after-partial-restore'),
            isNotNull,
          );
          expect(restarted.taskById('valid-asr-sibling'), isNotNull);
        } finally {
          restarted.dispose();
          await restarted.pendingPersistence;
        }
      },
    );

    test(
      'partial restore does not preserve legacy ASR data URI payloads',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final encodedAudio = base64Encode(List<int>.filled(64, 0x5a));
        final skippedAsrRow = <String, dynamic>{
          // Missing id keeps this corrupt legacy row on the skipped path.
          'type': 'asr',
          'title': 'Skipped ASR data URI',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {
            'metadata': 'data:audio/wav;base64,$encodedAudio',
          },
        };
        final validSibling = BackgroundTask(
          id: 'valid-asr-sibling-next-to-data-uri',
          type: BackgroundTaskType.asr,
          title: 'Valid ASR task',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        await file.writeAsString(jsonEncode([skippedAsrRow, validSibling]));

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(
            notifier.taskById('valid-asr-sibling-next-to-data-uri'),
            isNotNull,
          );

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Task after partial restore',
            taskId: 'task-after-partial-asr-data-uri',
          );
          await notifier.pendingPersistence;

          final persisted = await file.readAsString();
          expect(persisted, isNot(contains(encodedAudio)));
          expect(persisted, isNot(contains('data:audio/wav;base64')));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'partial restore does not preserve line-wrapped legacy ASR bytes',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final inlineAudio = base64Encode(
          List<int>.generate(96, (index) => (index * 17 + 3) % 256),
        );
        final wrappedAudio = RegExp('.{1,24}')
            .allMatches(inlineAudio)
            .map((match) => match.group(0)!)
            .join('\n');
        final skippedAsrRow = <String, dynamic>{
          // Missing id keeps this corrupt legacy row on the skipped path.
          'type': 'asr',
          'title': 'Skipped ASR wrapped bytes',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {'bytes': wrappedAudio},
        };
        final validSibling = BackgroundTask(
          id: 'valid-asr-sibling-next-to-wrapped-bytes',
          type: BackgroundTaskType.asr,
          title: 'Valid ASR task',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        await file.writeAsString(jsonEncode([skippedAsrRow, validSibling]));

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(
            notifier.taskById('valid-asr-sibling-next-to-wrapped-bytes'),
            isNotNull,
          );

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Task after partial restore',
            taskId: 'task-after-partial-asr-wrapped-bytes',
          );
          await notifier.pendingPersistence;

          final persisted = await file.readAsString();
          expect(persisted, isNot(contains(inlineAudio)));
          for (final chunk in RegExp('.{1,24}')
              .allMatches(inlineAudio)
              .map((match) => match.group(0)!)) {
            expect(persisted, isNot(contains(chunk)));
          }
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'partial restore does not preserve credentials in skipped ASR URLs',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        const credentialedUrl = 'https://alice:opaque-pass@host/audio.wav';
        final skippedAsrRow = <String, dynamic>{
          // Missing id keeps this corrupt legacy row on the skipped path.
          'type': 'asr',
          'title': 'Skipped ASR URL credentials',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {
            'metadata': {'sourceUrl': credentialedUrl},
          },
        };
        final validSibling = BackgroundTask(
          id: 'valid-asr-sibling-next-to-url-credentials',
          type: BackgroundTaskType.asr,
          title: 'Valid ASR task',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        await file.writeAsString(jsonEncode([skippedAsrRow, validSibling]));

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(
            notifier.taskById('valid-asr-sibling-next-to-url-credentials'),
            isNotNull,
          );

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Task after partial restore',
            taskId: 'task-after-partial-asr-url-credentials',
          );
          await notifier.pendingPersistence;

          final persisted = await file.readAsString();
          expect(persisted, isNot(contains('alice:opaque-pass@')));
          expect(persisted, isNot(contains(credentialedUrl)));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'removing a restored task preserves skipped entries across restart',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'removed-task-with-partial-restore';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        final malformedSibling = <String, dynamic>{
          // No ID makes this a malformed task entry, but its retry snapshot
          // still owns the same image blob as the valid task below.
          'type': 'ocr',
          'title': 'Malformed OCR sibling',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [],
          'retryData': retryData,
        };
        final unrelatedTask = BackgroundTask(
          id: 'unrelated-valid-task',
          type: BackgroundTaskType.asr,
          title: 'Keep this task',
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 2),
        ).toMap();
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            BackgroundTask(
              id: taskId,
              type: BackgroundTaskType.ocr,
              title: 'Delete this task',
              status: TaskStatus.failed,
              createdAt: DateTime(2025, 1, 1),
              retryData: retryData,
            ).toMap(),
            malformedSibling,
            unrelatedTask,
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          expect(notifier.taskById(taskId), isNotNull);
          expect(notifier.taskById('unrelated-valid-task'), isNotNull);

          notifier.removeTask(taskId);
          await notifier.pendingPersistence;

          final persisted = jsonDecode(await file.readAsString()) as List;
          expect(
            persisted.whereType<Map>().any((task) => task['id'] == taskId),
            isFalse,
            reason: 'the confirmed deletion must be durable',
          );
          expect(
            persisted.whereType<Map>().singleWhere(
                  (task) => task['title'] == 'Malformed OCR sibling',
                ),
            malformedSibling,
            reason: 'the skipped task data must survive the rewrite',
          );
          expect(
            persisted.whereType<Map>().singleWhere(
                  (task) => task['id'] == 'unrelated-valid-task',
                ),
            unrelatedTask,
          );
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }

        final restarted = BackgroundTaskNotifier();
        try {
          await restarted.restoreFromPersistence();
          expect(restarted.taskById(taskId), isNull);
          expect(restarted.taskById('unrelated-valid-task'), isNotNull);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          restarted.dispose();
          await restarted.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'failed partial-restore deletion keeps task visible and disk unchanged',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'failed-partial-restore-removal';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalContent = jsonEncode([
          BackgroundTask(
            id: taskId,
            type: BackgroundTaskType.ocr,
            title: 'Keep task if save fails',
            status: TaskStatus.failed,
            retryData: retryData,
          ).toMap(),
          {
            'type': 'ocr',
            'title': 'Malformed OCR sibling',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': retryData,
          },
        ]);
        await file.writeAsString(originalContent);

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final originalSnapshot = await file.readAsBytes();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            throw StateError('simulated persistence failure');
          };

          notifier.removeTask(taskId);
          await notifier.pendingPersistence;

          expect(notifier.taskById(taskId), isNotNull);
          expect(await file.readAsBytes(), originalSnapshot);
          expect(await file.readAsString(), originalContent);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unsafe skipped legacy snapshot blocks removal and later task writes',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'partial-delete-with-legacy-skipped-row';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final currentRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((currentRetryData['images'] as List).single
            as Map)['storageRef'] as String;
        final legacyRetryData = <String, dynamic>{
          'type': 'ocr',
          'version': 1,
          'images': [
            {
              'bytes': base64Encode(imageBytes),
              'storageRef': cacheReference,
              'format': 'png',
            },
          ],
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalContent = jsonEncode([
          BackgroundTask(
            id: taskId,
            type: BackgroundTaskType.ocr,
            title: 'Known OCR task',
            status: TaskStatus.failed,
            retryData: currentRetryData,
          ).toMap(),
          {
            'type': 'ocr',
            'title': 'Malformed legacy OCR sibling',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': legacyRetryData,
          },
        ]);
        await file.writeAsString(originalContent);

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final task = notifier.taskById(taskId)!;
          final retryDataBefore = jsonEncode(task.retryData);
          var writeAttempts = 0;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            writeAttempts++;
          };

          final removed = await notifier.removeTasksPersisted([taskId]);

          expect(removed, isFalse);
          expect(notifier.taskById(taskId), isNotNull);
          expect(
            jsonEncode(notifier.taskById(taskId)!.retryData),
            retryDataBefore,
          );
          expect(writeAttempts, 0);
          expect(await file.readAsString(), originalContent);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);

          const newTaskId = 'task-blocked-by-unsafe-skipped-snapshot';
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Must not overwrite an unsafe partial snapshot',
            taskId: newTaskId,
          );
          await notifier.pendingPersistence;

          expect(notifier.taskById(newTaskId), isNotNull);
          expect(writeAttempts, 0);
          expect(await file.readAsString(), originalContent);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }

        final restarted = BackgroundTaskNotifier();
        try {
          await restarted.restoreFromPersistence();
          expect(restarted.taskById(taskId), isNotNull);
          expect(
            restarted.taskById('task-blocked-by-unsafe-skipped-snapshot'),
            isNull,
          );
          expect(await file.readAsString(), originalContent);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
        } finally {
          restarted.dispose();
          await restarted.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'partial deletion leaves unsupported retry data unchanged until durable',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'partial-delete-unsupported-retry';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final cachedRetry = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((cachedRetry['images'] as List).single
            as Map)['storageRef'] as String;
        final unsupportedRetryData = <String, dynamic>{
          'type': 'ocr',
          'version': 99,
          'modelRef': {'configId': 'saved-config', 'modelId': 'saved-model'},
          'instructionContent': 'keep this retry context',
          'images': [
            {'storageRef': cacheReference, 'format': 'png'},
          ],
        };
        final malformedRetryData = <String, dynamic>{
          'type': 'ocr',
          'version': OcrRetrySnapshot.currentVersion,
          'images': [
            {
              'storageRef': cacheReference,
              'format': ['png'],
              'name': 7,
            },
          ],
        };
        final skippedRow = <String, dynamic>{
          'type': 'ocr',
          'title': 'Malformed sibling',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 1).toIso8601String(),
          'steps': [],
          'retryData': malformedRetryData,
          'extensionData': {
            'preserve': [1, 'two', true],
          },
        };
        final taskRow = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.ocr,
          title: 'Keep unsupported retry until deletion saves',
          status: TaskStatus.failed,
          retryData: unsupportedRetryData,
        ).toMap();
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([taskRow, skippedRow]));
        final originalBytes = await file.readAsBytes();

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();

          final restoredTask = notifier.taskById(taskId)!;
          expect(
            restoredTask.retryData,
            unsupportedRetryData,
            reason: 'partial restore must not publish a transformed snapshot',
          );
          var writeAttempts = 0;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            writeAttempts++;
          };

          final removed = await notifier.removeTasksPersisted([taskId]);

          expect(removed, isFalse);
          expect(notifier.taskById(taskId)?.retryData, unsupportedRetryData);
          expect(notifier.taskById(taskId), isNotNull);
          expect(writeAttempts, 0);
          expect(await file.readAsBytes(), originalBytes);
          expect(await OcrRetryStorage.read(cacheReference), imageBytes);
          expect(
            OcrRetryStorage.referencesFromSnapshot(
              skippedRow['retryData'] as Map<String, dynamic>,
            ),
            contains(cacheReference),
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'migration preserves valid images when optional metadata has wrong types',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'malformed-optional-image-metadata';
        final inlineBytes = Uint8List.fromList([1, 2, 3, 4]);
        final seedBytes = Uint8List.fromList([9, 10, 11, 12]);
        final cachedBytes = Uint8List.fromList([5, 6, 7, 8]);
        final cachedSnapshot = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [
              OcrRetryImage(bytes: seedBytes, format: 'png'),
              OcrRetryImage(bytes: cachedBytes, format: 'png'),
            ],
          ),
        );
        final preservedReference = ((cachedSnapshot['images'] as List)[1]
            as Map)['storageRef'] as String;
        final retryData = {
          'type': 'ocr',
          'version': 1,
          'images': [
            {
              'bytes': base64Encode(inlineBytes),
              'format': 7,
              'name': {'invalid': 'type'},
            },
            {
              'storageRef': preservedReference,
              'format': ['png'],
              'name': 9,
            },
          ],
        };
        final taskFile = _tasksFileIn(testDir.path);
        await taskFile.parent.create(recursive: true);
        await taskFile.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'ocr',
              'title': 'legacy OCR retry',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': retryData,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          await notifier.pendingPersistence;

          final persistedRetry = notifier.state.single.retryData!;
          final snapshot = OcrRetrySnapshot.fromMap(persistedRetry);
          final restored = await OcrRetryStorage.restoreImages(snapshot);
          expect(persistedRetry['version'], OcrRetrySnapshot.currentVersion);
          expect(snapshot.hasInvalidImages, isFalse);
          expect(snapshot.hasInvalidImageMetadata, isFalse);
          expect(snapshot.needsMigration, isFalse);
          expect(snapshot.images, hasLength(2));
          expect(snapshot.images.first.format, '');
          expect(snapshot.images.first.name, isNull);
          expect(snapshot.images.last.storageRef, preservedReference);
          expect(snapshot.images.last.format, '');
          expect(snapshot.images.last.name, isNull);
          expect(restored.isComplete, isTrue);
          expect(restored.images.map((image) => image.bytes!.toList()), [
            inlineBytes.toList(),
            cachedBytes.toList(),
          ]);
          expect(await OcrRetryStorage.read(preservedReference), cachedBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unsupported OCR retry versions preserve the required image count without inline bodies',
      () async {
        final file = _tasksFileIn(testDir.path);
        final encodedImage = base64Encode(List<int>.filled(64 * 1024, 0x5a));
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'unsupported-retry',
              'type': 'ocr',
              'title': 'unsupported OCR retry',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': {
                'type': 'ocr',
                'version': 99,
                'modelRef': {
                  'configId': 'saved-config',
                  'modelId': 'saved-model',
                },
                'instructionContent': 'saved prompt',
                'images': [
                  {'bytes': encodedImage, 'format': 'png'},
                  {'bytes': encodedImage, 'format': 'png'},
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final restored = notifier.state.single;
          final retryData = restored.retryData;
          expect(retryData, isNotNull);
          expect(retryData!['version'], OcrRetrySnapshot.currentVersion);
          expect(retryData['modelRef'], {
            'configId': 'saved-config',
            'modelId': 'saved-model',
          });
          expect(retryData['instructionContent'], 'saved prompt');
          final images = (retryData['images'] as List).cast<Map>();
          expect(images, hasLength(2));
          expect(
            images.every(
              (image) =>
                  image['storageRef'] is String && !image.containsKey('bytes'),
            ),
            isTrue,
          );
          await notifier.pendingPersistence;
          final persisted = await file.readAsString();
          expect(persisted, isNot(contains(encodedImage)));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'startup migrates version 2 OCR retry snapshots missing type before cleanup',
      () async {
        WebFileStore.enableTestMode();
        final file = _tasksFileIn(testDir.path);
        const taskId = 'missing-type-cached-retry';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final cachedRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'saved-config',
            modelId: 'saved-model',
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference =
            ((cachedRetryData['images'] as List).single as Map)['storageRef'];
        final missingTypeRetryData = Map<String, dynamic>.from(cachedRetryData)
          ..remove('type');
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'ocr',
              'title': 'cached OCR retry missing type',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': missingTypeRetryData,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          await notifier.pendingPersistence;

          final retryData = notifier.state.single.retryData!;
          expect(
            await OcrRetryStorage.read(cacheReference as String),
            imageBytes,
          );
          expect(retryData['type'], 'ocr');
          expect(
            ((retryData['images'] as List).single as Map)['storageRef'],
            cacheReference,
          );
          final persisted = jsonDecode(await file.readAsString()) as List;
          final persistedRetry = (persisted.single
              as Map<String, dynamic>)['retryData'] as Map<String, dynamic>;
          expect(persistedRetry['type'], 'ocr');
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unsupported OCR retry versions cannot reuse readable cached images',
      () async {
        WebFileStore.enableTestMode();
        final file = _tasksFileIn(testDir.path);
        const taskId = 'unsupported-cached-retry';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final cachedRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'saved-config',
            modelId: 'saved-model',
            images: [
              OcrRetryImage(bytes: imageBytes, format: 'png', name: 'scan.png'),
            ],
            instructionContent: 'saved prompt',
          ),
        );
        final cachedReference =
            ((cachedRetryData['images'] as List).single as Map)['storageRef'];
        final unsupportedRetryData = <String, dynamic>{
          ...cachedRetryData,
          'version': 99,
        };
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'ocr',
              'title': 'unsupported cached OCR retry',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': unsupportedRetryData,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final retryData = notifier.state.single.retryData!;
          final snapshot = OcrRetrySnapshot.fromMap(retryData);
          final restored = await OcrRetryStorage.restoreImages(snapshot);

          expect(retryData['version'], OcrRetrySnapshot.currentVersion);
          expect(snapshot.imageEntryCount, 1);
          expect(snapshot.images, hasLength(1));
          expect(snapshot.images.single.storageRef, isNot(cachedReference));
          expect(restored.isComplete, isFalse);
          expect(restored.images, isEmpty);
          expect(restored.missingImageCount, 1);
          expect(await OcrRetryStorage.read(cachedReference as String), isNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unsupported OCR cache cleanup preserves a blob shared by another retry',
      () async {
        WebFileStore.enableTestMode();
        final file = _tasksFileIn(testDir.path);
        const unsupportedTaskId = 'unsupported-shared-cache-retry';
        const supportedTaskId = 'supported-shared-cache-retry';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final cachedRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: supportedTaskId,
          snapshot: OcrRetrySnapshot.capture(
            configId: 'saved-config',
            modelId: 'saved-model',
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cachedReference =
            ((cachedRetryData['images'] as List).single as Map)['storageRef'];
        final unsupportedRetryData = <String, dynamic>{
          ...cachedRetryData,
          'version': 99,
        };
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': unsupportedTaskId,
              'type': 'ocr',
              'title': 'unsupported shared cache',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': unsupportedRetryData,
            },
            {
              'id': supportedTaskId,
              'type': 'ocr',
              'title': 'supported shared cache',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [],
              'retryData': cachedRetryData,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final unsupportedSnapshot = OcrRetrySnapshot.fromMap(
            notifier.state
                .singleWhere((task) => task.id == unsupportedTaskId)
                .retryData!,
          );
          final supportedSnapshot = OcrRetrySnapshot.fromMap(
            notifier.state
                .singleWhere((task) => task.id == supportedTaskId)
                .retryData!,
          );

          expect(
            (await OcrRetryStorage.restoreImages(
              unsupportedSnapshot,
            ))
                .isComplete,
            isFalse,
          );
          expect(supportedSnapshot.images.single.storageRef, cachedReference);
          final restored = await OcrRetryStorage.restoreImages(
            supportedSnapshot,
          );
          expect(restored.isComplete, isTrue);
          expect(restored.images.single.bytes, imageBytes);
          expect(
            await OcrRetryStorage.read(cachedReference as String),
            imageBytes,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unsupported OCR snapshots discard ambiguous model and instruction indices',
      () async {
        final file = _tasksFileIn(testDir.path);
        final encodedImage = base64Encode(List<int>.filled(64, 0x5a));
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'unsupported-index-retry',
              'type': 'ocr',
              'title': 'unsupported OCR retry',
              'status': 'failed',
              'createdAt': DateTime(2025, 1, 1).toIso8601String(),
              'steps': [
                {'label': 'step', 'status': 'pending'},
              ],
              'retryData': {
                'type': 'ocr',
                'version': 99,
                'modelIndex': 0,
                'instructionIndex': 0,
                'images': [
                  {'bytes': encodedImage, 'format': 'png'},
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final restored = notifier.state.single;
          final snapshot = OcrRetrySnapshot.fromMap(restored.retryData!);

          expect(
            restored.retryData!['version'],
            OcrRetrySnapshot.currentVersion,
          );
          expect(snapshot.imageEntryCount, 1);
          expect(snapshot.legacyModelIndex, isNull);
          expect(snapshot.legacyInstructionIndex, isNull);

          notifier.updateStep('unsupported-index-retry', 0, completed: true);
          await notifier.pendingPersistence;
          final persisted = await file.readAsString();
          expect(persisted, isNot(contains(encodedImage)));
          expect(persisted, isNot(contains('modelIndex')));
          expect(persisted, isNot(contains('instructionIndex')));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'startup removes OCR cache orphaned by an interrupted task removal',
      () async {
        WebFileStore.enableTestMode();
        const taskId = 'removed-task-cache-orphan';
        final imageBytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: taskId,
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cachedReference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        // The task-list replacement completed, but the process stopped before
        // its cache-reference deletion could run.
        await file.writeAsString('[]');

        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();

          expect(notifier.state, isEmpty);
          expect(await OcrRetryStorage.read(cachedReference), isNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'startup preserves referenced cache until transformed tasks are saved',
      () async {
        WebFileStore.enableTestMode();
        const unsupportedTaskId = 'unsupported-unsaved-cache-task';
        const supportedTaskId = 'supported-cache-task';
        const orphanTaskId = 'unreferenced-cache-task';
        final unsupportedBytes = Uint8List.fromList([1, 2, 3, 4]);
        final supportedBytes = Uint8List.fromList([5, 6, 7, 8]);
        final orphanBytes = Uint8List.fromList([9, 10, 11, 12]);

        Future<(Map<String, dynamic>, String)> cache(
          String taskId,
          Uint8List bytes,
        ) async {
          final data = await OcrRetryStorage.cacheSnapshot(
            taskId: taskId,
            snapshot: OcrRetrySnapshot.capture(
              images: [OcrRetryImage(bytes: bytes, format: 'png')],
            ),
          );
          final reference = (data['images'] as List).single as Map;
          return (data, reference['storageRef'] as String);
        }

        final (unsupportedData, unsupportedReference) = await cache(
          unsupportedTaskId,
          unsupportedBytes,
        );
        final (supportedData, supportedReference) = await cache(
          supportedTaskId,
          supportedBytes,
        );
        final (_, orphanReference) = await cache(orphanTaskId, orphanBytes);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          {
            'id': unsupportedTaskId,
            'type': 'ocr',
            'title': 'unsupported OCR task',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': {...unsupportedData, 'version': 99},
          },
          {
            'id': supportedTaskId,
            'type': 'ocr',
            'title': 'supported OCR task',
            'status': 'failed',
            'createdAt': DateTime(2025, 1, 1).toIso8601String(),
            'steps': [],
            'retryData': supportedData,
          },
        ]);
        await file.writeAsString(originalSnapshot);

        final notifier = BackgroundTaskNotifier();
        try {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            throw FileSystemException('simulated task snapshot write failure');
          };
          await notifier.restoreFromPersistence();

          expect(await file.readAsString(), originalSnapshot);
          expect(
            await OcrRetryStorage.read(unsupportedReference),
            unsupportedBytes,
          );
          expect(
            await OcrRetryStorage.read(supportedReference),
            supportedBytes,
          );
          expect(await OcrRetryStorage.read(orphanReference), orphanBytes);

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await notifier.restoreFromPersistence();

          expect(await OcrRetryStorage.read(unsupportedReference), isNull);
          expect(await OcrRetryStorage.read(orphanReference), isNull);
          expect(
            await OcrRetryStorage.read(supportedReference),
            supportedBytes,
          );
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test('startup cleanup waits for new OCR cache task publication', () async {
      WebFileStore.enableTestMode();
      final cleanupEntered = Completer<void>();
      final resumeCleanup = Completer<void>();
      BackgroundTaskNotifier.debugBeforeOcrCacheCleanup = () async {
        if (!cleanupEntered.isCompleted) cleanupEntered.complete();
        await resumeCleanup.future;
      };
      final notifier = BackgroundTaskNotifier();
      Future<void>? restore;
      Future<Map<String, dynamic>>? publication;
      String? cachedReference;
      var publishedBeforeCleanup = false;
      try {
        restore = notifier.restoreFromPersistence();
        await cleanupEntered.future;

        final imageBytes = Uint8List.fromList([7, 8, 9]);
        publication = OcrRetryStorage.withCacheMaintenanceLock(() async {
          final retryData = await OcrRetryStorage.cacheSnapshot(
            taskId: 'startup-cache-publication-race',
            snapshot: OcrRetrySnapshot.capture(
              images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
            ),
          );
          cachedReference = ((retryData['images'] as List).single
              as Map)['storageRef'] as String;
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'startup cache publication',
            retryData: retryData,
            taskId: 'startup-cache-publication-race',
          );
          return retryData;
        });
        publishedBeforeCleanup = await Future.any([
          publication.then((_) => true),
          Future<bool>.delayed(const Duration(seconds: 1), () => false),
        ]);

        resumeCleanup.complete();
        await restore;
        await publication;

        expect(publishedBeforeCleanup, isFalse);
        expect(
          await OcrRetryStorage.read(cachedReference!),
          orderedEquals(imageBytes),
        );
      } finally {
        if (!resumeCleanup.isCompleted) resumeCleanup.complete();
        if (restore != null) await restore;
        if (publication != null) await publication;
        notifier.dispose();
        await notifier.pendingPersistence;
        WebFileStore.disableTestMode();
      }
    });

    test(
      'removeTask cleans a blob published by queued legacy migration',
      () async {
        WebFileStore.enableTestMode();
        final cacheWriteEntered = Completer<void>();
        final resumeCacheWrite = Completer<void>();
        final bytes = Uint8List.fromList([11, 12, 13, 14]);
        String? cacheReference;
        OcrRetryStorage.debugBeforeCacheWrite = (reference, _) async {
          cacheReference = reference;
          if (!cacheWriteEntered.isCompleted) cacheWriteEntered.complete();
          await resumeCacheWrite.future;
        };
        final notifier = BackgroundTaskNotifier();
        try {
          final taskId = notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'legacy retry removed during migration',
            taskId: 'legacy-remove-during-cache-migration',
            retryData: {
              'type': 'ocr',
              'version': 1,
              'images': [
                {'bytes': base64Encode(bytes), 'format': 'png'},
              ],
            },
          );
          await cacheWriteEntered.future;

          notifier.removeTask(taskId);
          expect(notifier.state, isEmpty);
          resumeCacheWrite.complete();
          await notifier.pendingPersistence;

          expect(await _readFileIfExists(_tasksFileIn(testDir.path)), '[]');
          expect(cacheReference, isNotNull);
          expect(
            await OcrRetryStorage.read(cacheReference!),
            isNull,
            reason: 'the cache blob published during migration is now orphaned',
          );
        } finally {
          if (!resumeCacheWrite.isCompleted) resumeCacheWrite.complete();
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'partial restore never rewrites records that may own retry audio',
      () async {
        const audioId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final original = jsonEncode([
          {
            'id': 'valid-asr-task',
            'type': 'asr',
            'title': 'retry task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'audioReference': {'id': audioId},
            },
          },
          'corrupt task entry',
        ]);
        await file.writeAsString(original);
        final audioFile = File(
          p.join(testDir.path, 'background', 'asr_retry', '$audioId.audio'),
        )..createSync(recursive: true);
        await audioFile.writeAsBytes([1, 2, 3]);

        final firstRestore = BackgroundTaskNotifier();
        expect(await firstRestore.restoreFromPersistence(), isFalse);
        expect(firstRestore.retryAudioCleanupSafe, isFalse);
        await firstRestore.pendingPersistence;
        expect(await file.readAsString(), original);

        final secondRestore = BackgroundTaskNotifier();
        expect(await secondRestore.restoreFromPersistence(), isFalse);
        await secondRestore.pendingPersistence;

        expect(await file.readAsString(), original);
        expect(await audioFile.exists(), isTrue);
      },
    );

    test(
      'pre-restore snapshot writes preserve unrestored ownership markers',
      () async {
        const audioId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            BackgroundTask(
              id: 'pre-restore-known-task',
              type: BackgroundTaskType.ocr,
              title: 'Known task',
              status: TaskStatus.waiting,
              createdAt: DateTime.utc(2026),
            ).toMap(),
            {
              '_unrestoredTaskRecord': true,
              'retryAudioOwnershipKnown': false,
              'retryAudioIds': [audioId],
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        final secondStartup = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Added before restore',
            startImmediately: false,
            taskId: 'pre-restore-added-task',
          );
          await notifier.pendingPersistence;

          final persisted = jsonDecode(await file.readAsString()) as List;
          expect(
            persisted.whereType<Map>().any(
                  (row) => row['_unrestoredTaskRecord'] == true,
                ),
            isTrue,
          );

          expect(await secondStartup.restoreFromPersistence(), isFalse);
          expect(secondStartup.retryAudioCleanupSafe, isFalse);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          secondStartup.dispose();
          await secondStartup.pendingPersistence;
        }
      },
    );

    test(
      'versioned ASR persistence sanitizes task-level diagnostics',
      () async {
        const apiKey = 'sk-versioned-asr-task-level-secret-123456';
        const audioId = 'cccccccccccccccccccccccccccccccc';
        const audioSha256 =
            '0000000000000000000000000000000000000000000000000000000000000000';
        final audioReference = AsrAudioReference(
          id: audioId,
          name: 'source.wav',
          format: 'wav',
          byteLength: 0,
          sha256: audioSha256,
          requiresSourceReselection: true,
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'versioned-asr-with-task-level-secret',
              'type': 'asr',
              'title': 'ASR task with diagnostics',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'error': 'Transcription failed: Bearer $apiKey',
              'steps': [
                {
                  'label': 'Transcribe',
                  'status': 'failed',
                  'error': 'Authorization: Bearer $apiKey',
                },
              ],
              'rawRequest': {
                'headers': {'Authorization': 'Bearer $apiKey'},
                'body': {'api_key': apiKey},
              },
              'rawResponse': {
                'data': {'message': 'Bearer $apiKey'},
              },
              'retryData': {
                'type': 'asr',
                'version': 2,
                'audioReference': audioReference.toMap(),
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final asrRow = (jsonDecode(serialized) as List)
              .whereType<Map>()
              .singleWhere(
                  (row) => row['id'] == 'versioned-asr-with-task-level-secret');
          expect(asrRow['rawRequest'], isNull);
          expect(asrRow['rawResponse'], isNull);
          expect(asrRow['error'], isNot(contains(apiKey)));
          final steps = asrRow['steps'] as List;
          expect(steps.single['error'], isNot(contains(apiKey)));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'unsafe in-memory legacy ASR retry data cannot overwrite the task snapshot',
      () async {
        const apiKey = 'legacy-asr-api-key-should-not-reach-disk';
        final encodedAudio = base64Encode(List<int>.filled(64, 0x5a));
        final notifier = BackgroundTaskNotifier();
        try {
          final taskId = notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Existing ASR task',
            startImmediately: false,
          );
          await notifier.pendingPersistence;
          final file = _tasksFileIn(testDir.path);
          final originalSnapshot = await file.readAsString();

          notifier.setRetryData(taskId, {
            'audios': [
              {'bytes': encodedAudio, 'format': 'wav'},
            ],
            'apiKey': apiKey,
          });
          await notifier.pendingPersistence;

          expect(await file.readAsString(), originalSnapshot);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'unsafe legacy retry data is omitted without blocking safe task snapshots',
      () async {
        const apiKey = 'legacy-asr-api-key-should-not-reach-disk';
        final encodedAudio = base64Encode(List<int>.filled(64, 0x5a));
        final notifier = BackgroundTaskNotifier();
        try {
          final taskId = notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'In-memory legacy task',
            startImmediately: false,
          );
          await notifier.pendingPersistence;
          notifier.setRetryData(taskId, {
            'audios': [
              {'bytes': encodedAudio, 'format': 'wav'},
            ],
            'apiKey': apiKey,
          });
          await notifier.pendingPersistence;

          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Safe snapshot trigger',
            startImmediately: false,
          );
          await notifier.pendingPersistence;

          final serialized = await _tasksFileIn(testDir.path).readAsString();
          expect(serialized, isNot(contains(encodedAudio)));
          expect(serialized, isNot(contains(apiKey)));
          final rows = (jsonDecode(serialized) as List).cast<Map>();
          expect(rows, hasLength(2));
          final persistedAsr = rows.singleWhere((row) => row['id'] == taskId);
          expect(persistedAsr, isNot(contains('retryData')));
          expect(
            notifier.taskById(taskId)!.retryData!['apiKey'],
            apiKey,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'skipped legacy ASR rows do not preserve credential-named values',
      () async {
        const opaqueCredential = 'opaque123value';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            for (final field in [
              'key',
              'apiKeys',
              'privateKey',
              'clientSecret',
              'accessToken',
              'bearer',
              'auth',
              'API Key',
            ])
              {
                'type': 'asr',
                'title': 'Malformed legacy ASR row',
                'status': 'failed',
                'createdAt': DateTime.utc(2026).toIso8601String(),
                field: opaqueCredential,
              },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'legacy-credential-filter-write',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(opaqueCredential)));
          expect(serialized, contains('legacy-credential-filter-write'));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'skipped legacy ASR rows do not preserve numeric credential values',
      () async {
        const numericCredential = 172839;
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'asr',
              'title': 'Malformed legacy ASR row',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'API Key': numericCredential,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'legacy-numeric-credential-filter-write',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(numericCredential.toString())));
          expect(
              serialized, contains('legacy-numeric-credential-filter-write'));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'restore retires rejected ASR row ownership after sanitization is durable',
      () async {
        const apiKey = 'opaque-startup-asr-key-789';
        const audioId = 'abababababababababababababababab';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'valid-task-next-to-rejected-asr',
              'type': 'ocr',
              'title': 'Valid task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
            },
            {
              'type': 'asr',
              'title': 'Malformed legacy ASR row',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': audioId,
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'd' * 64,
                },
                'API Key': apiKey,
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(
              notifier.taskById('valid-task-next-to-rejected-asr'), isNotNull);
          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          expect(
            (jsonDecode(serialized) as List).whereType<Map>().where(
                  (row) => row['_unrestoredTaskRecord'] == true,
                ),
            isEmpty,
          );
          expect(notifier.retryAudioReferencedIds, isNot(contains(audioId)));
          expect(notifier.retryAudioCleanupSafe, isTrue);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'restore retires rejected ASR ownership when no task rows parse',
      () async {
        const apiKey = 'opaque-empty-startup-asr-key-456';
        const audioId = 'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'asr',
              'title': 'Malformed legacy ASR row',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': audioId,
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'd' * 64,
                },
                'API Key': apiKey,
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final rows = jsonDecode(serialized) as List;
          expect(
            rows.whereType<Map>().where(
                  (row) => row['_unrestoredTaskRecord'] == true,
                ),
            isEmpty,
          );
          expect(notifier.retryAudioReferencedIds, isEmpty);
          expect(notifier.retryAudioCleanupSafe, isTrue);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'restore scrubs credentials from parsed ASR rows with invalid versioned audio',
      () async {
        const apiKey = 'opaque-parsed-asr-key-812';
        const taskId = 'parsed-asr-invalid-audio-reference';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'asr',
              'title': 'ASR retry with invalid reference',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'API Key': apiKey,
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final rows = jsonDecode(serialized) as List;
          final asrRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == taskId,
              );
          expect(asrRow.containsKey('retryData'), isFalse);
          expect(
            rows.whereType<Map>().where(
                  (row) => row['_unrestoredTaskRecord'] == true,
                ),
            isEmpty,
          );
          expect(notifier.retryAudioCleanupSafe, isTrue);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'restore drops invalid v2 ownership before future writes',
      () async {
        const taskId = 'parsed-asr-invalid-safe-reference';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'asr',
              'title': 'ASR retry with structurally invalid reference',
              'status': 'running',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': 'broken-id',
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'e' * 64,
                },
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.taskById(taskId)?.status, TaskStatus.failed);
          await notifier.pendingPersistence;

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Task added after invalid retry restore',
            startImmediately: false,
            taskId: 'task-after-invalid-asr-reference',
          );
          await notifier.pendingPersistence;

          final rows = jsonDecode(await file.readAsString()) as List;
          final restoredRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == taskId,
              );
          expect(restoredRow.containsKey('retryData'), isFalse);
          expect(restoredRow['status'], TaskStatus.failed.name);
          expect(
            rows.whereType<Map>().any(
                  (row) => row['id'] == 'task-after-invalid-asr-reference',
                ),
            isTrue,
            reason: 'invalid retry metadata must not block later task writes',
          );
          expect(
            rows.whereType<Map>().where(
                  (row) => row['_unrestoredTaskRecord'] == true,
                ),
            isEmpty,
          );
          expect(notifier.retryAudioCleanupSafe, isTrue);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'restore scrubs credentials nested in an invalid versioned audio reference',
      () async {
        const apiKey = 'opaque-nested-reference-asr-key-614';
        const taskId = 'parsed-asr-invalid-reference-with-key';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'asr',
              'title': 'ASR retry with invalid reference',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': 'invalid-audio-id',
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'e' * 64,
                  'API Key': apiKey,
                },
              },
            },
            {'id': 'future-task', 'type': 'future-task', 'title': 'Unknown'},
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final rows = jsonDecode(serialized) as List;
          final asrRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == taskId,
              );
          expect(asrRow.containsKey('retryData'), isFalse);
          expect(
            rows.whereType<Map>().any(
                  (row) =>
                      row['_unrestoredTaskRecord'] == true &&
                      row['retryAudioOwnershipKnown'] == false,
                ),
            isTrue,
          );
          expect(notifier.retryAudioCleanupSafe, isFalse);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'partial restore scrubs credentials from parsed ASR rows with valid audio',
      () async {
        const apiKey = 'opaque-partial-parsed-asr-key-913';
        const taskId = 'parsed-asr-valid-audio-reference';
        const audioId = 'efefefefefefefefefefefefefefefef';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'asr',
              'title': 'ASR retry with valid reference',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': audioId,
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'e' * 64,
                },
                'API Key': apiKey,
              },
            },
            {'id': 'future-task', 'type': 'future-task', 'title': 'Unknown'},
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final rows = jsonDecode(serialized) as List;
          final asrRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == taskId,
              );
          final audioReference =
              ((asrRow['retryData'] as Map)['audioReference'] as Map);
          expect(audioReference['id'], audioId);
          expect(
            rows.whereType<Map>().any(
                  (row) => row['_unrestoredTaskRecord'] == true,
                ),
            isTrue,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'partial restore scrubs credentials from parsed ASR request diagnostics',
      () async {
        const apiKey = 'opaque-asr-request-diagnostic-key-417';
        const taskId = 'parsed-asr-request-diagnostic-key';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': taskId,
              'type': 'asr',
              'title': 'ASR task with request diagnostics',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'rawRequest': {
                'headers': {'Authorization': 'Bearer $apiKey'},
              },
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': 'abababababababababababababababab',
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'e' * 64,
                },
              },
            },
            {'id': 'future-task', 'type': 'future-task', 'title': 'Unknown'},
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final rows = jsonDecode(serialized) as List;
          final asrRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == taskId,
              );
          expect(asrRow.containsKey('rawRequest'), isFalse);
          expect(
            (asrRow['retryData'] as Map)['audioReference']['id'],
            'abababababababababababababababab',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'partial restore normalizes credentials out of unrestored task markers',
      () async {
        const apiKey = 'opaque-unrestored-marker-key-608';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              '_unrestoredTaskRecord': true,
              'retryAudioOwnershipKnown': false,
              'retryAudioIds': <String>[],
              'apiKey': apiKey,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final marker = (jsonDecode(serialized) as List).single as Map;
          expect(marker.keys, contains('_unrestoredTaskRecord'));
          expect(marker.containsKey('apiKey'), isFalse);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'safe skipped legacy ASR rows preserve Base64-alphabet titles',
      () async {
        const title = 'pending-transcription-1';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'asr',
              'title': title,
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'legacy-safe-title-preservation',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, contains(title));
          expect(serialized, contains('legacy-safe-title-preservation'));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'skipped legacy ASR rows do not preserve short audio payloads',
      () async {
        const payload = 'YQ==';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'asr',
              'title': 'Malformed legacy ASR row',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {'audio': payload},
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'legacy-short-audio-filter-write',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(payload)));
          expect(serialized, contains('legacy-short-audio-filter-write'));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'skipped legacy ASR rows do not preserve short Base64 metadata',
      () async {
        final payload = base64Encode(List<int>.filled(16, 0x5a));
        expect(payload.length, lessThan(32));
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'asr',
              'title': 'Malformed legacy ASR row',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {'metadata': payload},
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'legacy-short-base64-filter-write',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(payload)));
          expect(serialized, contains('legacy-short-base64-filter-write'));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'skipped legacy ASR rows do not preserve line-wrapped Base64 metadata',
      () async {
        final payload = base64Encode(List<int>.filled(65, 0x5a));
        final wrappedPayload = payload
            .split('')
            .asMap()
            .entries
            .fold<StringBuffer>(StringBuffer(), (buffer, entry) {
          buffer.write(entry.value);
          if ((entry.key + 1) % 16 == 0) buffer.write('\n');
          return buffer;
        }).toString();
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'type': 'asr',
              'title': 'Malformed legacy ASR row',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'metadata': wrappedPayload,
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'legacy-base64-filter-write',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          final persistedRows = jsonDecode(serialized) as List;
          expect(
            persistedRows.whereType<Map>().any((row) {
              final metadata = row['metadata'];
              return metadata is String &&
                  metadata.replaceAll(RegExp(r'\s+'), '') == payload;
            }),
            isFalse,
          );
          expect(serialized, contains('legacy-base64-filter-write'));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'unknown ASR checkpoint statuses become uncertain before later snapshots',
      () async {
        const apiKey = 'opaque-unknown-status-asr-key';
        const audioId = 'dddddddddddddddddddddddddddddddd';
        const audioSha256 =
            '0000000000000000000000000000000000000000000000000000000000000000';
        final audioReference = AsrAudioReference(
          id: audioId,
          name: 'source.wav',
          format: 'wav',
          byteLength: 0,
          sha256: audioSha256,
          requiresSourceReselection: true,
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'versioned-asr-with-unknown-chunk-status',
              'type': 'asr',
              'title': 'Versioned ASR task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'rawRequest': {
                'headers': {'Authorization': 'Bearer $apiKey'},
              },
              'retryData': {
                'type': 'asr',
                'version': 2,
                'audioReference': audioReference.toMap(),
                'chunks': [
                  {
                    'index': 0,
                    'startSeconds': 0,
                    'endSeconds': 1,
                    'status': 'future-status',
                    'text': 'must be retried',
                  },
                ],
                'apiKey': apiKey,
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger pre-restore snapshot',
            startImmediately: false,
            taskId: 'unknown-status-snapshot-write',
          );
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          final rows = jsonDecode(serialized) as List;
          expect(
            rows.whereType<Map>().any(
                  (row) => row['id'] == 'unknown-status-snapshot-write',
                ),
            isTrue,
          );
          final asrRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == 'versioned-asr-with-unknown-chunk-status',
              );
          final retryData = asrRow['retryData'] as Map;
          expect(retryData.containsKey('apiKey'), isFalse);
          expect(
            ((retryData['chunks'] as List).single as Map)['status'],
            'uncertain',
            reason: 'unknown provider outcomes must remain non-retryable',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'legacy ASR rows migrate when an unrelated malformed row is skipped',
      () async {
        WebFileStore.enableTestMode();
        const apiKey = 'opaque-mixed-restore-legacy-asr-key-432';
        const taskId = 'legacy-asr-next-to-malformed-ocr';
        final audioBytes = Uint8List.fromList(List<int>.generate(48, (i) => i));
        final encodedAudio = base64Encode(audioBytes);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'malformed-unrelated-ocr',
              'type': 'ocr',
              'title': 'Malformed unrelated OCR task',
              'status': 'not-a-task-status',
              'createdAt': DateTime.utc(2026).toIso8601String(),
            },
            {
              'id': taskId,
              'type': 'asr',
              'title': 'Legacy ASR beside malformed OCR',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'rawRequest': {
                'headers': {'Authorization': 'Bearer $apiKey'},
              },
              'retryData': {
                'audios': [
                  {
                    'bytes': encodedAudio,
                    'name': 'legacy.wav',
                    'format': 'wav'
                  },
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          var serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          expect(serialized, isNot(contains(encodedAudio)));
          var rows = jsonDecode(serialized) as List;
          final asrRow = rows.whereType<Map>().singleWhere(
                (row) => row['id'] == taskId,
              );
          expect(asrRow['rawRequest'], isNull);
          final retryData = asrRow['retryData'] as Map;
          expect(retryData['version'], 2);
          final references = retryData['audioReferences'] as List;
          final reference = AsrAudioReference.fromMap(
            Map<String, dynamic>.from(
              (references.single as Map)['audioReference'] as Map,
            ),
          );
          expect(await AsrRetryAudioStore().load(reference), audioBytes);
          expect(
            rows.whereType<Map>().any(
                  (row) => row['id'] == 'malformed-unrelated-ocr',
                ),
            isTrue,
            reason: 'the unrelated malformed row must remain preserved',
          );

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Task added after partial migration',
            startImmediately: false,
            taskId: 'task-added-after-partial-legacy-migration',
          );
          await notifier.pendingPersistence;
          serialized = await file.readAsString();
          rows = jsonDecode(serialized) as List;
          expect(
            rows.whereType<Map>().any(
                  (row) =>
                      row['id'] == 'task-added-after-partial-legacy-migration',
                ),
            isTrue,
          );
          expect(serialized, isNot(contains(apiKey)));
          expect(serialized, isNot(contains(encodedAudio)));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'restoring legacy ASR audio migrates bytes and drops legacy diagnostics',
      () async {
        WebFileStore.enableTestMode();
        const apiKey = 'opaque-legacy-asr-diagnostic-key-123';
        final audioBytes = Uint8List(48);
        final encodedAudio = base64Encode(audioBytes);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'legacy-asr-inline-audio',
              'type': 'asr',
              'title': 'legacy ASR task',
              'status': 'running',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'error': 'request failed with $apiKey',
              'rawRequest': {
                'headers': {'Authorization': 'Bearer $apiKey'},
              },
              'rawResponse': {
                'data': {'message': apiKey},
              },
              'retryData': {
                'audios': [
                  {
                    'bytes': encodedAudio,
                    'name': 'legacy.wav',
                    'format': 'wav',
                  },
                ],
                'modelIndex': 0,
                'saveFolder': 'transcripts',
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(encodedAudio)));
          expect(serialized, isNot(contains(apiKey)));
          final row = (jsonDecode(serialized) as List).single as Map;
          expect(row['rawRequest'], isNull);
          expect(row['rawResponse'], isNull);
          expect(row['error'], '应用重启，已中断');
          final retryData = row['retryData'] as Map;
          expect(retryData['version'], 2);
          expect(retryData.containsKey('modelReference'), isFalse);
          expect(retryData.containsKey('audios'), isFalse);
          final references = retryData['audioReferences'] as List;
          final reference = AsrAudioReference.fromMap(
            Map<String, dynamic>.from(
              (references.single as Map)['audioReference'] as Map,
            ),
          );
          expect(
            await AsrRetryAudioStore().load(reference),
            orderedEquals(audioBytes),
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'versionless ASR audio references survive retry-data migration',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final audioBytes = Uint8List.fromList(List<int>.generate(48, (i) => i));
        final reference = await store.save(
          audioBytes,
          name: 'already-stored.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);

        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'versionless-asr-reference',
              'type': 'asr',
              'title': 'Versionless ASR reference',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'audioReferences': [
                  {
                    'audioReference': reference.toMap(),
                    'chunks': const <dynamic>[],
                  },
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          final retryData =
              notifier.taskById('versionless-asr-reference')!.retryData!;
          expect(retryData['version'], 2);
          final migratedReferences = retryData['audioReferences'] as List;
          final migratedReference = AsrAudioReference.fromMap(
            Map<String, dynamic>.from(
              (migratedReferences.single as Map)['audioReference'] as Map,
            ),
          );
          expect(migratedReference.id, reference.id);
          expect(await store.load(migratedReference), audioBytes);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'versionless ASR references with unknown chunk statuses stay owned',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final audioBytes = Uint8List.fromList(List<int>.generate(48, (i) => i));
        final reference = await store.save(
          audioBytes,
          name: 'versionless-unknown-status.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);

        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'versionless-asr-unknown-chunk-status',
              'type': 'asr',
              'title': 'Versionless ASR reference with unknown chunk status',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'audioReferences': [
                  {
                    'audioReference': reference.toMap(),
                    'chunks': [
                      {
                        'index': 0,
                        'startSeconds': 0,
                        'endSeconds': 1,
                        'status': 'future-status',
                        'text': 'must remain unresolved',
                      },
                    ],
                  },
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          final migratedRetryData = notifier
              .taskById('versionless-asr-unknown-chunk-status')!
              .retryData!;
          expect(migratedRetryData['version'], 2);
          final migratedReferences =
              migratedRetryData['audioReferences'] as List;
          final migratedEntry = migratedReferences.single as Map;
          final migratedReference = AsrAudioReference.fromMap(
            Map<String, dynamic>.from(migratedEntry['audioReference'] as Map),
          );
          expect(migratedReference.id, reference.id);
          expect(
            ((migratedEntry['chunks'] as List).single as Map)['status'],
            'uncertain',
          );
          expect(notifier.retryAudioReferencedIds, contains(reference.id));
          expect(await store.load(migratedReference), audioBytes);

          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(reference), isNotNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'failed later ASR migration retains references in the loaded snapshot',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final audioBytes = Uint8List.fromList(List<int>.generate(48, (i) => i));
        final reference = await store.save(
          audioBytes,
          name: 'legacy-asr-rollback.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);

        const failedTaskId = 'legacy-asr-later-migration-failure';
        final originalContent = jsonEncode([
          {
            'id': 'legacy-asr-existing-reference',
            'type': 'asr',
            'title': 'Legacy ASR task with an existing audio reference',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'audioReferences': [
                {
                  'audioReference': reference.toMap(),
                  'chunks': const <dynamic>[],
                },
              ],
            },
          },
          {
            'id': failedTaskId,
            'type': 'asr',
            'title': 'Later legacy ASR task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {'audios': const <dynamic>[]},
          },
        ]);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(originalContent);

        // ignore: invalid_use_of_visible_for_testing_member
        BackgroundTaskNotifier.debugBeforeLegacyAsrRetryMigration =
            (taskId) async {
          if (taskId == failedTaskId) {
            throw StateError('simulated later legacy ASR migration failure');
          }
        };
        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          await notifier.pendingPersistence;

          expect(await file.readAsString(), originalContent);
          expect(
            await store.load(reference),
            audioBytes,
            reason:
                'rollback must retain audio still named by the authoritative snapshot',
          );
        } finally {
          // ignore: invalid_use_of_visible_for_testing_member
          BackgroundTaskNotifier.debugBeforeLegacyAsrRetryMigration = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'legacy ASR audio with missing bytes migrates to a non-playable reselection marker',
      () async {
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'legacy-asr-missing-audio',
              'type': 'asr',
              'title': 'legacy ASR task with missing audio',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'audios': [
                  {'bytes': '%%%not-base64%%%', 'format': 'wav'},
                ],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          final persisted = jsonDecode(await file.readAsString()) as List;
          final retryData = ((persisted.single as Map)['retryData'] as Map);
          expect(retryData['version'], 2);
          expect(retryData.containsKey('audios'), isFalse);
          final audioReference = Map<String, dynamic>.from(
            ((retryData['audioReferences'] as List).single
                as Map)['audioReference'] as Map,
          );
          expect(audioReference['byteLength'], 0);
          expect(audioReference['requiresSourceReselection'], isTrue);
          final reference = AsrAudioReference.fromMap(audioReference);
          await expectLater(
            AsrRetryAudioStore().load(reference),
            throwsA(isA<AsrRetryAudioUnavailableException>()),
          );
          await expectLater(
            AsrRetryAudioStore().deleteIfUnreferenced(reference, const {}),
            completes,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'versioned ASR restore removes unrecognized retry fields',
      () async {
        const apiKey = 'opaque-versioned-asr-extra-key-123';
        const filenameSecret = 'opaqueSecret98765';
        final inlineAudio = base64Encode(Uint8List(48));
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'versioned-asr-with-extra-fields',
              'type': 'asr',
              'title': 'versioned ASR task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'type': 'asr',
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': 'a' * 32,
                  'name': 'api_key-$filenameSecret.wav',
                  'format': 'wav',
                  'byteLength': 48,
                  'sha256': 'b' * 64,
                },
                'modelReference': {
                  'configId': 'provider',
                  'modelId': 'whisper-1',
                },
                'configSnapshot': {
                  'host': 'https://api.example.test',
                  'model': 'whisper-1',
                  'typeConfig': {'apiKey': apiKey},
                },
                'chunks': const <dynamic>[],
                'saveFolder': 'transcripts',
                'apiKey': apiKey,
                'audios': [
                  {'bytes': inlineAudio, 'format': 'wav'},
                ],
              },
            },
            {
              'id': 'versioned-multi-asr-with-extra-fields',
              'type': 'asr',
              'title': 'versioned multi-audio task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'type': 'asr',
                'version': 2,
                'audioReferences': [
                  {
                    'audioReference': {
                      'version': 1,
                      'id': 'c' * 32,
                      'name': 'second.wav',
                      'format': 'wav',
                      'byteLength': 48,
                      'sha256': 'd' * 64,
                    },
                    'chunks': [
                      {
                        'index': 0,
                        'startSeconds': 0,
                        'endSeconds': 1,
                        'status': 'succeeded',
                        'text': 'recognized words',
                        'apiKey': apiKey,
                      },
                    ],
                    'apiKey': apiKey,
                    'audio': inlineAudio,
                  },
                ],
                'modelReference': {
                  'configId': 'provider',
                  'modelId': 'whisper-1',
                },
                'apiKey': apiKey,
                'audio': inlineAudio,
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          final serialized = await file.readAsString();
          expect(serialized, isNot(contains(apiKey)));
          expect(serialized, isNot(contains(filenameSecret)));
          expect(serialized, isNot(contains(inlineAudio)));
          final rows = jsonDecode(serialized) as List;
          expect(rows, hasLength(2));
          final retryData = (rows.first as Map)['retryData'] as Map;
          expect(retryData.containsKey('apiKey'), isFalse);
          expect(retryData.containsKey('audios'), isFalse);
          expect(
            (retryData['configSnapshot'] as Map).containsKey('typeConfig'),
            isTrue,
          );
          expect(
            ((retryData['configSnapshot'] as Map)['typeConfig'] as Map)
                .containsKey('apiKey'),
            isFalse,
          );
          final audioReference = retryData['audioReference'] as Map;
          expect(audioReference['name'], 'audio.wav');

          final multiAudioRetryData = (rows.last as Map)['retryData'] as Map;
          expect(multiAudioRetryData.containsKey('apiKey'), isFalse);
          expect(multiAudioRetryData.containsKey('audio'), isFalse);
          final references = multiAudioRetryData['audioReferences'] as List;
          final reference = references.single as Map;
          expect(reference.keys.toSet(), {'audioReference', 'chunks'});
          expect(
            ((reference['chunks'] as List).single as Map).containsKey(
              'apiKey',
            ),
            isFalse,
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );

    test(
      'later writes retain cleanup safety after a partial restore',
      () async {
        const audioId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'valid-task',
              'type': 'ocr',
              'title': 'valid task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
            },
            {
              'id': 'skipped-asr-task',
              'type': 'unknown-asr-type',
              'title': 'unrestored retry task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'version': 2,
                'audioReference': {
                  'version': 1,
                  'id': audioId,
                  'name': 'retry.wav',
                  'format': 'wav',
                  'byteLength': 3,
                  'sha256': 'd' * 64,
                },
                'apiKey': 'opaque-skipped-task-key',
              },
            },
          ]),
        );

        final firstRestore = BackgroundTaskNotifier();
        expect(await firstRestore.restoreFromPersistence(), isFalse);
        expect(firstRestore.retryAudioCleanupSafe, isTrue);
        firstRestore.completeTask('valid-task');
        await firstRestore.pendingPersistence;

        final persistedRows =
            jsonDecode(await file.readAsString()) as List<dynamic>;
        final marker = persistedRows.singleWhere(
          (row) => row is Map && row['_unrestoredTaskRecord'] == true,
        ) as Map;
        expect(marker['retryAudioOwnershipKnown'], isTrue);
        expect(marker['retryAudioIds'], [audioId]);
        expect(
          await file.readAsString(),
          isNot(contains('opaque-skipped-task-key')),
        );

        final secondRestore = BackgroundTaskNotifier();
        expect(await secondRestore.restoreFromPersistence(), isFalse);
        expect(secondRestore.retryAudioCleanupSafe, isTrue);
        expect(secondRestore.retryAudioReferencedIds, {audioId});
        await secondRestore.pendingPersistence;
      },
    );

    test('recoverable retry references keep unrelated pruning safe', () async {
      const audioId = 'cccccccccccccccccccccccccccccccc';
      final file = _tasksFileIn(testDir.path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([
          {
            'id': 'future-asr-task',
            'type': 'future-asr-type',
            'title': 'unrecognized task type',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'version': 2,
              'audioReference': {
                'version': 1,
                'id': audioId,
                'name': 'retry.wav',
                'format': 'wav',
                'byteLength': 3,
                'sha256': 'd' * 64,
              },
            },
          },
        ]),
      );

      final notifier = BackgroundTaskNotifier();

      expect(await notifier.restoreFromPersistence(), isFalse);
      expect(notifier.retryAudioCleanupSafe, isTrue);
      expect(notifier.retryAudioReferencedIds, {audioId});
    });

    test(
      'pre-restore partial snapshots keep parsed ASR audio safe from pruning',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([1, 2, 3]),
          name: 'pre-restore-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final validTask = BackgroundTask(
          id: 'pre-restore-asr-owner',
          type: BackgroundTaskType.asr,
          title: 'Persisted retry owner',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final safelySkippedLegacyRow = <String, dynamic>{
          // Missing id makes this legacy ASR row unreadable as a task.
          'type': 'asr',
          'title': 'Safe skipped legacy row',
          'status': 'failed',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {'inputPath': '/recordings/legacy.wav'},
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([validTask.toMap(), safelySkippedLegacyRow]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'Trigger a pre-restore snapshot',
            startImmediately: false,
            taskId: 'pre-restore-prune-trigger',
          );
          await notifier.pendingPersistence;

          expect(
            notifier.retryAudioCleanupSafe,
            isFalse,
            reason:
                'pruning stays disabled until pre-restore cached tasks are published',
          );
          if (notifier.retryAudioCleanupSafe) {
            expect(
              notifier.retryAudioReferencedIds,
              contains(reference.id),
              reason:
                  'a cached persisted task must remain an audio owner before restore publishes it',
            );
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(
            await store.load(reference),
            isNotNull,
            reason: 'pre-restore pruning must not delete persisted retry audio',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'corrupt ASR rows with top-level audio refs disable startup pruning',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([1, 2, 3]),
          name: 'retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              // Missing id makes this row take the skipped-entry recovery path.
              'type': 'asr',
              'title': 'corrupt ASR task',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'steps': [],
              'audioReference': reference.toMap(),
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isFalse);
          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(await store.load(reference), isNotNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'valid ASR rows with top-level audio refs disable startup pruning',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([4, 5, 6]),
          name: 'valid-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          {
            'id': 'valid-top-level-audio-task',
            'type': 'asr',
            'title': 'valid ASR task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'steps': [],
            'audioReference': reference.toMap(),
          },
        ]);
        await file.writeAsString(originalSnapshot);

        final notifier = BackgroundTaskNotifier();
        try {
          final restored = await notifier.restoreFromPersistence();
          final cleanupSafe = notifier.retryAudioCleanupSafe;
          if (cleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }

          expect(restored, isFalse);
          expect(cleanupSafe, isFalse);
          expect(await file.readAsString(), originalSnapshot);
          expect(await store.load(reference), isNotNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'top-level retry audio ownership stays unsafe after snapshot sanitation',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([12, 13, 14]),
          name: 'malformed-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'malformed-retry-owner',
              'type': 'asr',
              'title': 'Malformed retry owner',
              'status': 'failed',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': 'malformed',
              'audioPath': '/retry-cache/${reference.id}.audio',
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isFalse);

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Trigger a successful sanitized snapshot',
            startImmediately: false,
          );
          await notifier.pendingPersistence;

          final cleanupSafe = notifier.retryAudioCleanupSafe;
          if (cleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(
            cleanupSafe,
            isFalse,
            reason:
                'an unrecoverable top-level audio path cannot retire its ownership marker',
          );
          expect(
            await store.load(reference),
            isNotNull,
            reason:
                'a sanitized snapshot must not permit pruning unknown retry audio',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'failed task removal keeps retry audio referenced until removal persists',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([7, 8, 9]),
          name: 'owned-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'failed-remove-still-owns-retry-audio';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Retry audio owner',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated task removal write failure');
        };
        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(notifier.retryAudioReferencedIds, contains(reference.id));

          notifier.removeTask(taskId);
          await notifier.pendingPersistence;

          expect(notifier.taskById(taskId), isNull);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(notifier.retryAudioReferencedIds, contains(reference.id));
          final persistedRows = jsonDecode(await file.readAsString()) as List;
          expect(
            persistedRows.whereType<Map>().any((row) => row['id'] == taskId),
            isTrue,
          );
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(reference), isNotNull);
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'disposing during a removal write preserves retry audio ownership',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([7, 8, 10]),
          name: 'dispose-pending-remove.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'dispose-pending-remove-still-owns-audio';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Retry audio owner during dispose',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final notifier = BackgroundTaskNotifier();
        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            if (writeStarted.isCompleted) return;
            writeStarted.complete();
            await resumeWrite.future;
          };
          notifier.removeTask(taskId);
          await writeStarted.future;

          notifier.dispose();
          expect(notifier.retryAudioReferencedIds, contains(reference.id));
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(
            await store.load(reference),
            isNotNull,
            reason:
                'the blocked removal has not removed the persisted owner row',
          );

          resumeWrite.complete();
          await notifier.pendingPersistence;
        } finally {
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'completed persisted tasks keep retry audio referenced until removal persists',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([1, 3, 5]),
          name: 'completed-owned-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'completed-remove-still-owns-retry-audio';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Completed task with retry audio',
          status: TaskStatus.completed,
          createdAt: DateTime.utc(2026),
          completedAt: DateTime.utc(2026, 1, 2),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated completed task removal write failure');
        };
        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(notifier.retryAudioReferencedIds, contains(reference.id));

          notifier.removeTask(taskId);
          await notifier.pendingPersistence;

          expect(notifier.taskById(taskId), isNull);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(
            notifier.retryAudioReferencedIds,
            contains(reference.id),
            reason: 'the still-persisted completed task owns its retry audio',
          );
          final persistedRows = jsonDecode(await file.readAsString()) as List;
          expect(
            persistedRows.whereType<Map>().any((row) => row['id'] == taskId),
            isTrue,
          );
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(reference), isNotNull);
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'completed legacy retry references stay protected until snapshot persists',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([2, 4, 6]),
          name: 'completed-legacy-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'completed-legacy-retry-owner';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Completed legacy task with retry audio',
          status: TaskStatus.completed,
          createdAt: DateTime.utc(2026),
          completedAt: DateTime.utc(2026, 1, 2),
          // A versionless reference record is accepted as legacy ownership.
          retryData: {
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated legacy cleanup snapshot write failure');
        };
        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          final persistedRows = jsonDecode(await file.readAsString()) as List;
          expect(
            persistedRows.whereType<Map>().any(
                  (row) =>
                      row['id'] == taskId &&
                      (row['retryData'] as Map?)?['audioReferences'] is List,
                ),
            isTrue,
            reason: 'the failed rewrite leaves the legacy reference on disk',
          );

          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(
            await store.load(reference),
            isNotNull,
            reason: 'pruning must retain audio still named by the old snapshot',
          );
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'completed legacy retry references stay protected while snapshot write is blocked',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([2, 4, 6]),
          name: 'completed-legacy-retry-blocked.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'completed-legacy-retry-blocked-owner';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Completed legacy task with retry audio',
          status: TaskStatus.completed,
          createdAt: DateTime.utc(2026),
          completedAt: DateTime.utc(2026, 1, 2),
          retryData: {
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final snapshotWriteStarted = Completer<void>();
        final resumeSnapshotWrite = Completer<void>();
        // ignore: invalid_use_of_visible_for_testing_member
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (snapshotWriteStarted.isCompleted) return;
          snapshotWriteStarted.complete();
          await resumeSnapshotWrite.future;
        };
        final notifier = BackgroundTaskNotifier();
        Future<bool>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotWriteStarted.future;

          expect(notifier.taskById(taskId)?.retryData, isNull);
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(
            await store.load(reference),
            isNotNull,
            reason:
                'a prune during snapshot rewrite must retain audio still named by the on-disk row',
          );

          resumeSnapshotWrite.complete();
          expect(await restore, isTrue);
        } finally {
          if (!resumeSnapshotWrite.isCompleted) resumeSnapshotWrite.complete();
          // ignore: invalid_use_of_visible_for_testing_member
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'task removal during restore keeps retry audio referenced after write failure',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([4, 5, 6]),
          name: 'restoring-retry.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'restore-remove-still-owns-retry-audio';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Retry audio owner during restore',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final snapshotRead = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotRead.isCompleted) return;
          snapshotRead.complete();
          await resumeRestore.future;
        };
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated task removal write failure');
        };

        final notifier = BackgroundTaskNotifier();
        Future<bool>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotRead.future;

          // The task exists in the captured snapshot but is not in state yet.
          notifier.removeTask(taskId);
          expect(notifier.taskById(taskId), isNull);

          resumeRestore.complete();
          expect(await restore, isTrue);
          await notifier.pendingPersistence;

          expect(notifier.retryAudioCleanupSafe, isTrue);
          final persistedRows = jsonDecode(await file.readAsString()) as List;
          expect(
            persistedRows.whereType<Map>().any((row) => row['id'] == taskId),
            isTrue,
            reason:
                'the failed deletion leaves the previously saved row on disk',
          );
          expect(
            notifier.retryAudioReferencedIds,
            contains(reference.id),
            reason: 'the persisted row still owns its retry audio',
          );
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(reference), isNotNull);
        } finally {
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'same-ID re-add during restore keeps old generation audio referenced',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final oldReference = await store.save(
          Uint8List.fromList([1, 2, 3]),
          name: 'old-generation.wav',
          format: 'wav',
        );
        final replacementReference = await store.save(
          Uint8List.fromList([4, 5, 6]),
          name: 'replacement-generation.wav',
          format: 'wav',
        );
        await store.releaseProtection(oldReference);
        await store.releaseProtection(replacementReference);
        const taskId = 'restore-remove-readd-still-owns-retry-audio';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Old retry audio owner',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': oldReference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final snapshotRead = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotRead.isCompleted) return;
          snapshotRead.complete();
          await resumeRestore.future;
        };
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated task removal write failure');
        };

        final notifier = BackgroundTaskNotifier();
        Future<bool>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotRead.future;

          // A same-ID generation can already be in state when a remove/re-add
          // races the disk restore. The captured disk row still owns its old
          // retry audio even though that row will be skipped during merge.
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Preexisting replacement generation',
            startImmediately: false,
            taskId: taskId,
            retryData: {
              'version': 2,
              'audioReferences': [
                {
                  'audioReference': replacementReference.toMap(),
                  'chunks': <dynamic>[],
                },
              ],
            },
          );

          notifier.removeTask(taskId);
          expect(notifier.taskById(taskId), isNull);
          expect(
            notifier.addTask(
              type: BackgroundTaskType.asr,
              title: 'Replacement retry audio owner',
              startImmediately: false,
              taskId: taskId,
              retryData: {
                'version': 2,
                'audioReferences': [
                  {
                    'audioReference': replacementReference.toMap(),
                    'chunks': <dynamic>[],
                  },
                ],
              },
            ),
            taskId,
          );

          resumeRestore.complete();
          expect(await restore, isTrue);
          await notifier.pendingPersistence;

          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(
            notifier.retryAudioReferencedIds,
            containsAll([oldReference.id, replacementReference.id]),
            reason:
                'the old on-disk generation and same-ID replacement both own audio until deletion persists',
          );
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(oldReference), isNotNull);
        } finally {
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'same-ID restore replacement retains old audio after snapshot write failure',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final oldReference = await store.save(
          Uint8List.fromList([1, 2, 3]),
          name: 'old-snapshot-generation.wav',
          format: 'wav',
        );
        final replacementReference = await store.save(
          Uint8List.fromList([4, 5, 6]),
          name: 'replacement-snapshot-generation.wav',
          format: 'wav',
        );
        await store.releaseProtection(oldReference);
        await store.releaseProtection(replacementReference);
        const taskId = 'restore-duplicate-id-write-failure';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Persisted retry audio owner',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': oldReference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final snapshotRead = Completer<void>();
        final resumeRestore = Completer<void>();
        // ignore: invalid_use_of_visible_for_testing_member
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotRead.isCompleted) return;
          snapshotRead.complete();
          await resumeRestore.future;
        };
        // ignore: invalid_use_of_visible_for_testing_member
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated same-ID replacement write failure');
        };

        final notifier = BackgroundTaskNotifier();
        Future<bool>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotRead.future;

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Preexisting same-ID replacement',
            startImmediately: false,
            taskId: taskId,
            retryData: {
              'version': 2,
              'audioReferences': [
                {
                  'audioReference': replacementReference.toMap(),
                  'chunks': <dynamic>[],
                },
              ],
            },
          );

          resumeRestore.complete();
          expect(await restore, isTrue);
          await notifier.pendingPersistence;

          expect(notifier.retryAudioCleanupSafe, isFalse);
          expect(
            notifier.retryAudioReferencedIds,
            contains(oldReference.id),
            reason:
                'the old on-disk generation remains authoritative until its replacement is durable',
          );
          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(await store.load(oldReference), isNotNull);
          final persistedRows = jsonDecode(await file.readAsString()) as List;
          expect(
            persistedRows.whereType<Map>().single['id'],
            taskId,
            reason:
                'the failed replacement leaves the original task row on disk',
          );
        } finally {
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          // ignore: invalid_use_of_visible_for_testing_member
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          // ignore: invalid_use_of_visible_for_testing_member
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'pruning waits for sanitized v2 retry ownership to become durable',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final recognizedReference = await store.save(
          Uint8List.fromList([1, 2, 3]),
          name: 'recognized.wav',
          format: 'wav',
        );
        final pathReference = await store.save(
          Uint8List.fromList([4, 5, 6]),
          name: 'legacy-path.wav',
          format: 'wav',
        );
        await store.releaseProtection(recognizedReference);
        await store.releaseProtection(pathReference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          {
            'id': 'v2-path-owner-before-sanitize',
            'type': 'asr',
            'title': 'Versioned ASR task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'type': 'asr',
              'version': 2,
              'audioReference': recognizedReference.toMap(),
              'legacyAudioPath': '/retry-cache/${pathReference.id}.audio',
              'chunks': <dynamic>[],
            },
          },
        ]);
        await file.writeAsString(originalSnapshot);

        final snapshotWriteStarted = Completer<void>();
        final resumeSnapshotWrite = Completer<void>();
        // ignore: invalid_use_of_visible_for_testing_member
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (!snapshotWriteStarted.isCompleted) {
            snapshotWriteStarted.complete();
          }
          await resumeSnapshotWrite.future;
          throw StateError('simulated sanitized snapshot write failure');
        };

        final notifier = BackgroundTaskNotifier();
        Future<bool>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotWriteStarted.future;

          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }

          resumeSnapshotWrite.complete();
          expect(await restore, isTrue);
          await notifier.pendingPersistence;
          expect(await file.readAsString(), originalSnapshot);
          expect(await store.load(pathReference), isNotNull);
        } finally {
          if (!resumeSnapshotWrite.isCompleted) resumeSnapshotWrite.complete();
          // ignore: invalid_use_of_visible_for_testing_member
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unknown v2 retry audio references remain protected after failed sanitization',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final recognizedReference = await store.save(
          Uint8List.fromList([1, 3, 5]),
          name: 'recognized.wav',
          format: 'wav',
        );
        final unrecognizedReference = await store.save(
          Uint8List.fromList([2, 4, 6]),
          name: 'unrecognized.wav',
          format: 'wav',
        );
        final pathReference = await store.save(
          Uint8List.fromList([7, 8, 9]),
          name: 'path-owned.wav',
          format: 'wav',
        );
        await store.releaseProtection(recognizedReference);
        await store.releaseProtection(unrecognizedReference);
        await store.releaseProtection(pathReference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          {
            'id': 'v2-with-unrecognized-audio-reference',
            'type': 'asr',
            'title': 'Versioned ASR task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'type': 'asr',
              'version': 2,
              'audioReference': recognizedReference.toMap(),
              'legacyAudioReference': unrecognizedReference.toMap(),
              'legacyAudioPath': '/retry-cache/${pathReference.id}.audio',
              'chunks': <dynamic>[],
            },
          },
        ]);
        await file.writeAsString(originalSnapshot);
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated sanitized snapshot write failure');
        };

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          expect(notifier.retryAudioCleanupSafe, isFalse);
          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }

          expect(await file.readAsString(), originalSnapshot);
          expect(await store.load(unrecognizedReference), isNotNull);
          expect(await store.load(pathReference), isNotNull);

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'snapshot recovery trigger',
          );
          await notifier.pendingPersistence;

          expect(
            notifier.retryAudioCleanupSafe,
            isTrue,
            reason: 'a durable sanitized snapshot resolves the unsafe row',
          );
          final sanitizedSnapshot = await file.readAsString();
          expect(sanitizedSnapshot, isNot(contains('legacyAudioPath')));
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(recognizedReference), isNotNull);
          await expectLater(
            store.load(unrecognizedReference),
            throwsA(isA<AsrRetryAudioUnavailableException>()),
          );
          await expectLater(
            store.load(pathReference),
            throwsA(isA<AsrRetryAudioUnavailableException>()),
          );
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unrecognized retry cache paths remain protected until sanitation is durable',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final recognizedReference = await store.save(
          Uint8List.fromList([1, 3, 5]),
          name: 'recognized.wav',
          format: 'wav',
        );
        final cachePathReference = await store.save(
          Uint8List.fromList([2, 4, 6]),
          name: 'legacy-path.wav',
          format: 'wav',
        );
        await store.releaseProtection(recognizedReference);
        await store.releaseProtection(cachePathReference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          {
            'id': 'v2-with-unrecognized-cache-path',
            'type': 'asr',
            'title': 'Versioned ASR task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'type': 'asr',
              'version': 2,
              'audioReference': recognizedReference.toMap(),
              'cachePath': '/retry-cache/${cachePathReference.id}.audio',
              'chunks': <dynamic>[],
            },
          },
        ]);
        await file.writeAsString(originalSnapshot);
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated sanitized snapshot write failure');
        };

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;

          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(await file.readAsString(), originalSnapshot);
          expect(await store.load(cachePathReference), isNotNull);

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'snapshot recovery trigger',
          );
          await notifier.pendingPersistence;

          expect(notifier.retryAudioCleanupSafe, isTrue);
          final sanitizedSnapshot = await file.readAsString();
          expect(sanitizedSnapshot, isNot(contains('cachePath')));
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(recognizedReference), isNotNull);
          await expectLater(
            store.load(cachePathReference),
            throwsA(isA<AsrRetryAudioUnavailableException>()),
          );
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'malformed ASR rows release ownership after durable sanitization',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final recognizedReference = await store.save(
          Uint8List.fromList([1, 3, 5]),
          name: 'recognized.wav',
          format: 'wav',
        );
        final unrecognizedReference = await store.save(
          Uint8List.fromList([2, 4, 6]),
          name: 'unrecognized.wav',
          format: 'wav',
        );
        await store.releaseProtection(recognizedReference);
        await store.releaseProtection(unrecognizedReference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'malformed-v2-with-unrecognized-audio-reference',
              'type': 'asr',
              'title': 'Malformed versioned ASR task',
              'status': 'not-a-task-status',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'type': 'asr',
                'version': 2,
                'audioReference': recognizedReference.toMap(),
                'legacyAudioReference': unrecognizedReference.toMap(),
                'chunks': <dynamic>[],
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(notifier.retryAudioReferencedIds, isEmpty);

          await store.prune(() => notifier.retryAudioReferencedIds);

          await expectLater(
            store.load(recognizedReference),
            throwsA(isA<AsrRetryAudioUnavailableException>()),
          );
          await expectLater(
            store.load(unrecognizedReference),
            throwsA(isA<AsrRetryAudioUnavailableException>()),
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'preserved malformed ASR cache paths keep retry audio protected',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([7, 8, 9]),
          name: 'legacy-cache-path.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'bad-asr',
              'type': 'asr',
              'title': 'Legacy cache path ASR task',
              'status': 'invalid',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': {
                'cachePath': '/retry-cache/${reference.id}.audio',
              },
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isTrue);
          expect(
            await file.readAsString(),
            contains('/retry-cache/${reference.id}.audio'),
          );
          expect(
            notifier.retryAudioReferencedIds,
            contains(reference.id),
          );

          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(reference), isNotNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'unrecognized top-level ASR cache paths keep pruning disabled',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([3, 4, 5]),
          name: 'top-level-cache-path.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          {
            'id': 'top-level-cache-path-owner',
            'type': 'asr',
            'title': 'Top-level cache path ASR task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'path': '/retry-cache/${reference.id}.audio',
          },
        ]);
        await file.writeAsString(originalSnapshot);

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          final cleanupSafe = notifier.retryAudioCleanupSafe;
          if (cleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }

          expect(await file.readAsString(), originalSnapshot);
          expect(await store.load(reference), isNotNull);
          expect(
            cleanupSafe,
            isFalse,
            reason:
                'an unknown top-level audio path keeps its owner unresolved',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test('unknown retry-data versions disable retry audio cleanup', () async {
      const audioId = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      const futureAudioId = 'ffffffffffffffffffffffffffffffff';
      final file = _tasksFileIn(testDir.path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode([
          {
            'id': 'valid-task',
            'type': 'ocr',
            'title': 'valid task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          },
          {
            'id': 'future-asr-task',
            'type': 'future-asr-type',
            'title': 'unrecognized task type',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': {
              'version': 3,
              'audioReference': {
                'version': 1,
                'id': audioId,
                'name': 'retry.wav',
                'format': 'wav',
                'byteLength': 3,
                'sha256': 'd' * 64,
              },
              'futureAudioReferences': [futureAudioId],
            },
          },
        ]),
      );
      final audioFile = File(
        p.join(testDir.path, 'background', 'asr_retry', '$audioId.audio'),
      )..createSync(recursive: true);
      await audioFile.writeAsBytes([1, 2, 3]);
      final futureAudioFile = File(
        p.join(testDir.path, 'background', 'asr_retry', '$futureAudioId.audio'),
      )..createSync(recursive: true);
      await futureAudioFile.writeAsBytes([4, 5, 6]);

      final notifier = BackgroundTaskNotifier();

      expect(await notifier.restoreFromPersistence(), isFalse);
      expect(notifier.retryAudioCleanupSafe, isFalse);
      notifier.completeTask('valid-task');
      await notifier.pendingPersistence;

      final persistedRows = jsonDecode(await file.readAsString()) as List;
      final marker = persistedRows.singleWhere(
        (row) => row is Map && row['_unrestoredTaskRecord'] == true,
      ) as Map;
      expect(marker['retryAudioOwnershipKnown'], isFalse);
      expect(await audioFile.exists(), isTrue);
      expect(await futureAudioFile.exists(), isTrue);
    });

    test(
      'back-to-back OCR removals preserve cache while deletion retry fails',
      () async {
        WebFileStore.enableTestMode();
        final imageBytes = Uint8List.fromList([31, 32, 33, 34]);
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: 'queued-shared-cache-seed',
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: imageBytes, format: 'png')],
          ),
        );
        final cacheReference = ((retryData['images'] as List).single
            as Map)['storageRef'] as String;
        final notifier = BackgroundTaskNotifier();
        final firstWriteEntered = Completer<void>();
        final resumeFirstWrite = Completer<void>();
        var writeCount = 0;
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'first shared-cache task',
            taskId: 'first-shared-cache-task',
            retryData: retryData,
          );
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'second shared-cache task',
            taskId: 'second-shared-cache-task',
            retryData: retryData,
          );
          await notifier.pendingPersistence;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            writeCount++;
            if (writeCount == 1) {
              firstWriteEntered.complete();
              await resumeFirstWrite.future;
            } else if (writeCount == 2 || writeCount == 3) {
              throw StateError('simulated second removal write failure');
            }
          };

          notifier.removeTask('first-shared-cache-task');
          await firstWriteEntered.future;
          notifier.removeTask('second-shared-cache-task');
          expect(notifier.state, isEmpty);

          resumeFirstWrite.complete();
          await notifier.pendingPersistence;

          final persistedTasks =
              jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                  as List;
          expect(
            persistedTasks.whereType<Map>().any(
                  (task) => task['id'] == 'second-shared-cache-task',
                ),
            isTrue,
            reason:
                'the first removal snapshot still references the second task',
          );
          expect(
            await OcrRetryStorage.read(cacheReference),
            orderedEquals(imageBytes),
            reason:
                'a failed later snapshot must not lose a durable task input',
          );
        } finally {
          if (!resumeFirstWrite.isCompleted) resumeFirstWrite.complete();
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'OCR cache deletion serializes with publication of a shared reference',
      () async {
        WebFileStore.enableTestMode();
        final bytes = Uint8List.fromList([21, 22, 23, 24]);
        final originalRetryData = await OcrRetryStorage.cacheSnapshot(
          taskId: 'shared-reference-seed',
          snapshot: OcrRetrySnapshot.capture(
            images: [OcrRetryImage(bytes: bytes, format: 'png')],
          ),
        );
        final reference = ((originalRetryData['images'] as List).single
            as Map)['storageRef'] as String;
        final deletionEntered = Completer<void>();
        final resumeDeletion = Completer<void>();
        BackgroundTaskNotifier.debugBeforeOcrCacheDelete = () async {
          if (deletionEntered.isCompleted) return;
          deletionEntered.complete();
          await resumeDeletion.future;
        };
        final notifier = BackgroundTaskNotifier();
        Future<void>? publication;
        var publicationFinishedBeforeDeletion = false;
        try {
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'task being removed',
            taskId: 'shared-reference-being-removed',
            retryData: originalRetryData,
          );
          await notifier.pendingPersistence;

          notifier.removeTask('shared-reference-being-removed');
          await deletionEntered.future;

          publication = OcrRetryStorage.withCacheMaintenanceLock(() async {
            final sharedRetryData = await OcrRetryStorage.cacheSnapshot(
              taskId: 'shared-reference-being-published',
              snapshot: OcrRetrySnapshot.capture(
                images: [
                  OcrRetryImage(
                    bytes: bytes,
                    storageRef: reference,
                    format: 'png',
                  ),
                ],
              ),
            );
            notifier.addTask(
              type: BackgroundTaskType.ocr,
              title: 'task sharing the cache blob',
              taskId: 'shared-reference-being-published',
              retryData: sharedRetryData,
            );
          });
          publicationFinishedBeforeDeletion = await Future.any([
            publication.then((_) => true),
            Future<bool>.delayed(
              const Duration(milliseconds: 100),
              () => false,
            ),
          ]);

          resumeDeletion.complete();
          await publication;
          await notifier.pendingPersistence;

          expect(
            publicationFinishedBeforeDeletion,
            isFalse,
            reason: 'cache publication must wait until deletion finishes',
          );
          expect(
            notifier.state.map((task) => task.id),
            contains('shared-reference-being-published'),
          );
          expect(await OcrRetryStorage.read(reference), orderedEquals(bytes));
        } finally {
          if (!resumeDeletion.isCompleted) resumeDeletion.complete();
          if (publication != null) await publication;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'restoreFromPersistence marks running tasks as failed and persists',
      () async {
        final file = _tasksFileIn(testDir.path);

        final n1 = BackgroundTaskNotifier();
        final id = n1.addTask(type: BackgroundTaskType.asr, title: '中断任务');
        // 等待本测试的任务落盘。
        await _waitFor(() async {
          final content = await _readFileIfExists(file);
          return content?.contains(id) ?? false;
        });

        final n2 = BackgroundTaskNotifier();
        await n2.restoreFromPersistence();

        expect(n2.state.length, 1);
        expect(n2.state[0].id, id);
        expect(n2.state[0].status, TaskStatus.failed);
        expect(n2.state[0].error, '应用重启，已中断');

        // The corrected state must be written back to disk so the next
        // startup doesn't re-mark the same task again.
        await _waitFor(() async {
          final content = await _readFileIfExists(file);
          return content?.contains('"status":"failed"') ?? false;
        });
      },
    );
    test(
      'addTask during startup restore preserves existing persisted tasks',
      () => _verifyStartupAddPreservesPersistedTask(
        storageDir: testDir.path,
        addedTaskId: 'added-during-restore',
        timing: _StartupAddTiming.afterRestoreReadStarts,
      ),
    );
    test(
      'queued add before startup restore preserves existing persisted tasks',
      () => _verifyStartupAddPreservesPersistedTask(
        storageDir: testDir.path,
        addedTaskId: 'added-before-restore',
        timing: _StartupAddTiming.queuedBeforeRestore,
      ),
    );
    test(
      'in-flight task write preserves prior tasks before startup restore reads',
      () => _verifyStartupAddPreservesPersistedTask(
        storageDir: testDir.path,
        addedTaskId: 'added-before-restore-read',
        timing: _StartupAddTiming.writePreparedBeforeRestoreRead,
      ),
    );
    test(
      'pre-restore add preserves safely skipped rows and survives partial restore',
      () async {
        const persistedTaskId = 'persisted-before-partial-restore';
        const addedTaskId = 'added-before-partial-restore';
        final persistedTask = BackgroundTask(
          id: persistedTaskId,
          type: BackgroundTaskType.asr,
          title: 'Existing persisted task',
          status: TaskStatus.waiting,
          createdAt: DateTime(2025, 1, 1),
        );
        final skippedRow = <String, dynamic>{
          // Missing id makes this safe, non-OCR row unreadable as a task.
          'type': 'asr',
          'title': 'Safely skipped ASR row',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 2).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {'inputPath': '/recordings/persisted.wav'},
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([persistedTask.toMap(), skippedRow]),
        );

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        try {
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'New task before partial restore',
            startImmediately: false,
            taskId: addedTaskId,
          );
          await notifier.pendingPersistence;

          final savedBeforeRestore =
              jsonDecode(await file.readAsString()) as List;
          expect(
            savedBeforeRestore.whereType<Map>().map((row) => row['id']),
            containsAll([persistedTaskId, addedTaskId]),
          );
          expect(
            savedBeforeRestore.whereType<Map>().singleWhere(
                  (row) => row['title'] == skippedRow['title'],
                ),
            skippedRow,
          );

          await notifier.restoreFromPersistence();
          await notifier.pendingPersistence;
          expect(notifier.taskById(persistedTaskId), isNotNull);
          expect(notifier.taskById(addedTaskId)?.status, TaskStatus.waiting);

          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(persistedTaskId), isNotNull);
          expect(reloaded.taskById(addedTaskId), isNotNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'pre-restore removals do not restore explicitly removed persisted tasks',
      () async {
        const taskId = 'removed-before-restore';
        const removeTaskId = 'removed-with-removeTask-before-restore';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before removal',
          startImmediately: false,
          taskId: taskId,
        );
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before removeTask',
          startImmediately: false,
          taskId: removeTaskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        try {
          expect(await notifier.removeTasksPersisted([taskId]), isTrue);
          await notifier.pendingPersistence;
          expect(
            (jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                    as List)
                .whereType<Map>()
                .map((task) => task['id']),
            [removeTaskId],
          );

          notifier.removeTask(removeTaskId);
          await notifier.pendingPersistence;
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
          expect(reloaded.taskById(removeTaskId), isNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'failed pre-restore removal keeps a task visible in a partial snapshot',
      () async {
        const taskId = 'kept-after-failed-partial-removal';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Keep after failed removal',
          status: TaskStatus.waiting,
          createdAt: DateTime(2025, 1, 1),
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([
          task.toMap(),
          {'type': 'asr', 'title': 'unparseable persisted entry'},
        ]);
        await file.writeAsString(originalSnapshot);

        final notifier = BackgroundTaskNotifier();
        try {
          notifier.removeTask(taskId);
          await notifier.pendingPersistence;
          expect(await file.readAsString(), originalSnapshot);

          await notifier.restoreFromPersistence();
          expect(notifier.taskById(taskId), isNotNull);
          expect(await file.readAsString(), originalSnapshot);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );
    test(
      'earlier removal write does not clear a later same-ID removal',
      () async {
        const taskId = 'removed-again-during-first-removal-write';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before repeated removal',
          startImmediately: false,
          taskId: taskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final firstWriteStarted = Completer<void>();
        final resumeFirstWrite = Completer<void>();
        final secondRemovalStarted = Completer<void>();
        final resumeSecondRemoval = Completer<void>();
        var writeCount = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          final attempt = writeCount++;
          if (attempt == 0) {
            firstWriteStarted.complete();
            await resumeFirstWrite.future;
          } else if (attempt == 2) {
            secondRemovalStarted.complete();
            await resumeSecondRemoval.future;
          }
        };
        final snapshotCaptured = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (!snapshotCaptured.isCompleted) {
            snapshotCaptured.complete();
            await resumeRestore.future;
          }
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<void>? firstRemovalWrite;
        Future<void>? restore;
        try {
          notifier.removeTask(taskId);
          await firstWriteStarted.future;
          firstRemovalWrite = notifier.pendingPersistence;

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Re-added with the same ID',
            startImmediately: false,
            taskId: taskId,
          );
          notifier.removeTask(taskId);

          // The first deletion succeeds and clears the newer marker. The
          // queued re-add then reaches disk before the second deletion pauses.
          resumeFirstWrite.complete();
          await firstRemovalWrite;
          await secondRemovalStarted.future;

          final pendingRemovalWrite = notifier.pendingPersistence;
          restore = notifier.restoreFromPersistence();
          await snapshotCaptured.future;
          resumeSecondRemoval.complete();
          await pendingRemovalWrite;
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          resumeRestore.complete();
          await restore;
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNull);
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
        } finally {
          if (!resumeFirstWrite.isCompleted) resumeFirstWrite.complete();
          if (!resumeSecondRemoval.isCompleted) {
            resumeSecondRemoval.complete();
          }
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'earlier removal write does not remove a same-ID task re-added afterward',
      () async {
        const taskId = 're-added-during-removal-write';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before removal and re-add',
          startImmediately: false,
          taskId: taskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        var writeCount = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (writeCount++ != 0) return;
          writeStarted.complete();
          await resumeWrite.future;
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        try {
          notifier.removeTask(taskId);
          await writeStarted.future;
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'New task with the same ID',
            startImmediately: false,
            taskId: taskId,
          );

          resumeWrite.complete();
          await notifier.pendingPersistence;

          expect(notifier.taskById(taskId)?.title, 'New task with the same ID');
          expect(
            (jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                    as List)
                .whereType<Map>()
                .map((row) => row['id']),
            [taskId],
          );

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId)?.title, 'New task with the same ID');
        } finally {
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'batch removal preserves a same-ID re-add and removes other requested tasks',
      () async {
        const taskId = 're-added-during-batch-removal-write';
        const otherTaskId = 'removed-during-batch-removal-write';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before batch removal',
          startImmediately: false,
          taskId: taskId,
        );
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Another persisted task to remove',
          startImmediately: false,
          taskId: otherTaskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        var writeCount = 0;

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<bool>? removal;
        try {
          await notifier.restoreFromPersistence();
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNotNull);
          expect(notifier.taskById(otherTaskId), isNotNull);

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            if (writeCount++ != 0) return;
            writeStarted.complete();
            await resumeWrite.future;
          };
          removal = notifier.removeTasksPersisted([taskId, otherTaskId]);
          await writeStarted.future;
          notifier.setSteps(taskId, notifier.taskById(taskId)!.steps);
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Replacement task with the same ID',
            startImmediately: false,
            taskId: taskId,
          );

          resumeWrite.complete();
          expect(await removal, isTrue);
          await notifier.pendingPersistence;

          expect(
            notifier.taskById(taskId)?.title,
            'Replacement task with the same ID',
          );
          expect(
            notifier.state.where((task) => task.id == taskId),
            hasLength(1),
          );
          expect(notifier.taskById(otherTaskId), isNull);
          final persisted =
              jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                  as List;
          expect(persisted.whereType<Map>().map((row) => row['id']), [taskId]);
          expect(
            persisted.whereType<Map>().single['title'],
            'Replacement task with the same ID',
          );

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(
            reloaded.taskById(taskId)?.title,
            'Replacement task with the same ID',
          );
          expect(reloaded.taskById(otherTaskId), isNull);
        } finally {
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'queued batch removal preserves a same-ID add made after invocation',
      () async {
        const blockerTaskId = 'first-batch-removal-blocker';
        const queuedTaskId = 'queued-batch-removal-re-added-task';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Task removed by the first batch',
          startImmediately: false,
          taskId: blockerTaskId,
        );
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Task targeted by the queued batch',
          startImmediately: false,
          taskId: queuedTaskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        var writeCount = 0;

        final notifier = BackgroundTaskNotifier();
        Future<bool>? firstRemoval;
        Future<bool>? queuedRemoval;
        try {
          await notifier.restoreFromPersistence();
          await notifier.pendingPersistence;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            if (writeCount++ != 0) return;
            writeStarted.complete();
            await resumeWrite.future;
          };

          firstRemoval = notifier.removeTasksPersisted([blockerTaskId]);
          await writeStarted.future;
          queuedRemoval = notifier.removeTasksPersisted([queuedTaskId]);
          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Replacement added while queued removal waits',
            startImmediately: false,
            taskId: queuedTaskId,
          );

          resumeWrite.complete();
          expect(await firstRemoval, isTrue);
          expect(await queuedRemoval, isTrue);
          await notifier.pendingPersistence;

          expect(notifier.taskById(blockerTaskId), isNull);
          expect(
            notifier.taskById(queuedTaskId)?.title,
            'Replacement added while queued removal waits',
          );
          expect(
            notifier.state.where((task) => task.id == queuedTaskId),
            hasLength(1),
          );
          final persisted =
              jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                  as List;
          expect(persisted.whereType<Map>().map((row) => row['id']), [
            queuedTaskId,
          ]);
          expect(
            persisted.whereType<Map>().single['title'],
            'Replacement added while queued removal waits',
          );
        } finally {
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (firstRemoval != null) await firstRemoval;
          if (queuedRemoval != null) await queuedRemoval;
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );
    test(
      'later pre-restore write retains removals after both removal writes fail',
      () async {
        const removedTaskId = 'removed-before-failed-write';
        const addedTaskId = 'added-after-failed-removal';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted task to remove',
          startImmediately: false,
          taskId: removedTaskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        var writeAttempts = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (writeAttempts++ < 2) {
            throw StateError('simulated task snapshot write failure');
          }
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        try {
          notifier.removeTask(removedTaskId);
          await notifier.pendingPersistence;
          expect(writeAttempts, 2);
          expect(
            (jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                    as List)
                .whereType<Map>()
                .map((task) => task['id']),
            [removedTaskId],
          );

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'New task after failed removal',
            startImmediately: false,
            taskId: addedTaskId,
          );
          await notifier.pendingPersistence;
          expect(writeAttempts, 3);
          final persistedIds =
              (jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                      as List)
                  .whereType<Map>()
                  .map((task) => task['id']);
          expect(persistedIds, [addedTaskId]);

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await reloaded.restoreFromPersistence();
          expect(reloaded.taskById(removedTaskId), isNull);
          expect(reloaded.taskById(addedTaskId), isNotNull);
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'removeTask retries a failed snapshot write before another mutation',
      () async {
        const taskId = 'removed-after-transient-snapshot-failure';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted task to remove',
          startImmediately: false,
          taskId: taskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        var writeAttempts = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (writeAttempts++ == 0) {
            throw StateError('simulated transient task snapshot write failure');
          }
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        try {
          notifier.removeTask(taskId);
          await notifier.pendingPersistence;

          final persisted =
              jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                  as List;

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(
            reloaded.taskById(taskId),
            isNull,
            reason: 'a fresh provider must not restore the removed task',
          );
          expect(persisted, isEmpty);
          expect(writeAttempts, 2);
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test('failed removal retry keeps a same-ID replacement task', () async {
      const taskId = 'replacement-after-failed-removal-write';
      final seed = BackgroundTaskNotifier();
      seed.addTask(
        type: BackgroundTaskType.asr,
        title: 'Persisted task to remove',
        startImmediately: false,
        taskId: taskId,
      );
      await seed.pendingPersistence;
      seed.dispose();
      await seed.pendingPersistence;

      final firstWriteStarted = Completer<void>();
      final resumeFirstWrite = Completer<void>();
      var writeAttempts = 0;
      BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
        final attempt = writeAttempts++;
        if (attempt == 0) {
          firstWriteStarted.complete();
          await resumeFirstWrite.future;
          throw StateError('simulated transient task snapshot write failure');
        }
        if (attempt == 2) {
          throw StateError('simulated queued replacement write failure');
        }
      };

      final notifier = BackgroundTaskNotifier();
      final reloaded = BackgroundTaskNotifier();
      try {
        notifier.removeTask(taskId);
        await firstWriteStarted.future;
        notifier.addTask(
          type: BackgroundTaskType.asr,
          title: 'Replacement task with the same ID',
          startImmediately: false,
          taskId: taskId,
        );

        resumeFirstWrite.complete();
        await notifier.pendingPersistence;

        expect(writeAttempts, 3);
        final persisted =
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()) as List;
        expect(persisted.whereType<Map>(), hasLength(1));
        expect(persisted.whereType<Map>().single['id'], taskId);
        expect(
          persisted.whereType<Map>().single['title'],
          'Replacement task with the same ID',
        );

        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
        await reloaded.restoreFromPersistence();
        await reloaded.pendingPersistence;
        expect(
          reloaded.taskById(taskId)?.title,
          'Replacement task with the same ID',
        );
      } finally {
        if (!resumeFirstWrite.isCompleted) resumeFirstWrite.complete();
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
        notifier.dispose();
        await notifier.pendingPersistence;
        reloaded.dispose();
        await reloaded.pendingPersistence;
      }
    });
    test(
      'removeTask during restore does not restore a not-yet-loaded task',
      () async {
        const taskId = 'removed-during-restore';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before restore removal',
          startImmediately: false,
          taskId: taskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final readStarted = Completer<void>();
        final resumeRead = Completer<void>();
        BackgroundTaskNotifier.debugBeforeTaskSnapshotRead = () async {
          if (readStarted.isCompleted) return;
          readStarted.complete();
          await resumeRead.future;
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<void>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await readStarted.future;

          // The task is on disk but has not entered notifier state yet.
          notifier.removeTask(taskId);
          expect(notifier.taskById(taskId), isNull);

          resumeRead.complete();
          await restore;
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNull);
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          BackgroundTaskNotifier.debugBeforeTaskSnapshotRead = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
        } finally {
          if (!resumeRead.isCompleted) resumeRead.complete();
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'removeTask during partial restore stays out of state after a saved deletion',
      () async {
        const taskId = 'removed-during-partial-restore';
        final removedTask = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Persisted task to remove',
          status: TaskStatus.waiting,
          createdAt: DateTime(2025, 1, 1),
        );
        final skippedRow = <String, dynamic>{
          'type': 'asr',
          'title': 'Safely skipped ASR row',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 2).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {'inputPath': '/recordings/persisted.wav'},
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([removedTask.toMap(), skippedRow]));

        final snapshotCaptured = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotCaptured.isCompleted) return;
          snapshotCaptured.complete();
          await resumeRestore.future;
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<void>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotCaptured.future;

          // Restore has captured the partial file but has not merged its row.
          notifier.removeTask(taskId);
          resumeRestore.complete();
          await restore;
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNull);

          final persisted = jsonDecode(await file.readAsString()) as List;
          expect(
            persisted.whereType<Map>().any((row) => row['id'] == taskId),
            isFalse,
          );
          expect(
            persisted.whereType<Map>().singleWhere(
                  (row) => row['title'] == skippedRow['title'],
                ),
            skippedRow,
          );

          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
        } finally {
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'removeTask during partial restore stays visible when deletion fails',
      () async {
        const taskId = 'visible-after-partial-restore-delete-failure';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Persisted task to keep visible',
          status: TaskStatus.waiting,
          createdAt: DateTime(2025, 1, 1),
        );
        final skippedRow = <String, dynamic>{
          'type': 'asr',
          'title': 'Safely skipped ASR row after failed delete',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 2).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {'inputPath': '/recordings/persisted.wav'},
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        final originalSnapshot = jsonEncode([task.toMap(), skippedRow]);
        await file.writeAsString(originalSnapshot);

        final snapshotCaptured = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotCaptured.isCompleted) return;
          snapshotCaptured.complete();
          await resumeRestore.future;
        };
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          throw StateError('simulated deletion write failure');
        };

        final notifier = BackgroundTaskNotifier();
        Future<void>? restore;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotCaptured.future;

          notifier.removeTask(taskId);
          resumeRestore.complete();
          await restore;
          await notifier.pendingPersistence;

          expect(notifier.taskById(taskId), isNotNull);
          expect(await file.readAsString(), originalSnapshot);
        } finally {
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
        }
      },
    );
    test(
      'removeTask before restore stays removed after restore captures the old snapshot',
      () async {
        const taskId = 'removed-before-restore-read-merge';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before queued removal',
          startImmediately: false,
          taskId: taskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        var writeCount = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (writeCount++ != 0) return;
          writeStarted.complete();
          await resumeWrite.future;
        };
        final snapshotCaptured = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotCaptured.isCompleted) return;
          snapshotCaptured.complete();
          await resumeRestore.future;
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<void>? restore;
        try {
          // Queue the deletion before restore starts, then let restore capture
          // the old file before the deletion reaches its atomic write.
          notifier.removeTask(taskId);
          await writeStarted.future;
          restore = notifier.restoreFromPersistence();
          await snapshotCaptured.future;

          resumeWrite.complete();
          await notifier.pendingPersistence;
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          resumeRestore.complete();
          await restore;
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNull);
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
        } finally {
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'batch removal during incomplete restore removes a disk-only task from live state',
      () async {
        const taskId = 'batch-removed-during-incomplete-restore';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Persisted task to remove during restore',
          status: TaskStatus.waiting,
          createdAt: DateTime(2025, 1, 1),
        );
        final skippedRow = <String, dynamic>{
          'type': 'asr',
          'title': 'Safely skipped ASR row during batch restore removal',
          'status': 'failed',
          'createdAt': DateTime(2025, 1, 2).toIso8601String(),
          'steps': <dynamic>[],
          'retryData': {'inputPath': '/recordings/persisted.wav'},
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap(), skippedRow]));

        final snapshotCaptured = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotCaptured.isCompleted) return;
          snapshotCaptured.complete();
          await resumeRestore.future;
        };
        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (writeStarted.isCompleted) return;
          writeStarted.complete();
          await resumeWrite.future;
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<void>? restore;
        Future<bool>? removal;
        try {
          restore = notifier.restoreFromPersistence();
          await snapshotCaptured.future;
          expect(notifier.taskById(taskId), isNull);

          // The task exists only on disk when the removal starts. Let restore
          // merge its partial snapshot, then hold the successful delete write
          // so the generation filter has to reconcile live state afterward.
          removal = notifier.removeTasksPersisted([taskId]);
          resumeRestore.complete();
          await restore;
          await writeStarted.future;
          expect(notifier.taskById(taskId), isNotNull);

          resumeWrite.complete();
          expect(await removal, isTrue);
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNull);

          final persisted = jsonDecode(await file.readAsString()) as List;
          expect(
            persisted.whereType<Map>().any((row) => row['id'] == taskId),
            isFalse,
          );
          expect(
            persisted.singleWhere(
              (row) => row is Map && row['title'] == skippedRow['title'],
            ),
            skippedRow,
          );

          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
        } finally {
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          if (removal != null) await removal;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'removeTasksPersisted before restore stays removed after restore captures the old snapshot',
      () async {
        const taskId = 'batch-removed-before-restore-read-merge';
        final seed = BackgroundTaskNotifier();
        seed.addTask(
          type: BackgroundTaskType.asr,
          title: 'Persisted before batch removal',
          startImmediately: false,
          taskId: taskId,
        );
        await seed.pendingPersistence;
        seed.dispose();
        await seed.pendingPersistence;

        final writeStarted = Completer<void>();
        final resumeWrite = Completer<void>();
        var writeCount = 0;
        BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
          if (writeCount++ != 0) return;
          writeStarted.complete();
          await resumeWrite.future;
        };
        final snapshotCaptured = Completer<void>();
        final resumeRestore = Completer<void>();
        BackgroundTaskNotifier.debugAfterTaskSnapshotRead = () async {
          if (snapshotCaptured.isCompleted) return;
          snapshotCaptured.complete();
          await resumeRestore.future;
        };

        final notifier = BackgroundTaskNotifier();
        final reloaded = BackgroundTaskNotifier();
        Future<void>? restore;
        Future<bool>? removal;
        try {
          // Hold the batch deletion before its atomic write, then let restore
          // capture the old file before the deletion commits.
          removal = notifier.removeTasksPersisted([taskId]);
          await writeStarted.future;
          restore = notifier.restoreFromPersistence();
          await snapshotCaptured.future;

          resumeWrite.complete();
          expect(await removal, isTrue);
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          resumeRestore.complete();
          await restore;
          await notifier.pendingPersistence;
          expect(notifier.taskById(taskId), isNull);
          expect(
            jsonDecode(await _tasksFileIn(testDir.path).readAsString()),
            isEmpty,
          );

          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          await reloaded.restoreFromPersistence();
          await reloaded.pendingPersistence;
          expect(reloaded.taskById(taskId), isNull);
        } finally {
          if (!resumeWrite.isCompleted) resumeWrite.complete();
          if (!resumeRestore.isCompleted) resumeRestore.complete();
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          BackgroundTaskNotifier.debugAfterTaskSnapshotRead = null;
          if (removal != null) await removal;
          if (restore != null) await restore;
          notifier.dispose();
          await notifier.pendingPersistence;
          reloaded.dispose();
          await reloaded.pendingPersistence;
        }
      },
    );
    test(
      'rapid consecutive mutations end with the final state on disk',
      () async {
        final file = _tasksFileIn(testDir.path);

        final notifier = BackgroundTaskNotifier();
        final id = notifier.addTask(
          type: BackgroundTaskType.ocr,
          title: '快速变更',
        );
        notifier.completeTask(id);
        notifier.removeTask(id);

        // Even with several immediate mutations, the serialized write chain
        // must leave the latest state on disk (no stale-snapshot overwrite).
        await _waitFor(() async {
          final content = await _readFileIfExists(file);
          return content == '[]';
        });
      },
    );

    // ==================================================================
    // iOS 26+ 常驻后台任务桥接挂钩
    // ==================================================================

    test(
        'iOS continued task bridge: submit while running, progress on steps, '
        'complete when no running tasks remain', () async {
      IosContinuedTaskService.debugForceSupported = true;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.johntsui.stroom/ios_continued_task'),
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      // 等待未等待（fire-and-forget）的通道调用落盘。
      Future<void> flush() =>
          Future<void>.delayed(const Duration(milliseconds: 20));

      final notifier = BackgroundTaskNotifier();

      // 任务启动（running）→ 提交常驻任务 + 上报进度（0 步完成）。
      final id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'OCR任务');
      await flush();
      expect(calls.where((c) => c.method == 'submit'), hasLength(1));
      expect(calls.where((c) => c.method == 'updateProgress'), isNotEmpty);

      // 步骤完成 → 继续上报进度。
      calls.clear();
      notifier.updateStep(id, 0, completed: true);
      await flush();
      expect(
        calls.where((c) => c.method == 'submit'),
        hasLength(1),
        reason: '任务仍在运行，常驻任务保持提交（幂等）',
      );
      final progress =
          calls.where((c) => c.method == 'updateProgress').toList();
      expect(progress, isNotEmpty);
      expect((progress.last.arguments as Map)['percent'], greaterThan(0));

      // 新增第二个任务会稀释占比，但上报进度必须单调不降。
      calls.clear();
      final id2 = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '第二个任务',
      );
      await flush();
      final progress2 =
          calls.where((c) => c.method == 'updateProgress').toList();
      expect(progress2, isNotEmpty);
      final prev = (progress.last.arguments as Map)['percent'] as int;
      final now = (progress2.last.arguments as Map)['percent'] as int;
      expect(now, greaterThanOrEqualTo(prev), reason: '系统进度条不允许回退');

      // 所有任务完成 → 没有运行中的任务 → 结束常驻任务。
      // （completeTask(id) 时 id2 仍在运行，中间态会合法地再提交一次，
      // 因此这里只断言 complete 被调用；"完成后不再有调用"由
      // 周期同步定时器测试覆盖。）
      calls.clear();
      notifier.completeTask(id);
      notifier.completeTask(id2);
      await flush();
      expect(calls.where((c) => c.method == 'complete'), hasLength(1));
    });

    test(
      'iOS continued task bridge: periodic sync keeps reporting progress '
      'while a task is running (long steps must not stall the system UI)',
      () {
        IosContinuedTaskService.debugForceSupported = true;
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.johntsui.stroom/ios_continued_task'),
          (MethodCall call) async {
            calls.add(call);
            return null;
          },
        );

        fakeAsync((async) {
          final notifier = BackgroundTaskNotifier();
          final id = notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: '长步骤任务',
          );
          async.flushMicrotasks();

          // 周期定时器（30s）在任务运行期间持续重报进度。
          calls.clear();
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();
          expect(
            calls.where((c) => c.method == 'updateProgress'),
            isNotEmpty,
            reason: '长步骤期间也要周期性上报进度，防止系统判定任务停滞',
          );
          calls.clear();
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();
          expect(calls.where((c) => c.method == 'updateProgress'), isNotEmpty);

          // 任务完成后定时器停止，不再产生任何调用。
          notifier.completeTask(id);
          async.flushMicrotasks();
          calls.clear();
          async.elapse(const Duration(seconds: 90));
          async.flushMicrotasks();
          expect(calls, isEmpty, reason: '没有运行中任务时不得周期重报');

          notifier.dispose();
        });
      },
    );

    test(
      'failed retry data replacement keeps persisted retry audio referenced',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final persistedReference = await store.save(
          Uint8List.fromList([1, 2, 3]),
          name: 'persisted-owner.wav',
          format: 'wav',
        );
        final replacementReference = await store.save(
          Uint8List.fromList([4, 5, 6]),
          name: 'replacement-owner.wav',
          format: 'wav',
        );
        await store.releaseProtection(persistedReference);
        await store.releaseProtection(replacementReference);
        const taskId = 'failed-retry-data-replacement-owner';
        Map<String, dynamic> retryData(AsrAudioReference reference) => {
              'version': 2,
              'audioReferences': [
                {
                  'audioReference': reference.toMap(),
                  'chunks': <dynamic>[],
                },
              ],
            };
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Persisted retry audio owner',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: retryData(persistedReference),
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            throw StateError('simulated retry-data replacement failure');
          };

          final restoredTask = notifier.taskById(taskId)!;
          expect(
            await notifier.setRetryDataAndWaitForGeneration(
              taskId,
              restoredTask,
              retryData(replacementReference),
            ),
            isFalse,
          );

          expect(
            notifier.retryAudioReferencedIds,
            contains(persistedReference.id),
            reason: 'the failed snapshot leaves the original task row on disk',
          );
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(persistedReference), isNotNull);
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'failed retry data clear keeps persisted retry audio referenced',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([7, 8, 9]),
          name: 'persisted-clear-owner.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        const taskId = 'failed-retry-data-clear-owner';
        final task = BackgroundTask(
          id: taskId,
          type: BackgroundTaskType.asr,
          title: 'Persisted retry audio owner',
          status: TaskStatus.failed,
          createdAt: DateTime.utc(2026),
          retryData: {
            'version': 2,
            'audioReferences': [
              {
                'audioReference': reference.toMap(),
                'chunks': <dynamic>[],
              },
            ],
          },
        );
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([task.toMap()]));

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isTrue);
          await notifier.pendingPersistence;
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = () async {
            throw StateError('simulated retry-data clear failure');
          };

          expect(
            await notifier.clearRetryDataForGeneration(
              taskId,
              notifier.taskById(taskId)!,
            ),
            isFalse,
          );

          expect(notifier.retryAudioReferencedIds, contains(reference.id));
          await store.prune(() => notifier.retryAudioReferencedIds);
          expect(await store.load(reference), isNotNull);
        } finally {
          BackgroundTaskNotifier.debugBeforeTaskSnapshotWrite = null;
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'scalar ASR retry paths keep audio ownership unresolved after a snapshot',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([12, 13, 14]),
          name: 'scalar-retry-path-owner.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'scalar-retry-path-owner',
              'type': BackgroundTaskType.asr.name,
              'title': 'Scalar retry path owner',
              'status': TaskStatus.failed.name,
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': '/cache/${reference.id}.audio',
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isFalse);

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Trigger snapshot after scalar retry restore',
            startImmediately: false,
          );
          await notifier.pendingPersistence;

          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(
            await store.load(reference),
            isNotNull,
            reason: 'the unrecognized retry path still owns the audio file',
          );
          expect(
            notifier.retryAudioCleanupSafe,
            isFalse,
            reason: 'unknown scalar retry ownership must not be retired',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'malformed skipped ASR scalar retry paths keep cleanup disabled after a snapshot',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([21, 22, 23]),
          name: 'malformed-scalar-retry-owner.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode([
            {
              'id': 'dddddddddddddddddddddddddddddddd',
              'type': BackgroundTaskType.asr.name,
              'title': 'Malformed scalar retry owner',
              'status': 'not a task status',
              'createdAt': DateTime.utc(2026).toIso8601String(),
              'retryData': '/cache/${reference.id}.audio',
            },
          ]),
        );

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isFalse);

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Trigger snapshot after malformed scalar retry restore',
            startImmediately: false,
          );
          await notifier.pendingPersistence;

          final persistedRows = jsonDecode(await file.readAsString()) as List;
          expect(
            persistedRows.whereType<Map>().any(
                  (row) =>
                      row['title'] ==
                      'Trigger snapshot after malformed scalar retry restore',
                ),
            isTrue,
            reason: 'the partial snapshot must complete before cleanup changes',
          );
          expect(
            persistedRows.whereType<Map>().any(
                  (row) => row['retryData'] == '/cache/${reference.id}.audio',
                ),
            isTrue,
            reason: 'the malformed row is preserved in the rewritten snapshot',
          );

          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(
            await store.load(reference),
            isNotNull,
            reason: 'the skipped malformed row still owns the audio file',
          );
          expect(
            notifier.retryAudioCleanupSafe,
            isFalse,
            reason: 'unknown scalar retry ownership must remain unresolved',
          );
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'preserved skipped ASR audio rows keep cleanup disabled after a snapshot',
      () async {
        WebFileStore.enableTestMode();
        final store = AsrRetryAudioStore();
        final reference = await store.save(
          Uint8List.fromList([9, 10, 11]),
          name: 'skipped-row-owner.wav',
          format: 'wav',
        );
        await store.releaseProtection(reference);
        final skippedRow = <String, dynamic>{
          'id': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'type': 'asr',
          'title': 'Malformed legacy audio owner',
          'status': 'not a status',
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'audioReference': '/recordings/${reference.id}.wav',
        };
        final file = _tasksFileIn(testDir.path);
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode([skippedRow]));

        final notifier = BackgroundTaskNotifier();
        try {
          expect(await notifier.restoreFromPersistence(), isFalse);
          expect(notifier.retryAudioCleanupSafe, isFalse);

          notifier.addTask(
            type: BackgroundTaskType.asr,
            title: 'Trigger safe partial snapshot',
            startImmediately: false,
          );
          await notifier.pendingPersistence;

          expect(
            await file.readAsString(),
            contains('/recordings/${reference.id}.wav'),
          );
          expect(
            notifier.retryAudioCleanupSafe,
            isFalse,
            reason: 'the preserved row still owns audio outside retryData',
          );
          if (notifier.retryAudioCleanupSafe) {
            await store.prune(() => notifier.retryAudioReferencedIds);
          }
          expect(await store.load(reference), isNotNull);
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
          WebFileStore.disableTestMode();
        }
      },
    );

    test(
      'iOS continued task bridge: no channel calls when not supported',
      () async {
        // debugForceSupported 保持 false（setUp 已重置）。
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.johntsui.stroom/ios_continued_task'),
          (MethodCall call) async {
            calls.add(call);
            return null;
          },
        );

        final notifier = BackgroundTaskNotifier();
        final id = notifier.addTask(
          type: BackgroundTaskType.ocr,
          title: 'OCR任务',
        );
        notifier.updateStep(id, 0, completed: true);
        notifier.completeTask(id);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(calls, isEmpty, reason: '非 iOS 平台（或 iOS < 26）不得触发任何桥接调用');
      },
    );
  });
}
