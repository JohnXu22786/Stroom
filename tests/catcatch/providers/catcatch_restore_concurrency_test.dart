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
  int pathRequests = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
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

  @override
  Future<bool> startBackgroundServiceForTask() async => true;

  @override
  Future<String?> executeTaskForTask({
    required CatCatchTask task,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) async => null;
}

CatCatchTask _task({
  required String id,
  required String url,
  TaskStatus status = TaskStatus.paused,
  List<StepStatus> steps = const [],
}) => CatCatchTask(
  id: id,
  url: url,
  expectedDurationSec: 30,
  status: status,
  steps: steps,
  createdAt: DateTime(2025, 1, 1),
);

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

      final persistedTasks =
          (jsonDecode(
                    await File(
                      '${persistedDirectory.path}/tasks.json',
                    ).readAsString(),
                  )
                  as List)
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

      final persistedTasks =
          jsonDecode(
                await File(
                  '${persistedDirectory.path}/tasks.json',
                ).readAsString(),
              )
              as List;
      expect(persistedTasks, isEmpty);
    },
  );
}
