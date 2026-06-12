import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' show CancelToken;

const _supportedVideoFormats = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
];

class AudioSeparationEngine {
  bool? _available;
  int? _totalDurationUs;

  Future<bool> isAvailable() async {
    if (_available != null) return _available!;

    try {
      final result = await Process.run('ffmpeg', ['-version'],
          runInShell: true);
      if (result.exitCode == 0) {
        _available = true;
        debugPrint('[AudioSeparationEngine] system ffmpeg ready');
        return true;
      }
    } catch (e) {
      debugPrint('[AudioSeparationEngine] ffmpeg not available: $e');
    }

    _available = false;
    return false;
  }

  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedVideoFormats.contains(format.toLowerCase().trim());
  }

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
        '音频分离引擎不可用。请安装 FFmpeg 后重试。',
      );
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

      await _extractWithProcess(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

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

  Future<void> _extractWithProcess({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final command = [
      '-i', inputPath,
      '-vn',
      '-acodec', 'libmp3lame',
      '-q:a', '2',
      '-y', outputPath,
      '-progress', 'pipe:1',
    ];

    debugPrint('[AudioSeparationEngine] ffmpeg command: ffmpeg ${command.join(' ')}');

    _totalDurationUs = null;
    final completer = Completer<void>();

    final process = await Process.start('ffmpeg', command, runInShell: true);

    cancelToken?.whenCancel.then((_) {
      if (!completer.isCompleted) {
        process.kill();
        completer.completeError(Exception('音频提取被取消'));
      }
    });

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (cancelToken?.isCancelled ?? false) return;
      _parseFfmpegProgress(line, onProgress);
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (cancelToken?.isCancelled ?? false) return;
      _parseFfmpegProgress(line, onProgress);
    });

    final exitCode = await process.exitCode;

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
        completer.completeError(Exception('音频提取失败，退出码: $exitCode'));
      }
    }

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
