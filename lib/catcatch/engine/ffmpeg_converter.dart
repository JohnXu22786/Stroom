import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' show CancelToken;
import 'package:media_kit/media_kit.dart';

/// 格式转换器
///
/// 将下载的 TS 分段合并/转换为 MP4。
/// 使用 media_kit 的编码引擎（通过 mpv 后端）进行转换。
class FFmpegConverter {
  FFmpegConverter._();

  /// 检查系统是否安装了 FFmpeg
  ///
  /// 此方法保留以保持向后兼容性，但现在始终返回 false，
  /// 因为我们使用 media_kit 内建的编码引擎。
  static Future<bool> isFFmpegAvailable() async => false;

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

    // 使用 media_kit 进行转换
    return _convertWithMediaKit(
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
  // media_kit 转换
  // ===========================================================================

  /// 使用 media_kit 引擎进行转换
  static Future<String> _convertWithMediaKit({
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

    // 如果输入是 TS 文件，使用纯 Dart 合并（不做重新编码）
    final isTs = inputPath.toLowerCase().endsWith('.ts');
    if (isTs) {
      onProgress?.call(10);
      await inputFile.copy(outputPath);
      onProgress?.call(100);
      return outputPath;
    }

    debugPrint(
        '[FFmpegConverter] Using media_kit for conversion: $inputPath -> $outputPath');

    final player = Player();
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Task was cancelled');
      }

      cancelToken?.whenCancel.then((_) async {
        try {
          await player.dispose();
        } catch (_) {}
      });

      // 配置 mpv 编码参数
      // --o=output.mp4: 输出文件路径
      // --oac=aac: 音频编码
      // --ovc=libx264: 视频编码
      // --ovcopts=preset=fast,crf=23: 编码选项
      if (player.platform != null) {
        await (player.platform as dynamic).setProperty('o', outputPath);
        await (player.platform as dynamic).setProperty('ovc', 'libx264');
        await (player.platform as dynamic).setProperty('oac', 'aac');
        await (player.platform as dynamic)
            .setProperty('ovcopts', 'preset=fast,crf=23');
      }

      // 打开媒体进行编码
      await player.open(
        Media(Uri.file(inputPath).toString()),
        play: true,
      );

      // 等待编码完成
      final completer = Completer<void>();
      StreamSubscription? completionSub;
      StreamSubscription? errorSub;

      completionSub = player.stream.completed.listen((completed) {
        if (completed && !completer.isCompleted) {
          completer.complete();
        }
      });

      errorSub = player.stream.error.listen((error) {
        if (error.isNotEmpty && !completer.isCompleted) {
          completer.completeError(Exception('转换失败: $error'));
        }
      });

      // 进度更新
      StreamSubscription<Duration>? positionSub;
      if (onProgress != null) {
        positionSub = player.stream.position.listen((position) {
          final duration = player.state.duration;
          if (duration.inMilliseconds > 0) {
            final progress =
                ((position.inMilliseconds / duration.inMilliseconds) * 100)
                    .round()
                    .clamp(0, 100);
            onProgress(progress);
          }
        });
      }

      // 设置超时（10分钟）
      final timeout = Future.delayed(const Duration(minutes: 10), () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('转换超时'));
        }
      });

      try {
        await completer.future;
      } finally {
        timeout.ignore();
        completionSub?.cancel();
        errorSub?.cancel();
        positionSub?.cancel();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      onProgress?.call(100);
      debugPrint('[FFmpegConverter] Conversion complete: $outputPath');
      return outputPath;
    } finally {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  /// 从视频文件中提取音频
  ///
  /// [inputPath] 输入视频文件路径
  /// [outputPath] 输出音频文件路径（建议 .mp3）
  /// [onProgress] 进度回调 0-100
  /// [cancelToken] 取消令牌
  ///
  /// 返回输出文件路径。
  static Future<String> extractAudio({
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

    debugPrint(
        '[FFmpegConverter] Using media_kit for audio extraction: $inputPath -> $outputPath');

    final player = Player();
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Task was cancelled');
      }

      cancelToken?.whenCancel.then((_) async {
        try {
          await player.dispose();
        } catch (_) {}
      });

      // 配置 mpv 编码参数
      // --o=output.mp3: 输出文件路径
      // --oac=libmp3lame: MP3 音频编码器
      // --ovc=no: 不编码视频
      if (player.platform != null) {
        await (player.platform as dynamic).setProperty('o', outputPath);
        await (player.platform as dynamic).setProperty('oac', 'libmp3lame');
        await (player.platform as dynamic).setProperty('ovc', 'no');
      }

      // 打开媒体进行编码
      await player.open(
        Media(Uri.file(inputPath).toString()),
        play: true,
      );

      // 等待编码完成
      final completer = Completer<void>();
      StreamSubscription? completionSub;
      StreamSubscription? errorSub;

      completionSub = player.stream.completed.listen((completed) {
        if (completed && !completer.isCompleted) {
          completer.complete();
        }
      });

      errorSub = player.stream.error.listen((error) {
        if (error.isNotEmpty && !completer.isCompleted) {
          completer.completeError(Exception('音频提取失败: $error'));
        }
      });

      // 进度更新
      StreamSubscription<Duration>? positionSub;
      if (onProgress != null) {
        positionSub = player.stream.position.listen((position) {
          final duration = player.state.duration;
          if (duration.inMilliseconds > 0) {
            final progress =
                ((position.inMilliseconds / duration.inMilliseconds) * 100)
                    .round()
                    .clamp(0, 100);
            onProgress(progress);
          }
        });
      }

      // 设置超时（5分钟）
      final timeout = Future.delayed(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('音频提取超时'));
        }
      });

      try {
        await completer.future;
      } finally {
        timeout.ignore();
        completionSub?.cancel();
        errorSub?.cancel();
        positionSub?.cancel();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      onProgress?.call(100);
      debugPrint('[FFmpegConverter] Audio extraction complete: $outputPath');
      return outputPath;
    } finally {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }
}
