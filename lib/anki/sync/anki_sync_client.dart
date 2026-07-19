import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// HTTP client for AnkiWeb sync authentication.
///
/// Matches Anki's Rust HttpSyncClient + sync_login() exactly:
/// 1. POST to /sync/hostKey with JSON {"u": email, "p": password}
/// 2. X-Sync-Header with empty sync_key (first login)
/// 3. Response: JSON {"key": "hkey_value"}
class AnkiSyncClient {
  static const String _baseUrl = 'https://sync.ankiweb.net/sync';

  /// Authenticate with AnkiWeb.
  ///
  /// Returns the session key (hkey) on success, or throws on failure.
  static Future<String> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/hostKey');
    final body = jsonEncode({'u': email, 'p': password});
    final header = jsonEncode({
      'sync_version': 1,
      'sync_key': '',
      'client_ver': 'ankidart:1.0',
      'session_key': _randomSessionId(),
    });

    final resp = await http.post(
      uri,
      body: body,
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Sync-Header': header,
      },
    );

    if (resp.statusCode != 200) {
      final errorText = resp.body.isNotEmpty ? resp.body : '无响应体';
      throw AnkiSyncException('登录失败 (${resp.statusCode}): $errorText');
    }

    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final key = json['key'] as String?;
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}

    throw AnkiSyncException('登录失败: 无法解析服务器响应 "${resp.body.trim()}"');
  }

  /// Exchange session key for a hostKey.
  /// [key] is the sync hkey to exchange.
  static Future<String> hostKey(String key) async {
    final uri = Uri.parse('$_baseUrl/hostKey');
    final header = jsonEncode({
      'sync_version': 1,
      'sync_key': key,
      'client_ver': 'ankidart:1.0',
      'session_key': _randomSessionId(),
    });

    final resp = await http.post(
      uri,
      body: jsonEncode({'u': key}),
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Sync-Header': header,
      },
    );

    if (resp.statusCode != 200) {
      throw AnkiSyncException(
          'hostKey 请求失败 (${resp.statusCode}): ${resp.body}');
    }

    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final hk = json['key'] as String?;
      if (hk != null && hk.isNotEmpty) return hk;
    } catch (_) {}

    throw AnkiSyncException('hostKey 获取失败: ${resp.body.trim()}');
  }

  static String _randomSessionId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return String.fromCharCodes(Iterable.generate(
        10, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
  }
}

class AnkiSyncException implements Exception {
  final String message;
  AnkiSyncException(this.message);
  @override
  String toString() => message;
}
