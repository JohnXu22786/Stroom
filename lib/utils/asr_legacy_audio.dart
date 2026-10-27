import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

const _legacyBase64BatchLength = 8192;

class _Base64ByteCountSink implements Sink<List<int>> {
  int byteLength = 0;

  @override
  void add(List<int> data) => byteLength += data.length;

  @override
  void close() {}
}

class _Base64BytesSink implements Sink<List<int>> {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  @override
  void add(List<int> data) => _builder.add(data);

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}

/// Validates legacy Base64 audio without retaining the decoded audio buffer.
///
/// Decoding proceeds in bounded input slices and yields between slices so
/// large legacy retry payloads do not monopolize Flutter Web's event loop.
/// Returns null for empty or malformed payloads, otherwise the decoded length.
Future<int?> validateAsrLegacyBase64AudioByteLength(
  String value, {
  void Function()? onYield,
  void Function()? checkCanceled,
}) async {
  checkCanceled?.call();
  if (value.isEmpty) return null;

  final output = _Base64ByteCountSink();
  try {
    final decoder = base64.decoder.startChunkedConversion(output);
    for (var start = 0;
        start < value.length;
        start += _legacyBase64BatchLength) {
      checkCanceled?.call();
      final end = start + _legacyBase64BatchLength < value.length
          ? start + _legacyBase64BatchLength
          : value.length;
      decoder.add(value.substring(start, end));
      if (end < value.length) {
        onYield?.call();
        await Future<void>.delayed(Duration.zero);
        checkCanceled?.call();
      }
    }
    decoder.close();
    checkCanceled?.call();
  } on FormatException {
    return null;
  }
  return output.byteLength > 0 ? output.byteLength : null;
}

/// Decodes legacy Base64 audio in bounded batches so Web staging remains
/// responsive after validation has accepted a large retry payload.
Future<Uint8List> decodeAsrLegacyBase64Audio(
  String value, {
  void Function()? onYield,
  void Function()? checkCanceled,
}) async {
  final output = _Base64BytesSink();
  final decoder = base64.decoder.startChunkedConversion(output);
  for (var start = 0; start < value.length; start += _legacyBase64BatchLength) {
    checkCanceled?.call();
    final end = start + _legacyBase64BatchLength < value.length
        ? start + _legacyBase64BatchLength
        : value.length;
    decoder.add(value.substring(start, end));
    if (end < value.length) {
      onYield?.call();
      await Future<void>.delayed(Duration.zero);
      checkCanceled?.call();
    }
  }
  decoder.close();
  return output.takeBytes();
}
