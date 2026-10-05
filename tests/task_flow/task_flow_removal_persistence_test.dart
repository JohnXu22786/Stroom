// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/services/attachment_storage.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Backgrounds extends BackgroundTaskNotifier {
  List<BackgroundTask> get tasks => state;
  void load(List<BackgroundTask> tasks) => state = tasks;
}

/// Hold the real atomic removal write at its first temporary directory.
class _RemovalDirectory implements Directory {
  _RemovalDirectory(this.delegate, this.started, this.release, this.fails);
  final Directory delegate;
  final Completer<void> started;
  final Completer<void> release;
  final bool fails;

  @override
  String get path => delegate.path;
  @override
  Future<bool> exists() => delegate.exists();
  @override
  Future<Directory> create({bool recursive = false}) =>
      delegate.create(recursive: recursive);
  @override
  Future<Directory> createTemp([String? prefix]) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
      if (fails) throw const FileSystemException('held removal failed');
    }
    return delegate.createTemp(prefix);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<String>> _savedIds(File file) async =>
    (jsonDecode(await file.readAsString()) as List)
        .map((entry) => entry['id'] as String)
        .toList()
      ..sort();

Future<void> _expectSavedIds(File file, List<String> expected) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  var actual = await _savedIds(file);
  while (actual.join(',') != expected.join(',') &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    actual = await _savedIds(file);
  }
  expect(actual, expected);
}

class _Synthesis extends TaskListNotifier {
  _Synthesis(super.ref);
  void load(List<SynthesisTask> tasks) => state = tasks;
}

class _CatCatch extends CatCatchNotifier {
  _CatCatch(super.ref);
  void load(List<catcatch.CatCatchTask> tasks) => state = tasks;
}

class _HeldRemoval extends TaskFlowExecutionNotifier {
  final started = Completer<void>();
  final release = Completer<void>();
  bool holdNextWrite = false;
  bool failHeldWrite = false;

  Future<bool> _holdWrite(Future<bool> Function() write) async {
    if (holdNextWrite) {
      holdNextWrite = false;
      if (failHeldWrite) {
        started.complete();
        await release.future;
        return false;
      }
      // Enqueue the atomic write before blocking its caller. This mirrors the
      // real writer, where a held filesystem operation already owns its place
      // in the persistence queue before later barrier-dependent flushes queue.
      final pending = write();
      started.complete();
      await release.future;
      return pending;
    }
    return write();
  }

  @override
  Future<bool> persist() => _holdWrite(super.persist);

  @override
  Future<bool> persistSnapshot(List<TaskFlowExecution> snapshot) =>
      _holdWrite(() => super.persistSnapshot(snapshot));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PathProviderPlatform originalPathProvider;
  late TaskFlowExecutionNotifier executions;
  late _Backgrounds backgrounds;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flow_removal_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
    executions = TaskFlowExecutionNotifier();
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    backgrounds = _Backgrounds();
  });

  tearDown(() async {
    if (executions.mounted) executions.dispose();
    await backgrounds.pendingPersistence;
    backgrounds.dispose();
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  for (final fails in [false, true]) {
    test(
        'disposal owns a debounced survivor update after ${fails ? 'failed' : 'saved'} atomic removal',
        () async {
      final removed = TaskFlowExecution(
          id: 'removed',
          flowId: 'f',
          flowName: 'Removed',
          status: FlowExecutionStatus.completed);
      final survivor = TaskFlowExecution(
          id: 'survivor',
          flowId: 'f',
          flowName: 'Survivor',
          status: FlowExecutionStatus.running,
          subTasks: [
            FlowSubTask(
                id: 'step',
                blockTypeKey: 'chat',
                blockLabel: 'Chat',
                subTaskId: 'child',
                subTaskType: 'background'),
          ]);
      expect(await executions.addExecutions([removed, survivor]), isTrue);
      final parent = p.join(directory.path, 'task_flows');
      final started = Completer<void>();
      final release = Completer<void>();
      final outerZone = Zone.current;
      await IOOverrides.runZoned(() async {
        // Only debounce requests this update's persistence. Bulk removal then
        // cancels that timer while its real AtomicFile write is held.
        executions.updateSubTaskStatus(survivor.id, 'step', TaskStatus.paused);
        final removal = executions.removeExecutionsPersisted([removed.id]);
        await started.future.timeout(const Duration(seconds: 5));
        executions.dispose();
        release.complete();
        expect(await removal.timeout(const Duration(seconds: 5)), !fails);
        // Observe the automatic flush reaching disk without requesting persist.
        // Its barrier continuation can enqueue after the removal future settles.
        final file = File(p.join(parent, 'executions.json'));
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          final saved = jsonDecode(await file.readAsString()) as List;
          final current =
              saved.singleWhere((entry) => entry['id'] == survivor.id);
          if (current['status'] == FlowExecutionStatus.paused.name) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(await executions.persistenceResult, isTrue);
        expect(await _savedIds(file),
            fails ? ['removed', 'survivor'] : ['survivor']);
        final restored = TaskFlowExecutionNotifier();
        try {
          expect(await restored.restoreFromPersistence(), isTrue);
          final restoredIds = restored.executions.map((e) => e.id).toList()
            ..sort();
          expect(restoredIds, fails ? ['removed', 'survivor'] : ['survivor']);
          expect(restored.execution(removed.id) != null, fails);
          final savedSurvivor = restored.execution(survivor.id)!;
          expect(savedSurvivor.status, FlowExecutionStatus.paused);
          expect(savedSurvivor.subTasks.single.outcome, FlowStepOutcome.paused);
        } finally {
          restored.dispose();
        }
      }, createDirectory: (path) {
        final delegate = outerZone.run(() => Directory(path));
        return p.normalize(path) == p.normalize(parent)
            ? _RemovalDirectory(delegate, started, release, fails)
            : delegate;
      });
    });

    test(
        'disposed flush ${fails ? 'retains failed' : 'excludes saved'} removals',
        () async {
      final held = _HeldRemoval();
      addTearDown(() {
        if (held.mounted) held.dispose();
      });
      final old = TaskFlowExecution(
          id: 'old',
          flowId: 'f',
          flowName: 'Old',
          status: FlowExecutionStatus.completed);
      expect(await held.addExecutions([old]), isTrue);
      held.holdNextWrite = true;
      held.failHeldWrite = fails;
      final removal = held.removeExecutionsPersisted([old.id]);
      await held.started.future;
      final pendingWrite = held.persist();
      held.dispose();
      held.release.complete();
      expect(await removal.timeout(const Duration(seconds: 5)), !fails);
      expect(await pendingWrite.timeout(const Duration(seconds: 5)), isTrue);
      final file =
          File(p.join(directory.path, 'task_flows', 'executions.json'));
      final saved = jsonDecode(await file.readAsString()) as List;
      expect(saved.map((e) => e['id']), fails ? ['old'] : isEmpty);
    });
  }

  test('durable bulk removal retains a shared picker copy until its last owner',
      () async {
    final path = await AttachmentStorage.saveFile(
        'notes.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')));
    final copy = File(p.join(directory.path, path));
    final owners = [
      for (final id in ['first', 'second'])
        TaskFlowExecution(
            id: id,
            flowId: 'f',
            flowName: id,
            status: FlowExecutionStatus.completed,
            inputStoragePath: path)
    ];
    expect(await executions.addExecutions(owners), isTrue);
    expect(await executions.removeExecutionsPersisted(['first']), isTrue);
    expect(await copy.exists(), isTrue);
    expect(await executions.removeExecutionsPersisted(['second']), isTrue);
    expect(await copy.exists(), isFalse);
  });

  test('bulk removal keeps a copy reserved by a queued registration', () async {
    final path = await AttachmentStorage.saveFile(
        'notes.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')));
    final copy = File(p.join(directory.path, path));
    final held = _HeldRemoval();
    addTearDown(held.dispose);
    final old = TaskFlowExecution(
        id: 'old',
        flowId: 'f',
        flowName: 'Old',
        status: FlowExecutionStatus.completed,
        inputStoragePath: path);
    expect(await held.addExecutions([old]), isTrue);
    held.holdNextWrite = true;
    final removal = held.removeExecutionsPersisted([old.id]);
    await held.started.future;
    final next = TaskFlowExecution(
        id: 'next',
        flowId: 'f',
        flowName: 'Next',
        status: FlowExecutionStatus.waiting,
        inputStoragePath: path);
    final registration = held.addExecutions([next]);
    expect(held.execution(next.id), isNull,
        reason:
            'the removal snapshot is still holding the shared mutation turn');
    held.release.complete();
    expect(
        await Future.wait([removal, registration])
            .timeout(const Duration(seconds: 5)),
        [true, true]);
    expect(held.executions.single.id, next.id);
    expect(await copy.exists(), isTrue);
    final file = File(p.join(directory.path, 'task_flows', 'executions.json'));
    final saved = (jsonDecode(await file.readAsString()) as List).single;
    expect(saved['id'], next.id);
    expect(saved['inputStoragePath'], path);
  });

  test(
      'bulk cleanup releases mutation turn before a queued retry holding its input lock',
      () async {
    final path = await AttachmentStorage.saveFile(
        'notes.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')));
    final copy = File(p.join(directory.path, path));
    final held = _HeldRemoval();
    addTearDown(held.dispose);
    final old = TaskFlowExecution(
        id: 'old',
        flowId: 'f',
        flowName: 'Old',
        status: FlowExecutionStatus.completed,
        inputStoragePath: path);
    expect(await held.addExecutions([old]), isTrue);
    held.holdNextWrite = true;
    final removal = held.removeExecutionsPersisted([old.id]);
    await held.started.future;
    final entered = Completer<void>();
    final retry = TaskFlowExecution(
        id: 'retry',
        flowId: 'f',
        flowName: 'Retry',
        status: FlowExecutionStatus.waiting,
        inputStoragePath: path);
    final registration = held.withInputStoragePathLock(path, () {
      entered.complete();
      return held.addExecutions([retry]);
    });
    await entered.future;
    held.release.complete();
    expect(
        await Future.wait([removal, registration])
            .timeout(const Duration(seconds: 5)),
        [true, true]);
    expect(held.executions.single.id, retry.id);
    expect(await copy.exists(), isTrue);
    final file = File(p.join(directory.path, 'task_flows', 'executions.json'));
    final saved = (jsonDecode(await file.readAsString()) as List).single;
    expect(saved['id'], retry.id);
    expect(saved['inputStoragePath'], path);
  });

  test('removal queued after a rejected registration never saves its records',
      () async {
    final held = _HeldRemoval();
    addTearDown(held.dispose);
    final old = TaskFlowExecution(
        id: 'old',
        flowId: 'f',
        flowName: 'Old',
        status: FlowExecutionStatus.completed);
    expect(await held.addExecutions([old]), isTrue);
    held.holdNextWrite = true;
    held.failHeldWrite = true;
    final rejected = TaskFlowExecution(
        id: 'rejected',
        flowId: 'f',
        flowName: 'Rejected',
        status: FlowExecutionStatus.waiting);
    final registration = held.addExecutions([rejected]);
    await held.started.future;
    final removal = held.removeExecutionsPersisted([old.id]);
    held.release.complete();
    expect(await registration, isFalse);
    expect(await removal, isTrue);
    expect(held.executions, isEmpty);
    final file = File(p.join(directory.path, 'task_flows', 'executions.json'));
    expect(jsonDecode(await file.readAsString()), isEmpty);
  });

  test('new registration remains durable when a removal write is pending',
      () async {
    final held = _HeldRemoval();
    addTearDown(held.dispose);
    final old = TaskFlowExecution(
        id: 'old',
        flowId: 'f',
        flowName: 'Old',
        status: FlowExecutionStatus.completed);
    expect(await held.addExecutions([old]), isTrue);
    held.holdNextWrite = true;
    final removal = held.removeExecutionsPersisted([old.id]);
    await held.started.future;
    final added = TaskFlowExecution(
        id: 'new',
        flowId: 'f',
        flowName: 'New',
        status: FlowExecutionStatus.waiting);
    final registration = held.addExecutions([added]);
    held.release.complete();
    expect(await removal, isTrue);
    expect(await registration, isTrue);
    expect(held.executions.single.id, added.id);
    final file = File(p.join(directory.path, 'task_flows', 'executions.json'));
    expect(
        (jsonDecode(await file.readAsString()) as List).single['id'], added.id);
  });

  for (final kind in ['background', 'synthesis', 'catcatch']) {
    for (final fails in [false, true]) {
      test(
          '$kind disposal flush retains additions after ${fails ? 'failed' : 'saved'} removal',
          () async {
        final container = ProviderContainer(overrides: [
          backgroundTasksProvider.overrideWith((ref) => _Backgrounds()),
          taskListProvider.overrideWith((ref) => _Synthesis(ref)),
          catcatchTasksProvider.overrideWith((ref) => _CatCatch(ref)),
        ]);
        var disposed = false;
        addTearDown(() {
          if (!disposed) container.dispose();
        });
        late Future<bool> Function(Iterable<String>) remove;
        late void Function() add;
        BackgroundTaskNotifier? backgroundNotifier;
        final speech = Completer<Uint8List>();
        final config = ProviderConfigItem(
            providerName: 'test',
            host: 'https://example.invalid/speech',
            key: 'key');
        final model = ModelConfig(name: 'test', modelId: 'test');
        if (kind == 'background') {
          final notifier =
              container.read(backgroundTasksProvider.notifier) as _Backgrounds;
          backgroundNotifier = notifier;
          notifier.load([
            BackgroundTask(
                id: 'old',
                type: BackgroundTaskType.chat,
                title: 'Old',
                status: TaskStatus.completed)
          ]);
          remove = notifier.removeTasksPersisted;
          add = () {
            notifier.addTask(
                type: BackgroundTaskType.chat,
                title: 'New',
                taskId: 'new',
                startImmediately: false);
          };
        } else if (kind == 'synthesis') {
          final notifier =
              container.read(taskListProvider.notifier) as _Synthesis;
          notifier.load([
            SynthesisTask(
                id: 'old',
                title: 'Old',
                text: 'text',
                status: TaskStatus.completed,
                providerConfig: config,
                modelConfig: model)
          ]);
          notifier.debugSynthesize = (_, __, ___) => speech.future;
          remove = notifier.removeTasksPersisted;
          add = () {
            notifier.addTask(
                taskId: 'new',
                title: 'New',
                text: 'text',
                providerConfig: config,
                modelConfig: model);
          };
        } else {
          final notifier =
              container.read(catcatchTasksProvider.notifier) as _CatCatch;
          notifier.load([
            catcatch.CatCatchTask(
                id: 'old',
                url: 'https://example.invalid/old',
                expectedDurationSec: 0,
                createdAt: DateTime.now(),
                status: catcatch.TaskStatus.completed)
          ]);
          remove = notifier.removeTasksPersisted;
          add = () {
            notifier.addTask('https://example.invalid/new', 0, taskId: 'new');
            notifier.pauseTask('new');
          };
        }
        expect(await remove(['absent']), isTrue);
        final parent = p.join(directory.path, kind);
        final file = File(p.join(parent, 'tasks.json'));
        final started = Completer<void>();
        final release = Completer<void>();
        final outerZone = Zone.current;
        await IOOverrides.runZoned(() async {
          final removal = remove(['old']);
          await started.future.timeout(const Duration(seconds: 5));
          add();
          container.dispose();
          disposed = true;
          release.complete();
          expect(await removal.timeout(const Duration(seconds: 5)), !fails);
          await _expectSavedIds(file, fails ? ['new', 'old'] : ['new']);
          await backgroundNotifier?.pendingPersistence;
        }, createDirectory: (path) {
          final delegate = outerZone.run(() => Directory(path));
          return p.normalize(path) == p.normalize(parent)
              ? _RemovalDirectory(delegate, started, release, fails)
              : delegate;
        });
        if (!speech.isCompleted) speech.complete(Uint8List(0));
        // Restore through the production parser, including running-task recovery.
        final restored = ProviderContainer();
        try {
          late List<String> ids;
          if (kind == 'background') {
            final notifier = restored.read(backgroundTasksProvider.notifier);
            await notifier.restoreFromPersistence();
            ids = restored
                .read(backgroundTasksProvider)
                .map((t) => t.id)
                .toList();
          } else if (kind == 'synthesis') {
            await restored
                .read(taskListProvider.notifier)
                .restoreFromPersistence();
            ids = restored.read(taskListProvider).map((t) => t.id).toList();
          } else {
            await restored
                .read(catcatchTasksProvider.notifier)
                .restoreUnfinishedTasks();
            ids =
                restored.read(catcatchTasksProvider).map((t) => t.id).toList();
          }
          ids.sort();
          expect(ids, fails ? ['new', 'old'] : ['new']);
        } finally {
          restored.dispose();
        }
      });
    }
  }

  for (final kind in ['synthesis', 'catcatch']) {
    test('$kind deletion failure keeps the child visible and durable for retry',
        () async {
      final container = ProviderContainer(overrides: [
        taskListProvider.overrideWith((ref) => _Synthesis(ref)),
        catcatchTasksProvider.overrideWith((ref) => _CatCatch(ref)),
      ]);
      final id = '$kind-child';
      late Future<bool> Function(Iterable<String>) remove;
      late List<String> Function() visibleIds;
      if (kind == 'synthesis') {
        final notifier =
            container.read(taskListProvider.notifier) as _Synthesis;
        notifier.load([
          SynthesisTask(
              id: id,
              title: 'Child',
              text: 'text',
              status: TaskStatus.completed,
              providerConfig: ProviderConfigItem(),
              modelConfig: ModelConfig(name: 'Test', modelId: 'test'))
        ]);
        remove = notifier.removeTasksPersisted;
        visibleIds =
            () => container.read(taskListProvider).map((t) => t.id).toList();
      } else {
        final notifier =
            container.read(catcatchTasksProvider.notifier) as _CatCatch;
        notifier.load([
          catcatch.CatCatchTask(
              id: id,
              url: 'https://example.com',
              expectedDurationSec: 0,
              createdAt: DateTime.now(),
              status: catcatch.TaskStatus.completed)
        ]);
        remove = notifier.removeTasksPersisted;
        visibleIds = () =>
            container.read(catcatchTasksProvider).map((t) => t.id).toList();
      }
      try {
        expect(await remove(['absent']), isTrue);
        final file = File(p.join(directory.path, kind, 'tasks.json'));
        final backup = File('${file.path}.bak');
        await file.rename(backup.path);
        await Directory(file.path).create();
        expect(await remove([id]), isFalse);
        expect(visibleIds(), [id]);
        expect(
            (jsonDecode(await backup.readAsString()) as List).single['id'], id);
        await Directory(file.path).delete();
        await backup.rename(file.path);
        expect(await remove([id]), isTrue);
        expect(visibleIds(), isEmpty);
        expect(jsonDecode(await file.readAsString()), isEmpty);
        // Also flush provider storage operations before releasing test storage.
        expect(await remove(['absent']), isTrue);
      } finally {
        container.dispose();
      }
    });
  }

  test('failed removal write keeps the saved cancellation for retry', () async {
    final path = await AttachmentStorage.saveFile(
        'notes.pdf', Uint8List.fromList(utf8.encode('%PDF-1.7\nreport')));
    final copy = File(p.join(directory.path, path));
    final execution = TaskFlowExecution(
      id: 'cancelled',
      flowId: 'f',
      flowName: 'Cancelled',
      status: FlowExecutionStatus.cancelled,
      inputStoragePath: path,
    );
    expect(await executions.addExecutions([execution]), isTrue);

    final file = File(p.join(directory.path, 'task_flows', 'executions.json'));
    final backup = File('${file.path}.bak');
    await file.rename(backup.path);
    await Directory(file.path).create();

    expect(await executions.removeExecutionsPersisted([execution.id]), isFalse);
    expect(executions.executions.single.id, execution.id);
    expect(await copy.exists(), isTrue);
    expect((jsonDecode(await backup.readAsString()) as List).single['id'],
        execution.id);

    await Directory(file.path).delete();
    await backup.rename(file.path);
    expect(await executions.removeExecutionsPersisted([execution.id]), isTrue);
    expect(executions.executions, isEmpty);
    expect(await copy.exists(), isFalse);
    expect(jsonDecode(await file.readAsString()), isEmpty);
  });

  test('failed child removal write retains child and parent after restart',
      () async {
    final childId = backgrounds.addTask(
      type: BackgroundTaskType.chat,
      title: 'Child',
      startImmediately: false,
    );
    // Flush the ordinary add write before forcing the removal write to fail.
    expect(await backgrounds.removeTasksPersisted(['absent']), isTrue);
    final parent = TaskFlowExecution(
      id: 'parent',
      flowId: 'f',
      flowName: 'Parent',
      status: FlowExecutionStatus.completed,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'chat',
          blockLabel: 'Child',
          subTaskId: childId,
          subTaskType: 'background',
          status: TaskStatus.completed,
        ),
      ],
    );
    expect(await executions.addExecutions([parent]), isTrue);

    final childFile = File(p.join(directory.path, 'background', 'tasks.json'));
    final backup = File('${childFile.path}.bak');
    await childFile.rename(backup.path);
    await Directory(childFile.path).create();
    expect(await backgrounds.removeTasksPersisted([childId]), isFalse);
    expect(backgrounds.tasks.single.id, childId);
    expect((jsonDecode(await backup.readAsString()) as List).single['id'],
        childId);
    final parentFile =
        File(p.join(directory.path, 'task_flows', 'executions.json'));
    expect((jsonDecode(await parentFile.readAsString()) as List).single['id'],
        parent.id);

    await Directory(childFile.path).delete();
    await backup.rename(childFile.path);
    final restored = _Backgrounds();
    await restored.restoreFromPersistence();
    expect(restored.tasks.single.id, childId);
    expect(await restored.removeTasksPersisted(['absent']), isTrue);
    restored.dispose();
  });

  test('retries a child already absent from memory after an older write fails',
      () async {
    final childId = backgrounds.addTask(
      type: BackgroundTaskType.chat,
      title: 'Child',
      startImmediately: false,
    );
    expect(await backgrounds.removeTasksPersisted(['absent']), isTrue);
    final file = File(p.join(directory.path, 'background', 'tasks.json'));
    final backup = File('${file.path}.bak');
    await file.rename(backup.path);
    await Directory(file.path).create();

    backgrounds.removeTask(childId);
    expect(await backgrounds.removeTasksPersisted([childId]), isFalse);
    expect(backgrounds.tasks, isEmpty);
    expect((jsonDecode(await backup.readAsString()) as List).single['id'],
        childId);

    await Directory(file.path).delete();
    await backup.rename(file.path);
    expect(await backgrounds.removeTasksPersisted([childId]), isTrue);
    expect(jsonDecode(await file.readAsString()), isEmpty);
  });
}
