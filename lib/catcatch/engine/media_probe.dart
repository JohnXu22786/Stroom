import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:video_player/video_player.dart';

class MediaProbeResult {
  final Duration? duration;
  final int? width;
  final int? height;

  const MediaProbeResult({this.duration, this.width, this.height});
}

class MediaProbe {
  static const defaultTimeout = Duration(seconds: 10);

  /// Probe media metadata (duration, width, height) using VideoPlayerController.
  ///
  /// [url] can be a local file path or a network URL (http/https).
  /// Returns a [MediaProbeResult]; on failure returns empty result.
  static Future<MediaProbeResult> probe(
    String url, {
    CancelToken? cancelToken,
    Duration timeout = defaultTimeout,
  }) async {
    if (cancelToken?.isCancelled ?? false) return const MediaProbeResult();

    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    late final VideoPlayerController controller;
    if (isNetworkUrl) {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      controller = VideoPlayerController.file(File(url));
    }

    try {
      final initialize = controller.initialize().timeout(timeout);
      if (cancelToken == null) {
        await initialize;
      } else {
        await Future.any<void>([
          initialize,
          cancelToken.whenCancel.then<void>((_) => throw _ProbeCancelled()),
        ]);
      }
      final result = MediaProbeResult(
        duration: controller.value.duration,
        width: controller.value.size.width.toInt(),
        height: controller.value.size.height.toInt(),
      );
      return result;
    } catch (e) {
      if (e is! _ProbeCancelled) {
        debugPrint('MediaProbe: failed to probe $url: $e');
      }
      return const MediaProbeResult();
    } finally {
      // A failed/abandoned initialize must not keep discovery blocked while
      // the platform player is released.
      try {
        await controller.dispose().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('MediaProbe: failed to dispose player for $url: $e');
      }
    }
  }
}

class _ProbeCancelled implements Exception {}
