import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' show CancelToken;
import 'package:fvp/mdk.dart' as mdk;

/// 格式转换器
///
/// 将下载的 TS 分段合并/转换为 MP4。
/// 使用 fvp 底层的 mdk.Player 编码引擎进行转换。
class FFmpegConverter {
  FFmpegConverter._();

  /// 将输入媒体转换为 MP4
  ///
  /// [inputPath] 输入文件路径（TS 文件或分段列表文件）
  /// [outputPath] 输出 MP4 路径
  /// [onProgress] 进度回调 0-100
  /// [cancelToken] 取消令牌
  ///
  /// 返回输出文件路径。
  static Future<String> convertToMp4({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final inputExt = p.extension(inputPath).toLowerCase();
    final playableExts = ['.mp4', '.webm', '.ogg', '.mov', '.mkv'];

    // 如果已经是可播放格式，直接复制
    if (playableExts.contains(inputExt)) {
      final sourceFile = File(inputPath);
      if (!await sourceFile.exists()) {
        throw FileSystemException('源文件不存在，无法复制', inputPath);
      }
      await sourceFile.copy(outputPath);
      return outputPath;
    }

    // 使用 fvp mdk 进行转换
    return _convertWithFvp(
      inputPath: inputPath,
      outputPath: outputPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// 纯 Dart 方式合并 TS 文件
  ///
  /// 将多个 TS 文件按顺序拼接为一个文件。
  /// 这只做简单的二进制拼接，不支持重新编码。
  ///
  /// [tsPaths] TS 文件路径列表
  /// [outputPath] 输出文件路径
  ///
  /// 返回输出文件路径。
  static Future<String> mergeTSFiles(
    List<String> tsPaths,
    String outputPath,
  ) async {
    if (tsPaths.isEmpty) {
      throw ArgumentError('tsPaths must not be empty');
    }

    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final raf = await outputFile.open(mode: FileMode.write);
    int merged = 0;
    try {
      for (final path in tsPaths) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('[FFmpegConverter] Warning: TS file not found: $path');
          continue;
        }
        await for (final chunk in file.openRead()) {
          await raf.writeFrom(chunk);
        }
        merged++;
      }
    } finally {
      await raf.close();
    }

    debugPrint('[FFmpegConverter] Merged $merged TS files into $outputPath');
    return outputPath;
  }

  // ===========================================================================
  // fvp mdk 转换
  // ===========================================================================

  /// 使用 fvp 底层的 mdk.Player 引擎进行转换
  ///
  /// 利用 [mdk.Player.record] 方法将输入媒体转码输出为 MP4 文件。
  /// 关闭音视频同步以达成尽可能快的转码速度。
  static Future<String> _convertWithFvp({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // 确保输出目录存在
    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    // 检查输入
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input file not found', inputPath);
    }

    // 如果输入是 TS 文件，直接复制（不做重新编码）
    final isTs = inputPath.toLowerCase().endsWith('.ts');
    if (isTs) {
      onProgress?.call(10);
      await inputFile.copy(outputPath);
      onProgress?.call(100);
      return outputPath;
    }

    debugPrint(
        '[FFmpegConverter] Using fvp for conversion: $inputPath -> $outputPath');

    final player = mdk.Player();
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Task was cancelled');
      }

      cancelToken?.whenCancel.then((_) {
        try {
          player.record(); // 停止录制
          player.dispose();
        } catch (_) {}
      });

      // 设置输入媒体
      player.media = inputPath;

      // 关闭音视频同步，实现最大转码速度
      player.setProperty('sync', 'none');
      player.setProperty('avsync', '0');

      // 开始录制输出 MP4
      player.record(to: outputPath, format: 'mp4');

      // 启动播放（即开始转码处理）
      player.state = mdk.PlaybackState.playing;

      // 等待转码完成
      final completer = Completer<void>();
      StreamSubscription<({mdk.MediaStatus oldValue, mdk.MediaStatus newValue})>?
          statusSub;
      StreamSubscription<mdk.MediaEvent>? eventSub;

      statusSub = player.onMediaStatus.listen((event) {
        final newStatus = event.newValue;
        if (newStatus.test(mdk.MediaStatus.end) &&
            !completer.isCompleted) {
          player.record(); // 停止录制，保存文件
          completer.complete();
        }
      });

      // 监听解码错误
      eventSub = player.onEvent.listen((event) {
        if (event.error < 0 && !completer.isCompleted) {
          player.record();
          completer.completeError(Exception('转码失败: ${event.detail}'));
        }
      });

      // 进度更新
      Timer? progressTimer;
      if (onProgress != null) {
        final totalDuration = player.mediaInfo.duration;
        if (totalDuration > 0) {
          progressTimer = Timer.periodic(
            const Duration(milliseconds: 500),
            (_) {
              final pos = player.position;
              final progress =
                  ((pos / totalDuration) * 100).round().clamp(0, 100);
              onProgress(progress);
            },
          );
        }
      }

      // 设置超时（10分钟）
      final timeout = Future.delayed(const Duration(minutes: 10), () {
        if (!completer.isCompleted) {
          player.record();
          completer.completeError(Exception('转换超时'));
        }
      });

      try {
        await completer.future;
      } finally {
        timeout.ignore();
        statusSub?.cancel();
        eventSub?.cancel();
        progressTimer?.cancel();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      onProgress?.call(100);
      debugPrint('[FFmpegConverter] Conversion complete: $outputPath');
      return outputPath;
    } finally {
      try {
        player.dispose();
      } catch (_) {}
    }
  }
}
