import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' show CancelToken;

/// 格式转换器
///
/// 将下载的 TS 分段合并/转换为 MP4。
/// 使用纯 Dart 方式进行二进制拼接，不做重新编码。
/// TS 流通常为 H.264 + AAC，直接拼接后改后缀即可被大多数播放器识别。
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
      onProgress?.call(100);
      return outputPath;
    }

    // TS 文件或未知格式：纯二进制复制
    // TS 流包含 H.264+AAC，复制后改名 .mp4 即可播放
    final sourceFile = File(inputPath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('源文件不存在', inputPath);
    }

    // 确保输出目录存在
    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    onProgress?.call(10);

    // 大文件流式复制
    final totalBytes = await sourceFile.length();
    final raf = await sourceFile.open(mode: FileMode.read);
    final waf = await File(outputPath).open(mode: FileMode.write);
    int bytesCopied = 0;
    const chunkSize = 8192;

    try {
      while (true) {
        if (cancelToken?.isCancelled ?? false) {
          throw Exception('Task was cancelled');
        }

        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;

        await waf.writeFrom(chunk);
        bytesCopied += chunk.length;

        if (totalBytes > 0 && onProgress != null) {
          final progress = ((bytesCopied / totalBytes) * 90 + 10).round().clamp(10, 99);
          onProgress(progress);
        }
      }
    } finally {
      await raf.close();
      await waf.close();
    }

    onProgress?.call(100);
    debugPrint('[FFmpegConverter] Copied $inputPath -> $outputPath');
    return outputPath;
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

  /// 从视频文件中提取音频
  ///
  /// 注意：此方法需要系统安装 FFmpeg 才能正常工作。
  /// 如果未安装 FFmpeg，将抛出异常。
  /// 推荐使用 [AudioSeparationEngine] 进行音频处理。
  static Future<String> extractAudio({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnsupportedError(
      '音频提取需要 FFmpeg。请确保系统已安装 FFmpeg，'
      '或使用 AudioSeparationEngine 进行音频处理。',
    );
  }
}
