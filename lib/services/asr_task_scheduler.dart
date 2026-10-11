import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../providers/background_task_provider.dart';
import '../providers/task_provider.dart';
import '../utils/text_manifest.dart';
import 'asr_result_saver.dart';
import 'asr_service.dart';

/// Input captured from the ASR page before navigation starts.
class AsrTaskAudio {
  final Uint8List bytes;
  final String name;
  final String format;

  AsrTaskAudio({
    required Uint8List bytes,
    required this.name,
    this.format = 'wav',
  }) : bytes = Uint8List.fromList(bytes);

  bool get isUrl => format == 'url';
}

class _AsrTaskJob {
  final String taskId;
  final AsrTaskAudio audio;
  final String title;
  final CancelToken cancelToken = CancelToken();
  AsrService? service;

  _AsrTaskJob(this.taskId, this.audio, this.title);
}

/// Owns one standalone ASR batch and runs its tasks serially after the page
/// has handed over a snapshot of all inputs and the save destination.
class AsrTaskScheduler {
  final BackgroundTaskNotifier notifier;
  final AsrConfig config;
  final List<AsrTaskAudio> audios;
  final String saveFolder;
  final int modelIndex;
  final AsrService Function(AsrConfig) _serviceFactory;
  final AsrTextWriter _writeText;
  final void Function() _onSaved;

  List<_AsrTaskJob>? _jobs;
  Future<void>? _running;

  AsrTaskScheduler({
    required this.notifier,
    required AsrConfig config,
    required List<AsrTaskAudio> audios,
    required this.saveFolder,
    required this.modelIndex,
    AsrService Function(AsrConfig)? serviceFactory,
    AsrTextWriter? writeText,
    void Function()? onSaved,
  })  : config = _snapshotConfig(config),
        audios = List.unmodifiable(
          audios.map(
            (audio) => AsrTaskAudio(
              bytes: audio.bytes,
              name: audio.name,
              format: audio.format,
            ),
          ),
        ),
        _serviceFactory =
            serviceFactory ?? ((config) => AsrService(config: config)),
        _writeText = writeText ?? TextManifest.writeText,
        _onSaved = onSaved ?? _ignoreSaved;

  static AsrConfig _snapshotConfig(AsrConfig config) => config.copyWith(
        typeConfig: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(config.typeConfig)) as Map,
        ),
        customParams: config.customParams.map((param) => param.copy()).toList(),
      );

  static void _ignoreSaved() {}

  List<String> get taskIds => List.unmodifiable(
        (_jobs ?? const <_AsrTaskJob>[]).map((job) => job.taskId),
      );

  /// Creates the waiting tasks once and returns the same execution future for
  /// every later start call.
  Future<void> start() {
    if (_running != null) return _running!;
    final jobs = _jobs ??= _createJobs();
    for (final job in jobs) {
      notifier.registerCancellation(job.taskId, () => _cancel(job));
      unawaited(_computeRetryData(job));
    }
    _running = _runQueue(jobs);
    return _running!;
  }

  List<_AsrTaskJob> _createJobs() => [
        for (final audio in audios)
          () {
            final title = audio.isUrl
                ? 'ASR_${_urlDisplayName(audio.name)}'
                : 'ASR_${audio.name}';
            final taskId = notifier.addTask(
              type: BackgroundTaskType.asr,
              title: title,
              startImmediately: false,
            );
            return _AsrTaskJob(taskId, audio, title);
          }(),
      ];

  static String _urlDisplayName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
      final name = segments.isEmpty ? uri.host : segments.last;
      return name.length <= 40 ? name : name.substring(0, 40);
    } catch (_) {
      return url;
    }
  }

  static Map<String, dynamic> _buildRetryData(
    AsrTaskAudio audio,
    int modelIndex,
    String saveFolder,
  ) =>
      <String, dynamic>{
        'type': 'asr',
        'audios': [
          if (audio.isUrl)
            <String, dynamic>{
              'url': audio.name,
              'name': audio.name,
              'format': 'url',
            }
          else
            <String, dynamic>{
              'bytes': base64Encode(audio.bytes),
              'name': audio.name,
              'format': audio.format,
            },
        ],
        'modelIndex': modelIndex,
        'saveFolder': saveFolder,
      };

  Future<void> _computeRetryData(_AsrTaskJob job) async {
    try {
      final retryData = await Isolate.run(
        () => _buildRetryData(job.audio, modelIndex, saveFolder),
      );
      _setRetryData(job, retryData);
    } catch (_) {
      // Isolate.run is unavailable on some targets, including Flutter Web.
      try {
        _setRetryData(job, _buildRetryData(job.audio, modelIndex, saveFolder));
      } catch (_) {
        // Retry data is optional for the running request.
      }
    }
  }

  void _setRetryData(_AsrTaskJob job, Map<String, dynamic> retryData) {
    if (notifier.taskById(job.taskId) == null) return;
    notifier.setRetryData(job.taskId, retryData);
  }

  void _cancel(_AsrTaskJob job) {
    if (!job.cancelToken.isCancelled) job.cancelToken.cancel('已取消');
    job.service?.close(force: true);
  }

  void _checkActive(_AsrTaskJob job) {
    final task = notifier.taskById(job.taskId);
    if (task == null || task.status != TaskStatus.running) _cancel(job);
    if (job.cancelToken.isCancelled) throw job.cancelToken.cancelError!;
  }

  Future<void> _runQueue(List<_AsrTaskJob> jobs) async {
    for (final job in jobs) {
      if (!notifier.startTaskIfWaiting(job.taskId)) {
        notifier.unregisterCancellation(job.taskId);
        continue;
      }
      await _runTask(job);
    }
  }

  Future<void> _runTask(_AsrTaskJob job) async {
    AsrService? service;
    var hasResult = false;
    try {
      _checkActive(job);
      notifier.updateStep(job.taskId, 0, running: true);
      service = job.service = _serviceFactory(config);
      final result = job.audio.isUrl
          ? await service.transcribeFromUrl(
              job.audio.name,
              cancelToken: job.cancelToken,
              onProgress: (event) => _reportProgress(job, event),
            )
          : await service.transcribe(
              audioBytes: job.audio.bytes,
              audioFormat: job.audio.format,
              cancelToken: job.cancelToken,
              onProgress: (event) => _reportProgress(job, event),
            );
      _checkActive(job);
      hasResult = true;
      notifier.setResult(job.taskId, result.text, folder: saveFolder);
      _checkActive(job);
      for (var index = 0; index < 4; index++) {
        notifier.updateStep(job.taskId, index, completed: true);
      }
      notifier.updateStep(job.taskId, 4, running: true);
      await AsrResultSaver(
        taskId: job.taskId,
        notifier: notifier,
        title: job.title,
        folder: saveFolder,
        cancelToken: job.cancelToken,
        onSaved: _onSaved,
        writeText: _writeText,
      ).saveResult(result.subtitle ?? result.text, format: result.outputFormat);
    } catch (error) {
      if (job.cancelToken.isCancelled) return;
      final task = notifier.taskById(job.taskId);
      if (task == null) return;

      if (!hasResult &&
          error is AsrChunkedTranscriptionException &&
          error.partialText.isNotEmpty) {
        if (task.status != TaskStatus.running) {
          _cancel(job);
          return;
        }
        notifier.setResult(
          job.taskId,
          error.partialText,
          isComplete: false,
          folder: saveFolder,
        );
      }
      for (var index = 0; index < task.steps.length; index++) {
        if (task.steps[index].running) {
          notifier.updateStep(job.taskId, index, failed: true, error: '$error');
        } else if (task.steps[index].status == BgStepStatus.pending) {
          notifier.updateStep(job.taskId, index, skipped: true);
        }
      }
      final rawRequest = <String, dynamic>{
        if (service?.lastRequestUrl != null) 'url': service!.lastRequestUrl,
        if (service?.lastRequestHeaders != null)
          'headers': service!.lastRequestHeaders,
        if (service?.lastRequestBody != null) 'body': service!.lastRequestBody,
      };
      final rawResponse = <String, dynamic>{
        if (service?.lastResponseStatusCode != null)
          'statusCode': service!.lastResponseStatusCode,
        if (service?.lastResponseHeaders != null)
          'headers': service!.lastResponseHeaders,
        if (service?.lastResponseData != null)
          'data': service!.lastResponseData,
      };
      notifier.failTask(
        job.taskId,
        error: hasResult ? '音频转写结果保存失败: $error' : '音频转写失败: $error',
        rawRequest: rawRequest,
        rawResponse: rawResponse,
      );
    } finally {
      notifier.unregisterCancellation(job.taskId);
      service?.close();
      job.service = null;
    }
  }

  void _reportProgress(_AsrTaskJob job, AsrRequestProgress event) {
    _checkActive(job);
    final chunk = event.chunkCount > 1
        ? '（片段 ${event.chunkIndex}/${event.chunkCount}）'
        : '';
    switch (event.phase) {
      case AsrRequestPhase.uploading:
        notifier.updateStep(job.taskId, 0, completed: true);
        final label = event.totalSendBytes > 0
            ? '上传音频$chunk ${((event.sentBytes * 100) ~/ event.totalSendBytes).clamp(0, 100)}%'
            : '上传音频$chunk';
        notifier.updateStep(job.taskId, 1, running: true, label: label);
      case AsrRequestPhase.waiting:
        notifier.updateStep(job.taskId, 0, completed: true);
        notifier.updateStep(job.taskId, 1, completed: true);
        final label = event.chunkCount > 1
            ? '转写中（片段 ${event.chunkIndex}/${event.chunkCount}）'
            : '转写中';
        notifier.updateStep(job.taskId, 2, running: true, label: label);
      case AsrRequestPhase.receiving:
        if (event.chunkIndex == event.chunkCount) {
          notifier.updateStep(job.taskId, 2, completed: true);
          final label = event.totalReceiveBytes > 0
              ? '接收结果 ${((event.receivedBytes * 100) ~/ event.totalReceiveBytes).clamp(0, 100)}%'
              : '接收结果';
          notifier.updateStep(job.taskId, 3, running: true, label: label);
        } else {
          notifier.updateStep(
            job.taskId,
            2,
            running: true,
            label: '转写中（接收片段 ${event.chunkIndex}/${event.chunkCount}）',
          );
        }
      case AsrRequestPhase.responseReceived:
      case AsrRequestPhase.chunkCompleted:
        if (event.chunkIndex == event.chunkCount) {
          notifier.updateStep(job.taskId, 2, completed: true);
          notifier.updateStep(job.taskId, 3, running: true, label: '接收结果');
        } else {
          final label = event.phase == AsrRequestPhase.chunkCompleted
              ? '转写中（已完成片段 ${event.chunkIndex}/${event.chunkCount}）'
              : '转写中（片段 ${event.chunkIndex}/${event.chunkCount} 已返回）';
          notifier.updateStep(job.taskId, 2, running: true, label: label);
        }
    }
  }
}
