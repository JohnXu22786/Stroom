/// Returns the payload of an SSE `data:` field, or null when [line] is not
/// a data field. The single space after the colon is optional in SSE.
String? sseDataLineValue(String line) {
  if (!line.startsWith('data:')) return null;

  final value = line.substring('data:'.length);
  return value.startsWith(' ') ? value.substring(1) : value;
}
