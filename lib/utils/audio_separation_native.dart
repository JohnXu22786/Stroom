import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' show CancelToken;

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';

/// 支持音频分离的格式列表
const _supportedVideoFormats = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
];

/// 音频分离引擎（原生平台实现）
///
/// 使用 ffmpeg_kit_flutter 内置 FFmpeg 从视频文件中提取音频。
/// 支持 Android、macOS、iOS，无需系统安装 FFmpeg。
class AudioSeparationEngine {
  bool? _available;
  int? _totalDurationUs;

  /// 检查音频分离引擎是否可用
  ///
  /// 调用 ffmpeg_kit_flutter 验证内置 FFmpeg 是否就绪。
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;

    try {
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        _available = true;
        debugPrint('[AudioSeparationEngine] ffmpeg_kit_flutter ready');
        return true;
      }
    } catch (e) {
      debugPrint(
          '[AudioSeparationEngine] ffmpeg_kit_flutter not available: $e');
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
  ///
  /// [videoBytes] 视频文件的字节数据
  /// [videoFormat] 视频格式（如 'mp4', 'mov' 等）
  /// [onProgress] 进度回调 0-100
  /// [cancelToken] 取消令牌
  ///
  /// 返回提取的音频字节数据（MP3 格式）。
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // 验证输入
    if (videoBytes.isEmpty) {
      throw Exception('视频数据为空');
    }

    if (!canHandleVideoFormat(videoFormat)) {
      throw Exception('不支持的视频格式: $videoFormat');
    }

    // 检查引擎可用性
    if (!(await isAvailable())) {
      throw Exception(
        '音频分离引擎不可用。当前平台不支持或内置 FFmpeg 未就绪。',
      );
    }

    // 创建临时目录和文件
    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(p.join(tempDir.path, 'audio_separation'));
    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }

    final inputPath = p.join(workDir.path, 'input.$videoFormat');
    final outputPath = p.join(workDir.path, 'output.mp3');

    try {
      // 写入临时视频文件
      await File(inputPath).writeAsBytes(videoBytes);

      // 使用 ffmpeg_kit_flutter 提取音频
      await _extractWithFfmpegKit(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      // 读取输出音频文件
      final audioFile = File(outputPath);
      if (!await audioFile.exists()) {
        throw Exception('音频提取失败：输出文件不存在');
      }

      final audioBytes = await audioFile.readAsBytes();
      if (audioBytes.isEmpty) {
        throw Exception('提取的音频数据为空');
      }

      return audioBytes;
    } finally {
      // 清理临时文件
      _cleanupFile(inputPath);
      _cleanupFile(outputPath);
      _cleanupDir(workDir);
    }
  }

  /// 使用 ffmpeg_kit_flutter 提取音频
  Future<void> _extractWithFfmpegKit({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final command =
        '-i $inputPath -vn -acodec libmp3lame -q:a 2 -y $outputPath';

    debugPrint('[AudioSeparationEngine] ffmpeg_kit command: $command');

    _totalDurationUs = null;
    final completer = Completer<void>();

    await FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (cancelToken?.isCancelled ?? false) {
          session.cancel();
          if (!completer.isCompleted) {
            completer.completeError(Exception('音频提取被取消'));
          }
          return;
        }

        if (ReturnCode.isSuccess(returnCode)) {
          onProgress?.call(100);
          if (!completer.isCompleted) completer.complete();
        } else if (ReturnCode.isCancel(returnCode)) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('音频提取被取消'));
          }
        } else {
          final output = await session.getOutput();
          final error = output ?? '未知错误';
          if (!completer.isCompleted) {
            completer.completeError(Exception('音频提取失败: $error'));
          }
        }
      },
      (log) {
        final message = log.getMessage();
        if (message != null) {
          _parseFfmpegProgress(message, onProgress);
        }
      },
    );

    return completer.future;
  }

  /// 解析 FFmpeg 日志中的进度信息
  void _parseFfmpegProgress(
      String message, void Function(int progress)? onProgress) {
    if (onProgress == null) return;

    // 匹配 "Duration:" 格式获取总时长
    final durationMatch =
        RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(message);
    if (durationMatch != null) {
      final h = int.parse(durationMatch.group(1)!);
      final m = int.parse(durationMatch.group(2)!);
      final s = double.parse(durationMatch.group(3)!);
      _totalDurationUs = ((h * 3600 + m * 60 + s) * 1000000).round();
    }

    // 匹配 "time=" 格式计算当前进度
    if (_totalDurationUs != null && _totalDurationUs! > 0) {
      final timeMatch =
          RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(message);
      if (timeMatch != null) {
        final h = int.parse(timeMatch.group(1)!);
        final m = int.parse(timeMatch.group(2)!);
        final s = double.parse(timeMatch.group(3)!);
        final currentUs = ((h * 3600 + m * 60 + s) * 1000000).round();
        final progress =
            (currentUs * 100 ~/ _totalDurationUs!).clamp(0, 100);
        onProgress(progress);
      }
    }
  }

  void _cleanupFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _cleanupDir(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
