import 'dart:typed_data';

/// Represents a single selected audio file for ASR transcription.
class SelectedAudio {
  final Uint8List bytes;
  final String name;
  final String format;

  SelectedAudio({required this.bytes, required this.name, this.format = 'wav'});
}
