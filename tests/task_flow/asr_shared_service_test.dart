// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member, use_null_aware_elements

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/asr_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/services/asr_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/asr_executor.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';

class _AsrAdapter implements HttpClientAdapter {
  _AsrAdapter({
    required this.responseBody,
    this.responseBodies = const [],
    this.responseStatusCode = 200,
    this.responseContentType = Headers.jsonContentType,
    this.holdResponse = false,
  });

  final String responseBody;
  final List<String> responseBodies;
  final int responseStatusCode;
  final String responseContentType;
  final bool holdResponse;
  final requests = <({RequestOptions options, Uint8List body})>[];
  int closeCalls = 0;
  int _responseIndex = 0;
  final requestStarted = Completer<void>();
  final cancelObserved = Completer<void>();
  final releaseResponse = Completer<void>();
  Future<dynamic>? observedCancelFuture;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    requests.add((options: options, body: Uint8List.fromList(body)));
    observedCancelFuture = cancelFuture;
    if (!requestStarted.isCompleted) requestStarted.complete();
    if (holdResponse) {
      final cancelSignal = cancelFuture?.then<bool>(
        (_) {
          if (!cancelObserved.isCompleted) cancelObserved.complete();
          return true;
        },
        onError: (_) {
          if (!cancelObserved.isCompleted) cancelObserved.complete();
          return true;
        },
      );
      final cancelled = await Future.any<bool>([
        if (cancelSignal != null) cancelSignal,
        releaseResponse.future.then((_) => false),
      ]);
      if (cancelled) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
    }
    return ResponseBody.fromString(
      responseBodies.isEmpty ? responseBody : responseBodies[_responseIndex++],
      responseStatusCode,
      headers: {
        Headers.contentTypeHeader: [responseContentType],
      },
    );
  }

  @override
  void close({bool force = false}) => closeCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late TaskFlowExecutionNotifier executions;
  late BackgroundTaskNotifier background;
  late String execId;
  late FlowSubTask subTask;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('flow_asr_shared_');
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
      blockTypeKey: 'asr',
      blockLabel: 'ASR',
      subTaskId: 'pending_asr_0',
      subTaskType: 'background',
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
  });

  tearDown(() async {
    if (executions.mounted) executions.dispose();
    background.dispose();
  });

  ProviderEntriesState providers({
    Map<String, dynamic> providerTypeConfig = const {},
    Map<String, dynamic> modelTypeConfig = const {},
    List<CustomParam> customParams = const [],
    String host = 'https://api.test.com/audio/transcriptions',
  }) =>
      ProviderEntriesState(
        entries: [
          ProviderEntry(
            name: 'ASR',
            type: 'asr',
            configs: [
              ProviderConfigItem(
                id: 'provider',
                host: host,
                key: 'test-key',
                typeConfig: providerTypeConfig,
                models: [
                  ModelConfig(
                    id: 'model',
                    name: 'Test ASR',
                    modelId: 'model-from-config',
                    typeConfig: modelTypeConfig,
                    customParams: customParams,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  TaskFlowBlock asrBlock({Map<String, dynamic> extraParams = const {}}) =>
      TaskFlowBlock(
        typeKey: BlockType.asr,
        params: {
          'modelRef': {'configId': 'provider', 'modelId': 'model'},
          ...extraParams,
        },
      );

  Future<File> audioFile(String name, {int dataBytes = 2}) async {
    final file = File('${directory.path}/$name');
    return file.writeAsBytes(pcmToWav(Uint8List(dataBytes)));
  }

  Future<_AsrAdapter> executeWithOwnedService({
    required String audioFileName,
    int responseStatusCode = 200,
    bool holdResponse = false,
    bool cancelRequest = false,
  }) async {
    final adapter = _AsrAdapter(
      responseBody: '{"text":"recognized"}',
      responseStatusCode: responseStatusCode,
      holdResponse: holdResponse,
    );
    final file = await audioFile(audioFileName);
    final cancelToken = cancelRequest ? CancelToken() : null;
    final request = executeAsrBlock(
      block: asrBlock(),
      def: BlockTypeDefinition.asr,
      input: file.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      providerEntries: providers(),
      cancelToken: cancelToken,
      asrServiceFactory: (config) {
        final dynamic service = AsrService(config: config);
        service.dioForTesting.httpClientAdapter = adapter;
        return service as AsrService;
      },
    );

    if (cancelRequest) {
      final assertion = expectLater(
        request,
        throwsA(isA<BlockExecutionException>()),
      );
      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
      cancelToken!.cancel('test cancellation');
      await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      await assertion;
    } else if (responseStatusCode >= 400) {
      await expectLater(request, throwsA(isA<BlockExecutionException>()));
    } else {
      expect(await request, 'recognized');
    }
    return adapter;
  }

  test('maps provider and model ASR settings into one shared config', () {
    final model = ModelConfig(
      id: 'm-local',
      name: 'Whisper',
      modelId: 'whisper-custom',
      typeConfig: {
        'enableLanguage': true,
        'language': 'zh',
        'enableResponseFormat': true,
        'responseFormat': 'verbose_json',
      },
      customParams: [
        CustomParam(paramName: 'top_k', defaultValue: '5', type: 'number'),
      ],
    );

    final config = createAsrConfigFromProviderModel(
      host: 'https://api.test.com/transcribe',
      apiKey: 'secret',
      model: model,
      providerTypeConfig: {
        'uploadMethod': 'base64Json',
        'maxFileSizeMb': 12,
        'preprocessing': 'resampleMono',
        'compression': 'flac',
        'chunking': 'fixedSize',
        'fallbackMethod': 'all',
      },
    );

    expect(config.model, 'whisper-custom');
    expect(config.typeConfig, model.typeConfig);
    expect(config.customParams.single.paramName, 'top_k');
    expect(config.uploadMethod, AudioUploadMethod.base64Json);
    expect(config.maxFileSizeBytes, 12 * 1024 * 1024);
    expect(config.preprocessing, 'resampleMono');
    expect(config.compression, 'flac');
    expect(config.chunking, 'fixedSize');
    expect(config.fallbackMethod, 'all');
  });

  test(
    'task-flow sends typed base64 parameters through the shared service',
    () async {
      final adapter = _AsrAdapter(responseBody: '{"text":"recognized"}');
      final dio = Dio()..httpClientAdapter = adapter;
      final file = await audioFile('typed.wav');
      final state = providers(
        providerTypeConfig: {'uploadMethod': 'base64Json'},
        modelTypeConfig: {
          'enableLanguage': true,
          'language': 'zh',
          'enableResponseFormat': true,
          'responseFormat': 'verbose_json',
          'enableTemperature': true,
          'temperature': 0.25,
          'enableTimestampGranularities': true,
          'timestampGranularities': ['word', 'segment'],
          'enablePrompt': true,
          'prompt': 'domain vocabulary',
        },
        customParams: [
          CustomParam(paramName: 'top_k', defaultValue: '7', type: 'number'),
          CustomParam(paramName: 'vad', defaultValue: 'false', type: 'boolean'),
          CustomParam(
            paramName: 'metadata',
            defaultValue: '{"speaker":"A"}',
            type: 'json',
          ),
        ],
      );

      final result = await executeAsrBlock(
        block: asrBlock(),
        def: BlockTypeDefinition.asr,
        input: file.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: state,
        asrServiceFactory: (config) => AsrService(config: config, dio: dio),
      );

      expect(result, 'recognized');
      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.options.contentType,
        contains('application/json'),
      );
      final body = jsonDecode(utf8.decode(adapter.requests.single.body))
          as Map<String, dynamic>;
      expect(body['file'], base64Encode(await file.readAsBytes()));
      expect(body['model'], 'model-from-config');
      expect(body['response_format'], 'verbose_json');
      expect(body['language'], 'zh');
      expect(body['temperature'], 0.25);
      expect(body['timestamp_granularities'], ['word', 'segment']);
      expect(body['prompt'], 'domain vocabulary');
      expect(body['top_k'], 7);
      expect(body['vad'], false);
      expect(body['metadata'], {'speaker': 'A'});
    },
  );

  test('task-flow closes its owned Dio after successful recognition', () async {
    final adapter = await executeWithOwnedService(
      audioFileName: 'owned-success.wav',
    );

    expect(adapter.closeCalls, 1);
  });

  test(
    'partial chunk results fail the task and never save formal text',
    () async {
      final adapter = _AsrAdapter(
        responseBody: '',
        responseBodies: [
          '{"text":"first chunk"}',
          '{"error":{"message":"middle failed"}}',
          '{"text":"last chunk"}',
        ],
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final file = await audioFile('partial.wav', dataBytes: 140);

      await expectLater(
        executeAsrBlock(
          block: asrBlock(extraParams: {'saveFolder': 'transcripts'}),
          def: BlockTypeDefinition.asr,
          input: file.path,
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          bgNotifier: background,
          providerEntries: providers(
            providerTypeConfig: {
              'maxFileSizeMb': 0.0001,
              'chunking': 'fixedSize',
              'fallbackMethod': 'generic',
            },
          ),
          asrServiceFactory: (config) => AsrService(config: config, dio: dio),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      expect(adapter.requests, hasLength(3));
      expect(background.state.single.status, TaskStatus.failed);
      expect(background.state.single.result, 'first chunk last chunk');
      expect(background.state.single.resultIsComplete, isFalse);
      expect(background.state.single.error, contains('middle failed'));
      expect(background.state.single.error, contains('片段 2'));
      expect(background.state.single.error, contains('成功: first chunk'));
      expect(background.state.single.error, contains('成功: last chunk'));
      expect(
        executions.execution(execId)!.subTasks.single.status,
        TaskStatus.failed,
      );
      expect(await TextManifest.loadRecords(), isEmpty);
    },
  );

  testWidgets('standalone partial results are marked incomplete', (
    tester,
  ) async {
    final adapter = _AsrAdapter(
      responseBody: '',
      responseBodies: [
        '{"text":"first chunk"}',
        '{"error":{"message":"middle failed"}}',
        '{"text":"last chunk"}',
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(dio.close);
    final entries = providers(
      providerTypeConfig: {
        'maxFileSizeMb': 0.0001,
        'chunking': 'fixedSize',
        'fallbackMethod': 'generic',
      },
    );
    final providerNotifier = ProviderEntriesNotifier()..state = entries;
    final encodedAudio = base64Encode(pcmToWav(Uint8List(140)));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith((ref) => providerNotifier),
          backgroundTasksProvider.overrideWith((ref) => background),
          audioRecordsProvider.overrideWith((ref) => AudioRecordsNotifier()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AsrPage(
                      retryData: {
                        'audios': [
                          {
                            'bytes': encodedAudio,
                            'name': 'standalone-partial.wav',
                            'format': 'wav',
                          },
                        ],
                      },
                      asrServiceFactory: (config) =>
                          AsrService(config: config, dio: dio),
                      onNavigateBack: () {},
                    ),
                  ),
                ),
                child: const Text('open ASR'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open ASR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始识别'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (background.state.isEmpty ||
          background.state.single.status != TaskStatus.failed) {
        if (DateTime.now().isAfter(deadline)) {
          fail('standalone ASR task did not fail after the chunk error');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(background.state.single.result, 'first chunk last chunk');
    expect(background.state.single.status, TaskStatus.failed);
    expect(background.state.single.resultIsComplete, isFalse);
    expect(adapter.requests, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('task-flow closes its owned Dio after a request failure', () async {
    final adapter = await executeWithOwnedService(
      audioFileName: 'owned-failure.wav',
      responseStatusCode: 500,
    );

    expect(adapter.closeCalls, 1);
  });

  test('task-flow closes its owned Dio after cancellation', () async {
    final adapter = await executeWithOwnedService(
      audioFileName: 'owned-cancel.wav',
      holdResponse: true,
      cancelRequest: true,
    );

    expect(adapter.closeCalls, 1);
  });

  test('task-flow leaves an injected Dio open after recognition', () async {
    final adapter = _AsrAdapter(responseBody: '{"text":"recognized"}');
    final dio = Dio()..httpClientAdapter = adapter;
    final file = await audioFile('injected-dio.wav');

    final result = await executeAsrBlock(
      block: asrBlock(),
      def: BlockTypeDefinition.asr,
      input: file.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      providerEntries: providers(),
      asrServiceFactory: (config) => AsrService(config: config, dio: dio),
    );

    expect(result, 'recognized');
    expect(adapter.closeCalls, 0);
    dio.close();
  });

  test(
    'URL-only provider rejects a local input before reading or requesting',
    () async {
      final adapter = _AsrAdapter(responseBody: '{"text":"should not run"}');
      final dio = Dio()..httpClientAdapter = adapter;
      final missingFile = File('${directory.path}/not-created.wav');

      await expectLater(
        executeAsrBlock(
          block: asrBlock(),
          def: BlockTypeDefinition.asr,
          input: missingFile.path,
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          bgNotifier: background,
          providerEntries: providers(
            providerTypeConfig: {'uploadMethod': 'url'},
          ),
          asrServiceFactory: (config) => AsrService(config: config, dio: dio),
        ),
        throwsA(
          isA<BlockExecutionException>().having(
            (error) => error.message,
            'message',
            contains('URL 上传方式'),
          ),
        ),
      );

      expect(adapter.requests, isEmpty);
      expect(await TextManifest.loadRecords(), isEmpty);
    },
  );

  test(
    'cancel reaches a chunked HTTP request and prevents orphan saves',
    () async {
      final adapter = _AsrAdapter(
        responseBody: '{"text":"late response"}',
        holdResponse: true,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final file = await audioFile('cancel.wav', dataBytes: 400);
      final cancelToken = CancelToken();
      final pending = executeAsrBlock(
        block: asrBlock(),
        def: BlockTypeDefinition.asr,
        input: file.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providers(
          providerTypeConfig: {
            'maxFileSizeMb': 0.0001,
            'chunking': 'fixedSize',
            'fallbackMethod': 'generic',
          },
        ),
        cancelToken: cancelToken,
        asrServiceFactory: (config) => AsrService(config: config, dio: dio),
      );
      final assertion = expectLater(
        pending,
        throwsA(isA<BlockExecutionException>()),
      );

      await adapter.requestStarted.future.timeout(const Duration(seconds: 5));
      cancelToken.cancel('test cancellation');
      if (adapter.observedCancelFuture != null) {
        await adapter.cancelObserved.future.timeout(const Duration(seconds: 5));
      }
      adapter.releaseResponse.complete();
      await assertion;

      expect(adapter.observedCancelFuture, isNotNull);
      expect(adapter.requests, hasLength(1));
      expect(await TextManifest.loadRecords(), isEmpty);
      expect(background.state.single.status, isNot(TaskStatus.completed));
    },
  );

  test(
    'SRT response saves only the shared service plain transcript text',
    () async {
      const srt = '1\n00:00:00,000 --> 00:00:01,000\nHello world';
      final adapter = _AsrAdapter(
        responseBody: srt,
        responseContentType: 'text/plain; charset=utf-8',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final file = await audioFile('subtitle.wav');

      final result = await executeAsrBlock(
        block: asrBlock(extraParams: {'saveFolder': 'transcripts'}),
        def: BlockTypeDefinition.asr,
        input: file.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providers(
          modelTypeConfig: {
            'enableResponseFormat': true,
            'responseFormat': 'srt',
          },
        ),
        asrServiceFactory: (config) => AsrService(config: config, dio: dio),
      );

      expect(result, 'Hello world');
      final records = await TextManifest.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.name, '语音识别_subtitle');
      expect(records.single.folder, 'transcripts');
      expect(
        await TextManifest.readText(records.single.storageFileName),
        'Hello world',
      );
      expect(records.single.format, 'txt');
      expect(records.single.storageFileName, endsWith('.txt'));
    },
  );
}
