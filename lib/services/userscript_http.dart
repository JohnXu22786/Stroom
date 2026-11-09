import 'dart:convert';

export 'userscript_http_response.dart';
export 'userscript_http_io.dart'
    if (dart.library.html) 'userscript_http_web.dart';

String normalizeUserscriptUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('invalidUrl');
  }
  final host = uri.host.toLowerCase();
  if (host == 'github.com') {
    final parts = uri.pathSegments;
    final blobIndex = parts.indexOf('blob');
    if (blobIndex == 2 && parts.length > 4) {
      final rawPath = [...parts.take(2), ...parts.skip(3)].join('/');
      return Uri.https('raw.githubusercontent.com', '/$rawPath').toString();
    }
  }
  final isGreasyFork = host == 'greasyfork.org' ||
      host == 'www.greasyfork.org' ||
      host == 'update.greasyfork.org';
  final isGithubRaw = host == 'raw.githubusercontent.com';
  if ((!isGreasyFork && !isGithubRaw) ||
      (isGreasyFork && !uri.path.toLowerCase().endsWith('.user.js'))) {
    throw const FormatException('unsupportedUrl');
  }
  if (host == 'greasyfork.org' || host == 'www.greasyfork.org') {
    return uri.replace(host: 'update.greasyfork.org').toString();
  }
  return uri.toString();
}

void validateUserscriptResponse(String source, {String? contentType}) {
  if (source.trim().isEmpty) throw const FormatException('notScript');
  final normalizedContentType = contentType?.toLowerCase();
  final mediaType = normalizedContentType?.split(';').first.trim();
  const javaScriptMimeTypes = {
    'application/javascript',
    'text/javascript',
    'application/ecmascript',
    'text/ecmascript',
    'application/x-ecmascript',
    'text/x-ecmascript',
    'application/x-javascript',
    'text/x-javascript',
  };
  if (mediaType == 'text/html' ||
      (mediaType != null &&
          !javaScriptMimeTypes.contains(mediaType) &&
          mediaType != 'text/plain' &&
          mediaType != 'application/octet-stream') ||
      RegExp(r'^\s*<(?:!doctype\s+html|html\b)', caseSensitive: false)
          .hasMatch(source)) {
    throw const FormatException('notScript');
  }
  final hasUserscriptHeader =
      RegExp(r'^\s*// ==UserScript==\s*$', multiLine: true).hasMatch(source);
  final hasUserscriptEnd =
      RegExp(r'^\s*// ==/UserScript==\s*$', multiLine: true).hasMatch(source);
  final isJavaScriptMime = javaScriptMimeTypes.contains(mediaType);
  var isJson = false;
  try {
    jsonDecode(source);
    isJson = true;
  } on FormatException {
    // JavaScript source isn't necessarily valid JSON.
  }
  final looksLikeError = RegExp(
    r'^\s*(?:access denied|permission denied|unauthorized|forbidden|not found|error\b|failed\b|request failed|cannot get\b|could not\b|bad gateway|service unavailable|rate limit\b|too many requests|http\s+\d{3})',
    caseSensitive: false,
  ).hasMatch(source);
  final isPlainTextMime = !isJavaScriptMime &&
      (mediaType == null ||
          mediaType == 'text/plain' ||
          mediaType == 'application/octet-stream');
  if ((isJson && !isJavaScriptMime) ||
      (looksLikeError && !isJavaScriptMime) ||
      (isPlainTextMime && !(hasUserscriptHeader && hasUserscriptEnd))) {
    throw const FormatException('notScript');
  }
}
