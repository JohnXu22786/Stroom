import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/providers/persistable_notifier.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';

class _DocumentsDirectory extends PathProviderPlatform {
  _DocumentsDirectory(this.path);

  final String path;
  Future<void> Function()? beforeResolve;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    await beforeResolve?.call();
    return path;
  }
}

class _SnapshotNotifier extends StateNotifier<List<String>>
    with PersistableNotifier<List<String>> {
  _SnapshotNotifier() : super(['first']);

  final serialized = <List<String>>[];

  void replace(String value) => state = [value];

  @override
  String get persistenceFileName => 'snapshots.json';

  @override
  List<String> fromJsonList(List<dynamic> json) => json.cast<String>();

  @override
  List<dynamic> toJsonList(List<String> state) {
    serialized.add(List.of(state));
    return state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late PathProviderPlatform originalPlatform;
  late _DocumentsDirectory platform;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('flow_persistence_');
    originalPlatform = PathProviderPlatform.instance;
    platform = _DocumentsDirectory(tempDir.path);
    PathProviderPlatform.instance = platform;
    AppStorage.resetCache();
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPlatform;
    AppStorage.resetCache();
    await tempDir.delete(recursive: true);
  });

  test('flow persistence reports failure, retains memory and retries',
      () async {
    final obstruction = File('${tempDir.path}/task_flows');
    await obstruction.writeAsString('blocked');
    final notifier = TaskFlowNotifier();
    addTearDown(notifier.dispose);
    final id = notifier.addFlow(name: 'unsaved flow');

    await expectLater(notifier.persist(), completion(isFalse));
    expect(notifier.persistenceError, isA<FileSystemException>());
    expect(notifier.getFlow(id)?.name, 'unsaved flow');
    await obstruction.delete();
    await expectLater(notifier.persist(), completion(isTrue));
    expect(notifier.persistenceError, isNull);
    final saved = jsonDecode(
        await File('${tempDir.path}/task_flows/flows.json').readAsString());
    expect(saved.single['id'], id);
    expect(saved.single['name'], 'unsaved flow');
  });

  test('execution persistence reports failure and retries the latest state',
      () async {
    final obstruction = File('${tempDir.path}/task_flows');
    await obstruction.writeAsString('blocked');
    final notifier = TaskFlowExecutionNotifier();
    addTearDown(notifier.dispose);
    final id = notifier.addExecution(flowId: 'flow', flowName: 'execution');
    await expectLater(notifier.persist(), completion(isFalse));
    expect(notifier.persistenceError, isA<FileSystemException>());
    expect(notifier.state.single.id, id);

    notifier.completeExecution(id);
    await obstruction.delete();
    await expectLater(notifier.persist(), completion(isTrue));
    expect(notifier.persistenceError, isNull);
    final saved = jsonDecode(
        await File('${tempDir.path}/task_flows/executions.json')
            .readAsString());
    expect(saved.single['id'], id);
    expect(saved.single['status'], 'completed');
  });

  test('queued snapshots are captured before IO and survive disposal',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    platform.beforeResolve = () async {
      if (!started.isCompleted) started.complete();
      await release.future;
    };
    final notifier = _SnapshotNotifier();
    final first = notifier.persist();
    await started.future;
    notifier.replace('second');
    final second = notifier.persist();
    notifier.dispose();
    try {
      expect(notifier.serialized, [
        ['first'],
        ['second'],
      ]);
    } finally {
      release.complete();
      await Future.wait([first, second]);
    }
    final saved = jsonDecode(
        await File('${tempDir.path}/task_flows/snapshots.json').readAsString());
    expect(saved, ['second']);
  });

  test('disposing executions flushes the final debounced progress', () async {
    final notifier = TaskFlowExecutionNotifier();
    final id = notifier.addExecution(flowId: 'flow', flowName: 'execution');
    await notifier.persistenceResult;
    notifier.completeExecution(id);
    notifier.dispose();
    await expectLater(notifier.persistenceResult, completion(isTrue));
    final saved = jsonDecode(
        await File('${tempDir.path}/task_flows/executions.json')
            .readAsString());
    expect(saved.single['status'], 'completed');
  });
}
