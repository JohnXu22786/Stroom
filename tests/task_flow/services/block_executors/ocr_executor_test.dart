// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/llm_account.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/llm_account_migration_service.dart';
import 'package:stroom/services/llm_chat_runtime.dart';
import 'package:stroom/services/llm_connector_http_client.dart';
import 'package:stroom/services/llm_connector_service.dart';
import 'package:stroom/services/llm_credential_store.dart';
import 'package:stroom/services/llm_model_group_provider.dart';
import 'package:stroom/services/llm_routing_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/ocr_executor.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

Uint8List _validPng() => img.encodePng(img.Image(width: 2, height: 2));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late TaskFlowExecutionNotifier executions;
  late BackgroundTaskNotifier background;
  late String execId;
  late FlowSubTask subTask;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('ocr_executor_test_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
  });

  tearDownAll(() async {
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    TextManifest.invalidateCache();
    executions = TaskFlowExecutionNotifier();
    background = BackgroundTaskNotifier();
    execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    subTask = FlowSubTask(
      blockTypeKey: 'ocr',
      blockLabel: 'OCR',
      subTaskId: 'pending_ocr_0',
      subTaskType: 'background',
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
  });

  tearDown(() {
    if (executions.mounted) executions.dispose();
    background.dispose();
  });

  ProviderEntriesState providerForOcr() => ProviderEntriesState(
    entries: [
      ProviderEntry(
        name: 'OCR',
        type: 'ocr',
        configs: [
          ProviderConfigItem(
            id: 'config',
            host: 'https://example.invalid/recognition',
            key: 'test-key',
            models: [ModelConfig(id: 'model', name: 'Test', modelId: 'test')],
          ),
        ],
      ),
    ],
  );

  TaskFlowBlock ocrBlock() => TaskFlowBlock(
    typeKey: BlockType.ocr,
    params: {
      'modelRef': {'configId': 'config', 'modelId': 'model'},
    },
  );

  test('OCR uses payload bytes instead of the filename suffix', () async {
    final bytes = _validPng();
    final source = await File(
      '${directory.path}/actually_png.jpg',
    ).writeAsBytes(bytes);
    String? requestFormat;

    final result = await executeOcrBlock(
      block: ocrBlock(),
      def: BlockTypeDefinition.ocr,
      input: source.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      providerEntries: providerForOcr(),
      requestOcr: (payload, format) async {
        expect(payload, bytes);
        requestFormat = format;
        return 'recognized text';
      },
    );

    expect(result, 'recognized text');
    expect(requestFormat, 'png');
  });

  test(
    'legacy Task Flow OCR models are registered and account routed',
    () async {
      final preferences = _MemoryPreferences();
      final accounts = LlmAccountConnectorService(
        preferences: preferences,
        credentialStore: _MemoryCredentialStore(),
      );
      final connector = _ExecutorFakeConnector(accounts);
      final runtime = LlmChatRoutingRuntime(
        accountService: accounts,
        routingService: LlmRoutingService(
          accountService: accounts,
          stateStore: LlmRoutingStateStore(preferences: preferences),
          concurrency: LlmConcurrencyReservations(),
        ),
        connectorClient: connector,
      );
      final source = await File(
        '${directory.path}/task-flow-ocr.png',
      ).writeAsBytes(_validPng());
      final providerEntries = ProviderEntriesState(
        entries: [
          ProviderEntry(
            name: 'Legacy OCR',
            type: 'ocr',
            configs: [
              ProviderConfigItem(
                id: 'legacy-task-flow-config',
                host: 'https://legacy.example.test/v1/chat/completions',
                key: 'legacy-key',
                providerName: 'Legacy OCR',
                models: [
                  ModelConfig(
                    id: 'legacy-model',
                    name: 'Legacy vision model',
                    modelId: 'legacy-upstream-model',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final block = TaskFlowBlock(
        typeKey: BlockType.ocr,
        params: {
          'modelRef': {
            'configId': 'legacy-task-flow-config',
            'modelId': 'legacy-model',
          },
        },
      );

      final result = await executeOcrBlock(
        block: block,
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerEntries,
        routingRuntime: Future.value(runtime),
      );

      final accountId = llmOcrAccountIdForConfig('legacy-task-flow-config');
      final groupId = stableLlmModelGroupId(accountId, 'legacy-model');
      expect(result, 'task flow recognized');
      expect(connector.requestedAccountId, accountId);
      expect(connector.requestedModelId, 'legacy-upstream-model');
      expect(connector.requestBody?['model'], 'legacy-upstream-model');
      expect(await accounts.readCredential(accountId), 'legacy-key');
      expect((await accounts.listModelGroups()).single.id, groupId);
    },
  );

  test('OCR rejects corrupt bytes before invoking its request', () async {
    final source = await File(
      '${directory.path}/corrupt.png',
    ).writeAsBytes([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
    var requested = false;

    await expectLater(
      executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        requestOcr: (_, format) async {
          requested = true;
          return format;
        },
      ),
      throwsA(
        isA<BlockExecutionException>().having(
          (error) => error.message,
          'message',
          contains('损坏'),
        ),
      ),
    );

    expect(requested, isFalse);
    expect(background.state.single.status, TaskStatus.failed);
    expect(background.state.single.error, contains('损坏'));
  });
}

class _ExecutorFakeConnector extends LlmConnectorHttpClient {
  _ExecutorFakeConnector(LlmAccountConnectorService accountService)
    : super(accountService: accountService);

  String? requestedAccountId;
  String? requestedModelId;
  Map<String, dynamic>? requestBody;

  @override
  Future<LlmConnectorResponse> request({
    required LlmAccount account,
    required String modelId,
    required Object? body,
    bool stream = false,
    String? nativeFormat,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Future<void> Function()? onRequestSent,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) async {
    requestedAccountId = account.id;
    requestedModelId = modelId;
    requestBody = Map<String, dynamic>.from(body! as Map);
    await onRequestSent?.call();
    return LlmConnectorResponse(
      statusCode: 200,
      body: const {
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': 'task flow recognized'},
          },
        ],
      },
      observation: LlmConnectorObservation(),
    );
  }
}

class _MemoryPreferences implements LlmAccountPreferences {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

class _MemoryCredentialStore implements LlmCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String value) async {
    values[reference] = value;
  }
}
