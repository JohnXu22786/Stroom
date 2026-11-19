import 'dart:io';
import 'dart:typed_data';

/// Writes [videoBytes] to a unique temporary video file for [generate].
///
/// The temporary directory is removed after generation, including when the
/// generator throws.
Future<T?> withVideoThumbnailTempFile<T>(
  Uint8List videoBytes,
  Future<T?> Function(String videoPath) generate,
) async {
  final tempDir = await Directory.systemTemp.createTemp('stroom_thumb_');
  final tempFile = File('${tempDir.path}/video.mp4');
  try {
    await tempFile.writeAsBytes(videoBytes);
    return await generate(tempFile.path);
  } finally {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
