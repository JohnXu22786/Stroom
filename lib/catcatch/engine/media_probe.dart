import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:video_player/video_player.dart';

class MediaProbeResult {
  final Duration? duration;
  final int? width;
  final int? height;

  const MediaProbeResult({this.duration, this.width, this.height});
}

class MediaProbe {
  /// Probe media metadata (duration, width, height) using VideoPlayerController.
  ///
  /// [url] can be a local file path or a network URL (http/https).
  /// Returns a [MediaProbeResult]; on failure returns empty result.
  static Future<MediaProbeResult> probe(String url) async {
    final isNetworkUrl =
        url.startsWith('http://') || url.startsWith('https://');

    late final VideoPlayerController controller;
    if (isNetworkUrl) {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      controller = VideoPlayerController.file(File(url));
    }

    try {
      await controller.initialize();
      final result = MediaProbeResult(
        duration: controller.value.duration,
        width: controller.value.size.width.toInt(),
        height: controller.value.size.height.toInt(),
      );
      return result;
    } catch (e) {
      debugPrint('MediaProbe: failed to probe $url: $e');
      return const MediaProbeResult();
    } finally {
      controller.dispose();
    }
  }
}
