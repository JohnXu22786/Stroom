import 'dart:typed_data';

/// Represents a single selected video file for audio separation.
class SelectedVideo {
  final Uint8List bytes;
  final String name;
  final String format;

  SelectedVideo({
    required this.bytes,
    required this.name,
    this.format = 'mp4',
  });
}
