import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart' show CancelToken;

import 'ffmpeg_wasm_interop.dart';

const _supportedVideoFormats = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
];

/// 音频分离引擎（Web 平台实现）
///
/// 使用 ffmpeg.wasm（WebAssembly FFmpeg 移植版）在浏览器中进行音频分离。
/// 首次使用需从 CDN 下载约 31MB 的 ffmpeg-core.wasm。
class AudioSeparationEngine {
  bool? _available;
  bool _loading = false;

  /// 检查音频分离引擎是否可用
  ///
  /// 首次调用会尝试从 CDN 加载 ffmpeg-core WASM（约 31MB）。
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    if (_loading) return false;

    _loading = true;
    try {
      if (ffmpegWasmIsLoaded()) {
        _available = true;
        debugPrint('[AudioSeparationEngine] ffmpeg.wasm ready');
        return true;
      }

      debugPrint('[AudioSeparationEngine] Loading ffmpeg-core WASM (~31MB)...');
      final loaded = await ffmpegWasmLoad();
      if (loaded) {
        _available = true;
        debugPrint('[AudioSeparationEngine] ffmpeg.wasm loaded successfully');
        return true;
      }
    } catch (e) {
      debugPrint('[AudioSeparationEngine] ffmpeg.wasm load failed: $e');
    } finally {
      _loading = false;
    }

    _available = false;
    return false;
  }

  /// 检查是否支持指定的视频格式
  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedVideoFormats.contains(format.toLowerCase().trim());
  }

  /// 从视频文件中提取音频
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
      throw Exception(
        '音频分离引擎不可用。ffmpeg.wasm 加载失败，请检查网络连接后重试。',
      );
    }

    final inputName = 'input.$videoFormat';
    const outputName = 'output.mp3';
    final completer = Completer<Uint8List>();

    // 注册进度回调
    void progressCallback(double p, int t) {
      onProgress?.call((p * 100).round().clamp(0, 100));
    }

    ffmpegWasmOnProgress(progressCallback);

    // 设置取消回调
    cancelToken?.whenCancel.then((_) {
      if (!completer.isCompleted) {
        ffmpegWasmTerminate();
        completer.completeError(Exception('音频提取被取消'));
      }
    });

    try {
      // 写入输入视频文件
      debugPrint('[AudioSeparationEngine] Writing input file: $inputName');
      await ffmpegWasmWriteFile(inputName, videoBytes);

      // 执行 FFmpeg 命令提取音频
      final args = [
        '-i', inputName,
        '-vn',                // 不处理视频
        '-acodec', 'libmp3lame',
        '-q:a', '2',          // 高质量 MP3
        '-y',                 // 覆盖输出
        outputName,
      ];

      debugPrint('[AudioSeparationEngine] ffmpeg.wasm exec: $args');

      final exitCode = await ffmpegWasmExec(args);

      if (cancelToken?.isCancelled ?? false) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('音频提取被取消'));
        }
        return completer.future;
      }

      if (exitCode != 0) {
        throw Exception('音频提取失败，退出码: $exitCode');
      }

      // 读取输出音频文件
      debugPrint('[AudioSeparationEngine] Reading output file: $outputName');
      final audioBytes = await ffmpegWasmReadFile(outputName);

      if (audioBytes.isEmpty) {
        throw Exception('提取的音频数据为空');
      }

      if (!completer.isCompleted) {
        completer.complete(audioBytes);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e is Exception ? e : Exception('$e'));
      }
    } finally {
      // 清理虚拟文件系统中的临时文件
      try {
        await ffmpegWasmDeleteFile(inputName);
      } catch (_) {}
      try {
        await ffmpegWasmDeleteFile(outputName);
      } catch (_) {}
      ffmpegWasmOnProgress(null); // 清除进度回调
    }

    return completer.future;
  }
}
