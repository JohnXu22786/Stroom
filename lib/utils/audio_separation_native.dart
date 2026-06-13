import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart' show CancelToken;

/// 音频分离引擎（原生平台实现 - 暂不可用）
///
/// FFmpeg 功能已被临时移除。如需使用，请安装 ffmpeg_kit_flutter 并
/// 在 CI 工作流中添加相应的平台补丁。
class AudioSeparationEngine {
  /// 始终返回 false（暂不可用）
  Future<bool> isAvailable() async {
    debugPrint('[AudioSeparationEngine] not available (ffmpeg not bundled)');
    return false;
  }

  /// 检查是否支持指定的视频格式（格式支持但引擎不可用）
  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    const supported = [
      'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
    ];
    return supported.contains(format.toLowerCase().trim());
  }

  /// 从视频文件中提取音频
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnsupportedError(
      '音频分离功能暂不可用。FFmpeg 库未集成到应用中。',
    );
  }
}
