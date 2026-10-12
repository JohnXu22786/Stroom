import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../models/ocr_batch_execution.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ios_continued_task_service.dart';
import '../services/ocr_retry_storage.dart';
import '../pages/ocr/ocr_retry_snapshot.dart';
import '../utils/atomic_file.dart';
import '../utils/ocr_diagnostics.dart';
import 'task_provider.dart';

// ============================================================================
// Background Task Type
// ============================================================================

/// The type of background operation being tracked.
enum BackgroundTaskType {
  ocr,
  asr,
  audioSeparation,
  chat;

  String get label {
    switch (this) {
      case BackgroundTaskType.ocr:
        return '文字识别';
      case BackgroundTaskType.asr:
        return '音频转写';
      case BackgroundTaskType.audioSeparation:
        return '音频分离';
      case BackgroundTaskType.chat:
        return '助手对话';
    }
  }

  /// Steps appropriate for each task type (used for step chain display).
  List<String> get stepLabels {
    switch (this) {
      case BackgroundTaskType.ocr:
        // OCR: single request with all images
        return ['连接服务器', '上传图片', '等待识别结果', '解析结果', '保存文件'];
      case BackgroundTaskType.asr:
        // ASR: one request per file, each file is a separate task
        return ['连接服务器', '上传音频', '转写中', '接收结果', '保存文件'];
      case BackgroundTaskType.audioSeparation:
        // Audio Separation: local processing only, no API
        return ['分离音频', '保存到文件'];
      case BackgroundTaskType.chat:
        // Chat/Assistant: API call
        return ['发送请求', '等待回复', '接收结果'];
    }
  }
}

// ============================================================================
// Step Status for Background Tasks
// ============================================================================

/// Simplified step status enum (without progress quantification).
enum BgStepStatus { pending, running, completed, failed, skipped }

/// A single step in a background task's step chain.
/// No progress bar — just shows status: pending, running, completed, failed, or skipped.
class BgTaskStep {
  final String label;
  final BgStepStatus status;
  final String? error;

  const BgTaskStep({
    required this.label,
    this.status = BgStepStatus.pending,
    this.error,
  });

  bool get completed => status == BgStepStatus.completed;
  bool get running => status == BgStepStatus.running;
  bool get failed => status == BgStepStatus.failed;
  bool get skipped => status == BgStepStatus.skipped;

  BgTaskStep copyWith({
    BgStepStatus? status,
    String? error,
    bool clearError = false,
    String? label,
  }) =>
      BgTaskStep(
        label: label ?? this.label,
        status: status ?? this.status,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'status': status.name,
        if (error != null) 'error': error,
      };

  factory BgTaskStep.fromMap(Map<String, dynamic> map) => BgTaskStep(
        label: map['label'] as String,
        status:
            BgStepStatus.values.byName(map['status'] as String? ?? 'pending'),
        error: map['error'] as String?,
      );
}

// ============================================================================
// Background Task Model
// ============================================================================

Map<String, dynamic>? _sanitizeOcrTaskRequest(
  Map<String, dynamic>? rawRequest, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(rawRequest),
    ...additionalCredentialValues,
  }.toList();
  Map<String, dynamic>? safeSource = _removeMaskedOcrDiagnosticValues(
    rawRequest,
    credentialValues,
  );
  final endpoint = safeSource?['host'] ?? safeSource?['url'];
  if (endpoint is String &&
      _legacyOcrTextContainsCredential(endpoint, credentialValues)) {
    safeSource = Map<String, dynamic>.from(safeSource!)
      ..remove('host')
      ..remove('url');
  }
  return OcrDiagnosticSnapshot.sanitizeRequest(
    safeSource,
    excludedValues: credentialValues,
  );
}

Map<String, dynamic>? _sanitizeOcrTaskResponse(
  Map<String, dynamic>? rawResponse,
  Map<String, dynamic>? rawRequest, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(rawRequest),
    ...additionalCredentialValues,
  }.toList();
  final safeSource = _removeMaskedOcrDiagnosticValues(
    rawResponse,
    credentialValues,
    includeResponseData: true,
  );
  return OcrDiagnosticSnapshot.sanitizeResponse(
    safeSource,
    excludedValues: credentialValues,
  );
}

Map<String, dynamic>? _removeMaskedOcrDiagnosticValues(
  Map<String, dynamic>? source,
  Iterable<String> credentialValues, {
  bool includeResponseData = false,
}) {
  if (source == null) return null;
  final safeSource = Map<String, dynamic>.from(source);
  bool matchesMaskedCredential(dynamic value) =>
      value is String &&
      _legacyOcrTextContainsMaskedCredential(value, credentialValues);

  for (final field in ['requestId', 'finishReason', 'finish_reason']) {
    if (matchesMaskedCredential(safeSource[field])) safeSource.remove(field);
  }

  final headers = safeSource['headers'];
  if (headers is Map) {
    final safeHeaders = Map<dynamic, dynamic>.from(headers);
    for (final entry in headers.entries) {
      if (entry.key is! String) continue;
      final requestId = OcrDiagnosticSnapshot.requestIdFromHeaders({
        entry.key: entry.value,
      });
      if (requestId != null && matchesMaskedCredential(requestId)) {
        safeHeaders.remove(entry.key);
      }
    }
    safeSource['headers'] = safeHeaders;
  }

  final data = safeSource['data'];
  if (includeResponseData && data is Map) {
    final safeData = Map<dynamic, dynamic>.from(data);
    for (final field in ['request_id', 'requestId', 'id']) {
      if (matchesMaskedCredential(safeData[field])) safeData.remove(field);
    }
    final choices = safeData['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final firstChoice = Map<dynamic, dynamic>.from(choices.first as Map);
      if (matchesMaskedCredential(firstChoice['finish_reason'])) {
        firstChoice.remove('finish_reason');
        final safeChoices = List<dynamic>.from(choices)..[0] = firstChoice;
        safeData['choices'] = safeChoices;
      }
    }
    safeSource['data'] = safeData;
  }
  return safeSource;
}

String? _sanitizeOcrTaskError(
  String? error,
  Map<String, dynamic>? rawRequest, {
  Iterable<String> additionalCredentialValues = const [],
}) {
  final credentialValues = <String>{
    ..._legacyOcrCredentialValues(rawRequest),
    ...additionalCredentialValues,
  }.toList();
  if (error != null &&
      _legacyOcrTextContainsMaskedCredential(error, credentialValues)) {
    return 'OCR 错误详情已隐藏';
  }
  return OcrDiagnosticSnapshot.sanitizeStoredTaskError(
    error,
    excludedValues: credentialValues,
  );
}

Map<String, dynamic> _unavailableOcrRetryData(
  String taskId,
  OcrRetrySnapshot snapshot,
) =>
    OcrRetryStorage.unavailableSnapshot(taskId: taskId, snapshot: snapshot);

const _maxRecoverableLegacyOcrImageCount = 1000;

int? _legacyOcrImageCount(Map<String, dynamic>? rawRequest) {
  if (rawRequest == null) return null;
  final storedCount = rawRequest['imageCount'];
  if (storedCount is int &&
      storedCount > 0 &&
      storedCount <= _maxRecoverableLegacyOcrImageCount) {
    return storedCount;
  }

  final body = rawRequest['body'];
  if (body is! Map || body['messages'] is! List) return null;
  var imageCount = 0;
  for (final message in body['messages'] as List) {
    if (message is! Map || message['content'] is! List) continue;
    for (final part in message['content'] as List) {
      if (part is Map &&
          (part['type'] == 'image_url' ||
              part['type'] == 'image' ||
              part.containsKey('image_url'))) {
        imageCount++;
      }
    }
  }
  return imageCount > 0 && imageCount <= _maxRecoverableLegacyOcrImageCount
      ? imageCount
      : null;
}

String? _legacyOcrModelId(Map<String, dynamic>? rawRequest) {
  final body = rawRequest?['body'];
  final modelId = body is Map ? body['model'] : null;
  if (modelId is! String) return null;
  final value = modelId.trim();
  final credentialValues = _legacyOcrCredentialValues(rawRequest).toList();
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:/-]{0,127}$').hasMatch(value) ||
      RegExp(
        r'^(?:sk-(?:proj-|ant-api\d{2}-|or-v1-)?[a-z0-9]{8,}|gsk_[a-z0-9]{8,}|gh[pousr]_[a-z0-9]{8,}|AIza[a-z0-9_-]{20,})$',
        caseSensitive: false,
      ).hasMatch(value) ||
      _legacyOcrTextContainsCredential(value, credentialValues)) {
    return null;
  }
  return value;
}

Iterable<String> _legacyOcrCredentialValues(Map<String, dynamic>? rawRequest) =>
    OcrDiagnosticSnapshot.credentialValuesFromRequest(rawRequest);

bool _legacyOcrTextContainsCredential(
  String text,
  Iterable<String> credentialValues,
) {
  if (OcrDiagnosticSnapshot.containsCredential(
    text,
    excludedValues: credentialValues,
  )) {
    return true;
  }
  return _legacyOcrTextContainsMaskedCredential(text, credentialValues);
}

bool _legacyOcrTextContainsMaskedCredential(
  String text,
  Iterable<String> credentialValues,
) {
  // Legacy request headers may contain only a masked key; compare its visible
  // edges before preserving any persisted text or diagnostic value.
  final compactedText = text.replaceAll(RegExp(r'\s+'), '');
  for (final value in credentialValues) {
    final ellipsis = RegExp(r'\.\.\.|…').firstMatch(value);
    if (ellipsis != null) {
      final prefix = value.substring(0, ellipsis.start);
      final suffix = value.substring(ellipsis.end);
      if (prefix.isNotEmpty &&
          suffix.isNotEmpty &&
          RegExp(
            '${RegExp.escape(prefix)}\\S+${RegExp.escape(suffix)}',
          ).hasMatch(compactedText)) {
        return true;
      }
      continue;
    }
    final mask = value.indexOf('*');
    if (mask < 0) continue;
    final prefix = value.substring(0, mask);
    // A very short visible prefix is too common to identify a credential in
    // free text; the general credential-shape checks above still redact
    // explicit assignments and recognizable tokens.
    if (prefix.length >= 4 &&
        RegExp('${RegExp.escape(prefix)}\\S{1,12}').hasMatch(compactedText)) {
      return true;
    }
  }
  return false;
}

String? _legacyOcrInstructionContent(Map<String, dynamic>? rawRequest) {
  final body = rawRequest?['body'];
  if (body is! Map || body['messages'] is! List) return null;
  final credentialValues = _legacyOcrCredentialValues(rawRequest).toList();
  final textParts = <String>[];
  for (final message in body['messages'] as List) {
    if (message is! Map ||
        message['role'] != 'user' ||
        message['content'] is! List) {
      continue;
    }
    for (final part in message['content'] as List) {
      if (part is Map && part['type'] == 'text' && part['text'] is String) {
        final text = part['text'] as String;
        if (!_legacyOcrTextContainsCredential(text, credentialValues)) {
          textParts.add(text);
        }
      }
    }
  }
  if (textParts.isEmpty) return null;
  final instruction = textParts.join('\n');
  if (instruction.length > 10000 ||
      RegExp(
        r'(?:data:image/|base64,)',
        caseSensitive: false,
      ).hasMatch(instruction) ||
      _legacyOcrTextContainsCredential(instruction, credentialValues)) {
    return null;
  }
  return instruction;
}

Map<String, dynamic>? _unavailableRetryDataFromLegacyRequest(
  String taskId,
  Map<String, dynamic>? rawRequest,
) {
  final imageCount = _legacyOcrImageCount(rawRequest);
  final modelId = _legacyOcrModelId(rawRequest);
  final instructionContent = _legacyOcrInstructionContent(rawRequest);
  if (imageCount == null && modelId == null && instructionContent == null) {
    return null;
  }
  return OcrRetryStorage.unavailableSnapshotForCount(
    taskId: taskId,
    imageCount: imageCount ?? 0,
    modelId: modelId,
    instructionContent: instructionContent,
  );
}

Map<String, dynamic>? _retryDataFromTaskMap(Map<String, dynamic> map) {
  final taskId = map['id'] as String;
  final rawRetryData = map['retryData'];
  if (rawRetryData is Map) {
    try {
      return Map<String, dynamic>.from(rawRetryData);
    } catch (_) {
      // Fall through to a safe unavailable snapshot instead of dropping task.
    }
  }
  if (map['type'] != BackgroundTaskType.ocr.name) return null;

  final rawRequest = map['rawRequest'];
  final request =
      rawRequest is Map ? Map<String, dynamic>.from(rawRequest) : null;
  return _unavailableRetryDataFromLegacyRequest(taskId, request) ??
      (rawRetryData == null
          ? null
          : OcrRetryStorage.unavailableSnapshotForCount(
              taskId: taskId,
              imageCount: 0,
            ));
}

List<OcrPageOutcome> _ocrPageOutcomesFromTaskMap(dynamic rawOutcomes) {
  if (rawOutcomes is! List) return const [];
  final outcomes = <OcrPageOutcome>[];
  for (final rawOutcome in rawOutcomes) {
    final outcome = OcrPageOutcome.fromMap(rawOutcome);
    if (outcome != null) outcomes.add(outcome);
  }
  outcomes.sort((a, b) => a.imageIndex.compareTo(b.imageIndex));
  return List.unmodifiable(outcomes);
}

/// A task model for OCR, ASR, and Audio Separation operations.
/// Uses a step chain (like CatCatch downloads) to show execution progress
/// without quantifying with percentages. Steps are task-type-specific.
class BackgroundTask {
  final String id;
  final BackgroundTaskType type;
  final String title;
  final TaskStatus status;
  final String?
      result; // The text result (OCR extracted text, ASR transcription) — kept internally for saving
  final bool resultIsComplete;
  final String resultFolder;
  final bool partialSaveRequested;
  final bool resultSavedAsPartial;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? statusChangedAt;
  final List<BgTaskStep> steps; // Step chain for UI display
  final String?
      downloadedFilePath; // File path for "open file" button (like CatCatch)
  final Map<String, dynamic>?
      rawRequest; // Raw request data for error diagnostics
  final Map<String, dynamic>?
      rawResponse; // Raw response data for error diagnostics
  final List<String> _ocrDiagnosticCredentialValues;
  final Map<String, dynamic>?
      retryData; // Retry data to pre-populate form when retrying
  final List<OcrPageOutcome> ocrPageOutcomes;

  BackgroundTask({
    required this.id,
    required this.type,
    required this.title,
    this.status = TaskStatus.running,
    this.result,
    this.resultIsComplete = true,
    this.resultFolder = '',
    this.partialSaveRequested = false,
    this.resultSavedAsPartial = false,
    String? error,
    DateTime? createdAt,
    this.completedAt,
    this.statusChangedAt,
    List<BgTaskStep> steps = const [],
    this.downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    this.retryData,
    List<OcrPageOutcome> ocrPageOutcomes = const [],
    Iterable<String> ocrDiagnosticCredentialValues = const [],
  })  : error = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskError(
                error,
                rawRequest,
                additionalCredentialValues: ocrDiagnosticCredentialValues,
              )
            : error,
        steps = type == BackgroundTaskType.ocr
            ? steps
                .map(
                  (step) => BgTaskStep(
                    label: step.label,
                    status: step.status,
                    error: _sanitizeOcrTaskError(
                      step.error,
                      rawRequest,
                      additionalCredentialValues: ocrDiagnosticCredentialValues,
                    ),
                  ),
                )
                .toList(growable: false)
            : steps,
        _ocrDiagnosticCredentialValues = type == BackgroundTaskType.ocr
            ? List<String>.unmodifiable({
                ..._legacyOcrCredentialValues(rawRequest),
                ...ocrDiagnosticCredentialValues,
              })
            : const [],
        rawRequest = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskRequest(
                rawRequest,
                additionalCredentialValues: ocrDiagnosticCredentialValues,
              )
            : rawRequest,
        rawResponse = type == BackgroundTaskType.ocr
            ? _sanitizeOcrTaskResponse(
                rawResponse,
                rawRequest,
                additionalCredentialValues: ocrDiagnosticCredentialValues,
              )
            : rawResponse,
        ocrPageOutcomes = type == BackgroundTaskType.ocr
            ? List.unmodifiable(
                ocrPageOutcomes.map(
                  (outcome) => OcrPageOutcome(
                    imageIndex: outcome.imageIndex,
                    status: outcome.status,
                    text: outcome.text,
                    error: _sanitizeOcrTaskError(
                      outcome.error,
                      rawRequest,
                      additionalCredentialValues: ocrDiagnosticCredentialValues,
                    ),
                  ),
                ),
              )
            : const [],
        createdAt = createdAt ?? DateTime.now();

  BackgroundTask copyWith({
    TaskStatus? status,
    String? result,
    bool? resultIsComplete,
    String? resultFolder,
    bool? partialSaveRequested,
    bool? resultSavedAsPartial,
    String? error,
    DateTime? completedAt,
    DateTime? statusChangedAt,
    List<BgTaskStep>? steps,
    String? downloadedFilePath,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
    Map<String, dynamic>? retryData,
    List<OcrPageOutcome>? ocrPageOutcomes,
    bool clearError = false,
    bool clearCompletedAt = false,
    bool clearDownloadedFilePath = false,
    bool clearRawRequest = false,
    bool clearRawResponse = false,
    bool clearRetryData = false,
  }) {
    final newStatus = status ?? this.status;
    final newStatusChangedAt = statusChangedAt ??
        (status != null && status != this.status
            ? DateTime.now()
            : this.statusChangedAt);
    return BackgroundTask(
      id: id,
      type: type,
      title: title,
      status: newStatus,
      result: result ?? this.result,
      resultIsComplete: resultIsComplete ?? this.resultIsComplete,
      resultFolder: resultFolder ?? this.resultFolder,
      partialSaveRequested: partialSaveRequested ?? this.partialSaveRequested,
      resultSavedAsPartial: resultSavedAsPartial ?? this.resultSavedAsPartial,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      statusChangedAt: newStatusChangedAt,
      steps: steps ?? this.steps,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
      rawRequest: clearRawRequest ? null : (rawRequest ?? this.rawRequest),
      rawResponse: clearRawResponse ? null : (rawResponse ?? this.rawResponse),
      ocrPageOutcomes: ocrPageOutcomes ?? this.ocrPageOutcomes,
      ocrDiagnosticCredentialValues: _ocrDiagnosticCredentialValues,
      retryData: clearRetryData ? null : (retryData ?? this.retryData),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'status': status.name,
        if (result != null) 'result': result,
        'resultIsComplete': resultIsComplete,
        if (resultFolder.isNotEmpty) 'resultFolder': resultFolder,
        'partialSaveRequested': partialSaveRequested,
        'resultSavedAsPartial': resultSavedAsPartial,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'steps': steps.map((s) => s.toMap()).toList(),
        if (downloadedFilePath != null)
          'downloadedFilePath': downloadedFilePath,
        if (rawRequest != null) 'rawRequest': rawRequest,
        if (rawResponse != null) 'rawResponse': rawResponse,
        if (retryData != null) 'retryData': retryData,
        if (ocrPageOutcomes.isNotEmpty)
          'ocrPageOutcomes':
              ocrPageOutcomes.map((outcome) => outcome.toMap()).toList(),
      };

  factory BackgroundTask.fromMap(Map<String, dynamic> map) => BackgroundTask(
        id: map['id'] as String,
        type: BackgroundTaskType.values.byName(map['type'] as String),
        title: map['title'] as String,
        status: TaskStatus.values.byName(map['status'] as String),
        result: map['result'] as String?,
        resultIsComplete: map['resultIsComplete'] as bool? ??
            !((map['error'] as String? ?? '').contains('finish_reason=length')),
        resultFolder: map['resultFolder'] as String? ?? '',
        partialSaveRequested: map['partialSaveRequested'] as bool? ?? false,
        resultSavedAsPartial: map['resultSavedAsPartial'] as bool? ?? false,
        error: map['error'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'] as String)
            : null,
        statusChangedAt: map['statusChangedAt'] != null
            ? DateTime.parse(map['statusChangedAt'] as String)
            : null,
        steps: (map['steps'] as List?)
                ?.map(
                  (s) => BgTaskStep.fromMap(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList() ??
            [],
        downloadedFilePath: map['downloadedFilePath'] as String?,
        rawRequest: map['rawRequest'] as Map<String, dynamic>?,
        rawResponse: map['rawResponse'] as Map<String, dynamic>?,
        retryData: _retryDataFromTaskMap(map),
        ocrPageOutcomes: _ocrPageOutcomesFromTaskMap(
          map['ocrPageOutcomes'],
        ),
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
  final Map<String, void Function()> _cancellations = {};

  /// Returns a live task by ID, or null after removal or notifier disposal.
  BackgroundTask? taskById(String taskId) {
    if (!mounted) return null;
    return state.where((task) => task.id == taskId).firstOrNull;
  }

  /// Only live owned operations register callbacks; restored records do not.
  void registerCancellation(String taskId, void Function() cancel) {
    if (!mounted || !state.any((task) => task.id == taskId)) {
      cancel();
      return;
    }
    _cancellations[taskId] = cancel;
  }

  void unregisterCancellation(String taskId) => _cancellations.remove(taskId);

  void cancelTask(String taskId) {
    final cancel = _cancellations.remove(taskId);
    if (cancel == null) return;
    cancel();
    if (!mounted) return;
    final task = state.where((task) => task.id == taskId).firstOrNull;
    if (task == null) return;
    setSteps(
      taskId,
      task.steps
          .map(
            (step) => step.copyWith(
              status: step.running
                  ? BgStepStatus.failed
                  : step.status == BgStepStatus.pending
                      ? BgStepStatus.skipped
                      : step.status,
            ),
          )
          .toList(),
    );
    failTask(taskId, error: '已取消');
  }

  /// 测试专用：覆盖持久化目录。
  ///
  /// 持久化测试需要隔离的目录（真实测试环境所有测试共享同一个
  /// AppStorage 目录，异步写入链可能跨测试交错，导致读脏数据）。
  @visibleForTesting
  static String? debugStorageDirectoryOverride;

  @visibleForTesting
  static Future<void> Function()? debugBeforeOcrCacheCleanup;

  @visibleForTesting
  static Future<void> Function()? debugBeforeOcrCacheDelete;

  @visibleForTesting
  static Future<void> Function()? debugBeforeTaskSnapshotWrite;

  BackgroundTaskNotifier() : super([]);

  @override
  void dispose() {
    for (final cancel in _cancellations.values.toList()) {
      cancel();
    }
    _cancellations.clear();
    _disposedSnapshot = List.of(state);
    _iosSyncTimer?.cancel();
    _iosSyncTimer = null;
    super.dispose();
  }

  /// Add a new background task and return its ID.
  /// Initializes default step chain based on task type.
  /// [retryData] stores the original input parameters (images, audio, model, etc.)
  /// so the retry flow can pre-populate the form.
  /// When [startImmediately] is true (default), the task starts as [TaskStatus.running].
  /// When false, the task starts as [TaskStatus.waiting] and can be started later via [startTask].
  String addTask({
    required BackgroundTaskType type,
    required String title,
    Map<String, dynamic>? retryData,
    bool startImmediately = true,
    String? taskId,
  }) {
    final id = taskId ?? _uuid.v4();
    final steps = type.stepLabels
        .map((label) => BgTaskStep(label: label, status: BgStepStatus.pending))
        .toList();
    final task = BackgroundTask(
      id: id,
      type: type,
      title: title,
      status: startImmediately ? TaskStatus.running : TaskStatus.waiting,
      steps: steps,
      retryData: retryData,
    );
    state = [task, ...state];
    _persistTasks();
    _syncIosContinuedTask();
    return id;
  }

  /// Start a waiting task — transitions it from [TaskStatus.waiting] to [TaskStatus.running].
  /// Does nothing if the task is not in waiting status (e.g. already running/completed).
  void startTask(String taskId) {
    startTaskIfWaiting(taskId);
  }

  /// Atomically claim a waiting task for execution.
  ///
  /// A queue uses the return value to avoid starting a task removed or
  /// canceled while it was waiting.
  bool startTaskIfWaiting(String taskId) {
    final index = state.indexWhere((task) => task.id == taskId);
    if (index == -1 || state[index].status != TaskStatus.waiting) return false;
    final tasks = [...state];
    tasks[index] = tasks[index].copyWith(
      status: TaskStatus.running,
      statusChangedAt: DateTime.now(),
    );
    state = tasks;
    _persistTasks();
    _syncIosContinuedTask();
    return true;
  }

  /// Mark a task as completed and keep it in the list (visible to user).
  /// Optionally provide [downloadedFilePath] for the "open file" button.
  void completeTask(
    String taskId, {
    String? downloadedFilePath,
    bool resultSavedAsPartial = false,
  }) {
    _updateTask(
      taskId,
      TaskStatus.completed,
      downloadedFilePath: downloadedFilePath,
      resultSavedAsPartial: resultSavedAsPartial,
    );
  }

  /// Mark a task as failed with an optional error message.
  void failTask(
    String taskId, {
    String? error,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    _updateTask(
      taskId,
      TaskStatus.failed,
      error: error,
      rawRequest: rawRequest,
      rawResponse: rawResponse,
    );
  }

  /// Set the result text for a task (OCR extracted text, ASR transcription, etc.).
  /// Can be called multiple times to update partial/intermediate results.
  /// The result is kept internally for file saving but NOT displayed in the card UI.
  void setResult(
    String taskId,
    String result, {
    bool isComplete = true,
    String? folder,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(
        result: result,
        resultIsComplete: isComplete,
        resultFolder: folder,
        error: t.error,
      );
    }).toList();
    _persistTasks();
  }

  /// Persist ordered per-image status so task cards and retries keep context.
  void setOcrPageOutcomes(String taskId, List<OcrPageOutcome> outcomes) {
    final ordered = outcomes.toList()
      ..sort((a, b) => a.imageIndex.compareTo(b.imageIndex));
    state = state
        .map(
          (task) => task.id == taskId
              ? task.copyWith(ocrPageOutcomes: List.unmodifiable(ordered))
              : task,
        )
        .toList();
    _persistTasks();
  }

  /// Persist the explicit user choice to save an incomplete OCR result.
  void markPartialResultSaveRequested(String taskId) {
    state = state
        .map(
          (task) => task.id == taskId
              ? task.copyWith(partialSaveRequested: true)
              : task,
        )
        .toList();
    _persistTasks();
  }

  /// Reopen the save step for a failed OCR task whose result is still present.
  void startSaveRetry(String taskId) {
    state = state.map((task) {
      if (task.id != taskId ||
          task.type != BackgroundTaskType.ocr ||
          task.status != TaskStatus.failed ||
          task.result == null) {
        return task;
      }
      final steps = [...task.steps];
      if (steps.length > 4) {
        steps[4] = steps[4].copyWith(
          status: BgStepStatus.running,
          clearError: true,
        );
      }
      return task.copyWith(
        status: TaskStatus.running,
        clearError: true,
        clearCompletedAt: true,
        statusChangedAt: DateTime.now(),
        steps: steps,
      );
    }).toList();
    _persistTasks();
    _syncIosContinuedTask();
  }

  /// Set the full step chain for a task.
  void setSteps(String taskId, List<BgTaskStep> steps) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(steps: steps);
    }).toList();
    _persistTasks();
    _syncIosContinuedTask();
  }

  /// Set raw request/response diagnostic data for error viewing.
  void setRawDiagnostics(
    String taskId, {
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(rawRequest: rawRequest, rawResponse: rawResponse);
    }).toList();
    _persistTasks();
  }

  /// Update a single step by index (e.g. mark as completed/running/failed).
  void updateStep(
    String taskId,
    int index, {
    bool? completed,
    bool? running,
    bool? failed,
    bool? skipped,
    String? error,
    String? label,
  }) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      final steps = [...t.steps];
      if (index < 0 || index >= steps.length) return t;
      BgStepStatus newStatus;
      if (completed == true) {
        newStatus = BgStepStatus.completed;
      } else if (running == true) {
        newStatus = BgStepStatus.running;
      } else if (failed == true) {
        newStatus = BgStepStatus.failed;
      } else if (skipped == true) {
        newStatus = BgStepStatus.skipped;
      } else {
        return t; // no change
      }
      steps[index] = steps[index].copyWith(
        status: newStatus,
        error: error,
        label: label,
      );
      return t.copyWith(steps: steps);
    }).toList();
    _persistTasks();
    _syncIosContinuedTask();
  }

  /// Remove a task from the list.
  void removeTask(String taskId) {
    if (_taskSnapshotIncomplete) {
      if (!state.any((task) => task.id == taskId)) return;
      // Keep the task visible until a partial snapshot can be safely written,
      // so the UI cannot claim a deletion that will return on restart.
      unawaited(removeTasksPersisted([taskId]));
      return;
    }
    _cancellations.remove(taskId)?.call();
    final removed = state.where((task) => task.id == taskId).firstOrNull;
    state = state.where((t) => t.id != taskId).toList();
    if (removed?.type == BackgroundTaskType.ocr && removed?.retryData != null) {
      final references = OcrRetryStorage.referencesFromSnapshot(
        removed!.retryData,
      );
      _persistOcrTaskRemoval(references);
    } else {
      _persistTasks();
    }
    _syncIosContinuedTask();
  }

  /// Save removals before publishing them; absent IDs also retry disk cleanup.
  Future<bool> removeTasksPersisted(Iterable<String> ids) async {
    final removedIds = ids.toSet();
    for (final id in removedIds) {
      cancelTask(id);
    }
    while (_removalBarrier != null) {
      await _removalBarrier!.future;
    }
    if (!mounted) return false;
    if (removedIds.isEmpty) return true;

    final gate = Completer<void>();
    _removalBarrier = gate;
    try {
      final removedTasks =
          state.where((task) => removedIds.contains(task.id)).toList();
      final proposed = state.where((t) => !removedIds.contains(t.id)).toList();
      if (!await _writeSnapshot(
        proposed,
        preserveSkippedEntries: _taskSnapshotIncomplete,
      )) {
        return false;
      }
      final cacheCandidates = <String>{
        for (final task in removedTasks)
          if (task.type == BackgroundTaskType.ocr)
            ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
      };
      final currentTasks = mounted ? state : (_disposedSnapshot ?? const []);
      cacheCandidates.addAll({
        for (final task in currentTasks)
          if (removedIds.contains(task.id) &&
              task.type == BackgroundTaskType.ocr)
            ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
      });
      if (mounted) {
        state = state.where((t) => !removedIds.contains(t.id)).toList();
        _syncIosContinuedTask();
      }
      if (!mounted) {
        // Deferred ordinary writes own this snapshot after disposal. Only a
        // successful removal may remove these IDs from its final flush.
        _disposedSnapshot = _disposedSnapshot
            ?.where((task) => !removedIds.contains(task.id))
            .toList();
      }
      await _deleteUnreferencedOcrCache(cacheCandidates);
      return true;
    } finally {
      _removalBarrier = null;
      gate.complete();
    }
  }

  Future<void> _deleteUnreferencedOcrCache(Set<String> candidates) async {
    if (candidates.isEmpty) return;
    try {
      await OcrRetryStorage.withCacheMaintenanceLock(() async {
        await debugBeforeOcrCacheDelete?.call();
        final referenced = await _ocrCacheReferencesForCleanup();
        if (referenced == null) return;
        await OcrRetryStorage.deleteUnreferenced(
          candidates: candidates,
          referenced: referenced,
        );
      });
    } catch (error) {
      debugPrint('[BackgroundTaskNotifier] OCR cache cleanup failed: $error');
    }
  }

  Future<void> _cleanupOrphanedOcrCache() async {
    if (_taskSnapshotIncomplete) return;
    try {
      await OcrRetryStorage.withCacheMaintenanceLock(() async {
        final beforeCleanup = debugBeforeOcrCacheCleanup;
        if (beforeCleanup != null) await beforeCleanup();
        final referenced = await _ocrCacheReferencesForCleanup();
        if (referenced == null) return;
        await OcrRetryStorage.cleanupUnreferencedCache(referenced: referenced);
      });
    } catch (error) {
      debugPrint('[BackgroundTaskNotifier] OCR cache sweep failed: $error');
    }
  }

  Future<void> _persistOcrTaskRemoval(Set<String> references) {
    final barrier = _removalBarrier;
    if (barrier == null) {
      final write = _writeSnapshot(state);
      return _pendingWrite = write.then<void>((saved) async {
        if (saved) {
          await _deleteUnreferencedOcrCache(references);
          await _cleanupOrphanedOcrCache();
        }
      });
    }

    final previous = _pendingWrite ?? Future<void>.value();
    final dirOverride = debugStorageDirectoryOverride;
    final deferred = previous.then((_) async {
      await barrier.future;
      final snapshot = mounted ? state : _disposedSnapshot;
      if (snapshot == null) return;
      final saved = await _writeSnapshotNow(snapshot, dirOverride);
      if (saved) {
        await _deleteUnreferencedOcrCache(references);
        await _cleanupOrphanedOcrCache();
      }
    });
    _pendingWrite = deferred;
    if (!mounted) _disposedPersistence = deferred;
    return deferred;
  }

  /// Update the retry data for a task (used to set retry data after
  /// computing it asynchronously via isolate).
  void setRetryData(String taskId, Map<String, dynamic>? retryData) {
    state = state.map((t) {
      if (t.id != taskId) return t;
      return t.copyWith(retryData: retryData);
    }).toList();
    _persistTasks();
  }

  void _updateTask(
    String taskId,
    TaskStatus status, {
    String? error,
    String? downloadedFilePath,
    bool? resultSavedAsPartial,
    Map<String, dynamic>? rawRequest,
    Map<String, dynamic>? rawResponse,
  }) {
    BackgroundTask? oldTask;
    state = state.map((t) {
      if (t.id != taskId) return t;
      oldTask = t;
      final shouldClearError = error == null && status == TaskStatus.completed;
      return t.copyWith(
        status: status,
        error: error,
        clearError: shouldClearError,
        downloadedFilePath: downloadedFilePath,
        resultSavedAsPartial: resultSavedAsPartial,
        rawRequest: rawRequest,
        rawResponse: rawResponse,
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
    _syncIosContinuedTask();
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
  // ==========================================================================
  // iOS 26+ 常驻后台任务同步（BGContinuedProcessingTask）
  // ==========================================================================

  /// 周期同步间隔：单个步骤可能耗时数分钟（上传/转写），期间步骤
  /// 进度不动，系统会认为任务停滞（可能提示用户或优先终止）。
  /// 周期重报进度可避免该问题。
  static const _iosSyncInterval = Duration(seconds: 30);

  /// 周期性重报进度的定时器（仅在存在运行中任务时激活）。
  Timer? _iosSyncTimer;

  /// 最近一次上报的进度百分比：多任务并行时新增任务会稀释占比，
  /// 用单调递增值避免系统进度条回退。
  int _iosLastPercent = 0;

  /// 将当前任务运行状态同步给 iOS 常驻后台桥接。
  ///
  /// - 有任务运行：维持常驻任务（原生侧已激活时自动跳过重复提交），
  ///   并上报进度（已完成步骤占比，单调不降）。
  /// - 没有任务运行：通知系统常驻任务完成。
  ///
  /// 自愈说明：任务被系统终止后，原生侧引用清空，下一次同步会自动
  /// 重新提交建立保护；但系统只接受前台状态下的提交，因此若 App
  /// 仍在后台，自愈会推迟到 App 回到前台后的下一次同步（周期定时器
  /// 或状态变更触发）。
  void _syncIosContinuedTask() {
    if (!IosContinuedTaskService.instance.isSupported) return;
    final running = state.where((t) => t.status == TaskStatus.running).toList();
    if (running.isEmpty) {
      _iosSyncTimer?.cancel();
      _iosSyncTimer = null;
      _iosLastPercent = 0;
      unawaited(IosContinuedTaskService.instance.complete());
      return;
    }
    // 存在运行中任务：启动周期重报定时器（幂等）。
    _iosSyncTimer ??= Timer.periodic(
      _iosSyncInterval,
      (_) => _syncIosContinuedTask(),
    );
    unawaited(IosContinuedTaskService.instance.submit());
    final totalSteps = running.fold<int>(0, (sum, t) => sum + t.steps.length);
    final doneSteps = running.fold<int>(
      0,
      (sum, t) =>
          sum +
          t.steps
              .where(
                (s) =>
                    s.status == BgStepStatus.completed ||
                    s.status == BgStepStatus.skipped,
              )
              .length,
    );
    final rawPercent = totalSteps == 0
        ? 0
        : ((doneSteps * 100) / totalSteps).round().clamp(0, 99);
    final percent = rawPercent > _iosLastPercent ? rawPercent : _iosLastPercent;
    _iosLastPercent = percent;
    unawaited(IosContinuedTaskService.instance.updateProgress(percent));
  }
  // ============================================================================
  // Persistence
  // ============================================================================

  /// 写入链：保证多次 _persistTasks 按调用顺序落盘，避免并发写入
  /// 交错导致旧快照覆盖新快照（步骤更新非常频繁，竞态窗口真实存在）。
  Future<void>? _pendingWrite;
  Completer<void>? _removalBarrier;
  List<BackgroundTask>? _disposedSnapshot;
  Future<void>? _disposedPersistence;
  // Preserve the authoritative file after a partial restore; later state
  // mutations must not serialize only the tasks that could be parsed.
  bool _taskSnapshotIncomplete = false;
  bool _taskSnapshotCanPreserveSkippedEntries = false;
  List<dynamic> _skippedTaskEntries = const [];

  /// Wait for queued task writes before releasing their storage directory.
  Future<void> get pendingPersistence => _pendingWrite ?? Future<void>.value();

  Future<bool> _persistTasks() {
    final preserveSkippedEntries = _taskSnapshotIncomplete;
    final barrier = _removalBarrier;
    if (barrier != null) {
      if (!mounted && _disposedPersistence != null) {
        return _disposedPersistence!.then((_) => false);
      }
      final previous = _pendingWrite ?? Future<void>.value();
      final dirOverride = debugStorageDirectoryOverride;
      final deferred = previous.then((_) async {
        await barrier.future;
        final snapshot = mounted ? state : _disposedSnapshot;
        if (snapshot == null) return false;
        return _writeSnapshotNow(
          snapshot,
          dirOverride,
          preserveSkippedEntries: preserveSkippedEntries,
        );
      });
      _pendingWrite = deferred.then<void>((_) {});
      if (!mounted) _disposedPersistence = _pendingWrite;
      return deferred;
    }
    if (!mounted) {
      final snapshot = _disposedSnapshot;
      if (snapshot == null) return Future<bool>.value(false);
      final write = _writeSnapshot(
        snapshot,
        preserveSkippedEntries: preserveSkippedEntries,
      );
      _disposedPersistence ??= write.then<void>((_) {});
      return write;
    }
    return _writeSnapshot(
      state,
      preserveSkippedEntries: preserveSkippedEntries,
    );
  }

  Future<bool> _writeSnapshot(
    List<BackgroundTask> snapshot, {
    bool preserveSkippedEntries = false,
  }) {
    final canPreserveSkippedEntries = _taskSnapshotIncomplete &&
        preserveSkippedEntries &&
        _canSafelyPreserveSkippedEntries(snapshot);
    if (_taskSnapshotIncomplete && !canPreserveSkippedEntries) {
      return Future<bool>.value(false);
    }
    final skippedEntries = canPreserveSkippedEntries
        ? List<dynamic>.unmodifiable(_skippedTaskEntries)
        : const <dynamic>[];
    // 同样在调用时捕获持久化目录覆盖值：写入链可能延迟到调用之后
    // 才真正执行，若此时再解析目录，测试 teardown 已重置覆盖值，
    // 残留写入会落到共享的正式目录（跨测试污染）。
    final dirOverride = debugStorageDirectoryOverride;
    // 串行化写入：每次写入排在上一次写入完成之后。
    final write = (_pendingWrite ?? Future<void>.value()).then((_) async {
      if (_taskSnapshotIncomplete &&
          (!canPreserveSkippedEntries ||
              !_canSafelyPreserveSkippedEntries(snapshot))) {
        return false;
      }
      if (_hasCacheMigrations(snapshot)) {
        return OcrRetryStorage.withCacheMaintenanceLock(
          () => _writePreparedSnapshot(
            snapshot,
            dirOverride,
            preservedEntries: skippedEntries,
          ),
        );
      }
      return _writePreparedSnapshot(
        snapshot,
        dirOverride,
        preservedEntries: skippedEntries,
      );
    });
    _pendingWrite = write.then<void>((_) {});
    return write;
  }

  Future<bool> _writeSnapshotNow(
    List<BackgroundTask> snapshot,
    String? dirOverride, {
    bool preserveSkippedEntries = false,
  }) {
    final canPreserveSkippedEntries = _taskSnapshotIncomplete &&
        preserveSkippedEntries &&
        _canSafelyPreserveSkippedEntries(snapshot);
    if (_taskSnapshotIncomplete && !canPreserveSkippedEntries) {
      return Future<bool>.value(false);
    }
    final skippedEntries = canPreserveSkippedEntries
        ? List<dynamic>.unmodifiable(_skippedTaskEntries)
        : const <dynamic>[];
    if (_hasCacheMigrations(snapshot)) {
      return OcrRetryStorage.withCacheMaintenanceLock(
        () => _writePreparedSnapshot(
          snapshot,
          dirOverride,
          preservedEntries: skippedEntries,
        ),
      );
    }
    return _writePreparedSnapshot(
      snapshot,
      dirOverride,
      preservedEntries: skippedEntries,
    );
  }

  Future<bool> _writePreparedSnapshot(
    List<BackgroundTask> snapshot,
    String? dirOverride, {
    List<dynamic> preservedEntries = const [],
  }) async {
    final prepared = await _prepareOcrRetriesForPersistence(snapshot);
    if (prepared == null) return false;
    _publishPreparedRetrySnapshots(snapshot, prepared);
    final data = <dynamic>[
      ...prepared.map((task) => task.toMap()),
      ...preservedEntries,
    ];
    return _writeSnapshotData(data, dirOverride);
  }

  bool _canSafelyPreserveSkippedEntries(List<BackgroundTask> snapshot) {
    if (!_taskSnapshotCanPreserveSkippedEntries ||
        !_canSafelySerializeKnownTasks(snapshot)) {
      return false;
    }
    for (final entry in _skippedTaskEntries) {
      if (entry is! Map) return false;
      if (entry.keys.any((key) => key is! String) ||
          entry.containsKey('rawRequest') ||
          entry.containsKey('rawResponse')) {
        return false;
      }
      final error = entry['error'];
      if (error != null &&
          (error is! String || _sanitizeOcrTaskError(error, null) != error)) {
        return false;
      }
      final rawSteps = entry['steps'];
      if (rawSteps != null) {
        if (rawSteps is! List) return false;
        for (final rawStep in rawSteps) {
          if (rawStep is! Map) continue;
          final stepError = rawStep['error'];
          if (stepError != null &&
              (stepError is! String ||
                  _sanitizeOcrTaskError(stepError, null) != stepError)) {
            return false;
          }
        }
      }
      final entryType = entry['type'];
      if (entryType != BackgroundTaskType.ocr.name) {
        if (BackgroundTaskType.values.any((type) => type.name == entryType)) {
          continue;
        }
        return false;
      }
      final retryData = entry['retryData'];
      if (retryData == null) continue;
      if (retryData is! Map) return false;
      try {
        final retrySnapshot = OcrRetrySnapshot.fromMap(
          Map<String, dynamic>.from(retryData),
        );
        if (retrySnapshot.version != OcrRetrySnapshot.currentVersion ||
            retrySnapshot.needsMigration ||
            retrySnapshot.hasInvalidImages ||
            retrySnapshot.images.any((image) => image.bytes != null)) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  bool _canSafelySerializeKnownTasks(List<BackgroundTask> snapshot) {
    for (final task in snapshot) {
      if (task.type != BackgroundTaskType.ocr || task.retryData == null) {
        continue;
      }
      try {
        final retrySnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
        if (retrySnapshot.version != OcrRetrySnapshot.currentVersion ||
            retrySnapshot.needsMigration ||
            retrySnapshot.hasInvalidImages ||
            retrySnapshot.hasInvalidImageMetadata ||
            retrySnapshot.images.any((image) => image.bytes != null)) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<Set<String>?> _ocrCacheReferencesForCleanup() async {
    final persisted = await _loadPersistedTasks();
    if (!persisted.isReadable) return null;
    final tasks = mounted ? state : (_disposedSnapshot ?? const []);
    return {
      for (final task in tasks)
        if (task.type == BackgroundTaskType.ocr)
          ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
      for (final task in persisted.tasks)
        if (task.type == BackgroundTaskType.ocr)
          ...OcrRetryStorage.referencesFromSnapshot(task.retryData),
      ..._referencesFromSkippedTaskEntries(),
      ..._referencesFromSkippedTaskEntries(persisted.skippedEntries),
    };
  }

  Set<String> _referencesFromSkippedTaskEntries([Iterable<dynamic>? entries]) {
    final references = <String>{};
    for (final entry in entries ?? _skippedTaskEntries) {
      if (entry is! Map) continue;
      final retryData = entry['retryData'];
      if (retryData is! Map) continue;
      try {
        references.addAll(
          OcrRetryStorage.referencesFromSnapshot(
            Map<String, dynamic>.from(retryData),
          ),
        );
      } catch (_) {
        // Unknown persisted data must never expand the set of deletable paths.
      }
    }
    return references;
  }

  bool _hasCacheMigrations(List<BackgroundTask> snapshot) {
    for (final task in snapshot) {
      if (task.type != BackgroundTaskType.ocr || task.retryData == null) {
        continue;
      }
      try {
        final retrySnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
        final canMigrateVersion = retrySnapshot.isLegacy ||
            retrySnapshot.version == 1 ||
            retrySnapshot.version == 2 ||
            retrySnapshot.version == OcrRetrySnapshot.currentVersion;
        if (canMigrateVersion && retrySnapshot.needsMigration) return true;
      } catch (_) {
        // Malformed data is sanitized by the prepare step without cache I/O.
      }
    }
    return false;
  }

  Future<List<BackgroundTask>?> _prepareOcrRetriesForPersistence(
    List<BackgroundTask> snapshot,
  ) async {
    final prepared = List<BackgroundTask>.of(snapshot);
    for (var index = 0; index < prepared.length; index++) {
      final task = prepared[index];
      if (task.type != BackgroundTaskType.ocr || task.retryData == null) {
        continue;
      }

      OcrRetrySnapshot retrySnapshot;
      try {
        retrySnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
      } catch (error) {
        debugPrint(
          '[BackgroundTaskNotifier] Dropping malformed OCR retry data for ${task.id}: $error',
        );
        prepared[index] = task.copyWith(clearRetryData: true);
        continue;
      }

      final canMigrateVersion = retrySnapshot.isLegacy ||
          retrySnapshot.version == 1 ||
          retrySnapshot.version == 2 ||
          retrySnapshot.version == OcrRetrySnapshot.currentVersion;
      if (!canMigrateVersion) {
        prepared[index] = task.copyWith(
          retryData: _unavailableOcrRetryData(task.id, retrySnapshot),
        );
        continue;
      }
      if (!retrySnapshot.needsMigration) continue;

      try {
        final retryData = await OcrRetryStorage.cacheSnapshot(
          taskId: task.id,
          snapshot: retrySnapshot,
          allowIncompleteImages: retrySnapshot.hasInvalidImages,
        );
        prepared[index] = task.copyWith(retryData: retryData);
      } catch (error) {
        debugPrint(
          '[BackgroundTaskNotifier] Failed to migrate OCR retry data for ${task.id}: $error',
        );
        if (retrySnapshot.images.any(
          (image) => image.bytes?.isNotEmpty ?? false,
        )) {
          // Keep valid legacy inputs in memory and on disk until the cache
          // write works. This also preserves valid entries in a mixed snapshot
          // while unavailable placeholders are prepared for invalid siblings.
          // The caller skips this entire tasks.json update so a progress change
          // cannot rewrite the inline image payload.
          return null;
        }
        prepared[index] = task.copyWith(
          retryData: _unavailableOcrRetryData(task.id, retrySnapshot),
        );
      }
    }
    return prepared;
  }

  void _publishPreparedRetrySnapshots(
    List<BackgroundTask> original,
    List<BackgroundTask> prepared,
  ) {
    final changed = <String, BackgroundTask>{};
    final originalById = {for (final task in original) task.id: task};
    for (var index = 0; index < original.length; index++) {
      final before = original[index];
      final after = prepared[index];
      if (before.id != after.id ||
          identical(before.retryData, after.retryData)) {
        continue;
      }
      changed[before.id] = after;
    }
    if (changed.isEmpty) return;

    List<BackgroundTask> update(List<BackgroundTask> current) =>
        current.map((task) {
          final before = originalById[task.id];
          final after = changed[task.id];
          if (before == null ||
              after == null ||
              !identical(task.retryData, before.retryData)) {
            return task;
          }
          return task.copyWith(retryData: after.retryData);
        }).toList(growable: false);

    if (mounted) state = update(state);
    if (_disposedSnapshot != null) {
      _disposedSnapshot = update(_disposedSnapshot!);
    }
  }

  Future<bool> _writeSnapshotData(
    List<dynamic> data,
    String? dirOverride,
  ) async {
    try {
      final file = await _tasksFile(dirOverride);
      await _writeTasksFile(file, jsonEncode(data));
      return true;
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to persist tasks: $e');
      return false;
    }
  }

  /// 原子写入任务文件（委托 [AtomicFile]：写临时文件 + rename 替换）。
  ///
  /// 直接 writeAsString 不是原子操作——写入中途崩溃/断电会留下
  /// 半截 JSON，下次启动恢复时整个文件解析失败、任务全部丢失。
  /// （写入链已串行化，不存在并发写同一文件的竞态。）
  Future<void> _writeTasksFile(File file, String data) async {
    await debugBeforeTaskSnapshotWrite?.call();
    await AtomicFile.writeString(file, data);
  }

  Future<
      ({
        List<BackgroundTask> tasks,
        bool isComplete,
        bool isReadable,
        List<dynamic> skippedEntries,
      })> _loadPersistedTasks() async {
    try {
      final file = await _tasksFile();
      if (!await file.exists()) {
        return (
          tasks: <BackgroundTask>[],
          isComplete: true,
          isReadable: true,
          skippedEntries: <dynamic>[],
        );
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        return (
          tasks: <BackgroundTask>[],
          isComplete: false,
          isReadable: false,
          skippedEntries: <dynamic>[],
        );
      }
      final list = jsonDecode(content) as List;
      final tasks = <BackgroundTask>[];
      final skippedEntries = <dynamic>[];
      var isComplete = true;
      for (final m in list) {
        try {
          tasks.add(
            BackgroundTask.fromMap(Map<String, dynamic>.from(m as Map)),
          );
        } catch (e) {
          // 单个损坏条目不应导致整个恢复失败：跳过并继续，
          // 保证其余有效任务仍能恢复。
          isComplete = false;
          skippedEntries.add(m);
          debugPrint(
            '[BackgroundTaskNotifier] Skipping corrupt task entry: $e',
          );
        }
      }
      return (
        tasks: tasks,
        isComplete: isComplete,
        isReadable: true,
        skippedEntries: skippedEntries,
      );
    } catch (e) {
      debugPrint('[BackgroundTaskNotifier] Failed to load persisted tasks: $e');
      return (
        tasks: <BackgroundTask>[],
        isComplete: false,
        isReadable: false,
        skippedEntries: <dynamic>[],
      );
    }
  }

  Future<File> _tasksFile([String? dirOverride]) async {
    final dirPath = dirOverride ??
        debugStorageDirectoryOverride ??
        await AppStorage.directory;
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
  /// Waiting tasks are kept as waiting (they haven't started yet).
  Future<void> restoreFromPersistence() async {
    final loaded = await _loadPersistedTasks();
    _taskSnapshotIncomplete = !loaded.isComplete;
    _taskSnapshotCanPreserveSkippedEntries =
        loaded.isReadable && !loaded.isComplete;
    _skippedTaskEntries = loaded.skippedEntries;
    final tasks = loaded.tasks;
    if (tasks.isEmpty) {
      if (loaded.isComplete) await _cleanupOrphanedOcrCache();
      return;
    }
    final restored = <BackgroundTask>[];
    for (var task in tasks) {
      // A partial task list is not authoritative enough to publish retry-data
      // sanitation: a later deletion may be refused, leaving the old snapshot
      // on disk. Keep each parsed task's retry data unchanged until the full
      // task file can be durably rewritten.
      if (loaded.isComplete &&
          task.type == BackgroundTaskType.ocr &&
          task.retryData != null) {
        OcrRetrySnapshot? parsedSnapshot;
        try {
          parsedSnapshot = OcrRetrySnapshot.fromMap(task.retryData!);
          final canMigrateVersion = parsedSnapshot.isLegacy ||
              parsedSnapshot.version == 1 ||
              parsedSnapshot.version == 2 ||
              parsedSnapshot.version == OcrRetrySnapshot.currentVersion;
          if (parsedSnapshot.hasInvalidImages && !canMigrateVersion) {
            task = task.copyWith(
              retryData: _unavailableOcrRetryData(task.id, parsedSnapshot),
            );
          }
        } catch (error) {
          if (parsedSnapshot != null) {
            task = task.copyWith(
              retryData: _unavailableOcrRetryData(task.id, parsedSnapshot),
            );
          } else {
            task = task.copyWith(clearRetryData: true);
          }
          debugPrint(
            '[BackgroundTaskNotifier] Failed to migrate OCR retry data for ${task.id}: $error',
          );
        }
      }
      restored.add(
        task.status == TaskStatus.running
            ? task.copyWith(status: TaskStatus.failed, error: '应用重启，已中断')
            : task,
      );
    }
    // Merge with existing state (in case tasks were added before restore completes)
    state = [
      for (final t in restored)
        if (!state.any((s) => s.id == t.id)) t,
      ...state,
    ];
    // 将"运行中 → 已中断"的状态回写到磁盘，
    // 使持久化文件与内存状态保持一致（否则下次启动会重复标记）。
    // A partial parse cannot safely replace the authoritative file: skipped
    // entries may still own retry-cache references.
    final snapshotSaved = loaded.isComplete && await _persistTasks();
    // 恢复后没有运行中的任务（进程已重启），结束 iOS 常驻任务保护。
    _syncIosContinuedTask();
    if (loaded.isComplete && snapshotSaved) {
      await _cleanupOrphanedOcrCache();
    }
    debugPrint(
      '[BackgroundTaskNotifier] Restored ${tasks.length} tasks from persistence',
    );
  }
}
