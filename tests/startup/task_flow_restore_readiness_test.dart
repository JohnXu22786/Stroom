import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/main.dart'
    show
        asrRetryAudioStoreProvider,
        catcatchStartupProvider,
        taskFlowExecutionRestorationProvider;
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/services/asr_retry_storage.dart';
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

class _FailingRetryAudioStore extends AsrRetryAudioStore {
  @override
  Future<void> prune(Set<String> Function() referencedIds) async {
    throw const FileSystemException('retry storage unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporaryDirectory;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('flow_restore_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsDirectory(
      temporaryDirectory.path,
    );
    AppStorage.resetCache();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    AppStorage.resetCache();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'missing flow records confirm ownership and unlock standalone tasks',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(taskFlowExecutionRestorationProvider.future),
        isTrue,
      );
      expect(
        container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.ready,
      );
    },
  );

  test('older flow records with explicit subTasks still restore', () async {
    final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
      ..createSync();
    File('${flowDirectory.path}/executions.json').writeAsStringSync(
      '[{"id":"legacy-run","flowId":"flow","flowName":"旧流程",'
      '"status":"completed","subTasks":[]}]',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(taskFlowExecutionRestorationProvider.future),
      isTrue,
    );
    expect(container.read(taskFlowExecutionsProvider).single.id, 'legacy-run');
    expect(
      container.read(taskFlowExecutionRestoreStatusProvider),
      FlowExecutionRestoreStatus.ready,
    );
  });

  test(
    'startup locks child controls before any task restore can publish',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          catcatchTasksProvider.overrideWith(
            (ref) => _BlockedCatCatchRestore(ref, started, release),
          ),
        ],
      );
      addTearDown(container.dispose);

      final startup = container.read(catcatchStartupProvider.future);
      await started.future;
      expect(
        container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.restoring,
      );
      release.complete();
      await startup;
      expect(
        container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.ready,
      );
    },
  );

  test(
    'corrupt flow records retain the file and keep task controls locked',
    () async {
      final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
        ..createSync();
      final file = File('${flowDirectory.path}/executions.json')
        ..writeAsStringSync('{broken json');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(taskFlowExecutionRestorationProvider.future),
        isFalse,
      );
      expect(
        container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.failed,
      );
      expect(file.readAsStringSync(), '{broken json');
    },
  );

  test(
    'a malformed child ownership entry cannot unlock task controls',
    () async {
      final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
        ..createSync();
      final file = File('${flowDirectory.path}/executions.json')
        ..writeAsStringSync('[{"id":"run","subTasks":[{"bad":"child"}]}]');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(taskFlowExecutionRestorationProvider.future),
        isFalse,
      );
      expect(
        container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.failed,
      );
      expect(
        file.readAsStringSync(),
        '[{"id":"run","subTasks":[{"bad":"child"}]}]',
      );
    },
  );

  test('unreadable flow record path keeps task controls locked', () async {
    final flowDirectory = Directory('${temporaryDirectory.path}/task_flows')
      ..createSync();
    Directory('${flowDirectory.path}/executions.json').createSync();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(taskFlowExecutionRestorationProvider.future),
      isFalse,
    );
    expect(
      container.read(taskFlowExecutionRestoreStatusProvider),
      FlowExecutionRestoreStatus.failed,
    );
  });

  test(
    'startup prunes orphaned ASR retry audio after valid task restoration',
    () async {
      final backgroundDirectory = Directory(
        '${temporaryDirectory.path}/background',
      );
      await backgroundDirectory.create(recursive: true);
      await File('${backgroundDirectory.path}/tasks.json').writeAsString('[]');
      final retryDirectory = Directory('${backgroundDirectory.path}/asr_retry');
      await retryDirectory.create(recursive: true);
      final orphan = File(
        '${retryDirectory.path}/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.audio',
      );
      await orphan.writeAsBytes([1, 2, 3]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(catcatchStartupProvider.future);

      expect(await orphan.exists(), isFalse);
    },
  );

  test(
    'startup preserves ASR retry audio when task records are corrupt',
    () async {
      final backgroundDirectory = Directory(
        '${temporaryDirectory.path}/background',
      );
      await backgroundDirectory.create(recursive: true);
      await File(
        '${backgroundDirectory.path}/tasks.json',
      ).writeAsString('{broken json');
      final retryDirectory = Directory('${backgroundDirectory.path}/asr_retry');
      await retryDirectory.create(recursive: true);
      final orphan = File(
        '${retryDirectory.path}/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.audio',
      );
      await orphan.writeAsBytes([1, 2, 3]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(catcatchStartupProvider.future);

      expect(await orphan.exists(), isTrue);
    },
  );

  test(
    'startup prunes retry audio after sanitizing malformed versioned references',
    () async {
      const audioId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final backgroundDirectory = Directory(
        '${temporaryDirectory.path}/background',
      );
      await backgroundDirectory.create(recursive: true);
      await File('${backgroundDirectory.path}/tasks.json').writeAsString(
        '[{"id":"malformed-asr","type":"asr","title":"retry task",'
        '"status":"failed","createdAt":"2026-10-11T00:00:00.000Z",'
        '"retryData":{"type":"asr","version":2}}]',
      );
      final retryDirectory = Directory('${backgroundDirectory.path}/asr_retry');
      await retryDirectory.create(recursive: true);
      final audio = File('${retryDirectory.path}/$audioId.audio')
        ..writeAsBytesSync([1, 2, 3]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(catcatchStartupProvider.future);

      expect(await audio.exists(), isFalse);
      expect(
        container.read(backgroundTasksProvider.notifier).retryAudioCleanupSafe,
        isTrue,
      );
    },
  );

  test(
    'startup preserves retry audio when ASR retry data is not a map',
    () async {
      const audioId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const audioSha256 =
          '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';
      final backgroundDirectory = Directory(
        '${temporaryDirectory.path}/background',
      );
      await backgroundDirectory.create(recursive: true);
      final retryData = jsonEncode({
        'type': 'asr',
        'version': 2,
        'audioReference': {
          'version': 1,
          'id': audioId,
          'name': 'retry.wav',
          'format': 'wav',
          'byteLength': 3,
          'sha256': audioSha256,
        },
      });
      await File('${backgroundDirectory.path}/tasks.json').writeAsString(
        jsonEncode([
          {
            'id': 'string-retry-data',
            'type': 'asr',
            'title': 'retry task',
            'status': 'failed',
            'createdAt': DateTime.utc(2026).toIso8601String(),
            'retryData': retryData,
          },
        ]),
      );
      final retryDirectory = Directory('${backgroundDirectory.path}/asr_retry');
      await retryDirectory.create(recursive: true);
      final audio = File('${retryDirectory.path}/$audioId.audio')
        ..writeAsBytesSync([1, 2, 3]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(catcatchStartupProvider.future);

      expect(await audio.exists(), isTrue);
      expect(
        container.read(backgroundTasksProvider.notifier).retryAudioCleanupSafe,
        isFalse,
      );
    },
  );

  test(
    'startup prunes unrelated retry audio when a corrupt row has a valid reference',
    () async {
      const retainedAudioId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const orphanAudioId = 'cccccccccccccccccccccccccccccccc';
      final backgroundDirectory = Directory(
        '${temporaryDirectory.path}/background',
      );
      await backgroundDirectory.create(recursive: true);
      await File('${backgroundDirectory.path}/tasks.json').writeAsString(
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
                'id': retainedAudioId,
                'name': 'retry.wav',
                'format': 'wav',
                'byteLength': 3,
                'sha256': 'd' * 64,
              },
            },
          },
        ]),
      );
      final retryDirectory = Directory('${backgroundDirectory.path}/asr_retry');
      await retryDirectory.create(recursive: true);
      final retained = File('${retryDirectory.path}/$retainedAudioId.audio')
        ..writeAsBytesSync([1, 2, 3]);
      final orphan = File('${retryDirectory.path}/$orphanAudioId.audio')
        ..writeAsBytesSync([4, 5, 6]);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(catcatchStartupProvider.future);

      expect(await retained.exists(), isTrue);
      expect(await orphan.exists(), isFalse);
      expect(
        container.read(backgroundTasksProvider.notifier).retryAudioCleanupSafe,
        isTrue,
      );
    },
  );

  test(
    'startup continues to restore task controls when retry audio pruning fails',
    () async {
      final backgroundDirectory = Directory(
        '${temporaryDirectory.path}/background',
      );
      await backgroundDirectory.create(recursive: true);
      await File('${backgroundDirectory.path}/tasks.json').writeAsString('[]');
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          asrRetryAudioStoreProvider.overrideWithValue(
            _FailingRetryAudioStore(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(catcatchStartupProvider.future),
        completes,
      );

      expect(
        container.read(taskFlowExecutionRestoreStatusProvider),
        FlowExecutionRestoreStatus.ready,
      );
    },
  );
}
