// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
import 'package:stroom/task_flow/services/block_executors/asr_executor.dart';
import 'package:stroom/task_flow/services/block_executors/audio_separation_executor.dart';
import 'package:stroom/task_flow/services/block_executors/ocr_executor.dart';
import 'package:stroom/task_flow/services/block_executors/shared_helpers.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

Uint8List _validPng() => img.encodePng(img.Image(width: 2, height: 2));

class _CancelOnCompletedStepBackground extends BackgroundTaskNotifier {
  void Function()? onCompletedStep;
  void Function()? onRunningStep;

  @override
  void updateStep(
    String taskId,
    int index, {
    bool? completed,
    bool? running,
    bool? failed,
    bool? skipped,
    String? error,
    String? label,
  }) {
    super.updateStep(
      taskId,
      index,
      completed: completed,
      running: running,
      failed: failed,
      skipped: skipped,
      error: error,
      label: label,
    );
    if (index == 1 && completed == true) onCompletedStep?.call();
    if (index == 1 && running == true) onRunningStep?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late TaskFlowExecutionNotifier executions;
  late BackgroundTaskNotifier background;
  late String execId;
  late FlowSubTask subTask;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('flow_artifact_cancel_');
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

  ProviderEntriesState providerFor(
    String type, {
    String host = 'https://example.invalid/recognition',
    Map<String, dynamic> typeConfig = const {},
    List<CustomParam> customParams = const [],
  }) {
    return ProviderEntriesState(entries: [
      ProviderEntry(name: type, type: type, configs: [
        ProviderConfigItem(
          id: 'config',
          host: host,
          key: 'test-key',
          models: [
            ModelConfig(
              id: 'model',
              name: 'Test',
              modelId: 'test',
              typeConfig: typeConfig,
              customParams: customParams,
            ),
          ],
        ),
      ]),
    ]);
  }

  TaskFlowBlock blockFor(BlockType type) => TaskFlowBlock(
        typeKey: type,
        params: {
          'modelRef': {'configId': 'config', 'modelId': 'model'},
        },
      );

  for (final type in [BlockType.asr, BlockType.ocr]) {
    test('${type.name} late response cannot save after cancellation', () async {
      final arrived = Completer<void>();
      final release = Completer<String>();

      final isAsr = type == BlockType.asr;
      final source =
          await File('${directory.path}/input.${isAsr ? 'wav' : 'png'}')
              .writeAsBytes(
                  isAsr ? pcmToWav(Uint8List.fromList([0, 0])) : _validPng());
      final pending = isAsr
          ? executeAsrBlock(
              block: blockFor(type),
              def: BlockTypeDefinition.asr,
              input: source.path,
              execId: execId,
              execNotifier: executions,
              flowSubTask: subTask,
              bgNotifier: background,
              providerEntries: providerFor('asr'),
              requestAsr: (_, __) {
                arrived.complete();
                return release.future;
              },
            )
          : executeOcrBlock(
              block: blockFor(type),
              def: BlockTypeDefinition.ocr,
              input: source.path,
              execId: execId,
              execNotifier: executions,
              flowSubTask: subTask,
              bgNotifier: background,
              providerEntries: providerFor('ocr'),
              requestOcr: (_, format) {
                expect(format, 'png');
                arrived.complete();
                return release.future;
              },
            );
      final assertion = expectLater(
        pending,
        throwsA(isA<BlockExecutionException>()),
      );
      await arrived.future.timeout(const Duration(seconds: 5));
      executions.cancelExecution(execId);
      expect(
          executions.execution(execId)?.status, FlowExecutionStatus.cancelled);
      release.complete('late result');
      await assertion;

      final hash =
          computeTextHash(Uint8List.fromList(utf8.encode('late result')));
      expect(await TextManifest.loadRecords(), isEmpty);
      expect(await WebFileStore.exists('texts/$hash.txt'), isFalse);
      expect(background.state.single.status, isNot(TaskStatus.completed));
      expect(
          executions.execution(execId)?.status, FlowExecutionStatus.cancelled);
    });

    test('${type.name} response still saves for an active execution', () async {
      final isAsr = type == BlockType.asr;
      final source =
          await File('${directory.path}/active.${isAsr ? 'wav' : 'png'}')
              .writeAsBytes(
                  isAsr ? pcmToWav(Uint8List.fromList([0, 0])) : _validPng());
      final result = await (isAsr
          ? executeAsrBlock(
              block: blockFor(type),
              def: BlockTypeDefinition.asr,
              input: source.path,
              execId: execId,
              execNotifier: executions,
              flowSubTask: subTask,
              bgNotifier: background,
              providerEntries: providerFor('asr'),
              requestAsr: (_, __) async => 'active result',
            )
          : executeOcrBlock(
              block: blockFor(type),
              def: BlockTypeDefinition.ocr,
              input: source.path,
              execId: execId,
              execNotifier: executions,
              flowSubTask: subTask,
              bgNotifier: background,
              providerEntries: providerFor('ocr'),
              requestOcr: (_, format) async {
                expect(format, 'png');
                return 'active result';
              },
            ));
      expect(result, 'active result');
      final records = await TextManifest.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.name, startsWith(isAsr ? '语音识别_' : '文字识别_'));
      expect(await TextManifest.readText(records.single.storageFileName),
          'active result');
      expect(background.state.single.status, TaskStatus.completed);
      expect(executions.execution(execId)?.status, FlowExecutionStatus.running);
    });
  }

  test('OCR shares options and fails truncated output', () async {
    final source = await File('${directory.path}/ocr_contract.png')
        .writeAsBytes(_validPng());
    final providers = providerFor(
      'ocr',
      host: 'https://example.invalid/v1/chat/completions/',
      typeConfig: {
        'enableMaxTokens': true,
        'maxTokens': 777,
        'enableTemperature': true,
        'temperature': 0.35,
        'enableTopP': true,
        'topP': 0.8,
        'userInstruction': '提取票据号码',
      },
      customParams: [
        CustomParam(
          paramName: 'response_format',
          defaultValue: '{"type":"json_object"}',
          type: 'json',
        ),
        CustomParam(
          paramName: 'top_k',
          defaultValue: '',
          type: 'number',
          options: ['50', '100'],
        ),
      ],
    );
    Map<String, dynamic>? requestBody;
    String? requestUrl;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          requestBody = Map<String, dynamic>.from(options.data as Map);
          requestUrl = options.uri.toString();
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'choices': [
                {
                  'finish_reason': 'length',
                  'message': {
                    'content': [
                      {'type': 'text', 'text': 'partial OCR text'},
                    ],
                  },
                },
              ],
            },
          ));
        },
      ));

    await expectLater(
      executeOcrBlock(
        block: blockFor(BlockType.ocr),
        def: BlockTypeDefinition.ocr,
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        providerEntries: providers,
        ocrDio: dio,
      ),
      throwsA(isA<BlockExecutionException>()),
    );

    expect(requestUrl, 'https://example.invalid/v1/chat/completions/');
    expect(requestBody?['model'], 'test');
    expect(requestBody?['max_tokens'], 777);
    expect(requestBody?['temperature'], 0.35);
    expect(requestBody?['top_p'], 0.8);
    expect(requestBody?['response_format'], {'type': 'json_object'});
    expect(requestBody?['top_k'], 50);
    final messages = requestBody?['messages'] as List;
    final userContent = (messages[1] as Map)['content'] as List;
    expect(userContent.last, {'type': 'text', 'text': '提取票据号码'});

    expect(background.state.single.status, TaskStatus.failed);
    expect(background.state.single.result, 'partial OCR text');
    expect(background.state.single.steps.first.status, BgStepStatus.failed);
    expect(executions.execution(execId)?.subTasks.single.status,
        TaskStatus.failed);
    expect(await TextManifest.loadRecords(), isEmpty);
  });

  Future<String> separateVideo(String input) => executeAudioSeparationBlock(
        def: BlockTypeDefinition.audioSeparation,
        block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
        input: input,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
      );

  test('web audio metadata yields while hashing large output', () async {
    final bytes = Uint8List(2 * 1024 * 1024);
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = (index * 17) & 0xff;
    }
    var hashingFinished = false;
    final metadata = computeAudioMetaWithEventLoopYield(bytes).then((value) {
      hashingFinished = true;
      return value;
    });

    await Future<void>.delayed(Duration.zero);

    expect(hashingFinished, isFalse);
    final result = await metadata;
    expect(result.$1, computeAudioHash(bytes));
    expect(result.$2, 'pcm');
  });

  test('separates a video stored behind a WebFileStore key', () async {
    const key = 'videos/library_clip.mp4';
    final video =
        await File('tests/fixtures/catcatch/audio_only.mp4').readAsBytes();
    await WebFileStore.write(key, video);

    final outputPath = await separateVideo(key);

    expect(await WebFileStore.read(outputPath), isNotEmpty);
    expect(await FileManifest.loadRecords(), hasLength(1));
  });

  test('separates a video from a native file path', () async {
    final video =
        await File('tests/fixtures/catcatch/audio_only.mp4').readAsBytes();
    final inputFile =
        await File('${directory.path}/native_clip.mp4').writeAsBytes(video);

    final outputPath = await separateVideo(inputFile.path);

    expect(await WebFileStore.read(outputPath), isNotEmpty);
    expect(await FileManifest.loadRecords(), hasLength(1));
  });

  test('does not start a WebFileStore read after cancellation during yield',
      () async {
    const key = 'videos/cancel_before_read.mp4';
    await WebFileStore.write(key, Uint8List.fromList([1]));
    var readCalls = 0;

    final pending = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: key,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      readWebFileBytes: (_) {
        readCalls++;
        return Future.value(Uint8List.fromList([1]));
      },
    );
    // The executor is suspended at its first frame yield, immediately before
    // it checks the WebFileStore key and starts reading the input.
    executions.cancelExecution(execId);

    await expectLater(pending, throwsA(isA<BlockExecutionException>()));

    expect(readCalls, 0);
    expect(
      executions.execution(execId)?.status,
      FlowExecutionStatus.cancelled,
    );
  });

  test('active flow still reads and separates a WebFileStore input', () async {
    const key = 'videos/active_read.mp4';
    final video =
        await File('tests/fixtures/catcatch/audio_only.mp4').readAsBytes();
    await WebFileStore.write(key, video);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    var readCalls = 0;

    final outputPath = await executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: key,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      readWebFileBytes: (path) {
        readCalls++;
        expect(path, key);
        return WebFileStore.read(path);
      },
      extractAudio: (path, format) {
        expect(path, key);
        expect(format, 'mp4');
        return Future.value(extracted);
      },
    );

    expect(readCalls, 1);
    expect(outputPath, 'tts_audio/${computeAudioHash(extracted)}.wav');
    expect(await WebFileStore.read(outputPath), extracted);
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(
      executions.execution(execId)?.status,
      FlowExecutionStatus.running,
    );
  });

  test('does not start metadata hashing after cancellation during yield',
      () async {
    final source = await File('${directory.path}/cancel_before_hash.mp4')
        .writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final cancellationScheduled = Completer<void>();
    background.dispose();
    final cancellingBackground = _CancelOnCompletedStepBackground();
    background = cancellingBackground;
    cancellingBackground.onRunningStep = () {
      scheduleMicrotask(() {
        executions.cancelExecution(execId);
        cancellationScheduled.complete();
      });
    };
    final pendingMetadata = Completer<(String, String)>();
    var metadataCalls = 0;

    final pending = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: source.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      extractAudio: (_, __) => Future.value(extracted),
      computeAudioMeta: (_) {
        metadataCalls++;
        return pendingMetadata.future;
      },
    );

    await expectLater(
      pending.timeout(const Duration(seconds: 2)),
      throwsA(isA<BlockExecutionException>()),
    );
    await cancellationScheduled.future;
    pendingMetadata.complete((computeAudioHash(extracted), 'wav'));

    expect(metadataCalls, 0);
    expect(
      executions.execution(execId)?.status,
      FlowExecutionStatus.cancelled,
    );
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  test('active flow still hashes and persists separated audio', () async {
    final source =
        await File('${directory.path}/active_metadata.mp4').writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    var metadataCalls = 0;

    final outputPath = await executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: source.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      extractAudio: (_, __) => Future.value(extracted),
      computeAudioMeta: (audioBytes) {
        metadataCalls++;
        return computeAudioMetaWithEventLoopYield(audioBytes);
      },
    );

    expect(metadataCalls, 1);
    expect(outputPath, 'tts_audio/${computeAudioHash(extracted)}.wav');
    expect(await WebFileStore.read(outputPath), extracted);
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(
      executions.execution(execId)?.status,
      FlowExecutionStatus.running,
    );
  });

  test('cancellation releases a pending WebFileStore read', () async {
    const key = 'videos/pending_clip.mp4';
    await WebFileStore.write(key, Uint8List.fromList([1]));
    final readStarted = Completer<void>();
    final releaseRead = Completer<Uint8List?>();
    var extractionStarted = false;
    final pending = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: key,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      readWebFileBytes: (_) {
        readStarted.complete();
        return releaseRead.future;
      },
      extractAudio: (_, __) {
        extractionStarted = true;
        return Future.value(pcmToWav(Uint8List.fromList([0, 0])));
      },
    );
    final assertion = expectLater(
      pending.timeout(const Duration(seconds: 2)),
      throwsA(isA<BlockExecutionException>()),
    );
    await readStarted.future.timeout(const Duration(seconds: 5));
    executions.cancelExecution(execId);
    try {
      await assertion;
    } finally {
      releaseRead.complete(Uint8List.fromList([1]));
    }

    expect(extractionStarted, isFalse);
    expect(executions.execution(execId)?.status, FlowExecutionStatus.cancelled);
  });

  test('cancellation releases an active separation wait before work finishes',
      () async {
    final source = await File('${directory.path}/input.mp4').writeAsBytes([1]);
    final entered = Completer<void>();
    final release = Completer<Uint8List>();
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final pending = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: source.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      extractAudio: (_, __) {
        entered.complete();
        return release.future;
      },
    );
    final assertion = expectLater(
      pending.timeout(const Duration(seconds: 2)),
      throwsA(isA<BlockExecutionException>()),
    );
    await entered.future.timeout(const Duration(seconds: 5));
    executions.cancelExecution(execId);
    try {
      await assertion;
    } finally {
      release.complete(extracted);
    }
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(
      await WebFileStore.exists('tts_audio/${computeAudioHash(extracted)}.wav'),
      isFalse,
    );
    expect(background.state.single.status, isNot(TaskStatus.completed));
    expect(executions.execution(execId)?.status, FlowExecutionStatus.cancelled);
  });

  test('cancellation after audio write removes unreferenced output', () async {
    final source = await File(
      '${directory.path}/written.mp4',
    ).writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final storageName = '${computeAudioHash(extracted)}.wav';
    var canceledAfterWrite = false;

    await expectLater(
      executeAudioSeparationBlock(
        def: BlockTypeDefinition.audioSeparation,
        block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        extractAudio: (_, __) async => extracted,
        onAudioFileWritten: () async {
          expect(await WebFileStore.exists('tts_audio/$storageName'), isTrue);
          expect(await FileManifest.loadRecords(), isEmpty);
          canceledAfterWrite = true;
          executions.cancelExecution(execId);
        },
      ),
      throwsA(isA<BlockExecutionException>()),
    );

    expect(canceledAfterWrite, isTrue);
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('tts_audio/$storageName'), isFalse);
  });

  test(
    'cancellation after audio write keeps output referenced by a record',
    () async {
      final source = await File(
        '${directory.path}/shared.mp4',
      ).writeAsBytes([1]);
      final extracted = pcmToWav(Uint8List.fromList([0, 0]));
      final storageName = '${computeAudioHash(extracted)}.wav';
      final existingRecord = AudioRecord(
        name: 'Existing audio',
        hash: computeAudioHash(extracted),
        format: 'wav',
        createdAt: DateTime.now(),
        size: extracted.length,
      );
      await FileManifest.writeFile(storageName, extracted);
      await FileManifest.addRecord(existingRecord);

      await expectLater(
        executeAudioSeparationBlock(
          def: BlockTypeDefinition.audioSeparation,
          block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
          input: source.path,
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          bgNotifier: background,
          extractAudio: (_, __) async => extracted,
          onAudioFileWritten: () async => executions.cancelExecution(execId),
        ),
        throwsA(isA<BlockExecutionException>()),
      );

      final records = await FileManifest.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.id, existingRecord.id);
      expect(await WebFileStore.read('tts_audio/$storageName'), extracted);
    },
  );

  test('cancellation keeps output when checking manifest references fails',
      () async {
    final source = await File(
      '${directory.path}/unknown_references.mp4',
    ).writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final storageName = '${computeAudioHash(extracted)}.wav';

    await expectLater(
      executeAudioSeparationBlock(
        def: BlockTypeDefinition.audioSeparation,
        block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        extractAudio: (_, __) async => extracted,
        onAudioFileWritten: () async => executions.cancelExecution(execId),
        loadAudioRecordsForCleanup: () async =>
            throw StateError('manifest unavailable'),
      ),
      throwsA(isA<BlockExecutionException>()),
    );

    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('tts_audio/$storageName'), isTrue);
  });

  test('record insertion failure removes the unreferenced output', () async {
    final source = await File(
      '${directory.path}/failed_record_insert.mp4',
    ).writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final storageName = '${computeAudioHash(extracted)}.wav';

    await expectLater(
      executeAudioSeparationBlock(
        def: BlockTypeDefinition.audioSeparation,
        block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        extractAudio: (_, __) async => extracted,
        addAudioRecord: (_) async => throw StateError('insert failed'),
      ),
      throwsA(isA<BlockExecutionException>()),
    );

    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('tts_audio/$storageName'), isFalse);
  });

  test('folder removal waits for a same-hash save before deleting bytes',
      () async {
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final hash = computeAudioHash(extracted);
    final storageName = '$hash.wav';
    final removableRecord = AudioRecord(
      name: 'Removable audio',
      hash: hash,
      format: 'wav',
      createdAt: DateTime.now(),
      size: extracted.length,
      folder: 'to_remove',
    );
    await FileManifest.writeFile(storageName, extracted);
    await FileManifest.addRecord(removableRecord);

    final writeStarted = Completer<void>();
    final releaseWrite = Completer<void>();
    final activeRecord = AudioRecord(
      name: 'Active audio',
      hash: hash,
      format: 'wav',
      createdAt: DateTime.now(),
      size: extracted.length,
      folder: 'keep',
    );
    final activeSave = FileManifest.withStorageFileSaveLock(
      storageName,
      () async {
        await FileManifest.writeFile(storageName, extracted);
        writeStarted.complete();
        await releaseWrite.future;
        await FileManifest.addRecord(activeRecord);
      },
    );
    await writeStarted.future;

    final removalWaiting = Completer<void>();
    final removal = FileManifest.removeFolder(
      'to_remove',
      onWaitingForSaves: () => removalWaiting.complete(),
    );
    await removalWaiting.future.timeout(const Duration(seconds: 5));
    var removedBeforeSaveFinished = false;
    unawaited(removal.then((_) => removedBeforeSaveFinished = true));
    await Future<void>.delayed(Duration.zero);
    expect(removedBeforeSaveFinished, isFalse);
    releaseWrite.complete();
    await activeSave;
    await removal;

    final records = await FileManifest.loadRecords();
    expect(records.map((record) => record.id), [activeRecord.id]);
    expect(await WebFileStore.read('tts_audio/$storageName'), extracted);
  });

  test('canceled separation waits for a concurrent same-hash save', () async {
    final firstSource = await File(
      '${directory.path}/first_shared.mp4',
    ).writeAsBytes([1]);
    final secondSource = await File(
      '${directory.path}/second_shared.mp4',
    ).writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final storageName = '${computeAudioHash(extracted)}.wav';
    final firstWriteFinished = Completer<void>();
    final releaseFirstWrite = Completer<void>();
    final secondWriteFinished = Completer<void>();
    final secondExecId = executions.addExecution(
      flowId: 'second_flow',
      flowName: 'Second Flow',
    );
    final secondSubTask = FlowSubTask(
      blockTypeKey: 'audio_separation',
      blockLabel: 'Audio Separation',
      subTaskId: 'pending_audio_1',
      subTaskType: 'background',
    );
    executions.addSubTask(secondExecId, secondSubTask);

    final first = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: firstSource.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      extractAudio: (_, __) async => extracted,
      onAudioFileWritten: () async {
        expect(await WebFileStore.exists('tts_audio/$storageName'), isTrue);
        firstWriteFinished.complete();
        await releaseFirstWrite.future;
      },
    );
    final firstAssertion = expectLater(
      first,
      throwsA(isA<BlockExecutionException>()),
    );
    await firstWriteFinished.future;

    final second = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: secondSource.path,
      execId: secondExecId,
      execNotifier: executions,
      flowSubTask: secondSubTask,
      bgNotifier: background,
      extractAudio: (_, __) async => extracted,
      onAudioFileWritten: () async => secondWriteFinished.complete(),
    );
    final secondAssertion = expectLater(second, completes);

    final secondWroteBeforeFirstReleased = await secondWriteFinished.future
        .then((_) => true)
        .timeout(const Duration(seconds: 1), onTimeout: () => false);
    expect(secondWroteBeforeFirstReleased, isFalse);

    executions.cancelExecution(execId);
    releaseFirstWrite.complete();
    await firstAssertion;
    await secondWriteFinished.future.timeout(const Duration(seconds: 5));
    await secondAssertion;

    final records = await FileManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.hash, computeAudioHash(extracted));
    expect(await WebFileStore.read('tts_audio/$storageName'), extracted);
  });

  test('canceled separation preserves a queued external audio save', () async {
    final source = await File(
      '${directory.path}/external_shared.mp4',
    ).writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final storageName = '${computeAudioHash(extracted)}.wav';
    final writeFinished = Completer<void>();
    final releaseWrite = Completer<void>();
    final externalSaveQueued = Completer<void>();

    final taskFlowSave = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: source.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      extractAudio: (_, __) async => extracted,
      onAudioFileWritten: () async {
        writeFinished.complete();
        await releaseWrite.future;
      },
    );
    final taskFlowAssertion = expectLater(
      taskFlowSave,
      throwsA(isA<BlockExecutionException>()),
    );
    await writeFinished.future;

    final externalRecord = AudioRecord(
      name: 'External audio save',
      hash: computeAudioHash(extracted),
      format: 'wav',
      createdAt: DateTime.now(),
      size: extracted.length,
    );
    final externalSave = FileManifest.withStorageFileSaveLock(
      storageName,
      () async {
        await FileManifest.writeFile(storageName, extracted);
        await FileManifest.addRecord(externalRecord);
      },
      onQueued: () => externalSaveQueued.complete(),
    );
    await externalSaveQueued.future.timeout(const Duration(seconds: 5));

    executions.cancelExecution(execId);
    releaseWrite.complete();
    await taskFlowAssertion;
    await externalSave;

    final records = await FileManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.id, externalRecord.id);
    expect(await WebFileStore.read('tts_audio/$storageName'), extracted);
  });

  test('canceled separation exits while queued on a same-hash save', () async {
    final firstSource = await File(
      '${directory.path}/queued_first.mp4',
    ).writeAsBytes([1]);
    final secondSource = await File(
      '${directory.path}/queued_second.mp4',
    ).writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    final storageName = '${computeAudioHash(extracted)}.wav';
    final firstWriteFinished = Completer<void>();
    final releaseFirstWrite = Completer<void>();
    final secondSaveQueued = Completer<void>();
    final secondExecId = executions.addExecution(
      flowId: 'queued_flow',
      flowName: 'Queued Flow',
    );
    final secondSubTask = FlowSubTask(
      blockTypeKey: 'audio_separation',
      blockLabel: 'Audio Separation',
      subTaskId: 'pending_audio_queued',
      subTaskType: 'background',
    );
    executions.addSubTask(secondExecId, secondSubTask);

    final first = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: firstSource.path,
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      bgNotifier: background,
      extractAudio: (_, __) async => extracted,
      onAudioFileWritten: () async {
        firstWriteFinished.complete();
        await releaseFirstWrite.future;
      },
    );
    final firstAssertion = expectLater(
      first,
      throwsA(isA<BlockExecutionException>()),
    );
    await firstWriteFinished.future;

    final second = executeAudioSeparationBlock(
      def: BlockTypeDefinition.audioSeparation,
      block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
      input: secondSource.path,
      execId: secondExecId,
      execNotifier: executions,
      flowSubTask: secondSubTask,
      bgNotifier: background,
      extractAudio: (_, __) async => extracted,
      onAudioFileSaveQueued: () => secondSaveQueued.complete(),
    );
    final secondAssertion = expectLater(
      second,
      throwsA(isA<BlockExecutionException>()),
    );
    await secondSaveQueued.future.timeout(const Duration(seconds: 5));

    executions.cancelExecution(secondExecId);
    var secondExitedBeforeFirstRelease = false;
    try {
      await secondAssertion.timeout(const Duration(seconds: 2));
      secondExitedBeforeFirstRelease = true;
      expect(await WebFileStore.read('tts_audio/$storageName'), extracted);
    } on TimeoutException {
      // The assertion below reports the stalled queued cancellation.
    } finally {
      executions.cancelExecution(execId);
      releaseFirstWrite.complete();
      await firstAssertion;
    }
    await secondAssertion;
    expect(secondExitedBeforeFirstRelease, isTrue);
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await WebFileStore.exists('tts_audio/$storageName'), isFalse);
  });

  test('separation removes its committed record if cancellation lands next',
      () async {
    background.dispose();
    final cancellingBackground = _CancelOnCompletedStepBackground();
    background = cancellingBackground;
    cancellingBackground.onCompletedStep =
        () => executions.cancelExecution(execId);
    final source =
        await File('${directory.path}/completed.mp4').writeAsBytes([1]);
    final extracted = pcmToWav(Uint8List.fromList([0, 0]));
    await expectLater(
      executeAudioSeparationBlock(
        def: BlockTypeDefinition.audioSeparation,
        block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
        input: source.path,
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        bgNotifier: background,
        extractAudio: (_, __) async => extracted,
      ),
      throwsA(isA<BlockExecutionException>()),
    );
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(
      await WebFileStore.exists('tts_audio/${computeAudioHash(extracted)}.wav'),
      isFalse,
    );
    expect(executions.execution(execId)?.status, FlowExecutionStatus.cancelled);
  });

  test('text commit guard is checked again after record lookup', () async {
    var checks = 0;
    final path = await saveTextForFlow(
      'late result',
      shouldCommit: () => ++checks == 1,
    );
    expect(path, isNull);
    expect(checks, 2);
    expect(await TextManifest.loadRecords(), isEmpty);
  });

  test('text commit guard removes a record if cancellation lands during insert',
      () async {
    var checks = 0;
    final path = await saveTextForFlow(
      'late result',
      shouldCommit: () => ++checks < 3,
    );
    expect(path, isNull);
    expect(checks, 3);
    expect(await TextManifest.loadRecords(), isEmpty);
    final hash =
        computeTextHash(Uint8List.fromList(utf8.encode('late result')));
    expect(await WebFileStore.exists('texts/$hash.txt'), isFalse);
  });
}
