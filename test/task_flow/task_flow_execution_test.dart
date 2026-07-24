import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';

void main() {
  group('FlowSubTask', () {
    test('default status is running', () {
      final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'task-1',
        subTaskType: 'catcatch',
      );
      expect(subTask.status, TaskStatus.running);
    });

    test('copyWithStatus updates status', () {
      final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'task-1',
        subTaskType: 'catcatch',
      );
      final updated = subTask.copyWithStatus(TaskStatus.completed);
      expect(updated.status, TaskStatus.completed);
      expect(updated.id, subTask.id);
      expect(updated.blockTypeKey, subTask.blockTypeKey);
    });
  });

  group('TaskFlowExecutionNotifier', () {
    late TaskFlowExecutionNotifier notifier;

    setUp(() {
      notifier = TaskFlowExecutionNotifier();
    });

    test('initial state is empty', () {
      expect(notifier.state, isEmpty);
    });

    test('addExecution creates a running execution', () {
      final id = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      expect(notifier.state.length, 1);
      final exec = notifier.state[0];
      expect(exec.status, FlowExecutionStatus.running);
      expect(exec.flowName, '测试流程');
      expect(exec.id, id);
    });

    test('addSubTask adds sub-task to execution', () {
      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '获取网页资源',
        subTaskId: 'real-task-1',
        subTaskType: 'catcatch',
      );

      notifier.addSubTask(execId, subTask);

      expect(notifier.state[0].subTasks.length, 1);
      expect(notifier.state[0].subTasks[0].subTaskId, 'real-task-1');
    });

    test('updateSubTaskStatus updates the sub-task status', () {
      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'real-task-1',
            subTaskType: 'catcatch',
          ));

      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.completed);

      expect(notifier.state[0].subTasks[0].status, TaskStatus.completed);
    });

    group('auto-completion on updateSubTaskStatus', () {
      test('completes execution when all sub-tasks are completed', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        final stId1 = notifier.state[0].subTasks.isNotEmpty
            ? notifier.state[0].subTasks[0].id
            : null;
        final subTask = FlowSubTask(
          blockTypeKey: 'catcatch',
          blockLabel: '获取网页资源',
          subTaskId: 'real-task-1',
          subTaskType: 'catcatch',
        );
        notifier.addSubTask(execId, subTask);
        final stId = notifier.state[0].subTasks[0].id;

        // Set to completed
        notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);

        expect(notifier.state[0].status, FlowExecutionStatus.completed);
        expect(notifier.state[0].completedAt, isNotNull);
      });

      test('fails execution when sub-task fails', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'real-task-1',
              subTaskType: 'catcatch',
            ));
        final stId = notifier.state[0].subTasks[0].id;

        // Set to failed
        notifier.updateSubTaskStatus(execId, stId, TaskStatus.failed);

        expect(notifier.state[0].status, FlowExecutionStatus.failed);
        expect(notifier.state[0].completedAt, isNotNull);
      });

      test('does NOT auto-complete when sub-task is still running', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'real-task-1',
              subTaskType: 'catcatch',
            ));
        final stId = notifier.state[0].subTasks[0].id;

        // Sub-task is already "running" by default — updating to running again
        // should NOT complete the execution
        notifier.updateSubTaskStatus(execId, stId, TaskStatus.running);

        expect(notifier.state[0].status, FlowExecutionStatus.running);
      });

      test('completes with multiple sub-tasks only when ALL are done', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '双块流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'task-1',
              subTaskType: 'catcatch',
            ));
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'asr',
              blockLabel: '语音识别',
              subTaskId: 'task-2',
              subTaskType: 'background',
            ));
        final stId1 = notifier.state[0].subTasks[0].id;
        final stId2 = notifier.state[0].subTasks[1].id;

        // Only first sub-task completed — should still be running
        notifier.updateSubTaskStatus(execId, stId1, TaskStatus.completed);
        expect(notifier.state[0].status, FlowExecutionStatus.running);

        // Both completed → flow completes
        notifier.updateSubTaskStatus(execId, stId2, TaskStatus.completed);
        expect(notifier.state[0].status, FlowExecutionStatus.completed);
      });

      test('fails execution when ANY sub-task fails while others are done', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '双块流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'task-1',
              subTaskType: 'catcatch',
            ));
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'asr',
              blockLabel: '语音识别',
              subTaskId: 'task-2',
              subTaskType: 'background',
            ));
        final stId1 = notifier.state[0].subTasks[0].id;
        final stId2 = notifier.state[0].subTasks[1].id;

        // First completed, second failed — should fail
        notifier.updateSubTaskStatus(execId, stId1, TaskStatus.completed);
        notifier.updateSubTaskStatus(execId, stId2, TaskStatus.failed);

        expect(notifier.state[0].status, FlowExecutionStatus.failed);
      });

      test('does NOT auto-complete if execution is already completed', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'task-1',
              subTaskType: 'catcatch',
            ));

        // Complete the sub-task first so completeExecution can work
        final stId = notifier.state[0].subTasks[0].id;
        notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);
        expect(notifier.state[0].status, FlowExecutionStatus.completed);

        // Calling completeExecution again on an already-completed flow
        // is a no-op
        notifier.completeExecution(execId);
        expect(notifier.state[0].status, FlowExecutionStatus.completed);
      });
    });

    group('completeExecution', () {
      test('sets status to completed when all sub-tasks are completed', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'task-1',
              subTaskType: 'catcatch',
            ));

        // Complete the sub-task first
        final stId = notifier.state[0].subTasks[0].id;
        notifier.updateSubTaskStatus(execId, stId, TaskStatus.completed);

        // Then call completeExecution
        notifier.completeExecution(execId);

        expect(notifier.state[0].status, FlowExecutionStatus.completed);
        expect(notifier.state[0].completedAt, isNotNull);
      });

      test('stays running when sub-tasks are still in progress', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'task-1',
              subTaskType: 'catcatch',
            ));

        // completeExecution while sub-task is still running
        notifier.completeExecution(execId);

        // Should stay running; auto-complete will handle transition
        expect(notifier.state[0].status, FlowExecutionStatus.running);
      });

      test('sets status to failed when any sub-task failed', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );
        notifier.addSubTask(
            execId,
            FlowSubTask(
              blockTypeKey: 'catcatch',
              blockLabel: '获取网页资源',
              subTaskId: 'task-1',
              subTaskType: 'catcatch',
            ));

        // Complete sub-task as failed
        final stId = notifier.state[0].subTasks[0].id;
        notifier.updateSubTaskStatus(execId, stId, TaskStatus.failed);

        // Then call completeExecution
        notifier.completeExecution(execId);

        expect(notifier.state[0].status, FlowExecutionStatus.failed);
        expect(notifier.state[0].completedAt, isNotNull);
      });
    });

    group('failExecution', () {
      test('sets status to failed with optional error message', () {
        final execId = notifier.addExecution(
          flowId: 'flow-1',
          flowName: '测试流程',
        );

        notifier.failExecution(execId, error: '连接超时');

        expect(notifier.state[0].status, FlowExecutionStatus.failed);
        expect(notifier.state[0].error, '连接超时');
        expect(notifier.state[0].completedAt, isNotNull);
      });
    });

    test('removeExecution removes the execution by id', () {
      final id = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      expect(notifier.state.length, 1);

      notifier.removeExecution(id);
      expect(notifier.state, isEmpty);
    });

    test('taskStatus getter returns correct TaskStatus', () {
      final running = TaskFlowExecution(
        flowId: 'flow-1',
        flowName: '运行中',
        status: FlowExecutionStatus.running,
      );
      final completed = TaskFlowExecution(
        flowId: 'flow-2',
        flowName: '已完成',
        status: FlowExecutionStatus.completed,
      );
      final failed = TaskFlowExecution(
        flowId: 'flow-3',
        flowName: '失败',
        status: FlowExecutionStatus.failed,
      );

      expect(running.taskStatus, TaskStatus.running);
      expect(completed.taskStatus, TaskStatus.completed);
      expect(failed.taskStatus, TaskStatus.failed);
    });
  });

  group('End-to-end: flow execution lifecycle', () {
    /// Simulates the flow execution lifecycle where the CatCatch block
    /// creates a real task and the polling loop monitors it.
    ///
    /// The execution page calls these methods in order:
    /// 1. addExecution
    /// 2. addSubTask (sub-task starts as "running")
    /// 3. updateSubTaskStatus (via polling loop when CatCatch completes)
    /// 4. completeExecution (from _startFlow after all blocks done)
    test('normal flow: catcatch succeeds, flow completes', () {
      final notifier = TaskFlowExecutionNotifier();

      // Step 1: Create execution
      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // Step 2: Add sub-task
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'real-catcatch-task', // matches CatCatch task ID
            subTaskType: 'catcatch',
          ));
      expect(notifier.state[0].subTasks.length, 1);
      // Sub-task starts as "running" (default)
      expect(notifier.state[0].subTasks[0].status, TaskStatus.running);
      // Flow is still running
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // Step 3: Polling loop detects CatCatch task completed
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.completed);
      // Flow auto-completes (all sub-tasks are terminal)
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
      expect(notifier.state[0].subTasks[0].status, TaskStatus.completed);

      // Step 4: completeExecution is called (from _startFlow)
      // At this point the flow is already completed by auto-complete,
      // so this is a no-op for status
      final prevStatus = notifier.state[0].status;
      notifier.completeExecution(execId);
      expect(notifier.state[0].status, prevStatus);
    });

    test('disposed flow: widget closed while catcatch is still running', () {
      final notifier = TaskFlowExecutionNotifier();

      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );

      // Add sub-task and set it running
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'real-catcatch-task',
            subTaskType: 'catcatch',
          ));
      // Sub-task is "running" (default) — simulates widget disposing while
      // the CatCatch task is still running
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // Simulate: CatCatch task completes later (in background)
      // The TaskFlowCard's _syncSubTaskStatuses picks this up
      // and calls updateSubTaskStatus
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.completed);

      // Flow auto-completes
      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test('disposed flow: catcatch succeeds but no completeExecution called',
        () {
      final notifier = TaskFlowExecutionNotifier();

      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'task-1',
            subTaskType: 'catcatch',
          ));

      // Widget disposed — _startFlow returns early.
      // completeExecution is NOT called. The flow stays "running".
      // But later the CatCatch task completes, and _syncSubTaskStatuses
      // calls updateSubTaskStatus which auto-completes.
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // CatCatch task completed in background
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.completed);

      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });

    test('catcatch fails: sub-task is failed, flow auto-fails', () {
      final notifier = TaskFlowExecutionNotifier();

      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'task-1',
            subTaskType: 'catcatch',
          ));

      // Polling loop sees CatCatch task failed
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.failed);

      // Flow auto-fails
      expect(notifier.state[0].status, FlowExecutionStatus.failed);
      expect(notifier.state[0].subTasks[0].status, TaskStatus.failed);
    });

    test('catcatch paused: sub-task stays paused until auto-select or manual',
        () {
      final notifier = TaskFlowExecutionNotifier();

      final execId = notifier.addExecution(
        flowId: 'flow-1',
        flowName: '测试流程',
      );
      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: '获取网页资源',
            subTaskId: 'task-1',
            subTaskType: 'catcatch',
          ));

      // Pipeline paused at userSelecting
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.paused);

      // Flow is still running (paused is not terminal)
      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // Auto-select sets it back to running
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.running);

      expect(notifier.state[0].status, FlowExecutionStatus.running);

      // Then completed
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.completed);

      expect(notifier.state[0].status, FlowExecutionStatus.completed);
    });
  });
}
