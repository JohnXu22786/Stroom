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
    final bytes = _parseIpAddress(host);
    if (bytes == null) {
      // Reject malformed numeric and IPv6-looking literals rather than
      // letting alternate parser spellings reach the HTTP client.
      return host.contains(':') ||
          RegExp(
            r'^(?:0x[0-9a-f]+|[0-9]+)(?:\.(?:0x[0-9a-f]+|[0-9]+))*$',
            caseSensitive: false,
          ).hasMatch(host);
    }
    if (bytes.length == 4) return _isPrivateIpv4(bytes);
    if (bytes.length != 16) return true;

    // IPv4-mapped IPv6 addresses use the same private-range policy as IPv4.
    final isIpv4Mapped = bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    if (isIpv4Mapped) return _isPrivateIpv4(bytes.sublist(12));

    final isUnspecified = bytes.every((byte) => byte == 0);
    final isLoopback =
        bytes.take(15).every((byte) => byte == 0) && bytes[15] == 1;
    final isUniqueLocal = bytes[0] & 0xfe == 0xfc;
    final isLinkLocal = bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80;
    final isSiteLocal = bytes[0] == 0xfe && bytes[1] & 0xc0 == 0xc0;
    final isMulticast = bytes[0] == 0xff;
    final isDocumentation = bytes[0] == 0x20 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x0d &&
        bytes[3] == 0xb8;
    return isUnspecified ||
        isLoopback ||
        isUniqueLocal ||
        isLinkLocal ||
        isSiteLocal ||
        isMulticast ||
        isDocumentation;
  }

  static bool _isPrivateIpv4(List<int> octets) =>
      octets[0] == 0 ||
      octets[0] == 10 ||
      octets[0] == 127 ||
      octets[0] >= 224 ||
      (octets[0] == 169 && octets[1] == 254) ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168) ||
      (octets[0] == 100 && octets[1] >= 64 && octets[1] <= 127) ||
      (octets[0] == 192 && octets[1] == 0 && octets[2] == 0) ||
      (octets[0] == 192 && octets[1] == 0 && octets[2] == 2) ||
      (octets[0] == 192 && octets[1] == 88 && octets[2] == 99) ||
      (octets[0] == 198 && (octets[1] == 18 || octets[1] == 19)) ||
      (octets[0] == 198 && octets[1] == 51 && octets[2] == 100) ||
      (octets[0] == 203 && octets[1] == 0 && octets[2] == 113);

  static List<int>? _parseIpAddress(String host) {
    if (!host.contains(':')) return _parseIpv4(host);

    final compressionIndex = host.indexOf('::');
    if (compressionIndex >= 0 &&
        host.indexOf('::', compressionIndex + 2) >= 0) {
      return null;
    }
    final leftText =
        compressionIndex < 0 ? host : host.substring(0, compressionIndex);
    final rightText =
        compressionIndex < 0 ? '' : host.substring(compressionIndex + 2);
    final left = _parseIpv6Groups(leftText);
    final right = _parseIpv6Groups(rightText);
    if (left == null || right == null) return null;
    final groupCount = left.length + right.length;
    if ((compressionIndex < 0 && groupCount != 8) ||
        (compressionIndex >= 0 && groupCount >= 8)) {
      return null;
    }
    final groups = [
      ...left,
      if (compressionIndex >= 0) ...List<int>.filled(8 - groupCount, 0),
      ...right,
    ];
    return [
      for (final group in groups) ...[group >> 8, group & 0xff],
    ];
  }

  static List<int>? _parseIpv6Groups(String section) {
    if (section.isEmpty) return const [];
    final parts = section.split(':');
    final groups = <int>[];
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      if (part.isEmpty) return null;
      if (part.contains('.')) {
        if (index != parts.length - 1) return null;
        final ipv4 = _parseIpv4(part);
        if (ipv4 == null) return null;
        groups
          ..add((ipv4[0] << 8) | ipv4[1])
          ..add((ipv4[2] << 8) | ipv4[3]);
        continue;
      }
      if (part.length > 4 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(part)) {
        return null;
      }
      groups.add(int.parse(part, radix: 16));
    }
    return groups;
  }

  static List<int>? _parseIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty ||
          (part.length > 1 && part.startsWith('0')) ||
          !RegExp(r'^\d+$').hasMatch(part)) {
        return null;
      }
      final octet = int.tryParse(part);
      if (octet == null || octet > 255) return null;
      octets.add(octet);
    }
    return octets;
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
