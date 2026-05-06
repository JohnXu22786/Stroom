import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

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

  // 用于重试的完整参数
  final String text;
  final ProviderConfigItem providerConfig;
  final ModelConfig modelConfig;
  final Map<String, String>? customParams;
  final Map<String, dynamic>? trimPreset;

  SynthesisTask({
    required this.id,
    required this.title,
    this.status = TaskStatus.running,
    this.error,
    DateTime? createdAt,
    this.completedAt,
    required this.text,
    required this.providerConfig,
    required this.modelConfig,
    this.customParams,
    this.trimPreset,
  }) : createdAt = createdAt ?? DateTime.now();

  SynthesisTask copyWith({
    TaskStatus? status,
    String? error,
    DateTime? completedAt,
  }) {
    return SynthesisTask(
      id: id,
      title: title,
      status: status ?? this.status,
      error: error,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      text: text,
      providerConfig: providerConfig,
      modelConfig: modelConfig,
      customParams: customParams,
      trimPreset: trimPreset,
    );
  }
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

      final provider = tts_provider_base.createProviderFromConfig(task.providerConfig);

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
        // 用户主动暂停，不视为错误
        return;
      }
      String errorMsg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg = '网络连接超时，请检查网络或API地址';
          break;
        case DioExceptionType.receiveTimeout:
          errorMsg = '服务器响应超时，请稍后重试';
          break;
        case DioExceptionType.connectionError:
          errorMsg = '无法连接到服务器（${e.message ?? "未知网络错误"}）';
          break;
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode ?? 0;
          final body = e.response?.data;
          errorMsg = 'API返回错误 (HTTP $statusCode${body != null ? ": $body" : ""})';
          break;
        default:
          errorMsg = '合成失败: ${e.message ?? e.toString()}';
      }
      _updateTask(task.id, TaskStatus.failed, error: errorMsg);
    } catch (e) {
      // 如果 token 已取消，忽略其他异常
      if (cancelToken.isCancelled) return;
      final errorMsg = '合成失败: $e';
      _updateTask(task.id, TaskStatus.failed, error: errorMsg);
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

    // 执行
    _executeTask(updated);
  }

  /// 关闭失败任务的错误信息（保留任务记录，仅清除错误字段）
  void dismissError(String taskId) {
    state = state.map((t) {
      if (t.id != taskId || t.status != TaskStatus.failed) return t;
      return t.copyWith(error: null);
    }).toList();
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
  }

  /// 删除单个任务
  void removeTask(String taskId) {
    // 取消正在进行的 HTTP 请求
    final token = _cancelTokens.remove(taskId);
    token?.cancel();
    state = state.where((t) => t.id != taskId).toList();
  }

  void _updateTask(String taskId, TaskStatus status, {String? error}) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        status: status,
        error: error,
        completedAt: status == TaskStatus.completed || status == TaskStatus.failed
            ? DateTime.now()
            : null,
      );
    }).toList();
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
}
