import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart' show CancelToken;

const _supportedVideoFormats = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
];

/// JS interop: 检查 AudioContext 是否可用
@JS('window.__mediaKitAudioSupported')
external bool _jsAudioSupported();

/// JS interop: 提取音频，返回 Uint8Array (WAV 数据)
@JS('window.__mediaKitExtractAudio')
external JSPromise _jsExtractAudio(JSAny videoBytes, JSString videoFormat);

/// 音频分离引擎（Web 平台实现）
///
/// 使用 Web Audio API（通过 JS 桥接 `web/media_kit_audio_extraction.js`）在浏览器中提取音频。
/// 无需 FFmpeg.wasm，无需下载 31MB WASM 文件。
class AudioSeparationEngine {
  bool? _available;
  bool _loading = false;

  /// 检查音频分离引擎是否可用
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    if (_loading) return false;

    _loading = true;
    try {
      _available = _jsAudioSupported();
      debugPrint('[AudioSeparationEngine] Web Audio API available: $_available');
      return _available!;
    } catch (e) {
      debugPrint('[AudioSeparationEngine] Web Audio API check failed: $e');
      _available = false;
      return false;
    } finally {
      _loading = false;
    }
  }

  /// 检查是否支持指定的视频格式
  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedVideoFormats.contains(format.toLowerCase().trim());
  }

  /// 从视频文件中提取音频（Web 平台）
  ///
  /// 通过 JS bridge 使用 Web Audio API 解码视频中的音频轨道并输出为 WAV 格式。
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (videoBytes.isEmpty) {
      throw Exception('视频数据为空');
    }

    if (!canHandleVideoFormat(videoFormat)) {
      throw Exception('不支持的视频格式: $videoFormat');
    }

    if (!(await isAvailable())) {
      throw Exception('Web Audio API 不可用');
    }

    cancelToken?.whenCancel.then((_) {});

    try {
      debugPrint('[AudioSeparationEngine] Extracting audio via Web Audio API...');

      // 将视频字节转换为 JSArray<JSNumber> (匹配 ffmpeg_wasm_interop 的写法)
      final jsBytes = videoBytes.map((b) => b.toJS).toList().toJS;
      final jsFormat = videoFormat.toJS;
      final promise = _jsExtractAudio(jsBytes, jsFormat);
      final result = await promise.toDart;

      if (result == null) {
        throw Exception('音频提取结果为空');
      }

      // JS Uint8Array 通过 dartify 转换为 Dart List<int>
      final list = result.dartify() as List<int>?;
      if (list == null || list.isEmpty) {
        throw Exception('提取的音频数据为空');
      }

      final audioBytes = Uint8List.fromList(list);

      if (cancelToken?.isCancelled ?? false) {
        throw Exception('音频提取被取消');
      }

      onProgress?.call(100);

      debugPrint('[AudioSeparationEngine] Audio extracted: ${audioBytes.length} bytes');
      return audioBytes;
    } catch (e) {
      debugPrint('[AudioSeparationEngine] Audio extraction failed: $e');
      rethrow;
    }
  }
}
