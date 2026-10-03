import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/main.dart'
    show catcatchStartupProvider, taskFlowExecutionRestorationProvider;
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _DocumentsDirectory extends PathProviderPlatform {
  _DocumentsDirectory(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _BlockedCatCatchRestore extends CatCatchNotifier {
  _BlockedCatCatchRestore(super.ref, this.started, this.release);
  final Completer<void> started;
  final Completer<void> release;

  @override
  Future<void> restoreUnfinishedTasks() async {
    started.complete();
    await release.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryDirectory;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('flow_restore_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance =
        _DocumentsDirectory(temporaryDirectory.path);
    AppStorage.resetCache();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
    await temporaryDirectory.delete(recursive: true);
  });

  test('missing flow records confirm ownership and unlock standalone tasks',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(taskFlowExecutionRestorationProvider.future),
        isTrue);
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.ready);
  });

  test('older flow records with explicit subTasks still restore', () async {
    final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
      ..createSync();
    File('${flowDirectory.path}/executions.json').writeAsStringSync(
        '[{"id":"legacy-run","flowId":"flow","flowName":"旧流程",'
        '"status":"completed","subTasks":[]}]');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(taskFlowExecutionRestorationProvider.future),
        isTrue);
    expect(container.read(taskFlowExecutionsProvider).single.id, 'legacy-run');
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.ready);
  });

  test('startup locks child controls before any task restore can publish',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final container = ProviderContainer(overrides: [
      catcatchTasksProvider.overrideWith(
          (ref) => _BlockedCatCatchRestore(ref, started, release)),
    ]);
    addTearDown(container.dispose);

    final startup = container.read(catcatchStartupProvider.future);
    await started.future;
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.restoring);
    release.complete();
    await startup;
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.ready);
  });

  test('corrupt flow records retain the file and keep task controls locked',
      () async {
    final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
      ..createSync();
    final file = File('${flowDirectory.path}/executions.json')
      ..writeAsStringSync('{broken json');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(taskFlowExecutionRestorationProvider.future),
        isFalse);
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.failed);
    expect(file.readAsStringSync(), '{broken json');
  });

  test('a malformed child ownership entry cannot unlock task controls',
      () async {
    final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
      ..createSync();
    final file = File('${flowDirectory.path}/executions.json')
      ..writeAsStringSync('[{"id":"run","subTasks":[{"bad":"child"}]}]');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(taskFlowExecutionRestorationProvider.future),
        isFalse);
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.failed);
    expect(
        file.readAsStringSync(), '[{"id":"run","subTasks":[{"bad":"child"}]}]');
  });

  test('unreadable flow record path keeps task controls locked', () async {
    final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
      ..createSync();
    Directory('${flowDirectory.path}/executions.json').createSync();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(taskFlowExecutionRestorationProvider.future),
        isFalse);
    expect(container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.failed);
  });
}
