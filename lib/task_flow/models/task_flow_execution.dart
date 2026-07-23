import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../providers/task_provider_shared.dart';

/// Status of a task flow execution.
enum FlowExecutionStatus { running, completed, failed }

/// A single sub-task within a task flow execution.
///
/// Each sub-task corresponds to one block in the flow definition.
/// The [subTaskId] references the actual task created in the
/// underlying task system (CatCatch, BackgroundTask, SynthesisTask).
@immutable
class FlowSubTask {
  final String id;
  final String blockTypeKey;
  final String blockLabel;
  final String subTaskId;
  final String subTaskType; // 'catcatch', 'background', 'synthesis'
  final TaskStatus status;

  FlowSubTask({
    String? id,
    required this.blockTypeKey,
    required this.blockLabel,
    required this.subTaskId,
    required this.subTaskType,
    this.status = TaskStatus.running,
  }) : id = id ?? const Uuid().v4();

  FlowSubTask copyWithStatus(TaskStatus newStatus) => FlowSubTask(
        id: id,
        blockTypeKey: blockTypeKey,
        blockLabel: blockLabel,
        subTaskId: subTaskId,
        subTaskType: subTaskType,
        status: newStatus,
      );
}

/// Tracks a running/completed task flow execution.
///
/// Contains:
/// - The flow definition reference (flowId)
/// - Overall execution status
/// - List of sub-tasks (one per block), each referencing the real task
@immutable
class TaskFlowExecution {
  final String id;
  final String flowId;
  final String flowName;
  final FlowExecutionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<FlowSubTask> subTasks;
  final String? error;

  TaskFlowExecution({
    String? id,
    required this.flowId,
    required this.flowName,
    this.status = FlowExecutionStatus.running,
    DateTime? createdAt,
    this.completedAt,
    this.subTasks = const [],
    this.error,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  TaskFlowExecution copyWith({
    FlowExecutionStatus? status,
    DateTime? completedAt,
    List<FlowSubTask>? subTasks,
    String? error,
  }) =>
      TaskFlowExecution(
        id: id,
        flowId: flowId,
        flowName: flowName,
        status: status ?? this.status,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
        subTasks: subTasks ?? this.subTasks,
        error: error ?? this.error,
      );

  /// Get the task status of this execution for the unified task list.
  TaskStatus get taskStatus {
    switch (status) {
      case FlowExecutionStatus.running:
        return TaskStatus.running;
      case FlowExecutionStatus.completed:
        return TaskStatus.completed;
      case FlowExecutionStatus.failed:
        return TaskStatus.failed;
    }
  }
}
