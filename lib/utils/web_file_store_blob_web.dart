import 'dart:async';
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

/// Converts a legacy IndexedDB byte value to a Blob without dartifying its
/// payload into a Uint8List first.
Future<bool> migrateStoredValueToBlob(Object objectStore, String key) async {
  final store = (objectStore as dynamic).idbObjectStore as web.IDBObjectStore;
  final request = store.get(key.toJS);
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    completer.completeError(
      request.error ?? StateError('Cannot read legacy attachment: $key'),
    );
  }).toJS;
  final value = await completer.future;
  if (value == null || value.isA<web.Blob>()) return false;
  if (!value.isA<JSUint8Array>() && !value.isA<JSArrayBuffer>()) {
    throw StateError('Cannot migrate attachment storage value: $key');
  }

  final blob = web.Blob([value].toJS);
  store.put(blob, key.toJS);
  return true;
}
