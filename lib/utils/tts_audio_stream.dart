import 'dart:async';
import 'dart:typed_data';

import 'audio_utils.dart';

class PreparedTtsAudioStream {
  const PreparedTtsAudioStream(this.chunks, this.format);

  final Stream<Uint8List> chunks;
  final String format;
}

/// Detects the streamed audio container and converts bare PCM to playable WAV.
Future<PreparedTtsAudioStream> prepareTtsPlaybackStream(
  Stream<Uint8List> chunks, {
  required String requestedFormat,
  required int sampleRate,
}) async {
  final iterator = StreamIterator<Uint8List>(chunks);
  final buffered = <Uint8List>[];
  final prefix = Uint8List(12);
  var prefixLength = 0;

  try {
    while (prefixLength < prefix.length && await iterator.moveNext()) {
      final chunk = iterator.current;
      if (chunk.isEmpty) continue;
      buffered.add(chunk);
      final prefixBytes = chunk.length < prefix.length - prefixLength
          ? chunk.length
          : prefix.length - prefixLength;
      prefix.setRange(prefixLength, prefixLength + prefixBytes, chunk);
      prefixLength += prefixBytes;
    }
  } catch (_) {
    await iterator.cancel();
    rethrow;
  }

  final normalizedRequested = requestedFormat.toLowerCase();
  if (prefixLength == 0) {
    return PreparedTtsAudioStream(
      _remainingChunks(iterator),
      normalizedRequested,
    );
  }

  late final String detectedFormat;
  try {
    detectedFormat = prefixLength < 4
        ? 'pcm'
        : detectAudioFormat(Uint8List.sublistView(prefix, 0, prefixLength));
  } catch (_) {
    await iterator.cancel();
    rethrow;
  }
  if (detectedFormat == 'pcm') {
    return PreparedTtsAudioStream(
      _convertPcmToWav(iterator, buffered, sampleRate),
      'wav',
    );
  }

  return PreparedTtsAudioStream(
    _forwardChunks(iterator, buffered),
    detectedFormat,
  );
}

Stream<Uint8List> _remainingChunks(StreamIterator<Uint8List> iterator) async* {
  try {
    while (await iterator.moveNext()) {
      if (iterator.current.isNotEmpty) yield iterator.current;
    }
  } finally {
    await iterator.cancel();
  }
}

Stream<Uint8List> _forwardChunks(
  StreamIterator<Uint8List> iterator,
  List<Uint8List> buffered,
) async* {
  try {
    for (final chunk in buffered) {
      yield chunk;
    }
    yield* _remainingChunks(iterator);
  } finally {
    await iterator.cancel();
  }
}

Stream<Uint8List> _convertPcmToWav(
  StreamIterator<Uint8List> iterator,
  List<Uint8List> buffered,
  int sampleRate,
) async* {
  try {
    // RIFF's unknown-length sentinel lets native playback begin while the PCM
    // stream is still arriving. The browser buffers the same chunks into Blob.
    final header = pcmToWav(Uint8List(0), sampleRate: sampleRate);
    final headerData = ByteData.sublistView(header);
    headerData.setUint32(4, 0xffffffff, Endian.little);
    headerData.setUint32(40, 0xffffffff, Endian.little);
    yield header;

    for (final chunk in buffered) {
      if (chunk.isNotEmpty) yield chunk;
    }
    while (await iterator.moveNext()) {
      if (iterator.current.isNotEmpty) yield iterator.current;
    }
  } finally {
    await iterator.cancel();
  }
}
