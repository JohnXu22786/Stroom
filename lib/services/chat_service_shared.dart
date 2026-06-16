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
