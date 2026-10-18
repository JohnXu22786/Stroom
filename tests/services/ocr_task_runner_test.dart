import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/ocr_batch_execution.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/ocr_result_saver.dart';
import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/services/ocr_task_runner.dart';
import 'package:stroom/utils/text_manifest.dart';

const _config = OcrConfig(
  host: 'https://ocr.test/chat',
  apiKey: 'opaque-test-api-secret-83',
);

class _ControlledAdapter implements HttpClientAdapter {
  final requested = Completer<RequestOptions>();
  final response = Completer<ResponseBody>();
  bool closed = false;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    requested.complete(options);
    // Deliberately permit a late response; the token must fence saving.
    return response.future;
  }

  void succeed({String finishReason = 'stop'}) =>
      response.complete(ResponseBody.fromString(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'owned text'},
              'finish_reason': finishReason
            }
          ]
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          'x-request-id': ['req-ocr-123'],
        },
      ));

  @override
  void close({bool force = false}) => closed = true;
}

class _OutOfOrderAdapter implements HttpClientAdapter {
  final List<int> requestedImageIds = [];
  final Map<int, RequestOptions> requestOptionsByImageId = {};
  final Map<int, Completer<ResponseBody>> _responses = {};
  final firstRequest = Completer<void>();
  final twoRequests = Completer<void>();
  final threeRequests = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final body = options.data as Map;
    final content = (body['messages'] as List)[1]['content'] as List;
    final dataUri = content.first['image_url']['url'] as String;
    final imageId = base64Decode(
      dataUri.substring(dataUri.indexOf(',') + 1),
    ).first;
    requestedImageIds.add(imageId);
    requestOptionsByImageId[imageId] = options;
    if (requestedImageIds.length == 1 && !firstRequest.isCompleted) {
      firstRequest.complete();
    }
    if (requestedImageIds.length == 2 && !twoRequests.isCompleted) {
      twoRequests.complete();
    }
    if (requestedImageIds.length == 3 && !threeRequests.isCompleted) {
      threeRequests.complete();
    }
    return _responses.putIfAbsent(imageId, Completer<ResponseBody>.new).future;
  }

  void complete(
    int imageId, {
    required String text,
    int statusCode = 200,
    String finishReason = 'stop',
  }) {
    final data = statusCode >= 400
        ? {
            'error': {'message': text},
          }
        : {
            'choices': [
              {
                'message': {'content': text},
                'finish_reason': finishReason,
              },
            ],
          };
    _responses[imageId]!.complete(
      ResponseBody.fromString(
        jsonEncode(data),
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BackgroundTaskNotifier notifier;
  late _ControlledAdapter adapter;
  late OcrTaskRunner runner;
  late String id;
  late Uint8List input;
  late Map<String, dynamic> typeConfig;
  int saves = 0;
  Completer<void>? writeGate;
  bool failNextFileWrite = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    directory = await Directory.systemTemp.createTemp('ocr_owned_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = directory.path;
    notifier = BackgroundTaskNotifier();
    id = notifier.addTask(type: BackgroundTaskType.ocr, title: 'owned');
    adapter = _ControlledAdapter();
    saves = 0;
    writeGate = null;
    failNextFileWrite = false;
    input = Uint8List.fromList([1, 2, 3]);
    typeConfig = {'userInstruction': 'original'};
    runner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config.copyWith(typeConfig: typeConfig),
      images: [(input, 'png')],
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = adapter,
      ),
      writeText: (name, text, {beforeCommit}) async {
        saves++;
        await writeGate?.future;
        if (failNextFileWrite) {
          failNextFileWrite = false;
          throw const FileSystemException('injected text write failure');
        }
        beforeCommit?.call();
        return TextManifest.writeText(name, text, beforeCommit: beforeCommit);
      },
      onSaved: () {},
    );
  });

  tearDown(() async {
    ManifestDatabase.beforeWebDataSaveForTesting = null;
    if (notifier.mounted) notifier.dispose();
    await notifier.pendingPersistence;
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    await directory.delete(recursive: true);
  });

  test('owned runner snapshots input and duplicate run submits only once',
      () async {
    input[0] = 99;
    typeConfig['userInstruction'] = 'changed';
    final first = runner.run();
    final second = runner.run();
    final request = await adapter.requested.future;
    final body = request.data as Map;
    final content = (body['messages'] as List)[1]['content'] as List;
    expect(content[0]['image_url']['url'], 'data:image/png;base64,AQID');
    expect(content[1]['text'], 'original');
    adapter.succeed();
    await Future.wait([first, second]);
    expect(adapter.calls, 1);
    expect(saves, 1);
    expect(notifier.state.single.status, TaskStatus.completed);
    final completedTask = notifier.state.single;
    expect(completedTask.rawRequest?['host'], 'ocr.test');
    expect(completedTask.rawRequest?['imageCount'], 1);
    expect(completedTask.rawRequest?['imageBytes'], 3);
    expect(completedTask.rawRequest?['durationMs'], isA<int>());
    expect(completedTask.rawRequest?.containsKey('body'), isFalse);
    expect(completedTask.rawResponse?['statusCode'], 200);
    expect(completedTask.rawResponse?['finishReason'], 'stop');
    expect(completedTask.rawResponse?['requestId'], 'req-ocr-123');
    expect(completedTask.rawResponse?['durationMs'], isA<int>());
    await notifier.pendingPersistence;
    final persistedFile = File(
      '${directory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
    );
    final persistedTask =
        (jsonDecode(await persistedFile.readAsString()) as List)
            .cast<Map<String, dynamic>>()
            .single;
    final persistedDiagnostics = jsonEncode(persistedTask);
    expect(persistedDiagnostics, contains('req-ocr-123'));
    expect(persistedDiagnostics, isNot(contains('opaque-test-api-secret-83')));
    expect(persistedDiagnostics, isNot(contains('data:image')));
    expect(persistedDiagnostics, isNot(contains('choices')));
    expect((await TextManifest.loadRecords()).single.folder, 'captured folder');
    expect(adapter.closed, isTrue);
  });

  test(
    'joint mode remains the default and sends every image in one request',
    () async {
      final jointRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [
          (Uint8List.fromList([1]), 'png'),
          (Uint8List.fromList([2]), 'png'),
        ],
        title: 'owned',
        folder: 'captured folder',
        serviceFactory: (config) =>
            OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );

      final running = jointRunner.run();
      final request = await adapter.requested.future;
      final content =
          ((request.data as Map)['messages'] as List)[1]['content'] as List;
      expect(content, hasLength(2));
      adapter.succeed();
      await running;
      expect(adapter.calls, 1);
    },
  );

  test(
    'per-image outcomes retain page order when requests finish out of order',
    () async {
      final outOfOrderAdapter = _OutOfOrderAdapter();
      final pageRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [
          (Uint8List.fromList([1]), 'png'),
          (Uint8List.fromList([2]), 'png'),
          (Uint8List.fromList([3]), 'png'),
        ],
        imageNames: ['first.png', 'second.png', 'third.png'],
        executionMode: OcrBatchMode.perImage,
        perImageConcurrency: 2,
        title: 'owned',
        folder: 'captured folder',
        serviceFactory: (config) => OcrService(
          config: config,
          dio: Dio()..httpClientAdapter = outOfOrderAdapter,
        ),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );

      final running = pageRunner.run();
      await outOfOrderAdapter.twoRequests.future.timeout(
        const Duration(seconds: 2),
      );
      outOfOrderAdapter.complete(2, text: 'failed page', statusCode: 500);
      await outOfOrderAdapter.threeRequests.future.timeout(
        const Duration(seconds: 2),
      );
      outOfOrderAdapter.complete(3, text: 'third page text');
      outOfOrderAdapter.complete(1, text: 'first page text');
      await running;

      final task = notifier.state.single;
      expect(outOfOrderAdapter.requestedImageIds, [1, 2, 3]);
      expect(task.status, TaskStatus.failed);
      expect(task.resultIsComplete, isFalse);
      expect(task.result, contains('--- 第 1 张图片：first.png ---'));
      expect(task.result, contains('--- 第 3 张图片：third.png ---'));
      expect(
        task.result!.indexOf('first page text'),
        lessThan(task.result!.indexOf('third page text')),
      );
      expect(task.ocrPageOutcomes.map((outcome) => outcome.status), [
        OcrPageOutcomeStatus.succeeded,
        OcrPageOutcomeStatus.failed,
        OcrPageOutcomeStatus.succeeded,
      ]);
      expect(task.error, contains('第 2 张'));

      await notifier.pendingPersistence;
      final persistedFile = File(
        '${directory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
      );
      final persistedTask =
          (jsonDecode(await persistedFile.readAsString()) as List)
              .cast<Map<String, dynamic>>()
              .single;
      final restoredTask = BackgroundTask.fromMap(persistedTask);
      expect(
        restoredTask.ocrPageOutcomes.map((outcome) => outcome.imageIndex),
        [0, 1, 2],
      );
      expect(restoredTask.ocrPageOutcomes.map((outcome) => outcome.status), [
        OcrPageOutcomeStatus.succeeded,
        OcrPageOutcomeStatus.failed,
        OcrPageOutcomeStatus.succeeded,
      ]);
    },
  );

  test('failed empty per-image batch stays incomplete', () async {
    final emptyFailedAdapter = _OutOfOrderAdapter();
    final emptyFailedRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [
        (Uint8List.fromList([1]), 'png'),
        (Uint8List.fromList([2]), 'png'),
      ],
      executionMode: OcrBatchMode.perImage,
      perImageConcurrency: 2,
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = emptyFailedAdapter,
      ),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = emptyFailedRunner.run();
    await emptyFailedAdapter.twoRequests.future.timeout(
      const Duration(seconds: 2),
    );
    emptyFailedAdapter.complete(1, text: '', statusCode: 500);
    emptyFailedAdapter.complete(2, text: '', statusCode: 500);
    await running;

    final task = notifier.state.single;
    expect(task.status, TaskStatus.failed);
    expect(task.result, '');
    expect(task.resultIsComplete, isFalse);
    expect(task.error, contains('结果不完整'));
    expect(task.steps[3].status, BgStepStatus.failed);
    expect(task.ocrPageOutcomes.map((outcome) => outcome.status), [
      OcrPageOutcomeStatus.failed,
      OcrPageOutcomeStatus.failed,
    ]);
  });

  test('queued per-image requests prevent aggregate stages from completing',
      () async {
    final stagedAdapter = _OutOfOrderAdapter();
    final parsingWithQueuedPage = Completer<List<BgTaskStep>>();
    notifier.addListener((tasks) {
      final task = tasks.single;
      if (!parsingWithQueuedPage.isCompleted &&
          task.ocrPageOutcomes.length == 2 &&
          task.ocrPageOutcomes[0].status == OcrPageOutcomeStatus.running &&
          task.ocrPageOutcomes[1].status == OcrPageOutcomeStatus.pending &&
          task.steps[3].status == BgStepStatus.running) {
        parsingWithQueuedPage.complete(List.unmodifiable(task.steps));
      }
    }, fireImmediately: false);
    final stagedRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [
        (Uint8List.fromList([1]), 'png'),
        (Uint8List.fromList([2]), 'png'),
      ],
      executionMode: OcrBatchMode.perImage,
      perImageConcurrency: 1,
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = stagedAdapter,
      ),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = stagedRunner.run();
    await stagedAdapter.firstRequest.future.timeout(
      const Duration(seconds: 2),
    );
    stagedAdapter.complete(1, text: 'first page');
    final stepsWhileSecondPageIsQueued =
        await parsingWithQueuedPage.future.timeout(const Duration(seconds: 2));
    await stagedAdapter.twoRequests.future.timeout(
      const Duration(seconds: 2),
    );
    stagedAdapter.complete(2, text: 'second page');
    await running;

    expect(stepsWhileSecondPageIsQueued[1].status, BgStepStatus.pending);
    expect(notifier.state.single.status, TaskStatus.completed);
    expect(
      notifier.state.single.steps.map((step) => step.status),
      everyElement(BgStepStatus.completed),
    );
  });

  test('concurrent per-image requests keep upload progress visible', () async {
    final progressAdapter = _OutOfOrderAdapter();
    final progressRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [
        (Uint8List.fromList([1]), 'png'),
        (Uint8List.fromList([2]), 'png'),
      ],
      executionMode: OcrBatchMode.perImage,
      perImageConcurrency: 2,
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = progressAdapter,
      ),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = progressRunner.run();
    await progressAdapter.twoRequests.future.timeout(
      const Duration(seconds: 2),
    );

    progressAdapter.requestOptionsByImageId[1]!.onSendProgress!(10, 10);
    expect(notifier.state.single.steps[2].running, isTrue);

    progressAdapter.requestOptionsByImageId[2]!.onSendProgress!(5, 10);
    final uploadStep = notifier.state.single.steps[1];
    expect(uploadStep.running, isTrue);
    expect(uploadStep.label, contains('第 2/2 张图片'));

    progressAdapter.complete(1, text: 'first page text');
    progressAdapter.complete(2, text: 'second page text');
    await running;
    expect(notifier.state.single.status, TaskStatus.completed);
  });

  test(
    'pre-upload per-image failure does not complete later aggregate stages',
    () async {
      final failedBeforeUploadAdapter = _OutOfOrderAdapter();
      final failedBeforeUploadRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [
          (Uint8List.fromList([1]), 'png'),
          (Uint8List.fromList([2]), 'png'),
        ],
        executionMode: OcrBatchMode.perImage,
        perImageConcurrency: 1,
        title: 'owned',
        folder: 'captured folder',
        serviceFactory: (config) => OcrService(
          config: config,
          dio: Dio()..httpClientAdapter = failedBeforeUploadAdapter,
        ),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );

      final running = failedBeforeUploadRunner.run();
      await failedBeforeUploadAdapter.firstRequest.future.timeout(
        const Duration(seconds: 2),
      );
      // The adapter leaves this failed request's upload-progress callback
      // untouched, so the page never advances past its initial stage.
      failedBeforeUploadAdapter.complete(
        1,
        text: 'pre-upload failure',
        statusCode: 500,
      );
      await failedBeforeUploadAdapter.twoRequests.future.timeout(
        const Duration(seconds: 2),
      );
      failedBeforeUploadAdapter.requestOptionsByImageId[2]!.onSendProgress!(
          10, 10);
      failedBeforeUploadAdapter.complete(2, text: 'succeeded page');
      await running;

      final task = notifier.state.single;
      expect(task.ocrPageOutcomes[0].status, OcrPageOutcomeStatus.failed);
      expect(task.ocrPageOutcomes[1].status, OcrPageOutcomeStatus.succeeded);
      expect(task.steps[1].status, isNot(BgStepStatus.completed));
      expect(task.steps[2].status, isNot(BgStepStatus.completed));
    },
  );

  test('out-of-order page success preserves failure diagnostics', () async {
    final diagnosticsAdapter = _OutOfOrderAdapter();
    final failedPagePublished = Completer<void>();
    notifier.addListener((tasks) {
      if (!failedPagePublished.isCompleted &&
          tasks.single.ocrPageOutcomes.any(
            (outcome) => outcome.status == OcrPageOutcomeStatus.failed,
          )) {
        failedPagePublished.complete();
      }
    }, fireImmediately: false);
    final diagnosticRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [
        (Uint8List.fromList([1]), 'png'),
        (Uint8List.fromList([2]), 'png'),
      ],
      executionMode: OcrBatchMode.perImage,
      perImageConcurrency: 2,
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = diagnosticsAdapter,
      ),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = diagnosticRunner.run();
    await diagnosticsAdapter.twoRequests.future.timeout(
      const Duration(seconds: 2),
    );
    diagnosticsAdapter.complete(
      2,
      text: 'failed page response',
      statusCode: 500,
    );
    await failedPagePublished.future.timeout(const Duration(seconds: 2));
    diagnosticsAdapter.complete(1, text: 'successful page response');
    await running;

    final task = notifier.state.single;
    expect(task.status, TaskStatus.failed);
    expect(task.rawResponse?['statusCode'], 500);
  });

  test('request failure diagnostics take precedence over incomplete pages',
      () async {
    final diagnosticsAdapter = _OutOfOrderAdapter();
    final incompletePagePublished = Completer<void>();
    notifier.addListener((tasks) {
      if (!incompletePagePublished.isCompleted &&
          tasks.single.ocrPageOutcomes.any(
            (outcome) => outcome.status == OcrPageOutcomeStatus.incomplete,
          )) {
        incompletePagePublished.complete();
      }
    }, fireImmediately: false);
    final diagnosticRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [
        (Uint8List.fromList([1]), 'png'),
        (Uint8List.fromList([2]), 'png'),
      ],
      executionMode: OcrBatchMode.perImage,
      perImageConcurrency: 2,
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = diagnosticsAdapter,
      ),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = diagnosticRunner.run();
    await diagnosticsAdapter.twoRequests.future.timeout(
      const Duration(seconds: 2),
    );
    diagnosticsAdapter.complete(
      1,
      text: 'incomplete page response',
      finishReason: 'length',
    );
    await incompletePagePublished.future.timeout(const Duration(seconds: 2));
    diagnosticsAdapter.complete(
      2,
      text: 'failed page response',
      statusCode: 500,
    );
    await running;

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.rawResponse?['statusCode'], 500);
  });

  test('retry reuses completed pages and requests only failed pages', () async {
    final retryRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [
        (Uint8List.fromList([1]), 'png'),
        (Uint8List.fromList([2]), 'png'),
      ],
      imageNames: ['first.png', 'second.png'],
      executionMode: OcrBatchMode.perImage,
      initialPageOutcomes: [
        const OcrPageOutcome(
          imageIndex: 0,
          status: OcrPageOutcomeStatus.succeeded,
          text: 'retained first page',
        ),
        const OcrPageOutcome(
          imageIndex: 1,
          status: OcrPageOutcomeStatus.failed,
          error: 'temporary failure',
        ),
      ],
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = retryRunner.run();
    final request = await adapter.requested.future;
    final content =
        ((request.data as Map)['messages'] as List)[1]['content'] as List;
    expect(content.single['image_url']['url'], 'data:image/png;base64,Ag==');
    adapter.succeed();
    await running;

    expect(adapter.calls, 1);
    expect(notifier.state.single.status, TaskStatus.completed);
    expect(notifier.state.single.result, contains('retained first page'));
    expect(notifier.state.single.result, contains('owned text'));
  });

  test(
    'canceling per-image work prevents queued requests from starting',
    () async {
      final queuedRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [
          (Uint8List.fromList([1]), 'png'),
          (Uint8List.fromList([2]), 'png'),
          (Uint8List.fromList([3]), 'png'),
        ],
        executionMode: OcrBatchMode.perImage,
        title: 'owned',
        folder: 'captured folder',
        serviceFactory: (config) =>
            OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );

      final running = queuedRunner.run();
      final request = await adapter.requested.future;
      notifier.cancelTask(id);
      expect(request.cancelToken!.isCancelled, isTrue);
      adapter.succeed();
      await running;

      expect(adapter.calls, 1);
      expect(saves, 0);
      expect(
        notifier.state.single.ocrPageOutcomes.every(
          (outcome) =>
              outcome.status != OcrPageOutcomeStatus.pending &&
              outcome.status != OcrPageOutcomeStatus.running,
        ),
        isTrue,
      );
    },
  );

  test(
    'a late cancelled runner cannot publish into a same-ID replacement',
    () async {
      final staleRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [(input, 'png')],
        executionMode: OcrBatchMode.perImage,
        title: 'owned',
        folder: 'captured folder',
        serviceFactory: (config) =>
            OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );

      final staleRun = staleRunner.run();
      final request = await adapter.requested.future;
      notifier.removeTask(id);
      notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'replacement',
        taskId: id,
      );
      const replacementOutcome = OcrPageOutcome(
        imageIndex: 0,
        status: OcrPageOutcomeStatus.succeeded,
        text: 'replacement page',
      );
      notifier.setOcrPageOutcomes(id, [replacementOutcome]);

      adapter.succeed();
      await staleRun;

      expect(request.cancelToken!.isCancelled, isTrue);
      expect(notifier.state.single.title, 'replacement');
      expect(
        notifier.state.single.ocrPageOutcomes.single.status,
        replacementOutcome.status,
      );
      expect(
        notifier.state.single.ocrPageOutcomes.single.text,
        replacementOutcome.text,
      );
    },
  );

  test(
    'a late cancelled runner cannot unregister same-ID replacement cancellation',
    () async {
      final staleRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [(input, 'png')],
        executionMode: OcrBatchMode.perImage,
        title: 'owned',
        folder: 'captured folder',
        serviceFactory: (config) =>
            OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );

      final staleRun = staleRunner.run();
      await adapter.requested.future;
      notifier.removeTask(id);
      notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'replacement',
        taskId: id,
      );

      final replacementAdapter = _ControlledAdapter();
      final replacementRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [(input, 'png')],
        executionMode: OcrBatchMode.perImage,
        title: 'replacement',
        folder: 'captured folder',
        serviceFactory: (config) => OcrService(
          config: config,
          dio: Dio()..httpClientAdapter = replacementAdapter,
        ),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );
      final replacementRun = replacementRunner.run();
      final replacementRequest = await replacementAdapter.requested.future;

      adapter.succeed();
      await staleRun;
      notifier.cancelTask(id);

      expect(replacementRequest.cancelToken!.isCancelled, isTrue);
      replacementAdapter.succeed();
      await replacementRun;
    },
  );

  test(
    'a same-ID replacement during result notification rejects late state',
    () async {
      var replaced = false;
      notifier.addListener((tasks) {
        if (!replaced && tasks.single.result == 'owned text') {
          replaced = true;
          notifier.removeTask(id);
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'replacement',
            taskId: id,
          );
        }
      }, fireImmediately: false);

      final running = runner.run();
      await adapter.requested.future;
      adapter.succeed();
      await running;

      expect(replaced, isTrue);
      expect(notifier.state.single.title, 'replacement');
      expect(notifier.state.single.result, isNull);
      expect(notifier.state.single.rawRequest, isNull);
      expect(notifier.state.single.rawResponse, isNull);
      expect(
        notifier.state.single.steps.every(
          (step) => step.status == BgStepStatus.pending,
        ),
        isTrue,
      );
    },
  );

  test(
    'a same-ID replacement during save completion stays running',
    () async {
      var replaced = false;
      notifier.addListener((tasks) {
        if (!replaced &&
            tasks.single.steps[4].status == BgStepStatus.completed) {
          replaced = true;
          notifier.removeTask(id);
          notifier.addTask(
            type: BackgroundTaskType.ocr,
            title: 'replacement',
            taskId: id,
          );
        }
      }, fireImmediately: false);

      final running = runner.run();
      await adapter.requested.future;
      adapter.succeed();
      await running;

      expect(replaced, isTrue);
      expect(notifier.state.single.title, 'replacement');
      expect(notifier.state.single.status, TaskStatus.running);
      expect(notifier.state.single.result, isNull);
      expect(notifier.state.single.downloadedFilePath, isNull);
      expect(await TextManifest.loadRecords(), isEmpty);
    },
  );

  test('persisted diagnostics exclude a key matching HTTP status', () async {
    const apiKey = '200';
    final credentialRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config.copyWith(apiKey: apiKey),
      images: [(input, 'png')],
      title: 'owned',
      folder: 'captured folder',
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = adapter,
      ),
      writeText: TextManifest.writeText,
      onSaved: () {},
    );

    final running = credentialRunner.run();
    await adapter.requested.future;
    adapter.succeed();
    await running;
    await notifier.pendingPersistence;

    final diagnostics = notifier.state.single.rawResponse!;
    expect(diagnostics['statusCode'], isNull);
    expect(diagnostics['finishReason'], 'stop');
    expect(jsonEncode(diagnostics), isNot(contains(apiKey)));
    final persistedFile = File(
      '${directory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
    );
    final persistedTask =
        (jsonDecode(await persistedFile.readAsString()) as List)
            .cast<Map<String, dynamic>>()
            .single;
    final persistedDiagnostics = jsonEncode(persistedTask['rawResponse']);
    expect(persistedDiagnostics, isNot(contains(apiKey)));
  });

  for (final apiKey in ['Exception', 'OCR']) {
    test(
      'configured API key $apiKey is absent from task snapshots',
      () async {
        final emittedSnapshots = <String>[];
        notifier.addListener((tasks) {
          if (tasks.isNotEmpty) {
            emittedSnapshots.add(jsonEncode(tasks.single.toMap()));
          }
        }, fireImmediately: false);
        final failingRunner = OcrTaskRunner(
          taskId: id,
          notifier: notifier,
          config: _config.copyWith(apiKey: apiKey),
          images: [(input, 'png')],
          title: 'owned',
          folder: 'captured folder',
          serviceFactory: (config) => OcrService(
            config: config,
            dio: Dio()..httpClientAdapter = adapter,
          ),
          writeText: TextManifest.writeText,
          onSaved: () {},
        );

        final running = failingRunner.run();
        final request = await adapter.requested.future;
        adapter.response.completeError(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: request,
              statusCode: 401,
              data: {'error': 'unauthorized'},
            ),
          ),
        );
        await running;
        await notifier.pendingPersistence;

        expect(emittedSnapshots, isNotEmpty);
        expect(
          emittedSnapshots.every((snapshot) => !snapshot.contains(apiKey)),
          isTrue,
          reason: 'every state transition is queued for task persistence',
        );
        final task = notifier.state.single;
        expect(task.error, isNot(contains(apiKey)));
        expect(
          task.steps.map((step) => step.error ?? '').join(' '),
          isNot(contains(apiKey)),
        );
        final taskFile = File(
          '${directory.path}${Platform.pathSeparator}background${Platform.pathSeparator}tasks.json',
        );
        expect(await taskFile.exists(), isTrue);
        expect(await taskFile.readAsString(), isNot(contains(apiKey)));
      },
    );
  }

  test('text file write failure keeps the result and does not report success',
      () async {
    failNextFileWrite = true;
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    await running;

    final task = notifier.state.single;
    expect(task.status, TaskStatus.failed);
    expect(task.result, 'owned text');
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(task.downloadedFilePath, isNull);
    expect(adapter.calls, 1);
  });

  test('empty reused result remains retryable after a save failure', () async {
    failNextFileWrite = true;
    final emptyRetryRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      executionMode: OcrBatchMode.perImage,
      initialPageOutcomes: const [
        OcrPageOutcome(
          imageIndex: 0,
          status: OcrPageOutcomeStatus.succeeded,
          text: '',
        ),
      ],
      title: 'owned',
      folder: 'captured folder',
      onSaved: () {},
      writeText: (name, text, {beforeCommit}) async {
        saves++;
        if (failNextFileWrite) {
          failNextFileWrite = false;
          throw const FileSystemException('injected text write failure');
        }
        beforeCommit?.call();
        return TextManifest.writeText(name, text, beforeCommit: beforeCommit);
      },
    );

    await emptyRetryRunner.run();

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.result, '');
    expect(notifier.state.single.error, startsWith('OCR结果保存失败:'));
    expect(await TextManifest.loadRecords(), isEmpty);

    final saver = OcrResultSaver(
      taskId: id,
      notifier: notifier,
      title: 'owned',
      folder: 'captured folder',
      onSaved: () {},
    );
    await saver.retryTaskResult();

    expect(adapter.calls, 0);
    expect(notifier.state.single.status, TaskStatus.completed);
    expect(notifier.state.single.result, '');
    expect((await TextManifest.loadRecords()).single.size, 0);
  });

  test('a returned file path without published text cannot complete the task',
      () async {
    final noPublishRunner = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: 'captured folder',
      onSaved: () {},
      serviceFactory: (config) => OcrService(
        config: config,
        dio: Dio()..httpClientAdapter = adapter,
      ),
      writeText: (name, text, {beforeCommit}) async {
        beforeCommit?.call();
        return '/texts/$name';
      },
    );
    final running = noPublishRunner.run();
    await adapter.requested.future;
    adapter.succeed();
    await running;

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.result, 'owned text');
    expect(notifier.state.single.downloadedFilePath, isNull);
    expect(await TextManifest.loadRecords(), isEmpty);
  });

  test('manifest failure can be retried without another OCR request', () async {
    var failManifestWrite = true;
    ManifestDatabase.beforeWebDataSaveForTesting = () async {
      if (failManifestWrite) {
        failManifestWrite = false;
        throw StateError('injected manifest write failure');
      }
    };

    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    await running;

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.result, 'owned text');
    expect(await TextManifest.loadRecords(), isEmpty);
    final fileName =
        '${computeTextHash(Uint8List.fromList(utf8.encode('owned text')))}.txt';
    expect(await TextManifest.readText(fileName), isNull);

    final task = notifier.state.single;
    final saver = OcrResultSaver(
      taskId: id,
      notifier: notifier,
      title: task.title,
      folder: task.resultFolder,
      onSaved: () {},
    );
    await saver.retryTaskResult();

    expect(adapter.calls, 1);
    expect(notifier.state.single.status, TaskStatus.completed);
    expect((await TextManifest.loadRecords()).single.name, 'owned');
    expect(await TextManifest.readText(fileName), 'owned text');
  });

  test('truncated OCR result requires explicit partial save and is marked',
      () async {
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed(finishReason: 'length');
    await running;

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.result, 'owned text');
    expect(notifier.state.single.resultIsComplete, isFalse);
    expect(notifier.state.single.partialSaveRequested, isFalse);
    expect(notifier.state.single.steps[3].completed, isTrue);
    expect(notifier.state.single.steps[4].skipped, isTrue);
    expect(await TextManifest.loadRecords(), isEmpty);

    final diagnostics = notifier.state.single;
    expect(diagnostics.rawRequest?['host'], 'ocr.test');
    expect(diagnostics.rawRequest?['imageCount'], 1);
    expect(diagnostics.rawRequest?['imageBytes'], 3);
    expect(diagnostics.rawRequest?['durationMs'], isA<int>());
    expect(diagnostics.rawRequest?.containsKey('body'), isFalse);
    expect(diagnostics.rawResponse?['statusCode'], 200);
    expect(diagnostics.rawResponse?['finishReason'], 'length');
    expect(diagnostics.rawResponse?['requestId'], 'req-ocr-123');
    expect(diagnostics.rawResponse?['durationMs'], isA<int>());

    final task = notifier.state.single;
    var failFirstPartialWrite = true;
    final saver = OcrResultSaver(
      taskId: id,
      notifier: notifier,
      title: task.title,
      folder: task.resultFolder,
      onSaved: () {},
      writeText: (name, text, {beforeCommit}) async {
        if (failFirstPartialWrite) {
          failFirstPartialWrite = false;
          throw const FileSystemException('injected partial write failure');
        }
        return TextManifest.writeText(name, text, beforeCommit: beforeCommit);
      },
    );
    await expectLater(saver.retryTaskResult(), throwsStateError);
    await expectLater(
      saver.retryTaskResult(allowPartial: true),
      throwsA(isA<FileSystemException>()),
    );
    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.partialSaveRequested, isTrue);
    await saver.retryTaskResult();

    expect(adapter.calls, 1);
    expect(notifier.state.single.status, TaskStatus.completed);
    expect(notifier.state.single.partialSaveRequested, isTrue);
    expect(notifier.state.single.resultSavedAsPartial, isTrue);
    final record = (await TextManifest.loadRecords()).single;
    expect(record.name, 'owned（部分结果）');
    expect(await TextManifest.readText(record.storageFileName), 'owned text');
  });

  test('cancelling save-only retry preserves an existing shared text file',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    await TextManifest.writeText('$hash.txt', 'owned text');
    await TextManifest.addRecord(TextRecord(
      name: 'existing',
      hash: hash,
      createdAt: DateTime.now(),
      size: 10,
    ));
    notifier.setResult(id, 'owned text');
    notifier.failTask(id, error: 'previous save failed');

    final published = Completer<void>();
    final release = Completer<void>();
    final saver = OcrResultSaver(
      taskId: id,
      notifier: notifier,
      title: 'owned',
      folder: '',
      onSaved: () {},
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final retry = saver.retryTaskResult();
    await published.future;
    notifier.cancelTask(id);
    release.complete();
    await expectLater(retry, throwsA(anything));

    expect(notifier.state.single.status, TaskStatus.failed);
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect((await TextManifest.loadRecords()).map((record) => record.name),
        ['existing']);
  });

  test(
    'a cancelled save-only retry cannot unregister same-ID replacement cancellation',
    () async {
      notifier.setResult(id, 'owned text');
      notifier.failTask(id, error: 'previous save failed');

      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      final saver = OcrResultSaver(
        taskId: id,
        notifier: notifier,
        title: 'owned',
        folder: '',
        onSaved: () {},
        writeText: (name, text, {beforeCommit}) async {
          writeStarted.complete();
          await releaseWrite.future;
          beforeCommit?.call();
          return TextManifest.writeText(name, text, beforeCommit: beforeCommit);
        },
      );
      final retry = saver.retryTaskResult();
      await writeStarted.future;

      notifier.removeTask(id);
      notifier.addTask(
        type: BackgroundTaskType.ocr,
        title: 'replacement',
        taskId: id,
      );

      final replacementAdapter = _ControlledAdapter();
      final replacementRunner = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [(input, 'png')],
        title: 'replacement',
        folder: 'captured folder',
        serviceFactory: (config) => OcrService(
          config: config,
          dio: Dio()..httpClientAdapter = replacementAdapter,
        ),
        writeText: TextManifest.writeText,
        onSaved: () {},
      );
      final replacementRun = replacementRunner.run();
      final replacementRequest = await replacementAdapter.requested.future;

      releaseWrite.complete();
      await expectLater(retry, throwsA(anything));
      notifier.cancelTask(id);
      final replacementWasCancelled =
          replacementRequest.cancelToken!.isCancelled;
      replacementAdapter.succeed();
      await replacementRun;

      expect(replacementWasCancelled, isTrue);
      expect(notifier.state.single.title, 'replacement');
      expect(notifier.state.single.status, TaskStatus.failed);
      expect(notifier.state.single.error, '已取消');
      expect(notifier.state.single.result, isNull);
    },
  );

  test('cancelling after manifest insertion rolls back its new record and file',
      () async {
    notifier.setResult(id, 'owned text');
    notifier.failTask(id, error: 'previous save failed');
    final saver = OcrResultSaver(
      taskId: id,
      notifier: notifier,
      title: 'owned',
      folder: '',
      onSaved: () {},
      addRecord: (record, {beforeCommit}) async {
        await TextManifest.addRecord(record, beforeCommit: beforeCommit);
        notifier.cancelTask(id);
      },
    );

    await expectLater(saver.retryTaskResult(), throwsA(anything));

    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    expect(notifier.state.single.status, TaskStatus.failed);
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(await TextManifest.readText('$hash.txt'), isNull);
  });

  test('rollback removes its known row when the first reference read fails',
      () async {
    notifier.setResult(id, 'owned text');
    notifier.failTask(id, error: 'previous save failed');
    var failReferenceRead = true;
    final saver = OcrResultSaver(
      taskId: id,
      notifier: notifier,
      title: 'owned',
      folder: '',
      onSaved: () {},
      loadRecordsUncached: () async {
        if (failReferenceRead) {
          failReferenceRead = false;
          throw StateError('injected reference read failure');
        }
        return TextManifest.loadRecordsUncached();
      },
      addRecord: (record, {beforeCommit}) async {
        await TextManifest.addRecord(record, beforeCommit: beforeCommit);
        notifier.cancelTask(id);
      },
    );

    await expectLater(saver.retryTaskResult(), throwsA(anything));

    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    expect(notifier.state.single.status, TaskStatus.failed);
    expect(await TextManifest.loadRecordsUncached(), isEmpty);
    expect(await TextManifest.readText('$hash.txt'), isNull);
  });

  test('delete aborts request and a late response cannot save', () async {
    final running = runner.run();
    final request = await adapter.requested.future;
    notifier.removeTask(id);
    expect(request.cancelToken!.isCancelled, isTrue);
    adapter.succeed();
    await running;
    expect(saves, 0);
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(adapter.closed, isTrue);
  });

  for (final (stage, sent, total) in [
    ('upload', 1, 10),
    ('server wait', 10, 10),
  ]) {
    test('delete during $stage prevents a late response from saving', () async {
      final running = runner.run();
      final request = await adapter.requested.future;
      request.onSendProgress!(sent, total);
      notifier.removeTask(id);

      expect(request.cancelToken!.isCancelled, isTrue);
      expect(notifier.state, isEmpty);
      adapter.succeed();
      await running;

      expect(saves, 0);
      expect(await TextManifest.loadRecords(), isEmpty);
      expect(adapter.closed, isTrue);
    });
  }

  test('persisted deletion cancels before awaiting storage', () async {
    final running = runner.run();
    final request = await adapter.requested.future;
    final removal = notifier.removeTasksPersisted([id]);
    expect(request.cancelToken!.isCancelled, isTrue);
    adapter.succeed();
    await running;
    expect(await removal, isTrue);
    expect(saves, 0);
  });

  test('batch uses one cancellable request with body-sized upload timeout',
      () async {
    final service =
        OcrService(config: _config, dio: Dio()..httpClientAdapter = adapter);
    final token = CancelToken();
    final stages = <OcrRequestStage>[];
    final running = service.recognizeBatch(
      imageBytesList: [(Uint8List(2 * 1024 * 1024), 'png'), (input, 'png')],
      cancelToken: token,
      onStage: stages.add,
    );
    final assertion = expectLater(running, throwsA(isA<Exception>()));
    final request = await adapter.requested.future;
    expect(request.sendTimeout, const Duration(minutes: 1, seconds: 4));
    expect(request.connectTimeout, const Duration(seconds: 30));
    expect(request.receiveTimeout, const Duration(minutes: 60));
    request.onSendProgress!(10, 10);
    expect(stages, [OcrRequestStage.uploading, OcrRequestStage.waiting]);
    token.cancel();
    adapter.succeed();
    await assertion;
    service.close();
    expect(adapter.calls, 1);
    expect(stages, isNot(contains(OcrRequestStage.parsing)));
  });

  test('notifier disposal cancels owned request and closes client', () async {
    final running = runner.run();
    final request = await adapter.requested.future;
    notifier.dispose();
    expect(request.cancelToken!.isCancelled, isTrue);
    adapter.succeed();
    await running;
    expect(saves, 0);
    expect(adapter.closed, isTrue);
  });

  test('cancel during file write prevents record commit', () async {
    writeGate = Completer<void>();
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    while (saves == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    notifier.cancelTask(id);
    writeGate!.complete();
    await running;
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(notifier.state.single.status, TaskStatus.failed);
    expect(notifier.state.single.error, '已取消');
    expect(adapter.closed, isTrue);
  });

  test('removing a task during file write prevents record commit', () async {
    writeGate = Completer<void>();
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    while (saves == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    notifier.removeTask(id);
    writeGate!.complete();
    await running;

    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    expect(notifier.state, isEmpty);
    expect(await TextManifest.loadRecords(), isEmpty);
    expect(await TextManifest.readText('$hash.txt'), isNull);
    expect(adapter.closed, isTrue);
  });

  for (final shared in [false, true]) {
    test(
        'cancel after file publication cleans new data and preserves shared=$shared',
        () async {
      final hash =
          computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
      final name = '$hash.txt';
      if (shared) {
        await TextManifest.writeText(name, 'owned text');
        await TextManifest.addRecord(TextRecord(
            name: 'existing', hash: hash, createdAt: DateTime.now(), size: 10));
      }
      final published = Completer<void>();
      final release = Completer<void>();
      final owned = OcrTaskRunner(
        taskId: id,
        notifier: notifier,
        config: _config,
        images: [(input, 'png')],
        title: 'owned',
        folder: '',
        onSaved: () {},
        serviceFactory: (config) =>
            OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
        writeText: (name, text, {beforeCommit}) async {
          final path = await TextManifest.writeText(name, text,
              beforeCommit: beforeCommit);
          published.complete();
          await release.future;
          return path;
        },
      );
      final running = owned.run();
      await adapter.requested.future;
      adapter.succeed();
      await published.future;
      notifier.cancelTask(id);
      release.complete();
      await running;
      expect(await TextManifest.readText(name), shared ? 'owned text' : isNull);
      expect((await TextManifest.loadRecords()).length, shared ? 1 : 0);
    });
  }

  test('cancelling queued OCR preserves an earlier in-flight same-hash writer',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    final published = Completer<void>();
    final release = Completer<void>();
    final earlier = TextManifest.withSaveLock(hash, () async {
      await TextManifest.writeText('$hash.txt', 'owned text');
      published.complete();
      await release.future;
      await TextManifest.addRecord(TextRecord(
          name: 'earlier', hash: hash, createdAt: DateTime.now(), size: 10));
    });
    await published.future;
    final running = runner.run();
    await adapter.requested.future;
    adapter.succeed();
    while (!notifier.state.single.steps[4].running) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(saves, 0);
    notifier.cancelTask(id);
    release.complete();
    await Future.wait([earlier, running]);
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect((await TextManifest.loadRecords()).single.name, 'earlier');
  });

  test('competing same-hash writer waits through cancelled OCR rollback',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    final published = Completer<void>();
    final release = Completer<void>();
    final owned = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final running = owned.run();
    await adapter.requested.future;
    adapter.succeed();
    await published.future;
    var competingPublished = false;
    final competing = () async {
      await TextManifest.writeText('$hash.txt', 'owned text');
      competingPublished = true;
      await TextManifest.addRecord(TextRecord(
          name: 'competing', hash: hash, createdAt: DateTime.now(), size: 10));
    }();
    await Future<void>.delayed(Duration.zero);
    expect(competingPublished, isFalse);
    notifier.cancelTask(id);
    release.complete();
    await Future.wait([running, competing]);
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect((await TextManifest.loadRecords()).single.name, 'competing');
  });

  for (final batch in [false, true]) {
    test(
        'same-hash ${batch ? 'batch ' : 'single '}deletion waits for save before removing shared text',
        () async {
      final hash =
          computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
      await TextManifest.writeText('$hash.txt', 'owned text');
      final existing = TextRecord(
        name: 'existing',
        hash: hash,
        createdAt: DateTime.now(),
        size: 10,
      );
      await TextManifest.addRecord(existing);

      final recordStarted = Completer<void>();
      final continueRecord = Completer<void>();
      var deletionFinished = false;
      final saver = OcrResultSaver(
        taskId: id,
        notifier: notifier,
        title: 'new result',
        folder: '',
        onSaved: () {},
        addRecord: (record, {beforeCommit}) async {
          recordStarted.complete();
          await continueRecord.future;
          await TextManifest.addRecord(record, beforeCommit: beforeCommit);
        },
      );

      final saving = saver.saveResult('owned text', isComplete: true);
      await recordStarted.future;
      final deletion = batch
          ? TextManifest.deleteRecords([existing.id])
          : TextManifest.deleteRecord(existing.id);
      final deleting = deletion.then((_) {
        deletionFinished = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(deletionFinished, isFalse,
          reason: 'same-hash deletion must wait for the result record commit');

      continueRecord.complete();
      final savedPath = await saving;
      await deleting;

      expect(notifier.state.single.status, TaskStatus.completed);
      expect(await TextManifest.readText('$hash.txt'), 'owned text');
      expect(savedPath, isNotEmpty);
      final records = await TextManifest.loadRecordsUncached();
      expect(records.map((record) => record.name), contains('new result'));
      expect(records.any((record) => record.id == existing.id), isFalse);
    });
  }

  test('cancel rollback does not invalidate another hash during record commit',
      () async {
    final published = Completer<void>();
    final release = Completer<void>();
    final owned = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final running = owned.run();
    await adapter.requested.future;
    adapter.succeed();
    await published.future;
    var cancelled = false;
    await TextManifest.addRecord(
        TextRecord(
            name: 'other hash',
            hash: 'other',
            createdAt: DateTime.now(),
            size: 10), beforeCommit: () {
      if (!cancelled) {
        cancelled = true;
        notifier.cancelTask(id);
        release.complete();
      }
    });
    await running;
    expect((await TextManifest.loadRecords()).single.name, 'other hash');
  });

  test('rollback reads current DB references without replacing shared cache',
      () async {
    final hash = computeTextHash(Uint8List.fromList(utf8.encode('owned text')));
    final published = Completer<void>();
    final release = Completer<void>();
    await TextManifest.loadRecords(); // Deliberately keep an older cached view.
    final owned = OcrTaskRunner(
      taskId: id,
      notifier: notifier,
      config: _config,
      images: [(input, 'png')],
      title: 'owned',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) =>
          OcrService(config: config, dio: Dio()..httpClientAdapter = adapter),
      writeText: (name, text, {beforeCommit}) async {
        final path = await TextManifest.writeText(name, text,
            beforeCommit: beforeCommit);
        published.complete();
        await release.future;
        return path;
      },
    );
    final running = owned.run();
    await adapter.requested.future;
    adapter.succeed();
    await published.future;
    await ManifestDatabase.insertTextRecord(TextRecord(
            name: 'DB reference',
            hash: hash,
            createdAt: DateTime.now(),
            size: 10)
        .toMap());
    notifier.cancelTask(id);
    release.complete();
    await running;
    expect(await TextManifest.readText('$hash.txt'), 'owned text');
    expect(
        (await TextManifest.loadRecordsUncached()).single.name, 'DB reference');
    expect(await TextManifest.loadRecords(), isEmpty,
        reason: "rollback lookup must not replace another caller's cache");
  });

  test('progress follows actual upload, server wait, parse and save', () async {
    final stages = <int>[];
    notifier.addListener((tasks) {
      final index = tasks.single.steps.indexWhere((step) => step.running);
      if (index >= 0 && (stages.isEmpty || stages.last != index)) {
        stages.add(index);
      }
    }, fireImmediately: false);
    writeGate = Completer<void>();
    final running = runner.run();
    final request = await adapter.requested.future;
    expect(notifier.state.single.steps[0].running, isTrue);
    request.onSendProgress!(5, 10);
    expect(notifier.state.single.steps[1].running, isTrue);
    expect(notifier.state.single.steps[1].label, contains('50%'));
    request.onSendProgress!(10, 10);
    expect(notifier.state.single.steps[2].running, isTrue);
    adapter.succeed();
    while (saves == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stages, [0, 1, 2, 3, 4]);
    expect(notifier.state.single.steps[4].running, isTrue);
    writeGate!.complete();
    await running;
  });

  for (final timeout in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$timeout fails once without saving or replay and closes client',
        () async {
      final running = runner.run();
      final request = await adapter.requested.future;
      expect(request.connectTimeout, const Duration(seconds: 30));
      expect(request.sendTimeout, const Duration(minutes: 1));
      expect(request.receiveTimeout, const Duration(minutes: 60));
      adapter.response
          .completeError(DioException(requestOptions: request, type: timeout));
      await running;
      expect(adapter.calls, 1);
      expect(saves, 0);
      expect(notifier.state.single.status, TaskStatus.failed);
      expect(notifier.state.single.rawResponse?['errorType'], timeout.name);
      expect(adapter.closed, isTrue);
    });
  }
}
