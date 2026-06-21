import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart' show CancelToken;
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _supportedVideoFormats = [
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp',
];

/// 音频分离引擎（原生平台实现）
///
/// 使用 media_kit 的 Player + mpv 编码引擎从视频中提取音频并保存为 MP3 文件。
class AudioSeparationEngine {
  /// 始终可用（media_kit 已集成）
  Future<bool> isAvailable() async {
    return true;
  }

  /// 检查是否支持指定的视频格式
  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedVideoFormats.contains(format.toLowerCase().trim());
  }

  /// 从视频文件中提取音频
  ///
  /// 使用 media_kit 的 Player 打开视频文件，通过 mpv 编码引擎输出音频到文件。
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

    final tempDir = await getTemporaryDirectory();
    final inputName = 'input_${DateTime.now().millisecondsSinceEpoch}.$videoFormat';
    final outputName = 'output_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final inputPath = p.join(tempDir.path, inputName);
    final outputPath = p.join(tempDir.path, outputName);

    try {
      // 写入输入视频文件
      await File(inputPath).writeAsBytes(videoBytes);

      debugPrint('[AudioSeparationEngine] Input written: $inputPath');

      // 创建 Player 并配置 mpv 编码输出
      final player = Player();
      try {
        // 配置 mpv 编码参数 (通过 NativePlayer 的 setProperty)
        if (player.platform != null) {
          await (player.platform as dynamic).setProperty('ao', 'null');
          await (player.platform as dynamic).setProperty('keep-open', 'no');
          await (player.platform as dynamic).setProperty('o', outputPath);
          await (player.platform as dynamic).setProperty('oac', 'libmp3lame');
          await (player.platform as dynamic).setProperty('ovc', 'no');
        }

        // ── 等待编码完成 ──────────────────────────────────────────────
        // 使用 Completer，配合三种完成检测方式：
        //   1. player.stream.completed 事件（首选）
        //   2. 输出文件轮询检测（后备）
        //   3. 5 分钟超时（终极保底）
        // ──────────────────────────────────────────────────────────────
        final completer = Completer<void>();
        StreamSubscription? completionSub;
        StreamSubscription? errorSub;
        Timer? filePollTimer;
        StreamSubscription<Duration>? positionSub;

        // 注册取消回调（必须在 completer 声明之后）
        cancelToken?.whenCancel.then((_) async {
          try {
            if (!completer.isCompleted) {
              completer.completeError(Exception('音频提取被取消'));
            }
          } catch (_) {}
          try {
            await player.dispose();
          } catch (_) {}
        });

        // 打开媒体文件（mpv 会进入编码模式，直接输出到文件）
        await player.open(
          Media(Uri.file(inputPath).toString()),
          play: true,
        );

        // 方式1: 监听 completed 事件（mpv 完成编码时触发）
        completionSub = player.stream.completed.listen((completed) {
          if (completed && !completer.isCompleted) {
            debugPrint('[AudioSeparationEngine] Completed event received');
            completer.complete();
          }
        });

        // 监听错误事件
        errorSub = player.stream.error.listen((error) {
          if (error.isNotEmpty && !completer.isCompleted) {
            completer.completeError(Exception('音频提取失败: $error'));
          }
        });

        // 进度更新
        if (onProgress != null) {
          // 使用 position 流获取编码进度
          positionSub = player.stream.position.listen((position) {
            final duration = player.state.duration;
            if (duration.inMilliseconds > 0) {
              final progress = ((position.inMilliseconds / duration.inMilliseconds) * 100)
                  .round()
                  .clamp(0, 100);
              onProgress(progress);
            }
          });
        }

        // 方式2: 输出文件轮询（completed 事件在编码模式下可能不触发）
        int lastFileSize = 0;
        int stableCount = 0;
        const stableThreshold = 4; // 连续 4 次（~2 秒）文件大小不变 = 编码完成
        filePollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (completer.isCompleted) return;

          try {
            final outputFile = File(outputPath);
            if (!outputFile.existsSync()) return;

            final currentSize = outputFile.lengthSync();

            // 确保文件非空后再进行稳定性判断
            if (currentSize > 0) {
              // 文件非空，进入稳定性判断
            } else {
              // 空文件，跳过本轮
              return;
            }

            // 向外部报告基于文件大小的进度（当 duration 不可用时）
            if (onProgress != null) {
              // 使用输入文件大小作为估算基准：输出 mp3 通常为输入的 5-15%
              // 保守估算：用当前文件大小 / (输入大小 * 0.15) 作为上限
              final estimatedMax = (videoBytes.length * 0.15).round().clamp(1, videoBytes.length);
              final fileProgress = (currentSize * 100 ~/ estimatedMax).clamp(0, 95);
              onProgress(fileProgress);
            }

            if (currentSize == lastFileSize) {
              stableCount++;
              if (stableCount >= stableThreshold) {
                debugPrint('[AudioSeparationEngine] Output file stable for ${stableThreshold * 500}ms, assuming encoding complete');
                if (onProgress != null) {
                  onProgress(100);
                }
                completer.complete();
              }
            } else {
              stableCount = 0;
              lastFileSize = currentSize;
            }
          } catch (_) {
            // 文件尚未就绪，忽略
          }
        });

        // 方式3: 超时（5分钟）
        final timeout = Future.delayed(const Duration(minutes: 5), () {
          if (!completer.isCompleted) {
            completer.completeError(Exception('音频提取超时'));
          }
        });

        try {
          await completer.future;
        } finally {
          timeout.ignore();
          filePollTimer?.cancel();
          completionSub?.cancel();
          errorSub?.cancel();
          positionSub?.cancel();
        }

        // 等待一小段时间确保文件写入完成
        await Future.delayed(const Duration(milliseconds: 500));

        // 读取输出音频文件
        if (cancelToken?.isCancelled ?? false) {
          throw Exception('音频提取被取消');
        }

        if (!await File(outputPath).exists()) {
          throw Exception('输出文件未生成');
        }

        final audioBytes = await File(outputPath).readAsBytes();

        if (audioBytes.isEmpty) {
          throw Exception('提取的音频数据为空');
        }

        debugPrint('[AudioSeparationEngine] Audio extracted: ${audioBytes.length} bytes');
        return audioBytes;
      } finally {
        try {
          await player.dispose();
        } catch (_) {}
      }
    } finally {
      // 清理临时文件
      try {
        if (await File(inputPath).exists()) {
          await File(inputPath).delete();
        }
      } catch (_) {}
      try {
        if (await File(outputPath).exists()) {
          await File(outputPath).delete();
        }
      } catch (_) {}
    }
  }
}
