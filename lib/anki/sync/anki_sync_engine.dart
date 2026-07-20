import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════
// Sync protocol implementation — translated from Anki's Rust source
// (rslib/src/sync/)
// ═══════════════════════════════════════════════════════════════

/// Mirror of Rust's SyncHeader (from sync/request/header_and_stream.rs)
class SyncHeader {
  final int syncVersion;
  final String syncKey;
  final String clientVer;
  final String sessionKey;

  SyncHeader({
    this.syncVersion = 1, // v1 = uncompressed JSON, works everywhere
    required this.syncKey,
    this.clientVer = 'ankidart:1.0',
    String? sessionKey,
  }) : sessionKey = sessionKey ?? _randomSessionId();

  Map<String, dynamic> toJson() => {
        'sync_version': syncVersion,
        'sync_key': syncKey,
        'client_ver': clientVer,
        'session_key': sessionKey,
      };

  static String _randomSessionId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return String.fromCharCodes(Iterable.generate(
        10, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
  }
}

/// Mirror of Rust's Chunk (from sync/collection/chunks.rs)
class SyncChunk {
  bool done;
  List<CardEntry> cards;
  List<NoteEntry> notes;
  List<RevlogEntry> revlog;

  SyncChunk(
      {this.done = false,
      List<CardEntry>? cards,
      List<NoteEntry>? notes,
      List<RevlogEntry>? revlog})
      : cards = cards ?? [],
        notes = notes ?? [],
        revlog = revlog ?? [];

  Map<String, dynamic> toJson() => {
        'done': done,
        if (cards.isNotEmpty) 'cards': cards.map((c) => c.toJson()).toList(),
        if (notes.isNotEmpty) 'notes': notes.map((n) => n.toJson()).toList(),
        if (revlog.isNotEmpty) 'revlog': revlog.map((r) => r.toJson()).toList(),
      };

  factory SyncChunk.fromJson(Map<String, dynamic> json) => SyncChunk(
        done: json['done'] as bool? ?? false,
        cards: (json['cards'] as List?)
                ?.map((c) => CardEntry.fromJson(c as List<dynamic>))
                .toList() ??
            [],
        notes: (json['notes'] as List?)
                ?.map((n) => NoteEntry.fromJson(n as List<dynamic>))
                .toList() ??
            [],
        revlog: (json['revlog'] as List?)
                ?.map((r) => RevlogEntry.fromJson(r as List<dynamic>))
                .toList() ??
            [],
      );
}

/// Mirror of Rust's CardEntry (from sync/collection/chunks.rs)
class CardEntry {
  int id;
  int nid;
  int did;
  int ord;
  int mtime;
  int usn;
  int ctype;
  int queue;
  int due;
  int ivl;
  int factor;
  int reps;
  int lapses;
  int left;
  int odue;
  int odid;
  int flags;
  String data;

  CardEntry({
    required this.id,
    required this.nid,
    required this.did,
    this.ord = 0,
    this.mtime = 0,
    this.usn = -1,
    this.ctype = 0,
    this.queue = 0,
    this.due = 0,
    this.ivl = 0,
    this.factor = 2500,
    this.reps = 0,
    this.lapses = 0,
    this.left = 0,
    this.odue = 0,
    this.odid = 0,
    this.flags = 0,
    this.data = '',
  });

  List<dynamic> toJson() => [
        id,
        nid,
        did,
        ord,
        mtime,
        usn,
        ctype,
        queue,
        due,
        ivl,
        factor,
        reps,
        lapses,
        left,
        odue,
        odid,
        flags,
        data
      ];

  factory CardEntry.fromJson(List<dynamic> j) => CardEntry(
        id: j[0] as int,
        nid: j[1] as int,
        did: j[2] as int,
        ord: (j[3] as num).toInt(),
        mtime: (j[4] as num).toInt(),
        usn: (j[5] as num).toInt(),
        ctype: (j[6] as num).toInt(),
        queue: (j[7] as num).toInt(),
        due: (j[8] as num).toInt(),
        ivl: (j[9] as num).toInt(),
        factor: (j[10] as num).toInt(),
        reps: (j[11] as num).toInt(),
        lapses: (j[12] as num).toInt(),
        left: (j[13] as num).toInt(),
        odue: (j[14] as num).toInt(),
        odid: (j[15] as num).toInt(),
        flags: (j[16] as num).toInt(),
        data: j[17] as String? ?? '',
      );
}

/// Mirror of Rust's NoteEntry (from sync/collection/chunks.rs)
class NoteEntry {
  int id;
  String guid;
  int mid;
  int mtime;
  int usn;
  String tags;
  String fields;
  String sfld;
  String csum;
  int flags;
  String data;

  NoteEntry({
    required this.id,
    required this.guid,
    required this.mid,
    this.mtime = 0,
    this.usn = -1,
    this.tags = '',
    this.fields = '',
    this.sfld = '',
    this.csum = '',
    this.flags = 0,
    this.data = '',
  });

  List<dynamic> toJson() =>
      [id, guid, mid, mtime, usn, tags, fields, sfld, csum, flags, data];

  factory NoteEntry.fromJson(List<dynamic> j) => NoteEntry(
        id: j[0] as int,
        guid: j[1] as String,
        mid: j[2] as int,
        mtime: (j[3] as num).toInt(),
        usn: (j[4] as num).toInt(),
        tags: j[5] as String? ?? '',
        fields: j[6] as String? ?? '',
        sfld: j[7] as String? ?? '',
        csum: j[8] as String? ?? '',
        flags: j[9] as int? ?? 0,
        data: j[10] as String? ?? '',
      );
}

/// Mirror of Rust's RevlogEntry (simplified)
class RevlogEntry {
  int id;
  int cid;
  int usn;
  int ease;
  int ivl;
  int lastIvl;
  int factor;
  int time;
  int type_;

  RevlogEntry(
      {required this.id,
      required this.cid,
      this.usn = -1,
      required this.ease,
      required this.ivl,
      this.lastIvl = 0,
      this.factor = 2500,
      this.time = 0,
      this.type_ = 0});

  List<dynamic> toJson() =>
      [id, cid, usn, ease, ivl, lastIvl, factor, time, type_];
  factory RevlogEntry.fromJson(List<dynamic> j) => RevlogEntry(
        id: j[0] as int,
        cid: j[1] as int,
        usn: j[2] as int? ?? -1,
        ease: j[3] as int,
        ivl: j[4] as int,
        lastIvl: j[5] as int? ?? 0,
        factor: j[6] as int? ?? 2500,
        time: j[7] as int? ?? 0,
        type_: j[8] as int? ?? 0,
      );
}

/// Mirror of Rust's SyncMeta (from sync/collection/meta.rs)
class SyncMeta {
  int usn = 0;
  int ts = 0;
  int serverMessageIndex = 0;

  SyncMeta();

  Map<String, dynamic> toJson() => {
        'usn': usn,
        'ts': ts,
        'scm': 0,
        'server_message_index': serverMessageIndex
      };
  factory SyncMeta.fromJson(Map<String, dynamic> j) => SyncMeta()
    ..usn = j['usn'] as int? ?? 0
    ..ts = j['ts'] as int? ?? 0
    ..serverMessageIndex = j['server_message_index'] as int? ?? 0;
}

// ═══════════════════════════════════════════════════════════════
// HTTP Sync Client
// ═══════════════════════════════════════════════════════════════

const _syncHeaderName = 'X-Sync-Header';

/// Full sync engine matching Anki's Rust HttpSyncClient.
class AnkiSyncEngine {
  String syncKey = '';
  String _sessionKey = '';
  late http.Client _client;
  String _endpoint = 'https://sync.ankiweb.net/sync';

  AnkiSyncEngine({String? endpoint}) {
    _endpoint = endpoint ?? 'https://sync.ankiweb.net/sync';
    _client = http.Client();
    _sessionKey = SyncHeader._randomSessionId();
  }

  /// Login and get host key.
  Future<String> login(String email, String password) async {
    final uri = Uri.parse('$_endpoint/hostKey');
    final body = jsonEncode({'u': email, 'p': password});
    final header = jsonEncode({
      'sync_version': 1,
      'sync_key': '',
      'client_ver': 'ankidart:1.0',
      'session_key': _sessionKey,
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
      throw Exception('登录失败 (${resp.statusCode}): ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final key = json['key'] as String?;
    if (key == null || key.isEmpty) throw Exception('登录失败: 响应中没有 key');
    syncKey = key;
    return key;
  }

  /// Get the host key (used by the sync server).
  Future<String> hostKey() async {
    final uri = Uri.parse('$_endpoint/hostKey');
    final header = jsonEncode({
      'sync_version': 1,
      'sync_key': syncKey,
      'client_ver': 'ankidart:1.0',
      'session_key': _sessionKey,
    });
    final resp = await http.post(
      uri,
      body: jsonEncode({'u': syncKey}),
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Sync-Header': header,
      },
    );
    if (resp.statusCode != 200)
      throw Exception('HostKey failed: ${resp.statusCode}');
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return json['key'] as String? ?? '';
  }

  /// Send a sync request with uncompressed JSON (sync v1 protocol).
  /// Returns the JSON response body.
  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> body,
  ) async {
    final header = SyncHeader(syncKey: syncKey, sessionKey: _sessionKey);
    final jsonStr = jsonEncode(body);

    final resp = await _client.post(
      Uri.parse('$_endpoint/$method'),
      headers: {
        'Content-Type': 'application/json',
        _syncHeaderName: jsonEncode(header.toJson()),
      },
      body: jsonStr,
    );

    if (resp.statusCode != 200) {
      throw Exception('Sync request $method 失败: ${resp.statusCode}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Exchange metadata with server.
  Future<SyncMeta> meta(SyncMeta localMeta) async {
    final resp = await _request('meta', localMeta.toJson());
    return SyncMeta.fromJson(resp);
  }

  /// Start sync, get server graves.
  Future<List<int>> start(int minUsn, int maxUsn) async {
    final resp = await _request('start', {
      'min_usn': minUsn,
      'max_usn': maxUsn,
      'server_graves': [],
      'client_graves': [],
    });
    return (resp['graves'] as List?)?.cast<int>() ?? [];
  }

  /// Get next chunk of changes.
  Future<SyncChunk> chunk() async {
    final resp = await _request('chunk', {});
    return SyncChunk.fromJson(resp);
  }

  /// Apply a chunk of changes.
  Future<void> applyChunk(SyncChunk chunk) async {
    await _request('applyChunk', chunk.toJson());
  }

  /// Apply graves.
  Future<void> applyGraves(List<int> ids, int type_) async {
    await _request('applyGraves', {'ids': ids, 'type': type_});
  }

  /// Sanity check.
  Future<Map<String, dynamic>> sanityCheck(
      int clientCount, int serverCount) async {
    return await _request('sanityCheck2', {
      'client': clientCount,
      'server': serverCount,
    });
  }

  /// Finish sync.
  Future<int> finish() async {
    final resp = await _request('finish', {});
    return resp['next_sync'] as int? ?? 0;
  }

  /// Full upload (replace server data with local).
  Future<void> fullUpload(List<int> data) async {
    final header = SyncHeader(syncKey: syncKey, sessionKey: _sessionKey);
    final resp = await _client.post(
      Uri.parse('$_endpoint/upload'),
      headers: {
        'Content-Type': 'application/octet-stream',
        _syncHeaderName: jsonEncode(header.toJson()),
      },
      body: data,
    );
    if (resp.statusCode != 200)
      throw Exception('Full upload failed: ${resp.statusCode}');
  }

  /// Full download (replace local data with server).
  Future<List<int>> fullDownload() async {
    final header = SyncHeader(syncKey: syncKey, sessionKey: _sessionKey);
    final resp = await _client.post(
      Uri.parse('$_endpoint/download'),
      headers: {
        'Content-Type': 'application/octet-stream',
        _syncHeaderName: jsonEncode(header.toJson()),
      },
    );
    if (resp.statusCode != 200)
      throw Exception('Full download failed: ${resp.statusCode}');
    return resp.bodyBytes;
  }

  // ── Media Sync ──────────────────────────────────────────

  /// Begin media sync.
  Future<Map<String, dynamic>> mediaBegin() async {
    return await _request('mediaBegin', {});
  }

  /// Get media changes.
  Future<Map<String, dynamic>> mediaChanges() async {
    return await _request('mediaChanges', {});
  }

  /// Upload media changes as ZIP.
  Future<void> mediaUpload(List<int> zipData) async {
    final header = SyncHeader(syncKey: syncKey, sessionKey: _sessionKey);
    final resp = await _client.post(
      Uri.parse('$_endpoint/uploadChanges'),
      headers: {
        'Content-Type': 'application/octet-stream',
        _syncHeaderName: jsonEncode(header.toJson()),
      },
      body: zipData,
    );
    if (resp.statusCode != 200)
      throw Exception('Media upload failed: ${resp.statusCode}');
  }

  /// Download media files as ZIP.
  Future<List<int>> mediaDownload(List<int> fileIds) async {
    final header = SyncHeader(syncKey: syncKey, sessionKey: _sessionKey);
    final payload = jsonEncode({'file_ids': fileIds});
    final resp = await _client.post(
      Uri.parse('$_endpoint/downloadFiles'),
      headers: {
        'Content-Type': 'application/octet-stream',
        _syncHeaderName: jsonEncode(header.toJson()),
      },
      body: utf8.encode(payload),
    );
    if (resp.statusCode != 200)
      throw Exception('Media download failed: ${resp.statusCode}');
    return resp.bodyBytes;
  }

  void dispose() {
    _client.close();
  }
}
