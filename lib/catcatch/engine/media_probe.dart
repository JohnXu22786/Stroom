import 'package:flutter/foundation.dart' show debugPrint;
import 'package:media_kit/media_kit.dart';

class MediaProbeResult {
  final Duration? duration;
  final int? width;
  final int? height;

  const MediaProbeResult({this.duration, this.width, this.height});
}

class MediaProbe {
  static Future<MediaProbeResult> probe(String url) async {
    final player = Player();
    try {
      await player.open(Media(url), play: false);
      // 等待媒体信息加载
      await Future.delayed(const Duration(seconds: 2));

      final result = MediaProbeResult(
        duration: player.state.duration,
        width: player.state.width,
        height: player.state.height,
      );
      return result;
    } catch (e) {
      debugPrint('MediaProbe: failed to probe $url: $e');
      return const MediaProbeResult();
    } finally {
      await player.dispose();
    }
  }
}
