import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// FFmpeg 路径解析器（暂不可用）
class FFmpegResolver {
  FFmpegResolver._();

  static Future<bool> isFFmpegAvailable() async => false;

  static Future<String?> ensureFFmpegReady() async => null;
}
