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

  FlowSubTask copyWith({String? subTaskId}) => FlowSubTask(
        id: id,
        blockTypeKey: blockTypeKey,
        blockLabel: blockLabel,
        subTaskId: subTaskId ?? this.subTaskId,
        subTaskType: subTaskType,
        status: status,
      );

  /// Serialize to a map for JSON persistence.
  Map<String, dynamic> toMap() => {
        'id': id,
        'blockTypeKey': blockTypeKey,
        'blockLabel': blockLabel,
        'subTaskId': subTaskId,
        'subTaskType': subTaskType,
        'status': status.name,
      };

  factory FlowSubTask.fromMap(Map<String, dynamic> map) => FlowSubTask(
        id: map['id'] as String?,
        blockTypeKey: map['blockTypeKey'] as String? ?? '',
        blockLabel: map['blockLabel'] as String? ?? '',
        subTaskId: map['subTaskId'] as String? ?? '',
        subTaskType: map['subTaskType'] as String? ?? '',
        status: _parseStatus(map['status'] as String?),
      );

  static TaskStatus _parseStatus(String? name) {
    if (name == null) return TaskStatus.running;
    return TaskStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => TaskStatus.running,
    );
  }
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

  /// Transient flag: the flow is alive but its current block is waiting
  /// for scheduler resources (concurrent flows). Never persisted — a
  /// restored execution is never queued.
  final bool queued;

  TaskFlowExecution({
    String? id,
    required this.flowId,
    required this.flowName,
    this.status = FlowExecutionStatus.running,
    DateTime? createdAt,
    this.completedAt,
    this.subTasks = const [],
    this.error,
    this.queued = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  TaskFlowExecution copyWith({
    FlowExecutionStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    List<FlowSubTask>? subTasks,
    String? error,
    bool clearError = false,
    bool? queued,
  }) =>
      TaskFlowExecution(
        id: id,
        flowId: flowId,
        flowName: flowName,
        status: status ?? this.status,
        createdAt: createdAt,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
        subTasks: subTasks ?? this.subTasks,
        error: clearError ? null : (error ?? this.error),
        queued: queued ?? this.queued,
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

  /// Serialize to a map for JSON persistence.
  Map<String, dynamic> toMap() => {
        'id': id,
        'flowId': flowId,
        'flowName': flowName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        'subTasks': subTasks.map((s) => s.toMap()).toList(),
        if (error != null) 'error': error,
      };

  factory TaskFlowExecution.fromMap(Map<String, dynamic> map) =>
      TaskFlowExecution(
        id: map['id'] as String?,
        flowId: map['flowId'] as String? ?? '',
        flowName: map['flowName'] as String? ?? '',
        status: _parseExecStatus(map['status'] as String?),
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'] as String)
            : null,
        subTasks: (map['subTasks'] as List<dynamic>?)
                ?.map(
                  (s) =>
                      FlowSubTask.fromMap(Map<String, dynamic>.from(s as Map)),
                )
                .toList() ??
            [],
        error: map['error'] as String?,
      );

  static FlowExecutionStatus _parseExecStatus(String? name) {
    if (name == null) return FlowExecutionStatus.running;
    return FlowExecutionStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => FlowExecutionStatus.running,
    );
  }
}
