import 'dart:typed_data';

bool isBlob(Object? value) => false;

int? blobByteLength(Object? value) => null;

Object createBlob(Uint8List bytes) => bytes;

Future<Uint8List?> readBlob(Object? value) async => null;

Future<bool> migrateStoredValueToBlob(Object objectStore, String key) async =>
    false;
