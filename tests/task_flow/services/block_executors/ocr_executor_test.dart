// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
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

  ProviderEntriesState providerForOcr() => ProviderEntriesState(entries: [
        ProviderEntry(name: 'OCR', type: 'ocr', configs: [
          ProviderConfigItem(
            id: 'config',
            host: 'https://example.invalid/recognition',
            key: 'test-key',
            models: [
              ModelConfig(id: 'model', name: 'Test', modelId: 'test'),
            ],
          ),
        ]),
      ]);

  TaskFlowBlock ocrBlock() => TaskFlowBlock(
        typeKey: BlockType.ocr,
        params: {
          'modelRef': {'configId': 'config', 'modelId': 'model'},
        },
      );

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
}
