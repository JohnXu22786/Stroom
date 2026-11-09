import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/services/storage_service.dart';

class _ControlledDocuments extends PathProviderPlatform {
  _ControlledDocuments(this.path);

  final String path;
  final restorePathStarted = Completer<void>();
  final releaseRestorePath = Completer<void>();
  final secondPathStarted = Completer<void>();
  final releaseSecondPath = Completer<void>();
  bool failNextPathRequest = false;
  int? failPathRequestAttempt;
  int pathRequestAttempts = 0;
  int pathRequests = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final attempt = ++pathRequestAttempts;
    if (attempt == failPathRequestAttempt) {
      throw StateError('controlled path failure');
    }
    if (failNextPathRequest) {
      failNextPathRequest = false;
      throw StateError('controlled path failure');
    }
    switch (++pathRequests) {
      case 1:
        restorePathStarted.complete();
        await releaseRestorePath.future;
      case 2:
        secondPathStarted.complete();
        await releaseSecondPath.future;
    }
    return path;
  }
}

class _RestoreRaceNotifier extends CatCatchNotifier {
  _RestoreRaceNotifier(super.ref);

  void setTasksForTest(List<CatCatchTask> tasks) => state = tasks;

  @override
  Future<bool> startBackgroundServiceForTask() async => true;

  @override
  Future<String?> executeTaskForTask({
    required CatCatchTask task,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) async =>
      null;
}

CatCatchTask _task({
  required String id,
  required String url,
  TaskStatus status = TaskStatus.paused,
  List<StepStatus> steps = const [],
}) =>
    CatCatchTask(
      id: id,
      url: url,
      expectedDurationSec: 30,
      status: status,
      steps: steps,
      createdAt: DateTime(2025, 1, 1),
    );

Future<void> _expectAutomaticRetry({
  required ProviderContainer container,
  required _RestoreRaceNotifier notifier,
  required _ControlledDocuments documents,
  required File tasksFile,
  required String currentTaskId,
  required String currentTaskUrl,
  required String storedTaskId,
  required String removedTaskId,
}) async {
  final recovered = Completer<void>();
  final subscription = container.listen<List<CatCatchTask>>(
    catcatchTasksProvider,
    (_, tasks) {
      if (tasks.any(
            (task) => task.id == currentTaskId && task.url == currentTaskUrl,
          ) &&
          tasks.any((task) => task.id == storedTaskId) &&
          tasks.every((task) => task.id != removedTaskId)) {
        if (!recovered.isCompleted) recovered.complete();
      }
    },
  );

  try {
    await documents.restorePathStarted.future.timeout(
      const Duration(seconds: 5),
    );
    documents.releaseRestorePath.complete();
    documents.releaseSecondPath.complete();

    await recovered.future.timeout(const Duration(seconds: 5));
    await notifier.waitForTaskSnapshotWritesForTesting();

    final tasks = container.read(catcatchTasksProvider);
    expect(
      tasks.map((task) => task.id).toSet(),
      {currentTaskId, storedTaskId},
    );
    expect(
      tasks.singleWhere((task) => task.id == currentTaskId).url,
      currentTaskUrl,
    );

    final persisted = jsonDecode(await tasksFile.readAsString()) as List;
    expect(
      persisted.map((entry) => (entry as Map)['id']).toSet(),
      {currentTaskId, storedTaskId},
    );
    expect(
      persisted
          .map((entry) => CatCatchTask.fromMap(entry as Map<String, dynamic>))
          .singleWhere((task) => task.id == currentTaskId)
          .url,
      currentTaskUrl,
    );
  } finally {
    if (!documents.releaseRestorePath.isCompleted) {
      documents.releaseRestorePath.complete();
    }
    if (!documents.releaseSecondPath.isCompleted) {
      documents.releaseSecondPath.complete();
    }
    subscription.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PathProviderPlatform originalPathProvider;
  late _ControlledDocuments documents;
  late ProviderContainer container;
  late _RestoreRaceNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('catcatch_restore_');
    originalPathProvider = PathProviderPlatform.instance;
    documents = _ControlledDocuments(directory.path);
    PathProviderPlatform.instance = documents;
    AppStorage.resetCache();
    container = ProviderContainer(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          notifier = _RestoreRaceNotifier(ref);
          return notifier;
        }),
      ],
    );
    container.read(catcatchTasksProvider);
  });

  tearDown(() async {
    container.dispose();
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  test(
    'restore retains removals made after a failed read for the next retry',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final task = _task(
        id: 'removed-after-failed-restore',
        url: 'https://example.com/removed.mp4',
      );
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      const unreadableSnapshot = '[{not-json}]';
      await tasksFile.writeAsString(unreadableSnapshot);
      notifier.setTasksForTest([task]);

      final failedRestore = notifier.restoreUnfinishedTasks();
      await documents.restorePathStarted.future;
      documents.releaseRestorePath.complete();
      await failedRestore;

      notifier.removeTask(task.id);
      await tasksFile.writeAsString(jsonEncode([task.toMap()]));
      await notifier.restoreUnfinishedTasks();
      await notifier.removeTasksPersisted(['persistence-barrier']);

      expect(container.read(catcatchTasksProvider), isEmpty);
      expect(jsonDecode(await tasksFile.readAsString()), isEmpty);
    },
  );

  test(
    'snapshot queued during restore is replaced with reconciled state',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final storedTask = _task(
        id: 'stored-before-snapshot',
        url: 'https://example.com/stored.mp4',
      );
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      await tasksFile.writeAsString(jsonEncode([storedTask.toMap()]));

      final firstRestore = notifier.restoreUnfinishedTasks();
      try {
        await documents.restorePathStarted.future;
        notifier.failAllRunningTasks(error: 'application shutdown');
        await Future.any([
          documents.secondPathStarted.future,
          notifier.waitForTaskSnapshotWritesForTesting(),
        ]);

        documents.releaseRestorePath.complete();
        await firstRestore;
        expect(
          container.read(catcatchTasksProvider).map((task) => task.id),
          ['stored-before-snapshot'],
        );

        documents.releaseSecondPath.complete();
        await notifier.waitForTaskSnapshotWritesForTesting();

        expect(
          container.read(catcatchTasksProvider).map((task) => task.id),
          ['stored-before-snapshot'],
        );
        final persisted = jsonDecode(await tasksFile.readAsString()) as List;
        expect(
          persisted.map((entry) => (entry as Map)['id']),
          ['stored-before-snapshot'],
        );
      } finally {
        if (!documents.releaseRestorePath.isCompleted) {
          documents.releaseRestorePath.complete();
        }
        if (!documents.releaseSecondPath.isCompleted) {
          documents.releaseSecondPath.complete();
        }
        await firstRestore;
        await notifier.waitForTaskSnapshotWritesForTesting();
      }
    },
  );

  test(
    'successful replacement snapshot clears a deferred-write marker',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final storedTask = _task(
        id: 'stored-before-deferred-write',
        url: 'https://example.com/stored.mp4',
      );
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      await tasksFile.writeAsString(jsonEncode([storedTask.toMap()]));

      final firstRestore = notifier.restoreUnfinishedTasks();
      try {
        await documents.restorePathStarted.future;
        notifier.failAllRunningTasks(error: 'application shutdown');
        await Future.any([
          documents.secondPathStarted.future,
          notifier.waitForTaskSnapshotWritesForTesting(),
        ]);

        documents.releaseRestorePath.complete();
        await firstRestore;
        documents.releaseSecondPath.complete();
        await notifier.waitForTaskSnapshotWritesForTesting();

        expect(
          container.read(catcatchTasksProvider).map((task) => task.id),
          ['stored-before-deferred-write'],
        );

        AppStorage.resetCache();
        documents.failNextPathRequest = true;
        notifier.setTasksForTest([]);
        notifier.failAllRunningTasks(error: 'application shutdown');
        await notifier.waitForTaskSnapshotWritesForTesting();

        expect(
          container.read(catcatchTasksProvider),
          isEmpty,
        );
        expect(
          (jsonDecode(await tasksFile.readAsString()) as List)
              .map((entry) => (entry as Map)['id']),
          ['stored-before-deferred-write'],
        );

        await notifier.restoreUnfinishedTasks();

        expect(container.read(catcatchTasksProvider), isEmpty);
      } finally {
        if (!documents.releaseRestorePath.isCompleted) {
          documents.releaseRestorePath.complete();
        }
        if (!documents.releaseSecondPath.isCompleted) {
          documents.releaseSecondPath.complete();
        }
        await firstRestore;
        await notifier.waitForTaskSnapshotWritesForTesting();
      }
    },
  );

  test(
    'restore loads persisted tasks after deferring a pending snapshot write',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final storedTask = _task(
        id: 'stored-before-mutation',
        url: 'https://example.com/stored.mp4',
      );
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      await tasksFile.writeAsString(jsonEncode([storedTask.toMap()]));

      notifier.addTask(
        'https://example.com/concurrent-add.mp4',
        30,
        taskId: 'concurrent-add',
      );
      await documents.restorePathStarted.future;
      final restore = notifier.restoreUnfinishedTasks();
      try {
        documents.releaseRestorePath.complete();
        await restore;
        await notifier.removeTasksPersisted(['persistence-barrier']);

        final expectedIds = {'stored-before-mutation', 'concurrent-add'};
        expect(
          container.read(catcatchTasksProvider).map((task) => task.id).toSet(),
          expectedIds,
        );
        final persisted = jsonDecode(await tasksFile.readAsString()) as List;
        expect(
          persisted.map((entry) => (entry as Map)['id']).toSet(),
          expectedIds,
        );
      } finally {
        if (!documents.releaseRestorePath.isCompleted) {
          documents.releaseRestorePath.complete();
        }
        await restore;
        await notifier.removeTasksPersisted(['persistence-barrier']);
      }
    },
  );

  test(
    'automatically retries a transient restore failure and persists reconciled state',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      final persistedCurrentTask = _task(
        id: 'current-task',
        url: 'https://example.com/persisted-version.mp4',
      );
      final storedTask = _task(
        id: 'stored-task',
        url: 'https://example.com/stored.mp4',
      );
      final removedTask = _task(
        id: 'removed-task',
        url: 'https://example.com/removed.mp4',
      );
      final originalSnapshot = jsonEncode([
        persistedCurrentTask.toMap(),
        storedTask.toMap(),
        removedTask.toMap(),
      ]);
      await tasksFile.writeAsString(originalSnapshot);
      notifier.setTasksForTest([persistedCurrentTask]);
      documents.failNextPathRequest = true;

      final currentTask = _task(
        id: 'current-task',
        url: 'https://example.com/current-version.mp4',
      );
      final recovery = _expectAutomaticRetry(
        container: container,
        notifier: notifier,
        documents: documents,
        tasksFile: tasksFile,
        currentTaskId: currentTask.id,
        currentTaskUrl: currentTask.url,
        storedTaskId: storedTask.id,
        removedTaskId: removedTask.id,
      );

      await notifier.restoreUnfinishedTasks();
      expect(await tasksFile.readAsString(), originalSnapshot);
      notifier.setTasksForTest([currentTask]);
      notifier.removeTask(removedTask.id);
      await recovery;
    },
  );

  test(
    'automatically retries restore after a queued task snapshot write fails',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      final storedTask = _task(
        id: 'stored-task-after-write-failure',
        url: 'https://example.com/stored.mp4',
      );
      final currentTask = _task(
        id: 'current-task-after-write-failure',
        url: 'https://example.com/current.mp4',
      );
      final removedTask = _task(
        id: 'removed-task-after-write-failure',
        url: 'https://example.com/removed.mp4',
      );
      final originalSnapshot = jsonEncode([
        currentTask.toMap(),
        storedTask.toMap(),
        removedTask.toMap(),
      ]);
      await tasksFile.writeAsString(originalSnapshot);

      final initialTask = _task(
        id: currentTask.id,
        url: 'https://example.com/initial.mp4',
      );
      notifier.setTasksForTest([initialTask, removedTask]);
      documents.failPathRequestAttempt = 2;
      notifier.removeTask(removedTask.id);
      await notifier.waitForTaskSnapshotWritesForTesting();
      expect(await tasksFile.readAsString(), originalSnapshot);
      await notifier.restoreUnfinishedTasks();
      expect(
        container.read(catcatchTasksProvider).map((task) => task.id),
        [initialTask.id],
      );

      final updatedCurrentTask = _task(
        id: initialTask.id,
        url: 'https://example.com/updated.mp4',
      );
      final recovery = _expectAutomaticRetry(
        container: container,
        notifier: notifier,
        documents: documents,
        tasksFile: tasksFile,
        currentTaskId: updatedCurrentTask.id,
        currentTaskUrl: updatedCurrentTask.url,
        storedTaskId: storedTask.id,
        removedTaskId: removedTask.id,
      );

      notifier.setTasksForTest([updatedCurrentTask]);
      await recovery;
    },
  );

  test(
    'failed restore preserves stored bytes through mutation and retry',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final tasksFile = File('${persistedDirectory.path}/tasks.json');
      const unreadableSnapshot = '[{not-json}]';
      await tasksFile.writeAsString(unreadableSnapshot);
      final inMemoryTask = _task(
        id: 'in-memory-before-restore',
        url: 'https://example.com/current.mp4',
      );
      notifier.setTasksForTest([inMemoryTask]);

      final failedRestore = notifier.restoreUnfinishedTasks();
      await documents.restorePathStarted.future;
      documents.releaseRestorePath.complete();
      await failedRestore;

      expect(
        container.read(catcatchTasksProvider).map((task) => task.id),
        ['in-memory-before-restore'],
      );

      notifier.addTask(
        'https://example.com/added-after-failure.mp4',
        30,
        taskId: 'added-after-failure',
      );
      await notifier.restoreUnfinishedTasks();
      expect(await tasksFile.readAsString(), unreadableSnapshot);

      final recoveredStoredTask = _task(
        id: 'stored-task',
        url: 'https://example.com/stored.mp4',
      );
      final storedVersionOfAddedTask = _task(
        id: 'added-after-failure',
        url: 'https://example.com/persisted-version.mp4',
      );
      await tasksFile.writeAsString(
        jsonEncode([
          recoveredStoredTask.toMap(),
          storedVersionOfAddedTask.toMap(),
        ]),
      );

      await notifier.restoreUnfinishedTasks();
      await notifier.removeTasksPersisted(['persistence-barrier']);

      final tasks = container.read(catcatchTasksProvider);
      expect(
        tasks.map((task) => task.id).toSet(),
        {'in-memory-before-restore', 'added-after-failure', 'stored-task'},
      );
      expect(
        tasks.where((task) => task.id == 'added-after-failure'),
        hasLength(1),
      );
      expect(
        tasks.singleWhere((task) => task.id == 'added-after-failure').url,
        'https://example.com/added-after-failure.mp4',
      );

      final persisted = jsonDecode(await tasksFile.readAsString()) as List;
      expect(persisted, hasLength(3));
      expect(
        persisted.map((entry) => (entry as Map)['id']).toSet(),
        {'in-memory-before-restore', 'added-after-failure', 'stored-task'},
      );
    },
  );

  test(
    'restore keeps a concurrent task and prefers its in-memory version',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final persistedDuplicate = _task(
        id: 'concurrent-task',
        url: 'https://example.com/persisted-version.mp4',
      );
      final persistedRunning = _task(
        id: 'persisted-running',
        url: 'https://example.com/running.mp4',
        status: TaskStatus.running,
      );
      final interruptedSelection = _task(
        id: 'legacy-selection',
        url: 'https://example.com/legacy.mp4',
        status: TaskStatus.running,
        steps: [StepStatus.running(StepType.userSelecting)],
      );
      final removedDuringRestore = _task(
        id: 'removed-during-restore',
        url: 'https://example.com/removed.mp4',
      );
      await File('${persistedDirectory.path}/tasks.json').writeAsString(
        jsonEncode([
          persistedDuplicate.toMap(),
          persistedRunning.toMap(),
          interruptedSelection.toMap(),
          removedDuringRestore.toMap(),
        ]),
      );

      final restore = notifier.restoreUnfinishedTasks();
      const expectedIds = {
        'concurrent-task',
        'persisted-running',
        'legacy-selection',
      };
      try {
        await documents.restorePathStarted.future;

        notifier.addTask(
          'https://example.com/in-memory-version.mp4',
          30,
          taskId: 'concurrent-task',
        );
        await documents.secondPathStarted.future;
        notifier.removeTask('removed-during-restore');

        documents.releaseRestorePath.complete();
        await restore;

        final tasks = container.read(catcatchTasksProvider);
        expect(tasks.map((task) => task.id).toSet(), expectedIds);
        expect(tasks, hasLength(3));
        expect(
          tasks.singleWhere((task) => task.id == 'concurrent-task').url,
          'https://example.com/in-memory-version.mp4',
        );
        expect(
          tasks.singleWhere((task) => task.id == 'persisted-running').status,
          TaskStatus.paused,
        );
        expect(
          tasks.singleWhere((task) => task.id == 'legacy-selection').status,
          TaskStatus.failed,
        );
      } finally {
        if (!documents.releaseRestorePath.isCompleted) {
          documents.releaseRestorePath.complete();
        }
        if (!documents.releaseSecondPath.isCompleted) {
          documents.releaseSecondPath.complete();
        }
        await restore;
        await notifier.removeTasksPersisted(['persistence-barrier']);
      }

      final persistedTasks = (jsonDecode(
        await File(
          '${persistedDirectory.path}/tasks.json',
        ).readAsString(),
      ) as List)
          .map(
            (task) => CatCatchTask.fromMap(
              Map<String, dynamic>.from(task as Map),
            ),
          )
          .toList();
      expect(persistedTasks.map((task) => task.id).toSet(), expectedIds);
    },
  );

  test(
    'overlapping restores keep removal tracking until both finish',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final removedTask = _task(
        id: 'removed-between-restores',
        url: 'https://example.com/removed.mp4',
      );
      await File(
        '${persistedDirectory.path}/tasks.json',
      ).writeAsString(jsonEncode([removedTask.toMap()]));

      final firstRestore = notifier.restoreUnfinishedTasks();
      final secondRestore = notifier.restoreUnfinishedTasks();
      try {
        await documents.restorePathStarted.future;
        await documents.secondPathStarted.future;

        documents.releaseRestorePath.complete();
        await firstRestore;
        notifier.removeTask(removedTask.id);

        documents.releaseSecondPath.complete();
        await secondRestore;
        expect(container.read(catcatchTasksProvider), isEmpty);
      } finally {
        if (!documents.releaseRestorePath.isCompleted) {
          documents.releaseRestorePath.complete();
        }
        if (!documents.releaseSecondPath.isCompleted) {
          documents.releaseSecondPath.complete();
        }
        await Future.wait([firstRestore, secondRestore]);
        await notifier.removeTasksPersisted(['persistence-barrier']);
      }

      final persistedTasks = jsonDecode(
        await File(
          '${persistedDirectory.path}/tasks.json',
        ).readAsString(),
      ) as List;
      expect(persistedTasks, isEmpty);
    },
  );

  test(
    'restore waits for a pending reconciliation write before loading',
    () async {
      final persistedDirectory = Directory('${directory.path}/catcatch')
        ..createSync();
      final removedTask = _task(
        id: 'removed-before-pending-write',
        url: 'https://example.com/removed.mp4',
      );
      await File(
        '${persistedDirectory.path}/tasks.json',
      ).writeAsString(jsonEncode([removedTask.toMap()]));

      final firstRestore = notifier.restoreUnfinishedTasks();
      Future<void>? secondRestore;
      try {
        await documents.restorePathStarted.future;
        notifier.removeTask(removedTask.id);
        await documents.secondPathStarted.future;

        documents.releaseRestorePath.complete();
        await firstRestore;

        expect(documents.releaseSecondPath.isCompleted, isFalse);
        secondRestore = notifier.restoreUnfinishedTasks();

        documents.releaseSecondPath.complete();
        await secondRestore;
        expect(container.read(catcatchTasksProvider), isEmpty);
      } finally {
        if (!documents.releaseRestorePath.isCompleted) {
          documents.releaseRestorePath.complete();
        }
        if (!documents.releaseSecondPath.isCompleted) {
          documents.releaseSecondPath.complete();
        }
        await firstRestore;
        if (secondRestore != null) await secondRestore;
        await notifier.removeTasksPersisted([removedTask.id]);
      }

      final persistedTasks = jsonDecode(
        await File(
          '${persistedDirectory.path}/tasks.json',
        ).readAsString(),
      ) as List;
      expect(persistedTasks, isEmpty);
    },
  );
}
