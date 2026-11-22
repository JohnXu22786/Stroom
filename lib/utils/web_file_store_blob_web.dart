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

Future<Uint8List?> readBlobCancellable(
  Object? value,
  Future<void> cancellation,
) async {
  final blob = _blobFromStoredValue(value);
  if (blob == null) return null;

  final reader = blob.stream().getReader() as web.ReadableStreamDefaultReader;
  final cancelled = Completer<void>();
  final chunks = BytesBuilder(copy: false);
  final subscription = cancellation.asStream().listen((_) {
    try {
      unawaited(
        reader.cancel().toDart.then<void>((_) {}, onError: (Object _) {}),
      );
    } catch (_) {
      // The stream may already have closed when cancellation arrives.
    }
    if (!cancelled.isCompleted) cancelled.complete();
  });

  try {
    while (true) {
      final next = await Future.any<Object?>([
        reader.read().toDart,
        cancelled.future.then<Object?>((_) => null),
      ]);
      if (next == null) break;

      final result = next as web.ReadableStreamReadResult;
      if (result.done) break;
      final value = result.value;
      if (value == null || !value.isA<JSUint8Array>()) {
        throw StateError('Blob stream returned a non-byte chunk');
      }
      chunks.add((value as JSUint8Array).toDart);
    }
    return chunks.takeBytes();
  } finally {
    await subscription.cancel();
    reader.releaseLock();
  }
}

/// Converts a legacy IndexedDB byte value to a Blob without dartifying its
/// payload into a Uint8List first.
Future<({Object? value, bool converted})> migrateStoredValueToBlob(
  Object objectStore,
  String key,
) async {
  final dynamic nativeStore;
  try {
    // idb_shim's native browser store exposes its raw IndexedDB object store;
    // only its non-IndexedDB fallback needs the Dart conversion path below.
    nativeStore = (objectStore as dynamic).idbObjectStore;
  } catch (_) {
    return _migrateThroughShim(objectStore, key);
  }
  if (!(nativeStore as JSAny?).isA<web.IDBObjectStore>()) {
    return _migrateThroughShim(objectStore, key);
  }

  final store = nativeStore as web.IDBObjectStore;
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
  if (value == null) return (value: null, converted: false);
  if (value.isA<web.Blob>()) {
    return (value: IdbNativeValue(value), converted: false);
  }
  if (!value.isA<JSUint8Array>() && !value.isA<JSArrayBuffer>()) {
    throw StateError('Cannot migrate attachment storage value: $key');
  }

  final blob = web.Blob([value].toJS);
  store.put(blob, key.toJS);
  return (value: IdbNativeValue(blob), converted: true);
}

Future<({Object? value, bool converted})> _migrateThroughShim(
  Object objectStore,
  String key,
) async {
  final dynamic store = objectStore;
  final value = await store.getObject(key) as Object?;
  if (value == null || isBlob(value)) {
    return (value: value, converted: false);
  }

  final bytes = switch (value) {
    Uint8List bytes => bytes,
    List<int> bytes => Uint8List.fromList(bytes),
    _ => null,
  };
  if (bytes == null) {
    throw StateError('Cannot migrate attachment storage value: $key');
  }
  final blob = createBlob(bytes);
  await store.put(blob, key);
  return (value: blob, converted: true);
}
