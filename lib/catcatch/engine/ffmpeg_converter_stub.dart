import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;

/// Stub implementation for web.
///
/// Web does not support file system media conversion via FFmpeg/fvp.
/// This stub throws [UnsupportedError] if called.
class FFmpegConverter {
  FFmpegConverter._();

  /// 将输入媒体转换为 MP4。
  ///
  /// Web 平台不支持媒体转换操作。
  static Future<String> convertToMp4({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnsupportedError(
      'Media conversion is not supported on web platform',
    );
  }
}
