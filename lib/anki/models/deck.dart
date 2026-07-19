/// Represents a deck in the Anki system — JSON shape matches Anki's col blob.
class AnkiDeck {
  int id;
  String name;
  String desc; // description
  int mod; // last modified (epoch seconds)
  int usn; // update sequence number
  int dyn; // 0=normal, 1=filtered
  int conf; // deck config preset id
  int crt; // creation date

  // Per-day counters (set by Anki on load; zero-initialized for us)
  List<int> lrnToday; // [count, sec]
  List<int> revToday;
  List<int> newToday;
  List<int> timeToday;

  bool collapsed;
  bool browserCollapsed;

  AnkiDeck({
    required this.id,
    required this.name,
    this.desc = '',
    this.mod = 0,
    this.usn = -1,
    this.dyn = 0,
    this.conf = 1,
    this.crt = 0,
    List<int>? lrnToday,
    List<int>? revToday,
    List<int>? newToday,
    List<int>? timeToday,
    this.collapsed = false,
    this.browserCollapsed = false,
  })  : lrnToday = lrnToday ?? [0, 0],
        revToday = revToday ?? [0, 0],
        newToday = newToday ?? [0, 0],
        timeToday = timeToday ?? [0, 0];

  factory AnkiDeck.createNew({required String name, String description = ''}) {
    _idCounter++;
    final now = DateTime.now().microsecondsSinceEpoch;
    return AnkiDeck(
      id: now + _idCounter,
      name: name,
      desc: description,
      mod: now ~/ 1000,
      crt: now ~/ 1000,
    );
  }

  static int _idCounter = 0;

  String? get parentName {
    final i = name.lastIndexOf('::');
    return i < 0 ? null : name.substring(0, i);
  }

  String get childName {
    final i = name.lastIndexOf('::');
    return i < 0 ? name : name.substring(i + 2);
  }

  bool isParentOf(String n) => n.startsWith('$name::');

  // ── Anki-compatible JSON ───────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'mod': mod,
        'usn': usn,
        'dyn': dyn,
        'conf': conf,
        'crt': crt,
        'lrnToday': lrnToday,
        'revToday': revToday,
        'newToday': newToday,
        'timeToday': timeToday,
        'collapsed': collapsed,
        'browserCollapsed': browserCollapsed,
      };

  factory AnkiDeck.fromJson(Map<String, dynamic> j) => AnkiDeck(
        id: j['id'] as int,
        name: j['name'] as String,
        desc: j['desc'] as String? ?? '',
        mod: j['mod'] as int? ?? 0,
        usn: j['usn'] as int? ?? -1,
        dyn: j['dyn'] as int? ?? 0,
        conf: j['conf'] as int? ?? 1,
        crt: j['crt'] as int? ?? 0,
        lrnToday: (j['lrnToday'] as List?)?.cast<int>() ?? [0, 0],
        revToday: (j['revToday'] as List?)?.cast<int>() ?? [0, 0],
        newToday: (j['newToday'] as List?)?.cast<int>() ?? [0, 0],
        timeToday: (j['timeToday'] as List?)?.cast<int>() ?? [0, 0],
        collapsed: j['collapsed'] as bool? ?? false,
        browserCollapsed: j['browserCollapsed'] as bool? ?? false,
      );

  @override
  String toString() => 'AnkiDeck(id=$id, name=$name)';
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AnkiDeck && id == other.id;
  @override
  int get hashCode => id.hashCode;
}
