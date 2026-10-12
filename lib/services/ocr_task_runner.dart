import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/ocr_batch_execution.dart';
import '../providers/background_task_provider.dart';
import '../utils/ocr_diagnostics.dart';
import '../utils/text_manifest.dart';
import 'ocr_result_saver.dart';
import 'ocr_service.dart';

/// Owns one OCR submission, including its inputs, client and save destination.
/// The page may disappear; only task cancellation or provider disposal stops it.
class OcrTaskRunner {
  final String taskId;
  final BackgroundTaskNotifier notifier;
  final OcrConfig config;
  final List<(Uint8List, String)> images;
  final List<String?> imageNames;
  final OcrBatchMode executionMode;
  final int perImageConcurrency;
  final List<OcrPageOutcome> initialPageOutcomes;
  final String title;
  final String folder;
  final void Function() onSaved;
  final OcrService Function(OcrConfig) _serviceFactory;
  final Future<String> Function(String, String, {void Function()? beforeCommit})
      _writeText;
  final CancelToken _cancelToken = CancelToken();
  late final OcrResultSaver _resultSaver = OcrResultSaver(
    taskId: taskId,
    notifier: notifier,
    title: title,
    folder: folder,
    onSaved: onSaved,
    cancelToken: _cancelToken,
    writeText: _writeText,
  );
  OcrService? _service;
  OcrService? _diagnosticService;
  OcrService? _failedDiagnosticService;
  OcrService? _incompleteDiagnosticService;
  final Set<OcrService> _activeServices = {};
  final Map<int, int> _perImageRequestStages = {};
  final Map<int, int> _perImageUploadPercent = {};
  Future<void>? _running;
  int _stage = -1;
  int _uploadPercent = -1;

  OcrTaskRunner({
    required this.taskId,
    required this.notifier,
    required OcrConfig config,
    required List<(Uint8List, String)> images,
    List<String?> imageNames = const [],
    this.executionMode = OcrBatchMode.joint,
    this.perImageConcurrency = 1,
    List<OcrPageOutcome> initialPageOutcomes = const [],
    required this.title,
    required this.folder,
    required this.onSaved,
    OcrService Function(OcrConfig)? serviceFactory,
    Future<String> Function(String, String, {void Function()? beforeCommit})?
        writeText,
  })  : config = config.copyWith(
          // Type config is JSON-shaped; recursively copy mutable containers.
          typeConfig: Map<String, dynamic>.from(
            jsonDecode(jsonEncode(config.typeConfig)) as Map,
          ),
          customParams: config.customParams
              .map((param) => param.copy())
              .toList(),
        ),
        images = List.unmodifiable(
          images.map((image) => (Uint8List.fromList(image.$1), image.$2)),
        ),
        imageNames = List.unmodifiable(
          List<String?>.generate(
            images.length,
            (index) => index < imageNames.length ? imageNames[index] : null,
          ),
        ),
        initialPageOutcomes = List.unmodifiable(initialPageOutcomes),
        _serviceFactory =
            serviceFactory ?? ((config) => OcrService(config: config)),
        _writeText = writeText ?? TextManifest.writeText {
    if (perImageConcurrency < 1 || perImageConcurrency > 2) {
      throw ArgumentError.value(
        perImageConcurrency,
        'perImageConcurrency',
        'OCR per-image concurrency must be 1 or 2',
      );
    }
  }

  /// Memoization fences duplicate starts, including starts after completion.
  Future<void> run() => _running ??= _run();

  void cancel() {
    _cancelToken.cancel('已取消');
    for (final service in _activeServices.toList()) {
      service.close(force: true);
    }
  }

  void _checkActive() {
    if (!notifier.mounted || !notifier.state.any((task) => task.id == taskId)) {
      cancel();
    }
    if (_cancelToken.isCancelled) throw _cancelToken.cancelError!;
  }

  void _advance(int next) {
    _checkActive();
    if (next <= _stage) return;
    for (var i = 0; i < next; i++) {
      notifier.updateStep(taskId, i, completed: true);
    }
    _stage = next;
    notifier.updateStep(taskId, next, running: true);
  }

  void _requestStage(OcrRequestStage stage) {
    switch (stage) {
      case OcrRequestStage.uploading:
        _advance(1);
      case OcrRequestStage.waiting:
        _advance(2);
      case OcrRequestStage.parsing:
        _advance(3);
    }
  }

  void _perImageRequestStage(int imageIndex, OcrRequestStage stage) {
    _setPerImageStageIndex(imageIndex, stage.index + 1);
  }

  void _setPerImageStageIndex(int imageIndex, int stageIndex) {
    _checkActive();
    if (_perImageRequestStages[imageIndex] == stageIndex) return;
    _perImageRequestStages[imageIndex] = stageIndex;
    _perImageUploadPercent.putIfAbsent(imageIndex, () => 0);
    _syncPerImageSteps();
  }

  void _syncPerImageSteps() {
    if (_perImageRequestStages.isEmpty ||
        _cancelToken.isCancelled ||
        !notifier.mounted) {
      return;
    }
    final task = notifier.state.where((task) => task.id == taskId).firstOrNull;
    if (task == null || task.steps.length < 4) return;

    final activeStages = _perImageRequestStages.values.toList();
    final steps = List<BgTaskStep>.of(task.steps);
    for (var index = 0; index <= 3; index++) {
      final running = activeStages.contains(index);
      final completed = activeStages.every((stage) => stage > index);
      final status = running
          ? BgStepStatus.running
          : completed
              ? BgStepStatus.completed
              : BgStepStatus.pending;
      steps[index] = steps[index].copyWith(
        status: status,
        clearError: true,
      );
    }

    final uploadingPages = _perImageRequestStages.entries
        .where((entry) => entry.value == OcrRequestStage.uploading.index + 1)
        .toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    if (uploadingPages.isNotEmpty) {
      final progress = uploadingPages.map((entry) {
        final percent = _perImageUploadPercent[entry.key] ?? 0;
        return '第 ${entry.key + 1}/${images.length} 张图片 $percent%';
      }).join('，');
      steps[1] = steps[1].copyWith(label: '上传' + progress);
    }
    notifier.setSteps(taskId, steps);
  }

  void _uploadProgress(int sent, int total, {int? imageIndex}) {
    _checkActive();
    if (total <= 0) return;
    final percent = (sent * 100 ~/ total).clamp(0, 100);
    if (imageIndex != null) {
      if (_perImageRequestStages[imageIndex] !=
              OcrRequestStage.uploading.index + 1 ||
          _perImageUploadPercent[imageIndex] == percent) {
        return;
      }
      _perImageUploadPercent[imageIndex] = percent;
      _syncPerImageSteps();
      return;
    }
    if (_stage != 1) return;
    if (percent == _uploadPercent) return;
    _uploadPercent = percent;
    notifier.updateStep(taskId, 1, running: true, label: '上传图片 $percent%');
  }

  Future<void> _run() async {
    notifier.registerCancellation(taskId, cancel);
    String? taskSpecificFailure;
    try {
      _checkActive();
      _advance(0);
      late final OcrResult result;
      String? incompleteMessage;
      if (executionMode == OcrBatchMode.joint) {
        final service = _service = _serviceFactory(config);
        _activeServices.add(service);
        result = images.length == 1
            ? await service.recognize(
                imageBytes: images.single.$1,
                imageFormat: images.single.$2,
                cancelToken: _cancelToken,
                onSendProgress: _uploadProgress,
                onStage: _requestStage,
              )
            : await service.recognizeBatch(
                imageBytesList: images,
                cancelToken: _cancelToken,
                onSendProgress: _uploadProgress,
                onStage: _requestStage,
              );
        _diagnosticService = service;
      } else {
        final (pageResult, message) = await _recognizePerImage();
        result = pageResult;
        incompleteMessage = message;
      }
      _checkActive();
      if (result.isComplete || result.text.isNotEmpty) {
        notifier.setResult(
          taskId,
          result.text,
          isComplete: result.isComplete,
          folder: folder,
        );
      }
      if (!result.isComplete) {
        notifier.updateStep(taskId, 3, completed: true);
        taskSpecificFailure = incompleteMessage;
        throw Exception(
          incompleteMessage ??
              'OCR 返回了不完整结果（finish_reason=' +
                  (result.finishReason ?? 'unknown') +
                  '）',
        );
      }
      final service = _diagnosticService ?? _service;
      notifier.setRawDiagnostics(
        taskId,
        rawRequest: service?.diagnosticRequest,
        rawResponse: service?.diagnosticResponse(),
      );
      _advance(4);
      await _resultSaver.saveResult(result.text, isComplete: result.isComplete);
    } catch (error) {
      // A removed/disposed task must never be recreated by late callbacks.
      if (!_cancelToken.isCancelled && notifier.mounted) {
        final task = notifier.state
            .where((task) => task.id == taskId)
            .firstOrNull;
        if (task != null) {
          final safeError = taskSpecificFailure == null
              ? error is OcrRequestTooLargeException
                  ? error.toString()
                  : OcrDiagnosticSnapshot.safeTaskError(
                      error,
                      excludedValues: [config.apiKey],
                    )
              : OcrDiagnosticSnapshot.sanitizeStoredTaskError(
                      taskSpecificFailure,
                      excludedValues: [config.apiKey],
                    ) ??
                    'OCR 部分页面未完成';
          for (var i = 0; i < task.steps.length; i++) {
            if (task.steps[i].running) {
              notifier.updateStep(taskId, i, failed: true, error: safeError);
            } else if (task.steps[i].status == BgStepStatus.pending) {
              notifier.updateStep(taskId, i, skipped: true);
            }
          }
          final service =
              _failedDiagnosticService ??
              _incompleteDiagnosticService ??
              _diagnosticService ??
              _service;
          final result = task.result;
          final errorMessage = result == null
              ? 'OCR识别失败: $safeError'
              : task.resultIsComplete
                  ? 'OCR结果保存失败: $safeError'
                  : 'OCR结果不完整: $safeError';
          final safeErrorMessage =
              OcrDiagnosticSnapshot.sanitizeStoredTaskError(
                    errorMessage,
                    excludedValues: [config.apiKey],
                  ) ??
                  '';
          notifier.failTask(
            taskId,
            error: safeErrorMessage,
            rawRequest: service?.diagnosticRequest,
            rawResponse: service?.diagnosticResponse(error: error),
          );
        }
      }
    } finally {
      notifier.unregisterCancellation(taskId);
      for (final service in _activeServices.toList()) {
        service.close();
      }
      _activeServices.clear();
      _service = null;
    }
  }

  Future<(OcrResult, String?)> _recognizePerImage() async {
    if (images.isEmpty) {
      throw ArgumentError(
        'OCR per-image execution requires at least one image',
      );
    }
    final outcomes = List<OcrPageOutcome>.generate(
      images.length,
      (index) => OcrPageOutcome(
        imageIndex: index,
        status: OcrPageOutcomeStatus.pending,
      ),
    );
    for (final outcome in initialPageOutcomes) {
      if (outcome.imageIndex >= 0 &&
          outcome.imageIndex < outcomes.length &&
          outcome.canReuseResult) {
        outcomes[outcome.imageIndex] = outcome;
      }
    }
    _publishPageOutcomes(outcomes);

    var nextImageIndex = 0;
    var processingTimeMs = 0;
    var cancellationOutcomesPublished = false;

    void publishCancelledOutcomes() {
      if (cancellationOutcomesPublished) return;
      cancellationOutcomesPublished = true;
      for (var index = 0; index < outcomes.length; index++) {
        final outcome = outcomes[index];
        if (outcome.status == OcrPageOutcomeStatus.pending ||
            outcome.status == OcrPageOutcomeStatus.running) {
          outcomes[index] = OcrPageOutcome(
            imageIndex: index,
            status: OcrPageOutcomeStatus.cancelled,
            error: '已取消',
          );
        }
      }
      if (notifier.mounted && notifier.state.any((task) => task.id == taskId)) {
        _publishPageOutcomes(outcomes);
      }
    }

    Future<void> runWorker() async {
      while (true) {
        try {
          _checkActive();
        } catch (_) {
          if (_cancelToken.isCancelled) publishCancelledOutcomes();
          rethrow;
        }
        final imageIndex = nextImageIndex++;
        if (imageIndex >= images.length) return;
        if (outcomes[imageIndex].canReuseResult) continue;

        outcomes[imageIndex] = OcrPageOutcome(
          imageIndex: imageIndex,
          status: OcrPageOutcomeStatus.running,
        );
        _publishPageOutcomes(outcomes);
        final image = images[imageIndex];
        final service = _serviceFactory(config);
        _activeServices.add(service);
        try {
          _setPerImageStageIndex(imageIndex, 0);
          final result = await service.recognize(
            imageBytes: image.$1,
            imageFormat: image.$2,
            cancelToken: _cancelToken,
            onSendProgress: (sent, total) =>
                _uploadProgress(sent, total, imageIndex: imageIndex),
            onStage: (stage) => _perImageRequestStage(imageIndex, stage),
          );
          _checkActive();
          processingTimeMs += result.processingTimeMs;
          if (result.isComplete) {
            _diagnosticService = service;
          } else {
            _incompleteDiagnosticService ??= service;
          }
          outcomes[imageIndex] = OcrPageOutcome(
            imageIndex: imageIndex,
            status: result.isComplete
                ? OcrPageOutcomeStatus.succeeded
                : OcrPageOutcomeStatus.incomplete,
            text: result.text,
            error: result.isComplete
                ? null
                : 'OCR 返回了不完整结果（finish_reason=' +
                      (result.finishReason ?? 'unknown') +
                      '）',
          );
        } catch (error) {
          if (_cancelToken.isCancelled) {
            publishCancelledOutcomes();
            rethrow;
          }
          _checkActive();
          _failedDiagnosticService ??= service;
          outcomes[imageIndex] = OcrPageOutcome(
            imageIndex: imageIndex,
            status: OcrPageOutcomeStatus.failed,
            error: error is OcrRequestTooLargeException
                ? error.toString()
                : OcrDiagnosticSnapshot.safeTaskError(
                    error,
                    excludedValues: [config.apiKey],
                  ),
          );
        } finally {
          _perImageRequestStages.remove(imageIndex);
          _perImageUploadPercent.remove(imageIndex);
          _syncPerImageSteps();
          _activeServices.remove(service);
          service.close();
        }
        _publishPageOutcomes(outcomes);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(perImageConcurrency, (_) => runWorker()),
    );
    _checkActive();

    final complete = outcomes.every(
      (outcome) => outcome.status == OcrPageOutcomeStatus.succeeded,
    );
    final combinedText = _combinedPageText(outcomes);
    final errorMessage = complete ? null : _pageFailureMessage(outcomes);
    return (
      OcrResult(
        text: combinedText,
        processingTimeMs: processingTimeMs,
        imageCount: images.length,
        isComplete: complete,
        finishReason: complete ? 'stop' : 'partial',
      ),
      errorMessage,
    );
  }

  void _publishPageOutcomes(List<OcrPageOutcome> outcomes) {
    notifier.setOcrPageOutcomes(taskId, List.unmodifiable(outcomes));
  }

  String _combinedPageText(List<OcrPageOutcome> outcomes) => outcomes
      .where((outcome) => outcome.text?.isNotEmpty == true)
      .map((outcome) {
        final name = imageNames[outcome.imageIndex]?.trim();
        final label = name == null || name.isEmpty
            ? '第 ' + (outcome.imageIndex + 1).toString() + ' 张图片'
            : '第 ' + (outcome.imageIndex + 1).toString() + ' 张图片：' + name;
        return '--- ' + label + ' ---\n' + outcome.text!;
      })
      .join('\n\n');

  String _pageFailureMessage(List<OcrPageOutcome> outcomes) {
    final failures = outcomes
        .where((outcome) => outcome.status != OcrPageOutcomeStatus.succeeded)
        .map((outcome) {
          final label = '第 ' + (outcome.imageIndex + 1).toString() + ' 张图片';
          final state = outcome.status == OcrPageOutcomeStatus.incomplete
              ? '结果不完整'
              : '识别失败';
          return label + state;
        })
        .join('；');
    return '部分图片 OCR 未完成：' + failures;
  }
}
