import 'dart:typed_data';

Future<Uint8List> extractAudioFromWebBytes(
  Uint8List videoBytes,
  String videoFormat,
) =>
    Future.error(
      UnsupportedError('Web Audio extraction is only available on web'),
    );
