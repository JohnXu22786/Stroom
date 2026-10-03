import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/legacy.dart';

import '../../providers/task_provider_shared.dart';
import '../../services/attachment_storage.dart';
import '../models/task_flow_execution.dart';
import '../models/flow_payload.dart';
import '../models/io_type.dart';
import 'persistable_notifier.dart';

/// Provider for tracking task flow executions (for the unified task list).
final taskFlowExecutionsProvider =
    StateNotifierProvider<TaskFlowExecutionNotifier, List<TaskFlowExecution>>(
  (ref) => TaskFlowExecutionNotifier(),
);

/// Startup sets this to restoring before loading any task lists. Directly
/// constructed pages default to ready; they have no startup restore window.
enum FlowExecutionRestoreStatus { ready, restoring, failed }

final taskFlowExecutionRestoreStatusProvider =
    StateProvider<FlowExecutionRestoreStatus>(
        (ref) => FlowExecutionRestoreStatus.ready);

class TaskFlowExecutionNotifier extends StateNotifier<List<TaskFlowExecution>>
    with PersistableNotifier<List<TaskFlowExecution>> {
  TaskFlowExecutionNotifier() : super([]);

  Future<void> _registrationQueue = Future<void>.value();
  final Object _registrationWriteZone = Object();
  Completer<void>? _registrationBarrier;
  List<TaskFlowExecution>? _disposedSnapshot;
  Future<bool>? _disposedPersistence;

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
        if (item is! Map ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['subTasks'] is! List ||
            (item['subTasks'] as List).any((subTask) =>
                subTask is! Map ||
                subTask['subTaskId'] is! String ||
                (subTask['subTaskId'] as String).isEmpty)) {
          throw const FormatException('Invalid task flow ownership record');
        }
        result.add(
          TaskFlowExecution.fromMap(Map<String, dynamic>.from(item)),
        );
      } catch (e) {
        debugPrint('WARNING: Corrupt TaskFlowExecution: $e');
        rethrow;
      }
    }
    return result;
  }

  @override
  List<dynamic> toJsonList(List<TaskFlowExecution> state) {
    return state.map((e) => e.toMap()).toList();
  }

  final Map<String, TaskFlowExecution> _pendingInputRemovals = {};
  final Map<String, int> _pendingInputRegistrations = {};
  Future<void> _inputRemovalQueue = Future<void>.value();
  final Map<String, Future<void>> _inputPathLocks = {};
  final Set<String> _deletingInputPaths = {};

  /// Keep validation and durable registration of a picker copy together with
  /// the last-reference check and deletion of that same copy.
  Future<T> withInputStoragePathLock<T>(
    String? path,
    Future<T> Function() action,
  ) async {
    if (path == null || path.isEmpty) return action();
    final previous = _inputPathLocks[path];
    final released = Completer<void>();
    _inputPathLocks[path] = released.future;
    if (previous != null) await previous;
    try {
      return await action();
    } finally {
      if (identical(_inputPathLocks[path], released.future)) {
        _inputPathLocks.remove(path);
      }
      released.complete();
    }
  }

  /// Batches reserve shared picker copies in sorted order to avoid deadlocks.
  Future<T> withInputStoragePathsLock<T>(
      Iterable<String?> paths, Future<T> Function() action) {
    final ordered = paths.whereType<String>()
        .where((path) => path.isNotEmpty).toSet().toList()..sort();
    Future<T> acquire(int index) => index == ordered.length
        ? action()
        : withInputStoragePathLock(ordered[index], () => acquire(index + 1));
    return acquire(0);
  }

  bool referencesInputStoragePath(String path) => mounted &&
      (state.any((entry) => entry.inputStoragePath == path) ||
          (_pendingInputRegistrations[path] ?? 0) > 0 ||
          _pendingInputRemovals.values
              .any((entry) => entry.inputStoragePath == path));

  /// Release copies only after their owning records were durably removed.
  /// Bulk history cleanup uses the same locks and last-reference checks.
  Future<void> cleanupInputStoragePaths(Iterable<String?> paths) async {
    final uniquePaths = paths.whereType<String>()
        .where((path) => path.isNotEmpty).toSet();
    for (final path in uniquePaths) {
      if (!mounted || referencesInputStoragePath(path)) continue;
      await withInputStoragePathLock(path, () async {
        if (!mounted || referencesInputStoragePath(path)) return;
        _deletingInputPaths.add(path);
        try {
          await AttachmentStorage.deleteFile(path);
        } catch (error) {
          debugPrint('Failed to clean up flow input $path: $error');
        } finally {
          _deletingInputPaths.remove(path);
        }
      });
    }
  }

  Timer? _persistTimer;

  List<TaskFlowExecution> get executions => state;

  TaskFlowExecution? execution(String id) =>
      state.where((e) => e.id == id).firstOrNull;

  /// One atomic submission snapshot contains every input and placeholder.
  Future<bool> addExecutions(List<TaskFlowExecution> executions) {
    if (executions.any((entry) =>
        _deletingInputPaths.contains(entry.inputStoragePath))) {
      throw StateError('输入文件正在删除，请重新选择文件');
    }
    final submitted = List<TaskFlowExecution>.of(executions);
    // Queue publication can wait behind another durable registration. Reserve
    // picker copies now so removal cleanup sees these future owners as well.
    final reservedPaths = submitted.map((entry) => entry.inputStoragePath)
        .whereType<String>().where((path) => path.isNotEmpty).toSet();
    for (final path in reservedPaths) {
      _pendingInputRegistrations.update(path, (count) => count + 1,
          ifAbsent: () => 1);
    }
    final operation = _registrationQueue.then((_) async {
      try {
        if (!mounted) return false;
        final barrier = Completer<void>();
        _registrationBarrier = barrier;
        var saved = false;
        try {
          state = [...submitted.reversed, ...state];
          saved = await runZoned<Future<bool>>(
            persist,
            zoneValues: {_registrationWriteZone: true},
          );
          return saved;
        } finally {
          if (!saved) {
            final ids = submitted.map((entry) => entry.id).toSet();
            if (mounted) {
              state = state.where((entry) => !ids.contains(entry.id)).toList();
            } else {
              // The disposal snapshot owns media references as well as
              // progress. Rejected submissions cannot enter its final flush.
              _disposedSnapshot = _disposedSnapshot
                  ?.where((entry) => !ids.contains(entry.id))
                  .toList();
            }
          }
          _registrationBarrier = null;
          barrier.complete();
        }
      } finally {
        for (final path in reservedPaths) {
          final count = _pendingInputRegistrations[path]!;
          if (count == 1) {
            _pendingInputRegistrations.remove(path);
          } else {
            _pendingInputRegistrations[path] = count - 1;
          }
        }
      }
    });
    _registrationQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  String addExecution(
      {required String flowId,
      required String flowName,
      List<FlowSubTask> subTasks = const [],
      String inputText = '',
      int inputDurationSec = 0,
      String? inputMimeType,
      IOType? inputType,
      String? inputFileName,
      String? inputStoragePath}) {
    if (_deletingInputPaths.contains(inputStoragePath)) {
      throw StateError('输入文件正在删除，请重新选择文件');
    }
    final entry = TaskFlowExecution(
        flowId: flowId,
        flowName: flowName,
        subTasks: subTasks,
        inputText: inputText,
        inputDurationSec: inputDurationSec,
        inputMimeType: inputMimeType,
        inputType: inputType,
        inputFileName: inputFileName,
        inputStoragePath: inputStoragePath);
    state = [entry, ...state];
    unawaited(persist());
    return entry.id;
  }

  void _update(
      String id, TaskFlowExecution Function(TaskFlowExecution) update) {
    if (!mounted) {
      return;
    }
    var changed = false;
    final next = state.map((e) {
      if (e.id != id) {
        return e;
      }
      final value = update(e);
      changed = changed || !identical(value, e);
      return value;
    }).toList();
    if (!changed) {
      return;
    }
    state = next;
    _debouncedPersist();
  }

  void addSubTask(String executionId, FlowSubTask subTask) => _update(
      executionId,
      (e) => e.isTerminal ? e : e.copyWith(subTasks: [...e.subTasks, subTask]));

  void updateSubTaskId(
          String executionId, String subTaskId, String newSubTaskId) =>
      _update(
          executionId,
          (e) => e.isTerminal
              ? e
              : e.copyWith(
                  subTasks: e.subTasks
                      .map((st) => st.id == subTaskId
                          ? st.copyWith(subTaskId: newSubTaskId)
                          : st)
                      .toList()));

  /// Child callbacks cannot reopen a terminal execution. The service owns the
  /// final lifecycle; a completed child is not a durable checkpoint yet.
  void updateSubTaskStatus(
      String executionId, String subTaskId, TaskStatus status) {
    _update(executionId, (e) {
      if (e.isTerminal) {
        return e;
      }
      final current = e.subTasks.where((st) => st.id == subTaskId).firstOrNull;
      if (current == null ||
          (current.status == status &&
              current.outcome == FlowSubTask.outcomeFor(status) &&
              (status != TaskStatus.paused ||
                  e.status == FlowExecutionStatus.paused))) {
        return e;
      }
      final steps = e.subTasks
          .map((st) => st.id == subTaskId ? st.copyWithStatus(status) : st)
          .toList();
      if (status == TaskStatus.paused) {
        return e.copyWith(status: FlowExecutionStatus.paused, subTasks: steps);
      }
      return e.copyWith(subTasks: steps);
    });
  }

  void setExecutionStatus(String id, FlowExecutionStatus status,
          {String? error}) =>
      _update(
          id,
          (e) => e.copyWith(
              status: status,
              error: error,
              clearError: error == null,
              queued: false,
              clearCompletedAt: ![
                FlowExecutionStatus.completed,
                FlowExecutionStatus.failed,
                FlowExecutionStatus.cancelled,
                FlowExecutionStatus.interrupted
              ].contains(status),
              completedAt: [
                FlowExecutionStatus.completed,
                FlowExecutionStatus.failed,
                FlowExecutionStatus.cancelled,
                FlowExecutionStatus.interrupted
              ].contains(status)
                  ? DateTime.now()
                  : null));

  /// Save the output before the dispatcher is allowed to start the next step.
  Future<bool> saveStepResult(String id, String stepId, FlowPayload result) {
    _update(
        id,
        (e) => e.isTerminal
            ? e
            : e.copyWith(
                subTasks: e.subTasks
                    .map((st) => st.id == stepId
                        ? st.copyWith(
                            status: TaskStatus.completed,
                            outcome: FlowStepOutcome.succeeded,
                            result: result)
                        : st)
                    .toList()));
    return persist();
  }

  void prepareResume(String id) => _update(id, (e) {
        var prefix = true;
        final steps = e.subTasks.map((st) {
          if (prefix &&
              st.outcome == FlowStepOutcome.succeeded &&
              st.result != null) {
            return st;
          }
          prefix = false;
          return st.copyWith(
              subTaskId: 'pending_${st.blockTypeKey}_${st.id}',
              status: TaskStatus.waiting,
              outcome: FlowStepOutcome.pending,
              clearResult: true);
        }).toList();
        return e.copyWith(
            status: FlowExecutionStatus.waiting,
            clearError: true,
            clearCompletedAt: true,
            subTasks: steps);
      });

  void completeExecution(String id) => _update(id, (e) {
        if (e.isTerminal || e.status == FlowExecutionStatus.paused) {
          return e;
        }
        if (e.subTasks.any((st) => st.outcome == FlowStepOutcome.failed)) {
          return e.copyWith(
              status: FlowExecutionStatus.failed,
              completedAt: DateTime.now(),
              subTasks: e.subTasks
                  .map((st) => st.outcome == FlowStepOutcome.succeeded ||
                          st.outcome == FlowStepOutcome.failed
                      ? st
                      : st.copyWith(
                          status: TaskStatus.paused,
                          outcome: st.outcome == FlowStepOutcome.pending
                              ? FlowStepOutcome.skipped
                              : FlowStepOutcome.interrupted))
                  .toList());
        }
        if (e.subTasks.any((st) => st.outcome != FlowStepOutcome.succeeded)) {
          return e;
        }
        return e.copyWith(
            status: FlowExecutionStatus.completed, completedAt: DateTime.now());
      });

  void failExecution(String id, {String? error}) =>
      _finish(id, FlowExecutionStatus.failed, FlowStepOutcome.interrupted,
          error: error);
  void interruptExecution(String id, {String? error}) =>
      _finish(id, FlowExecutionStatus.interrupted, FlowStepOutcome.interrupted,
          error: error);
  void cancelExecution(String id) =>
      _finish(id, FlowExecutionStatus.cancelled, FlowStepOutcome.cancelled);

  void _finish(
          String id, FlowExecutionStatus status, FlowStepOutcome activeOutcome,
          {String? error}) =>
      _update(id, (e) {
        if (e.isTerminal) {
          return e.status == status && e.error == null && error != null
              ? e.copyWith(error: error)
              : e;
        }
        return e.copyWith(
            status: status,
            completedAt: DateTime.now(),
            error: error,
            queued: false,
            subTasks: e.subTasks.map((st) {
              if (st.outcome == FlowStepOutcome.succeeded ||
                  st.outcome == FlowStepOutcome.failed) {
                return st;
              }
              return st.copyWith(
                  status: TaskStatus.paused,
                  outcome: st.outcome == FlowStepOutcome.pending
                      ? (status == FlowExecutionStatus.cancelled
                          ? FlowStepOutcome.cancelled
                          : FlowStepOutcome.skipped)
                      : activeOutcome);
            }).toList());
      });

  /// Removing waiting records itself prevents dispatch, even without a UI
  /// cleanup callback. The service observes removals to cancel active work.
  Future<void> removeExecution(String id) {
    if (!mounted) {
      return Future<void>.value();
    }
    final removed = execution(id);
    if (removed == null) return Future<void>.value();
    state = state.where((e) => e.id != id).map((e) {
      if (removed.batchId == null ||
          e.batchId != removed.batchId ||
          e.isTerminal) {
        return e;
      }
      return e.copyWith(
          status: FlowExecutionStatus.cancelled,
          queued: false,
          completedAt: DateTime.now(),
          subTasks: e.subTasks
              .map((st) => st.outcome == FlowStepOutcome.succeeded ||
                      st.outcome == FlowStepOutcome.failed
                  ? st
                  : st.copyWith(
                      status: TaskStatus.paused,
                      outcome: FlowStepOutcome.cancelled))
              .toList());
    }).toList();
    _pendingInputRemovals[id] = removed;
    // Delete the copy only after the record removal has reached disk.
    final write = persist();
    final operation = _inputRemovalQueue.then((_) async {
      final saved = await write;
      if (!saved) {
        if (mounted) {
          state = [removed.copyWith(
              status: FlowExecutionStatus.interrupted,
              queued: false,
              completedAt: DateTime.now(),
              error: '删除记录未能保存，请重试',
              subTasks: removed.subTasks.map((step) =>
                  step.outcome == FlowStepOutcome.succeeded || step.outcome == FlowStepOutcome.failed
                    ? step
                    : step.copyWith(status: TaskStatus.paused, outcome: FlowStepOutcome.interrupted)).toList()), ...state];
          await persist();
        }
        _pendingInputRemovals.remove(id);
        return;
      }
      _pendingInputRemovals.remove(id);
      await cleanupInputStoragePaths([removed.inputStoragePath]);
    });
    _inputRemovalQueue = operation.catchError((Object error, StackTrace stack) {
      debugPrint('Failed to clean up removed flow input: $error');
    });
    return operation;
  }

  void setExecutionQueued(String id, bool queued) => _update(
      id,
      (e) => e.isTerminal ||
              e.status == FlowExecutionStatus.paused ||
              e.queued == queued
          ? e
          : e.copyWith(queued: queued));

  void _debouncedPersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 200), persist);
  }

  @override
  Future<bool> persist() {
    _persistTimer?.cancel();
    _persistTimer = null;
    final barrier = _registrationBarrier;
    if (barrier != null && Zone.current[_registrationWriteZone] != true) {
      return barrier.future.then((_) => persist());
    }
    if (!mounted) {
      final snapshot = _disposedSnapshot;
      if (snapshot == null) return Future.value(false);
      // A registration override may reach this point in its own write zone.
      // Deduplicate only the final flush after that registration settles.
      if (barrier != null) return super.persistSnapshot(snapshot);
      return _disposedPersistence ??= super.persistSnapshot(snapshot);
    }
    return super.persist();
  }

  Future<bool> restoreFromPersistence() async {
    if (!await restore()) return false;
    state = state.map((e) {
      if (e.status != FlowExecutionStatus.running) {
        return e;
      }
      return e.copyWith(
          status: FlowExecutionStatus.interrupted,
          completedAt: DateTime.now(),
          error: '应用退出时执行中断，可从已保存的步骤继续',
          subTasks: e.subTasks
              .map((st) => switch (st.outcome) {
                    FlowStepOutcome.running ||
                    FlowStepOutcome.paused =>
                      st.copyWith(
                          status: TaskStatus.paused,
                          outcome: FlowStepOutcome.interrupted),
                    FlowStepOutcome.pending => st.copyWith(
                        status: TaskStatus.paused,
                        outcome: FlowStepOutcome.skipped),
                    _ => st,
                  })
              .toList());
    }).toList();
    await persist();
    return true;
  }

  @override
  void dispose() {
    _disposedSnapshot = List<TaskFlowExecution>.of(state);
    if (_persistTimer != null || _registrationBarrier != null) {
      unawaited(persist());
    }
    super.dispose();
  }
}
