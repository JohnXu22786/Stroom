import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/audio_separation_executor.dart';

const _executionId = 'execution-id';

class _MockTaskFlowExecutionNotifier extends Mock
    implements TaskFlowExecutionNotifier {}

class _MockBackgroundTaskNotifier extends Mock
    implements BackgroundTaskNotifier {}

void main() {
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
