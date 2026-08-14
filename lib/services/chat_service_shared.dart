import 'package:flutter/foundation.dart' show debugPrint;

/// Map MIME type to file extension for data URI.
String imageExtension(String mimeType) {
  switch (mimeType) {
    case 'image/png':
      return 'png';
    case 'image/gif':
      return 'gif';
    case 'image/webp':
      return 'webp';
    case 'image/bmp':
      return 'bmp';
    default:
      return 'jpeg';
  }
}

/// Map audio MIME type to format identifier for [input_audio] content part.
///
/// The format field in the OpenAI [input_audio] spec expects values like
/// 'mp3', 'wav', 'ogg', etc., derived from the MIME type.
/// Falls back to 'mp3' for unrecognised audio MIME types.
String audioFormatFromMimeType(String mimeType) {
  switch (mimeType) {
    case 'audio/mpeg':
    case 'audio/mp3':
      return 'mp3';
    case 'audio/wav':
    case 'audio/x-wav':
    case 'audio/wave':
      return 'wav';
    case 'audio/ogg':
      return 'ogg';
    case 'audio/aac':
      return 'aac';
    case 'audio/flac':
    case 'audio/x-flac':
      return 'flac';
    case 'audio/webm':
      return 'webm';
    case 'audio/mp4':
    case 'audio/x-m4a':
      return 'm4a';
    default:
      // Fall back to extracting extension from filename as last resort
      return 'mp3';
  }
}

/// Set a value at a dot-notation path in the given map.
/// E.g. setNestedParam(map, 'thinking.type', 'enabled')
///   -> map['thinking']['type'] = 'enabled'
///
/// Defensive: when a flat param collides with a nested param sharing a
/// prefix (e.g. `provider` vs `provider.only`), the nested path always wins
/// in BOTH insertion orders — an existing map is never clobbered by a later
/// flat assignment, and an existing scalar is replaced by a fresh map so the
/// nested path can descend. This avoids the old type-cast crash and keeps
/// the precedence deterministic. Both silent-drop directions are logged.
void setNestedParam(Map<String, dynamic> map, String path, dynamic value) {
  final parts = path.split('.');
  if (parts.length == 1) {
    final existing = map[parts[0]];
    if (existing is Map<String, dynamic>) {
      // 嵌套路径已占位：保留嵌套结构，丢弃扁平值（嵌套优先，两种顺序
      // 一致）。更高层级的扁平覆盖在此被丢弃——记录日志便于排查。
      debugPrint(
        '[ChatService] setNestedParam: flat param "$path" dropped because '
        'a nested structure already occupies that key.',
      );
      return;
    }
    map[parts[0]] = value;
    return;
  }
  var current = map;
  for (int i = 0; i < parts.length - 1; i++) {
    final existing = current[parts[i]];
    if (existing is Map<String, dynamic>) {
      current = existing;
    } else {
      if (existing != null) {
        debugPrint(
          '[ChatService] setNestedParam: flat value under "$path" replaced '
          'by a nested structure (nested path wins).',
        );
      }
      final nested = <String, dynamic>{};
      current[parts[i]] = nested;
      current = nested;
    }
  }
  current[parts.last] = value;
}
