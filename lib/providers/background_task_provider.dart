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
}

// ============================================================================
// Background Task Model
// ============================================================================

/// A lightweight task model for OCR, ASR, and Audio Separation operations.
/// These are simple start → complete/fail tasks without complex step tracking.
class BackgroundTask {
  final String id;
  final BackgroundTaskType type;
  final String title;
  final TaskStatus status;
  final int progress; // 0-100
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;

  BackgroundTask({
    required this.id,
    required this.type,
    required this.title,
    this.status = TaskStatus.running,
    this.progress = 0,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    this.statusChangedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  BackgroundTask copyWith({
    TaskStatus? status,
    int? progress,
    String? error,
    DateTime? completedAt,
    DateTime? statusChangedAt,
  }) {
    final newStatus = status ?? this.status;
    final newStatusChangedAt =
        statusChangedAt ??
        (status != null && status != this.status
            ? DateTime.now()
            : this.statusChangedAt);
    return BackgroundTask(
      id: id,
      type: type,
      title: title,
      status: newStatus,
      progress: progress ?? this.progress,
      error: error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      statusChangedAt: newStatusChangedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'status': status.name,
    'progress': progress,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'statusChangedAt': statusChangedAt?.toIso8601String(),
  };

  factory BackgroundTask.fromMap(Map<String, dynamic> map) => BackgroundTask(
    id: map['id'] as String,
    type: BackgroundTaskType.values.byName(map['type'] as String),
    title: map['title'] as String,
    status: TaskStatus.values.byName(map['status'] as String),
    progress: map['progress'] as int? ?? 0,
    error: map['error'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    completedAt: map['completedAt'] != null
        ? DateTime.parse(map['completedAt'] as String)
        : null,
    statusChangedAt: map['statusChangedAt'] != null
        ? DateTime.parse(map['statusChangedAt'] as String)
        : null,
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
  String addTask({required BackgroundTaskType type, required String title}) {
    final id = _uuid.v4();
    final task = BackgroundTask(id: id, type: type, title: title);
    state = [task, ...state];
    _persistTasks();
    return id;
  }

  /// Mark a task as completed and keep it in the list (visible to user).
  void completeTask(String taskId) {
    _updateTask(taskId, TaskStatus.completed, progress: 100);
  }

  /// Mark a task as failed with an optional error message.
  void failTask(String taskId, {String? error}) {
    _updateTask(taskId, TaskStatus.failed, error: error);
  }

  /// Update the progress of a running task.
  void updateProgress(String taskId, int progress) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      if (t.status != TaskStatus.running) return t;
      return t.copyWith(progress: progress.clamp(0, 100));
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
    int? progress,
  }) {
    BackgroundTask? oldTask;
    state = state.map((t) {
      if (t.id != taskId) return t;
      oldTask = t;
      return t.copyWith(
        status: status,
        progress: progress ?? t.progress,
        error: error,
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
