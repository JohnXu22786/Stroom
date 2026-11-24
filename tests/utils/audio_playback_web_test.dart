// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
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

  test(
    'stopping before streamed audio is ready settles the pending load',
    () async {
      final audioCreated = Completer<html.AudioElement>();
      final player = AudioPlayerAdapter(
        createAudio: () {
          final audio = html.AudioElement();
          if (!audioCreated.isCompleted) audioCreated.complete(audio);
          return audio;
        },
      );
      addTearDown(player.dispose);

      final playback = player.playStream(
        Stream<Uint8List>.value(_testWav()),
        contentType: 'audio/wav',
      );
      await audioCreated.future;

      player.stop();

      await expectLater(
        playback.timeout(const Duration(milliseconds: 50)),
        completes,
      );
    },
  );

  test('plays the audio resource built from streamed chunks', () async {
    final audioCreated = Completer<html.AudioElement>();
    final player = AudioPlayerAdapter(
      createAudio: () {
        final audio = html.AudioElement();
        if (!audioCreated.isCompleted) audioCreated.complete(audio);
        return audio;
      },
    );
    addTearDown(player.dispose);

    final chunks = StreamController<Uint8List>();
    final playback = player.playStream(chunks.stream, contentType: 'audio/wav');
    chunks.add(_testWav());
    await chunks.close();
    final audio = await audioCreated.future;
    _stubPlay(audio);
    final started = player.stateStream.firstWhere((_) => player.playing);
    audio.dispatchEvent(html.Event('canplay'));

    await started.timeout(const Duration(seconds: 1));
    expect(audio.src, startsWith('blob:'));
    audio.dispatchEvent(html.Event('ended'));
    await playback;
    expect(player.playing, isFalse);
  });

  test('loading another audio file settles current stream playback', () async {
    final audios = <html.AudioElement>[];
    final streamAudioCreated = Completer<html.AudioElement>();
    final player = AudioPlayerAdapter(
      createAudio: () {
        final audio = html.AudioElement();
        audios.add(audio);
        if (!streamAudioCreated.isCompleted) {
          streamAudioCreated.complete(audio);
        }
        return audio;
      },
    );
    addTearDown(player.dispose);

    final playback = player.playStream(
      Stream<Uint8List>.value(_testWav()),
      contentType: 'audio/wav',
    );
    final streamAudio = await streamAudioCreated.future;
    _stubPlay(streamAudio);
    final started = player.stateStream.firstWhere((_) => player.playing);
    streamAudio.dispatchEvent(html.Event('canplay'));
    await started.timeout(const Duration(seconds: 1));

    final nextLoad = player.load(
      'data:audio/wav;base64,${base64Encode(_testWav())}',
    );
    final nextAudio = audios.last;
    nextAudio.dispatchEvent(html.Event('canplay'));
    await nextLoad;

    await expectLater(
      playback.timeout(const Duration(milliseconds: 50)),
      completes,
    );
    expect(player.playing, isFalse);
  });

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

Uint8List _testWav() {
  const sampleBytes = 16000;
  final bytes = Uint8List(44 + sampleBytes);
  final data = ByteData.view(bytes.buffer);
  void writeTag(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  writeTag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  writeTag(8, 'WAVE');
  writeTag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeTag(36, 'data');
  data.setUint32(40, sampleBytes, Endian.little);
  return bytes;
}

void _stubPlay(html.AudioElement audio) {
  final audioJs = JSObject.fromInteropObject(audio);
  final promiseConstructor =
      JSObject.fromInteropObject(html.window)['Promise']! as JSObject;
  final resolvePromise = promiseConstructor['resolve'] as JSFunction;
  audioJs['play'] = (() => resolvePromise.callAsFunction(
        promiseConstructor,
      )).toJS;
}
