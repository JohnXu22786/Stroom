import 'package:flutter/foundation.dart' show debugPrint;
import 'package:video_player/video_player.dart';

class MediaProbeResult {
  final Duration? duration;
  final int? width;
  final int? height;

  const MediaProbeResult({this.duration, this.width, this.height});
}

class MediaProbe {
  static Future<MediaProbeResult> probe(String url) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      final result = MediaProbeResult(
        duration: controller.value.duration,
        width: controller.value.size.width.toInt(),
        height: controller.value.size.height.toInt(),
      );
      await controller.dispose();
      return result;
    } catch (e) {
      debugPrint('MediaProbe: failed to probe $url: $e');
      return const MediaProbeResult();
    }
  }
}
