import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;

  @override
  Future<String> getApplicationDocumentsPath() async => path;
}

class _MockCatCatchNotifier extends Mock implements CatCatchNotifier {}

catcatch.CatCatchTask _failedTask(String id) => catcatch.CatCatchTask(
      id: id,
      url: 'https://example.com/v',
      expectedDurationSec: 0,
      title: '示例视频',
      status: catcatch.TaskStatus.failed,
      createdAt: DateTime(2026, 1, 1),
      steps: const [],
      error: '测试失败',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskFlowExecution inputDurationSec serialization', () {
    test('omitted from JSON when 0, round-trips when > 0', () {
      final without = TaskFlowExecution(
        flowId: 'f1',
        flowName: '流',
        inputText: 'https://example.com',
      );
      final mapWithout = without.toMap();
      expect(mapWithout.containsKey('inputDurationSec'), isFalse);
      expect(
        TaskFlowExecution.fromMap(mapWithout).inputDurationSec,
        0,
      );

      final withDuration = TaskFlowExecution(
        flowId: 'f1',
        flowName: '流',
        inputText: 'https://example.com',
        inputDurationSec: 125,
      );
      final mapWith = withDuration.toMap();
      expect(mapWith['inputDurationSec'], 125);
      expect(
        TaskFlowExecution.fromMap(mapWith).inputDurationSec,
        125,
      );
    });

    test('manifest input identity survives execution serialization', () {
      final execution = TaskFlowExecution(
        flowId: 'f1',
        flowName: '流',
        inputText: 'images/hash.png',
        inputType: IOType.image,
        inputManifestStoragePath: 'hash.png',
        inputManifestType: FlowInputManifestType.image,
      );

      final restored = TaskFlowExecution.fromMap(execution.toMap());
      expect(restored.inputText, 'images/hash.png');
      expect(restored.inputManifestStoragePath, 'hash.png');
      expect(restored.inputManifestType, FlowInputManifestType.image);
      expect(restored.inputStoragePath, isNull,
          reason: 'manifest files are not generic attachment copies');
    });

    test('manifest key resolves a path even when the saved path is stale',
        () async {
      SharedPreferences.setMockInitialValues({});
      ManifestDatabase.enableTestMode();
      ImageManifest.invalidateCache();
      final previous = PathProviderPlatform.instance;
      final directory =
          await Directory.systemTemp.createTemp('flow_manifest_input_');
      PathProviderPlatform.instance = _Documents(directory.path);
      final record = ImageRecord(
        id: 'task-flow-image',
        name: 'Input',
        hash: 'task-flow-inputs/image',
        format: 'png',
        createdAt: DateTime(2026, 1, 1),
        size: 4,
      );
      try {
        await ImageManifest.addRecord(record);
        await ImageManifest.writeFile(
          record.storagePath,
          Uint8List.fromList([1, 2, 3, 4]),
        );
        final manifestPath =
            await ImageManifest.readFilePath(record.storagePath);
        expect(manifestPath, isNotNull);

        final resolved = await resolveTaskFlowInputReference(
          FlowRunInput(
            text: '/old/container/path/image.png',
            manifestStoragePath: record.storagePath,
            manifestType: FlowInputManifestType.image,
          ),
        );

        expect(resolved, manifestPath);
      } finally {
        await ImageManifest.deleteFile(record.storagePath);
        await ManifestDatabase.clearAllData();
        ImageManifest.invalidateCache();
        PathProviderPlatform.instance = previous;
        await directory.delete(recursive: true);
      }
    });
  });

  group('TaskFlowExecutionService run-input fan-out', () {
    late ProviderContainer container;
    late TaskFlowExecutionService service;
    late _MockCatCatchNotifier catcatchNotifier;

    /// Captured (url, durationSec) pairs from catcatchNotifier.addTask.
    late List<(String, int)> addTaskCalls;

    String flowId = '';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      final flowNotifier = TaskFlowNotifier();
      flowId = flowNotifier.addFlow(
        name: '下载流程',
        blocks: [TaskFlowBlock(typeKey: BlockType.catcatch)],
      );

      addTaskCalls = [];
      final ocrConfig = ProviderConfigItem(
        id: 'test-ocr-config',
        providerName: 'Test OCR',
        host: 'https://example.com',
        key: 'test-key',
        models: [
          ModelConfig(
            id: 'test-ocr-model',
            name: 'Test OCR',
            modelId: 'test-ocr-model',
          ),
        ],
      );
      final providerNotifier = ProviderEntriesNotifier()
        ..state = ProviderEntriesState(
          entries: [
            ProviderEntry(
              id: 'test-ocr-entry',
              name: 'Test OCR',
              type: 'ocr',
              configs: [ocrConfig],
            ),
          ],
        );
      catcatchNotifier = _MockCatCatchNotifier();
      String? capturedTaskId;
      when(
        () => catcatchNotifier.addTask(
          any(),
          any(),
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((inv) {
        addTaskCalls.add((
          inv.positionalArguments[0] as String,
          inv.positionalArguments[1] as int,
        ));
        capturedTaskId = inv.namedArguments[#taskId] as String;
        return capturedTaskId!;
      });
      // The executor polls for the task with the id it created — always
      // answer with a failed task so the block terminates fast.
      when(() => catcatchNotifier.state).thenAnswer(
        (_) => [_failedTask(capturedTaskId ?? 'stub')],
      );

      container = ProviderContainer(
        overrides: [
          providerEntriesProvider.overrideWith((ref) => providerNotifier),
          taskFlowListProvider.overrideWith((ref) => flowNotifier),
          taskFlowExecutionsProvider.overrideWith(
            (ref) => TaskFlowExecutionNotifier(),
          ),
          catcatchTasksProvider.overrideWith((ref) => catcatchNotifier),
        ],
      );
      service = container.read(taskFlowExecutionServiceProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test(
        'startFlowMany creates one execution per input, each carrying its '
        'own input text and duration', () async {
      await service.startFlowMany(flowId, [
        const FlowRunInput(text: 'https://a.com/v', durationSec: 90),
        const FlowRunInput(text: 'https://b.com/v'),
      ]);

      final executions = container.read(taskFlowExecutionsProvider);
      expect(executions.length, 2);
      // The notifier prepends new executions — match by input text.
      final byText = {for (final e in executions) e.inputText: e};
      expect(byText['https://a.com/v']!.inputDurationSec, 90);
      expect(byText['https://b.com/v']!.inputDurationSec, 0);
    });

    test(
        'the per-run duration reaches the catcatch block and overrides the '
        'block default; zero falls back to the block config', () async {
      // Block configured with a 300s duration filter.
      flowId = container.read(taskFlowListProvider.notifier).addFlow(
        name: '带时长的下载流程',
        blocks: [
          TaskFlowBlock(
            typeKey: BlockType.catcatch,
            params: const {'durationSec': 300},
          ),
        ],
      );

      await service.startFlowMany(flowId, [
        const FlowRunInput(text: 'https://a.com/v', durationSec: 125),
        const FlowRunInput(text: 'https://b.com/v'),
      ]);

      expect(addTaskCalls.length, 2);
      // Per-run duration (125) beats the block-configured 300.
      expect(addTaskCalls[0], ('https://a.com/v', 125));
      // No per-run duration → the block-configured 300 is used.
      expect(addTaskCalls[1], ('https://b.com/v', 300));
    });

    test('retry re-resolves and persists an app media manifest identity',
        () async {
      ManifestDatabase.enableTestMode();
      ImageManifest.invalidateCache();
      final previous = PathProviderPlatform.instance;
      final directory =
          await Directory.systemTemp.createTemp('flow_manifest_retry_');
      PathProviderPlatform.instance = _Documents(directory.path);
      final record = ImageRecord(
        id: 'task-flow-retry-image',
        name: 'Input',
        hash: 'task-flow-retry/image',
        format: 'png',
        createdAt: DateTime(2026, 1, 1),
        size: 8,
      );
      try {
        await ImageManifest.addRecord(record);
        await ImageManifest.writeFile(
          record.storagePath,
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        );
        flowId = container.read(taskFlowListProvider.notifier).addFlow(
          name: '图片流程',
          inputType: IOType.image,
          blocks: [
            TaskFlowBlock(
              typeKey: BlockType.ocr,
              params: {
                'modelRef': {
                  'configId': 'test-ocr-config',
                  'modelId': 'test-ocr-model',
                },
              },
            ),
          ],
        );
        final original = TaskFlowExecution(
          flowId: flowId,
          flowName: '图片流程',
          status: FlowExecutionStatus.failed,
          inputText: '/old/container/path/image.png',
          inputType: IOType.image,
          inputFileName: 'Input.png',
          inputMimeType: 'image/png',
          inputManifestStoragePath: record.storagePath,
          inputManifestType: FlowInputManifestType.image,
        );
        await container
            .read(taskFlowExecutionsProvider.notifier)
            .addExecutions([original]);

        final ids = await service.retryExecution(
          original.id,
          useLatestConfiguration: true,
        );
        final execution = container
            .read(taskFlowExecutionsProvider)
            .firstWhere((item) => item.id == ids.single);
        final restored = TaskFlowExecution.fromMap(execution.toMap());
        expect(restored.inputText, '/old/container/path/image.png');
        expect(restored.inputManifestStoragePath, record.storagePath);
        expect(restored.inputManifestType, FlowInputManifestType.image);
        expect(restored.inputStoragePath, isNull);
      } finally {
        await ImageManifest.deleteFile(record.storagePath);
        await ManifestDatabase.clearAllData();
        ImageManifest.invalidateCache();
        PathProviderPlatform.instance = previous;
        await directory.delete(recursive: true);
      }
    });

    test(
        'startFlow keeps the single-input API and preserves durationSec '
        '(task-list retry path)', () async {
      await service.startFlow(
        flowId,
        'https://a.com/v',
        durationSec: 300,
      );

      final executions = container.read(taskFlowExecutionsProvider);
      expect(executions.length, 1);
      expect(executions[0].inputText, 'https://a.com/v');
      expect(executions[0].inputDurationSec, 300);
    });
  });
}
