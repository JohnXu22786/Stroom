import 'dart:async';
import 'dart:convert';
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
import 'media_probe.dart';
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
        if (steps[i].completed || steps[i].skipped) continue;
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
                detectedMedia, task.expectedDurationSec,
                toleranceSec: DefaultRules.durationToleranceSeconds);
            // 检测音视频分轨并标记
            final withSplitTrack = _detectSplitTracks(filtered);
            _markStep(steps, i, done: true);
            onUpdate(task.copyWith(
                steps: steps,
                detectedMedia: withSplitTrack,
                progress: _calcProgress(steps)));
            detectedMedia = withSplitTrack;
            break;
          case StepType.userSelecting:
            if (selectedMedia == null && detectedMedia.length > 1) {
              onUpdate(task.copyWith(steps: steps, status: TaskStatus.running, detectedMedia: detectedMedia));
              return null;
            }
            selectedMedia ??=
                detectedMedia.isNotEmpty ? detectedMedia.first : null;
            if (selectedMedia == null) {
              throw Exception('未能获取到可用媒体资源，请检查URL是否正确以及目标网站是否可达');
            }
            _markStep(steps, i, done: true);
            onUpdate(task.copyWith(
                steps: steps,
                selectedMedia: selectedMedia,
                progress: _calcProgress(steps)));
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
              if (isPlaylistSelected || _isSpecialFormat(ext)) {
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
            final isPlaylistSel =
                task.selectedMedia?.isPlaylist ?? false;
            if (!isPlaylistSel && !_isSpecialFormat(skipExt)) {
              _markStep(steps, i, skipped: true);
              onUpdate(task.copyWith(
                  steps: steps, progress: _calcProgress(steps)));
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
      // Format DioException with user-friendly Chinese message
      if (e is DioException) {
        taskError = _formatDioError(e);
      } else {
        taskError = e.toString();
      }
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

    // 主动探针：对可播放但缺少时长/分辨率信息的视频预先探测
    if (!(cancelToken?.isCancelled ?? false)) {
      resources = await _probeMediaResources(resources);
    }

    _markStep(steps, 0, done: true);
    _markStep(steps, 1, done: true);
    onUpdate(task.copyWith(
        steps: steps,
        detectedMedia: resources,
        progress: _calcProgress(steps)));
    return resources;
  }

  /// 对可播放但缺少信息的媒体资源进行主动探测（时长、分辨率）。
  static Future<List<MediaResource>> _probeMediaResources(
      List<MediaResource> resources) async {
    if (kIsWeb) return resources;

    final result = <MediaResource>[];
    for (final res in resources) {
      if (res.isPlayable && (res.duration == null || res.width == null)) {
        final probe = await MediaProbe.probe(res.url);
        result.add(res.copyWith(
          duration: probe.duration != null
              ? _formatDuration(probe.duration!)
              : res.duration,
          width: probe.width ?? res.width,
          height: probe.height ?? res.height,
        ));
        continue;
      }
      result.add(res);
    }
    return result;
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
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
  /// Web 端提示信息
  static const String webDownloadHint = 'Web 端不支持直接下载媒体文件。\n'
      '请安装浏览器扩展「CatCatch（猫抓）」后再试。\n'
      '作者：笨笨猫（xifangczy），完全免费开源。\n'
      '注意：请认准作者，避免下载到付费版/山寨版。\n'
      'GitHub 地址: https://github.com/xifangczy/cat-catch';

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
          final mergedPath = await DownloadManager.downloadSegmentsAndMerge(
            segmentUrls: segments,
            outputPath: p.join(downloadDir,
                '${p.basenameWithoutExtension(media.url)}_merged.ts'),
            headers: browserHeaders,
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
        final tempDir = Directory(downloadDir);
        if (!await tempDir.exists()) await tempDir.create(recursive: true);
        final tempPath =
            p.join(downloadDir, '.${fileName}${DefaultRules.tempFileSuffix}');

        final downloadedFilePath = await DownloadManager.downloadFile(
          url: media.url,
          saveDir: downloadDir,
          fileName: fileName,
          headers: browserHeaders,
          onProgress: (received, total) {
            final progress = total > 0 ? (received * 100 ~/ total) : 0;
            _markStep(steps, 5,
                running: true, progress: progress.clamp(0, 100));
            onUpdate(
                task.copyWith(steps: steps, progress: _calcProgress(steps)));
          },
          cancelToken: cancelToken,
          taskId: task.id,
          existingPath: tempPath,
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

  /// 检测疑似音视频分轨资源
  /// 对同一时长区间内既有音频又有视频的情况进行标记
  static List<MediaResource> _detectSplitTracks(List<MediaResource> media) {
    if (media.length < 2) return media;

    final result = List<MediaResource>.from(media);
    final audioList = <int>[];
    final videoList = <int>[];

    // 分离音视频索引
    for (int i = 0; i < result.length; i++) {
      if (result[i].isAudio) audioList.add(i);
      if (result[i].isVideo) videoList.add(i);
    }

    if (audioList.isEmpty || videoList.isEmpty) return result;

    // 按时长相似度分组
    for (final ai in audioList) {
      for (final vi in videoList) {
        if (result[ai].groupId != null || result[vi].groupId != null) continue;
        final aDuration = result[ai].duration;
        final vDuration = result[vi].duration;
        if (aDuration != null && vDuration != null) {
          final aSec = _parseDurationToSeconds(aDuration);
          final vSec = _parseDurationToSeconds(vDuration);
          if (aSec != null && vSec != null && (aSec - vSec).abs() <= 2) {
            final groupId = 'split_${result[ai].name}_${result[vi].name}';
            result[ai] = result[ai].copyWith(
              groupId: groupId,
              isLikelySplitTrack: true,
            );
            result[vi] = result[vi].copyWith(
              groupId: groupId,
              isLikelySplitTrack: true,
            );
          }
        } else {
          // 无时长信息时，通过文件名相似度判断
          final aName = result[ai].name.toLowerCase();
          final vName = result[vi].name.toLowerCase();
          final commonPrefix = _longestCommonPrefix(aName, vName);
          if (commonPrefix.length > 5 &&
              (aName.contains('audio') ||
                  vName.contains('audio') ||
                  aName.contains('video') ||
                  vName.contains('video'))) {
            final groupId = 'split_$commonPrefix';
            result[ai] = result[ai].copyWith(
              groupId: groupId,
              isLikelySplitTrack: true,
            );
            result[vi] = result[vi].copyWith(
              groupId: groupId,
              isLikelySplitTrack: true,
            );
          }
        }
      }
    }

    return result;
  }

  /// 计算两个字符串的最长公共前缀
  static String _longestCommonPrefix(String a, String b) {
    final minLen = a.length < b.length ? a.length : b.length;
    int i = 0;
    while (i < minLen && a[i] == b[i]) {
      i++;
    }
    return a.substring(0, i);
  }

  /// 将 "00:12:34.567" 格式的时长转为秒
  static double? _parseDurationToSeconds(String duration) {
    final parts = duration.split(':');
    if (parts.length == 3) {
      final h = double.tryParse(parts[0]) ?? 0;
      final m = double.tryParse(parts[1]) ?? 0;
      final s = double.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    if (parts.length == 2) {
      final m = double.tryParse(parts[0]) ?? 0;
      final s = double.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return double.tryParse(duration);
  }

  /// 判断扩展名是否为需要用户确认转换的特殊格式
  ///
  /// 特殊格式通常指非标准播放格式（如 ts、flv 等），
  /// 需要询问用户是否自动用 ffmpeg 转码为 mp4。
  static bool _isSpecialFormat(String ext) {
    const specialFormats = {
      'ts',
      'flv',
      'f4v',
      'hlv',
      'mkv',
      'avi',
      'wmv',
      'mpeg',
      'mpg',
      'm4s',
      'ogg',
      'ogv',
      'm3u8',
      'm3u',
      'mpd',
    };
    return specialFormats.contains(ext.toLowerCase());
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
      bool skipped = false,
      String? error,
      int progress = 0}) {
    if (index >= steps.length) return;
    steps[index] = steps[index].copyWith(
        completed: done,
        running: running,
        failed: failed,
        skipped: skipped,
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

  /// Format DioException, preserving original error details.
  static String _formatDioError(DioException e) {
    final String originalMsg = e.message ?? '';
    String extra;
    if (originalMsg.isNotEmpty) {
      extra = '\n原始错误: $originalMsg';
    } else {
      extra = '';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络或服务器状态$extra';
      case DioExceptionType.sendTimeout:
        return '发送请求超时$extra';
      case DioExceptionType.receiveTimeout:
        return '接收响应超时，服务器响应过慢$extra';
      case DioExceptionType.connectionError:
        if (kIsWeb) {
          return '无法连接到服务器。\n\n$webDownloadHint';
        }
        return '无法连接到服务器，请检查URL是否正确$extra';
      case DioExceptionType.badCertificate:
        return '服务器证书验证失败$extra';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        String bodyStr;
        if (body is List<int>) {
          try {
            bodyStr = utf8.decode(body);
          } catch (_) {
            bodyStr = body.toString();
          }
        } else {
          bodyStr = body?.toString() ?? '';
        }
        return '服务器返回错误 (HTTP $code)${bodyStr.isNotEmpty ? ": $bodyStr" : ""}$extra';
      case DioExceptionType.cancel:
        return '请求已取消$extra';
      default:
        return '网络错误: ${e.message ?? "未知错误"}';
    }
  }
}
