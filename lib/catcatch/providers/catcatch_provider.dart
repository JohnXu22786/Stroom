import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart' show CancelToken;
import '../models/catcatch_task.dart';
import '../models/media_resource.dart';
import '../engine/task_executor.dart';

// =============================================================================
// Provider 定义
// =============================================================================

/// 猫抓任务列表 Provider
///
/// 管理所有下载任务的生命周期：创建、执行、暂停、重试、删除。
final catcatchTasksProvider =
    StateNotifierProvider<CatCatchNotifier, List<CatCatchTask>>((ref) {
  return CatCatchNotifier(ref);
});

// =============================================================================
// StateNotifier
// =============================================================================

/// 猫抓任务状态管理器
///
/// 负责：
/// - 添加新任务并启动执行
/// - 暂停/继续/重试任务
/// - 用户选择媒体资源
/// - 任务持久化（启动恢复、退出保存）
class CatCatchNotifier extends StateNotifier<List<CatCatchTask>> {
  final Ref ref;

  /// 当前运行中的取消令牌映射（taskId → CancelToken）
  final Map<String, CancelToken> _cancelTokens = {};

  CatCatchNotifier(this.ref) : super([]);

  // ===========================================================================
  // 公开方法
  // ===========================================================================

  /// 添加新任务并开始执行
  ///
  /// [url] 用户输入的 URL
  /// [expectedDurationSec] 用户期望的时长（秒）
  ///
  /// 返回新任务 ID。
  String addTask(String url, int expectedDurationSec) {
    final id = const Uuid().v4();
    final task = CatCatchTask(
      id: id,
      url: url,
      expectedDurationSec: expectedDurationSec,
      title: _inferTitle(url),
      createdAt: DateTime.now(),
    );
    state = [...state, task];

    // 异步开始执行
    _executeTask(task);

    return id;
  }

  /// 暂停任务
  void pauseTask(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return;

    // 取消当前操作
    final cancelToken = _cancelTokens.remove(id);
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(status: TaskStatus.paused, error: '已暂停')
        else
          state[i],
    ];
  }

  /// 继续任务（从暂停状态恢复）
  void resumeTask(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return;
    if (state[index].status != TaskStatus.paused) return;

    final task = state[index];
    // 如果卡在 userSelecting 步骤，让 _executeSteps 自然处理

    // 找到第一个未完成的步骤
    StepType? firstIncomplete;
    int firstIncompleteIndex = -1;
    for (int i = 0; i < task.steps.length; i++) {
      if (!task.steps[i].completed) {
        firstIncomplete = task.steps[i].type;
        firstIncompleteIndex = i;
        break;
      }
    }

    // 重置该步骤及之后为 pending
    final newSteps = List<StepStatus>.from(task.steps);
    if (firstIncompleteIndex >= 0) {
      for (int i = firstIncompleteIndex; i < newSteps.length; i++) {
        newSteps[i] = StepStatus.pending(newSteps[i].type);
      }
    }

    final updated = task.copyWith(
      status: TaskStatus.running,
      steps: newSteps,
      clearError: true,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];

    if (firstIncomplete != null) {
      _executeTaskFrom(updated, firstIncomplete);
    } else {
      // 所有步骤都已完成的极端情况，从头执行
      _executeTask(updated);
    }
  }

  /// 重试失败的任务（从头开始）
  void retryTask(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return;
    if (state[index].status != TaskStatus.failed) return;

    final task = state[index].copyWith(
      status: TaskStatus.running,
      progress: 0,
      clearError: true,
      clearCompletedAt: true,
      clearDownloadedFilePath: true,
      steps: StepType.values.map((t) => StepStatus.pending(t)).toList(),
      selectedMedia: null,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) task else state[i],
    ];

    _executeTask(task);
  }

  /// 从指定步骤重试
  void retryStep(String taskId, StepType stepType) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final task = state[index];
    if (task.status != TaskStatus.failed && task.status != TaskStatus.paused) {
      return;
    }

    // 清除步骤信息
    final stepIndex = StepType.values.indexOf(stepType);
    final newSteps = List<StepStatus>.from(task.steps);
    for (int i = stepIndex; i < newSteps.length; i++) {
      newSteps[i] = StepStatus.pending(newSteps[i].type);
    }

    // 如果重试的步骤在 downloading 之前，需要清除 selectedMedia 让用户重新选择
    final clearSelection = StepType.values.indexOf(stepType) <
        StepType.values.indexOf(StepType.downloading);

    final updatedTask = task.copyWith(
      status: TaskStatus.running,
      steps: newSteps,
      clearError: true,
      clearSelectedMedia: clearSelection,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updatedTask else state[i],
    ];

    _executeTaskFrom(updatedTask, stepType);
  }

  /// 删除任务
  void removeTask(String id) {
    // 如果任务正在运行，取消
    final cancelToken = _cancelTokens.remove(id);
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }

    state = state.where((t) => t.id != id).toList();
  }

  /// 用户选择媒体资源（在 userSelecting 步骤后调用）
  void selectMedia(String taskId, MediaResource media) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    // 标记 userSelecting 步骤为已完成
    final steps = state[index].steps.map((s) {
      if (s.type == StepType.userSelecting) {
        return StepStatus.done(StepType.userSelecting);
      }
      return s;
    }).toList();

    final task = state[index].copyWith(
      selectedMedia: media,
      status: TaskStatus.running,
      steps: steps,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) task else state[i],
    ];

    // 从 downloading 步骤继续
    _executeTaskFrom(task, StepType.downloading);
  }

  /// 恢复未完成的任务（应用启动时调用）
  Future<void> restoreUnfinishedTasks() async {
    try {
      final tasks = await _loadPersistedTasks();
      if (tasks.isEmpty) return;

      // 只恢复 running 和 paused 状态的任务
      final unfinished = tasks.where((t) =>
          t.status == TaskStatus.running || t.status == TaskStatus.paused);
      if (unfinished.isEmpty) return;

      // 将所有任务标记为 paused（避免自动继续执行）
      state = [
        ...state,
        for (final task in unfinished)
          task.copyWith(status: TaskStatus.paused, error: '应用重启，已暂停'),
      ];

      debugPrint(
        '[CatCatchNotifier] Restored ${unfinished.length} unfinished tasks',
      );
    } catch (e) {
      debugPrint('[CatCatchNotifier] Failed to restore tasks: $e');
    }
  }

  /// 标记所有运行中的任务为失败（应用退出时）
  void failAllRunningTasks({required String error}) {
    state = [
      for (final task in state)
        if (task.status == TaskStatus.running ||
            task.status == TaskStatus.paused)
          task.copyWith(
            status: TaskStatus.failed,
            error: error,
            steps: task.steps.map((s) {
              if (s.running) return s.copyWith(failed: true, running: false);
              return s;
            }).toList(),
          )
        else
          task,
    ];

    // 取消所有运行中的操作
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel();
    }
    _cancelTokens.clear();

    // 持久化最终状态
    _persistTasks();
  }

  // ===========================================================================
  // 内部执行方法
  // ===========================================================================

  /// 执行任务
  Future<void> _executeTask(CatCatchTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      final result = await TaskExecutor.executeTask(
        task: task,
        onUpdate: (updated) {
          final index = state.indexWhere((t) => t.id == updated.id);
          if (index >= 0) {
            final currentStatus = state[index].status;
            // 如果外部已将任务暂停，保留暂停状态，不覆盖
            if (currentStatus == TaskStatus.paused &&
                updated.status == TaskStatus.running) {
              state = [
                for (int i = 0; i < state.length; i++)
                  if (i == index)
                    updated.copyWith(status: TaskStatus.paused)
                  else
                    state[i],
              ];
            } else {
              state = [
                for (int i = 0; i < state.length; i++)
                  if (i == index) updated else state[i],
              ];
            }
          }
          _persistTasks();
        },
        cancelToken: cancelToken,
      );

      if (result != null) {
        debugPrint('[CatCatchNotifier] Task completed: ${task.id} → $result');
      } else {
        // 返回 null 时可能是等待用户选择
        debugPrint(
            '[CatCatchNotifier] Task waiting for user selection: ${task.id}');
      }
    } catch (e) {
      debugPrint('[CatCatchNotifier] Task execution error: $e');
      // 更新为失败状态
      final index = state.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == index)
              state[i].copyWith(
                status: TaskStatus.failed,
                error: e.toString(),
              )
            else
              state[i],
        ];
        _persistTasks();
      }
    } finally {
      if (_cancelTokens[task.id] == cancelToken) {
        _cancelTokens.remove(task.id);
      }
    }
  }

  /// 从指定步骤执行
  Future<void> _executeTaskFrom(CatCatchTask task, StepType fromStep) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      final result = await TaskExecutor.retryFromStep(
        task: task,
        fromStep: fromStep,
        onUpdate: (updated) {
          final index = state.indexWhere((t) => t.id == updated.id);
          if (index >= 0) {
            final currentStatus = state[index].status;
            // 如果外部已将任务暂停，保留暂停状态，不覆盖
            if (currentStatus == TaskStatus.paused &&
                updated.status == TaskStatus.running) {
              state = [
                for (int i = 0; i < state.length; i++)
                  if (i == index)
                    updated.copyWith(status: TaskStatus.paused)
                  else
                    state[i],
              ];
            } else {
              state = [
                for (int i = 0; i < state.length; i++)
                  if (i == index) updated else state[i],
              ];
            }
          }
          _persistTasks();
        },
        cancelToken: cancelToken,
      );

      if (result != null) {
        debugPrint(
            '[CatCatchNotifier] Task retry completed: ${task.id} → $result');
      }
    } catch (e) {
      debugPrint('[CatCatchNotifier] Task retry error: $e');
      final index = state.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == index)
              state[i].copyWith(
                status: TaskStatus.failed,
                error: e.toString(),
              )
            else
              state[i],
        ];
        _persistTasks();
      }
    } finally {
      if (_cancelTokens[task.id] == cancelToken) {
        _cancelTokens.remove(task.id);
      }
    }
  }

  // ===========================================================================
  // 持久化
  // ===========================================================================

  /// 保存任务列表到本地文件
  Future<void> _persistTasks() async {
    try {
      final file = await _tasksFile();
      final data = state.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[CatCatchNotifier] Failed to persist tasks: $e');
    }
  }

  /// 从本地文件加载任务列表
  Future<List<CatCatchTask>> _loadPersistedTasks() async {
    try {
      final file = await _tasksFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list
          .map((m) => CatCatchTask.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      debugPrint('[CatCatchNotifier] Failed to load persisted tasks: $e');
      return [];
    }
  }

  /// 持久化文件路径
  Future<File> _tasksFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final catcatchDir = Directory(p.join(dir.path, 'catcatch'));
    if (!await catcatchDir.exists()) {
      await catcatchDir.create(recursive: true);
    }
    return File(p.join(catcatchDir.path, 'tasks.json'));
  }

  // ===========================================================================
  // 辅助方法
  // ===========================================================================

  /// 从 URL 推断标题
  static String _inferTitle(String url) {
    try {
      final uri = Uri.parse(url);
      // 取路径最后一段
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.last;
      }
      return uri.host;
    } catch (_) {
      return url.length > 50 ? '${url.substring(0, 50)}...' : url;
    }
  }
}
