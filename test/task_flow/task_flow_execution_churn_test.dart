import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';

void main() {
  group('TaskFlowExecutionNotifier completeExecution', () {
    late TaskFlowExecutionNotifier notifier;

    setUp(() {
      notifier = TaskFlowExecutionNotifier();
    });

    // =========================================================================
    // completeExecution behavior tests
    // =========================================================================
    test('all sub-tasks completed → flow becomes completed', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));
      final stId = notifier.state[0].subTasks[0].id;

      // Simulate: CatCatch task completed, polling loop updates sub-task
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);
      // Auto-complete should fire, but test that completeExecution also works
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test('sub-tasks still running → completeExecution stays running', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));

      // Call completeExecution while sub-task is running (default)
      notifier.completeExecution(execId);

      // Flow should stay running
      expect(notifier.state[0].status, FlowExecutionStatus.running);
    });

    test('any sub-task failed → completeExecution sets failed', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));
      final stId = notifier.state[0].subTasks[0].id;

      // Simulate: CatCatch task failed
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.failed);
      // Auto-complete should have set failed already
      expect(notifier.state[0].status, FlowExecutionStatus.failed);
    });

    test('multi-sub-task: all completed → completed', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '双块');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'asr',
            blockLabel: '语音识别',
            subTaskId: 't2',
            subTaskType: 'background',
          ));
      final st1 = notifier.state[0].subTasks[0].id;
      final st2 = notifier.state[0].subTasks[1].id;

      notifier.updateSubTaskStatus(execId, st1, TaskStatus.completed);
      // Still running (not all done)
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      notifier.updateSubTaskStatus(execId, st2, TaskStatus.completed);
      // All done
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test('multi-sub-task: one failed, one completed → failed', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '双块');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'asr',
            blockLabel: '语音识别',
            subTaskId: 't2',
            subTaskType: 'background',
          ));
      final st1 = notifier.state[0].subTasks[0].id;
      final st2 = notifier.state[0].subTasks[1].id;

      notifier.updateSubTaskStatus(execId, st1, TaskStatus.completed);
      notifier.updateSubTaskStatus(execId, st2, TaskStatus.failed);

      expect(notifier.state[0].status, FlowExecutionStatus.failed);
    });

    // =========================================================================
    // Critical: flow should NOT show "completed" when sub-tasks are running
    // and it should NOT show "failed" when sub-tasks are completed.
    // =========================================================================

    test('BUGFIX: completeExecution with running subtask must NOT mark failed',
        () {
      // When the flow execution page calls completeExecution after the for-loop,
      // but the sub-tasks are still running (e.g., CatCatch polling returned
      // early), the flow must stay running, NOT be marked as failed.
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));

      // Sub-task is running (default)
      notifier.completeExecution(execId);

      // Must NOT be failed — must stay running
      expect(notifier.state[0].status, isNot(FlowExecutionStatus.failed));
      expect(notifier.state[0].status, FlowExecutionStatus.running);
    });

    test(
        'BUGFIX: completed sub-tasks + completeExecution = completed, not failed',
        () {
      // The polling loop completed the CatCatch task, updated the sub-task
      // to completed. Then _startFlow calls completeExecution. The result
      // MUST be completed (not failed).
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));
      final stId = notifier.state[0].subTasks[0].id;

      // CatCatch completed, polling loop updated sub-task
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);
      expect(notifier.state[0].subTasks[0].status, TaskStatus.completed);

      // Now completeExecution is called from _startFlow
      notifier.completeExecution(execId);

      // MUST be completed
      expect(notifier.state[0].status, isNot(FlowExecutionStatus.failed));
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test('BUGFIX: failed sub-tasks + completeExecution = failed', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 't1',
            subTaskType: 'catcatch',
          ));
      final stId = notifier.state[0].subTasks[0].id;

      // CatCatch failed
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.failed);
      expect(notifier.state[0].subTasks[0].status, TaskStatus.failed);

      // Called from _startFlow (though _startFlow only calls on success,
      // test the worst case)
      notifier.completeExecution(execId);

      expect(notifier.state[0].status, FlowExecutionStatus.failed);
    });
  });

  // ===========================================================================
  // Simulate the exact _startFlow → completeExecution flow path
  // ===========================================================================
  group('Simulated _startFlow lifecycle', () {
    late TaskFlowExecutionNotifier notifier;

    setUp(() {
      notifier = TaskFlowExecutionNotifier();
    });

    test('scenario: CatCatch blocks succeeds, flow completes', () {
      // Simulates _startFlow creating execution and blocks running
      final execId = notifier.addExecution(flowId: 'f1', flowName: '任务');

      // Block 1: CatCatch
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'catcatch-task',
            subTaskType: 'catcatch',
          ));
      // CatCatch task eventually completes
      final stId = notifier.state[0].subTasks[0].id;
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);
      expect(notifier.state[0].subTasks[0].status, TaskStatus.completed);

      // _startFlow for-loop ends, allSucceeded=true
      // completeExecution is called
      notifier.completeExecution(execId);

      // Flow must be COMPLETED
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test('scenario: CatCatch task running, flow stays running', () {
      // Bug scenario: completeExecution called while CatCatch is still
      // running. Flow must stay running, not fail.
      final execId = notifier.addExecution(flowId: 'f1', flowName: '任务');

      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'catcatch-task',
            subTaskType: 'catcatch',
          ));
      // Sub-task is running (default)
      expect(notifier.state[0].subTasks[0].status, TaskStatus.running);

      // completeExecution called while task is running
      notifier.completeExecution(execId);

      // Flow must stay RUNNING, NOT failed
      expect(notifier.state[0].status, isNot(FlowExecutionStatus.failed));
      expect(notifier.state[0].status, FlowExecutionStatus.running);
    });

    test('scenario: CatCatch task completes later → auto-complete', () {
      // Widget disposed during CatCatch execution. completeExecution was
      // NOT called (because _startFlow exited early). CatCatch completes
      // later in background. _syncSubTaskStatuses updates sub-task.
      // auto-complete fires.
      final execId = notifier.addExecution(flowId: 'f1', flowName: '任务');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'catcatch-task',
            subTaskType: 'catcatch',
          ));

      // Widget disposed, completeExecution NOT called.
      // Flow stays running.
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // Later, CatCatch completes in background.
      final stId = notifier.state[0].subTasks[0].id;
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);

      // Auto-complete should fire → flow completed
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test(
        'scenario: flow recovers from failed to completed when tasks are retried',
        () {
      // When failExecution was called but the CatCatch task is later retried
      // and succeeds, the flow should recover to "completed" status.
      final execId = notifier.addExecution(flowId: 'f1', flowName: '任务');
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'catcatch-task',
            subTaskType: 'catcatch',
          ));

      // failExecution called (e.g., the CatCatch task initially failed)
      notifier.failExecution(execId, error: '下载失败');
      expect(notifier.state[0].status, FlowExecutionStatus.failed);
      expect(notifier.state[0].error, '下载失败');

      // User retried the CatCatch task, it succeeded.
      // _syncSubTaskStatuses updates the sub-task to completed.
      final stId = notifier.state[0].subTasks[0].id;
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);

      // Flow should recover to completed
      expect(notifier.state[0].subTasks[0].status, TaskStatus.completed);
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });
  });
}
