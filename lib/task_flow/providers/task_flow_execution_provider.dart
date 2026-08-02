import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';

import '../../providers/task_provider_shared.dart';
import '../models/task_flow_execution.dart';
import 'persistable_notifier.dart';

/// Provider for tracking task flow executions (for the unified task list).
final taskFlowExecutionsProvider =
    StateNotifierProvider<TaskFlowExecutionNotifier, List<TaskFlowExecution>>(
      (ref) => TaskFlowExecutionNotifier(),
    );

class TaskFlowExecutionNotifier extends StateNotifier<List<TaskFlowExecution>>
    with PersistableNotifier<List<TaskFlowExecution>> {
  TaskFlowExecutionNotifier() : super([]);

  // ===========================================================================
  // PersistableNotifier contract
  // ===========================================================================

  @override
  String get persistenceFileName => 'executions.json';

  @override
  List<TaskFlowExecution> fromJsonList(List<dynamic> json) {
    final result = <TaskFlowExecution>[];
    for (final item in json) {
      try {
        result.add(
          TaskFlowExecution.fromMap(Map<String, dynamic>.from(item as Map)),
        );
      } catch (e) {
        debugPrint('WARNING: Skipping corrupt TaskFlowExecution: $e');
      }
    }
    return result;
  }

  @override
  List<dynamic> toJsonList(List<TaskFlowExecution> state) {
    return state.map((e) => e.toMap()).toList();
  }

  // ===========================================================================
  // Operations
  // ===========================================================================

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
    _persistExecutions();
    return execution.id;
  }

  /// Add a sub-task to an existing execution.
  void addSubTask(String executionId, FlowSubTask subTask) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      return e.copyWith(subTasks: [...e.subTasks, subTask]);
    }).toList();
  }

  /// Update a placeholder sub-task's [subTaskId] with the real task ID
  /// after the actual task has been created.
  void updateSubTaskId(
    String executionId,
    String subTaskId,
    String newSubTaskId,
  ) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      final updated = e.subTasks.map((st) {
        if (st.id != subTaskId) return st;
        return st.copyWith(subTaskId: newSubTaskId);
      }).toList();
      return e.copyWith(subTasks: updated);
    }).toList();
  }

  /// Update a sub-task's status.
  ///
  /// Recomputes the execution status from the current sub-task states
  /// whenever a sub-task changes. This allows the flow to recover from
  /// "failed" to "completed" if a failed CatCatch task is retried and
  /// succeeds, or to move from "completed" to "failed" if a sub-task
  /// fails after the flow was already marked complete.
  void updateSubTaskStatus(
    String executionId,
    String subTaskId,
    TaskStatus status,
  ) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      final updated = e.subTasks.map((st) {
        if (st.id != subTaskId) return st;
        return st.copyWithStatus(status);
      }).toList();
      e = e.copyWith(subTasks: updated);

      if (updated.isEmpty) return e;

      final anyFailed = updated.any((st) => st.status == TaskStatus.failed);
      final anyRunning = updated.any(
        (st) =>
            st.status == TaskStatus.running ||
            st.status == TaskStatus.waiting ||
            st.status == TaskStatus.paused,
      );
      final allCompleted = updated.every(
        (st) => st.status == TaskStatus.completed,
      );

      if (anyFailed) {
        return e.copyWith(
          status: FlowExecutionStatus.failed,
          completedAt: updated.isNotEmpty ? DateTime.now() : null,
        );
      } else if (anyRunning) {
        return e.copyWith(status: FlowExecutionStatus.running);
      } else if (allCompleted) {
        return e.copyWith(
          status: FlowExecutionStatus.completed,
          completedAt: DateTime.now(),
        );
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
      if (e.subTasks.isEmpty) {
        return e.copyWith(
          status: FlowExecutionStatus.completed,
          completedAt: DateTime.now(),
        );
      }
      final allCompleted = e.subTasks.every(
        (st) => st.status == TaskStatus.completed,
      );
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
      return e;
    }).toList();
    _debouncedPersist();
  }

  /// Mark execution as failed.
  ///
  /// Also cascade-fails any sub-tasks that are not yet `completed` or
  /// `failed` (i.e., `waiting`, `running`, or `paused`).  When the flow
  /// terminates, those blocks will never execute (or continue), so marking
  /// them `failed` keeps the progress text consistent and prevents the
  /// UI from showing a spinner for a dead flow.
  void failExecution(String executionId, {String? error}) {
    state = state.map((e) {
      if (e.id != executionId) return e;
      final cascaded = e.subTasks.map((st) {
        if (st.status != TaskStatus.completed &&
            st.status != TaskStatus.failed) {
          return st.copyWithStatus(TaskStatus.failed);
        }
        return st;
      }).toList();
      return e.copyWith(
        status: FlowExecutionStatus.failed,
        completedAt: DateTime.now(),
        error: error,
        subTasks: cascaded,
      );
    }).toList();
    _debouncedPersist();
  }

  /// Remove an execution.
  void removeExecution(String executionId) {
    state = state.where((e) => e.id != executionId).toList();
    _debouncedPersist();
  }

  // ===========================================================================
  // Persistence
  // ===========================================================================

  Timer? _persistTimer;

  void _debouncedPersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 200), persist);
  }

  /// Persist immediately (bypasses debounce). Used only at creation time
  /// so the execution survives a crash before a terminal state is reached.
  void _persistExecutions() {
    persist();
  }

  /// Restore persisted executions on startup.
  Future<void> restoreFromPersistence() async {
    await restore();
    state = state.map((e) {
      if (e.status == FlowExecutionStatus.running) {
        return e.copyWith(
          status: FlowExecutionStatus.failed,
          completedAt: DateTime.now(),
          subTasks: e.subTasks.map((s) {
            if (s.status != TaskStatus.completed &&
                s.status != TaskStatus.failed) {
              return s.copyWithStatus(TaskStatus.failed);
            }
            return s;
          }).toList(),
        );
      }
      return e;
    }).toList();
    persist();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}
