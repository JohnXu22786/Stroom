import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/pages/ocr/ocr_retry_snapshot.dart';
import 'package:stroom/pages/ocr_page.dart';
import 'package:stroom/pages/text_preview_edit_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/ocr_instructions_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/ocr_retry_storage.dart';
import 'package:stroom/services/ocr_service.dart';
import 'package:stroom/services/ocr_task_runner.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/ocr_executor.dart';
import 'package:stroom/utils/ocr_image_payload.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

class _ScriptedOcrAdapter implements HttpClientAdapter {
  _ScriptedOcrAdapter(this.responses);

  final List<(int, String)> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, content) = responses.removeAt(0);
    final body = status >= 400
        ? {
            'error': {'message': content}
          }
        : {
            'choices': [
              {
                'message': {'content': content},
                'finish_reason': 'stop',
              },
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _typeConfig = <String, dynamic>{
  'enableMaxTokens': true,
  'maxTokens': 1536,
  'enableTemperature': true,
  'temperature': 0.2,
  'enableTopP': true,
  'topP': 0.8,
};

OcrConfig _ocrConfig() => OcrConfig(
      host: 'https://ocr.test/v1/chat/completions',
      apiKey: 'test-key',
      model: 'vision-test',
      typeConfig: _typeConfig,
      customParams: [
        CustomParam(paramName: 'detail', defaultValue: 'high'),
      ],
    );

ProviderEntry _ocrEntry() => ProviderEntry(
      id: 'ocr-entry',
      type: 'ocr',
      name: 'Test OCR',
      configs: [
        ProviderConfigItem(
          id: 'ocr-config',
          providerName: 'Test OCR',
          host: 'https://ocr.test/v1/chat/completions',
          key: 'test-key',
          models: [
            ModelConfig(
              id: 'ocr-model',
              name: 'Vision Test',
              modelId: 'vision-test',
              typeConfig: _typeConfig,
              customParams: [
                CustomParam(paramName: 'detail', defaultValue: 'high'),
              ],
            ),
          ],
        ),
      ],
    );

Dio _dioFor(OcrConfig config, _ScriptedOcrAdapter adapter) =>
    Dio(BaseOptions(headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
    }))
      ..httpClientAdapter = adapter;

OcrPage _ocrPage({
  required Uint8List pickedImage,
  required _ScriptedOcrAdapter adapter,
}) =>
    OcrPage(
      testGalleryPicker: ({maxWidth, maxHeight, imageQuality}) async => [
        XFile.fromData(
          pickedImage,
          path:
              '${Directory.systemTemp.path}${Platform.pathSeparator}invoice.png',
        ),
      ],
      testImagePayloadPreparer: (bytes) async =>
          prepareOcrImagePayloadSync(bytes),
      testOcrServiceFactory: (config) => OcrService(
        config: config,
        dio: _dioFor(config, adapter),
      ),
    );

Widget _deliveryApp({
  required BackgroundTaskNotifier background,
  required Uint8List pickedImage,
  required _ScriptedOcrAdapter adapter,
}) =>
    ProviderScope(
      overrides: [
        providerEntriesProvider.overrideWith((ref) {
          final notifier = ProviderEntriesNotifier();
          notifier.state = ProviderEntriesState(entries: [_ocrEntry()]);
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) => background),
        ocrInstructionsProvider.overrideWith((ref) {
          final notifier = OcrInstructionsNotifier(ref);
          notifier.state = const [];
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _ocrPage(
                      pickedImage: pickedImage,
                      adapter: adapter,
                    ),
                  ),
                ),
                child: const Text('打开 OCR'),
              ),
            ),
          ),
        ),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for condition');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> _requestBody(RequestOptions options) =>
    Map<String, dynamic>.from(options.data as Map);

Uint8List _requestImageBytes(RequestOptions options) {
  final messages = _requestBody(options)['messages'] as List;
  final content = messages[1]['content'] as List;
  final dataUri = content.single['image_url']['url'] as String;
  return base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));
}

Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 8, 6),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 6);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory taskDirectory;
  late Uint8List sourceImage;
  late BackgroundTaskNotifier background;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    WebFileStore.enableTestMode();
    TextManifest.invalidateCache();
    taskDirectory = await Directory.systemTemp.createTemp('ocr_e2e_delivery_');
    BackgroundTaskNotifier.debugStorageDirectoryOverride = taskDirectory.path;
    background = BackgroundTaskNotifier();
    sourceImage = Uint8List.fromList(
      img.encodePng(img.Image(width: 8, height: 6)),
    );
  });

  tearDown(() async {
    if (background.mounted) background.dispose();
    BackgroundTaskNotifier.debugStorageDirectoryOverride = null;
    await taskDirectory.delete(recursive: true);
  });

  testWidgets('page pick, edit, submit, save, open, and task-flow parity', (
    tester,
  ) async {
    sourceImage = (await tester.runAsync(_createEnginePng))!;
    final adapter = _ScriptedOcrAdapter([
      (200, 'Recognized text'),
      (200, 'Task flow text'),
    ]);
    await tester.pumpWidget(_deliveryApp(
      background: background,
      pickedImage: sourceImage,
      adapter: adapter,
    ));
    await tester.tap(find.text('打开 OCR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('相册选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从系统相册选择'));
    await tester.pump();
    await _pumpUntil(tester, () => find.text('已选 1 张图片').evaluate().isNotEmpty);

    await tester.tap(find.byKey(const Key('ocr_grid_item_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.crop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditorPage).evaluate().isNotEmpty,
    );
    await _pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
    );
    await tester.tap(find.text('右旋'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('保存'));
    await _pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始识别'));
    await _pumpUntil(tester, () => find.byType(OcrPage).evaluate().isEmpty);
    await _pumpUntil(
      tester,
      () =>
          adapter.requests.length == 1 &&
          background.state.any((task) => task.status == TaskStatus.completed),
    );
    final pageTask = background.state.single;
    expect(pageTask.result, 'Recognized text');
    final editedPayload = prepareOcrImagePayloadSync(
      _requestImageBytes(adapter.requests.first),
    );
    expect((editedPayload.width, editedPayload.height), (6, 8));
    final pageBody = _requestBody(adapter.requests.first);
    expect(pageBody['max_tokens'], 1536);
    expect(pageBody['temperature'], 0.2);
    expect(pageBody['top_p'], 0.8);
    expect(pageBody['detail'], 'high');

    final flow = TaskFlowExecutionNotifier();
    final executionId = flow.addExecution(
      flowId: 'ocr-parity-flow',
      flowName: 'OCR parity',
    );
    final subTask = FlowSubTask(
      blockTypeKey: 'ocr',
      blockLabel: 'OCR',
      subTaskId: 'ocr-parity-pending',
      subTaskType: 'background',
      status: TaskStatus.waiting,
    );
    flow.addSubTask(executionId, subTask);
    final inputFile = File('${taskDirectory.path}/edited.png');
    await tester.runAsync(
      () => inputFile.writeAsBytes(_requestImageBytes(adapter.requests.first)),
    );
    final config = _ocrConfig();
    final flowDio = _dioFor(config, adapter);
    final flowResult = await tester.runAsync(
      () => executeOcrBlock(
        block: TaskFlowBlock(
          typeKey: BlockType.ocr,
          params: {
            'modelRef': {'configId': 'ocr-config', 'modelId': 'ocr-model'},
          },
        ),
        def: BlockTypeDefinition.ocr,
        input: inputFile.path,
        execId: executionId,
        execNotifier: flow,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: ProviderEntriesState(entries: [_ocrEntry()]),
        ocrDio: flowDio,
      ),
    );
    expect(flowResult, 'Task flow text');
    flow.dispose();
    flowDio.close(force: true);

    final pageRequest = adapter.requests[0];
    final flowRequest = adapter.requests[1];
    expect(flowRequest.uri, pageRequest.uri);
    expect(
      flowRequest.headers['Authorization'],
      pageRequest.headers['Authorization'],
    );
    expect(_requestBody(flowRequest), _requestBody(pageRequest));

    final records = await tester.runAsync(TextManifest.loadRecordsUncached);
    expect(records, isNotNull);
    expect(
      records!.map((item) => item.name),
      contains('OCR_invoice.png'),
      reason: 'OCR completion must persist a text record',
    );
    final record =
        records.singleWhere((item) => item.name == 'OCR_invoice.png');
    final savedText = await tester.runAsync(
      () => TextManifest.readText(record.storageFileName),
    );
    expect(savedText, 'Recognized text');
    await tester.pumpWidget(
      MaterialApp(
        home: TextPreviewEditPage(file: record, initialContent: savedText),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recognized text'), findsOneWidget);
  });

  test('failed OCR task restores its image after restart and retries to save',
      () async {
    final failureAdapter = _ScriptedOcrAdapter([(503, 'temporary outage')]);
    final failedId = 'ocr-restart-failure';
    final retryData = await OcrRetryStorage.cacheSnapshot(
      taskId: failedId,
      snapshot: OcrRetrySnapshot.capture(
        configId: 'ocr-config',
        modelId: 'ocr-model',
        images: [
          OcrRetryImage(bytes: sourceImage, format: 'png', name: 'scan.png'),
        ],
      ),
    );
    background.addTask(
      type: BackgroundTaskType.ocr,
      title: 'OCR restart',
      retryData: retryData,
      taskId: failedId,
    );
    final firstRunner = OcrTaskRunner(
      taskId: failedId,
      notifier: background,
      config: _ocrConfig(),
      images: [(sourceImage, 'png')],
      title: 'OCR restart',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) => OcrService(
        config: config,
        dio: _dioFor(config, failureAdapter),
      ),
    );
    await firstRunner.run();
    expect(background.state.single.status, TaskStatus.failed);
    await background.pendingPersistence;

    background.dispose();
    background = BackgroundTaskNotifier();
    await background.restoreFromPersistence();
    final restored = background.state.single;
    expect(restored.id, failedId);
    expect(restored.status, TaskStatus.failed);
    expect(restored.retryData, isNotNull);
    final restoredImages = await OcrRetryStorage.restoreImages(
      OcrRetrySnapshot.fromMap(restored.retryData!),
    );
    expect(restoredImages.isComplete, isTrue);
    expect(restoredImages.images.single.bytes, sourceImage);

    final retryAdapter = _ScriptedOcrAdapter([(200, 'Recovered text')]);
    final retryId = background.addTask(
      type: BackgroundTaskType.ocr,
      title: 'OCR restart retry',
      retryData: restored.retryData,
    );
    final retryRunner = OcrTaskRunner(
      taskId: retryId,
      notifier: background,
      config: _ocrConfig(),
      images: [
        (
          restoredImages.images.single.bytes!,
          restoredImages.images.single.format
        ),
      ],
      title: 'OCR restart retry',
      folder: '',
      onSaved: () {},
      serviceFactory: (config) => OcrService(
        config: config,
        dio: _dioFor(config, retryAdapter),
      ),
    );
    await retryRunner.run();
    expect(background.state.firstWhere((task) => task.id == retryId).status,
        TaskStatus.completed);
    final record = (await TextManifest.loadRecords()).single;
    expect(
        await TextManifest.readText(record.storageFileName), 'Recovered text');
  });
}
