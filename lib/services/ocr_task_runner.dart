import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../providers/background_task_provider.dart';
import '../utils/text_manifest.dart';
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
    _cancelToken.throwIfCancellationRequested();
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

  Future<String> _save(String text) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final hash = computeTextHash(bytes);
    return TextManifest.withSaveLock(hash, () async {
      final name = '$hash.txt';
      final record = TextRecord(
          name: title,
          hash: hash,
          createdAt: DateTime.now(),
          size: bytes.length,
          folder: folder,
          textLength: text.length);
      var existed = true; // Until existence is known, never delete shared data.
      try {
        _checkActive();
        existed = await TextManifest.readFilePath(name) != null;
        _checkActive();
        final path = await _writeText(name, text, beforeCommit: _checkActive);
        _checkActive();
        await TextManifest.addRecord(record, beforeCommit: _checkActive);
        _checkActive();
        return path;
      } catch (_) {
        if (_cancelToken.isCancelled) {
          // Cancellation may arrive after file publication or DB insertion.
          // Remove only this record, then only newly created unreferenced data.
          final records = await TextManifest.loadRecordsUncached();
          if (records.any((item) => item.id == record.id)) {
            await TextManifest.deleteRecord(record.id, preserveFiles: true);
          }
          if (!existed &&
              !(await TextManifest.loadRecordsUncached())
                  .any((item) => item.hash == hash)) {
            await TextManifest.deleteFile(name);
          }
        }
        rethrow;
      }
    });
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
      notifier.setResult(taskId, result.text);
      if (!result.isComplete) {
        throw Exception('OCR 返回了不完整结果（finish_reason=${result.finishReason}）');
      }
      _advance(4);
      final filePath = await _save(result.text);
      _checkActive();
      notifier.updateStep(taskId, 4, completed: true);
      notifier.completeTask(taskId, downloadedFilePath: filePath);
      onSaved();
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
          notifier.failTask(taskId,
              error: 'OCR识别失败: $error',
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
