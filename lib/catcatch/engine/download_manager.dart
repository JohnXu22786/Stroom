import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import '../config/default_rules.dart';
import 'download_manager_shared.dart';

/// 下载管理器
///
/// 支持：
/// - 单文件下载（含断点续传）
/// - 多分段并行下载 + 合并
/// - 进度回调（精确到每个分段）
/// - 下载进度持久化（应用重启后可恢复）
class DownloadManager {
  DownloadManager._();

  static final Set<String> _activeDownloadPaths = <String>{};
  static final Map<String, int> _activeLegacyPartialUsers = <String, int>{};

  static bool _reserveLegacyPartial(String? path) {
    if (path == null) return false;
    final canUsePartial = !_activeLegacyPartialUsers.containsKey(path);
    _activeLegacyPartialUsers.update(path, (users) => users + 1,
        ifAbsent: () => 1);
    return canUsePartial;
  }

  static void _releaseLegacyPartial(String? path) {
    if (path == null) return;
    final users = _activeLegacyPartialUsers[path];
    if (users == null || users <= 1) {
      _activeLegacyPartialUsers.remove(path);
    } else {
      _activeLegacyPartialUsers[path] = users - 1;
    }
  }

  static bool _pathExists(String path) {
    try {
      return FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.notFound;
    } catch (_) {
      return false;
    }
  }

  static String _reserveOutputPath(String outputPath) {
    if (_activeDownloadPaths.add(outputPath)) return outputPath;

    final directory = p.dirname(outputPath);
    final extension = p.extension(outputPath);
    final baseName = p.basenameWithoutExtension(outputPath);
    var suffix = 1;
    late String candidate;
    do {
      candidate = p.join(directory, '$baseName ($suffix)$extension');
      suffix++;
    } while (
        _activeDownloadPaths.contains(candidate) || _pathExists(candidate));
    _activeDownloadPaths.add(candidate);
    return candidate;
  }

  /// 检测服务器是否支持断点续传（Range 请求）
  ///
  /// 发送 HEAD 请求检查响应头中的 `Accept-Ranges` 是否为 `bytes`。
  /// [url] 目标 URL
  /// [headers] 自定义 HTTP 头
  /// 返回 `true` 表示服务器支持范围请求（可续传）。
  static Future<bool> checkServerResumeSupport(String url,
      {Map<String, String>? headers}) async {
    final dio = Dio();
    try {
      final mergedHeaders =
          Map<String, String>.from(DefaultRules.defaultHeaders);
      if (headers != null) mergedHeaders.addAll(headers);
      final response = await dio.head(
        url,
        options: Options(
          headers: mergedHeaders,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final acceptRanges = response.headers.value('accept-ranges');
      return acceptRanges?.toLowerCase() == 'bytes';
    } catch (e) {
      debugPrint('[DownloadManager] Resume check failed: $e');
      return false;
    } finally {
      dio.close();
    }
  }

  /// 暂停指定下载任务
  ///
  /// 创建一个 Completer 存入暂停令牌表，下载循环检测到后会等待该 Completer 完成。
  /// [taskId] 任务 ID
  static Future<void> pauseDownload(String taskId) async {
    final completer = Completer<void>();
    pauseTokens[taskId] = completer;
    debugPrint('[DownloadManager] Paused task: $taskId');
  }

  /// 恢复指定下载任务
  ///
  /// 完成对应的 Completer，使下载循环继续执行。
  /// [taskId] 任务 ID
  static void resumeDownload(String taskId) {
    final completer = pauseTokens.remove(taskId);
    if (completer != null && !completer.isCompleted) {
      completer.complete();
      debugPrint('[DownloadManager] Resumed task: $taskId');
    }
  }

  /// 检查指定任务是否处于暂停状态
  ///
  /// [taskId] 任务 ID
  /// 返回 `true` 表示该任务已暂停。
  static bool isPaused(String taskId) {
    return pauseTokens.containsKey(taskId);
  }

  /// 下载单个文件，支持断点续传
  ///
  /// [url] 文件 URL
  /// [saveDir] 保存目录
  /// [fileName] 保存文件名
  /// [headers] 自定义 HTTP 头
  /// [onProgress] 进度回调 (receivedBytes, totalBytes)
  /// [cancelToken] 取消令牌
  /// [existingPath] 已存在的文件路径（从中断处继续）
  /// [taskId] 任务 ID（用于暂停/恢复控制）
  ///
  /// 返回最终完整的文件路径。
  static Future<String> downloadFile({
    required String url,
    required String saveDir,
    required String fileName,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
    String? existingPath,
    String taskId = '',
  }) async {
    final requestedOutputPath = p.join(saveDir, fileName);
    final outputPath = _reserveOutputPath(requestedOutputPath);
    final sameNameDownloadIsActive = outputPath != requestedOutputPath;
    final taskSuffix =
        base64Url.encode(utf8.encode(taskId)).replaceAll('=', '');
    final tempPath = taskId.isEmpty
        ? '$outputPath${DefaultRules.tempFileSuffix}'
        : '$requestedOutputPath.$taskSuffix${DefaultRules.tempFileSuffix}';
    final hasExistingPartialReservation =
        existingPath != null && existingPath != tempPath;
    final ownsExistingPartialReservation =
        hasExistingPartialReservation && _reserveLegacyPartial(existingPath);
    final canUseExistingPartial = ownsExistingPartialReservation &&
        !(sameNameDownloadIsActive &&
            existingPath ==
                '$requestedOutputPath${DefaultRules.tempFileSuffix}');

    // Directory creation - wrapped in try-catch for web compatibility
    try {
      final dir = Directory(saveDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (_) {}

    // 确定起始位置（断点续传）
    int startByte = 0;
    try {
      final tempFile = File(tempPath);
      if (!await tempFile.exists() &&
          existingPath != null &&
          existingPath != tempPath &&
          canUseExistingPartial) {
        final existingFile = File(existingPath);
        if (await existingFile.exists()) {
          await existingFile.copy(tempPath);
        }
      }
      if (await tempFile.exists()) {
        startByte = await tempFile.length();
        if (startByte > 0) {
          debugPrint('[DownloadManager] Resuming from byte $startByte');
        }
      }
    } catch (_) {}

    final dio = Dio();
    cancelToken?.whenCancel.then((_) => dio.close());

    try {
      final mergedHeaders =
          Map<String, String>.from(DefaultRules.defaultHeaders);
      if (headers != null) mergedHeaders.addAll(headers);
      if (startByte > 0) {
        mergedHeaders['Range'] = 'bytes=$startByte-';
      }

      final response = await dio.get(
        url,
        options: Options(
          headers: mergedHeaders,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 30),
        ),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final adjustedReceived = received + startByte;
          final adjustedTotal =
              total > 0 ? total + startByte : -1; // -1 means unknown
          onProgress?.call(adjustedReceived, adjustedTotal);
        },
      );

      // A server may ignore Range and return the full file with status 200.
      // In that case restart from the full response instead of appending it to
      // the existing partial file.
      if (startByte > 0 && response.statusCode == HttpStatus.ok) {
        startByte = 0;
      } else if (startByte > 0 &&
          response.statusCode != HttpStatus.partialContent) {
        throw StateError(
          'Expected a partial response when resuming, got ${response.statusCode}',
        );
      }

      // On web, File operations will fail - this is expected
      // We still try to write the file for native platforms
      try {
        final file = File(tempPath);
        final raf = await file.open(
          mode: startByte > 0 ? FileMode.writeOnlyAppend : FileMode.write,
        );
        try {
          final stream = response.data.stream as Stream<List<int>>;
          await for (final chunk in stream) {
            // 检查暂停状态，如果已暂停则等待恢复
            if (taskId.isNotEmpty) {
              final pauseCompleter = pauseTokens[taskId];
              if (pauseCompleter != null) {
                await pauseCompleter.future;
              }
            }
            await raf.writeFrom(chunk);
            // Progress already handled by onReceiveProgress above
          }
        } finally {
          await raf.close();
        }

        // Rename temp to final
        if (await File(outputPath).exists()) {
          await File(outputPath).delete();
        }
        await file.rename(outputPath);
        if (canUseExistingPartial && existingPath != tempPath) {
          try {
            await File(existingPath).delete();
          } catch (_) {}
        }
        debugPrint('[DownloadManager] Download complete: $outputPath');
        return outputPath;
      } catch (e) {
        if (kIsWeb) {
          debugPrint(
              '[DownloadManager] File write failed (expected on web): $e');
          // Return temp path or output path as best-effort
          return tempPath;
        }
        rethrow;
      }
    } finally {
      dio.close();
      _activeDownloadPaths.remove(outputPath);
      if (hasExistingPartialReservation) {
        _releaseLegacyPartial(existingPath);
      }
    }
  }

  /// 下载多个分段并合并
  ///
  /// [segmentUrls] 分段 URL 列表
  /// [outputPath] 合并后输出的文件路径
  /// [headers] 自定义 HTTP 头
  /// [concurrency] 并行下载数（默认 3）
  /// [onProgress] 进度回调 (completedCount, totalCount, overallProgress%)
  /// [cancelToken] 取消令牌
  /// [taskId] 任务 ID（用于持久化）
  ///
  /// 返回输出文件路径。
  static Future<String> downloadSegmentsAndMerge({
    required List<String> segmentUrls,
    List<({int start, int length})?>? segmentRanges,
    required String outputPath,
    Map<String, String>? headers,
    Map<String, String> Function(String url)? headersForUrl,
    int concurrency = 3,
    void Function(int completed, int total, int progress)? onProgress,

    /// Byte-granularity progress: total bytes received across all
    /// segments so far (monotonic — used by stall detection).
    void Function(int totalBytes)? onBytes,
    CancelToken? cancelToken,
    String taskId = '',
  }) async {
    if (segmentUrls.isEmpty) {
      throw ArgumentError('segmentUrls must not be empty');
    }
    if (segmentRanges != null && segmentRanges.length != segmentUrls.length) {
      throw ArgumentError('segmentRanges must match segmentUrls length');
    }

    // Hold the resolved path until staging, merging, and cleanup all finish.
    // The parts directory uses this same path, isolating concurrent tasks with
    // the same requested filename.
    final resolvedOutputPath = _reserveOutputPath(outputPath);
    return _downloadSegmentsAtOutputPath(
      segmentUrls: segmentUrls,
      segmentRanges: segmentRanges,
      outputPath: resolvedOutputPath,
      headers: headers,
      headersForUrl: headersForUrl,
      concurrency: concurrency,
      onProgress: onProgress,
      onBytes: onBytes,
      cancelToken: cancelToken,
      taskId: taskId,
    ).whenComplete(() {
      _activeDownloadPaths.remove(resolvedOutputPath);
    });
  }

  static Future<String> _downloadSegmentsAtOutputPath({
    required List<String> segmentUrls,
    List<({int start, int length})?>? segmentRanges,
    required String outputPath,
    Map<String, String>? headers,
    Map<String, String> Function(String url)? headersForUrl,
    int concurrency = 3,
    void Function(int completed, int total, int progress)? onProgress,
    void Function(int totalBytes)? onBytes,
    CancelToken? cancelToken,
    String taskId = '',
  }) async {
    final dir = Directory(p.dirname(outputPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final total = segmentUrls.length;
    final tempDirPath = p.join(
      p.dirname(outputPath),
      '.${p.basename(outputPath)}_parts',
    );
    final tempDir = Directory(tempDirPath);
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    // 恢复进度
    final hasByteRanges = segmentRanges?.any((range) => range != null) ?? false;
    final completedSegments = <int>{};
    if (taskId.isNotEmpty && !hasByteRanges) {
      final saved = await loadSegmentProgress(taskId);
      final savedSegments = saved?['completedSegments'];
      if (savedSegments is List) {
        completedSegments.addAll(
          savedSegments.whereType<int>().where((index) => index >= 0 && index < total),
        );
        debugPrint(
          '[DownloadManager] Restored progress: ${completedSegments.length}/$total',
        );
      }
    }

    // 下载队列
    final partFiles = List<String?>.filled(total, null);
    final errors = <int, String>{};

    // 收集已完成的下载
    for (int i = 0; i < total; i++) {
      if (!completedSegments.contains(i)) continue;
      final partPath = p.join(tempDirPath, 'part_$i');
      final partFile = File(partPath);
      if (await partFile.exists() && await partFile.length() > 0) {
        partFiles[i] = partPath;
      } else {
        completedSegments.remove(i);
      }
    }

    // Seed the byte counter from restored parts so the published total
    // never regresses across retries with restored segment progress.
    var totalBytes = 0;
    for (int i = 0; i < total; i++) {
      if (!completedSegments.contains(i)) continue;
      final partFile = File(p.join(tempDirPath, 'part_$i'));
      totalBytes += await partFile.length();
    }

    // 并行下载
    final semaphore = Semaphore(concurrency);
    final futures = <Future<void>>[];
    var progressWrite = Future<void>.value();
    // Total bytes across all segments (monotonic; no awaits inside the
    // accumulation, so the single-threaded event loop keeps it atomic).
    // Seeded above from restored parts.

    for (int i = 0; i < total; i++) {
      if (completedSegments.contains(i)) continue;
      futures.add(
        downloadSingleSegment(
          index: i,
          url: segmentUrls[i],
          rangeStart: segmentRanges?[i]?.start,
          rangeLength: segmentRanges?[i]?.length,
          tempDir: tempDirPath,
          partFiles: partFiles,
          headers: headersForUrl?.call(segmentUrls[i]) ?? headers,
          semaphore: semaphore,
          cancelToken: cancelToken,
          errors: errors,
          taskId: taskId,
          onSegmentComplete: (idx) async {
            completedSegments.add(idx);
            final completedCount = completedSegments.length;
            final progress = (completedCount * 100 ~/ total).clamp(0, 100);
            onProgress?.call(completedCount, total, progress);
            if (taskId.isNotEmpty) {
              final savedSegments = completedSegments.toList()..sort();
              progressWrite = progressWrite.then(
                (_) => saveSegmentProgress(taskId, {
                  'completedSegments': savedSegments,
                }),
              );
              await progressWrite;
            }
          },
          onBytesDelta: (delta) {
            totalBytes += delta;
            onBytes?.call(totalBytes);
          },
        ),
      );
    }

    await Future.wait(futures);

    if (errors.isNotEmpty && completedSegments.length < total) {
      final errorMsg =
          errors.entries.map((e) => 'Segment[${e.key}]: ${e.value}').join('; ');
      throw Exception('Download failed: $errorMsg');
    }

    // 合并
    onProgress?.call(total, total, 95);
    final validParts = partFiles.whereType<String>().toList();
    // Byte signal during the merge too — a multi-GB merge on slow storage
    // can exceed the flow's stall window if the signature stays frozen.
    var mergeBytes = 0;
    await mergeFiles(
      validParts,
      outputPath,
      onBytes: (delta) {
        mergeBytes += delta;
        onBytes?.call(totalBytes + mergeBytes);
      },
    );

    // 清理临时目录
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}

    // 清理进度
    if (taskId.isNotEmpty) {
      await deleteSegmentProgress(taskId);
    }

    debugPrint('[DownloadManager] Segments merged to: $outputPath');
    return outputPath;
  }

  /// 获取已下载的字节数（用于断点续传判断）
  static int getDownloadedBytes(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return 0;
    return file.lengthSync();
  }

  /// 合并多个文件为一个
  ///
  /// [inputPaths] 输入文件路径列表（按顺序）
  /// [outputPath] 输出文件路径
  /// [onBytes] 每写入一个 chunk 后回调该 chunk 的字节数（用于停滞检测）
  static Future<void> mergeFiles(
    List<String> inputPaths,
    String outputPath, {
    void Function(int delta)? onBytes,
  }) async {
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final raf = await outputFile.open(mode: FileMode.write);
    try {
      for (final path in inputPaths) {
        final inputFile = File(path);
        if (!await inputFile.exists()) {
          debugPrint('[DownloadManager] Warning: part file not found: $path');
          continue;
        }
        await for (final chunk in inputFile.openRead()) {
          await raf.writeFrom(chunk);
          onBytes?.call(chunk.length);
        }
      }
    } finally {
      await raf.close();
    }
  }

  static Future<void> saveProgress(
    String taskId,
    Map<String, dynamic> progress,
  ) async {
    await saveSegmentProgress(taskId, progress);
  }

  static Future<Map<String, dynamic>?> loadProgress(String taskId) async {
    return loadSegmentProgress(taskId);
  }
}
