import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../providers/task_provider_shared.dart';
import 'flow_launch_snapshot.dart';
import 'flow_payload.dart';
import 'io_type.dart';

class FlowRunInput {
  final String text;
  final int durationSec;
  final String? mimeType;
  final String? fileName;
  /// Picker copy retained while an execution can retry this input.
  final String? ownedStoragePath;
  const FlowRunInput({required this.text, this.durationSec = 0, this.mimeType,
    this.fileName, this.ownedStoragePath});
}

enum FlowExecutionStatus {
  waiting,
  running,
  paused,
  completed,
  failed,
  cancelled,
  interrupted
}

enum FlowStepOutcome {
  pending,
  running,
  paused,
  succeeded,
  failed,
  skipped,
  cancelled,
  interrupted
}

@immutable
class FlowSubTask {
  final String id;
  final String blockTypeKey;
  final String blockLabel;
  final String subTaskId;
  final String subTaskType;
  final TaskStatus status;
  final FlowStepOutcome outcome;
  final FlowPayload? result;
  FlowSubTask(
      {String? id,
      required this.blockTypeKey,
      required this.blockLabel,
      required this.subTaskId,
      required this.subTaskType,
      this.status = TaskStatus.running,
      FlowStepOutcome? outcome,
      this.result})
      : id = id ?? const Uuid().v4(),
        outcome = outcome ?? outcomeFor(status);

  static FlowStepOutcome outcomeFor(TaskStatus status) => switch (status) {
        TaskStatus.running => FlowStepOutcome.running,
        TaskStatus.waiting => FlowStepOutcome.pending,
        TaskStatus.paused => FlowStepOutcome.paused,
        TaskStatus.completed => FlowStepOutcome.succeeded,
        TaskStatus.failed => FlowStepOutcome.failed,
      };
  FlowSubTask copyWithStatus(TaskStatus status) =>
      copyWith(status: status, outcome: outcomeFor(status));
  FlowSubTask copyWith(
          {String? subTaskId,
          TaskStatus? status,
          FlowStepOutcome? outcome,
          FlowPayload? result,
          bool clearResult = false}) =>
      FlowSubTask(
          id: id,
          blockTypeKey: blockTypeKey,
          blockLabel: blockLabel,
          subTaskId: subTaskId ?? this.subTaskId,
          subTaskType: subTaskType,
          status: status ?? this.status,
          outcome: outcome ?? this.outcome,
          result: clearResult ? null : result ?? this.result);
  Map<String, dynamic> toMap() => {
        'id': id,
        'blockTypeKey': blockTypeKey,
        'blockLabel': blockLabel,
        'subTaskId': subTaskId,
        'subTaskType': subTaskType,
        'status': status.name,
        'outcome': outcome.name,
        if (result != null) 'result': result!.toMap()
      };
  factory FlowSubTask.fromMap(Map<String, dynamic> map) => FlowSubTask(
      id: map['id'] as String?,
      blockTypeKey: map['blockTypeKey'] as String? ?? '',
      blockLabel: map['blockLabel'] as String? ?? '',
      subTaskId: map['subTaskId'] as String? ?? '',
      subTaskType: map['subTaskType'] as String? ?? '',
      status:
          TaskStatus.values.where((s) => s.name == map['status']).firstOrNull ??
              TaskStatus.running,
      outcome: FlowStepOutcome.values
          .where((s) => s.name == map['outcome'])
          .firstOrNull,
      result: map['result'] is Map
          ? FlowPayload.fromMap(Map<String, dynamic>.from(map['result'] as Map))
          : null);
}

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
  final String inputText;
  final int inputDurationSec;
  final String? inputMimeType;
  final IOType? inputType;
  final String? inputFileName;
  final String? inputStoragePath;
  final bool queued;
  final String? batchId;
  final int batchIndex;
  final FlowLaunchSnapshot? snapshot;
  bool get isTerminal => [
        FlowExecutionStatus.completed,
        FlowExecutionStatus.failed,
        FlowExecutionStatus.cancelled,
        FlowExecutionStatus.interrupted
      ].contains(status);
  bool get canResume =>
      snapshot != null &&
      [
        FlowExecutionStatus.paused,
        FlowExecutionStatus.failed,
        FlowExecutionStatus.interrupted
      ].contains(status);
  TaskFlowExecution(
      {String? id,
      required this.flowId,
      required this.flowName,
      this.status = FlowExecutionStatus.running,
      DateTime? createdAt,
      this.completedAt,
      List<FlowSubTask> subTasks = const [],
      this.error,
      this.inputText = '',
      this.inputDurationSec = 0,
      this.inputMimeType,
      this.inputType,
      this.inputFileName,
      this.inputStoragePath,
      this.queued = false,
      this.batchId,
      this.batchIndex = 0,
      this.snapshot})
      : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        subTasks = List.unmodifiable(subTasks);
  TaskFlowExecution copyWith(
          {FlowExecutionStatus? status,
          DateTime? completedAt,
          bool clearCompletedAt = false,
          List<FlowSubTask>? subTasks,
          String? error,
          bool clearError = false,
          String? inputText,
          int? inputDurationSec,
          String? inputMimeType,
          IOType? inputType,
          String? inputFileName,
          String? inputStoragePath,
          bool? queued}) =>
      TaskFlowExecution(
          id: id,
          flowId: flowId,
          flowName: flowName,
          status: status ?? this.status,
          createdAt: createdAt,
          completedAt:
              clearCompletedAt ? null : completedAt ?? this.completedAt,
          subTasks: subTasks ?? this.subTasks,
          error: clearError ? null : error ?? this.error,
          inputText: inputText ?? this.inputText,
          inputDurationSec: inputDurationSec ?? this.inputDurationSec,
          inputMimeType: inputMimeType ?? this.inputMimeType,
          inputType: inputType ?? this.inputType,
          inputFileName: inputFileName ?? this.inputFileName,
          inputStoragePath: inputStoragePath ?? this.inputStoragePath,
          queued: queued ?? this.queued,
          batchId: batchId,
          batchIndex: batchIndex,
          snapshot: snapshot);
  TaskStatus get taskStatus => switch (status) {
        FlowExecutionStatus.waiting => TaskStatus.waiting,
        FlowExecutionStatus.running => TaskStatus.running,
        FlowExecutionStatus.paused ||
        FlowExecutionStatus.interrupted ||
        FlowExecutionStatus.cancelled =>
          TaskStatus.paused,
        FlowExecutionStatus.completed => TaskStatus.completed,
        FlowExecutionStatus.failed => TaskStatus.failed,
      };
  Map<String, dynamic> toMap() => {
        'id': id,
        'flowId': flowId,
        'flowName': flowName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        'subTasks': subTasks.map((s) => s.toMap()).toList(),
        if (error != null) 'error': error,
        'inputText': inputText,
        if (inputDurationSec > 0) 'inputDurationSec': inputDurationSec,
        if (inputMimeType != null) 'inputMimeType': inputMimeType,
        if (inputType != null) 'inputType': inputType!.name,
        if (inputFileName != null) 'inputFileName': inputFileName,
        if (inputStoragePath != null) 'inputStoragePath': inputStoragePath,
        if (batchId != null) 'batchId': batchId,
        'batchIndex': batchIndex,
        if (snapshot != null) 'snapshot': snapshot!.toMap()
      };
  factory TaskFlowExecution.fromMap(Map<String, dynamic> map) =>
      TaskFlowExecution(
          id: map['id'] as String?,
          flowId: map['flowId'] as String? ?? '',
          flowName: map['flowName'] as String? ?? '',
          status: FlowExecutionStatus.values
                  .where((s) => s.name == map['status'])
                  .firstOrNull ??
              FlowExecutionStatus.running,
          createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
          completedAt: DateTime.tryParse(map['completedAt'] as String? ?? ''),
          subTasks: (map['subTasks'] as List? ?? [])
              .map((s) =>
                  FlowSubTask.fromMap(Map<String, dynamic>.from(s as Map)))
              .toList(),
          error: map['error'] as String?,
          inputText: map['inputText'] as String? ?? '',
          inputDurationSec: map['inputDurationSec'] as int? ?? 0,
          inputMimeType: map['inputMimeType'] as String?,
      inputType: IOType.values.where((t) => t.name == map['inputType']).firstOrNull,
      inputFileName: map['inputFileName'] as String?,
      inputStoragePath: map['inputStoragePath'] as String?,
          batchId: map['batchId'] as String?,
          batchIndex: map['batchIndex'] as int? ?? 0,
          snapshot: map['snapshot'] is Map
              ? FlowLaunchSnapshot.fromMap(
                  Map<String, dynamic>.from(map['snapshot'] as Map))
              : null);
}
