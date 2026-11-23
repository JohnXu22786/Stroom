import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/audio_utils.dart';
import 'package:stroom/utils/tts_audio_stream.dart';
import 'package:stroom/utils/tts_stream_audio_source.dart';

void main() {
  test(
    'forwards each synthesized chunk to the audio source in order',
    () async {
      final chunks = StreamController<Uint8List>();
      final source = TtsStreamAudioSource(
        chunks.stream,
        contentType: 'audio/wav',
      );
      final response = await source.request();
      final received = <List<int>>[];
      final playbackDone = response.stream
          .listen(received.add)
          .asFuture<void>();

      chunks.add(Uint8List.fromList([1, 2]));
      await Future<void>.delayed(Duration.zero);
      chunks.add(Uint8List.fromList([3, 4]));
      await chunks.close();
      await playbackDone;
      await source.completed;

      expect(response.rangeRequestsSupported, isFalse);
      expect(response.contentType, 'audio/wav');
      expect(received, [
        <int>[1, 2],
        <int>[3, 4],
      ]);
    },
  );

  test('stopping the audio source cancels its upstream stream', () async {
    var upstreamCancelled = false;
    final chunks = StreamController<Uint8List>(
      onCancel: () => upstreamCancelled = true,
    );
    final source = TtsStreamAudioSource(
      chunks.stream,
      contentType: 'audio/wav',
    );
    final response = await source.request();
    final subscription = response.stream.listen((_) {});

    await subscription.cancel();

    expect(upstreamCancelled, isTrue);
    await expectLater(source.completed, completes);
  });

  test('reports a terminal synthesis error to playback completion', () async {
    final chunks = StreamController<Uint8List>();
    final source = TtsStreamAudioSource(
      chunks.stream,
      contentType: 'audio/wav',
    );
    final response = await source.request();
    final error = StateError('synthesis failed');
    final playbackError = expectLater(response.stream, emitsError(same(error)));
    final completionError = expectLater(source.completed, throwsA(same(error)));

    chunks.addError(error);
    await chunks.close();

    await playbackError;
    await completionError;
  });

  test('converts raw PCM chunks to WAV at the requested sample rate', () async {
    final pcm = Uint8List.fromList([1, 2, 3, 4]);
    final prepared = await prepareTtsPlaybackStream(
      Stream<Uint8List>.fromIterable([
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3, 4]),
      ]),
      requestedFormat: 'mp3',
      sampleRate: 16000,
    );
    final chunks = await prepared.chunks.toList();

    expect(prepared.format, 'wav');
    expect(chunks, [pcmToWav(pcm, sampleRate: 16000)]);
  });
}
