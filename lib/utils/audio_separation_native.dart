import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' show CancelToken;

// macOS/Android/iOS/Windows：使用 ffmpeg_kit_flutter_new 的内置 FFmpeg
// Linux：使用 asset 中捆绑的 FFmpeg 二进制 → Process.run
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'ffmpeg_resolver.dart';

const _supportedVideoFormats = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
];

/// 音频分离引擎（原生平台实现）
///
/// 跨平台音频分离，无需用户额外安装 FFmpeg：
/// - Android/iOS/macOS：使用 ffmpeg_kit_flutter 内置 FFmpeg
/// - Windows/Linux：使用 asset 中捆绑的 FFmpeg 二进制文件
/// - Web：使用 audio_separation_web.dart 中的独立实现
class AudioSeparationEngine {
  bool? _available;
  int? _totalDurationUs;

  /// 缓存 Windows/Linux 上 FFmpeg 可执行文件的路径
  String? _resolvedFfmpegPath;

  /// 当前平台是否应使用 ffmpeg_kit_flutter_new（而非 Process.run）
  ///
  /// ffmpeg_kit_flutter_new 支持：Android、iOS、macOS、Windows
  /// Linux 需要从 assets 中提取二进制并通过 Process.run 调用
  static bool get _useFfmpegKitFlutter =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// 检查音频分离引擎是否可用
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;

    if (_useFfmpegKitFlutter) {
      // macOS/Android/iOS：ffmpeg_kit_flutter 内置 FFmpeg
      try {
        final session = await FFmpegKit.execute('-version');
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          _available = true;
          debugPrint(
              '[AudioSeparationEngine] ffmpeg_kit_flutter ready'
              ' (${Platform.operatingSystem})');
          return true;
        }
      } catch (e) {
        debugPrint(
            '[AudioSeparationEngine] ffmpeg_kit_flutter not available: $e');
      }
    } else {
      // Windows/Linux：使用 asset 中捆绑的 FFmpeg 二进制
      try {
        final ffmpegPath = await FFmpegResolver.ensureFFmpegReady();
        if (ffmpegPath != null) {
          _resolvedFfmpegPath = ffmpegPath;
          final result = await Process.run(ffmpegPath, ['-version']);
          if (result.exitCode == 0) {
            _available = true;
            debugPrint(
                '[AudioSeparationEngine] bundled ffmpeg ready'
                ' (${Platform.operatingSystem}): $ffmpegPath');
            return true;
          }
        }
      } catch (e) {
        debugPrint(
            '[AudioSeparationEngine] bundled ffmpeg not available: $e');
      }
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
      throw Exception('音频分离引擎不可用。请确认应用资源完整后重试。');
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(p.join(tempDir.path, 'audio_separation'));
    if (!await workDir.exists()) {
      await workDir.create(recursive: true);
    }

    final inputPath = p.join(workDir.path, 'input.$videoFormat');
    final outputPath = p.join(workDir.path, 'output.mp3');

    try {
      await File(inputPath).writeAsBytes(videoBytes);

      if (_useFfmpegKitFlutter) {
        await _extractWithFfmpegKit(
          inputPath: inputPath,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else {
        await _extractWithProcess(
          inputPath: inputPath,
          outputPath: outputPath,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      }

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
      _cleanupFile(inputPath);
      _cleanupFile(outputPath);
      _cleanupDir(workDir);
    }
  }

  /// Windows/Linux：使用捆绑的 FFmpeg 二进制提取音频
  Future<void> _extractWithProcess({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final ffmpegPath = _resolvedFfmpegPath ?? 'ffmpeg';
    final command = [
      '-i', inputPath,
      '-vn',
      '-acodec', 'libmp3lame',
      '-q:a', '2',
      '-y', outputPath,
      '-progress', 'pipe:1',
    ];

    debugPrint(
        '[AudioSeparationEngine] ffmpeg: $ffmpegPath ${command.join(' ')}');

    _totalDurationUs = null;
    final completer = Completer<void>();

    final process = await Process.start(ffmpegPath, command);

    cancelToken?.whenCancel.then((_) {
      if (!completer.isCompleted) {
        process.kill();
        completer.completeError(Exception('音频提取被取消'));
      }
    });

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (cancelToken?.isCancelled ?? false) return;
      _parseFfmpegProgress(line, onProgress);
    });

    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (cancelToken?.isCancelled ?? false) return;
      _parseFfmpegProgress(line, onProgress);
    });

    final exitCode = await process.exitCode;

    // 取消流订阅，避免处理过期数据
    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (cancelToken?.isCancelled ?? false) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('音频提取被取消'));
      }
      return completer.future;
    }

    if (exitCode == 0) {
      onProgress?.call(100);
      if (!completer.isCompleted) completer.complete();
    } else {
      if (!completer.isCompleted) {
        completer.completeError(
            Exception('音频提取失败，退出码: $exitCode'));
      }
    }

    return completer.future;
  }

  /// 移动端：使用 ffmpeg_kit_flutter 内置 FFmpeg 提取音频
  Future<void> _extractWithFfmpegKit({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final command =
        '-i $inputPath -vn -acodec libmp3lame -q:a 2 -y $outputPath';

    debugPrint(
        '[AudioSeparationEngine] ffmpeg_kit_flutter command: $command');

    _totalDurationUs = null;
    final completer = Completer<void>();

    // 设置取消回调：cancelToken 触发时取消 FFmpeg 执行
    cancelToken?.whenCancel.then((_) {
      FFmpegKit.cancel();
      if (!completer.isCompleted) {
        completer.completeError(Exception('音频提取被取消'));
      }
    });

    await FFmpegKit.executeAsync(
      command,
      (session) async {
        try {
          if (cancelToken?.isCancelled ?? false) {
            session.cancel();
            if (!completer.isCompleted) {
              completer.completeError(Exception('音频提取被取消'));
            }
            return;
          }

          final returnCode = await session.getReturnCode();
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
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('音频提取回调异常: $e'));
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

  void _parseFfmpegProgress(
      String message, void Function(int progress)? onProgress) {
    if (onProgress == null) return;

    final durationMatch =
        RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(message);
    if (durationMatch != null) {
      final h = int.parse(durationMatch.group(1)!);
      final m = int.parse(durationMatch.group(2)!);
      final s = double.parse(durationMatch.group(3)!);
      _totalDurationUs = ((h * 3600 + m * 60 + s) * 1000000).round();
    }

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