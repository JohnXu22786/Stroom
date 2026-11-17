// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

@TestOn('browser')
library;

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_playback_web.dart';

void main() {
  test(
    'load settles when the player is disposed before audio is ready',
    () async {
      final player = AudioPlayerAdapter();
      final load = player.load('data:audio/wav;base64,');

      player.dispose();

      await expectLater(load.timeout(const Duration(seconds: 1)), completes);
    },
  );

  test('downloadAudioFile defers Blob URL revocation', () async {
    final urlConstructor =
        JSObject.fromInteropObject(html.window)['URL']! as JSObject;
    final originalRevoke = urlConstructor['revokeObjectURL'] as JSFunction;
    final revokedUrls = <String>[];

    urlConstructor['revokeObjectURL'] = ((JSString url) => revokedUrls.add(
      url.toDart,
    )).toJS;
    addTearDown(() {
      urlConstructor['revokeObjectURL'] = originalRevoke;
      for (final url in revokedUrls) {
        originalRevoke.callAsFunction(urlConstructor, url.toJS);
      }
    });

    downloadAudioFile(Uint8List.fromList([1, 2, 3]), 'audio.wav', 'audio/wav');

    expect(revokedUrls, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(revokedUrls, hasLength(1));
  });
}
