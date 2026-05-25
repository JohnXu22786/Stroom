import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../services/storage_service.dart';

import 'tts_state_provider.dart';
import 'provider_config.dart';
import 'tts_provider.dart' as tts_provider_base;
import '../utils/audio_trim.dart';
import '../utils/audio_utils.dart';
import '../utils/file_manifest.dart';

// ============================================================================
// 任务状态枚举
// ============================================================================

enum TaskStatus { running, completed, failed, paused }

// ============================================================================
// 合成任务模型
// ============================================================================

class SynthesisTask {
  final String id;
  final String title;
  final TaskStatus status;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;

  // 用于重试的完整参数
  final String text;
  final ProviderConfigItem providerConfig;
  final ModelConfig modelConfig;
  final Map<String, String>? customParams;
  final Map<String, dynamic>? trimPreset;

  /// 原始请求体 JSON（用于错误详情展示，不做解析）
  final String? originalRequest;

  /// 原始错误响应体（用于错误详情展示，不做解析）
  final String? originalResponse;

  SynthesisTask({
    required this.id,
    required this.title,
    this.status = TaskStatus.running,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    this.statusChangedAt,
    required this.text,
    required this.providerConfig,
    required this.modelConfig,
    this.customParams,
    this.trimPreset,
    this.originalRequest,
    this.originalResponse,
  }) : createdAt = createdAt ?? DateTime.now();

  SynthesisTask copyWith({
    TaskStatus? status,
    String? error,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    String? originalRequest,
    String? originalResponse,
  }) {
    final newStatus = status ?? this.status;
    final newStatusChangedAt = statusChangedAt ??
        (status != null && status != this.status
            ? DateTime.now()
            : this.statusChangedAt);
    return SynthesisTask(
      id: id,
      title: title,
      status: newStatus,
      error: error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      statusChangedAt: newStatusChangedAt,
      text: text,
      providerConfig: providerConfig,
      modelConfig: modelConfig,
      customParams: customParams,
      trimPreset: trimPreset,
      originalRequest: originalRequest ?? this.originalRequest,
      originalResponse: originalResponse ?? this.originalResponse,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'status': status.name,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'text': text,
        'providerConfig': providerConfig.toMap(),
        'modelConfig': modelConfig.toMap(),
        'customParams': customParams,
        'trimPreset': trimPreset,
        'originalRequest': originalRequest,
        'originalResponse': originalResponse,
      };

  factory SynthesisTask.fromMap(Map<String, dynamic> map) => SynthesisTask(
        id: map['id'] as String,
        title: map['title'] as String,
        status: TaskStatus.values.byName(map['status'] as String),
        error: map['error'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'] as String)
            : null,
        statusChangedAt: map['statusChangedAt'] != null
            ? DateTime.parse(map['statusChangedAt'] as String)
            : null,
        text: map['text'] as String,
        providerConfig:
            ProviderConfigItem.fromMap(map['providerConfig'] as Map<String, dynamic>),
        modelConfig:
            ModelConfig.fromMap(map['modelConfig'] as Map<String, dynamic>),
        customParams: map['customParams'] != null
            ? Map<String, String>.from(map['customParams'] as Map)
            : null,
        trimPreset: map['trimPreset'] != null
            ? Map<String, dynamic>.from(map['trimPreset'] as Map)
            : null,
        originalRequest: map['originalRequest'] as String?,
        originalResponse: map['originalResponse'] as String?,
      );
}

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

  TaskListNotifier(this.ref) : super([]);

  /// 添加一个合成任务并立刻开始后台执行
  String addTask({
    required String title,
    required String text,
    required ProviderConfigItem providerConfig,
    required ModelConfig modelConfig,
    Map<String, String>? customParams,
    Map<String, dynamic>? trimPreset,
  }) {
    final id = _uuid.v4();
    final task = SynthesisTask(
      id: id,
      title: title,
      text: text,
      providerConfig: providerConfig,
      modelConfig: modelConfig,
      customParams: customParams,
      trimPreset: trimPreset,
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

      // 执行合成
      var audioData = await provider.synthesize(
        task.text,
        params: params,
        cancelToken: cancelToken,
      );

      // 如果已被暂停，不再继续处理
      if (cancelToken.isCancelled) return;

      // 格式校验
      var actualFormat = synthConfig.format;
      if (audioData.isNotEmpty) {
        final fixed = ensureValidAudioFormat(
          audioData,
          requestedFormat: synthConfig.format,
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
      await _saveAudioFile(
        audioData,
        actualFormat,
        task.text,
        name: task.title,
      );

      // 更新任务为完成
      _updateTask(task.id, TaskStatus.completed);

      // 刷新文件列表
      ref.read(audioRecordsProvider.notifier).loadRecords();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
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
      if (cancelToken.isCancelled) return;
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
      _cancelTokens.remove(task.id);
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
  void resumeTask(String taskId) {
    final index = state.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    if (state[index].status != TaskStatus.paused) return;

    final task = state[index];
    final updated = task.copyWith(
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

  void _updateTask(String taskId, TaskStatus status,
      {String? error, String? originalRequest, String? originalResponse}) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        status: status,
        error: error,
        originalRequest: originalRequest,
        originalResponse: originalResponse,
        completedAt:
            status == TaskStatus.completed || status == TaskStatus.failed
                ? DateTime.now()
                : null,
      );
    }).toList();
    _persistTasks();
  }

  /// 保存音频文件（与 TTSStateNotifier 逻辑一致）
  Future<AudioRecord> _saveAudioFile(
    Uint8List audioData,
    String format,
    String text, {
    String name = '',
  }) async {
    final hash = computeAudioHash(audioData);
    // 如果未提供标题，使用文本的前几个字
    final displayName = name.isNotEmpty
        ? name
        : (text.length > 20 ? text.substring(0, 20) : text);

    // 写入音频实体文件
    await FileManifest.writeFile('$hash.$format', audioData);

    // 写入源文本文件
    if (text.isNotEmpty) {
      final textBytes = Uint8List.fromList(utf8.encode(text));
      await FileManifest.writeFile('$hash.txt', textBytes);
    }

    final record = AudioRecord(
      name: displayName,
      hash: hash,
      format: format,
      createdAt: DateTime.now(),
      size: audioData.length,
      sourceText: text,
    );

    await FileManifest.addRecord(record);
    return record;
  }

  // ============================================================================
  // 持久化
  // ============================================================================

  Future<void> _persistTasks() async {
    try {
      final file = await _tasksFile();
      final data = state.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[TaskListNotifier] Failed to persist tasks: $e');
    }
  }

  Future<List<SynthesisTask>> _loadPersistedTasks() async {
    try {
      final file = await _tasksFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final list = jsonDecode(content) as List;
      return list
          .map((m) => SynthesisTask.fromMap(Map<String, dynamic>.from(m as Map)))
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
}
