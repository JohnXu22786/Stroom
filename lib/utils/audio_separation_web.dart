import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;

import 'audio_separation_native.dart' show extractAudioWebAsync;

/// Web platform audio separation engine.
///
/// Uses the shared pure-Dart MP4 demuxer and packaging so extracted audio has
/// the same playable WAV (PCM) or M4A (AAC) output on every platform.
class AudioSeparationEngine {
  /// Always available — pure-Dart implementation.
  Future<bool> isAvailable() async => true;

  static const _supportedFormats = ['mp4', 'mov', 'm4v', '3gp'];

  bool canHandleVideoFormat(String format) {
    if (format.isEmpty) return false;
    return _supportedFormats.contains(format.toLowerCase().trim());
  }

  /// Extract audio using the shared pure-Dart MP4 demuxer and packager.
  Future<Uint8List> extractAudio({
    required Uint8List videoBytes,
    required String videoFormat,
    void Function(int progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final result = await extractAudioWebAsync(
      videoBytes: videoBytes,
      videoFormat: videoFormat,
      isCancelled: () => cancelToken?.isCancelled ?? false,
      onProgress: (progress) {
        if (progress != 100) onProgress?.call(progress);
      },
    );
    if (cancelToken?.isCancelled ?? false) {
      throw Exception('Audio extraction was cancelled');
    }
    onProgress?.call(100);
    return result;
  }
}
