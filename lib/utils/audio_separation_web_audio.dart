import 'dart:typed_data';

import 'audio_separation_native.dart' show extractAudioWebAsync;

/// Extracts an MP4-family container's audio track in the browser.
///
/// The shared pure-Dart demuxer handles the video container and returns audio
/// in its native output format (WAV for PCM, M4A for AAC).
Future<Uint8List> extractAudioFromWebBytes(
  Uint8List videoBytes,
  String videoFormat, {
  bool Function()? isCancelled,
  void Function(int progress)? onProgress,
}) => extractAudioWebAsync(
  videoBytes: videoBytes,
  videoFormat: videoFormat,
  isCancelled: isCancelled,
  onProgress: onProgress,
);
