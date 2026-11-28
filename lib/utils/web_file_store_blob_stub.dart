import 'dart:typed_data';

bool isBlob(Object? value) => false;

int? blobByteLength(Object? value) => null;

Object createBlob(Uint8List bytes) => bytes;

Future<Uint8List?> readBlob(Object? value) async => null;

Future<Uint8List?> readBlobPrefix(Object? value, int maxBytes) async => null;

Future<Uint8List?> readBlobCancellable(
  Object? value,
  Future<void> cancellation,
) async =>
    null;

Future<({Object? value, bool converted})> migrateStoredValueToBlob(
  Object objectStore,
  String key,
) async =>
    (value: null, converted: false);
