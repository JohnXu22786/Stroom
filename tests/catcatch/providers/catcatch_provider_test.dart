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
  Completer<void>? releaseAllRequests;
  int pathRequests = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    pathRequests++;
    if (pathRequests == 1) {
      final started = firstRequestStarted;
      if (started != null && !started.isCompleted) started.complete();
      await releaseFirstRequest?.future;
    }
    await releaseAllRequests?.future;
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
  bool holdRetryExecutions = false;
  bool holdTaskExecutions = false;
  Object? taskExecutionError;
  Object? retryExecutionError;
  final retryCancelTokens = <CancelToken>[];
  final retryReleases = <Completer<void>>[];
  final retryCompletions = <Completer<void>>[];
  final taskCancelTokens = <CancelToken>[];
  final taskReleases = <Completer<void>>[];
  final taskCompletions = <Completer<void>>[];
  CatCatchTask? lastExecutedTask;
  CatCatchTask? lastRetriedTask;
  void Function(CatCatchTask)? lastTaskUpdate;
  void Function(CatCatchTask)? lastRetryTaskUpdate;
  final uncancelledTaskCompletions = <String>[];

  void setTasksForTest(List<CatCatchTask> tasks) => state = tasks;

  List<CatCatchTask> get tasksForTest => state;

  @override
  Future<String?> executeTaskForTask({
    required CatCatchTask task,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) async {
    executorStarts++;
    lastExecutedTask = task;
    lastTaskUpdate = onUpdate;
    onUpdate(task.copyWith(status: TaskStatus.running));
    if (!executorStarted.isCompleted) executorStarted.complete();
    if (executorStarts == 2 && !secondExecutorStarted.isCompleted) {
      secondExecutorStarted.complete();
    }
    if (holdTaskExecutions) {
      taskCancelTokens.add(cancelToken);
      final release = Completer<void>();
      final completion = Completer<void>();
      taskReleases.add(release);
      taskCompletions.add(completion);
      try {
        await release.future;
        if (!cancelToken.isCancelled) {
          uncancelledTaskCompletions.add(task.id);
        }
      } finally {
        if (!completion.isCompleted) completion.complete();
      }
    }
    if (taskExecutionError != null) throw taskExecutionError!;
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
    lastRetriedTask = task;
    lastRetryTaskUpdate = onUpdate;
    onUpdate(task.copyWith(status: TaskStatus.running));
    if (!executorStarted.isCompleted) executorStarted.complete();
    if (executorStarts == 2 && !secondExecutorStarted.isCompleted) {
      secondExecutorStarted.complete();
    }
    if (holdRetryExecutions) {
      retryCancelTokens.add(cancelToken);
      final release = Completer<void>();
      final completion = Completer<void>();
      retryReleases.add(release);
      retryCompletions.add(completion);
      try {
        await release.future;
      } finally {
        if (!completion.isCompleted) completion.complete();
      }
    }
    if (retryExecutionError != null) throw retryExecutionError!;
    return null;
  }
}

class _FailingSerializationTask extends CatCatchTask {
  _FailingSerializationTask()
      : super(
          id: 'failing-serialization',
          url: 'https://example.com/video.mp4',
          expectedDurationSec: 30,
          status: TaskStatus.completed,
          createdAt: DateTime(2025, 1, 1),
        );

  @override
  Map<String, dynamic> toMap() => throw StateError('test persistence failure');
}

Future<CatCatchTask?> _waitForPersistedTaskForTest(
  Directory directory,
  String taskId, {
  TaskStatus expectedStatus = TaskStatus.failed,
  int? expectedProgress,
}) async {
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
        if (task.id == taskId &&
            task.status == expectedStatus &&
            (expectedProgress == null || task.progress == expectedProgress)) {
          return task;
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return null;
}

Future<CatCatchTask?> _waitForPersistedLatestTaskForTest(
  Directory directory,
  String taskId, {
  required int expectedProgress,
}) async {
  final file = File('${directory.path}/catcatch/tasks.json');
  final timeout = Stopwatch()..start();
  while (timeout.elapsed < const Duration(seconds: 5)) {
    if (await file.exists()) {
      final tasks = (jsonDecode(await file.readAsString()) as List)
          .map(
            (task) => CatCatchTask.fromMap(
              Map<String, dynamic>.from(task as Map),
            ),
          )
          .where((task) => task.id == taskId)
          .toList();
      if (tasks.length > 1 && tasks.last.progress == expectedProgress) {
        return tasks.last;
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
    late bool containerDisposed;

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
      containerDisposed = false;
      container.read(catcatchTasksProvider);
      preferences = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      if (!containerDisposed) container.dispose();
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
      servicePlatform.stopRequested = Completer<void>();
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
        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );
        expect(servicePlatform.running, isFalse);
        expect(servicePlatform.stopCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);

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
        expect(servicePlatform.stopCalls, 1);
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

    test('startup failure preserves a user-enabled service', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', true);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;

      try {
        notifier.addTask(
          'invalid://failed-with-enabled-service',
          30,
          taskId: 'failed-with-enabled-service',
        );
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'failed-with-enabled-service',
        );
        expect(persisted?.status, TaskStatus.failed);
        expect(await notifier.removeTasksPersisted(['absent-task']), isTrue);

        expect(notifier.executorStarts, 0);
        expect(servicePlatform.startCalls, 1);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);
        expect(preferences.getBool('background_service_enabled'), isTrue);
      } finally {
        await notifier.removeTasksPersisted(['failed-with-enabled-service']);
      }
    });

    test('startup failure waits until a task snapshot saves before cleanup',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      final catcatchDirectory = Directory('${directory.path}/catcatch');
      if (await catcatchDirectory.exists()) {
        await catcatchDirectory.delete(recursive: true);
      }
      await File(catcatchDirectory.path).writeAsString('not a directory');

      final originalDebugPrint = debugPrint;
      final failedWrites = Completer<void>();
      final laterFailedWrite = Completer<void>();
      var persistenceFailures = 0;
      debugPrint = (message, {wrapWidth}) {
        if (message?.startsWith(
              '[CatCatchNotifier] Failed to persist tasks:',
            ) ==
            true) {
          persistenceFailures++;
          if (persistenceFailures == 2 && !failedWrites.isCompleted) {
            failedWrites.complete();
          }
          if (persistenceFailures == 3 && !laterFailedWrite.isCompleted) {
            laterFailedWrite.complete();
          }
        }
        originalDebugPrint(message, wrapWidth: wrapWidth);
      };

      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-unsaved-task' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );

      try {
        notifier.addTask(
          'invalid://failed-unsaved-task',
          30,
          taskId: 'failed-unsaved-task',
        );
        final failure = await failed.future.timeout(
          const Duration(seconds: 2),
        );
        expect(failure.error, contains('后台服务启动失败'));
        await failedWrites.future.timeout(const Duration(seconds: 2));
        notifier.removeTask('absent-task');
        await laterFailedWrite.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(notifier.executorStarts, 0);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        debugPrint = originalDebugPrint;
        subscription.close();
      }
    });

    test('startup failure cleans up after a queued idle write is persisted',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      servicePlatform.stopRequested = Completer<void>();
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
        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );
        expect(servicePlatform.running, isFalse);
        expect(servicePlatform.stopCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
        await notifier.removeTasksPersisted(['failed-after-idle-write']);
      }
    });

    test(
        'startup failure cleanup survives a queued snapshot failure after the failed state was saved',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      servicePlatform.stopRequested = Completer<void>();
      documents.firstRequestStarted = Completer<void>();
      documents.releaseFirstRequest = Completer<void>();
      notifier.setTasksForTest([
        task('other-task').copyWith(status: TaskStatus.running),
      ]);

      final originalDebugPrint = debugPrint;
      final laterWriteFailed = Completer<void>();
      debugPrint = (message, {wrapWidth}) {
        if (message?.startsWith(
                  '[CatCatchNotifier] Failed to persist tasks:',
                ) ==
                true &&
            !laterWriteFailed.isCompleted) {
          laterWriteFailed.complete();
        }
        originalDebugPrint(message, wrapWidth: wrapWidth);
      };

      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-with-queued-write-error' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );

      try {
        notifier.addTask(
          'invalid://failed-with-queued-write-error',
          30,
          taskId: 'failed-with-queued-write-error',
        );
        await documents.firstRequestStarted!.future.timeout(
          const Duration(seconds: 2),
        );
        final failure = await failed.future.timeout(
          const Duration(seconds: 2),
        );
        expect(failure.error, contains('后台服务启动失败'));
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);

        notifier.setTasksForTest([
          for (final current in notifier.tasksForTest)
            if (current.id == 'other-task')
              current.copyWith(status: TaskStatus.completed)
            else
              current,
          _FailingSerializationTask(),
        ]);
        notifier.removeTask('absent-task');

        documents.releaseFirstRequest!.complete();
        await laterWriteFailed.future.timeout(const Duration(seconds: 2));
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'failed-with-queued-write-error',
        );
        expect(persisted?.status, TaskStatus.failed);
        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );

        expect(servicePlatform.running, isFalse);
        expect(servicePlatform.stopCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        debugPrint = originalDebugPrint;
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
      }
    });

    test(
        'startup failure cleanup survives provider disposal during persistence',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      servicePlatform.stopRequested = Completer<void>();
      documents.firstRequestStarted = Completer<void>();
      documents.releaseFirstRequest = Completer<void>();
      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-before-provider-disposal' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );

      try {
        notifier.addTask(
          'invalid://failed-before-provider-disposal',
          30,
          taskId: 'failed-before-provider-disposal',
        );
        await documents.firstRequestStarted!.future.timeout(
          const Duration(seconds: 2),
        );
        final failure = await failed.future.timeout(
          const Duration(seconds: 2),
        );
        expect(failure.error, contains('后台服务启动失败'));
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);

        container.dispose();
        containerDisposed = true;
        documents.releaseFirstRequest!.complete();
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'failed-before-provider-disposal',
        );
        expect(persisted?.status, TaskStatus.failed);
        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );

        expect(servicePlatform.running, isFalse);
        expect(servicePlatform.stopCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
      }
    });

    test('startup failure removal cleanup survives provider disposal',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      servicePlatform.stopRequested = Completer<void>();
      documents.firstRequestStarted = Completer<void>();
      documents.releaseFirstRequest = Completer<void>();
      notifier.setTasksForTest([
        task('other-task').copyWith(status: TaskStatus.running),
      ]);
      final failed = Completer<CatCatchTask>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          for (final current in tasks) {
            if (current.id == 'failed-before-removal-disposal' &&
                current.status == TaskStatus.failed &&
                !failed.isCompleted) {
              failed.complete(current);
            }
          }
        },
      );
      Future<bool>? pendingRemoval;

      try {
        notifier.addTask(
          'invalid://failed-before-removal-disposal',
          30,
          taskId: 'failed-before-removal-disposal',
        );
        await documents.firstRequestStarted!.future.timeout(
          const Duration(seconds: 2),
        );
        final failure = await failed.future.timeout(
          const Duration(seconds: 2),
        );
        expect(failure.error, contains('后台服务启动失败'));

        pendingRemoval = notifier.removeTasksPersisted([
          'other-task',
          'failed-before-removal-disposal',
        ]);
        container.dispose();
        containerDisposed = true;
        documents.releaseFirstRequest!.complete();
        expect(await pendingRemoval, isTrue);

        final persisted =
            await File('${directory.path}/catcatch/tasks.json').readAsString();
        expect(jsonDecode(persisted), isEmpty);
        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );

        expect(servicePlatform.running, isFalse);
        expect(servicePlatform.stopCalls, 1);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
        if (pendingRemoval != null) await pendingRemoval;
      }
    });

    test('startup failure cleanup waits while another task is running',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startResult = false;
      servicePlatform.runningAfterStart = true;
      documents.firstRequestStarted = Completer<void>();
      documents.releaseFirstRequest = Completer<void>();
      notifier.setTasksForTest([
        task('queued-removal'),
        task('still-running').copyWith(status: TaskStatus.running),
      ]);
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
        expect(await notifier.removeTasksPersisted(['absent-task']), isTrue);
        expect(servicePlatform.running, isTrue);
        expect(servicePlatform.stopCalls, 0);
        expect(preferences.getBool('background_service_enabled'), isFalse);

        expect(await notifier.removeTasksPersisted(['still-running']), isTrue);
        expect(servicePlatform.running, isFalse);
        expect(servicePlatform.stopCalls, 1);
      } finally {
        if (!documents.releaseFirstRequest!.isCompleted) {
          documents.releaseFirstRequest!.complete();
        }
        subscription.close();
        if (pendingRemoval != null) await pendingRemoval;
        await notifier.removeTasksPersisted([
          'still-running',
          'failed-during-removal',
        ]);
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

    test('pausing the last task stops temporary service after startup',
        () async {
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.startEntered = Completer<void>();
      servicePlatform.releaseStart = Completer<void>();
      servicePlatform.stopRequested = Completer<void>();

      try {
        notifier.addTask(
          'invalid://paused-during-startup',
          30,
          taskId: 'paused-during-startup',
        );
        await servicePlatform.startEntered!.future.timeout(
          const Duration(seconds: 2),
        );

        notifier.pauseTask('paused-during-startup');
        servicePlatform.releaseStart!.complete();

        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'paused-during-startup',
          expectedStatus: TaskStatus.paused,
        );

        expect(persisted?.status, TaskStatus.paused);
        expect(notifier.executorStarts, 0);
        expect(servicePlatform.stopCalls, 1);
        expect(servicePlatform.running, isFalse);
        expect(preferences.getBool('background_service_enabled'), isFalse);
      } finally {
        if (!servicePlatform.releaseStart!.isCompleted) {
          servicePlatform.releaseStart!.complete();
        }
        await notifier.removeTasksPersisted(['paused-during-startup']);
      }
    });

    test('pausing preserves a user-enabled background service', () async {
      await preferences.setBool('background_service_enabled', true);
      expect(await startBackgroundService(), isTrue);
      notifier.setTasksForTest([
        task('paused-persistent-service').copyWith(status: TaskStatus.running),
      ]);

      try {
        notifier.pauseTask('paused-persistent-service');
        final persisted = await _waitForPersistedTaskForTest(
          directory,
          'paused-persistent-service',
          expectedStatus: TaskStatus.paused,
        );

        expect(persisted?.status, TaskStatus.paused);
        expect(servicePlatform.stopCalls, 0);
        expect(servicePlatform.running, isTrue);
        expect(preferences.getBool('background_service_enabled'), isTrue);
      } finally {
        await notifier.removeTasksPersisted(['paused-persistent-service']);
      }
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

    test('repeated confirm cancels superseded execution before pause',
        () async {
      const taskId = 'repeat-confirm-pause';
      notifier.holdRetryExecutions = true;
      notifier.setTasksForTest([task(taskId)]);

      try {
        notifier.confirmAndContinue(taskId);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
        notifier.confirmAndContinue(taskId);
        await notifier.secondExecutorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        final firstRun = notifier.retryCancelTokens[0];
        final currentRun = notifier.retryCancelTokens[1];
        expect(firstRun.isCancelled, isTrue);
        expect(currentRun.isCancelled, isFalse);

        notifier.pauseTask(taskId);

        expect(firstRun.isCancelled, isTrue);
        expect(currentRun.isCancelled, isTrue);
      } finally {
        for (final release in notifier.retryReleases) {
          if (!release.isCompleted) release.complete();
        }
        await notifier.removeTasksPersisted([taskId]);
      }
    });

    test('pausing a duplicate updates the active row and stops the service',
        () async {
      const taskId = 'pause-active-duplicate';
      await preferences.setBool('background_service_enabled', false);
      servicePlatform.running = true;
      servicePlatform.stopRequested = Completer<void>();
      notifier.holdTaskExecutions = true;
      notifier.setTasksForTest([task(taskId)]);

      try {
        notifier.addTask('invalid://pause-duplicate', 30, taskId: taskId);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        expect(notifier.tasksForTest.last.status, TaskStatus.running);
        final activeToken = notifier.taskCancelTokens.single;
        notifier.pauseTask(taskId);

        expect(activeToken.isCancelled, isTrue);
        expect(notifier.tasksForTest.last.status, TaskStatus.paused);
        await servicePlatform.stopRequested!.future.timeout(
          const Duration(seconds: 2),
        );
        await notifier.waitForTaskSnapshotWritesForTesting();

        final persisted = (jsonDecode(
          await File('${directory.path}/catcatch/tasks.json').readAsString(),
        ) as List)
            .map((record) => CatCatchTask.fromMap(
                  Map<String, dynamic>.from(record as Map),
                ))
            .where((current) => current.id == taskId)
            .toList();
        expect(persisted, hasLength(2));
        expect(persisted.last.status, TaskStatus.paused);
        expect(servicePlatform.stopCalls, 1);
      } finally {
        for (final release in notifier.taskReleases) {
          if (!release.isCompleted) release.complete();
        }
        await Future.wait(notifier.taskCompletions.map((item) => item.future));
        await notifier.removeTasksPersisted([taskId]);
      }
    });

    test('normal execution failure marks the active duplicate row failed',
        () async {
      const taskId = 'normal-failed-active-duplicate';
      const failureMessage = 'Bad state: normal execution failed';
      notifier.holdTaskExecutions = true;
      notifier.taskExecutionError = StateError('normal execution failed');
      notifier.setTasksForTest([task(taskId)]);
      final activeRowFailed = Completer<void>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          if (tasks.length > 1 &&
              tasks.last.id == taskId &&
              tasks.last.status == TaskStatus.failed &&
              tasks.last.error == failureMessage &&
              !activeRowFailed.isCompleted) {
            activeRowFailed.complete();
          }
        },
      );

      try {
        notifier.addTask('invalid://normal-failure', 30, taskId: taskId);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
        expect(notifier.tasksForTest.last.status, TaskStatus.running);

        notifier.taskReleases.single.complete();
        await activeRowFailed.future.timeout(const Duration(seconds: 2));
        await notifier.waitForTaskSnapshotWritesForTesting();

        final persisted = (jsonDecode(
          await File('${directory.path}/catcatch/tasks.json').readAsString(),
        ) as List)
            .map((record) => CatCatchTask.fromMap(
                  Map<String, dynamic>.from(record as Map),
                ))
            .where((current) => current.id == taskId)
            .toList();
        expect(persisted.last.status, TaskStatus.failed);
        expect(persisted.last.error, failureMessage);
      } finally {
        subscription.close();
        for (final release in notifier.taskReleases) {
          if (!release.isCompleted) release.complete();
        }
        await Future.wait(notifier.taskCompletions.map((item) => item.future));
        await notifier.removeTasksPersisted([taskId]);
      }
    });

    test('retry execution failure marks the active duplicate row failed',
        () async {
      const taskId = 'retry-failed-active-duplicate';
      const failureMessage = 'Bad state: retry execution failed';
      notifier.holdRetryExecutions = true;
      notifier.retryExecutionError = StateError('retry execution failed');
      notifier.setTasksForTest([
        task(taskId).copyWith(
          status: TaskStatus.failed,
          error: 'older failure',
        ),
        task(taskId).copyWith(
          status: TaskStatus.failed,
          error: 'latest failure',
        ),
      ]);
      final activeRowFailed = Completer<void>();
      final subscription = container.listen<List<CatCatchTask>>(
        catcatchTasksProvider,
        (_, tasks) {
          if (tasks.last.id == taskId &&
              tasks.last.status == TaskStatus.failed &&
              tasks.last.error == failureMessage &&
              !activeRowFailed.isCompleted) {
            activeRowFailed.complete();
          }
        },
      );

      try {
        notifier.retryStep(taskId, StepType.fetching);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
        expect(notifier.tasksForTest.last.status, TaskStatus.running);

        notifier.retryReleases.single.complete();
        await activeRowFailed.future.timeout(const Duration(seconds: 2));
        await notifier.waitForTaskSnapshotWritesForTesting();

        final persisted = (jsonDecode(
          await File('${directory.path}/catcatch/tasks.json').readAsString(),
        ) as List)
            .map((record) => CatCatchTask.fromMap(
                  Map<String, dynamic>.from(record as Map),
                ))
            .where((current) => current.id == taskId)
            .toList();
        expect(persisted.last.status, TaskStatus.failed);
        expect(persisted.last.error, failureMessage);
      } finally {
        subscription.close();
        for (final release in notifier.retryReleases) {
          if (!release.isCompleted) release.complete();
        }
        await Future.wait(notifier.retryCompletions.map((item) => item.future));
        await notifier.removeTasksPersisted([taskId]);
      }
    });

    test(
      'runtime updates from reused addTask ID survive fresh-provider restore',
      () async {
        const taskId = 'reused-add-task-progress';
        const replacementMedia = MediaResource(
          url: 'https://example.com/replacement.m3u8',
          name: 'replacement',
          ext: 'm3u8',
          isPlaylist: true,
        );
        final distinctBefore = task('progress-before');
        final older = task(taskId).copyWith(
          url: 'https://example.com/older.mp4',
          metadata: const {'replacement': 'older'},
        );
        final distinctAfter = task('progress-after');
        notifier.holdTaskExecutions = true;
        notifier.setTasksForTest([distinctBefore, older, distinctAfter]);

        try {
          notifier.addTask(
            'https://example.com/replacement-page',
            90,
            taskId: taskId,
          );
          await notifier.executorStarted.future.timeout(
            const Duration(seconds: 2),
          );

          expect(notifier.tasksForTest.map((current) => current.id).toList(), [
            'progress-before',
            taskId,
            'progress-after',
            taskId,
          ]);
          final replacementExecution = notifier.lastExecutedTask!;
          final runtimeUpdate = replacementExecution.copyWith(
            status: TaskStatus.running,
            steps: [
              StepStatus.done(StepType.fetching),
              StepStatus.progressing(StepType.downloading, 73),
            ],
            detectedMedia: const [replacementMedia],
            selectedMedia: replacementMedia,
            progress: 73,
            downloadedFilePath: '/tmp/replacement.partial.mp4',
            metadata: const {'replacement': 'newest'},
            downloadedBytes: 1234,
          );
          notifier.lastTaskUpdate!(runtimeUpdate);

          final persisted = await _waitForPersistedTaskForTest(
            directory,
            taskId,
            expectedStatus: TaskStatus.running,
            expectedProgress: runtimeUpdate.progress,
          );
          expect(persisted, isNotNull);
          final persistedRecords = (jsonDecode(
            await File(
              '${directory.path}/catcatch/tasks.json',
            ).readAsString(),
          ) as List)
              .map(
                (record) => CatCatchTask.fromMap(
                  Map<String, dynamic>.from(record as Map),
                ),
              )
              .toList();
          expect(persistedRecords.map((current) => current.id).toList(), [
            'progress-before',
            taskId,
            'progress-after',
            taskId,
          ]);

          for (final release in notifier.taskReleases) {
            if (!release.isCompleted) release.complete();
          }
          await Future.wait(
            notifier.taskCompletions.map((item) => item.future),
          ).timeout(const Duration(seconds: 2));

          // A fresh container models process restart and forces restore to pick
          // the last persisted record for the duplicate task ID.
          container.dispose();
          containerDisposed = true;
          container = ProviderContainer(
            overrides: [
              catcatchTasksProvider.overrideWith((ref) {
                notifier = _CleanupCatCatchNotifier(ref);
                return notifier;
              }),
            ],
          );
          containerDisposed = false;
          container.read(catcatchTasksProvider);
          await notifier.restoreUnfinishedTasks();

          expect(notifier.tasksForTest.map((current) => current.id).toList(), [
            'progress-before',
            taskId,
            'progress-after',
          ]);
          final restored = notifier.tasksForTest.singleWhere(
            (current) => current.id == taskId,
          );
          expect(restored.url, runtimeUpdate.url);
          expect(
            restored.expectedDurationSec,
            runtimeUpdate.expectedDurationSec,
          );
          expect(restored.progress, runtimeUpdate.progress);
          expect(restored.downloadedFilePath, runtimeUpdate.downloadedFilePath);
          expect(restored.detectedMedia.single.url, replacementMedia.url);
          expect(restored.selectedMedia?.url, replacementMedia.url);
          expect(restored.downloadedBytes, runtimeUpdate.downloadedBytes);
          expect(restored.metadata, runtimeUpdate.metadata);
          expect(restored.title, runtimeUpdate.title);
          expect(restored.status, TaskStatus.paused);
          expect(restored.error, '应用重启，已暂停');
          expect(restored.steps.map((step) => step.progress).toList(), [
            100,
            73,
          ]);
        } finally {
          for (final release in notifier.taskReleases) {
            if (!release.isCompleted) release.complete();
          }
          await Future.wait(
            notifier.taskCompletions.map((item) => item.future),
          );
          await notifier.removeTasksPersisted([
            taskId,
            'progress-before',
            'progress-after',
          ]);
        }
      },
    );

    test(
      'resuming duplicate IDs preserves the newest runtime snapshot',
      () async {
        const taskId = 'resume-newest-runtime-snapshot';
        const staleMedia = MediaResource(
          url: 'https://example.com/older.m3u8',
          name: 'older',
          ext: 'm3u8',
          isPlaylist: true,
        );
        const newestMedia = MediaResource(
          url: 'https://example.com/newest.m3u8',
          name: 'newest',
          ext: 'm3u8',
          isPlaylist: true,
        );
        final older = task(taskId).copyWith(
          steps: StepType.values.map(StepStatus.pending).toList(),
          detectedMedia: const [staleMedia],
          selectedMedia: staleMedia,
          progress: 8,
          downloadedFilePath: '/tmp/older.partial.mp4',
          downloadedBytes: 80,
        );
        final newest = task(taskId).copyWith(
          steps: [
            StepStatus.done(StepType.fetching, detail: 'newest fetched page'),
            ...StepType.values.skip(1).map(StepStatus.pending),
          ],
          detectedMedia: const [newestMedia],
          selectedMedia: newestMedia,
          progress: 47,
          downloadedFilePath: '/tmp/newest.partial.mp4',
          downloadedBytes: 4700,
        );
        notifier.holdRetryExecutions = true;
        notifier.setTasksForTest([older, newest]);
        final executionNotifier = notifier;

        try {
          executionNotifier.resumeTask(taskId);
          await executionNotifier.executorStarted.future.timeout(
            const Duration(seconds: 2),
          );

          final persisted = await _waitForPersistedLatestTaskForTest(
            directory,
            taskId,
            expectedProgress: newest.progress,
          );
          expect(persisted, isNotNull);
          expect(persisted!.progress, newest.progress);
          expect(persisted.steps.first.completed, isTrue);
          expect(persisted.steps.first.detail, 'newest fetched page');
          expect(
            persisted.detectedMedia.map((media) => media.url).toList(),
            [newestMedia.url],
          );
          expect(persisted.selectedMedia?.url, newestMedia.url);
          expect(persisted.downloadedFilePath, newest.downloadedFilePath);
          expect(persisted.downloadedBytes, newest.downloadedBytes);
        } finally {
          for (final release in executionNotifier.retryReleases) {
            if (!release.isCompleted) release.complete();
          }
          await Future.wait(
            executionNotifier.retryCompletions.map((item) => item.future),
          );
          await notifier.removeTasksPersisted([taskId]);
        }
      },
    );

    test(
      'resume runtime updates persist to the newest duplicate task row',
      () async {
        const taskId = 'resumed-duplicate-task';
        const staleMedia = MediaResource(
          url: 'https://example.com/stale.m3u8',
          name: 'stale',
          ext: 'm3u8',
          isPlaylist: true,
        );
        const resumedMedia = MediaResource(
          url: 'https://example.com/resumed.m3u8',
          name: 'resumed',
          ext: 'm3u8',
          isPlaylist: true,
        );
        final pendingSteps = StepType.values.map(StepStatus.pending).toList();
        final older = task(taskId).copyWith(
          url: 'https://example.com/older.mp4',
          expectedDurationSec: 30,
          steps: pendingSteps,
          progress: 8,
          metadata: const {
            'stale-setting': 'older',
            'runtime-key': 'before',
          },
        );
        final newer = task(taskId).copyWith(
          url: 'https://example.com/newer.mp4',
          expectedDurationSec: 90,
          title: 'Newest stale task',
          createdAt: DateTime(2025, 1, 2),
          steps: pendingSteps,
          detectedMedia: const [staleMedia],
          selectedMedia: staleMedia,
          progress: 12,
          downloadedFilePath: '/tmp/stale.partial.mp4',
          metadata: const {
            'stale-setting': 'newer',
            'runtime-key': 'current',
            'newest-only': 'preserved',
          },
          downloadedBytes: 345,
        );
        notifier.holdRetryExecutions = true;
        notifier.setTasksForTest([older, newer]);
        final executionNotifier = notifier;

        try {
          executionNotifier.resumeTask(taskId);
          await executionNotifier.executorStarted.future.timeout(
            const Duration(seconds: 2),
          );

          final runtimeUpdate = executionNotifier.lastRetriedTask!.copyWith(
            status: TaskStatus.running,
            steps: [
              StepStatus.done(StepType.fetching),
              StepStatus.progressing(StepType.downloading, 73),
            ],
            detectedMedia: const [resumedMedia],
            selectedMedia: resumedMedia,
            progress: 73,
            downloadedFilePath: '/tmp/resumed.partial.mp4',
            metadata: const {
              'stale-setting': 'older',
              'runtime-key': 'after',
            },
            downloadedBytes: 1234,
          );
          executionNotifier.lastRetryTaskUpdate!(runtimeUpdate);

          final persisted = await _waitForPersistedLatestTaskForTest(
            directory,
            taskId,
            expectedProgress: runtimeUpdate.progress,
          );
          expect(persisted, isNotNull);
          expect(persisted!.detectedMedia.single.url, resumedMedia.url);
          expect(persisted.selectedMedia?.url, resumedMedia.url);
          expect(
              persisted.downloadedFilePath, runtimeUpdate.downloadedFilePath);
          expect(persisted.downloadedBytes, runtimeUpdate.downloadedBytes);
          expect(persisted.url, newer.url);
          expect(persisted.expectedDurationSec, newer.expectedDurationSec);
          expect(persisted.title, newer.title);
          expect(persisted.createdAt, newer.createdAt);
          expect(persisted.metadata, {
            'stale-setting': 'newer',
            'runtime-key': 'after',
            'newest-only': 'preserved',
          });

          final persistedRecords = (jsonDecode(
            await File('${directory.path}/catcatch/tasks.json').readAsString(),
          ) as List)
              .map(
                (record) => CatCatchTask.fromMap(
                  Map<String, dynamic>.from(record as Map),
                ),
              )
              .toList();
          expect(persistedRecords.map((current) => current.id).toList(), [
            taskId,
            taskId,
          ]);
          expect(persistedRecords.last.progress, runtimeUpdate.progress);

          for (final release in executionNotifier.retryReleases) {
            if (!release.isCompleted) release.complete();
          }
          await Future.wait(
            executionNotifier.retryCompletions.map((item) => item.future),
          ).timeout(const Duration(seconds: 2));

          // A fresh provider models process restart and restores only the last
          // persisted record for this duplicate task ID.
          container.dispose();
          containerDisposed = true;
          container = ProviderContainer(
            overrides: [
              catcatchTasksProvider.overrideWith((ref) {
                notifier = _CleanupCatCatchNotifier(ref);
                return notifier;
              }),
            ],
          );
          containerDisposed = false;
          container.read(catcatchTasksProvider);
          await notifier.restoreUnfinishedTasks();

          expect(notifier.tasksForTest, hasLength(1));
          final restored = notifier.tasksForTest.single;
          expect(restored.progress, runtimeUpdate.progress);
          expect(restored.downloadedFilePath, runtimeUpdate.downloadedFilePath);
          expect(restored.detectedMedia.single.url, resumedMedia.url);
          expect(restored.selectedMedia?.url, resumedMedia.url);
          expect(restored.downloadedBytes, runtimeUpdate.downloadedBytes);
          expect(restored.url, newer.url);
          expect(restored.expectedDurationSec, newer.expectedDurationSec);
          expect(restored.title, newer.title);
          expect(restored.createdAt, newer.createdAt);
          expect(restored.metadata, persisted.metadata);
          expect(restored.status, TaskStatus.paused);
        } finally {
          for (final release in executionNotifier.retryReleases) {
            if (!release.isCompleted) release.complete();
          }
          await Future.wait(
            executionNotifier.retryCompletions.map((item) => item.future),
          );
          await notifier.removeTasksPersisted([taskId]);
        }
      },
    );

    test('resumed runtime title updates replace the unchanged newest title',
        () async {
      const taskId = 'resumed-duplicate-title-task';
      final pendingSteps = StepType.values.map(StepStatus.pending).toList();
      final older = task(taskId).copyWith(
        title: 'Shared task title',
        steps: pendingSteps,
      );
      final newer = task(taskId).copyWith(
        title: 'Shared task title',
        steps: pendingSteps,
      );
      notifier.holdRetryExecutions = true;
      notifier.setTasksForTest([older, newer]);
      final executionNotifier = notifier;

      try {
        executionNotifier.resumeTask(taskId);
        await executionNotifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        final runtimeUpdate = executionNotifier.lastRetriedTask!.copyWith(
          title: 'Fetched page title',
          status: TaskStatus.running,
          steps: [
            StepStatus.done(StepType.fetching),
            StepStatus.progressing(StepType.downloading, 73),
          ],
          progress: 73,
        );
        executionNotifier.lastRetryTaskUpdate!(runtimeUpdate);

        final persisted = await _waitForPersistedLatestTaskForTest(
          directory,
          taskId,
          expectedProgress: runtimeUpdate.progress,
        );
        expect(persisted, isNotNull);
        expect(persisted!.title, 'Fetched page title');
      } finally {
        for (final release in executionNotifier.retryReleases) {
          if (!release.isCompleted) release.complete();
        }
        await Future.wait(
          executionNotifier.retryCompletions.map((item) => item.future),
        );
        await notifier.removeTasksPersisted([taskId]);
      }
    });

    test('restore keeps the newest persisted record for duplicate task IDs',
        () async {
      const taskId = 'restored-duplicate-task';
      final older = task(taskId).copyWith(
        url: 'https://example.com/older.mp4',
        metadata: const {'replacement': 'older'},
      );
      const replacementMedia = MediaResource(
        url: 'https://example.com/replacement.m3u8',
        name: 'replacement',
        ext: 'm3u8',
        isPlaylist: true,
      );
      final replacement = task(taskId).copyWith(
        url: 'https://example.com/replacement-page',
        title: 'Replacement task',
        expectedDurationSec: 90,
        status: TaskStatus.running,
        steps: [
          StepStatus.done(StepType.fetching),
          StepStatus.progressing(StepType.downloading, 47),
        ],
        detectedMedia: const [replacementMedia],
        selectedMedia: replacementMedia,
        progress: 47,
        downloadedFilePath: '/tmp/replacement.partial.mp4',
        metadata: const {'replacement': 'newest'},
        downloadedBytes: 1234,
      );
      final distinctBefore = task('distinct-before');
      final distinctAfter = task('distinct-after');
      final tasksDirectory = Directory('${directory.path}/catcatch');
      await tasksDirectory.create(recursive: true);
      await File('${tasksDirectory.path}/tasks.json').writeAsString(
        jsonEncode([
          older.toMap(),
          distinctBefore.toMap(),
          replacement.toMap(),
          distinctAfter.toMap(),
        ]),
      );

      // A fresh container has no in-memory tasks, like a process restart.
      container.dispose();
      containerDisposed = true;
      container = ProviderContainer(overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          notifier = _CleanupCatCatchNotifier(ref);
          return notifier;
        }),
      ]);
      containerDisposed = false;
      container.read(catcatchTasksProvider);

      await notifier.restoreUnfinishedTasks();

      expect(
        notifier.tasksForTest.map((current) => current.id).toList(),
        [taskId, 'distinct-before', 'distinct-after'],
      );
      final restored = notifier.tasksForTest.singleWhere(
        (current) => current.id == taskId,
      );
      expect(restored.url, replacement.url);
      expect(restored.title, replacement.title);
      expect(restored.expectedDurationSec, replacement.expectedDurationSec);
      expect(restored.status, TaskStatus.paused);
      expect(restored.error, '应用重启，已暂停');
      expect(restored.steps.map((step) => step.progress).toList(), [100, 47]);
      expect(restored.detectedMedia.single.url, replacementMedia.url);
      expect(restored.selectedMedia?.url, replacementMedia.url);
      expect(restored.progress, replacement.progress);
      expect(restored.downloadedFilePath, replacement.downloadedFilePath);
      expect(restored.metadata, replacement.metadata);
      expect(restored.downloadedBytes, replacement.downloadedBytes);
    });

    test('reused addTask ID cancels superseded execution before removal',
        () async {
      const taskId = 'duplicate-add-task-remove';
      notifier.holdTaskExecutions = true;

      try {
        notifier.addTask('invalid://first-task', 30, taskId: taskId);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        notifier.addTask('invalid://second-task', 30, taskId: taskId);
        await notifier.secondExecutorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        final supersededRun = notifier.taskCancelTokens[0];
        final currentRun = notifier.taskCancelTokens[1];
        final supersededRunCancelledBeforeRemoval = supersededRun.isCancelled;

        expect(await notifier.removeTasksPersisted([taskId]), isTrue);
        for (final release in notifier.taskReleases) {
          if (!release.isCompleted) release.complete();
        }
        await Future.wait(notifier.taskCompletions.map((item) => item.future))
            .timeout(const Duration(seconds: 2));

        expect(supersededRunCancelledBeforeRemoval, isTrue);
        expect(supersededRun.isCancelled, isTrue);
        expect(currentRun.isCancelled, isTrue);
        expect(notifier.tasksForTest, isEmpty);
        expect(notifier.uncancelledTaskCompletions, isEmpty);
      } finally {
        for (final release in notifier.taskReleases) {
          if (!release.isCompleted) release.complete();
        }
        await notifier.removeTasksPersisted([taskId]);
      }
    });

    test('removing a repeated task cancels all overlapping executions',
        () async {
      const taskId = 'repeat-confirm-remove';
      notifier.holdRetryExecutions = true;
      notifier.setTasksForTest([task(taskId)]);

      try {
        notifier.confirmAndContinue(taskId);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
        notifier.confirmAndContinue(taskId);
        await notifier.secondExecutorStarted.future.timeout(
          const Duration(seconds: 2),
        );

        final firstRun = notifier.retryCancelTokens[0];
        final currentRun = notifier.retryCancelTokens[1];
        expect(firstRun.isCancelled, isTrue);
        expect(currentRun.isCancelled, isFalse);

        notifier.removeTask(taskId);

        expect(firstRun.isCancelled, isTrue);
        expect(currentRun.isCancelled, isTrue);
        expect(notifier.tasksForTest, isEmpty);
      } finally {
        for (final release in notifier.retryReleases) {
          if (!release.isCompleted) release.complete();
        }
        await notifier.removeTasksPersisted([taskId]);
      }
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
        expect(await stopBackgroundService(), isFalse);
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

    test(
      'removal cleans every duplicate while preserving remaining owners',
      () async {
        const firstMedia = MediaResource(
          url: 'https://example.com/first.mp4',
          name: 'first',
          ext: 'mp4',
        );
        const secondMedia = MediaResource(
          url: 'https://example.com/second.mp4',
          name: 'second',
          ext: 'mp4',
        );
        final downloadDir = Directory('${directory.path}/catcatch/downloads')
          ..createSync(recursive: true);
        final firstArtifact = File('${downloadDir.path}/first.mp4.catcatch_tmp')
          ..writeAsStringSync('first partial');
        final secondArtifact = File(
          '${downloadDir.path}/second.mp4.catcatch_tmp',
        )..writeAsStringSync('second partial');
        final firstPartial = File('${directory.path}/first.partial')
          ..writeAsStringSync('first recorded partial');
        final secondPartial = File('${directory.path}/second.partial')
          ..writeAsStringSync('second recorded partial');
        final sharedArtifact = File('${downloadDir.path}/second.mp4')
          ..writeAsStringSync('remaining owner');
        notifier.setTasksForTest([
          task('duplicate').copyWith(
            selectedMedia: firstMedia,
            downloadedFilePath: firstPartial.path,
          ),
          task('duplicate').copyWith(
            selectedMedia: secondMedia,
            downloadedFilePath: secondPartial.path,
          ),
          task('remaining').copyWith(downloadedFilePath: sharedArtifact.path),
        ]);

        notifier.removeTask('duplicate');
        expect(notifier.tasksForTest.map((task) => task.id), ['remaining']);
        await notifier.waitForTaskSnapshotWritesForTesting();
        final removedArtifacts = [
          firstArtifact,
          secondArtifact,
          firstPartial,
          secondPartial,
        ];
        // Wait for the unawaited cleanup through its observable filesystem result.
        await Future<void>(() async {
          while (removedArtifacts.any((file) => file.existsSync())) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }).timeout(const Duration(seconds: 2));
        expect(sharedArtifact.readAsStringSync(), 'remaining owner');
      },
    );

    test('removal cleanup rechecks owners selected during its async gap',
        () async {
      const media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final downloadDir = Directory('${directory.path}/catcatch/downloads')
        ..createSync(recursive: true);
      final tempDownload = File(
        '${downloadDir.path}/video.mp4.catcatch_tmp',
      )..writeAsStringSync('partial download');
      final unsharedDownload = File('${directory.path}/unshared-download.tmp')
        ..writeAsStringSync('removed task artifact');
      final progressFile = File(
        '${directory.path}/catcatch/.progress/removed_dl_progress.json',
      )..createSync(recursive: true);

      documents.firstRequestStarted = Completer<void>();
      documents.releaseAllRequests = Completer<void>();
      notifier.setTasksForTest([
        task('removed').copyWith(
          selectedMedia: media,
          downloadedFilePath: unsharedDownload.path,
        ),
        task('remaining').copyWith(
          steps: [StepStatus.running(StepType.userSelecting)],
        ),
      ]);

      try {
        notifier.removeTask('removed');
        await documents.firstRequestStarted!.future.timeout(
          const Duration(seconds: 2),
        );

        notifier.selectMedia('remaining', media);
        await notifier.executorStarted.future.timeout(
          const Duration(seconds: 2),
        );
        expect(
          notifier.tasksForTest
              .singleWhere((current) => current.id == 'remaining')
              .selectedMedia,
          media,
        );

        documents.releaseAllRequests!.complete();
        await notifier.waitForTaskSnapshotWritesForTesting();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(await tempDownload.exists(), isTrue);
        expect(await unsharedDownload.exists(), isFalse);
        expect(await progressFile.exists(), isFalse);
      } finally {
        if (!documents.releaseAllRequests!.isCompleted) {
          documents.releaseAllRequests!.complete();
        }
      }
    });

    test('removal cleanup rechecks owners selected after its snapshot',
        () async {
      const media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final downloadDir = Directory('${directory.path}/catcatch/downloads')
        ..createSync(recursive: true);
      final tempDownload = File(
        '${downloadDir.path}/video.mp4.catcatch_tmp',
      )..writeAsStringSync('partial download');
      final unsharedDownload = File('${directory.path}/unshared-download.tmp')
        ..writeAsStringSync('removed task artifact');
      final progressFile = File(
        '${directory.path}/catcatch/.progress/removed_dl_progress.json',
      )..createSync(recursive: true);
      final remaining = task('remaining').copyWith(
        steps: [StepStatus.running(StepType.userSelecting)],
      );
      notifier.setTasksForTest([remaining]);

      final cleanup = CatCatchNotifier.cleanupTaskFiles(
        task('removed').copyWith(
          selectedMedia: media,
          downloadedFilePath: unsharedDownload.path,
        ),
        appDirPath: directory.path,
        remainingTasks: notifier.tasksForTest,
        remainingTasksProvider: () => notifier.tasksForTest,
      );
      // The owner list starts with an unselected task. Select its media after
      // cleanup starts but before its first async deletion resumes.
      notifier.selectMedia('remaining', media);
      await notifier.executorStarted.future.timeout(
        const Duration(seconds: 2),
      );
      await cleanup;

      expect(await tempDownload.exists(), isTrue);
      expect(await unsharedDownload.exists(), isFalse);
      expect(await progressFile.exists(), isFalse);
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
