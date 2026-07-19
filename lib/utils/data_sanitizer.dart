/// Utility functions for sanitizing data for display and persistence.
///
/// Prevents UI freezes by hiding large base64-encoded content (e.g., images,
/// videos, audio, documents) and truncating oversized strings.
///
/// IMPORTANT: This is also used on the **save path** (see
/// [ChatMessage._sanitizeRawMap]) to keep the on-disk JSON small. A multi-MB
/// base64 video embedded in `rawRequest` would otherwise bloat SharedPreferences
/// writes, causing UI freezes, process kills, and silent data corruption.
class DataSanitizer {
  DataSanitizer._();

  /// Generic `data:<mime>;base64,<data>` URI pattern.
  ///
  /// MIME type characters per RFC 6838: `[a-zA-Z0-9.+\-]+`. We allow both
  /// the type and subtype segments plus an optional `;<params>` block
  /// (e.g. `;charset=utf-8`) before the `;base64,` marker.
  ///
  /// Matches: `data:image/png;base64,…`, `data:video/mp4;base64,…`,
  ///          `data:audio/mpeg;base64,…`, `data:application/pdf;base64,…`,
  ///          `data:image/svg+xml;base64,…`
  static final RegExp _dataUriPattern = RegExp(
      r'^data:[a-zA-Z0-9][a-zA-Z0-9.+\-]*/[a-zA-Z0-9][a-zA-Z0-9.+\-]*(;[^,]*)?;base64,');

  /// Long base64-like strings (no data URI prefix) are detected by sampling
  /// the first 100 chars for the base64 alphabet. Compiled once at file scope
  /// to avoid per-call compilation cost on the save hot path.
  static final RegExp _base64Alphabet = RegExp(r'^[A-Za-z0-9+/=]+$');
  static final RegExp _whitespace = RegExp(r'[\s\r\n]');

  /// Recursively sanitize [data] for display by hiding base64 content
  /// (images, videos, audio, documents, etc.) to prevent UI freezes when
  /// rendering large encoded data.
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
  ///
  /// Detects **all** `data:<mime>;base64,<data>` URIs (not just images) so
  /// video, audio, PDF and other large attachments are stripped on save.
  /// Also detects standalone base64 strings longer than 300 chars.
  static String sanitizeBase64String(String value) {
    if (_dataUriPattern.hasMatch(value)) {
      final commaIndex = value.indexOf(',');
      final prefix = value.substring(0, commaIndex + 1);
      final b64Part = value.substring(commaIndex + 1);
      return '$prefix[base64 data: ${b64Part.length} bytes hidden]';
    }
    // Detect long base64-like strings (>= 300 chars).
    // Only check first 100 chars to avoid scanning huge strings on the main thread.
    if (value.length >= 300) {
      // Some base64 encoders insert newlines every 76 chars — strip them for the check.
      final sample = value.substring(0, 100).replaceAll(_whitespace, '');
      if (_base64Alphabet.hasMatch(sample)) {
        return '[base64 data: ${value.length} bytes hidden]';
      }
    }
    return value;
  }
}
