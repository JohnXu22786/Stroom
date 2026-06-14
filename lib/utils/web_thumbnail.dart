/// Web thumbnail generation (web platform).
/// Uses dart:js_interop for blob URL creation.
import 'dart:js_interop';
import 'dart:typed_data';

/// Generate a thumbnail from video bytes by creating a blob URL
/// and using media_kit's Player to take a screenshot.
Future<Uint8List?> generateThumbnailFromBytes(Uint8List videoBytes) async {
  try {
    final jsBytes = videoBytes.map((b) => b.toJS).toList().toJS;
    final result = _jsCreateBlobUrl(jsBytes);
    if (result == null) return null;
    final blobUrl = result.dartify() as String?;
    if (blobUrl == null || blobUrl.isEmpty) return null;
    // Web thumbnail via Player.screenshot is handled separately
    return null;
  } catch (_) {
    return null;
  }
}

/// Create a blob URL from JS bytes.
Future<String?> createBlobUrl(Uint8List videoBytes) async {
  final jsBytes = videoBytes.map((b) => b.toJS).toList().toJS;
  final result = _jsCreateBlobUrl(jsBytes);
  if (result == null) return null;
  return result.dartify() as String?;
}

/// Revoke a blob URL to free memory.
void revokeBlobUrl(String url) {
  _jsRevokeBlobUrl(url.toJS);
}

@JS('URL.createObjectURL')
external JSAny? _jsCreateBlobUrl(JSAny blob);

@JS('URL.revokeObjectURL')
external void _jsRevokeBlobUrl(JSString url);
