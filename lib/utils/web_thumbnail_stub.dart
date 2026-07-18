/// Web thumbnail generation stubs (native platform).
/// Uses only native-compatible code.
library;

import 'dart:typed_data';

/// Generate a thumbnail from video bytes (not supported on native via this method).
Future<Uint8List?> generateThumbnailFromBytes(Uint8List videoBytes) async {
  // On native platforms, thumbnails are generated from the file path directly.
  return null;
}

/// Create a blob URL from JS bytes (stub for native).
Future<String?> createBlobUrl(Uint8List videoBytes) async => null;

/// Revoke a blob URL (stub for native).
void revokeBlobUrl(String url) {}
