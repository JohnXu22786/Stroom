import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import '../../services/storage_service.dart';
import '../../services/background_service.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart' show CancelToken;
import '../models/catcatch_task.dart';
import 'catcatch_provider_shared.dart';
import '../models/media_resource.dart';
import '../engine/task_executor.dart';
import '../config/default_rules.dart';
import '../engine/executor_save.dart';
import '../../utils/atomic_file.dart';

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

  Future<bool>? _pendingWrite;
  int _serviceCleanupGeneration = 0;
  int _persistedServiceCleanupGeneration = 0;
  Completer<void>? _removalBarrier;
  List<CatCatchTask>? _disposedSnapshot;
  Future<bool>? _disposedPersistence;
  int _activeTaskRestorations = 0;
  bool _taskRestoreNeedsRetry = false;
  bool _snapshotWriteDeferred = false;
  final Set<String> _removedTaskIdsDuringRestore = {};
  static const int _initialTaskRestoreRetryDelaySeconds = 1;
  static const int _maximumTaskRestoreRetryDelaySeconds = 60;
  Timer? _taskRestoreRetryTimer;
  int _taskRestoreRetryDelaySeconds = _initialTaskRestoreRetryDelaySeconds;

  bool get _restoringTasks => _activeTaskRestorations > 0;

  CatCatchNotifier(this.ref) : super([]);

  @override
  void dispose() {
    _cancelTaskRestoreRetry();
    _disposedSnapshot = List.of(state);
    super.dispose();
  }

  void _scheduleTaskRestoreRetry() {
    if (!mounted || _taskRestoreRetryTimer != null) return;
    _taskRestoreRetryTimer = Timer(
      Duration(seconds: _taskRestoreRetryDelaySeconds),
      () {
        _taskRestoreRetryTimer = null;
        if (!mounted) return;
        if (_activeTaskRestorations > 0) {
          _scheduleTaskRestoreRetry();
          return;
        }
        unawaited(restoreUnfinishedTasks());
      },
    );

    final nextDelaySeconds = _taskRestoreRetryDelaySeconds * 2;
    _taskRestoreRetryDelaySeconds =
        nextDelaySeconds < _maximumTaskRestoreRetryDelaySeconds
            ? nextDelaySeconds
            : _maximumTaskRestoreRetryDelaySeconds;
  }

  void _cancelTaskRestoreRetry({bool resetDelay = false}) {
    _taskRestoreRetryTimer?.cancel();
    _taskRestoreRetryTimer = null;
    if (resetDelay) {
      _taskRestoreRetryDelaySeconds = _initialTaskRestoreRetryDelaySeconds;
    }
  }

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
  /// [deferSingleResourceSelection] lets flows inspect a sole resource before download.
  ///
  /// 返回新任务 ID。
  String addTask(String url, int expectedDurationSec,
      {String videoFolder = '',
      String audioFolder = '',
      String? taskId,
      bool deferSingleResourceSelection = false}) {
    final id = taskId ?? const Uuid().v4();
    final metadata = <String, String>{
      if (videoFolder.isNotEmpty) 'videoFolder': videoFolder,
      if (audioFolder.isNotEmpty) 'audioFolder': audioFolder,
      if (deferSingleResourceSelection) 'deferSingleResourceSelection': 'true',
    };
    final task = CatCatchTask(
      id: id,
      url: url,
      expectedDurationSec: expectedDurationSec,
      title: inferTitleFromUrl(url),
      createdAt: DateTime.now(),
      metadata: metadata,
    );
    _removedTaskIdsDuringRestore.remove(id);
    state = [...state, task];
    unawaited(_persistTasks());

    // 异步开始执行
    final previousCancelToken = _cancelTokens[id];
    if (previousCancelToken != null && !previousCancelToken.isCancelled) {
      previousCancelToken.cancel();
    }
    _executeTask(task);

    return id;
  }

  /// 暂停任务
  void pauseTask(String id) {
    final index = state.lastIndexWhere((t) => t.id == id);
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
    unawaited(_persistTasks());
  }

  /// 继续任务（从暂停状态恢复）
  void resumeTask(String id) {
    final index = state.lastIndexWhere((t) => t.id == id);
    if (index < 0) return;
    if (state[index].status != TaskStatus.paused) return;

    final task = state[index];
    final latestRuntimeTask = state.lastWhere((t) => t.id == id);
    final resumeSnapshot = task.copyWith(
      steps: latestRuntimeTask.steps,
      detectedMedia: latestRuntimeTask.detectedMedia,
      selectedMedia: latestRuntimeTask.selectedMedia,
      progress: latestRuntimeTask.progress,
      downloadedFilePath: latestRuntimeTask.downloadedFilePath,
      downloadedBytes: latestRuntimeTask.downloadedBytes,
      clearSelectedMedia: latestRuntimeTask.selectedMedia == null,
      clearDownloadedFilePath: latestRuntimeTask.downloadedFilePath == null,
    );
    // 如果卡在 userSelecting 步骤，让 _executeSteps 自然处理

    // 找到第一个未完成的步骤
    StepType? firstIncomplete;
    int firstIncompleteIndex = -1;
    for (int i = 0; i < resumeSnapshot.steps.length; i++) {
      if (!resumeSnapshot.steps[i].completed) {
        firstIncomplete = resumeSnapshot.steps[i].type;
        firstIncompleteIndex = i;
        break;
      }
    }

    // 重置该步骤及之后为 pending
    final newSteps = List<StepStatus>.from(resumeSnapshot.steps);
    if (firstIncompleteIndex >= 0) {
      for (int i = firstIncompleteIndex; i < newSteps.length; i++) {
        newSteps[i] = StepStatus.pending(newSteps[i].type);
      }
    }

    final updated = resumeSnapshot.copyWith(
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
    _removedTaskIdsDuringRestore.add(id);

    // 如果任务正在运行，取消
    final cancelToken = _cancelTokens.remove(id);
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel();
    }

    // 查找被删除的任务，用于清理文件
    final removedTasks = state.where((t) => t.id == id).toList();
    final remainingTasks = state.where((t) => t.id != id).toList();
    for (final task in removedTasks) {
      unawaited(_cleanupTaskFiles(task, remainingTasks: remainingTasks));
    }

    state = remainingTasks;
    _persistTasks();
  }

  /// Save removals before publishing them; absent IDs also retry disk cleanup.
  Future<bool> removeTasksPersisted(Iterable<String> ids) async {
    while (_removalBarrier != null) {
      await _removalBarrier!.future;
    }
    final cleanupGeneration = _serviceCleanupGeneration;
    if (!mounted) return false;
    final removedIds = ids.toSet();
    if (removedIds.isEmpty) return true;

    final gate = Completer<void>();
    _removalBarrier = gate;
    try {
      final proposed = state.where((t) => !removedIds.contains(t.id)).toList();
      if (_restoringTasks || _taskRestoreNeedsRetry) {
        _removedTaskIdsDuringRestore.addAll(removedIds);
      }
      if (!await _writeSnapshot(proposed)) return false;
      if (cleanupGeneration > _persistedServiceCleanupGeneration) {
        _persistedServiceCleanupGeneration = cleanupGeneration;
      }
      if (mounted) {
        final removed = state.where((t) => removedIds.contains(t.id)).toList();
        final remaining =
            state.where((t) => !removedIds.contains(t.id)).toList();
        state = remaining;
        for (final id in removedIds) {
          final token = _cancelTokens.remove(id);
          if (token != null && !token.isCancelled) token.cancel();
        }
        for (final task in removed) {
          unawaited(_cleanupTaskFiles(task, remainingTasks: remaining));
        }
      }
      if (!mounted) {
        // Deferred ordinary writes own this snapshot after disposal. Only a
        // successful removal may remove these IDs from its final flush.
        _disposedSnapshot = _disposedSnapshot
            ?.where((task) => !removedIds.contains(task.id))
            .toList();
      }
      final remainingTasks = mounted ? state : _disposedSnapshot;
      if (cleanupGeneration == _serviceCleanupGeneration &&
          remainingTasks != null &&
          !remainingTasks.any((task) => task.status == TaskStatus.running)) {
        await stopBackgroundServiceIfNotUserEnabled();
      }
      return true;
    } finally {
      _removalBarrier = null;
      gate.complete();
    }
  }

  /// 清理任务关联的临时文件
  Future<void> _cleanupTaskFiles(CatCatchTask? task,
      {Iterable<CatCatchTask> remainingTasks = const []}) async {
    if (task == null) return;
    try {
      final appDirPath = await AppStorage.directory;
      Iterable<CatCatchTask> currentRemainingTasks() =>
          mounted ? state : (_disposedSnapshot ?? remainingTasks);
      await cleanupTaskFiles(task,
          appDirPath: appDirPath,
          remainingTasks: currentRemainingTasks(),
          remainingTasksProvider: currentRemainingTasks);
    } catch (e) {
      debugPrint('[CatCatchNotifier] Failed to clean up task files: $e');
    }
  }

  /// 清理任务关联的临时文件（静态方法，可用于测试）
  ///
  /// 删除任务相关的临时下载文件、分段目录、转换文件、进度跟踪等。
  /// 对于已完成的任务，不会删除最终保存的文件（[downloadedFilePath]）。
  /// [appDirPath] 可选，指定应用目录路径；未指定时使用 [AppStorage.directory]。
  @visibleForTesting
  static Future<void> cleanupTaskFiles(CatCatchTask task,
      {String? appDirPath,
      Iterable<CatCatchTask> remainingTasks = const [],
      Iterable<CatCatchTask> Function()? remainingTasksProvider}) async {
    final appDir = appDirPath ?? await AppStorage.directory;
    Iterable<CatCatchTask> currentRemainingTasks() =>
        remainingTasksProvider?.call() ?? remainingTasks;

    bool isInUse(String path) {
      final normalizedPath = _normalizedFilePath(path);
      for (final remainingTask in currentRemainingTasks()) {
        final downloadedFilePath = remainingTask.downloadedFilePath;
        if (downloadedFilePath != null &&
            _normalizedFilePath(downloadedFilePath) == normalizedPath) {
          return true;
        }
        if (remainingTask.status != TaskStatus.completed &&
            _mediaDerivedArtifacts(remainingTask, appDir).any((artifact) =>
                _normalizedFilePath(artifact.path) == normalizedPath)) {
          return true;
        }
      }
      return false;
    }

    // 1. 删除分段下载进度跟踪
    final progressPath =
        p.join(appDir, 'catcatch', '.progress', '${task.id}_dl_progress.json');
    await _deleteFileBestEffort(File(progressPath));

    // 2. 对于未完成的任务，删除它已记录的 downloadedFilePath
    // （放在前面处理，与 selectedMedia 无关）
    if (task.downloadedFilePath != null &&
        task.status != TaskStatus.completed) {
      final downloadedFilePath = task.downloadedFilePath!;
      await _deleteFileBestEffort(File(downloadedFilePath),
          shouldDelete: () => !isInUse(downloadedFilePath));
    }

    // 3. 如果没有已选媒体资源，说明还没开始下载，无需进一步清理
    if (task.selectedMedia == null) return;

    for (final artifact in _mediaDerivedArtifacts(task, appDir)) {
      bool shouldDelete() => !isInUse(artifact.path);
      if (artifact is Directory) {
        await _deleteDirBestEffort(artifact, shouldDelete: shouldDelete);
      } else if (artifact is File) {
        await _deleteFileBestEffort(artifact, shouldDelete: shouldDelete);
      }
    }
  }

  static String _normalizedFilePath(String path) =>
      p.normalize(p.absolute(path));

  static List<FileSystemEntity> _mediaDerivedArtifacts(
      CatCatchTask task, String appDir) {
    final media = task.selectedMedia;
    if (media == null) return const [];

    final fileName = buildDownloadFileName(media, task.metadata);
    final downloadDir = p.join(appDir, 'catcatch', 'downloads');
    final convertDir = p.join(appDir, 'catcatch', 'converted');
    final mergedName = '${p.basenameWithoutExtension(fileName)}_merged.ts';
    final convertBase = media.isPlaylist
        ? p.basenameWithoutExtension(mergedName)
        : p.basenameWithoutExtension(fileName);
    // The downloader writes the non-dot temp file while the executor checks
    // the dot-prefixed variant when resuming.
    final tempSuffix = DefaultRules.tempFileSuffix;
    return [
      File(p.join(downloadDir, '$fileName$tempSuffix')),
      File(p.join(downloadDir, '.$fileName$tempSuffix')),
      File(p.join(downloadDir, fileName)),
      File(p.join(downloadDir, mergedName)),
      Directory(p.join(downloadDir, '.${mergedName}_parts')),
      // Playlists convert the merged TS, so their output uses its basename.
      File(p.join(convertDir, '$convertBase.mp4')),
    ];
  }

  /// 删除文件（尽力而为，失败时短暂重试）。
  ///
  /// 取消下载后写入句柄可能尚未释放（Windows 上打开的文件无法删除），
  /// 因此重试几次直到句柄释放，避免残留半下载文件。
  /// 重试间隔为 150ms × 尝试次数（锁定句柄的单元测试依赖该节奏）。
  static Future<void> _deleteFileBestEffort(File file,
      {bool Function()? shouldDelete}) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        if (await file.exists()) {
          if (shouldDelete != null && !shouldDelete()) return;
          await file.delete();
        }
        return;
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
    debugPrint('[CatCatchNotifier] Failed to delete file after retries: $file');
  }

  /// 删除目录（递归），失败时短暂重试（与 [_deleteFileBestEffort] 同理）。
  static Future<void> _deleteDirBestEffort(Directory dir,
      {bool Function()? shouldDelete}) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        if (await dir.exists()) {
          if (shouldDelete != null && !shouldDelete()) return;
          await dir.delete(recursive: true);
        }
        return;
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
    debugPrint(
        '[CatCatchNotifier] Failed to delete directory after retries: $dir');
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
      selectMedia(parentTaskId, mediaList.first, mergeAudioUrl: mergeAudioUrl);
      return;
    }

    // 第一个资源：走正常流程
    selectMedia(parentTaskId, mediaList.first, mergeAudioUrl: mergeAudioUrl);

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
    _cancelTaskRestoreRetry();
    _activeTaskRestorations++;
    try {
      // A previous restore may have queued its reconciled snapshot without
      // awaiting it. Wait before loading so a later restore cannot read stale
      // data while that write is still pending.
      final pendingWrite = _pendingWrite;
      if (pendingWrite != null &&
          !await pendingWrite &&
          !_taskRestoreNeedsRetry &&
          !_snapshotWriteDeferred) {
        debugPrint(
          '[CatCatchNotifier] Skipping restore after a task snapshot write failed',
        );
        _taskRestoreNeedsRetry = true;
        _scheduleTaskRestoreRetry();
        return;
      }

      final tasks = await _loadPersistedTasks();

      final removedTaskIds = Set<String>.of(_removedTaskIdsDuringRestore);

      // 迁移旧数据：userSelecting 中但 detectedMedia 为空的任务标记为失败
      final migrated = [
        for (final task in tasks)
          if (task.steps
                  .any((s) => s.type == StepType.userSelecting && s.running) &&
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

      // The current state may have changed while loading. Keep its latest
      // version for matching IDs and append concurrent tasks after the file
      // snapshot, while still normalizing tasks restored after a process restart.
      final currentTasks = <String, CatCatchTask>{
        for (final task in state)
          if (!removedTaskIds.contains(task.id)) task.id: task,
      };
      final restoredTasks = <String, CatCatchTask>{};
      for (final task in migrated) {
        if (removedTaskIds.contains(task.id)) continue;
        restoredTasks[task.id] = task.status == TaskStatus.running
            ? task.copyWith(status: TaskStatus.paused, error: '应用重启，已暂停')
            : task;
      }

      final hadConcurrentChanges =
          state.isNotEmpty || removedTaskIds.isNotEmpty;
      state = [
        for (final task in restoredTasks.values)
          currentTasks.remove(task.id) ?? task,
        ...currentTasks.values,
      ];
      _taskRestoreNeedsRetry = false;
      _cancelTaskRestoreRetry(resetDelay: true);
      if (hadConcurrentChanges) unawaited(_persistTasks());

      debugPrint(
        '[CatCatchNotifier] Restored ${tasks.length} tasks from persistence',
      );
    } catch (e) {
      _taskRestoreNeedsRetry = true;
      _scheduleTaskRestoreRetry();
      debugPrint('[CatCatchNotifier] Failed to restore tasks: $e');
    } finally {
      _activeTaskRestorations--;
      if (_activeTaskRestorations == 0) {
        // Keep removals until a safe snapshot lands so a later retry cannot
        // reintroduce tasks from the older on-disk snapshot.
        if (_snapshotWriteDeferred && !_taskRestoreNeedsRetry) {
          _snapshotWriteDeferred = false;
          unawaited(_persistTasks());
        }
      }
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
  bool _hasRunningTasks() => state.any((t) => t.status == TaskStatus.running);

  /// Starts a temporary service for CatCatch tasks without changing user intent.
  @visibleForTesting
  Future<bool> startBackgroundServiceForTask() =>
      startBackgroundService(persistEnabled: false);

  @visibleForTesting
  Future<String?> executeTaskForTask({
    required CatCatchTask task,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) =>
      TaskExecutor.executeTask(
        task: task,
        onUpdate: onUpdate,
        cancelToken: cancelToken,
      );

  @visibleForTesting
  Future<String?> retryFromStepForTask({
    required CatCatchTask task,
    required StepType fromStep,
    required void Function(CatCatchTask updated) onUpdate,
    required CancelToken cancelToken,
  }) =>
      TaskExecutor.retryFromStep(
        task: task,
        fromStep: fromStep,
        onUpdate: onUpdate,
        cancelToken: cancelToken,
      );

  void _markTaskFailedAfterBackgroundServiceStartup(String taskId) {
    final index = state.lastIndexWhere((current) => current.id == taskId);
    if (index < 0) return;

    _serviceCleanupGeneration++;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          state[i].copyWith(
            status: TaskStatus.failed,
            error: '后台服务启动失败，任务未执行',
          )
        else
          state[i],
    ];
    _persistTasks();
  }

  /// 执行任务
  Future<void> _executeTask(CatCatchTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      // Task status does not indicate whether the background service is alive.
      final serviceStarted = await startBackgroundServiceForTask();
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_cancelTokens[task.id], cancelToken) ||
          !state.any((current) => current.id == task.id)) {
        return;
      }
      if (isBackgroundServiceSupported() && !serviceStarted) {
        _markTaskFailedAfterBackgroundServiceStartup(task.id);
        return;
      }

      final result = await executeTaskForTask(
        task: task,
        onUpdate: (updated) {
          if (!mounted ||
              cancelToken.isCancelled ||
              !identical(_cancelTokens[task.id], cancelToken)) {
            return;
          }
          final index = state.lastIndexWhere((t) => t.id == updated.id);
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
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_cancelTokens[task.id], cancelToken)) {
        return;
      }
      debugPrint('[CatCatchNotifier] Task execution error: $e');
      // 更新为失败状态
      final index = state.lastIndexWhere((t) => t.id == task.id);
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
    final previousCancelToken = _cancelTokens[task.id];
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;
    if (previousCancelToken != null && !previousCancelToken.isCancelled) {
      previousCancelToken.cancel();
    }

    try {
      // Task status does not indicate whether the background service is alive.
      final index = state.lastIndexWhere((current) => current.id == task.id);
      if (index >= 0 && state[index].status != TaskStatus.running) {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == index)
              state[i].copyWith(status: TaskStatus.running)
            else
              state[i],
        ];
      }
      final serviceStarted = await startBackgroundServiceForTask();
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_cancelTokens[task.id], cancelToken) ||
          !state.any((current) => current.id == task.id)) {
        return;
      }
      if (isBackgroundServiceSupported() && !serviceStarted) {
        _markTaskFailedAfterBackgroundServiceStartup(task.id);
        return;
      }

      final result = await retryFromStepForTask(
        task: task,
        fromStep: fromStep,
        onUpdate: (updated) {
          if (!mounted ||
              cancelToken.isCancelled ||
              !identical(_cancelTokens[task.id], cancelToken)) {
            return;
          }
          final index = state.lastIndexWhere((t) => t.id == updated.id);
          if (index >= 0) {
            final current = state[index];
            final mergedMetadata = Map<String, String>.from(current.metadata);
            for (final key in task.metadata.keys) {
              if (!updated.metadata.containsKey(key)) {
                mergedMetadata.remove(key);
              }
            }
            for (final entry in updated.metadata.entries) {
              if (task.metadata[entry.key] != entry.value) {
                mergedMetadata[entry.key] = entry.value;
              }
            }

            final runtimeUpdate = updated.copyWith(
              url: current.url,
              expectedDurationSec: current.expectedDurationSec,
              title:
                  current.title != task.title ? current.title : updated.title,
              createdAt: current.createdAt,
              statusChangedAt: updated.status == task.status
                  ? current.statusChangedAt
                  : updated.statusChangedAt,
              metadata: mergedMetadata,
            );
            final next = current.status == TaskStatus.paused &&
                    updated.status == TaskStatus.running
                // 如果外部已将任务暂停，保留暂停状态，不覆盖
                ? runtimeUpdate.copyWith(status: TaskStatus.paused)
                : runtimeUpdate;
            state = [
              for (int i = 0; i < state.length; i++)
                if (i == index) next else state[i],
            ];
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
      if (!mounted ||
          cancelToken.isCancelled ||
          !identical(_cancelTokens[task.id], cancelToken)) {
        return;
      }
      debugPrint('[CatCatchNotifier] Task retry error: $e');
      final index = state.lastIndexWhere((t) => t.id == task.id);
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
  Future<void> _persistTasks({
    bool stopServiceWhenIdle = true,
    int? cleanupGeneration,
  }) {
    final generation = cleanupGeneration ?? _serviceCleanupGeneration;
    final barrier = _removalBarrier;
    if (barrier != null) {
      return barrier.future.then(
        (_) => _persistTasks(
          stopServiceWhenIdle: stopServiceWhenIdle,
          cleanupGeneration: generation,
        ),
      );
    }
    if (!mounted) {
      final snapshot = _disposedSnapshot;
      if (snapshot == null) return Future<void>.value();
      final persistence = _disposedPersistence ??= _writeSnapshot(snapshot);
      return persistence.then(
        (writeSucceeded) => _completeSnapshotPersistence(
          snapshot: snapshot,
          generation: generation,
          stopServiceWhenIdle: stopServiceWhenIdle,
          writeSucceeded: writeSucceeded,
        ),
      );
    }
    final snapshot = state;
    return _writeSnapshot(snapshot).then(
      (writeSucceeded) => _completeSnapshotPersistence(
        snapshot: snapshot,
        generation: generation,
        stopServiceWhenIdle: stopServiceWhenIdle,
        writeSucceeded: writeSucceeded,
      ),
    );
  }

  Future<void> _completeSnapshotPersistence({
    required List<CatCatchTask> snapshot,
    required int generation,
    required bool stopServiceWhenIdle,
    required bool writeSucceeded,
  }) async {
    if (writeSucceeded && generation > _persistedServiceCleanupGeneration) {
      _persistedServiceCleanupGeneration = generation;
    }
    // Recheck after the write: an earlier queued snapshot may have already
    // persisted this cleanup generation while this snapshot was pending.
    final currentSnapshot = mounted ? state : (_disposedSnapshot ?? snapshot);
    if (stopServiceWhenIdle &&
        generation <= _persistedServiceCleanupGeneration &&
        generation == _serviceCleanupGeneration &&
        !snapshot.any((task) => task.status == TaskStatus.running) &&
        !currentSnapshot.any((task) => task.status == TaskStatus.running)) {
      await stopBackgroundServiceIfNotUserEnabled();
    }
  }

  Future<bool> _writeSnapshot(List<CatCatchTask> snapshot) {
    final deferWhenQueued =
        _taskRestoreNeedsRetry || _activeTaskRestorations > 0;
    if (deferWhenQueued) _snapshotWriteDeferred = true;
    final previous = _pendingWrite?.then<void>((_) {}) ?? Future<void>.value();
    final write = previous.then((_) async {
      try {
        final file = await _tasksFile();
        if (deferWhenQueued ||
            _taskRestoreNeedsRetry ||
            _activeTaskRestorations > 0) {
          _snapshotWriteDeferred = true;
          return false;
        }
        final data = snapshot.map((t) => t.toMap()).toList();
        // 原子写入：防止中途崩溃留下半截 JSON 导致任务列表丢失。
        await AtomicFile.writeString(file, jsonEncode(data));
        if (_activeTaskRestorations == 0 && !_taskRestoreNeedsRetry) {
          final persistedTaskIds = snapshot.map((task) => task.id).toSet();
          _removedTaskIdsDuringRestore
              .removeWhere((id) => !persistedTaskIds.contains(id));
          _snapshotWriteDeferred = false;
        }
        return true;
      } catch (e) {
        debugPrint('[CatCatchNotifier] Failed to persist tasks: $e');
        return false;
      }
    });
    _pendingWrite = write;
    return write;
  }

  /// Waits for queued task snapshots to settle in deterministic tests.
  @visibleForTesting
  Future<void> waitForTaskSnapshotWritesForTesting() async {
    while (true) {
      final pendingWrite = _pendingWrite;
      if (pendingWrite == null) return;
      await pendingWrite;
      if (identical(pendingWrite, _pendingWrite)) return;
    }
  }

  /// 从本地文件加载任务列表
  Future<List<CatCatchTask>> _loadPersistedTasks() async {
    final file = await _tasksFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    final list = jsonDecode(content) as List;
    return list
        .map((m) => CatCatchTask.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
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
