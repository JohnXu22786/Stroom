import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';

class _Notifier extends Mock implements CatCatchNotifier {}

void main() {
  test('human confirmation can outlast the stall window', () async {
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载',
        subTaskId: 'pending',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting);
    executions.addSubTask(execId, subTask);
    late String taskId;
    var reads = 0;
    when(() => notifier.addTask(any(), any(), taskId: any(named: 'taskId')))
        .thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.state).thenAnswer((_) {
      reads++;
      return [
        catcatch.CatCatchTask(
          id: taskId,
          url: 'https://x',
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          status: reads < 4
              ? catcatch.TaskStatus.running
              : catcatch.TaskStatus.completed,
          metadata: reads < 4 ? {'pendingConfirm': 'special_format'} : {},
          steps: reads < 4
              ? [
                  const catcatch.StepStatus(
                      type: catcatch.StepType.converting, running: true)
                ]
              : [],
          downloadedFilePath: reads < 4
              ? null
              : p.absolute('tests/fixtures/catcatch/video_only.mp4'),
        )
      ];
    });
    when(() => notifier.removeTask(any())).thenReturn(null);
    when(() => notifier.confirmAndContinue(any())).thenReturn(null);
    final result = await executeCatCatchBlock(
      def: BlockTypeDefinition.catcatch,
      block: TaskFlowBlock(typeKey: BlockType.catcatch),
      input: 'https://x',
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      catcatchNotifier: notifier,
      stallTimeout: const Duration(milliseconds: 100),
    );
    expect(result, p.absolute('tests/fixtures/catcatch/video_only.mp4'));
    verifyNever(() => notifier.confirmAndContinue(any()));
    verifyNever(() => notifier.removeTask(any()));
  });
}
