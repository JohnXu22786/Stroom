import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';

void main() {
  // ===========================================================================
  // Convert CatCatch status helper (mirrors _convertCatCatchStatus from card)
  // ===========================================================================
  TaskStatus _convertCatCatchStatus(catcatch.TaskStatus status) {
    switch (status) {
      case catcatch.TaskStatus.waiting:
        return TaskStatus.waiting;
      case catcatch.TaskStatus.running:
        return TaskStatus.running;
      case catcatch.TaskStatus.completed:
        return TaskStatus.completed;
      case catcatch.TaskStatus.failed:
        return TaskStatus.failed;
      case catcatch.TaskStatus.paused:
        return TaskStatus.paused;
    }
  }

  /// Priority: waiting(0) < running(1) < paused(2) < completed(3) / failed(3).
  int _statusPriority(TaskStatus status) {
    switch (status) {
      case TaskStatus.waiting:
        return 0;
      case TaskStatus.running:
        return 1;
      case TaskStatus.paused:
        return 2;
      case TaskStatus.completed:
      case TaskStatus.failed:
        return 3;
    }
  }

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

  // ===========================================================================
  // Status priority sync (mirrors card's _syncSubTaskStatuses logic)
  // ===========================================================================
  group('status priority prevents regression', () {
    test('running (1) does NOT overwrite completed (3)', () {
      expect(
          _statusPriority(TaskStatus.running) >
              _statusPriority(TaskStatus.completed),
          false);
    });

    test('completed (3) DOES overwrite running (1)', () {
      expect(
          _statusPriority(TaskStatus.completed) >
              _statusPriority(TaskStatus.running),
          true);
    });

    test('completed (3) DOES overwrite waiting (0)', () {
      expect(
          _statusPriority(TaskStatus.completed) >
              _statusPriority(TaskStatus.waiting),
          true);
    });

    test('running (1) DOES overwrite waiting (0)', () {
      expect(
          _statusPriority(TaskStatus.running) >
              _statusPriority(TaskStatus.waiting),
          true);
    });

    test('failed (3) has same priority as completed (3)', () {
      expect(_statusPriority(TaskStatus.failed),
          _statusPriority(TaskStatus.completed));
    });

    test(
        'paused (2) has higher priority than running (1) but lower than completed (3)',
        () {
      expect(
          _statusPriority(TaskStatus.paused) >
              _statusPriority(TaskStatus.running),
          true);
      expect(
          _statusPriority(TaskStatus.paused) <
              _statusPriority(TaskStatus.completed),
          true);
    });

    test(
        'waiting (0) does NOT overwrite running (1) — prevents card sync from reverting execution status',
        () {
      // This is the critical guard: if the card syncs while the real task is still
      // "waiting" but the execution block already set "running", the card must NOT
      // overwrite "running" with "waiting".
      expect(
          _statusPriority(TaskStatus.waiting) >
              _statusPriority(TaskStatus.running),
          false);
    });
  });

  // ===========================================================================
  // CatCatch TaskStatus conversion (mirrors _convertCatCatchStatus)
  // ===========================================================================
  group('_convertCatCatchStatus', () {
    test('catcatch.running → TaskStatus.running', () {
      expect(_convertCatCatchStatus(catcatch.TaskStatus.running),
          TaskStatus.running);
    });
    test('catcatch.completed → TaskStatus.completed', () {
      expect(_convertCatCatchStatus(catcatch.TaskStatus.completed),
          TaskStatus.completed);
    });
    test('catcatch.failed → TaskStatus.failed', () {
      expect(_convertCatCatchStatus(catcatch.TaskStatus.failed),
          TaskStatus.failed);
    });
    test('catcatch.paused → TaskStatus.paused', () {
      expect(_convertCatCatchStatus(catcatch.TaskStatus.paused),
          TaskStatus.paused);
    });
    test('catcatch.waiting → TaskStatus.waiting', () {
      expect(_convertCatCatchStatus(catcatch.TaskStatus.waiting),
          TaskStatus.waiting);
    });
  });

  // ===========================================================================
  // Flow execution status: failed takes priority over running
  // ===========================================================================
  group('execution status recomputation — failed priority', () {
    test(
        'if any sub-task failed, flow is failed even if others are still running',
        () {
      final notifier = TaskFlowExecutionNotifier();
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      final p1 = FlowSubTask(
        blockTypeKey: 'a',
        blockLabel: 'A',
        subTaskId: 'p1',
        subTaskType: 'catcatch',
        status: TaskStatus.failed,
      );
      notifier.addSubTask(execId, p1);

      final p2 = FlowSubTask(
        blockTypeKey: 'b',
        blockLabel: 'B',
        subTaskId: 'p2',
        subTaskType: 'background',
        status: TaskStatus.running,
      );
      notifier.addSubTask(execId, p2);

      // addSubTask does not auto-recompute flow status; trigger
      // recomputation so the failed priority logic is exercised.
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.failed);
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[1].id, TaskStatus.running);

      expect(notifier.state[0].status, FlowExecutionStatus.failed);
    });

    test('if any sub-task failed, flow is failed even if others are waiting',
        () {
      final notifier = TaskFlowExecutionNotifier();
      final execId = notifier.addExecution(flowId: 'f1', flowName: '测试');

      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'a',
            blockLabel: 'A',
            subTaskId: 'p1',
            subTaskType: 'catcatch',
            status: TaskStatus.failed,
          ));

      notifier.addSubTask(
          execId,
          FlowSubTask(
            blockTypeKey: 'b',
            blockLabel: 'B',
            subTaskId: 'p2',
            subTaskType: 'background',
            status: TaskStatus.waiting,
          ));

      // addSubTask does not auto-recompute flow status; trigger
      // recomputation so the failed priority logic is exercised.
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[0].id, TaskStatus.failed);
      notifier.updateSubTaskStatus(
          execId, notifier.state[0].subTasks[1].id, TaskStatus.waiting);

      expect(notifier.state[0].status, FlowExecutionStatus.failed);
    });
  });
}
