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
void setNestedParam(Map<String, dynamic> map, String path, dynamic value) {
  final parts = path.split('.');
  if (parts.length == 1) {
    map[parts[0]] = value;
    return;
  }
  var current = map;
  for (int i = 0; i < parts.length - 1; i++) {
    current.putIfAbsent(parts[i], () => <String, dynamic>{});
    current = current[parts[i]] as Map<String, dynamic>;
  }
  current[parts.last] = value;
}
