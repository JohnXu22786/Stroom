import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/remote_assistant_catalog.dart';

const String kDefaultAssistantCatalogUrl = String.fromEnvironment(
  'STROOM_ASSISTANT_CATALOG_URL',
  defaultValue: '',
);
const int _maxCatalogBytes = 1024 * 1024;

class DownloadedRemoteAssistant {
  final RemoteAssistantCatalogEntry? catalogEntry;
  final RemoteAssistantDefinition definition;
  final String fileUrl;
  final String sha256;
  final String format;

  const DownloadedRemoteAssistant({
    required this.catalogEntry,
    required this.definition,
    required this.fileUrl,
    required this.sha256,
    required this.format,
  });
}

/// Fetches Stroom catalogs and assistant definitions. It intentionally accepts
/// only HTTPS and keeps catalog entries on the catalog's origin.
class AssistantCatalogService {
  AssistantCatalogService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  Future<RemoteAssistantCatalog> fetchCatalog(String catalogUrl) async {
    final uri = _validateHttpsUri(catalogUrl);
    final bytes = await _getBytes(uri, expectedOrigin: uri);
    final source = utf8.decode(bytes, allowMalformed: false);
    return RemoteAssistantCatalog.parse(source);
  }

  Future<DownloadedRemoteAssistant> fetchCatalogEntry({
    required String catalogUrl,
    required RemoteAssistantCatalogEntry entry,
  }) async {
    final catalogUri = _validateHttpsUri(catalogUrl);
    final fileReference = Uri.parse(entry.file);
    if (fileReference.hasScheme ||
        fileReference.hasAuthority ||
        entry.file.startsWith('/')) {
      throw const FormatException('Catalog file must be a relative path.');
    }
    final fileUri = catalogUri.resolveUri(fileReference);
    if (!_sameOrigin(catalogUri, fileUri)) {
      throw const FormatException('Catalog files must use the catalog origin.');
    }
    final bytes = await _getBytes(fileUri, expectedOrigin: catalogUri);
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != entry.sha256) {
      throw const FormatException(
          'Assistant file SHA-256 does not match catalog.');
    }
    final source = utf8.decode(bytes, allowMalformed: false);
    final definition = RemoteAssistantDefinition.parse(
      source,
      format: entry.format,
    );
    _validateCatalogMatch(entry, definition);
    return DownloadedRemoteAssistant(
      catalogEntry: entry,
      definition: definition,
      fileUrl: fileUri.toString(),
      sha256: actualHash,
      format: entry.format,
    );
  }

  Future<DownloadedRemoteAssistant> fetchDirectAssistant(String url) async {
    final uri = _validateHttpsUri(url);
    final bytes = await _getBytes(uri, expectedOrigin: uri);
    final source = utf8.decode(bytes, allowMalformed: false);
    final format = _formatForUri(uri);
    final definition = RemoteAssistantDefinition.parse(source, format: format);
    return DownloadedRemoteAssistant(
      catalogEntry: null,
      definition: definition,
      fileUrl: uri.toString(),
      sha256: sha256.convert(bytes).toString(),
      format: format,
    );
  }

  Future<List<int>> _getBytes(Uri uri, {Uri? expectedOrigin}) async {
    final request = http.Request('GET', uri)
      ..headers['Accept'] =
          'application/json, application/yaml, text/markdown, text/plain';
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen((_) {}).cancel();
      throw FormatException(
          'Download failed with HTTP ${response.statusCode}.');
    }
    if (response.contentLength != null &&
        response.contentLength! > _maxCatalogBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException(
          'Remote assistant files may not exceed 1 MiB.');
    }
    final finalUri = response.request?.url ?? uri;
    if (finalUri.scheme != 'https' ||
        (expectedOrigin != null && !_sameOrigin(expectedOrigin, finalUri))) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException(
          'HTTPS redirects must stay on the same origin.');
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response.stream) {
      length += chunk.length;
      if (length > _maxCatalogBytes) {
        throw const FormatException(
            'Remote assistant files may not exceed 1 MiB.');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Uri _validateHttpsUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        _isLocalHost(uri.host)) {
      throw const FormatException(
          'Assistant URLs must be absolute HTTPS URLs.');
    }
    return uri;
  }

  static bool _isLocalHost(String rawHost) {
    final host = rawHost.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.endsWith('.test')) {
      return true;
    }
    final parts = host.split('.');
    if (parts.length == 4 &&
        parts.every((part) => int.tryParse(part) != null)) {
      final octets = parts.map(int.parse).toList();
      if (octets.any((part) => part < 0 || part > 255)) return true;
      return octets[0] == 10 ||
          octets[0] == 127 ||
          octets[0] == 0 ||
          (octets[0] == 169 && octets[1] == 254) ||
          (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
          (octets[0] == 192 && octets[1] == 168);
    }
    if (host.contains(':')) {
      return host == '::1' ||
          host.startsWith('fc') ||
          host.startsWith('fd') ||
          host.startsWith('fe8') ||
          host.startsWith('fe9') ||
          host.startsWith('fea') ||
          host.startsWith('feb') ||
          host.startsWith('::ffff:127.') ||
          host.startsWith('::ffff:10.') ||
          host.startsWith('::ffff:192.168.');
    }
    return false;
  }

  static bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme &&
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.port == b.port;

  static String _formatForUri(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.json')) return 'stroom-json-v1';
    if (path.endsWith('.yaml') || path.endsWith('.yml'))
      return 'stroom-yaml-v1';
    if (path.endsWith('.md') || path.endsWith('.markdown')) {
      return kRemoteAssistantMarkdownFormat;
    }
    throw const FormatException(
        'URL must point to a .json, .yaml, .yml, or .md file.');
  }

  static void _validateCatalogMatch(
    RemoteAssistantCatalogEntry entry,
    RemoteAssistantDefinition definition,
  ) {
    if (entry.id != definition.id ||
        entry.name != definition.name ||
        entry.version != definition.version ||
        entry.description != definition.description ||
        entry.emoji != definition.emoji) {
      throw const FormatException(
          'Catalog metadata does not match assistant file.');
    }
  }
}
