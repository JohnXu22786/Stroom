import 'package:flutter_riverpod/legacy.dart';

import '../../providers/task_provider_shared.dart';
import '../models/task_flow_execution.dart';

/// Provider for tracking task flow executions (for the unified task list).
final taskFlowExecutionsProvider =
    StateNotifierProvider<TaskFlowExecutionNotifier, List<TaskFlowExecution>>(
  (ref) => TaskFlowExecutionNotifier(),
);

class TaskFlowExecutionNotifier extends StateNotifier<List<TaskFlowExecution>> {
  TaskFlowExecutionNotifier() : super([]);

  /// Create a new execution entry.
  String addExecution({
    required String flowId,
    required String flowName,
    List<FlowSubTask> subTasks = const [],
  }) {
    final execution = TaskFlowExecution(
      flowId: flowId,
      flowName: flowName,
      subTasks: subTasks,
    );
    state = [execution, ...state];
    return execution.id;
  }

  /// Add a sub-task to an existing execution.
  void addSubTask(String executionId, FlowSubTask subTask) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      return e.copyWith(subTasks: [...e.subTasks, subTask]);
    }).toList();
  }

  /// Update a sub-task's status.
  void updateSubTaskStatus(
      String executionId, String subTaskId, TaskStatus status) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      final updated = e.subTasks.map((st) {
        if (st.id != subTaskId) return st;
        return st.copyWithStatus(status);
      }).toList();
      return e.copyWith(subTasks: updated);
    }).toList();
  }

  /// Mark execution as completed.
  ///
  /// Always marks as [FlowExecutionStatus.completed] because this is only
  /// called when all blocks have finished successfully. The previous logic
  /// checked `subTasks.every(completed)` which was fragile — a sub-task
  /// could still be in a non-completed state due to timing.
  void completeExecution(String executionId) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      return e.copyWith(
        status: FlowExecutionStatus.completed,
        completedAt: DateTime.now(),
      );
    }).toList();
  }

  /// Mark execution as failed.
  void failExecution(String executionId, {String? error}) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      return e.copyWith(
        status: FlowExecutionStatus.failed,
        completedAt: DateTime.now(),
        error: error,
      );
    }).toList();
  }

  /// Remove an execution.
  void removeExecution(String executionId) {
    state = state.where((e) => e.id != executionId).toList();
  }
}
