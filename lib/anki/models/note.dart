/// AnkiDroid note database schema — exact 1:1 mapping.
class AnkiNote {
  int id; // PRIMARY KEY — microsecond timestamp
  String guid; // globally unique id (for syncing)
  int mid; // model id (note type)
  int mod; // last modified (epoch seconds)
  int usn; // update sequence number
  String tags; // space-separated tag string (e.g. " tag1 tag2 ")
  String flds; // field values separated by 0x1f (unit separator)
  String sfld; // sort field — first field value
  int csum; // checksum (for duplicate detection)
  int flags; // flags
  String data; // JSON string (unused by core)

  AnkiNote({
    int? id,
    this.guid = '',
    required this.mid,
    this.mod = 0,
    this.usn = -1,
    this.tags = '',
    required this.flds,
    this.sfld = '',
    this.csum = 0,
    this.flags = 0,
    this.data = '',
  }) : id = id ?? _nextId();

  factory AnkiNote.createNew(
      {required int mid, required String flds, String tags = ''}) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final fields = flds.split(String.fromCharCode(0x1f));
    final sf = fields.isNotEmpty ? fields.first : '';
    return AnkiNote(
      id: now + DateTime.now().microsecond,
      guid: _guid(),
      mid: mid,
      mod: now ~/ 1000,
      tags: tags,
      flds: flds,
      sfld: sf,
    );
  }

  /// Fields as a list.
  List<String> get fieldList =>
      flds.isEmpty ? [] : flds.split(String.fromCharCode(0x1f));

  /// Tag list.
  List<String> get tagList => tags.trim().isEmpty
      ? []
      : tags.trim().split(' ').where((t) => t.isNotEmpty).toList();

  void addTag(String t) {
    final list = tagList;
    if (!list.contains(t)) {
      list.add(t);
      tags = ' ${list.join(' ')} ';
    }
  }

  void removeTag(String t) {
    final list = tagList..remove(t);
    tags = list.isEmpty ? '' : ' ${list.join(' ')} ';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'guid': guid,
        'mid': mid,
        'mod': mod,
        'usn': usn,
        'tags': tags,
        'flds': flds,
        'sfld': sfld,
        'csum': csum,
        'flags': flags,
        'data': data,
      };

  factory AnkiNote.fromMap(Map<String, dynamic> m) => AnkiNote(
        id: m['id'] as int,
        guid: m['guid'] as String? ?? '',
        mid: m['mid'] as int,
        mod: m['mod'] as int? ?? 0,
        usn: m['usn'] as int? ?? -1,
        tags: m['tags'] as String? ?? '',
        flds: m['flds'] as String? ?? '',
        sfld: m['sfld'] as String? ?? '',
        csum: m['csum'] as int? ?? 0,
        flags: m['flags'] as int? ?? 0,
        data: m['data'] as String? ?? '',
      );

  static int _counter = 0;
  static int _nextId() {
    _counter++;
    return DateTime.now().microsecondsSinceEpoch + _counter;
  }

  static String _guid() => '${DateTime.now().microsecondsSinceEpoch}_$_counter';

  @override
  String toString() => 'AnkiNote(id=$id, mid=$mid)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AnkiNote && id == other.id;
  @override
  int get hashCode => id.hashCode;
}
