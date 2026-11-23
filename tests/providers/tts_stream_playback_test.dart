import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
      final playbackDone =
          response.stream.listen(received.add).asFuture<void>();

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

  test('streams raw PCM as WAV at the requested sample rate', () async {
    final chunks = StreamController<Uint8List>();
    final preparedFuture = prepareTtsPlaybackStream(
      chunks.stream,
      requestedFormat: 'mp3',
      sampleRate: 16000,
    );
    final firstPcmChunk = Uint8List.fromList(List<int>.generate(12, (i) => i));
    chunks.add(firstPcmChunk);
    final prepared = await preparedFuture;
    final output = StreamIterator<Uint8List>(prepared.chunks);

    expect(prepared.format, 'wav');
    try {
      expect(
        await output.moveNext().timeout(const Duration(milliseconds: 50)),
        isTrue,
      );
      final header = output.current;
      final headerData = ByteData.sublistView(header);
      expect(headerData.getUint32(4, Endian.little), 0xffffffff);
      expect(headerData.getUint32(40, Endian.little), 0xffffffff);
      expect(await output.moveNext(), isTrue);
      expect(output.current, firstPcmChunk);

      final nextOutput = output.moveNext();
      final secondPcmChunk = Uint8List.fromList([12, 13]);
      chunks.add(secondPcmChunk);
      expect(await nextOutput, isTrue);
      expect(output.current, secondPcmChunk);
      final streamDone = output.moveNext();
      await chunks.close();
      expect(await streamDone, isFalse);
    } finally {
      await chunks.close();
      await output.cancel();
    }
  });
}
