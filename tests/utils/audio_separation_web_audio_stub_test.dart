import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_separation_web_audio_stub.dart'
    as webAudioStub;

void main() {
  test('reports unsupported extraction on non-web platforms', () async {
    await expectLater(
      webAudioStub.extractAudioFromWebBytes(Uint8List(0), 'mp4'),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          'Web Audio extraction is only available on web',
        ),
      ),
    );
  });
}
