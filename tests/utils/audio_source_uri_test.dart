import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_source_uri.dart';

void main() {
  group('audioSourceUri', () {
    test('preserves a generated data URI scheme', () {
      const dataUri = 'data:audio/mpeg;base64,SUQz';

      expect(audioSourceUri(dataUri).toString(), dataUri);
    });

    test('converts a local path to a file URI', () {
      const filePath = '/tmp/voice recording.mp3';

      expect(audioSourceUri(filePath), Uri.file(filePath));
      expect(audioSourceUri(r'C:recording.mp3'), Uri.file(r'C:recording.mp3'));
      expect(
        audioSourceUri('recording:take.mp3'),
        Uri.file('recording:take.mp3'),
      );
    });
  });
}
