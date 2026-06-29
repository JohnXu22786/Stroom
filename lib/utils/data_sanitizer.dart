/// Utility functions for sanitizing data for display.
///
/// Prevents UI freezes by hiding large base64-encoded content (e.g., images)
/// and truncating oversized strings.
class DataSanitizer {
  DataSanitizer._();

  /// Recursively sanitize [data] for display by hiding base64 content
  /// (images, etc.) to prevent UI freezes when rendering large encoded data.
  static dynamic sanitizeForDisplay(dynamic data) {
    if (data is Map) {
      final result = <String, dynamic>{};
      for (final entry in data.entries) {
        result[entry.key] = sanitizeForDisplay(entry.value);
      }
      return result;
    } else if (data is List) {
      return data.map(sanitizeForDisplay).toList();
    } else if (data is String) {
      return sanitizeBase64String(data);
    }
    return data;
  }

  /// Replace long base64 strings with a placeholder showing only length.
  /// Detects data URIs for images and standalone base64 strings longer than 300 chars.
  static String sanitizeBase64String(String value) {
    // Data URI pattern: data:image/<type>;base64,<data>
    // Supports types like png, jpeg, svg+xml, webp, etc.
    final dataUriPattern =
        RegExp(r'^data:image/[a-zA-Z][a-zA-Z0-9+\-.]*;base64,');
    if (dataUriPattern.hasMatch(value)) {
      final commaIndex = value.indexOf(',');
      final prefix = value.substring(0, commaIndex + 1);
      final b64Part = value.substring(commaIndex + 1);
      return '$prefix[base64 data: ${b64Part.length} bytes hidden]';
    }
    // Detect long base64-like strings (>= 300 chars).
    // Only check first 100 chars to avoid scanning huge strings on the main thread.
    if (value.length >= 300) {
      // Some base64 encoders insert newlines every 76 chars — strip them for the check.
      final sample =
          value.substring(0, 100).replaceAll(RegExp(r'[\s\r\n]'), '');
      final base64Chars = RegExp(r'^[A-Za-z0-9+/=]+$');
      if (base64Chars.hasMatch(sample)) {
        return '[base64 data: ${value.length} bytes hidden]';
      }
    }
    return value;
  }
}
