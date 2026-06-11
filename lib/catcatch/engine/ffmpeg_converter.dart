import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart' show CancelToken;

/// 格式转换器
///
/// 将下载的 TS 分段合并/转换为 MP4。
/// 优先使用系统安装的 FFmpeg，不可用时退化为纯 Dart 合并。
class FFmpegConverter {
  FFmpegConverter._();

  /// 检查系统是否安装了 FFmpeg
  ///
  /// 执行 `ffmpeg -version` 验证。
  static Future<bool> isFFmpegAvailable() async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['ffmpeg'],
      );
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('[FFmpegConverter] FFmpeg not found: $e');
      return false;
    }
  }

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
      return outputPath;
    }

    final ffmpegAvailable = await isFFmpegAvailable();

    if (ffmpegAvailable) {
      return _convertWithFfmpeg(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    // FFmpeg 不可用时，使用纯 Dart 合并（仅适用于 TS 文件）
    debugPrint('[FFmpegConverter] FFmpeg not available, using pure Dart merge');
    if (inputExt == '.ts' || inputExt == '.ts.catcatch_tmp') {
      // 直接复制文件（TS → MP4 容器兼容）
      onProgress?.call(10);
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
throw FileSystemException('下载源文件不存在，请重新下载', inputPath);
      }

      onProgress?.call(50);
      await inputFile.copy(outputPath);
      onProgress?.call(100);

      return outputPath;
    }

    throw UnsupportedError(
      'FFmpeg is required to convert non-TS formats. '
      'Please install FFmpeg or provide a TS file.',
    );
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

  // ===========================================================================
  // FFmpeg 转换
  // ===========================================================================

  /// 使用 FFmpeg 进行转换
  static Future<String> _convertWithFfmpeg({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // 确保输出目录存在
    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    // 检查输入
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input file not found', inputPath);
    }

    // 如果输入是 TS 文件，直接复制流（不重新编码）
    final isTs = inputPath.toLowerCase().endsWith('.ts');

    final args = <String>[
      '-i', inputPath,
      '-y', // 覆盖输出
      '-progress', 'pipe:1', // 输出进度到 stdout
    ];

    if (isTs) {
      args.addAll(['-c', 'copy']);
    } else {
      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'fast',
        '-crf',
        '23',
        '-c:a',
        'aac',
        '-b:a',
        '128k',
      ]);
    }

    args.add(outputPath);

    debugPrint('[FFmpegConverter] Running: ffmpeg ${args.join(' ')}');

    final process = await Process.start('ffmpeg', args);
    cancelToken?.whenCancel.then((_) {
      process.kill();
    });

    int? totalDurationUs;

    // 读取 stdout 获取 FFmpeg 进度
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (cancelToken?.isCancelled ?? false) {
        process.kill();
        return;
      }
      if (line.startsWith('out_time_us=')) {
        final us = int.tryParse(line.substring('out_time_us='.length));
        if (us != null && totalDurationUs != null && totalDurationUs! > 0) {
          final p = (us * 100 ~/ totalDurationUs!).clamp(0, 100);
          onProgress?.call(p);
        }
      }
    });

    // 读取 stderr 获取总时长
    final stderrLines = <String>[];
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrLines.add(line);
      final durationMatch =
          RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
      if (durationMatch != null) {
        final h = int.parse(durationMatch.group(1)!);
        final m = int.parse(durationMatch.group(2)!);
        final s = double.parse(durationMatch.group(3)!);
        totalDurationUs = ((h * 3600 + m * 60 + s) * 1000000).round();
      }
    });

    final exitCode = await process.exitCode;

    // 如果取消了，终止进程
    if (cancelToken?.isCancelled ?? false) {
      process.kill();
      throw Exception('Task was cancelled during FFmpeg conversion');
    }

    if (exitCode != 0) {
      final error = stderrLines.join('\n');
      throw ProcessException(
        'ffmpeg',
        args,
        'Exit code: $exitCode\n$error',
      );
    }

    onProgress?.call(100);
    debugPrint('[FFmpegConverter] Conversion complete: $outputPath');
    return outputPath;
  }

  /// 从视频文件中提取音频
  ///
  /// [inputPath] 输入视频文件路径
  /// [outputPath] 输出音频文件路径（建议 .mp3）
  /// [onProgress] 进度回调 0-100
  /// [cancelToken] 取消令牌
  ///
  /// 返回输出文件路径。
  static Future<String> extractAudio({
    required String inputPath,
    required String outputPath,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // 确保输出目录存在
    final outDir = Directory(File(outputPath).parent.path);
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    // 检查输入
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input file not found', inputPath);
    }

    final args = <String>[
      '-i', inputPath,
      '-vn', // 不包含视频流
      '-acodec', 'libmp3lame',
      '-q:a', '2', // 高质量
      '-y', // 覆盖输出
      '-progress', 'pipe:1',
      outputPath,
    ];

    debugPrint('[FFmpegConverter] Running ffmpeg audio extraction: '
        'ffmpeg ${args.join(' ')}');

    final process = await Process.start('ffmpeg', args);
    cancelToken?.whenCancel.then((_) {
      process.kill();
    });

    int? totalDurationUs;

    // 读取 stdout 获取 FFmpeg 进度
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (cancelToken?.isCancelled ?? false) {
        process.kill();
        return;
      }
      if (line.startsWith('out_time_us=')) {
        final us = int.tryParse(line.substring('out_time_us='.length));
        if (us != null && totalDurationUs != null && totalDurationUs! > 0) {
          final p = (us * 100 ~/ totalDurationUs!).clamp(0, 100);
          onProgress?.call(p);
        }
      }
    });

    // 读取 stderr 获取总时长
    final stderrLines = <String>[];
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrLines.add(line);
      final durationMatch =
          RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.\d+)').firstMatch(line);
      if (durationMatch != null) {
        final h = int.parse(durationMatch.group(1)!);
        final m = int.parse(durationMatch.group(2)!);
        final s = double.parse(durationMatch.group(3)!);
        totalDurationUs = ((h * 3600 + m * 60 + s) * 1000000).round();
      }
    });

    final exitCode = await process.exitCode;

    if (cancelToken?.isCancelled ?? false) {
      process.kill();
      throw Exception('Task was cancelled during audio extraction');
    }

    if (exitCode != 0) {
      final error = stderrLines.join('\n');
      throw ProcessException(
        'ffmpeg',
        args,
        'Exit code: $exitCode\n$error',
      );
    }

    onProgress?.call(100);
    debugPrint('[FFmpegConverter] Audio extraction complete: $outputPath');
    return outputPath;
  }
}
