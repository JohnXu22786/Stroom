import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/services/background_service.dart';
import 'package:stroom/services/storage_service.dart';

class _TestDocuments extends PathProviderPlatform {
  _TestDocuments(this.path);

  final String path;
  Completer<void>? firstRequestStarted;
  Completer<void>? releaseFirstRequest;
  int pathRequests = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    pathRequests++;
    if (pathRequests == 1) {
      final started = firstRequestStarted;
      if (started != null && !started.isCompleted) started.complete();
      await releaseFirstRequest?.future;
    }
    return path;
  }
}

class _BackgroundServicePlatform extends FlutterBackgroundServicePlatform {
  bool running = false;
  int stopCalls = 0;
  int startCalls = 0;
  bool startResult = true;
  bool? runningAfterStart;
  Object? startError;
  Completer<void>? stopRequested;
  Completer<void>? secondStopRequested;
  Completer<void>? releaseStop;
  Completer<void>? startEntered;
  Completer<void>? releaseStart;

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async =>
      true;

  @override
  Future<bool> start() async {
    startCalls++;
    running = true;
    final entered = startEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    await releaseStart?.future;
    if (startError != null) throw startError!;
    running = runningAfterStart ?? startResult;
    return startResult;
  }

  @override
  Future<bool> isServiceRunning() async => running;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    if (method == 'stopService') {
      stopCalls++;
      final pending = stopRequested;
      if (pending != null && !pending.isCompleted) pending.complete();
      final secondPending = secondStopRequested;
      if (stopCalls == 2 &&
          secondPending != null &&
          !secondPending.isCompleted) {
        secondPending.complete();
      }
      final release = releaseStop;
      if (release == null) {
        running = false;
      } else {
        unawaited(release.future.then((_) {
          running = false;
        }));
      }
    }
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
}

class _FailingEnabledPreferenceStore extends InMemorySharedPreferencesStore {
  _FailingEnabledPreferenceStore(Map<String, Object> data)
      : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (valueType == 'Bool' && key == 'flutter.background_service_enabled') {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _CleanupCatCatchNotifier extends CatCatchNotifier {
  _CleanupCatCatchNotifier(super.ref);

  final executorStarted = Completer<void>();
  final secondExecutorStarted = Completer<void>();
  int executorStarts = 0;

  void setTasksForTest(List<CatCatchTask> tasks) => state = tasks;

  List<CatCatchTask> get tasksForTest => state;

  @override
  Future<String?> executeTaskForTask({
    required CatCatchTask task,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) async {
    executorStarts++;
    onUpdate(task.copyWith(status: TaskStatus.running));
    if (!executorStarted.isCompleted) executorStarted.complete();
    if (executorStarts == 2 && !secondExecutorStarted.isCompleted) {
      secondExecutorStarted.complete();
    }
    return null;
  }

  @override
  Future<String?> retryFromStepForTask({
    required CatCatchTask task,
    required StepType fromStep,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) async {
    executorStarts++;
    onUpdate(task.copyWith(status: TaskStatus.running));
    if (!executorStarted.isCompleted) executorStarted.complete();
    if (executorStarts == 2 && !secondExecutorStarted.isCompleted) {
      secondExecutorStarted.complete();
    }
    return null;
  }
}

Future<CatCatchTask?> _waitForPersistedTaskForTest(
  Directory directory,
  String taskId,
) async {
  final file = File('${directory.path}/catcatch/tasks.json');
  final timeout = Stopwatch()..start();
  while (timeout.elapsed < const Duration(seconds: 5)) {
    if (await file.exists()) {
      final tasks = (jsonDecode(await file.readAsString()) as List).map(
        (task) => CatCatchTask.fromMap(
          Map<String, dynamic>.from(task as Map),
        ),
      );
      for (final task in tasks) {
        if (task.id == taskId && task.status == TaskStatus.failed) {
          return task;
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatCatchNotifier background service ownership', () {
    late Directory directory;
    late _TestDocuments documents;
    late _BackgroundServicePlatform servicePlatform;
    late PathProviderPlatform originalPathProvider;
    late ProviderContainer container;
    late _CleanupCatCatchNotifier notifier;
    late SharedPreferences preferences;
    late TargetPlatform? originalTargetPlatform;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      resetBackgroundServiceLifecycleStateForTesting();
      originalPathProvider = PathProviderPlatform.instance;
      originalTargetPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      servicePlatform = _BackgroundServicePlatform();
      FlutterBackgroundServicePlatform.instance = servicePlatform;
      directory = await Directory.systemTemp.createTemp('catcatch_service_');
      documents = _TestDocuments(directory.path);
      PathProviderPlatform.instance = documents;
      AppStorage.resetCache();
      container = ProviderContainer(overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          notifier = _CleanupCatCatchNotifier(ref);
          return notifier;
        }),
      ]);
      container.read(catcatchTasksProvider);
      preferences = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      container.dispose();
      PathProviderPlatform.instance = originalPathProvider;
      debugDefaultTargetPlatformOverride = originalTargetPlatform;
      AppStorage.resetCache();
      await directory.delete(recursive: true);
    });

    CatCatchTask task(String id) => CatCatchTask(
          id: id,
          url: 'https://example.com/video.mp4',
          expectedDurationSec: 30,
          status: TaskStatus.paused,
          createdAt: DateTime(2025, 1, 1),
        );

    test('new tasks await temporary service startup before execution',
        () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();

      try {
        notifier.addTask('invalid://task-start-guard', 30, taskId: 'new-task');
        await Future.any([
          servicePlatform.startEntered!.future,
          notifier.executorStarted.future,
        ]).timeout(const Duration(seconds: 2));

        expect(servicePlatform.startEntered!.isCompleted, isTrue);
        expect(notifier.executorStarts, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);

        servicePlatform.releaseStart!.complete();
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
      } finally {
        if (!servicePlatform.releaseStart!.isCompleted) {
          servicePlatform.releaseStart!.complete();
        }
        await notifier.removeTasksPersisted(['new-task']);
      }
    });

    test('resumed tasks await temporary service startup before execution',
        () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();
      final resumed = task('resumed-task').copyWith(
        steps: StepType.values.map(StepStatus.pending).toList(),
      );
      notifier.setTasksForTest([resumed]);

      try {
        notifier.resumeTask('resumed-task');
        await Future.any([
          servicePlatform.startEntered!.future,
          notifier.executorStarted.future,
        ]).timeout(const Duration(seconds: 2));

        expect(servicePlatform.startEntered!.isCompleted, isTrue);
        expect(notifier.executorStarts, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);

        servicePlatform.releaseStart!.complete();
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
      } finally {
        if (!servicePlatform.releaseStart!.isCompleted) {
          servicePlatform.releaseStart!.complete();
        }
        await notifier.removeTasksPersisted(['persistence-drain']);
      }
    });

    test('new task startup failure is persisted and can be retried', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-new-task' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );

      try {
        notifier.addTask(
          'invalid://failed-new-task',
          30,
          taskId: 'failed-new-task',
        );
        final failure = await failed.future.timeout(
          const Duration(seconds: 2),
        );

        expect(failure.error, contains('后台服务启动失败'));
        expect(notifier.executorStarts, 0);
        expect(servicePlatform.startCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);
        expect(await isWatchdogEnabled(), isTrue);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);
        expect(
            await _waitForPersistedTaskForTest(
              directory,
              'failed-new-task',
            ),
            isA<CatCatchTask>().having(
              (task) => task.status,
              'persisted status',
              TaskStatus.failed,
            ));

        final retryFailed = Completer<CatCatchTask>();
        final retrySubscription = container.listen<List<CatCatchTask>>(
          catcatchTasksProvider,
          (_, tasks) {
            for (final current in tasks) {
              if (current.id == 'failed-new-task' &&
                  current.status == TaskStatus.failed &&
                  !retryFailed.isCompleted) {
                retryFailed.complete(current);
              }
            }
          },
        );
        servicePlatform.running = false;
        servicePlatform.runningAfterStart = false;
        notifier.retryTask('failed-new-task');
        await retryFailed.future.timeout(const Duration(seconds: 2));
        retrySubscription.close();

        expect(servicePlatform.startCalls, 2);
        expect(notifier.executorStarts, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);
        expect(servicePlatform.stopCalls, 0);
      } finally {
        subscription.close();
        await notifier.removeTasksPersisted(['failed-new-task']);
      }
    });

    test('resumed task start exception is persisted without entering executor',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', true);
      servicePlatform.startError = StateError('native start failed');
      final resumed = task('failed-resumed-task').copyWith(
        steps: StepType.values.map(StepStatus.pending).toList(),
      );
      notifier.setTasksForTest([resumed]);
      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-resumed-task' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );

      try {
        notifier.resumeTask('failed-resumed-task');
        final failure = await failed.future.timeout(
          const Duration(seconds: 2),
        );

        expect(failure.error, contains('后台服务启动失败'));
        expect(notifier.executorStarts, 0);
        expect(servicePlatform.startCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isTrue);
        expect(await isWatchdogEnabled(), isTrue);
        expect(servicePlatform.stopCalls, 0);
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'failed-resumed-task',
        );
        expect(persisted?.status, TaskStatus.failed);
        expect(persisted?.error, contains('后台服务启动失败'));

        final retryFailed = Completer<CatCatchTask>();
        final retrySubscription = container.listen<List<CatCatchTask>>(
          catcatchTasksProvider,
          (_, tasks) {
            for (final current in tasks) {
              if (current.id == 'failed-resumed-task' &&
                  current.status == TaskStatus.failed &&
                  !retryFailed.isCompleted) {
                retryFailed.complete(current);
              }
            }
          },
        );
        servicePlatform.running = false;
        notifier.retryStep('failed-resumed-task', StepType.fetching);
        await retryFailed.future.timeout(const Duration(seconds: 2));
        retrySubscription.close();

        expect(servicePlatform.startCalls, 2);
        expect(notifier.executorStarts, 0);
        expect(preferences.getBool('background_service_enabled'), isTrue);
        expect(servicePlatform.stopCalls, 0);
      } finally {
        subscription.close();
        await notifier.removeTasksPersisted(['failed-resumed-task']);
      }
    });

    test('startup failure does not stop service for a queued idle write',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      documents.firstRequestStarted = Completer<void>();
      documents.releaseFirstRequest = Completer<void>();
      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-after-idle-write' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );

      try {
        notifier.removeTask('absent-task');
        await documents.firstRequestStarted!.future.timeout(
          const Duration(seconds: 2),
        );
        notifier.addTask(
          'invalid://failed-after-idle-write',
          30,
          taskId: 'failed-after-idle-write',
        );
        await failed.future.timeout(const Duration(seconds: 2));

        expect(notifier.executorStarts, 0);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);

        documents.releaseFirstRequest!.complete();
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'failed-after-idle-write',
        );
        expect(persisted?.status, TaskStatus.failed);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
        await notifier.removeTasksPersisted(['failed-after-idle-write']);
      }
    });

    test('startup failure invalidates a queued removal cleanup', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      documents.firstRequestStarted = Completer<void>();
      documents.releaseFirstRequest = Completer<void>();
      notifier.setTasksForTest([task('queued-removal')]);
      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-during-removal' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );
      Future<bool>? pendingRemoval;

      try {
        pendingRemoval = notifier.removeTasksPersisted(['queued-removal']);
        await documents.firstRequestStarted!.future.timeout(
          const Duration(seconds: 2),
        );
        notifier.addTask(
          'invalid://failed-during-removal',
          30,
          taskId: 'failed-during-removal',
        );
        await failed.future.timeout(const Duration(seconds: 2));

        expect(notifier.executorStarts, 0);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);

        documents.releaseFirstRequest!.complete();
        expect(await pendingRemoval, isTrue);
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'failed-during-removal',
        );
        expect(persisted?.status, TaskStatus.failed);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
        if (pendingRemoval != null) await pendingRemoval;
        await notifier.removeTasksPersisted(['failed-during-removal']);
      }
    });

    test('unsupported platforms continue tasks when service start fails',
        () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;

      try {
        notifier.addTask(
          'invalid://unsupported-service',
          30,
          taskId: 'unsupported-service',
        );
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        expect(notifier.executorStarts, 1);
        expect(servicePlatform.startCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);

        notifier.setTasksForTest([
          ...notifier.tasksForTest,
          task('unsupported-resumed-task').copyWith(
            steps: StepType.values.map(StepStatus.pending).toList(),
          ),
        ]);
        notifier.resumeTask('unsupported-resumed-task');
        await notifier.secondExecutorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        expect(notifier.executorStarts, 2);
        expect(servicePlatform.startCalls, 2);
      } finally {
        await notifier.removeTasksPersisted([
          'unsupported-service',
          'unsupported-resumed-task',
        ]);
      }
    });

    test('media selection awaits temporary service startup before continuing',
        () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();
      final selecting = task('selected-task').copyWith(
        steps: StepType.values.map((type) {
          return type == StepType.userSelecting
              ? StepStatus.running(type)
              : StepStatus.pending(type);
        }).toList(),
      );
      notifier.setTasksForTest([selecting]);

      try {
        notifier.selectMedia(
          'selected-task',
          MediaResource(
            url: 'https://example.com/video.mp4',
            name: 'video',
            ext: 'mp4',
            initiator: 'https://example.com',
            isPlayable: true,
          ),
        );
        await Future.any([
          servicePlatform.startEntered!.future,
          notifier.executorStarted.future,
        ]).timeout(const Duration(seconds: 2));

        expect(servicePlatform.startEntered!.isCompleted, isTrue);
        expect(notifier.executorStarts, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);

        servicePlatform.releaseStart!.complete();
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
      } finally {
        if (!servicePlatform.releaseStart!.isCompleted) {
          servicePlatform.releaseStart!.complete();
        }
        await notifier.removeTasksPersisted(['persistence-drain']);
      }
    });

    test('persisted removal preserves a user-enabled service', () async {
      await preferences.setBool('background_service_enabled', true);
      await notifier.startBackgroundServiceForTask();
      notifier.setTasksForTest([task('persistent-remove')]);

      expect(
          await notifier.removeTasksPersisted(['persistent-remove']), isTrue);

      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('ordinary cleanup preserves a user-enabled service', () async {
      await preferences.setBool('background_service_enabled', true);
      await notifier.startBackgroundServiceForTask();
      notifier.setTasksForTest([task('persistent-ordinary')]);

      notifier.removeTask('persistent-ordinary');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('ordinary cleanup stops a CatCatch-only service without persisting it',
        () async {
      await preferences.setBool('background_service_enabled', false);
      await notifier.startBackgroundServiceForTask();
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isFalse);

      servicePlatform.stopRequested = Completer<void>();
      notifier.setTasksForTest([task('temporary-ordinary')]);
      notifier.removeTask('temporary-ordinary');
      await servicePlatform.stopRequested!.future.timeout(
        const Duration(seconds: 2),
      );

      expect(servicePlatform.stopCalls, 1);
      expect(servicePlatform.running, isFalse);
      expect(preferences.getBool('background_service_enabled'), isFalse);
    });

    test('persisted cleanup still stops a temporary service', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.running = true;
      notifier.setTasksForTest([task('temporary-persisted')]);

      expect(
          await notifier.removeTasksPersisted(['temporary-persisted']), isTrue);

      expect(servicePlatform.stopCalls, 1);
      expect(servicePlatform.running, isFalse);
      expect(preferences.getBool('background_service_enabled'), isFalse);
    });

    test('cleanup queued during confirm-and-continue startup keeps service',
        () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();
      const startingTaskId = 'confirm-start';
      const cleanupTaskId = 'cleanup-during-start';
      notifier.setTasksForTest([task(startingTaskId), task(cleanupTaskId)]);

      addTearDown(() {
        final release = servicePlatform.releaseStart;
        if (release != null && !release.isCompleted) release.complete();
      });

      final removedTask = Completer<void>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          if (!tasks.any((current) => current.id == cleanupTaskId) &&
              !removedTask.isCompleted) {
            removedTask.complete();
          }
        },
      );
      addTearDown(subscription.close);

      notifier.confirmAndContinue(startingTaskId);
      await servicePlatform.startEntered!.future.timeout(
        const Duration(seconds: 2),
      );
      final statusWhileStarting = notifier.tasksForTest
          .singleWhere((current) => current.id == startingTaskId)
          .status;

      final cleanup = notifier.removeTasksPersisted([cleanupTaskId]);
      await removedTask.future.timeout(const Duration(seconds: 2));
      servicePlatform.releaseStart!.complete();

      expect(await cleanup, isTrue);
      await notifier.executorStarted.future.timeout(
        const Duration(seconds: 2),
      );
      // Absent IDs still persist, which drains the executor's fire-and-forget
      // snapshot before tearDown removes its documents directory.
      await notifier.removeTasksPersisted(['persistence-drain']);

      expect(statusWhileStarting, TaskStatus.running);
      expect(notifier.executorStarts, 1);
      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isFalse);
    });

    test('concurrent confirms wait for an in-flight service start', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();
      notifier.setTasksForTest([task('first-confirm'), task('second-confirm')]);

      notifier.confirmAndContinue('first-confirm');
      await servicePlatform.startEntered!.future.timeout(
        const Duration(seconds: 2),
      );
      notifier.confirmAndContinue('second-confirm');
      final executorStartsBeforeServiceReady = notifier.executorStarts;

      servicePlatform.releaseStart!.complete();
      await notifier.secondExecutorStarted.future.timeout(
        const Duration(seconds: 2),
      );
      await notifier.removeTasksPersisted(['persistence-drain']);

      expect(executorStartsBeforeServiceReady, 0);
      expect(notifier.executorStarts, 2);
      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isFalse);
    });

    test('rejected user start preference write does not start service',
        () async {
      await preferences.setBool('background_service_enabled', false);
      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingEnabledPreferenceStore({
        'flutter.background_service_enabled': false,
      });
      try {
        await preferences.reload();
        expect(await startBackgroundService(), isFalse);
        await preferences.reload();
        expect(preferences.getBool('background_service_enabled'), isFalse);

        notifier.setTasksForTest([task('failed-preference-write')]);
        expect(
          await notifier.removeTasksPersisted(['failed-preference-write']),
          isTrue,
        );

        expect(servicePlatform.startCalls, 0);
        expect(servicePlatform.stopCalls, 0);
        expect(servicePlatform.running, isFalse);
      } finally {
        SharedPreferencesStorePlatform.instance = originalStore;
      }
    });

    test('cleanup honors an explicit stop when persisting it fails', () async {
      await preferences.setBool('background_service_enabled', true);
      expect(await startBackgroundService(), isTrue);

      final originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = _FailingEnabledPreferenceStore({
        'flutter.background_service_enabled': true,
      });
      try {
        await preferences.reload();
        expect(await stopBackgroundService(), isTrue);
        await preferences.reload();
        expect(preferences.getBool('background_service_enabled'), isTrue);
        expect(servicePlatform.running, isFalse);

        expect(await notifier.startBackgroundServiceForTask(), isTrue);
        notifier.setTasksForTest([task('failed-disable-write')]);
        expect(
          await notifier.removeTasksPersisted(['failed-disable-write']),
          isTrue,
        );

        expect(servicePlatform.stopCalls, 2);
        expect(servicePlatform.running, isFalse);
      } finally {
        SharedPreferencesStorePlatform.instance = originalStore;
      }
    });

    test('cleanup does not race a concurrent user-enabled start', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();

      final start = startBackgroundService();
      await servicePlatform.startEntered!.future.timeout(
        const Duration(seconds: 2),
      );
      notifier.setTasksForTest([task('concurrent-start')]);
      final cleanup = notifier.removeTasksPersisted(['concurrent-start']);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      servicePlatform.releaseStart!.complete();

      expect(await start, isTrue);
      expect(await cleanup, isTrue);
      expect(servicePlatform.stopCalls, 0);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('a user start waits for an in-flight CatCatch cleanup stop', () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.running = true;
      servicePlatform.stopRequested = Completer<void>();
      servicePlatform.releaseStop = Completer<void>();
      notifier.setTasksForTest([task('cleanup-before-start')]);

      final cleanup = notifier.removeTasksPersisted(['cleanup-before-start']);
      await servicePlatform.stopRequested!.future.timeout(
        const Duration(seconds: 2),
      );
      final start = startBackgroundService();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(preferences.getBool('background_service_enabled'), isFalse);
      expect(servicePlatform.running, isTrue);

      servicePlatform.releaseStop!.complete();
      expect(await cleanup, isTrue);
      expect(await start, isTrue);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });

    test('a user start reconciles a timed-out stop before reporting active',
        () async {
      expect(await startBackgroundService(), isTrue);
      servicePlatform.stopRequested = Completer<void>();
      servicePlatform.secondStopRequested = Completer<void>();
      servicePlatform.releaseStop = Completer<void>();

      final stop = stopBackgroundService();
      await servicePlatform.stopRequested!.future.timeout(
        const Duration(seconds: 2),
      );
      final result = await stop.timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          servicePlatform.releaseStop!.complete();
          return stop;
        },
      );

      expect(result, isFalse);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);

      var startCompleted = false;
      final start = startBackgroundService().then((result) {
        startCompleted = true;
        return result;
      });
      try {
        await servicePlatform.secondStopRequested!.future.timeout(
          const Duration(seconds: 2),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(startCompleted, isFalse);
        expect(servicePlatform.startCalls, 1);
        servicePlatform.releaseStop!.complete();
        expect(await start, isTrue);
      } finally {
        if (!servicePlatform.releaseStop!.isCompleted) {
          servicePlatform.releaseStop!.complete();
        }
      }

      expect(servicePlatform.startCalls, 2);
      expect(servicePlatform.running, isTrue);
      expect(preferences.getBool('background_service_enabled'), isTrue);
    });
  });
}
