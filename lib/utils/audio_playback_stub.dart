import 'dart:typed_data';

/// Stub for platforms where dart:html is not available (native)
void playAudioBytes(Uint8List data, String mimeType) {
  // No-op on native platforms - use just_audio or other native audio player
}

void stopAudio() {
  // No-op
}
