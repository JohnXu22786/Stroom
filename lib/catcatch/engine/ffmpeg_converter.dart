import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show debugPrint;

/// TS 文件合并工具
///
/// 将下载的多个 TS 分段按顺序合并为一个可播放的 TS 文件。
/// TS 流为 H.264 + AAC，二进制拼接即可得到完整可播放视频。
class FFmpegConverter {
  FFmpegConverter._();

  /// 合并 TS 分段为单个可播放 TS 文件
  ///
  /// 将多个 TS 文件按顺序二进制拼接。
  /// TS 的 188 字节包结构天然支持无缝拼接。
  ///
  /// [tsPaths] TS 文件路径列表
  /// [outputPath] 输出文件路径（建议 .ts）
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

  /// 将 .ts 文件输出为可播放的 .ts 文件
  ///
  /// 实际只是验证文件存在，不做重新编码。
  /// 用于 task_executor 中统一输出路径。
  static Future<String> convertToTs({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final sourceFile = File(inputPath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('源文件不存在', inputPath);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Task was cancelled');
    }

    // 确保输出目录存在
    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    onProgress?.call(50);

    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Task was cancelled');
    }

    // 文件已存在或直接复制
    if (await File(outputPath).exists()) {
      await File(outputPath).delete();
    }
    await sourceFile.copy(outputPath);

    onProgress?.call(100);
    debugPrint('[FFmpegConverter] Output ready: $outputPath');
    return outputPath;
  }
}
