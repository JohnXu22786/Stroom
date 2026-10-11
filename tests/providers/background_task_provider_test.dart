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
      // iOS 常驻任务桥接默认关闭（测试机非 iOS）。
      IosContinuedTaskService.debugForceSupported = false;
    });

    tearDown(() async {
      BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
      BackgroundTaskNotifier.debugBeforeOcrCacheCleanup = null;
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
        expect(retryData['version'], 2);
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
      'restore drops legacy retry bodies when cache migration fails',
      () async {
        final bytes = Uint8List.fromList(List<int>.filled(64 * 1024, 0x5a));
        final encodedBytes = base64Encode(bytes);
        final taskFile = _tasksFileIn(testDir.path);
        await taskFile.parent.create(recursive: true);
        await taskFile.writeAsString(
          jsonEncode([
            {
              'id': '',
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
                    'format': 'png',
                    'name': 'receipt.png',
                  },
                ],
              },
            },
          ]),
        );
        final notifier = BackgroundTaskNotifier();
        try {
          await notifier.restoreFromPersistence();
          final task = notifier.state.single;
          final snapshot = OcrRetrySnapshot.fromMap(task.retryData!);

          expect(task.retryData!['version'], OcrRetrySnapshot.currentVersion);
          expect(snapshot.imageEntryCount, 1);
          expect(snapshot.instructionContent, 'Read the receipt total');
          expect(snapshot.images.single.bytes, isNull);
          expect(
            await OcrRetryStorage.restoreImages(snapshot),
            isA<OcrRetryRestoreResult>().having(
              (result) => result.isComplete,
              'complete image set',
              isFalse,
            ),
          );

          notifier.updateStep('', 0, completed: true);
          await notifier.pendingPersistence;
          final persisted = await taskFile.readAsString();
          expect(persisted, isNot(contains(encodedBytes)));
          expect(persisted, isNot(contains('"bytes"')));
        } finally {
          notifier.dispose();
          await notifier.pendingPersistence;
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
          'headers': {'Authorization': 'Bearer opaque-u...t-87'},
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

    test('legacy OCR diagnostics omit unverified finish reasons', () {
      const apiKey = 'opaque-user-secret-87';
      final task = BackgroundTask.fromMap({
        'id': 'legacy-ocr-opaque-finish-reason',
        'type': 'ocr',
        'title': '旧版 OCR 任务',
        'status': 'failed',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
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

      expect(task.rawResponse, {'statusCode': 401});
      expect(persisted, isNot(contains(apiKey)));
    });

    test('OCR task error sanitizer preserves safe Dio failure types', () {
      const safeError = 'OCR 请求失败（connectionTimeout）';
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
    });

    test('legacy OCR task and step errors redact response bodies on load', () {
      final apiKey = 'AIza${List.filled(35, 'a').join()}';
      final imageData = base64Encode(List<int>.filled(256, 65));
      final legacyError =
          'OCR识别失败: Exception: 请求失败 (HTTP 401): '
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
      const unsafeError =
          'Incorrect API key provided: '
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
      const unsafeError =
          'Incorrect API key provided: '
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
          expect(retryData!['version'], 2);
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
            )).isComplete,
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

          expect(restored.retryData!['version'], 2);
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
        final cachedReference =
            ((retryData['images'] as List).single as Map)['storageRef']
                as String;
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
          cachedReference =
              ((retryData['images'] as List).single as Map)['storageRef']
                  as String;
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

    test('iOS continued task bridge: submit while running, progress on steps, '
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
      final progress = calls
          .where((c) => c.method == 'updateProgress')
          .toList();
      expect(progress, isNotEmpty);
      expect((progress.last.arguments as Map)['percent'], greaterThan(0));

      // 新增第二个任务会稀释占比，但上报进度必须单调不降。
      calls.clear();
      final id2 = notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: '第二个任务',
      );
      await flush();
      final progress2 = calls
          .where((c) => c.method == 'updateProgress')
          .toList();
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
