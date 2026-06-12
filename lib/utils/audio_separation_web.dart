import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart' show CancelToken;

/// 音频分离引擎（Web 平台实现）
///
/// Web 端不支持从视频文件中提取音频。
/// 仅支持纯音频数据的格式转换（如 PCM→WAV）。
class AudioSeparationEngine {
  bool? _available;

  /// 检查音频分离引擎是否可用
  ///
  /// Web 端不支持视频→音频提取，始终返回 false。
  Future<bool> isAvailable() async {
    _available ??= false;
    return _available!;
  }

  /// 检查是否支持指定的视频格式
  ///
  /// Web 端支持格式检测，但不支持实际提取。
  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp']
        .contains(format.toLowerCase().trim());
  }

  /// 从视频文件中提取音频（Web 端不支持）
  ///
  /// Web 端无法直接从视频中提取音频。如果需要此功能，
  /// 请使用桌面版或移动版应用。
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    debugPrint('[AudioSeparationEngine] Web 端不支持从视频中提取音频');

    throw UnsupportedError(
      'Web 端暂不支持从视频文件中提取音频。\n'
      '请使用移动版或桌面版应用进行音频分离。',
    );
  }
}
