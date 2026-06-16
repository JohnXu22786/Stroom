import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
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
    // Directory creation - wrapped in try-catch for web compatibility
    try {
      final dir = Directory(saveDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (_) {}

    final outputPath = p.join(saveDir, fileName);
    final tempPath = '$outputPath${DefaultRules.tempFileSuffix}';

    // 确定起始位置（断点续传）
    int startByte = 0;
    try {
      if (existingPath != null) {
        final existingFile = File(existingPath);
        if (await existingFile.exists()) {
          startByte = await existingFile.length();
          debugPrint('[DownloadManager] Resuming from byte $startByte');
        }
      } else {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          startByte = await tempFile.length();
          debugPrint(
              '[DownloadManager] Found partial download, resuming from byte $startByte');
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

      // On web, File operations will fail - this is expected
      // We still try to write the file for native platforms
      try {
        final file = File(tempPath);
        final raf = await file.open(mode: FileMode.writeOnlyAppend);
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
        debugPrint('[DownloadManager] Download complete: $outputPath');
        return outputPath;
      } catch (e) {
        debugPrint('[DownloadManager] File write failed (expected on web): $e');
        // Return temp path or output path as best-effort
        return tempPath;
      }
    } finally {
      dio.close();
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
    required String outputPath,
    Map<String, String>? headers,
    int concurrency = 3,
    void Function(int completed, int total, int progress)? onProgress,
    CancelToken? cancelToken,
    String taskId = '',
  }) async {
    if (segmentUrls.isEmpty) {
      throw ArgumentError('segmentUrls must not be empty');
    }

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
    int completedCount = 0;
    if (taskId.isNotEmpty) {
      final saved = await loadSegmentProgress(taskId);
      if (saved != null) {
        completedCount = saved['completed'] as int? ?? 0;
        debugPrint(
            '[DownloadManager] Restored progress: $completedCount/$total');
      }
    }

    // 下载队列
    final partFiles = List<String?>.filled(total, null);
    final errors = <int, String>{};

    // 收集已完成的下载
    for (int i = 0; i < completedCount && i < total; i++) {
      final partPath = p.join(tempDirPath, 'part_$i');
      final partFile = File(partPath);
      if (await partFile.exists() && await partFile.length() > 0) {
        partFiles[i] = partPath;
      } else {
        completedCount = i; // 回退
        break;
      }
    }

    // 并行下载
    final semaphore = Semaphore(concurrency);
    final futures = <Future<void>>[];

    for (int i = completedCount; i < total; i++) {
      futures.add(downloadSingleSegment(
        index: i,
        url: segmentUrls[i],
        tempDir: tempDirPath,
        partFiles: partFiles,
        headers: headers,
        semaphore: semaphore,
        cancelToken: cancelToken,
        errors: errors,
        taskId: taskId,
        onSegmentComplete: (idx) {
          completedCount++;
          final progress = (completedCount * 100 ~/ total).clamp(0, 100);
          onProgress?.call(completedCount, total, progress);
          // 保存进度
          if (taskId.isNotEmpty) {
            saveSegmentProgress(taskId, {'completed': completedCount});
          }
        },
      ));
    }

    await Future.wait(futures);

    if (errors.isNotEmpty && completedCount < total) {
      final errorMsg =
          errors.entries.map((e) => 'Segment[${e.key}]: ${e.value}').join('; ');
      throw Exception('Download failed: $errorMsg');
    }

    // 合并
    onProgress?.call(total, total, 95);
    final validParts = partFiles.whereType<String>().toList();
    await mergeFiles(validParts, outputPath);

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
  static Future<void> mergeFiles(
    List<String> inputPaths,
    String outputPath,
  ) async {
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
