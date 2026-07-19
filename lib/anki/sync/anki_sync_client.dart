import 'package:http/http.dart' as http;

/// HTTP client for AnkiWeb sync authentication.
///
/// Mirrors AnkiDroid's `com.ichi2.anki.sync.AnkiSyncClient` login flow:
/// 1. POST credentials → get `key` (session hkey)
/// 2. POST key → get `hostKey` (optional, for API access)
///
/// The full sync protocol (protobuf data exchange) is NOT implemented here.
/// This covers authentication only — sufficient for identity verification
/// and future API access.
class AnkiSyncClient {
  static const String _baseUrl = 'https://sync.ankiweb.net/sync';

  /// Authenticate with AnkiWeb.
  ///
  /// Returns the session key (hkey) on success, or throws on failure.
  static Future<String> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/login');
    final resp = await http.post(
      uri,
      body: {'username': email, 'password': password},
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    if (resp.statusCode != 200) {
      throw AnkiSyncException('服务器返回 ${resp.statusCode}');
    }

    final body = resp.body.trim();
    if (body.startsWith('key=')) {
      return body.substring(4);
    }
    if (body == 'bad auth') {
      throw AnkiSyncException('账号或密码错误');
    }
    throw AnkiSyncException('登录失败: $body');
  }

  /// Exchange session key for a hostKey.
  static Future<String> hostKey(String key) async {
    final uri = Uri.parse('$_baseUrl/hostKey');
    final resp = await http.post(
      uri,
      body: {'key': key},
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    if (resp.statusCode != 200) {
      throw AnkiSyncException('hostKey 请求失败: ${resp.statusCode}');
    }

    final body = resp.body.trim();
    if (body.startsWith('hostKey=')) {
      return body.substring(8);
    }
    throw AnkiSyncException('hostKey 获取失败: $body');
  }
}

class AnkiSyncException implements Exception {
  final String message;
  AnkiSyncException(this.message);
  @override
  String toString() => message;
}
