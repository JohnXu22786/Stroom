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
  ///
  /// If the execution is still "running" and all sub-tasks have reached a
  /// terminal state (completed or failed), this method will automatically
  /// mark the execution as completed/failed.
  void updateSubTaskStatus(
      String executionId, String subTaskId, TaskStatus status) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      final updated = e.subTasks.map((st) {
        if (st.id != subTaskId) return st;
        return st.copyWithStatus(status);
      }).toList();
      e = e.copyWith(subTasks: updated);
      // Auto-complete/auto-fail if all sub-tasks reached terminal state.
      // This handles the case where the execution page was disposed mid-flow
      // and the underlying tasks continued running in the background.
      if (e.status == FlowExecutionStatus.running) {
        final allTerminal = updated.every(
          (st) =>
              st.status == TaskStatus.completed ||
              st.status == TaskStatus.failed,
        );
        if (allTerminal && updated.isNotEmpty) {
          final allCompleted =
              updated.every((st) => st.status == TaskStatus.completed);
          return e.copyWith(
            status: allCompleted
                ? FlowExecutionStatus.completed
                : FlowExecutionStatus.failed,
            completedAt: DateTime.now(),
          );
        }
      }
      return e;
    }).toList();
  }

  /// Mark execution as completed.
  ///
  /// Sets status based on sub-task states:
  /// - All completed → completed
  /// - Any running → stays running (wait for auto-complete)
  /// - Any failed → failed
  void completeExecution(String executionId) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      // Compute status from sub-tasks
      if (e.subTasks.isEmpty) {
        return e.copyWith(
          status: FlowExecutionStatus.completed,
          completedAt: DateTime.now(),
        );
      }
      final allCompleted =
          e.subTasks.every((st) => st.status == TaskStatus.completed);
      final anyFailed = e.subTasks.any((st) => st.status == TaskStatus.failed);
      if (allCompleted) {
        return e.copyWith(
          status: FlowExecutionStatus.completed,
          completedAt: DateTime.now(),
        );
      } else if (anyFailed) {
        return e.copyWith(
          status: FlowExecutionStatus.failed,
          completedAt: DateTime.now(),
        );
      }
      // Still running — leave as is; auto-complete will handle it
      return e;
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
