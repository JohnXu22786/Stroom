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
          'opaque-query-secret-87'
        ),
        (
          'https://user:oauth-userinfo-secret@ocr.test/v1',
          'oauth-userinfo-secret'
        ),
        (
          'https://ocr.test/v1?access_token=opaque-token-secret-87',
          'opaque-token-secret-87'
        ),
        (
          'https://ocr.test/v1?secretKey=opaque-secret-key-191',
          'opaque-secret-key-191'
        ),
        (
          'https://ocr.test/v1?privateKey=opaque-private-key-191',
          'opaque-private-key-191'
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
          'rawResponse': {
            'statusCode': 401,
            'requestId': credential,
          },
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
                    'image_url': {
                      'url': 'data:image/png;base64,aGVsbG8=',
                    },
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
        {
          'label': 'OCR request',
          'status': 'failed',
          'error': 'OCR 错误详情已隐藏',
        },
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

    test('legacy diagnostics skip excluded ID before a later safe candidate',
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
    });

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
            'data': {
              'request_id': apiKey,
              'requestId': safeRequestId,
            },
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

      expect(task.rawResponse, {
        'statusCode': 401,
        'requestId': safeRequestId,
      });
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

          expect(notifier.taskById('new-task-with-unsafe-skipped-neighbor'),
              isNotNull);
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
            images: [
              OcrRetryImage(bytes: skippedImageBytes, format: 'png'),
            ],
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
          expect(notifier.taskById('valid-sibling-after-partial-restore'),
              isNotNull);
          expect(notifier.state.map((task) => task.id), [
            'valid-sibling-after-partial-restore',
          ]);
          expect(await OcrRetryStorage.read(skippedCacheReference),
              skippedImageBytes);
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
          expect(await OcrRetryStorage.read(skippedCacheReference),
              skippedImageBytes);
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
              restarted.taskById('new-asr-after-partial-restore'), isNotNull);
          expect(restarted.taskById('valid-asr-sibling'), isNotNull);
        } finally {
          restarted.dispose();
          await restarted.pendingPersistence;
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
          expect(restarted.taskById('task-blocked-by-unsafe-skipped-snapshot'),
              isNull);
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
              await OcrRetryStorage.read(cacheReference as String), imageBytes);
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
                const Duration(milliseconds: 100), () => false),
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
        await file
            .writeAsString(jsonEncode([persistedTask.toMap(), skippedRow]));

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
            (jsonDecode(
              await _tasksFileIn(testDir.path).readAsString(),
            ) as List)
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
            (jsonDecode(
              await _tasksFileIn(testDir.path).readAsString(),
            ) as List)
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
          expect(
            persisted.whereType<Map>().map((row) => row['id']),
            [taskId],
          );
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
          expect(
            persisted.whereType<Map>().map((row) => row['id']),
            [queuedTaskId],
          );
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
            (jsonDecode(
              await _tasksFileIn(testDir.path).readAsString(),
            ) as List)
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
          final persistedIds = (jsonDecode(
            await _tasksFileIn(testDir.path).readAsString(),
          ) as List)
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
    test(
      'failed removal retry keeps a same-ID replacement task',
      () async {
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
              jsonDecode(await _tasksFileIn(testDir.path).readAsString())
                  as List;
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
      },
    );
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
