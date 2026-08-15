/// Web thumbnail generation (web platform).
/// Uses the HTML5 video + canvas pipeline from `cross_platform_video_thumbnails`
/// to extract a frame from a blob URL built from the video bytes.
library;

import 'dart:typed_data';

// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cross_platform_video_thumbnails/cross_platform_video_thumbnails.dart';

/// Generate a thumbnail from video bytes by creating a blob URL and handing it
/// to the package's web implementation (HTML5 video element + canvas).
///
/// Returns null when generation fails (unsupported codec, empty bytes, ...);
/// callers fall back to a static icon.
Future<Uint8List?> generateThumbnailFromBytes(Uint8List videoBytes) async {
  if (videoBytes.isEmpty) return null;
  try {
    final blobUrl = await createBlobUrl(videoBytes);
    if (blobUrl == null || blobUrl.isEmpty) return null;
    try {
      await CrossPlatformVideoThumbnails.initialize();
      final result = await CrossPlatformVideoThumbnails.generateThumbnail(
        blobUrl,
        const ThumbnailOptions(
          timePosition: 1.0,
          width: 320,
          height: 240,
          quality: 0.8,
          format: ThumbnailFormat.jpeg,
        ),
      ).timeout(const Duration(seconds: 10));
      if (result.data.isNotEmpty) {
        return Uint8List.fromList(result.data);
      }
    } finally {
      revokeBlobUrl(blobUrl);
    }
  } catch (_) {
    // Thumbnail generation failed — caller falls back to a static icon.
  }
  return null;
}

/// Create a blob URL from JS bytes.
Future<String?> createBlobUrl(Uint8List videoBytes) async {
  try {
    final blob = html.Blob([videoBytes]);
    return html.Url.createObjectUrl(blob);
  } catch (_) {
    return null;
  }
}

/// Revoke a blob URL to free memory.
void revokeBlobUrl(String url) {
  html.Url.revokeObjectUrl(url);
}
