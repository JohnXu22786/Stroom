import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'generated/anki/sync.pb.dart';
import 'generated/anki/cards.pb.dart';
import 'generated/anki/notes.pb.dart';
import 'generated/anki/decks.pb.dart';

/// Full Anki sync client using protobuf messages.
///
/// Protocol (matching AnkiWeb's v3 sync):
/// 1. Login → POST form → hkey
/// 2. SyncStatus → POST protobuf → check if changes exist
/// 3. SyncCollection → POST protobuf → send/receive data
class AnkiFullSyncClient {
  static const String _baseUrl = 'https://sync.ankiweb.net/sync';

  String? _hkey;

  // ── Login ──────────────────────────────────────────────

  /// Login to AnkiWeb and store the session key.
  /// Matches Anki's Rust sync_login(): POST /sync/hostKey with {"u","p"} JSON.
  Future<SyncAuth> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/hostKey');
    final body = jsonEncode({'u': email, 'p': password});
    final header = jsonEncode({
      'sync_version': 1,
      'sync_key': '',
      'client_ver': 'ankidart:1.0',
      'session_key': _sessionId(),
    });
    final resp = await http.post(
      uri,
      body: body,
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Sync-Header': header
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('登录失败 (${resp.statusCode}): ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final key = json['key'] as String?;
    if (key == null || key.isEmpty) throw Exception('登录失败: 响应中没有 key');
    _hkey = key;
    return SyncAuth()..hkey = key;
  }

  static String _sessionId() {
    const c = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return String.fromCharCodes(
        Iterable.generate(10, (_) => c.codeUnitAt(r.nextInt(c.length))));
  }

  /// Login using existing session key.
  SyncAuth authWithKey(String key) {
    _hkey = key;
    return SyncAuth()..hkey = key;
  }

  // ── Sync Status ────────────────────────────────────────

  /// Check sync status (what changes are needed).
  Future<SyncStatusResponse> checkStatus(String hkey) async {
    final auth = SyncAuth()..hkey = hkey;
    final payload = auth.writeToBuffer();
    final resp = await http.post(
      Uri.parse('$_baseUrl/sync'),
      body: payload,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    if (resp.statusCode != 200) {
      throw Exception('同步状态检查失败: ${resp.statusCode}');
    }
    return SyncStatusResponse.fromBuffer(resp.bodyBytes);
  }

  // ── Sync Collection ────────────────────────────────────

  /// Start a sync session with the server.
  /// Returns the server response with host_number and required action.
  Future<SyncCollectionResponse> startSync(String hkey) async {
    final auth = SyncAuth()..hkey = hkey;
    final req = SyncCollectionRequest()
      ..auth = auth
      ..syncMedia = false;
    final payload = req.writeToBuffer();
    final resp = await http.post(
      Uri.parse('$_baseUrl/sync'),
      body: payload,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    if (resp.statusCode != 200) {
      throw Exception('同步启动失败: ${resp.statusCode}');
    }
    return SyncCollectionResponse.fromBuffer(resp.bodyBytes);
  }

  // ── Full Upload / Download ─────────────────────────────

  /// Upload local collection to server (full sync).
  Future<void> fullUpload(String hkey, List<int> collectionData) async {
    // The full upload wraps the collection data in a sync message
    // This requires understanding the server protocol
    throw UnimplementedError('fullUpload: 需要实现 chunks 传输协议');
  }

  /// Download collection from server (full sync).
  Future<List<int>> fullDownload(String hkey) async {
    throw UnimplementedError('fullDownload: 需要实现 chunks 传输协议');
  }
}
