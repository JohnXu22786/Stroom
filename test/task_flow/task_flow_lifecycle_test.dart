import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';

void main() {
  group('TaskFlow sub-task lifecycle with placeholders', () {
    late TaskFlowExecutionNotifier notifier;

    setUp(() {
      notifier = TaskFlowExecutionNotifier();
    });

    // =========================================================================
    // 1. Placeholder creation
    // =========================================================================
    test('placeholder sub-task is created with waiting status', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '双步流');

      final placeholder = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, placeholder);

      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'audioSeparation',
            blockLabel: '音频分离',
            subTaskId: 'pending_audioSeparation_1',
            subTaskType: 'background',
            status: TaskStatus.waiting,
          ));

      final exec = notifier.state[0];
      expect(exec.subTasks.length, 2);
      expect(exec.subTasks[0].status, TaskStatus.waiting);
      expect(exec.subTasks[0].subTaskId, 'pending_catcatch_0');
      expect(exec.subTasks[1].status, TaskStatus.waiting);
      expect(exec.subTasks[1].subTaskId, 'pending_audioSeparation_1');
    });

    test('both sub-tasks appear immediately, not one at a time', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '双步流');

      // Simulate the pre-creation in _startFlow
      final catcatchPlaceholder = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, catcatchPlaceholder);

      final audioPlaceholder = FlowSubTask(
        blockTypeKey: 'audioSeparation',
        blockLabel: '音频分离',
        subTaskId: 'pending_audioSeparation_1',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, audioPlaceholder);

      // Both should be present immediately
      final exec = notifier.state[0];
      expect(exec.subTasks.length, 2);
    });

    // =========================================================================
    // 2. Placeholder → real ID transition
    // =========================================================================
    test('updateSubTaskId replaces placeholder with real task ID', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final placeholder = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, placeholder);
      final placeholderId = notifier.state[0].subTasks[0].id;

      // Simulate CatCatch creating the real task
      final realTaskId = 'cc_abc123';
      notifier.updateSubTaskId(execId, placeholderId, realTaskId);

      final exec = notifier.state[0];
      expect(exec.subTasks[0].subTaskId, realTaskId);
      expect(exec.subTasks[0].status, TaskStatus.waiting); // status unchanged
    });

    test('updateSubTaskId only affects the matched sub-task', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '双步流');

      final p1 = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, p1);
      final id1 = notifier.state[0].subTasks[0].id;

      final p2 = FlowSubTask(
        blockTypeKey: 'audioSeparation',
        blockLabel: '音频分离',
        subTaskId: 'pending_audioSeparation_1',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, p2);

      // Only update sub-task 1's ID
      notifier.updateSubTaskId(execId, id1, 'real_catcatch_id');

      final exec = notifier.state[0];
      expect(exec.subTasks[0].subTaskId, 'real_catcatch_id');
      expect(
          exec.subTasks[1].subTaskId, 'pending_audioSeparation_1'); // unchanged
    });

    // =========================================================================
    // 3. Status transitions: waiting → running → completed
    // =========================================================================
    test('sub-task transitions: waiting → running → completed (happy path)',
        () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final placeholder = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, placeholder);
      final stId = notifier.state[0].subTasks[0].id;

      // Block starts → update ID + set running
      notifier.updateSubTaskId(execId, stId, 'real_task_123');
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.running);

      var exec = notifier.state[0];
      expect(exec.subTasks[0].status, TaskStatus.running);
      expect(exec.subTasks[0].subTaskId, 'real_task_123');
      expect(exec.status, FlowExecutionStatus.running);

      // Block completes
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);
      notifier.completeExecution(execId);

      exec = notifier.state[0];
      expect(exec.subTasks[0].status, TaskStatus.completed);
      expect(exec.status, FlowExecutionStatus.completed);
    });

    test('sub-task transitions: waiting → running → failed (error path)', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final placeholder = FlowSubTask(
        blockTypeKey: 'audioSeparation',
        blockLabel: '音频分离',
        subTaskId: 'pending_audioSeparation_0',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, placeholder);
      final stId = notifier.state[0].subTasks[0].id;

      // Block starts
      notifier.updateSubTaskId(execId, stId, 'bg_task_id');
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.running);

      // File read fails → sub-task fails
      notifier.updateSubTaskStatus(execId, stId, TaskStatus.failed);
      notifier.failExecution(execId, error: '输入文件不存在');

      final exec = notifier.state[0];
      expect(exec.subTasks[0].status, TaskStatus.failed);
      expect(exec.status, FlowExecutionStatus.failed);
    });

    // =========================================================================
    // 4. Multi-block flow: sub-tasks progress independently
    // =========================================================================
    test('two-block flow: first completes, second stays running', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '双步流');

      // Create placeholders for both blocks
      final p1 = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, p1);
      final id1 = notifier.state[0].subTasks[0].id;

      final p2 = FlowSubTask(
        blockTypeKey: 'audioSeparation',
        blockLabel: '音频分离',
        subTaskId: 'pending_audioSeparation_1',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, p2);
      final id2 = notifier.state[0].subTasks[1].id;

      // Block 0 starts and completes
      notifier.updateSubTaskId(execId, id1, 'cc_task_1');
      notifier.updateSubTaskStatus(execId, id1, TaskStatus.running);
      notifier.updateSubTaskStatus(execId, id1, TaskStatus.completed);

      // Block 1 starts (but not yet complete)
      notifier.updateSubTaskId(execId, id2, 'bg_task_1');
      notifier.updateSubTaskStatus(execId, id2, TaskStatus.running);

      var exec = notifier.state[0];
      expect(exec.subTasks[0].status, TaskStatus.completed);
      expect(exec.subTasks[1].status, TaskStatus.running);
      expect(exec.status, FlowExecutionStatus.running); // flow still running

      // Block 1 completes
      notifier.updateSubTaskStatus(execId, id2, TaskStatus.completed);
      notifier.completeExecution(execId);

      exec = notifier.state[0];
      expect(exec.subTasks[0].status, TaskStatus.completed);
      expect(exec.subTasks[1].status, TaskStatus.completed);
      expect(exec.status, FlowExecutionStatus.completed);
    });

    // =========================================================================
    // 5. Flow status recomputation
    // =========================================================================
    test('flow stays running when any sub-task is waiting or running', () {
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final p1 = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'p1',
        subTaskType: 'catcatch',
        status: TaskStatus.completed,
      );
      notifier.addSubTask(execId, p1);

      final p2 = FlowSubTask(
        blockTypeKey: 'audioSeparation',
        blockLabel: '音频分离',
        subTaskId: 'p2',
        subTaskType: 'background',
        status: TaskStatus.waiting, // ← still waiting
      );
      notifier.addSubTask(execId, p2);

      final exec = notifier.state[0];
      expect(exec.status, FlowExecutionStatus.running);
      // Should NOT be completed even though one sub-task is done
      expect(exec.status != FlowExecutionStatus.completed, isTrue);
    });
  });

  group('TaskFlowExecutionNotifier updateSubTaskId', () {
    test('updateSubTaskId preserves all other sub-task fields', () {
      final notifier = TaskFlowExecutionNotifier();
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final placeholder = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'pending_catcatch_0',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, placeholder);
      final stId = notifier.state[0].subTasks[0].id;

      notifier.updateSubTaskId(execId, stId, 'real_task_id');

      final updated = notifier.state[0].subTasks[0];
      expect(updated.id, stId);
      expect(updated.blockTypeKey, 'catcatch');
      expect(updated.blockLabel, '获取网页资源');
      expect(updated.subTaskType, 'catcatch');
      expect(updated.status, TaskStatus.waiting); // unchanged
      expect(updated.subTaskId, 'real_task_id'); // changed
    });

    test('updateSubTaskId does not affect other executions', () {
      final notifier = TaskFlowExecutionNotifier();

      final execId1 = notifier.addExecution(flowId: 'f1', flowName: '一');
      notifier.addSubTask(
          execId1,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: 'A',
            subTaskId: 'pending_0',
            subTaskType: 'catcatch',
          ));
      final st1Id =
          notifier.state.where((e) => e.id == execId1).first.subTasks[0].id;

      final execId2 = notifier.addExecution(flowId: 'f2', flowName: '二');
      notifier.addSubTask(
          execId2,
          FlowSubTask(
            blockTypeKey: 'asr',
            blockLabel: 'B',
            subTaskId: 'pending_0',
            subTaskType: 'background',
          ));

      // Only update execution 1
      notifier.updateSubTaskId(execId1, st1Id, 'real_1');

      // Execution 2 should be unaffected
      final exec2 = notifier.state.where((e) => e.id == execId2).first;
      expect(exec2.subTasks[0].subTaskId, 'pending_0');
    });

    test('updateSubTaskId with non-existent sub-task ID does nothing', () {
      final notifier = TaskFlowExecutionNotifier();
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      // Should not throw
      notifier.updateSubTaskId(execId, 'non_existent_id', 'new_id');

      // Verify state unchanged
      expect(notifier.state.length, 1);
    });
  });

  group('recomputes execution status from sub-task states', () {
    test('all waiting → running', () {
      final notifier = TaskFlowExecutionNotifier();
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final p1 = FlowSubTask(
        blockTypeKey: 'a',
        blockLabel: 'A',
        subTaskId: 'p1',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, p1);

      final p2 = FlowSubTask(
        blockTypeKey: 'b',
        blockLabel: 'B',
        subTaskId: 'p2',
        subTaskType: 'background',
        status: TaskStatus.waiting,
      );
      notifier.addSubTask(execId, p2);

      // Even with waiting, should still be running (not completed)
      expect(notifier.state[0].status, FlowExecutionStatus.running);
    });
  });
}
