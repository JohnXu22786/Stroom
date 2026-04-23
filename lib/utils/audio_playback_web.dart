import 'dart:html' as html;
import 'dart:typed_data';

html.AudioElement? _audio;

/// Play audio bytes using the HTML5 Audio element (Web only)
void playAudioBytes(Uint8List data, String mimeType) {
  stopAudio();
  final blob = html.Blob([data], mimeType);
  final url = html.Url.createObjectUrl(blob);
  _audio = html.AudioElement(url);
  _audio?.play();
}

/// Play audio from a URL
void playAudioUrl(String url) {
  stopAudio();
  _audio = html.AudioElement(url);
  _audio?.play();
}

/// Stop current audio playback
void stopAudio() {
  _audio?.pause();
  _audio = null;
}
