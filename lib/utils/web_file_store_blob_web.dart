import 'dart:js_interop';
import 'dart:typed_data';

import 'package:idb_shim/idb_shim.dart' show IdbNativeValue;
import 'package:web/web.dart' as web;

web.Blob? _blobFromStoredValue(Object? value) {
  if (value is! IdbNativeValue) return null;
  final jsValue = value.jsObject as JSAny?;
  if (!jsValue.isA<web.Blob>()) return null;
  return value.jsObject as web.Blob;
}

bool isBlob(Object? value) => _blobFromStoredValue(value) != null;

int? blobByteLength(Object? value) => _blobFromStoredValue(value)?.size.toInt();

Object createBlob(Uint8List bytes) =>
    IdbNativeValue(web.Blob([bytes.toJS].toJS));

Future<Uint8List?> readBlob(Object? value) async {
  final blob = _blobFromStoredValue(value);
  if (blob == null) return null;
  final buffer = await blob.arrayBuffer().toDart;
  return Uint8List.view(buffer.toDart);
}
