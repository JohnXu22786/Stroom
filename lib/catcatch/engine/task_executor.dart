import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
import 'dart_cat_catch_sniffer.dart';
import 'download_manager.dart';
import 'ffmpeg_converter.dart';
import 'executor_utils.dart';
import 'executor_media.dart';
import 'executor_save.dart';

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
          '此功能需要登录账户后使用，请使用右上角浏览器内登录功能',
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
    ensureExecutorSteps(steps);
    String? downloadedFilePath = task.downloadedFilePath;
    List<MediaResource> detectedMedia = List.from(task.detectedMedia);
    MediaResource? selectedMedia = task.selectedMedia;
    String? taskError;
    try {
      for (int i = startFromIndex; i < steps.length; i++) {
        if (cancelToken?.isCancelled ?? false) return null;
        final stepType = steps[i].type;
        if (steps[i].completed || steps[i].skipped) continue;
        markExecutorStep(steps, i, running: true);
        switch (stepType) {
          case StepType.fetching:
            onUpdate(task.copyWith(steps: steps, status: TaskStatus.running));
            final (detectedResources, fetchedPageTitle) =
                await _executeFetchAndAnalyze(
                    task: task,
                    steps: steps,
                    onUpdate: onUpdate,
                    cancelToken: cancelToken);
            detectedMedia = detectedResources;
            // Update local task with page title so downstream steps can use it
            if (fetchedPageTitle != null &&
                fetchedPageTitle.isNotEmpty &&
                fetchedPageTitle != task.title) {
              task = task.copyWith(
                title: fetchedPageTitle,
                metadata: {
                  ...task.metadata,
                  'pageTitle': fetchedPageTitle,
                },
              );
            }
            break;
          case StepType.analyzing:
            markExecutorStep(steps, i, done: true);
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
            final beforeCount = detectedMedia.length;
            final filtered = SniffingEngine.filterByDuration(
                detectedMedia, task.expectedDurationSec,
                toleranceSec: DefaultRules.durationToleranceSeconds);
            // 检测音视频分轨并标记
            final withSplitTrack = detectSplitTracks(filtered);
            final detail = buildDurationFilterDetail(
                beforeCount, withSplitTrack.length, task.expectedDurationSec);
            markExecutorStep(steps, i, done: true, detail: detail);
            onUpdate(task.copyWith(
                steps: steps,
                detectedMedia: withSplitTrack,
                progress: calcExecutorProgress(steps)));
            detectedMedia = withSplitTrack;
            break;
          case StepType.userSelecting:
            if (selectedMedia == null && detectedMedia.length > 1) {
              final detail = '共${detectedMedia.length}个资源，请用户选择';
              onUpdate(task.copyWith(
                  steps: steps.map((s) {
                    if (s.type == StepType.userSelecting) {
                      return s.copyWith(detail: detail);
                    }
                    return s;
                  }).toList(),
                  status: TaskStatus.running,
                  detectedMedia: detectedMedia,
                  progress: calcExecutorProgress(steps)));
              return null;
            }
            selectedMedia ??=
                detectedMedia.isNotEmpty ? detectedMedia.first : null;
            if (selectedMedia == null) {
              throw Exception('未能获取到可用媒体资源，请检查URL是否正确以及目标网站是否可达');
            }
            final autoDetail =
                detectedMedia.length == 1 ? '剩余1个结果，自动进入下载' : '自动选择第1个结果，进入下载';
            markExecutorStep(steps, i, done: true, detail: autoDetail);
            onUpdate(task.copyWith(
                steps: steps,
                selectedMedia: selectedMedia,
                progress: calcExecutorProgress(steps)));
            break;
          case StepType.downloading:
            // 检查服务器是否支持断点续传
            if (task.metadata['resumeSupported'] == null &&
                selectedMedia != null) {
              final supportsResume =
                  await DownloadManager.checkServerResumeSupport(
                selectedMedia.url,
                headers: DefaultRules.buildBrowserHeaders(
                  referer: selectedMedia.initiator,
                ),
              );
              onUpdate(task.copyWith(
                metadata: {
                  ...task.metadata,
                  'resumeSupported': supportsResume ? 'true' : 'false',
                },
              ));
            }
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

            // 检查下载的文件是否仍然存在（防止重启后临时文件被清理）
            if (!File(downloadedFilePath).existsSync()) {
              debugPrint('[TaskExecutor] 下载文件不存在，重新下载: $downloadedFilePath');
              downloadedFilePath = await _executeDownload(
                task: task,
                steps: steps,
                media: selectedMedia ??
                    (detectedMedia.isNotEmpty ? detectedMedia.first : null),
                detectedMedia: detectedMedia,
                onUpdate: onUpdate,
                cancelToken: cancelToken,
              );
              if (downloadedFilePath == null) {
                throw Exception('重新下载失败，下载文件不存在');
              }
              // 更新任务状态中的下载路径
              onUpdate(task.copyWith(downloadedFilePath: downloadedFilePath));
            }

            // 检查是否需要用户确认转换操作（特殊格式/播放列表）
            final pendingConfirm = task.metadata['pendingConfirm'];
            if (pendingConfirm != 'done') {
              final ext = p
                  .extension(downloadedFilePath)
                  .toLowerCase()
                  .replaceAll('.', '');
              final isPlaylistSelected =
                  task.selectedMedia?.isPlaylist ?? false;
              if (isPlaylistSelected || isSpecialFormat(ext)) {
                onUpdate(task.copyWith(
                  steps: steps,
                  metadata: {
                    ...task.metadata,
                    'pendingConfirm': 'special_format',
                    'pendingConfirmFormat': ext,
                  },
                ));
                return null;
              }
            }

            // 普通格式文件不需要转码/合并，直接跳过
            final skipExt = p
                .extension(downloadedFilePath)
                .toLowerCase()
                .replaceAll('.', '');
            final isPlaylistSel = task.selectedMedia?.isPlaylist ?? false;
            if (!isPlaylistSel && !isSpecialFormat(skipExt)) {
              markExecutorStep(steps, i,
                  skipped: true, detail: '.$skipExt 格式无需转换，已跳过');
              onUpdate(task.copyWith(
                  steps: steps, progress: calcExecutorProgress(steps)));
              continue;
            }

            downloadedFilePath = await _executeConvert(
                task: task,
                steps: steps,
                inputPath: downloadedFilePath,
                onUpdate: onUpdate,
                cancelToken: cancelToken);
            break;
          case StepType.saving:
            downloadedFilePath = await executeSave(
                task: task,
                steps: steps,
                sourcePath: downloadedFilePath,
                onUpdate: onUpdate);
            break;
        }
      }
      markAllExecutorStepsDone(steps);
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
      // Format DioException with user-friendly Chinese message
      if (e is DioException) {
        taskError = formatDioError(e);
      } else {
        taskError = e.toString();
      }
      for (int i = startFromIndex; i < steps.length; i++) {
        if (steps[i].running) {
          markExecutorStep(steps, i, failed: true, error: taskError);
          break;
        }
      }
      onUpdate(task.copyWith(
          steps: steps,
          status: TaskStatus.failed,
          error: taskError,
          downloadedFilePath: downloadedFilePath,
          progress: calcExecutorProgress(steps)));
      return null;
    }
  }

  /// Step 0-1: 获取并分析
  /// 返回 (检测到的媒体资源列表, 网页标题)
  static Future<(List<MediaResource>, String?)> _executeFetchAndAnalyze({
    required CatCatchTask task,
    required List<StepStatus> steps,
    required void Function(CatCatchTask) onUpdate,
    CancelToken? cancelToken,
  }) async {
    var capturedPageTitle = task.title;

    // -----------------------------------------------------------------------
    // Tier 1: Use DartCatCatchSniffer (pure Dart, stream-based, HTML regex)
    // This handles direct media URLs, playlists, and HTML page parsing.
    // -----------------------------------------------------------------------
    final dartSniffer = DartCatCatchSniffer();
    try {
      final headers = DefaultRules.buildBrowserHeaders(
        referer: task.url,
      );

      final dartResult = await dartSniffer.sniff(
        task.url,
        headers: headers,
        cancelToken: cancelToken,
      );

      markExecutorStep(steps, 0,
          running: true, progress: dartResult.resources.isNotEmpty ? 80 : 40);
      onUpdate(task.copyWith(steps: steps, progress: 20));

      if (dartResult.resources.isNotEmpty) {
        // Dart sniffer found resources — use them directly
        var resources = dartResult.resources;

        // 主动探针：对可播放但缺少时长/分辨率信息的视频预先探测
        if (!(cancelToken?.isCancelled ?? false)) {
          resources = await probeMediaResources(resources);
        }

        markExecutorStep(steps, 0,
            done: true, detail: '获取到${resources.length}个媒体资源');
        markExecutorStep(steps, 1, done: true);
        onUpdate(task.copyWith(
            steps: steps,
            detectedMedia: resources,
            progress: calcExecutorProgress(steps)));
        return (resources, capturedPageTitle);
      }

      // If Dart sniffer says needsWebViewFallback, skip Tier 2 and go directly
      // to WebView sniffing
      if (dartResult.needsWebViewFallback) {
        // On web, HeadlessInAppWebView opens a visible browser window.
        // Skip WebView sniffing and fail with a clear message instead.
        if (kIsWeb) {
          throw Exception(
            '网页无法直接获取资源（需要浏览器环境），请尝试在移动端或桌面端使用该功能。'
            '或者直接粘贴视频/音频文件的直链地址。',
          );
        }
        debugPrint(
            '[TaskExecutor] DartCatCatchSniffer recommends WebView fallback');
        return await _fallbackToWebView(
          task: task,
          steps: steps,
          onUpdate: onUpdate,
          cancelToken: cancelToken,
          capturedPageTitle: capturedPageTitle,
          existingResources: const [],
        );
      }
    } catch (e) {
      debugPrint('[TaskExecutor] DartCatCatchSniffer failed: $e');
      // On web, if direct HTTP sniffing fails, don't fall through to Tier 2/3
      // because WebView will open a visible browser window.
      if (kIsWeb) {
        rethrow;
      }
      // Non-fatal — fall through to Tier 2 (on non-web platforms)
    } finally {
      dartSniffer.dispose();
    }

    // -----------------------------------------------------------------------
    // Tier 2: Traditional SniffingEngine (existing behavior)
    // -----------------------------------------------------------------------
    markExecutorStep(steps, 0, running: true, progress: 10);
    onUpdate(task.copyWith(steps: steps, progress: 5));

    try {
      var resources = await SniffingEngine.analyzeUrl(task.url,
          cancelToken: cancelToken, onProgress: (step, progress) {
        markExecutorStep(steps, 0, running: true, progress: progress);
        onUpdate(task.copyWith(steps: steps, progress: (progress * 20 ~/ 100)));
      });

      // -------------------------------------------------------------------
      // Tier 3: WebView sniffing if direct sniffing found nothing useful
      // -------------------------------------------------------------------
      final needsWebView = resources.isEmpty ||
          (resources.length == 1 &&
              !SniffingEngine.isMediaExtension(resources.first.ext));
      if (needsWebView && !(cancelToken?.isCancelled ?? false)) {
        // On web, HeadlessInAppWebView opens a visible browser window.
        // Skip WebView sniffing and fail with a clear message instead.
        if (kIsWeb) {
          throw Exception(
            '网页无法直接获取资源（需要浏览器环境），请尝试在移动端或桌面端使用该功能。'
            '或者直接粘贴视频/音频文件的直链地址。',
          );
        }
        var (webViewResources, pageTitle) = await _fallbackToWebView(
          task: task,
          steps: steps,
          onUpdate: onUpdate,
          cancelToken: cancelToken,
          capturedPageTitle: capturedPageTitle,
          existingResources: resources,
        );

        if (pageTitle != null && pageTitle.isNotEmpty) {
          capturedPageTitle = pageTitle;
        }
        resources = webViewResources;
      }

      // 主动探针：对可播放但缺少时长/分辨率信息的视频预先探测
      if (!(cancelToken?.isCancelled ?? false)) {
        resources = await probeMediaResources(resources);
      }

      markExecutorStep(steps, 0,
          done: true, detail: '获取到${resources.length}个媒体资源');
      markExecutorStep(steps, 1, done: true);
      onUpdate(task.copyWith(
          steps: steps,
          detectedMedia: resources,
          progress: calcExecutorProgress(steps)));
      return (resources, capturedPageTitle);
    } catch (e) {
      debugPrint('[TaskExecutor] All sniffing tiers failed: $e');
      rethrow;
    }
  }

  /// Fallback to WebView-based sniffing (Tier 3).
  ///
  /// Launches a headless WebView to discover media resources that require
  /// JavaScript rendering.
  static Future<(List<MediaResource>, String?)> _fallbackToWebView({
    required CatCatchTask task,
    required List<StepStatus> steps,
    required void Function(CatCatchTask) onUpdate,
    CancelToken? cancelToken,
    required String capturedPageTitle,
    required List<MediaResource> existingResources,
  }) async {
    markExecutorStep(steps, 0, running: true, progress: 50);
    onUpdate(task.copyWith(steps: steps, progress: 20));

    debugPrint(
        '[TaskExecutor] Direct sniffing found only ${existingResources.length} resource(s), '
        'launching WebView background sniffer');

    var resources = List<MediaResource>.from(existingResources);
    var pageTitle = capturedPageTitle;

    try {
      final (webViewResources, pTitle) = await WebViewSniffer.sniff(
        url: task.url,
        timeout: const Duration(seconds: 30),
        cancelToken: cancelToken,
        onProgress: (step, progress) {
          markExecutorStep(steps, 0,
              running: true, progress: 50 + (progress ~/ 2));
          onUpdate(task.copyWith(
              steps: steps, progress: 20 + (progress * 30 ~/ 100)));
        },
      );

      if (pTitle != null && pTitle.isNotEmpty) {
        pageTitle = pTitle;
      }

      // Merge results (dedup by URL)
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
    }

    return (resources, pageTitle);
  }

  /// Step 2: 解析播放列表
  static Future<List<MediaResource>?> _executeParsePlaylist(
      {required CatCatchTask task,
      required List<StepStatus> steps,
      required List<MediaResource> media,
      CancelToken? cancelToken}) async {
    final playlist = media.where((m) => m.isPlaylist).toList();
    if (playlist.isEmpty) {
      markExecutorStep(steps, 2, done: true);
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
      final totalCount = media.length + segmentMedia.length;
      markExecutorStep(steps, 2,
          done: true, detail: '获取到$totalCount个资源（播放列表${segments.length}个分段）');
      return [...media, ...segmentMedia];
    }
    markExecutorStep(steps, 2, done: true);
    return null;
  }

  static Future<String?> _executeDownload({
    required CatCatchTask task,
    required List<StepStatus> steps,
    required MediaResource? media,
    required List<MediaResource> detectedMedia,
    required void Function(CatCatchTask updated) onUpdate,
    CancelToken? cancelToken,
  }) async {
    if (media == null) throw Exception('未能获取到可用媒体资源，请检查URL是否正确以及目标网站是否可达');

    // Web 端无法绕过 CORS 下载，引导用户安装浏览器扩展
    if (kIsWeb) {
      throw Exception(webDownloadHint);
    }

    final referer = media.initiator;
    final browserHeaders = DefaultRules.buildBrowserHeaders(
      referer: referer,
    );

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
          // 使用网页标题命名播放列表合并文件
          final playlistBaseName = p.basenameWithoutExtension(
              buildDownloadFileName(media, task.metadata));
          final mergedPath = await DownloadManager.downloadSegmentsAndMerge(
            segmentUrls: segments,
            outputPath: p.join(downloadDir, '${playlistBaseName}_merged.ts'),
            headers: browserHeaders,
            concurrency: DefaultRules.maxConcurrency,
            onProgress: (completed, total, progress) {
              markExecutorStep(steps, 5, running: true, progress: progress);
              onUpdate(task.copyWith(
                  steps: steps, progress: calcExecutorProgress(steps)));
            },
            cancelToken: cancelToken,
            taskId: task.id,
          );
          markExecutorStep(steps, 5, done: true);
          onUpdate(task.copyWith(
              steps: steps, progress: calcExecutorProgress(steps)));
          return mergedPath;
        }
        final fileName = buildDownloadFileName(media, task.metadata);
        final tempDir = Directory(downloadDir);
        if (!await tempDir.exists()) await tempDir.create(recursive: true);
        final tempPath =
            p.join(downloadDir, '.$fileName${DefaultRules.tempFileSuffix}');

        final downloadedFilePath = await DownloadManager.downloadFile(
          url: media.url,
          saveDir: downloadDir,
          fileName: fileName,
          headers: browserHeaders,
          onProgress: (received, total) {
            final progress = total > 0 ? (received * 100 ~/ total) : 0;
            markExecutorStep(steps, 5,
                running: true, progress: progress.clamp(0, 100));
            onUpdate(task.copyWith(
                steps: steps, progress: calcExecutorProgress(steps)));
          },
          cancelToken: cancelToken,
          taskId: task.id,
          existingPath: tempPath,
        );
        markExecutorStep(steps, 5, done: true);
        onUpdate(
            task.copyWith(steps: steps, progress: calcExecutorProgress(steps)));
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
    // 防御性检查
    if (!File(inputPath).existsSync()) {
      throw FileSystemException('下载源文件不存在，请重新下载', inputPath);
    }
    final appDirPath = await AppStorage.directory;
    final outputDir = p.join(appDirPath, 'catcatch', 'converted');
    final outputName = '${p.basenameWithoutExtension(inputPath)}.mp4';
    final outputPath = p.join(outputDir, outputName);
    final result = await FFmpegConverter.convertToMp4(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: (progress) {
          markExecutorStep(steps, 6, running: true, progress: progress);
          onUpdate(task.copyWith(
              steps: steps, progress: calcExecutorProgress(steps)));
        },
        cancelToken: cancelToken);
    markExecutorStep(steps, 6, done: true);
    onUpdate(
        task.copyWith(steps: steps, progress: calcExecutorProgress(steps)));
    return result;
  }
}
