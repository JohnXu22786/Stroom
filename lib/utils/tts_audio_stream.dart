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
  final bytes = BytesBuilder(copy: false);
  try {
    for (final chunk in buffered) {
      bytes.add(chunk);
    }
    while (await iterator.moveNext()) {
      bytes.add(iterator.current);
    }
    final pcm = bytes.takeBytes();
    if (pcm.isNotEmpty) yield pcmToWav(pcm, sampleRate: sampleRate);
  } finally {
    await iterator.cancel();
  }
}
