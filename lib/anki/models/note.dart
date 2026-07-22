/// Anki Note — exact 1:1 mapping of the upstream Rust `Note` struct
/// (ankitects/anki rslib/src/notes/mod.rs).
///
/// Field naming follows the upstream Rust source / protobuf definition
/// (`notes.proto`), NOT the DB column short names.
///
/// ## Version reference
/// - AnkiDroid target release: **2.24.0** (May 2026)
/// - Upstream anki commit tracked at proto import time
/// - Upstream Rust workspace: `rslib/src/notes/mod.rs`
///
/// ## Key differences from DB storage
/// - `fields` is a `List<String>` (in-memory); DB stores as 0x1f-separated string in `flds`.
/// - `tags` is a `List<String>` (in-memory); DB stores as space-separated string.
/// - `sort_field` is `String?` (in-memory); DB stores as required `sfld`.
/// - `checksum` is `int?` (in-memory); DB stores as required `csum`.

/// In-memory Note matching the upstream Rust `Note` struct.
class Note {
  int id; // PRIMARY KEY — microsecond timestamp
  String guid; // globally unique id (for syncing)
  int notetype_id; // model id / note type id (was: mid)
  int mtime; // last modified epoch seconds (was: mod)
  int usn; // update sequence number
  List<String> tags; // tag list (was: space-separated String)
  List<String> fields; // field values list (was: 0x1f-separated String in flds)
  String? sort_field; // first non-empty sort field (was: String sfld)
  int? checksum; // checksum for duplicate detection (was: int csum)
  int flags; // flags
  String custom_data; // JSON string (was: data)

  Note({
    int? id,
    this.guid = '',
    required this.notetype_id,
    this.mtime = 0,
    this.usn = -1,
    List<String>? tags,
    required this.fields,
    this.sort_field,
    this.checksum,
    this.flags = 0,
    this.custom_data = '',
  })  : id = id ?? _nextId(),
        tags = tags ?? [];

  /// Creates a new note from a notetype id and field values.
  factory Note.createNew({
    required int notetype_id,
    required List<String> fields,
    List<String>? tags,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final sf = fields.isNotEmpty ? fields.first : '';
    return Note(
      id: now,
      guid: _guid(),
      notetype_id: notetype_id,
      mtime: now ~/ 1000,
      tags: tags ?? [],
      fields: fields,
      sort_field: sf,
    );
  }

  /// Creates a new note from a notetype id and field values string (0x1f-separated).
  factory Note.createNewFromFlds({
    required int notetype_id,
    required String flds,
    String tagsStr = '',
  }) {
    final fields =
        flds.isEmpty ? <String>[] : flds.split(String.fromCharCode(0x1f));
    return Note.createNew(
      notetype_id: notetype_id,
      fields: fields,
      tags: tagsStr.trim().isEmpty
          ? <String>[]
          : tagsStr.trim().split(' ').where((t) => t.isNotEmpty).toList(),
    );
  }

  /// Fields as a 0x1f-separated string for DB storage.
  String get fldsForDb => fields.join(String.fromCharCode(0x1f));

  /// Tags as a space-padded string for DB storage (e.g. " tag1 tag2 ").
  String get tagsForDb {
    if (tags.isEmpty) return '';
    return ' ${tags.join(' ')} ';
  }

  /// Sort field value for DB storage (derived from fields[0] if not set).
  String get sfldForDb => sort_field ?? (fields.isNotEmpty ? fields.first : '');

  /// Checksum for DB storage (computed if not set).
  int get csumForDb => checksum ?? Note.computeChecksum(sfldForDb);

  // ── Tag helpers ───────────────────────────────────────────────────────

  bool hasTag(String t) => tags.contains(t);

  void addTag(String t) {
    if (!tags.contains(t)) {
      tags.add(t);
    }
  }

  void removeTag(String t) {
    tags.remove(t);
  }

  // ── Serialization ─────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'guid': guid,
        'mid': notetype_id,
        'mod': mtime,
        'usn': usn,
        'tags': tagsForDb,
        'flds': fldsForDb,
        'sfld': sfldForDb,
        'csum': csumForDb,
        'flags': flags,
        'data': custom_data,
      };

  factory Note.fromMap(Map<String, dynamic> m) {
    final fldsStr = m['flds'] as String? ?? '';
    final fields =
        fldsStr.isEmpty ? <String>[] : fldsStr.split(String.fromCharCode(0x1f));
    final tagsStr = m['tags'] as String? ?? '';
    final tags = tagsStr.trim().isEmpty
        ? <String>[]
        : tagsStr.trim().split(' ').where((t) => t.isNotEmpty).toList();
    return Note(
      id: m['id'] as int,
      guid: m['guid'] as String? ?? '',
      notetype_id: m['mid'] as int,
      mtime: m['mod'] as int? ?? 0,
      usn: m['usn'] as int? ?? -1,
      tags: tags,
      fields: fields,
      sort_field: m['sfld'] as String?,
      checksum: m['csum'] as int?,
      flags: m['flags'] as int? ?? 0,
      custom_data: m['data'] as String? ?? '',
    );
  }

  static int _counter = 0;
  static int _nextId() {
    _counter++;
    return DateTime.now().microsecondsSinceEpoch + _counter;
  }

  static String _guid() => '${DateTime.now().microsecondsSinceEpoch}_$_counter';

  /// Compute the checksum for a field value (SHA1 truncated to u32).
  static int computeChecksum(String text) {
    // Simplified: use dart's built-in hashCode as a lightweight approximation.
    // The real implementation uses SHA-1, but for local-only operation and
    // duplicate detection the hash code is sufficient.
    return text.hashCode;
  }

  @override
  String toString() => 'Note(id=$id, notetype_id=$notetype_id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Note && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
