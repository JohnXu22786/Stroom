// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';

class _Notifier extends Mock implements CatCatchNotifier {}

void main() {
  test('native save skips rehash; legacy and mismatched paths use fallback',
      () async {
    final path = p.absolute('tests/fixtures/catcatch/video_only.mp4');
    var fallbackCalls = 0;
    Future<void> run(Map<String, String> metadata,
        {bool pauseOnOutput = false}) async {
      final notifier = _Notifier();
      final executions = TaskFlowExecutionNotifier();
      addTearDown(executions.dispose);
      final step = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: 'CatCatch',
        subTaskId: 'pending_catcatch',
        subTaskType: 'catcatch',
      );
      final execId = executions
          .addExecution(flowId: 'flow', flowName: 'Flow', subTasks: [step]);
      var tasks = <catcatch.CatCatchTask>[];
      when(() => notifier.state).thenAnswer((_) => tasks);
      when(() => notifier.addTask(
            any(),
            any(),
            taskId: any(named: 'taskId'),
            videoFolder: any(named: 'videoFolder'),
            audioFolder: any(named: 'audioFolder'),
            deferSingleResourceSelection:
                any(named: 'deferSingleResourceSelection'),
          )).thenAnswer((invocation) {
        final taskId = invocation.namedArguments[#taskId] as String;
        tasks = [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://example.invalid/video',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: catcatch.TaskStatus.completed,
            downloadedFilePath: path,
            metadata: metadata,
          ),
        ];
        return taskId;
      });
      final block = TaskFlowBlock(typeKey: BlockType.catcatch);
      expect(
        await executeCatCatchBlock(
          def: block.getDefinition()!,
          block: block,
          input: 'https://example.invalid/video',
          execId: execId,
          execNotifier: executions,
          flowSubTask: step,
          catcatchNotifier: notifier,
          pollInterval: const Duration(milliseconds: 1),
          onFallbackRegistration: () => fallbackCalls++,
          onOutputType: (_) {
            if (pauseOnOutput)
              executions.setExecutionStatus(execId, FlowExecutionStatus.paused);
          },
        ),
        path,
      );
      if (pauseOnOutput) {
        expect(
            executions.execution(execId)?.status, FlowExecutionStatus.paused);
      }
    }

    await run({catcatch.CatCatchTask.nativeRegisteredPathKey: path});
    expect(fallbackCalls, 0);
    await run({});
    expect(fallbackCalls, 1);
    await run(
        {catcatch.CatCatchTask.nativeRegisteredPathKey: '$path.previous'});
    expect(fallbackCalls, 2);
    await run({catcatch.CatCatchTask.nativeRegisteredPathKey: path},
        pauseOnOutput: true);
    expect(fallbackCalls, 2);
  });
}
