import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/audio_separation_executor.dart';
import 'package:stroom/utils/audio_utils.dart' show computeAudioHash;
import 'package:stroom/utils/file_manifest.dart';

const _executionId = 'execution-id';

class _MockTaskFlowExecutionNotifier extends Mock
    implements TaskFlowExecutionNotifier {}

class _MockBackgroundTaskNotifier extends Mock
    implements BackgroundTaskNotifier {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('executeAudioSeparationBlock cancellation before extraction', () {
    late Directory inputDirectory;
    late String inputPath;
    late FlowSubTask flowSubTask;
    late TaskFlowExecution execution;
    late _MockTaskFlowExecutionNotifier execNotifier;
    late _MockBackgroundTaskNotifier bgNotifier;
    var backgroundTaskCreated = false;

    setUp(() async {
      inputDirectory = await Directory.systemTemp.createTemp(
        'audio-separation-cancellation-',
      );
      inputPath = '${inputDirectory.path}/source.mp4';
      await File(inputPath).writeAsBytes([0]);

      flowSubTask = FlowSubTask(
        id: 'audio-step',
        blockTypeKey: BlockType.audioSeparation.name,
        blockLabel: BlockTypeDefinition.audioSeparation.label,
        subTaskId: 'pending-audio',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      execution = TaskFlowExecution(
        id: _executionId,
        flowId: 'flow-id',
        flowName: 'flow',
        subTasks: [flowSubTask],
      );
      execNotifier = _MockTaskFlowExecutionNotifier();
      when(() => execNotifier.execution(_executionId))
          .thenAnswer((_) => execution);

      bgNotifier = _MockBackgroundTaskNotifier();
      backgroundTaskCreated = false;
      when(() => bgNotifier.addTask(
            type: BackgroundTaskType.audioSeparation,
            title: '音频分离_source',
            taskId: any(named: 'taskId'),
          )).thenAnswer((_) {
        backgroundTaskCreated = true;
        return 'audio-task-id';
      });
    });

    tearDown(() async {
      await inputDirectory.delete(recursive: true);
    });

    test('does not start the extractor when canceled after task creation',
        () async {
      var extractorCalls = 0;
      final operation = _execute(
        inputPath: inputPath,
        flowSubTask: flowSubTask,
        execNotifier: execNotifier,
        bgNotifier: bgNotifier,
        extractAudio: (path, format) async {
          extractorCalls++;
          return Uint8List.fromList([1]);
        },
      );

      expect(backgroundTaskCreated, isTrue);
      execution = execution.copyWith(status: FlowExecutionStatus.cancelled);

      await expectLater(
        operation,
        throwsA(isA<BlockExecutionException>()),
      );
      expect(extractorCalls, 0);
    });

    test('starts the extractor while the flow is active', () async {
      final extractionStarted = Completer<void>();
      final extraction = Completer<Uint8List>();
      var extractorCalls = 0;
      final operation = _execute(
        inputPath: inputPath,
        flowSubTask: flowSubTask,
        execNotifier: execNotifier,
        bgNotifier: bgNotifier,
        extractAudio: (path, format) {
          extractorCalls++;
          extractionStarted.complete();
          return extraction.future;
        },
      );

      expect(backgroundTaskCreated, isTrue);
      await extractionStarted.future;
      expect(execution.isTerminal, isFalse);

      execution = execution.copyWith(status: FlowExecutionStatus.cancelled);
      extraction.complete(Uint8List.fromList([1]));
      await expectLater(
        operation,
        throwsA(isA<BlockExecutionException>()),
      );
      expect(extractorCalls, 1);
    });
  });

  group('executeAudioSeparationBlock title deduplication', () {
    late Directory inputDirectory;
    late String firstInputPath;
    late String secondInputPath;
    late FlowSubTask firstSubTask;
    late FlowSubTask secondSubTask;
    late TaskFlowExecution firstExecution;
    late TaskFlowExecution secondExecution;
    late _MockTaskFlowExecutionNotifier execNotifier;
    late _MockBackgroundTaskNotifier bgNotifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      ManifestDatabase.enableTestMode();
      FileManifest.invalidateCache();

      inputDirectory = await Directory.systemTemp.createTemp(
        'audio-separation-title-dedup-',
      );
      final firstInputDirectory = Directory('${inputDirectory.path}/first');
      final secondInputDirectory = Directory('${inputDirectory.path}/second');
      await firstInputDirectory.create();
      await secondInputDirectory.create();
      firstInputPath = '${firstInputDirectory.path}/source.mp4';
      secondInputPath = '${secondInputDirectory.path}/source.mp4';
      await File(firstInputPath).writeAsBytes([0]);
      await File(secondInputPath).writeAsBytes([0]);

      firstSubTask = FlowSubTask(
        id: 'first-audio-step',
        blockTypeKey: BlockType.audioSeparation.name,
        blockLabel: BlockTypeDefinition.audioSeparation.label,
        subTaskId: 'pending-first-audio',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      secondSubTask = FlowSubTask(
        id: 'second-audio-step',
        blockTypeKey: BlockType.audioSeparation.name,
        blockLabel: BlockTypeDefinition.audioSeparation.label,
        subTaskId: 'pending-second-audio',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      firstExecution = TaskFlowExecution(
        id: 'first-execution',
        flowId: 'first-flow',
        flowName: 'First flow',
        subTasks: [firstSubTask],
      );
      secondExecution = TaskFlowExecution(
        id: 'second-execution',
        flowId: 'second-flow',
        flowName: 'Second flow',
        subTasks: [secondSubTask],
      );
      execNotifier = _MockTaskFlowExecutionNotifier();
      when(
        () => execNotifier.execution('first-execution'),
      ).thenAnswer((_) => firstExecution);
      when(
        () => execNotifier.execution('second-execution'),
      ).thenAnswer((_) => secondExecution);

      bgNotifier = _MockBackgroundTaskNotifier();
      when(
        () => bgNotifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: '音频分离_source',
          taskId: any(named: 'taskId'),
        ),
      ).thenAnswer((_) => 'audio-task-id');
    });

    tearDown(() async {
      await inputDirectory.delete(recursive: true);
    });

    Future<String> separate({
      required String inputPath,
      required String executionId,
      required FlowSubTask subTask,
      required Uint8List outputBytes,
      Future<void> Function()? onAudioFileWritten,
      void Function()? onAudioRecordNameAllocationQueued,
      Future<void> Function(AudioRecord)? addAudioRecord,
    }) {
      return executeAudioSeparationBlock(
        def: BlockTypeDefinition.audioSeparation,
        block: TaskFlowBlock(
          typeKey: BlockType.audioSeparation,
          params: {'saveFolder': 'Shared'},
        ),
        input: inputPath,
        execId: executionId,
        execNotifier: execNotifier,
        flowSubTask: subTask,
        bgNotifier: bgNotifier,
        extractAudio: (_, __) async => outputBytes,
        computeAudioMeta: (bytes) async => (computeAudioHash(bytes), 'wav'),
        onAudioFileWritten: onAudioFileWritten,
        onAudioRecordNameAllocationQueued: onAudioRecordNameAllocationQueued,
        addAudioRecord: addAudioRecord,
      );
    }

    test(
      'concurrent different-hash outputs receive unique names and files',
      () async {
        final firstBytes = Uint8List.fromList([1, 2, 3]);
        final secondBytes = Uint8List.fromList([4, 5, 6]);
        final bothFilesWritten = Completer<void>();
        final releaseFileWrites = Completer<void>();
        var fileWrites = 0;
        Future<void> holdAfterFileWrite() async {
          if (++fileWrites == 2) bothFilesWritten.complete();
          await releaseFileWrites.future;
        }

        final firstRecordAtInsert = Completer<void>();
        final releaseFirstInsert = Completer<void>();
        final secondNameAllocationQueued = Completer<void>();
        Future<void> holdFirstRecordInsert(AudioRecord record) async {
          if (!firstRecordAtInsert.isCompleted) {
            firstRecordAtInsert.complete();
            await releaseFirstInsert.future;
          }
          await FileManifest.addRecord(record);
        }

        void observeQueuedNameAllocation() {
          if (!secondNameAllocationQueued.isCompleted) {
            secondNameAllocationQueued.complete();
          }
        }

        final first = separate(
          inputPath: firstInputPath,
          executionId: 'first-execution',
          subTask: firstSubTask,
          outputBytes: firstBytes,
          onAudioFileWritten: holdAfterFileWrite,
          onAudioRecordNameAllocationQueued: observeQueuedNameAllocation,
          addAudioRecord: holdFirstRecordInsert,
        );
        final second = separate(
          inputPath: secondInputPath,
          executionId: 'second-execution',
          subTask: secondSubTask,
          outputBytes: secondBytes,
          onAudioFileWritten: holdAfterFileWrite,
          onAudioRecordNameAllocationQueued: observeQueuedNameAllocation,
          addAudioRecord: holdFirstRecordInsert,
        );

        await bothFilesWritten.future;
        releaseFileWrites.complete();
        await secondNameAllocationQueued.future;
        releaseFirstInsert.complete();
        await Future.wait([first, second]);

        final records = await FileManifest.loadRecords();
        expect(records, hasLength(2));
        expect(records.map((record) => record.name).toSet(), {
          '音频分离_source',
          '音频分离_source (2)',
        });
        expect(records.every((record) => record.folder == 'Shared'), isTrue);
        expect(records.map((record) => record.hash).toSet(), {
          computeAudioHash(firstBytes),
          computeAudioHash(secondBytes),
        });
        expect(
          await FileManifest.readFile('${computeAudioHash(firstBytes)}.wav'),
          firstBytes,
        );
        expect(
          await FileManifest.readFile('${computeAudioHash(secondBytes)}.wav'),
          secondBytes,
        );
      },
    );

    test(
      'cancellation while queued for same-folder name allocation removes its file',
      () async {
        final firstBytes = Uint8List.fromList([13, 14, 15]);
        final secondBytes = Uint8List.fromList([16, 17, 18]);
        final firstRecordAtInsert = Completer<void>();
        final releaseFirstInsert = Completer<void>();
        final secondNameAllocationQueued = Completer<void>();

        Future<void> holdFirstRecordInsert(AudioRecord record) async {
          if (!firstRecordAtInsert.isCompleted) {
            firstRecordAtInsert.complete();
            await releaseFirstInsert.future;
          }
          await FileManifest.addRecord(record);
        }

        final first = separate(
          inputPath: firstInputPath,
          executionId: 'first-execution',
          subTask: firstSubTask,
          outputBytes: firstBytes,
          addAudioRecord: holdFirstRecordInsert,
        );
        await firstRecordAtInsert.future;

        final second = separate(
          inputPath: secondInputPath,
          executionId: 'second-execution',
          subTask: secondSubTask,
          outputBytes: secondBytes,
          onAudioRecordNameAllocationQueued: () {
            secondNameAllocationQueued.complete();
          },
        );
        final canceledSecond = expectLater(
          second,
          throwsA(isA<BlockExecutionException>()),
        );
        await secondNameAllocationQueued.future;

        secondExecution = secondExecution.copyWith(
          status: FlowExecutionStatus.cancelled,
        );
        await canceledSecond;
        final secondFileAfterCancellation = await FileManifest.readFile(
          '${computeAudioHash(secondBytes)}.wav',
        );
        releaseFirstInsert.complete();
        await expectLater(first, completes);

        expect(
          secondFileAfterCancellation,
          isNull,
          reason: 'the canceled flow never committed a record for its file',
        );
        final records = await FileManifest.loadRecords();
        expect(records, hasLength(1));
        expect(records.single.hash, computeAudioHash(firstBytes));
      },
    );

    test(
      'sequential saves keep the base name then use the (2) suffix',
      () async {
        final firstBytes = Uint8List.fromList([7, 8, 9]);
        final secondBytes = Uint8List.fromList([10, 11, 12]);

        await separate(
          inputPath: firstInputPath,
          executionId: 'first-execution',
          subTask: firstSubTask,
          outputBytes: firstBytes,
        );
        await separate(
          inputPath: secondInputPath,
          executionId: 'second-execution',
          subTask: secondSubTask,
          outputBytes: secondBytes,
        );

        final records = await FileManifest.loadRecords();
        expect(records.map((record) => record.name).toSet(), {
          '音频分离_source',
          '音频分离_source (2)',
        });
        expect(records.every((record) => record.folder == 'Shared'), isTrue);
      },
    );
  });
}

Future<String> _execute({
  required String inputPath,
  required FlowSubTask flowSubTask,
  required TaskFlowExecutionNotifier execNotifier,
  required BackgroundTaskNotifier bgNotifier,
  required Future<Uint8List> Function(String, String) extractAudio,
}) {
  return executeAudioSeparationBlock(
    def: BlockTypeDefinition.audioSeparation,
    block: TaskFlowBlock(typeKey: BlockType.audioSeparation),
    input: inputPath,
    execId: _executionId,
    execNotifier: execNotifier,
    flowSubTask: flowSubTask,
    bgNotifier: bgNotifier,
    extractAudio: extractAudio,
  );
}
