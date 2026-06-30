import 'media_resource.dart';

// =============================================================================
// 步骤类型枚举
// =============================================================================

/// 任务执行步骤类型
enum StepType {
  fetching('获取网页内容'),
  analyzing('分析媒体资源'),
  parsingPlaylist('解析播放列表'),
  filtering('按时长筛选'),
  userSelecting('等待用户选择'),
  downloading('下载'),
  converting('转码/合并'),
  saving('保存到本地');

  final String label;
  const StepType(this.label);
}

// =============================================================================
// 步骤状态
// =============================================================================

/// 单个步骤的状态
class StepStatus {
  final StepType type;
  final bool completed;
  final bool running;
  final bool failed;
  final bool skipped;
  final String? error;
  final int progress; // 0-100，仅 running 时有效
  final String? detail; // 步骤执行详情，可点击展开查看

  const StepStatus({
    required this.type,
    this.completed = false,
    this.running = false,
    this.failed = false,
    this.skipped = false,
    this.error,
    this.progress = 0,
    this.detail,
  });

  // ---------------------------------------------------------------------------
  // 便捷构造
  // ---------------------------------------------------------------------------

  /// 初始待机状态
  factory StepStatus.pending(StepType type) => StepStatus(type: type);

  /// 运行中
  factory StepStatus.running(StepType type) =>
      StepStatus(type: type, running: true, progress: 0);

  /// 已完成
  factory StepStatus.done(StepType type, {String? detail}) =>
      StepStatus(type: type, completed: true, progress: 100, detail: detail);

  /// 已跳过（如因为无需转换直接复制）
  factory StepStatus.skipped(StepType type, {String? detail}) =>
      StepStatus(type: type, skipped: true, progress: 100, detail: detail);

  /// 已失败
  factory StepStatus.fail(StepType type, String? error, {String? detail}) =>
      StepStatus(type: type, failed: true, error: error, detail: detail);

  /// 运行中 + 进度
  factory StepStatus.progressing(StepType type, int progress,
          {String? detail}) =>
      StepStatus(type: type, running: true, progress: progress, detail: detail);

  // ---------------------------------------------------------------------------
  // 序列化
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'completed': completed,
        'running': running,
        'failed': failed,
        'skipped': skipped,
        'error': error,
        'progress': progress,
        'detail': detail,
      };

  factory StepStatus.fromMap(Map<String, dynamic> map) => StepStatus(
        type: StepType.values.byName(map['type'] as String),
        completed: map['completed'] as bool? ?? false,
        running: map['running'] as bool? ?? false,
        failed: map['failed'] as bool? ?? false,
        skipped: map['skipped'] as bool? ?? false,
        error: map['error'] as String?,
        progress: map['progress'] as int? ?? 0,
        detail: map['detail'] as String?,
      );

  StepStatus copyWith({
    StepType? type,
    bool? completed,
    bool? running,
    bool? failed,
    bool? skipped,
    String? error,
    int? progress,
    String? detail,
    bool clearError = false,
    bool clearDetail = false,
  }) =>
      StepStatus(
        type: type ?? this.type,
        completed: completed ?? this.completed,
        running: running ?? this.running,
        failed: failed ?? this.failed,
        skipped: skipped ?? this.skipped,
        error: clearError ? null : (error ?? this.error),
        progress: progress ?? this.progress,
        detail: clearDetail ? null : (detail ?? this.detail),
      );

  @override
  String toString() =>
      'StepStatus(${type.label}, completed=$completed, running=$running, '
      'failed=$failed, skipped=$skipped, progress=$progress, error=$error)';
}

// =============================================================================
// 任务整体状态
// =============================================================================

/// 任务整体状态
enum TaskStatus {
  running('运行中'),
  completed('已完成'),
  failed('失败'),
  paused('已暂停');

  final String label;
  const TaskStatus(this.label);
}

// =============================================================================
// 任务模型
// =============================================================================

/// 猫抓下载任务
class CatCatchTask {
  final String id;
  final String url;
  final int expectedDurationSec;
  final String title;
  final TaskStatus status;
  final List<StepStatus> steps;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;
  final List<MediaResource> detectedMedia;
  final MediaResource? selectedMedia;
  final int progress;
  final String? downloadedFilePath;
  final Map<String, String> metadata;

  const CatCatchTask({
    required this.id,
    required this.url,
    required this.expectedDurationSec,
    this.title = '',
    this.status = TaskStatus.running,
    this.steps = const [],
    this.error,
    required this.createdAt,
    this.completedAt,
    this.statusChangedAt,
    this.detectedMedia = const [],
    this.selectedMedia,
    this.progress = 0,
    this.downloadedFilePath,
    this.metadata = const {},
  });

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  CatCatchTask copyWith({
    String? id,
    String? url,
    int? expectedDurationSec,
    String? title,
    TaskStatus? status,
    List<StepStatus>? steps,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    List<MediaResource>? detectedMedia,
    MediaResource? selectedMedia,
    int? progress,
    String? downloadedFilePath,
    Map<String, String>? metadata,
    bool clearError = false,
    bool clearCompletedAt = false,
    bool clearDownloadedFilePath = false,
    bool clearSelectedMedia = false,
  }) {
    final newStatus = status ?? this.status;
    final newStatusChangedAt = statusChangedAt ??
        (status != null && status != this.status
            ? DateTime.now()
            : this.statusChangedAt);

    return CatCatchTask(
      id: id ?? this.id,
      url: url ?? this.url,
      expectedDurationSec: expectedDurationSec ?? this.expectedDurationSec,
      title: title ?? this.title,
      status: newStatus,
      steps: steps ?? this.steps,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      statusChangedAt: newStatusChangedAt,
      detectedMedia: detectedMedia ?? this.detectedMedia,
      selectedMedia:
          clearSelectedMedia ? null : (selectedMedia ?? this.selectedMedia),
      progress: progress ?? this.progress,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      metadata: metadata ?? this.metadata,
    );
  }

  // ---------------------------------------------------------------------------
  // 序列化
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'expectedDurationSec': expectedDurationSec,
        'title': title,
        'status': status.name,
        'steps': steps.map((s) => s.toMap()).toList(),
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'detectedMedia': detectedMedia.map((m) => m.toMap()).toList(),
        'selectedMedia': selectedMedia?.toMap(),
        'progress': progress,
        'downloadedFilePath': downloadedFilePath,
        'metadata': metadata,
      };

  factory CatCatchTask.fromMap(Map<String, dynamic> map) => CatCatchTask(
        id: map['id'] as String,
        url: map['url'] as String,
        expectedDurationSec: map['expectedDurationSec'] as int,
        title: map['title'] as String? ?? '',
        status: TaskStatus.values.byName(map['status'] as String? ?? 'running'),
        steps: (map['steps'] as List?)
                ?.map((s) =>
                    StepStatus.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [],
        error: map['error'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'] as String)
            : null,
        statusChangedAt: map['statusChangedAt'] != null
            ? DateTime.tryParse(map['statusChangedAt'] as String)
            : null,
        detectedMedia: (map['detectedMedia'] as List?)
                ?.map((m) =>
                    MediaResource.fromMap(Map<String, dynamic>.from(m as Map)))
                .toList() ??
            [],
        selectedMedia: map['selectedMedia'] != null
            ? MediaResource.fromMap(
                Map<String, dynamic>.from(map['selectedMedia'] as Map))
            : null,
        progress: map['progress'] as int? ?? 0,
        downloadedFilePath: map['downloadedFilePath'] as String?,
        metadata: Map<String, String>.from(map['metadata'] as Map? ?? {}),
      );

  @override
  String toString() =>
      'CatCatchTask(id=$id, title=$title, status=${status.label}, progress=$progress)';
}
