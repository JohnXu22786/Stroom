import 'dart:js_interop';
import 'dart:typed_data';

@JS('__mediaKitExtractAudio')
external JSPromise<JSUint8Array> _extractAudio(
  JSUint8Array videoBytes,
  JSString videoFormat,
);

Future<Uint8List> extractAudioFromWebBytes(
  Uint8List videoBytes,
  String videoFormat,
) async {
  final output = await _extractAudio(videoBytes.toJS, videoFormat.toJS).toDart;
  return output.toDart;
}
