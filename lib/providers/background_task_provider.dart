import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'task_provider.dart';

// ============================================================================
// Background Task Type
// ============================================================================

/// The type of background operation being tracked.
enum BackgroundTaskType {
  ocr,
  asr,
  audioSeparation;

  String get label {
    switch (this) {
      case BackgroundTaskType.ocr:
        return '文字识别';
      case BackgroundTaskType.asr:
        return '音频转写';
      case BackgroundTaskType.audioSeparation:
        return '音频分离';
    }
  }

  /// Steps appropriate for each task type (used for step chain display).
  List<String> get stepLabels {
    switch (this) {
      case BackgroundTaskType.ocr:
        // OCR: single request with all images
        return ['连接服务器', '上传图片', '识别中', '接收结果', '保存文件'];
      case BackgroundTaskType.asr:
        // ASR: one request per file
        return ['处理音频文件中...'];
      case BackgroundTaskType.audioSeparation:
        // Audio Separation: local processing only, no API
        return ['正在分离音频...'];
    }
  }
}

// ============================================================================
// Step Status for Background Tasks
// ============================================================================

/// Simplified step status enum (without progress quantification).
enum BgStepStatus { pending, running, completed, failed, skipped }

/// A single step in a background task's step chain.
/// No progress bar — just shows status: pending, running, completed, failed, or skipped.
class BgTaskStep {
  final String label;
  final BgStepStatus status;
  final String? error;

  const BgTaskStep({
    required this.label,
    this.status = BgStepStatus.pending,
    this.error,
  });

  bool get completed => status == BgStepStatus.completed;
  bool get running => status == BgStepStatus.running;
  bool get failed => status == BgStepStatus.failed;
  bool get skipped => status == BgStepStatus.skipped;

  BgTaskStep copyWith({
    BgStepStatus? status,
    String? error,
    bool clearError = false,
  }) =>
      BgTaskStep(
        label: label,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'status': status.name,
        if (error != null) 'error': error,
      };

  factory BgTaskStep.fromMap(Map<String, dynamic> map) => BgTaskStep(
        label: map['label'] as String,
        status:
            BgStepStatus.values.byName(map['status'] as String? ?? 'pending'),
        error: map['error'] as String?,
      );
}

// ============================================================================
// Background Task Model
// ============================================================================

/// A task model for OCR, ASR, and Audio Separation operations.
/// Uses a step chain (like CatCatch downloads) to show execution progress
/// without quantifying with percentages. Steps are task-type-specific.
class BackgroundTask {
  final String id;
  final BackgroundTaskType type;
  final String title;
  final TaskStatus status;
  final String?
      result; // The text result (OCR extracted text, ASR transcription) — kept internally for saving
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;
  final List<BgTaskStep> steps; // Step chain for UI display
  final String?
      downloadedFilePath; // File path for "open file" button (like CatCatch)
  final Map<String, dynamic>?
      rawRequest; // Raw request data for error diagnostics
  final Map<String, dynamic>?
      rawResponse; // Raw response data for error diagnostics

  BackgroundTask({
    required this.id,
    required this.type,
    required this.title,
    this.status = TaskStatus.running,
    this.result,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    this.statusChangedAt,
    this.steps = const [],
    this.downloadedFilePath,
    this.rawRequest,
    this.rawResponse,
  }) : createdAt = createdAt ?? DateTime.now();

  BackgroundTask copyWith({
    TaskStatus? status,
    String? result,
    String? error,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    List<BgTaskStep>? steps,
    String? downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    bool clearError = false,
    bool clearDownloadedFilePath = false,
    bool clearRawRequest = false,
    bool clearRawResponse = false,
  }) {
    final newStatus = status ?? this.status;
    final newStatusChangedAt = statusChangedAt ??
        (status != null && status != this.status
            ? DateTime.now()
            : this.statusChangedAt);
    return BackgroundTask(
      id: id,
      type: type,
      title: title,
      status: newStatus,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      statusChangedAt: newStatusChangedAt,
      steps: steps ?? this.steps,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      rawRequest: clearRawRequest ? null : (rawRequest ?? this.rawRequest),
      rawResponse: clearRawResponse ? null : (rawResponse ?? this.rawResponse),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'status': status.name,
        if (result != null) 'result': result,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'steps': steps.map((s) => s.toMap()).toList(),
        if (downloadedFilePath != null)
          'downloadedFilePath': downloadedFilePath,
        if (rawRequest != null) 'rawRequest': rawRequest,
        if (rawResponse != null) 'rawResponse': rawResponse,
      };

  factory BackgroundTask.fromMap(Map<String, dynamic> map) => BackgroundTask(
        id: map['id'] as String,
        type: BackgroundTaskType.values.byName(map['type'] as String),
        title: map['title'] as String,
        status: TaskStatus.values.byName(map['status'] as String),
        result: map['result'] as String?,
        error: map['error'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'] as String)
            : null,
        statusChangedAt: map['statusChangedAt'] != null
            ? DateTime.parse(map['statusChangedAt'] as String)
            : null,
        steps: (map['steps'] as List?)
                ?.map((s) =>
                    BgTaskStep.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [],
        downloadedFilePath: map['downloadedFilePath'] as String?,
        rawRequest: map['rawRequest'] as Map<String, dynamic>?,
        rawResponse: map['rawResponse'] as Map<String, dynamic>?,
      );
}

// ============================================================================
// Provider
// ============================================================================

final backgroundTasksProvider =
    StateNotifierProvider<BackgroundTaskNotifier, List<BackgroundTask>>(
  (ref) => BackgroundTaskNotifier(),
);

class BackgroundTaskNotifier extends StateNotifier<List<BackgroundTask>> {
  final _uuid = const Uuid();

  BackgroundTaskNotifier() : super([]);

  /// Add a new background task (running) and return its ID.
  /// Initializes default step chain based on task type.
  String addTask({required BackgroundTaskType type, required String title}) {
    final id = _uuid.v4();
    final steps = type.stepLabels
        .map((label) => BgTaskStep(label: label, status: BgStepStatus.pending))
        .toList();
    final task = BackgroundTask(id: id, type: type, title: title, steps: steps);
    state = [task, ...state];
    _persistTasks();
    return id;
  }

  /// Mark a task as completed and keep it in the list (visible to user).
  /// Optionally provide [downloadedFilePath] for the "open file" button.
  void completeTask(String taskId, {String? downloadedFilePath}) {
    _updateTask(
      taskId,
      TaskStatus.completed,
      downloadedFilePath: downloadedFilePath,
    );
  }

  /// Mark a task as failed with an optional error message.
  void failTask(String taskId,
      {String? error,
      Map<String, dynamic>? rawRequest,
      Map<String, dynamic>? rawResponse}) {
    _updateTask(taskId, TaskStatus.failed,
        error: error, rawRequest: rawRequest, rawResponse: rawResponse);
  }

  /// Set the result text for a task (OCR extracted text, ASR transcription, etc.).
  /// Can be called multiple times to update partial/intermediate results.
  /// The result is kept internally for file saving but NOT displayed in the card UI.
  void setResult(String taskId, String result) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(result: result, error: t.error);
    }).toList();
    _persistTasks();
  }

  /// Set the full step chain for a task.
  void setSteps(String taskId, List<BgTaskStep> steps) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(steps: steps);
    }).toList();
    _persistTasks();
  }

  /// Set raw request/response diagnostic data for error viewing.
  void setRawDiagnostics(
    String taskId, {
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        rawRequest: rawRequest,
        rawResponse: rawResponse,
      );
    }).toList();
    _persistTasks();
  }

  /// Update a single step by index (e.g. mark as completed/running/failed).
  void updateStep(
    String taskId,
    int index, {
    bool? completed,
    bool? running,
    bool? failed,
    bool? skipped,
    String? error,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      final steps = [...t.steps];
      if (index < 0 || index >= steps.length) return t;
      BgStepStatus newStatus;
      if (completed == true) {
        newStatus = BgStepStatus.completed;
      } else if (running == true) {
        newStatus = BgStepStatus.running;
      } else if (failed == true) {
        newStatus = BgStepStatus.failed;
      } else if (skipped == true) {
        newStatus = BgStepStatus.skipped;
      } else {
        return t; // no change
      }
      steps[index] = steps[index].copyWith(status: newStatus, error: error);
      return t.copyWith(steps: steps);
    }).toList();
    _persistTasks();
  }

  /// Remove a task from the list.
  void removeTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
    _persistTasks();
  }

  void _updateTask(
    String taskId,
    TaskStatus status, {
    String? error,
    String? downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    BackgroundTask? oldTask;
    state = state.map((t) {
      if (t.id != taskId) return t;
      oldTask = t;
      final shouldClearError = error == null && status == TaskStatus.completed;
      return t.copyWith(
        status: status,
        error: error,
        clearError: shouldClearError,
        downloadedFilePath: downloadedFilePath,
        rawRequest: rawRequest,
        rawResponse: rawResponse,
        completedAt:
            status == TaskStatus.completed || status == TaskStatus.failed
                ? DateTime.now()
                : null,
      );
    }).toList();
    _persistTasks();

    // Send notification when task completes or fails
    if ((status == TaskStatus.completed || status == TaskStatus.failed) &&
        oldTask != null) {
      _sendTaskNotification(oldTask!, status, error);
    }
  }

  void _sendTaskNotification(
    BackgroundTask task,
    TaskStatus status,
    String? error,
  ) {
    // Fire-and-forget: notifications should never crash the task state update
    try {
      final future = NotificationService().showTaskCompletionNotification(
        taskId: task.id,
        title: task.title,
        typeLabel: task.type.label,
        success: status == TaskStatus.completed,
        error: error,
      );
      // Handle async errors silently
      unawaited(future.catchError((_) {}));
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to send notification: $e');
    }
  }

  // ============================================================================
  // Persistence
  // ============================================================================

  Future<void> _persistTasks() async {
    try {
      final file = await _tasksFile();
      final data = state.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to persist tasks: $e');
    }
  }

  Future<List<BackgroundTask>> _loadPersistedTasks() async {
    try {
      final file = await _tasksFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list
          .map(
            (m) => BackgroundTask.fromMap(Map<String, dynamic>.from(m as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to load persisted tasks: $e');
      return [];
    }
  }

  Future<File> _tasksFile() async {
    final dirPath = await AppStorage.directory;
    final bgDir = Directory(p.join(dirPath, 'background'));
    try {
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }
    } catch (_) {}
    return File(p.join(bgDir.path, 'tasks.json'));
  }

  /// Restore persisted tasks on startup.
  /// Running tasks are marked as failed since they can't be resumed.
  Future<void> restoreFromPersistence() async {
    final tasks = await _loadPersistedTasks();
    if (tasks.isEmpty) return;
    final restored = [
      for (final task in tasks)
        if (task.status == TaskStatus.running)
          task.copyWith(status: TaskStatus.failed, error: '应用重启，已中断')
        else
          task,
    ];
    // Merge with existing state (in case tasks were added before restore completes)
    state = [
      for (final t in restored)
        if (!state.any((s) => s.id == t.id)) t,
      ...state,
    ];
    debugPrint(
      '[BackgroundTaskNotifier] Restored ${tasks.length} tasks from persistence',
    );
  }
}
