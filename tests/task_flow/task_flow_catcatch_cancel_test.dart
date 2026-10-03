import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';

class _Download extends Mock implements CatCatchNotifier {}

class _Executions extends TaskFlowExecutionNotifier {
  @override
  Future<bool> persist() async => true;
}

void main() {
  test('a cancelled download flow stops polling and cancels its engine task',
      () async {
    final download = _Download();
    when(() => download.mounted).thenReturn(true);
    when(() => download.state).thenReturn([]);
    when(() => download.addTask(any(), any(),
            taskId: any(named: 'taskId'),
            videoFolder: any(named: 'videoFolder'),
            audioFolder: any(named: 'audioFolder')))
        .thenAnswer((call) => call.namedArguments[#taskId] as String);
    final executions = _Executions();
    final step = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: 'Download',
        subTaskId: 'pending_catcatch',
        subTaskType: 'catcatch');
    final id = executions
        .addExecution(flowId: 'flow', flowName: 'Flow', subTasks: [step]);
    final future = executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(typeKey: BlockType.catcatch),
        input: 'https://example.com',
        execId: id,
        execNotifier: executions,
        flowSubTask: step,
        catcatchNotifier: download,
        pollInterval: const Duration(milliseconds: 10));
    executions.cancelExecution(id);
    await expectLater(
        future,
        throwsA(isA<BlockExecutionException>().having(
            (error) => error.message, 'cancellation', contains('已停止'))));
    verify(() => download.removeTask(any())).called(1);
    expect(executions.executions.single.status, FlowExecutionStatus.cancelled);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    executions.dispose();
  });
}
