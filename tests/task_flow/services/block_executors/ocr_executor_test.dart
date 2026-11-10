// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/ocr_executor.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/http_timeout.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

Uint8List _validPng() => img.encodePng(img.Image(width: 2, height: 2));

class _EchoingErrorAdapter implements HttpClientAdapter {
  _EchoingErrorAdapter(this.apiKey);

  final String apiKey;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await for (final _ in requestStream) {}
    }
    return ResponseBody.fromString(
      '{"error":{"message":"Rejected key=$apiKey"}}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CapturingSuccessAdapter implements HttpClientAdapter {
  RequestOptions? capturedOptions;
  List<int> capturedBodyBytes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    capturedOptions = options;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        capturedBodyBytes.addAll(chunk);
      }
    }
    return ResponseBody.fromString(
      '{"choices":[{"message":{"content":"recognized"},"finish_reason":"stop"}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _IncompleteOcrAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await for (final _ in requestStream) {}
    }
    return ResponseBody.fromString(
      '{"choices":[{"message":{"content":"partial OCR text"},"finish_reason":"length"}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

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
    WebFileStore.enableTestMode();
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

  tearDown(() async {
    await background.pendingPersistence;
    if (executions.mounted) executions.dispose();
    background.dispose();
    WebFileStore.disableTestMode();
  });

  ProviderEntriesState providerForOcr({
    String key = 'test-key',
    int? requestSizeBudgetBytes,
    Map<String, dynamic> modelTypeConfig = const {},
    List<CustomParam> customParams = const [],
  }) =>
      ProviderEntriesState(entries: [
        ProviderEntry(name: 'OCR', type: 'ocr', configs: [
          ProviderConfigItem(
            id: 'config',
            host: 'https://example.invalid/recognition',
            key: key,
            models: [
              ModelConfig(
                id: 'model',
                name: 'Test',
                modelId: 'test',
                typeConfig: {
                  ...modelTypeConfig,
                  if (requestSizeBudgetBytes != null)
                    'requestSizeBudgetBytes': requestSizeBudgetBytes,
                },
                customParams: customParams,
              ),
            ],
          ),
        ]),
      ]);

  TaskFlowBlock ocrBlock({String modelId = 'model'}) => TaskFlowBlock(
        typeKey: BlockType.ocr,
        params: {
          'modelRef': {'configId': 'config', 'modelId': modelId},
        },
      );

  Future<void> expectPreflightFailure({
    required String expectedError,
    required Future<String> Function() execute,
  }) async {
    await expectLater(
      execute(),
      throwsA(isA<BlockExecutionException>().having(
        (error) => error.message,
        'message',
        expectedError,
      )),
    );

    final failedTask = background.state.last;
    expect(failedTask.status, TaskStatus.failed);
    expect(failedTask.error, expectedError);
    expect(
      executions.execution(execId)?.subTasks.single.status,
      TaskStatus.failed,
    );
  }

  Future<void> expectIncompleteOcrLocalization({
    required AppLocalizations localizations,
    required String expectedError,
  }) async {
    expect(
      localizations.bgTaskOcrResultIncomplete('length'),
      expectedError,
      reason: 'The injected localization should provide the expected locale',
    );
    final source =
        await File('${directory.path}/partial.png').writeAsBytes(_validPng());
    final dio = Dio()..httpClientAdapter = _IncompleteOcrAdapter();

    try {
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
          localizations: localizations,
          ocrDio: dio,
        ),
        throwsA(isA<BlockExecutionException>().having(
          (error) => error.message,
          'message',
          expectedError,
        )),
      );
    } finally {
      dio.close(force: true);
    }

    final failedTask = background.state.single;
    expect(failedTask.status, TaskStatus.failed);
    expect(failedTask.result, 'partial OCR text');
    expect(failedTask.resultIsComplete, isFalse);
    expect(failedTask.error, expectedError);
    expect(
      executions.execution(execId)?.subTasks.single.status,
      TaskStatus.failed,
    );

    await background.pendingPersistence;
    final restored =
        BackgroundTaskNotifier(localizationsResolver: () => localizations);
    addTearDown(restored.dispose);
    expect(await restored.restoreFromPersistence(), isTrue);
    final restoredTask = restored.taskById(failedTask.id)!;
    expect(restoredTask.result, 'partial OCR text');
    expect(restoredTask.resultIsComplete, isFalse);
    expect(restoredTask.error, expectedError);
  }

  Future<void> expectLocalizedFailureSummaries({
    required AppLocalizations localizations,
  }) async {
    final source =
        await File('${directory.path}/localized_failure.png').writeAsBytes(
      _validPng(),
    );
    BlockExecutionException? estimatorFailure;
    try {
      await executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(
          modelTypeConfig: {'userInstruction': 42},
        ),
        localizations: localizations,
      );
    } on BlockExecutionException catch (error) {
      estimatorFailure = error;
    }
    expect(estimatorFailure, isNotNull);
    final estimatorDetail = estimatorFailure!.message;
    expect(estimatorDetail, isNotEmpty);
    expect(
      background.state.last.error,
      '${localizations.unifiedTaskOcrFailed}: $estimatorDetail',
    );
    expect(background.state.last.status, TaskStatus.failed);
    expect(
      executions.execution(execId)?.subTasks.single.status,
      TaskStatus.failed,
    );
    await background.pendingPersistence;

    BlockExecutionException? requestFailure;
    try {
      await executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: localizations,
        requestOcr: (_, _) async => throw StateError('synthetic OCR failure'),
      );
    } on BlockExecutionException catch (error) {
      requestFailure = error;
    }
    expect(requestFailure, isNotNull);
    final requestDetail = requestFailure!.message;
    expect(requestDetail, isNotEmpty);
    expect(
      background.state.last.error,
      '${localizations.unifiedTaskOcrFailed}: $requestDetail',
    );
    expect(background.state.last.status, TaskStatus.failed);
    expect(
      executions.execution(execId)?.subTasks.single.status,
      TaskStatus.failed,
    );
    await background.pendingPersistence;
  }

  test('OCR uses payload bytes instead of the filename suffix', () async {
    final bytes = _validPng();
    final source =
        await File('${directory.path}/actually_png.jpg').writeAsBytes(bytes);
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

  test('OCR reads image bytes from a WebFileStore key', () async {
    const key = 'attachments/taskflow_image.png';
    final bytes = _validPng();
    await WebFileStore.write(key, bytes);
    Uint8List? requestedBytes;
    String? requestFormat;

    final result = await executeOcrBlock(
      block: ocrBlock(),
      def: BlockTypeDefinition.ocr,
      input: key,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      providerEntries: providerForOcr(),
      requestOcr: (payload, format) async {
        requestedBytes = payload;
        requestFormat = format;
        return 'recognized web image';
      },
    );

    expect(result, 'recognized web image');
    expect(requestedBytes, bytes);
    expect(requestFormat, 'png');
  });

  test(
      'TaskFlow OCR send timeout includes instruction and custom parameter text',
      () async {
    final source = await File('${directory.path}/large_request.png')
        .writeAsBytes(_validPng());
    final instruction = List.filled(600000, 'i').join();
    final customValue = List.filled(600000, 'c').join();
    final adapter = _CapturingSuccessAdapter();
    final dio = Dio()..httpClientAdapter = adapter;

    try {
      final result = await executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(
          modelTypeConfig: {'userInstruction': instruction},
          customParams: [
            CustomParam(
              paramName: 'custom_prompt',
              defaultValue: customValue,
            ),
          ],
        ),
        ocrDio: dio,
      );

      expect(result, 'recognized');
      expect(adapter.capturedOptions, isNotNull);
      expect(adapter.capturedBodyBytes.length, greaterThan(1024 * 1024));
      expect(
        adapter.capturedOptions!.sendTimeout,
        sendTimeoutForBytes(adapter.capturedBodyBytes.length),
      );
      expect(adapter.capturedOptions!.sendTimeout, const Duration(seconds: 62));
    } finally {
      dio.close(force: true);
    }
  });

  test('incomplete OCR failure is localized in English', () async {
    await expectIncompleteOcrLocalization(
      localizations: AppLocalizationsEn(),
      expectedError: 'OCR returned an incomplete result (finish_reason=length)',
    );
  });

  test('incomplete OCR failure is localized in Chinese', () async {
    await expectIncompleteOcrLocalization(
      localizations: AppLocalizationsZhCn(),
      expectedError: 'OCR 返回了不完整结果（finish_reason=length）',
    );
  });

  test('OCR failure summaries are localized in English', () async {
    await expectLocalizedFailureSummaries(localizations: AppLocalizationsEn());
  });

  test('OCR failure summaries are localized in Chinese', () async {
    await expectLocalizedFailureSummaries(
        localizations: AppLocalizationsZhCn());
  });

  test('OCR rejects oversized WebFileStore input before request dispatch',
      () async {
    const key = 'attachments/oversized_taskflow_image.png';
    await WebFileStore.write(key, Uint8List(800 * 1024));
    var requested = false;

    await expectLater(
      executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: key,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(requestSizeBudgetBytes: 1024 * 1024),
        requestOcr: (_, _) async {
          requested = true;
          return 'unexpected request';
        },
      ),
      throwsA(isA<BlockExecutionException>().having(
        (error) => error.message,
        'message',
        contains('OCR request size budget (1.00 MiB)'),
      )),
    );

    expect(requested, isFalse);
    expect(background.state.single.status, TaskStatus.failed);
  });

  test(
    'cancellation during OCR input read prevents request dispatch',
    () async {
      final source = await File('${directory.path}/cancelled.png')
          .writeAsBytes(_validPng());
      final readStarted = Completer<void>();
      final releaseRead = Completer<void>();
      var requested = false;

      final execution = executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        readInputBytes: (_, _) async {
          readStarted.complete();
          await releaseRead.future;
          return _validPng();
        },
        requestOcr: (_, _) async {
          requested = true;
          return 'must not be sent';
        },
      );

      await readStarted.future;
      executions.cancelExecution(execId);
      releaseRead.complete();

      await expectLater(
        execution,
        throwsA(isA<BlockExecutionException>().having(
          (error) => error.message,
          'message',
          '任务流已结束或删除',
        )),
      );

      expect(requested, isFalse);
      expect(background.state, isEmpty);
      expect(
        executions.execution(execId)?.status,
        FlowExecutionStatus.cancelled,
      );
      expect(
        executions.execution(execId)?.subTasks.single.outcome,
        FlowStepOutcome.cancelled,
      );
    },
  );

  test('OCR rejects corrupt bytes before invoking its request', () async {
    final source = await File('${directory.path}/corrupt.png').writeAsBytes(
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00],
    );
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
        localizations: AppLocalizationsZh(),
        requestOcr: (_, format) async {
          requested = true;
          return format;
        },
      ),
      throwsA(isA<BlockExecutionException>().having(
        (error) => error.message,
        'message',
        contains('损坏'),
      )),
    );

    expect(requested, isFalse);
    expect(background.state.single.status, TaskStatus.failed);
    expect(background.state.single.error, contains('损坏'));
  });

  test('OCR localizes unsupported image payload errors in English', () async {
    final source = await File('${directory.path}/unsupported.tiff')
        .writeAsBytes([0x49, 0x49, 0x2a, 0x00, 0x08, 0x00]);
    final localizations = AppLocalizationsEn();
    final expectedError = localizations.ocrImageUnsupportedSpecialFormat;

    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: localizations,
      ),
    );
  });

  test('OCR localizes corrupt image payload errors in Simplified Chinese',
      () async {
    final source = await File('${directory.path}/corrupt.png').writeAsBytes(
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00],
    );
    final localizations = AppLocalizationsZh();
    final expectedError = localizations.ocrImageDecodeFailed;

    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: localizations,
      ),
    );
  });

  test('OCR rejects files above the flow image limit before reading', () async {
    final source = File('${directory.path}/oversized.png');
    final handle = await source.open(mode: FileMode.write);
    await handle.setPosition(20 * 1024 * 1024);
    await handle.writeByte(0);
    await handle.close();
    var requested = false;
    var readAttempted = false;

    await expectLater(
      executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries:
            providerForOcr(requestSizeBudgetBytes: 40 * 1024 * 1024),
        readInputBytes: (_, _) async {
          readAttempted = true;
          throw StateError('oversized file should not be read');
        },
        requestOcr: (_, _) async {
          requested = true;
          return 'recognized text';
        },
      ),
      throwsA(isA<BlockExecutionException>().having(
        (error) => error.message,
        'message',
        contains('20.00 MiB'),
      )),
    );

    expect(requested, isFalse);
    expect(readAttempted, isFalse);
    expect(background.state.single.status, TaskStatus.failed);
    expect(
      background.state.single.error,
      contains('the task flow image input limit (20.00 MiB)'),
    );
    expect(
      executions.execution(execId)?.subTasks.single.status,
      TaskStatus.failed,
    );
  });

  test('OCR applies the selected model request budget before reading',
      () async {
    final source = File('${directory.path}/over_budget.png');
    final handle = await source.open(mode: FileMode.write);
    await handle.setPosition(800 * 1024);
    await handle.writeByte(0);
    await handle.close();
    var requested = false;
    var readAttempted = false;

    await expectLater(
      executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(requestSizeBudgetBytes: 1024 * 1024),
        readInputBytes: (_, _) async {
          readAttempted = true;
          throw StateError('over-budget file should not be read');
        },
        requestOcr: (_, _) async {
          requested = true;
          return 'recognized text';
        },
      ),
      throwsA(isA<BlockExecutionException>().having(
        (error) => error.message,
        'message',
        contains('OCR request size budget (1.00 MiB)'),
      )),
    );

    expect(requested, isFalse);
    expect(readAttempted, isFalse);
    expect(background.state.single.status, TaskStatus.failed);
    expect(
      background.state.single.error,
      contains('OCR request size budget (1.00 MiB)'),
    );
  });

  test('OCR rejects input that grows past the bounded read ceiling', () async {
    final source =
        await File('${directory.path}/growing.png').writeAsBytes([0]);
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
        providerEntries: providerForOcr(requestSizeBudgetBytes: 1024),
        readInputBytes: (_, maxBytes) async => Uint8List(maxBytes + 1),
        requestOcr: (_, _) async {
          requested = true;
          return 'recognized text';
        },
      ),
      throwsA(isA<BlockExecutionException>().having(
        (error) => error.message,
        'message',
        contains('OCR request size budget'),
      )),
    );

    expect(requested, isFalse);
    expect(background.state.single.status, TaskStatus.failed);
    expect(
      background.state.single.error,
      contains('OCR request size budget (0.00097656 MiB)'),
    );
  });

  test('OCR provider key echoes are removed from all failure surfaces',
      () async {
    const apiKey = 'configured-taskflow-ocr-secret-42';
    final source = await File('${directory.path}/credential_echo.png')
        .writeAsBytes(_validPng());
    final dio = Dio()..httpClientAdapter = _EchoingErrorAdapter(apiKey);

    BlockExecutionException? thrown;
    try {
      await executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(key: apiKey),
        ocrDio: dio,
      );
    } on BlockExecutionException catch (error) {
      thrown = error;
    } finally {
      dio.close(force: true);
    }

    expect(thrown, isNotNull);
    final task = background.state.single;
    expect(task.status, TaskStatus.failed);
    expect(task.error, isNot(contains(apiKey)));
    expect(task.error, contains('HTTP 401'));
    expect(task.steps.first.status, BgStepStatus.failed);
    expect(task.steps.first.error, isNot(contains(apiKey)));
    expect(task.steps.first.error, contains('HTTP 401'));
    expect(thrown!.toString(), isNot(contains(apiKey)));
    expect(thrown.toString(), contains('HTTP 401'));
  });

  test('missing OCR input failure is localized in English', () async {
    const expectedError =
        'The image file could not be found. Select the image again.';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: '${directory.path}/missing.png',
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: AppLocalizationsEn(),
      ),
    );
  });

  test('missing OCR input failure is localized in Chinese', () async {
    const expectedError = '找不到图片文件，请重新选择图片。';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: '${directory.path}/missing.png',
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: AppLocalizationsZhCn(),
      ),
    );
  });

  test('unreadable OCR input failure is localized in English', () async {
    final source = await File('${directory.path}/unreadable.png')
        .writeAsBytes(_validPng());
    const expectedError =
        'The image file could not be read. Check file access and try again.';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: AppLocalizationsEn(),
        readInputBytes: (_, _) => throw StateError('read failed'),
      ),
    );
  });

  test('unreadable OCR input failure is localized in Chinese', () async {
    final source = await File('${directory.path}/unreadable.png')
        .writeAsBytes(_validPng());
    const expectedError = '无法读取图片文件，请检查文件访问权限后重试。';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: AppLocalizationsZhCn(),
        readInputBytes: (_, _) => throw StateError('read failed'),
      ),
    );
  });

  test('unavailable OCR model failure is localized in English', () async {
    final source = await File('${directory.path}/unused_model_en.png')
        .writeAsBytes(_validPng());
    const expectedError =
        'No usable OCR model is configured. Choose an OCR provider and model in flow settings.';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(modelId: 'unavailable'),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: AppLocalizationsEn(),
      ),
    );
  });

  test('unavailable OCR model failure is localized in Chinese', () async {
    final source = await File('${directory.path}/unused_model_zh.png')
        .writeAsBytes(_validPng());
    const expectedError = '未配置可用的 OCR 模型，请在流程设置中选择 OCR 服务和模型。';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(modelId: 'unavailable'),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(),
        localizations: AppLocalizationsZhCn(),
      ),
    );
  });

  test('oversized OCR input failure is localized in English', () async {
    const key = 'attachments/oversized_taskflow_image_en.png';
    await WebFileStore.write(key, Uint8List(800 * 1024));
    const expectedError =
        'The image exceeds OCR request size budget (1.00 MiB). Choose a smaller image and try again.';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: key,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(requestSizeBudgetBytes: 1024 * 1024),
        localizations: AppLocalizationsEn(),
      ),
    );
  });

  test('oversized OCR input failure is localized in Chinese', () async {
    const key = 'attachments/oversized_taskflow_image_zh.png';
    await WebFileStore.write(key, Uint8List(800 * 1024));
    const expectedError = '图片超过OCR 请求大小预算（1.00 MiB），请缩小图片后重试。';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: key,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providerForOcr(requestSizeBudgetBytes: 1024 * 1024),
        localizations: AppLocalizationsZhCn(),
      ),
    );
  });

  test('task flow image limit error is localized in English', () async {
    final source = File('${directory.path}/flow_limit_en.png');
    final handle = await source.open(mode: FileMode.write);
    await handle.setPosition(20 * 1024 * 1024);
    await handle.writeByte(0);
    await handle.close();
    const expectedError =
        'The image exceeds the task flow image input limit (20.00 MiB). Choose a smaller image and try again.';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries:
            providerForOcr(requestSizeBudgetBytes: 40 * 1024 * 1024),
        localizations: AppLocalizationsEn(),
      ),
    );
  });

  test('task flow image limit error is localized in Chinese', () async {
    final source = File('${directory.path}/flow_limit_zh.png');
    final handle = await source.open(mode: FileMode.write);
    await handle.setPosition(20 * 1024 * 1024);
    await handle.writeByte(0);
    await handle.close();
    const expectedError = '图片超过任务流图片输入上限（20.00 MiB），请缩小图片后重试。';
    await expectPreflightFailure(
      expectedError: expectedError,
      execute: () => executeOcrBlock(
        block: ocrBlock(),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries:
            providerForOcr(requestSizeBudgetBytes: 40 * 1024 * 1024),
        localizations: AppLocalizationsZhCn(),
      ),
    );
  });
}
