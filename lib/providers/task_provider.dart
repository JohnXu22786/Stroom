import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../services/storage_service.dart';
import 'task_provider_shared.dart';
export 'task_provider_shared.dart';
import 'tts_state_provider.dart';
import 'provider_config.dart';
import 'tts_provider.dart' as tts_provider_base;
import '../utils/audio_trim.dart';
import '../utils/atomic_file.dart';
import '../utils/audio_utils.dart';
import '../utils/file_manifest.dart';

// ============================================================================
// 任务列表提供器
// ============================================================================

final taskListProvider =
    StateNotifierProvider<TaskListNotifier, List<SynthesisTask>>(
  (ref) => TaskListNotifier(ref),
);

class TaskListNotifier extends StateNotifier<List<SynthesisTask>> {
  final Ref ref;
  final _uuid = const Uuid();

  // 每个正在运行的任务对应的 CancelToken
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Future<void>> _saveLocks = {};

  /// Allows tests to pause after file writes and before the gallery commit.
  @visibleForTesting
  Future<void> Function()? debugBeforeSaveCommit;

  @visibleForTesting
  Future<void> Function()? debugAfterSaveCommit;

  @visibleForTesting
  Future<Uint8List> Function(String, Map<String, dynamic>, CancelToken)?
      debugSynthesize;

  Future<void>? _pendingWrite;
  Completer<void>? _removalBarrier;
  List<SynthesisTask>? _disposedSnapshot;
  Future<void>? _disposedPersistence;

  TaskListNotifier(this.ref) : super([]);

  /// 添加一个合成任务并立刻开始后台执行
  String addTask({
    required String title,
    required String text,
    required ProviderConfigItem providerConfig,
    required ModelConfig modelConfig,
    Map<String, String>? customParams,
    Map<String, dynamic>? trimPreset,
    String? taskId,
    String folder = '',
  }) {
    final id = taskId ?? _uuid.v4();
    final task = SynthesisTask(
      id: id,
      title: title,
      text: text,
      providerConfig: providerConfig,
      modelConfig: modelConfig,
      customParams: customParams,
      trimPreset: trimPreset,
      folder: folder,
    );

    state = [task, ...state];
    _persistTasks();

    // 在后台执行合成
    _executeTask(task);

    return id;
  }

  /// 在后台执行合成任务
  Future<void> _executeTask(SynthesisTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    bool isCurrent() =>
        !cancelToken.isCancelled &&
        mounted &&
        identical(_cancelTokens[task.id], cancelToken) &&
        state.any((t) => t.id == task.id && t.status == TaskStatus.running);

    try {
      final synthConfig = ref.read(synthesisConfigProvider);

      final provider =
          tts_provider_base.createProviderFromConfig(task.providerConfig);

      // 构建参数
      final params = <String, dynamic>{
        'voice': synthConfig.voice,
        'speed': synthConfig.speed,
        'volume': synthConfig.volume,
        'format': synthConfig.format,
        'response_format': synthConfig.format,
        'model': task.modelConfig.modelId,
      };
      if (task.customParams != null) {
        params.addAll(task.customParams!);
      }
      // 'saveFolder' is an internal key (flow blocks use it to pick the
      // output folder) — strip it so it never reaches the TTS API body.
      params.remove('saveFolder');
      // customParams values are String-typed (flow blocks stringify
      // numbers); the API contract for speed is numeric, so coerce it
      // back instead of sending "speed": "1.0" as a JSON string, which
      // strict TTS servers reject with 400.
      final speedParam = task.customParams?['speed'];
      if (speedParam != null) {
        params['speed'] = double.tryParse(speedParam) ?? synthConfig.speed;
      }
      final volumeParam = task.customParams?['volume'];
      if (volumeParam != null) {
        params['volume'] = double.tryParse(volumeParam) ?? synthConfig.volume;
      }
      final requestedFormat = task.customParams?['response_format'] ??
          task.customParams?['format'] ??
          synthConfig.format;
      // Parse JSON-type custom param values from string to actual JSON
      // objects/arrays so they are sent as raw JSON, not quoted strings.
      parseJsonCustomParams(params, task.modelConfig);

      // 执行合成
      final synthesize = debugSynthesize;
      var audioData = synthesize != null
          ? await synthesize(task.text, params, cancelToken)
          : await provider.synthesize(
              task.text,
              params: params,
              cancelToken: cancelToken,
            );

      // 如果已被暂停，不再继续处理
      if (cancelToken.isCancelled) return;

      // 格式校验
      var actualFormat = requestedFormat;
      if (audioData.isNotEmpty) {
        final fixed = ensureValidAudioFormat(
          audioData,
          requestedFormat: requestedFormat,
          sampleRate: 24000,
        );
        audioData = fixed.$1;
        actualFormat = fixed.$2;
      }

      // 裁切
      if (task.trimPreset != null && audioData.isNotEmpty) {
        try {
          audioData = trimAudio(audioData, preset: task.trimPreset!);
        } catch (e) {
          debugPrint('Failed to trim audio: $e');
        }
      }

      // 如果已被暂停，不保存
      if (cancelToken.isCancelled) return;

      // 保存音频文件
      final saveFolder = task.customParams?['saveFolder'] ?? '';
      final saved = await _saveAudioFile(
        audioData,
        actualFormat,
        task.text,
        isCurrent: isCurrent,
        name: task.title,
        // 显式 folder 参数（TTS 页面）优先；任务流块通过 customParams
        // 传 saveFolder，两者都指向保存目录。
        folder: task.folder.isNotEmpty ? task.folder : saveFolder,
      );

      if (saved == null) return;
      try {
        if (!isCurrent()) {
          await saved.rollback();
          return;
        }

        // Status and gallery commit finish while this hash is locked, so a
        // resumed task cannot race the old save's final cancellation check.
        try {
          _updateTask(task.id, TaskStatus.completed,
              downloadedFilePath: saved.filePath);
        } catch (_) {
          await saved.rollback();
          rethrow;
        }
      } finally {
        saved.release();
      }

      // 刷新文件列表
      ref.read(audioRecordsProvider.notifier).loadRecords();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel ||
          cancelToken.isCancelled ||
          !mounted ||
          !identical(_cancelTokens[task.id], cancelToken)) {
        return;
      }
      String responseBodyStr = '';
      if (e.response?.data != null) {
        final d = e.response!.data;
        if (d is List<int>) {
          try {
            responseBodyStr = utf8.decode(d);
          } catch (_) {
            responseBodyStr = d.toString();
          }
        } else {
          responseBodyStr = d.toString();
        }
      }
      final String origMsg = e.message ?? '';
      final String extra = origMsg.isNotEmpty ? '\n原始错误: $origMsg' : '';
      String errorMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg = '网络连接超时，请检查网络或API地址$extra';
          break;
        case DioExceptionType.receiveTimeout:
          errorMsg = '服务器响应超时，请稍后重试$extra';
          break;
        case DioExceptionType.connectionError:
          errorMsg = kIsWeb
              ? '无法连接到服务器。Web端常见原因：CORS跨域限制或API地址不正确。$extra'
              : '无法连接到服务器（${e.message ?? "未知网络错误"}）';
          break;
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode ?? 0;
          final body = e.response?.data;
          errorMsg =
              'API返回错误 (HTTP $statusCode${body != null ? ": $body" : ""})$extra';
          break;
        default:
          errorMsg = '合成失败: ${e.message ?? e.toString()}';
      }
      _updateTask(
        task.id,
        TaskStatus.failed,
        error: errorMsg,
        originalResponse: responseBodyStr.isNotEmpty ? responseBodyStr : null,
      );
    } catch (e) {
      if (cancelToken.isCancelled ||
          !mounted ||
          !identical(_cancelTokens[task.id], cancelToken)) {
        return;
      }
      String? origReq;
      String? origResp;
      if (e is tts_provider_base.SynthesisException) {
        origReq = e.requestBody;
        origResp = e.responseBody;
      }
      final errorMsg = '合成失败: $e';
      _updateTask(
        task.id,
        TaskStatus.failed,
        error: errorMsg,
        originalRequest: origReq,
        originalResponse: origResp,
      );
    } finally {
      if (identical(_cancelTokens[task.id], cancelToken)) {
        _cancelTokens.remove(task.id);
      }
    }
  }

  /// 暂停运行中的任务
  void pauseTask(String taskId) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    if (state[index].status != TaskStatus.running) return;

    // 取消 HTTP 请求
    final token = _cancelTokens.remove(taskId);
    token?.cancel();

    // 更新状态
    final newState = [...state];
    newState[index] = newState[index].copyWith(
      status: TaskStatus.paused,
      completedAt: null,
    );
    state = newState;
    _persistTasks();
  }

  /// 继续已暂停的任务（重新开始）
  void resumeTask(String taskId,
      {ProviderConfigItem? providerConfig, ModelConfig? modelConfig}) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    if (state[index].status != TaskStatus.paused) return;

    final task = state[index];
    final updated = task.copyWith(
      providerConfig: providerConfig,
      modelConfig: modelConfig,
      status: TaskStatus.running,
      error: null,
      completedAt: null,
    );
    final newState = [...state];
    newState[index] = updated;
    state = newState;
    _persistTasks();

    _executeTask(updated);
  }

  /// 重试失败的任务
  void retryTask(String taskId) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final oldTask = state[index];
    if (oldTask.status != TaskStatus.failed) return;

    // 更新状态为运行中
    final updated = oldTask.copyWith(
      status: TaskStatus.running,
      error: null,
      completedAt: null,
    );
    final newState = [...state];
    newState[index] = updated;
    state = newState;
    _persistTasks();

    // 确保 SynthesisConfig 使用当前模型的 voice ID，而非过期的 voice name
    _syncVoiceFromModelConfig(updated.modelConfig);

    // 执行
    _executeTask(updated);
  }

  /// 从模型配置中同步 voice ID 到 SynthesisConfig（防止过期的 voice name 被发送）
  void _syncVoiceFromModelConfig(ModelConfig modelConfig) {
    if (modelConfig.voices.isNotEmpty) {
      final notifier = ref.read(synthesisConfigProvider.notifier);
      notifier.updateVoice(modelConfig.voices.first.id);
    }
  }

  /// 将指定 ID 的任务标记为失败（用于外部触发，如应用退出）
  void failTask(String taskId, {required String error}) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        status: TaskStatus.failed,
        error: error,
        completedAt: DateTime.now(),
      );
    }).toList();
    _persistTasks();
  }

  /// 将所有运行中的任务标记为失败（应用退出/断开连接时调用）
  void failAllRunningTasks({required String error}) {
    state = state.map((t) {
      if (t.status != TaskStatus.running) return t;
      return t.copyWith(
        status: TaskStatus.failed,
        error: error,
        completedAt: DateTime.now(),
      );
    }).toList();
    _persistTasks();
  }

  /// 关闭指定任务的错误信息
  void dismissError(String taskId) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(error: null);
    }).toList();
    _persistTasks();
  }

  /// 删除单个任务
  void removeTask(String taskId) {
    // 取消正在进行的 HTTP 请求
    final token = _cancelTokens.remove(taskId);
    token?.cancel();
    state = state.where((t) => t.id != taskId).toList();
    _persistTasks();
  }

  /// Save removals before publishing them; absent IDs also retry disk cleanup.
  Future<bool> removeTasksPersisted(Iterable<String> ids) async {
    while (_removalBarrier != null) {
      await _removalBarrier!.future;
    }
    if (!mounted) return false;
    final removedIds = ids.toSet();
    if (removedIds.isEmpty) return true;

    final gate = Completer<void>();
    _removalBarrier = gate;
    try {
      final proposed = state.where((t) => !removedIds.contains(t.id)).toList();
      if (!await _writeSnapshot(proposed)) return false;
      if (mounted) {
        state = state.where((t) => !removedIds.contains(t.id)).toList();
        for (final id in removedIds) {
          _cancelTokens.remove(id)?.cancel();
        }
      }
      if (!mounted) {
        // Deferred ordinary writes own this snapshot after disposal. Only a
        // successful removal may remove these IDs from its final flush.
        _disposedSnapshot = _disposedSnapshot
            ?.where((task) => !removedIds.contains(task.id))
            .toList();
      }
      return true;
    } finally {
      _removalBarrier = null;
      gate.complete();
    }
  }

  void _updateTask(String taskId, TaskStatus status,
      {String? error,
      String? originalRequest,
      String? originalResponse,
      String? downloadedFilePath}) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        status: status,
        error: error,
        originalRequest: originalRequest,
        originalResponse: originalResponse,
        downloadedFilePath: downloadedFilePath,
        completedAt:
            status == TaskStatus.completed || status == TaskStatus.failed
                ? DateTime.now()
                : null,
      );
    }).toList();
    _persistTasks();
  }

  /// 保存音频文件（与 TTSStateNotifier 逻辑一致）
  /// Returns the saved file and rollback/release actions for the caller to
  /// finish the task status under the same hash lock. A canceled save removes
  /// its own gallery record and unreferenced files.
  Future<
      ({
        String? filePath,
        Future<void> Function() rollback,
        void Function() release,
      })?> _saveAudioFile(
    Uint8List audioData,
    String format,
    String text, {
    required bool Function() isCurrent,
    String name = '',
    String folder = '',
  }) async {
    final hash = computeAudioHash(audioData);
    final audioName = '$hash.$format';
    final textName = '$hash.txt';
    // 如果未提供标题，使用文本的前几个字
    final displayName = name.isNotEmpty
        ? name
        : (text.length > 20 ? text.substring(0, 20) : text);

    // Two attempts can produce the same hash. Keep the old save and its
    // rollback together so a resumed attempt never loses its new files.
    final precedingSave = _saveLocks[hash];
    final unlocked = Completer<void>();
    final lock = unlocked.future;
    _saveLocks[hash] = lock;
    var handedOff = false;

    void release() {
      if (identical(_saveLocks[hash], lock)) _saveLocks.remove(hash);
      if (!unlocked.isCompleted) unlocked.complete();
    }

    try {
      if (precedingSave != null) await precedingSave;
      if (!isCurrent()) return null;

      // Hash-addressed files may already belong to another gallery record.
      // Keep the old source so a canceled duplicate save cannot replace it.
      final audioExisted = await FileManifest.readFilePath(audioName) != null;
      final previousText = await FileManifest.readFile(textName);
      if (!isCurrent()) return null;

      final record = AudioRecord(
        name: displayName,
        hash: hash,
        format: format,
        createdAt: DateTime.now(),
        size: audioData.length,
        sourceText: text,
        folder: folder,
      );

      var wroteAudio = false;
      var wroteText = false;
      var committed = false;

      Future<void> rollback() async {
        await FileManifest.deleteRecord(record.id);
        final records = await FileManifest.loadRecords();
        if (wroteAudio &&
            !records.any((other) => other.storageFileName == audioName)) {
          if (audioExisted) {
            // deleteRecord removes the entity when this was its sole record.
            if (await FileManifest.readFilePath(audioName) == null) {
              await FileManifest.writeFile(audioName, audioData);
            }
          } else {
            await FileManifest.deleteFile(audioName);
          }
        }
        if (previousText != null) {
          // deleteRecord can remove the shared sidecar even for an empty-text
          // attempt, so restore any source that existed before this save.
          if (wroteText || await FileManifest.readFile(textName) == null) {
            await FileManifest.writeFile(textName, previousText);
          }
        } else if (wroteText && !records.any((other) => other.hash == hash)) {
          await FileManifest.deleteFile(textName);
        }
      }

      try {
        // Write the entity and source before publishing a gallery record.
        await FileManifest.writeFile(audioName, audioData);
        wroteAudio = true;
        if (!isCurrent()) return null;

        if (text.isNotEmpty) {
          await FileManifest.writeFile(
              textName, Uint8List.fromList(utf8.encode(text)));
          wroteText = true;
        }
        if (!isCurrent()) return null;

        await debugBeforeSaveCommit?.call();
        if (!isCurrent()) return null;
        await FileManifest.addRecord(record);
        await debugAfterSaveCommit?.call();
        if (!isCurrent()) return null;

        // Get the file path for the "open file" button.
        final filePath = await FileManifest.readFilePath(audioName);
        if (!isCurrent()) return null;
        committed = true;
        handedOff = true;
        return (filePath: filePath, rollback: rollback, release: release);
      } finally {
        if (!committed) await rollback();
      }
    } finally {
      if (!handedOff) release();
    }
  }

  // ============================================================================
  // 持久化
  // ============================================================================

  Future<void> _persistTasks() {
    final barrier = _removalBarrier;
    if (barrier != null) return barrier.future.then((_) => _persistTasks());
    if (!mounted) {
      final snapshot = _disposedSnapshot;
      if (snapshot == null) return Future<void>.value();
      return _disposedPersistence ??= _writeSnapshot(snapshot).then((_) {});
    }
    return _writeSnapshot(state).then((_) {});
  }

  Future<bool> _writeSnapshot(List<SynthesisTask> snapshot) {
    final previous = _pendingWrite ?? Future<void>.value();
    final write = previous.then((_) async {
      try {
        final file = await _tasksFile();
        final data = snapshot.map((t) => t.toMap()).toList();
        // 原子写入：直接 writeAsString 中途崩溃会留下半截 JSON，
        // 下次启动整个任务列表解析失败。
        await AtomicFile.writeString(file, jsonEncode(data));
        return true;
      } catch (e) {
        debugPrint('[TaskListNotifier] Failed to persist tasks: $e');
        return false;
      }
    });
    _pendingWrite = write.then<void>((_) {});
    return write;
  }

  Future<List<SynthesisTask>> _loadPersistedTasks() async {
    try {
      final file = await _tasksFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list
          .map(
              (m) => SynthesisTask.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      debugPrint('[TaskListNotifier] Failed to load persisted tasks: $e');
      return [];
    }
  }

  Future<File> _tasksFile() async {
    final dirPath = await AppStorage.directory;
    final synthDir = Directory(p.join(dirPath, 'synthesis'));
    try {
      if (!await synthDir.exists()) {
        await synthDir.create(recursive: true);
      }
    } catch (_) {}
    return File(p.join(synthDir.path, 'tasks.json'));
  }

  /// 从持久化恢复所有任务（应用启动时调用）
  Future<void> restoreFromPersistence() async {
    final tasks = await _loadPersistedTasks();
    if (tasks.isEmpty) return;
    state = [
      for (final task in tasks)
        if (task.status == TaskStatus.running)
          task.copyWith(status: TaskStatus.failed, error: '应用重启，已中断')
        else
          task,
    ];
    debugPrint(
        '[TaskListNotifier] Restored ${tasks.length} tasks from persistence');
  }

  @override
  void dispose() {
    _disposedSnapshot = List.of(state);
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) token.cancel();
    }
    _cancelTokens.clear();
    super.dispose();
  }

  /// Parse JSON-type custom param values from string to actual JSON
  /// objects/arrays so they are sent as raw JSON, not quoted strings.
  ///
  /// Non-JSON type params are left unchanged. Invalid JSON strings are kept
  /// as-is (fallback to raw string). Already-parsed values (Map/List) are
  /// not double-parsed.
  @visibleForTesting
  static void parseJsonCustomParams(
      Map<String, dynamic>? params, ModelConfig modelConfig) {
    if (params == null) return;
    for (final cp in modelConfig.customParams) {
      if (cp.type != 'json') continue;
      if (!params.containsKey(cp.paramName)) continue;
      final rawValue = params[cp.paramName];
      if (rawValue is String) {
        try {
          params[cp.paramName] = jsonDecode(rawValue);
        } catch (_) {
          if (rawValue.trim().isNotEmpty) {
            debugPrint(
              '[TaskListNotifier] parseJsonCustomParams: failed to parse '
              '"$rawValue" as JSON for param "${cp.paramName}" — '
              'keeping raw string.',
            );
          }
        }
      }
      // If already a Map/List/num/bool — leave as-is
    }
  }
}
