import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

bool isBlob(Object? value) => (value as JSAny?).isA<web.Blob>();

int? blobByteLength(Object? value) =>
    isBlob(value) ? (value as web.Blob).size.toInt() : null;

Object createBlob(Uint8List bytes) => web.Blob([bytes.toJS].toJS);

Future<Uint8List?> readBlob(Object? value) async {
  if (!isBlob(value)) return null;
  final buffer = await (value as web.Blob).arrayBuffer().toDart;
  return Uint8List.view(buffer.toDart);
}
