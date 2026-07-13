import '../providers/provider_config.dart';

// ============================================================================
// 任务状态枚举
// ============================================================================

enum TaskStatus { running, completed, failed, paused, waiting }

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

  final String? downloadedFilePath; // File path for "open file" button

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
    this.downloadedFilePath,
  }) : createdAt = createdAt ?? DateTime.now();

  SynthesisTask copyWith({
    TaskStatus? status,
    String? error,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    String? originalRequest,
    String? originalResponse,
    String? downloadedFilePath,
    bool clearDownloadedFilePath = false,
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
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
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
        if (downloadedFilePath != null)
          'downloadedFilePath': downloadedFilePath,
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
        providerConfig: ProviderConfigItem.fromMap(
            map['providerConfig'] as Map<String, dynamic>),
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
        downloadedFilePath: map['downloadedFilePath'] as String?,
      );
}
