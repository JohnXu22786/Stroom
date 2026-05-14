import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import '../../services/storage_service.dart';
import '../../utils/retry_helper.dart';
import 'package:dio/dio.dart';
import '../config/default_rules.dart';
import '../models/catcatch_task.dart';
import '../models/media_resource.dart';
import 'sniffing_engine.dart';
import 'm3u8_parser.dart';
import 'webview_sniffer.dart';
import 'mpd_parser.dart';
import 'download_manager.dart';
import 'ffmpeg_converter.dart';

class TaskExecutor {
  TaskExecutor._();

  /// 执行完整流程
  static Future<String?> executeTask({
    required CatCatchTask task,
    required void Function(CatCatchTask updated) onUpdate,
    CancelToken? cancelToken,
  }) async {
    return _executeSteps(
        task: task,
        startFromIndex: 0,
        onUpdate: onUpdate,
        cancelToken: cancelToken);
  }

  /// 从指定步骤重试
  static Future<String?> retryFromStep({
    required CatCatchTask task,
    required StepType fromStep,
    required void Function(CatCatchTask updated) onUpdate,
    CancelToken? cancelToken,
  }) async {
    try {
      final stepIndex = StepType.values.indexOf(fromStep);
      if (stepIndex < 0) throw ArgumentError('Unknown step type: $fromStep');
      final newSteps = List<StepStatus>.from(task.steps);
      for (int i = stepIndex; i < newSteps.length; i++) {
        newSteps[i] = StepStatus.pending(newSteps[i].type);
      }
      final updatedTask = task.copyWith(
        status: TaskStatus.running,
        steps: newSteps,
        progress: stepIndex > 0
            ? ((stepIndex * 100 ~/ StepType.values.length).clamp(0, 100))
            : 0,
        clearError: true,
      );
      onUpdate(updatedTask);
      return await _executeSteps(
          task: updatedTask,
          startFromIndex: stepIndex,
          onUpdate: onUpdate,
          cancelToken: cancelToken);
    } catch (e) {
      if (e is UnsupportedError) {
        throw Exception(
          '此功能需要原生平台支持 (Android/iOS/Windows/Mac/Linux)，Web 平台不可用',
        );
      }
      rethrow;
    }
  }

  /// 从指定索引执行步骤
  static Future<String?> _executeSteps({
    required CatCatchTask task,
    required int startFromIndex,
    required void Function(CatCatchTask updated) onUpdate,
    CancelToken? cancelToken,
  }) async {
    return _executeStepsInternal(
      task: task,
      startFromIndex: startFromIndex,
      onUpdate: onUpdate,
      cancelToken: cancelToken,
    );
  }

  /// 从指定索引执行步骤 (internal)
  static Future<String?> _executeStepsInternal({
    required CatCatchTask task,
    required int startFromIndex,
    required void Function(CatCatchTask updated) onUpdate,
    CancelToken? cancelToken,
  }) async {
    final steps = List<StepStatus>.from(task.steps);
    _ensureSteps(steps);
    String? downloadedFilePath = task.downloadedFilePath;
    List<MediaResource> detectedMedia = List.from(task.detectedMedia);
    MediaResource? selectedMedia = task.selectedMedia;
    String? taskError;
    try {
      for (int i = startFromIndex; i < steps.length; i++) {
        if (cancelToken?.isCancelled ?? false) return null;
        final stepType = steps[i].type;
        if (steps[i].completed) continue;
        _markStep(steps, i, running: true);
        switch (stepType) {
          case StepType.fetching:
            onUpdate(task.copyWith(steps: steps, status: TaskStatus.running));
            detectedMedia = await _executeFetchAndAnalyze(
                task: task,
                steps: steps,
                onUpdate: onUpdate,
                cancelToken: cancelToken);
            break;
          case StepType.analyzing:
            _markStep(steps, i, done: true);
            onUpdate(task.copyWith(steps: steps));
            break;
          case StepType.parsingPlaylist:
            final result = await _executeParsePlaylist(
                task: task,
                steps: steps,
                media: detectedMedia,
                cancelToken: cancelToken);
            if (result != null) detectedMedia = result;
            onUpdate(task.copyWith(steps: steps, detectedMedia: detectedMedia));
            break;
          case StepType.filtering:
            final filtered = SniffingEngine.filterByDuration(
                detectedMedia, task.expectedDurationSec);
            _markStep(steps, i, done: true);
            onUpdate(task.copyWith(
                steps: steps,
                detectedMedia: filtered,
                progress: _calcProgress(steps)));
            detectedMedia = filtered;
            break;
          case StepType.userSelecting:
            if (selectedMedia == null && detectedMedia.length > 1) {
              onUpdate(task.copyWith(steps: steps, status: TaskStatus.running));
              return null;
            }
            selectedMedia ??=
                detectedMedia.isNotEmpty ? detectedMedia.first : null;
            if (selectedMedia == null) throw Exception('没有找到可下载的媒体资源');
            _markStep(steps, i, done: true);
            onUpdate(task.copyWith(
                steps: steps,
                selectedMedia: selectedMedia,
                progress: _calcProgress(steps)));
            break;
          case StepType.downloading:
            downloadedFilePath = await _executeDownload(
              task: task,
              steps: steps,
              media: selectedMedia ??
                  (detectedMedia.isNotEmpty ? detectedMedia.first : null),
              detectedMedia: detectedMedia,
              onUpdate: onUpdate,
              cancelToken: cancelToken,
            );
            break;
          case StepType.converting:
            if (downloadedFilePath == null) throw Exception('下载文件路径为空，无法转换');
            downloadedFilePath = await _executeConvert(
                task: task,
                steps: steps,
                inputPath: downloadedFilePath,
                onUpdate: onUpdate,
                cancelToken: cancelToken);
            break;
          case StepType.saving:
            downloadedFilePath = await _executeSave(
                task: task,
                steps: steps,
                sourcePath: downloadedFilePath,
                onUpdate: onUpdate);
            break;
        }
      }
      _markAllDone(steps);
      onUpdate(task.copyWith(
          steps: steps,
          status: TaskStatus.completed,
          progress: 100,
          completedAt: DateTime.now(),
          downloadedFilePath: downloadedFilePath));
      return downloadedFilePath;
    } catch (e, s) {
      if (cancelToken?.isCancelled ?? false) return null;
      debugPrint('[TaskExecutor] Task failed: $e\n$s');
      taskError = e.toString();
      for (int i = startFromIndex; i < steps.length; i++) {
        if (steps[i].running) {
          _markStep(steps, i, failed: true, error: taskError);
          break;
        }
      }
      onUpdate(task.copyWith(
          steps: steps,
          status: TaskStatus.failed,
          error: taskError,
          downloadedFilePath: downloadedFilePath));
      return null;
    }
  }

  /// Step 0-1: 获取并分析
  static Future<List<MediaResource>> _executeFetchAndAnalyze({
    required CatCatchTask task,
    required List<StepStatus> steps,
    required void Function(CatCatchTask) onUpdate,
    CancelToken? cancelToken,
  }) async {
    // Step 1: Direct HTTP sniffing
    var resources = await SniffingEngine.analyzeUrl(task.url,
        cancelToken: cancelToken, onProgress: (step, progress) {
      _markStep(steps, 0, running: true, progress: progress);
      onUpdate(task.copyWith(steps: steps, progress: (progress * 20 ~/ 100)));
    });

    // Step 2: Launch WebView if direct sniffing found nothing useful.
    // Cases: 0 resources, or 1 resource whose ext is not a known media extension
    // (e.g. Bilibili page URL → ext="" → isMediaExtension("")=false → WebView launches).
    final needsWebView = resources.isEmpty ||
        (resources.length == 1 &&
            !SniffingEngine.isMediaExtension(resources.first.ext));
    if (needsWebView && !(cancelToken?.isCancelled ?? false)) {
      _markStep(steps, 0, running: true, progress: 50);
      onUpdate(task.copyWith(steps: steps, progress: 20));

      debugPrint(
          '[TaskExecutor] Direct sniffing found only ${resources.length} resource(s), '
          'launching WebView background sniffer');

      try {
        final webViewResources = await WebViewSniffer.sniff(
          url: task.url,
          timeout: const Duration(seconds: 30),
          cancelToken: cancelToken,
          onProgress: (step, progress) {
            _markStep(steps, 0, running: true, progress: 50 + (progress ~/ 2));
            onUpdate(task.copyWith(
                steps: steps, progress: 20 + (progress * 30 ~/ 100)));
          },
        );

        // Merge: keep direct sniff results first (usually higher quality), then add new ones
        final existingUrls = resources.map((r) => r.url).toSet();
        for (final r in webViewResources) {
          if (!existingUrls.contains(r.url)) {
            resources = [...resources, r];
          }
        }

        debugPrint(
            '[TaskExecutor] WebView sniffer found ${webViewResources.length} resource(s), '
            'total after merge: ${resources.length}');
      } catch (e) {
        debugPrint(
            '[TaskExecutor] WebView sniffing failed, continuing with direct results: $e');
        // Non-fatal - continue with whatever direct sniffing found
      }
    }

    _markStep(steps, 0, done: true);
    _markStep(steps, 1, done: true);
    onUpdate(task.copyWith(
        steps: steps,
        detectedMedia: resources,
        progress: _calcProgress(steps)));
    return resources;
  }

  /// Step 2: 解析播放列表
  static Future<List<MediaResource>?> _executeParsePlaylist(
      {required CatCatchTask task,
      required List<StepStatus> steps,
      required List<MediaResource> media,
      CancelToken? cancelToken}) async {
    final playlist = media.where((m) => m.isPlaylist).toList();
    if (playlist.isEmpty) {
      _markStep(steps, 2, done: true);
      return null;
    }
    for (final pl in playlist) {
      final dio = Dio();
      cancelToken?.whenCancel.then((_) {
        dio.close();
      });
      String content;
      try {
        final headers = <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        };
        if (pl.initiator != null) headers['Referer'] = pl.initiator!;
        final response = await dio.get(
          pl.url,
          options: Options(headers: headers),
        );
        content = response.data is String ? response.data as String : '';
      } finally {
        dio.close();
      }
      List<String> segments;
      if (pl.isM3U8) {
        segments = await M3U8Parser.parsePlaylist(content, pl.url);
      } else if (pl.isMPD) {
        segments = await MPDParser.parseManifest(content, pl.url);
      } else {
        continue;
      }
      final segmentMedia = segments.map((segUrl) {
        final (name, ext) = SniffingEngine.parseFileName(segUrl);
        return MediaResource(
            url: segUrl,
            name: name,
            ext: ext.isEmpty ? 'ts' : ext,
            initiator: pl.url,
            isPlayable: false,
            isPlaylist: false);
      }).toList();
      _markStep(steps, 2, done: true);
      return [...media, ...segmentMedia];
    }
    _markStep(steps, 2, done: true);
    return null;
  }

  /// Step 5: 下载
  static Future<String?> _executeDownload({
    required CatCatchTask task,
    required List<StepStatus> steps,
    required MediaResource? media,
    required List<MediaResource> detectedMedia,
    required void Function(CatCatchTask updated) onUpdate,
    CancelToken? cancelToken,
  }) async {
    if (media == null) throw Exception('没有可下载的媒体资源');
    return RetryHelper.retry(
      fn: () async {
        final appDirPath = await AppStorage.directory;
        final downloadDir = p.join(appDirPath, 'catcatch', 'downloads');
        if (media.isPlaylist) {
          final segments = detectedMedia
              .where((m) => !m.isPlaylist && m.initiator == media.url)
              .map((m) => m.url)
              .toList();
          if (segments.isEmpty) throw Exception('播放列表没有可下载的分段');
          final mergedPath = await DownloadManager.downloadSegmentsAndMerge(
            segmentUrls: segments,
            outputPath: p.join(downloadDir,
                '${p.basenameWithoutExtension(media.url)}_merged.ts'),
            concurrency: DefaultRules.maxConcurrency,
            onProgress: (completed, total, progress) {
              _markStep(steps, 5, running: true, progress: progress);
              onUpdate(
                  task.copyWith(steps: steps, progress: _calcProgress(steps)));
            },
            cancelToken: cancelToken,
            taskId: task.id,
          );
          _markStep(steps, 5, done: true);
          onUpdate(task.copyWith(steps: steps, progress: _calcProgress(steps)));
          return mergedPath;
        }
        final ext = media.ext;
        final fileName = '${media.name}.$ext';
        final downloadedFilePath = await DownloadManager.downloadFile(
          url: media.url,
          saveDir: downloadDir,
          fileName: fileName,
          onProgress: (received, total) {
            final progress = total > 0 ? (received * 100 ~/ total) : 0;
            _markStep(steps, 5,
                running: true, progress: progress.clamp(0, 100));
            onUpdate(
                task.copyWith(steps: steps, progress: _calcProgress(steps)));
          },
          cancelToken: cancelToken,
        );
        _markStep(steps, 5, done: true);
        onUpdate(task.copyWith(steps: steps, progress: _calcProgress(steps)));
        return downloadedFilePath;
      },
      maxRetries: 2,
      retryableCheck: (error) {
        if (cancelToken?.isCancelled ?? false) return false;
        return RetryHelper.isRetryableError(error);
      },
    );
  }

  /// Step 6: 转换
  static Future<String> _executeConvert(
      {required CatCatchTask task,
      required List<StepStatus> steps,
      required String inputPath,
      required void Function(CatCatchTask) onUpdate,
      CancelToken? cancelToken}) async {
    final appDirPath = await AppStorage.directory;
    final outputDir = p.join(appDirPath, 'catcatch', 'converted');
    final outputName = '${p.basenameWithoutExtension(inputPath)}.mp4';
    final outputPath = p.join(outputDir, outputName);
    final result = await FFmpegConverter.convertToMp4(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: (progress) {
          _markStep(steps, 6, running: true, progress: progress);
          onUpdate(task.copyWith(steps: steps, progress: _calcProgress(steps)));
        },
        cancelToken: cancelToken);
    _markStep(steps, 6, done: true);
    onUpdate(task.copyWith(steps: steps, progress: _calcProgress(steps)));
    return result;
  }

  /// Step 7: 保存
  static Future<String> _executeSave(
      {required CatCatchTask task,
      required List<StepStatus> steps,
      required String? sourcePath,
      required void Function(CatCatchTask) onUpdate}) async {
    if (sourcePath == null) throw Exception('源文件路径为空，无法保存');
    final appDirPath = await AppStorage.directory;
    final saveDir = p.join(appDirPath, 'catcatch', 'completed');
    final saveDirObj = Directory(saveDir);
    if (!await saveDirObj.exists()) await saveDirObj.create(recursive: true);
    final fileName = p.basename(sourcePath);
    final finalPath = await _uniquePath(p.join(saveDir, fileName));
    await File(sourcePath).copy(finalPath);
    _markStep(steps, 7, done: true);
    onUpdate(task.copyWith(steps: steps, progress: _calcProgress(steps)));
    return finalPath;
  }

  static void _ensureSteps(List<StepStatus> steps) {
    final existing = {for (final s in steps) s.type};
    for (final type in StepType.values) {
      if (!existing.contains(type)) {
        final insertAt = StepType.values.indexOf(type);
        if (insertAt <= steps.length) {
          steps.insert(insertAt, StepStatus.pending(type));
        } else {
          steps.add(StepStatus.pending(type));
        }
      }
    }
  }

  static void _markStep(List<StepStatus> steps, int index,
      {bool done = false,
      bool running = false,
      bool failed = false,
      String? error,
      int progress = 0}) {
    if (index >= steps.length) return;
    steps[index] = steps[index].copyWith(
        completed: done,
        running: running,
        failed: failed,
        error: error,
        progress: progress);
  }

  static void _markAllDone(List<StepStatus> steps) {
    for (int i = 0; i < steps.length; i++) {
      steps[i] = steps[i].copyWith(
          completed: true, running: false, failed: false, progress: 100);
    }
  }

  static int _calcProgress(List<StepStatus> steps) {
    if (steps.isEmpty) return 0;
    int sum = 0;
    for (final s in steps) {
      if (s.completed) {
        sum += 100;
      } else if (s.running) {
        sum += s.progress;
      }
    }
    return (sum ~/ steps.length).clamp(0, 100);
  }

  static Future<String> _uniquePath(String path) async {
    final file = File(path);
    if (!await file.exists()) return path;
    final dir = p.dirname(path);
    final name = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    for (int i = 1; i < 100; i++) {
      final newPath = p.join(dir, '${name}_$i$ext');
      if (!await File(newPath).exists()) return newPath;
    }
    return path;
  }
}
