// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/tts_executor.dart';
import 'package:stroom/task_flow/services/flow_temporary_artifact_storage.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/web_file_store.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);

  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

class _Executions extends TaskFlowExecutionNotifier {
  void Function(String executionId)? afterPersistedId;

  @override
  Future<bool> persist() async => true;

  @override
  Future<bool> updateSubTaskIdPersisted(
    String executionId,
    String subTaskId,
    String newSubTaskId,
  ) async {
    final persisted = await super.updateSubTaskIdPersisted(
      executionId,
      subTaskId,
      newSubTaskId,
    );
    afterPersistedId?.call(executionId);
    return persisted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late PathProviderPlatform previousDocuments;
  late ProviderContainer container;
  late TaskListNotifier tasks;
  late _Executions executions;
  late String executionId;
  late FlowSubTask flowSubTask;
  late ProviderConfigItem config;
  late ProviderEntriesState providers;
  final audio = pcmToWav(Uint8List.fromList([0, 0, 1, 0]));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    documents = await Directory.systemTemp.createTemp('flow_tts_temp_');
    previousDocuments = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(documents.path);
    AppStorage.resetCache();
    WebFileStore.enableTestMode();

    config = ProviderConfigItem(
      id: 'tts-config',
      providerName: 'Test TTS',
      host: 'https://example.invalid/tts',
      key: 'test-key',
      models: [
        ModelConfig(id: 'tts-model', name: 'Test', modelId: 'test-tts'),
      ],
    );
    providers = ProviderEntriesState(entries: [
      ProviderEntry(name: 'Test TTS', type: 'tts', configs: [config]),
    ]);
    container = ProviderContainer();
    tasks = container.read(taskListProvider.notifier);
    tasks.debugSynthesize = (_, _, _) async => audio;

    executions = _Executions();
    flowSubTask = FlowSubTask(
      blockTypeKey: BlockType.tts.name,
      blockLabel: BlockTypeDefinition.tts.label,
      subTaskId: 'pending-tts',
      subTaskType: 'synthesis',
      status: TaskStatus.waiting,
    );
    executionId = executions.addExecution(
      flowId: 'flow',
      flowName: 'Flow',
      subTasks: [flowSubTask],
    );
  });

  tearDown(() async {
    container.dispose();
    executions.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WebFileStore.disableTestMode();
    PathProviderPlatform.instance = previousDocuments;
    AppStorage.resetCache();
    await documents.delete(recursive: true);
  });

  test('temporary synthesis routes output to execution storage, not saveFolder',
      () async {
    final block = TaskFlowBlock(
      id: 'tts-block',
      typeKey: BlockType.tts,
      params: {
        'modelRef': {
          'configId': config.id,
          'modelId': config.models.single.id,
        },
        'saveFolder': 'configured-folder',
      },
    );

    final output = await executeTtsBlock(
      block: block,
      def: BlockTypeDefinition.tts,
      input: 'Hello temporary output',
      execId: executionId,
      execNotifier: executions,
      flowSubTask: flowSubTask,
      taskListNotifier: tasks,
      providerEntries: providers,
      temporaryOutput: true,
    );

    expect(output, startsWith('task_flow_temporary/'));
    final task = container.read(taskListProvider).single;
    expect(task.downloadedFilePath, output);
    expect(
      task.customParams?[flowTemporaryExecutionIdKey],
      executionId,
    );
    expect(task.customParams?[flowTemporaryBlockIdKey], block.id);
    expect(task.customParams?.containsKey('saveFolder'), isFalse);
    expect(await WebFileStore.read(output), audio);
  });

  for (final action in ['pause', 'cancel']) {
    test('$action after temporary ID persistence prevents synthesis start',
        () async {
      final controlApplied = Completer<void>();
      executions.afterPersistedId = (id) {
        if (action == 'pause') {
          executions.setExecutionStatus(id, FlowExecutionStatus.paused);
        } else {
          executions.cancelExecution(id);
        }
        controlApplied.complete();
      };

      await expectLater(
        executeTtsBlock(
          block: TaskFlowBlock(
            id: 'tts-block',
            typeKey: BlockType.tts,
            params: {
              'modelRef': {
                'configId': config.id,
                'modelId': config.models.single.id,
              },
            },
          ),
          def: BlockTypeDefinition.tts,
          input: 'This child must not start',
          execId: executionId,
          execNotifier: executions,
          flowSubTask: flowSubTask,
          taskListNotifier: tasks,
          providerEntries: providers,
          temporaryOutput: true,
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(controlApplied.isCompleted, isTrue);
      expect(container.read(taskListProvider), isEmpty);
    });
  }
}
