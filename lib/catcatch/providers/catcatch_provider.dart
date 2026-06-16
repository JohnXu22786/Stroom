import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../services/storage_service.dart';
import '../../services/background_service.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart' show CancelToken;
import '../models/catcatch_task.dart';
import 'catcatch_provider_shared.dart';
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
  /// [videoFolder] 视频文件保存到该文件夹（空字符串表示根目录）
  /// [audioFolder] 音频文件保存到该文件夹（空字符串表示根目录）
  ///
  /// 返回新任务 ID。
  String addTask(String url, int expectedDurationSec,
      {String videoFolder = '', String audioFolder = ''}) {
    final id = const Uuid().v4();
    final metadata = <String, String>{
      if (videoFolder.isNotEmpty) 'videoFolder': videoFolder,
      if (audioFolder.isNotEmpty) 'audioFolder': audioFolder,
    };
    final task = CatCatchTask(
      id: id,
      url: url,
      expectedDurationSec: expectedDurationSec,
      title: inferTitleFromUrl(url),
      createdAt: DateTime.now(),
      metadata: metadata,
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
    _persistTasks();
  }

  /// 用户确认继续处理特殊格式（在 converting 步骤前调用）
  ///
  /// 当下载的文件是 ts/flv 等特殊格式或来自播放列表时，
  /// 任务会暂停等待用户确认。调用此方法表示用户同意继续转换。
  void confirmAndContinue(String taskId) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    final task = state[index];
    final metadata = Map<String, String>.from(task.metadata);
    metadata['pendingConfirm'] = 'done';
    metadata.remove('pendingConfirmFormat');

    final updated = task.copyWith(metadata: metadata);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];

    _executeTaskFrom(updated, StepType.converting);
  }

  /// 用户选择媒体资源（在 userSelecting 步骤后调用）
  ///
  /// [mergeAudioUrl] 如果非空，表示需要将指定音频 URL 合并到选中的视频中。
  void selectMedia(String taskId, MediaResource media,
      {String? mergeAudioUrl}) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    // 标记 userSelecting 步骤为已完成
    final steps = state[index].steps.map((s) {
      if (s.type == StepType.userSelecting) {
        return StepStatus.done(StepType.userSelecting);
      }
      return s;
    }).toList();

    // 如果传入了合并音频 URL，存入任务元数据
    Map<String, String> metadata = Map.from(state[index].metadata);
    if (mergeAudioUrl != null && mergeAudioUrl.isNotEmpty) {
      metadata['mergeAudioUrl'] = mergeAudioUrl;
      metadata['mergeMode'] = 'audio_video';
    } else {
      metadata.remove('mergeAudioUrl');
      metadata.remove('mergeMode');
    }

    final task = state[index].copyWith(
      selectedMedia: media,
      status: TaskStatus.running,
      steps: steps,
      metadata: metadata,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) task else state[i],
    ];

    // 从 downloading 步骤继续
    _executeTaskFrom(task, StepType.downloading);
  }

  /// 批量选择多个媒体资源进行下载
  ///
  /// 第一个资源走正常 `selectMedia` 流程，其余资源作为独立子任务直接进入下载步骤。
  void batchSelectMedia(
    String parentTaskId,
    List<MediaResource> mediaList, {
    String? mergeAudioUrl,
  }) {
    if (mediaList.isEmpty) return;
    if (mediaList.length == 1) {
      selectMedia(parentTaskId, mediaList.first,
          mergeAudioUrl: mergeAudioUrl);
      return;
    }

    // 第一个资源：走正常流程
    selectMedia(parentTaskId, mediaList.first,
        mergeAudioUrl: mergeAudioUrl);

    // 其余资源：创建子任务，跳过分析直接下载
    final parentIndex = state.indexWhere((t) => t.id == parentTaskId);
    if (parentIndex < 0) return;
    final parent = state[parentIndex];

    for (int i = 1; i < mediaList.length; i++) {
      final media = mediaList[i];
      _addChildDownloadTask(parent, media);
    }
  }

  /// 创建子下载任务（跳过分析，直接下载指定资源）
  void _addChildDownloadTask(CatCatchTask parent, MediaResource media) {
    final id = const Uuid().v4();
    final allSteps = StepType.values.map((t) {
      final idx = StepType.values.indexOf(t);
      if (idx < StepType.values.indexOf(StepType.downloading)) {
        return StepStatus.done(t);
      }
      return StepStatus.pending(t);
    }).toList();

    final childTask = CatCatchTask(
      id: id,
      url: parent.url,
      expectedDurationSec: parent.expectedDurationSec,
      title: '${parent.title} - ${media.name}.${media.ext}',
      status: TaskStatus.running,
      steps: allSteps,
      createdAt: DateTime.now(),
      detectedMedia: [media],
      selectedMedia: media,
      metadata: Map.from(parent.metadata),
    );

    state = [...state, childTask];
    _persistTasks();
    _executeTaskFrom(childTask, StepType.downloading);
  }

  /// 跳过转换步骤，直接保存原始格式文件
  ///
  /// 当用户选择"保留原始格式"时调用，跳过 ffmpeg 转换直接进入保存步骤。
  void skipConversion(String taskId) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index < 0) return;

    // 标记 converting 步骤为已跳过
    final steps = state[index].steps.map((s) {
      if (s.type == StepType.converting) {
        return StepStatus.skipped(StepType.converting);
      }
      return s;
    }).toList();

    final metadata = Map<String, String>.from(state[index].metadata);
    metadata['pendingConfirm'] = 'done';
    metadata.remove('pendingConfirmFormat');

    final task = state[index].copyWith(
      metadata: metadata,
      steps: steps,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) task else state[i],
    ];

    // 从 saving 步骤继续
    _executeTaskFrom(task, StepType.saving);
  }

  /// 恢复所有持久化的任务（应用启动时调用）
  Future<void> restoreUnfinishedTasks() async {
    try {
      final tasks = await _loadPersistedTasks();
      if (tasks.isEmpty) return;

      // 迁移旧数据：userSelecting 中但 detectedMedia 为空的任务标记为失败
      final migrated = [
        for (final task in tasks)
          if (task.steps.any((s) => s.type == StepType.userSelecting && s.running) &&
              task.detectedMedia.isEmpty)
            task.copyWith(
              status: TaskStatus.failed,
              error: '旧任务的媒体数据已丢失，请重试',
              steps: task.steps.map((s) {
                if (s.type == StepType.userSelecting && s.running) {
                  return s.copyWith(failed: true, running: false);
                }
                return s;
              }).toList(),
            )
          else
            task,
      ];

      // 加载全部任务，running 的改为 paused，其余保持原样（包括 failed 中的原始错误）
      state = [
        for (final task in migrated)
          if (task.status == TaskStatus.running)
            task.copyWith(status: TaskStatus.paused, error: '应用重启，已暂停')
          else
            task,
      ];

      debugPrint(
        '[CatCatchNotifier] Restored ${tasks.length} tasks from persistence',
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

  /// 检查是否有运行中的任务
  bool _hasRunningTasks() =>
      state.any((t) => t.status == TaskStatus.running);

  /// 执行任务
  Future<void> _executeTask(CatCatchTask task) async {
    if (!_hasRunningTasks()) {
      await startBackgroundService();
    }
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
    if (!_hasRunningTasks()) {
      await startBackgroundService();
    }
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
    if (!_hasRunningTasks()) {
      await stopBackgroundService();
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
    final dirPath = await AppStorage.directory;
    final catcatchDir = Directory(p.join(dirPath, 'catcatch'));
    try {
      if (!await catcatchDir.exists()) {
        await catcatchDir.create(recursive: true);
      }
    } catch (_) {
      // Directory creation may fail on some platforms (e.g. web)
    }
    return File(p.join(catcatchDir.path, 'tasks.json'));
  }

}
