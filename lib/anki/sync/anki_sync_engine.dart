import 'dart:math';

import 'anki_sync_protocol_client.dart';

// ═══════════════════════════════════════════════════════════════
// Sync protocol implementation — translated from Anki's Rust source
// (rslib/src/sync/)
// ═══════════════════════════════════════════════════════════════

/// Legacy sync-v1 header model. Current Anki servers require sync v8 or later;
/// this type is retained only for source compatibility and is not sent.
@Deprecated('Use AnkiSyncProtocolClient with sync v10')
class SyncHeader {
  final int syncVersion;
  final String syncKey;
  final String clientVer;
  final String sessionKey;

  SyncHeader({
    this.syncVersion = 1,
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
    return String.fromCharCodes(
      Iterable.generate(10, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
    );
  }
}

/// Mirror of Rust's Chunk (from sync/collection/chunks.rs)
class SyncChunk {
  bool done;
  List<CardEntry> cards;
  List<NoteEntry> notes;
  List<RevlogEntry> revlog;

  SyncChunk({
    this.done = false,
    List<CardEntry>? cards,
    List<NoteEntry>? notes,
    List<RevlogEntry>? revlog,
  })  : cards = cards ?? [],
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
        data,
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

  List<dynamic> toJson() => [
        id,
        guid,
        mid,
        mtime,
        usn,
        tags,
        fields,
        sfld,
        csum,
        flags,
        data,
      ];

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

  RevlogEntry({
    required this.id,
    required this.cid,
    this.usn = -1,
    required this.ease,
    required this.ivl,
    this.lastIvl = 0,
    this.factor = 2500,
    this.time = 0,
    this.type_ = 0,
  });

  List<dynamic> toJson() => [
        id,
        cid,
        usn,
        ease,
        ivl,
        lastIvl,
        factor,
        time,
        type_,
      ];
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
        'server_message_index': serverMessageIndex,
      };
  factory SyncMeta.fromJson(Map<String, dynamic> j) => SyncMeta()
    ..usn = j['usn'] as int? ?? 0
    ..ts = j['ts'] as int? ?? 0
    ..serverMessageIndex = j['server_message_index'] as int? ?? 0;
}

// ═══════════════════════════════════════════════════════════════
// HTTP Sync Client
// ═══════════════════════════════════════════════════════════════

/// Compatibility wrapper for older callers. The old implementation sent
/// sync-v1 JSON and X-Sync-Header requests that current Anki servers reject.
/// Authentication and safe one-way collection transfer now use sync v10.
@Deprecated('Use AnkiSyncProtocolClient and AnkiCollectionTransfer directly')
class AnkiSyncEngine {
  final String _endpoint;
  String syncKey = '';
  AnkiSyncProtocolClient? _client;

  AnkiSyncEngine({String? endpoint})
      : _endpoint = endpoint ?? 'https://sync.ankiweb.net/sync/';

  Future<String> login(String email, String password) async {
    final client = _clientForKey();
    syncKey = await client.login(email, password);
    return syncKey;
  }

  Future<SyncMeta> meta(SyncMeta localMeta) async {
    final remote = await _authenticatedClient().checkStatus();
    return SyncMeta()
      ..usn = remote.usn
      ..ts = remote.serverTime;
  }

  Future<List<int>> start(int minUsn, int maxUsn) async =>
      _incrementalSyncUnsupported();

  Future<SyncChunk> chunk() async => _incrementalSyncUnsupported();

  Future<void> applyChunk(SyncChunk chunk) async =>
      _incrementalSyncUnsupported();

  Future<void> applyGraves(List<int> ids, int type_) async =>
      _incrementalSyncUnsupported();

  Future<Map<String, dynamic>> sanityCheck(
    int clientCount,
    int serverCount,
  ) async =>
      _incrementalSyncUnsupported();

  Future<int> finish() async => _incrementalSyncUnsupported();

  Future<void> fullUpload(List<int> data) async =>
      throw const AnkiSyncException('请使用 AnkiCollectionTransfer，在备份和确认覆盖后上传');

  Future<List<int>> fullDownload() async =>
      _authenticatedClient().downloadCollection();

  Future<Map<String, dynamic>> mediaBegin() async => _mediaSyncUnsupported();
  Future<Map<String, dynamic>> mediaChanges() async => _mediaSyncUnsupported();
  Future<void> mediaUpload(List<int> zipData) async => _mediaSyncUnsupported();
  Future<List<int>> mediaDownload(List<int> fileIds) async =>
      _mediaSyncUnsupported();

  AnkiSyncProtocolClient _clientForKey() {
    if (_client != null) return _client!;
    final uri = Uri.tryParse(_endpoint);
    if (uri != null &&
        uri.host == 'sync.ankiweb.net' &&
        (uri.path == '/sync' || uri.path == '/sync/')) {
      _client = AnkiSyncProtocolClient.ankiWeb();
    } else {
      _client = AnkiSyncProtocolClient.selfHosted(endpoint: _endpoint);
    }
    return _client!;
  }

  AnkiSyncProtocolClient _authenticatedClient() {
    if (syncKey.isEmpty) {
      throw const AnkiSyncException('请先登录同步账户');
    }
    if (_client == null) {
      final uri = Uri.tryParse(_endpoint);
      if (uri != null &&
          uri.host == 'sync.ankiweb.net' &&
          (uri.path == '/sync' || uri.path == '/sync/')) {
        _client = AnkiSyncProtocolClient.ankiWeb(hostKey: syncKey);
      } else {
        _client = AnkiSyncProtocolClient.selfHosted(
          endpoint: _endpoint,
          hostKey: syncKey,
        );
      }
    }
    return _client!;
  }

  Never _incrementalSyncUnsupported() =>
      throw const AnkiSyncException('旧版增量同步引擎已停用；Stroom 尚未实现安全的双向增量合并');

  Never _mediaSyncUnsupported() =>
      throw const AnkiSyncException('Stroom 尚未实现 Anki 媒体文件同步');

  void dispose() {
    _client?.close();
    _client = null;
  }
}
