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
  test('natural playback completion resets state and emits final position',
      () async {
    html.AudioElement? audio;
    final player = AudioPlayerAdapter(
      createAudio: () => audio = html.AudioElement(),
    );
    addTearDown(player.dispose);

    const wav =
        'UklGRkQDAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YSADAACAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgA==';
    await player.load('data:audio/wav;base64,$wav');

    final states = <bool>[];
    final positions = <Duration>[];
    final stateSubscription = player.stateStream.listen((_) {
      states.add(player.playing);
    });
    final positionSubscription = player.positionStream.listen(positions.add);
    addTearDown(stateSubscription.cancel);
    addTearDown(positionSubscription.cancel);

    // Stub play() so the browser's autoplay policy does not affect this event test.
    final audioJs = JSObject.fromInteropObject(audio!);
    final promiseConstructor =
        JSObject.fromInteropObject(html.window)['Promise']! as JSObject;
    final resolvePromise = promiseConstructor['resolve'] as JSFunction;
    audioJs['play'] = (() => resolvePromise.callAsFunction(
          promiseConstructor,
        )).toJS;
    await player.play();
    expect(player.playing, isTrue);

    final stateChanged = player.stateStream.firstWhere((_) => !player.playing);
    audio!.currentTime = audio!.duration;
    audio!.dispatchEvent(html.Event('ended'));
    await stateChanged;

    expect(player.playing, isFalse);
    expect(states, [true, false]);
    expect(
      positions.last,
      greaterThanOrEqualTo(const Duration(milliseconds: 100)),
    );
  });
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
