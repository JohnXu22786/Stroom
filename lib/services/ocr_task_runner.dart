import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../providers/background_task_provider.dart';
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
  Future<void>? _running;
  int _stage = -1;
  int _uploadPercent = -1;

  OcrTaskRunner({
    required this.taskId,
    required this.notifier,
    required OcrConfig config,
    required List<(Uint8List, String)> images,
    required this.title,
    required this.folder,
    required this.onSaved,
    OcrService Function(OcrConfig)? serviceFactory,
    Future<String> Function(String, String, {void Function()? beforeCommit})?
        writeText,
  })  : config = config.copyWith(
          // Type config is JSON-shaped; recursively copy mutable containers.
          typeConfig: Map<String, dynamic>.from(
              jsonDecode(jsonEncode(config.typeConfig)) as Map),
          customParams:
              config.customParams.map((param) => param.copy()).toList(),
        ),
        images = List.unmodifiable(
            images.map((image) => (Uint8List.fromList(image.$1), image.$2))),
        _serviceFactory =
            serviceFactory ?? ((config) => OcrService(config: config)),
        _writeText = writeText ?? TextManifest.writeText;

  /// Memoization fences duplicate starts, including starts after completion.
  Future<void> run() => _running ??= _run();

  void cancel() {
    _cancelToken.cancel('已取消');
    _service?.close(force: true);
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

  void _uploadProgress(int sent, int total) {
    _checkActive();
    if (total <= 0 || _stage != 1) return;
    final percent = (sent * 100 ~/ total).clamp(0, 100);
    if (percent == _uploadPercent) return;
    _uploadPercent = percent;
    notifier.updateStep(taskId, 1, running: true, label: '上传图片 $percent%');
  }

  Future<void> _run() async {
    notifier.registerCancellation(taskId, cancel);
    try {
      _checkActive();
      _advance(0);
      final service = _service = _serviceFactory(config);
      final result = images.length == 1
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
      _checkActive();
      notifier.setResult(
        taskId,
        result.text,
        isComplete: result.isComplete,
        folder: folder,
      );
      if (!result.isComplete) {
        notifier.updateStep(taskId, 3, completed: true);
        throw Exception('OCR 返回了不完整结果（finish_reason=${result.finishReason}）');
      }
      _advance(4);
      await _resultSaver.saveResult(
        result.text,
        isComplete: result.isComplete,
      );
    } catch (error) {
      // A removed/disposed task must never be recreated by late callbacks.
      if (!_cancelToken.isCancelled && notifier.mounted) {
        final task =
            notifier.state.where((task) => task.id == taskId).firstOrNull;
        if (task != null) {
          for (var i = 0; i < task.steps.length; i++) {
            if (task.steps[i].running) {
              notifier.updateStep(taskId, i, failed: true, error: '$error');
            } else if (task.steps[i].status == BgStepStatus.pending) {
              notifier.updateStep(taskId, i, skipped: true);
            }
          }
          final service = _service;
          final result = task.result;
          final errorMessage = result == null
              ? 'OCR识别失败: $error'
              : task.resultIsComplete
                  ? 'OCR结果保存失败: $error'
                  : 'OCR结果不完整: $error';
          notifier.failTask(taskId,
              error: errorMessage,
              rawRequest: service == null
                  ? null
                  : {
                      'url': service.lastRequestUrl,
                      'headers': service.lastRequestHeaders,
                      'body': service.lastRequestBody,
                    },
              rawResponse: service == null
                  ? null
                  : {
                      'statusCode': service.lastResponseStatusCode,
                      'headers': service.lastResponseHeaders,
                      'data': service.lastResponseData,
                    });
        }
      }
    } finally {
      notifier.unregisterCancellation(taskId);
      _service?.close();
      _service = null;
    }
  }
}
