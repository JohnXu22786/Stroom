import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';

class _MockCatCatchNotifier extends Mock implements CatCatchNotifier {}

catcatch.CatCatchTask _task(
  catcatch.TaskStatus status, {
  required String id,
  int progress = 0,
  int downloadedBytes = 0,
  String? downloadedPath,
}) {
  return catcatch.CatCatchTask(
    id: id,
    url: 'https://example.com/video',
    title: '示例视频',
    status: status,
    expectedDurationSec: 0,
    createdAt: DateTime(2026, 1, 1),
    progress: progress,
    downloadedBytes: downloadedBytes,
    steps: [
      catcatch.StepStatus(
        type: catcatch.StepType.fetching,
        running: status == catcatch.TaskStatus.running,
        progress: progress,
      ),
    ],
    downloadedFilePath: downloadedPath,
  );
}

void main() {
  group('executeCatCatchBlock stall detection', () {
    late TaskFlowExecutionNotifier execNotifier;
    late FlowSubTask flowSubTask;
    late String execId;

    setUp(() {
      execNotifier = TaskFlowExecutionNotifier();
      execId = execNotifier.addExecution(flowId: 'f1', flowName: '测试流');
      flowSubTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      execNotifier.addSubTask(execId, flowSubTask);
    });

    test(
        'abandons a stalled task: no progress change for stallTimeout '
        'cancels the engine and fails the block', () async {
      final notifier = _MockCatCatchNotifier();
      final removedIds = <String>[];
      late String capturedTaskId;
      when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
          .thenAnswer((inv) {
        capturedTaskId = inv.namedArguments[#taskId] as String;
        return capturedTaskId;
      });
      when(() => notifier.state).thenAnswer(
        (_) => [_task(catcatch.TaskStatus.running, id: capturedTaskId)],
      );
      when(() => notifier.removeTask(any())).thenAnswer((inv) {
        removedIds.add(inv.positionalArguments.first as String);
      });

      await expectLater(
        executeCatCatchBlock(
          def: BlockTypeDefinition.catcatch,
          block: TaskFlowBlock(typeKey: BlockType.catcatch),
          input: 'https://example.com/video',
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          catcatchNotifier: notifier,
          stallTimeout: const Duration(milliseconds: 100),
        ),
        throwsA(
          isA<BlockExecutionException>().having(
            (e) => e.message,
            'message',
            contains('下载无进展'),
          ),
        ),
      );

      expect(removedIds, [capturedTaskId],
          reason: 'a stalled task must be cancelled via removeTask');
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.failed);
      expect(execNotifier.state[0].status, FlowExecutionStatus.failed);
    });

    test('progress changes keep the task alive until it completes', () async {
      final notifier = _MockCatCatchNotifier();
      var reads = 0;
      late String capturedTaskId;
      when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
          .thenAnswer((inv) {
        capturedTaskId = inv.namedArguments[#taskId] as String;
        return capturedTaskId;
      });
      when(() => notifier.state).thenAnswer((_) {
        reads++;
        // Read 1 = the executor's pre-loop snapshot (still running);
        // read 2+ = the poll loop sees the task completed — a healthy
        // task that finishes, so stall detection must never fire.
        if (reads == 1) {
          return [
            _task(catcatch.TaskStatus.running,
                id: capturedTaskId, progress: 30),
          ];
        }
        return [
          _task(
            catcatch.TaskStatus.completed,
            id: capturedTaskId,
            progress: 100,
            downloadedPath: 'C:\\out\\video.mp4',
          ),
        ];
      });
      when(() => notifier.removeTask(any())).thenReturn(null);

      final result = await executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(typeKey: BlockType.catcatch),
        input: 'https://example.com/video',
        execId: execId,
        execNotifier: execNotifier,
        flowSubTask: flowSubTask,
        catcatchNotifier: notifier,
        stallTimeout: const Duration(milliseconds: 100),
      );

      expect(result, 'C:\\out\\video.mp4');
      expect(execNotifier.state[0].subTasks[0].status, TaskStatus.completed);
      verifyNever(() => notifier.removeTask(any()));
    });

    test(
        'byte progress (chunked download, no Content-Length) keeps a '
        'healthy task alive even when percent progress stays 0', () async {
      final notifier = _MockCatCatchNotifier();
      var reads = 0;
      late String capturedTaskId;
      when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
          .thenAnswer((inv) {
        capturedTaskId = inv.namedArguments[#taskId] as String;
        return capturedTaskId;
      });
      when(() => notifier.state).thenAnswer((_) {
        reads++;
        // Chunked download: percent progress stays 0, but bytes stream in
        // for the first several reads (healthy) — then byte progress stops
        // (simulating a download that finally stalls).
        if (reads <= 5) {
          return [
            _task(catcatch.TaskStatus.running,
                id: capturedTaskId, downloadedBytes: (reads - 1) * 1024 * 1024),
          ];
        }
        return [
          _task(catcatch.TaskStatus.running,
              id: capturedTaskId, downloadedBytes: 5 * 1024 * 1024),
        ];
      });
      when(() => notifier.removeTask(any())).thenReturn(null);

      await expectLater(
        executeCatCatchBlock(
          def: BlockTypeDefinition.catcatch,
          block: TaskFlowBlock(typeKey: BlockType.catcatch),
          input: 'https://example.com/video',
          execId: execId,
          execNotifier: execNotifier,
          flowSubTask: flowSubTask,
          catcatchNotifier: notifier,
          stallTimeout: const Duration(milliseconds: 100),
        ),
        throwsA(
          isA<BlockExecutionException>().having(
            (e) => e.message,
            'message',
            contains('下载无进展'),
          ),
        ),
      );

      // The stall fires only AFTER byte progress stops — while bytes were
      // increasing (reads 2-5), no cancellation happened.
      verify(() => notifier.removeTask(any())).called(1);
    });
  });
}
